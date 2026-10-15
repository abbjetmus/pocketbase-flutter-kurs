# Kapitel 3 – ACID och transaktioner

> **Mål med kapitlet:** Du ska förstå vad en transaktion är och kunna använda
> `BEGIN`, `COMMIT` och `ROLLBACK`. Du ska kunna förklara de fyra bokstäverna i
> ACID med konkreta exempel, känna igen vanliga samtidighetsproblem och veta hur
> SQLite och PocketBase hanterar dem.

## 3.1 Problemet: saker som måste hända tillsammans

I Kvittra visar varje inlägg hur många som gillat det. Att räkna alla
gillningar varje gång flödet visas kan bli dyrt när det finns miljontals
inlägg, så många appar sparar en **räknare** direkt på inlägget:
`posts.likes_count`. När någon gillar ett inlägg måste då *två* saker hända:

```
1.  INSERT INTO likes (post, user, created) VALUES (...);
2.  UPDATE posts SET likes_count = likes_count + 1 WHERE id = ...;
```

Vad händer om servern kraschar **mellan** rad 1 och rad 2?

```
  likes: 3 rader                likes: 4 rader                 likes: 4 rader
  likes_count = 3     ──1──►    likes_count = 3     ──⚡──►    likes_count = 3
                                                               Räknaren är fel – för alltid!
```

Gillningen finns, men räknaren visar fel siffra, och ingen kommer någonsin att
rätta den. Samma sak gäller många andra flöden i en social app:

- publicera ett inlägg **och** skapa notiser till alla följare,
- radera ett konto **och** alla användarens inlägg, kommentarer och gillningar,
- ta bort en gillning **och** minska räknaren.

Vi behöver ett sätt att säga: **"antingen händer alla sakerna, eller ingen av
dem"**. Det är vad en transaktion är.

## 3.2 Transaktioner: BEGIN, COMMIT, ROLLBACK

En **transaktion** är en grupp av SQL-satser som databasen behandlar som en
enda odelbar enhet.

| Kommando | Betyder |
|----------|---------|
| `BEGIN;` (eller `BEGIN TRANSACTION;`) | Starta en transaktion |
| `COMMIT;` | Spara alla ändringar permanent |
| `ROLLBACK;` | Ångra **alla** ändringar sedan `BEGIN` |

En lyckad gillning med räknare skulle se ut så här:

```sql
BEGIN;
INSERT INTO likes (post, user, created)
VALUES ((SELECT id FROM posts WHERE title = 'Morgondimma'),
        (SELECT id FROM users WHERE username = 'evaek'),
        '2026-10-12 10:00:00.000Z');
UPDATE posts SET likes_count = likes_count + 1 WHERE title = 'Morgondimma';
COMMIT;
```

Och en som vi ångrar:

```sql
BEGIN;
UPDATE posts SET title = upper(title);   -- hoppsan, alla titlar med VERSALER!
ROLLBACK;                                -- ångra allt
SELECT title FROM posts;                 -- titlarna är som förut
```

```
     BEGIN                                       COMMIT
       │  ┌─────────┐  ┌─────────┐  ┌─────────┐    │
 ──────┼─►│ INSERT  │─►│ UPDATE  │─►│ INSERT  │────┼──► allt sparas
       │  └─────────┘  └─────────┘  └─────────┘    │
       │                                           │
       │        fel / krasch / ROLLBACK            │
       └───────────────────────────────────────────┴──► ingenting sparas
```

💡 **Tips:** Varje enskild SQL-sats som du kör *utanför* `BEGIN ... COMMIT` är
automatiskt en egen liten transaktion (*autocommit*). Ett `UPDATE` som ändrar
100 rader ändrar alltså alla 100 eller ingen.

### Prova i PocketBase

Kör det andra exemplet ovan (det med `upper` och `ROLLBACK`) i **SQL console**.
Den sista `SELECT`:en visar att titlarna är oförändrade.

Tre saker att veta om transaktioner i SQL console:

1. **Hela rutan är allt-eller-inget.** Kör du flera satser utan `BEGIN` och en av
   dem misslyckas, sparas ingenting från den körningen.
2. **`BEGIN ... ROLLBACK` i samma körning** är ett säkert sätt att prova en
   farlig ändring.
3. ⚠️ **`BEGIN` utan `COMMIT`/`ROLLBACK` i samma körning – eller ett fel efter
   `BEGIN` – lämnar transaktionen öppen.** Den håller då skrivlåset (se 3.5),
   och PocketBase kan inte spara något förrän du startar om servern
   (`Ctrl + C`, sedan `./pocketbase serve`). Vid omstarten ångras den
   halvfärdiga transaktionen automatiskt – du ser atomicitet i praktiken!

🧪 **Prova själv:** Kör följande i SQL console. Den första satsen är en ny
gillning (evaek gillar Morgondimma), den andra en dubblett (bertil har redan
gillat Morgondimma):

```sql
INSERT INTO likes (post, user, created)
VALUES ((SELECT id FROM posts WHERE title = 'Morgondimma'),
        (SELECT id FROM users WHERE username = 'evaek'), '2026-10-12 10:00:00.000Z');
INSERT INTO likes (post, user, created)
VALUES ((SELECT id FROM posts WHERE title = 'Morgondimma'),
        (SELECT id FROM users WHERE username = 'bertil'), '2026-10-12 10:00:00.000Z');
```

Du får felet `UNIQUE constraint failed: likes.post, likes.user`. Kontrollera
sedan med en ny körning:

```sql
SELECT COUNT(*) AS gillningar
FROM likes l
JOIN posts p ON p.id = l.post
WHERE p.title = 'Morgondimma';
```

Svaret är fortfarande **2**. Evas gillning, som i sig var helt korrekt, sparades
inte – eftersom körningen som helhet misslyckades.

## 3.3 ACID

ACID är fyra egenskaper som en pålitlig databas garanterar för transaktioner.

| Bokstav | Engelska | Svenska | Kortversion |
|---------|----------|---------|-------------|
| **A** | Atomicity | Atomicitet | Allt eller inget |
| **C** | Consistency | Konsistens | Reglerna gäller alltid |
| **I** | Isolation | Isolering | Samtidiga transaktioner stör inte varandra |
| **D** | Durability | Beständighet | Det som är sparat förblir sparat |

### A – Atomicitet: allt eller inget

"Atom" betyder odelbar. En transaktion genomförs **helt** eller **inte alls**.

**Exempel i Kvittra:** När Anna publicerar ett inlägg ska alla hennes följare få
en notis. Säg att vi har en tabell `notifications (id, user, post, message,
created)`:

```sql
BEGIN;
INSERT INTO posts (id, author, title, body, created)
VALUES ('nyttinlagg0001', (SELECT id FROM users WHERE username = 'anna'),
        'Söndagsfika', 'Kanelbullar och kaffe på balkongen.', '2026-10-12 15:00:00.000Z');

INSERT INTO notifications (user, post, message, created)
SELECT f.follower, 'nyttinlagg0001', 'anna har publicerat ett nytt inlägg',
       '2026-10-12 15:00:00.000Z'
FROM follows f
WHERE f.following = (SELECT id FROM users WHERE username = 'anna');
COMMIT;
```

Om något av stegen misslyckas – eller datorn kraschar mitt i – blir det
`ROLLBACK` (och efter en krasch gör databasen det automatiskt när den startar
igen). Följarna får aldrig en notis om ett inlägg som inte finns, och inlägget
publiceras aldrig "tyst" utan notiser.

💡 **Tips:** Att radera ett konto med *Cascade delete* i PocketBase är också
atomärt: användaren och allt innehåll som kaskaden tar bort försvinner i en och
samma transaktion. Antingen är kontot helt borta, eller så finns allt kvar.

### C – Konsistens: reglerna gäller alltid

En transaktion tar databasen från ett **giltigt** tillstånd till ett annat
giltigt tillstånd. "Giltigt" betyder att alla regler du definierat håller:
`NOT NULL`, `UNIQUE`, `CHECK`, främmande nycklar.

**Exempel i Kvittra:**

| Regel | Skyddar mot |
|-------|-------------|
| `UNIQUE (post, user)` på `likes` | att samma person gillar samma inlägg två gånger |
| `UNIQUE (follower, following)` på `follows` | att man följer samma person två gånger |
| `CHECK (follower <> following)` | att man följer sig själv |
| `CHECK (likes_count >= 0)` | en negativ räknare |
| `REFERENCES posts(id)` | en gillning på ett inlägg som inte finns |

Som du såg i 🧪-övningen ovan vägrar databasen att spara en dubbelgillning, och
eftersom körningen var en transaktion ångrades även det som gick bra.

⚠️ **Varning:** Konsistens i ACID betyder bara att **de regler du har skrivit**
följs. Regeln "`likes_count` ska vara lika med antalet rader i `likes`" står
ingenstans, så databasen kan inte vakta den. Det är en av anledningarna till att
härledda värden är riskabla (kapitel 4.9). Och kom ihåg från kapitel 2: i
PocketBase är bara de **unika indexen** regler i själva databasen – resten
kontrolleras av PocketBase.

### I – Isolering: samtidiga transaktioner stör inte varandra

Många användare använder appen samtidigt. **Isolering** betyder att varje
transaktion ska bete sig *som om* den vore ensam i databasen.

**Exempel: dubbeltryck på gilla-knappen.** Johan trycker två gånger snabbt på
"Gilla" (eller har appen öppen på både mobilen och datorn). Appen gör så här:

```
1. Har jag redan gillat?  SELECT COUNT(*) FROM likes WHERE post = ? AND user = ?
2. Om 0 → gilla:          INSERT INTO likes ...
```

Utan isolering kan det gå så här:

```
 tid   Tryck 1                             Tryck 2
 ───   ──────────────────────────────      ──────────────────────────────
  1    SELECT ... → 0 (inte gillat!)
  2                                        SELECT ... → 0 (inte gillat!)
  3    INSERT gillning
  4                                        INSERT gillning
  5    ✓ "Gillat!"                         ✓ "Gillat!"

       → Två gillningar från samma person. Inlägget får ett hjärta för mycket.
```

Båda såg att Johan inte hade gillat, eftersom ingen av dem hade hunnit spara än.
Det här kallas ett **race condition** (kapplöpning). Lösningar:

1. **Låt databasen avgöra med ett villkor.** Det unika indexet på
   `likes(post, user)` gör det omöjligt att spara två gillningar – den andra
   `INSERT`:en misslyckas, oavsett timing. Det är därför indexet finns!
   Vill du slippa felet kan du be databasen att tyst hoppa över dubbletten:

   ```sql
   INSERT INTO likes (post, user, created)
   VALUES (?, ?, ?)
   ON CONFLICT (post, user) DO NOTHING;
   ```

   Nu är "gilla" **idempotent**: att trycka två gånger ger samma resultat som att
   trycka en gång.

2. **Gör kontroll + insättning i samma skrivtransaktion.** I SQLite startar
   `BEGIN IMMEDIATE` en transaktion som direkt tar skrivlåset, så ingen annan kan
   skriva mellan din kontroll och din insättning:

   ```sql
   BEGIN IMMEDIATE;
   SELECT COUNT(*) FROM likes WHERE post = ? AND user = ?;
   -- appen ser 0 → det är inte gillat
   INSERT INTO likes (post, user, created) VALUES (?, ?, ?);
   COMMIT;
   ```

   Om tryck 2 försöker samtidigt får det vänta (eller felet `database is locked`)
   tills tryck 1 är klart – och när det väl får göra sin `SELECT` ser det
   gillningen.

💡 **Tips:** Lösning 1 är nästan alltid bäst när regeln går att uttrycka som ett
villkor: den gäller all kod som någonsin skriver till tabellen. Lösning 2 behövs
när regeln är för krånglig för ett villkor, t.ex. "max 100 inlägg per dygn".

### D – Beständighet: sparat är sparat

När databasen har sagt "COMMIT klart" ska ändringen **finnas kvar**, även om
strömmen går en millisekund senare, servern kraschar eller appen stängs.

**Exempel:** Cissi publicerar "Halvmaran avklarad" och appen visar "Publicerat!".
Sekunden efter startar servern om. När den är igång igen måste inlägget finnas
där.

Databasen åstadkommer det genom att skriva ändringen till en **logg på disken**
(och be operativsystemet att verkligen skriva till disken, `fsync`) *innan* den
svarar "klart". Efter en krasch läser den loggen och:

- ändringar från transaktioner som hann bli `COMMIT`:ade → behålls,
- ändringar från transaktioner som inte hann bli klara → kastas.

Det är så atomicitet och beständighet samarbetar efter en krasch:

```
  BEGIN ── INSERT like ── UPDATE likes_count ── COMMIT ✓ ── ⚡ krasch
                                                        → båda ändringarna finns kvar (D)

  BEGIN ── INSERT like ── ⚡ krasch
                          → gillningen rullas tillbaka vid omstart (A)
```

## 3.4 Isoleringsproblem

Perfekt isolering är dyrt: transaktioner skulle i princip behöva köras en i taget.
Därför låter många databaser dig välja en lägre nivå som tillåter vissa
problem i utbyte mot bättre prestanda. Här är de klassiska problemen:

### Dirty read – läsa ej sparad data

Transaktion B läser något som A har skrivit men **inte** committat. Sedan gör A
`ROLLBACK`. B har då agerat på data som aldrig funnits.

```
 A: INSERT INTO posts (... 'Hemligt utkast' ...);     (inte committat)
 B: SELECT ... FROM posts → ser 'Hemligt utkast'      skickar push-notis till följarna!
 A: ROLLBACK;                                         (inlägget fanns aldrig)
```

### Non-repeatable read – samma fråga, olika svar

B läser en rad två gånger inom samma transaktion, och A hinner ändra och
committa raden emellan.

```
 B: SELECT username FROM users WHERE id = ?;   → 'cissi'
 A: UPDATE users SET username = 'cissi_springer' WHERE ...; COMMIT;
 B: SELECT username FROM users WHERE id = ?;   → 'cissi_springer'   (?!)
```

### Phantom read – nya rader dyker upp

B räknar rader som matchar ett villkor och läser sedan raderna, och A hinner
**lägga till** en rad som matchar emellan.

```
 B: SELECT COUNT(*) FROM comments WHERE post = ?;   → 3    rubrik: "3 kommentarer"
 A: INSERT INTO comments (... samma post ...); COMMIT;
 B: SELECT * FROM comments WHERE post = ?;          → 4 rader (en "spökrad")
```

Dubbeltrycket på gilla-knappen i 3.3 är i grunden ett fantomproblem: raden som
`SELECT` letade efter dök upp först efteråt.

### Lost update – en uppdatering försvinner

Två transaktioner läser samma värde, räknar fram ett nytt, och skriver tillbaka.
Den sista skriver över den förstas ändring.

```
 Räknare: likes_count för "Halvmaran avklarad" = 4

 Eva gillar:  läser 4                 Johan gillar:  läser 4
 Eva:         skriver 4 + 1 = 5       Johan:         skriver 4 + 1 = 5
                                      → borde vara 6!
```

Lösningen är ofta att låta databasen räkna i en enda sats i stället för att läsa
till appen och skriva tillbaka:

```sql
-- Dåligt: appen läser likes_count, räknar +1 och skriver tillbaka värdet
-- Bra: en atomär sats – databasen räknar själv
UPDATE posts SET likes_count = likes_count + 1 WHERE id = ?;
```

Ännu bättre är ibland att inte spara räknaren alls, utan räkna fram den med
`COUNT(*)` när den behövs. Då finns inget att tappa bort.

Lost update finns även utan räknare: om Anna redigerar sitt inlägg på mobilen och
datorn samtidigt vinner den som sparar sist, och den andra ändringen försvinner
tyst.

### Isoleringsnivåer

SQL-standarden definierar fyra nivåer. Ju högre nivå, desto färre problem – men
desto mer väntan och låsning.

| Nivå | Dirty read | Non-repeatable read | Phantom read |
|------|:----------:|:-------------------:|:------------:|
| Read Uncommitted | möjligt | möjligt | möjligt |
| Read Committed | – | möjligt | möjligt |
| Repeatable Read | – | – | möjligt |
| Serializable | – | – | – |

PostgreSQL använder **Read Committed** som standard; MySQL (InnoDB) använder
**Repeatable Read**. Man väljer nivå med t.ex.
`SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;` (gäller ej SQLite).

💡 **Tips:** Du behöver inte kunna tabellen utantill. Det viktiga är att veta *att*
de här problemen finns, så att du känner igen dem – särskilt **lost update** och
**race conditions** som dubbeltryck, som är vanliga buggar i riktiga appar.

## 3.5 SQLite i praktiken

SQLite är enklare än serverdatabaser på ett sätt som gör isolering lättare:

- **Bara en skrivare åt gången.** Hela databasen låses när någon skriver. Två
  transaktioner kan alltså aldrig skriva samtidigt. Det gör att SQLite i praktiken
  ger **Serializable**-isolering.
- **Många läsare samtidigt** – särskilt i WAL-läge (se nedan).
- Om en skrivare måste vänta för länge får den felet `SQLITE_BUSY` /
  `database is locked`. Man brukar därför sätta en *busy timeout* så att den väntar
  en stund i stället för att ge upp direkt.

Det är också därför en bortglömd `BEGIN` i SQL console stoppar PocketBase: den
öppna transaktionen håller det enda skrivlåset, och alla andra som vill skriva
får vänta.

### Transaktionstyper i SQLite

| Kommando | När tas skrivlåset? |
|----------|---------------------|
| `BEGIN` / `BEGIN DEFERRED` | Först när transaktionen gör sin första skrivning |
| `BEGIN IMMEDIATE` | Direkt. Bra när du ska läsa-och-sedan-skriva (som gilla-kontrollen) |
| `BEGIN EXCLUSIVE` | Direkt, och blockerar även läsare (i icke-WAL-läge) |

### WAL – Write-Ahead Logging

Som standard skriver SQLite ändringar direkt i databasfilen och sparar en kopia
av det gamla innehållet i en *rollback journal*. I **WAL-läge** gör den tvärtom:
nya ändringar skrivs först till en separat loggfil (`data.db-wal`), och flyttas
in i huvudfilen senare (en *checkpoint*).

```
             Rollback journal (standard)              WAL-läge
           ┌───────────────────────────────┐     ┌───────────────────────────────┐
 skrivare  │ skriver i data.db,            │     │ lägger till i data.db-wal     │
           │ läsare måste vänta            │     │ läsare läser data.db          │
           │                               │     │ + det committade i WAL        │
           └───────────────────────────────┘     └───────────────────────────────┘
                                                  → läsare och skrivare blockerar
                                                    inte varandra
```

```sql
PRAGMA journal_mode;         -- visa nuvarande läge (i PocketBase: wal)
PRAGMA journal_mode = WAL;   -- slå på (sparas i filen, gäller sedan alltid)
PRAGMA busy_timeout = 5000;  -- vänta upp till 5 s på lås i stället för att ge fel
```

Fördelar med WAL: läsare blockeras inte av skrivare, och skrivningar blir ofta
snabbare. Det är därför **PocketBase alltid kör SQLite i WAL-läge**. Om du tittar
i `pb_data/` ser du filerna `data.db`, `data.db-wal` och `data.db-shm`.

🧪 **Prova själv:** Kör `PRAGMA journal_mode;` i SQL console. Vilket läge kör din
PocketBase i?

⚠️ **Varning:** Kopiera aldrig bara `data.db` som backup medan PocketBase kör –
de senaste ändringarna kan ligga kvar i `-wal`-filen. Använd PocketBase inbyggda
backup (**Settings → Backups**), eller stoppa servern först.

## 3.6 Transaktioner i PocketBase

PocketBase sköter transaktioner åt dig vid vanliga API-anrop: att skapa, ändra
eller ta bort en record (inklusive *Cascade delete*) är en egen transaktion.
Men när du skriver **hooks** (serverkod i JavaScript, modul 02) och vill göra
flera ändringar som hör ihop, använder du `$app.runInTransaction`:

```javascript
// pb_hooks/like.pb.js (förenklat exempel): gilla + öka räknaren
$app.runInTransaction((txApp) => {
    const post = txApp.findRecordById("posts", postId);

    const like = new Record(txApp.findCollectionByNameOrId("likes"));
    like.set("post", postId);
    like.set("user", userId);
    txApp.save(like);              // unika indexet kastar fel vid dubbelgillning

    post.set("likes_count", post.getInt("likes_count") + 1);
    txApp.save(post);              // använd txApp, inte $app, inuti transaktionen!

    // Kastas ett fel någonstans här rullas ALLT tillbaka automatiskt.
});
```

Samma principer som i SQL:

| SQL | PocketBase-hook |
|-----|-----------------|
| `BEGIN` | `$app.runInTransaction((txApp) => { ...` |
| satser i transaktionen | anrop på `txApp` |
| `COMMIT` | funktionen returnerar normalt |
| `ROLLBACK` | funktionen kastar ett fel (`throw`) |

⚠️ **Varning:** Inuti `runInTransaction` måste du använda `txApp` och inte `$app`.
Annars körs anropet *utanför* transaktionen – och eftersom SQLite bara har en
skrivare kan det till och med hänga sig (deadlock) när det väntar på låset som
den egna transaktionen håller.

För dubbelgillningsproblemet räcker det unika indexet på `likes(post, user)` som
du redan har skapat. I modul 02 ser du hur API-regler och hooks skyddar resten,
t.ex. att man inte kan följa sig själv.

## 3.7 Sammanfattning

- En **transaktion** grupperar satser: `BEGIN` … `COMMIT` sparar allt, `ROLLBACK`
  ångrar allt.
- **A**tomicitet: allt eller inget. **C**onsistency: villkoren gäller alltid.
  **I**solering: samtidiga transaktioner stör inte varandra. **D**urability: det
  committade finns kvar efter en krasch.
- Klassiska samtidighetsproblem: dirty read, non-repeatable read, phantom read och
  lost update. Dubbeltryck på gilla-knappen är ett race condition.
- Skydda dig med **villkor/unika index** (gärna med `ON CONFLICT DO NOTHING`), med
  **atomära satser** (`likes_count = likes_count + 1`) och genom att göra
  kontroll + skrivning i **samma transaktion**.
- **SQLite** har en skrivare åt gången och kör i praktiken serialiserbart.
  **WAL** låter läsare och skrivare arbeta samtidigt. PocketBase använder WAL.
- I SQL console: avsluta alltid `BEGIN` med `COMMIT` eller `ROLLBACK` i samma
  körning. I PocketBase-hooks: `$app.runInTransaction((txApp) => ...)`.

## Kontrollfrågor

1. Vad händer med ändringarna om en transaktion har gjort två `INSERT` och
   servern kraschar innan `COMMIT`?
2. Vilken ACID-egenskap bryts om en gillning sparas men räknaren `likes_count`
   aldrig ökas?
3. Varför räcker det inte att appen först kollar om användaren redan gillat och
   sedan sparar gillningen?
4. Vad är skillnaden mellan `BEGIN` och `BEGIN IMMEDIATE` i SQLite?
5. Varför kan PocketBase sluta svara om du kör `BEGIN;` i SQL console utan att
   avsluta transaktionen?
6. Vilka tre filer hittar du i `pb_data/` för databasen och varför?

Nästa kapitel: [Kapitel 4 – Databasdesign](04-databasdesign.md)

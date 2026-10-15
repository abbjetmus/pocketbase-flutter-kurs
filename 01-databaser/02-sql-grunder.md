# Kapitel 2 – SQL-grunder

> **Mål med kapitlet:** Du ska kunna skapa tabeller med datatyper och villkor,
> lägga in, läsa, ändra och ta bort data, sammanfatta data med aggregat och
> `GROUP BY`, kombinera tabeller med `JOIN` och underfrågor, samt förstå när ett
> index behövs.

## 2.0 Så kör du exemplen

Alla exempel körs mot Kvittra i din PocketBase. Har du inte byggt den än – gör
det först (se [modulens README](README.md), steg 1–2).

| Exempel som … | Kör du i … |
|---------------|------------|
| bara läser (`SELECT`) | en **View collection**: *New collection* → typ **View** → klistra in frågan i *Select query* → *Create*. Eller snabbt i **SQL console**. |
| ändrar data (`INSERT`, `UPDATE`, `DELETE`) eller visar en frågeplan | **Settings → SQL console** |
| skapar tabeller och index | Dashboard (*New collection*, *New field*, *New index*). SQL:en visas för att du ska förstå vad PocketBase gör åt dig. |

Kom ihåg att en View collection måste ha en kolumn som heter `id` (se
[README](README.md#skapa-en-view-collection)). Därför börjar många frågor i
kapitlet med `p.id` eller `u.id`. I resultattabellerna nedan visar vi **inte**
id-kolumnen, eftersom dina id:n är slumpade och ser annorlunda ut än någon
annans.

## 2.1 Vad är SQL?

SQL (*Structured Query Language*) är ett **deklarativt** språk. Det betyder att
du beskriver **vad** du vill ha – inte **hur** datorn ska ta fram det.

Jämför med hur du skulle hitta användare som har en webbplats i ett vanligt
program:

```python
# Imperativt (Python): du beskriver HUR – loopa, jämför, samla ihop
result = []
for user in users:
    if user.website != "":
        result.append((user.username, user.website))
```

```sql
-- Deklarativt (SQL): du beskriver VAD
SELECT username, website FROM users WHERE website != '';
```

Databasen har en **frågeoptimerare** (*query planner*) som själv väljer det
snabbaste sättet att ta fram svaret, till exempel om den ska använda ett index
eller läsa hela tabellen.

SQL-kommandon delas in i grupper:

| Grupp | Står för | Kommandon | Används till |
|-------|----------|-----------|--------------|
| **DDL** | *Data Definition Language* | `CREATE`, `ALTER`, `DROP` | Definiera **strukturen**: tabeller, index, vyer |
| **DML** | *Data Manipulation Language* | `INSERT`, `UPDATE`, `DELETE` | Ändra **innehållet** |
| **DQL** | *Data Query Language* | `SELECT` | Läsa data (räknas ibland till DML) |
| **TCL** | *Transaction Control Language* | `BEGIN`, `COMMIT`, `ROLLBACK` | Transaktioner (kapitel 3) |

I PocketBase motsvarar DDL det du gör när du skapar och ändrar collections, och
DML det du gör när du skapar, redigerar och tar bort records.

Några skrivregler:

- Nyckelord som `SELECT` är inte skiftlägeskänsliga, men man skriver dem ofta
  med VERSALER för att de ska synas.
- Text skrivs inom **enkla citattecken**: `'anna'`. Dubbla citattecken används
  för **namn** på tabeller och kolumner: `"user"`.
- Varje sats avslutas med semikolon `;`.
- Kommentarer: `-- resten av raden` eller `/* flera rader */`.

⚠️ **Varning:** Kolumnen `likes.user` har ett namn som är ett **reserverat ord** i
många databaser. I SQLite (och därmed PocketBase) går det bra att skriva
`user` utan citattecken. I PostgreSQL betyder `SELECT user` däremot "vilken
databasanvändare är inloggad?", så där måste du skriva `"user"`. Samma sak
gäller ord som `order`, `group` och `end`.

## 2.2 CREATE TABLE – datatyper

En tabell skapas med `CREATE TABLE`. Varje kolumn får ett namn, en datatyp och
eventuella villkor. Så här kan `posts` se ut skriven för hand i SQLite:

```sql
CREATE TABLE posts (
    id       TEXT PRIMARY KEY,
    author   TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title    TEXT NOT NULL CHECK (length(title) > 0),
    body     TEXT NOT NULL,
    created  TEXT NOT NULL
);
```

SQLite har fem lagringsklasser. Andra databaser har fler typer, men de mappar
ungefär så här:

| SQLite | Innehåll | PostgreSQL-motsvarighet | Exempel i Kvittra |
|--------|----------|-------------------------|-------------------|
| `INTEGER` | Heltal | `integer`, `bigint` | antal gillningar, längd i tecken |
| `REAL` | Decimaltal (flyttal) | `double precision` | (t.ex. latitud för en plats) |
| `TEXT` | Text | `text`, `varchar(n)` | `username`, `body`, id:n, datum |
| `BLOB` | Binärdata | `bytea` | (bilder – men lagra hellre som fil, se kapitel 4) |
| `NULL` | "Inget värde" | `NULL` | ett värde som saknas |

SQLite har ingen egen `BOOLEAN`- eller `DATETIME`-typ. Man använder:

- **boolean** → `INTEGER` med `0` (falskt) och `1` (sant). PocketBase-fältet
  *Bool* lagras just så.
- **datum och tid** → `TEXT` i ISO 8601-format. PocketBase lagrar t.ex.
  `'2026-10-11 06:45:00.000Z'` (UTC).

Varför fungerar text för datum? För att formatet `YYYY-MM-DD HH:MM:SS` sorteras
korrekt i bokstavsordning: `'2026-09-28' < '2026-10-04'`. Mer om datum i
[kapitel 4](04-databasdesign.md).

### Så här ser det ut i PocketBase

PocketBase skrev `CREATE TABLE` åt dig när du skapade collectionen. Kör i
**SQL console**:

```sql
SELECT sql FROM sqlite_master WHERE name = 'posts';
```

Du får ungefär (kolumnerna i bokstavsordning):

```sql
CREATE TABLE `posts` (
  `author`  TEXT DEFAULT '' NOT NULL,
  `body`    TEXT DEFAULT '' NOT NULL,
  `created` TEXT DEFAULT '' NOT NULL,
  `id`      TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL,
  `title`   TEXT DEFAULT '' NOT NULL,
  `updated` TEXT DEFAULT '' NOT NULL
)
```

Tre saker att lägga märke till:

1. **Allt är `TEXT`** – även id:n, relationer och datum.
2. **Tomt betyder `''`, inte `NULL`.** Ett textfält som du lämnar tomt i
   PocketBase sparas som tom sträng. Därför skriver vi `website = ''` och inte
   `website IS NULL` i den här kursen.
3. **Inga `REFERENCES` och inga `CHECK`.** PocketBase kontrollerar relationer,
   *Required*, längder och *Cascade delete* själv, i sin egen kod, innan den
   sparar. Det enda databasen själv vaktar är primärnyckeln och dina **unika
   index**. Det får konsekvenser – se 2.3.

## 2.3 Villkor (constraints)

Villkor är regler som databasen *vägrar* bryta. De är ditt viktigaste skydd mot
felaktig data – oavsett om felet kommer från en bugg i appen, en
adminanvändare eller ett skript.

| Villkor | Betyder | Exempel i SQL | Motsvarighet i PocketBase |
|---------|---------|---------------|---------------------------|
| `PRIMARY KEY` | Unik identifierare för raden | `id TEXT PRIMARY KEY` | fältet `id` |
| `NOT NULL` | Värde måste finnas | `title TEXT NOT NULL` | *Required* |
| `UNIQUE` | Inga dubbletter | `username TEXT UNIQUE` | Index med *Unique* |
| `CHECK (...)` | Ett eget villkor som måste vara sant | `CHECK (follower <> following)` | API-regel eller hook (modul 02) |
| `DEFAULT ...` | Värde om inget anges | `created TEXT DEFAULT (datetime('now'))` | *Autodate*, standardvärden |
| `REFERENCES t(kol)` | Främmande nyckel | `post TEXT REFERENCES posts(id)` | fält av typen *Relation* |

Så här skulle `likes` och `follows` se ut med alla villkor i ren SQL:

```sql
CREATE TABLE likes (
    id       TEXT PRIMARY KEY,
    post     TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created  TEXT NOT NULL,
    UNIQUE (post, user)                 -- gilla samma inlägg bara en gång
);

CREATE TABLE follows (
    id         TEXT PRIMARY KEY,
    follower   TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    following  TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created    TEXT NOT NULL,
    UNIQUE (follower, following),       -- följa samma person bara en gång
    CHECK (follower <> following)       -- man kan inte följa sig själv
);
```

Lägg märke till `UNIQUE (post, user)` och `CHECK (follower <> following)`: ett
villkor som gäller *flera* kolumner skrivs som ett **tabellvillkor** efter
kolumnerna. I PocketBase skapade du samma `UNIQUE` som ett index med två
kolumner.

### Främmande nycklar och ON DELETE

Vad ska hända med kommentarerna om ett inlägg tas bort? Det bestämmer du med
`ON DELETE` (i PocketBase: inställningen *Cascade delete* på relationsfältet):

| Regel | Vad händer med raderna som pekar på den borttagna raden? | I Kvittra |
|-------|----------------------------------------------------------|-----------|
| `RESTRICT` / `NO ACTION` (standard) | Borttagningen **nekas** så länge det finns referenser | – |
| `CASCADE` | Raderna tas **också bort** | alla relationer (*Cascade delete* på) |
| `SET NULL` | Den främmande nyckeln sätts till `NULL` (tom) | ett alternativ för `posts.author` |
| `SET DEFAULT` | Sätts till kolumnens standardvärde | – |

```
Ta bort användaren bertil

  users          posts (author = bertil)      comments/likes på hans inlägg
  ┌────────┐ CASCADE ┌──────────────┐  CASCADE  ┌──────────────┐
  │ bertil │ ──────► │ tas bort     │ ────────► │ tas bort     │
  └────────┘         └──────────────┘           └──────────────┘
       │ CASCADE     ┌───────────────────────────────────────────┐
       └───────────► │ hans egna kommentarer, gillningar och     │
                     │ follows (åt båda hållen) tas bort         │
                     └───────────────────────────────────────────┘
```

Kaskaden fortsätter i flera steg: användaren → hans inlägg → kommentarerna och
gillningarna på de inläggen.

**Vad är rätt för `posts.author`?** Det finns inget enda svar:

| Val | Effekt | Passar när … |
|-----|--------|--------------|
| `CASCADE` | Kontot och allt innehåll försvinner | Användaren ska kunna radera sig helt (GDPR). Vi väljer detta. |
| `SET NULL` | Inläggen ligger kvar som "[borttagen användare]" | Diskussioner ska gå att läsa även när någon slutat (som på många forum). Kräver att `author` får vara tom. |
| `RESTRICT` | Kontot går inte att ta bort förrän inläggen är borttagna | Man vill tvinga fram ett aktivt val, t.ex. "radera eller anonymisera dina inlägg först". |

⚠️ **Varning:** I ren SQLite är kontroll av främmande nycklar **avstängd** som
standard – man måste köra `PRAGMA foreign_keys = ON;` i varje anslutning.
PocketBase slår på den, men eftersom PocketBases tabeller saknar `REFERENCES`
spelar det ingen roll där: det är PocketBase som vaktar relationerna.

🧪 **Prova själv:** Testa vilka regler som skyddar Kvittra.

1. I Dashboard: öppna `likes` och skapa en ny record där **bertil** gillar
   **Morgondimma**. Det har han redan gjort, så du får felet *"Value must be
   unique"* – det unika indexet slog till.
2. Skapa ett inlägg utan titel. Felet kommer från *Required*.
3. Skapa en `follows`-record där `follower` och `following` är samma person.
   Det **går**! Vi har ingen `CHECK` i PocketBase. Ta bort recorden igen. (I
   modul 02 stoppar du det med en API-regel.)
4. I **SQL console**: lägg in en gillning på ett inlägg som inte finns.

   ```sql
   INSERT INTO likes (post, user, created)
   VALUES ('finnsinte12345', (SELECT id FROM users WHERE username = 'anna'),
           '2026-10-12 09:00:00.000Z');
   SELECT * FROM likes WHERE post = 'finnsinte12345';
   ```

   Det går också – tabellen har ingen `REFERENCES`, och SQL console går förbi
   PocketBase. Städa upp: `DELETE FROM likes WHERE post = 'finnsinte12345';`

Slutsats: **vilka regler som gäller beror på var de är definierade.** Regler i
databasen (unika index) gäller alltid. Regler i PocketBase gäller bara när du går
via PocketBase (Dashboard och API).

### ALTER TABLE och DROP TABLE

```sql
-- Lägg till en kolumn i efterhand
ALTER TABLE users ADD COLUMN city TEXT NOT NULL DEFAULT '';

-- Byt namn på en kolumn
ALTER TABLE users RENAME COLUMN city TO location;

-- Ta bort kolumnen igen (SQLite 3.35+)
ALTER TABLE users DROP COLUMN location;

-- Ta bort en hel tabell (och all data!)
DROP TABLE IF EXISTS demo_posts;
```

I PocketBase gör du samma sak i Dashboard: **New field** (`ADD COLUMN`), byta
namn på ett fält (`RENAME COLUMN`), ta bort fältet (`DROP COLUMN`) och ta bort
en collection (`DROP TABLE`).

⚠️ **Varning:** Ändra aldrig strukturen på PocketBases tabeller med `ALTER` eller
`DROP` i SQL console. PocketBase har en egen beskrivning av varje collection och
blir förvirrad om tabellen inte längre stämmer med den. Gör strukturändringar i
Dashboard.

## 2.4 INSERT – lägga in data

```sql
-- Ange kolumnerna explicit (rekommenderas)
INSERT INTO likes (post, user, created)
VALUES (
    (SELECT id FROM posts WHERE title = 'Hej Kvittra!'),
    (SELECT id FROM users WHERE username = 'johan'),
    '2026-10-12 09:00:00.000Z'
);
```

Kör det i **SQL console**. Johan gillar nu Evas första inlägg. Två saker att
lägga märke till:

- Vi angav inte `id`. Kolumnen har ett `DEFAULT` som hittar på ett id åt oss.
- Vi slog upp id:n med små underfrågor (`SELECT id FROM ...`) – mer om
  underfrågor i 2.10.

Kontrollera:

```sql
SELECT l.id, u.username, l.created
FROM likes l
JOIN users u ON u.id = l.user
JOIN posts p ON p.id = l.post
WHERE p.title = 'Hej Kvittra!';
```

| username | created |
|----------|---------|
| johan | 2026-10-12 09:00:00.000Z |

Flera rader i en sats skrivs så här:

```sql
INSERT INTO comments (post, author, body, created) VALUES
    ((SELECT id FROM posts WHERE title = 'Morgondimma'),
     (SELECT id FROM users WHERE username = 'bertil'), 'Vackert!', '2026-10-12 09:05:00.000Z'),
    ((SELECT id FROM posts WHERE title = 'Morgondimma'),
     (SELECT id FROM users WHERE username = 'cissi'), 'Wow!', '2026-10-12 09:06:00.000Z');
```

Det vanliga sättet i PocketBase är förstås **New record** i Dashboard, eller
ett `POST`-anrop till REST-API:t. Då fyller PocketBase i `id`, `created` och
`updated` och kontrollerar alla regler.

💡 **Tips:** Skriv alltid ut kolumnnamnen i `INSERT`. Då fungerar satsen även om
någon lägger till en kolumn i tabellen senare, och det syns vad varje värde är.

⚠️ **Varning:** Satserna ovan ändrar Kvittras data. I 2.7 tar vi bort dem igen, så
att svaren i resten av kapitlet och i övningarna stämmer.

## 2.5 SELECT – läsa data

Grundformen:

```sql
SELECT kolumn1, kolumn2     -- vilka kolumner
FROM tabell                 -- från vilken tabell
WHERE villkor               -- vilka rader
ORDER BY kolumn             -- i vilken ordning
LIMIT antal;                -- hur många
```

```sql
SELECT * FROM users;                                  -- alla kolumner (bra för att titta)
SELECT username, name FROM users;                     -- bara vissa kolumner
SELECT username AS anvandarnamn FROM users;           -- byt namn på kolumner i svaret
SELECT title, length(body) AS tecken FROM posts;      -- beräknade kolumner
SELECT DISTINCT author FROM posts;                    -- unika värden
```

### WHERE – filtrera rader

```sql
SELECT id, username, website FROM users WHERE website != '';
```

| username | website |
|----------|---------|
| anna | https://anna.example.com |
| cissi | https://cissi.example.com |

Vanliga operatorer i `WHERE`:

| Operator | Exempel | Betyder |
|----------|---------|---------|
| `=`, `<>` (eller `!=`) | `username = 'anna'` | lika med / inte lika med |
| `<`, `<=`, `>`, `>=` | `created >= '2026-10-01'` | jämförelse |
| `AND`, `OR`, `NOT` | `bio = '' AND website = ''` | kombinera villkor |
| `IN (...)` | `username IN ('anna', 'cissi')` | något av värdena |
| `BETWEEN a AND b` | `length(body) BETWEEN 30 AND 50` | inom intervall (inklusive gränserna) |
| `LIKE` | `title LIKE '%kaffe%'` | mönster: `%` = valfri text, `_` = ett tecken |
| `IS NULL`, `IS NOT NULL` | `c.id IS NULL` | saknar värde / har värde |

```sql
-- Inlägg från oktober 2026
SELECT id, title
FROM posts
WHERE created >= '2026-10-01'
  AND created <  '2026-11-01'
ORDER BY created;
```

| title |
|-------|
| Kanelbullens dag |
| Brädspelskväll igen? |
| Halvmaran avklarad |
| Morgondimma |

⚠️ **Varning:** `BETWEEN '2026-10-01' AND '2026-10-11'` skulle missa
"Morgondimma", eftersom `'2026-10-11 06:45:00.000Z'` är *större* än texten
`'2026-10-11'`. Använd hellre "`>=` början och `<` dagen efter slutet".

⚠️ **Varning:** `NULL` betyder "okänt", och `x = NULL` ger **aldrig** någon träff
– inte ens när `x` saknar värde. Använd alltid `IS NULL` och `IS NOT NULL`. I
PocketBase är tomma textfält `''` och inte `NULL`, så där skriver du
`website = ''`. `NULL` dyker däremot upp i resultatet av en `LEFT JOIN` (2.9).

💡 **Tips:** `LIKE` skiljer inte på stora och små bokstäver i SQLite – men bara för
a–z. `'%kaffe%'` hittar alltså "Kaffe", medan `'%ö%'` inte hittar "Ö".

### ORDER BY, LIMIT och OFFSET

```sql
-- De tre senaste inläggen
SELECT id, title, created
FROM posts
ORDER BY created DESC
LIMIT 3;
```

| title | created |
|-------|---------|
| Morgondimma | 2026-10-11 06:45:00.000Z |
| Halvmaran avklarad | 2026-10-10 14:00:00.000Z |
| Brädspelskväll igen? | 2026-10-07 12:30:00.000Z |

`ASC` (stigande) är standard, `DESC` är fallande. Man kan sortera på flera
kolumner: `ORDER BY author, created DESC`.

`LIMIT` begränsar antalet rader och `OFFSET` hoppar över rader. Tillsammans ger
de **sidindelning** (*pagination*) – precis det ett flöde behöver när man
scrollar:

```sql
-- "Sida 2" med 3 inlägg per sida
SELECT id, title, created FROM posts ORDER BY created DESC LIMIT 3 OFFSET 3;
```

| title | created |
|-------|---------|
| Kanelbullens dag | 2026-10-04 08:00:00.000Z |
| Kaffe efter löprundan | 2026-09-28 08:10:00.000Z |
| Hej Kvittra! | 2026-09-25 09:00:00.000Z |

```
posts sorterade på created DESC
┌──┬──┬──┐┌──┬──┬──┐┌──┬──┬──┐┌──┐
│10│ 9│ 8││ 7│ 6│ 5││ 4│ 3│ 2││ 1│
└──┴──┴──┘└──┴──┴──┘└──┴──┴──┘└──┘
  sida 1    sida 2    sida 3   sida 4
           ↑ LIMIT 3 OFFSET 3
```

💡 **Tips:** PocketBase-API:t har precis detta inbyggt:
`/api/collections/posts/records?page=2&perPage=3&sort=-created`.

⚠️ **Varning:** Utan `ORDER BY` är ordningen på raderna **odefinierad**. Den kan
se rätt ut i dag och vara annorlunda i morgon. Använd alltid `ORDER BY`
tillsammans med `LIMIT`.

## 2.6 UPDATE – ändra data

Du har redan kört `UPDATE` – när du flyttade tillbaka inläggens datum i
[README](README.md#2d-flytta-tillbaka-tiden). Fler exempel (SQL console):

```sql
-- Eva skriver en bio
UPDATE users
SET bio = 'Ny på Kvittra!'
WHERE username = 'evaek';

-- Flera kolumner samtidigt
UPDATE posts
SET title = 'Morgondimma över ån', body = 'Uppe tidigt. Värt det!'
WHERE title = 'Morgondimma';
```

I Dashboard motsvarar det att öppna en record, ändra fälten och spara.

⚠️ **Varning:** `UPDATE` **utan** `WHERE` ändrar **alla rader** i tabellen:

```sql
UPDATE users SET bio = 'Hej!';   -- 💥 nu har ALLA samma bio
```

En bra vana: skriv först en `SELECT` med samma `WHERE` och kontrollera att du får
precis de rader du vill ändra. Byt sedan `SELECT *` mot `UPDATE ... SET ...`.

```sql
SELECT * FROM users WHERE username = 'evaek';           -- 1. kontrollera
UPDATE users SET bio = '' WHERE username = 'evaek';     -- 2. ändra (tillbaka)
```

Ändra även tillbaka inlägget:

```sql
UPDATE posts
SET title = 'Morgondimma', body = 'Uppe tidigt för att fånga dimman över ån.'
WHERE title = 'Morgondimma över ån';
```

## 2.7 DELETE – ta bort data

```sql
-- Ta bort Johans gillning av "Hej Kvittra!" från 2.4
DELETE FROM likes
WHERE created = '2026-10-12 09:00:00.000Z';

-- Ta bort de två kommentarerna från 2.4
DELETE FROM comments
WHERE body IN ('Vackert!', 'Wow!');
```

Nu är datan som den var från början.

⚠️ **Varning:** `DELETE FROM likes;` utan `WHERE` tömmer **hela tabellen**. Det
finns ingen papperskorg. Två skyddsnät: kör farliga ändringar i en transaktion så
att du kan ångra med `ROLLBACK` (kapitel 3), och ha backup.

🧪 **Prova själv – CASCADE i PocketBase:** Skapa i Dashboard en testanvändare
`testare` (lösenord `kvittra123`), ett inlägg av `testare`, en kommentar från
`anna` på inlägget och en gillning från `bertil`. Ta sedan bort `testare` i
Dashboard (öppna recorden → menyn → *Delete*). Vad hände med inlägget,
kommentaren och gillningen? Gör om samma sak men ta bort användaren i
**SQL console** med `DELETE FROM users WHERE username = 'testare';`. Vad ligger
kvar nu – och varför? (Tips: läs slutet av 2.2 igen.) Städa upp det som blev
kvar.

## 2.8 Aggregatfunktioner, GROUP BY och HAVING

**Aggregatfunktioner** räknar ihop många rader till ett värde:

| Funktion | Gör |
|----------|-----|
| `COUNT(*)` | Antal rader |
| `COUNT(kolumn)` | Antal rader där kolumnen **inte** är `NULL` |
| `SUM(kolumn)` | Summa |
| `AVG(kolumn)` | Medelvärde |
| `MIN(kolumn)`, `MAX(kolumn)` | Minsta / största värdet |

Ett aggregat utan `GROUP BY` ger **en** rad. I en View collection behöver den
raden ändå ett id – därav `ROW_NUMBER() OVER ()`:

```sql
SELECT (ROW_NUMBER() OVER ()) AS id,
       COUNT(*)            AS antal,
       SUM(bio != '')      AS med_bio,
       SUM(website != '')  AS med_webbplats
FROM users;
```

| antal | med_bio | med_webbplats |
|-------|---------|---------------|
| 6 | 4 | 2 |

(`bio != ''` är `1` när det är sant och `0` annars, så `SUM` räknar de sanna.)

```sql
SELECT (ROW_NUMBER() OVER ()) AS id,
       COUNT(*)                     AS antal,
       MIN(created)                 AS forsta,
       MAX(created)                 AS senaste,
       ROUND(AVG(length(body)), 1)  AS snittlangd
FROM posts;
```

| antal | forsta | senaste | snittlangd |
|-------|--------|---------|------------|
| 10 | 2026-09-01 08:15:00.000Z | 2026-10-11 06:45:00.000Z | 42.5 |

### GROUP BY – en sammanfattning per grupp

`GROUP BY` delar raderna i grupper och kör aggregatet per grupp:

```sql
SELECT u.id, u.username, COUNT(*) AS antal
FROM posts p
JOIN users u ON u.id = p.author
GROUP BY u.id, u.username
ORDER BY u.username;
```

| username | antal |
|----------|-------|
| anna | 2 |
| bertil | 2 |
| cissi | 3 |
| dahl | 2 |
| evaek | 1 |

```
posts                               GROUP BY författare          resultat
┌──────────────────────┬────────┐   ┌───────────────────────┐    ┌──────────┬───────┐
│ title                │ author │   │ anna:   Höstpromenad, │    │ username │ antal │
├──────────────────────┼────────┤   │         Morgondimma   │    ├──────────┼───────┤
│ Höstpromenad …       │ anna   │   ├───────────────────────┤    │ anna     │   2   │
│ Mitt första surdeg…  │ bertil │──►│ bertil: Surdeg, Kanel-│──► │ bertil   │   2   │
│ Brädspelskväll på f… │ dahl   │   │         bullens dag   │    │ cissi    │   3   │
│ Milen under 50 min…  │ cissi  │   ├───────────────────────┤    │ dahl     │   2   │
│ …                    │ …      │   │ cissi:  Milen, Kaffe, │    │ evaek    │   1   │
└──────────────────────┴────────┘   │         Halvmaran     │    └──────────┴───────┘
                                    │ …                     │
                                    └───────────────────────┘
```

Johan finns inte med – han har inga inlägg, så det finns ingen grupp för honom.
Hur man får med honom (med `0`) ser du i 2.9.

⚠️ **Varning:** Alla kolumner i `SELECT` som *inte* är aggregat bör stå i
`GROUP BY`. SQLite låter dig fuska och väljer då ett slumpmässigt värde ur
gruppen, men PostgreSQL ger ett fel – och det är PostgreSQL som har rätt.

### HAVING – filtrera grupper

`WHERE` filtrerar **rader före** grupperingen. `HAVING` filtrerar **grupper
efter** grupperingen.

```sql
-- Inlägg med minst 3 gillningar
SELECT p.id, p.title, COUNT(*) AS gillningar
FROM likes l
JOIN posts p ON p.id = l.post
GROUP BY p.id, p.title
HAVING COUNT(*) >= 3
ORDER BY gillningar DESC, p.title;
```

| title | gillningar |
|-------|------------|
| Halvmaran avklarad | 4 |
| Brädspelskväll igen? | 3 |
| Höstpromenad i Slottsskogen | 3 |

Ordningen som databasen (logiskt) utför en `SELECT` i är inte samma som du
skriver den i:

```
 1. FROM / JOIN    vilka tabeller
 2. WHERE          släng rader som inte matchar
 3. GROUP BY       bilda grupper
 4. HAVING         släng grupper som inte matchar
 5. SELECT         välj/beräkna kolumner
 6. ORDER BY       sortera
 7. LIMIT/OFFSET   klipp
```

Det förklarar till exempel varför du inte kan använda ett aggregat i `WHERE`.

## 2.9 JOIN – kombinera tabeller

Tabellen `likes` innehåller bara id:n: `post = 'x7…', user = 'k3…'`. För att
visa "anna gillar Halvmaran avklarad" måste vi **joina** in de andra tabellerna.

### INNER JOIN

`INNER JOIN` (eller bara `JOIN`) ger de rader där det finns en matchning i
**båda** tabellerna.

```sql
-- Flödet: de fem senaste inläggen med författarens användarnamn
SELECT p.id, u.username AS author, p.title, p.created
FROM posts p
INNER JOIN users u ON u.id = p.author
ORDER BY p.created DESC
LIMIT 5;
```

| author | title | created |
|--------|-------|---------|
| anna | Morgondimma | 2026-10-11 06:45:00.000Z |
| cissi | Halvmaran avklarad | 2026-10-10 14:00:00.000Z |
| dahl | Brädspelskväll igen? | 2026-10-07 12:30:00.000Z |
| bertil | Kanelbullens dag | 2026-10-04 08:00:00.000Z |
| cissi | Kaffe efter löprundan | 2026-09-28 08:10:00.000Z |

`p` och `u` är **alias** – korta namn på tabellerna så att vi slipper skriva
`posts.author`. `ON` anger hur raderna ska paras ihop: främmande nyckel =
primärnyckel.

En kopplingstabell (N:M) joinar man "genom": från `posts` via `likes` till
`users`.

```sql
-- Vilka har gillat "Halvmaran avklarad"?
SELECT l.id, u.username
FROM likes l
JOIN users u ON u.id = l.user
JOIN posts p ON p.id = l.post
WHERE p.title = 'Halvmaran avklarad'
ORDER BY u.username;
```

| username |
|----------|
| anna |
| dahl |
| evaek |
| johan |

### LEFT JOIN

`LEFT JOIN` ger **alla** rader från den vänstra tabellen, och matchande rader
från den högra om de finns. Saknas matchning fylls kolumnerna med `NULL`.

```sql
-- Senaste veckans inlägg och deras kommentarer
SELECT (ROW_NUMBER() OVER ()) AS id, p.title, c.body AS kommentar
FROM posts p
LEFT JOIN comments c ON c.post = p.id
WHERE p.created >= '2026-10-05'
ORDER BY p.created, c.created;
```

| title | kommentar |
|-------|-----------|
| Brädspelskväll igen? | Självklart! |
| Halvmaran avklarad | Wow, grattis! |
| Halvmaran avklarad | Snyggt! |
| Halvmaran avklarad | Imponerande! |
| **Morgondimma** | **NULL** |

Med `INNER JOIN` hade "Morgondimma" inte kommit med alls, eftersom ingen har
kommenterat det. Lägg märke till att ett inlägg med tre kommentarer blir **tre
rader** – därför kan `p.id` inte vara id i den här viewn, och vi använder
`ROW_NUMBER()` i stället.

⚠️ **Varning:** id-kolumnen i en View collection måste vara **unik per rad**.
Väljer du `p.id` här får "Halvmaran avklarad" samma id tre gånger, och
Dashboard visar då bara en av raderna.

Tänk på JOIN:ar som mängder:

```
     INNER JOIN                         LEFT JOIN
   ┌─────────┐                       ┌─────────┐
   │  A   ┌──┼──────┐                │█████┌───┼──────┐
   │      │██│      │                │█████│███│      │
   │      │██│   B  │                │█████│███│   B  │
   └──────┼──┘      │                └─────┼───┘      │
          └─────────┘                      └──────────┘
  bara det som matchar          allt i A + det som matchar i B
  i både A och B                (NULL där B saknas)

  A = posts, B = comments
  Morgondimma (inga kommentarer) hamnar bara i LEFT JOIN.
```

Ett klassiskt användningsfall för `LEFT JOIN` är att räkna **inklusive noll**:

```sql
-- Antal inlägg per användare, även de som inte har skrivit något
SELECT u.id, u.username, COUNT(p.id) AS antal
FROM users u
LEFT JOIN posts p ON p.author = u.id
GROUP BY u.id, u.username
ORDER BY antal DESC, u.username;
```

| username | antal |
|----------|-------|
| cissi | 3 |
| anna | 2 |
| bertil | 2 |
| dahl | 2 |
| evaek | 1 |
| johan | 0 |

Johan får `0`. Lägg märke till `COUNT(p.id)` och inte `COUNT(*)` –
`COUNT(*)` hade räknat Johans rad (med `NULL`-inlägg) som 1.

### Samma tabell två gånger

`follows` har två främmande nycklar till `users`. Vill du visa båda namnen
joinar du `users` **två gånger**, med olika alias:

```sql
-- Vilka följer cissi?
SELECT f.id, a.username AS foljare, b.username AS foljer
FROM follows f
JOIN users a ON a.id = f.follower
JOIN users b ON b.id = f.following
WHERE b.username = 'cissi'
ORDER BY a.username;
```

| foljare | foljer |
|---------|--------|
| anna | cissi |
| dahl | cissi |
| evaek | cissi |

Man kan till och med joina `follows` med *sig själv* – en **självjoin** – för att
hitta par som följer varandra. Det gör du i övning 3.1.

💡 **Tips:** Det finns även `RIGHT JOIN` och `FULL OUTER JOIN` (stöds i SQLite
från version 3.39). I praktiken klarar man sig nästan alltid med `INNER` och `LEFT`.

🧪 **Prova själv:** Skriv en fråga som visar alla användare och titeln på deras
inlägg. Använd först `INNER JOIN`, sedan `LEFT JOIN`. Hur många rader blir det i
varje fall (10 och 11)? Vem skiljer?

## 2.10 Underfrågor (subqueries)

En **underfråga** är en `SELECT` inuti en annan fråga, inom parentes.

**I `WHERE` – jämför med ett beräknat värde:**

```sql
-- Inlägg med längre text än genomsnittet
SELECT id, title, length(body) AS tecken
FROM posts
WHERE length(body) > (SELECT AVG(length(body)) FROM posts)
ORDER BY tecken DESC, title;
```

| title | tecken |
|-------|--------|
| Höstpromenad i Slottsskogen | 58 |
| Kaffe efter löprundan | 58 |
| Brädspelskväll igen? | 48 |
| Hej Kvittra! | 48 |
| Mitt första surdegsbröd | 43 |

**Med `IN` / `NOT IN` – jämför med en lista:**

```sql
-- Användare som aldrig har skrivit ett inlägg
SELECT id, username
FROM users
WHERE id NOT IN (SELECT author FROM posts);
```

Svaret blir `johan`.

**Med `EXISTS` – finns det minst en rad?**

```sql
-- Inlägg som anna har gillat
SELECT p.id, p.title
FROM posts p
WHERE EXISTS (
    SELECT 1
    FROM likes l
    JOIN users u ON u.id = l.user
    WHERE l.post = p.id
      AND u.username = 'anna'
)
ORDER BY p.created;
```

| title |
|-------|
| Mitt första surdegsbröd |
| Milen under 50 minuter! |
| Kaffe efter löprundan |
| Kanelbullens dag |
| Halvmaran avklarad |

**I `SELECT` – ett värde per rad (korrelerad underfråga):**

```sql
SELECT u.id,
       u.username,
       (SELECT COUNT(*) FROM posts p   WHERE p.author    = u.id) AS inlagg,
       (SELECT COUNT(*) FROM follows f WHERE f.following = u.id) AS foljare
FROM users u
ORDER BY foljare DESC, u.username;
```

| username | inlagg | foljare |
|----------|--------|---------|
| anna | 2 | 4 |
| cissi | 3 | 3 |
| dahl | 2 | 2 |
| bertil | 2 | 1 |
| evaek | 1 | 0 |
| johan | 0 | 0 |

En underfråga är **korrelerad** när den refererar till den yttre frågan
(`u.id`). Den körs då logiskt en gång per rad.

💡 **Tips:** Varför inte två `LEFT JOIN` i stället – en mot `posts` och en mot
`follows`? För att varje join **multiplicerar** raderna: anna har 2 inlägg och 4
följare, så hon skulle få 2 × 4 = 8 rader och `COUNT` skulle ge 8 för båda.
Underfrågor i `SELECT` (eller `COUNT(DISTINCT ...)`) undviker den fällan. Du får
prova i övning 3.5.

⚠️ **Varning:** `NOT IN` med en underfråga som kan returnera `NULL` ger tomt
resultat (på grund av hur `NULL` fungerar). `posts.author` är obligatorisk, så här
är det säkert. Hade vi valt `ON DELETE SET NULL` för författaren hade det kunnat
bli fel. Är du osäker – använd `NOT EXISTS`.

💡 **Tips:** Många underfrågor kan skrivas om som `JOIN` och tvärtom. Välj det som
är lättast att läsa.

## 2.11 Index

Utan index måste databasen läsa **varje rad** i tabellen för att hitta det du
söker (en *full table scan*). Ett **index** fungerar som registret längst bak i
en bok: en sorterad lista som pekar direkt till rätt sida.

```
Utan index: vilka gillar inlägg X?       Med index på likes(post, user)
┌─────┬──────┐                           index (sorterat)        tabell
│ A   │ anna │ ← läs                     ┌──────┬──────┐        ┌─────┬──────┐
│ X   │ dahl │ ← läs ✓                   │ A    │ anna │        │ …   │      │
│ B   │ cissi│ ← läs                     │ …    │      │        │ X   │ dahl │
│ X   │ evaek│ ← läs ✓                   │ X    │ dahl ├───────►│ …   │      │
│ …   │ …    │ ← läs … (alla rader)      │ X    │ evaek├───────►│ X   │ evaek│
└─────┴──────┘                           └──────┴──────┘        └─────┴──────┘
```

I SQL skapar man index så här:

```sql
CREATE INDEX idx_posts_author ON posts(author);

-- Sammansatt och unikt: ett villkor och ett index på samma gång
CREATE UNIQUE INDEX idx_likes_post_user ON likes(post, user);
```

I PocketBase skapade du dina index med **New index** i collection-inställningarna
(PocketBase hittar på ett namn som `idx_…`). Med `EXPLAIN QUERY PLAN` i
**SQL console** kan du se om databasen använder dem:

```sql
EXPLAIN QUERY PLAN
SELECT * FROM likes WHERE post = 'abc';
```

```text
SEARCH likes USING INDEX idx_… (post=?)
```

```sql
EXPLAIN QUERY PLAN
SELECT * FROM posts WHERE title = 'Morgondimma';
```

```text
SCAN posts
```

`SEARCH ... USING INDEX` är bra. `SCAN posts` betyder att hela tabellen läses –
vi har inget index på `title`.

Lägg märke till att det **unika** indexet på `likes(post, user)` även används när
du bara söker på `post`. Ett sammansatt index fungerar för sökningar på den
**första** kolumnen (eller de första kolumnerna), men inte för bara den andra.
Därför behövde vi ett extra index på `likes(user)` ("vilka inlägg har anna
gillat?") och på `follows(following)` ("vilka följer anna?").

**När ska man skapa ett index?**

| Skapa index på … | Exempel i Kvittra |
|------------------|-------------------|
| Främmande nycklar | `posts(author)`, `comments(post)`, `likes(user)`, `follows(following)` |
| Kolumner du ofta filtrerar på i `WHERE` | `posts(created)` för "senaste veckan" |
| Kolumner du ofta sorterar på | `posts(created)` för flödet |
| Kolumner som ska vara unika | `users(username)`, `likes(post, user)` |

**Men inte överallt:** varje index tar plats och gör `INSERT`, `UPDATE` och
`DELETE` lite långsammare, eftersom indexet också måste uppdateras. På små
tabeller (några hundra rader) märks ingen skillnad alls.

💡 **Tips:** Primärnyckeln är alltid indexerad automatiskt.

## 2.12 Vyer (views)

En **vy** är en sparad `SELECT` som du kan fråga som om den vore en tabell. Den
lagrar ingen egen data – frågan körs varje gång. I SQL:

```sql
CREATE VIEW feed AS
SELECT ...;

SELECT * FROM feed WHERE viewer = 'anna';
```

En **View collection** i PocketBase är exakt det: PocketBase skapar en SQL-vy av
din fråga, och du kan bläddra i den, filtrera den och hämta den via API:t som en
vanlig collection.

Prova att skapa en View collection som heter `feed`: varje rad är "ett inlägg som
`viewer` ser i sitt flöde", alltså inlägg från personer som `viewer` följer.

```sql
SELECT (ROW_NUMBER() OVER ()) AS id,
       v.username AS viewer,
       a.username AS author,
       p.title,
       p.created
FROM follows f
JOIN users v ON v.id = f.follower
JOIN posts p ON p.author = f.following
JOIN users a ON a.id = p.author
ORDER BY p.created DESC
```

Öppna sedan `feed` och skriv `viewer = 'anna'` i sökfältet ovanför raderna. Du
ser Annas flöde: fem inlägg från bertil och cissi.

Vyer är bra för att ge ett enkelt namn åt en krånglig fråga som används ofta.
I modul 02 ser du hur man kan styra *vem* som får läsa en View collection med
API-regler.

💡 **Tips:** Ett id från `ROW_NUMBER()` är bara ett radnummer – det kan ändras när
datan ändras. Det duger för att titta på datan, men vill du länka till en viss rad
i en app behöver du ett stabilt id (t.ex. `p.id` när varje inlägg bara förekommer
en gång).

## Sammanfattning

| Vill du … | Använd | I PocketBase |
|-----------|--------|--------------|
| skapa/ändra/ta bort en tabell | `CREATE TABLE`, `ALTER TABLE`, `DROP TABLE` | New collection, New field, Delete collection |
| skydda datan | `NOT NULL`, `UNIQUE`, `CHECK`, `DEFAULT`, `PRIMARY KEY`, `REFERENCES ... ON DELETE` | Required, unikt index, Relation + Cascade delete, API-regler |
| lägga in / ändra / ta bort rader | `INSERT`, `UPDATE ... WHERE`, `DELETE ... WHERE` | New record, redigera, Delete (eller SQL console) |
| läsa | `SELECT ... FROM ... WHERE ... ORDER BY ... LIMIT` | View collection |
| sammanfatta | `COUNT`, `SUM`, `AVG`, `MIN`, `MAX`, `GROUP BY`, `HAVING` | View collection |
| kombinera tabeller | `INNER JOIN`, `LEFT JOIN` | View collection |
| fråga i frågan | underfrågor med `IN`, `EXISTS` eller i `SELECT` | View collection |
| snabba upp sökningar | `CREATE INDEX` | New index |
| spara en fråga | `CREATE VIEW` | View collection |

Nästa kapitel: [Kapitel 3 – ACID och transaktioner](03-acid-och-transaktioner.md)

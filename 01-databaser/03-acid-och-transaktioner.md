# Kapitel 3 – ACID och transaktioner

> **Mål med kapitlet:** Du ska förstå vad en transaktion är och kunna använda
> `BEGIN`, `COMMIT` och `ROLLBACK`. Du ska kunna förklara de fyra bokstäverna i
> ACID med konkreta exempel, känna igen vanliga samtidighetsproblem och veta hur
> SQLite och PocketBase hanterar dem.

## 3.1 Problemet: saker som måste hända tillsammans

Föreningen vill kunna flytta en bokning från tvättstuga 1 till tvättstuga 2,
och samtidigt logga att det hänt. Eller tänk på det klassiska bankexemplet:
Anna swishar 500 kr till föreningen för en festlokalsbokning.

```
1.  UPDATE accounts SET balance = balance - 500 WHERE owner = 'Anna';
2.  UPDATE accounts SET balance = balance + 500 WHERE owner = 'Föreningen';
```

Vad händer om strömmen går **mellan** rad 1 och rad 2?

```
  Anna: 2000 kr                 Anna: 1500 kr                Anna: 1500 kr
  Föreningen: 10000 kr  ──1──►  Föreningen: 10000 kr  ──⚡──► Föreningen: 10000 kr
                                                              500 kr har försvunnit!
```

Pengarna har lämnat Annas konto men aldrig kommit fram. Vi behöver ett sätt att
säga: **"antingen händer båda sakerna, eller ingen av dem"**. Det är vad en
transaktion är.

## 3.2 Transaktioner: BEGIN, COMMIT, ROLLBACK

En **transaktion** är en grupp av SQL-satser som databasen behandlar som en
enda odelbar enhet.

| Kommando | Betyder |
|----------|---------|
| `BEGIN;` (eller `BEGIN TRANSACTION;`) | Starta en transaktion |
| `COMMIT;` | Spara alla ändringar permanent |
| `ROLLBACK;` | Ångra **alla** ändringar sedan `BEGIN` |

För att kunna köra bankexemplet behöver vi en liten extratabell. Den hör inte
till Föreningsappen, så vi skapar den bara för att leka:

```sql
CREATE TABLE IF NOT EXISTS accounts (
    id       INTEGER PRIMARY KEY,
    owner    TEXT    NOT NULL UNIQUE,
    balance  INTEGER NOT NULL CHECK (balance >= 0)   -- i öre, aldrig negativt
);
DELETE FROM accounts;
INSERT INTO accounts (owner, balance) VALUES
    ('Anna', 200000),          -- 2 000 kr
    ('Föreningen', 1000000);   -- 10 000 kr
```

En lyckad överföring:

```sql
BEGIN;
UPDATE accounts SET balance = balance - 50000 WHERE owner = 'Anna';
UPDATE accounts SET balance = balance + 50000 WHERE owner = 'Föreningen';
COMMIT;

SELECT owner, balance / 100.0 AS kronor FROM accounts;
```

| owner | kronor |
|-------|--------|
| Anna | 1500.0 |
| Föreningen | 10500.0 |

En överföring vi ångrar:

```sql
BEGIN;
UPDATE accounts SET balance = balance - 50000 WHERE owner = 'Anna';
-- Hoppsan, fel mottagare. Ångra allt!
ROLLBACK;

SELECT owner, balance / 100.0 AS kronor FROM accounts;   -- Anna har fortfarande 1500
```

```
     BEGIN                                       COMMIT
       │  ┌─────────┐  ┌─────────┐  ┌─────────┐    │
 ──────┼─►│ UPDATE  │─►│ UPDATE  │─►│ INSERT  │────┼──► allt sparas
       │  └─────────┘  └─────────┘  └─────────┘    │
       │                                           │
       │        fel / krasch / ROLLBACK            │
       └───────────────────────────────────────────┴──► ingenting sparas
```

💡 **Tips:** Varje enskild SQL-sats som du kör *utanför* `BEGIN ... COMMIT` är
automatiskt en egen liten transaktion (*autocommit*). Ett `UPDATE` som ändrar
100 rader ändrar alltså alla 100 eller ingen.

🧪 **Prova själv:** Kör `BEGIN;`, sedan `DELETE FROM bookings;` och
`SELECT COUNT(*) FROM bookings;` (0 rader!). Kör `ROLLBACK;` och räkna igen.
Det här är ett utmärkt säkerhetsnät innan du kör farliga `UPDATE`/`DELETE`.

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

**Exempel i Föreningsappen:** När styrelsen tar bort festlokalen ur bokningssystemet
vill de flytta alla framtida bokningar till en ny lokal och skicka ett anslag om
det. Om anslaget misslyckas ska bokningarna inte vara flyttade, och tvärtom.

```sql
PRAGMA foreign_keys = ON;
BEGIN;
INSERT INTO resources (name, description, max_hours)
VALUES ('Nya festlokalen', 'Hus B, plan 0.', 12);

UPDATE bookings
SET resource = (SELECT id FROM resources WHERE name = 'Nya festlokalen')
WHERE resource = (SELECT id FROM resources WHERE name = 'Festlokalen');

INSERT INTO posts (title, body, author, published)
VALUES ('Festlokalen flyttar', 'Alla bokningar är flyttade till hus B.', 1, 1);
COMMIT;
```

Om något av stegen misslyckas – eller datorn kraschar mitt i – gör man
`ROLLBACK` (och efter en krasch gör databasen det automatiskt när den startar
igen). Resultatet blir aldrig "halvflyttat".

### C – Konsistens: reglerna gäller alltid

En transaktion tar databasen från ett **giltigt** tillstånd till ett annat
giltigt tillstånd. "Giltigt" betyder att alla regler du definierat håller:
`NOT NULL`, `UNIQUE`, `CHECK`, främmande nycklar.

**Exempel:** `accounts.balance` har `CHECK (balance >= 0)`. Anna har 1 500 kr och
försöker föra över 5 000 kr:

```sql
BEGIN;
UPDATE accounts SET balance = balance - 500000 WHERE owner = 'Anna';
-- Error: CHECK constraint failed: balance >= 0
ROLLBACK;
```

Databasen vägrar ändringen. I Föreningsappen skyddar `CHECK ("end" > "start")` på
samma sätt mot bokningar som slutar innan de börjar, och den främmande nyckeln
mot bokningar av resurser som inte finns.

⚠️ **Varning:** Konsistens i ACID betyder bara att **de regler du har skrivit**
följs. Om du glömmer `CHECK (balance >= 0)` kan saldot bli negativt utan att
databasen bryr sig. Regler som "en tvättstuga får bara bokas 3 timmar" måste du
antingen uttrycka som villkor, triggers eller kontrollera i backend-koden.

### I – Isolering: samtidiga transaktioner stör inte varandra

Många användare använder appen samtidigt. **Isolering** betyder att varje
transaktion ska bete sig *som om* den vore ensam i databasen.

**Exempel: två medlemmar bokar samma tvättid.** Klockan 07:59:59 trycker både
Bertil och Eva på "Boka" för tvättstuga 1 den 20 oktober kl 07–10. Appen gör så här:

```
1. Kolla om tiden är ledig:  SELECT COUNT(*) FROM bookings WHERE resource = 1 AND ...
2. Om 0 → boka:              INSERT INTO bookings ...
```

Utan isolering kan det gå så här:

```
 tid   Bertil                              Eva
 ───   ──────────────────────────────      ──────────────────────────────
  1    SELECT ... → 0 (ledigt!)
  2                                        SELECT ... → 0 (ledigt!)
  3    INSERT bokning
  4                                        INSERT bokning
  5    ✓ "Du har bokat!"                   ✓ "Du har bokat!"

       → Två bokningar på samma tid. Konflikt i tvättstugan.
```

Båda såg att tiden var ledig, eftersom ingen av dem hade hunnit boka än. Det här
kallas ett **race condition** (kapplöpning). Lösningar:

1. **Låt databasen avgöra med ett villkor.** Ett unikt index gör det omöjligt att
   spara två bokningar med samma resurs och starttid – den andra `INSERT`:en
   misslyckas, oavsett timing:

   ```sql
   CREATE UNIQUE INDEX IF NOT EXISTS idx_bookings_unique_slot
   ON bookings(resource, "start");
   ```

   (Det fungerar när alla pass har fasta starttider, som 07, 10, 13 … Överlappande
   fria tider kräver en kontroll i en transaktion, se punkt 2.)

2. **Gör kontroll + insättning i samma skrivtransaktion.** I SQLite startar
   `BEGIN IMMEDIATE` en transaktion som direkt tar skrivlåset, så ingen annan kan
   skriva mellan din kontroll och din insättning:

   ```sql
   BEGIN IMMEDIATE;
   SELECT COUNT(*) FROM bookings
   WHERE resource = 1
     AND "start" < '2026-10-20 10:00:00'   -- befintlig börjar före min slut
     AND "end"   > '2026-10-20 07:00:00';  -- och slutar efter min start
   -- appen ser 0 → det är ledigt
   INSERT INTO bookings (resource, user, "start", "end")
   VALUES (1, 2, '2026-10-20 07:00:00', '2026-10-20 10:00:00');
   COMMIT;
   ```

   Om Eva försöker samtidigt får hon vänta (eller felet `database is locked`) tills
   Bertil är klar – och när hon väl får göra sin `SELECT` ser hon Bertils bokning.

💡 **Tips:** Villkoret för att två tidsintervall **överlappar** är
`a.start < b.end AND a.end > b.start`. Lär dig det utantill – det behövs i
varje bokningssystem.

### D – Beständighet: sparat är sparat

När databasen har sagt "COMMIT klart" ska ändringen **finnas kvar**, även om
strömmen går en millisekund senare, servern kraschar eller appen stängs.

**Exempel:** Anna bokar festlokalen och får "Bokning bekräftad". Sekunden efter
startar servern om. När den är igång igen måste bokningen finnas där.

Databasen åstadkommer det genom att skriva ändringen till en **logg på disken**
(och be operativsystemet att verkligen skriva till disken, `fsync`) *innan* den
svarar "klart". Efter en krasch läser den loggen och:

- ändringar från transaktioner som hann bli `COMMIT`:ade → behålls,
- ändringar från transaktioner som inte hann bli klara → kastas.

Det är så atomicitet och beständighet samarbetar efter en krasch:

```
  BEGIN ── UPDATE Anna ── UPDATE Föreningen ── COMMIT ✓ ── ⚡ krasch
                                                        → båda ändringarna finns kvar (D)

  BEGIN ── UPDATE Anna ── ⚡ krasch
                          → Annas ändring rullas tillbaka vid omstart (A)
```

## 3.4 Isoleringsproblem

Perfekt isolering är dyrt: transaktioner skulle i princip behöva köras en i taget.
Därför låter många databaser dig välja en lägre nivå som tillåter vissa
problem i utbyte mot bättre prestanda. Här är de klassiska problemen:

### Dirty read – läsa ej sparad data

Transaktion B läser något som A har skrivit men **inte** committat. Sedan gör A
`ROLLBACK`. B har då agerat på data som aldrig funnits.

```
 A: UPDATE resources SET active = 0 WHERE id = 1;     (inte committat)
 B: SELECT active FROM resources WHERE id = 1;  → 0   "Tvättstugan är stängd"
 A: ROLLBACK;                                         (den var aldrig stängd)
```

### Non-repeatable read – samma fråga, olika svar

B läser en rad två gånger inom samma transaktion, och A hinner ändra och
committa raden emellan.

```
 B: SELECT max_hours FROM resources WHERE id = 3;  → 12
 A: UPDATE resources SET max_hours = 6 WHERE id = 3; COMMIT;
 B: SELECT max_hours FROM resources WHERE id = 3;  → 6   (?!)
```

### Phantom read – nya rader dyker upp

B räknar rader som matchar ett villkor två gånger, och A hinner **lägga till**
en rad som matchar emellan.

```
 B: SELECT COUNT(*) FROM bookings WHERE resource = 1 AND "start" LIKE '2026-10-20%';  → 0
 A: INSERT INTO bookings (... resource 1, 2026-10-20 07:00 ...); COMMIT;
 B: SELECT COUNT(*) ... → 1   (en "spökrad")
```

Dubbelbokningen i avsnitt 3.3 är i grunden ett fantomproblem.

### Lost update – en uppdatering försvinner

Två transaktioner läser samma värde, räknar fram ett nytt, och skriver tillbaka.
Den sista skriver över den förstas ändring.

```
 Räknare: "antal lediga parkeringsplatser" = 5

 A: läser 5                         B: läser 5
 A: skriver 5 - 1 = 4               B: skriver 5 - 1 = 4
                                    → borde vara 3!
```

Lösningen är ofta att låta databasen räkna i en enda sats i stället för att läsa
till appen och skriva tillbaka:

```sql
-- Dåligt (läs i appen, räkna, skriv tillbaka): risk för lost update
-- Bra: en atomär sats
UPDATE accounts SET balance = balance - 100 WHERE owner = 'Anna';
```

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
**dubbelbokning**, som är vanliga buggar i riktiga appar.

## 3.5 SQLite i praktiken

SQLite är enklare än serverdatabaser på ett sätt som gör isolering lättare:

- **Bara en skrivare åt gången.** Hela databasen låses när någon skriver. Två
  transaktioner kan alltså aldrig skriva samtidigt. Det gör att SQLite i praktiken
  ger **Serializable**-isolering.
- **Många läsare samtidigt** – särskilt i WAL-läge (se nedan).
- Om en skrivare måste vänta för länge får den felet `SQLITE_BUSY` /
  `database is locked`. Man brukar därför sätta en *busy timeout* så att den väntar
  en stund i stället för att ge upp direkt.

### Transaktionstyper i SQLite

| Kommando | När tas skrivlåset? |
|----------|---------------------|
| `BEGIN` / `BEGIN DEFERRED` | Först när transaktionen gör sin första skrivning |
| `BEGIN IMMEDIATE` | Direkt. Bra när du ska läsa-och-sedan-skriva (som bokningskontrollen) |
| `BEGIN EXCLUSIVE` | Direkt, och blockerar även läsare (i icke-WAL-läge) |

### WAL – Write-Ahead Logging

Som standard skriver SQLite ändringar direkt i databasfilen och sparar en kopia
av det gamla innehållet i en *rollback journal*. I **WAL-läge** gör den tvärtom:
nya ändringar skrivs först till en separat loggfil (`forening.db-wal`), och flyttas
in i huvudfilen senare (en *checkpoint*).

```
             Rollback journal (standard)              WAL-läge
           ┌───────────────────────────────┐     ┌───────────────────────────────┐
 skrivare  │ skriver i forening.db,        │     │ lägger till i forening.db-wal │
           │ läsare måste vänta            │     │ läsare läser forening.db      │
           │                               │     │ + det committade i WAL        │
           └───────────────────────────────┘     └───────────────────────────────┘
                                                  → läsare och skrivare blockerar
                                                    inte varandra
```

```sql
PRAGMA journal_mode = WAL;   -- slå på (sparas i filen, gäller sedan alltid)
PRAGMA journal_mode;         -- visa nuvarande läge
PRAGMA busy_timeout = 5000;  -- vänta upp till 5 s på lås i stället för att ge fel
```

Fördelar med WAL: läsare blockeras inte av skrivare, och skrivningar blir ofta
snabbare. Det är därför **PocketBase alltid kör SQLite i WAL-läge**. Om du tittar
i `pb_data/` ser du filerna `data.db`, `data.db-wal` och `data.db-shm`.

⚠️ **Varning:** Kopiera aldrig bara `data.db` som backup medan PocketBase kör –
de senaste ändringarna kan ligga kvar i `-wal`-filen. Använd PocketBase inbyggda
backup-funktion eller kommandot `.backup` i `sqlite3`.

## 3.6 Transaktioner i PocketBase

PocketBase sköter transaktioner åt dig vid vanliga API-anrop: att skapa en
record är en egen transaktion. Men när du skriver **hooks** (serverkod i
JavaScript, modul 02) och vill göra flera ändringar som hör ihop, använder du
`$app.runInTransaction`:

```javascript
// pb_hooks/move_bookings.pb.js (förenklat exempel)
$app.runInTransaction((txApp) => {
    const oldRes = txApp.findFirstRecordByData("resources", "name", "Festlokalen");
    const newRes = txApp.findFirstRecordByData("resources", "name", "Nya festlokalen");

    const bookings = txApp.findRecordsByFilter(
        "bookings", "resource = {:id}", "", 0, 0, { id: oldRes.id });

    for (const b of bookings) {
        b.set("resource", newRes.id);
        txApp.save(b);          // använd txApp, inte $app, inuti transaktionen!
    }
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

För dubbelbokningsproblemet i PocketBase använder man typiskt ett **unikt index**
på collectionen (`resource` + `start`) eller en hook som kontrollerar överlapp
innan en bokning sparas. Det gör vi i modul 02.

## 3.7 Sammanfattning

- En **transaktion** grupperar satser: `BEGIN` … `COMMIT` sparar allt, `ROLLBACK`
  ångrar allt.
- **A**tomicitet: allt eller inget. **C**onsistency: villkoren gäller alltid.
  **I**solering: samtidiga transaktioner stör inte varandra. **D**urability: det
  committade finns kvar efter en krasch.
- Klassiska samtidighetsproblem: dirty read, non-repeatable read, phantom read och
  lost update. Dubbelbokning är ett exempel på ett race condition.
- Skydda dig med **villkor/unika index** och genom att göra kontroll + skrivning i
  **samma transaktion**.
- **SQLite** har en skrivare åt gången och kör i praktiken serialiserbart.
  **WAL** låter läsare och skrivare arbeta samtidigt. PocketBase använder WAL.
- I PocketBase-hooks använder du `$app.runInTransaction((txApp) => ...)`.

## Kontrollfrågor

1. Vad händer med ändringarna om du kör `BEGIN`, två `UPDATE` och sedan stänger
   `sqlite3` utan `COMMIT`?
2. Vilken ACID-egenskap bryts om en överföring drar pengar från ett konto men
   aldrig sätter in dem på det andra?
3. Varför räcker det inte att appen först kollar om en tid är ledig och sedan
   bokar?
4. Vad är skillnaden mellan `BEGIN` och `BEGIN IMMEDIATE` i SQLite?
5. Vilka tre filer hittar du i `pb_data/` för databasen och varför?

Nästa kapitel: [Kapitel 4 – Databasdesign](04-databasdesign.md)

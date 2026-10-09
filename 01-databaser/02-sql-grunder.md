# Kapitel 2 – SQL-grunder

> **Mål med kapitlet:** Du ska kunna skapa tabeller med datatyper och villkor,
> lägga in, läsa, ändra och ta bort data, sammanfatta data med aggregat och
> `GROUP BY`, kombinera tabeller med `JOIN` och underfrågor, samt förstå när ett
> index behövs.

Alla exempel körs mot exempeldatabasen. Skapa den först (se [modulens
README](README.md)):

```bash
sqlite3 forening.db < seed.sql
sqlite3 forening.db
```

och kör sedan i `sqlite3`:

```text
.headers on
.mode box
PRAGMA foreign_keys = ON;
```

Hela seed-skriptet finns också längst ner i det här kapitlet, i
[avsnitt 2.13](#213-hela-seed-skriptet).

## 2.1 Vad är SQL?

SQL (*Structured Query Language*) är ett **deklarativt** språk. Det betyder att
du beskriver **vad** du vill ha – inte **hur** datorn ska ta fram det.

Jämför med hur du skulle hitta styrelsemedlemmar i ett vanligt program:

```python
# Imperativt (Python): du beskriver HUR – loopa, jämför, samla ihop
result = []
for user in users:
    if user.role == "board":
        result.append((user.name, user.email))
```

```sql
-- Deklarativt (SQL): du beskriver VAD
SELECT name, email FROM users WHERE role = 'board';
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

Några skrivregler:

- Nyckelord som `SELECT` är inte skiftlägeskänsliga, men man skriver dem ofta
  med VERSALER för att de ska synas.
- Text skrivs inom **enkla citattecken**: `'board'`. Dubbla citattecken används
  för **namn** på tabeller och kolumner: `"end"`.
- Varje sats avslutas med semikolon `;`.
- Kommentarer: `-- resten av raden` eller `/* flera rader */`.

⚠️ **Varning:** Kolumnerna `start` och `end` i `bookings` har namn som är
reserverade ord i SQL. SQLite är snäll och accepterar ofta `start` utan citat,
men `end` kräver nästan alltid citattecken. Därför skriver vi alltid `"start"`
och `"end"` i det här materialet. (PocketBase sköter det automatiskt åt dig.)

## 2.2 CREATE TABLE – datatyper

En tabell skapas med `CREATE TABLE`. Varje kolumn får ett namn, en datatyp och
eventuella villkor.

```sql
CREATE TABLE demo_resources (
    id         INTEGER PRIMARY KEY,
    name       TEXT    NOT NULL,
    max_hours  INTEGER
);
```

SQLite har fem lagringsklasser. Andra databaser har fler typer, men de mappar
ungefär så här:

| SQLite | Innehåll | PostgreSQL-motsvarighet | Exempel i Föreningsappen |
|--------|----------|-------------------------|--------------------------|
| `INTEGER` | Heltal | `integer`, `bigint` | `floor`, `max_hours`, id:n |
| `REAL` | Decimaltal (flyttal) | `double precision` | `size_sqm` |
| `TEXT` | Text | `text`, `varchar(n)` | `name`, `email`, datum |
| `BLOB` | Binärdata | `bytea` | (bilder – men lagra hellre som fil) |
| `NULL` | "Inget värde" | `NULL` | `note` om ingen anteckning |

SQLite har ingen egen `BOOLEAN`- eller `DATETIME`-typ. Vi använder:

- **boolean** → `INTEGER` med `0` (falskt) och `1` (sant), t.ex. `active`,
- **datum och tid** → `TEXT` i ISO 8601-format, t.ex. `'2026-10-12 07:00:00'`.

Varför fungerar text för datum? För att formatet `YYYY-MM-DD HH:MM:SS` sorteras
korrekt i bokstavsordning: `'2026-09-30' < '2026-10-12'`. Mer om datum i
[kapitel 4](04-databasdesign.md).

## 2.3 Villkor (constraints)

Villkor är regler som databasen *vägrar* bryta. De är ditt viktigaste skydd mot
felaktig data – oavsett om felet kommer från en bugg i appen, en
adminanvändare eller ett skript.

| Villkor | Betyder | Exempel |
|---------|---------|---------|
| `PRIMARY KEY` | Unik identifierare för raden | `id INTEGER PRIMARY KEY` |
| `NOT NULL` | Värde måste finnas | `name TEXT NOT NULL` |
| `UNIQUE` | Inga dubbletter i kolumnen | `email TEXT NOT NULL UNIQUE` |
| `CHECK (...)` | Ett eget villkor som måste vara sant | `CHECK (floor >= 0)` |
| `DEFAULT ...` | Värde om inget anges | `role TEXT DEFAULT 'member'` |
| `REFERENCES t(kol)` | Främmande nyckel | `user INTEGER REFERENCES users(id)` |

Så här ser `users` och `bookings` ut i seed-skriptet (tabellerna finns redan om
du har kört `seed.sql`, så den här koden är bara till för att läsa):

```sql
CREATE TABLE users (
    id         INTEGER PRIMARY KEY,
    email      TEXT    NOT NULL UNIQUE,
    name       TEXT    NOT NULL,
    apartment  INTEGER REFERENCES apartments(id) ON DELETE SET NULL,
    role       TEXT    NOT NULL DEFAULT 'member'
                       CHECK (role IN ('member', 'board', 'admin')),
    created    TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE bookings (
    id        INTEGER PRIMARY KEY,
    resource  INTEGER NOT NULL REFERENCES resources(id) ON DELETE CASCADE,
    user      INTEGER NOT NULL REFERENCES users(id)     ON DELETE CASCADE,
    "start"   TEXT    NOT NULL,
    "end"     TEXT    NOT NULL,
    note      TEXT,
    CHECK ("end" > "start")
);
```

Lägg märke till `CHECK ("end" > "start")`: ett villkor som gäller *flera*
kolumner skrivs som ett **tabellvillkor** efter kolumnerna.

### Främmande nycklar och ON DELETE

Vad ska hända med bokningarna om en medlem tas bort? Det bestämmer du med
`ON DELETE`:

| Regel | Vad händer med raderna som pekar på den borttagna raden? | Används i seed för |
|-------|----------------------------------------------------------|--------------------|
| `RESTRICT` / `NO ACTION` (standard) | Borttagningen **nekas** så länge det finns referenser | – |
| `CASCADE` | Raderna tas **också bort** | `bookings.user`, `bookings.resource` |
| `SET NULL` | Den främmande nyckeln sätts till `NULL` | `users.apartment`, `posts.author` |
| `SET DEFAULT` | Sätts till kolumnens standardvärde | – |

```
DELETE FROM users WHERE id = 2;

  users           bookings (user = 2)        posts (author = 2)
  ┌────┐  CASCADE  ┌──────────────┐ SET NULL ┌──────────────┐
  │ 2  │ ────────► │ tas bort     │          │ author = NULL│
  └────┘           └──────────────┘          └──────────────┘
```

Tanken: en bokning utan medlem är meningslös – ta bort den. Ett anslag är
fortfarande intressant även om författaren flyttat – behåll det men nollställ
författaren.

⚠️ **Varning:** I SQLite är kontroll av främmande nycklar **avstängd** som
standard. Kör alltid `PRAGMA foreign_keys = ON;` i början av varje session,
annars kan du lägga in `user = 999` utan att få fel. (PocketBase slår på det åt dig.)

🧪 **Prova själv:** Testa att villkoren verkligen skyddar. Varje sats nedan ska ge
ett fel. Läs felmeddelandet och fundera på vilket villkor som slog till.

```sql
PRAGMA foreign_keys = ON;
INSERT INTO users (email, name) VALUES ('anna@example.com', 'Anna 2');      -- UNIQUE
INSERT INTO users (email, name, role) VALUES ('x@example.com', 'X', 'king'); -- CHECK
INSERT INTO apartments (number, floor, size_sqm) VALUES ('1401', 4, NULL);  -- NOT NULL
INSERT INTO bookings (resource, user, "start", "end")
VALUES (1, 999, '2026-10-20 07:00:00', '2026-10-20 10:00:00');              -- FOREIGN KEY
INSERT INTO bookings (resource, user, "start", "end")
VALUES (1, 1, '2026-10-20 10:00:00', '2026-10-20 07:00:00');                -- CHECK end > start
```

### ALTER TABLE och DROP TABLE

```sql
-- Lägg till en kolumn i efterhand
ALTER TABLE resources ADD COLUMN location TEXT;

-- Byt namn på en kolumn
ALTER TABLE resources RENAME COLUMN location TO building;

-- Ta bort kolumnen igen (SQLite 3.35+)
ALTER TABLE resources DROP COLUMN building;

-- Ta bort en hel tabell (och all data!)
DROP TABLE IF EXISTS demo_resources;
```

## 2.4 INSERT – lägga in data

```sql
-- Ange kolumnerna explicit (rekommenderas)
INSERT INTO resources (name, description, max_hours)
VALUES ('Gästlägenheten', 'Två bäddar, plan 3.', 24);
```

Vi angav inte `id` eller `active`. `id` får automatiskt nästa lediga nummer och
`active` får sitt `DEFAULT 1`. Se resultatet:

```sql
SELECT * FROM resources WHERE name = 'Gästlägenheten';
```

| id | name | description | max_hours | active |
|----|------|-------------|-----------|--------|
| 5 | Gästlägenheten | Två bäddar, plan 3. | 24 | 1 |

Flera rader i en sats:

```sql
INSERT INTO apartments (number, floor, size_sqm) VALUES
    ('1401', 4, 55.0),
    ('1402', 4, 79.5);
```

💡 **Tips:** Skriv alltid ut kolumnnamnen i `INSERT`. Då fungerar satsen även om
någon lägger till en kolumn i tabellen senare, och det syns vad varje värde är.

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
SELECT * FROM users;                      -- alla kolumner (bra för att titta)
SELECT name, email FROM users;            -- bara vissa kolumner
SELECT name AS namn, email AS epost FROM users;  -- byt namn på kolumner i svaret
SELECT number, size_sqm * 10.764 AS size_sqft FROM apartments;  -- beräknade kolumner
SELECT DISTINCT role FROM users;          -- unika värden
```

### WHERE – filtrera rader

```sql
SELECT name, email FROM users WHERE role = 'board';
```

| name | email |
|------|-------|
| Anna Andersson | anna@example.com |
| David Dahl | david@example.com |

Vanliga operatorer i `WHERE`:

| Operator | Exempel | Betyder |
|----------|---------|---------|
| `=`, `<>` (eller `!=`) | `role = 'board'` | lika med / inte lika med |
| `<`, `<=`, `>`, `>=` | `size_sqm > 60` | jämförelse |
| `AND`, `OR`, `NOT` | `floor = 1 AND size_sqm > 50` | kombinera villkor |
| `IN (...)` | `role IN ('board', 'admin')` | något av värdena |
| `BETWEEN a AND b` | `floor BETWEEN 1 AND 2` | inom intervall (inklusive gränserna) |
| `LIKE` | `email LIKE '%@example.com'` | mönster: `%` = valfri text, `_` = ett tecken |
| `IS NULL`, `IS NOT NULL` | `apartment IS NULL` | saknar värde / har värde |

```sql
-- Bokningar på tvättstuga 1 under den 12 oktober
SELECT id, user, "start", "end"
FROM bookings
WHERE resource = 1
  AND "start" >= '2026-10-12 00:00:00'
  AND "start" <  '2026-10-13 00:00:00';

-- Medlemmar utan lägenhet
SELECT name FROM users WHERE apartment IS NULL;
```

⚠️ **Varning:** `WHERE apartment = NULL` ger **aldrig** någon träff! `NULL`
betyder "okänt", och "okänt = okänt" är inte sant utan också okänt. Använd alltid
`IS NULL` och `IS NOT NULL`.

### ORDER BY, LIMIT och OFFSET

```sql
-- Lägenheter större än 60 kvm, största först
SELECT number, floor, size_sqm
FROM apartments
WHERE size_sqm > 60
ORDER BY size_sqm DESC;
```

| number | floor | size_sqm |
|--------|-------|----------|
| 1301 | 3 | 104.0 |
| 1202 | 2 | 88.0 |
| 1101 | 1 | 72.0 |
| 1201 | 2 | 72.0 |
| 1302 | 3 | 61.0 |

`ASC` (stigande) är standard, `DESC` är fallande. Man kan sortera på flera
kolumner: `ORDER BY floor ASC, number ASC`.

`LIMIT` begränsar antalet rader och `OFFSET` hoppar över rader. Tillsammans ger
de **sidindelning** (*pagination*):

```sql
-- De tre senast registrerade medlemmarna
SELECT name, created FROM users ORDER BY created DESC LIMIT 3;

-- "Sida 2" med 4 anslag per sida
SELECT id, title FROM posts ORDER BY created DESC LIMIT 4 OFFSET 4;
```

```
posts sorterade på created DESC
┌──┬──┬──┬──┐┌──┬──┐
│6 │5 │4 │3 ││2 │1 │
└──┴──┴──┴──┘└──┴──┘
   sida 1       sida 2  ← LIMIT 4 OFFSET 4
```

💡 **Tips:** PocketBase API:et har precis detta inbyggt: `?page=2&perPage=4&sort=-created`.

⚠️ **Varning:** Utan `ORDER BY` är ordningen på raderna **odefinierad**. Den kan
se rätt ut i dag och vara annorlunda i morgon. Använd alltid `ORDER BY`
tillsammans med `LIMIT`.

## 2.6 UPDATE – ändra data

```sql
-- Anteckning på bokning 5
UPDATE bookings
SET note = 'Tar med eget tvättmedel'
WHERE id = 5;

-- Flera kolumner samtidigt
UPDATE resources
SET active = 1, description = 'Nyrenoverad!'
WHERE name = 'Bastun';
```

⚠️ **Varning:** `UPDATE` **utan** `WHERE` ändrar **alla rader** i tabellen:

```sql
UPDATE users SET role = 'admin';   -- 💥 nu är ALLA administratörer
```

En bra vana: skriv först en `SELECT` med samma `WHERE` och kontrollera att du får
precis de rader du vill ändra. Byt sedan `SELECT *` mot `UPDATE ... SET ...`.

```sql
SELECT * FROM bookings WHERE id = 5;          -- 1. kontrollera
UPDATE bookings SET note = NULL WHERE id = 5;  -- 2. ändra
```

## 2.7 DELETE – ta bort data

```sql
-- Ta bort en bokning
DELETE FROM bookings WHERE id = 15;

-- Ta bort alla gamla bokningar
DELETE FROM bookings WHERE "end" < '2026-10-01 00:00:00';
```

⚠️ **Varning:** `DELETE FROM bookings;` utan `WHERE` tömmer **hela tabellen**.
Det finns ingen papperskorg. Två skyddsnät: kör farliga ändringar i en
transaktion så att du kan ångra med `ROLLBACK` (kapitel 3), och ha backup.

🧪 **Prova själv:** Kör `PRAGMA foreign_keys = ON;` och sedan
`DELETE FROM users WHERE id = 7;` (Gunilla). Hur många bokningar finns kvar? Vad
står det i `author` på hennes anslag? Kör `sqlite3 forening.db < seed.sql` för
att återställa efteråt.

## 2.8 Aggregatfunktioner, GROUP BY och HAVING

**Aggregatfunktioner** räknar ihop många rader till ett värde:

| Funktion | Gör |
|----------|-----|
| `COUNT(*)` | Antal rader |
| `COUNT(kolumn)` | Antal rader där kolumnen **inte** är `NULL` |
| `SUM(kolumn)` | Summa |
| `AVG(kolumn)` | Medelvärde |
| `MIN(kolumn)`, `MAX(kolumn)` | Minsta / största värdet |

```sql
SELECT COUNT(*) AS antal, COUNT(note) AS med_anteckning FROM bookings;
```

| antal | med_anteckning |
|-------|----------------|
| 15 | 4 |

```sql
SELECT SUM(size_sqm) AS total_yta,
       ROUND(AVG(size_sqm), 1) AS snitt,
       MIN(size_sqm) AS minst,
       MAX(size_sqm) AS storst
FROM apartments;
```

| total_yta | snitt | minst | storst |
|-----------|-------|-------|--------|
| 535.0 | 66.9 | 34.5 | 104.0 |

### GROUP BY – en sammanfattning per grupp

`GROUP BY` delar raderna i grupper och kör aggregatet per grupp:

```sql
SELECT resource, COUNT(*) AS antal
FROM bookings
GROUP BY resource;
```

```
bookings                          GROUP BY resource          resultat
┌────┬──────────┐                 ┌──────────────────┐       ┌──────────┬───────┐
│ id │ resource │                 │ resource = 1     │       │ resource │ antal │
├────┼──────────┤    ────────►    │  id 1,2,5,7,...  │ ────► │    1     │   7   │
│ 1  │    1     │                 ├──────────────────┤       │    2     │   5   │
│ 2  │    1     │                 │ resource = 2     │       │    3     │   3   │
│ 3  │    2     │                 │  id 3,6,8,...    │       └──────────┴───────┘
│ 4  │    3     │                 ├──────────────────┤
│ …  │    …     │                 │ resource = 3     │
└────┴──────────┘                 │  id 4,9,13       │
                                  └──────────────────┘
```

⚠️ **Varning:** Alla kolumner i `SELECT` som *inte* är aggregat bör stå i
`GROUP BY`. SQLite låter dig fuska och väljer då ett slumpmässigt värde ur
gruppen, men PostgreSQL ger ett fel – och det är PostgreSQL som har rätt.

### HAVING – filtrera grupper

`WHERE` filtrerar **rader före** grupperingen. `HAVING` filtrerar **grupper
efter** grupperingen.

```sql
-- Medlemmar som har gjort minst 2 bokningar
SELECT user, COUNT(*) AS antal
FROM bookings
GROUP BY user
HAVING COUNT(*) >= 2;
```

| user | antal |
|------|-------|
| 1 | 4 |
| 2 | 2 |
| 3 | 2 |
| 5 | 2 |

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

Bokningstabellen innehåller bara id:n: `resource = 1, user = 3`. För att visa
"Tvättstuga 1 – Cecilia Carlsson" måste vi **joina** in de andra tabellerna.

### INNER JOIN

`INNER JOIN` (eller bara `JOIN`) ger de rader där det finns en matchning i
**båda** tabellerna.

```sql
SELECT b.id, r.name AS resource, u.name AS user, b."start"
FROM bookings b
INNER JOIN resources r ON r.id = b.resource
INNER JOIN users     u ON u.id = b.user
WHERE b."start" LIKE '2026-10-12%'
ORDER BY b."start";
```

| id | resource | user | start |
|----|----------|------|-------|
| 1 | Tvättstuga 1 | Anna Andersson | 2026-10-12 07:00:00 |
| 2 | Tvättstuga 1 | Cecilia Carlsson | 2026-10-12 10:00:00 |
| 3 | Tvättstuga 2 | Eva Ek | 2026-10-12 16:00:00 |

`b`, `r` och `u` är **alias** – korta namn på tabellerna så att vi slipper skriva
`bookings.resource`. `ON` anger hur raderna ska paras ihop: främmande nyckel =
primärnyckel.

### LEFT JOIN

`LEFT JOIN` ger **alla** rader från den vänstra tabellen, och matchande rader
från den högra om de finns. Saknas matchning fylls kolumnerna med `NULL`.

```sql
SELECT a.number, u.name
FROM apartments a
LEFT JOIN users u ON u.apartment = a.id
ORDER BY a.number;
```

| number | name |
|--------|------|
| 1001 | Cecilia Carlsson |
| 1002 | David Dahl |
| 1101 | Anna Andersson |
| 1101 | Bertil Berg |
| **1102** | **NULL** |
| 1201 | Eva Ek |
| 1202 | Fredrik Falk |
| 1301 | Gunilla Gran |
| 1301 | Hassan Haddad |
| 1302 | Ida Isaksson |

Med `INNER JOIN` hade lägenhet 1102 inte kommit med alls, eftersom ingen bor där.
Och Johan, som inte har någon lägenhet, kommer inte med i någon av frågorna –
han finns ju inte i den vänstra tabellen.

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

  A = apartments, B = users
  Lägenhet 1102 hamnar bara i LEFT JOIN. Johan (utan lägenhet) i ingen av dem.
```

Ett klassiskt användningsfall för `LEFT JOIN` är att räkna **inklusive noll**:

```sql
-- Antal bokningar per medlem, även de som inte har bokat något
SELECT u.name, COUNT(b.id) AS antal
FROM users u
LEFT JOIN bookings b ON b.user = u.id
GROUP BY u.id, u.name
ORDER BY antal DESC, u.name;
```

Johan Jönsson får `0`. Lägg märke till `COUNT(b.id)` och inte `COUNT(*)` –
`COUNT(*)` hade räknat Johans rad (med `NULL`-bokning) som 1.

💡 **Tips:** Det finns även `RIGHT JOIN` och `FULL OUTER JOIN` (stöds i SQLite
från version 3.39). I praktiken klarar man sig nästan alltid med `INNER` och `LEFT`.

🧪 **Prova själv:** Skriv en fråga som visar alla anslag med titel och
författarens namn. Använd först `INNER JOIN`, sedan `LEFT JOIN`. Ger de samma
resultat? Varför? (Tips: kan `posts.author` vara `NULL`?)

## 2.10 Underfrågor (subqueries)

En **underfråga** är en `SELECT` inuti en annan fråga, inom parentes.

**I `WHERE` – jämför med ett beräknat värde:**

```sql
-- Lägenheter som är större än genomsnittet
SELECT number, size_sqm
FROM apartments
WHERE size_sqm > (SELECT AVG(size_sqm) FROM apartments);
```

**Med `IN` / `NOT IN` – jämför med en lista:**

```sql
-- Medlemmar som aldrig har bokat något
SELECT name
FROM users
WHERE id NOT IN (SELECT user FROM bookings);
```

**Med `EXISTS` – finns det minst en rad?**

```sql
-- Resurser som har minst en bokning i november
SELECT r.name
FROM resources r
WHERE EXISTS (
    SELECT 1 FROM bookings b
    WHERE b.resource = r.id
      AND b."start" >= '2026-11-01'
);
```

**I `SELECT` – ett värde per rad (korrelerad underfråga):**

```sql
SELECT u.name,
       (SELECT COUNT(*) FROM posts p WHERE p.author = u.id) AS antal_anslag
FROM users u
WHERE u.role IN ('board', 'admin');
```

En underfråga är **korrelerad** när den refererar till den yttre frågan
(`u.id`). Den körs då logiskt en gång per rad.

⚠️ **Varning:** `NOT IN` med en underfråga som kan returnera `NULL` ger tomt
resultat (på grund av hur `NULL` fungerar). `bookings.user` är `NOT NULL`, så här
är det säkert. Är du osäker – använd `NOT EXISTS`.

💡 **Tips:** Många underfrågor kan skrivas om som `JOIN` och tvärtom. Välj det som
är lättast att läsa.

## 2.11 Index

Utan index måste databasen läsa **varje rad** i tabellen för att hitta det du
söker (en *full table scan*). Ett **index** fungerar som registret längst bak i
en bok: en sorterad lista som pekar direkt till rätt sida.

```
Utan index: leta efter user = 5           Med index på bookings(user)
┌────┬──────┐                             index (sorterat)     tabell
│ 1  │  1   │ ← läs                       ┌──────┬────┐       ┌────┬──────┐
│ 2  │  3   │ ← läs                       │ 1    │ 1  │       │ …  │      │
│ 3  │  5   │ ← läs ✓                     │ 1    │ 7  │       │ 3  │  5   │
│ 4  │  4   │ ← läs                       │ …    │    │       │ …  │      │
│ …  │  …   │ ← läs … (alla rader)        │ 5    │ 3 ─┼──────►│ 10 │  5   │
│ 15 │  2   │ ← läs                       │ 5    │ 10─┼──────►│ …  │      │
└────┴──────┘                             └──────┴────┘       └────┴──────┘
```

```sql
CREATE INDEX IF NOT EXISTS idx_bookings_user ON bookings(user);

-- Sammansatt index: först resurs, sedan starttid
CREATE INDEX IF NOT EXISTS idx_bookings_resource_start ON bookings(resource, "start");

-- Unikt index: ett villkor och ett index på samma gång
CREATE UNIQUE INDEX idx_unique_slot ON bookings(resource, "start");
```

(De två första indexen finns redan i `seed.sql`. Kör `DROP INDEX
idx_unique_slot;` efteråt om du provar det sista.)

Med `EXPLAIN QUERY PLAN` kan du se om databasen använder ett index:

```sql
EXPLAIN QUERY PLAN
SELECT * FROM bookings WHERE resource = 1 AND "start" >= '2026-10-12';
```

```text
QUERY PLAN
`--SEARCH bookings USING INDEX idx_bookings_resource_start (resource=? AND start>?)
```

`SEARCH ... USING INDEX` är bra. `SCAN bookings` betyder att hela tabellen lästs.

**När ska man skapa ett index?**

| Skapa index på … | Exempel |
|------------------|---------|
| Främmande nycklar | `bookings(user)`, `users(apartment)` |
| Kolumner du ofta filtrerar på i `WHERE` | `bookings(resource, "start")` |
| Kolumner du ofta sorterar på | `posts(created)` |
| Kolumner som ska vara unika | `users(email)` – `UNIQUE` skapar index automatiskt |

**Men inte överallt:** varje index tar plats och gör `INSERT`, `UPDATE` och
`DELETE` lite långsammare, eftersom indexet också måste uppdateras. På små
tabeller (några hundra rader) märks ingen skillnad alls.

💡 **Tips:** Primärnyckeln är alltid indexerad automatiskt.

## 2.12 Vyer (views)

En **vy** är en sparad `SELECT` som du kan fråga som om den vore en tabell. Den
lagrar ingen egen data – frågan körs varje gång.

```sql
CREATE VIEW IF NOT EXISTS board_members AS
SELECT u.id, u.name, u.email, a.number AS apartment_number
FROM users u
LEFT JOIN apartments a ON a.id = u.apartment
WHERE u.role IN ('board', 'admin');

SELECT * FROM board_members ORDER BY name;
```

Seed-skriptet innehåller vyn `upcoming_bookings`. Prova:

```sql
SELECT * FROM upcoming_bookings LIMIT 5;
```

Vyer är bra för att ge ett enkelt namn åt en krånglig fråga som används ofta.

💡 **Tips:** PocketBase har *View collections* som bygger på exakt samma idé:
en collection som definieras av en `SELECT`-fråga.

## 2.13 Hela seed-skriptet

Det här är innehållet i [`seed.sql`](seed.sql). Det används i alla övningar.
Läs igenom det – det är en bra repetition av allt i kapitlet.

```sql
-- =====================================================================
-- seed.sql – Föreningsappen (modul 01 – Databaser)
--
-- Skapar tabellerna apartments, users, resources, bookings och posts
-- och fyller dem med exempeldata. Skriptet är skrivet för SQLite.
--
-- Kör så här:
--   sqlite3 forening.db < seed.sql        (skapar/återställer en fil)
--   sqlite3 forening.db                    (öppna sedan databasen)
--
-- Skriptet kan köras flera gånger: det tar bort tabellerna först.
-- Alla tider lagras som text i UTC, format 'YYYY-MM-DD HH:MM:SS'.
-- =====================================================================

PRAGMA foreign_keys = ON;   -- SQLite kontrollerar inte främmande nycklar utan detta!

-- Ta bort i omvänd ordning (barn före föräldrar)
DROP VIEW  IF EXISTS upcoming_bookings;
DROP TABLE IF EXISTS bookings;
DROP TABLE IF EXISTS posts;
DROP TABLE IF EXISTS resources;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS apartments;

-- ---------------------------------------------------------------------
-- Tabeller
-- ---------------------------------------------------------------------

CREATE TABLE apartments (
    id        INTEGER PRIMARY KEY,                 -- auto-ökande id
    number    TEXT    NOT NULL UNIQUE,             -- t.ex. '1101'
    floor     INTEGER NOT NULL CHECK (floor >= 0),
    size_sqm  REAL    NOT NULL CHECK (size_sqm > 0)
);

CREATE TABLE users (
    id         INTEGER PRIMARY KEY,
    email      TEXT    NOT NULL UNIQUE,
    name       TEXT    NOT NULL,
    apartment  INTEGER REFERENCES apartments(id) ON DELETE SET NULL,
    role       TEXT    NOT NULL DEFAULT 'member'
                       CHECK (role IN ('member', 'board', 'admin')),
    created    TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE resources (
    id           INTEGER PRIMARY KEY,
    name         TEXT    NOT NULL UNIQUE,
    description  TEXT,
    max_hours    INTEGER NOT NULL CHECK (max_hours BETWEEN 1 AND 24),
    active       INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0, 1))
);

CREATE TABLE bookings (
    id        INTEGER PRIMARY KEY,
    resource  INTEGER NOT NULL REFERENCES resources(id) ON DELETE CASCADE,
    user      INTEGER NOT NULL REFERENCES users(id)     ON DELETE CASCADE,
    "start"   TEXT    NOT NULL,
    "end"     TEXT    NOT NULL,
    note      TEXT,
    CHECK ("end" > "start")
);

CREATE TABLE posts (
    id         INTEGER PRIMARY KEY,
    title      TEXT    NOT NULL,
    body       TEXT    NOT NULL,
    author     INTEGER REFERENCES users(id) ON DELETE SET NULL,
    published  INTEGER NOT NULL DEFAULT 0 CHECK (published IN (0, 1)),
    created    TEXT    NOT NULL DEFAULT (datetime('now'))
);

-- Index på främmande nycklar och kolumner vi ofta filtrerar på
CREATE INDEX idx_users_apartment      ON users(apartment);
CREATE INDEX idx_bookings_user        ON bookings(user);
CREATE INDEX idx_bookings_resource_start ON bookings(resource, "start");
CREATE INDEX idx_posts_author         ON posts(author);

-- ---------------------------------------------------------------------
-- Data
-- ---------------------------------------------------------------------

INSERT INTO apartments (id, number, floor, size_sqm) VALUES
    (1, '1001', 0, 34.5),
    (2, '1002', 0, 58.0),
    (3, '1101', 1, 72.0),
    (4, '1102', 1, 45.5),
    (5, '1201', 2, 72.0),
    (6, '1202', 2, 88.0),
    (7, '1301', 3, 104.0),
    (8, '1302', 3, 61.0);

INSERT INTO users (id, email, name, apartment, role, created) VALUES
    (1,  'anna@example.com',   'Anna Andersson',   3, 'board',  '2025-01-10 09:00:00'),
    (2,  'bertil@example.com', 'Bertil Berg',      3, 'member', '2025-01-12 18:30:00'),
    (3,  'cecilia@example.com','Cecilia Carlsson', 1, 'member', '2025-02-03 12:00:00'),
    (4,  'david@example.com',  'David Dahl',       2, 'board',  '2025-02-20 08:15:00'),
    (5,  'eva@example.com',    'Eva Ek',           5, 'member', '2025-03-01 10:00:00'),
    (6,  'fredrik@example.com','Fredrik Falk',     6, 'member', '2025-04-11 16:45:00'),
    (7,  'gunilla@example.com','Gunilla Gran',     7, 'admin',  '2025-04-11 17:00:00'),
    (8,  'hassan@example.com', 'Hassan Haddad',    7, 'member', '2025-06-23 20:10:00'),
    (9,  'ida@example.com',    'Ida Isaksson',     8, 'member', '2025-09-05 11:30:00'),
    (10, 'johan@example.com',  'Johan Jönsson',    NULL, 'member', '2026-01-15 14:00:00');
-- Johan har ännu ingen lägenhet kopplad (t.ex. nyinflyttad, ej registrerad).
-- Lägenhet 4 (1102) har ingen registrerad medlem.

INSERT INTO resources (id, name, description, max_hours, active) VALUES
    (1, 'Tvättstuga 1', 'Källaren, hus A. Två maskiner och en torktumlare.', 3, 1),
    (2, 'Tvättstuga 2', 'Källaren, hus B. Tre maskiner och torkskåp.',       3, 1),
    (3, 'Festlokalen',  'Plan 0. Plats för 30 personer, kök finns.',         12, 1),
    (4, 'Bastun',       'Stängd för renovering.',                            2, 0);

INSERT INTO bookings (id, resource, user, "start", "end", note) VALUES
    (1,  1, 1, '2026-10-12 07:00:00', '2026-10-12 10:00:00', NULL),
    (2,  1, 3, '2026-10-12 10:00:00', '2026-10-12 13:00:00', 'Mycket tvätt'),
    (3,  2, 5, '2026-10-12 16:00:00', '2026-10-12 19:00:00', NULL),
    (4,  3, 4, '2026-10-17 15:00:00', '2026-10-17 23:00:00', '40-årsfest'),
    (5,  1, 2, '2026-10-13 07:00:00', '2026-10-13 10:00:00', NULL),
    (6,  2, 6, '2026-10-13 10:00:00', '2026-10-13 13:00:00', NULL),
    (7,  1, 1, '2026-10-14 16:00:00', '2026-10-14 19:00:00', NULL),
    (8,  2, 8, '2026-10-14 07:00:00', '2026-10-14 10:00:00', NULL),
    (9,  3, 9, '2026-10-24 12:00:00', '2026-10-24 22:00:00', 'Barnkalas'),
    (10, 1, 5, '2026-10-15 13:00:00', '2026-10-15 16:00:00', NULL),
    (11, 2, 3, '2026-10-15 16:00:00', '2026-10-15 19:00:00', NULL),
    (12, 1, 7, '2026-10-16 07:00:00', '2026-10-16 10:00:00', NULL),
    (13, 3, 1, '2026-11-07 14:00:00', '2026-11-07 20:00:00', 'Föreningsstämma'),
    (14, 1, 1, '2026-09-28 07:00:00', '2026-09-28 10:00:00', NULL),
    (15, 2, 2, '2026-09-30 16:00:00', '2026-09-30 19:00:00', NULL);

INSERT INTO posts (id, title, body, author, published, created) VALUES
    (1, 'Välkommen till nya appen!',
        'Nu kan ni boka tvättstuga och festlokal direkt i mobilen.', 1, 1, '2026-09-01 08:00:00'),
    (2, 'Städdag 18 oktober',
        'Vi ses på gården kl 10. Föreningen bjuder på fika.',        4, 1, '2026-09-20 19:00:00'),
    (3, 'Bastun stängd',
        'Bastun renoveras under hösten. Vi återkommer med datum.',   7, 1, '2026-09-25 12:00:00'),
    (4, 'Kallelse till föreningsstämma',
        'Stämman hålls 7 november kl 14 i festlokalen.',             1, 1, '2026-10-01 09:00:00'),
    (5, 'Utkast: nya trivselregler',
        'Förslag på nya regler för tvättstugan. Ej klart.',          4, 0, '2026-10-05 21:00:00'),
    (6, 'Cykelrensning',
        'Omärkta cyklar i cykelrummet tas bort 1 november.',         7, 1, '2026-10-06 07:30:00');

-- En vy: kommande bokningar med namn i stället för id
CREATE VIEW upcoming_bookings AS
SELECT b.id,
       r.name  AS resource_name,
       u.name  AS user_name,
       b."start",
       b."end"
FROM bookings b
JOIN resources r ON r.id = b.resource
JOIN users     u ON u.id = b.user
WHERE b."start" >= '2026-10-12 00:00:00'
ORDER BY b."start";
```

## Sammanfattning

| Vill du … | Använd |
|-----------|--------|
| skapa/ändra/ta bort en tabell | `CREATE TABLE`, `ALTER TABLE`, `DROP TABLE` |
| skydda datan | `NOT NULL`, `UNIQUE`, `CHECK`, `DEFAULT`, `PRIMARY KEY`, `REFERENCES ... ON DELETE` |
| lägga in / ändra / ta bort rader | `INSERT`, `UPDATE ... WHERE`, `DELETE ... WHERE` |
| läsa | `SELECT ... FROM ... WHERE ... ORDER BY ... LIMIT` |
| sammanfatta | `COUNT`, `SUM`, `AVG`, `MIN`, `MAX`, `GROUP BY`, `HAVING` |
| kombinera tabeller | `INNER JOIN`, `LEFT JOIN` |
| fråga i frågan | underfrågor med `IN`, `EXISTS` eller i `SELECT` |
| snabba upp sökningar | `CREATE INDEX` |
| spara en fråga | `CREATE VIEW` |

Nästa kapitel: [Kapitel 3 – ACID och transaktioner](03-acid-och-transaktioner.md)

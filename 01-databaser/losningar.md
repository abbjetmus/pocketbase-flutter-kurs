# Lösningar – Modul 01 Databaser

Här är lösningsförslag till [övningarna](ovningar.md). Det finns ofta flera
korrekta sätt att skriva en fråga – om ditt svar ger samma resultat och är lätt
att läsa är det lika bra. Alla frågor förutsätter en nyss återställd databas
(`sqlite3 forening.db < seed.sql`) och `PRAGMA foreign_keys = ON;`.

---

## Del A – SQL-frågor

### Nivå 1

**1.1**

```sql
SELECT * FROM resources WHERE active = 1;
```

Tvättstuga 1, Tvättstuga 2 och Festlokalen. Bastun har `active = 0`.

**1.2**

```sql
SELECT number, floor
FROM apartments
WHERE floor >= 2
ORDER BY number;
```

| number | floor |
|--------|-------|
| 1201 | 2 |
| 1202 | 2 |
| 1301 | 3 |
| 1302 | 3 |

**1.3**

```sql
SELECT COUNT(*) AS antal_medlemmar FROM users;   -- 10
```

**1.4**

```sql
SELECT id, user, note
FROM bookings
WHERE note IS NOT NULL;
```

| id | user | note |
|----|------|------|
| 2 | 3 | Mycket tvätt |
| 4 | 4 | 40-årsfest |
| 9 | 9 | Barnkalas |
| 13 | 1 | Föreningsstämma |

⚠️ `WHERE note != NULL` ger noll rader. Använd alltid `IS NOT NULL`.

**1.5**

```sql
SELECT title, created
FROM posts
WHERE published = 1
ORDER BY created DESC;
```

| title | created |
|-------|---------|
| Cykelrensning | 2026-10-06 07:30:00 |
| Kallelse till föreningsstämma | 2026-10-01 09:00:00 |
| Bastun stängd | 2026-09-25 12:00:00 |
| Städdag 18 oktober | 2026-09-20 19:00:00 |
| Välkommen till nya appen! | 2026-09-01 08:00:00 |

**1.6**

```sql
SELECT number, size_sqm
FROM apartments
ORDER BY size_sqm DESC
LIMIT 1;
```

Lägenhet 1301 med 104 kvm. Alternativ med underfråga (ger alla vid delad förstaplats):

```sql
SELECT number, size_sqm
FROM apartments
WHERE size_sqm = (SELECT MAX(size_sqm) FROM apartments);
```

**1.7**

```sql
SELECT name, email
FROM users
WHERE email LIKE '%an%';
```

Anna Andersson, Hassan Haddad och Johan Jönsson. `%` betyder "vad som helst,
även ingenting", så `'%an%'` betyder "innehåller *an* någonstans".

**1.8**

```sql
SELECT name FROM users WHERE apartment IS NULL;   -- Johan Jönsson
```

**1.9**

```sql
-- 1. Lägg till
INSERT INTO users (email, name, apartment)
VALUES ('kim@example.com', 'Kim Kursdeltagare', 4);
SELECT * FROM users WHERE email = 'kim@example.com';
-- role blev 'member' och created fick dagens datum tack vare DEFAULT

-- 2. Ändra roll
UPDATE users SET role = 'board' WHERE email = 'kim@example.com';
SELECT name, role FROM users WHERE email = 'kim@example.com';
```

```sql
-- 3. Ogiltig roll – ger fel
UPDATE users SET role = 'kung' WHERE email = 'kim@example.com';
-- Runtime error: CHECK constraint failed: role IN ('member', 'board', 'admin')
```

`CHECK`-villkoret på `role` tillåter bara de tre värdena. Raden ändras inte.

```sql
-- 4. Ta bort
DELETE FROM users WHERE email = 'kim@example.com';
SELECT COUNT(*) FROM users;   -- 10 igen
```

💡 Lägg märke till att vi använder `WHERE email = ...` hela tiden. Utan `WHERE`
hade *alla* medlemmar fått rollen `board` i steg 2.

**1.10**

```sql
INSERT INTO bookings (resource, user, "start", "end")
VALUES (1, 1, '2026-10-20 10:00:00', '2026-10-20 07:00:00');
-- Runtime error: CHECK constraint failed: end
```

```sql
INSERT INTO bookings (resource, user, "start", "end")
VALUES (1, 42, '2026-10-20 07:00:00', '2026-10-20 10:00:00');
-- Runtime error: FOREIGN KEY constraint failed
```

Fick du **inget** fel på den andra? Då har du glömt `PRAGMA foreign_keys = ON;`.
Ta i så fall bort raden: `DELETE FROM bookings WHERE user = 42;`

### Nivå 2

**2.1**

```sql
SELECT role, COUNT(*) AS antal
FROM users
GROUP BY role
ORDER BY antal DESC;
```

| role | antal |
|------|-------|
| member | 7 |
| board | 2 |
| admin | 1 |

**2.2**

```sql
SELECT a.number, COUNT(u.id) AS antal_medlemmar
FROM apartments a
LEFT JOIN users u ON u.apartment = a.id
GROUP BY a.id, a.number
ORDER BY a.number;
```

| number | antal_medlemmar |
|--------|-----------------|
| 1001 | 1 |
| 1002 | 1 |
| 1101 | 2 |
| 1102 | 0 |
| 1201 | 1 |
| 1202 | 1 |
| 1301 | 2 |
| 1302 | 1 |

Två fällor: med `INNER JOIN` försvinner 1102, och med `COUNT(*)` får 1102 värdet
1 i stället för 0 (raden med `NULL`-medlem räknas).

**2.3**

```sql
SELECT b."start", b."end", r.name AS resurs, u.name AS medlem
FROM bookings b
JOIN resources r ON r.id = b.resource
JOIN users     u ON u.id = b.user
WHERE b."start" >= '2026-10-12 00:00:00'
  AND b."start" <  '2026-10-19 00:00:00'
ORDER BY b."start";
```

| start | end | resurs | medlem |
|-------|-----|--------|--------|
| 2026-10-12 07:00:00 | 2026-10-12 10:00:00 | Tvättstuga 1 | Anna Andersson |
| 2026-10-12 10:00:00 | 2026-10-12 13:00:00 | Tvättstuga 1 | Cecilia Carlsson |
| 2026-10-12 16:00:00 | 2026-10-12 19:00:00 | Tvättstuga 2 | Eva Ek |
| 2026-10-13 07:00:00 | 2026-10-13 10:00:00 | Tvättstuga 1 | Bertil Berg |
| 2026-10-13 10:00:00 | 2026-10-13 13:00:00 | Tvättstuga 2 | Fredrik Falk |
| 2026-10-14 07:00:00 | 2026-10-14 10:00:00 | Tvättstuga 2 | Hassan Haddad |
| 2026-10-14 16:00:00 | 2026-10-14 19:00:00 | Tvättstuga 1 | Anna Andersson |
| 2026-10-15 13:00:00 | 2026-10-15 16:00:00 | Tvättstuga 1 | Eva Ek |
| 2026-10-15 16:00:00 | 2026-10-15 19:00:00 | Tvättstuga 2 | Cecilia Carlsson |
| 2026-10-16 07:00:00 | 2026-10-16 10:00:00 | Tvättstuga 1 | Gunilla Gran |
| 2026-10-17 15:00:00 | 2026-10-17 23:00:00 | Festlokalen | David Dahl |

💡 Använd "`>=` start och `<` dagen efter slutet" i stället för
`BETWEEN '2026-10-12' AND '2026-10-18'`. Med `BETWEEN` missar du allt som startar
*under* den 18:e, eftersom `'2026-10-18 10:00:00' > '2026-10-18'`.

**2.4**

```sql
SELECT p.title, u.name AS forfattare, a.number AS lagenhet
FROM posts p
LEFT JOIN users      u ON u.id = p.author
LEFT JOIN apartments a ON a.id = u.apartment
WHERE p.published = 1
ORDER BY p.created;
```

`LEFT JOIN` gör att anslaget visas även om författaren tagits bort
(`author = NULL`) eller saknar lägenhet. Med seed-datan ger `JOIN` samma resultat.

**2.5**

```sql
SELECT r.name,
       SUM(unixepoch(b."end") - unixepoch(b."start")) / 3600.0 AS timmar
FROM resources r
JOIN bookings b ON b.resource = r.id
GROUP BY r.id, r.name
ORDER BY timmar DESC;
```

| name | timmar |
|------|--------|
| Festlokalen | 24.0 |
| Tvättstuga 1 | 21.0 |
| Tvättstuga 2 | 15.0 |

💡 Om du använder `julianday()` i stället kan du få svar som `24.000000007` på
grund av avrundningsfel i flyttal. `unixepoch()` räknar i hela sekunder.

**2.6**

```sql
-- Med LEFT JOIN: behåll resurser där ingen bokning hittades
SELECT r.name
FROM resources r
LEFT JOIN bookings b ON b.resource = r.id
WHERE b.id IS NULL;

-- Med NOT EXISTS
SELECT r.name
FROM resources r
WHERE NOT EXISTS (SELECT 1 FROM bookings b WHERE b.resource = r.id);
```

Båda ger `Bastun`.

**2.7**

```sql
SELECT DISTINCT u.name
FROM users u
JOIN bookings  b ON b.user = u.id
JOIN resources r ON r.id = b.resource
WHERE r.name = 'Festlokalen'
ORDER BY u.name;
```

Anna Andersson, David Dahl och Ida Isaksson.

**2.8**

```sql
SELECT floor, COUNT(*) AS antal, SUM(size_sqm) AS total_yta
FROM apartments
GROUP BY floor
HAVING SUM(size_sqm) > 120
ORDER BY floor;
```

| floor | antal | total_yta |
|-------|-------|-----------|
| 2 | 2 | 160.0 |
| 3 | 2 | 165.0 |

Villkoret gäller en *summa per grupp*, därför `HAVING` och inte `WHERE`.

**2.9**

```sql
SELECT u.name
FROM users u
JOIN bookings  b ON b.user = u.id
JOIN resources r ON r.id = b.resource
WHERE r.name IN ('Tvättstuga 1', 'Tvättstuga 2')
GROUP BY u.id, u.name
HAVING COUNT(DISTINCT b.resource) = 2;
```

Bertil Berg, Cecilia Carlsson och Eva Ek. `WHERE` begränsar till de två
tvättstugorna, och `HAVING` behåller de medlemmar som har bokningar på *två
olika* av dem.

**2.10**

```sql
SELECT u.name,
       SUM(unixepoch(b."end") - unixepoch(b."start")) / 3600.0 AS timmar
FROM users u
JOIN bookings b ON b.user = u.id
GROUP BY u.id, u.name
ORDER BY timmar DESC
LIMIT 3;
```

| name | timmar |
|------|--------|
| Anna Andersson | 15.0 |
| Ida Isaksson | 10.0 |
| David Dahl | 8.0 |

### Nivå 3

**3.1 – Dubbelbokningar**

```sql
-- Lägg in två krockande testbokningar
INSERT INTO bookings (resource, user, "start", "end") VALUES
    (2, 9,  '2026-10-20 07:00:00', '2026-10-20 10:00:00'),
    (2, 10, '2026-10-20 09:00:00', '2026-10-20 12:00:00');

SELECT b1.id AS bokning_a, b2.id AS bokning_b, b1.resource,
       b1."start" AS a_start, b1."end" AS a_end,
       b2."start" AS b_start, b2."end" AS b_end
FROM bookings b1
JOIN bookings b2
  ON  b1.resource = b2.resource
  AND b1.id < b2.id                -- varje par en gång, och inte med sig själv
  AND b1."start" < b2."end"        -- överlappsvillkoret
  AND b1."end"   > b2."start";

-- Städa upp
DELETE FROM bookings WHERE "start" LIKE '2026-10-20%' AND resource = 2;
```

Resultatet blir ett par (bokning 16 och 17). Två saker att lägga märke till:

- `b1.id < b2.id` ser till att vi inte jämför en bokning med sig själv och att
  paret (16, 17) inte också visas som (17, 16).
- Pass som bara *möts* (10–13 och 13–16) räknas inte som överlapp, eftersom vi
  använder `<` och `>` och inte `<=` och `>=`.

**3.2 – Lediga pass**

```sql
WITH slots(slot_start, slot_end) AS (
    VALUES ('2026-10-12 07:00:00', '2026-10-12 10:00:00'),
           ('2026-10-12 10:00:00', '2026-10-12 13:00:00'),
           ('2026-10-12 13:00:00', '2026-10-12 16:00:00'),
           ('2026-10-12 16:00:00', '2026-10-12 19:00:00'),
           ('2026-10-12 19:00:00', '2026-10-12 22:00:00')
)
SELECT s.slot_start, s.slot_end
FROM slots s
WHERE NOT EXISTS (
    SELECT 1
    FROM bookings b
    WHERE b.resource = 1
      AND b."start" < s.slot_end
      AND b."end"   > s.slot_start
)
ORDER BY s.slot_start;
```

| slot_start | slot_end |
|------------|----------|
| 2026-10-12 13:00:00 | 2026-10-12 16:00:00 |
| 2026-10-12 16:00:00 | 2026-10-12 19:00:00 |
| 2026-10-12 19:00:00 | 2026-10-12 22:00:00 |

`WITH` skapar en tillfällig namngiven tabell (en *CTE*, *Common Table Expression*)
som bara finns under frågan. I en riktig app skulle passen kanske genereras i
koden eller finnas i en egen tabell.

**3.3 – Regelbrott**

```sql
SELECT b.id, r.name,
       (unixepoch(b."end") - unixepoch(b."start")) / 3600.0 AS timmar,
       r.max_hours
FROM bookings b
JOIN resources r ON r.id = b.resource
WHERE (unixepoch(b."end") - unixepoch(b."start")) / 3600.0 > r.max_hours;
```

Seed-datan ger 0 rader. Testa:

```sql
INSERT INTO bookings (resource, user, "start", "end")
VALUES (2, 9, '2026-10-21 07:00:00', '2026-10-21 12:00:00');   -- 5 h, max 3
-- kör frågan igen → en rad
DELETE FROM bookings WHERE "start" = '2026-10-21 07:00:00' AND resource = 2;
```

💡 Den här regeln går inte att uttrycka med ett vanligt `CHECK`, eftersom den
kräver data från en annan tabell. Den kontrolleras typiskt i backend-koden (t.ex.
en PocketBase-hook) eller med en *trigger*.

**3.4 – Nästa bokning**

```sql
SELECT u.name, MIN(b."start") AS nasta_bokning
FROM users u
JOIN bookings b ON b.user = u.id
WHERE b."start" >= '2026-10-12 00:00:00'
GROUP BY u.id, u.name
ORDER BY nasta_bokning;
```

Nio medlemmar. Johan har ingen bokning alls och kommer inte med – precis som det
ska vara, eftersom vi använder `JOIN` och inte `LEFT JOIN`. Bokningarna i
september filtreras bort av `WHERE` *innan* `MIN` räknas ut.

**3.5 – Statistikvy**

```sql
DROP VIEW IF EXISTS member_stats;
CREATE VIEW member_stats AS
SELECT u.id,
       u.name,
       a.number AS apartment_number,
       COUNT(b.id) AS bookings_count,
       COALESCE(SUM(unixepoch(b."end") - unixepoch(b."start")), 0) / 3600.0
           AS booked_hours
FROM users u
LEFT JOIN apartments a ON a.id = u.apartment
LEFT JOIN bookings   b ON b.user = u.id
GROUP BY u.id, u.name, a.number;

SELECT * FROM member_stats ORDER BY booked_hours DESC, name;
```

`COALESCE(x, 0)` ger `0` om `x` är `NULL`. Utan den hade Johan fått `NULL` timmar,
eftersom `SUM` av inga rader är `NULL`.

**3.6 – Aktivitet per lägenhet**

```sql
SELECT a.number, COUNT(b.id) AS antal_bokningar
FROM apartments a
LEFT JOIN users    u ON u.apartment = a.id
LEFT JOIN bookings b ON b.user = u.id
GROUP BY a.id, a.number
ORDER BY antal_bokningar DESC, a.number;
```

| number | antal_bokningar |
|--------|-----------------|
| 1101 | 6 |
| 1001 | 2 |
| 1201 | 2 |
| 1301 | 2 |
| 1002 | 1 |
| 1202 | 1 |
| 1302 | 1 |
| 1102 | 0 |

1101 har 6: Anna (4) + Bertil (2). Båda `JOIN`:arna måste vara `LEFT` för att
1102 ska komma med.

**3.7 – Säker bokning**

```sql
BEGIN IMMEDIATE;

-- 1. Kontroll: finns något som överlappar? (förväntat: 0)
SELECT COUNT(*) AS krockar
FROM bookings
WHERE resource = 3
  AND "start" < '2026-10-31 20:00:00'
  AND "end"   > '2026-10-31 12:00:00';

-- 2. Appen ser 0 och bokar
INSERT INTO bookings (resource, user, "start", "end", note)
VALUES (3, 6, '2026-10-31 12:00:00', '2026-10-31 20:00:00', 'Halloweenfest');

COMMIT;
-- (Om kontrollen hade gett > 0 skulle appen i stället köra ROLLBACK.)
```

`BEGIN IMMEDIATE` tar SQLites skrivlås **direkt**. Ingen annan kan då hinna
skriva en krockande bokning mellan vår `SELECT` och vår `INSERT`. Med ett vanligt
`BEGIN` (deferred) tas skrivlåset först vid `INSERT`, och två transaktioner kan
båda hinna läsa "0 krockar" först.

Det går också att göra det i en enda sats, så att det inte finns något "mellan":

```sql
INSERT INTO bookings (resource, user, "start", "end", note)
SELECT 3, 6, '2026-10-31 12:00:00', '2026-10-31 20:00:00', 'Halloweenfest'
WHERE NOT EXISTS (
    SELECT 1 FROM bookings
    WHERE resource = 3
      AND "start" < '2026-10-31 20:00:00'
      AND "end"   > '2026-10-31 12:00:00'
);
SELECT changes();   -- 1 = bokad, 0 = upptaget (här 0, vi bokade ju nyss)
```

**3.8 – Fast passindelning**

```sql
CREATE UNIQUE INDEX idx_bookings_unique_slot ON bookings(resource, "start");

-- Test: Tvättstuga 1, 2026-10-12 07:00 är redan bokat av Anna
INSERT INTO bookings (resource, user, "start", "end")
VALUES (1, 2, '2026-10-12 07:00:00', '2026-10-12 10:00:00');
-- Runtime error: UNIQUE constraint failed: bookings.resource, bookings.start
```

Det räcker inte för festlokalen eftersom tider där kan **överlappa utan att börja
samtidigt**: 15:00–23:00 och 18:00–22:00 har olika `start` och släpps igenom av
indexet. För fria tider behövs en överlappskontroll (3.7), i en transaktion eller
en hook/trigger. (PostgreSQL har för övrigt en speciell *exclusion constraint* som
kan förbjuda överlappande intervall direkt i databasen.)

```sql
DROP INDEX idx_bookings_unique_slot;   -- städa upp
```

**3.9 – Kaskader**

```sql
BEGIN;
DELETE FROM users WHERE id = 1;
SELECT COUNT(*) FROM bookings WHERE user = 1;          -- 0  (CASCADE)
SELECT id, title, author FROM posts WHERE id IN (1, 4); -- author = NULL (SET NULL)
ROLLBACK;

BEGIN;
DELETE FROM apartments WHERE id = 3;
SELECT name, apartment FROM users WHERE id IN (1, 2);  -- apartment = NULL (SET NULL)
SELECT COUNT(*) FROM bookings;                          -- opåverkat
ROLLBACK;
```

- Tas Anna bort försvinner hennes 4 bokningar (`ON DELETE CASCADE` på
  `bookings.user`), medan hennes två anslag finns kvar med `author = NULL`
  (`ON DELETE SET NULL` på `posts.author`).
- Tas lägenhet 1101 bort får Anna och Bertil `apartment = NULL`. Deras bokningar
  påverkas inte – kaskaden går bara ett steg, till de rader som pekar direkt på
  lägenheten.
- Efter `ROLLBACK` är allt som förut. Kontrollera med `SELECT COUNT(*) FROM bookings;`.

---

## Del B – ACID och transaktioner

**B.1** Det är **atomiciteten** som saknas: bokningen och avgiften hör ihop men
sparades i två separata transaktioner, så bara den ena blev av. Lösning: gör
båda insättningarna i **samma transaktion på servern**. Appen gör ett anrop (t.ex.
"skapa bokning"), och servern – i PocketBase en hook med
`$app.runInTransaction` – skapar både bokningen och avgiften. Misslyckas något
rullas båda tillbaka. Regeln: logik som måste hålla ihop ska ligga på servern,
inte i klienten.

**B.2**

```
 tid   Bertil                                Eva
  1    SELECT krockar → 0
  2                                          SELECT krockar → 0
  3    INSERT (07–10)  ✓
  4                                          INSERT (07–10)  ✓   ← dubbelbokning
```

| Lösning | Fördelar | Nackdelar |
|---------|----------|-----------|
| **Unikt index** på `(resource, start)` | Enkel, går inte att kringgå, fungerar oavsett vilken kod som skriver | Fungerar bara om alla pass har fasta starttider |
| **Kontroll + insert i samma transaktion** (`BEGIN IMMEDIATE` eller `INSERT ... WHERE NOT EXISTS`) | Fungerar för fria, överlappande tider | All kod som skapar bokningar måste göra rätt; låser databasen kort |
| *(bonus)* Trigger i databasen som vägrar överlapp | Gäller all kod | Svårare att läsa och felsöka |

Den andra personen får ett fel och appen bör visa "Tiden blev precis bokad av
någon annan – välj en annan tid".

**B.3** Det är en **lost update**. Lös det genom att låta databasen räkna i en
enda atomär sats, och lägg till ett villkor så att värdet inte kan gå under noll:

```sql
-- Exempel med en tillfällig tabell
CREATE TABLE IF NOT EXISTS sauna_capacity (id INTEGER PRIMARY KEY, free_spots INTEGER NOT NULL CHECK (free_spots >= 0));
INSERT OR REPLACE INTO sauna_capacity (id, free_spots) VALUES (1, 4);

UPDATE sauna_capacity
SET free_spots = free_spots - 1
WHERE id = 1 AND free_spots > 0;     -- påverkar 0 rader om det är fullt

SELECT changes();                     -- 1 = du fick en plats, 0 = fullt
```

`CHECK (free_spots >= 0)` är ett extra skyddsnät (konsistens) om någon skulle
skriva en sats utan `free_spots > 0`.

Men – fundera på om räknaren alls behövs. "Lediga platser" är ett **härlett
värde** (kapacitet minus antal bokningar) och kan räknas fram med `COUNT(*)`.
Då försvinner problemet helt.

**B.4** Ja, bokningen finns – det är **beständighet** (durability). PocketBase
svarar först efter att transaktionen är committad, och SQLite committar först när
ändringen är skriven och synkad till disk (i WAL-läge: till `data.db-wal`). Vid
omstart läser SQLite WAL-filen och allt committat finns kvar. Transaktioner som
*inte* hann committas kastas (atomicitet).

**B.5** I WAL-läge kan de senaste committade ändringarna ligga i `data.db-wal` och
inte ännu i `data.db`. En kopia av bara `data.db` kan därför sakna data, och
kopierar man mitt i en checkpoint kan filen till och med vara trasig. Använd i
stället PocketBase inbyggda backup (adminpanelen eller API:et), eller `sqlite3`:s
`.backup`-kommando / `VACUUM INTO 'backup.db'`, som tar en konsistent ögonblicksbild.

**B.6**

| # | Problem |
|---|---------|
| a | Phantom read (nya rader dök upp) |
| b | Lost update |
| c | Dirty read |
| d | Non-repeatable read (samma rad, nytt värde) |

---

## Del C – Designuppgift

Det här är *ett* förslag. Andra lösningar kan vara lika bra – det viktiga är att
du kan motivera dina val.

### C.1 – Styrelsemöten med protokoll och närvaro

**Entiteter och attribut**

| Entitet | Attribut |
|---------|----------|
| `meetings` | `type`, `held_at`, `location`, `chair`, `secretary`, `created`, `updated` |
| `meeting_attendees` | `meeting`, `user`, `invited`, `attended` |
| `minutes_items` (paragrafer) | `meeting`, `number`, `title`, `body`, `decision` |
| `meeting_adjusters` | `meeting`, `user`, `adjusted_at` |
| `users` | *(finns redan)* |

Är "protokoll" en egen entitet? Ett möte har exakt ett protokoll och ett protokoll
hör till exakt ett möte (**1:1**), och protokollet har inga egna attribut utöver
paragraferna och justeringen. Därför slår vi ihop det med `meetings`. Paragraferna
hör till mötet.

**Relationer**

| Relation | Kardinalitet | Motivering |
|----------|--------------|------------|
| `meetings` – `minutes_items` | 1 : N | Ett möte har många paragrafer; en paragraf hör till ett möte |
| `users` – `meetings` (närvaro) | N : M | En medlem går på många möten; ett möte har många deltagare → kopplingstabell `meeting_attendees` med egna attribut (`invited`, `attended`) |
| `users` – `meetings` (justerare) | N : M | Kopplingstabell `meeting_adjusters` med `adjusted_at` |
| `users` – `meetings` (ordförande/sekreterare) | 1 : N (×2) | Ett möte har exakt en ordförande och en sekreterare → två FK-kolumner |

**ER-diagram**

```
┌───────────────────┐         ┌──────────────────┐         ┌───────────────────┐
│ meeting_attendees │         │     meetings     │         │ meeting_adjusters │
│───────────────────│         │──────────────────│         │───────────────────│
│ PK,FK meeting     │>○──────┼│ PK id            │┼──────○<│ PK,FK meeting     │
│ PK,FK user        │         │    type          │         │ PK,FK user        │
│    invited        │         │    held_at       │         │    adjusted_at    │
│    attended       │         │    location      │         └─────────┬─────────┘
└─────────┬─────────┘         │ FK chair         │                   >○
          >○                  │ FK secretary     │                   │
          │                   └───┬─────────┬────┘                   │
          │        (chair,       >○         ┼                        │
          │         secretary)    │         ○<                       │
          │                       │  ┌──────┴───────────┐            │
          │                       │  │  minutes_items   │            │
          │                       │  │──────────────────│            │
          │                       │  │ PK id            │            │
          │                       │  │ FK meeting       │            │
          │                       │  │    number        │            │
          │                       │  │    title, body   │            │
          │                       │  │    decision      │            │
          │                       │  │ UNIQUE(meeting,  │            │
          │                       │  │        number)   │            │
          │                       │  └──────────────────┘            │
          │                       ┼                                  │
          │              ┌────────┴─────────┐                        │
          └─────────────┼│      users       │┼───────────────────────┘
                         │──────────────────│
                         │ PK id            │
                         └──────────────────┘
```

Kortversion i text:

```
users    ┼──○< meeting_attendees >○──┼ meetings     (N:M närvaro, med invited/attended)
users    ┼──○< meeting_adjusters >○──┼ meetings     (N:M justerare, med adjusted_at)
users    ┼──○< meetings                             (chair, secretary – två 1:N)
meetings ┼──○< minutes_items                        (1:N paragrafer)
```

**SQL**

```sql
PRAGMA foreign_keys = ON;

CREATE TABLE meetings (
    id         INTEGER PRIMARY KEY,
    type       TEXT NOT NULL CHECK (type IN ('board', 'extra', 'annual')),
    held_at    TEXT NOT NULL,                       -- UTC, ISO 8601
    location   TEXT NOT NULL DEFAULT 'Festlokalen',
    chair      INTEGER REFERENCES users(id) ON DELETE SET NULL,
    secretary  INTEGER REFERENCES users(id) ON DELETE SET NULL,
    created    TEXT NOT NULL DEFAULT (datetime('now')),
    updated    TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX idx_meetings_held_at ON meetings(held_at);

CREATE TABLE meeting_attendees (
    meeting   INTEGER NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
    user      INTEGER NOT NULL REFERENCES users(id)    ON DELETE CASCADE,
    invited   INTEGER NOT NULL DEFAULT 1 CHECK (invited  IN (0, 1)),
    attended  INTEGER NOT NULL DEFAULT 0 CHECK (attended IN (0, 1)),
    PRIMARY KEY (meeting, user)
);
CREATE INDEX idx_meeting_attendees_user ON meeting_attendees(user);

CREATE TABLE minutes_items (
    id        INTEGER PRIMARY KEY,
    meeting   INTEGER NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
    number    INTEGER NOT NULL CHECK (number > 0),      -- §-nummer
    title     TEXT NOT NULL,
    body      TEXT NOT NULL DEFAULT '',
    decision  TEXT,                                      -- NULL = inget beslut
    UNIQUE (meeting, number)
);

CREATE TABLE meeting_adjusters (
    meeting      INTEGER NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
    user         INTEGER NOT NULL REFERENCES users(id)    ON DELETE RESTRICT,
    adjusted_at  TEXT,                                   -- NULL = ej justerat än
    PRIMARY KEY (meeting, user)
);

-- Testdata
INSERT INTO meetings (id, type, held_at, chair, secretary) VALUES
    (1, 'board', '2026-09-08 17:00:00', 1, 4),
    (2, 'board', '2026-10-06 17:00:00', 1, 4);

INSERT INTO meeting_attendees (meeting, user, attended) VALUES
    (1, 1, 1), (1, 4, 1), (1, 7, 1),
    (2, 1, 1), (2, 4, 1), (2, 7, 0);

INSERT INTO minutes_items (meeting, number, title, decision) VALUES
    (1, 1, 'Mötets öppnande', NULL),
    (1, 2, 'Bokningsapp', 'Styrelsen beslutar att införa bokningsappen.'),
    (2, 1, 'Mötets öppnande', NULL),
    (2, 2, 'Bastu', 'Bastun renoveras under hösten.');

INSERT INTO meeting_adjusters (meeting, user, adjusted_at) VALUES
    (1, 4, '2026-09-10 08:00:00'), (1, 7, '2026-09-11 19:00:00'),
    (2, 4, '2026-10-08 08:00:00'), (2, 7, NULL);
```

**Frågor**

```sql
-- Närvaroprocent per person under 2026
SELECT u.name,
       COUNT(*)                                     AS kallad,
       SUM(ma.attended)                             AS narvarande,
       ROUND(100.0 * SUM(ma.attended) / COUNT(*))   AS procent
FROM meeting_attendees ma
JOIN meetings m ON m.id = ma.meeting
JOIN users    u ON u.id = ma.user
WHERE ma.invited = 1
  AND m.held_at >= '2026-01-01' AND m.held_at < '2027-01-01'
GROUP BY u.id, u.name
ORDER BY procent DESC, u.name;
```

| name | kallad | narvarande | procent |
|------|--------|------------|---------|
| Anna Andersson | 2 | 2 | 100.0 |
| David Dahl | 2 | 2 | 100.0 |
| Gunilla Gran | 2 | 1 | 50.0 |

```sql
-- Är protokollen justerade? (Räknas fram – sparas inte!)
SELECT m.id, m.held_at,
       COUNT(ad.user)        AS justerare,
       COUNT(ad.adjusted_at) AS har_justerat,
       CASE WHEN COUNT(ad.user) = 2 AND COUNT(ad.adjusted_at) = 2
            THEN 'Justerat' ELSE 'Ej justerat' END AS status
FROM meetings m
LEFT JOIN meeting_adjusters ad ON ad.meeting = m.id
GROUP BY m.id, m.held_at;
```

**Motivering och val**

- **3NF:** Varje kolumn beror på sin tabells nyckel och inget annat. Medlemmarnas
  namn finns bara i `users`. Paragrafer, närvaro och justering ligger i egna
  tabeller i stället för som listor i `meetings` (1NF).
- **Unika paragrafnummer:** `UNIQUE (meeting, number)` – samma nummer får finnas
  på olika möten men inte två gånger på samma möte.
- **Ordförande/sekreterare som kolumner** eftersom det är *exakt en* av varje per
  möte. Alternativet – en kolumn `role` i `meeting_attendees` – är också rimligt
  men gör det svårare att garantera "exakt en ordförande".
- **"Protokollet är justerat"** sparas inte som en egen kolumn: det är ett
  härlett värde som räknas fram från `meeting_adjusters`.
- **Exakt två justerare** går inte att uttrycka med enkla villkor. Det kontrolleras
  i backend (hook) eller med en trigger.
- `ON DELETE RESTRICT` på justerare: man ska inte kunna radera en medlem som
  justerat ett protokoll utan att tänka efter (protokoll är juridiska dokument).

### C.2 – Kö till parkeringsplatser

**Entiteter, relationer och val**

| Entitet | Attribut |
|---------|----------|
| `parking_spaces` | `number`, `has_charger`, `monthly_fee_ore` |
| `parking_leases` (uthyrningar) | `space`, `apartment`, `monthly_fee_ore`, `start_date`, `end_date` |
| `parking_queue` | `apartment`, `queued_at`, `wants_charger`, `left_at`, `left_reason` |

| Relation | Kardinalitet |
|----------|--------------|
| `parking_spaces` – `parking_leases` | 1 : N (en plats har många uthyrningar över tid) |
| `apartments` – `parking_leases` | 1 : N |
| `apartments` – `parking_queue` | 1 : N över tid, men högst **en aktiv** köplats per lägenhet |
| `parking_spaces` – `apartments` | N : M över tid, via `parking_leases` (kopplingstabell med egna attribut) |

```
apartments ┼──○< parking_leases >○──┼ parking_spaces
     ┼
     └────○< parking_queue
```

- **Lägenheten** hyr platsen och står i kön, inte medlemmen – så står det i
  beskrivningen, och det fungerar när en medlem i hushållet flyttar.
- **Köplacering räknas fram** med `ROW_NUMBER()` över `queued_at`. Sparar man
  "nummer 3" måste alla efter ändras när någon lämnar kön – en klassisk
  uppdateringsanomali.
- **Pengar i öre** som heltal.
- **Avgiften kopieras till uthyrningen** – medveten denormalisering: priset på en
  gammal uthyrning ska inte ändras när avgiften höjs.
- **Historik** genom att aldrig ta bort uthyrningar, utan sätta `end_date`.
  `end_date IS NULL` = pågående.

**SQL**

```sql
PRAGMA foreign_keys = ON;

CREATE TABLE parking_spaces (
    id               INTEGER PRIMARY KEY,
    number           INTEGER NOT NULL UNIQUE CHECK (number > 0),
    has_charger      INTEGER NOT NULL DEFAULT 0 CHECK (has_charger IN (0, 1)),
    monthly_fee_ore  INTEGER NOT NULL CHECK (monthly_fee_ore >= 0)
);

CREATE TABLE parking_leases (
    id               INTEGER PRIMARY KEY,
    space            INTEGER NOT NULL REFERENCES parking_spaces(id) ON DELETE RESTRICT,
    apartment        INTEGER NOT NULL REFERENCES apartments(id)     ON DELETE RESTRICT,
    monthly_fee_ore  INTEGER NOT NULL CHECK (monthly_fee_ore >= 0),
    start_date       TEXT    NOT NULL,                  -- 'YYYY-MM-DD'
    end_date         TEXT,                              -- NULL = pågående
    CHECK (end_date IS NULL OR end_date > start_date)
);
-- En plats kan bara ha EN pågående uthyrning (partiellt unikt index)
CREATE UNIQUE INDEX idx_leases_active_space
    ON parking_leases(space) WHERE end_date IS NULL;
CREATE INDEX idx_leases_apartment ON parking_leases(apartment);

CREATE TABLE parking_queue (
    id             INTEGER PRIMARY KEY,
    apartment      INTEGER NOT NULL REFERENCES apartments(id) ON DELETE CASCADE,
    queued_at      TEXT    NOT NULL DEFAULT (datetime('now')),
    wants_charger  INTEGER NOT NULL DEFAULT 0 CHECK (wants_charger IN (0, 1)),
    left_at        TEXT,                                -- NULL = står i kön
    left_reason    TEXT CHECK (left_reason IN ('got_space', 'withdrew')),
    CHECK ((left_at IS NULL) = (left_reason IS NULL))   -- båda eller ingen
);
-- En lägenhet kan bara stå i kön en gång åt gången
CREATE UNIQUE INDEX idx_queue_active_apartment
    ON parking_queue(apartment) WHERE left_at IS NULL;

-- Testdata
INSERT INTO parking_spaces (number, has_charger, monthly_fee_ore) VALUES
    (1, 1, 75000), (2, 0, 50000), (3, 0, 50000);

INSERT INTO parking_leases (space, apartment, monthly_fee_ore, start_date, end_date) VALUES
    (1, 7, 70000, '2024-01-01', '2025-12-31'),   -- gammal uthyrning, gammalt pris
    (1, 6, 75000, '2026-01-01', NULL),
    (2, 3, 50000, '2025-05-01', NULL),
    (3, 1, 50000, '2025-08-01', NULL);

INSERT INTO parking_queue (apartment, queued_at, wants_charger, left_at, left_reason) VALUES
    (5, '2025-03-14 10:00:00', 1, NULL, NULL),
    (8, '2025-06-02 18:30:00', 0, NULL, NULL),
    (2, '2024-11-20 09:00:00', 0, '2025-05-01 00:00:00', 'withdrew'),
    (4, '2026-02-01 12:00:00', 0, NULL, NULL);
```

**Frågor**

```sql
-- Kön i ordning, med placering (räknad, inte sparad)
SELECT ROW_NUMBER() OVER (ORDER BY q.queued_at) AS placering,
       a.number AS lagenhet,
       q.queued_at,
       CASE q.wants_charger WHEN 1 THEN 'ja' ELSE 'nej' END AS vill_ha_laddplats
FROM parking_queue q
JOIN apartments a ON a.id = q.apartment
WHERE q.left_at IS NULL
ORDER BY placering;
```

| placering | lagenhet | queued_at | vill_ha_laddplats |
|-----------|----------|-----------|-------------------|
| 1 | 1201 | 2025-03-14 10:00:00 | ja |
| 2 | 1302 | 2025-06-02 18:30:00 | nej |
| 3 | 1102 | 2026-02-01 12:00:00 | nej |

```sql
-- Lediga platser just nu
SELECT s.number, s.has_charger, s.monthly_fee_ore / 100.0 AS avgift_kr
FROM parking_spaces s
WHERE NOT EXISTS (
    SELECT 1 FROM parking_leases l
    WHERE l.space = s.id AND l.end_date IS NULL
);
```

(Ger inga rader med testdatan – alla tre platser är uthyrda.)

```sql
-- Försök hyra ut plats 2 en gång till → fel tack vare det partiella indexet
INSERT INTO parking_leases (space, apartment, monthly_fee_ore, start_date)
VALUES (2, 5, 50000, '2026-11-01');
-- Runtime error: UNIQUE constraint failed: parking_leases.space
```

**Motivering**

- **3NF:** Platsens egenskaper finns bara i `parking_spaces`, lägenhetens bara i
  `apartments`. Enda medvetna avsteget är `monthly_fee_ore` i `parking_leases`,
  som är *historisk* data (priset vid uthyrningstillfället) och därför inte en
  kopia som ska hållas synkad.
- **Inga dubbla uthyrningar:** det partiella unika indexet
  `... WHERE end_date IS NULL` gör att en plats bara kan ha en pågående uthyrning.
  Det skyddar inte mot överlapp i *historiska* perioder – det får en hook eller
  trigger kontrollera, men det är sällan ett praktiskt problem.
- **Lämna kön** görs med `left_at` + `left_reason` (soft delete) så att föreningen
  kan se historik ("hur länge fick man vänta?"). Hade historiken inte behövts hade
  en vanlig `DELETE` räckt.
- När en lägenhet får en plats görs två ändringar – ny rad i `parking_leases` och
  `left_at` i `parking_queue` – i **samma transaktion** (atomicitet!).

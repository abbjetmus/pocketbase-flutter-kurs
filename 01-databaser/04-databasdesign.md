# Kapitel 4 – Databasdesign

> **Mål med kapitlet:** Du ska kunna gå från en beskrivning i vanlig text till en
> genomtänkt datamodell: hitta entiteter, attribut och relationer, bestämma
> kardinalitet, rita ett ER-diagram och normalisera. Du ska också kunna fatta
> medvetna beslut om nycklar, datatyper, `NULL`, index och borttagning.

En databas är svår att ändra när den väl är full av data och flera appar
använder den. Ett par timmars eftertanke i början sparar veckor senare.

## 4.1 Designprocessen

```
  ┌───────────────┐   ┌───────────────┐   ┌───────────────┐   ┌───────────────┐   ┌───────────────┐
  │ 1. Entiteter  │──►│ 2. Attribut   │──►│ 3. Relationer │──►│ 4. Normalisera│──►│ 5. Villkor,   │
  │  (substantiv) │   │ (egenskaper)  │   │ & kardinalitet│   │  (1NF–3NF)    │   │ typer, index  │
  └───────────────┘   └───────────────┘   └───────────────┘   └───────────────┘   └───────────────┘
```

Vi går igenom stegen med Föreningsappen. Utgångspunkten är styrelsens
önskemål, skrivet i vanlig text:

> *"Föreningen har ett antal **lägenheter**. **Medlemmar** bor i lägenheterna och
> loggar in med e-post. Medlemmar ska kunna **boka** tvättstugor och festlokalen –
> vi kallar dem **resurser**. En resurs kan bara bokas ett visst antal timmar åt
> gången. Styrelsen ska kunna skriva **anslag** som alla kan läsa."*

### Steg 1: Entiteter – leta efter substantiv

En **entitet** är en "sak" som du vill spara information om och som har en egen
identitet. Ett bra knep är att stryka under substantiven i texten:

| Substantiv | Entitet? | Motivering |
|------------|----------|------------|
| lägenhet | ✅ `apartments` | Har egna egenskaper (nummer, våning, storlek) |
| medlem | ✅ `users` | Loggar in, gör saker |
| resurs (tvättstuga, festlokal) | ✅ `resources` | Bokas, har egna regler |
| bokning | ✅ `bookings` | En händelse med egen tid och egna data |
| anslag | ✅ `posts` | Har titel, text, författare |
| e-post | ❌ attribut | En egenskap hos en medlem |
| timmar | ❌ attribut | `max_hours` på en resurs |
| styrelsen | ❌ attribut (just nu) | En **roll** en medlem har – `role = 'board'` |

💡 **Tips:** Om något bara har *ett* värde och inga egna egenskaper är det ofta ett
attribut. Börjar du vilja spara saker *om* det (t.ex. styrelsens mötesdatum) kan
det behöva bli en egen entitet.

### Steg 2: Attribut

För varje entitet: vilka egenskaper behöver vi? Fråga dig *"vad ska appen visa,
söka på eller räkna med?"*

| Entitet | Attribut |
|---------|----------|
| `apartments` | `number`, `floor`, `size_sqm` |
| `users` | `email`, `name`, `role` (+ lösenord, som PocketBase sköter) |
| `resources` | `name`, `description`, `max_hours`, `active` |
| `bookings` | `start`, `end`, `note` |
| `posts` | `title`, `body`, `published`, `created` |

### Steg 3: Relationer och kardinalitet

Nu frågar vi hur entiteterna hänger ihop, och **hur många** av varje som kan höra
ihop – det kallas **kardinalitet**. Ställ alltid frågan *åt båda hållen*:

- *En lägenhet* kan ha *hur många* medlemmar? → **många** (ett par, en familj).
- *En medlem* kan bo i *hur många* lägenheter? → **en** (i vår app).
- ⇒ apartments **1 : N** users.

| Typ | Betydelse | Exempel | Hur det lagras |
|-----|-----------|---------|----------------|
| **1 : 1** | En till en | En medlem ↔ en medlemsprofil med extra uppgifter | FK med `UNIQUE` i ena tabellen (eller samma tabell) |
| **1 : N** | En till många | En resurs ↔ många bokningar | FK på **N**-sidan: `bookings.resource` |
| **N : M** | Många till många | Medlemmar ↔ styrelsemöten de deltagit i | **Kopplingstabell** med två FK |

### 1:N – främmande nyckel på "många"-sidan

```
resources (1) ─────────< (N) bookings
                              └─ resource INTEGER REFERENCES resources(id)
```

Försök aldrig lägga det åt andra hållet, med en lista av boknings-id:n i
`resources`. Mer om det i avsnitt 4.9.

### N:M – kopplingstabell

Säg att föreningen vill kunna märka anslag med **taggar** ("Tvättstuga",
"Ekonomi", "Stämma"). Ett anslag kan ha många taggar och en tagg kan sitta på
många anslag. Det går inte att lösa med en främmande nyckel i någon av tabellerna.
Lösningen är en tredje tabell, en **kopplingstabell** (*junction table*):

```
posts (1) ───< (N) post_tags (N) >─── (1) tags

┌──────────┐      ┌───────────────┐      ┌──────────┐
│  posts   │      │   post_tags   │      │   tags   │
│──────────│      │───────────────│      │──────────│
│ id    PK │◄─────│ post   FK     │      │ id    PK │
│ title    │      │ tag    FK     │─────►│ name     │
│ …        │      │ PK(post, tag) │      └──────────┘
└──────────┘      └───────────────┘
```

```sql
CREATE TABLE tags (
    id    INTEGER PRIMARY KEY,
    name  TEXT NOT NULL UNIQUE
);

CREATE TABLE post_tags (
    post  INTEGER NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    tag   INTEGER NOT NULL REFERENCES tags(id)  ON DELETE CASCADE,
    PRIMARY KEY (post, tag)          -- samma tagg kan inte sättas två gånger
);
CREATE INDEX idx_post_tags_tag ON post_tags(tag);

INSERT INTO tags (name) VALUES ('Tvättstuga'), ('Stämma'), ('Gården');
INSERT INTO post_tags (post, tag) VALUES (2, 3), (4, 2), (5, 1);

-- Alla anslag med taggen 'Stämma'
SELECT p.title
FROM posts p
JOIN post_tags pt ON pt.post = p.id
JOIN tags t       ON t.id = pt.tag
WHERE t.name = 'Stämma';
```

Lägg märke till att `bookings` faktiskt också är en sorts kopplingstabell mellan
`users` och `resources` (medlemmar ↔ resurser är N:M) – fast med egna attribut
(`start`, `end`, `note`). Det är väldigt vanligt: kopplingen i sig är en händelse
med egen data.

💡 **Tips:** I PocketBase gör man N:M med ett *Relation*-fält som tillåter flera
värden. Det lagras som en JSON-lista i en kolumn – praktiskt, men bakom kulisserna
en annan lösning än en kopplingstabell. Vill du ha extra data på kopplingen (t.ex.
"närvarande: ja/nej") behöver du ändå en egen collection för kopplingen.

## 4.2 ER-diagram

Ett **ER-diagram** (*Entity–Relationship*) visar entiteter, attribut och
relationer. Det finns flera notationer. Den vanligaste i praktiken är
**kråkfotsnotation** (*crow's foot*):

```
  ──┼──   exakt en               ──○┼──  noll eller en
  ──<     många                  ──○<    noll eller många
  ──┼<    en eller många
```

Föreningsappen:

```
┌──────────────┐           ┌──────────────┐            ┌──────────────┐
│  apartments  │           │    users     │            │    posts     │
│──────────────│           │──────────────│            │──────────────│
│ PK id        │┼○──────○< │ PK id        │┼○──────○<  │ PK id        │
│    number  U │           │    email   U │            │    title     │
│    floor     │           │    name      │            │    body      │
│    size_sqm  │           │ FK apartment │            │ FK author    │
└──────────────┘           │    role      │            │    published │
                           │    created   │            │    created   │
                           └──────┬───────┘            └──────────────┘
                                  ┼
                                  │
                                  ○<
                           ┌──────┴───────┐            ┌──────────────┐
                           │   bookings   │            │  resources   │
                           │──────────────│            │──────────────│
                           │ PK id        │ >○──────┼  │ PK id        │
                           │ FK resource  │            │    name    U │
                           │ FK user      │            │   description│
                           │    start     │            │    max_hours │
                           │    end       │            │    active    │
                           │    note      │            └──────────────┘
                           └──────────────┘

PK = primärnyckel, FK = främmande nyckel, U = unik
```

Läs t.ex. linjen mellan `apartments` och `users`: en medlem hör till *noll eller
en* lägenhet (`apartment` kan vara `NULL`), och en lägenhet har *noll eller många*
medlemmar.

💡 **Tips:** Rita gärna på papper eller använd verktyg som
[dbdiagram.io](https://dbdiagram.io) eller [drawio](https://app.diagrams.net).
Ett ER-diagram är också det bästa sättet att diskutera en design med andra.

## 4.3 Normalisering

**Normalisering** är en metod för att ta bort upprepning (redundans) och därmed
risken att samma sak står olika på olika ställen. Man pratar om *normalformer*.
I praktiken räcker de tre första.

Vi utgår från styrelsens gamla bokningsark:

| booking | resource | resource_max_hours | member | member_email | apartment | floor | times |
|---------|----------|--------------------|--------|--------------|-----------|-------|-------|
| 1 | Tvättstuga 1 | 3 | Anna Andersson | anna@example.com | 1101 | 1 | 2026-10-12 07–10, 2026-10-14 16–19 |
| 2 | Tvättstuga 1 | 3 | Cecilia Carlsson | cecilia@example.com | 1001 | 0 | 2026-10-12 10–13 |
| 3 | Festlokalen | 12 | David Dahl | david@example.com | 1002 | 0 | 2026-10-17 15–23 |
| 4 | Tvättstuga 1 | **4** | Anna Andersson | **anna@exmaple.com** | 1101 | 1 | 2026-10-16 07–10 |

Problemen syns redan: Annas e-post är felstavad på rad 4, och tvättstuga 1 har
plötsligt `max_hours = 4`. Vilken är rätt? Det här är **uppdateringsanomalier**:

| Anomali | Exempel |
|---------|---------|
| **Uppdatering** | Anna byter e-post → måste ändras på alla hennes rader. Missas en blir det motsägelser. |
| **Insättning** | Vi kan inte lägga in en ny resurs (t.ex. bastun) förrän någon har bokat den. |
| **Borttagning** | Tar vi bort Davids enda bokning försvinner all info om att lägenhet 1002 ligger på plan 0. |

### Första normalformen (1NF): ett värde per cell

> **Regel:** Varje cell innehåller ett **enda, odelbart** värde. Inga listor,
> inga upprepade kolumner (`time1`, `time2`, `time3`). Varje rad är unik.

Kolumnen `times` bryter mot 1NF – den innehåller en lista. Vi delar upp den så
att varje bokat pass blir en egen rad, och delar `start`/`end` i separata kolumner:

| resource | resource_max_hours | member | member_email | apartment | floor | start | end |
|----------|--------------------|--------|--------------|-----------|-------|-------|-----|
| Tvättstuga 1 | 3 | Anna Andersson | anna@example.com | 1101 | 1 | 2026-10-12 07:00 | 2026-10-12 10:00 |
| Tvättstuga 1 | 3 | Anna Andersson | anna@example.com | 1101 | 1 | 2026-10-14 16:00 | 2026-10-14 19:00 |
| Tvättstuga 1 | 3 | Cecilia Carlsson | cecilia@example.com | 1001 | 0 | 2026-10-12 10:00 | 2026-10-12 13:00 |
| Festlokalen | 12 | David Dahl | david@example.com | 1002 | 0 | 2026-10-17 15:00 | 2026-10-17 23:00 |
| Tvättstuga 1 | 3 | Anna Andersson | anna@example.com | 1101 | 1 | 2026-10-16 07:00 | 2026-10-16 10:00 |

Nu är tabellen i 1NF. En rad identifieras av `(resource, start)`. Men upprepningen
är ännu värre!

### Andra normalformen (2NF): hela nyckeln

> **Regel:** 1NF + varje kolumn som inte ingår i nyckeln ska bero på **hela**
> nyckeln, inte bara en del av den.

Nyckeln är `(resource, start)`. Men `resource_max_hours` beror bara på
`resource` – inte på `start`. Det är ett **partiellt beroende**. Lösning: flytta
ut det som bara beror på resursen till en egen tabell.

```
resources                          bookings_2nf
┌──────────────┬───────────┐      ┌──────────────┬──────────────────┬───────────────┬─────┐
│ name (PK)    │ max_hours │      │ resource     │ start            │ member        │ ... │
├──────────────┼───────────┤      ├──────────────┼──────────────────┼───────────────┼─────┤
│ Tvättstuga 1 │ 3         │      │ Tvättstuga 1 │ 2026-10-12 07:00 │ Anna Andersson│ ... │
│ Festlokalen  │ 12        │      │ ...          │                  │               │     │
└──────────────┴───────────┘      └──────────────┴──────────────────┴───────────────┴─────┘
```

`max_hours` står nu på exakt ett ställe.

💡 **Tips:** 2NF är bara intressant när nyckeln består av flera kolumner. Har
tabellen en enkel `id`-nyckel är den automatiskt i 2NF (om den är i 1NF) – men
läs vidare, för då flyttar problemet till 3NF.

### Tredje normalformen (3NF): inga transitiva beroenden

> **Regel:** 2NF + kolumner som inte är nyckel får inte bero på **andra** kolumner
> som inte är nyckel. "Varje kolumn ska bero på nyckeln, hela nyckeln och inget
> annat än nyckeln."

I `bookings_2nf` gäller: bokning → `member` → `member_email` och
`member` → `apartment` → `floor`. E-posten beror på medlemmen, inte på bokningen.
Våningen beror på lägenheten. Det är **transitiva beroenden**.

Lösning: bryt ut `users` och `apartments`, och låt bokningen bara peka på
medlemmen med en främmande nyckel. Vi inför samtidigt `id`-kolumner:

```
apartments                users                              resources
┌────┬────────┬───────┐   ┌────┬──────────────────┬───────┐   ┌────┬──────────────┬───────────┐
│ id │ number │ floor │   │ id │ name             │ apart.│   │ id │ name         │ max_hours │
├────┼────────┼───────┤   ├────┼──────────────────┼───────┤   ├────┼──────────────┼───────────┤
│ 1  │ 1001   │ 0     │   │ 1  │ Anna Andersson   │ 3     │   │ 1  │ Tvättstuga 1 │ 3         │
│ 2  │ 1002   │ 0     │   │ 3  │ Cecilia Carlsson │ 1     │   │ 3  │ Festlokalen  │ 12        │
│ 3  │ 1101   │ 1     │   │ 4  │ David Dahl       │ 2     │   └────┴──────────────┴───────────┘
└────┴────────┴───────┘   └────┴──────────────────┴───────┘
                                       (+ email)
bookings
┌────┬──────────┬──────┬──────────────────┬──────────────────┐
│ id │ resource │ user │ start            │ end              │
├────┼──────────┼──────┼──────────────────┼──────────────────┤
│ 1  │ 1        │ 1    │ 2026-10-12 07:00 │ 2026-10-12 10:00 │
│ 7  │ 1        │ 1    │ 2026-10-14 16:00 │ 2026-10-14 19:00 │
│ 2  │ 1        │ 3    │ 2026-10-12 10:00 │ 2026-10-12 13:00 │
│ 4  │ 3        │ 4    │ 2026-10-17 15:00 │ 2026-10-17 23:00 │
│ 12 │ 1        │ 1    │ 2026-10-16 07:00 │ 2026-10-16 10:00 │
└────┴──────────┴──────┴──────────────────┴──────────────────┘
```

Och vips – vi har landat i precis Föreningsappens datamodell. Alla tre
anomalierna är borta:

| Anomali | Efter normalisering |
|---------|---------------------|
| Anna byter e-post | En rad i `users` ändras |
| Ny resurs utan bokningar | En rad i `resources` |
| Davids enda bokning tas bort | Lägenhet 1002 finns kvar i `apartments` |

💡 **Tips:** En snabb tumregel för 3NF: *"Om jag ändrar det här värdet, måste jag
då ändra det på flera rader?"* Om ja – bryt ut det i en egen tabell.

### När ska man denormalisera?

**Denormalisering** betyder att man medvetet lägger in upprepad eller härledd data
för att vinna prestanda eller enkelhet. Det är okej – men gör det medvetet och
med en plan för hur datan hålls synkad.

| Situation | Exempel | Varför det kan vara okej |
|-----------|---------|--------------------------|
| Historik som *inte* ska ändras | Spara `price_ore` på bokningen i stället för att alltid läsa resursens nuvarande pris | Priset på en gammal bokning ska inte ändras när avgiften höjs |
| Tunga beräkningar som läses ofta | `comment_count` på ett anslag | Slipper räkna alla kommentarer vid varje listvisning |
| Rapporter/statistik | En separat sammanställningstabell per månad | Rapporter ska inte belasta den vanliga databasen |

⚠️ **Varning:** Börja alltid normaliserat. Denormalisera först när du har ett
*mätt* prestandaproblem. Det är mycket lättare att lägga till en kopia senare än
att städa upp i inkonsekvent data.

## 4.4 Välja nycklar

### Surrogatnyckel eller naturlig nyckel?

| | Naturlig nyckel | Surrogatnyckel |
|---|-----------------|----------------|
| Vad | Ett värde som finns "på riktigt" | Ett påhittat id utan betydelse |
| Exempel | `email`, personnummer, lägenhetsnummer | `id = 17`, `id = 'k3j9x0p2m1q8w7e'` |
| Fördel | Ingen extra kolumn, betyder något | Ändras aldrig, alltid unik, kort |
| Nackdel | Kan ändras (folk byter e-post!), kan vara känsligt (personnummer) | Måste joinas för att få något läsbart |

**Rekommendation:** Använd en surrogatnyckel (`id`) som primärnyckel, och lägg
`UNIQUE` på de naturliga nycklarna. Det är precis vad vi gör med `users.email`
och `apartments.number`.

### Auto-increment eller UUID?

| | `INTEGER` auto-increment | UUID / slumpad sträng |
|---|--------------------------|------------------------|
| Exempel | `1, 2, 3, …` | `'550e8400-e29b-41d4-a716-446655440000'` |
| Storlek | Liten, snabb | Större |
| Läsbarhet | Lätt att prata om ("bokning 5") | Svårt |
| Kan gissas? | Ja – `/bookings/6` ligger nog efter `/bookings/5` | Nej |
| Kan skapas i appen (offline)? | Nej, databasen delar ut | Ja |
| Sammanslagning av databaser | Krockar | Krockar (praktiskt taget) aldrig |

PocketBase använder slumpade 15-teckens id:n som `k3j9x0p2m1q8w7e` – i praktiken
samma idé som UUID. I seed-skriptet använder vi heltal för att det är lättare att
läsa och skriva för hand.

⚠️ **Varning:** Att id:n går att gissa är ingen säkerhetsbrist i sig, men du får
aldrig lita på att "ingen vet id:t". Behörighet ska alltid kontrolleras
(i PocketBase: API rules).

## 4.5 Namnkonventioner

Det viktigaste är att vara **konsekvent**. I den här kursen gäller:

| Regel | Exempel | Inte |
|-------|---------|------|
| `snake_case` | `size_sqm`, `max_hours` | `sizeSqm`, `MaxHours` |
| Engelska namn | `bookings`, `published` | `bokningar`, `publicerad` |
| Tabeller i plural | `users`, `resources` | `user`, `resource` |
| Primärnyckel heter `id` | `id` | `user_id` i `users`-tabellen |
| FK heter som det den pekar på (singular) | `bookings.user`, `posts.author` | `bookings.users` |
| Enhet i namnet när det inte är självklart | `size_sqm`, `price_ore`, `duration_min` | `size`, `price` |
| Booleans som påståenden | `active`, `published`, `is_paid` | `status2`, `flag` |
| Undvik reserverade ord | `starts_at` | `start`, `end`, `order`, `user`, `group` |

💡 **Tips:** Många projekt döper främmande nycklar till `user_id`, `resource_id`
osv. Det är också en bra konvention. Vi använder `user`, `resource` eftersom det
är så PocketBase-relationer brukar heta. Huvudsaken är att man väljer *en* stil.

⚠️ **Varning:** Som tabellen visar är `start`, `end` och `user` egentligen dåliga
kolumnnamn – de är reserverade ord i SQL (`user` är reserverat i PostgreSQL).
Vi behåller dem i kursen eftersom det är kursens datamodell och PocketBase
hanterar det åt oss, men i en ny design skulle `starts_at` och `ends_at` vara
bättre.

## 4.6 Datatyper – välj rätt

### Datum och tid: UTC och ISO 8601

- Spara **alltid i UTC** (svensk tid är UTC+1 på vintern och UTC+2 på sommaren).
  Konvertera till lokal tid först när du visar det för användaren.
- Använd formatet **ISO 8601**: `2026-10-12 07:00:00` eller `2026-10-12T07:00:00Z`.
  Det är entydigt (inte "10/12" – oktober eller december?) och sorteras rätt som text.

```sql
SELECT datetime('now');                              -- nu, i UTC
SELECT datetime('now', 'localtime');                 -- nu, i datorns lokala tid
SELECT date('2026-10-12 07:00:00', '+7 days');       -- 2026-10-19
SELECT (unixepoch('2026-10-17 23:00:00')
      - unixepoch('2026-10-17 15:00:00')) / 3600.0 AS timmar;   -- 8.0
```

`unixepoch()` ger antal sekunder sedan 1970-01-01 (finns från SQLite 3.38). Har du
en äldre version, använd `strftime('%s', ...)` i stället.

⚠️ **Varning:** Ett klassiskt fel är att spara lokal tid utan tidszon. Två gånger
om året (sommartid) blir det då en timme som finns två gånger, eller inte alls.

### Pengar: heltal i öre

Spara **aldrig** pengar som flyttal (`REAL`). Flyttal kan inte representera alla
decimaltal exakt:

```sql
SELECT 0.1 + 0.2;                 -- 0.30000000000000004 😱
SELECT 10 + 20 AS ore;            -- 30 (exakt)
```

Spara i stället i **minsta enheten som heltal**: `price_ore INTEGER`,
`12950` = 129,50 kr. Dela med 100 först när du visar beloppet. (PostgreSQL har även
den exakta typen `numeric(10,2)`.)

### Booleans

SQLite saknar `BOOLEAN`. Använd `INTEGER` med `CHECK (x IN (0, 1))` och
`NOT NULL DEFAULT 0` (eller `1`), som `resources.active` och `posts.published`.

### Text med fasta val (enum)

Använd `TEXT` + `CHECK (... IN (...))`, som `users.role`. Om listan ofta ändras
eller behöver egna egenskaper – gör en egen tabell i stället.

## 4.7 NULL eller standardvärde?

`NULL` betyder **"okänt" eller "saknas"** – inte "noll" och inte "tom sträng".

| Kolumn | NULL tillåtet? | Varför |
|--------|----------------|--------|
| `bookings.note` | ✅ | Det är frivilligt att skriva en anteckning |
| `users.apartment` | ✅ | En medlem kan sakna kopplad lägenhet (t.ex. Johan) |
| `resources.active` | ❌ `NOT NULL DEFAULT 1` | En resurs är alltid antingen aktiv eller inte |
| `users.role` | ❌ `NOT NULL DEFAULT 'member'` | Alla har en roll |
| `bookings.start` | ❌ `NOT NULL` | En bokning utan tid är meningslös |

Tumregler:

- **Gör kolumner `NOT NULL` som standard.** Tillåt `NULL` bara när "saknas" är ett
  verkligt, meningsfullt tillstånd.
- Använd `DEFAULT` när det finns ett naturligt utgångsvärde.
- Blanda inte ihop "saknas" (`NULL`) och "tom" (`''`) – välj ett av dem.

⚠️ **Varning:** `NULL` beter sig konstigt i jämförelser: `NULL = NULL` är inte sant,
`COUNT(kolumn)` hoppar över `NULL`, och `NOT IN` med en `NULL` i listan ger inga
rader. Ju färre `NULL`, desto färre överraskningar.

## 4.8 Villkor, index och borttagning

### Villkor som skydd

Lägg affärsregler i databasen där det går. Appen kan ha buggar, men villkoren
gäller alltid – oavsett om datan kommer från appen, adminpanelen eller ett skript.

```sql
-- utdrag ur CREATE TABLE-satser
CHECK (size_sqm > 0)
CHECK ("end" > "start")
CHECK (role IN ('member', 'board', 'admin'))
email TEXT NOT NULL UNIQUE
```

### Index

- Skapa index på **främmande nycklar** – de används i nästan varje `JOIN`.
  (SQLite och PostgreSQL skapar inte det automatiskt!)
- Skapa index på kolumner du ofta **filtrerar** eller **sorterar** på, t.ex.
  `bookings(resource, "start")` för "visa tvättstugans schema".
- Låt bli att indexera allt. Varje index kostar vid skrivning.

### Soft delete eller hard delete?

| | Hard delete | Soft delete |
|---|-------------|-------------|
| Hur | `DELETE FROM posts WHERE id = 3;` | `UPDATE posts SET deleted_at = datetime('now') WHERE id = 3;` |
| Data | Borta för alltid | Ligger kvar, döljs |
| Fördel | Enkelt, inga spöken, bra för integritet (GDPR) | Går att ångra, historik bevaras |
| Nackdel | Går inte att ångra | **Varje** fråga måste ha `WHERE deleted_at IS NULL`; `UNIQUE` krånglar till sig |

```sql
ALTER TABLE posts ADD COLUMN deleted_at TEXT;   -- NULL = inte borttagen
UPDATE posts SET deleted_at = datetime('now') WHERE id = 5;
SELECT id, title FROM posts WHERE deleted_at IS NULL;
```

💡 **Tips:** Använd hard delete som standard. Välj soft delete för data där
"ångra" eller historik verkligen behövs. Personuppgifter som någon begärt ska
raderas måste raderas på riktigt (GDPR).

### Audit-fält: created och updated

Lägg till `created` och `updated` på nästan alla tabeller. De kostar nästan
ingenting och är ovärderliga vid felsökning ("när ändrades den här bokningen?").

```sql
-- kolumner att lägga till i CREATE TABLE
created TEXT NOT NULL DEFAULT (datetime('now')),
updated TEXT NOT NULL DEFAULT (datetime('now'))
```

`updated` måste sättas vid varje ändring – i appen eller med en trigger.
PocketBase lägger till och sköter `created` och `updated` automatiskt.

## 4.9 Två klassiska misstag

### Misstag 1: lagra härledda värden

Spara inte det som kan räknas fram från annan data:

| Spara inte | Räkna i stället |
|------------|-----------------|
| `bookings.duration_hours` | `(unixepoch("end") - unixepoch("start")) / 3600.0` |
| `users.booking_count` | `SELECT COUNT(*) FROM bookings WHERE user = ?` |
| `users.age` | Spara `birth_date` och räkna |

Ett härlett värde kan bli **fel** så fort originaldatan ändras och någon glömmer
att uppdatera kopian. (Undantag: medveten denormalisering, se 4.3.)

### Misstag 2: kommaseparerade listor i en kolumn

```
resources (FEL!)
┌────┬──────────────┬───────────────────────┐
│ id │ name         │ booked_by             │
├────┼──────────────┼───────────────────────┤
│ 1  │ Tvättstuga 1 │ '1,3,2,1,5,7'         │
└────┴──────────────┴───────────────────────┘
```

Det här bryter mot 1NF och ger massor av problem:

- Du kan inte ha en främmande nyckel – `'1,3,99'` accepteras utan protest.
- Att hitta "alla resurser som medlem 1 bokat" kräver `LIKE '%1%'`, som även
  matchar 11, 21 och 100 – och kan inte använda index.
- Att ta bort ett värde ur listan kräver strängmanipulering.
- Det går inte att lägga till extra info per koppling (t.ex. tid).

Lösningen är alltid en egen tabell (1:N) eller en kopplingstabell (N:M).

## 4.10 Checklista: Bra att tänka på när du skapar tabeller

**Struktur**
- [ ] Varje tabell representerar **en** sorts sak (en entitet).
- [ ] Varje tabell har en primärnyckel – helst en surrogatnyckel `id`.
- [ ] Inga listor eller upprepade kolumner (`phone1`, `phone2`) – 1NF.
- [ ] Varje fakta finns på **ett** ställe – 2NF/3NF.
- [ ] 1:N-relationer har FK på N-sidan; N:M har en kopplingstabell.
- [ ] Inga härledda värden sparas (om du inte medvetet denormaliserar).

**Kolumner**
- [ ] Konsekventa namn: `snake_case`, engelska, tabeller i plural.
- [ ] Rätt datatyp: heltal för antal, `TEXT` i ISO 8601 (UTC) för tid, heltal i
      öre för pengar, `0/1` för booleans.
- [ ] Enhet i namnet när den inte är självklar (`size_sqm`, `price_ore`).
- [ ] `NOT NULL` som standard; `NULL` bara när "saknas" betyder något.
- [ ] Rimliga `DEFAULT`-värden.

**Skydd**
- [ ] `UNIQUE` på naturliga nycklar (e-post, lägenhetsnummer).
- [ ] `CHECK` för giltiga värden och intervall.
- [ ] `REFERENCES` på alla främmande nycklar, med genomtänkt `ON DELETE`.
- [ ] `PRAGMA foreign_keys = ON` i SQLite.

**Prestanda och drift**
- [ ] Index på främmande nycklar och kolumner som ofta filtreras/sorteras.
- [ ] `created` och `updated` på tabeller där ändringar är intressanta.
- [ ] Beslut om soft delete vs hard delete.
- [ ] Har du ritat ett ER-diagram och visat det för någon annan?

## 4.11 Sammanfattning

- Designprocessen: **entiteter → attribut → relationer & kardinalitet →
  normalisering → villkor, typer, index**.
- **1:N** = FK på många-sidan. **N:M** = kopplingstabell. **1:1** = FK med `UNIQUE`.
- **1NF**: ett värde per cell. **2NF**: beroende av hela nyckeln. **3NF**: inga
  beroenden mellan icke-nyckelkolumner.
- Denormalisera bara medvetet och när du har ett skäl.
- Surrogatnyckel som PK, `UNIQUE` på naturliga nycklar.
- Datum i UTC och ISO 8601, pengar som heltal i öre, booleans som 0/1.
- Lagra inte härledda värden och aldrig listor i en kolumn.

Nu är du redo för [övningarna](ovningar.md)! Efter det fortsätter vi med
[modul 02 – PocketBase](../02-pocketbase/), där samma modell blir collections.

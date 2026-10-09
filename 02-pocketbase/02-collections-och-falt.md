# 02 – Collections och fält

En **collection** är PocketBases motsvarighet till en tabell. I det här kapitlet
går vi igenom de tre sorternas collections, alla fälttyper, de vanligaste
fältinställningarna och hur allt blir SQL i SQLite.

## Tre typer av collections

När du klickar **+ New collection** i Dashboard får du välja typ högst upp i
panelen:

| Typ | Används till | I Föreningsappen |
|-----|--------------|------------------|
| **Base** | Vanlig data: skapa, läsa, ändra, ta bort | `apartments`, `resources`, `bookings`, `posts` |
| **Auth** | Användare som kan logga in. Har inbyggda fält för e-post, lösenord m.m. | `users` |
| **View** | Skrivskyddad collection som byggs av en SQL-`SELECT` | t.ex. `resource_stats` (antal bokningar per resurs) |

```
           ┌──────────────── Collection ────────────────┐
           │                                            │
     ┌─────┴─────┐          ┌─────┴─────┐         ┌─────┴─────┐
     │   base    │          │   auth    │         │   view    │
     │ CRUD-data │          │ base +    │         │ SELECT …  │
     │           │          │ inloggning│         │ bara läsa │
     └───────────┘          └───────────┘         └───────────┘
```

### Base

Standardtypen. Du väljer själv vilka fält som ska finnas. PocketBase lägger
alltid till `id`.

### Auth

En auth-collection är en base-collection med extra systemfält och extra
endpoints för inloggning:

| Systemfält | Betydelse |
|------------|-----------|
| `email` | E-postadress (unik) |
| `emailVisibility` | Om andra användare får se e-postadressen |
| `verified` | Om e-postadressen har verifierats |
| `password` | Lösenord (sparas som hash, skickas aldrig ut i API-svar) |
| `tokenKey` | Hemlig nyckel som gör att inloggningstoken kan ogiltigförklaras |

Collectionen `users` skapas automatiskt och är en auth-collection. Vi bygger
vidare på den i stället för att skapa en ny. Mer om inloggning i kapitel 4.

### View

En view-collection definieras av en SQL-fråga, precis som en `CREATE VIEW` i
modul 01. Den kan inte skrivas till och skickar inga realtidshändelser. Frågan
**måste** returnera en kolumn som heter `id`.

```sql
SELECT r.id, r.name, COUNT(b.id) AS bookings_count
FROM resources r
LEFT JOIN bookings b ON b.resource = r.id
GROUP BY r.id
```

PocketBase gissar fälttyperna utifrån frågan. I SQLite blir det bokstavligen en
vy:

```sql
CREATE VIEW `resource_stats` AS SELECT * FROM (SELECT r.id, r.name, ...);
```

Vi bygger den i övning 7.

## Systemfält: id, created, updated

| Fält | Typ | Beskrivning |
|------|-----|-------------|
| `id` | text (primärnyckel) | 15 tecken, `a-z0-9`, slumpas automatiskt. Kan inte tas bort. |
| `created` | autodate | Sätts när posten skapas |
| `updated` | autodate | Sätts när posten skapas och varje gång den ändras |

När du skapar en collection i Dashboard läggs `created` och `updated` till
automatiskt som fält av typen **autodate**. De är vanliga fält som du i princip
kan ta bort, men behåll dem – de är nästan alltid användbara (sortera anslag
på `-created`, visa "senast ändrad" osv.).

⚠️ **Varning:** Skapar du en collection via kod (migration i kapitel 7) läggs
`created`/`updated` **inte** till av sig själva. Då måste du lägga till två
autodate-fält uttryckligen.

## Alla fälttyper

I Dashboard klickar du **+ New field** i collection-panelen och väljer typ.

| Fälttyp | Lagrar | SQL-kolumn | Tomt värde | Använd till |
|---------|--------|------------|------------|-------------|
| `text` | Sträng | `TEXT` | `""` | Namn, titlar, korta texter, lägenhetsnummer |
| `editor` | HTML-text | `TEXT` | `""` | Formaterad brödtext, t.ex. `posts.body` |
| `number` | Tal (decimal) | `NUMERIC` | `0` | Våning, kvadratmeter, `max_hours` |
| `bool` | Sant/falskt | `BOOLEAN` | `false` | `active`, `published` |
| `email` | E-postadress | `TEXT` | `""` | Kontaktadress (inte inloggning – det sköter auth) |
| `url` | Webbadress | `TEXT` | `""` | Länk till föreningens hemsida |
| `date` | Datum + tid (UTC) | `TEXT` | `""` | `bookings.start`, `bookings.end` |
| `autodate` | Datum som sätts automatiskt | `TEXT` | – | `created`, `updated` |
| `select` | Ett eller flera värden från en fast lista | `TEXT` (enkel) / `JSON` (flera) | `""` / `[]` | `users.role` |
| `file` | Filnamn; själva filen ligger i `pb_data/storage` | `TEXT` / `JSON` | `""` / `[]` | Bild till anslag, avatar |
| `relation` | Id till post(er) i en annan collection | `TEXT` / `JSON` | `""` / `[]` | `bookings.resource`, `posts.author` |
| `json` | Godtycklig JSON | `JSON` | `null` | Fria inställningar, data du inte vill strukturera |
| `geoPoint` | `{"lon": .., "lat": ..}` | `JSON` | `{"lon":0,"lat":0}` | Föreningens position på en karta |
| `password` | Hashat lösenord | `TEXT` | `""` | Finns i auth-collections. Skapa sällan själv. |

### Hur väljer jag fälttyp?

```
Är det ett val från en fast lista (t.ex. roll, status)?  ──► select
Pekar det på en annan post?                              ──► relation
Är det ett datum/klockslag?                              ──► date (eller autodate)
Är det ett tal man räknar med eller jämför (>, <)?       ──► number
  ...men inte ett "nummer" som kan ha bokstäver/nollor
  först, t.ex. lägenhet "1001B" eller "0042"?             ──► text
Ja/nej?                                                  ──► bool
Formaterad text med rubriker och fetstil?                ──► editor
En uppladdad fil?                                        ──► file
Okänd struktur som varierar?                             ──► json (sista utväg)
```

💡 **Tips:** Lägenhetsnummer (`apartments.number`) är ett klassiskt exempel
på något som *heter* nummer men ska vara `text`. Lantmäteriets
lägenhetsnummer som `1001` räknar man aldrig med, och föreningar har ibland
nummer som `12A`.

⚠️ **Varning:** Använd inte `json` som genväg för att slippa designa. Det går
dåligt att filtrera och validera på innehållet, och du tappar de fördelar som
normaliseringen i [modul 01](../01-databaser/04-databasdesign.md) gav dig.

### Select: en eller flera

Ett select-fält har en lista med tillåtna värden. Inställningen **Max select**
(i Dashboard: *Single* / *Multiple*) avgör om fältet håller ett värde (sträng)
eller flera (lista).

```json
{ "role": "styrelse" }                // maxSelect = 1
{ "weekdays": ["mon", "wed", "fri"] } // maxSelect > 1
```

Försöker någon spara ett värde som inte finns i listan svarar PocketBase med
`400 Bad Request`. Det är som en `CHECK`-constraint i SQL.

### Date

Datum skickas och sparas som text i UTC:

```
2026-10-12 08:00:00.000Z
```

PocketBase accepterar även ISO-formatet `2026-10-12T08:00:00Z`. Appen ansvarar
för att översätta till svensk tid när datumet visas. `Z` betyder UTC, så
`08:00Z` är `10:00` svensk sommartid.

### File

Ett file-fält sparar bara filnamnet i databasen. Själva filen hamnar i
`pb_data/storage/<collection-id>/<post-id>/`. Viktiga inställningar:

| Inställning | Betydelse |
|-------------|-----------|
| Max select | En eller flera filer |
| Max size | Maxstorlek per fil i byte |
| Mime types | Tillåtna filtyper, t.ex. `image/jpeg`, `image/png` |
| Thumb sizes | Automatiska miniatyrer, t.ex. `200x200` |
| Protected | Filen kräver en särskild fil-token för att laddas ner |

Filer hämtas via `/api/files/<collection>/<post-id>/<filnamn>`.

## Fältinställningar

Varje fält har en kugghjulsikon i Dashboard med inställningar. De viktigaste:

| Inställning | Finns på | Effekt | Motsvarighet i SQL |
|-------------|----------|--------|--------------------|
| **Nonempty** (`required`) | alla | Värdet får inte vara tomt (`""`, `0`, `false`, `[]`) | `NOT NULL` + `CHECK (x <> '')` |
| **Min / Max length** | text, editor, password | Antal tecken | `CHECK (length(x) <= 200)` |
| **Pattern** | text, password | Reguljärt uttryck som värdet måste matcha | `CHECK (x REGEXP ...)` |
| **Min / Max** | number, date | Minsta/största värde | `CHECK (x BETWEEN ...)` |
| **No decimals** (`onlyInt`) | number | Bara heltal | `INTEGER` |
| **Max select** | select, file, relation | En eller flera | – |
| **Hidden** | alla | Fältet skickas aldrig ut i API-svar (bara superusers ser det) | – |
| **Presentable** | alla | Visas som etikett när posten visas i en relation i Dashboard | – |

⚠️ **Varning:** `required` på ett **number**-fält betyder att värdet inte får
vara `0`. Ett `bool`-fält med `required` måste vara `true`. Det överraskar de
flesta! Sätt alltså inte `required` på `active` eller `published` – då kan man
aldrig spara `false`.

### Pattern-exempel

| Fält | Pattern | Betyder |
|------|---------|---------|
| `apartments.number` | `^[0-9]{4}[A-Z]?$` | Fyra siffror, eventuellt en versal efter |
| `users.phone` | `^\+?[0-9 -]{7,20}$` | Telefonnummer |

## Unikt värde – med index

I PocketBase v0.23+ finns ingen "Unique"-kryssruta på själva fältet. Unikhet
gör man med ett **unikt index**, precis som i SQL.

**Så här i Dashboard:**

1. Öppna collectionen (kugghjulet).
2. Längst ner under fälten: klicka **+ New index**.
3. Kryssa i **Unique**.
4. Välj kolumn(er), t.ex. `number`.
5. Klicka **Set index** och sedan **Save changes**.

Resultatet är en vanlig SQL-sats:

```sql
CREATE UNIQUE INDEX idx_apartments_number ON apartments (number);
```

Försöker någon skapa två lägenheter med nummer `1001` svarar API:t:

```json
{
  "status": 400,
  "message": "Failed to create record.",
  "data": {
    "number": { "code": "validation_not_unique", "message": "Value must be unique." }
  }
}
```

### Index för snabbhet

Index är inte bara för unikhet. Som du lärde dig i modul 01 gör ett index att
databasen slipper läsa hela tabellen. Bokningar söks nästan alltid på resurs och
tid, så det är ett bra index:

```sql
CREATE INDEX idx_bookings_resource_start ON bookings (resource, start);
```

💡 **Tips:** Lägg index på fält som du ofta filtrerar eller sorterar på, och på
relationsfält. PocketBase skapar **inte** index på relationsfält automatiskt.

## Från SQL till collection – jämförelse

I modul 01 kanske du skrev ungefär så här:

```sql
CREATE TABLE bookings (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  resource_id INTEGER NOT NULL REFERENCES resources(id) ON DELETE CASCADE,
  user_id     INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  start       TEXT NOT NULL,
  "end"       TEXT NOT NULL,
  note        TEXT,
  CHECK ("end" > start)
);
```

Samma sak i PocketBase:

| SQL | PocketBase-fält | Inställningar |
|-----|-----------------|---------------|
| `id INTEGER PRIMARY KEY` | `id` (automatiskt) | – |
| `resource_id ... REFERENCES resources` | `resource` (relation → resources) | Max select 1, Nonempty, Cascade delete |
| `user_id ... REFERENCES users` | `user` (relation → users) | Max select 1, Nonempty, Cascade delete |
| `start TEXT NOT NULL` | `start` (date) | Nonempty |
| `"end" TEXT NOT NULL` | `end` (date) | Nonempty |
| `note TEXT` | `note` (text) | Max 500 |
| `CHECK ("end" > start)` | – | Görs med en hook (kapitel 7) |
| – | `created`, `updated` (autodate) | automatiskt |

Och det här är SQL:en som PocketBase faktiskt skapar:

```sql
CREATE TABLE `bookings` (
  `created`  TEXT DEFAULT '' NOT NULL,
  `end`      TEXT DEFAULT '' NOT NULL,
  `id`       TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL,
  `note`     TEXT DEFAULT '' NOT NULL,
  `resource` TEXT DEFAULT '' NOT NULL,
  `start`    TEXT DEFAULT '' NOT NULL,
  `updated`  TEXT DEFAULT '' NOT NULL,
  `user`     TEXT DEFAULT '' NOT NULL
);
```

Lägg märke till:

1. Relationsfälten heter `resource` och `user`, inte `resource_id`. I
   PocketBase är konventionen att relationsfältet heter som det det pekar på.
2. Det finns **ingen** `FOREIGN KEY` i SQL:en. PocketBase kontrollerar själv
   att id:t finns och sköter cascade delete i sin egen kod. Därför är det extra
   viktigt att alltid gå via API:t.
3. `required` och `max` syns inte i SQL:en. Valideringen sker i PocketBase
   innan raden skrivs.
4. Villkor som "slut efter start" kan inte uttryckas med fältinställningar. Där
   behövs en hook.

## Steg för steg: skapa `resources` i Dashboard

1. Klicka **+ New collection** i vänsterspalten.
2. Typ: **Base**. Namn: `resources`.
3. Klicka **+ New field** → **Plain text**. Namn: `name`. Öppna kugghjulet på
   fältet, kryssa i **Nonempty**, sätt **Max length** till `100`.
4. **+ New field** → **Plain text**. Namn: `description`.
5. **+ New field** → **Number**. Namn: `max_hours`. Inställningar: **Min** `1`,
   **Max** `48`, kryssa i **No decimals**.
6. **+ New field** → **Bool**. Namn: `active`. *Inte* Nonempty.
7. Under **Indexes**: **+ New index** → Unique → `name`.
8. Fliken **API Rules** låter vi vara tills vidare (kapitel 4).
9. Klicka **Create**.

Klicka sedan på `resources` och **+ New record**. Skapa "Tvättstuga 1" (max 3
timmar, aktiv) och "Festlokalen" (max 12 timmar, aktiv).

🧪 **Prova själv:** Försök skapa en resurs till med namnet "Tvättstuga 1". Vad
händer? Försök sedan sätta `max_hours` till `2.5`. Vad säger PocketBase?

## Att ändra en collection i efterhand

Du kan när som helst lägga till, döpa om eller ta bort fält. PocketBase
översätter det till `ALTER TABLE`.

⚠️ **Varning:**

- **Ta bort fält** raderar kolumnen och all data i den. Det går inte att ångra.
- **Byta namn** på ett fält bevarar datan, men alla appar, filter och regler
  som använder det gamla namnet slutar fungera.
- **Byta fälttyp** går inte. Skapa ett nytt fält, flytta datan, ta bort det
  gamla.

Varje ändring du gör i Dashboard skapar dessutom automatiskt en fil i
`pb_migrations/`. Mer om det i kapitel 7.

## Sammanfattning

- Collection-typer: **base** (vanlig data), **auth** (inloggning), **view**
  (skrivskyddad `SELECT`).
- `id` skapas alltid. `created`/`updated` är autodate-fält.
- Välj fälttyp efter vad värdet *betyder*, inte hur det ser ut.
- `required` = "inte tomt", vilket för number betyder ≠ 0 och för bool = true.
- Unikhet och snabbhet görs med **index**.
- Allt blir vanliga SQLite-tabeller, men utan `FOREIGN KEY` – PocketBase sköter
  integriteten.

Nästa kapitel: [Relationer](03-relationer.md).

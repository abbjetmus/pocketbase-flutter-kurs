# 01 – Vad är PocketBase?

## Problemet vi vill lösa

I modul 01 skapade du tabeller i SQLite och ställde frågor med SQL. Det fungerar
utmärkt när *du* sitter vid datorn. Men Föreningsappen ska köras i medlemmarnas
mobiler. Då uppstår en rad frågor:

- Mobilen kan inte öppna en SQLite-fil som ligger på en server. Hur kommer
  appen åt datan?
- Hur loggar Anna in, och hur vet servern att det är hon?
- Hur hindrar vi Anna från att radera Bos bokning?
- Hur får Bos telefon veta att Anna just bokade tvättstugan, utan att fråga
  servern varje sekund?
- Var sparas bilder som laddas upp till ett anslag?

Svaret är en **backend**: ett program som körs på en server, äger databasen och
erbjuder ett kontrollerat API som appen anropar över internet.

```
┌──────────────┐      HTTP/JSON       ┌──────────────┐      SQL       ┌──────────┐
│ Flutter-app  │  ─────────────────►  │   Backend    │ ─────────────► │ Databas  │
│ (i mobilen)  │  ◄─────────────────  │ (på servern) │ ◄───────────── │ (SQLite) │
└──────────────┘                      └──────────────┘                └──────────┘
```

Appen pratar **aldrig** direkt med databasen. Den ber backend om saker, och
backend avgör om frågan är tillåten.

## Två sätt att få en backend

| | Egen backend | Backend-as-a-Service (BaaS) |
|---|---|---|
| Exempel | Node.js + Express, Django, Spring, ASP.NET | PocketBase, Firebase, Supabase, Appwrite |
| Du skriver | Allt: routes, SQL, inloggning, lösenordshashning, behörighet, filuppladdning | Bara datamodell, regler och eventuell specialkod |
| Tid till första fungerande API | Dagar–veckor | Minuter |
| Flexibilitet | Total | Stor, men inom ramarna |
| Risk för säkerhetsmisstag | Hög (du bygger inloggning själv) | Lägre (beprövad inloggning), men reglerna måste du fortfarande skriva rätt |

PocketBase är en **BaaS som du kör själv** (self-hosted). Till skillnad från
Firebase ligger datan på din egen server, i en vanlig SQLite-fil som du kan
öppna och läsa.

## Vad PocketBase innehåller

PocketBase är skrivet i programspråket **Go** och levereras som **en enda
körbar fil** (cirka 30–40 MB). Inget att installera, ingen separat
databasserver. I den filen finns:

| Del | Vad den gör |
|-----|-------------|
| **SQLite-databas** | All data sparas i `pb_data/data.db` |
| **REST-API** | Automatiska endpoints för varje collection: lista, hämta, skapa, ändra, ta bort |
| **Realtid** | Klienter kan prenumerera på ändringar (Server-Sent Events) |
| **Autentisering** | E-post/lösenord, engångskoder (OTP), OAuth2 (Google, Apple m.fl.) |
| **API-regler** | Ett litet regelspråk som avgör vem som får göra vad |
| **Fillagring** | Uppladdade filer sparas lokalt eller i S3 |
| **Dashboard (Admin UI)** | Ett webbgränssnitt där du skapar collections och ser data |
| **JS-hooks** | Egen serverkod i JavaScript för specialfall |
| **Migrationer** | Databasstrukturen som kod, så att den kan versionshanteras |

```
            ┌───────────────────────── pocketbase (en fil) ─────────────────────────┐
  HTTP ───► │  Router ──► API-regler ──► Hooks ──► Record-logik ──► SQLite (pb_data) │
            │     │                                                                 │
            │     └──► Dashboard /_/        Realtid (SSE) ◄── ändringar             │
            └────────────────────────────────────────────────────────────────────────┘
```

💡 **Tips:** Ordet *collection* betyder i PocketBase ungefär "tabell". En
*record* (post) är en rad i tabellen. Vi använder orden collection och post
genom hela modulen.

## Installation

1. Gå till <https://pocketbase.io/docs/> och ladda ner zip-filen för ditt
   operativsystem (macOS: `darwin_arm64` för M-processorer, `darwin_amd64` för
   Intel; Windows: `windows_amd64`; Linux: `linux_amd64`).
2. Skapa en mapp för projektet, till exempel `foreningen-pb`, och packa upp
   zip-filen där. Du får filen `pocketbase` (eller `pocketbase.exe`).
3. Öppna en terminal i mappen och kontrollera versionen:

```bash
cd foreningen-pb
./pocketbase --version
# pocketbase version 0.39.x
```

⚠️ **Varning (macOS):** Första gången kan macOS säga att programmet "inte kan
öppnas eftersom utvecklaren inte kan verifieras". Kör då
`xattr -d com.apple.quarantine ./pocketbase` en gång, eller högerklicka på
filen i Finder och välj *Öppna*.

## Starta servern

```bash
./pocketbase serve
```

Utskriften ser ut ungefär så här:

```
2026/10/09 09:26:52 Server started at http://127.0.0.1:8090
├─ REST API:  http://127.0.0.1:8090/api/
└─ Dashboard: http://127.0.0.1:8090/_/
```

Servern kör tills du trycker `Ctrl+C`. Två adresser är viktiga:

| Adress | Vad |
|--------|-----|
| `http://127.0.0.1:8090/api/` | REST-API:t som appen anropar |
| `http://127.0.0.1:8090/_/` | Dashboard, för dig som utvecklare |

Testa att API:t lever:

```bash
curl http://127.0.0.1:8090/api/health
# {"message":"API is healthy.","code":200,"data":{}}
```

💡 **Tips:** `127.0.0.1` betyder "den här datorn". Vill du nå servern från en
mobil på samma wifi startar du med `./pocketbase serve --http=0.0.0.0:8090`
och använder datorns IP-adress (t.ex. `http://192.168.1.23:8090`). Från
Android-emulatorn når du datorn via `http://10.0.2.2:8090`.

## Skapa en superuser

En **superuser** är en administratör som får göra *allt*: logga in i
Dashboard, ändra collections och läsa all data. API-regler gäller inte för
superusers.

Första gången du startar servern skriver PocketBase ut en länk i terminalen
som börjar med `http://127.0.0.1:8090/_/#/pbinstall/...`. Öppna den och fyll i
e-post och lösenord. Alternativt skapar du superusern från terminalen:

```bash
./pocketbase superuser upsert admin@example.com EttLangtLosenord123
```

(`upsert` betyder "skapa, eller uppdatera om den redan finns". Det är också
räddningen om du glömmer lösenordet.)

Logga sedan in på <http://127.0.0.1:8090/_/>.

⚠️ **Varning:** Superusers ligger i en egen collection, `_superusers`. De är
**inte** samma sak som medlemmar i `users`, och en medlem med rollen `admin` i
vår app är inte heller en superuser. Mer om det i kapitel 4.

## En rundtur i Dashboard

När du loggat in ser du ungefär detta:

```
┌────────────┬───────────────────────────────────────────────────────────┐
│ Collections│  users                                   [+ New record]  │
│  ┌───────┐ │  ┌──────────┬────────────────┬────────┬──────────────┐   │
│  │ users │ │  │ id       │ email          │ name   │ created      │   │
│  └───────┘ │  ├──────────┼────────────────┼────────┼──────────────┤   │
│ + New coll.│  │ (tomt)   │                │        │              │   │
│            │  └──────────┴────────────────┴────────┴──────────────┘   │
│ ─────────  │                                                           │
│ Logs       │   ⚙ (kugghjulet vid namnet) = redigera collection         │
│ Settings   │                                                           │
└────────────┴───────────────────────────────────────────────────────────┘
```

- **Collections** (vänster): alla dina collections. Från början finns bara
  `users`. Systemcollections som `_superusers` döljs i listan som standard.
- **+ New collection**: skapa en ny collection (kapitel 2).
- **Kugghjulet** bredvid collection-namnet: ändra fält, index och API-regler.
- **Logs**: alla API-anrop. Ovärderligt när något inte fungerar.
- **Settings**: applikationens namn och URL, e-postinställningar (SMTP),
  fillagring, backuper med mera.

🧪 **Prova själv:** Klicka på `users` och sedan på kugghjulet. Vilka fält finns
redan? (Du bör se bland annat `email`, `password`, `name`, `avatar`,
`verified`, `created` och `updated`.)

## Mappstrukturen

Efter första starten ser projektmappen ut så här:

```
foreningen-pb/
├── pocketbase          ← programmet
├── pb_data/            ← DATA. Skapas automatiskt. Checka INTE in i git.
│   ├── data.db         ← huvuddatabasen (SQLite)
│   ├── auxiliary.db    ← loggar m.m. (SQLite)
│   ├── storage/        ← uppladdade filer
│   └── types.d.ts      ← typdefinitioner för hooks (autokomplettering i VS Code)
├── pb_migrations/      ← migrationer (JavaScript). Checka IN i git.
└── pb_hooks/           ← egen serverkod (*.pb.js). Checka IN i git. Skapas av dig.
```

| Mapp | Innehåll | Git? |
|------|----------|------|
| `pb_data` | Själva datan, lösenordshashar, uppladdade filer | **Nej** – lägg i `.gitignore` |
| `pb_migrations` | Hur databasstrukturen ska se ut, steg för steg | **Ja** |
| `pb_hooks` | Din egen JavaScript-kod | **Ja** |

En lämplig `.gitignore`:

```gitignore
pb_data/
pocketbase
pocketbase.exe
```

💡 **Tips:** Tanken är att `pb_migrations` + `pb_hooks` beskriver *hur*
backend fungerar, medan `pb_data` är *innehållet*. En kollega som klonar ditt
repo och startar PocketBase får exakt samma collections och regler, men en tom
databas. Det går vi igenom i kapitel 7.

## Under huven: det är bara SQLite

Det här är det viktigaste sambandet med modul 01. När du skapar en collection i
Dashboard skapar PocketBase en **vanlig SQL-tabell** i `pb_data/data.db`.

| PocketBase | SQL (modul 01) |
|------------|----------------|
| Collection | Tabell |
| Record / post | Rad |
| Fält (field) | Kolumn |
| `id` | Primärnyckel (`TEXT PRIMARY KEY`, 15 tecken) |
| Relationsfält | Kolumn med id:t på en annan post (som en främmande nyckel) |
| Index | Index (`CREATE INDEX ...`) |
| View-collection | SQL-vy (en sparad `SELECT`) |
| API-regel | Ungefär ett `WHERE`-villkor som läggs till automatiskt |

### Öppna databasen med sqlite3

Stoppa gärna servern först (eller öppna filen bara för läsning) så att du inte
råkar ändra något medan den kör.

```bash
sqlite3 pb_data/data.db
```

```sql
sqlite> .tables
_authOrigins    _externalAuths  _mfas    _params      _superusers
_collections    _migrations     _otps    users

sqlite> .schema users
CREATE TABLE `users` (`avatar` TEXT DEFAULT '' NOT NULL,
  `created` TEXT DEFAULT '' NOT NULL, `email` TEXT DEFAULT '' NOT NULL,
  `emailVisibility` BOOLEAN DEFAULT FALSE NOT NULL,
  `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL,
  `name` TEXT DEFAULT '' NOT NULL, `password` TEXT DEFAULT '' NOT NULL,
  `tokenKey` TEXT DEFAULT '' NOT NULL, `updated` TEXT DEFAULT '' NOT NULL,
  `verified` BOOLEAN DEFAULT FALSE NOT NULL);
```

Några saker att lägga märke till:

1. Tabeller som börjar med `_` är **systemtabeller**. `_collections` beskriver
   alla dina collections (fält, regler, index) som JSON. `_migrations` håller
   reda på vilka migrationer som körts.
2. Alla kolumner är `NOT NULL` med ett **standardvärde** (`''`, `0`, `FALSE`).
   PocketBase använder alltså nästan aldrig `NULL` – ett tomt textfält är `''`.
   (Undantaget är `json`-fält.)
3. `id` är text, inte ett heltal med `AUTOINCREMENT`. Ett id ser ut som
   `flskfapcqwu5iun`. Det är slumpat, så ingen kan gissa nästa id.
4. Lösenord sparas som en **hash** i kolumnen `password`, aldrig i klartext.
5. Datum sparas som text i formatet `2026-10-12 08:00:00.000Z` (alltid UTC).

🧪 **Prova själv:** Kör `SELECT id, email, created FROM users;` i sqlite3.
Skapa sedan en användare i Dashboard (klicka `users` → *New record*) och kör
frågan igen.

⚠️ **Varning:** Läsa med sqlite3 är helt ok och bra för förståelsen. Men
**skriv inte** till tabellerna direkt med `INSERT`/`UPDATE` medan du lär dig.
Då går du förbi PocketBase: inga regler, inga hooks, inga realtidshändelser,
ingen validering och inga lösenordshashar. Ändra alltid data via API:t eller
Dashboard.

## Vad händer vid ett anrop?

Så här ser det ut när appen ber om Annas bokningar:

```
App:  GET /api/collections/bookings/records?filter=start>=@todayStart
         Authorization: <Annas token>
          │
          ▼
PocketBase:
  1. Vem är det?       → token tillhör users-posten "Anna"
  2. Vilken regel?     → listRule för bookings: user = @request.auth.id
  3. Bygg SQL:         SELECT bookings.* FROM bookings
                       WHERE (start >= '2026-10-09 00:00:00.000Z')
                         AND (user = 'flskfapcqwu5iun')
                       ORDER BY ... LIMIT 30
  4. Kör hooks         (om du skrivit några)
  5. Svara med JSON    {"page":1,"perPage":30,"totalItems":2,"items":[...]}
```

Du skriver alltså aldrig SQL-frågan själv. Du beskriver *vad* du vill ha
(filter) och *vem som får se vad* (regel), och PocketBase bygger frågan. Det är
därför SQL-kunskaperna från modul 01 fortfarande är värdefulla: du förstår vad
som händer, varför index behövs och varför en regel är ett slags `WHERE`.

💡 **Tips:** Starta med `./pocketbase serve --dev` så skrivs alla SQL-frågor
som PocketBase kör ut i terminalen. Det är ett utmärkt sätt att se kopplingen
mellan filter, regler och SQL.

## När är PocketBase *inte* rätt val?

PocketBase passar utmärkt för appar som Föreningsappen: hundratals eller några
tusen användare, en server, rimligt enkel logik. Det är mindre lämpligt när:

- du behöver köra många servrar samtidigt bakom en lastbalanserare (SQLite är
  en fil på *en* dator),
- du har mycket tung affärslogik som passar bättre i en egen backend,
- organisationen kräver en viss databas, t.ex. PostgreSQL.

## Sammanfattning

- PocketBase är en backend i en enda fil: SQLite, REST, realtid, auth, filer
  och Dashboard.
- Starta med `./pocketbase serve`, Dashboard finns på `/_/`.
- En superuser får göra allt. Vanliga användare styrs av API-regler.
- `pb_data` är data (inte i git), `pb_migrations` och `pb_hooks` är kod (i git).
- Collections är SQL-tabeller i `pb_data/data.db`. Du kan läsa dem med
  `sqlite3`, men ändra data via API:t.

Nästa kapitel: [Collections och fält](02-collections-och-falt.md).

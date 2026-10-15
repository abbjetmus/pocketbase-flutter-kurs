# 01 – Vad är PocketBase?

## Problemet vi vill lösa

I modul 01 skapade du tabeller och ställde frågor med SQL. Det fungerar utmärkt
när *du* sitter vid datorn. Men Kvittra ska köras i användarnas mobiler. Då
uppstår en rad frågor:

- Mobilen kan inte öppna en databasfil som ligger på en server. Hur kommer
  appen åt datan?
- Hur registrerar sig Anna och loggar in, och hur vet servern att det är hon?
- Hur hindrar vi Anna från att radera Bos inlägg, eller gilla något i Bos namn?
- Hur får Bos telefon veta att Anna just kommenterade hans inlägg, utan att
  fråga servern varje sekund?
- Var sparas bilderna som laddas upp till ett inlägg?

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

💡 **Tips:** Du har redan sett hur det ser ut från appens håll. Test-API:t
[JSONPlaceholder](https://jsonplaceholder.typicode.com) svarar med JSON på
`/users`, `/posts` och `/comments` – men det låtsas bara spara det du skickar.
Med PocketBase bygger vi ett riktigt API med samma sorts data, där ändringar
sparas och där varje användare bara får göra det hen har rätt till.

## Två sätt att få en backend

| | Egen backend | Backend-as-a-Service (BaaS) |
|---|---|---|
| Exempel | Node.js + Express, Django, Spring, ASP.NET | PocketBase, Firebase, Supabase, Appwrite |
| Du skriver | Allt: routes, SQL, inloggning, lösenordshashning, behörighet, filuppladdning | Bara datamodell, regler och eventuell specialkod |
| Tid till första fungerande API | Dagar–veckor | Minuter |
| Flexibilitet | Total | Stor, men inom ramarna |
| Risk för säkerhetsmisstag | Hög (du bygger inloggning själv) | Lägre (beprövad inloggning), men reglerna måste du fortfarande skriva rätt |

PocketBase är en **BaaS som du kör själv** (self-hosted). Till skillnad från
Firebase ligger datan på din egen server, i en vanlig SQLite-fil.

## Vad PocketBase innehåller

PocketBase levereras som **en enda körbar fil** (zip-filen är runt 12 MB,
själva programmet runt 30 MB). Inget att installera, ingen separat
databasserver. I den filen finns:

| Del | Vad den gör |
|-----|-------------|
| **SQLite-databas** | All data sparas i `pb_data/data.db` |
| **REST-API** | Automatiska endpoints för varje collection: lista, hämta, skapa, ändra, ta bort |
| **Realtid** | Klienter kan prenumerera på ändringar (Server-Sent Events) |
| **Autentisering** | E-post/användarnamn + lösenord, engångskoder (OTP), OAuth2 (Google, Apple m.fl.) |
| **API-regler** | Ett litet regelspråk som avgör vem som får göra vad |
| **Fillagring** | Uppladdade filer (t.ex. avatarer och bilder) sparas lokalt eller i S3 |
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
genom hela modulen. (Lätt att blanda ihop: en *post* i PocketBase är en rad i
vilken collection som helst, medan ett *inlägg* är en rad i Kvittras
collection `posts`.)

## Installation

Om du redan laddade ner PocketBase i modul 01 kan du använda samma program –
men lägg det i en **ny mapp**, så att du börjar med en tom databas.

1. Gå till <https://pocketbase.io/docs/> och ladda ner zip-filen för ditt
   operativsystem och din processor:

   | Dator | Fil |
   |-------|-----|
   | Mac med M-processor (Apple Silicon) | `..._darwin_arm64.zip` |
   | Mac med Intel-processor | `..._darwin_amd64.zip` |
   | Windows (de flesta datorer) | `..._windows_amd64.zip` |
   | Linux | `..._linux_amd64.zip` (eller `arm64`) |

   Materialet är testat med v0.39.4. Den versionen finns under
   [GitHub Releases](https://github.com/pocketbase/pocketbase/releases/tag/v0.39.4).
   En nyare 0.x-version fungerar nästan alltid likadant, men om något i
   materialet inte stämmer – titta i `CHANGELOG.md` som följer med i zip-filen.

2. Skapa en ny mapp för projektet, till exempel `kvittra-pb`, och packa upp
   zip-filen där. Du får filen `pocketbase` (eller `pocketbase.exe`).
3. Öppna en terminal i mappen och kontrollera versionen:

```bash
cd kvittra-pb
./pocketbase --version
# pocketbase version 0.39.4
```

(På Windows skriver du `.\pocketbase.exe` i stället för `./pocketbase` i alla
kommandon.)

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
2026/10/15 10:17:41 Server started at http://127.0.0.1:8090
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

Första gången du startar servern öppnar PocketBase en installationslänk i
webbläsaren (den skrivs också ut i terminalen och börjar med
`http://127.0.0.1:8090/_/#/pbinstall/...`). Fyll i e-post och lösenord där.
Alternativt skapar du superusern från terminalen:

```bash
./pocketbase superuser upsert admin@example.com EttLangtLosenord123
```

(`upsert` betyder "skapa, eller uppdatera om den redan finns". Det är också
räddningen om du glömmer lösenordet. Det finns även `superuser create`, som
bara skapar.)

Logga sedan in på <http://127.0.0.1:8090/_/>.

⚠️ **Varning:** Superusers ligger i en egen collection, `_superusers`. De är
**inte** samma sak som användarna i `users`. Anna som skriver inlägg i Kvittra
är en vanlig användare – och en användare som är admin i en *grupp* (kapitel 8)
är inte heller en superuser. Mer om det i kapitel 4.

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
`verified`, `created` och `updated`. Fälten `username`, `bio` och `website`
som Kvittra behöver lägger du till själv i kapitel 2.)

## Mappstrukturen

Efter första starten ser projektmappen ut så här:

```
kvittra-pb/
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

💡 **Tips:** Vill du börja om från noll? Stoppa servern och ta bort mappen
`pb_data`. Nästa start ger en helt tom databas (och du behöver skapa en ny
superuser).

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

### Se SQL:en – utan att lämna PocketBase

Du behöver inget extra verktyg för att se hur tabellerna ser ut. SQLite sparar
varje tabells `CREATE TABLE`-sats i systemtabellen `sqlite_master`, och den kan
du läsa med en **view-collection** (mer om sådana i kapitel 2):

1. Dashboard → **+ New collection** → välj typen **View**.
2. Namn: `db_tables`.
3. Fråga:

   ```sql
   SELECT name AS id, sql FROM sqlite_master WHERE type = 'table'
   ```

4. Låt API-reglerna vara låsta (bara superusers) och klicka **Create**.

Öppna `db_tables` och klicka på raden `users`:

```sql
CREATE TABLE `users` (`avatar` TEXT DEFAULT '' NOT NULL,
  `created` TEXT DEFAULT '' NOT NULL, `email` TEXT DEFAULT '' NOT NULL,
  `emailVisibility` BOOLEAN DEFAULT FALSE NOT NULL,
  `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL,
  `name` TEXT DEFAULT '' NOT NULL, `password` TEXT DEFAULT '' NOT NULL,
  `tokenKey` TEXT DEFAULT '' NOT NULL, `updated` TEXT DEFAULT '' NOT NULL,
  `verified` BOOLEAN DEFAULT FALSE NOT NULL)
```

Några saker att lägga märke till:

1. Tabeller som börjar med `_` är **systemtabeller**. `_collections` beskriver
   alla dina collections (fält, regler, index) som JSON. `_migrations` håller
   reda på vilka migrationer som körts.
2. Alla kolumner är `NOT NULL` med ett **standardvärde** (`''`, `0`, `FALSE`).
   PocketBase använder alltså nästan aldrig `NULL` – ett tomt textfält är `''`.
   (Undantaget är `json`-fält.)
3. `id` är text, inte ett heltal med `AUTOINCREMENT`. Ett id ser ut som
   `qypx76fi904xnmo`. Det är slumpat, så ingen kan gissa nästa id.
4. Lösenord sparas som en **hash** i kolumnen `password`, aldrig i klartext.
5. Datum sparas som text i formatet `2026-10-15 08:17:41.396Z` (alltid UTC).

💡 **Tips:** `pb_data/data.db` är en helt vanlig SQLite-fil. Den kan öppnas med
vilket SQLite-verktyg som helst, men i den här modulen behövs det aldrig – och
du ska **inte skriva** till den utanför PocketBase. Då går du förbi PocketBase:
inga regler, inga hooks, inga realtidshändelser, ingen validering och inga
lösenordshashar. Ändra alltid data via API:t eller Dashboard.

## Vad händer vid ett anrop?

Så här ser det ut när appen ber om Annas flöde – inlägg från dem hon följer:

```
App:  GET /api/collections/posts/records
          ?filter=author.follows_via_following.follower ?= "ryd2jdczusx4tm4"
          &sort=-created
         Authorization: <Annas token>
          │
          ▼
PocketBase:
  1. Vem är det?       → token tillhör users-posten "anna"
  2. Vilken regel?     → listRule för posts: @request.auth.id != ""
  3. Bygg SQL:         SELECT DISTINCT posts.* FROM posts
                       LEFT JOIN users   ON users.id = posts.author
                       LEFT JOIN follows ON follows.following = users.id
                       WHERE ('ryd2jdczusx4tm4' IS NOT '')       ← regeln
                         AND follows.follower = 'ryd2jdczusx4tm4' ← filtret
                       ORDER BY posts.created DESC LIMIT 30
  4. Kör hooks         (om du skrivit några)
  5. Svara med JSON    {"page":1,"perPage":30,"totalItems":4,"items":[...]}
```

Du skriver alltså aldrig SQL-frågan själv. Du beskriver *vad* du vill ha
(filter) och *vem som får se vad* (regel), och PocketBase bygger frågan med
`JOIN`:ar åt dig. Det är därför SQL-kunskaperna från modul 01 fortfarande är
värdefulla: du förstår vad som händer, varför index behövs och varför en regel
är ett slags `WHERE`. (Filtret med `follows_via_following` går vi igenom i
kapitel 3 och 5.)

💡 **Tips:** Starta med `./pocketbase serve --dev` så skrivs alla SQL-frågor
som PocketBase kör ut i terminalen. Det är ett utmärkt sätt att se kopplingen
mellan filter, regler och SQL.

## När är PocketBase *inte* rätt val?

PocketBase passar utmärkt för appar som Kvittra i liten och mellanstor skala:
hundratals eller tusentals användare, en server, rimligt enkel logik. Det är
mindre lämpligt när:

- du behöver köra många servrar samtidigt bakom en lastbalanserare (SQLite är
  en fil på *en* dator) – ett riktigt stort socialt nätverk hamnar där,
- du har mycket tung affärslogik som passar bättre i en egen backend,
- organisationen kräver en viss databas, t.ex. PostgreSQL.

## Sammanfattning

- PocketBase är en backend i en enda fil: SQLite, REST, realtid, auth, filer
  och Dashboard.
- Starta modulen i en **ny, tom mapp**. Starta servern med `./pocketbase serve`,
  Dashboard finns på `/_/`.
- En superuser får göra allt. Vanliga användare styrs av API-regler.
- `pb_data` är data (inte i git), `pb_migrations` och `pb_hooks` är kod (i git).
- Collections är SQL-tabeller i `pb_data/data.db`. Du kan se SQL:en med en
  view-collection eller `serve --dev`, men ändra data via API:t.

Nästa kapitel: [Collections och fält](02-collections-och-falt.md).

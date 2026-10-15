# Modul 01 – Databaser

I den här modulen lär du dig vad en databas är, hur du pratar med den med SQL,
varför transaktioner och ACID är så viktigt, och hur du designar tabeller som
håller i längden. Allt bygger på kursens gemensamma exempel: **Kvittra**, en
enkel social app med tabellerna `users`, `posts`, `comments`, `likes` och
`follows` (se kursens [README](../README.md)).

Du arbetar direkt i **PocketBase** redan från början. PocketBase är en färdig
backend i en enda fil, och under huven är den en vanlig SQLite-databas. Du
bygger Kvittras tabeller (i PocketBase kallas de *collections*) i
webbgränssnittet, matar in lite data och skriver sedan dina SQL-frågor som
**View collections**. När du i modul 02 går djupare i PocketBase känner du
alltså redan igen både verktyget och datamodellen.

## Lärandemål

När du är klar med modulen ska du kunna:

- förklara vad en databas och ett databashanteringssystem (DBMS) är, och varför
  man använder en databas i stället för filer eller kalkylark,
- beskriva begreppen tabell, rad, kolumn, primärnyckel och främmande nyckel,
- skapa tabeller med lämpliga datatyper och villkor (*constraints*), både i SQL
  och som collections i PocketBase,
- skriva frågor med `SELECT`, `WHERE`, `ORDER BY`, `GROUP BY`, `HAVING`, `JOIN`
  och underfrågor, samt förstå `INSERT`, `UPDATE` och `DELETE`,
- förklara vad en transaktion är och vad var och en av bokstäverna i ACID betyder,
- känna igen typiska samtidighetsproblem (t.ex. dubbla gillningar och tappade
  uppdateringar av en räknare) och hur databasen skyddar mot dem,
- designa en datamodell: hitta entiteter, relationer och kardinalitet, rita ett
  ER-diagram och normalisera till tredje normalformen,
- fatta medvetna beslut om nycklar, datatyper, datum, bilder, `NULL` och index.

## Innehåll

| # | Kapitel | Innehåll |
|---|---------|----------|
| 1 | [Vad är en databas?](01-vad-ar-en-databas.md) | Databaser, DBMS, tabeller, nycklar, SQLite vs PostgreSQL, PocketBase |
| 2 | [SQL-grunder](02-sql-grunder.md) | `CREATE TABLE`, CRUD, aggregat, `JOIN`, underfrågor, index, vyer |
| 3 | [ACID och transaktioner](03-acid-och-transaktioner.md) | `BEGIN`/`COMMIT`/`ROLLBACK`, ACID, isoleringsproblem, SQLite/WAL |
| 4 | [Databasdesign](04-databasdesign.md) | ER-diagram, kardinalitet, normalisering, nycklar, datatyper, checklista |
| – | [Övningar](ovningar.md) | Nivå 1–3: SQL-frågor, ACID-tankeövningar, två designuppgifter |
| – | [Lösningar](losningar.md) | Lösningsförslag (försök själv först!) |

Rekommenderad ordning: gör stegen i det här dokumentet först (installera
PocketBase och bygg Kvittra). Läs sedan kapitlen 1–4 i tur och ordning och gör
🧪 *Prova själv*-uppgifterna under tiden. Gör sist [övningarna](ovningar.md).

---

## Steg 1: Installera PocketBase

PocketBase är ett enda program utan installation. Det kräver ingen databasserver
– databasen är en SQLite-fil i mappen `pb_data/`.

1. Gå till [pocketbase.io/docs](https://pocketbase.io/docs/) och ladda ner zip-filen
   för ditt system (macOS, Windows eller Linux). Materialet är testat med
   PocketBase 0.39; senare versioner fungerar normalt likadant.
2. Packa upp zip-filen i en ny mapp, t.ex. `kvittra-pb/`. Mappen innehåller
   programmet `pocketbase` (`pocketbase.exe` på Windows).
3. Öppna en terminal i mappen och starta servern:

   ```bash
   ./pocketbase serve          # macOS / Linux
   .\pocketbase.exe serve      # Windows (PowerShell)
   ```

   ```text
   Server started at http://127.0.0.1:8090
   ├─ REST API:  http://127.0.0.1:8090/api/
   └─ Dashboard: http://127.0.0.1:8090/_/
   ```

4. Första gången öppnas en länk i webbläsaren där du skapar ett
   **superuser-konto** (administratör). Använd t.ex. `admin@example.com` och ett
   lösenord du kommer ihåg. Öppnas ingen länk kan du i stället skapa kontot i
   terminalen (stoppa servern med `Ctrl + C` först):

   ```bash
   ./pocketbase superuser upsert admin@example.com DittLosenord123
   ```

5. Logga in i **Dashboard** på <http://127.0.0.1:8090/_/>.

⚠️ **Varning (macOS):** Vägrar macOS starta programmet ("kan inte verifieras")?
Högerklicka på `pocketbase` i Finder, välj **Öppna** och bekräfta en gång.

💡 **Tips:** Stoppa servern med `Ctrl + C` och starta den igen med
`./pocketbase serve`. All data ligger kvar i `pb_data/`.

---

## Steg 2: Bygg Kvittra i Dashboard

En ny PocketBase har redan en collection som heter **users** (inloggningsbara
användare). Vi lägger till några fält i den och skapar sedan fyra nya
collections. Namnen måste vara *exakt* som nedan, eftersom alla frågor i
modulen (och modul 02) använder dem.

### 2a. Komplettera `users`

Klicka på **users** i vänstermenyn och sedan på kugghjulet bredvid namnet.
Lägg till tre fält med **New field**:

| Fält | Typ | Inställningar |
|------|-----|---------------|
| `username` | Plain text | **Required**, Min length 3, Max length 20 |
| `bio` | Plain text | – |
| `website` | URL | – |

Gå sedan till avsnittet för index längst ner, klicka **New index**, välj
kolumnen `username` och kryssa i **Unique**. Spara med **Save changes**.

Fälten `id`, `email`, `password`, `name`, `created` och `updated` finns redan.

### 2b. Skapa `posts`, `comments`, `likes` och `follows`

Klicka på **New collection**, låt typen vara **Base**, skriv namnet och lägg till
fälten. En **Relation** pekar på en annan collection; välj **Single** (en record)
och slå på **Cascade delete** för alla relationer nedan.

| Collection | Fält (typ) | Index |
|------------|------------|-------|
| `posts` | `author` (Relation → users, Required), `title` (Plain text, Required), `body` (Plain text, Required) | `author` |
| `comments` | `post` (Relation → posts, Required), `author` (Relation → users, Required), `body` (Plain text, Required) | `post` |
| `likes` | `post` (Relation → posts, Required), `user` (Relation → users, Required) | **Unique** på `post` + `user`, samt `user` |
| `follows` | `follower` (Relation → users, Required), `following` (Relation → users, Required) | **Unique** på `follower` + `following`, samt `following` |

Varje ny collection får automatiskt fälten `id`, `created` och `updated`.
(Kontrollera att `created` finns under fälten. Saknas den, lägg till ett fält av
typen **Autodate** som heter `created` och sätts vid *Create*.)

💡 **Tips:** Unikt index på `post` + `user` i `likes` betyder: samma användare kan
inte gilla samma inlägg två gånger. Du lär dig varför i kapitel 2 och 3.

### 2c. Mata in exempeldatan

Skapa records med **New record** i varje collection. Gör det i den här
ordningen, eftersom relationerna måste ha något att peka på:
`users` → `posts` → `comments` → `likes` → `follows`.

PocketBase ger varje record ett slumpat **id** med 15 tecken, t.ex.
`k3j9x0p2m1q8w7e`. Det gör inget – frågorna i modulen joinar alltid fram
användarnamn och titlar i stället för att skriva id:n.

**users** – lösenord `kvittra123` för alla. Lämna tomma celler (–) tomma.

| username | name | email | bio | website |
|----------|------|-------|-----|---------|
| anna | Anna Andersson | anna@example.com | Fotograf och kaffeälskare. | https://anna.example.com |
| bertil | Bertil Berg | bertil@example.com | Bakar surdegsbröd på helgerna. | – |
| cissi | Cecilia Carlsson | cecilia@example.com | Löpare. Springer helst i skogen. | https://cissi.example.com |
| dahl | David Dahl | david@example.com | Utvecklare som gillar brädspel. | – |
| evaek | Eva Ek | eva@example.com | – | – |
| johan | Johan Jönsson | johan@example.com | – | – |

**posts** – mata in dem *i den här ordningen* (äldst först).

| # | author | title | body |
|---|--------|-------|------|
| 1 | anna | Höstpromenad i Slottsskogen | Löven har börjat skifta färg. Perfekt ljus för foto i dag! |
| 2 | bertil | Mitt första surdegsbröd | Efter tre försök blev det äntligen luftigt. |
| 3 | dahl | Brädspelskväll på fredag | Vi kör Carcassonne. Vem är med? |
| 4 | cissi | Milen under 50 minuter! | Nytt personbästa i morse: 49:12. |
| 5 | evaek | Hej Kvittra! | Mitt första inlägg. Vad brukar ni skriva om här? |
| 6 | cissi | Kaffe efter löprundan | Finns det något bättre än kaffe efter en kall morgonrunda? |
| 7 | bertil | Kanelbullens dag | Bakade 40 bullar i morse. Kaffe, någon? |
| 8 | dahl | Brädspelskväll igen? | Förra gången blev succé. Samma tid nästa fredag? |
| 9 | cissi | Halvmaran avklarad | 1:49:30! Tack för all pepp. |
| 10 | anna | Morgondimma | Uppe tidigt för att fånga dimman över ån. |

**comments** (13 st)

| post | author | body |
|------|--------|------|
| Höstpromenad i Slottsskogen | bertil | Vilka färger! |
| Höstpromenad i Slottsskogen | cissi | Slottsskogen är bäst på hösten. |
| Mitt första surdegsbröd | anna | Ser jättegott ut! |
| Brädspelskväll på fredag | cissi | Jag är med! |
| Brädspelskväll på fredag | dahl | Toppen, då kör vi! |
| Milen under 50 minuter! | anna | Grymt jobbat! |
| Hej Kvittra! | anna | Välkommen! |
| Kanelbullens dag | anna | Jag tar två! |
| Kanelbullens dag | bertil | Tyvärr, allt är slut. |
| Brädspelskväll igen? | cissi | Självklart! |
| Halvmaran avklarad | anna | Wow, grattis! |
| Halvmaran avklarad | dahl | Snyggt! |
| Halvmaran avklarad | evaek | Imponerande! |

**likes** (19 st) – vem som gillar vilket inlägg

| post | gillas av |
|------|-----------|
| Höstpromenad i Slottsskogen | bertil, cissi, dahl |
| Mitt första surdegsbröd | anna |
| Brädspelskväll på fredag | cissi |
| Milen under 50 minuter! | anna, dahl |
| Hej Kvittra! | – |
| Kaffe efter löprundan | anna |
| Kanelbullens dag | anna, cissi |
| Brädspelskväll igen? | cissi, johan, dahl |
| Halvmaran avklarad | anna, dahl, evaek, johan |
| Morgondimma | bertil, cissi |

Varje namn är en egen record i `likes` (t.ex. tre records för det första inlägget).

**follows** (10 st) – `follower` följer `following`

| follower | following |
|----------|-----------|
| anna | bertil |
| anna | cissi |
| bertil | anna |
| bertil | dahl |
| cissi | anna |
| cissi | dahl |
| dahl | cissi |
| evaek | anna |
| evaek | cissi |
| johan | anna |

⚠️ **Varning:** Matar du in något fel eller hoppar över en rad kommer dina svar i
övningarna att skilja sig från de förväntade. Kontrollera antalet: 6 users,
10 posts, 13 comments, 19 likes och 10 follows.

### 2d. Flytta tillbaka tiden

Fältet `created` sätts automatiskt till *nu* och går inte att ändra i
formulären. I övningarna låtsas vi att **dagens datum är måndag 12 oktober
2026**, och då behöver inläggen ha datum från hösten 2026. Det fixar vi med SQL
– din första `UPDATE`!

1. Gå till **Settings** (kugghjulet längst ner till vänster) och välj
   **SQL console**.
2. Klistra in hela blocket nedan och klicka **Execute**. PocketBase varnar
   första gången du kör något som ändrar data – bekräfta.

```sql
UPDATE posts SET created = '2026-09-01 08:15:00.000Z' WHERE title = 'Höstpromenad i Slottsskogen';
UPDATE posts SET created = '2026-09-03 19:40:00.000Z' WHERE title = 'Mitt första surdegsbröd';
UPDATE posts SET created = '2026-09-05 12:00:00.000Z' WHERE title = 'Brädspelskväll på fredag';
UPDATE posts SET created = '2026-09-08 07:30:00.000Z' WHERE title = 'Milen under 50 minuter!';
UPDATE posts SET created = '2026-09-25 09:00:00.000Z' WHERE title = 'Hej Kvittra!';
UPDATE posts SET created = '2026-09-28 08:10:00.000Z' WHERE title = 'Kaffe efter löprundan';
UPDATE posts SET created = '2026-10-04 08:00:00.000Z' WHERE title = 'Kanelbullens dag';
UPDATE posts SET created = '2026-10-07 12:30:00.000Z' WHERE title = 'Brädspelskväll igen?';
UPDATE posts SET created = '2026-10-10 14:00:00.000Z' WHERE title = 'Halvmaran avklarad';
UPDATE posts SET created = '2026-10-11 06:45:00.000Z' WHERE title = 'Morgondimma';
SELECT title, created FROM posts ORDER BY created;
```

Den sista raden visar resultatet: tio inlägg med datum från 1 september till
11 oktober 2026. Alla tider lagras i UTC som text i formatet
`'YYYY-MM-DD HH:MM:SS.sssZ'`.

---

## Så kör du SQL i PocketBase

Det finns två ställen där du skriver SQL i den här modulen:

| Verktyg | Var | Används till |
|---------|-----|--------------|
| **View collection** | **New collection** → typ **View** | Alla `SELECT`-övningar. Frågan sparas som en collection som du bläddrar i som vilken tabell som helst. |
| **SQL console** | **Settings** → **SQL console** | Ändringar (`INSERT`, `UPDATE`, `DELETE`), transaktioner, `EXPLAIN QUERY PLAN` och snabbtester. |

### Skapa en View collection

1. Klicka **New collection**, skriv ett namn (t.ex. `ovning_1_1`) och välj
   typen **View** i stället för Base.
2. Skriv din `SELECT`-fråga i fältet **Select query**.
3. Klicka **Create**. PocketBase kontrollerar frågan och skapar fälten
   automatiskt utifrån kolumnerna.
4. Klicka på den nya collectionen i menyn för att se raderna. Ändra frågan via
   kugghjulet bredvid namnet.

Tre regler för views i PocketBase:

- **Frågan måste ha en kolumn som heter `id`**, med ett unikt värde per rad.
  Ofta finns ett naturligt id (`SELECT p.id, p.title ...`). Saknas det – t.ex.
  när du räknar med `COUNT` – lägger du till
  `(ROW_NUMBER() OVER ()) AS id` först i `SELECT`. Glömmer du det får du felet
  *"Invalid query - missing required id column"*.
- **Bara `SELECT`.** En view kan inte ändra data.
- **`ORDER BY` i frågan bestämmer ordningen** i listan (så länge du inte klickar
  på en kolumnrubrik för att sortera om).

💡 **Tips:** Döp dina views efter övningen, t.ex. `ovning_2_3`, så hittar du dem
igen. PocketBase sparar dessutom varje ändring du gör i Dashboard som en fil i
mappen `pb_migrations/`.

### SQL console – och en viktig varning

SQL console kör det du skriver direkt mot databasen. Du kan köra flera satser på
en gång (avsluta varje med `;`), men bara resultatet från den **sista** visas.

⚠️ **Varning:** SQL console går *förbi* PocketBase. Inga regler, ingen
validering och ingen *cascade delete* – det sköts av PocketBase, inte av
SQLite. Använd den för att öva, inte för att administrera en riktig app.

⚠️ **Varning:** Skriver du `BEGIN;` måste `COMMIT;` eller `ROLLBACK;` stå i
**samma** körning. Glömmer du det, eller om en sats misslyckas efter `BEGIN`,
blir transaktionen hängande och PocketBase slutar svara på ändringar. Lösning:
stoppa servern med `Ctrl + C` och starta den igen – den halvfärdiga
transaktionen ångras då automatiskt. Mer om transaktioner i
[kapitel 3](03-acid-och-transaktioner.md).

💡 **Tips:** Databasen är en vanlig SQLite-fil: `pb_data/data.db`. Vill du kan du
öppna den med t.ex. DB Browser for SQLite för att titta – men ändra inget där
medan PocketBase kör.

### Börja om från början

Har du förstört datan i en övning? Antingen rättar du den i Dashboard, eller så
börjar du om helt: stoppa servern, ta bort mappen `pb_data/` och gör steg 2
igen. (Dina collections finns kvar som filer i `pb_migrations/` och skapas
automatiskt igen, så då behöver du bara skapa superusern och mata in datan.)

## Om exempeldatan

Kvittra har 6 användare, 10 inlägg, 13 kommentarer, 19 gillningar och 10
följ-relationer. Den är liten nog att mata in för hand men räcker för att varje
övning ska få ett intressant svar: det finns inlägg utan kommentarer, inlägg
utan gillningar, användare som inte skrivit något, ömsesidiga följare och en
användare som gillat sitt eget inlägg. **Dagens datum är måndag 12 oktober
2026**, så "senaste veckan" betyder från och med `'2026-10-05'`.

Nästa steg: [Kapitel 1 – Vad är en databas?](01-vad-ar-en-databas.md)

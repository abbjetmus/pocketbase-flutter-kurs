# Modul 02 – PocketBase

I modul 01 lärde du dig vad en databas är, hur man skriver SQL och hur man
designar tabeller med primärnycklar och främmande nycklar. I den här modulen tar
vi samma datamodell (Kvittra) och bygger en riktig **backend** av den med
[PocketBase](https://pocketbase.io/).

När modulen är klar har du en server som:

- lagrar användare, inlägg, kommentarer, gillningar och följningar,
- låter användare registrera sig och logga in,
- bestämmer vem som får läsa och ändra vad,
- svarar på HTTP-anrop från en app (REST) och skickar nya kommentarer i realtid,
- stoppar spam och fusk med egen serverkod (hooks),
- går att återskapa på en annan dator med hjälp av migrationer.

Det är precis den backend som Flutter-appen i modul 03–04 – och din egen app – kommer att prata med.

## Förkunskaper

- Modul 01, särskilt [SQL-grunder](../01-databaser/02-sql-grunder.md),
  [ACID och transaktioner](../01-databaser/03-acid-och-transaktioner.md) och
  [databasdesign](../01-databaser/04-databasdesign.md).
- Du kan öppna en terminal och köra kommandon.
- Lite JavaScript-läsförståelse hjälper i kapitel 7–8, men det är inget krav.

## Allt görs i PocketBase

Alla övningar görs direkt i PocketBase: i Dashboard (Admin UI), med `curl` mot
REST-API:t, med JavaScript i `pb_hooks/` och med migrationer i
`pb_migrations/`. Du behöver inga andra databasverktyg.

⚠️ **Varning:** I modul 01 körde du PocketBase med ett färdigt Kvittra-schema och
testdata. Starta modul 02 i en **ny, tom mapp** (t.ex. `kvittra-pb`) med en
egen, tom `pb_data`. Här bygger du schemat själv, steg för steg, och då får
det inte krocka med collections som redan finns.

## Version

Materialet är skrivet för och testat med **PocketBase v0.39** (0.39.4) och
Dart-paketet **`pocketbase` 0.23 eller senare**. PocketBase gjorde stora
ändringar i v0.23 (t.ex. heter kolumnerna i en collection nu `fields` i stället
för `schema`, och "admins" heter nu "superusers"). Om du googlar och hittar
exempel med `schema:`, `$app.dao()` eller `onRecordBeforeCreateRequest` så är
de skrivna för en gammal version och fungerar inte rakt av.

## Lärandemål

Efter modulen ska du kunna:

1. Förklara vad PocketBase är och hur det skiljer sig från att skriva en egen
   backend.
2. Installera och starta PocketBase, skapa en superuser och hitta runt i
   Dashboard (Admin UI).
3. Skapa collections av typerna `base`, `auth` och `view`, välja rätt fälttyp
   och se hur de motsvarar SQL-tabeller i SQLite.
4. Modellera 1:N- och N:M-relationer med relationsfält och
   kopplings-collections, och hämta relaterad data med `expand` och
   back-relationer.
5. Skriva API-regler som skyddar data per åtgärd (list, view, create, update,
   delete) och känna igen vanliga säkerhetsmisstag.
6. Anropa REST-API:t med `curl`, och använda `filter`, `sort`, `expand`,
   `fields` och paginering – till exempel för att bygga ett flöde med inlägg
   från dem du följer.
7. Använda Dart-SDK:n för inloggning, CRUD, filter, realtid och felhantering
   och mappa poster till Dart-klasser.
8. Skriva JavaScript-hooks för validering, egna endpoints, transaktioner och
   schemalagda jobb, och versionshantera databasstrukturen med migrationer.
9. Bygga ut modellen med grupper: regler som styr synlighet, roller som
   kontrolleras i hooks, server-stämplade fält och notiser.

## Innehåll

| Kapitel | Innehåll |
|---------|----------|
| [01 – Vad är PocketBase?](01-vad-ar-pocketbase.md) | BaaS vs egen backend, installation, superuser, mappstruktur, SQLite under huven |
| [02 – Collections och fält](02-collections-och-falt.md) | Collection-typer, alla fälttyper, fältinställningar, index, jämförelse med `CREATE TABLE` |
| [03 – Relationer](03-relationer.md) | Relationsfält, 1:N, N:M (gillningar), självrefererande N:M (följningar), `expand`, back-relationer |
| [04 – Autentisering och API-regler](04-autentisering-och-api-regler.md) | Auth-collections, registrering och inloggning, regler per åtgärd, regler för hela Kvittra, säkerhetsmisstag |
| [05 – REST-API och filter](05-rest-api-och-filter.md) | Endpoints, `curl`, filter-syntax, flödet, sortering, paginering, datum, realtid |
| [06 – Dart-SDK](06-dart-sdk.md) | `pocketbase`-paketet i Flutter: auth, CRUD, `pb.filter`, gilla/följa, realtid, fel, modellklasser |
| [07 – Hooks och migrationer](07-hooks-och-migrationer.md) | JS-hooks, användarnamn, spamskydd, egna routes, transaktioner, cron, migrationer och git |
| [08 – Grupper, roller och behörigheter](08-grupper-och-behorigheter.md) | Synlighet med back-relationer, server-stämplade fält, roller i hooks, notiser, view med räknare, organisering av hooks |
| [Övningar](ovningar.md) | Steg-för-steg-övningar, Nivå 1–3 |
| [Lösningar](losningar.md) | Lösningsförslag, inklusive en migration som skapar hela schemat |

## Arbetsgång

1. Läs kapitel 1–2 och gör övning 1 (skapa collections).
2. Läs kapitel 3 och gör övning 2 (relationer och testdata).
3. Läs kapitel 4–5 och gör övning 3–5 (regler, curl, filter).
4. Läs kapitel 6. Dart-koden kör du på riktigt först i modul 03, men läs den nu
   så att du vet vad som väntar.
5. Läs kapitel 7 och gör övning 6–8 (hooks, view, N:M).
6. Läs kapitel 8 och gör övning 9–11 (grupper, roller, notiser). De är på
   Nivå 3 och förbereder dig för när du bygger din egen, produktionslika app.

💡 **Tips:** Har du kört fast eller hoppat över något? I
[lösningarna](losningar.md#hela-schemat-som-migration) finns en migration som
bygger hela schemat med testdata, så att du kan komma ikapp på en minut.

## Kvittra i PocketBase – snabböversikt

```
           ┌───────────────── author ─────────────────┐
           ▼                                          │
      ┌─────────┐                                ┌─────────┐
      │  users  │◄─ author ── comments ── post ─►│  posts  │
      │ (auth)  │              (base)            │ (base)  │
      └─────────┘                                └─────────┘
       ▲   ▲   ▲                                      ▲
       │   │   └──── user ──── likes ──── post ───────┘
       │   │                   (base)
       └───┴── follower / following ── follows (base)
```

Pilarna går från fältet till den post fältet pekar på – som främmande nycklar i
modul 01.

| Collection | Typ | Viktiga fält |
|------------|-----|--------------|
| `users` | auth | `email`, `password`, `username` (text, unikt index), `name`, `bio`, `website` (url), `avatar` (file) |
| `posts` | base | `author` (relation → users), `title` (text), `body` (text), `image` (file), `created`, `updated` |
| `comments` | base | `post` (relation → posts, cascade delete), `author` (relation → users), `body` (text) |
| `likes` | base | `post` (relation → posts, cascade delete), `user` (relation → users, cascade delete). Unikt index på `(post, user)` |
| `follows` | base | `follower` (relation → users), `following` (relation → users), båda cascade delete. Unikt index på `(follower, following)` |

`likes` och `follows` är **kopplings-collections** (N:M), precis som
kopplingstabellerna i modul 01. Det är de som gör Kvittra till en *social* app,
och det är de som API-reglerna i kapitel 4 och flödet i kapitel 5 bygger på.

I kapitel 8 byggs modellen ut med `groups`, `group_members` (roller `admin`,
`moderator`, `member`), ett valfritt fält `posts.group`, `notifications` och
view-collectionen `posts_view`.

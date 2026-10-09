# Modul 02 – PocketBase

I modul 01 lärde du dig vad en databas är, hur man skriver SQL och hur man
designar tabeller med primärnycklar och främmande nycklar. I den här modulen tar
vi samma datamodell (Föreningsappen) och bygger en riktig **backend** av den med
[PocketBase](https://pocketbase.io/).

När modulen är klar har du en server som:

- lagrar lägenheter, medlemmar, resurser, bokningar och anslag,
- låter medlemmar logga in,
- bestämmer vem som får läsa och ändra vad,
- svarar på HTTP-anrop från en app (REST) och skickar ändringar i realtid,
- stoppar dubbelbokningar med egen serverkod (hooks),
- går att återskapa på en annan dator med hjälp av migrationer.

Det är precis den backend som Flutter-appen i modul 03–04 – och din egen app – kommer att prata med.

## Förkunskaper

- Modul 01, särskilt [SQL-grunder](../01-databaser/02-sql-grunder.md),
  [ACID och transaktioner](../01-databaser/03-acid-och-transaktioner.md) och
  [databasdesign](../01-databaser/04-databasdesign.md).
- Du kan öppna en terminal och köra kommandon.
- Lite JavaScript-läsförståelse hjälper i kapitel 7, men det är inget krav.

## Version

Materialet är skrivet för **PocketBase v0.39** och Dart-paketet
**`pocketbase` 0.23 eller senare**. PocketBase gjorde stora ändringar i v0.23
(t.ex. heter kolumnerna i en collection nu `fields` i stället för `schema`, och
"admins" heter nu "superusers"). Om du googlar och hittar exempel med
`schema:`, `$app.dao()` eller `onRecordBeforeCreateRequest` så är de skrivna för
en gammal version och fungerar inte rakt av.

## Lärandemål

Efter modulen ska du kunna:

1. Förklara vad PocketBase är och hur det skiljer sig från att skriva en egen
   backend.
2. Installera och starta PocketBase, skapa en superuser och hitta runt i
   Dashboard (Admin UI).
3. Skapa collections av typerna `base`, `auth` och `view`, välja rätt fälttyp
   och se hur de motsvarar SQL-tabeller i SQLite.
4. Modellera 1:N- och N:M-relationer med relationsfält, och hämta relaterad
   data med `expand` och back-relationer.
5. Skriva API-regler som skyddar data per åtgärd (list, view, create, update,
   delete) och känna igen vanliga säkerhetsmisstag.
6. Anropa REST-API:t med `curl`, och använda `filter`, `sort`, `expand`,
   `fields` och paginering.
7. Använda Dart-SDK:n för inloggning, CRUD, filter, realtid och felhantering
   och mappa poster till Dart-klasser.
8. Skriva JavaScript-hooks för validering, egna endpoints och schemalagda
   jobb, och versionshantera databasstrukturen med migrationer.
9. Bygga en backend för många föreningar samtidigt (multi-tenancy) med roller,
   en behörighetsmatris, server-stämplade fält och notiser.

## Innehåll

| Kapitel | Innehåll |
|---------|----------|
| [01 – Vad är PocketBase?](01-vad-ar-pocketbase.md) | BaaS vs egen backend, installation, superuser, mappstruktur, SQLite under huven |
| [02 – Collections och fält](02-collections-och-falt.md) | Collection-typer, alla fälttyper, fältinställningar, index, jämförelse med `CREATE TABLE` |
| [03 – Relationer](03-relationer.md) | Relationsfält, 1:N, N:M, `expand`, back-relationer, filtrering över relationer |
| [04 – Autentisering och API-regler](04-autentisering-och-api-regler.md) | Auth-collections, inloggning, regler per åtgärd, regler för hela Föreningsappen, säkerhetsmisstag |
| [05 – REST-API och filter](05-rest-api-och-filter.md) | Endpoints, `curl`, filter-syntax, sortering, paginering, datum, realtid |
| [06 – Dart-SDK](06-dart-sdk.md) | `pocketbase`-paketet i Flutter: auth, CRUD, `pb.filter`, expand, realtid, fel, modellklasser |
| [07 – Hooks och migrationer](07-hooks-och-migrationer.md) | JS-hooks, validering av bokningar, egna routes, cron, transaktioner, migrationer och git |
| [08 – Flera föreningar, roller och behörigheter](08-flera-foreningar-och-behorigheter.md) | Multi-tenancy, server-stämplade fält, behörighetsmatris, notiser, view med aggregat, organisering av hooks |
| [Övningar](ovningar.md) | Steg-för-steg-övningar, Nivå 1–3 |
| [Lösningar](losningar.md) | Lösningsförslag, inklusive en migration som skapar hela schemat |

## Arbetsgång

1. Läs kapitel 1–2 och gör övning 1 (skapa collections).
2. Läs kapitel 3 och gör övning 2 (relationer och testdata).
3. Läs kapitel 4–5 och gör övning 3–5 (regler, curl, filter).
4. Läs kapitel 6. Dart-koden kör du på riktigt först i modul 03, men läs den nu
   så att du vet vad som väntar.
5. Läs kapitel 7 och gör övning 6–8 (hook, view, N:M).
6. Läs kapitel 8 och gör övning 9–11 (flera föreningar, behörighetsmatris,
   notiser). De är på Nivå 3 och förbereder dig för när du bygger din egen,
   produktionslika app.

💡 **Tips:** Har du kört fast eller hoppat över något? I
[lösningarna](losningar.md#hela-schemat-som-migration) finns en migration som
bygger hela schemat med testdata, så att du kan komma ikapp på en minut.

## Föreningsappen i PocketBase – snabböversikt

```
apartments ◄──── users ◄──────────┬──────────── posts
  (base)          (auth)          │             (base)
                    ▲             │
                    │ user        │ author
                    │             │
                 bookings ────► resources
                  (base) resource  (base)
```

| Collection | Typ | Viktiga fält |
|------------|-----|--------------|
| `apartments` | base | `number` (text), `floor` (number), `size_sqm` (number) |
| `users` | auth | `email`, `password`, `name`, `apartment` (relation), `role` (select) |
| `resources` | base | `name` (text), `description` (text), `max_hours` (number), `active` (bool) |
| `bookings` | base | `resource` (relation), `user` (relation), `start` (date), `end` (date), `note` (text) |
| `posts` | base | `title` (text), `body` (editor), `author` (relation), `published` (bool), `created` (autodate) |

Fältet `role` på `users` blir i PocketBase ett select-fält med värdena
`member`, `styrelse` och `admin`. Det är det fältet som API-reglerna i kapitel 4
bygger på.

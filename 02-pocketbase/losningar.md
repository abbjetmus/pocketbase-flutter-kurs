# Lösningar – Modul 02: PocketBase

Det här är **lösningsförslag**. Det finns ofta flera rätta sätt. Jämför med din
egen lösning och fundera på skillnaderna – särskilt när det gäller
API-reglerna, där små skillnader kan betyda stora säkerhetshål.

Id:n som `flskfapcqwu5iun` i exemplen är slumpade och blir andra hos dig.

## Innehåll

- [Hela schemat som migration](#hela-schemat-som-migration) (kom ikapp på en minut)
- [Övning 1](#övning-1) · [2](#övning-2) · [3](#övning-3) · [4](#övning-4) ·
  [5](#övning-5) · [6](#övning-6) · [7](#övning-7) · [8](#övning-8) ·
  [9–11](#övning-911) · [12](#övning-12)
- [Utbyggnad: flera föreningar](#utbyggnad-flera-föreningar) (migration för kapitel 8)

---

## Hela schemat som migration

Lägg filerna i `pb_migrations/` och starta servern (eller kör
`./pocketbase migrate up`). Den första skapar alla collections med fält,
index och API-regler från kapitel 2–4. Den andra lägger in testdatan från
övning 2.

⚠️ **Varning:** Kör dem i en **ny, tom** projektmapp (ta bort `pb_data` först
om du redan har skapat collections för hand – annars krockar namnen). Kör
aldrig testdata-migrationen på en riktig server.

`pb_migrations/1700000000_foreningsappen_schema.js`:

```js
/// <reference path="../pb_data/types.d.ts" />

// Skapar hela datamodellen för Föreningsappen.
migrate((app) => {
  // ---------- apartments ----------
  const apartments = new Collection({
    type: "base",
    name: "apartments",
    listRule: '@request.auth.id != ""',
    viewRule: '@request.auth.id != ""',
    createRule: '@request.auth.role = "admin"',
    updateRule: '@request.auth.role = "admin"',
    deleteRule: '@request.auth.role = "admin"',
    fields: [
      { type: "text", name: "number", required: true, max: 10 },
      { type: "number", name: "floor", onlyInt: true, min: -2, max: 30 },
      { type: "number", name: "size_sqm", min: 0 },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
      { type: "autodate", name: "updated", onCreate: true, onUpdate: true },
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_apartments_number ON apartments (number)",
    ],
  });
  app.save(apartments);

  // ---------- users (finns redan som auth-collection) ----------
  const users = app.findCollectionByNameOrId("users");
  users.fields.add(new RelationField({
    name: "apartment",
    collectionId: apartments.id,
    maxSelect: 1,
    cascadeDelete: false,
  }));
  users.fields.add(new SelectField({
    name: "role",
    values: ["member", "styrelse", "admin"],
    maxSelect: 1,
  }));
  users.listRule = '@request.auth.id != ""';
  users.viewRule = '@request.auth.id != ""';
  users.createRule = null; // bara superuser/admin skapar konton
  users.updateRule =
    'id = @request.auth.id && @request.body.role:isset = false && @request.body.apartment:isset = false';
  users.deleteRule = null;
  app.save(users);

  // ---------- resources ----------
  const resources = new Collection({
    type: "base",
    name: "resources",
    listRule: '@request.auth.id != ""',
    viewRule: '@request.auth.id != ""',
    createRule: '@request.auth.role = "admin"',
    updateRule: '@request.auth.role = "admin"',
    deleteRule: '@request.auth.role = "admin"',
    fields: [
      { type: "text", name: "name", required: true, max: 100 },
      { type: "text", name: "description" },
      { type: "number", name: "max_hours", onlyInt: true, min: 1, max: 48 },
      { type: "bool", name: "active" },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
      { type: "autodate", name: "updated", onCreate: true, onUpdate: true },
    ],
    indexes: ["CREATE UNIQUE INDEX idx_resources_name ON resources (name)"],
  });
  app.save(resources);

  // ---------- bookings ----------
  const bookings = new Collection({
    type: "base",
    name: "bookings",
    listRule:
      'user = @request.auth.id || @request.auth.role = "styrelse" || @request.auth.role = "admin"',
    viewRule:
      'user = @request.auth.id || @request.auth.role = "styrelse" || @request.auth.role = "admin"',
    createRule:
      '@request.auth.id != "" && @request.body.user = @request.auth.id && @request.body.resource.active = true',
    updateRule: 'user = @request.auth.id && @request.body.user:changed = false',
    deleteRule: 'user = @request.auth.id || @request.auth.role = "admin"',
    fields: [
      {
        type: "relation",
        name: "resource",
        collectionId: resources.id,
        maxSelect: 1,
        required: true,
        cascadeDelete: true,
      },
      {
        type: "relation",
        name: "user",
        collectionId: users.id,
        maxSelect: 1,
        required: true,
        cascadeDelete: true,
      },
      { type: "date", name: "start", required: true },
      { type: "date", name: "end", required: true },
      { type: "text", name: "note", max: 500 },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
      { type: "autodate", name: "updated", onCreate: true, onUpdate: true },
    ],
    indexes: [
      "CREATE INDEX idx_bookings_resource_start ON bookings (resource, start)",
      "CREATE INDEX idx_bookings_user ON bookings (user)",
    ],
  });
  app.save(bookings);

  // ---------- posts ----------
  const posts = new Collection({
    type: "base",
    name: "posts",
    listRule:
      '@request.auth.id != "" && (published = true || author = @request.auth.id)',
    viewRule:
      '@request.auth.id != "" && (published = true || author = @request.auth.id)',
    createRule:
      '(@request.auth.role = "styrelse" || @request.auth.role = "admin") && @request.body.author = @request.auth.id',
    updateRule: 'author = @request.auth.id && @request.body.author:changed = false',
    deleteRule: 'author = @request.auth.id || @request.auth.role = "admin"',
    fields: [
      { type: "text", name: "title", required: true, max: 200 },
      { type: "editor", name: "body" },
      {
        type: "relation",
        name: "author",
        collectionId: users.id,
        maxSelect: 1,
        required: true,
        cascadeDelete: false,
      },
      { type: "bool", name: "published" },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
      { type: "autodate", name: "updated", onCreate: true, onUpdate: true },
    ],
  });
  app.save(posts);
}, (app) => {
  // Nedgradering: ta bort i omvänd ordning
  for (const name of ["posts", "bookings", "resources"]) {
    app.delete(app.findCollectionByNameOrId(name));
  }
  const users = app.findCollectionByNameOrId("users");
  users.fields.removeByName("role");
  users.fields.removeByName("apartment");
  app.save(users);
  app.delete(app.findCollectionByNameOrId("apartments"));
});
```

`pb_migrations/1700000001_testdata.js`:

```js
/// <reference path="../pb_data/types.d.ts" />

// TESTDATA – kör bara lokalt, aldrig i produktion.
migrate((app) => {
  const save = (collectionName, data) => {
    const record = new Record(app.findCollectionByNameOrId(collectionName));
    record.load(data);
    app.save(record);
    return record;
  };

  const a1001 = save("apartments", { number: "1001", floor: 1, size_sqm: 54.5 });
  const a1002 = save("apartments", { number: "1002", floor: 1, size_sqm: 72 });
  const a2001 = save("apartments", { number: "2001", floor: 2, size_sqm: 88 });
  const a3001 = save("apartments", { number: "3001", floor: 3, size_sqm: 61 });

  const users = app.findCollectionByNameOrId("users");
  const person = (email, name, role, apartment) => {
    const u = new Record(users);
    u.set("email", email);
    u.set("name", name);
    u.set("role", role);
    u.set("apartment", apartment.id);
    u.set("verified", true);
    u.setPassword("hemligt123");
    app.save(u);
    return u;
  };

  const anna = person("anna@example.com", "Anna Andersson", "member", a1001);
  const bo = person("bo@example.com", "Bo Berg", "styrelse", a1002);
  const cecilia = person("cecilia@example.com", "Cecilia Ek", "member", a2001);
  person("david@example.com", "David Dahl", "admin", a3001);

  const t1 = save("resources", { name: "Tvättstuga 1", description: "Källaren, hus A", max_hours: 3, active: true });
  const t2 = save("resources", { name: "Tvättstuga 2", description: "Källaren, hus B", max_hours: 3, active: true });
  const fest = save("resources", { name: "Festlokalen", description: "Plats för 40 personer", max_hours: 12, active: true });
  save("resources", { name: "Bastun", description: "Stängd för renovering", max_hours: 2, active: false });

  save("bookings", { resource: t1.id, user: anna.id, start: "2026-11-02 07:00:00.000Z", end: "2026-11-02 09:00:00.000Z", note: "Två maskiner" });
  save("bookings", { resource: t1.id, user: cecilia.id, start: "2026-11-02 09:00:00.000Z", end: "2026-11-02 12:00:00.000Z", note: "" });
  save("bookings", { resource: t2.id, user: bo.id, start: "2026-11-03 16:00:00.000Z", end: "2026-11-03 18:00:00.000Z", note: "" });
  save("bookings", { resource: fest.id, user: anna.id, start: "2026-11-14 15:00:00.000Z", end: "2026-11-14 23:00:00.000Z", note: "40-årsfest" });
  save("bookings", { resource: fest.id, user: bo.id, start: "2026-11-21 10:00:00.000Z", end: "2026-11-21 14:00:00.000Z", note: "Styrelsemöte" });

  save("posts", { title: "Välkommen till appen!", body: "<p>Här hittar du anslag och bokningar.</p>", author: bo.id, published: true });
  save("posts", { title: "Städdag 1 november", body: "<p>Vi ses på gården kl. 10.</p>", author: bo.id, published: true });
  save("posts", { title: "Utkast: ny tvättstugeordning", body: "<p>Ej klart.</p>", author: bo.id, published: false });
}, (app) => {
  // Töm testdatan (ordningen spelar roll p.g.a. relationerna)
  for (const name of ["posts", "bookings", "resources"]) {
    for (const r of app.findAllRecords(name)) app.delete(r);
  }
  for (const email of ["anna", "bo", "cecilia", "david"]) {
    try { app.delete(app.findAuthRecordByEmail("users", email + "@example.com")); } catch (_) {}
  }
  for (const r of app.findAllRecords("apartments")) app.delete(r);
});
```

Alla användare har lösenordet `hemligt123`. Skapa sedan en superuser:

```bash
./pocketbase superuser upsert admin@example.com EttLangtLosenord123
```

---

## Övning 1

a) `start` blev `TEXT` (datum lagras som text i UTC). `active` blev
`BOOLEAN`.

b) Nej. PocketBase skapar inga `FOREIGN KEY`-constraints. Relationsfält är
vanliga `TEXT`-kolumner (eller `JSON` för multi), och PocketBase kontrollerar
själv att id:na finns och sköter cascade delete. Därför ska data alltid
ändras via API:t eller Dashboard, aldrig direkt med SQL.

c) En fil per ändring du gjort i Dashboard (skapa collection, ändra
`users`, ...). Automigrate skapar dem automatiskt så att strukturen kan
versionshanteras.

---

## Övning 2

2. Dashboard visar namnen (t.ex. "Tvättstuga 1", "Anna Andersson") i stället
   för id:n i relationskolumnerna.

3. Det går inte:
   `Failed to delete record. Make sure that the record is not part of a required relation reference.`
   `posts.author` är *required* och har **inte** cascade delete. Att ta bort Bo
   skulle lämna anslag utan författare, så PocketBase vägrar (som
   `ON DELETE RESTRICT`). Ta bort eller flytta Bos anslag först. (Om Bo bara
   hade haft bokningar hade det gått – de har cascade delete och hade
   försvunnit med honom.)

4. Bokningarna av Tvättstuga 2 tas bort automatiskt, eftersom
   `bookings.resource` har **cascade delete**.

---

## Övning 3

### Reglerna

| Collection | List / View | Create | Update | Delete |
|------------|-------------|--------|--------|--------|
| `apartments` | `@request.auth.id != ""` | `@request.auth.role = "admin"` | `@request.auth.role = "admin"` | `@request.auth.role = "admin"` |
| `resources` | `@request.auth.id != ""` | `@request.auth.role = "admin"` | `@request.auth.role = "admin"` | `@request.auth.role = "admin"` |
| `bookings` | `user = @request.auth.id \|\| @request.auth.role = "styrelse" \|\| @request.auth.role = "admin"` | `@request.auth.id != "" && @request.body.user = @request.auth.id && @request.body.resource.active = true` | `user = @request.auth.id && @request.body.user:changed = false` | `user = @request.auth.id \|\| @request.auth.role = "admin"` |
| `posts` | `@request.auth.id != "" && (published = true \|\| author = @request.auth.id)` | `(@request.auth.role = "styrelse" \|\| @request.auth.role = "admin") && @request.body.author = @request.auth.id` | `author = @request.auth.id && @request.body.author:changed = false` | `author = @request.auth.id \|\| @request.auth.role = "admin"` |
| `users` | `@request.auth.id != ""` | `null` (låst) | `id = @request.auth.id && @request.body.role:isset = false && @request.body.apartment:isset = false` | `null` (låst) |

(I tabellen står `\|\|` för att Markdown-tabellen inte ska gå sönder. I
Dashboard skriver du `||`.)

### Förväntade resultat

| # | Som | Försök | Resultat |
|---|-----|--------|----------|
| 1 | utloggad | Lista `resources` | `200` med **tom** lista (list-regeln filtrerar bort allt) |
| 2 | Anna | Lista `bookings` | `200`, bara Annas bokningar |
| 3 | Bo | Lista `bookings` | `200`, alla bokningar |
| 4 | Anna | Boka i eget namn | `200`, bokningen skapas |
| 5 | Anna | Boka i Cecilias namn | `400 Failed to create record.` |
| 6 | Anna | Boka Bastun (inaktiv) | `400 Failed to create record.` |
| 7 | Anna | Ändra `note` | `200` |
| 8 | Anna | Byta `user` till Cecilia | `404` |
| 9 | Anna | Ta bort Cecilias bokning | `404` |
| 10 | Anna | Skapa anslag | `400 Failed to create record.` |
| 11 | Anna | Lista `posts` | `200`, utkastet syns **inte** |
| 12 | Anna | Sätta `role` till `admin` | `404` |
| 13 | Anna | Ändra eget `name` | `200` |

**Varför 404?** För view, update och delete letar PocketBase upp posten *med
regeln som villkor*. Om regeln inte är uppfylld "finns" posten inte för dig.
Det är en säkerhetsfördel: ett `403` skulle avslöja att posten existerar.
Create har ingen befintlig post att leta upp, därför `400`. Regler som är
`null` ger `403` ("Only superusers can perform this action.").

---

## Övning 4

```bash
B=http://127.0.0.1:8090

# 1. Logga in
TOKEN=$(curl -s -X POST $B/api/collections/users/auth-with-password \
  -H "Content-Type: application/json" \
  -d '{"identity":"anna@example.com","password":"hemligt123"}' \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["token"])')

# Annas id (behövs när hon bokar)
ME=$(curl -s -X POST $B/api/collections/users/auth-refresh -H "Authorization: $TOKEN" \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["record"]["id"])')

# 2. Lista resurser
curl -s $B/api/collections/resources/records -H "Authorization: $TOKEN"

# 3. Hämta en (byt ut id)
curl -s $B/api/collections/resources/records/RESURS_ID -H "Authorization: $TOKEN"

# 4. Skapa bokning
curl -s -X POST $B/api/collections/bookings/records \
  -H "Authorization: $TOKEN" -H "Content-Type: application/json" \
  -d "{\"resource\":\"RESURS_ID\",\"user\":\"$ME\",
       \"start\":\"2026-11-10 08:00:00Z\",\"end\":\"2026-11-10 10:00:00Z\"}"

# 5. Ändra
curl -s -X PATCH $B/api/collections/bookings/records/BOKNINGS_ID \
  -H "Authorization: $TOKEN" -H "Content-Type: application/json" \
  -d '{"note":"Glöm inte tvättmedel"}'

# 6. Ta bort → 204
curl -s -X DELETE $B/api/collections/bookings/records/BOKNINGS_ID \
  -H "Authorization: $TOKEN" -w "%{http_code}\n"
```

7. Svaret innehåller fel per fält:

```json
{"data":{"start":{"code":"validation_required","message":"Cannot be blank."}},
 "message":"Failed to create record.","status":400}
```

(Om hooken från övning 6 redan finns kommer PocketBases fältvalidering
fortfarande först, eftersom hooken anropar `e.next()` innan den kör sina egna
kontroller.)

8. David (admin) får `200` och resursen skapas. Anna får
   `400 Failed to create record.` eftersom create-regeln kräver
   `@request.auth.role = "admin"`.

---

## Övning 5

Alla svar är testade mot testdatan. Skicka dem med
`curl -G ... --data-urlencode 'filter=...'`.

| # | Collection | Parametrar |
|---|------------|------------|
| 1 | `resources` | `filter=active = true` `sort=name` |
| 2 | `apartments` | `filter=(floor = 1 \|\| floor = 2) && size_sqm > 60` |
| 3 | `bookings` | `filter=resource.name = "Festlokalen"` `sort=-start` |
| 4 | `bookings` | `filter=start >= "2026-11-01 00:00:00" && start < "2026-12-01 00:00:00"` `expand=resource,user` `fields=id,start,end,expand.resource.name,expand.user.name` |
| 5 | `bookings` | `filter=note != ""` |
| 6 | `bookings` | Går **inte** direkt – se nedan |
| 7 | `bookings` | `filter=user.apartment.floor = 1` |
| 8 | `resources` | `expand=bookings_via_resource` `fields=name,expand.bookings_via_resource.start` |
| 9 | `users` | `filter=posts_via_author.published ?= true` |
| 10 | `bookings` | `page=2` `perPage=2` – med 5 bokningar blir `totalPages` 3 |
| 11 | `posts` | `filter=published = true` `sort=-created` `fields=id,title,body:excerpt(50,true)` |
| 12 | `bookings` (som Anna) | `filter=start >= @now` `sort=start` `expand=resource` |

**6.** Filterspråket kan inte räkna (`end - start` ger fel). Alternativ:

- Lägg till ett number-fält `hours` som en hook räknar ut vid varje sparning,
  och filtrera `hours > 2`.
- Gör en view-collection som räknar ut längden med
  `(julianday(end) - julianday(start)) * 24` (se övning 7).
- Hämta bokningarna och filtrera i appen (bara om de är få).

**12.** List-regeln ser redan till att Anna bara får sina egna bokningar,
så `start >= @now` räcker. Vill du vara tydlig kan du lägga till
`user = "<Annas id>"` – men **inte** `user = @request.auth.id`, för `@request`
får inte användas i klientens filter (`403`). `@now` är däremot tillåtet.

---

## Övning 6

1. Koden finns i [kapitel 7](07-hooks-och-migrationer.md#exempel-2-ingen-dubbelbokning-och-max_hours)
   (`booking_utils.js` + `bookings.pb.js` med `onRecordValidate`).

3. Ja, den stoppas även i Dashboard. `onRecordValidate` är en *model hook*
   som körs vid varje sparning, oavsett källa. Bra, eftersom regeln om
   dubbelbokning gäller datan – inte vem som frågar.

4. En kvot per medlem gäller **vem som frågar** och ska inte gälla
   superusers, så en request hook passar:

```js
/// <reference path="../pb_data/types.d.ts" />

// Högst 2 kommande tvättstugebokningar per medlem.
onRecordCreateRequest((e) => {
  if (!e.hasSuperuserAuth()) {
    const resource = e.app.findRecordById("resources", e.record.getString("resource"));
    if (resource.getString("name").indexOf("Tvättstuga") === 0) {
      const upcoming = e.app.findRecordsByFilter(
        "bookings",
        "user = {:user} && end > @now && resource.name ~ 'Tvättstuga%'",
        "", 3, 0,
        { user: e.record.getString("user") },
      );
      if (upcoming.length >= 2) {
        throw new BadRequestError("Du har redan 2 kommande tvättider.");
      }
    }
  }
  e.next();
}, "bookings");
```

💡 Snyggare: lägg ett number-fält `max_upcoming_per_user` på `resources` i
stället för att leta efter namnet "Tvättstuga".

5. I teorin kan två anrop som kommer *exakt* samtidigt båda passera
   kontrollen innan någon av dem hunnit spara (en *race condition*, se
   isolering i ACID-kapitlet). SQLite skriver bara en transaktion i taget,
   vilket gör fönstret mycket litet, men det är inte noll. Sätt att minska
   risken:
   - Gör kontrollen och sparningen i **samma transaktion** – t.ex. en egen
     route som kör `runInTransaction` och där kontrollen sker med `txApp`.
   - För fasta tidsluckor (t.ex. tvättpass 07–10, 10–13): lägg till ett fält
     `slot` och ett **unikt index** på `(resource, slot)`. Då garanterar
     databasen själv att det aldrig blir dubbelt.

---

## Övning 7

1–2. **+ New collection → View**, namn `resource_stats`, fråga:

```sql
SELECT r.id, r.name,
       COUNT(b.id)  AS bookings_count,
       MAX(b.start) AS last_booking
FROM resources r
LEFT JOIN bookings b ON b.resource = r.id
GROUP BY r.id
```

List/View-regel: `@request.auth.id != ""`.

3. `GET /api/collections/resource_stats/records?sort=-bookings_count`

4. `bookings_count` räknar **alla** bokningar – view-frågan går inte genom
   reglerna på `bookings`. Här är det ofarligt (bara antal per resurs). Det
   vore ett problem om viewn visade *vem* som bokat eller anteckningar, eller
   om den kunde filtreras så att man kan räkna ut något hemligt (t.ex. antal
   bokningar per enskild användare). Viewns egna regler är det enda skyddet.

5. Bokade timmar per lägenhet:

```sql
SELECT a.id, a.number,
       ROUND(COALESCE(SUM((julianday(b.end) - julianday(b.start)) * 24), 0), 1) AS hours
FROM apartments a
LEFT JOIN users u    ON u.apartment = a.id
LEFT JOIN bookings b ON b.user = u.id
GROUP BY a.id
```

Med testdatan blir det 1001: 10 h, 1002: 6 h, 2001: 3 h, 3001: 0 h.
(PocketBase gissar att `hours` är ett json-fält eftersom det är ett uttryck;
värdet är ändå ett tal och går att sortera på: `sort=-hours`.)

---

## Övning 8

### Del A – taggar (multi-relation)

`pb_migrations/1700000100_tags.js` (alternativ till att klicka i Dashboard):

```js
/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const tags = new Collection({
    type: "base",
    name: "tags",
    listRule: '@request.auth.id != ""',
    viewRule: '@request.auth.id != ""',
    createRule: '@request.auth.role = "styrelse" || @request.auth.role = "admin"',
    updateRule: '@request.auth.role = "styrelse" || @request.auth.role = "admin"',
    deleteRule: '@request.auth.role = "admin"',
    fields: [
      { type: "text", name: "name", required: true, max: 50 },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
      { type: "autodate", name: "updated", onCreate: true, onUpdate: true },
    ],
    indexes: ["CREATE UNIQUE INDEX idx_tags_name ON tags (name)"],
  });
  app.save(tags);

  const posts = app.findCollectionByNameOrId("posts");
  posts.fields.add(new RelationField({
    name: "tags",
    collectionId: tags.id,
    maxSelect: 5,
    cascadeDelete: false,
  }));
  posts.createRule =
    '(@request.auth.role = "styrelse" || @request.auth.role = "admin") && ' +
    '@request.body.author = @request.auth.id && @request.body.tags:length <= 3';
  app.save(posts);

  for (const name of ["tvätt", "fest", "renovering", "styrelsen"]) {
    const record = new Record(tags);
    record.set("name", name);
    app.save(record);
  }
}, (app) => {
  const posts = app.findCollectionByNameOrId("posts");
  posts.fields.removeByName("tags");
  posts.createRule =
    '(@request.auth.role = "styrelse" || @request.auth.role = "admin") && @request.body.author = @request.auth.id';
  app.save(posts);
  app.delete(app.findCollectionByNameOrId("tags"));
});
```

3. Lägga till och ta bort:

```bash
curl -s -X PATCH $B/api/collections/posts/records/POST_ID \
  -H "Authorization: $BO_TOKEN" -H "Content-Type: application/json" \
  -d '{"tags+": "TAGG_ID"}'

curl -s -X PATCH $B/api/collections/posts/records/POST_ID \
  -H "Authorization: $BO_TOKEN" -H "Content-Type: application/json" \
  -d '{"tags-": "TAGG_ID"}'
```

4. `filter=tags.name ?= "fest"` ger alla anslag där **minst en** tagg heter
   fest. `tags.name = "fest"` kräver att **alla** taggar heter fest – ett
   anslag med `["tvätt","fest"]` kommer då inte med.

5. `GET /api/collections/tags/records?expand=posts_via_tags`

6. Create-regeln (se migrationen ovan):

```
(@request.auth.role = "styrelse" || @request.auth.role = "admin") &&
@request.body.author = @request.auth.id &&
@request.body.tags:length <= 3
```

### Del B – anmälningar (kopplings-collection)

`pb_migrations/1700000300_events.js`:

```js
/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const users = app.findCollectionByNameOrId("users");

  const events = new Collection({
    type: "base",
    name: "events",
    listRule: '@request.auth.id != ""',
    viewRule: '@request.auth.id != ""',
    createRule: '@request.auth.role = "styrelse" || @request.auth.role = "admin"',
    updateRule: '@request.auth.role = "styrelse" || @request.auth.role = "admin"',
    deleteRule: '@request.auth.role = "styrelse" || @request.auth.role = "admin"',
    fields: [
      { type: "text", name: "title", required: true, max: 200 },
      { type: "date", name: "date", required: true },
      { type: "number", name: "max_attendees", onlyInt: true, min: 0 },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
      { type: "autodate", name: "updated", onCreate: true, onUpdate: true },
    ],
  });
  app.save(events);

  const attendees = new Collection({
    type: "base",
    name: "event_attendees",
    listRule: '@request.auth.id != ""',
    viewRule: '@request.auth.id != ""',
    // bara sig själv, och bara till framtida aktiviteter
    createRule: '@request.body.user = @request.auth.id && @request.body.event.date > @now',
    updateRule:
      'user = @request.auth.id && @request.body.user:changed = false && @request.body.event:changed = false',
    deleteRule: 'user = @request.auth.id',
    fields: [
      { type: "relation", name: "event", collectionId: events.id, maxSelect: 1, required: true, cascadeDelete: true },
      { type: "relation", name: "user", collectionId: users.id, maxSelect: 1, required: true, cascadeDelete: true },
      { type: "select", name: "status", values: ["yes", "maybe"], maxSelect: 1, required: true },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
      { type: "autodate", name: "updated", onCreate: true, onUpdate: true },
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_event_attendees_event_user ON event_attendees (event, user)",
    ],
  });
  app.save(attendees);
}, (app) => {
  app.delete(app.findCollectionByNameOrId("event_attendees"));
  app.delete(app.findCollectionByNameOrId("events"));
});
```

`pb_hooks/attendees.pb.js`:

```js
/// <reference path="../pb_data/types.d.ts" />

// Stoppa "ja"-anmälningar när aktiviteten är full (max_attendees = 0 betyder obegränsat).
onRecordCreate((e) => {
  if (e.record.getString("status") === "yes") {
    const event = e.app.findRecordById("events", e.record.getString("event"));
    const max = event.getInt("max_attendees");
    if (max > 0) {
      const count = e.app.countRecords(
        "event_attendees",
        $dbx.hashExp({ event: event.id, status: "yes" }),
      );
      if (count >= max) {
        throw new BadRequestError("Aktiviteten är fullbokad.");
      }
    }
  }
  e.next();
}, "event_attendees");
```

💡 **Fundera vidare:** Hooken körs bara vid *create*. Någon som anmält sig
som `maybe` kan sedan ändra till `yes` (update) och komma förbi gränsen. Lös
det genom att också lyssna på `onRecordUpdate` när `status` ändras till
`yes` – och räkna då bort posten själv (`id != ...`) som i
bokningshooken i kapitel 7.

Testat beteende:

| Försök | Resultat |
|--------|----------|
| Anna anmäler sig (`yes`) | OK |
| Anna anmäler sig igen | `400`, `validation_not_unique` på `event`/`user` (unikt index) |
| Bo anmäler sig när `max_attendees` = 1 | `400 Aktiviteten är fullbokad.` |
| Bo anmäler Anna | `400` (create-regeln) |

10. `GET /api/collections/events/records/EVENT_ID?expand=event_attendees_via_event.user`

11. Med en multi-relation `events.attendees`:
    - måste alla medlemmar ha **update**-rätt på hela `events`-posten för att
      kunna anmäla sig – och kan då ändra titel och datum eller ta bort andra
      från listan;
    - finns ingen plats för `status` eller tidpunkt för anmälan;
    - blir det ett race när två personer anmäler sig samtidigt (båda läser
      listan, båda skriver tillbaka – en anmälan kan försvinna);
    - går det inte att sätta ett unikt index mot dubbelanmälan.

---

## Övning 9–11

Koden för hooks, matris, notiser, view och cron finns i sin helhet i
[kapitel 8](08-flera-foreningar-och-behorigheter.md) och är testad i den
mappstruktur som beskrivs där (`main.pb.js` + `collections/`, `cron/`,
`utils/`). Migrationen som bygger strukturen finns
[nedan](#utbyggnad-flera-föreningar).

**9.2** Innan ändringen fanns unika index på bara `name` respektive
`number`. Två föreningar kunde alltså inte ha varsin "Tvättstuga 1".
Med index på `(association, name)` är det bara inom samma förening namnet
måste vara unikt.

**9.5** Exempel på läckor att leta efter:

- `bookings` create-regeln utan `@request.body.resource.association = @request.auth.association`
  → man kan boka en annan förenings resurs.
- `post_comments` create-regel som bara kollar `user` → man kan kommentera
  andra föreningars anslag (och via `expand=post` kanske se dem).
- `posts_view` utan regel på `association` → alla ser alla föreningars
  anslagstitlar.
- `users` list-regel `@request.auth.id != ""` → alla ser alla användare i hela
  systemet.
- En egen route eller cron som returnerar data utan att filtrera på
  `e.auth.getString("association")`.

**10.5** Route som visar vad den inloggade får göra:

```js
/// <reference path="../../pb_data/types.d.ts" />

routerAdd("GET", "/api/foreningen/my-permissions", (e) => {
  const perms = require(`${__hooks}/utils/permissions.js`);
  const areas = ["posts", "resources"];
  const ops = ["read", "create", "update", "delete"];

  const result = {};
  for (const area of areas) {
    result[area] = ops.filter((op) => perms.can(e.app, e.auth, area, op));
  }
  return e.json(200, { role: e.auth.getString("role"), permissions: result });
}, $apis.requireAuth("users"));
```

Lägg filen i `pb_hooks/api/permissions.pb.js` och lägg till
`` require(`${__hooks}/api/permissions.pb.js`); `` i `main.pb.js`. Svar för
Anna (member i Eken) och Cecilia (member i Björken):

```json
{"permissions":{"posts":["read"],"resources":[]},"role":"member"}
{"permissions":{"posts":["read","create"],"resources":[]},"role":"member"}
```

(`resources` är tom tills du lagt till området i matrisen eller i
`DEFAULT_PERMISSIONS` – det är övning 10.4.)

**11.5** Ändra filtret i `notifyAssociation`:

```js
"association = {:a} && id != {:author} && notify_posts = true"
```

---

## Övning 12

Programmet i slutet av [kapitel 6](06-dart-sdk.md#ett-komplett-dart-program)
tillsammans med klasserna `Resource`, `Booking` och `BookingRepository` från
samma kapitel är ett komplett lösningsförslag (testat med Dart-paketet
`pocketbase` 0.23). Realtidsdelen:

```dart
final unsubscribe = await pb.collection('bookings').subscribe('*', (e) {
  print('${e.action}: ${e.record?.id}');
});

// Låt programmet vänta en stund så att du hinner skapa en bokning i Dashboard
await Future.delayed(const Duration(seconds: 60));
await unsubscribe();
```

Tänk på att Anna bara får händelser om bokningar hon får se enligt
list-regeln – skapa alltså en bokning *för Anna* i Dashboard.

---

## Utbyggnad: flera föreningar

Migration för [kapitel 8](08-flera-foreningar-och-behorigheter.md). Den
förutsätter schemat ovan (`1700000000_foreningsappen_schema.js`).

`pb_migrations/1700000500_flera_foreningar.js`:

```js
/// <reference path="../pb_data/types.d.ts" />

// Utbyggnad: flera föreningar i samma backend (multi-tenancy).
migrate((app) => {
  // ---------- associations ----------
  const associations = new Collection({
    type: "base",
    name: "associations",
    listRule: "id = @request.auth.association",
    viewRule: "id = @request.auth.association",
    createRule: null,
    updateRule: null, // behörighetsmatrisen ändras via en egen route eller av superuser
    deleteRule: null,
    fields: [
      { type: "text", name: "name", required: true, max: 200 },
      { type: "json", name: "permissions", maxSize: 20000 },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
      { type: "autodate", name: "updated", onCreate: true, onUpdate: true },
    ],
  });
  app.save(associations);

  // ---------- users.association ----------
  const users = app.findCollectionByNameOrId("users");
  users.fields.add(new RelationField({
    name: "association",
    collectionId: associations.id,
    maxSelect: 1,
    cascadeDelete: false,
  }));
  users.listRule = '@request.auth.id != "" && association = @request.auth.association';
  users.viewRule = '@request.auth.id != "" && association = @request.auth.association';
  users.updateRule =
    'id = @request.auth.id && @request.body.role:isset = false && ' +
    '@request.body.apartment:isset = false && @request.body.association:isset = false';
  app.save(users);

  // ---------- association på allt innehåll ----------
  for (const name of ["apartments", "resources", "bookings", "posts"]) {
    const c = app.findCollectionByNameOrId(name);
    c.fields.add(new RelationField({
      name: "association",
      collectionId: associations.id,
      maxSelect: 1,
      cascadeDelete: true,
    }));
    c.addIndex("idx_" + name + "_association", false, "association", "");
    app.save(c);
  }

  const sameAssoc = "association = @request.auth.association";

  const apartments = app.findCollectionByNameOrId("apartments");
  apartments.listRule = '@request.auth.id != "" && ' + sameAssoc;
  apartments.viewRule = apartments.listRule;
  apartments.createRule = '@request.auth.role = "admin"';
  apartments.updateRule = '@request.auth.role = "admin" && ' + sameAssoc;
  apartments.deleteRule = apartments.updateRule;
  // lägenhetsnummer är unika per förening, inte globalt
  apartments.removeIndex("idx_apartments_number");
  apartments.addIndex("idx_apartments_assoc_number", true, "association, number", "");
  app.save(apartments);

  const resources = app.findCollectionByNameOrId("resources");
  resources.listRule = '@request.auth.id != "" && ' + sameAssoc;
  resources.viewRule = resources.listRule;
  resources.createRule = '@request.auth.role = "admin"';
  resources.updateRule = '@request.auth.role = "admin" && ' + sameAssoc;
  resources.deleteRule = resources.updateRule;
  resources.removeIndex("idx_resources_name");
  resources.addIndex("idx_resources_assoc_name", true, "association, name", "");
  app.save(resources);

  const bookings = app.findCollectionByNameOrId("bookings");
  bookings.listRule =
    sameAssoc + ' && (user = @request.auth.id || @request.auth.role = "styrelse" || @request.auth.role = "admin")';
  bookings.viewRule = bookings.listRule;
  bookings.createRule =
    '@request.auth.id != "" && @request.body.user = @request.auth.id && ' +
    '@request.body.resource.association = @request.auth.association && @request.body.resource.active = true';
  bookings.updateRule = 'user = @request.auth.id && @request.body.user:changed = false';
  bookings.deleteRule =
    'user = @request.auth.id || (@request.auth.role = "admin" && ' + sameAssoc + ')';
  app.save(bookings);

  // posts: läsning via regel, skrivning via behörighetsmatrisen i en hook
  const posts = app.findCollectionByNameOrId("posts");
  posts.listRule =
    '@request.auth.id != "" && ' + sameAssoc + ' && (published = true || author = @request.auth.id)';
  posts.viewRule = posts.listRule;
  posts.createRule = '@request.auth.id != ""';
  posts.updateRule = sameAssoc + ' && @request.body.author:changed = false';
  posts.deleteRule = sameAssoc;
  app.save(posts);

  // ---------- post_comments ----------
  const postComments = new Collection({
    type: "base",
    name: "post_comments",
    listRule: "post.association = @request.auth.association",
    viewRule: "post.association = @request.auth.association",
    createRule:
      '@request.body.user = @request.auth.id && @request.body.post.association = @request.auth.association',
    updateRule: "user = @request.auth.id && @request.body.post:changed = false && @request.body.user:changed = false",
    deleteRule: 'user = @request.auth.id || (@request.auth.role = "admin" && post.association = @request.auth.association)',
    fields: [
      { type: "relation", name: "post", collectionId: posts.id, maxSelect: 1, required: true, cascadeDelete: true },
      { type: "relation", name: "user", collectionId: users.id, maxSelect: 1, required: true, cascadeDelete: true },
      { type: "text", name: "text", required: true, max: 2000 },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
      { type: "autodate", name: "updated", onCreate: true, onUpdate: true },
    ],
    indexes: ["CREATE INDEX idx_post_comments_post ON post_comments (post)"],
  });
  app.save(postComments);

  // ---------- notifications (skrivs bara av servern) ----------
  const notifications = new Collection({
    type: "base",
    name: "notifications",
    listRule: "user = @request.auth.id",
    viewRule: "user = @request.auth.id",
    createRule: null,
    updateRule:
      "user = @request.auth.id && @request.body.user:isset = false && " +
      "@request.body.title:isset = false && @request.body.body:isset = false",
    deleteRule: "user = @request.auth.id",
    fields: [
      { type: "relation", name: "user", collectionId: users.id, maxSelect: 1, required: true, cascadeDelete: true },
      { type: "text", name: "title", required: true, max: 200 },
      { type: "text", name: "body", max: 1000 },
      { type: "text", name: "link", max: 500 },
      { type: "bool", name: "read" },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
      { type: "autodate", name: "updated", onCreate: true, onUpdate: true },
    ],
    indexes: ["CREATE INDEX idx_notifications_user ON notifications (user, read)"],
  });
  app.save(notifications);

  // ---------- posts_view (view med aggregat) ----------
  const postsView = new Collection({
    type: "view",
    name: "posts_view",
    listRule: '@request.auth.id != "" && association = @request.auth.association',
    viewRule: '@request.auth.id != "" && association = @request.auth.association',
    viewQuery: `
      SELECT p.id, p.title, p.author, p.association, p.created,
             COUNT(c.id) AS comments_count
      FROM posts p
      LEFT JOIN post_comments c ON c.post = p.id
      WHERE p.published = TRUE
      GROUP BY p.id
    `,
  });
  app.save(postsView);
});
```

Kommentarer:

- Migrationen saknar nedgraderingsfunktion – den är valfri. Att bygga tillbaka
  allt (ta bort fält, index och collections i rätt ordning) är ett bra extra
  övningsmoment.
- `removeIndex("idx_apartments_number")` tar bort det gamla unika indexet. Har
  du skapat collectionen i Dashboard kan indexet heta något annat – kolla
  namnet under *Indexes*.
- Befintliga poster får ett tomt `association`. Sätt föreningen på dem i
  Dashboard (eller i en migration) innan du testar, annars syns de inte för
  någon.

Testdata för föreningarna (kör som superuser):

```bash
# Två föreningar – Björken får en egen matris där medlemmar får skapa anslag
curl -s -X POST $B/api/collections/associations/records \
  -H "Authorization: $SUPERUSER_TOKEN" -H "Content-Type: application/json" \
  -d '{"name":"Förening Eken"}'

curl -s -X POST $B/api/collections/associations/records \
  -H "Authorization: $SUPERUSER_TOKEN" -H "Content-Type: application/json" \
  -d '{"name":"Förening Björken","permissions":{"posts":{
        "member":["read","create"],
        "styrelse":["read","create","update","delete"],
        "admin":["read","create","update","delete"]}}}'
```

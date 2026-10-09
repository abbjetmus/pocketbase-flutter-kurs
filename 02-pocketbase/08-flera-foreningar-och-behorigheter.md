# 08 – Flera föreningar, roller och behörigheter

Hittills har Föreningsappen haft **en** förening. Men tänk dig att appen blir
populär och att tjugo bostadsrättsföreningar vill använda den. Ska vi starta
tjugo PocketBase-servrar? Nej – det vanliga i riktiga produkter är att **en**
backend betjänar många föreningar, och att varje förening bara ser sin egen
data. Det kallas **multi-tenancy** (en *tenant* = en "hyresgäst", här en
förening).

Det här kapitlet är en **utbyggnad** av kursens datamodell. Grundmodellen i
kursens README gäller fortfarande; vi lägger till en collection
`associations` och ett fält `association` på det mesta. Kapitlet samlar
mönster som används i riktiga, driftsatta föreningsappar:

1. Multi-tenancy med regler som håller isär föreningarna.
2. Fält som **servern** stämplar, så att klienten inte kan fuska.
3. En **behörighetsmatris** per förening som kontrolleras i en hook.
4. **Sidoeffekter** efter sparning: notiser till alla medlemmar.
5. **View-collections** med aggregat för listskärmar.
6. Egna routes och schemalagda påminnelser.
7. Hur man **organiserar** `pb_hooks` när projektet växer.

💡 **Tips:** Kapitlet förutsätter kapitel 1–7. Du kan bygga allt i Dashboard,
men det går fortare att köra migrationen i
[lösningarna](losningar.md#utbyggnad-flera-föreningar) och läsa koden här.

## 1. Datamodellen

```
                        ┌──────────────────┐
                        │   associations   │
                        │──────────────────│
                        │ id               │
                        │ name             │
                        │ permissions(json)│
                        └────────┬─────────┘
                                 │ 1
       ┌──────────────┬──────────┼───────────┬──────────────┐
       │ *            │ *        │ *         │ *            │ *
  apartments       users     resources    bookings        posts ──< post_comments
                   │ role                                   │
                   │ association                            └─(posts_view: aggregat)
                   │
                   └──< notifications  (skrivs bara av servern)
```

| Ändring | Typ | Kommentar |
|---------|-----|-----------|
| Ny collection `associations` | base | `name` (text), `permissions` (json) |
| `users.association` | relation → associations, single | Vilken förening medlemmen tillhör |
| `users.role` | select: `member`, `styrelse`, `admin` | Som tidigare (ibland heter de `member`/`board`/`admin` på engelska) |
| `association` på `apartments`, `resources`, `bookings`, `posts` | relation, single | Vems data är det? |
| Ny collection `post_comments` | base | `post`, `user`, `text` |
| Ny collection `notifications` | base | `user`, `title`, `body`, `link`, `read` |
| Ny view `posts_view` | view | Anslag + antal kommentarer |

### Varför `association` på *varje* collection?

Man skulle kunna nöja sig med `users.association` och resonera "en bokning
tillhör en användare, som tillhör en förening". Regeln blir då
`user.association = @request.auth.association`. Det fungerar, men:

- reglerna blir längre och långsammare (en extra `JOIN` per post),
- vissa poster har ingen naturlig användare (en resurs, en lägenhet),
- en medlem som byter förening skulle "ta med sig" sina gamla bokningar.

Därför lägger man ett **direkt** `association`-fält på allt innehåll och ett
index på det. Det är en avsiktlig, liten denormalisering (jämför
[databasdesign](../01-databaser/04-databasdesign.md)).

⚠️ **Varning:** Unika index måste nu inkludera föreningen. Två föreningar
får båda ha en "Tvättstuga 1" och en lägenhet "1001":

```sql
CREATE UNIQUE INDEX idx_resources_assoc_name ON resources (association, name);
CREATE UNIQUE INDEX idx_apartments_assoc_number ON apartments (association, number);
```

## 2. Regler som håller isär föreningarna

Grundbulten i alla regler är:

```
association = @request.auth.association
```

"Postens förening är samma som den inloggades förening." Kombinera den med det
du redan kan från kapitel 4:

| Mönster | Regel |
|---------|-------|
| Alla inloggade i samma förening | `@request.auth.id != "" && association = @request.auth.association` |
| Bara ägaren | `user = @request.auth.id` |
| Bara admin i samma förening | `@request.auth.role = "admin" && association = @request.auth.association` |
| Bara servern får skriva | `null` |

### Reglerna för hela utbyggnaden

| Collection | List / View | Create | Update | Delete |
|------------|-------------|--------|--------|--------|
| `associations` | `id = @request.auth.association` | `null` | `null` | `null` |
| `users` | `@request.auth.id != "" && association = @request.auth.association` | `null` | `id = @request.auth.id && @request.body.role:isset = false && @request.body.apartment:isset = false && @request.body.association:isset = false` | `null` |
| `apartments`, `resources` | `@request.auth.id != "" && association = @request.auth.association` | `@request.auth.role = "admin"` (+ hook stämplar föreningen) | `@request.auth.role = "admin" && association = @request.auth.association` | samma som update |
| `bookings` | `association = @request.auth.association && (user = @request.auth.id \|\| @request.auth.role = "styrelse" \|\| @request.auth.role = "admin")` | se nedan | `user = @request.auth.id && @request.body.user:changed = false` | `user = @request.auth.id \|\| (@request.auth.role = "admin" && association = @request.auth.association)` |
| `posts` | `@request.auth.id != "" && association = @request.auth.association && (published = true \|\| author = @request.auth.id)` | `@request.auth.id != ""` (+ matrisen i hook) | `association = @request.auth.association && @request.body.author:changed = false` (+ matrisen) | `association = @request.auth.association` (+ matrisen) |
| `post_comments` | `post.association = @request.auth.association` | `@request.body.user = @request.auth.id && @request.body.post.association = @request.auth.association` | `user = @request.auth.id && @request.body.post:changed = false && @request.body.user:changed = false` | `user = @request.auth.id \|\| (@request.auth.role = "admin" && post.association = @request.auth.association)` |
| `notifications` | `user = @request.auth.id` | `null` | `user = @request.auth.id && @request.body.user:isset = false && @request.body.title:isset = false && @request.body.body:isset = false` | `user = @request.auth.id` |
| `posts_view` | `@request.auth.id != "" && association = @request.auth.association` | – | – | – |

Create-regeln för bokningar måste kontrollera att **resursen** hör till rätt
förening – annars kan Anna i förening Eken boka förening Björkens tvättstuga
genom att skicka in dess id:

```
@request.auth.id != "" &&
@request.body.user = @request.auth.id &&
@request.body.resource.association = @request.auth.association &&
@request.body.resource.active = true
```

### `notifications` – en collection som bara servern skriver till

Create-regeln är `null`: ingen klient kan skapa notiser, bara hooks (som inte
går genom reglerna). Medlemmen får läsa och ta bort sina egna notiser, och får
uppdatera dem – men bara fältet `read`, eftersom alla andra fält är spärrade
med `:isset = false`. Det här mönstret ("klienten får bara markera som läst")
återkommer i många appar.

## 3. Server-stämplade fält

Vilken förening en bokning tillhör ska **aldrig** klienten bestämma. Vi låter
servern sätta fältet, oavsett vad som skickas:

`pb_hooks/collections/tenant.pb.js`:

```js
/// <reference path="../../pb_data/types.d.ts" />

// Stämpla föreningen på allt innehåll som skapas via API:t.
// Klienten får aldrig välja förening själv.
onRecordCreateRequest((e) => {
  if (!e.hasSuperuserAuth()) {
    if (!e.auth || !e.auth.getString("association")) {
      throw new ForbiddenError("Du tillhör ingen förening.");
    }
    e.record.set("association", e.auth.getString("association"));
  }
  e.next();
}, "apartments", "resources", "bookings", "posts");

// Vid uppdatering: behåll alltid den sparade föreningen.
onRecordUpdateRequest((e) => {
  if (!e.hasSuperuserAuth()) {
    e.record.set("association", e.record.original().getString("association"));
  }
  e.next();
}, "apartments", "resources", "bookings", "posts");
```

- En hook kan registreras för **flera collections** på en gång.
- `e.record.original()` är posten som den ser ut i databasen *innan*
  ändringen. Bra för att återställa fält eller jämföra före/efter.
- Superusers (Dashboard, skript) får sätta föreningen själva.

Samma teknik använder man för statusfält. Om föreningen kräver att bokningar
av festlokalen godkänns av styrelsen, ska det vara **servern** som sätter
`approval_status = "pending"` – annars skickar klienten bara med
`"approved"` och hoppar över hela godkännandet:

```js
onRecordCreateRequest((e) => {
  if (!e.hasSuperuserAuth()) {
    const resource = e.app.findRecordById("resources", e.record.getString("resource"));
    const needsApproval = resource.getBool("requires_approval");
    e.record.set("approval_status", needsApproval ? "pending" : "approved");
  }
  e.next();
}, "bookings");
```

(Förutsätter att du lagt till `resources.requires_approval` (bool) och
`bookings.approval_status` (select: `pending`, `approved`, `rejected`).)

💡 **Tips:** Skriv en kommentar vid varje stämplat fält som förklarar
*varför*. Om någon senare "förenklar" bort hooken öppnas ett säkerhetshål.

## 4. Behörighetsmatris per förening

Olika föreningar vill ha olika regler. I förening Eken får bara styrelsen
skriva anslag. I förening Björken får alla medlemmar det. Det kan vi inte
hårdkoda i en API-regel – det är **data** som varje förening själv ska kunna
ändra.

Vi sparar en matris i `associations.permissions` (json):

```json
{
  "posts": {
    "member":   ["read"],
    "styrelse": ["read", "create", "update", "delete"],
    "admin":    ["read", "create", "update", "delete"]
  },
  "resources": {
    "member":   ["read"],
    "styrelse": ["read"],
    "admin":    ["read", "create", "update", "delete"]
  }
}
```

Läs den som: *område → roll → tillåtna operationer*. Appen kan använda samma
matris för att visa eller dölja menyval och knappar.

### Varför räcker inte API-regler?

Regeln skulle behöva säga: "slå upp `posts` i föreningens matris, sedan
nyckeln som är *lika med användarens roll*, och kolla om listan innehåller
`create`". Regelspråket kan följa relationer och fasta fältnamn, men inte
använda ett värde (rollen) som *nyckel* i en JSON-struktur. Lösningen är en
hook med en delad hjälpfunktion.

`pb_hooks/utils/permissions.js`:

```js
// Standard om föreningen inte har någon egen matris.
const DEFAULT_PERMISSIONS = {
  posts: {
    member: ["read"],
    styrelse: ["read", "create", "update", "delete"],
    admin: ["read", "create", "update", "delete"],
  },
};

function loadMatrix(app, associationId) {
  try {
    const association = app.findRecordById("associations", associationId);
    // getString ger JSON-texten; JSON.parse gör om den till ett JS-objekt
    const raw = association.getString("permissions");
    const parsed = raw ? JSON.parse(raw) : null;
    return parsed || DEFAULT_PERMISSIONS;
  } catch (err) {
    return DEFAULT_PERMISSIONS;
  }
}

function can(app, user, area, operation) {
  const matrix = loadMatrix(app, user.getString("association"));
  const byRole = matrix[area] || {};
  const allowed = byRole[user.getString("role")] || [];
  return allowed.indexOf(operation) !== -1;
}

// Kastar ForbiddenError om den inloggade inte får utföra operationen.
function enforce(e, area, operation) {
  if (e.hasSuperuserAuth()) return;
  if (!e.auth) {
    throw new UnauthorizedError("Du måste vara inloggad.");
  }
  if (!can(e.app, e.auth, area, operation)) {
    throw new ForbiddenError("Din roll saknar behörighet för detta.");
  }
}

module.exports = { enforce, can, DEFAULT_PERMISSIONS };
```

⚠️ **Varning:** Läs json-fält med `getString(...)` + `JSON.parse(...)`.
`record.get("permissions")` kan i JS-hooks ge tillbaka råa byte (en lista med
tal som `[123, 34, ...]`) i stället för ett objekt, och då blir alla
kontroller fel utan att något felmeddelande syns.

Användning i `pb_hooks/collections/posts.pb.js`:

```js
/// <reference path="../../pb_data/types.d.ts" />

onRecordCreateRequest((e) => {
  require(`${__hooks}/utils/permissions.js`).enforce(e, "posts", "create");
  if (!e.hasSuperuserAuth()) {
    e.record.set("author", e.auth.id); // stämpla författaren
  }
  e.next();
}, "posts");

onRecordUpdateRequest((e) => {
  require(`${__hooks}/utils/permissions.js`).enforce(e, "posts", "update");
  e.next();
}, "posts");

onRecordDeleteRequest((e) => {
  require(`${__hooks}/utils/permissions.js`).enforce(e, "posts", "delete");
  e.next();
}, "posts");
```

Resultat:

| Användare | Förening | Roll | Matris säger | Skapa anslag |
|-----------|----------|------|--------------|--------------|
| Anna | Eken | member | standard: `["read"]` | `403 Din roll saknar behörighet för detta.` |
| Bo | Eken | styrelse | `["read","create",...]` | ✅ |
| Cecilia | Björken | member | Björkens matris: `["read","create"]` | ✅ |

API-reglerna och matrisen samarbetar: **regeln** håller isär föreningarna
(`association = @request.auth.association`), **matrisen** avgör vad rollen får
göra inom föreningen. Båda måste säga ja.

💡 **Tips:** Hooks av typen `on...Request` körs bara för API-anrop. Kod på
servern (andra hooks, cron, migrationer) påverkas inte av matrisen – vilket är
precis vad man vill när servern själv skapar t.ex. notiser.

## 5. Sidoeffekter efter sparning – notiser

När styrelsen publicerar ett anslag ska alla andra i föreningen få en notis i
appen. Det är en **sidoeffekt**: anslaget är huvudsaken, notisen en bonus. Den
ska göras *efter* att anslaget sparats, och ett fel i notiskoden får inte göra
att anslaget försvinner.

```js
// I pb_hooks/collections/posts.pb.js

onRecordAfterCreateSuccess((e) => {
  if (e.record.getBool("published")) {
    require(`${__hooks}/utils/notifications.js`).notifyAssociation(e.app, e.record);
  }
  e.next();
}, "posts");

// Även när ett utkast publiceras i efterhand
onRecordAfterUpdateSuccess((e) => {
  const wasPublished = e.record.original().getBool("published");
  if (!wasPublished && e.record.getBool("published")) {
    require(`${__hooks}/utils/notifications.js`).notifyAssociation(e.app, e.record);
  }
  e.next();
}, "posts");
```

`pb_hooks/utils/notifications.js`:

```js
// Skapar en notis per medlem i föreningen (utom författaren).
function notifyAssociation(app, post) {
  try {
    const members = app.findRecordsByFilter(
      "users",
      "association = {:a} && id != {:author}",
      "", 0, 0,
      { a: post.getString("association"), author: post.getString("author") },
    );
    const collection = app.findCollectionByNameOrId("notifications");

    app.runInTransaction((txApp) => {
      for (const m of members) {
        const n = new Record(collection);
        n.set("user", m.id);
        n.set("title", "Nytt anslag: " + post.getString("title"));
        n.set("link", "/posts/" + post.id);
        txApp.save(n);
      }
    });
  } catch (err) {
    // Notiser är en bonus – ett fel här ska inte påverka anslaget.
    console.log("Kunde inte skapa notiser:", err);
  }
}

module.exports = { notifyAssociation };
```

- `try/catch` runt allt, och `e.next()` anropas alltid.
- `findRecordsByFilter` med `limit` 0 hämtar alla medlemmar. För en förening
  med några hundra medlemmar går det bra; för tusentals bör man dela upp
  arbetet eller köa det.
- Flutter-appen prenumererar på `notifications` med
  `subscribe('*', ...)` (kapitel 6) och visar en röd prick direkt. Realtid
  följer list-regeln `user = @request.auth.id`, så var och en får bara sina
  egna.

💡 **Tips:** Riktiga push-notiser (som syns när appen är stängd) skickas
oftast till en extern tjänst, t.ex. Firebase Cloud Messaging, med
`$http.send(...)` från samma typ av hook. Skicka då med en hemlig header och
läs hemligheten från en miljövariabel (`$os.getenv("PUSH_SECRET")`) – lägg
den aldrig i koden.

## 6. View-collection för listskärmen

Anslagslistan i appen ska visa "💬 3" bredvid varje anslag. Att hämta alla
kommentarer för att räkna dem är slöseri. En view-collection gör det i SQL:

```sql
SELECT p.id, p.title, p.author, p.association, p.created,
       COUNT(c.id) AS comments_count
FROM posts p
LEFT JOIN post_comments c ON c.post = p.id
WHERE p.published = TRUE
GROUP BY p.id
```

**I Dashboard:** + New collection → typ **View** → namn `posts_view` → klistra
in frågan → fliken API Rules: List och View
`@request.auth.id != "" && association = @request.auth.association` → Create.

```
GET /api/collections/posts_view/records?sort=-created&expand=author
```

```json
{ "items": [ { "id": "jkooif1cco6ckxf", "title": "Städdag", "comments_count": 1,
               "expand": { "author": { "name": "Bo" } } } ] }
```

Observera:

- Kolumnerna `author` och `association` behåller sin typ (relation), så
  `expand=author` och regeln på `association` fungerar.
- `id` är anslagets id – appen kan öppna `posts/{id}` när man klickar.
- `LEFT JOIN` gör att anslag utan kommentarer får `0` i stället för att
  försvinna (jämför `JOIN`-typerna i modul 01).

⚠️ **Varning:** View-frågan körs **utan** API-reglerna för `posts` och
`post_comments`. Viewn får sina egna regler, och det är de som gäller. Glöm
du `WHERE p.published = TRUE` och regeln på `association` läcker du utkast och
andra föreningars anslag. View-collections skickar inte heller några
realtidshändelser – lyssna på `posts` och hämta om viewn vid behov.

## 7. Egna routes och påminnelser

Kvällen före en bokning ska medlemmen få en påminnelse. Logiken läggs i en
modul så att den kan anropas både från cron och från en testroute:

`pb_hooks/utils/reminders.js`:

```js
function remindTomorrow(app) {
  const now = new DateTime();
  const from = now.addDate(0, 0, 1);
  const to = now.addDate(0, 0, 2);

  const bookings = app.findRecordsByFilter(
    "bookings",
    "start >= {:from} && start < {:to}",
    "start", 0, 0,
    { from: from, to: to },
  );

  const collection = app.findCollectionByNameOrId("notifications");
  for (const b of bookings) {
    app.expandRecord(b, ["resource"], null);
    const n = new Record(collection);
    n.set("user", b.getString("user"));
    n.set("title", "Påminnelse: " + b.expandedOne("resource").getString("name"));
    n.set("body", "Din bokning börjar " + b.getString("start"));
    app.save(n);
  }
  return bookings.length;
}

module.exports = { remindTomorrow };
```

`pb_hooks/cron/reminders.pb.js`:

```js
/// <reference path="../../pb_data/types.d.ts" />

// Varje dag kl. 16:00 UTC (18:00 svensk sommartid)
cronAdd("paminn_bokningar", "0 16 * * *", () => {
  require(`${__hooks}/utils/reminders.js`).remindTomorrow($app);
});

// För att kunna testa utan att vänta till kl. 16 – bara för superusers
routerAdd("POST", "/api/foreningen/test-reminders", (e) => {
  const n = require(`${__hooks}/utils/reminders.js`).remindTomorrow(e.app);
  return e.json(200, { sent: n });
}, $apis.requireSuperuserAuth());
```

- `app.expandRecord(record, ["resource"], null)` fyller i `expand` på servern,
  och `expandedOne("resource")` hämtar den expanderade posten.
- Cron-jobbet går inte genom API-reglerna och ser alla föreningars
  bokningar – det är meningen här, eftersom notisen ändå skickas till
  bokningens egen användare.

## Organisera pb_hooks

Bara `.pb.js`-filer **direkt** i `pb_hooks/` laddas automatiskt. I ett större
projekt samlar man därför registreringen i en `main.pb.js` och delar upp
resten i mappar:

```
pb_hooks/
├── main.pb.js                 ← den enda fil som laddas automatiskt
├── collections/               ← en fil per collection
│   ├── tenant.pb.js
│   ├── bookings.pb.js
│   └── posts.pb.js
├── api/                       ← egna routes (routerAdd)
│   └── stats.pb.js
├── cron/                      ← schemalagda jobb (cronAdd)
│   └── reminders.pb.js
└── utils/                     ← hjälpfunktioner (module.exports), inga hooks
    ├── booking_utils.js
    ├── permissions.js
    ├── notifications.js
    └── reminders.js
```

`pb_hooks/main.pb.js`:

```js
/// <reference path="../pb_data/types.d.ts" />

// Bara filer direkt i pb_hooks/ laddas automatiskt.
// Filerna i undermapparna registreras härifrån.
require(`${__hooks}/collections/tenant.pb.js`);
require(`${__hooks}/collections/bookings.pb.js`);
require(`${__hooks}/collections/posts.pb.js`);
require(`${__hooks}/cron/reminders.pb.js`);
```

Regler för uppdelningen:

| Mapp | Innehåller | Får registrera hooks? |
|------|------------|------------------------|
| `collections/` | `onRecord...`-hooks för en collection | Ja |
| `api/` | `routerAdd` | Ja |
| `cron/` | `cronAdd` | Ja |
| `utils/` | Ren logik som exporteras med `module.exports` | **Nej** – anropas med `require` *inuti* hooks |

⚠️ **Varning:** Kom ihåg isoleringen från kapitel 7: en hook ser inte
variabler från filen den står i. Därför står `require(...)` **inne i** varje
hook, inte överst i filen.

## Testa att föreningarna verkligen hålls isär

En checklista du bör köra med curl (eller automatiserat) varje gång du ändrar
regler:

| Test | Förväntat |
|------|-----------|
| Anna (Eken) listar `resources` | Bara Ekens resurser |
| Anna bokar Björkens tvättstuga (Björkens resurs-id) | `400` |
| Anna skickar `"association": "<Björkens id>"` när hon bokar | Bokningen får ändå Ekens id |
| Anna (member) skapar ett anslag i Eken | `403` från matrisen |
| Cecilia (member) skapar ett anslag i Björken | OK – Björkens matris tillåter |
| Cecilia kommenterar ett anslag i Eken | `400` |
| Anna ändrar `title` på sin notis | `404` (bara `read` får ändras) |
| Anna skapar en notis | `403` (create = `null`) |
| Anna listar `users` | Bara medlemmar i Eken |

## Sammanfattning

- **Multi-tenancy:** `associations` + `association` på allt innehåll +
  `association = @request.auth.association` i reglerna. Unika index inkluderar
  föreningen.
- **Server-stämplade fält** (`association`, `author`, `approval_status`) sätts i
  `onRecordCreateRequest` – klienten kan inte välja dem.
- **Behörighetsmatris** i ett json-fält, kontrollerad av en delad
  `enforce(e, område, operation)` som kastar `ForbiddenError`.
- **Sidoeffekter** i `onRecordAfterCreateSuccess` med `try/catch` och
  `e.next()`.
- **`null`-regler** för collections som bara servern skriver till.
- **View-collections** med `COUNT` för listskärmar – med egna, noggranna regler.
- **Organisera** hooks i `main.pb.js` + `collections/`, `api/`, `cron/`,
  `utils/`.

Nu är du redo för [övningarna](ovningar.md).

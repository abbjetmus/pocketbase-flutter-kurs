# 08 – Grupper, roller och behörigheter

Hittills är allt i Kvittra publikt för alla inloggade. Men tänk dig att appen
växer och att användarna vill ha **grupper**, som i Facebook: en öppen grupp
för surdegsbagare där vem som helst får gå med, och en privat grupp för en
löparklubb där bara medlemmarna ser inläggen. I grupperna finns dessutom
**roller**: en admin som hanterar medlemmar och moderatorer som får ta bort
olämpliga kommentarer.

Det här kapitlet är en **utbyggnad** av kursens datamodell. Grundmodellen i
kursens README (`users`, `posts`, `comments`, `likes`, `follows`) gäller
fortfarande; vi lägger till nya collections och ett valfritt fält på `posts`.
Kapitlet samlar mönster som används i riktiga, driftsatta appar:

1. Regler som styr **synlighet** via back-relationer (och `@collection`).
2. Fält som **servern** stämplar, så att klienten inte kan fuska.
3. **Roller** per grupp som kontrolleras i en hook med en delad hjälpfunktion.
4. **Sidoeffekter** efter sparning: notiser när någon gillar eller kommenterar.
5. **View-collections** med räknare för flödet.
6. Schemalagda jobb: en veckosammanfattning.
7. Hur man **organiserar** `pb_hooks` när projektet växer.

💡 **Tips:** Kapitlet förutsätter kapitel 1–7. Du kan bygga allt i Dashboard,
men det går fortare att köra migrationen i
[lösningarna](losningar.md#utbyggnad-grupper) och läsa koden här.

## 1. Datamodellen

```
                    ┌──────────────────┐
                    │      groups      │
                    │──────────────────│
                    │ name             │
                    │ description      │
                    │ owner → users    │
                    │ visibility       │  public | private
                    └────────┬─────────┘
                             │ 1
              ┌──────────────┴───────────────┐
              │ *                            │ *  (valfritt)
     ┌────────┴─────────┐           ┌────────┴─────────┐
     │  group_members   │           │      posts       │ ──< comments, likes
     │──────────────────│           │──────────────────│
     │ group → groups   │           │ group → groups   │  "" = vanligt inlägg
     │ user  → users    │           │ ...              │
     │ role             │           └──────────────────┘
     └──────────────────┘             (posts_view: likes_count, comments_count)
       admin | moderator | member

     notifications (user, actor, type, post, text, read) – skrivs bara av servern
```

| Ändring | Typ | Kommentar |
|---------|-----|-----------|
| Ny collection `groups` | base | `name`, `description`, `owner` (relation → users), `visibility` (select: `public`, `private`) |
| Ny collection `group_members` | base | `group` (→ groups, cascade), `user` (→ users, cascade), `role` (select: `admin`, `moderator`, `member`). Unikt index på `(group, user)` |
| `posts.group` | relation → groups, single, **valfri**, cascade | Tomt = vanligt inlägg i flödet. Satt = inlägg i en grupp |
| Ny collection `notifications` | base | `user` (mottagare), `actor` (vem gjorde något), `type` (`like`, `comment`, `digest`), `post`, `text`, `read` |
| Ny view `posts_view` | view | Inlägg + `likes_count` och `comments_count` |

### Varför rollen i `group_members` och inte på `users`?

En roll gäller **i en viss grupp**. Bo kan vara admin i Löparklubben och vanlig
medlem i Surdegsbagare. Därför hör rollen hemma på *kopplingen* mellan användare
och grupp – precis som när en kopplingstabell i modul 01 fick egna kolumner.
Det är dessutom säkrare: ett fält `users.role` skulle användaren själv kunna
försöka ändra (kapitel 4, misstag 10).

⚠️ **Varning:** `group` är ett reserverat ord i SQL (`GROUP BY`). I
PocketBase-regler och filter går det bra att skriva `group`, men i rå SQL – i
en view eller ett index – måste du citera det: `p."group"` eller
`` `group` ``.

## 2. Synlighet med back-relationer

Grundbulten i utbyggnaden är regeln "får jag se det här inlägget?":

```
group = "" ||
group.visibility = "public" ||
group.group_members_via_group.user ?= @request.auth.id
```

Läs den rad för rad:

1. `group = ""` – inlägget hör inte till någon grupp: synligt för alla
   inloggade, som förut.
2. `group.visibility = "public"` – inlägget ligger i en öppen grupp.
3. `group.group_members_via_group.user ?= @request.auth.id` – följ `group` till
   gruppen, sedan back-relationen till alla medlemsrader i gruppen, och kolla
   att **minst en** av dem är jag.

Det är exakt samma teknik som flödet i kapitel 3, bara i en regel i stället för
ett filter.

### Samma sak med `@collection`

Utan relationsväg skulle man skriva regeln med `@collection` (kapitel 4):

```
group = "" ||
group.visibility = "public" ||
(@collection.group_members.group ?= group && @collection.group_members.user ?= @request.auth.id)
```

Båda formerna är testade och ger samma resultat. Villkoren på
`@collection.group_members` gäller **samma rad** (gruppen är inläggets grupp
*och* användaren är jag). Back-relationen är kortare och svårare att göra fel
på, så den använder vi.

⚠️ **Varning – två tysta fel som är lätta att göra:**

| Fel regel | Vad händer (testat) |
|-----------|---------------------|
| `group = "" \|\| @collection.group_members.user ?= @request.auth.id` | Kopplingen till inläggets grupp saknas: "jag är medlem i *någon* grupp". Cecilia, som bara är med i Surdegsbagare, ser Löparklubbens privata inlägg. **Läcka!** |
| `group = "" \|\| group.group_members_via_group.user = @request.auth.id` | `=` i stället för `?=` betyder "**alla** medlemmar är jag". Ingen ser gruppinläggen – inte ens medlemmarna. |

Testa alltid en regel med (1) en medlem, (2) en icke-medlem som är med i en
*annan* grupp, och (3) en användare utan grupper.

### Reglerna för hela utbyggnaden

För att tabellen ska bli läsbar använder vi två förkortningar:

- `MEDLEM` = `group_members_via_group.user ?= @request.auth.id`
- `SER_INLÄGGET` = `group = "" || group.visibility = "public" || group.MEDLEM`

| Collection | List / View | Create | Update | Delete |
|------------|-------------|--------|--------|--------|
| `groups` | `@request.auth.id != "" && (visibility = "public" \|\| MEDLEM)` | `@request.auth.id != ""` (+ hook stämplar `owner`) | `MEDLEM && @request.body.owner:isset = false` (+ hook: `edit_group`) | `owner = @request.auth.id` |
| `group_members` | `@request.auth.id != "" && (group.visibility = "public" \|\| group.MEDLEM)` | `@request.auth.id != ""` (+ hook, se avsnitt 4) | `@request.auth.id != "" && @request.body.group:isset = false && @request.body.user:isset = false` (+ hook: `manage_members`) | `user = @request.auth.id \|\| group.MEDLEM` (+ hook) |
| `posts` | `@request.auth.id != "" && (SER_INLÄGGET)` | `@request.auth.id != "" && @request.body.author = @request.auth.id && (@request.body.group = "" \|\| @request.body.group.MEDLEM)` | `author = @request.auth.id && @request.body.author:changed = false && @request.body.group:changed = false` | `author = @request.auth.id \|\| group.MEDLEM` (+ hook: `delete_post`) |
| `comments` | `@request.auth.id != "" && (SER_INLÄGGET med prefixet post.)` | som förut + `@request.body.post` måste vara synligt | som förut | `author = @request.auth.id \|\| post.author = @request.auth.id \|\| post.group.MEDLEM` (+ hook: `delete_comment`) |
| `likes` | som `comments` | som förut + `@request.body.post` måste vara synligt | `null` | som förut |
| `notifications` | `user = @request.auth.id` | `null` | `user = @request.auth.id` + `:isset = false` på alla fält utom `read` | `user = @request.auth.id` |
| `posts_view` | `@request.auth.id != "" && (SER_INLÄGGET)` | – | – | – |

"Som förut" betyder reglerna från kapitel 4. "Med prefixet `post.`" betyder
att varje fält får `post.` framför sig, t.ex.

```
@request.auth.id != "" && (
  post.group = "" ||
  post.group.visibility = "public" ||
  post.group.group_members_via_group.user ?= @request.auth.id
)
```

och "måste vara synligt" att samma villkor skrivs med `@request.body.post.`
framför. Den fullständiga texten för varje regel finns i migrationen i
lösningarna.

Varför måste `comments` och `likes` ha egna synlighetsregler? Annars kan
Cecilia lista `comments` och läsa allt som skrivs i Löparklubbens privata
inlägg – eller gilla ett privat inlägg genom att skicka in dess id. Varje
collection skyddar sig själv; att `posts` är skyddad hjälper inte.

### `notifications` – en collection som bara servern skriver till

Create-regeln är `null`: ingen klient kan skapa notiser, bara hooks (som inte
går genom reglerna). Användaren får läsa och ta bort sina egna notiser, och får
uppdatera dem – men bara fältet `read`, eftersom alla andra fält är spärrade
med `:isset = false`. Det här mönstret ("klienten får bara markera som läst")
återkommer i många appar.

## 3. Server-stämplade fält

Vissa fält får **aldrig** klienten bestämma:

| Fält | Stämplas till | Varför |
|------|---------------|--------|
| `posts.author`, `comments.author` | den inloggade | Ingen ska kunna skriva i någon annans namn (kapitel 7) |
| `groups.owner` | den inloggade | Annars kan man skapa en grupp "ägd" av någon annan |
| `group_members.role` | `"member"` | Annars går man med i en grupp som `admin` |

`pb_hooks/collections/groups.pb.js`:

```js
/// <reference path="../../pb_data/types.d.ts" />

// Den som skapar gruppen blir ägare – klienten kan inte välja.
onRecordCreateRequest((e) => {
  if (!e.hasSuperuserAuth()) {
    e.record.set("owner", e.auth.id);
  }
  e.next();
}, "groups");

// ...och första admin. Görs av servern med e.app.save(), så
// group_members-hookarna för API-anrop (som alltid sätter "member") körs inte.
onRecordAfterCreateSuccess((e) => {
  const m = new Record(e.app.findCollectionByNameOrId("group_members"));
  m.set("group", e.record.id);
  m.set("user", e.record.getString("owner"));
  m.set("role", "admin");
  e.app.save(m);
  e.next();
}, "groups");

onRecordUpdateRequest((e) => {
  require(`${__hooks}/utils/group_permissions.js`).enforce(e, e.record.id, "edit_group");
  e.next();
}, "groups");
```

- `e.auth` finns alltid här, eftersom create-regeln `@request.auth.id != ""`
  redan har stoppat utloggade innan hooken körs (kapitel 7).
- Skickar Bo `"owner": "<Cecilias id>"` blir Bo ändå ägare.
- `onRecord...Request`-hooks körs bara för API-anrop. När servern själv sparar
  med `e.app.save(m)` hoppas de över – därför kan servern skapa en admin fast
  API-hooken för `group_members` alltid sätter `member`.

`pb_hooks/collections/group_members.pb.js` (create-delen):

```js
/// <reference path="../../pb_data/types.d.ts" />

onRecordCreateRequest((e) => {
  if (!e.hasSuperuserAuth()) {
    // Rollen bestäms aldrig av klienten. Nya medlemmar är alltid "member".
    e.record.set("role", "member");

    const groupId = e.record.getString("group");
    if (e.record.getString("user") === e.auth.id) {
      // Gå med själv: bara i publika grupper
      const group = e.app.findRecordById("groups", groupId);
      if (group.getString("visibility") !== "public") {
        throw new ForbiddenError("Gruppen är privat. Be en admin lägga till dig.");
      }
    } else {
      // Lägga till någon annan: kräver manage_members (admin)
      require(`${__hooks}/utils/group_permissions.js`).enforce(e, groupId, "manage_members");
    }
  }
  e.next();
}, "group_members");
```

💡 **Tips:** Skriv en kommentar vid varje stämplat fält som förklarar
*varför*. Om någon senare "förenklar" bort hooken öppnas ett säkerhetshål.

## 4. Roller i en hook – `enforce`

Vad får varje roll göra?

| Operation | admin | moderator | member |
|-----------|:-----:|:---------:|:------:|
| `delete_post` – ta bort andras inlägg i gruppen | ✅ | ✅ | – |
| `delete_comment` – ta bort andras kommentarer i gruppen | ✅ | ✅ | – |
| `manage_members` – lägga till, ta bort, ändra roll | ✅ | – | – |
| `edit_group` – ändra namn och beskrivning | ✅ | – | – |

Sitt eget kan man alltid ta bort, och inläggets författare får ta bort
kommentarer under sitt inlägg (som i kapitel 4).

### Varför inte bara API-regler?

Det *går* att uttrycka "jag är admin i inläggets grupp" som en regel – flera
villkor på samma back-relation gäller samma rad:

```
group.group_members_via_group.user ?= @request.auth.id &&
group.group_members_via_group.role ?= "admin"
```

Men reglerna blir snabbt oläsliga när de ska säga "författaren, *eller*
inläggets författare, *eller* moderator/admin i inläggets grupp" på fyra
collections. Och samma tabell behövs i appen för att visa rätt knappar. Därför:

- **API-regeln** gör det grova: du måste åtminstone vara medlem i gruppen
  (`group.MEDLEM` i delete-regeln) – annars `404`, och ingen läcka.
- **Hooken** avgör det fina: vad din *roll* får göra – annars `403` med ett
  begripligt meddelande.

Båda måste säga ja. Tabellen ovan finns på **ett** ställe, i en hjälpmodul.

`pb_hooks/utils/group_permissions.js`:

```js
// Vad varje roll i en grupp får göra.
const ROLE_PERMISSIONS = {
  admin: ["delete_post", "delete_comment", "manage_members", "edit_group"],
  moderator: ["delete_post", "delete_comment"],
  member: [],
};

// Användarens roll i gruppen, eller "" om hen inte är medlem.
function roleInGroup(app, groupId, userId) {
  if (!groupId || !userId) return "";
  const rows = app.findRecordsByFilter(
    "group_members",
    "group = {:group} && user = {:user}",
    "", 1, 0,
    { group: groupId, user: userId },
  );
  return rows.length > 0 ? rows[0].getString("role") : "";
}

function can(app, groupId, userId, operation) {
  const allowed = ROLE_PERMISSIONS[roleInGroup(app, groupId, userId)] || [];
  return allowed.indexOf(operation) !== -1;
}

// Kastar ett fel om den inloggade inte får utföra operationen i gruppen.
function enforce(e, groupId, operation) {
  if (e.hasSuperuserAuth()) return;
  if (!e.auth) {
    throw new UnauthorizedError("Du måste vara inloggad.");
  }
  if (!can(e.app, groupId, e.auth.id, operation)) {
    throw new ForbiddenError("Din roll i gruppen saknar behörighet för detta.");
  }
}

module.exports = { ROLE_PERMISSIONS, roleInGroup, can, enforce };
```

Användning – `pb_hooks/collections/comments.pb.js`:

```js
/// <reference path="../../pb_data/types.d.ts" />

// Kommentarens författare och inläggets författare får alltid ta bort.
// Alla andra behöver delete_comment i inläggets grupp (moderator, admin).
onRecordDeleteRequest((e) => {
  const post = e.app.findRecordById("posts", e.record.getString("post"));
  const me = e.auth ? e.auth.id : "";
  if (e.record.getString("author") !== me && post.getString("author") !== me) {
    require(`${__hooks}/utils/group_permissions.js`)
      .enforce(e, post.getString("group"), "delete_comment");
  }
  e.next();
}, "comments");
```

`pb_hooks/collections/posts.pb.js` (delete-delen):

```js
// Författaren får alltid ta bort. Andra behöver delete_post i gruppen.
onRecordDeleteRequest((e) => {
  if (!e.auth || e.record.getString("author") !== e.auth.id) {
    require(`${__hooks}/utils/group_permissions.js`)
      .enforce(e, e.record.getString("group"), "delete_post");
  }
  e.next();
}, "posts");
```

`pb_hooks/collections/group_members.pb.js` (update och delete):

```js
// Ändra roll: bara admin
onRecordUpdateRequest((e) => {
  require(`${__hooks}/utils/group_permissions.js`)
    .enforce(e, e.record.getString("group"), "manage_members");
  e.next();
}, "group_members");

// Lämna gruppen själv går alltid. Ta bort någon annan: bara admin.
onRecordDeleteRequest((e) => {
  if (!e.auth || e.record.getString("user") !== e.auth.id) {
    require(`${__hooks}/utils/group_permissions.js`)
      .enforce(e, e.record.getString("group"), "manage_members");
  }
  e.next();
}, "group_members");
```

Resultat med testdatan (Bo äger den privata Löparklubben, Anna och David är
medlemmar, Cecilia äger den publika Surdegsbagare):

| Vem | Försöker | Svar |
|-----|----------|------|
| Anna (member) | Ta bort Davids kommentar i Löparklubben | `403 Din roll i gruppen saknar behörighet för detta.` |
| Anna (member) | Ändra sin egen roll till `admin` | `403` |
| Bo (admin) | Göra Anna till `moderator` | ✅ |
| Anna (moderator) | Ta bort Davids kommentar | ✅ `204` |
| Anna (moderator) | Lägga till Cecilia i gruppen | `403` (bara admin) |
| Cecilia (inte medlem) | Ta bort Anna ur Löparklubben | `404` (regeln: hon ser inte ens raden) |
| David | Lämna Löparklubben | ✅ `204` |

💡 **Tips:** Hooks av typen `on...Request` körs bara för API-anrop. Kod på
servern (andra hooks, cron, migrationer) påverkas inte av `enforce` – vilket är
precis vad man vill när servern själv t.ex. skapar gruppens första admin.

⚠️ **Varning:** Vill du låta varje grupp ha **egna** rättigheter (t.ex. att
moderatorer i Surdegsbagare också får ändra gruppens namn) kan du spara
tabellen i ett json-fält, `groups.permissions`. Läs det då med
`getString(...)` + `JSON.parse(...)`. `record.get("permissions")` kan i
JS-hooks ge tillbaka råa byte (en lista med tal som `[123, 34, ...]`) i stället
för ett objekt, och då blir alla kontroller fel utan att något felmeddelande
syns. (Det är övning 10.4.)

## 5. Sidoeffekter efter sparning – notiser

När någon gillar eller kommenterar ditt inlägg ska du få en notis i appen. Det
är en **sidoeffekt**: gillningen är huvudsaken, notisen en bonus. Den ska göras
*efter* att gillningen sparats, och ett fel i notiskoden får inte göra att
gillningen försvinner.

`pb_hooks/utils/notifications.js`:

```js
// Skapar en notis till userId. Fel loggas men kastas inte vidare –
// notisen är en bonus och får aldrig stoppa gillningen/kommentaren.
function notify(app, userId, actorId, type, postId, text) {
  if (!userId || userId === actorId) return; // inga notiser om sig själv
  try {
    const n = new Record(app.findCollectionByNameOrId("notifications"));
    n.set("user", userId);
    n.set("actor", actorId);
    n.set("type", type);
    n.set("post", postId);
    n.set("text", text);
    app.save(n);
  } catch (err) {
    console.log("Kunde inte skapa notis:", err);
  }
}

module.exports = { notify };
```

I `pb_hooks/collections/likes.pb.js`:

```js
onRecordAfterCreateSuccess((e) => {
  const post = e.app.findRecordById("posts", e.record.getString("post"));
  require(`${__hooks}/utils/notifications.js`).notify(
    e.app,
    post.getString("author"),     // mottagare: inläggets författare
    e.record.getString("user"),   // vem som gillade
    "like",
    post.id,
    "gillade ditt inlägg: " + post.getString("title"),
  );
  e.next();
}, "likes");
```

Och likadant i `comments.pb.js`, med `e.record.getString("author")` som actor,
typen `"comment"` och texten `"kommenterade ditt inlägg: ..."`.

- `try/catch` runt allt, och `e.next()` anropas alltid.
- Kommenterar Bo sitt eget inlägg skapas ingen notis (`userId === actorId`).
- `onRecordAfterCreateSuccess` är en model hook: den körs för **alla**
  sparningar, även när en migration lägger in testdata. Ligger hooken på plats
  när du kör testdata-migrationen får du alltså notiser för testdatan också.
- Flutter-appen prenumererar på `notifications` med
  `subscribe('*', ...)` (kapitel 6) och visar en röd prick direkt. Realtid
  följer list-regeln `user = @request.auth.id`, så var och en får bara sina
  egna. Hämta med `expand=actor` för att kunna skriva "**bo** gillade ditt
  inlägg".

💡 **Tips:** Riktiga push-notiser (som syns när appen är stängd) skickas
oftast till en extern tjänst, t.ex. Firebase Cloud Messaging, med
`$http.send(...)` från samma typ av hook. Skicka då med en hemlig header och
läs hemligheten från en miljövariabel (`$os.getenv("PUSH_SECRET")`) – lägg
den aldrig i koden.

## 6. View-collection för flödet

Flödet ska visa "♥ 3 · 💬 2" under varje inlägg. Att hämta alla gillningar och
kommentarer för att räkna dem är slöseri. En view-collection gör det i SQL.

Första försöket, med två `LEFT JOIN`:

```sql
SELECT p.id, p.title, COUNT(l.id) AS likes_count, COUNT(c.id) AS comments_count
FROM posts p
LEFT JOIN likes l    ON l.post = p.id
LEFT JOIN comments c ON c.post = p.id
GROUP BY p.id
```

Testat: "Bästa kaffet i stan?" har 3 gillningar och 2 kommentarer, men frågan
ger **6 och 6**. Två `JOIN` mot två olika "många"-tabeller multiplicerar
raderna (3 × 2 = 6) innan `COUNT` räknar – samma fälla som i modul 01. Räkna i
stället med en **delfråga per tabell**:

```sql
SELECT p.id, p.author, p."group", p.title, p.created,
       CAST((SELECT COUNT(*) FROM likes l    WHERE l.post = p.id) AS INTEGER) AS likes_count,
       CAST((SELECT COUNT(*) FROM comments c WHERE c.post = p.id) AS INTEGER) AS comments_count
FROM posts p
```

**I Dashboard:** + New collection → typ **View** → namn `posts_view` → klistra
in frågan → fliken API Rules: List och View
`@request.auth.id != "" && (group = "" || group.visibility = "public" || group.group_members_via_group.user ?= @request.auth.id)`
→ Create.

```
GET /api/collections/posts_view/records?sort=-likes_count&expand=author
```

```json
{ "items": [ { "id": "jecocasqaz8ls35", "title": "Bästa kaffet i stan?",
               "likes_count": 3, "comments_count": 2,
               "expand": { "author": { "username": "bo", "name": "Bo Berg" } } }, ... ] }
```

Observera:

- `p."group"` måste citeras eftersom `group` är ett SQL-ord.
- Kolumnerna `author` och `group` behåller sin typ (relation), så
  `expand=author` och regeln på `group...` fungerar.
- `CAST(... AS INTEGER)` gör att PocketBase gissar typen `number`. Utan den
  blir delfrågans kolumn ett json-fält – värdet är ändå ett tal, men
  `number` är tydligare för appen.
- `id` är inläggets id – appen kan öppna `posts/{id}` när man klickar.
- Nu kan man filtrera och sortera på antal: `filter=likes_count >= 2`,
  `sort=-likes_count`. Det gick inte direkt på `posts` (kapitel 5).

⚠️ **Varning:** View-frågan körs **utan** API-reglerna för `posts`, `likes`
och `comments`. Viewn får sina egna regler, och det är de som gäller. Glömmer
du synlighetsregeln läcker du titlarna på de privata gruppernas inlägg. View-
collections skickar inte heller några realtidshändelser – lyssna på `posts`,
`likes` och `comments` och hämta om viewn vid behov.

## 7. Schemalagt jobb: veckosammanfattning

Varje måndag morgon får alla vars inlägg fått gillningar en notis: "Dina inlägg
gillades 4 gånger den senaste veckan." Logiken läggs i en modul så att den kan
anropas både från cron och från en testroute:

`pb_hooks/utils/digest.js`:

```js
// Skapar en "veckosammanfattning"-notis till varje användare vars
// inlägg fick minst en gillning de senaste 7 dagarna.
function weeklyDigest(app) {
  const since = new DateTime().addDate(0, 0, -7);
  const likes = app.findRecordsByFilter(
    "likes", "created >= {:since}", "", 0, 0, { since: since },
  );

  // Räkna gillningar per författare
  const perAuthor = {};
  for (const like of likes) {
    app.expandRecord(like, ["post"], null);
    const authorId = like.expandedOne("post").getString("author");
    perAuthor[authorId] = (perAuthor[authorId] || 0) + 1;
  }

  const collection = app.findCollectionByNameOrId("notifications");
  let sent = 0;
  for (const authorId in perAuthor) {
    const n = new Record(collection);
    n.set("user", authorId);
    n.set("type", "digest");
    n.set("text", `Dina inlägg gillades ${perAuthor[authorId]} gånger den senaste veckan.`);
    app.save(n);
    sent++;
  }
  return sent;
}

module.exports = { weeklyDigest };
```

`pb_hooks/cron/digest.pb.js`:

```js
/// <reference path="../../pb_data/types.d.ts" />

// Måndagar kl. 07:00 UTC
cronAdd("veckosammanfattning", "0 7 * * 1", () => {
  require(`${__hooks}/utils/digest.js`).weeklyDigest($app);
});

// För att kunna testa utan att vänta till måndag – bara för superusers
routerAdd("POST", "/api/kvittra/test-digest", (e) => {
  const sent = require(`${__hooks}/utils/digest.js`).weeklyDigest(e.app);
  return e.json(200, { sent: sent });
}, $apis.requireSuperuserAuth());
```

- `app.expandRecord(record, ["post"], null)` fyller i `expand` på servern,
  och `expandedOne("post")` hämtar den expanderade posten.
- Cron-jobbet går inte genom API-reglerna och ser alla gillningar, även i
  privata grupper. Det är ok här, eftersom notisen bara innehåller ett antal
  och bara går till inläggets egen författare.

### Glöm inte de egna routerna!

Kommer du ihåg `/api/kvittra/stats` från kapitel 7? Den listar titlarna på de
mest gillade inläggen – och går inte genom reglerna. Nu när det finns privata
grupper **läcker** den. Det är den vanligaste läckan när en app får
synlighetsregler i efterhand. Rättningen:

```js
// Bara inlägg som alla får se – inte de i privata grupper!
const posts = e.app.findRecordsByFilter(
  "posts", 'group = "" || group.visibility = "public"', "", 0, 0,
);
```

## Organisera pb_hooks

Bara `.pb.js`-filer **direkt** i `pb_hooks/` laddas automatiskt. I ett större
projekt samlar man därför registreringen i en `main.pb.js` och delar upp
resten i mappar:

```
pb_hooks/
├── main.pb.js                 ← den enda fil som laddas automatiskt
├── collections/               ← en fil per collection
│   ├── users.pb.js
│   ├── posts.pb.js
│   ├── comments.pb.js
│   ├── likes.pb.js
│   ├── groups.pb.js
│   └── group_members.pb.js
├── api/                       ← egna routes (routerAdd)
│   ├── stats.pb.js
│   └── account.pb.js
├── cron/                      ← schemalagda jobb (cronAdd)
│   ├── cleanup.pb.js
│   └── digest.pb.js
└── utils/                     ← hjälpfunktioner (module.exports), inga hooks
    ├── constants.js
    ├── user_rules.js
    ├── group_permissions.js
    ├── notifications.js
    ├── cleanup.js
    └── digest.js
```

`pb_hooks/main.pb.js`:

```js
/// <reference path="../pb_data/types.d.ts" />

// Bara filer direkt i pb_hooks/ laddas automatiskt.
// Filerna i undermapparna registreras härifrån.
require(`${__hooks}/collections/users.pb.js`);
require(`${__hooks}/collections/posts.pb.js`);
require(`${__hooks}/collections/comments.pb.js`);
require(`${__hooks}/collections/likes.pb.js`);
require(`${__hooks}/collections/groups.pb.js`);
require(`${__hooks}/collections/group_members.pb.js`);
require(`${__hooks}/api/stats.pb.js`);
require(`${__hooks}/api/account.pb.js`);
require(`${__hooks}/cron/cleanup.pb.js`);
require(`${__hooks}/cron/digest.pb.js`);
```

Regler för uppdelningen:

| Mapp | Innehåller | Får registrera hooks? |
|------|------------|------------------------|
| `collections/` | `onRecord...`-hooks för en collection | Ja |
| `api/` | `routerAdd` | Ja |
| `cron/` | `cronAdd` (och eventuell testroute) | Ja |
| `utils/` | Ren logik som exporteras med `module.exports` | **Nej** – anropas med `require` *inuti* hooks |

⚠️ **Varning:** Kom ihåg isoleringen från kapitel 7: en hook ser inte
variabler från filen den står i. Därför står `require(...)` **inne i** varje
hook, inte överst i filen. Flyttar du in filerna från kapitel 7 i mapparna –
ta bort dem ur `pb_hooks/` direkt, annars registreras varje hook två gånger.

## Testa att synligheten och rollerna håller

En checklista du bör köra med curl (eller automatiserat) varje gång du ändrar
regler. Testdata: Bo äger den privata gruppen Löparklubben (Anna och David är
medlemmar) och har skrivit inlägget "Intervaller på torsdag" där. Cecilia äger
den publika gruppen Surdegsbagare.

| Test | Förväntat |
|------|-----------|
| Cecilia listar `posts` | Bara inlägg utan grupp och i publika grupper – inte "Intervaller på torsdag" |
| Cecilia hämtar "Intervaller på torsdag" med id | `404` |
| Cecilia listar `comments` till inlägget (filter på `post`) | Tom lista |
| Cecilia kommenterar eller gillar inlägget | `400` |
| Cecilia skriver ett inlägg i Löparklubben | `400` (inte medlem) |
| Cecilia listar `groups` och `group_members` | Bara Surdegsbagare |
| Cecilia listar `posts_view` | Samma inlägg som i `posts` – inget privat |
| David går med i Löparklubben själv | `403 Gruppen är privat. Be en admin lägga till dig.` |
| David går med i Surdegsbagare och skickar `"role":"admin"` | OK, men rollen blir `member` |
| Bo skapar en grupp och skickar `"owner": "<Cecilias id>"` | Bo blir ändå ägare och admin |
| Bo byter `owner` på sin grupp | `404` (`owner:isset = false`) |
| Anna ändrar `text` på sin notis | `404` (bara `read` får ändras) |
| Anna skapar en notis | `403` (create = `null`) |
| Bo läser Annas notis med id | `404` |
| Cecilia anropar `/api/kvittra/stats` | Inga titlar från privata grupper |

## Sammanfattning

- **Utbyggnad:** `groups`, `group_members` (roll per grupp), valfritt
  `posts.group`, `notifications`, `posts_view`.
- **Synlighet:** `group = "" || group.visibility = "public" ||
  group.group_members_via_group.user ?= @request.auth.id` – och samma villkor
  med `post.`-prefix på `comments` och `likes`. Använd `?=`, och glöm inte att
  koppla `@collection` till posten.
- **Server-stämplade fält** (`author`, `owner`, `role`) sätts i
  `onRecordCreateRequest` – klienten kan inte välja dem.
- **Roller:** regeln kräver medlemskap, en delad
  `enforce(e, groupId, operation)` avgör vad rollen får och kastar
  `ForbiddenError`.
- **Sidoeffekter** i `onRecordAfterCreateSuccess` med `try/catch` och
  `e.next()`.
- **`null`-regler** för collections som bara servern skriver till.
- **View-collections** med delfrågor (inte dubbla `JOIN`) för räknare – med
  egna, noggranna regler.
- **Egna routes och cron** går förbi reglerna – granska dem när synligheten
  ändras.
- **Organisera** hooks i `main.pb.js` + `collections/`, `api/`, `cron/`,
  `utils/`.

Nu är du redo för [övningarna](ovningar.md).

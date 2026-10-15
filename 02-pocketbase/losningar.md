# Lösningar – Modul 02: PocketBase

Det här är **lösningsförslag**. Det finns ofta flera rätta sätt. Jämför med din
egen lösning och fundera på skillnaderna – särskilt när det gäller
API-reglerna, där små skillnader kan betyda stora säkerhetshål.

Id:n som `ryd2jdczusx4tm4` i exemplen är slumpade och blir andra hos dig.

## Innehåll

- [Hela schemat som migration](#hela-schemat-som-migration) (kom ikapp på en minut)
- [Övning 1](#övning-1) · [2](#övning-2) · [3](#övning-3) · [4](#övning-4) ·
  [5](#övning-5) · [6](#övning-6) · [7](#övning-7) · [8](#övning-8) ·
  [9–11](#övning-911) · [12](#övning-12)
- [Utbyggnad: grupper](#utbyggnad-grupper) (migration för kapitel 8)

---

## Hela schemat som migration

Lägg filerna i `pb_migrations/` och starta servern (eller kör
`./pocketbase migrate up`). Den första skapar alla collections med fält,
index och API-regler från kapitel 2–4. Den andra lägger in testdatan från
övning 2.

⚠️ **Varning:** Kör dem i en **ny, tom** projektmapp (ta bort `pb_data` först
om du redan har skapat collections för hand – annars krockar namnen). Kör
aldrig testdata-migrationen på en riktig server.

`pb_migrations/1700000000_kvittra_schema.js`:

```js
/// <reference path="../pb_data/types.d.ts" />

// Skapar hela grundmodellen för Kvittra: users, posts, comments, likes, follows.
migrate((app) => {
  const LOGGED_IN = '@request.auth.id != ""';

  // ---------- users (finns redan som auth-collection) ----------
  const users = app.findCollectionByNameOrId("users");
  users.fields.add(new TextField({
    name: "username",
    required: true,
    min: 2,
    max: 20,
    pattern: "^[a-z0-9_]+$",
  }));
  users.fields.add(new TextField({ name: "bio", max: 300 }));
  users.fields.add(new URLField({ name: "website" }));
  users.addIndex("idx_users_username", true, "username", "");
  // Man kan logga in med e-post ELLER användarnamn
  users.passwordAuth.identityFields = ["email", "username"];
  users.listRule = LOGGED_IN;
  users.viewRule = LOGGED_IN;
  users.createRule = ""; // fri registrering
  users.updateRule = "id = @request.auth.id";
  users.deleteRule = null; // konton tas bort via en egen route (kapitel 7)
  app.save(users);

  // ---------- posts ----------
  const posts = new Collection({
    type: "base",
    name: "posts",
    listRule: LOGGED_IN,
    viewRule: LOGGED_IN,
    createRule: '@request.auth.id != "" && @request.body.author = @request.auth.id',
    updateRule: "author = @request.auth.id && @request.body.author:changed = false",
    deleteRule: "author = @request.auth.id",
    fields: [
      {
        type: "relation",
        name: "author",
        collectionId: users.id,
        maxSelect: 1,
        required: true,
        cascadeDelete: false,
      },
      { type: "text", name: "title", required: true, max: 200 },
      { type: "text", name: "body", max: 5000 },
      {
        type: "file",
        name: "image",
        maxSelect: 1,
        maxSize: 5242880,
        mimeTypes: ["image/jpeg", "image/png", "image/webp"],
        thumbs: ["400x0"],
      },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
      { type: "autodate", name: "updated", onCreate: true, onUpdate: true },
    ],
    indexes: [
      "CREATE INDEX idx_posts_author ON posts (author)",
      "CREATE INDEX idx_posts_created ON posts (created)",
    ],
  });
  app.save(posts);

  // ---------- comments ----------
  const comments = new Collection({
    type: "base",
    name: "comments",
    listRule: LOGGED_IN,
    viewRule: LOGGED_IN,
    createRule: '@request.auth.id != "" && @request.body.author = @request.auth.id',
    updateRule:
      "author = @request.auth.id && @request.body.post:isset = false && @request.body.author:isset = false",
    deleteRule: "author = @request.auth.id || post.author = @request.auth.id",
    fields: [
      {
        type: "relation",
        name: "post",
        collectionId: posts.id,
        maxSelect: 1,
        required: true,
        cascadeDelete: true,
      },
      {
        type: "relation",
        name: "author",
        collectionId: users.id,
        maxSelect: 1,
        required: true,
        cascadeDelete: false,
      },
      { type: "text", name: "body", required: true, max: 2000 },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
      { type: "autodate", name: "updated", onCreate: true, onUpdate: true },
    ],
    indexes: ["CREATE INDEX idx_comments_post ON comments (post)"],
  });
  app.save(comments);

  // ---------- likes (N:M users <-> posts) ----------
  const likes = new Collection({
    type: "base",
    name: "likes",
    listRule: LOGGED_IN,
    viewRule: LOGGED_IN,
    createRule: '@request.auth.id != "" && @request.body.user = @request.auth.id',
    updateRule: null, // en gillning ändras aldrig – den skapas eller tas bort
    deleteRule: "user = @request.auth.id",
    fields: [
      {
        type: "relation",
        name: "post",
        collectionId: posts.id,
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
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_likes_post_user ON likes (post, user)",
      "CREATE INDEX idx_likes_user ON likes (user)",
    ],
  });
  app.save(likes);

  // ---------- follows (N:M users <-> users) ----------
  const follows = new Collection({
    type: "base",
    name: "follows",
    listRule: LOGGED_IN,
    viewRule: LOGGED_IN,
    createRule:
      '@request.auth.id != "" && @request.body.follower = @request.auth.id && @request.body.following != @request.auth.id',
    updateRule: null,
    deleteRule: "follower = @request.auth.id",
    fields: [
      {
        type: "relation",
        name: "follower",
        collectionId: users.id,
        maxSelect: 1,
        required: true,
        cascadeDelete: true,
      },
      {
        type: "relation",
        name: "following",
        collectionId: users.id,
        maxSelect: 1,
        required: true,
        cascadeDelete: true,
      },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_follows_follower_following ON follows (follower, following)",
      "CREATE INDEX idx_follows_following ON follows (following)",
    ],
  });
  app.save(follows);
}, (app) => {
  // Nedgradering: ta bort i omvänd ordning
  for (const name of ["follows", "likes", "comments", "posts"]) {
    app.delete(app.findCollectionByNameOrId(name));
  }
  const users = app.findCollectionByNameOrId("users");
  users.passwordAuth.identityFields = ["email"];
  users.removeIndex("idx_users_username");
  for (const name of ["website", "bio", "username"]) {
    users.fields.removeByName(name);
  }
  app.save(users);
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

  const usersCollection = app.findCollectionByNameOrId("users");
  const person = (username, name, bio, website) => {
    const u = new Record(usersCollection);
    u.set("email", username + "@example.com");
    u.set("username", username);
    u.set("name", name);
    u.set("bio", bio);
    u.set("website", website);
    u.set("verified", true);
    u.setPassword("hemligt123");
    app.save(u);
    return u;
  };

  const anna = person("anna", "Anna Andersson", "Kaffe, kod och katter.", "https://example.com/anna");
  const bo = person("bo", "Bo Berg", "Springer mest.", "");
  const cecilia = person("cecilia", "Cecilia Ek", "Bakar bröd på helgerna.", "https://example.com/cecilia");
  const david = person("david", "David Dahl", "", "");

  const p1 = save("posts", { author: bo.id, title: "Bästa kaffet i stan?", body: "Jag letar efter ett nytt favoritkafé. Tips?" });
  const p2 = save("posts", { author: bo.id, title: "Tips på löparrundor", body: "Fem kilometer runt sjön är perfekt en tisdag." });
  const p3 = save("posts", { author: anna.id, title: "Mitt första inlägg", body: "Hej allihop! Nu är jag också på Kvittra." });
  const p4 = save("posts", { author: cecilia.id, title: "Surdegsbröd", body: "Bakade surdegsbröd idag. Tredje försöket blev bäst." });
  save("posts", { author: cecilia.id, title: "Kaffe eller te?", body: "Jag har bytt till te. Någon mer?" });
  save("posts", { author: david.id, title: "Hej Kvittra!", body: "Testar appen." });

  save("comments", { post: p1.id, author: anna.id, body: "Testa kaféet vid torget!" });
  save("comments", { post: p1.id, author: cecilia.id, body: "Håller med Anna." });
  save("comments", { post: p3.id, author: bo.id, body: "Välkommen!" });
  save("comments", { post: p4.id, author: anna.id, body: "Ser jättegott ut." });
  save("comments", { post: p4.id, author: david.id, body: "Recept, tack!" });

  save("likes", { post: p1.id, user: anna.id });
  save("likes", { post: p1.id, user: cecilia.id });
  save("likes", { post: p1.id, user: david.id });
  save("likes", { post: p3.id, user: bo.id });
  save("likes", { post: p4.id, user: anna.id });
  save("likes", { post: p4.id, user: bo.id });

  save("follows", { follower: anna.id, following: bo.id });
  save("follows", { follower: anna.id, following: cecilia.id });
  save("follows", { follower: bo.id, following: anna.id });
  save("follows", { follower: cecilia.id, following: bo.id });
  save("follows", { follower: david.id, following: anna.id });
}, (app) => {
  // Töm testdatan. likes, follows och comments försvinner med cascade delete,
  // men posts.author har ingen cascade – ta därför bort inläggen först.
  for (const r of app.findAllRecords("posts")) app.delete(r);
  for (const username of ["anna", "bo", "cecilia", "david"]) {
    try {
      app.delete(app.findAuthRecordByEmail("users", username + "@example.com"));
    } catch (_) {}
  }
});
```

Alla användare har lösenordet `hemligt123` och kan logga in med e-post eller
användarnamn. Skapa sedan en superuser:

```bash
./pocketbase superuser upsert admin@example.com EttLangtLosenord123
```

Sammanfattning av testdatan:

| | anna | bo | cecilia | david |
|---|---|---|---|---|
| Inlägg | Mitt första inlägg | Bästa kaffet i stan?, Tips på löparrundor | Surdegsbröd, Kaffe eller te? | Hej Kvittra! |
| Följer | bo, cecilia | anna | bo | anna |
| Följs av | bo, david | anna, cecilia | anna | – |
| Har gillat | Bästa kaffet, Surdegsbröd | Mitt första inlägg, Surdegsbröd | Bästa kaffet | Bästa kaffet |

---

## Övning 1

a) `created` blev `TEXT` (datum lagras som text i UTC). `emailVisibility`
blev `BOOLEAN`.

b) Nej. PocketBase skapar inga `FOREIGN KEY`-constraints. Relationsfält är
vanliga `TEXT`-kolumner (eller `JSON` för multi), och PocketBase kontrollerar
själv att id:na finns och sköter cascade delete. Därför ska data alltid
ändras via API:t eller Dashboard.

c) Inte i `CREATE TABLE`-satsen, utan som en egen rad i `db_indexes`:
`CREATE UNIQUE INDEX ... ON likes (post, user)` (eller med backticks, beroende
på hur det skapades). Namnet kan se ut som `idx_xxxx` om Dashboard döpte det.
Index är egna objekt i databasen, precis som i modul 01.

d) En fil per ändring du gjort i Dashboard (ändrat `users`, skapat `posts`,
`db_tables` ...). Automigrate skapar dem automatiskt så att strukturen kan
versionshanteras. Även view-collections blir migrationer.

---

## Övning 2

2. Dashboard visar användarnamn och titlar (t.ex. "anna", "Bästa kaffet i
   stan?") i stället för id:n i relationskolumnerna.

3. Det går inte:
   `Failed to delete record. Make sure that the record is not part of a required relation reference.`
   `posts.author` (och `comments.author`) är *required* och har **inte**
   cascade delete. Att ta bort Bo skulle lämna inlägg utan författare, så
   PocketBase vägrar (som `ON DELETE RESTRICT`). Kvittra löser det genom att
   anonymisera kontot i stället (kapitel 7, övning 6.4).

4. Kommentaren och gillningen tas bort automatiskt, eftersom `comments.post`
   och `likes.post` har **cascade delete**.

5. Den dubbla gillningen stoppas av det unika indexet
   (`validation_not_unique`) – index gäller alltid, oavsett vem som sparar.
   Att Anna följer Anna **går** däremot i Dashboard: inga regler finns än, och
   regler gäller ändå inte superusers. Regeln
   `@request.body.following != @request.auth.id` skyddar API:t. Ska det vara
   omöjligt överallt behövs en model hook (`onRecordValidate`), som i kapitel
   7:s exempel med gillningar.

---

## Övning 3

### Reglerna

| Collection | List / View | Create | Update | Delete |
|------------|-------------|--------|--------|--------|
| `users` | `@request.auth.id != ""` | `""` (fri registrering) | `id = @request.auth.id` | `null` |
| `posts` | `@request.auth.id != ""` | `@request.auth.id != "" && @request.body.author = @request.auth.id` | `author = @request.auth.id && @request.body.author:changed = false` | `author = @request.auth.id` |
| `comments` | `@request.auth.id != ""` | `@request.auth.id != "" && @request.body.author = @request.auth.id` | `author = @request.auth.id && @request.body.post:isset = false && @request.body.author:isset = false` | `author = @request.auth.id \|\| post.author = @request.auth.id` |
| `likes` | `@request.auth.id != ""` | `@request.auth.id != "" && @request.body.user = @request.auth.id` | `null` | `user = @request.auth.id` |
| `follows` | `@request.auth.id != ""` | `@request.auth.id != "" && @request.body.follower = @request.auth.id && @request.body.following != @request.auth.id` | `null` | `follower = @request.auth.id` |

(I tabellen står `\|\|` för att Markdown-tabellen inte ska gå sönder. I
Dashboard skriver du `||`.)

### Förväntade resultat

| # | Som | Försök | Resultat |
|---|-----|--------|----------|
| 1 | utloggad | Lista `posts` | `200` med **tom** lista (list-regeln filtrerar bort allt) |
| 2 | utloggad | Registrera `erik` | `200`, kontot skapas |
| 3 | utloggad | Registrera med `"verified": true` | `400`, `validation_values_mismatch` på `verified` – PocketBase skyddar fältet själv |
| 4 | Anna | Lista `posts` | `200`, alla inlägg |
| 5 | Anna | Skapa inlägg i eget namn | `200` |
| 6 | Anna | Skapa inlägg i Bos namn | `400 Failed to create record.` |
| 7 | Anna | Ändra titel på eget inlägg | `200` |
| 8 | Anna | Byta `author` till Bo | `404` |
| 9 | Anna | Ändra Bos inlägg | `404` |
| 10 | Anna | Gilla igen | `400`, `validation_not_unique` på `post` och `user` |
| 11 | Anna | Gilla i Cecilias namn | `400 Failed to create record.` |
| 12 | Anna | Ta bort Bos gillning | `404` |
| 13 | Anna | Ändra en gillning | `403 Only superusers can perform this action.` (Update är `null`) |
| 14 | Anna | Följa sig själv | `400 Failed to create record.` |
| 15 | Anna | Ta bort Bos kommentar under sitt eget inlägg | `204` (`post.author = @request.auth.id`) |
| 16 | Anna | Flytta sin kommentar | `404` (`post:isset = false`) |
| 17 | Anna | Ändra Bos `name` | `404` |
| 18 | Anna | Lista `users` | Hon ser sin egen e-post, men inte de andras (`emailVisibility` är `false`) |

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

# Annas id (behövs när hon skapar saker i sitt namn)
ME=$(curl -s -X POST $B/api/collections/users/auth-refresh -H "Authorization: $TOKEN" \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["record"]["id"])')

# 2. Lista inlägg
curl -s $B/api/collections/posts/records -H "Authorization: $TOKEN"

# 3. Hämta ett (byt ut id)
curl -s $B/api/collections/posts/records/INLAGGETS_ID -H "Authorization: $TOKEN"

# 4. Skapa
curl -s -X POST $B/api/collections/posts/records \
  -H "Authorization: $TOKEN" -H "Content-Type: application/json" \
  -d "{\"author\":\"$ME\",\"title\":\"Fikadags\",\"body\":\"Kanelbullar i fikarummet!\"}"

# 5. Ändra
curl -s -X PATCH $B/api/collections/posts/records/NYA_ID \
  -H "Authorization: $TOKEN" -H "Content-Type: application/json" \
  -d '{"body":"Kanelbullar OCH kardemummabullar!"}'

# 6. Ta bort → 204
curl -s -X DELETE $B/api/collections/posts/records/NYA_ID \
  -H "Authorization: $TOKEN" -w "%{http_code}\n"
```

7. Svaret innehåller fel per fält:

```json
{"data":{"title":{"code":"validation_required","message":"Cannot be blank."}},
 "message":"Failed to create record.","status":400}
```

8. Gilla och ta bort gillningen:

```bash
LIKE=$(curl -s -X POST $B/api/collections/likes/records \
  -H "Authorization: $TOKEN" -H "Content-Type: application/json" \
  -d "{\"post\":\"DAVIDS_INLAGG_ID\",\"user\":\"$ME\"}" \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["id"])')

curl -s -X DELETE $B/api/collections/likes/records/$LIKE \
  -H "Authorization: $TOKEN" -w "%{http_code}\n"   # 204
```

9. `POST /api/collections/follows/records` med
   `{"follower":"<Annas id>","following":"<Davids id>"}`.

10. Registrera och logga in med användarnamnet:

```bash
curl -s -X POST $B/api/collections/users/records -H "Content-Type: application/json" \
  -d '{"email":"erik@example.com","password":"hemligt123","passwordConfirm":"hemligt123",
       "username":"erik","name":"Erik Eriksson"}'

curl -s -X POST $B/api/collections/users/auth-with-password -H "Content-Type: application/json" \
  -d '{"identity":"erik","password":"hemligt123"}'
```

Det fungerar bara om `username` är identitetsfält (*Options* → *Identity/Password*).

---

## Övning 5

Alla svar är testade mot testdatan. Skicka dem med
`curl -G ... --data-urlencode 'filter=...'`. `ANNAS_ID` och `BOS_ID` byter du
mot riktiga id:n.

| # | Collection | Parametrar | Resultat med testdatan |
|---|------------|------------|------------------------|
| 1 | `posts` | `sort=-created` | 6 inlägg, "Hej Kvittra!" först |
| 2 | `posts` | `filter=title ~ "kaffe" \|\| body ~ "kaffe"` | Bästa kaffet i stan?, Kaffe eller te? |
| 3 | `posts` | `filter=author.username = "bo"` | Bos 2 inlägg |
| 4 | `posts` | `expand=author,comments_via_post.author` `fields=title,expand.author.name,expand.comments_via_post.body,expand.comments_via_post.expand.author.username` | |
| 5 | `comments` | `filter=post.title = "Bästa kaffet i stan?"` `sort=created` `expand=author` | Annas och Cecilias kommentarer |
| 6 | `posts` | Går **inte** direkt – se nedan | |
| 7 | `posts` | `filter=likes_via_post.user ?= "ANNAS_ID"` | Bästa kaffet i stan?, Surdegsbröd |
| 8 | `posts` | `filter=likes_via_post.user != "ANNAS_ID"` | De 4 andra (även de som ingen gillat) |
| 9 | `posts` | `filter=author.follows_via_following.follower ?= "ANNAS_ID"` `sort=-created` `expand=author` | Bos och Cecilias 4 inlägg |
| 10 | `users` | Följer: `filter=follows_via_following.follower ?= "ANNAS_ID"`. Följare: `filter=follows_via_follower.following ?= "ANNAS_ID"` | bo, cecilia / bo, david |
| 11 | `users` | `filter=follows_via_follower.following ?= "BOS_ID" && follows_via_following.follower ?= "BOS_ID"` | anna |
| 12 | `posts` | `filter=comments_via_post.id = ""` | Tips på löparrundor, Kaffe eller te?, Hej Kvittra! |
| 13 | `posts` | `page=2` `perPage=2` `sort=-created` | `totalPages` = 3 |
| 14 | `posts` | `filter=created >= @todayStart` `sort=-created` `fields=id,title,body:excerpt(50,true)` | |
| 15 | `posts` | `filter=author = "ANNAS_ID"` | Mitt första inlägg |

**6.** Filterspråket kan inte räkna – det finns ingen `COUNT` i ett filter, och
`:length` fungerar bara på fält som själva är listor. Alternativ:

- En view-collection med `likes_count` (kapitel 8: `posts_view`), och sedan
  `filter=likes_count >= 2` på viewn. Ger Bästa kaffet i stan? och
  Surdegsbröd.
- Ett number-fält `likes_count` på `posts` som hooks räknar upp och ner när
  gillningar skapas och tas bort (snabbt att läsa, men lätt att det glider
  isär).
- Hämta gillningarna och räkna i appen (bara om de är få).

**9.** Med `=` i stället för `?=` blir det bara 2 inlägg (Cecilias). `=`
betyder "**alla** följare är Anna", och Bo har två följare (Anna och Cecilia).

**10.** På `users` pekar `follows_via_following` på rader där användaren
*blir följd*. `.follower ?= ANNAS_ID` betyder alltså "Anna följer den här
användaren". Åt andra hållet: `follows_via_follower` är raderna där
användaren *följer*, och `.following ?= ANNAS_ID` betyder "den här användaren
följer Anna".

**14.** `@todayStart` är midnatt **UTC** – se varningen i kapitel 5.

**15.** **Inte** `author = @request.auth.id` – `@request` får inte användas i
klientens filter (`403 Only superusers can filter by @request.`). `@now` och
`@todayStart` är däremot tillåtna.

---

## Övning 6

1. Koden finns i [kapitel 7](07-hooks-och-migrationer.md#exempel-2-användarnamn--normalisera-och-validera)
   (`utils/constants.js`, `utils/user_rules.js`, `users.pb.js`, `likes.pb.js`
   och `posts.pb.js`).

3. Ja, gillningen stoppas även i Dashboard. `onRecordValidate` är en *model
   hook* som körs vid varje sparning, oavsett källa – bra, eftersom regeln
   gäller datan. Spamskyddet stoppar däremot **inte** en superuser: det är en
   request hook som hoppar över `e.hasSuperuserAuth()`. Rimligt, eftersom
   spamskyddet handlar om *vem som frågar*, och en administratör som lägger in
   data ska inte begränsas.

4. Efter anropet: Davids gillning av "Bästa kaffet i stan?" och följningen av
   Anna är borta, "Hej Kvittra!" och kommentaren "Recept, tack!" står kvar
   under "Borttagen användare", och den gamla token ger
   `401 The request requires valid record authorization token.` (lösenordsbytet
   ändrade `tokenKey`).

5. Förbjudna ord gäller **innehållet**, så en model hook passar. Låt den gälla
   alla – även superusers – så att inget förbjudet kan komma in den vägen
   heller. Lägg `BANNED_WORDS: ["spam", "fusk"]` i `constants.js`:

```js
/// <reference path="../pb_data/types.d.ts" />

onRecordValidate((e) => {
  e.next();
  const { BANNED_WORDS } = require(`${__hooks}/utils/constants.js`);
  const text = e.record.getString("body").toLowerCase();
  for (const word of BANNED_WORDS) {
    if (text.indexOf(word) !== -1) {
      throw new BadRequestError("Kommentaren innehåller otillåtna ord.");
    }
  }
}, "comments");
```

6. Ja, i teorin. Hooken *räknar* först och *sparar* sedan. Kommer två anrop
   exakt samtidigt kan båda räkna till 2 innan något av dem hunnit spara – en
   *race condition* (se isolering i ACID-kapitlet). SQLite skriver bara en
   transaktion i taget, vilket gör fönstret mycket litet, men det är inte noll.
   För ett spamskydd spelar det ingen roll – ett fjärde inlägg ibland är
   ofarligt. När en gräns *måste* hålla (t.ex. "max ett konto per e-post")
   använder man ett **unikt index**, som databasen själv garanterar.

---

## Övning 7

1–2. **+ New collection → View**, namn `user_stats`, fråga:

```sql
SELECT u.id, u.username,
       CAST((SELECT COUNT(*) FROM posts p   WHERE p.author    = u.id) AS INTEGER) AS posts_count,
       CAST((SELECT COUNT(*) FROM follows f WHERE f.following = u.id) AS INTEGER) AS followers_count,
       CAST((SELECT COUNT(*) FROM follows f WHERE f.follower  = u.id) AS INTEGER) AS following_count
FROM users u
```

List/View-regel: `@request.auth.id != ""`.

Med tre `LEFT JOIN` (posts, follows, follows) och `COUNT` multipliceras raderna:
Bo har 2 inlägg och 2 följare, så båda siffrorna skulle bli 4. Varje räknare
behöver därför en egen delfråga. `CAST(... AS INTEGER)` gör att PocketBase
gissar typen `number`.

3. `GET /api/collections/user_stats/records?sort=-followers_count,username`

| username | posts_count | followers_count | following_count |
|----------|-------------|-----------------|-----------------|
| anna | 1 | 2 | 2 |
| bo | 2 | 2 | 1 |
| cecilia | 2 | 1 | 1 |
| david | 1 | 0 | 1 |

4. Alla inloggade ser siffrorna. View-frågan går **inte** genom reglerna på
   `posts` och `follows`, så den räknar allt. Här är det ofarligt – samma
   uppgifter går att få fram via `follows` och `posts`, som alla inloggade får
   läsa. Det blir ett problem när viewn räknar något man *inte* får se: efter
   kapitel 8 räknas också inlägg i privata grupper i `posts_count`. Då avslöjar
   viewn att någon är aktiv i privata grupper. Rätta genom att bara räkna
   inlägg med `p."group" = ''` (eller i publika grupper). Viewns egna regler är
   det enda skyddet.

5. Gillningar som varje användare har fått:

```sql
SELECT u.id, u.username, COUNT(l.id) AS likes_received
FROM users u
LEFT JOIN posts p ON p.author = u.id
LEFT JOIN likes l ON l.post = p.id
GROUP BY u.id
```

Med testdatan: bo 3, cecilia 2, anna 1, david 0. Här blir det rätt med `JOIN`
eftersom vi bara räknar *en* sorts många-rader (gillningar via inlägg).
`COUNT(...)` direkt i `SELECT` gissas som `number` utan `CAST`.

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
    createRule: null, // taggar skapas av superuser
    updateRule: null,
    deleteRule: null,
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
    '@request.auth.id != "" && @request.body.author = @request.auth.id && ' +
    "@request.body.tags:length <= 3";
  app.save(posts);

  for (const name of ["kaffe", "löpning", "bakning", "fika"]) {
    const record = new Record(tags);
    record.set("name", name);
    app.save(record);
  }
}, (app) => {
  const posts = app.findCollectionByNameOrId("posts");
  posts.fields.removeByName("tags");
  posts.createRule = '@request.auth.id != "" && @request.body.author = @request.auth.id';
  app.save(posts);
  app.delete(app.findCollectionByNameOrId("tags"));
});
```

3. Lägga till och ta bort (som Bo, på hans eget inlägg):

```bash
curl -s -X PATCH $B/api/collections/posts/records/INLAGGETS_ID \
  -H "Authorization: $BO_TOKEN" -H "Content-Type: application/json" \
  -d '{"tags+": "TAGG_ID"}'

curl -s -X PATCH $B/api/collections/posts/records/INLAGGETS_ID \
  -H "Authorization: $BO_TOKEN" -H "Content-Type: application/json" \
  -d '{"tags-": "TAGG_ID"}'
```

4. `filter=tags.name ?= "kaffe"` ger alla inlägg där **minst en** tagg heter
   kaffe. `tags.name = "kaffe"` kräver att **alla** taggar heter kaffe – ett
   inlägg med `["kaffe","fika"]` kommer då inte med.

5. `GET /api/collections/tags/records?expand=posts_via_tags`

6. Create-regeln (se migrationen ovan):

```
@request.auth.id != "" && @request.body.author = @request.auth.id &&
@request.body.tags:length <= 3
```

### Del B – gillningar och följningar

7. ```
   GET /api/collections/posts/records/INLAGGETS_ID
       ?expand=likes_via_post.user
       &fields=title,expand.likes_via_post.expand.user.username
   ```

8. Förslag att följa, som filter på `users` (`MITT_ID` = Davids id):

```
follows_via_following.follower.follows_via_following.follower ?= "MITT_ID" &&
follows_via_following.follower != "MITT_ID" &&
id != "MITT_ID"
```

Läs den inifrån: `follows_via_following.follower` är de som följer den här
användaren; `.follows_via_following.follower ?= MITT_ID` betyder att jag följer
någon av dem. Rad två: jag följer inte redan användaren (`!=` = "ingen av
följarna är jag"). Rad tre: inte jag själv.

Testat: David följer Anna, som följer Bo och Cecilia – förslagen blir **bo**
och **cecilia**. För Anna blir listan tom: de hon följer (Bo och Cecilia)
följer bara Anna och Bo, och Bo följer hon redan.

9. Multi-relation `posts.liked_by`:
   - alla måste ha **update**-rätt på hela inlägget för att kunna gilla – och
     kan då ändra titeln eller ta bort andras gillningar;
   - ingen plats för `created` (när gillade man?), så ingen veckosammanfattning;
   - två samtidiga gillningar kan skriva över varandra (båda läser listan,
     båda skriver tillbaka);
   - realtid blir "inlägget ändrades" i stället för "ny gillning".

   Multi-relation `users.following`:
   - man kan inte fråga "vilka följer Anna?" lika enkelt, och listan kan bli
     tusentals id:n lång på populära konton;
   - regeln för att följa skulle behöva låta användaren uppdatera sin egen
     post – lätt att råka öppna för andra fält;
   - inget unikt index, ingen `created`, och "man kan inte följa sig själv"
     blir svårare att uttrycka.

---

## Övning 9–11

Koden för hooks, regler, notiser, view och cron finns i sin helhet i
[kapitel 8](08-grupper-och-behorigheter.md) och är testad i den mappstruktur
som beskrivs där (`main.pb.js` + `collections/`, `api/`, `cron/`, `utils/`).
Migrationen som bygger strukturen finns [nedan](#utbyggnad-grupper).

**9.5** (testat):

- `group = "" || @collection.group_members.user ?= @request.auth.id`: Cecilia
  (medlem i Surdegsbagare) ser "Intervaller på torsdag" – läcka. Den som inte
  är med i någon grupp ser det inte.
- `group = "" || group.group_members_via_group.user = @request.auth.id`: ingen
  ser gruppinlägget, inte ens Bo och Anna.

**9.6** Exempel på läckor att leta efter:

- `comments` eller `likes` utan synlighetsregel → man kan lista kommentarer
  och gillningar på privata inlägg (och via `expand=post` kanske se dem).
- `posts` update-regel utan `@request.body.group:changed = false` → en
  medlem kan flytta ett privat inlägg till en publik grupp – eller till ingen
  grupp alls.
- `posts_view` utan synlighetsregel → alla ser titlarna.
- `group_members` med list-regeln `@request.auth.id != ""` → alla ser vilka
  som är med i privata grupper.
- `/api/kvittra/stats` från kapitel 7 → listar titlar från privata grupper.
- `user_stats` (övning 7) → räknar inlägg i privata grupper.

**10.4** Per-grupp-rättigheter. Lägg till ett json-fält `permissions` på
`groups` och läs det i `group_permissions.js`:

```js
function loadPermissions(app, groupId) {
  try {
    const group = app.findRecordById("groups", groupId);
    // getString ger JSON-texten; JSON.parse gör om den till ett JS-objekt.
    // (group.get("permissions") kan ge råa byte i JS-hooks!)
    const raw = group.getString("permissions");
    const parsed = raw ? JSON.parse(raw) : null;
    return parsed || ROLE_PERMISSIONS;
  } catch (err) {
    return ROLE_PERMISSIONS;
  }
}

function can(app, groupId, userId, operation) {
  const table = loadPermissions(app, groupId);
  const allowed = table[roleInGroup(app, groupId, userId)] || [];
  return allowed.indexOf(operation) !== -1;
}
```

Sätt Surdegsbagares `permissions` (som superuser eller admin) till:

```json
{
  "admin": ["delete_post", "delete_comment", "manage_members", "edit_group"],
  "moderator": ["delete_post", "delete_comment", "edit_group"],
  "member": []
}
```

⚠️ Tänk på vem som får ändra fältet! Med update-regeln från kapitel 8 och
`enforce(..., "edit_group")` kan en admin ge sig själv – eller moderatorerna –
nya rättigheter. Vill du att bara gruppens ägare ska få ändra tabellen,
lägg till `@request.body.permissions:isset = false || owner = @request.auth.id`
i update-regeln.

**10.5** Route som visar vad den inloggade får göra i en grupp:

```js
/// <reference path="../../pb_data/types.d.ts" />

routerAdd("GET", "/api/kvittra/groups/{id}/my-permissions", (e) => {
  const groupId = e.request.pathValue("id");
  const perms = require(`${__hooks}/utils/group_permissions.js`);
  const role = perms.roleInGroup(e.app, groupId, e.auth.id);
  return e.json(200, {
    group: groupId,
    role: role,
    permissions: perms.ROLE_PERMISSIONS[role] || [],
  });
}, $apis.requireAuth("users"));
```

Lägg filen i `pb_hooks/api/permissions.pb.js` och lägg till
`` require(`${__hooks}/api/permissions.pb.js`); `` i `main.pb.js`. Svar för
Löparklubben (Anna moderator, Bo admin, Cecilia inte medlem):

```json
{"group":"...","permissions":["delete_post","delete_comment"],"role":"moderator"}
{"group":"...","permissions":["delete_post","delete_comment","manage_members","edit_group"],"role":"admin"}
{"group":"...","permissions":[],"role":""}
```

(Har du gjort 10.4, byt `perms.ROLE_PERMISSIONS[role]` mot den tabell
`loadPermissions` returnerar.)

**11.2** `posts_view` med testdatan, `sort=-likes_count`: Bästa kaffet i
stan? (3 gillningar, 2 kommentarer), Surdegsbröd (2, 2), Mitt första inlägg
(1, 1), sedan de övriga med 0.

**11.6** Ändra `notify` så att den hoppar över mottagare som inte vill ha
notiser om gillningar:

```js
if (type === "like") {
  const recipient = app.findRecordById("users", userId);
  if (!recipient.getBool("notify_likes")) return;
}
```

Regeln på `users` behöver inte ändras: update-regeln `id = @request.auth.id`
låter redan var och en ändra sitt *eget* fält – och fältet påverkar bara en
själv. (Jämför med `is_moderator` i kapitel 4, som ger makt över andra.)

---

## Övning 12

Programmet i slutet av [kapitel 6](06-dart-sdk.md#ett-komplett-dart-program)
tillsammans med klasserna `AppUser`, `Post`, `Comment` och `KvittraRepository`
från samma kapitel är ett komplett lösningsförslag (testat med Dart-paketet
`pocketbase` 0.25). Realtidsdelen:

```dart
final post = await pb.collection('posts').getFirstListItem(
  'title = "Bästa kaffet i stan?"',
);

final unsubscribe = await pb.collection('comments').subscribe(
  '*',
  (e) => print('${e.action}: ${e.record?.getStringValue('body')}'),
  filter: pb.filter('post = {:post}', {'post': post.id}),
);

// Låt programmet vänta en stund så att du hinner skapa kommentarer i Dashboard
await Future.delayed(const Duration(seconds: 60));
await unsubscribe();
```

Bara kommentaren på "Bästa kaffet i stan?" dyker upp – filtret gäller även
realtidshändelserna.

---

## Utbyggnad: grupper

Migration för [kapitel 8](08-grupper-och-behorigheter.md). Den förutsätter
schemat ovan (`1700000000_kvittra_schema.js`). Hooks från kapitel 8 behövs
för att grupper ska få ägare och första admin.

`pb_migrations/1700000500_grupper.js`:

```js
/// <reference path="../pb_data/types.d.ts" />

// Utbyggnad: grupper med roller, notiser och posts_view.
migrate((app) => {
  const users = app.findCollectionByNameOrId("users");
  const posts = app.findCollectionByNameOrId("posts");

  // ---------- groups ----------
  const groups = new Collection({
    type: "base",
    name: "groups",
    fields: [
      { type: "text", name: "name", required: true, max: 100 },
      { type: "text", name: "description", max: 1000 },
      { type: "relation", name: "owner", collectionId: users.id, maxSelect: 1, required: true, cascadeDelete: false },
      { type: "select", name: "visibility", values: ["public", "private"], maxSelect: 1, required: true },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
      { type: "autodate", name: "updated", onCreate: true, onUpdate: true },
    ],
  });
  app.save(groups);

  // ---------- group_members ----------
  const members = new Collection({
    type: "base",
    name: "group_members",
    fields: [
      { type: "relation", name: "group", collectionId: groups.id, maxSelect: 1, required: true, cascadeDelete: true },
      { type: "relation", name: "user", collectionId: users.id, maxSelect: 1, required: true, cascadeDelete: true },
      { type: "select", name: "role", values: ["admin", "moderator", "member"], maxSelect: 1, required: true },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_group_members_group_user ON group_members (`group`, user)",
      "CREATE INDEX idx_group_members_user ON group_members (user)",
    ],
  });
  app.save(members);

  // Regler som nämner group_members_via_group kan sättas först när
  // group_members finns.
  const isMember = "group_members_via_group.user ?= @request.auth.id";
  groups.listRule = '@request.auth.id != "" && (visibility = "public" || ' + isMember + ")";
  groups.viewRule = groups.listRule;
  groups.createRule = '@request.auth.id != ""'; // owner stämplas av en hook
  groups.updateRule = isMember + " && @request.body.owner:isset = false"; // + enforce(edit_group)
  groups.deleteRule = "owner = @request.auth.id";
  app.save(groups);

  members.listRule =
    '@request.auth.id != "" && (group.visibility = "public" || group.' + isMember + ")";
  members.viewRule = members.listRule;
  members.createRule = '@request.auth.id != ""'; // hook: gå med i publik grupp, eller admin lägger till
  members.updateRule =
    '@request.auth.id != "" && @request.body.group:isset = false && @request.body.user:isset = false'; // + enforce
  members.deleteRule = "user = @request.auth.id || group." + isMember; // + enforce
  app.save(members);

  // ---------- posts.group ----------
  posts.fields.add(new RelationField({
    name: "group",
    collectionId: groups.id,
    maxSelect: 1,
    cascadeDelete: true,
  }));
  posts.addIndex("idx_posts_group", false, "`group`", "");
  const canSeePost = 'group = "" || group.visibility = "public" || group.' + isMember;
  posts.listRule = '@request.auth.id != "" && (' + canSeePost + ")";
  posts.viewRule = posts.listRule;
  posts.createRule =
    '@request.auth.id != "" && @request.body.author = @request.auth.id && ' +
    '(@request.body.group = "" || @request.body.group.' + isMember + ")";
  posts.updateRule =
    "author = @request.auth.id && @request.body.author:changed = false && @request.body.group:changed = false";
  posts.deleteRule = "author = @request.auth.id || group." + isMember; // + enforce(delete_post)
  app.save(posts);

  // ---------- comments och likes följer inläggets synlighet ----------
  const canSeeThePost =
    'post.group = "" || post.group.visibility = "public" || post.group.' + isMember;
  const canSeeBodyPost =
    '@request.body.post.group = "" || @request.body.post.group.visibility = "public" || ' +
    "@request.body.post.group." + isMember;

  const comments = app.findCollectionByNameOrId("comments");
  comments.listRule = '@request.auth.id != "" && (' + canSeeThePost + ")";
  comments.viewRule = comments.listRule;
  comments.createRule =
    '@request.auth.id != "" && @request.body.author = @request.auth.id && (' +
    canSeeBodyPost + ")";
  comments.deleteRule =
    "author = @request.auth.id || post.author = @request.auth.id || post.group." + isMember; // + enforce
  app.save(comments);

  const likes = app.findCollectionByNameOrId("likes");
  likes.listRule = '@request.auth.id != "" && (' + canSeeThePost + ")";
  likes.viewRule = likes.listRule;
  likes.createRule =
    '@request.auth.id != "" && @request.body.user = @request.auth.id && (' +
    canSeeBodyPost + ")";
  app.save(likes);

  // ---------- notifications (skrivs bara av servern) ----------
  const notifications = new Collection({
    type: "base",
    name: "notifications",
    listRule: "user = @request.auth.id",
    viewRule: "user = @request.auth.id",
    createRule: null,
    updateRule:
      "user = @request.auth.id && @request.body.user:isset = false && @request.body.actor:isset = false && " +
      "@request.body.type:isset = false && @request.body.post:isset = false && @request.body.text:isset = false",
    deleteRule: "user = @request.auth.id",
    fields: [
      { type: "relation", name: "user", collectionId: users.id, maxSelect: 1, required: true, cascadeDelete: true },
      { type: "relation", name: "actor", collectionId: users.id, maxSelect: 1, cascadeDelete: true },
      { type: "select", name: "type", values: ["like", "comment", "digest"], maxSelect: 1, required: true },
      { type: "relation", name: "post", collectionId: posts.id, maxSelect: 1, cascadeDelete: true },
      { type: "text", name: "text", max: 500 },
      { type: "bool", name: "read" },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
    ],
    indexes: ["CREATE INDEX idx_notifications_user_read ON notifications (user, read)"],
  });
  app.save(notifications);

  // ---------- posts_view ----------
  const postsView = new Collection({
    type: "view",
    name: "posts_view",
    listRule: '@request.auth.id != "" && (' + canSeePost + ")",
    viewRule: '@request.auth.id != "" && (' + canSeePost + ")",
    viewQuery: `
      SELECT p.id, p.author, p."group", p.title, p.created,
             CAST((SELECT COUNT(*) FROM likes l    WHERE l.post = p.id) AS INTEGER) AS likes_count,
             CAST((SELECT COUNT(*) FROM comments c WHERE c.post = p.id) AS INTEGER) AS comments_count
      FROM posts p
    `,
  });
  app.save(postsView);
});
```

Kommentarer:

- Migrationen saknar nedgraderingsfunktion – den är valfri. Att bygga tillbaka
  allt (ta bort fält, index och collections i rätt ordning, och återställa
  reglerna) är ett bra extra övningsmoment.
- `groups` och `group_members` sparas först **utan** regler och får sina
  regler i ett andra steg. En regel som nämner `group_members_via_group` kan
  inte sparas innan `group_members` finns.
- Strängarna byggs ihop med `+` för att det ska synas att samma villkor
  återkommer. Klistrar du in reglerna i Dashboard i stället skriver du ut dem
  i sin helhet.
- I indexen står `` `group` `` med backticks, eftersom `group` är ett SQL-ord.
- Befintliga inlägg får ett tomt `group` och fortsätter alltså att synas för
  alla inloggade.

Testdata för grupperna (kör som användarna själva, så att hookarna stämplar
ägare och roller):

```bash
# Bo skapar den privata Löparklubben (Bo blir ägare och admin via hooks)
curl -s -X POST $B/api/collections/groups/records \
  -H "Authorization: $BO_TOKEN" -H "Content-Type: application/json" \
  -d '{"name":"Löparklubben","description":"Vi springer tillsammans.","visibility":"private"}'

# Cecilia skapar den publika Surdegsbagare
curl -s -X POST $B/api/collections/groups/records \
  -H "Authorization: $CECILIA_TOKEN" -H "Content-Type: application/json" \
  -d '{"name":"Surdegsbagare","visibility":"public"}'

# Bo (admin) lägger till Anna och David i Löparklubben
curl -s -X POST $B/api/collections/group_members/records \
  -H "Authorization: $BO_TOKEN" -H "Content-Type: application/json" \
  -d '{"group":"LOPARKLUBBENS_ID","user":"ANNAS_ID"}'
curl -s -X POST $B/api/collections/group_members/records \
  -H "Authorization: $BO_TOKEN" -H "Content-Type: application/json" \
  -d '{"group":"LOPARKLUBBENS_ID","user":"DAVIDS_ID"}'

# Bo skriver ett inlägg i gruppen, och David kommenterar
curl -s -X POST $B/api/collections/posts/records \
  -H "Authorization: $BO_TOKEN" -H "Content-Type: application/json" \
  -d '{"author":"BOS_ID","group":"LOPARKLUBBENS_ID","title":"Intervaller på torsdag",
       "body":"Vi ses vid sjön 18.00."}'
curl -s -X POST $B/api/collections/comments/records \
  -H "Authorization: $DAVID_TOKEN" -H "Content-Type: application/json" \
  -d '{"author":"DAVIDS_ID","post":"INLAGGETS_ID","body":"Jag kommer!"}'
```

# 07 – Hooks och migrationer

Collections, fält och API-regler räcker långt. Men vissa saker kan regler inte
uttrycka, eller uttrycker dåligt:

- "Användarnamnet ska sparas med små bokstäver, och `admin` får ingen ta."
- "Ingen får skriva fler än tre inlägg per minut." (spamskydd)
- "När ett konto tas bort ska gillningar och följningar försvinna och profilen
  anonymiseras – allt eller inget."
- "Rensa bort konton som aldrig verifierats, varje natt."

För sådant skriver man egen serverkod: **hooks**. I andra halvan av kapitlet
lär vi oss **migrationer** – hur databasstrukturen blir kod som kan
versionshanteras och köras på en annan dator.

## Del 1: Hooks

### Var och hur?

Hooks skrivs i JavaScript i mappen `pb_hooks/`, i filer som slutar på
**`.pb.js`**. PocketBase läser in dem när servern startar, i
filnamnsordning, och **startar om automatiskt** när du sparar en ändring
(på macOS/Linux).

```
kvittra-pb/
└── pb_hooks/
    ├── users.pb.js          ← laddas automatiskt (slutar på .pb.js)
    └── utils/
        └── user_rules.js    ← laddas INTE automatiskt; hämtas med require()
```

⚠️ **Varning:** Bara `.pb.js`-filer som ligger **direkt** i `pb_hooks/`
laddas automatiskt – inte filer i undermappar. När projektet växer brukar man
därför ha en `main.pb.js` som hämtar in resten med `require`. Hur det ser ut
visar vi i [kapitel 8](08-grupper-och-behorigheter.md#organisera-pb_hooks).

Börja varje hook-fil med raden:

```js
/// <reference path="../pb_data/types.d.ts" />
```

Då får du autokomplettering och dokumentation i VS Code för allt PocketBase
erbjuder (`$app`, `Record`, `onRecordCreate` ...).

Filen `pb_data/types.d.ts` skapas av PocketBase själv och beskriver alla
funktioner och objekt som finns i hooks. Öppna `pb_hooks` i VS Code, så får du
autokomplettering och felmarkeringar direkt i editorn. Ligger filen i en
undermapp (t.ex. `pb_hooks/collections/`) blir sökvägen
`../../pb_data/types.d.ts`.

### JavaScript i PocketBase (JSVM) – det du måste veta

PocketBase utökar du med **JavaScript** som körs av en inbyggd
JavaScript-motor (**goja**). Det är *inte* Node.js och *inte* en webbläsare:

| Fungerar | Fungerar inte |
|----------|---------------|
| ES5 och det mesta av modern syntax: `const`/`let`, arrow functions, template strings `` `${x}` ``, destructuring, spread `...`, klasser, `?.` och `??` | `async`/`await`, `Promise`, `setTimeout` – allt är **synkront** |
| `require()` av egna filer (CommonJS: `module.exports`) | npm-paket och Node-API:er (`fs`, `path`, `process`, `Buffer`) |
| `JSON.parse`, `JSON.stringify`, `Math`, `Date` | `fetch`, `window`, `document` |
| `console.log(...)` – syns i terminalen där PocketBase kör | – |

**Viktiga globala objekt** (allt finns beskrivet i `types.d.ts`):

| Global | Används till | Exempel |
|--------|--------------|---------|
| `$app` | Hela applikationen: hitta, spara, ta bort poster och collections | `$app.findRecordById("posts", id)` |
| `$apis` | Middleware och hjälpfunktioner för routes | `$apis.requireAuth()` |
| `$os` | Miljövariabler och operativsystem | `$os.getenv("PUSH_SECRET")` |
| `$security` | Slumpsträngar, hashning, tokens | `$security.randomString(8)` |
| `$http` | Synkrona HTTP-anrop till andra tjänster | `$http.send({ url: "...", method: "POST", body: "..." })` |
| `$mails` | Färdiga systemmejl (t.ex. verifiering, lösenordsåterställning) | `$mails.sendRecordPasswordReset($app, user)` |
| `$dbx` | Bygga databasvillkor för t.ex. `countRecords` | `$dbx.hashExp({ post: id })` |
| `__hooks` | Absolut sökväg till `pb_hooks`-mappen | `` require(`${__hooks}/utils/x.js`) `` |
| `Record`, `Collection`, `DateTime` | Klasser för att skapa poster, collections och datum | `new Record(collection)` |
| `BadRequestError`, `ForbiddenError`, `NotFoundError`, `UnauthorizedError`, `TooManyRequestsError` | Fel som blir HTTP-svar | `throw new BadRequestError("...")` |

**Två regler som orsakar flest buggar:**

1. **Varje hook körs isolerat.** Variabler och funktioner som deklareras
   *utanför* hook-funktionen finns inte när hooken körs. Lägg hjälpkod i en
   vanlig `.js`-fil med `module.exports` och hämta den med
   `` require(`${__hooks}/...`) `` **inuti** hooken.
2. **Glöm inte `e.next()`.** (Mer om det strax.)

```js
// ❌ FEL – RESERVED finns inte inne i hooken
const RESERVED = ["admin"];
onRecordValidate((e) => {
  if (RESERVED.indexOf(e.record.getString("username")) !== -1) { /* ReferenceError! */ }
  e.next();
}, "users");

// ✅ RÄTT – hjälpkoden hämtas inne i hooken
onRecordValidate((e) => {
  const { RESERVED_USERNAMES } = require(`${__hooks}/utils/constants.js`);
  if (RESERVED_USERNAMES.indexOf(e.record.getString("username")) !== -1) {
    throw new BadRequestError("Användarnamnet är reserverat.");
  }
  e.next();
}, "users");
```

**Automatisk omladdning:** när du sparar en fil i `pb_hooks/` startar
PocketBase om sig själv (på macOS och Linux) och skriver
`File pb_hooks/... changed, restarting...` i terminalen. På Windows måste du
starta om servern för hand. Får du ett syntaxfel syns det i terminalen vid
omstarten.

### Grundmönstret

```js
onRecordCreateRequest((e) => {
  // 1. Kod som körs FÖRE det som hooken omsluter
  console.log("Någon skapar ett inlägg:", e.record.getString("title"));

  e.next(); // 2. Låt PocketBase fortsätta (validera, spara, svara...)

  // 3. Kod som körs EFTER
}, "posts"); // ← bara för collectionen posts
```

Alla hooks har samma form: en funktion som får ett event `e`, och som **måste
anropa `e.next()`** för att kedjan ska fortsätta. Glömmer du `e.next()` händer
ingenting – posten sparas inte, och klienten får inget vettigt svar.

För att **stoppa** något kastar du ett fel:

```js
throw new BadRequestError("Du kan inte gilla ditt eget inlägg."); // 400
throw new ForbiddenError("Bara gruppens admin får göra det.");    // 403
throw new NotFoundError("Inlägget finns inte.");                  // 404
throw new TooManyRequestsError("Du skriver för snabbt.");         // 429
```

Meddelandet kommer fram till klienten i `message` (och i Dart i
`e.response['message']`).

### Två familjer av record-hooks

```
     HTTP-anrop                            Dashboard / annan hook / migration
         │                                              │
         ▼                                              │
 API-regeln kontrolleras (create/update/delete)         │
         │                                              │
         ▼                                              │
 onRecordCreateRequest  ← bara via REST-API             │
         │   (har e.auth, e.requestInfo())              │
         ▼                                              ▼
 onRecordCreate ──────────── "model hooks": körs ALLTID när en post sparas
         │
         ├─► onRecordValidate   (fältvalidering)
         ├─► onRecordCreateExecute  (själva INSERT:en)
         ▼
 onRecordAfterCreateSuccess  (efter commit – skicka mejl, notiser...)
```

| Hook | Körs | Bra till |
|------|------|----------|
| `onRecordCreateRequest`, `onRecordUpdateRequest`, `onRecordDeleteRequest` | Bara när anropet kommer via REST-API:t | Sådant som beror på *vem* som frågar: stämpla `author`, spamskydd, roller |
| `onRecordsListRequest`, `onRecordViewRequest` | Vid läsning via API | Ändra/filtrera svaret |
| `onRecordValidate` | Vid varje sparning (create + update), alla källor | **Datavalidering** som alltid ska gälla |
| `onRecordCreate`, `onRecordUpdate`, `onRecordDelete` | Vid varje sparning/borttagning, alla källor | Sätta härledda värden innan sparning |
| `onRecordAfterCreateSuccess` m.fl. | När sparningen lyckats | Sidoeffekter: mejl, push, notiser, logg |

Tumregel: **regler om datan** → model hooks (`onRecordValidate`). **Regler om
vem som frågar** → request hooks (eller API-regler).

⚠️ **Varning:** Lägg märke till ordningen överst i bilden: **API-regeln
kontrolleras innan** request-hooken körs, och den kontrolleras mot det
klienten *skickade*. Säger regeln nej körs hooken aldrig. Det betyder också att
en hook som ändrar `e.record` inte kan "hjälpa" ett anrop förbi en regel som
`@request.body.author = @request.auth.id`.

### Eventet `e`

| Egenskap | Finns i | Innehåll |
|----------|---------|----------|
| `e.app` | alla | Applikationen (samma som `$app`, men transaktionsmedveten – använd den) |
| `e.record` | record-hooks | Posten som skapas/ändras |
| `e.collection` | record-hooks | Collectionen |
| `e.auth` | request-hooks, routes | Den inloggade (`null` om utloggad) |
| `e.requestInfo()` | request-hooks, routes | `{ body, query, headers, auth, method }` |
| `e.hasSuperuserAuth()` | request-hooks, routes | `true` om en superuser gör anropet |

Läsa och skriva fält på en post:

```js
e.record.get("title")             // valfritt värde
e.record.getString("author")      // som sträng (t.ex. ett relations-id)
e.record.getInt("likes_count")    // som heltal
e.record.getBool("emailVisibility") // som bool
e.record.getDateTime("created")   // som DateTime (har .unix(), .addDate(), ...)
e.record.set("title", "Ändrad av servern")
e.record.original()               // posten som den ser ut i databasen (vid update)
```

### Exempel 1: Stämpla författaren på servern

I kapitel 4 krävde create-regeln att `@request.body.author = @request.auth.id`.
Ett alternativ är att servern helt enkelt *sätter* rätt författare, oavsett vad
klienten skickar:

```js
/// <reference path="../pb_data/types.d.ts" />

onRecordCreateRequest((e) => {
  // Superusers (Dashboard) får välja fritt
  if (!e.hasSuperuserAuth() && e.auth) {
    e.record.set("author", e.auth.id);
  }
  e.next();
}, "posts", "comments"); // samma hook för två collections
```

Vill du att appen ska kunna *låta bli* att skicka `author` måste du också
förenkla create-regeln till `@request.auth.id != ""` – annars stoppar regeln
anropet innan hooken hinner köras (se varningen ovan). Med båda på plats får
Anna sitt eget id som författare även om hon skickar Bos.

Det är ett vanligt mönster i riktiga projekt: fält som klienten inte ska kunna
välja (vem som skrev, vilken roll man får, status) stämplas på servern.

### Exempel 2: Användarnamn – normalisera och validera

Det här är kapitlets viktigaste exempel. Kraven:

1. `"  Anna_A "` ska sparas som `"anna_a"` (inga mellanslag, små bokstäver), så
   att `Anna` och `anna` inte kan bli två olika konton.
2. Vissa namn är reserverade: `admin`, `kvittra`, `support`, `api`, `root`.

Kraven gäller **datan** – oavsett om användaren skapas i appen, i Dashboard
eller i en migration. Därför en model hook. Vi delar upp koden i en modul med
logiken och en `.pb.js`-fil som registrerar hooken.

⚠️ **Varning:** Varje hook körs i en **egen isolerad miljö**. Variabler och
funktioner som du deklarerar utanför hook-funktionen syns **inte** inuti den.
Därför lägger man återanvändbar kod i en modul och hämtar den med
`require(`${__hooks}/...`)` *inuti* hooken. `__hooks` är sökvägen till
`pb_hooks`-mappen.

`pb_hooks/utils/constants.js`:

```js
module.exports = {
  // Användarnamn som ingen får registrera
  RESERVED_USERNAMES: ["admin", "kvittra", "support", "api", "root"],
  // Spamskydd: högst så här många inlägg per minut och användare
  MAX_POSTS_PER_MINUTE: 3,
};
```

`pb_hooks/utils/user_rules.js`:

```js
module.exports = {
  // Gör om användarnamnet till gemener och tar bort mellanslag runt det.
  normalizeUsername: (record) => {
    const raw = record.getString("username");
    record.set("username", raw.trim().toLowerCase());
  },

  // Kastar BadRequestError om användarnamnet är reserverat.
  validateUsername: (record) => {
    const { RESERVED_USERNAMES } = require(`${__hooks}/utils/constants.js`);
    const username = record.getString("username");
    if (RESERVED_USERNAMES.indexOf(username) !== -1) {
      throw new BadRequestError(`Användarnamnet "${username}" är reserverat.`);
    }
  },
};
```

`pb_hooks/users.pb.js`:

```js
/// <reference path="../pb_data/types.d.ts" />

// Körs vid både create och update, oavsett om ändringen kommer från
// appen, Dashboard, en annan hook eller en migration.
onRecordValidate((e) => {
  const rules = require(`${__hooks}/utils/user_rules.js`);

  // 1. Före PocketBases validering: normalisera ("  Anna_A " → "anna_a")
  rules.normalizeUsername(e.record);

  // 2. PocketBases egen validering (required, pattern, unikt index, ...)
  e.next();

  // 3. Våra egna regler
  rules.validateUsername(e.record);
}, "users");
```

Några saker att lägga märke till:

1. **Ordningen runt `e.next()`.** I `onRecordValidate` är det `e.next()` som
   kör PocketBases fältvalidering. Normaliseringen ligger *före*, så att
   pattern `^[a-z0-9_]+$` och det unika indexet kontrollerar det normaliserade
   värdet – `"  Fia_F "` godkänns och sparas som `fia_f`, och `BO` krockar med
   `bo`. Våra egna kontroller ligger *efter*, så att PocketBases vanliga
   felmeddelanden ("Cannot be blank") kommer först.
2. **`require` inuti hooken** – inte överst i filen.
3. **Felet syns för klienten**: `{"message":"Användarnamnet \"admin\" är reserverat.","status":400}`.

Testa:

```bash
# Normaliseras och godkänns → username "fia_f"
curl -s -X POST http://127.0.0.1:8090/api/collections/users/records \
  -H "Content-Type: application/json" \
  -d '{"email":"fia@example.com","password":"hemligt123","passwordConfirm":"hemligt123",
       "username":"  Fia_F ","name":"Fia"}'

# Reserverat → 400
curl -s -X POST ... -d '{..., "username":"Admin"}'
# {"data":{},"message":"Användarnamnet \"admin\" är reserverat.","status":400}

# Krockar med "bo" efter normalisering → 400 validation_not_unique
curl -s -X POST ... -d '{..., "username":"BO"}'
```

💡 **Tips:** Använd `console.log(...)` för felsökning. Utskriften syns i
terminalen där PocketBase kör.

### Exempel 3: Man får inte gilla sitt eget inlägg

Ännu en regel om datan, som rör en *annan* post (inlägget som gillas):

`pb_hooks/likes.pb.js`:

```js
/// <reference path="../pb_data/types.d.ts" />

onRecordValidate((e) => {
  e.next();
  const post = e.app.findRecordById("posts", e.record.getString("post"));
  if (post.getString("author") === e.record.getString("user")) {
    throw new BadRequestError("Du kan inte gilla ditt eget inlägg.");
  }
}, "likes");
```

Vi valde att *förbjuda* det (en designfråga – Facebook tillåter det). I
kapitel 4 såg du att samma sak går att skriva som en create-regel:
`@request.body.post.author != @request.auth.id`. Jämför:

| | API-regel | Hook (`onRecordValidate`) |
|---|---|---|
| Felmeddelande | Generiskt `400 Failed to create record.` | Begripligt: "Du kan inte gilla ditt eget inlägg." |
| Gäller Dashboard, migrationer, andra hooks | Nej (regler gäller bara API:t) | Ja |
| Synlig i Dashboard bland reglerna | Ja | Nej – man måste läsa koden |

#### Hitta en post – vilka funktioner finns?

| Funktion | Returnerar | Om inget hittas |
|----------|------------|-----------------|
| `app.findRecordById(coll, id)` | En post | **Kastar fel** |
| `app.findFirstRecordByFilter(coll, filter, params)` | En post | **Kastar fel** ("no rows in result set") |
| `app.findRecordsByFilter(coll, filter, sort, limit, offset, params)` | Lista | Tom lista |
| `app.findAllRecords(coll)` | Lista (alla!) | Tom lista |
| `app.countRecords(coll, ...villkor)` | Antal | `0` |

⚠️ **Varning:** `findFirstRecordByFilter` och `findRecordById` kastar ett fel
om posten inte finns. Vill du bara veta *om* något finns, använd
`findRecordsByFilter` med `limit` 1 och kolla `length`, eller lägg anropet i
`try/catch`.

### Exempel 4: Spamskydd (rate limit)

"Högst tre inlägg per minut" beror på **vem som frågar** och ska inte gälla
superusers – alltså en request hook. Kravet rör *andra* poster (de senaste
inläggen), så det går inte att skriva som en API-regel.

`pb_hooks/posts.pb.js`:

```js
/// <reference path="../pb_data/types.d.ts" />

onRecordCreateRequest((e) => {
  if (!e.hasSuperuserAuth() && e.auth) {
    const { MAX_POSTS_PER_MINUTE } = require(`${__hooks}/utils/constants.js`);
    const oneMinuteAgo = new DateTime().add(-60 * 1000 * 1000 * 1000); // nanosekunder

    const recent = e.app.countRecords(
      "posts",
      $dbx.hashExp({ author: e.auth.id }),
      $dbx.exp("created > {:since}", { since: oneMinuteAgo.string() }),
    );
    if (recent >= MAX_POSTS_PER_MINUTE) {
      throw new TooManyRequestsError("Du skriver för snabbt. Vänta en minut.");
    }
  }
  e.next();
}, "posts");
```

1. **`{:since}`-parametrar** fungerar som `pb.filter` i Dart och som `?` i
   SQL. Bygg aldrig villkor med strängsammanfogning.
2. `$dbx.hashExp({ author: ... })` blir `author = '...'` och
   `$dbx.exp(...)` är ett fritt SQL-villkor. `countRecords` tar hur många
   villkor som helst (de kombineras med `AND`).
3. `DateTime.add` tar en tid i **nanosekunder** (Go-stil), därav
   `60 * 1000 * 1000 * 1000` för 60 sekunder. `.string()` ger formatet
   `2026-10-15 08:19:20.626Z` som går att jämföra med `created`.
4. Hooken ser **alla** inlägg, även dem som list-regeln skulle dölja. Hooks går
   inte genom API-reglerna.

```bash
# Fjärde inlägget inom en minut
# {"data":{},"message":"Du skriver för snabbt. Vänta en minut.","status":429}
```

### Exempel 5: Egen endpoint (route)

Ibland vill appen ha något som inte är vanlig CRUD, t.ex. statistik. Med
`routerAdd` skapar du en egen endpoint:

`pb_hooks/api.pb.js`:

```js
/// <reference path="../pb_data/types.d.ts" />

routerAdd("GET", "/api/kvittra/stats", (e) => {
  const count = (name) => e.app.countRecords(name);

  // De tre mest gillade inläggen
  const top = e.app.findAllRecords("posts")
    .map((p) => ({
      title: p.getString("title"),
      likes: e.app.countRecords("likes", $dbx.hashExp({ post: p.id })),
    }))
    .sort((a, b) => b.likes - a.likes)
    .slice(0, 3);

  return e.json(200, {
    users: count("users"),
    posts: count("posts"),
    comments: count("comments"),
    likes: count("likes"),
    top: top,
  });
}, $apis.requireAuth());
```

```bash
curl -s http://127.0.0.1:8090/api/kvittra/stats -H "Authorization: $TOKEN"
# {"comments":5,"likes":6,"posts":6,
#  "top":[{"likes":3,"title":"Bästa kaffet i stan?"},{"likes":2,"title":"Surdegsbröd"},
#         {"likes":1,"title":"Mitt första inlägg"}],"users":4}
```

- `$apis.requireAuth()` är ett *middleware* som ger `401` om ingen är
  inloggad. `$apis.requireAuth("users")` kräver en användare från just `users`,
  och `$apis.requireSuperuserAuth()` kräver superuser (andra får `403`).
- Egna routes går **inte** genom API-reglerna. Du ansvarar själv för
  behörigheten. Här ser alla inloggade antal och titlar – det är ok så länge
  alla inlägg är publika. (I kapitel 8 blir det inte längre sant!)
- Lägg egna routes under ett eget prefix, t.ex. `/api/kvittra/`, så att de
  inte krockar med PocketBases egna.
- `findAllRecords` + en `countRecords` per inlägg är okej för en kurs, men
  skalar dåligt. Med tusentals inlägg är en view-collection bättre.

💡 **Tips:** Statistik som den här kan ofta göras enklare med en
**view-collection** (kapitel 2) – då får du API-regler, filter och sortering
på köpet. Det gör vi i övning 7.

### Exempel 6: Transaktion – ta bort sitt konto

`users` har Delete-regeln `null`. Ett konto kan inte heller tas bort rakt av,
eftersom `posts.author` är required utan cascade (kapitel 3). I stället
erbjuder vi en route som:

1. tar bort användarens gillningar och följningar (åt båda hållen),
2. anonymiserar profilen (inlägg och kommentarer finns kvar, men under
   "Borttagen användare"),
3. byter lösenord så att ingen kan logga in.

Det måste ske **allt eller inget**. Går steg 2 fel får gillningarna inte redan
vara borta. Det är exakt det du lärde dig om **atomicitet** i
[ACID-kapitlet](../01-databaser/03-acid-och-transaktioner.md).

```js
/// <reference path="../pb_data/types.d.ts" />

routerAdd("POST", "/api/kvittra/delete-account", (e) => {
  const userId = e.auth.id;

  e.app.runInTransaction((txApp) => {
    // 1. Ta bort gillningar och följningar
    const likes = txApp.findRecordsByFilter("likes", "user = {:u}", "", 0, 0, { u: userId });
    const follows = txApp.findRecordsByFilter(
      "follows", "follower = {:u} || following = {:u}", "", 0, 0, { u: userId },
    );
    for (const r of likes.concat(follows)) {
      txApp.delete(r);
    }

    // 2. Anonymisera kontot
    const user = txApp.findRecordById("users", userId);
    const anon = "borttagen_" + $security.randomStringWithAlphabet(8, "abcdefghijklmnopqrstuvwxyz0123456789");
    user.set("username", anon);
    user.set("name", "Borttagen användare");
    user.set("email", anon + "@example.invalid");
    user.set("bio", "");
    user.set("website", "");
    user.set("avatar", null);

    // 3. Nytt slumpat lösenord – ingen kan logga in, och gamla tokens slutar gälla
    user.setPassword($security.randomString(30));
    txApp.save(user); // kör onRecordValidate för users (kapitlets exempel 2)
  });

  return e.json(200, { deleted: true });
}, $apis.requireAuth("users"));
```

```
runInTransaction
  ├─ delete like 1     ✓
  ├─ delete follow 1   ✓
  ├─ save user         ✗ (t.ex. valideringsfel) → fel kastas
  └─ ROLLBACK – gillningen och följningen kommer tillbaka
```

⚠️ **Varning:** Inuti `runInTransaction` ska du använda **`txApp`**, inte
`$app` eller `e.app`. Annars hamnar anropet utanför transaktionen – och i
värsta fall väntar det på att transaktionen ska bli klar, som i sin tur väntar
på anropet (deadlock).

Efter anropet ger Annas gamla token `401` och hennes inlägg visas med namnet
"Borttagen användare". Lägg också märke till att `onRecordValidate` för `users`
kördes även här, eftersom `txApp.save` sparar en post – fördelen med att lägga
validering i en model hook.

### Exempel 7: Schemalagt jobb (cron)

Varje natt kl. 03:00: ta bort konton som aldrig verifierat sin e-post och är
äldre än 30 dagar.

`pb_hooks/utils/cleanup.js`:

```js
function cleanupUnverified(app) {
  const limit = new DateTime().addDate(0, 0, -30); // 30 dagar sedan
  const old = app.findRecordsByFilter(
    "users", "verified = false && created < {:limit}", "", 0, 0, { limit: limit },
  );

  let deleted = 0;
  for (const u of old) {
    try {
      app.delete(u);
      deleted++;
    } catch (err) {
      // T.ex. om kontot hunnit skriva inlägg (posts.author har ingen cascade delete)
      console.log(`Kunde inte ta bort ${u.getString("username")}:`, err);
    }
  }
  console.log(`Rensade ${deleted} av ${old.length} overifierade konton`);
  return deleted;
}

module.exports = { cleanupUnverified };
```

I `pb_hooks/api.pb.js` (eller en egen fil):

```js
cronAdd("rensa_overgivna_konton", "0 3 * * *", () => {
  require(`${__hooks}/utils/cleanup.js`).cleanupUnverified($app);
});

// För att kunna testa utan att vänta till kl. 03 – bara för superusers
routerAdd("POST", "/api/kvittra/test-cleanup", (e) => {
  const deleted = require(`${__hooks}/utils/cleanup.js`).cleanupUnverified(e.app);
  return e.json(200, { deleted: deleted });
}, $apis.requireSuperuserAuth());
```

Här används **inte** en transaktion runt allt: ett konto som inte går att ta
bort ska inte stoppa de andra. `try/catch` per post gör att jobbet fortsätter,
och felet loggas, t.ex.
`the record cannot be deleted because it is part of a required reference ...`.

Cron-uttrycket har fem delar:

```
┌───────── minut (0–59)
│ ┌─────── timme (0–23)
│ │ ┌───── dag i månaden (1–31)
│ │ │ ┌─── månad (1–12)
│ │ │ │ ┌─ veckodag (0–6, söndag = 0)
│ │ │ │ │
0 3 * * *     varje dag kl. 03:00 (UTC)
*/15 * * * *  var 15:e minut
0 7 * * 1     måndagar kl. 07:00
0 12 1 * *    den 1:a varje månad kl. 12:00
```

I cron-jobb finns inget `e` – använd den globala `$app`. Tiderna är i UTC.

### Exempel 8: Efter sparning – sidoeffekter

```js
onRecordAfterCreateSuccess((e) => {
  const post = e.app.findRecordById("posts", e.record.getString("post"));
  console.log(`Ny kommentar på "${post.getString("title")}": ${e.record.getString("body")}`);
  e.next();
}, "comments");
```

Här passar det att skicka mejl (`$app.newMailClient()`), push-notiser eller
skapa notiser i appen (kapitel 8). Posten är redan sparad, så ett fel här
ångrar inte kommentaren.

### Hooks eller API-regler?

| Fråga | Lösning |
|-------|---------|
| Vem får läsa/ändra? | **API-regler** – snabbast, syns i Dashboard |
| Får klienten sätta det här fältet? | **API-regel** (`:isset`, `:changed`) eller stämpla i **request hook** |
| Krav som rör *andra* poster (spamskydd, inte gilla eget)? | **Hook** |
| Normalisera/validera data oavsett källa? | **Model hook** (`onRecordValidate`) |
| Flera ändringar som måste lyckas tillsammans? | **Route + `runInTransaction`** |
| Något som ska hända regelbundet? | **`cronAdd`** |
| Mejl/notis när något hänt? | **`onRecord...AfterCreateSuccess`** |

## Del 2: Migrationer

### Problemet

Du har byggt alla collections i Dashboard på din dator. Nu ska:

- din kurskamrat köra samma backend,
- servern i produktion få samma struktur,
- du lägga till fältet `posts.pinned` utan att tappa någon data.

Att klicka runt i Dashboard på varje dator är långsamt och felbenäget. Och du
kan inte skicka `pb_data` – den innehåller ju din testdata och dina lösenord.

**Migrationer** löser det: varje ändring av strukturen sparas som en
JavaScript-fil i `pb_migrations/`. Filerna körs i ordning, och PocketBase
håller reda på vilka som redan körts (i tabellen `_migrations`).

```
pb_migrations/
├── 1791530000_updated_users.js      ← kördes 2026-10-01
├── 1791530100_created_posts.js      ← kördes 2026-10-01
├── 1791530200_created_likes.js      ← kördes 2026-10-02
└── 1791540000_updated_posts.js      ← NY – körs vid nästa start
```

Siffran i början är en Unix-tidsstämpel. Den styr ordningen.

### Automigrate – migrationer skapas av sig själva

När du kör den färdiga `pocketbase`-filen är **automigrate** påslaget. Varje
gång du ändrar en collection i Dashboard (eller via API:t som superuser)
skrivs en migrationsfil automatiskt:

```
Du klickar "Save changes" på posts i Dashboard
          │
          ▼
pb_migrations/1791531151_updated_posts.js skapas
```

En automatiskt skapad migration ser ut ungefär så här:

```js
/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_1125843985")

  // add field
  collection.fields.addAt(7, new Field({
    "hidden": false,
    "id": "bool2063623452",
    "name": "pinned",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "bool"
  }))

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_1125843985")

  // remove field
  collection.fields.removeById("bool2063623452")

  return app.save(collection)
})
```

Varje fil har två funktioner:

| Funktion | Körs vid | Gör |
|----------|----------|-----|
| Första (`up`) | Start av servern / `migrate up` | Gör ändringen |
| Andra (`down`) | `migrate down` | Ångrar ändringen |

### Arbetsflöde med git

```
  Din dator                         Git                   Kurskamrat / server
  ─────────                         ───                   ───────────────────
  Ändra i Dashboard
       │
       ▼
  pb_migrations/xxx.js skapas
       │  git add pb_migrations pb_hooks
       │  git commit -m "Lägg till posts.pinned"
       └──────────────────────────► push ───────────► git pull
                                                           │
                                                           ▼
                                                   ./pocketbase serve
                                                   → kör nya migrationer
                                                   → samma struktur!
```

1. Ändra strukturen i Dashboard (lokalt).
2. Kontrollera att en ny fil dykt upp i `pb_migrations/`.
3. Commita `pb_migrations/` och `pb_hooks/` tillsammans med appkoden.
4. På den andra datorn/servern: hämta koden och starta PocketBase. Nya
   migrationer körs automatiskt vid start.

⚠️ **Varning:**

- **Ändra aldrig** en migration som redan har körts någon annanstans. Den körs
  inte igen. Gör i stället en ny migration.
- **Radera inte** migrationsfiler i onödan. Om du måste (t.ex. för att städa
  bort experiment lokalt), kör `./pocketbase migrate history-sync` efteråt så
  att `_migrations`-tabellen stämmer med filerna.
- Ändra helst **inte** strukturen direkt i Dashboard på produktionsservern.
  Då skapas migrationer där som inte finns i git.
- Migrationer körs bara **vid start**. Lägger du till en migrationsfil medan
  servern kör händer ingenting förrän du startar om.

### Kommandon

| Kommando | Gör |
|----------|-----|
| `./pocketbase migrate up` | Kör alla migrationer som inte körts (görs även automatiskt vid `serve`) |
| `./pocketbase migrate down 1` | Ångrar den senaste migrationen (frågar `y/N` först) |
| `./pocketbase migrate create "namn"` | Skapar en tom migrationsfil som du fyller i själv |
| `./pocketbase migrate collections` | Skapar **en** migration med en ögonblicksbild av alla collections |
| `./pocketbase migrate history-sync` | Tar bort poster i `_migrations` som saknar fil |

`migrate collections` är bra när du har klickat ihop allt utan att bry dig om
migrationerna och vill börja om med en ren fil: ta bort de gamla
migrationsfilerna, kör `migrate collections` och sedan `migrate history-sync`.

### Skriva en migration för hand

Ibland vill man skriva migrationen själv, till exempel för att skapa
**testdata** (seed) eller göra om data. Skapa en tom fil:

```bash
./pocketbase migrate create "seed_demo"
# skapar pb_migrations/1791600000_seed_demo.js
```

Fyll i den:

```js
/// <reference path="../pb_data/types.d.ts" />

// DEMODATA – kör bara lokalt (se varningen nedan)
migrate((app) => {
  const users = app.findCollectionByNameOrId("users");
  const posts = app.findCollectionByNameOrId("posts");

  const demo = new Record(users);
  demo.set("email", "demo@example.com");
  demo.set("username", "demo");
  demo.set("name", "Demo Demosson");
  demo.set("verified", true);
  demo.setPassword("hemligt123");
  app.save(demo);

  const post = new Record(posts);
  post.load({   // sätter flera fält på en gång
    author: demo.id,
    title: "Välkommen till Kvittra!",
    body: "Det här är ett demoinlägg.",
  });
  app.save(post);
}, (app) => {
  try {
    const demo = app.findAuthRecordByEmail("users", "demo@example.com");
    for (const p of app.findRecordsByFilter("posts", "author = {:a}", "", 0, 0, { a: demo.id })) {
      app.delete(p);
    }
    app.delete(demo);
  } catch (_) {
    // fanns inte – ignorera
  }
});
```

Lägg märke till `down`-funktionen: inläggen måste bort *före* användaren,
eftersom `posts.author` saknar cascade delete.

Du kan också skapa hela collections i kod:

```js
migrate((app) => {
  const collection = new Collection({
    type: "base",
    name: "tags",
    listRule: '@request.auth.id != ""',
    viewRule: '@request.auth.id != ""',
    createRule: null,
    updateRule: null,
    deleteRule: null,
    fields: [
      { type: "text", name: "name", required: true, max: 50 },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
      { type: "autodate", name: "updated", onCreate: true, onUpdate: true },
    ],
    indexes: ["CREATE UNIQUE INDEX idx_tags_name ON tags (name)"],
  });
  app.save(collection);
}, (app) => {
  app.delete(app.findCollectionByNameOrId("tags"));
});
```

I [lösningarna](losningar.md#hela-schemat-som-migration) finns en migration
som skapar **hela** Kvittras schema med regler och index.

💡 **Tips:** Migrationer körs i en **transaktion**. Om något går fel mitt i
rullas allt tillbaka, och databasen blir inte halvfärdig.

### Typiskt misstag: seed-data i produktion

Testdata ("Anna", "Bo", lösenordet `hemligt123`) ska inte hamna på
produktionsservern – då finns det plötsligt konton med ett lösenord som står i
ditt git-repo. Lägg testanvändare i en separat migration som du bara kör
lokalt, eller skapa dem med ett skript mot API:t. Data som alla installationer
behöver (t.ex. en lista med standardtaggar) kan däremot ligga i en vanlig
migration.

## Sammanfattning

- Hooks ligger i `pb_hooks/*.pb.js` och laddas om automatiskt.
- Varje hook måste anropa `e.next()`. Kasta `BadRequestError` m.fl. för att
  stoppa.
- Request hooks (`onRecordCreateRequest`) gäller API-anrop och körs **efter**
  att API-regeln godkänt anropet. Model hooks (`onRecordValidate`,
  `onRecordCreate`) gäller alla sparningar.
- Kod utanför hook-funktionen syns inte inuti – använd `require(`${__hooks}/...`)`.
- `routerAdd` för egna endpoints, `cronAdd` för schemalagda jobb,
  `runInTransaction` för allt-eller-inget (använd `txApp`).
- Migrationer i `pb_migrations/` beskriver strukturen som kod. Automigrate
  skapar dem när du ändrar i Dashboard. Commita dem till git, ändra aldrig en
  redan körd migration.

Nästa kapitel: [Grupper, roller och behörigheter](08-grupper-och-behorigheter.md).
Vill du öva först? Övning 1–8 i [övningarna](ovningar.md) bygger på kapitel 1–7.

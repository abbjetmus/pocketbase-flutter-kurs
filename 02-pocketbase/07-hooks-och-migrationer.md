# 07 – Hooks och migrationer

Collections, fält och API-regler räcker långt. Men vissa saker kan regler inte
uttrycka:

- "En bokning får inte överlappa en annan bokning av samma resurs."
- "En bokning får vara högst `max_hours` timmar lång."
- "Boka samma tid tio veckor i rad – allt eller inget."
- "Rensa bort gamla bokningar varje natt."

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
foreningen-pb/
└── pb_hooks/
    ├── bookings.pb.js      ← laddas automatiskt (slutar på .pb.js)
    └── booking_utils.js    ← laddas INTE automatiskt; hämtas med require()
```

⚠️ **Varning:** Bara `.pb.js`-filer som ligger **direkt** i `pb_hooks/`
laddas automatiskt – inte filer i undermappar. När projektet växer brukar man
därför ha en `main.pb.js` som hämtar in resten med `require`. Hur det ser ut
visar vi i [kapitel 8](08-flera-foreningar-och-behorigheter.md#organisera-pb_hooks).

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

PocketBase är skrivet i Go, men du utökar det med **JavaScript** som körs av
en inbyggd JavaScript-motor (**goja**). Det är *inte* Node.js och *inte* en
webbläsare:

| Fungerar | Fungerar inte |
|----------|---------------|
| ES5 och det mesta av modern syntax: `const`/`let`, arrow functions, template strings `` `${x}` ``, destructuring, spread `...`, klasser, `?.` och `??` | `async`/`await`, `Promise`, `setTimeout` – allt är **synkront** |
| `require()` av egna filer (CommonJS: `module.exports`) | npm-paket och Node-API:er (`fs`, `path`, `process`, `Buffer`) |
| `JSON.parse`, `JSON.stringify`, `Math`, `Date` | `fetch`, `window`, `document` |
| `console.log(...)` – syns i terminalen och under **Logs** i Dashboard | – |

**Viktiga globala objekt** (allt finns beskrivet i `types.d.ts`):

| Global | Används till | Exempel |
|--------|--------------|---------|
| `$app` | Hela applikationen: hitta, spara, ta bort poster och collections | `$app.findRecordById("resources", id)` |
| `$apis` | Middleware och hjälpfunktioner för routes | `$apis.requireAuth()` |
| `$os` | Miljövariabler och operativsystem | `$os.getenv("PUSH_SECRET")` |
| `$security` | Slumpsträngar, hashning, tokens | `$security.randomString(8)` |
| `$http` | Synkrona HTTP-anrop till andra tjänster | `$http.send({ url: "...", method: "POST", body: "..." })` |
| `$mails` | Färdiga systemmejl (t.ex. verifiering, lösenordsåterställning) | `$mails.sendRecordPasswordReset($app, user)` |
| `$dbx` | Bygga databasvillkor för t.ex. `countRecords` | `$dbx.hashExp({ resource: id })` |
| `__hooks` | Absolut sökväg till `pb_hooks`-mappen | `` require(`${__hooks}/utils/x.js`) `` |
| `Record`, `Collection`, `DateTime` | Klasser för att skapa poster, collections och datum | `new Record(collection)` |
| `BadRequestError`, `ForbiddenError`, `NotFoundError`, `UnauthorizedError` | Fel som blir HTTP-svar | `throw new BadRequestError("...")` |

**Två regler som orsakar flest buggar:**

1. **Varje hook körs isolerat.** Variabler och funktioner som deklareras
   *utanför* hook-funktionen finns inte när hooken körs. Lägg hjälpkod i en
   vanlig `.js`-fil med `module.exports` och hämta den med
   `` require(`${__hooks}/...`) `` **inuti** hooken.
2. **Glöm inte `e.next()`.** (Mer om det strax.)

```js
// ❌ FEL – HOURS finns inte inne i hooken
const HOURS = 3;
onRecordValidate((e) => {
  if (e.record.getInt("max_hours") > HOURS) { /* ReferenceError! */ }
  e.next();
}, "resources");

// ✅ RÄTT – hjälpkoden hämtas inne i hooken
onRecordValidate((e) => {
  const { MAX_HOURS } = require(`${__hooks}/utils/constants.js`);
  if (e.record.getInt("max_hours") > MAX_HOURS) {
    throw new BadRequestError(`Högst ${MAX_HOURS} timmar.`);
  }
  e.next();
}, "resources");
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
  console.log("Någon försöker skapa en bokning:", e.record.get("start"));

  e.next(); // 2. Låt PocketBase fortsätta (validera, spara, svara...)

  // 3. Kod som körs EFTER
}, "bookings"); // ← bara för collectionen bookings
```

Alla hooks har samma form: en funktion som får ett event `e`, och som **måste
anropa `e.next()`** för att kedjan ska fortsätta. Glömmer du `e.next()` händer
ingenting – posten sparas inte, och klienten får inget vettigt svar.

För att **stoppa** något kastar du ett fel:

```js
throw new BadRequestError("Tiden är redan bokad.");   // 400
throw new ForbiddenError("Bara styrelsen får göra det."); // 403
throw new NotFoundError("Resursen finns inte.");        // 404
```

Meddelandet kommer fram till klienten i `message` (och i Dart i
`e.response['message']`).

### Två familjer av record-hooks

```
     HTTP-anrop                            Dashboard / annan hook / migration
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
| `onRecordCreateRequest`, `onRecordUpdateRequest`, `onRecordDeleteRequest` | Bara när anropet kommer via REST-API:t | Sådant som beror på *vem* som frågar: stämpla `user`, kontrollera roller |
| `onRecordsListRequest`, `onRecordViewRequest` | Vid läsning via API | Ändra/filtrera svaret |
| `onRecordValidate` | Vid varje sparning (create + update), alla källor | **Datavalidering** som alltid ska gälla |
| `onRecordCreate`, `onRecordUpdate`, `onRecordDelete` | Vid varje sparning/borttagning, alla källor | Sätta härledda värden innan sparning |
| `onRecordAfterCreateSuccess` m.fl. | När sparningen lyckats | Sidoeffekter: mejl, push, logg |

Tumregel: **regler om datan** → model hooks (`onRecordValidate`). **Regler om
vem som frågar** → request hooks (eller API-regler).

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
e.record.get("note")              // valfritt värde
e.record.getString("resource")    // som sträng
e.record.getInt("max_hours")      // som heltal
e.record.getBool("active")        // som bool
e.record.getDateTime("start")     // som DateTime (har .unix(), .addDate(), ...)
e.record.set("note", "Ändrad av server")
```

### Exempel 1: Stämpla användaren på servern

I kapitel 4 krävde create-regeln att `@request.body.user = @request.auth.id`.
Ett alternativ är att servern helt enkelt *sätter* rätt användare, oavsett vad
klienten skickar:

```js
/// <reference path="../pb_data/types.d.ts" />

onRecordCreateRequest((e) => {
  // Superusers (Dashboard) får välja fritt
  if (!e.hasSuperuserAuth() && e.auth) {
    e.record.set("user", e.auth.id);
  }
  e.next();
}, "bookings");
```

Det är ett vanligt mönster i riktiga projekt: fält som klienten inte ska kunna
välja (vem som bokade, vilken förening, status) stämplas på servern.

### Exempel 2: Ingen dubbelbokning och max_hours

Det här är kapitlets viktigaste exempel. Vi delar upp det i två filer: själva
logiken i en modul och registreringen i en `.pb.js`-fil.

⚠️ **Varning:** Varje hook körs i en **egen isolerad miljö**. Variabler och
funktioner som du deklarerar utanför hook-funktionen syns **inte** inuti den.
Därför lägger man återanvändbar kod i en modul och hämtar den med
`require(`${__hooks}/...`)` *inuti* hooken. `__hooks` är sökvägen till
`pb_hooks`-mappen.

`pb_hooks/booking_utils.js`:

```js
module.exports = {
  validateBooking: (app, record) => {
    const start = record.getDateTime("start");
    const end = record.getDateTime("end");

    // 1. Slut efter start
    if (end.unix() <= start.unix()) {
      throw new BadRequestError("Sluttiden måste vara efter starttiden.");
    }

    // 2. Resursen måste vara aktiv
    const resource = app.findRecordById("resources", record.getString("resource"));
    if (!resource.getBool("active")) {
      throw new BadRequestError("Resursen går inte att boka just nu.");
    }

    // 3. Max antal timmar
    const hours = (end.unix() - start.unix()) / 3600;
    const maxHours = resource.getInt("max_hours");
    if (maxHours > 0 && hours > maxHours) {
      throw new BadRequestError(`Max ${maxHours} timmar per bokning.`);
    }

    // 4. Ingen överlappning med andra bokningar av samma resurs
    const overlapping = app.findRecordsByFilter(
      "bookings",
      "resource = {:resource} && start < {:end} && end > {:start} && id != {:id}",
      "",   // sortering
      1,    // limit – vi behöver bara veta om det finns minst en
      0,    // offset
      {
        resource: record.getString("resource"),
        start: start,
        end: end,
        id: record.id,
      },
    );
    if (overlapping.length > 0) {
      throw new BadRequestError("Tiden är redan bokad.");
    }
  },
};
```

`pb_hooks/bookings.pb.js`:

```js
/// <reference path="../pb_data/types.d.ts" />

// Körs vid både create och update, oavsett om ändringen kommer från
// appen, Dashboard, en annan hook eller en migration.
onRecordValidate((e) => {
  // Kör först PocketBases egen validering (required, relationer finns, ...)
  e.next();
  // ...och sedan våra egna regler.
  require(`${__hooks}/booking_utils.js`).validateBooking(e.app, e.record);
}, "bookings");
```

Några saker att lägga märke till:

1. **`{:resource}`-parametrar** fungerar som `pb.filter` i Dart och som `?` i
   SQL. Bygg aldrig filtret med strängsammanfogning.
2. **`id != {:id}`** gör att en bokning inte krockar med *sig själv* när den
   uppdateras.
3. **Överlappsvillkoret** `start < ny_slut && end > ny_start` är samma som i
   kapitel 5. En bokning 10–12 krockar inte med en som börjar 12.
4. **`e.next()` först** i `onRecordValidate`: då kommer PocketBases vanliga
   felmeddelanden ("Cannot be blank") först, och vår kod kan lita på att
   `start`, `end` och `resource` finns.
5. Hooken ser **alla** bokningar, även dem Anna inte får läsa enligt
   list-regeln. Hooks går inte genom API-reglerna. Det är därför kontrollen
   måste ligga här och inte i appen.

Testa:

```bash
# Första bokningen – OK
curl -s -X POST http://127.0.0.1:8090/api/collections/bookings/records \
  -H "Authorization: $TOKEN" -H "Content-Type: application/json" \
  -d '{"resource":"<tvättstugans id>","user":"<annas id>",
       "start":"2026-10-12 08:00:00Z","end":"2026-10-12 10:00:00Z"}'

# Överlappar – nekas
curl -s -X POST ... -d '{..., "start":"2026-10-12 09:00:00Z","end":"2026-10-12 11:00:00Z"}'
# {"data":{},"message":"Tiden är redan bokad.","status":400}

# För lång (max_hours = 3) – nekas
curl -s -X POST ... -d '{..., "start":"2026-10-13 08:00:00Z","end":"2026-10-13 15:00:00Z"}'
# {"data":{},"message":"Max 3 timmar per bokning.","status":400}
```

💡 **Tips:** Använd `console.log(...)` för felsökning. Utskriften syns i
terminalen där PocketBase kör, och under **Logs** i Dashboard.

#### Hitta en post – vilka funktioner finns?

| Funktion | Returnerar | Om inget hittas |
|----------|------------|-----------------|
| `app.findRecordById(coll, id)` | En post | **Kastar fel** |
| `app.findFirstRecordByFilter(coll, filter, params)` | En post | **Kastar fel** ("no rows in result set") |
| `app.findRecordsByFilter(coll, filter, sort, limit, offset, params)` | Lista | Tom lista |
| `app.findAllRecords(coll)` | Lista (alla!) | Tom lista |
| `app.countRecords(coll, $dbx.hashExp({...}))` | Antal | `0` |

⚠️ **Varning:** `findFirstRecordByFilter` och `findRecordById` kastar ett fel
om posten inte finns. Vill du bara veta *om* något finns, använd
`findRecordsByFilter` med `limit` 1 och kolla `length`, eller lägg anropet i
`try/catch`.

### Exempel 3: Egen endpoint (route)

Ibland vill appen ha något som inte är vanlig CRUD, t.ex. statistik. Med
`routerAdd` skapar du en egen endpoint:

```js
/// <reference path="../pb_data/types.d.ts" />

routerAdd("GET", "/api/foreningen/stats", (e) => {
  const resources = e.app.findAllRecords("resources");

  const items = resources.map((r) => ({
    resource: r.getString("name"),
    bookings: e.app.countRecords("bookings", $dbx.hashExp({ resource: r.id })),
  }));

  return e.json(200, { items: items });
}, $apis.requireAuth());
```

```bash
curl -s http://127.0.0.1:8090/api/foreningen/stats -H "Authorization: $TOKEN"
# {"items":[{"bookings":2,"resource":"Tvättstuga 1"},{"bookings":0,"resource":"Festlokalen"}]}
```

- `$apis.requireAuth()` är ett *middleware* som ger `401` om ingen är
  inloggad. `$apis.requireAuth("users")` kräver en användare från just `users`,
  och `$apis.requireSuperuserAuth()` kräver superuser.
- Egna routes går **inte** genom API-reglerna. Du ansvarar själv för
  behörigheten. Här ser alla inloggade antalet – inga personuppgifter.
- Lägg egna routes under ett eget prefix, t.ex. `/api/foreningen/`, så att de
  inte krockar med PocketBases egna.

💡 **Tips:** Statistik som den här kan ofta göras enklare med en
**view-collection** (kapitel 2) – då får du API-regler, filter och sortering
på köpet. Det gör vi i övning 7.

### Exempel 4: Transaktion – återkommande bokning

En medlem vill boka tvättstugan samma tid fyra veckor i rad. Om vecka 3 är
upptagen ska **ingen** av bokningarna sparas – annars sitter hon med tre av
fyra och måste städa upp själv. Det här är exakt det du lärde dig om
**atomicitet** i [ACID-kapitlet](../01-databaser/03-acid-och-transaktioner.md).

```js
/// <reference path="../pb_data/types.d.ts" />

routerAdd("POST", "/api/foreningen/book-series", (e) => {
  const body = e.requestInfo().body;
  const weeks = Number(body.weeks) || 0;
  if (weeks < 1 || weeks > 10) {
    throw new BadRequestError("Ange mellan 1 och 10 veckor.");
  }

  const collection = e.app.findCollectionByNameOrId("bookings");
  const created = [];

  e.app.runInTransaction((txApp) => {
    for (let i = 0; i < weeks; i++) {
      const record = new Record(collection);
      record.set("resource", body.resource);
      record.set("user", e.auth.id);
      record.set("start", new DateTime(body.start).addDate(0, 0, 7 * i));
      record.set("end", new DateTime(body.end).addDate(0, 0, 7 * i));
      record.set("note", body.note || "");

      txApp.save(record); // kör onRecordValidate → kastar fel vid krock
      created.push(record.id);
    }
  });

  return e.json(200, { created: created.length, ids: created });
}, $apis.requireAuth("users"));
```

```
runInTransaction
  ├─ save vecka 1  ✓
  ├─ save vecka 2  ✓
  ├─ save vecka 3  ✗ "Tiden är redan bokad."  → fel kastas
  └─ ROLLBACK – vecka 1 och 2 försvinner också
```

⚠️ **Varning:** Inuti `runInTransaction` ska du använda **`txApp`**, inte
`$app` eller `e.app`. Annars hamnar anropet utanför transaktionen – och i
värsta fall väntar det på att transaktionen ska bli klar, som i sin tur väntar
på anropet (deadlock).

Notera också att vår valideringshook körs även här, eftersom `txApp.save`
sparar en post. Det är fördelen med att lägga valideringen i en model hook.

### Exempel 5: Schemalagt jobb (cron)

Rensa bort bokningar som slutade för mer än ett år sedan, varje natt kl. 03:00:

```js
/// <reference path="../pb_data/types.d.ts" />

cronAdd("rensa_gamla_bokningar", "0 3 * * *", () => {
  const limit = new DateTime().addDate(-1, 0, 0); // ett år sedan

  const old = $app.findRecordsByFilter(
    "bookings", "end < {:limit}", "", 0, 0, { limit: limit },
  );

  $app.runInTransaction((txApp) => {
    for (const b of old) {
      txApp.delete(b);
    }
  });

  console.log(`Rensade ${old.length} gamla bokningar`);
});
```

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
0 8 * * 1     måndagar kl. 08:00
0 12 1 * *    den 1:a varje månad kl. 12:00
```

I cron-jobb finns inget `e` – använd den globala `$app`. Tiderna är i UTC.

### Exempel 6: Efter sparning – sidoeffekter

```js
onRecordAfterCreateSuccess((e) => {
  const resource = e.app.findRecordById("resources", e.record.getString("resource"));
  console.log(`Ny bokning av ${resource.getString("name")}: ${e.record.getString("start")}`);
  e.next();
}, "bookings");
```

Här passar det att skicka mejl (`$app.newMailClient()`), push-notiser eller
logga. Posten är redan sparad, så ett fel här ångrar inte bokningen.

### Hooks eller API-regler?

| Fråga | Lösning |
|-------|---------|
| Vem får läsa/ändra? | **API-regler** – snabbast, syns i Dashboard |
| Får klienten sätta det här fältet? | **API-regel** (`:isset`, `:changed`) eller stämpla i **request hook** |
| Krav som rör *andra* poster (överlapp, kvoter)? | **Hook** (`onRecordValidate`) |
| Krav som rör beräkningar (timmar, summor)? | **Hook** |
| Flera ändringar som måste lyckas tillsammans? | **Route + `runInTransaction`** |
| Något som ska hända regelbundet? | **`cronAdd`** |
| Mejl/notis när något hänt? | **`onRecord...AfterCreateSuccess`** |

## Del 2: Migrationer

### Problemet

Du har byggt alla collections i Dashboard på din dator. Nu ska:

- din kurskamrat köra samma backend,
- servern i produktion få samma struktur,
- du lägga till fältet `bookings.status` utan att tappa någon data.

Att klicka runt i Dashboard på varje dator är långsamt och felbenäget. Och du
kan inte skicka `pb_data` – den innehåller ju din testdata och dina lösenord.

**Migrationer** löser det: varje ändring av strukturen sparas som en
JavaScript-fil i `pb_migrations/`. Filerna körs i ordning, och PocketBase
håller reda på vilka som redan körts (i tabellen `_migrations`).

```
pb_migrations/
├── 1791530000_created_apartments.js     ← kördes 2026-10-01
├── 1791530100_updated_users.js          ← kördes 2026-10-01
├── 1791530200_created_bookings.js       ← kördes 2026-10-02
└── 1791540000_updated_bookings.js       ← NY – körs vid nästa start
```

Siffran i början är en Unix-tidsstämpel. Den styr ordningen.

### Automigrate – migrationer skapas av sig själva

När du kör den färdiga `pocketbase`-filen är **automigrate** påslaget. Varje
gång du ändrar en collection i Dashboard skrivs en migrationsfil automatiskt:

```
Du klickar "Save changes" på bookings i Dashboard
          │
          ▼
pb_migrations/1791531151_updated_bookings.js skapas
```

En automatiskt skapad migration ser ut ungefär så här:

```js
/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_986407980")

  // add field
  collection.fields.addAt(6, new Field({
    "hidden": false,
    "id": "select2063623452",
    "maxSelect": 1,
    "name": "status",
    "required": false,
    "type": "select",
    "values": ["confirmed", "cancelled"]
  }))

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_986407980")

  // remove field
  collection.fields.removeById("select2063623452")

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
       │  git commit -m "Lägg till bookings.status"
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
./pocketbase migrate create "seed_resources"
# skapar pb_migrations/1791600000_seed_resources.js
```

Fyll i den:

```js
/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const resources = app.findCollectionByNameOrId("resources");

  const data = [
    { name: "Tvättstuga 1", description: "Källaren, hus A", max_hours: 3, active: true },
    { name: "Tvättstuga 2", description: "Källaren, hus B", max_hours: 3, active: true },
    { name: "Festlokalen", description: "Plats för 40 personer", max_hours: 12, active: true },
    { name: "Bastun", description: "Stängd för renovering", max_hours: 2, active: false },
  ];

  for (const d of data) {
    const record = new Record(resources);
    record.load(d);  // sätter alla fält på en gång
    app.save(record);
  }
}, (app) => {
  for (const name of ["Tvättstuga 1", "Tvättstuga 2", "Festlokalen", "Bastun"]) {
    try {
      app.delete(app.findFirstRecordByFilter("resources", "name = {:n}", { n: name }));
    } catch (_) {
      // fanns inte – ignorera
    }
  }
});
```

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
som skapar **hela** Föreningsappens schema med regler och index.

💡 **Tips:** Migrationer körs i en **transaktion**. Om något går fel mitt i
rullas allt tillbaka, och databasen blir inte halvfärdig.

### Typiskt misstag: seed-data i produktion

Testdata ("Anna", "Bo", lösenordet `hemligt123`) ska inte hamna på
produktionsservern. Lägg testanvändare i en separat migration som du bara kör
lokalt, eller skapa dem med ett skript mot API:t. Resurser som "Tvättstuga 1"
kan däremot vara rimlig startdata överallt.

## Sammanfattning

- Hooks ligger i `pb_hooks/*.pb.js` och laddas om automatiskt.
- Varje hook måste anropa `e.next()`. Kasta `BadRequestError` m.fl. för att
  stoppa.
- Request hooks (`onRecordCreateRequest`) gäller API-anrop. Model hooks
  (`onRecordValidate`, `onRecordCreate`) gäller alla sparningar.
- Kod utanför hook-funktionen syns inte inuti – använd `require(`${__hooks}/...`)`.
- `routerAdd` för egna endpoints, `cronAdd` för schemalagda jobb,
  `runInTransaction` för allt-eller-inget (använd `txApp`).
- Migrationer i `pb_migrations/` beskriver strukturen som kod. Automigrate
  skapar dem när du ändrar i Dashboard. Commita dem till git, ändra aldrig en
  redan körd migration.

Nästa kapitel: [Flera föreningar och behörigheter](08-flera-foreningar-och-behorigheter.md).
Vill du öva först? Övning 1–8 i [övningarna](ovningar.md) bygger på kapitel 1–7.

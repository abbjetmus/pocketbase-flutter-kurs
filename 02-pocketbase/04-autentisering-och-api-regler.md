# 04 – Autentisering och API-regler

Hittills har vi skapat collections och data som superuser. Men Kvittras
användare är inga superusers. I det här kapitlet lär vi oss:

1. hur användare registrerar sig och loggar in (**autentisering** – *vem är du?*),
2. hur vi bestämmer vad de får göra (**auktorisering** – *vad får du göra?*).

Det andra är det viktigaste kapitlet i hela modulen ur säkerhetssynpunkt. En
app kan se perfekt ut och ändå läcka all data om reglerna är fel.

## Auth-collections

`users` är en **auth-collection** (kapitel 2). Utöver vanliga fält har den
inloggnings-endpoints:

| Endpoint | Gör |
|----------|-----|
| `POST /api/collections/users/records` | Registrera ett nytt konto (styrs av create-regeln) |
| `POST /api/collections/users/auth-with-password` | Logga in med e-post/användarnamn + lösenord |
| `POST /api/collections/users/auth-refresh` | Förnya token (kräver giltig token) |
| `POST /api/collections/users/request-password-reset` | Skicka "glömt lösenord"-mejl |
| `POST /api/collections/users/request-verification` | Skicka verifieringsmejl |
| `POST /api/collections/users/request-otp` + `auth-with-otp` | Engångskod via e-post |
| `POST /api/collections/users/auth-with-oauth2` | Logga in med Google, Apple m.fl. |
| `GET  /api/collections/users/auth-methods` | Vilka inloggningssätt är påslagna? |

### Inloggningsmetoder

Inställningarna hittar du i Dashboard: `users` → kugghjulet → fliken
**Options**.

| Metod | Beskrivning | Kvittra |
|-------|-------------|---------|
| **Identity/Password** | E-post (eller annat unikt fält, t.ex. `username`) + lösenord | ✅ Det vi använder |
| **OTP** | Engångskod skickas till e-post | Bra för den som glömmer lösenord |
| **OAuth2** | "Logga in med Google/Apple/Microsoft" | Vanligt i sociala appar – möjligt senare |
| **MFA** | Kräver två metoder (t.ex. lösenord + OTP) | För konton som är extra värda att skydda |

### Registrering

En social app låter vem som helst skapa ett konto. Det gör man med ett vanligt
create-anrop mot `users` (förutsatt att create-regeln är öppen, se nedan):

```bash
curl -X POST http://127.0.0.1:8090/api/collections/users/records \
  -H "Content-Type: application/json" \
  -d '{"email":"erik@example.com","password":"hemligt123","passwordConfirm":"hemligt123",
       "username":"erik","name":"Erik Eriksson"}'
```

`passwordConfirm` måste vara samma som `password`. Svaret är den nya
användaren – utan lösenord, förstås.

### Vad händer vid inloggning?

```
App                                        PocketBase
 │  POST /auth-with-password                    │
 │  {"identity":"anna@example.com",             │
 │   "password":"hemligt123"}                   │
 │ ───────────────────────────────────────────► │ 1. Hitta users-post med e-posten
 │                                              │    (eller användarnamnet)
 │                                              │ 2. Jämför lösenord mot hashen
 │                                              │ 3. Skapa en signerad token (JWT)
 │ ◄─────────────────────────────────────────── │
 │  {"token":"eyJhbGciOi...",                   │
 │   "record":{"id":"ryd2jdczusx4tm4",          │
 │             "username":"anna", ...}}         │
 │                                              │
 │  GET /api/collections/posts/records          │
 │  Authorization: eyJhbGciOi...                │
 │ ───────────────────────────────────────────► │ 4. Verifiera token → det är Anna
 │                                              │ 5. Kör API-regeln med Annas data
```

Med curl:

```bash
curl -X POST http://127.0.0.1:8090/api/collections/users/auth-with-password \
  -H "Content-Type: application/json" \
  -d '{"identity":"anna@example.com","password":"hemligt123"}'
```

Har du lagt till `username` som identitetsfält (kapitel 2) fungerar också
`"identity":"anna"`.

**Token** är ett signerat "passerkort". Appen sparar det och skickar med det i
headern `Authorization` vid varje anrop. Den är giltig en viss tid (i v0.39 är
standard 432000 sekunder = 5 dagar för `users`; det går att ändra under
*Options → Token options*). Appen förnyar den med `auth-refresh` innan den går
ut.

⚠️ **Varning:** Token är lika känslig som ett lösenord. Logga den aldrig, och
lägg den aldrig i en URL.

## API-regler: grunderna

Varje collection har **fem regler**, en per åtgärd. Du hittar dem i Dashboard:
collection → kugghjulet → fliken **API Rules**.

| Regel | Gäller | HTTP |
|-------|--------|------|
| **List/Search** | Hämta flera poster | `GET /records` |
| **View** | Hämta en post | `GET /records/:id` |
| **Create** | Skapa | `POST /records` |
| **Update** | Ändra | `PATCH /records/:id` |
| **Delete** | Ta bort | `DELETE /records/:id` |

Auth-collections har dessutom en **Manage**-regel (vem får ändra andras
e-post/lösenord) och en **Auth**-regel (extra villkor för att få logga in).

### Tre sorters värden

Det här är den absolut viktigaste tabellen i kapitlet:

| Värde | I Dashboard | Betyder |
|-------|-------------|---------|
| `null` | Låst hänglås 🔒 (*"Superusers only"*) | **Bara superusers.** Standard för nya collections. |
| `""` (tom sträng) | Upplåst, tomt textfält | **Alla – även utloggade!** |
| `"villkor"` | Upplåst, text i fältet | Bara om villkoret är sant |

⚠️ **Varning:** `null` och `""` ser nästan likadana ut men betyder motsatsen.
`null` = stängt för alla utom superusers. `""` = öppet för hela internet. I
Dashboard klickar du på hänglåset för att växla. När du låser upp ett
regelfält och lämnar det tomt har du gjort collectionen **publik**.

### Vad händer när en regel säger nej?

| Åtgärd | Svar när regeln inte uppfylls |
|--------|-------------------------------|
| List | `200` med **färre poster** (de som inte uppfyller regeln filtreras bort) – kanske en tom lista |
| View, Update, Delete | `404 Not Found` (posten "finns inte" för dig) |
| Create | `400 Bad Request` (`Failed to create record.`) |
| Regeln är `null` (superusers only) | `403 Forbidden` |

List-regeln fungerar alltså som ett **filter**: PocketBase lägger till den som
ett extra `WHERE`-villkor. Det är därför en utloggad användare får en tom lista
i stället för ett fel.

## Regelspråket

En regel är ett uttryck som blir sant eller falskt för varje post.

### Vad kan man referera till?

| Uttryck | Betyder | Exempel |
|---------|---------|---------|
| `fältnamn` | Fält på posten som regeln gäller | `author = @request.auth.id` |
| `relation.fält` | Fält på en relaterad post | `post.author = @request.auth.id` |
| `@request.auth.*` | Den inloggade användaren | `@request.auth.id`, `@request.auth.verified` |
| `@request.body.*` | Data som klienten skickar (create/update) | `@request.body.author` |
| `@request.query.*` | Query-parametrar i URL:en | `@request.query.page` |
| `@request.headers.*` | HTTP-headers (gemener, `-` blir `_`) | `@request.headers.x_app_version` |
| `@request.method` | `GET`, `POST`, ... | |
| `@collection.namn.*` | Valfri annan collection (som en subquery/JOIN) | se nedan |
| `@now`, `@todayStart`, ... | Datum-makron (UTC) | `created > @todayStart` |

### Operatorer

| Operator | Betyder |
|----------|---------|
| `=` `!=` | lika / inte lika |
| `>` `>=` `<` `<=` | större / mindre |
| `~` `!~` | innehåller / innehåller inte (som `LIKE '%x%'`) |
| `?=` `?!=` `?>` `?~` ... | "minst ett av värdena" (för listor och back-relationer) |
| `&&` `\|\|` `( )` | och / eller / gruppering |

### Modifierare

| Modifierare | Betyder | Exempel |
|-------------|---------|---------|
| `:isset` | Skickade klienten fältet över huvud taget? | `@request.body.post:isset = false` |
| `:changed` | Skickade klienten ett **annat** värde än det som är sparat? | `@request.body.author:changed = false` |
| `:length` | Antal element i en lista (multi-fält) | `@request.body.tags:length <= 3` |
| `:each` | Villkoret ska gälla varje element | `@request.body.interests:each != "spam"` |
| `:lower` | Jämför utan skiftlägeskänslighet | `title:lower ~ "kaffe"` |

## Det allra vanligaste: "inloggad"

```
@request.auth.id != ""
```

Om ingen är inloggad är `@request.auth.id` en tom sträng. Den här regeln
betyder alltså "vilken inloggad användare som helst".

## Regler för Kvittra

Vi går igenom collection för collection. Grundtanken i en social app: **alla
inloggade får läsa, men man får bara skriva i sitt eget namn och bara ändra
sitt eget.**

### `users`

| Regel | Värde | Varför |
|-------|-------|--------|
| List | `@request.auth.id != ""` | Inloggade kan söka efter andra användare |
| View | `@request.auth.id != ""` | ...och se deras profil |
| Create | `""` | **Fri registrering** – vem som helst får skapa ett konto |
| Update | `id = @request.auth.id` | Man ändrar bara sin egen profil |
| Delete | `null` | Konton tas bort via en egen route som anonymiserar (kapitel 7) |

Create `""` är ett av få tillfällen då en tom regel är rätt: hela poängen är
att någon som inte har ett konto ska kunna skapa ett. Att det är säkert beror
på två saker:

- PocketBase skyddar själv systemfälten. Skickar man med `"verified": true` vid
  registrering svarar PocketBase `400` (`validation_values_mismatch`) – bara
  superusers (och den som har Manage-rätt) får sätta det.
- `users` har inga fält som ger extra makt, t.ex. en roll.

⚠️ **Varning:** Lägger du senare till ett fält som ger makt – säg
`is_moderator` (bool) – på `users`, **måste** både create- och update-regeln
hindra att man sätter det själv:

```
@request.body.is_moderator:isset = false
```

Annars kan vem som helst på internet registrera sig med
`"is_moderator": true`. (I kapitel 8 löser vi roller på ett säkrare sätt, i en
egen collection där servern sätter rollen.)

💡 **Tips:** E-postadresser skickas bara ut till andra om `emailVisibility` är
`true` på posten. Din egen e-post ser du alltid. Det är därför Anna ser sin
e-post men inte Bos när hon listar `users` – i en social app vill de flesta
visa sitt användarnamn, inte sin e-post.

### `posts` – inlägg

**List / View – alla inloggade ser alla inlägg:**

```
@request.auth.id != ""
```

**Create – man får bara skriva inlägg i sitt eget namn:**

```
@request.auth.id != "" && @request.body.author = @request.auth.id
```

Utan `@request.body.author = @request.auth.id` kan Anna skicka
`{"author": "<Bos id>", "title": "Jag gillar inte kaffe"}` och publicera
något i Bos namn.

**Update – bara egna inlägg, och författaren får inte bytas:**

```
author = @request.auth.id && @request.body.author:changed = false
```

- `author = @request.auth.id` – posten som den ser ut **nu** måste vara min.
  För Anna blir det i praktiken SQL:en `WHERE author = 'ryd2jdczusx4tm4'`.
- `@request.body.author:changed = false` – om klienten skickar `author` måste
  det vara samma värde som redan är sparat.

Utan den andra delen kan Anna ändra sitt inlägg och sätta `author` till Bo – och
plötsligt står Bo som avsändare till något han aldrig skrivit.

**Delete – bara egna inlägg:**

```
author = @request.auth.id
```

### `comments` – kommentarer

| Regel | Värde |
|-------|-------|
| List / View | `@request.auth.id != ""` |
| Create | `@request.auth.id != "" && @request.body.author = @request.auth.id` |
| Update | `author = @request.auth.id && @request.body.post:isset = false && @request.body.author:isset = false` |
| Delete | `author = @request.auth.id \|\| post.author = @request.auth.id` |

Två nya mönster:

- **Update med `:isset = false`:** klienten får inte ens *skicka med* `post`
  eller `author`. Det enda som går att ändra är alltså `body`. (Man ska inte
  kunna flytta sin kommentar till ett annat inlägg.)
- **Delete via en relation:** `post.author = @request.auth.id` följer
  relationen från kommentaren till inlägget. Den som skrev *inlägget* får
  alltså ta bort elaka kommentarer under det – även om någon annan skrev dem.

### `likes` och `follows` – kopplings-collections

| Collection | Create | Update | Delete |
|------------|--------|--------|--------|
| `likes` | `@request.auth.id != "" && @request.body.user = @request.auth.id` | `null` | `user = @request.auth.id` |
| `follows` | `@request.auth.id != "" && @request.body.follower = @request.auth.id && @request.body.following != @request.auth.id` | `null` | `follower = @request.auth.id` |

List och View är `@request.auth.id != ""` på båda.

- Man gillar bara i eget namn och "ogillar" (tar bort) bara sin egen gillning.
- Man följer bara i eget namn, och `@request.body.following != @request.auth.id`
  hindrar att man följer sig själv.
- Update är `null`: en gillning eller följning ändras aldrig, den skapas eller
  tas bort. Att låsa det man inte behöver är god vana.
- Att samma person inte kan gilla två gånger sköter det **unika indexet** på
  `(post, user)`, inte regeln. Ett andra försök ger `400` med
  `validation_not_unique`.

💡 **Tips:** Man kan följa en relation i body också:
`@request.body.post.author != @request.auth.id` i create-regeln för `likes`
skulle hindra att man gillar sitt eget inlägg. I kapitel 7 gör vi samma sak
med en hook i stället – och jämför för- och nackdelar.

## @collection – regler som tittar i andra collections

Ibland räcker det inte med fälten på posten eller den inloggade, utan man
behöver titta i en *annan* collection. `@collection.<namn>` fungerar som en
`JOIN` mot en valfri collection.

Exempel: tänk dig att Kvittra får **privata konton** (ett bool-fält
`users.private`). Ett privat kontos inlägg ska bara synas för dem som följer
kontot. List-regeln på `posts` kan då skrivas:

```
@request.auth.id != "" && (
  author.private = false ||
  author = @request.auth.id ||
  (@collection.follows.follower ?= @request.auth.id && @collection.follows.following ?= author)
)
```

Den sista raden betyder: "det finns en rad i `follows` där jag är `follower`
**och** inläggets författare är `following`". Båda villkoren gäller samma rad
i `follows`.

Eftersom det redan finns en väg via relationer kan samma sak skrivas kortare
med en back-relation (kapitel 3):

```
author.follows_via_following.follower ?= @request.auth.id
```

Båda varianterna är testade och ger samma resultat. Tumregel: finns det en väg
via relationsfält, använd back-relationen. Använd `@collection` när det inte
finns någon sådan väg.

⚠️ **Varning:** Den farligaste missen med `@collection` är att glömma att
**koppla** den till posten. Regeln
`@collection.follows.follower ?= @request.auth.id` (utan `following ?= author`)
betyder "jag följer *någon*" – och då ser alla som följer minst en person
alla privata inlägg. Testa alltid med en användare som *inte* ska få se.

💡 **Tips:** Vill du joina *samma* collection flera gånger med **olika** rader
(t.ex. "Anna följer Bo" och "Bo följer Anna") ger du varje join ett eget alias
med suffixet `:alias`, t.ex. `@collection.follows:a.follower` och
`@collection.follows:b.follower`.

Avancerade regler kan bli långsamma. Börja enkelt, och lägg komplicerad logik i
en hook (kapitel 7) om regeln blir svår att läsa.

## Ändringar på användaren – när gäller de?

`@request.auth.*` hämtas från **databasen** vid varje anrop (via id:t i
token), inte från token själv. Om något på Annas användarpost ändras gäller det
direkt i reglerna. Men appen har kvar den gamla `record` som den fick vid
inloggningen – anropa `auth-refresh` för att få den uppdaterade posten till
appen.

## Superusers och regler

Superusers **ignorerar alla regler**. När du testar i Dashboard är du superuser
och ser allt. Därför måste du testa reglerna som en vanlig användare – med curl
(kapitel 5) eller med appen.

💡 **Tips:** I Dashboard kan du öppna en användare och välja
**Impersonate** i menyn (⋯). Då får du en token för den användaren som du kan
klistra in i curl.

## Vanliga säkerhetsmisstag

| # | Misstag | Följd | Rätt |
|---|---------|-------|------|
| 1 | Lämnar regeln tom (`""`) "för att testa" | Hela internet kan läsa/ändra | Använd `@request.auth.id != ""` och glöm inte att strama åt |
| 2 | Create på `posts` kontrollerar inte `@request.body.author` | Man kan skriva i andras namn | `@request.body.author = @request.auth.id` |
| 3 | Update kontrollerar bara `author = @request.auth.id` | Man kan "ge bort" sitt inlägg till någon annan | Lägg till `@request.body.author:changed = false` |
| 4 | Create på `likes` kontrollerar inte `@request.body.user` | Man kan gilla i andras namn och blåsa upp siffror | `@request.body.user = @request.auth.id` |
| 5 | Inget unikt index på `likes (post, user)` | Samma person gillar 1000 gånger | Unikt index |
| 6 | Litar på att appen döljer knappar | Någon anropar API:t direkt med curl | All behörighet i regler/hooks, aldrig bara i appen |
| 7 | List-regel strängare än View eller tvärtom av misstag | Data läcker via den ena vägen | Håll List och View i synk |
| 8 | Glömmer att `expand` och filter går via relationer | — (PocketBase skyddar, men…) | Kontrollera reglerna på *alla* collections, inte bara den du frågar |
| 9 | Hemlig data i ett fält som alla får läsa | Läcker | Markera fältet **Hidden** eller lägg det i en separat collection med egna regler |
| 10 | Fält som ger makt (t.ex. `is_moderator`) på `users` utan `:isset = false` | Vem som helst blir moderator | `@request.body.is_moderator:isset = false` i create och update |
| 11 | Testar bara som superuser | Ser inga fel | Testa alltid som en vanlig användare |

⚠️ **Varning:** Misstag 6 är det viktigaste. **Appen är inte en
säkerhetsgräns.** Allt som appen kan göra, kan en användare göra med curl. Om
knappen "Ta bort" bara visas på dina egna inlägg men Delete-regeln är
`@request.auth.id != ""`, då kan alla ta bort allas inlägg.

## Checklista innan du går vidare

För varje collection, för varje av de fem reglerna, fråga:

1. Ska utloggade kunna göra detta? (Nästan aldrig – registrering är
   undantaget.)
2. Vilka inloggade? Alla, ägaren, någon med en viss koppling?
3. Vid create/update: vilka fält får klienten sätta? Vilka måste låsas med
   `= @request.auth.id`, `:changed = false` eller `:isset = false`?
4. Har jag testat som en vanlig användare – både det som ska gå och det som
   *inte* ska gå?

🧪 **Prova själv:** Sätt reglerna på `posts` enligt ovan. Logga in som Anna
(curl) och försök (a) skapa ett inlägg i Bos namn, (b) ändra ditt eget inlägg
så att Bo blir författare, (c) ändra titeln på Bos inlägg. Alla tre ska
misslyckas. Svaren ska bli `400`, `404` och `404`.

## Sammanfattning

- Auth-collections ger registrering och inloggning. Token skickas i
  `Authorization`-headern.
- Fem regler per collection: list, view, create, update, delete.
- `null` = bara superusers. `""` = alla, även utloggade. Text = villkor.
- `@request.auth.*` är den inloggade, `@request.body.*` är det som skickas in.
- Lås fält med `= @request.auth.id`, `:changed = false` och `:isset = false`.
- `@collection` och back-relationer låter regeln titta i andra collections –
  men glöm inte att koppla dem till posten.
- Superusers ignorerar regler – testa som vanlig användare.
- Appen är inte en säkerhetsgräns.

Nästa kapitel: [REST-API och filter](05-rest-api-och-filter.md).

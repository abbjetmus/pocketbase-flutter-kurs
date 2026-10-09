# 04 – Autentisering och API-regler

Hittills har vi skapat collections och data som superuser. Men Föreningsappens
medlemmar är inga superusers. I det här kapitlet lär vi oss:

1. hur medlemmar loggar in (**autentisering** – *vem är du?*),
2. hur vi bestämmer vad de får göra (**auktorisering** – *vad får du göra?*).

Det andra är det viktigaste kapitlet i hela modulen ur säkerhetssynpunkt. En
app kan se perfekt ut och ändå läcka all data om reglerna är fel.

## Auth-collections

`users` är en **auth-collection** (kapitel 2). Utöver vanliga fält har den
inloggnings-endpoints:

| Endpoint | Gör |
|----------|-----|
| `POST /api/collections/users/auth-with-password` | Logga in med e-post + lösenord |
| `POST /api/collections/users/auth-refresh` | Förnya token (kräver giltig token) |
| `POST /api/collections/users/request-password-reset` | Skicka "glömt lösenord"-mejl |
| `POST /api/collections/users/request-verification` | Skicka verifieringsmejl |
| `POST /api/collections/users/request-otp` + `auth-with-otp` | Engångskod via e-post |
| `POST /api/collections/users/auth-with-oauth2` | Logga in med Google, Apple m.fl. |
| `GET  /api/collections/users/auth-methods` | Vilka inloggningssätt är påslagna? |

### Inloggningsmetoder

Inställningarna hittar du i Dashboard: `users` → kugghjulet → fliken
**Options**.

| Metod | Beskrivning | Föreningsappen |
|-------|-------------|----------------|
| **Identity/Password** | E-post (eller annat unikt fält) + lösenord | ✅ Det vi använder |
| **OTP** | Engångskod skickas till e-post | Bra för äldre medlemmar som glömmer lösenord |
| **OAuth2** | "Logga in med Google/Apple/Microsoft" | Möjligt senare |
| **MFA** | Kräver två metoder (t.ex. lösenord + OTP) | För styrelsen? |

### Vad händer vid inloggning?

```
App                                        PocketBase
 │  POST /auth-with-password                    │
 │  {"identity":"anna@example.com",             │
 │   "password":"hemligt123"}                   │
 │ ───────────────────────────────────────────► │ 1. Hitta users-post med e-posten
 │                                              │ 2. Jämför lösenord mot hashen
 │                                              │ 3. Skapa en signerad token (JWT)
 │ ◄─────────────────────────────────────────── │
 │  {"token":"eyJhbGciOi...",                   │
 │   "record":{"id":"flskfapcqwu5iun",          │
 │             "name":"Anna","role":"member"}}  │
 │                                              │
 │  GET /api/collections/bookings/records       │
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

**Token** är ett signerat "passerkort". Appen sparar det och skickar med det i
headern `Authorization` vid varje anrop. Den är giltig en viss tid (i v0.39 är standard 432000 sekunder = 5 dagar
för `users`; det går att ändra under *Options → Token options*). Appen förnyar
den med `auth-refresh` innan den går ut.

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
| Create | `400 Bad Request` |
| Regeln är `null` (superusers only) | `403 Forbidden` |

List-regeln fungerar alltså som ett **filter**: PocketBase lägger till den som
ett extra `WHERE`-villkor. Det är därför en utloggad användare får en tom lista
i stället för ett fel.

## Regelspråket

En regel är ett uttryck som blir sant eller falskt för varje post.

### Vad kan man referera till?

| Uttryck | Betyder | Exempel |
|---------|---------|---------|
| `fältnamn` | Fält på posten som regeln gäller | `published = true` |
| `relation.fält` | Fält på en relaterad post | `resource.active = true` |
| `@request.auth.*` | Den inloggade användaren | `@request.auth.id`, `@request.auth.role` |
| `@request.body.*` | Data som klienten skickar (create/update) | `@request.body.user` |
| `@request.query.*` | Query-parametrar i URL:en | `@request.query.page` |
| `@request.headers.*` | HTTP-headers (gemener, `-` blir `_`) | `@request.headers.x_app_version` |
| `@request.method` | `GET`, `POST`, ... | |
| `@collection.namn.*` | Valfri annan collection (som en subquery/JOIN) | se nedan |
| `@now`, `@todayStart`, ... | Datum-makron (UTC) | `start > @now` |

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
| `:isset` | Skickade klienten fältet över huvud taget? | `@request.body.role:isset = false` |
| `:changed` | Skickade klienten ett **annat** värde än det som är sparat? | `@request.body.user:changed = false` |
| `:length` | Antal element i en lista | `@request.body.tags:length <= 3` |
| `:each` | Villkoret ska gälla varje element | `@request.body.weekdays:each != "sun"` |
| `:lower` | Jämför utan skiftlägeskänslighet | `title:lower ~ "fest"` |

## Det allra vanligaste: "inloggad"

```
@request.auth.id != ""
```

Om ingen är inloggad är `@request.auth.id` en tom sträng. Den här regeln
betyder alltså "vilken inloggad användare som helst".

## Regler för Föreningsappen

Vi går igenom collection för collection. Rollerna finns i fältet
`users.role`: `member`, `styrelse` eller `admin`.

### `apartments`

| Regel | Värde | Varför |
|-------|-------|--------|
| List | `@request.auth.id != ""` | Inloggade får se lägenhetslistan |
| View | `@request.auth.id != ""` | |
| Create | `@request.auth.role = "admin"` | Bara föreningens admin lägger till lägenheter |
| Update | `@request.auth.role = "admin"` | |
| Delete | `@request.auth.role = "admin"` | |

### `resources`

| Regel | Värde |
|-------|-------|
| List | `@request.auth.id != ""` |
| View | `@request.auth.id != ""` |
| Create / Update / Delete | `@request.auth.role = "admin"` |

💡 **Tips:** Vill du att inaktiva resurser bara ska synas för admin? Skriv
List: `@request.auth.id != "" && (active = true \|\| @request.auth.role = "admin")`.

### `bookings` – den intressanta

**List / View – medlemmar ser bara sina egna bokningar, styrelsen ser alla:**

```
user = @request.auth.id || @request.auth.role = "styrelse" || @request.auth.role = "admin"
```

`user` är fältet på bokningen. `@request.auth.id` är den inloggades id. För Anna
blir det i praktiken SQL:en `WHERE user = 'flskfapcqwu5iun' OR ...`.

**Create – man får bara boka i sitt eget namn, och bara aktiva resurser:**

```
@request.auth.id != "" &&
@request.body.user = @request.auth.id &&
@request.body.resource.active = true
```

Utan `@request.body.user = @request.auth.id` kan Anna skicka
`{"user": "<Bos id>"}` och boka i Bos namn. Notera att man kan följa en
relation i body: `@request.body.resource.active` slår upp resursen som
klienten skickat in och kontrollerar att den är aktiv.

**Update – bara egna bokningar, och man får inte flytta över dem till någon
annan:**

```
user = @request.auth.id && @request.body.user:changed = false
```

- `user = @request.auth.id` – posten som den ser ut **nu** måste vara min.
- `@request.body.user:changed = false` – om klienten skickar `user` måste det
  vara samma värde som redan är sparat.

Utan den andra delen kan Anna ändra sin bokning och sätta `user` till Bo – och
plötsligt står Bo för en bokning han inte gjort.

**Delete – egna bokningar, eller admin:**

```
user = @request.auth.id || @request.auth.role = "admin"
```

### `posts` – anslag

**List / View – inloggade ser publicerade anslag, och sina egna utkast:**

```
@request.auth.id != "" && (published = true || author = @request.auth.id)
```

**Create – bara styrelse och admin, och i eget namn:**

```
(@request.auth.role = "styrelse" || @request.auth.role = "admin") &&
@request.body.author = @request.auth.id
```

**Update – bara författaren, och författaren får inte bytas:**

```
author = @request.auth.id && @request.body.author:changed = false
```

**Delete:**

```
author = @request.auth.id || @request.auth.role = "admin"
```

### `users` – skydda rollen!

| Regel | Värde | Varför |
|-------|-------|--------|
| List | `@request.auth.id != ""` | Inloggade ser grannarnas namn |
| View | `@request.auth.id != ""` | |
| Create | `null` | Konton skapas av admin (superuser) – ingen fri registrering |
| Update | se nedan | |
| Delete | `null` | |

**Update – man får ändra sin egen profil, men inte roll eller lägenhet:**

```
id = @request.auth.id &&
@request.body.role:isset = false &&
@request.body.apartment:isset = false
```

`:isset = false` betyder att klienten inte ens får **skicka med** fältet.

Vill du tillåta självregistrering (Create = `""`)? Då **måste** du hindra
att man sätter sin egen roll:

```
@request.body.role:isset = false && @request.body.apartment:isset = false
```

Annars kan vem som helst på internet registrera sig med `"role": "admin"`.

💡 **Tips:** E-postadresser skickas bara ut till andra om `emailVisibility` är
`true` på posten. Din egen e-post ser du alltid. Det är därför Anna ser sin
e-post men inte Bos i listan.

## @collection – regler som tittar i andra collections

Ibland räcker det inte med fälten på posten eller den inloggade, utan man
behöver titta i en *annan* collection som inte är kopplad via en relation från
posten.

`@collection.<namn>` fungerar som en `JOIN` mot en valfri collection:

Exempel med en tänkt kopplings-collection `event_attendees` (från kapitel 3)
och en collection `event_comments` som har en relation `event`: "man får se
kommentarerna till en aktivitet om man själv är anmäld till den":

```
@collection.event_attendees.event ?= event &&
@collection.event_attendees.user ?= @request.auth.id
```

💡 **Tips:** Vill du joina *samma* collection flera gånger med olika
villkor (t.ex. "Anna är anmäld" och "Bo är anmäld") ger du varje join ett
alias med suffixet `:alias`, t.ex. `@collection.event_attendees:anna.user` och
`@collection.event_attendees:bo.user`.

Avancerade regler kan bli långsamma. Börja enkelt, och lägg komplicerad logik i
en hook (kapitel 7) om regeln blir svår att läsa.

## Rollen i token – och när den ändras

`@request.auth.role` hämtas från **databasen** vid varje anrop (via id:t i
token), inte från token själv. Om admin ändrar Annas roll till `styrelse`
gäller det direkt. Men appen har kvar den gamla `record` som den fick vid
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
| 2 | Create på bookings kontrollerar inte `@request.body.user` | Man kan boka i andras namn | `@request.body.user = @request.auth.id` |
| 3 | Update kontrollerar bara `user = @request.auth.id` | Man kan flytta sin bokning till någon annan | Lägg till `@request.body.user:changed = false` |
| 4 | Självregistrering utan skydd av `role` | Vem som helst blir admin | `@request.body.role:isset = false` |
| 5 | Användaren får uppdatera sin egen roll | Medlem gör sig till admin | Samma som ovan, i Update-regeln |
| 6 | Litar på att appen döljer knappar | Någon anropar API:t direkt med curl | All behörighet i regler/hooks, aldrig bara i appen |
| 7 | List-regel strängare än View eller tvärtom av misstag | Data läcker via den ena vägen | Håll List och View i synk |
| 8 | Glömmer att `expand` och filter går via relationer | — (PocketBase skyddar, men…) | Kontrollera reglerna på *alla* collections, inte bara den du frågar |
| 9 | Hemlig data i ett fält som alla får läsa | Läcker | Markera fältet **Hidden** eller lägg det i en separat collection med egna regler |
| 10 | Testar bara som superuser | Ser inga fel | Testa alltid som `member` |

⚠️ **Varning:** Regel 6 är den viktigaste. **Appen är inte en säkerhetsgräns.**
Allt som appen kan göra, kan en användare göra med curl. Om knappen "Radera
anslag" bara visas för styrelsen men Delete-regeln är `@request.auth.id != ""`,
då kan alla radera anslag.

## Checklista innan du går vidare

För varje collection, för varje av de fem reglerna, fråga:

1. Ska utloggade kunna göra detta? (Nästan aldrig.)
2. Vilka inloggade? Alla, ägaren, en viss roll?
3. Vid create/update: vilka fält får klienten sätta? Vilka måste låsas med
   `= @request.auth.id`, `:changed = false` eller `:isset = false`?
4. Har jag testat som en vanlig `member` – både det som ska gå och det som
   *inte* ska gå?

🧪 **Prova själv:** Sätt reglerna på `bookings` enligt ovan. Logga in som Anna
(curl) och försök (a) boka i Bos namn, (b) ändra din bokning så att den blir
Bos, (c) läsa Bos bokningar. Alla tre ska misslyckas. Svaren ska bli `400`,
`404` och en lista utan Bos bokningar.

## Sammanfattning

- Auth-collections ger inloggning. Token skickas i `Authorization`-headern.
- Fem regler per collection: list, view, create, update, delete.
- `null` = bara superusers. `""` = alla, även utloggade. Text = villkor.
- `@request.auth.*` är den inloggade, `@request.body.*` är det som skickas in.
- Lås fält med `= @request.auth.id`, `:changed = false` och `:isset = false`.
- Superusers ignorerar regler – testa som vanlig användare.
- Appen är inte en säkerhetsgräns.

Nästa kapitel: [REST-API och filter](05-rest-api-och-filter.md).

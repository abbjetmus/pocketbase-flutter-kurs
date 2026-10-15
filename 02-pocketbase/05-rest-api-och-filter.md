# 05 – REST-API och filter

Allt du gjort i Dashboard går också att göra över HTTP. Det är så Flutter-appen
pratar med PocketBase. I det här kapitlet använder vi `curl` för att se exakt
vad som skickas och tas emot. När du sedan använder Dart-SDK:n (kapitel 6) vet
du vad som händer under huven.

## REST i korthet

REST betyder att varje "sak" har en adress (URL), och att HTTP-metoden säger vad
du vill göra med den. Du känner igen mönstret från
[JSONPlaceholder](https://jsonplaceholder.typicode.com): `GET /posts`,
`GET /posts/1`, `POST /posts` och så vidare.

| Metod | Betyder | SQL-motsvarighet |
|-------|---------|------------------|
| `GET` | Hämta | `SELECT` |
| `POST` | Skapa | `INSERT` |
| `PATCH` | Ändra delar | `UPDATE` |
| `DELETE` | Ta bort | `DELETE` |

## Endpoints för poster

För varje collection skapar PocketBase automatiskt:

| Åtgärd | Metod + URL | Regel |
|--------|-------------|-------|
| Lista | `GET /api/collections/{collection}/records` | List |
| Hämta en | `GET /api/collections/{collection}/records/{id}` | View |
| Skapa | `POST /api/collections/{collection}/records` | Create |
| Ändra | `PATCH /api/collections/{collection}/records/{id}` | Update |
| Ta bort | `DELETE /api/collections/{collection}/records/{id}` | Delete |

Jämfört med JSONPlaceholder (`/posts/1`) ligger alltså allt under
`/api/collections/<namn>/records`.

Övriga användbara endpoints:

| URL | Gör |
|-----|-----|
| `GET /api/health` | Lever servern? |
| `POST /api/collections/users/auth-with-password` | Logga in (kapitel 4) |
| `GET /api/files/{collection}/{id}/{filnamn}` | Ladda ner en fil |
| `GET /api/realtime` | Realtidsanslutning (se nedan) |

## Förberedelse: spara en token i en variabel

Alla exempel nedan förutsätter att servern kör på port 8090, att reglerna från
kapitel 4 är inlagda och att Anna finns. Logga in och spara token i en
shell-variabel (macOS/Linux):

```bash
TOKEN=$(curl -s -X POST http://127.0.0.1:8090/api/collections/users/auth-with-password \
  -H "Content-Type: application/json" \
  -d '{"identity":"anna@example.com","password":"hemligt123"}' \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["token"])')

echo $TOKEN
```

Spara gärna Annas id också – du behöver det när hon skapar saker i sitt namn:

```bash
ME=$(curl -s -X POST http://127.0.0.1:8090/api/collections/users/auth-refresh \
  -H "Authorization: $TOKEN" \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["record"]["id"])')
```

💡 **Tips:** Har du `jq` installerat kan du i stället skriva
`| jq -r .token`. På Windows fungerar exemplen i Git Bash eller WSL.

## CRUD med curl

### Lista

```bash
curl -s http://127.0.0.1:8090/api/collections/posts/records \
  -H "Authorization: $TOKEN"
```

```json
{
  "page": 1,
  "perPage": 30,
  "totalItems": 6,
  "totalPages": 1,
  "items": [
    { "id": "jecocasqaz8ls35", "collectionName": "posts", "author": "evw7k9240ep07xd",
      "title": "Bästa kaffet i stan?", "body": "Jag letar efter ett nytt favoritkafé. Tips?",
      "image": "", "created": "2026-10-15 08:17:41.461Z", ... },
    ...
  ]
}
```

Svaret är alltid **paginerat**: du får en sida (`page`) med högst `perPage`
poster, plus totalt antal. (JSONPlaceholder skickar en ren lista – PocketBase
skickar ett objekt med listan i `items`.)

### Hämta en

```bash
curl -s http://127.0.0.1:8090/api/collections/posts/records/jecocasqaz8ls35 \
  -H "Authorization: $TOKEN"
```

### Skapa

```bash
curl -s -X POST http://127.0.0.1:8090/api/collections/posts/records \
  -H "Authorization: $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"author\": \"$ME\", \"title\": \"Fikadags\", \"body\": \"Kanelbullar i fikarummet!\"}"
```

Svaret är den skapade posten med nytt `id`, `created` och `updated`.

### Ändra

Skicka bara de fält som ska ändras:

```bash
curl -s -X PATCH http://127.0.0.1:8090/api/collections/posts/records/INLAGGETS_ID \
  -H "Authorization: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"body": "Kanelbullar OCH kardemummabullar!"}'
```

### Ta bort

```bash
curl -s -X DELETE http://127.0.0.1:8090/api/collections/posts/records/INLAGGETS_ID \
  -H "Authorization: $TOKEN" -w "%{http_code}\n"
# 204
```

`204 No Content` betyder att det gick bra (det finns inget att skicka tillbaka).

### Gilla och följa

Att gilla ett inlägg är att *skapa* en post i `likes`. Att sluta gilla är att
*ta bort* den:

```bash
# Gilla
curl -s -X POST http://127.0.0.1:8090/api/collections/likes/records \
  -H "Authorization: $TOKEN" -H "Content-Type: application/json" \
  -d "{\"post\": \"INLAGGETS_ID\", \"user\": \"$ME\"}"

# Följ Bo
curl -s -X POST http://127.0.0.1:8090/api/collections/follows/records \
  -H "Authorization: $TOKEN" -H "Content-Type: application/json" \
  -d "{\"follower\": \"$ME\", \"following\": \"BOS_ID\"}"
```

### Filuppladdning

Filer skickas som `multipart/form-data` i stället för JSON:

```bash
curl -s -X POST http://127.0.0.1:8090/api/collections/posts/records \
  -H "Authorization: $TOKEN" \
  -F "author=$ME" -F "title=Dagens bröd" \
  -F "image=@brod.jpg"
```

Bilden hämtas sedan från
`/api/files/posts/<inläggets id>/<filnamn>`, och en miniatyr med
`?thumb=400x0`.

## Felsvar

Alla fel har samma form:

```json
{
  "status": 400,
  "message": "Failed to create record.",
  "data": {
    "title": { "code": "validation_required", "message": "Cannot be blank." }
  }
}
```

| Status | Betyder | Typisk orsak |
|--------|---------|--------------|
| `400` | Bad Request | Valideringsfel, felaktigt filter, create-regeln ej uppfylld, dubbel gillning |
| `401` | Unauthorized | Endpoint kräver inloggning men ingen/ogiltig token |
| `403` | Forbidden | Regeln är `null` (bara superusers) |
| `404` | Not Found | Posten finns inte – eller så får du inte se/ändra den |
| `429` | Too Many Requests | Rate limit (om påslaget, eller ditt eget spamskydd i kapitel 7) |

`data` innehåller fel per fält. Det är det appen ska visa vid formuläret.
Försöker Anna gilla samma inlägg två gånger ser `data` ut så här:

```json
{ "post": { "code": "validation_not_unique", "message": "Value must be unique." },
  "user": { "code": "validation_not_unique", "message": "Value must be unique." } }
```

## Query-parametrar för listor

| Parameter | Exempel | Betyder |
|-----------|---------|---------|
| `page` | `page=2` | Vilken sida (börjar på 1) |
| `perPage` | `perPage=50` | Poster per sida (standard 30, max 1000) |
| `sort` | `sort=-created,title` | Sortering. `-` = fallande. Flera fält med komma |
| `filter` | `filter=title ~ "kaffe"` | Villkor (se nedan) |
| `expand` | `expand=author,comments_via_post.author` | Hämta relaterade poster (kapitel 3) |
| `fields` | `fields=id,title,expand.author.username` | Bara vissa fält i svaret |
| `skipTotal` | `skipTotal=1` | Räkna inte totalt antal (snabbare). `totalItems` och `totalPages` blir `-1` |

### URL-kodning

Filter innehåller mellanslag, citattecken och `&&`. De måste URL-kodas. Låt
curl göra det med `-G` och `--data-urlencode`:

```bash
curl -s -G http://127.0.0.1:8090/api/collections/posts/records \
  -H "Authorization: $TOKEN" \
  --data-urlencode 'filter=title ~ "kaffe" || body ~ "kaffe"' \
  --data-urlencode 'sort=-created' \
  --data-urlencode 'expand=author' \
  --data-urlencode 'perPage=10'
```

`-G` gör att datan läggs i URL:en som en `GET`-fråga.

### Paginering

```
Totalt 95 inlägg, perPage=30

page=1  → poster  1–30
page=2  → poster 31–60
page=3  → poster 61–90
page=4  → poster 91–95   (totalPages = 4)
```

Appen hämtar sida 1, och när användaren scrollar ner hämtar den sida 2 osv.
`skipTotal=1` är bra för ett oändligt flöde: det sparar en `COUNT(*)`-fråga,
och man vet att man är klar när en sida har färre poster än `perPage`.

### Sortering

```
sort=-created            nyaste först (det vanliga för ett flöde)
sort=created             äldsta först (det vanliga för kommentarer)
sort=author.name,-created först författarens namn, sedan nyast
sort=@random             slumpordning
```

💡 **Tips:** Ange alltid `sort` för listor som visas för användaren. Utan
sortering garanterar databasen ingen ordning.

### Fields – hämta bara det du behöver

```
fields=id,title
fields=*,expand.author.username
fields=id,title,body:excerpt(100,true)
```

`:excerpt(100,true)` kortar ner texten till 100 tecken (utan HTML-taggar) och
lägger till `...`. Perfekt för ett flöde där hela texten visas först när man
klickar på inlägget.

## Filter-syntax

Filter använder **samma språk som API-reglerna** (kapitel 4), men skickas av
klienten och kan bara *begränsa* resultatet ytterligare – aldrig visa mer än
reglerna tillåter.

```
Slutligt resultat = poster där  (list-regel)  OCH  (ditt filter)
```

⚠️ **Varning:** `@request.*` (t.ex. `@request.auth.id`) får bara användas i
**regler**, inte i filter som klienten skickar. Försöker en vanlig användare
svarar PocketBase `403 Only superusers can filter by @request.`. Vill appen ha
"mina inlägg" skickar den sitt eget id som värde:
`author = "ryd2jdczusx4tm4"` (i Dart: `pb.filter('author = {:me}', {'me': myId})`).

### Operatorer

| Operator | Betyder | Exempel |
|----------|---------|---------|
| `=` | Lika med | `author.username = "bo"` |
| `!=` | Inte lika med | `website != ""` |
| `>` `>=` `<` `<=` | Jämförelse | `created >= @todayStart` |
| `~` | Innehåller (skiftlägesokänsligt för a–z) | `title ~ "kaffe"` |
| `!~` | Innehåller inte | `title !~ "test"` |
| `?=` `?!=` `?>` `?>=` `?<` `?<=` `?~` `?!~` | Minst ett element uppfyller | `likes_via_post.user ?= "..."` |
| `&&` | Och | `author.username = "bo" && title ~ "kaffe"` |
| `\|\|` | Eller | `title ~ "kaffe" \|\| body ~ "kaffe"` |
| `( )` | Gruppering | `(a = 1 \|\| b = 2) && c = 3` |

`~` lägger automatiskt till `%` runt värdet (`LIKE '%kaffe%'`). Vill du styra
själv, skriv `%` i värdet: `title ~ "Kaffe%"` betyder "börjar med Kaffe".

### Värden

| Typ | Skrivs | Exempel |
|-----|--------|---------|
| Text | Inom `"..."` eller `'...'` | `username = "anna"` |
| Tal | Som det är | `likes_count >= 2` (i en view, kapitel 8) |
| Bool | `true` / `false` | `emailVisibility = true` |
| Tomt | `""` | `image != ""` (har en bild) |
| Null | `null` | används för json-fält |
| Fält | Fältnamn utan citattecken | `updated > created` (har redigerats) |

### Exempel från Kvittra

```
# Inlägg som nämner kaffe i titel eller text
title ~ "kaffe" || body ~ "kaffe"

# Bos inlägg
author.username = "bo"

# Inlägg med bild
image != ""

# Inlägg som har redigerats
updated > created

# Användare som har en hemsida
website != ""

# Kommentarer till inlägg som Bo skrivit
post.author.username = "bo"            (på comments)
```

## Datum i filter

Datum lagras som text i UTC, `2026-10-15 08:00:00.000Z`. Eftersom formatet
sorterar rätt som text fungerar vanliga jämförelser:

```
# Inlägg från den 15 oktober (UTC)
created >= "2026-10-15 00:00:00" && created < "2026-10-16 00:00:00"

# Inlägg från och med 15 oktober
created >= "2026-10-15"
```

### Datum-makron

| Makro | Betyder (UTC) |
|-------|---------------|
| `@now` | Just nu |
| `@todayStart` / `@todayEnd` | Dagens början / slut |
| `@yesterday` / `@tomorrow` | Samma klockslag igår / imorgon |
| `@monthStart` / `@monthEnd` | Månadens början / slut |
| `@yearStart` / `@yearEnd` | Årets början / slut |
| `@second`, `@minute`, `@hour`, `@weekday`, `@day`, `@month`, `@year` | Delar av nuvarande tid, som tal |

```
# Inlägg från idag
created >= @todayStart

# Inlägg från det senaste dygnet
created >= @yesterday

# Gillningar denna månad
created >= @monthStart          (på likes)
```

Du kan också använda SQLite-funktionen `strftime`:

```
# Inlägg i oktober 2026
strftime('%Y-%m', created) = "2026-10"
```

⚠️ **Varning:** Allt är i **UTC**. `@todayStart` är midnatt UTC, vilket är
kl. 02:00 svensk sommartid (01:00 vintertid). Ett inlägg skrivet kl. 00:30
svensk tid den 15 oktober ligger alltså den 14 oktober i UTC. För exakta
"dagens inlägg i Sverige" ska appen räkna ut start och slut på dygnet i lokal
tid, konvertera till UTC och skicka som vanliga datumvärden. Dart-SDK:n
hjälper till med det (kapitel 6).

## Flödet och andra filter över kopplingar

De mest användbara filtren i en social app går via kopplings-collections. Här
är de viktigaste – alla testade mot testdatan i lösningarna (Annas id står som
`ANNAS_ID`):

```
# Flödet: inlägg från dem Anna följer
author.follows_via_following.follower ?= "ANNAS_ID"

# Inlägg som Anna har gillat
likes_via_post.user ?= "ANNAS_ID"

# Inlägg som Anna INTE har gillat (även de som ingen gillat)
likes_via_post.user != "ANNAS_ID"

# Inlägg utan kommentarer
comments_via_post.id = ""

# Användare som Anna följer (på users)
follows_via_following.follower ?= "ANNAS_ID"

# Ömsesidiga följare till Bo: följer Bo OCH följs av Bo (på users)
follows_via_follower.following ?= "BOS_ID" && follows_via_following.follower ?= "BOS_ID"
```

Hur ska man läsa `=` och `!=` när vänstersidan ger **flera** värden?

| Skrivsätt | Betyder | Exempel |
|-----------|---------|---------|
| `x ?= v` | **minst en** är `v` | gillad av Anna |
| `x = v` | **alla** är `v` | (sällan det du vill – se varningen i kapitel 3) |
| `x != v` | **ingen** är `v` | inte gillad av Anna |

Flödet i curl:

```bash
curl -s -G http://127.0.0.1:8090/api/collections/posts/records \
  -H "Authorization: $TOKEN" \
  --data-urlencode "filter=author.follows_via_following.follower ?= \"$ME\"" \
  --data-urlencode 'sort=-created' \
  --data-urlencode 'expand=author' \
  --data-urlencode 'skipTotal=1'
```

💡 **Tips:** Vill du ta med Annas egna inlägg i flödet? Lägg till
`|| author = "ANNAS_ID"`. Och kom ihåg: skicka id:t som ett **värde** – inte
`@request.auth.id`, som är förbjudet i klientens filter.

⚠️ **Varning:** Filterspråket kan inte **räkna**. "Inlägg med minst 10
gillningar" eller "sortera på antal gillningar" går inte att uttrycka med ett
filter på `posts` (det finns ingen `COUNT`). Lösningen är en view-collection
med `likes_count` som du kan filtrera och sortera på – den bygger vi i övning 7
och kapitel 8.

## Realtid

Tänk dig att Anna och Bo båda tittar på samma inlägg. Anna skriver en
kommentar. Hur får Bos skärm veta det?

**Polling** (fråga var femte sekund) fungerar men är slösaktigt. PocketBase har
i stället **realtid** via *Server-Sent Events* (SSE): en HTTP-anslutning som
hålls öppen och där servern skickar händelser när något ändras.

```
Bos app                               PocketBase                       Annas app
   │ GET /api/realtime (hålls öppen)      │                                │
   │ ◄──── PB_CONNECT {clientId}          │                                │
   │ POST /api/realtime                   │                                │
   │   {clientId, subscriptions:          │                                │
   │    ["comments/*"]}                   │                                │
   │                                      │ ◄──── POST /comments/records ──│
   │ ◄──── comments/* {action:"create",   │                                │
   │        record:{...}}                 │                                │
```

### Prova med curl

Terminal 1 – öppna anslutningen:

```bash
curl -N http://127.0.0.1:8090/api/realtime
```

```
id:BdRLaggYdVrv4DCy0fm71kW7M5HyYjd42tyfIxdP
event:PB_CONNECT
data:{"clientId":"BdRLaggYdVrv4DCy0fm71kW7M5HyYjd42tyfIxdP"}
```

Terminal 2 – prenumerera (byt ut clientId). Svaret är `204`:

```bash
curl -s -X POST http://127.0.0.1:8090/api/realtime \
  -H "Authorization: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"clientId":"BdRLaggYdVrv4DCy0fm71kW7M5HyYjd42tyfIxdP","subscriptions":["comments/*"]}'
```

Skapa sedan en kommentar (från terminal 2 eller Dashboard). I terminal 1 dyker
det upp:

```
event:comments/*
data:{"record":{"author":"ovwg8fdd7tfdfey","body":"Realtid!","id":"bnl6d5swobpmuvh","post":"jecocasqaz8ls35",...},"action":"create"}
```

### Ämnen (topics)

| Topic | Händelser för |
|-------|---------------|
| `comments/*` | Alla poster i `comments` som du får se |
| `comments/bnl6d5swobpmuvh` | En enskild post |

`action` är `create`, `update` eller `delete`.

⚠️ **Varning:** Realtid följer reglerna. Med `*` gäller **List**-regeln och
med ett id gäller **View**-regeln. Anna får alltså inga händelser om poster
hon inte får se. View-collections skickar inga realtidshändelser alls.

💡 **Tips:** I praktiken skriver du aldrig den här koden själv. Dart-SDK:n
sköter anslutning, prenumeration och återanslutning med ett enda anrop – och
kan dessutom filtrera, så att appen bara får kommentarer till *det* inlägg som
visas: `pb.collection('comments').subscribe('*', ..., filter: ...)`. Se
kapitel 6.

## Sammanfattning

- Varje collection får fem endpoints: list, view, create, update, delete.
- Token skickas i `Authorization`-headern.
- Listor är paginerade: `page`, `perPage`, `skipTotal`.
- `filter` använder samma språk som reglerna och kan bara begränsa mer.
- Flödet: `author.follows_via_following.follower ?= "<mitt id>"`. Använd
  `?=` för "minst en" och `!=` för "ingen".
- `sort`, `expand` och `fields` styr ordning, relationer och svarsstorlek.
- Datum är UTC-text. Använd makron som `@now` och `@todayStart`.
- Realtid via SSE: prenumerera på `collection/*` eller `collection/id`.

Nästa kapitel: [Dart-SDK](06-dart-sdk.md).

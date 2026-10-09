# 05 – REST-API och filter

Allt du gjort i Dashboard går också att göra över HTTP. Det är så Flutter-appen
pratar med PocketBase. I det här kapitlet använder vi `curl` för att se exakt
vad som skickas och tas emot. När du sedan använder Dart-SDK:n (kapitel 6) vet
du vad som händer under huven.

## REST i korthet

REST betyder att varje "sak" har en adress (URL), och att HTTP-metoden säger vad
du vill göra med den.

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

💡 **Tips:** Har du `jq` installerat kan du i stället skriva
`| jq -r .token`. På Windows fungerar exemplen i Git Bash eller WSL.

## CRUD med curl

### Lista

```bash
curl -s http://127.0.0.1:8090/api/collections/resources/records \
  -H "Authorization: $TOKEN"
```

```json
{
  "page": 1,
  "perPage": 30,
  "totalItems": 2,
  "totalPages": 1,
  "items": [
    { "id": "yj5nd2n7f6ckups", "collectionName": "resources", "name": "Tvättstuga 1",
      "max_hours": 3, "active": true, "created": "2026-10-09 07:27:06.356Z", ... },
    { "id": "tjw76ww0o045edu", "name": "Festlokalen", ... }
  ]
}
```

Svaret är alltid **paginerat**: du får en sida (`page`) med högst `perPage`
poster, plus totalt antal.

### Hämta en

```bash
curl -s http://127.0.0.1:8090/api/collections/resources/records/yj5nd2n7f6ckups \
  -H "Authorization: $TOKEN"
```

### Skapa

```bash
curl -s -X POST http://127.0.0.1:8090/api/collections/bookings/records \
  -H "Authorization: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "resource": "yj5nd2n7f6ckups",
    "user": "flskfapcqwu5iun",
    "start": "2026-10-12 08:00:00.000Z",
    "end": "2026-10-12 10:00:00.000Z",
    "note": "Två maskiner"
  }'
```

Svaret är den skapade posten med nytt `id`, `created` och `updated`.

### Ändra

Skicka bara de fält som ska ändras:

```bash
curl -s -X PATCH http://127.0.0.1:8090/api/collections/bookings/records/awp65on7uxbw5nb \
  -H "Authorization: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"note": "Bara en maskin"}'
```

### Ta bort

```bash
curl -s -X DELETE http://127.0.0.1:8090/api/collections/bookings/records/awp65on7uxbw5nb \
  -H "Authorization: $TOKEN" -w "%{http_code}\n"
# 204
```

`204 No Content` betyder att det gick bra (det finns inget att skicka tillbaka).

### Filuppladdning

Filer skickas som `multipart/form-data` i stället för JSON:

```bash
curl -s -X POST http://127.0.0.1:8090/api/collections/posts/records \
  -H "Authorization: $TOKEN" \
  -F "title=Städdag" -F "author=<ditt id>" -F "published=true" \
  -F "image=@stadning.jpg"
```

(Förutsätter att `posts` har ett file-fält `image`.)

## Felsvar

Alla fel har samma form:

```json
{
  "status": 400,
  "message": "Failed to create record.",
  "data": {
    "start": { "code": "validation_required", "message": "Cannot be blank." }
  }
}
```

| Status | Betyder | Typisk orsak |
|--------|---------|--------------|
| `400` | Bad Request | Valideringsfel, felaktigt filter, create-regeln ej uppfylld |
| `401` | Unauthorized | Endpoint kräver inloggning men ingen/ogiltig token |
| `403` | Forbidden | Regeln är `null` (bara superusers) |
| `404` | Not Found | Posten finns inte – eller så får du inte se/ändra den |
| `429` | Too Many Requests | Rate limit (om påslaget) |

`data` innehåller fel per fält. Det är det appen ska visa vid formuläret.

## Query-parametrar för listor

| Parameter | Exempel | Betyder |
|-----------|---------|---------|
| `page` | `page=2` | Vilken sida (börjar på 1) |
| `perPage` | `perPage=50` | Poster per sida (standard 30, max 1000) |
| `sort` | `sort=-start,created` | Sortering. `-` = fallande. Flera fält med komma |
| `filter` | `filter=active=true` | Villkor (se nedan) |
| `expand` | `expand=resource,user.apartment` | Hämta relaterade poster (kapitel 3) |
| `fields` | `fields=id,name,expand.resource.name` | Bara vissa fält i svaret |
| `skipTotal` | `skipTotal=1` | Räkna inte totalt antal (snabbare). `totalItems` blir `-1` |

### URL-kodning

Filter innehåller mellanslag, citattecken och `&&`. De måste URL-kodas. Låt
curl göra det med `-G` och `--data-urlencode`:

```bash
curl -s -G http://127.0.0.1:8090/api/collections/bookings/records \
  -H "Authorization: $TOKEN" \
  --data-urlencode 'filter=start >= @todayStart && resource.name ~ "Tvätt"' \
  --data-urlencode 'sort=start' \
  --data-urlencode 'expand=resource' \
  --data-urlencode 'perPage=10'
```

`-G` gör att datan läggs i URL:en som en `GET`-fråga.

### Paginering

```
Totalt 95 bokningar, perPage=30

page=1  → poster  1–30
page=2  → poster 31–60
page=3  → poster 61–90
page=4  → poster 91–95   (totalPages = 4)
```

Appen hämtar sida 1, och när användaren scrollar ner hämtar den sida 2 osv.
`skipTotal=1` är bra för oändlig scroll: det sparar en `COUNT(*)`-fråga, och
man vet att man är klar när en sida har färre poster än `perPage`.

### Sortering

```
sort=start               stigande starttid (tidigast först)
sort=-created            senast skapade först
sort=resource.name,start först resursnamn, sedan starttid
sort=@random             slumpordning
```

💡 **Tips:** Ange alltid `sort` för listor som visas för användaren. Utan
sortering garanterar databasen ingen ordning.

### Fields – hämta bara det du behöver

```
fields=id,name
fields=*,expand.resource.name
fields=id,title,body:excerpt(200,true)
```

`:excerpt(200,true)` kortar ner texten till 200 tecken (utan HTML-taggar) och
lägger till `...`. Perfekt för en lista med anslag där hela texten visas först
när man klickar.

## Filter-syntax

Filter använder **samma språk som API-reglerna** (kapitel 4), men skickas av
klienten och kan bara *begränsa* resultatet ytterligare – aldrig visa mer än
reglerna tillåter.

```
Slutligt resultat = poster där  (list-regel)  OCH  (ditt filter)
```

⚠️ **Varning:** `@request.*` (t.ex. `@request.auth.id`) får bara användas i
**regler**, inte i filter som klienten skickar. Försöker en vanlig användare
svarar PocketBase `403 Only superusers can filter by @request`. Vill appen ha
"mina bokningar" skickar den sitt eget id som värde:
`user = "flskfapcqwu5iun"` (i Dart: `pb.filter('user = {:me}', {'me': myId})`).

### Operatorer

| Operator | Betyder | Exempel |
|----------|---------|---------|
| `=` | Lika med | `active = true` |
| `!=` | Inte lika med | `role != "member"` |
| `>` `>=` `<` `<=` | Jämförelse | `max_hours >= 4` |
| `~` | Innehåller (skiftlägesokänsligt för a–z) | `name ~ "tvätt"` |
| `!~` | Innehåller inte | `title !~ "test"` |
| `?=` `?!=` `?>` `?>=` `?<` `?<=` `?~` `?!~` | Minst ett element uppfyller | `tags.name ?= "fest"` |
| `&&` | Och | `active = true && max_hours > 2` |
| `\|\|` | Eller | `role = "styrelse" \|\| role = "admin"` |
| `( )` | Gruppering | `(a = 1 \|\| b = 2) && c = 3` |

`~` lägger automatiskt till `%` runt värdet (`LIKE '%tvätt%'`). Vill du styra
själv, skriv `%` i värdet: `name ~ "Tvätt%"` betyder "börjar med Tvätt".

### Värden

| Typ | Skrivs | Exempel |
|-----|--------|---------|
| Text | Inom `"..."` eller `'...'` | `name = "Festlokalen"` |
| Tal | Som det är | `floor >= 2` |
| Bool | `true` / `false` | `published = true` |
| Tomt | `""` | `note != ""` (har en anteckning) |
| Null | `null` | används för json-fält |
| Fält | Fältnamn utan citattecken | `end > start` |

### Exempel från Föreningsappen

```
# Aktiva resurser
active = true

# Publicerade anslag som nämner "städdag" i titel eller text
published = true && (title ~ "städdag" || body ~ "städdag")

# Lägenheter på våning 2–4 som är större än 60 kvm
floor >= 2 && floor <= 4 && size_sqm > 60

# Styrelsemedlemmar
role = "styrelse"

# Bokningar som har en anteckning
note != ""

# Bokningar gjorda av någon i lägenhet 1001
user.apartment.number = "1001"
```

## Datum i filter

Datum lagras som text i UTC, `2026-10-12 08:00:00.000Z`. Eftersom formatet
sorterar rätt som text fungerar vanliga jämförelser:

```
# Alla bokningar den 12 oktober (UTC)
start >= "2026-10-12 00:00:00" && start < "2026-10-13 00:00:00"

# Bokningar från och med 12 oktober
start >= "2026-10-12"
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
# Kommande bokningar
start >= @now

# Pågående bokningar just nu
start <= @now && end > @now

# Anslag skapade denna månad
created >= @monthStart
```

Du kan också använda SQLite-funktionen `strftime`:

```
# Bokningar i oktober 2026
strftime('%Y-%m', start) = "2026-10"
```

⚠️ **Varning:** Allt är i **UTC**. `@todayStart` är midnatt UTC, vilket är
kl. 02:00 svensk sommartid (01:00 vintertid). En bokning kl. 00:30 svensk tid
den 12 oktober ligger alltså den 11 oktober i UTC. För exakta "dagens
bokningar i Sverige" ska appen räkna ut start och slut på dygnet i lokal tid,
konvertera till UTC och skicka som vanliga datumvärden. Dart-SDK:n hjälper till
med det (kapitel 6).

## Överlappande tider – ett klassiskt filter

Hur hittar man bokningar som krockar med en ny bokning `[ny_start, ny_slut)`?
Två intervall överlappar om **det ena börjar innan det andra slutar, och slutar
efter att det andra börjat**:

```
          ny_start            ny_slut
              │                  │
   ───────────[══════════════════)──────────────
   [═══════)                                       ingen krock (slutar innan)
          [════════)                               KROCK
                    [══════)                       KROCK
                          [══════════════)         KROCK
                                 [════════)        ingen krock (börjar när ny slutar)
```

```
resource = "yj5nd2n7f6ckups" && start < "2026-10-12 11:00:00" && end > "2026-10-12 09:00:00"
```

Kommer den tillbaka med `totalItems > 0` är tiden upptagen. Vi använder exakt
detta villkor i en hook i kapitel 7 – för att kontrollen måste göras på
servern, inte bara i appen.

## Realtid

Tänk dig att Anna och Bo båda tittar på tvättstugans kalender. Anna bokar
10–12. Hur får Bos skärm veta det?

**Polling** (fråga var femte sekund) fungerar men är slösaktigt. PocketBase har
i stället **realtid** via *Server-Sent Events* (SSE): en HTTP-anslutning som
hålls öppen och där servern skickar händelser när något ändras.

```
Bos app                               PocketBase                       Annas app
   │ GET /api/realtime (hålls öppen)      │                                │
   │ ◄──── PB_CONNECT {clientId}          │                                │
   │ POST /api/realtime                   │                                │
   │   {clientId, subscriptions:          │                                │
   │    ["bookings/*"]}                   │                                │
   │                                      │ ◄──── POST /bookings/records ──│
   │ ◄──── bookings/* {action:"create",   │                                │
   │        record:{...}}                 │                                │
```

### Prova med curl

Terminal 1 – öppna anslutningen:

```bash
curl -N http://127.0.0.1:8090/api/realtime
```

```
id:cBHE9Vri8J2MpPwGEe4n1sEFHaJqZFiOU5TF68vw
event:PB_CONNECT
data:{"clientId":"cBHE9Vri8J2MpPwGEe4n1sEFHaJqZFiOU5TF68vw"}
```

Terminal 2 – prenumerera (byt ut clientId):

```bash
curl -s -X POST http://127.0.0.1:8090/api/realtime \
  -H "Authorization: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"clientId":"cBHE9Vri8J2MpPwGEe4n1sEFHaJqZFiOU5TF68vw","subscriptions":["bookings/*"]}'
```

Skapa sedan en bokning (från terminal 2 eller Dashboard). I terminal 1 dyker
det upp:

```
event:bookings/*
data:{"record":{"id":"6lsba2w1dz84gbt","resource":"yj5nd2n7f6ckups",...},"action":"create"}
```

### Ämnen (topics)

| Topic | Händelser för |
|-------|---------------|
| `bookings/*` | Alla poster i `bookings` som du får se |
| `bookings/awp65on7uxbw5nb` | En enskild post |

`action` är `create`, `update` eller `delete`.

⚠️ **Varning:** Realtid följer reglerna. Med `*` gäller **List**-regeln och
med ett id gäller **View**-regeln. Anna får alltså inga händelser om Bos
bokningar om reglerna säger att hon inte får se dem. View-collections skickar
inga realtidshändelser alls.

💡 **Tips:** I praktiken skriver du aldrig den här koden själv. Dart-SDK:n
sköter anslutning, prenumeration och återanslutning med ett enda anrop:
`pb.collection('bookings').subscribe('*', ...)`. Se kapitel 6.

## Sammanfattning

- Varje collection får fem endpoints: list, view, create, update, delete.
- Token skickas i `Authorization`-headern.
- Listor är paginerade: `page`, `perPage`, `skipTotal`.
- `filter` använder samma språk som reglerna och kan bara begränsa mer.
- `sort`, `expand` och `fields` styr ordning, relationer och svarsstorlek.
- Datum är UTC-text. Använd makron som `@now` och `@todayStart`.
- Realtid via SSE: prenumerera på `collection/*` eller `collection/id`.

Nästa kapitel: [Dart-SDK](06-dart-sdk.md).

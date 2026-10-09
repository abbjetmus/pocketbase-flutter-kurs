# 03 – Relationer

I [modul 01](../01-databaser/04-databasdesign.md) lärde du dig att koppla ihop
tabeller med främmande nycklar och `JOIN`. I PocketBase gör man samma sak med
fälttypen **relation**. I det här kapitlet går vi igenom hur relationsfält
fungerar, hur man modellerar 1:N och N:M, och hur man hämtar relaterad data med
`expand`.

## Relationsfältet

Ett relationsfält sparar **id:t** (eller id:na) för poster i en annan
collection. Det är samma idé som en främmande nyckel.

```
bookings                              resources
┌────────────────┬──────────────────┐ ┌─────────────────┬───────────────┐
│ id             │ resource         │ │ id              │ name          │
├────────────────┼──────────────────┤ ├─────────────────┼───────────────┤
│ awp65on7uxbw5nb│ yj5nd2n7f6ckups ─┼─┼►yj5nd2n7f6ckups │ Tvättstuga 1  │
│ n1stp7rywikrrzx│ yj5nd2n7f6ckups ─┼─┘                 │               │
│ e0hrorpht8i9gly│ tjw76ww0o045edu ─┼──►tjw76ww0o045edu │ Festlokalen   │
└────────────────┴──────────────────┘ └─────────────────┴───────────────┘
```

### Inställningar

| Inställning | Betydelse |
|-------------|-----------|
| **Collection** | Vilken collection fältet pekar på. Kan inte ändras efteråt. |
| **Max select** | `1` = enkel relation (värdet är en sträng). Större än 1 = multi-relation (värdet är en lista). |
| **Min select** | Minsta antal (bara för multi). |
| **Nonempty** (`required`) | Minst en relation måste anges. |
| **Cascade delete** | Om den refererade posten tas bort, tas även *den här* posten bort (enkel relation) eller id:t bort ur listan (multi). |

I Dashboard visas Max select som valet **Single** / **Multiple** när du skapar
fältet.

### Enkel eller multi – hur ser datan ut?

```json
// Enkel relation (maxSelect = 1)
{ "resource": "yj5nd2n7f6ckups" }

// Multi-relation (maxSelect > 1)
{ "tags": ["v37ggynko5xjo8w", "pyl9q3pev7kbrey"] }
```

I SQLite blir en enkel relation en `TEXT`-kolumn och en multi-relation en
`JSON`-kolumn som innehåller en lista:

```sql
`resource` TEXT DEFAULT '' NOT NULL
`tags`     JSON DEFAULT '[]' NOT NULL
```

### Cascade delete – vad ska hända när något tas bort?

Tänk igenom varje relation i Föreningsappen:

| Relation | Om den refererade posten tas bort... | Cascade delete? |
|----------|--------------------------------------|-----------------|
| `bookings.resource` → resources | Bokningar av en borttagen resurs är meningslösa | **Ja** |
| `bookings.user` → users | En medlem som flyttar – bokningarna kan försvinna | **Ja** |
| `users.apartment` → apartments | Lägenheter tas sällan bort. Medlemmar ska inte raderas för det | **Nej** |
| `posts.author` → users | Anslaget ska finnas kvar även om skribenten flyttar | **Nej** |

⚠️ **Varning:** Om cascade delete är **av** och relationen är **required**
(t.ex. `posts.author`) kan du inte ta bort en användare som har skrivit
anslag – PocketBase vägrar, eftersom anslagen då skulle peka på något som inte
finns. Det är samma beteende som `ON DELETE RESTRICT` i SQL. Det är oftast vad
du vill, men det är bra att veta när du får felet.

## 1:N – en till många

Den vanligaste relationen. En resurs har många bokningar, men varje bokning
gäller exakt en resurs.

```
resources 1 ──────< * bookings
          (en)        (många)
```

Regel: **relationsfältet ligger på "många"-sidan**. Precis som i SQL: det är
`bookings` som har kolumnen `resource`, inte `resources` som har en lista med
bokningar.

Föreningsappens 1:N-relationer:

| "Ett" | "Många" | Fält (på många-sidan) |
|-------|---------|-----------------------|
| apartments | users | `users.apartment` |
| resources | bookings | `bookings.resource` |
| users | bookings | `bookings.user` |
| users | posts | `posts.author` |

### Steg för steg: lägg till `bookings` i Dashboard

1. **+ New collection** → Base → namn `bookings`.
2. **+ New field** → **Relation**. Namn: `resource`. Collection: `resources`.
   Välj **Single**. Öppna kugghjulet: kryssa i **Nonempty** och
   **Cascade delete**.
3. **+ New field** → **Relation**. Namn: `user`. Collection: `users`. Single,
   Nonempty, Cascade delete.
4. **+ New field** → **DateTime**. Namn: `start`. Nonempty.
5. **+ New field** → **DateTime**. Namn: `end`. Nonempty.
6. **+ New field** → **Plain text**. Namn: `note`. Max length 500.
7. Under **Indexes**: lägg till `(resource, start)` och `(user)` (inte unique).
8. **Create**.

När du nu skapar en bokning i Dashboard får du en sökbar lista med resurser och
användare att välja bland i stället för att klistra in id:n.

💡 **Tips:** Kryssa i **Presentable** på `resources.name` och `users.name`. Då
visar Dashboard "Tvättstuga 1" i stället för `yj5nd2n7f6ckups` i listor.

## N:M – många till många

Ibland kan båda sidor ha många. Exempel:

- Ett **anslag** kan ha flera **taggar** ("tvätt", "fest"), och en tagg kan
  sitta på många anslag.
- En **aktivitet** (t.ex. städdag) kan ha många **deltagare**, och en medlem kan
  delta i många aktiviteter.

I modul 01 löste du det med en **kopplingstabell** (junction table). I
PocketBase finns två sätt.

### Sätt 1: Multi-relation

Lägg ett relationsfält med **Multiple** på ena sidan:

```
posts                         tags
┌──────┬────────────────────┐ ┌──────┬────────────┐
│ id   │ tags (JSON-lista)  │ │ id   │ name       │
├──────┼────────────────────┤ ├──────┼────────────┤
│ p1   │ ["t1","t2"]        │ │ t1   │ tvätt      │
│ p2   │ ["t2"]             │ │ t2   │ fest       │
└──────┴────────────────────┘ └──────┴────────────┘
```

Lägga till och ta bort enstaka id:n utan att skicka hela listan görs med
modifierare på fältnamnet:

```json
{ "tags+": "t3" }          // lägg till sist
{ "+tags": "t3" }          // lägg till först
{ "tags-": ["t1", "t2"] }  // ta bort
```

### Sätt 2: Kopplings-collection

Skapa en egen collection som motsvarar kopplingstabellen:

```
events            event_attendees                  users
┌──────┐          ┌──────┬───────┬──────┬────────┐ ┌──────┐
│ id   │ 1     *  │ id   │ event │ user │ status │ │ id   │
│ e1   │◄─────────│ a1   │ e1    │ u1   │ yes    │►│ u1   │
└──────┘          │ a2   │ e1    │ u2   │ maybe  │ │ u2   │
                  └──────┴───────┴──────┴────────┘ └──────┘
```

`event_attendees` har två enkla relationsfält (`event`, `user`) och ett unikt
index på `(event, user)` så att ingen kan anmäla sig två gånger.

### Vilket ska jag välja?

| | Multi-relation | Kopplings-collection |
|---|---|---|
| Enkelhet | ✅ Ett fält, inga extra collections | ❌ En extra collection |
| Extra data om kopplingen (t.ex. `status`, `created`) | ❌ Går inte | ✅ Hur mycket som helst |
| Vem får ändra? | Den som får ändra *posten* får ändra hela listan | Egna API-regler per koppling |
| Många kopplingar (hundratals+) | ❌ Listan blir stor och tung att uppdatera | ✅ Skalar bra |
| Realtid när någon anmäler sig | Hela posten uppdateras | En ny post skapas – tydligt event |
| Bra till | Taggar, kategorier, "ansvariga" (få, sällan ändrade) | Deltagare, medlemskap, röster, likes |

Tumregel: **Om kopplingen har egna egenskaper eller ändras av många olika
användare – använd en kopplings-collection.** Annars räcker multi-relation.

⚠️ **Varning:** Om alla medlemmar ska kunna anmäla sig till en aktivitet via
en multi-relation `events.attendees`, måste alla få **uppdatera** hela
`events`-posten. Då kan Anna också ta bort Bo från listan, eller ändra
aktivitetens titel. Med en kopplings-collection kan regeln i stället vara
"du får bara skapa och ta bort din egen anmälan".

## Expand – hämta relaterad data i samma anrop

När du hämtar en bokning får du bara id:t på resursen:

```json
{ "id": "awp65on7uxbw5nb", "resource": "yj5nd2n7f6ckups", "user": "flskfapcqwu5iun", ... }
```

Appen vill visa "Tvättstuga 1, bokad av Anna". I SQL hade du skrivit en `JOIN`.
I PocketBase lägger du till parametern **`expand`**:

```
GET /api/collections/bookings/records?expand=resource,user
```

```json
{
  "id": "awp65on7uxbw5nb",
  "resource": "yj5nd2n7f6ckups",
  "user": "flskfapcqwu5iun",
  "start": "2026-10-12 08:00:00.000Z",
  "end": "2026-10-12 10:00:00.000Z",
  "expand": {
    "resource": { "id": "yj5nd2n7f6ckups", "name": "Tvättstuga 1", "max_hours": 3, ... },
    "user":     { "id": "flskfapcqwu5iun", "name": "Anna", ... }
  }
}
```

Relationsfältet finns kvar som id, och de hela posterna läggs under `expand`.
För en multi-relation blir värdet under `expand` en **lista**.

### Nästlad expand

Vilken lägenhet bor Anna i? Följ relationerna med punkt:

```
?expand=resource,user.apartment
```

```
bookings ──resource──► resources
    │
    └──────user──────► users ──apartment──► apartments
```

```json
"expand": {
  "resource": { "name": "Tvättstuga 1", ... },
  "user": {
    "name": "Anna",
    "apartment": "hshivujvo83ear9",
    "expand": {
      "apartment": { "number": "1001", "floor": 1, ... }
    }
  }
}
```

Du kan gå upp till **6 nivåer** djupt.

⚠️ **Varning:** `expand` respekterar API-reglerna. Om Anna inte har rätt att
**visa** (view rule) en post så expanderas den helt enkelt inte – den saknas
under `expand` utan felmeddelande. Ser du ett tomt `expand`? Kontrollera
view-regeln på den collection du försöker expandera.

## Back-relationer – åt andra hållet

`bookings` pekar på `resources`. Men hur får man alla bokningar *för* en resurs
när man hämtar resursen? Resursen har ju inget fält som pekar på bokningarna.

Svaret är en **back-relation**, med syntaxen:

```
<collection som pekar hit>_via_<fältnamnet som pekar>
```

```
GET /api/collections/resources/records?expand=bookings_via_resource
```

```json
{
  "id": "yj5nd2n7f6ckups",
  "name": "Tvättstuga 1",
  "expand": {
    "bookings_via_resource": [
      { "id": "awp65on7uxbw5nb", "start": "2026-10-12 08:00:00.000Z", ... },
      { "id": "n1stp7rywikrrzx", "start": "2026-10-12 10:00:00.000Z", ... }
    ]
  }
}
```

Fler exempel i Föreningsappen:

| Från | Back-relation | Ger |
|------|---------------|-----|
| `users` | `bookings_via_user` | Alla bokningar medlemmen gjort |
| `users` | `posts_via_author` | Alla anslag medlemmen skrivit |
| `apartments` | `users_via_apartment` | Alla som bor i lägenheten |
| `tags` | `posts_via_tags` | Alla anslag med taggen (fungerar även för multi-relation) |

⚠️ **Varning:** Expand av back-relationer ger **max 1000 poster** per relation
och kan inte pagineras. Hämta alltså inte "alla bokningar någonsin" för en
resurs på det här sättet. Fråga i stället `bookings` direkt med ett filter och
paginering (kapitel 5).

## Filtrera över relationer

Punkt-notationen fungerar också i `filter` och `sort`. PocketBase gör
`JOIN`:en åt dig.

```
# Bokningar av resurser vars namn innehåller "Tvätt"
filter=resource.name ~ "Tvätt"

# Bokningar gjorda av någon som bor på våning 3
filter=user.apartment.floor = 3

# Sortera bokningar efter resursnamn, sedan starttid
sort=resource.name,start
```

Med back-relationer:

```
# Resurser som har minst en bokning med en anteckning som innehåller "tvätt"
GET /api/collections/resources/records?filter=bookings_via_resource.note ?~ "tvätt"

# Användare som har skrivit minst ett publicerat anslag
GET /api/collections/users/records?filter=posts_via_author.published ?= true
```

Operatorn `?=` betyder "**minst en** av dem är lika med". Den behövs när
vänstersidan kan ge flera värden: back-relationer och multi-relationer.

```
# Anslag som har taggen "fest" (multi-relation)
filter=tags.name ?= "fest"
```

Jämför: `tags.name = "fest"` betyder i praktiken "**alla** taggar heter fest",
vilket nästan aldrig är vad du vill. Mer om operatorer i kapitel 5.

## Ett komplett exempel

Bokningssidan i appen ska visa: "Tvättstuga 1 · 12 okt 10:00–12:00 · Anna
(lgh 1001)" för alla kommande bokningar i tvättstugor.

```
GET /api/collections/bookings/records
    ?filter=resource.name ~ "Tvätt" && start >= @now
    &sort=start
    &expand=resource,user.apartment
```

Ungefär motsvarande SQL:

```sql
SELECT b.*, r.*, u.*, a.*
FROM bookings b
JOIN resources r  ON r.id = b.resource
JOIN users u      ON u.id = b.user
JOIN apartments a ON a.id = u.apartment
WHERE r.name LIKE '%Tvätt%'
  AND b.start >= datetime('now')
  -- + listRule för bookings läggs till automatiskt
ORDER BY b.start;
```

🧪 **Prova själv:** Skapa två bokningar i Dashboard. Öppna sedan i webbläsaren
(inloggad som superuser i Dashboard räcker inte – använd curl med token från
kapitel 5, eller sätt list-regeln tillfälligt till tom sträng):

```
http://127.0.0.1:8090/api/collections/bookings/records?expand=resource,user
```

Vad händer om du stavar fel, t.ex. `expand=resurce`? (Svar: ingenting! Du
får inget fel, bara inget `expand`. Stavfel i expand är därför en vanlig
felkälla – kontrollera alltid stavningen först.)

## Sammanfattning

- Relationsfält lagrar id:n. **Single** = sträng, **Multiple** = lista.
- 1:N: fältet på "många"-sidan.
- N:M: multi-relation (enkelt) eller kopplings-collection (flexibelt).
- `cascadeDelete` styr vad som händer när den refererade posten försvinner.
- `expand=a,b.c` hämtar relaterade poster, upp till 6 nivåer.
- Back-relation: `bookings_via_resource`, max 1000 poster vid expand.
- Punkt-notation fungerar i filter och sort. Använd `?=` för "minst en".
- Expand och filter respekterar API-reglerna.

Nästa kapitel: [Autentisering och API-regler](04-autentisering-och-api-regler.md).

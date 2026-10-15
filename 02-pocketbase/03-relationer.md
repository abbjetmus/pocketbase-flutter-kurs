# 03 – Relationer

I [modul 01](../01-databaser/04-databasdesign.md) lärde du dig att koppla ihop
tabeller med främmande nycklar och `JOIN`. I PocketBase gör man samma sak med
fälttypen **relation**. I det här kapitlet går vi igenom hur relationsfält
fungerar, hur man modellerar 1:N och N:M – även N:M mot *samma* collection,
som när användare följer användare – och hur man hämtar relaterad data med
`expand`.

## Relationsfältet

Ett relationsfält sparar **id:t** (eller id:na) för poster i en annan
collection. Det är samma idé som en främmande nyckel.

```
comments                                  posts
┌─────────────────┬──────────────────┐   ┌─────────────────┬──────────────────────┐
│ id              │ post             │   │ id              │ title                │
├─────────────────┼──────────────────┤   ├─────────────────┼──────────────────────┤
│ c2ux8d0bp1kq5nm │ jecocasqaz8ls35 ─┼─┬─┼►jecocasqaz8ls35 │ Bästa kaffet i stan? │
│ m1kd8w3hq0v7trx │ jecocasqaz8ls35 ─┼─┘ │                 │                      │
│ x9tq2n5rw3zp0aa │ e0hrorpht8i9gly ─┼───┼►e0hrorpht8i9gly │ Surdegsbröd          │
└─────────────────┴──────────────────┘   └─────────────────┴──────────────────────┘
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
{ "post": "jecocasqaz8ls35" }

// Multi-relation (maxSelect > 1)
{ "tags": ["v37ggynko5xjo8w", "pyl9q3pev7kbrey"] }
```

I SQLite blir en enkel relation en `TEXT`-kolumn och en multi-relation en
`JSON`-kolumn som innehåller en lista:

```sql
`post` TEXT DEFAULT '' NOT NULL
`tags` JSON DEFAULT '[]' NOT NULL
```

### Cascade delete – vad ska hända när något tas bort?

Tänk igenom varje relation i Kvittra:

| Relation | Om den refererade posten tas bort... | Cascade delete? |
|----------|--------------------------------------|-----------------|
| `comments.post` → posts | Kommentarer till ett borttaget inlägg är meningslösa | **Ja** |
| `likes.post` → posts | Gillningar av ett borttaget inlägg likaså | **Ja** |
| `likes.user` → users | Gillningarna från en borttagen användare kan försvinna | **Ja** |
| `follows.follower` / `follows.following` → users | En följning mellan två personer kräver att båda finns | **Ja** (på båda) |
| `posts.author` → users | Inläggen ska inte försvinna i smyg – kontot anonymiseras i stället (kapitel 7) | **Nej** |
| `comments.author` → users | Samma resonemang som för inlägg | **Nej** |

⚠️ **Varning:** Om cascade delete är **av** och relationen är **required**
(t.ex. `posts.author`) kan du inte ta bort en användare som har skrivit
inlägg – PocketBase vägrar med
`Failed to delete record. Make sure that the record is not part of a required relation reference.`
Inläggen skulle ju annars peka på något som inte finns. Det är samma beteende
som `ON DELETE RESTRICT` i SQL. Det är oftast vad du vill, men det är bra att
veta när du får felet.

## 1:N – en till många

Den vanligaste relationen. Ett inlägg har många kommentarer, men varje
kommentar hör till exakt ett inlägg.

```
posts 1 ──────< * comments
      (en)        (många)
```

Regel: **relationsfältet ligger på "många"-sidan**. Precis som i SQL: det är
`comments` som har kolumnen `post`, inte `posts` som har en lista med
kommentarer.

Kvittras 1:N-relationer:

| "Ett" | "Många" | Fält (på många-sidan) |
|-------|---------|-----------------------|
| users | posts | `posts.author` |
| posts | comments | `comments.post` |
| users | comments | `comments.author` |

### Steg för steg: lägg till `posts` och `comments` i Dashboard

**posts:**

1. **+ New collection** → Base → namn `posts`.
2. **+ New field** → **Relation**. Namn: `author`. Collection: `users`.
   Välj **Single**. Öppna kugghjulet: kryssa i **Nonempty**, men **inte**
   Cascade delete.
3. **+ New field** → **Plain text**. Namn: `title`. Nonempty, Max length 200.
4. **+ New field** → **Plain text**. Namn: `body`. Max length 5000.
5. **+ New field** → **File**. Namn: `image`. Single, Max size `5242880`
   (5 MB), Mime types `image/jpeg`, `image/png`, `image/webp`,
   Thumb sizes `400x0`. Inte Nonempty – bilden är valfri.
6. Under **Indexes**: lägg till `(author)` och `(created)` (inte unique).
7. **Create**.

**comments:**

1. **+ New collection** → Base → namn `comments`.
2. **Relation** `post` → `posts`, Single, Nonempty, **Cascade delete**.
3. **Relation** `author` → `users`, Single, Nonempty, *inte* Cascade delete.
4. **Plain text** `body`, Nonempty, Max length 2000.
5. Index på `(post)`. **Create**.

När du nu skapar en kommentar i Dashboard får du en sökbar lista med inlägg och
användare att välja bland i stället för att klistra in id:n.

💡 **Tips:** Kryssa i **Presentable** på `users.username` och `posts.title`.
Då visar Dashboard "anna" och "Bästa kaffet i stan?" i stället för
`ryd2jdczusx4tm4` i listor.

## N:M – många till många

Ibland kan båda sidor ha många. I Kvittra finns två sådana relationer:

- En användare kan **gilla** många inlägg, och ett inlägg kan gillas av många
  användare.
- En användare kan **följa** många användare, och kan följas av många.

I modul 01 löste du det med en **kopplingstabell** (junction table). I
PocketBase finns två sätt.

### Sätt 1: Multi-relation

Lägg ett relationsfält med **Multiple** på ena sidan, t.ex. `posts.liked_by`:

```
posts                                   users
┌──────┬──────────────────────────────┐ ┌──────┬──────────┐
│ id   │ liked_by (JSON-lista)        │ │ id   │ username │
├──────┼──────────────────────────────┤ ├──────┼──────────┤
│ p1   │ ["u1","u3","u4"]             │ │ u1   │ anna     │
│ p4   │ ["u1"]                       │ │ u3   │ cecilia  │
└──────┴──────────────────────────────┘ └──────┴──────────┘
```

Lägga till och ta bort enstaka id:n utan att skicka hela listan görs med
modifierare på fältnamnet:

```json
{ "liked_by+": "u2" }          // lägg till sist
{ "+liked_by": "u2" }          // lägg till först
{ "liked_by-": ["u1", "u3"] }  // ta bort
```

### Sätt 2: Kopplings-collection

Skapa en egen collection som motsvarar kopplingstabellen:

```
posts               likes                               users
┌──────┐            ┌──────┬──────┬──────┬─────────┐    ┌──────┐
│ id   │ 1       *  │ id   │ post │ user │ created │ *  │ id   │
│ p1   │◄───────────│ l1   │ p1   │ u1   │ ...     │───►│ u1   │
│ p4   │            │ l2   │ p1   │ u3   │ ...     │    │ u3   │
└──────┘            │ l3   │ p4   │ u1   │ ...     │    └──────┘
                    └──────┴──────┴──────┴─────────┘
```

`likes` har två enkla relationsfält (`post`, `user`) och ett unikt index på
`(post, user)` så att ingen kan gilla samma inlägg två gånger.

### Vilket ska jag välja?

| | Multi-relation | Kopplings-collection |
|---|---|---|
| Enkelhet | ✅ Ett fält, inga extra collections | ❌ En extra collection |
| Extra data om kopplingen (t.ex. `created` – *när* gillade hon?) | ❌ Går inte | ✅ Hur mycket som helst |
| Vem får ändra? | Den som får ändra *posten* får ändra hela listan | Egna API-regler per koppling |
| Många kopplingar (hundratals+) | ❌ Listan blir stor och tung att uppdatera | ✅ Skalar bra |
| Realtid när någon gillar | Hela inlägget uppdateras | En ny post skapas – tydligt event |
| Bra till | Taggar, kategorier (få, sällan ändrade) | Gillningar, följningar, medlemskap, röster |

Tumregel: **Om kopplingen har egna egenskaper eller ändras av många olika
användare – använd en kopplings-collection.** Annars räcker multi-relation.

⚠️ **Varning:** Om alla ska kunna gilla via en multi-relation
`posts.liked_by`, måste alla få **uppdatera** hela `posts`-posten. Då kan Anna
också ta bort Cecilias gillning ur listan, eller ändra titeln på Bos inlägg.
Med en kopplings-collection kan regeln i stället vara "du får bara skapa och
ta bort din egen gillning". Därför använder Kvittra `likes`.

### N:M mot samma collection: `follows`

`follows` är också en kopplings-collection, men **båda** relationsfälten pekar
på `users`. Det kallas en *självrefererande* relation.

```
                    follows
users               ┌──────┬──────────┬───────────┐
┌──────┬─────────┐  │ id   │ follower │ following │
│ u1   │ anna    │◄─┤ f1   │ u1       │ u2        │   anna följer bo
│ u2   │ bo      │◄─┤ f2   │ u1       │ u3        │   anna följer cecilia
│ u3   │ cecilia │  │ f3   │ u2       │ u1        │   bo följer anna
│ u4   │ david   │  │ f4   │ u3       │ u2        │   cecilia följer bo
└──────┴─────────┘  │ f5   │ u4       │ u1        │   david följer anna
                    └──────┴──────────┴───────────┘
```

Läs varje rad som en mening: "**follower** följer **following**". Riktningen
spelar roll – att Anna följer Cecilia betyder inte att Cecilia följer Anna. Två
enkla relationsfält med tydliga namn är mycket lättare att förstå (och att
skriva regler för) än ett `users.following`-fält med en lista.

### Steg för steg: `likes` och `follows`

**likes:** Base, namn `likes`.

| Fält | Typ | Inställningar |
|------|-----|---------------|
| `post` | Relation → posts | Single, Nonempty, Cascade delete |
| `user` | Relation → users | Single, Nonempty, Cascade delete |

Ta bort fältet `updated` (en gillning ändras aldrig – den skapas eller tas
bort). Index: **unikt** på `(post, user)` och vanligt på `(user)`.

**follows:** Base, namn `follows`.

| Fält | Typ | Inställningar |
|------|-----|---------------|
| `follower` | Relation → users | Single, Nonempty, Cascade delete |
| `following` | Relation → users | Single, Nonempty, Cascade delete |

Ta bort `updated`. Index: **unikt** på `(follower, following)` och vanligt på
`(following)`.

🧪 **Prova själv:** Skapa en gillning för Anna på ett inlägg i Dashboard. Försök
skapa samma gillning igen. Vilket fel får du?

## Expand – hämta relaterad data i samma anrop

När du hämtar ett inlägg får du bara id:t på författaren:

```json
{ "id": "jecocasqaz8ls35", "author": "evw7k9240ep07xd", "title": "Bästa kaffet i stan?", ... }
```

Appen vill visa "Bästa kaffet i stan? – av Bo Berg". I SQL hade du skrivit en
`JOIN`. I PocketBase lägger du till parametern **`expand`**:

```
GET /api/collections/posts/records?expand=author
```

```json
{
  "id": "jecocasqaz8ls35",
  "author": "evw7k9240ep07xd",
  "title": "Bästa kaffet i stan?",
  "body": "Jag letar efter ett nytt favoritkafé. Tips?",
  "expand": {
    "author": { "id": "evw7k9240ep07xd", "username": "bo", "name": "Bo Berg", ... }
  }
}
```

Relationsfältet finns kvar som id, och de hela posterna läggs under `expand`.
För en multi-relation blir värdet under `expand` en **lista**.

### Nästlad expand

Till en kommentar vill vi visa både vem som skrev kommentaren och vem som skrev
inlägget. Följ relationerna med punkt:

```
GET /api/collections/comments/records?expand=author,post.author
```

```
comments ──author──► users
    │
    └──────post────► posts ──author──► users
```

```json
"expand": {
  "author": { "username": "anna", ... },
  "post": {
    "title": "Bästa kaffet i stan?",
    "author": "evw7k9240ep07xd",
    "expand": {
      "author": { "username": "bo", "name": "Bo Berg", ... }
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

`comments` pekar på `posts`. Men hur får man alla kommentarer *till* ett inlägg
när man hämtar inlägget? Inlägget har ju inget fält som pekar på
kommentarerna.

Svaret är en **back-relation**, med syntaxen:

```
<collection som pekar hit>_via_<fältnamnet som pekar>
```

```
GET /api/collections/posts/records/jecocasqaz8ls35?expand=author,comments_via_post.author
```

```json
{
  "title": "Bästa kaffet i stan?",
  "expand": {
    "author": { "name": "Bo Berg", ... },
    "comments_via_post": [
      { "body": "Testa kaféet vid torget!", "expand": { "author": { "username": "anna", ... } } },
      { "body": "Håller med Anna.",         "expand": { "author": { "username": "cecilia", ... } } }
    ]
  }
}
```

Ett anrop gav inlägget, författaren, alla kommentarer och varje kommentars
författare. Det är precis vad en "visa inlägg"-skärm behöver.

Back-relationerna i Kvittra:

| Från | Back-relation | Ger |
|------|---------------|-----|
| `posts` | `comments_via_post` | Inläggets kommentarer |
| `posts` | `likes_via_post` | Inläggets gillningar |
| `users` | `posts_via_author` | Alla inlägg användaren skrivit |
| `users` | `likes_via_user` | Alla gillningar användaren gjort |
| `users` | `follows_via_follower` | Följningar där användaren är *follower* = de hen **följer** |
| `users` | `follows_via_following` | Följningar där användaren är *following* = hens **följare** |

⚠️ **Varning:** Lätt att blanda ihop de två sista! Läs namnet bokstavligt:
`follows_via_following` = "rader i `follows` som pekar hit via fältet
`following`" = rader där den här användaren *blir följd*.

⚠️ **Varning:** Expand av back-relationer ger **max 1000 poster** per relation
och kan inte pagineras. Hämta alltså inte "alla gillningar någonsin" för ett
populärt inlägg på det här sättet. Fråga i stället `likes` direkt med ett filter
och paginering (kapitel 5), eller räkna i en view-collection (kapitel 8).

## Filtrera över relationer

Punkt-notationen fungerar också i `filter` och `sort`. PocketBase gör
`JOIN`:en åt dig.

```
# Inlägg skrivna av användaren "bo"
filter=author.username = "bo"

# Kommentarer till inlägg som Bo skrivit
filter=post.author.username = "bo"

# Sortera inlägg efter författarens namn, sedan nyast först
sort=author.name,-created
```

Med back-relationer:

```
# Inlägg som Anna har gillat
GET /api/collections/posts/records?filter=likes_via_post.user.username ?= "anna"

# Inlägg som Anna har kommenterat
GET /api/collections/posts/records?filter=comments_via_post.author.username ?= "anna"

# Användare som följer Bo (Bos följare)
GET /api/collections/users/records?filter=follows_via_follower.following.username ?= "bo"
```

Operatorn `?=` betyder "**minst en** av dem är lika med". Den behövs när
vänstersidan kan ge flera värden: back-relationer och multi-relationer.

### Flödet: inlägg från dem jag följer

Det viktigaste filtret i hela Kvittra. Följ kedjan steg för steg:

```
posts.author                          → inläggets författare (en user)
  .follows_via_following              → alla rader i follows där författaren blir följd
    .follower                         → vem som följer författaren
      ?= "<Annas id>"                 → minst en av dem är Anna
```

```
GET /api/collections/posts/records
    ?filter=author.follows_via_following.follower ?= "ryd2jdczusx4tm4"
    &sort=-created
    &expand=author
```

Med testdatan (Anna följer Bo och Cecilia) ger det Bos och Cecilias fyra
inlägg.

⚠️ **Varning:** Skriv `?=`, inte `=`. Med `=` betyder filtret i praktiken
"**alla** som följer författaren är Anna". Bo har två följare (Anna och
Cecilia), så hans inlägg försvinner – du får bara två av de fyra inläggen,
helt utan felmeddelande. Den sortens tysta fel är svåra att hitta, så testa
alltid filter mot data där det finns *flera* rader på många-sidan.

## Ett komplett exempel

Inläggssidan i appen ska visa: "Bästa kaffet i stan? · Bo Berg · gillad av
anna, cecilia, david · 2 kommentarer (med namn)".

```
GET /api/collections/posts/records/jecocasqaz8ls35
    ?expand=author,comments_via_post.author,likes_via_post.user
```

Ungefär motsvarande SQL (tre frågor, eftersom ett inlägg har *flera*
kommentarer och *flera* gillningar):

```sql
SELECT p.*, u.* FROM posts p JOIN users u ON u.id = p.author
WHERE p.id = 'jecocasqaz8ls35';

SELECT c.*, u.* FROM comments c JOIN users u ON u.id = c.author
WHERE c.post = 'jecocasqaz8ls35';

SELECT l.*, u.* FROM likes l JOIN users u ON u.id = l.user
WHERE l.post = 'jecocasqaz8ls35';
-- + view-/list-reglerna för varje collection läggs till automatiskt
```

🧪 **Prova själv:** Skapa ett par kommentarer och gillningar i Dashboard. Öppna
sedan i webbläsaren (inloggad som superuser i Dashboard räcker inte – använd
curl med token från kapitel 5, eller sätt list-reglerna på `posts`, `users` och
`comments` tillfälligt till tom sträng och **lås dem igen** efteråt):

```
http://127.0.0.1:8090/api/collections/posts/records?expand=author,comments_via_post.author
```

Vad händer om du stavar fel, t.ex. `expand=autor`? (Svar: ingenting! Du
får inget fel, bara inget `expand`. Stavfel i expand är därför en vanlig
felkälla – kontrollera alltid stavningen först. Ett stavfel i `filter` ger
däremot `400`.)

## Sammanfattning

- Relationsfält lagrar id:n. **Single** = sträng, **Multiple** = lista.
- 1:N: fältet på "många"-sidan (`posts.author`, `comments.post`).
- N:M: multi-relation (enkelt) eller kopplings-collection (flexibelt). Kvittra
  använder kopplings-collections: `likes` och den självrefererande `follows`.
- `cascadeDelete` styr vad som händer när den refererade posten försvinner.
- `expand=a,b.c` hämtar relaterade poster, upp till 6 nivåer.
- Back-relation: `comments_via_post`, max 1000 poster vid expand.
- Punkt-notation fungerar i filter och sort. Använd `?=` för "minst en" –
  flödet är `author.follows_via_following.follower ?= "<mitt id>"`.
- Expand och filter respekterar API-reglerna.

Nästa kapitel: [Autentisering och API-regler](04-autentisering-och-api-regler.md).

# 7. Hämta och lägga till data med Vue

Hittills har du bara använt Dashboard. Men en riktig app pratar med PocketBase
via dess **API**. I det här kapitlet gör du det från en liten webbapp skriven i
**Vue 3**.

Appen finns färdig i mappen [`kvittra-vue`](kvittra-vue/). Den har redan
paketet **`pocketbase`** installerat. Det är PocketBase eget JavaScript-paket
(en *SDK*) som sköter allt prat med servern. Du skriver all din kod i en enda
fil: `src/App.vue`.

## Steg 1 – Öppna API-reglerna tillfälligt

Från början är nästan alla collections **låsta** 🔒. Då får bara superusers läsa
och skriva, och Vue-appen är inte inloggad. Vi öppnar därför reglerna medan vi
testar.

Öppna kugghjulet på varje collection → fliken **API Rules**. Klicka på
hänglåset så att det låses upp, och låt textfältet vara **tomt**.

| Collection | Lås upp och lämna tomt | Låt vara låst 🔒 |
|------------|------------------------|-------------------|
| `posts` | List/Search, View, Create, Delete | Update |
| `comments` | List/Search, View, Create, Delete | Update |
| `likes` | List/Search, View, Create, Delete | Update |
| `follows` | List/Search, View | Create, Update, Delete |
| `users` | List/Search, View | Rör inte de andra |

💡 `users` är inte låst från början. List/Search och View har texten
`id = @request.auth.id`. **Sudda ut texten** så att fälten blir tomma.

⚠️ En tom regel betyder att **alla** får göra det. Det går bra på din egen dator
medan du testar, men så får det aldrig vara i en riktig app. I
[kapitel 9](09-inloggning-och-api-regler.md) byter du ut reglerna mot riktiga.

## Steg 2 – Starta Vue-projektet

Öppna Vue-projektet i VS Code, öppna en terminal (**Terminal → New Terminal**) och skriv:

```powershell
npm install
```

`npm install` laddar ner allt projektet behöver (Vue, PocketBase-paketet och
Vite) till mappen `node_modules`. Det behöver du bara göra en gång.

Starta sedan appen:

```powershell
npm run dev
```

Öppna adressen som visas i terminalen (oftast <http://localhost:5173>) i
webbläsaren.

Du ska se rubriken **Kvittra** och de fyra användarna anna, bertil, cissi och
david.

⚠️ **Två terminaler:** PocketBase (`.\pocketbase serve`) och Vue-appen
(`npm run dev`) ska vara igång samtidigt, i var sitt terminalfönster.

## Så fungerar App.vue

Öppna `src/App.vue`. Filen har tre delar:

| Del | Innehåller |
|-----|------------|
| `<script setup>` | JavaScript: hämtar och sparar data |
| `<template>` | HTML: det som visas på sidan |
| `<style>` | CSS: hur det ser ut |

Det viktigaste i `<script setup>`:

```js
import PocketBase from 'pocketbase'

const pb = new PocketBase('http://127.0.0.1:8090')

const users = ref([])

async function loadUsers() {
  users.value = await pb.collection('users').getFullList({ sort: 'username' })
}

onMounted(() => {
  loadUsers()
})
```

- `pb` är kopplingen till din PocketBase.
- `ref([])` skapar en variabel som Vue **håller koll på**. När den ändras ritas
  sidan om. I JavaScript läser och ändrar du den med `.value`.
- `pb.collection('users').getFullList()` hämtar alla records i `users`.
- `await` väntar på svaret från servern. Därför måste funktionen vara `async`.
- `onMounted` körs en gång när sidan har visats.

Och i `<template>`:

```html
<li v-for="user in users" :key="user.id">
  {{ user.username }} – {{ user.name }}
</li>
```

- `v-for` skapar ett `<li>` för varje användare i listan.
- `{{ ... }}` skriver ut ett värde på sidan.

💡 När du sparar filen uppdateras sidan i webbläsaren direkt.

## Så lägger du till en egen fråga

Varje gång gör du samma tre steg. Exempel: visa alla inlägg.

**1. Skapa en `ref` och en funktion** i `<script setup>`, under `loadUsers`:

```js
const posts = ref([])

async function loadPosts() {
  posts.value = await pb.collection('posts').getFullList()
}
```

**2. Anropa funktionen** i `onMounted`:

```js
onMounted(() => {
  loadUsers()
  loadPosts()
})
```

**3. Visa datan** i `<template>`:

```html
<h2>Inlägg</h2>
<ul>
  <li v-for="post in posts" :key="post.id">
    <strong>{{ post.title }}</strong> – {{ post.body }}
  </li>
</ul>
```

💡 **Se allt som kom tillbaka:** Skriv `<pre>{{ posts }}</pre>` i template. Då
visas hela svaret som JSON, och du ser exakt vilka fält som finns.

## Hämta data

### Fyra sätt att hämta

| Kod | Ger dig |
|-----|---------|
| `getFullList(options)` | **Alla** records, som en lista |
| `getList(page, perPage, options)` | **En sida** med records |
| `getOne(id, options)` | **En** record med ett visst id |
| `getFirstListItem(filter, options)` | Den **första** record som matchar filtret |

`getList` ger inte bara en lista, utan ett objekt:

```js
{
  page: 1,          // vilken sida
  perPage: 2,       // hur många per sida
  totalItems: 6,    // hur många det finns totalt
  totalPages: 3,    // hur många sidor det blir
  items: [ ... ]    // records på den här sidan
}
```

### Options – sortera, filtrera, ta med relationer

Alla fyra tar ett objekt med inställningar, `options`:

```js
await pb.collection('posts').getFullList({
  sort: '-created',
  filter: 'title ~ "bröd"',
  expand: 'author',
})
```

| Option | Gör | Exempel |
|--------|-----|---------|
| `sort` | Sorterar. `-` framför betyder fallande | `'-created'`, `'title'` |
| `filter` | Behåller bara records som matchar | `'title ~ "bröd"'` |
| `expand` | Tar med records som en relation pekar på | `'author'` |

### Filter

| Filter | Betyder |
|--------|---------|
| `title = "Matchdag"` | lika med |
| `title != "Matchdag"` | inte lika med |
| `title ~ "bröd"` | innehåller "bröd" |
| `created > "2025-01-01"` | större än (fungerar på datum och tal) |
| `bio = ""` | fältet är tomt |
| `&&`, `\|\|` | och, eller |

⚠️ Hela filtret är en text inom **enkla** citattecken `'...'`. Text **inne i**
filtret skrivs med **dubbla** citattecken `"..."`.

## Relationer med expand

I `posts` är `author` bara ett **id**:

```json
{
  "title": "Matchdag",
  "author": "k3jd8w1mz0q2xyz"
}
```

Med `expand: 'author'` hämtar PocketBase också användaren som id:t pekar på. Den
hamnar under `expand`:

```json
{
  "title": "Matchdag",
  "author": "k3jd8w1mz0q2xyz",
  "expand": {
    "author": {
      "username": "david",
      "name": "David Dahl"
    }
  }
}
```

I template skriver du:

```html
{{ post.title }} – {{ post.expand?.author?.name }}
```

💡 `?.` betyder "om det finns". Om `expand` saknas, t.ex. för att du glömde
`expand: 'author'`, visas ingenting i stället för att appen kraschar.

| Du vill | expand |
|---------|--------|
| Flera relationer | `'author,post'` (kommatecken, inga mellanslag) |
| En relation i en relation | `'post.author'` → `comment.expand.post.expand.author` |
| **Bakåt**: alla kommentarer på ett inlägg | `'comments_via_post'` |

### Bakåt-relationer

Relationen går från `comments` till `posts` (`comments.post`). Men ibland vill
man gå åt andra hållet: "ge mig inlägget **och** alla kommentarer som pekar på
det".

Det skrivs `comments_via_post`, alltså "de `comments` som pekar på mig via
fältet `post`".

```js
await pb.collection('posts').getFullList({ expand: 'comments_via_post' })
```

```html
{{ post.title }} har {{ post.expand?.comments_via_post?.length ?? 0 }} kommentarer
```

`?? 0` behövs eftersom `comments_via_post` saknas helt när ett inlägg inte har
några kommentarer.

### Filtrera via en relation

Du kan använda en punkt för att filtrera på ett fält i en relation:

```js
await pb.collection('posts').getFullList({ filter: 'author.username = "bertil"' })
```

Det ger bertils inlägg, utan att du behöver veta hans id.

## Lägga till data

Med `create` skapar du en ny record. Du skickar med ett objekt med fälten:

```js
await pb.collection('posts').create({
  author: 'k3jd8w1mz0q2xyz',   // id på en användare
  title: 'Hej Kvittra',
  body: 'Mitt första inlägg från Vue!',
})
```

För relationsfält skickar du **id:t** på den record det ska peka på.

### Ett formulär

Här är ett formulär för nya inlägg. Användarna från exemplet i `App.vue` används
för att välja författare.

```js
const newPost = ref({ author: '', title: '', body: '' })

async function createPost() {
  await pb.collection('posts').create(newPost.value)
  newPost.value = { author: '', title: '', body: '' }
  await loadPosts()   // hämta listan igen så att det nya inlägget syns
}
```

```html
<h2>Nytt inlägg</h2>
<form @submit.prevent="createPost">
  <select v-model="newPost.author">
    <option value="" disabled>Välj författare</option>
    <option v-for="user in users" :key="user.id" :value="user.id">
      {{ user.username }}
    </option>
  </select>
  <input v-model="newPost.title" placeholder="Rubrik" />
  <textarea v-model="newPost.body" placeholder="Text"></textarea>
  <button>Skicka</button>
</form>
```

- `v-model` kopplar ihop ett fält i formuläret med en `ref`. Skriver du i fältet
  ändras `newPost`.
- `:value="user.id"` gör att `newPost.author` får användarens **id**, men det
  som visas är användarnamnet.
- `@submit.prevent="createPost"` kör `createPost` när man klickar på knappen,
  utan att sidan laddas om.

💡 Händer ingenting när du klickar **Skicka**? Öppna konsolen (**F12**). Under
`response.data` står vilket fält som är fel, t.ex. att `title` inte får vara
tom.

⚠️ Just nu kan du välja **vilken** författare som helst, alltså skriva i någon
annans namn. Det stoppar vi med API-regler i kapitel 9.

### Ta bort

```js
await pb.collection('posts').delete(post.id)
```

## Sammanfattning

| Kod | Gör |
|-----|-----|
| `pb.collection('posts')` | Väljer collection |
| `getFullList({ ... })` | Hämtar alla records |
| `getList(1, 10, { ... })` | Hämtar en sida |
| `getOne(id)` | Hämtar en record via id |
| `getFirstListItem('username = "anna"')` | Hämtar första som matchar |
| `sort: '-created'` | Sorterar, nyast först |
| `filter: 'title ~ "bröd"'` | Filtrerar |
| `expand: 'author'` | Tar med en relation, hamnar i `record.expand.author` |
| `expand: 'comments_via_post'` | Tar med en bakåt-relation |
| `create({ ... })` | Skapar en record |
| `delete(id)` | Tar bort en record |

## Övningar

Skriv all kod i `src/App.vue`. Övningarna bygger vidare på varandra, så gör dem
i ordning. Lösningar finns i
[losningar.md](losningar.md#kapitel-7--hämta-och-lägga-till-data-med-vue).

💡 Händer ingenting? Öppna konsolen i webbläsaren (**F12** → **Console**). Där
står felet i rött.

### Hämta

**7.1** Lägg till `<pre>{{ users }}</pre>` i template. Nu ser du allt som kom
tillbaka för varje användare. Syns `email`?
*Svar: Nej. E-postadressen visas inte för andra.*

**7.2** Visa alla inlägg. Gör precis som i avsnittet
[Så lägger du till en egen fråga](#så-lägger-du-till-en-egen-fråga).
*Svar: 6 inlägg.*

**7.3** Sortera inläggen så att det **nyaste** kommer först. Ändra i
`loadPosts`:

```js
posts.value = await pb.collection('posts').getFullList({ sort: '-created' })
```

*Svar: Andra försöket överst, Höstpromenad nederst.*

**7.4** Visa bara inlägg vars rubrik innehåller "bröd". Lägg till ett `filter`
bredvid `sort`, inom samma `{ }`. Byt sedan "bröd" mot "bok".
*Svar: Mitt första surdegsbröd. Med "bok": Tips på en bra bok?*

Ta bort filtret igen innan du går vidare.

### Relationer

**7.5** Visa författarens namn efter varje rubrik.

1. Lägg till `expand: 'author'` i `loadPosts`.
2. Skriv `{{ post.expand?.author?.name }}` i ditt `<li>`.

*Svar: t.ex. "Matchdag – David Dahl".*

**7.6** Visa bara inläggen som `anna` har skrivit. Använd ett filter via
relationen, som i avsnittet [Filtrera via en relation](#filtrera-via-en-relation).
*Svar: Höstpromenad, Morgondimma.*

Ta bort filtret igen innan du går vidare.

**7.7** Visa hur många kommentarer varje inlägg har. Byt `expand` till
`'author,comments_via_post'` och skriv antalet i ditt `<li>`, som i avsnittet
[Bakåt-relationer](#bakåt-relationer).
*Svar: Höstpromenad 1, Mitt första surdegsbröd 2, Morgondimma 0, Tips på en bra
bok? 2, Matchdag 1, Andra försöket 0.*

**7.8** Visa alla kommentarer med text och användarnamnet på den som skrev
dem. Gör samma tre steg som för inläggen, men med `comments`:

```js
const comments = ref([])

async function loadComments() {
  comments.value = await pb.collection('comments').getFullList({ expand: 'author' })
}
```

Glöm inte att anropa `loadComments()` i `onMounted`, och att skriva en lista i
template.
*Svar: 6 kommentarer, t.ex. "Recept tack! – cissi".*

### Lägga till

**7.9** Kopiera formuläret från avsnittet [Ett formulär](#ett-formulär) till
din app: koden till `<script setup>` och HTML:en till `<template>`. Skapa ett
inlägg. Syns det i listan? Syns det i Dashboard?

**7.10** Gör ett formulär för nya **kommentarer**. Utgå från formuläret för
inlägg och ändra så här:

| Inlägg | Kommentar |
|--------|-----------|
| `newPost` | `newComment` |
| `{ author: '', title: '', body: '' }` | `{ post: '', author: '', body: '' }` |
| `createPost` | `createComment` |
| `pb.collection('posts')` | `pb.collection('comments')` |
| `loadPosts()` | `loadComments()` |
| `<input>` för rubrik | en `<select>` med alla inlägg (`v-for="post in posts"`) |

Skriv en kommentar. Syns den i listan från 7.8?

### Ta bort

**7.11** Lägg till en knapp **Ta bort** på varje inlägg.

```js
async function deletePost(post) {
  await pb.collection('posts').delete(post.id)
  await loadPosts()
}
```

```html
<button @click="deletePost(post)">Ta bort</button>
```

Knappen ska ligga **inne i** ditt `<li v-for="post in posts">`, annars vet den
inte vilket inlägg den ska ta bort. Ta bort inlägget du skapade i 7.9.

⚠️ **Viktigt:** SQL-övningarna i nästa kapitel räknar med **exakt** datan från
kapitel 6. Ta bort allt du har lagt till, även kommentarer och likes (det går
att göra i Dashboard). Jämför sedan med tabellen i
[kapitel 6](06-lagg-in-data.md#kontrollera).

### Utmaningar

De här är frivilliga, för dig som vill ha mer.

**7.12 Gilla.** Lägg till en knapp **Gilla** på varje inlägg som skapar en like
från `anna`. Visa antalet likes med `likes_via_post`. Vad händer om du gillar
samma inlägg två gånger? Varför?
Ledtråd: du behöver Annas id. Kopiera det från Dashboard.

**7.13 Sidor.** Ändra `loadPosts` så att den använder `getList` och hämtar
**två** inlägg per sida. Visa "Sida 1 av 3" och knapparna **Föregående** och
**Nästa**.

**7.14 Annas flöde.** Ändra `loadPosts` så att den bara visar inlägg från dem
som `anna` följer.
*Svar: Mitt första surdegsbröd (bertil), Tips på en bra bok? (cissi), Andra
försöket (bertil).*
Ledtråd: hämta först raderna i `follows` där `follower.username = "anna"`. Fältet
`following` innehåller id:n på dem hon följer.

Nästa kapitel: [SQL och View collections](08-sql-och-view-collections.md)

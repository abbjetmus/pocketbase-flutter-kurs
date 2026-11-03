# 7. Hämta och lägga till data med Vue

Hittills har du bara använt Dashboard. Men en riktig app pratar med PocketBase
via dess **API**. I det här kapitlet gör du det från en liten webbapp skriven i
**Vue 3**.

Appen finns färdig i mappen [`kvittra-vue`](kvittra-vue/). Den har redan
paketet **`pocketbase`** installerat. Det är PocketBase eget JavaScript-paket
(en *SDK*) som sköter allt prat med servern. Du skriver all din kod i en enda
fil: `src/App.vue`.

## Det här behöver du

- PocketBase med Kvittras data från [kapitel 6](06-lagg-in-data.md)
- [Node.js](https://nodejs.org/), version **22 eller senare** (välj **LTS**)
- [VS Code](https://code.visualstudio.com/)

Kontrollera att Node.js finns genom att skriva det här i en terminal:

```powershell
node -v
```

Du ska få ett versionsnummer, t.ex. `v22.12.0`.

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

1. Kopiera mappen `kvittra-vue` till din dator, t.ex. till `Dokument`.
2. Öppna mappen i VS Code (**File → Open Folder…**).
3. Öppna en terminal i VS Code (**Terminal → New Terminal**) och skriv:

```powershell
npm install
```

`npm install` laddar ner allt projektet behöver (Vue, PocketBase-paketet och
Vite) till mappen `node_modules`. Det behöver du bara göra en gång.

4. Starta appen:

```powershell
npm run dev
```

5. Öppna <http://localhost:5173> i webbläsaren.

Du ska se rubriken **Kvittra** och de fyra användarna anna, bertil, cissi och
david.

⚠️ **Två terminaler:** PocketBase (`.\pocketbase serve`) och Vue-appen
(`npm run dev`) ska vara igång samtidigt, i var sitt terminalfönster.

### Om det blir fel

Appen visar felet i en röd ruta. Hela felet syns i webbläsarens konsol
(**F12** → fliken **Console**).

| Du ser | Det betyder |
|--------|-------------|
| `Fel 0: Something went wrong.` | PocketBase är inte igång, eller adressen är fel |
| `Fel 403: Only superusers can perform this action.` | Regeln är fortfarande låst 🔒 |
| `Fel 404: ...` | Fel namn på collectionen, eller så finns inte recorden |
| `Fel 400: ...` | Fel i ett filter, eller i datan du försöker spara |
| Ingen röd ruta, men listan är tom | Regeln för `users` har kvar sin text. Sudda ut den |

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
  try {
    users.value = await pb.collection('users').getFullList({ sort: 'username' })
  } catch (e) {
    showError(e)
  }
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
- `try` / `catch` fångar fel, och `showError` visar dem i den röda rutan.
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

**1. Skapa en `ref`** under kommentaren `Skriv dina egna refs och funktioner här under`:

```js
const posts = ref([])

async function loadPosts() {
  try {
    posts.value = await pb.collection('posts').getFullList()
  } catch (e) {
    showError(e)
  }
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
  try {
    await pb.collection('posts').create(newPost.value)
    newPost.value = { author: '', title: '', body: '' }
    await loadPosts()   // hämta listan igen så att det nya inlägget syns
  } catch (e) {
    showError(e)
  }
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

💡 Får du `Fel 400: Failed to create record.`? Öppna konsolen (**F12**). Under
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

Skriv all kod i `src/App.vue`. Lösningar finns i
[losningar.md](losningar.md#kapitel-7--hämta-och-lägga-till-data-med-vue).

### Hämta

**7.1** Starta projektet och kontrollera att de fyra användarna syns. Lägg
sedan till `<pre>{{ users }}</pre>` i template. Vilka fält har en användare?
Syns `email` och `password`?
*Svar: Nej. Du ser bland annat `id`, `username`, `name`, `bio`, `website`,
`avatar`, `created` och `updated`, men inte `email` och `password`.*

**7.2** Visa alla inlägg med rubrik och text, **nyast först**.
*Svar: Andra försöket överst, Höstpromenad nederst (om du lade in dem i samma
ordning som i kapitel 6).*

**7.3** Visa bara de inlägg vars rubrik innehåller "bröd".
*Svar: Mitt första surdegsbröd.*

**7.4** Hämta **en** användare, `anna`, med `getFirstListItem` och visa hennes
namn och bio.
*Svar: Anna Andersson – Gillar promenader och foto.*

**7.5** Hämta inläggen med `getList`, **två per sida**, nyast först. Visa
"Sida 1 av 3" ovanför listan. Lägg till knapparna **Föregående** och **Nästa**
som byter sida.
*Svar: Sida 1 visar Andra försöket och Matchdag. Det finns 6 inlägg och 3
sidor.*

### Relationer

**7.6** Visa alla inlägg med rubrik och författarens **namn**.
*Svar: t.ex. "Matchdag – David Dahl".*

**7.7** Visa alla kommentarer med kommentarens text, användarnamnet på den som
skrev den **och** rubriken på inlägget den hör till.
*Svar: 6 rader, t.ex. "Recept tack! – cissi – Mitt första surdegsbröd".*

**7.8** Visa titlarna på alla inlägg som `anna` har skrivit. Använd ett filter
via relationen, inte hennes id.
*Svar: Höstpromenad, Morgondimma.*

**7.9** Visa varje inlägg med antal likes och antal kommentarer.
*Svar: Höstpromenad 2 / 1, Mitt första surdegsbröd 3 / 2, Morgondimma 0 / 0,
Tips på en bra bok? 0 / 2, Matchdag 1 / 1, Andra försöket 2 / 0.*
Ledtråd: bakåt-relationer.

### Lägga till

**7.10** Bygg formuläret för nya inlägg från avsnittet
[Ett formulär](#ett-formulär). Skapa ett inlägg och kontrollera att det syns
både i appen och i Dashboard. Vad händer om du skickar utan rubrik?

**7.11** Bygg ett formulär för nya **kommentarer**. Man ska välja inlägg och
författare i var sin lista och skriva en text. Kontrollera att antalet
kommentarer från 7.9 ökar.

**7.12** Lägg till en lista **"Jag är:"** överst där man väljer en användare,
och en knapp **Gilla** på varje inlägg. Knappen skapar en like för den valda
användaren. Vad händer om du gillar samma inlägg två gånger? Varför?

### Städa upp

**7.13** Lägg till en knapp **Ta bort** på varje inlägg som tar bort det. Ta
bort inläggen du skapade i 7.10. Vad hände med kommentarerna och likesen som
hörde till dem? Varför?

⚠️ **Viktigt:** SQL-övningarna i nästa kapitel räknar med **exakt** datan från
kapitel 6. Ta bort allt du har lagt till, även likes och kommentarer på de
gamla inläggen (det går att göra i Dashboard). Jämför sedan med tabellen i
[kapitel 6](06-lagg-in-data.md#kontrollera).

### Utmaning

**7.14 Annas flöde.** Visa inläggen från de användare som `anna` följer, med
rubrik och författare.
*Svar: Mitt första surdegsbröd (bertil), Tips på en bra bok? (cissi), Andra
försöket (bertil).*
Ledtråd: hämta först de rader i `follows` där `follower.username = "anna"`. Där
finns id:n på dem hon följer, i fältet `following`. Bygg sedan ett filter för
`posts` av dem.

Nästa kapitel: [SQL och View collections](08-sql-och-view-collections.md)

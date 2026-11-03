# Lösningar

Försök själv innan du tittar här! Det finns ofta fler sätt att skriva en fråga
som ger samma resultat.

## Kapitel 7 – Hämta och lägga till data med Vue

I lösningarna visas bara det du lägger till i `App.vue`. Kod i `<script setup>`
skrivs under kommentaren `Skriv dina egna refs och funktioner här under`, och
funktionerna som hämtar data anropas i `onMounted`. HTML skrivs i `<template>`.

**7.1** Lägg till i template:

```html
<pre>{{ users }}</pre>
```

`email` syns inte, eftersom PocketBase bara visar e-postadressen för användaren
själv (eller om `emailVisibility` är på). `password` skickas aldrig ut.

**7.2** Alla inlägg, nyast först

```js
const posts = ref([])

async function loadPosts() {
  try {
    posts.value = await pb.collection('posts').getFullList({ sort: '-created' })
  } catch (e) {
    showError(e)
  }
}
```

```html
<h2>Inlägg</h2>
<ul>
  <li v-for="post in posts" :key="post.id">
    <strong>{{ post.title }}</strong> – {{ post.body }}
  </li>
</ul>
```

**7.3** Byt frågan i `loadPosts` (eller gör en ny funktion):

```js
posts.value = await pb.collection('posts').getFullList({ filter: 'title ~ "bröd"' })
```

**7.4** En användare

```js
const anna = ref(null)

async function loadAnna() {
  try {
    anna.value = await pb.collection('users').getFirstListItem('username = "anna"')
  } catch (e) {
    showError(e)
  }
}
```

```html
<p v-if="anna">{{ anna.name }} – {{ anna.bio }}</p>
```

`anna` är `null` tills svaret har kommit. `v-if` gör att raden inte visas
förrän då.

**7.5** Sidor

```js
const page = ref(1)
const postPage = ref(null)

async function loadPage() {
  try {
    postPage.value = await pb.collection('posts').getList(page.value, 2, { sort: '-created' })
  } catch (e) {
    showError(e)
  }
}

function nextPage() {
  page.value++
  loadPage()
}

function prevPage() {
  page.value--
  loadPage()
}
```

```html
<div v-if="postPage">
  <p>Sida {{ postPage.page }} av {{ postPage.totalPages }}</p>
  <ul>
    <li v-for="post in postPage.items" :key="post.id">{{ post.title }}</li>
  </ul>
  <button :disabled="page <= 1" @click="prevPage">Föregående</button>
  <button :disabled="page >= postPage.totalPages" @click="nextPage">Nästa</button>
</div>
```

`:disabled` gör knappen grå när det inte finns någon sida åt det hållet.

**7.6** Inlägg med författare

```js
posts.value = await pb.collection('posts').getFullList({
  sort: '-created',
  expand: 'author',
})
```

```html
<li v-for="post in posts" :key="post.id">
  {{ post.title }} – {{ post.expand?.author?.name }}
</li>
```

**7.7** Kommentarer med författare och inlägg

```js
const comments = ref([])

async function loadComments() {
  try {
    comments.value = await pb.collection('comments').getFullList({ expand: 'author,post' })
  } catch (e) {
    showError(e)
  }
}
```

```html
<h2>Kommentarer</h2>
<ul>
  <li v-for="comment in comments" :key="comment.id">
    {{ comment.body }} – {{ comment.expand?.author?.username }} –
    {{ comment.expand?.post?.title }}
  </li>
</ul>
```

**7.8** Annas inlägg

```js
posts.value = await pb.collection('posts').getFullList({
  filter: 'author.username = "anna"',
})
```

Punkten går via relationen `author` till fältet `username` i `users`. Det
motsvarar en `JOIN` i SQL, som du lär dig i nästa kapitel.

**7.9** Antal likes och kommentarer

```js
posts.value = await pb.collection('posts').getFullList({
  sort: 'created',
  expand: 'likes_via_post,comments_via_post',
})
```

```html
<li v-for="post in posts" :key="post.id">
  {{ post.title }}:
  {{ post.expand?.likes_via_post?.length ?? 0 }} likes,
  {{ post.expand?.comments_via_post?.length ?? 0 }} kommentarer
</li>
```

**7.10** Se avsnittet [Ett formulär](07-hamta-och-lagga-till-data-med-vue.md#ett-formulär).
Utan rubrik får du `Fel 400: Failed to create record.`, eftersom `title` är
**Nonempty**. I konsolen står det under `response.data.title`.

**7.11** Ny kommentar

```js
const newComment = ref({ post: '', author: '', body: '' })

async function createComment() {
  try {
    await pb.collection('comments').create(newComment.value)
    newComment.value = { post: '', author: '', body: '' }
    await loadPosts()
  } catch (e) {
    showError(e)
  }
}
```

```html
<h2>Ny kommentar</h2>
<form @submit.prevent="createComment">
  <select v-model="newComment.post">
    <option value="" disabled>Välj inlägg</option>
    <option v-for="post in posts" :key="post.id" :value="post.id">
      {{ post.title }}
    </option>
  </select>
  <select v-model="newComment.author">
    <option value="" disabled>Välj författare</option>
    <option v-for="user in users" :key="user.id" :value="user.id">
      {{ user.username }}
    </option>
  </select>
  <input v-model="newComment.body" placeholder="Kommentar" />
  <button>Skicka</button>
</form>
```

**7.12** Gilla

```js
const me = ref('')

async function like(post) {
  try {
    await pb.collection('likes').create({ post: post.id, user: me.value })
    await loadPosts()
  } catch (e) {
    showError(e)
  }
}
```

```html
<label>
  Jag är:
  <select v-model="me">
    <option v-for="user in users" :key="user.id" :value="user.id">
      {{ user.username }}
    </option>
  </select>
</label>

<ul>
  <li v-for="post in posts" :key="post.id">
    {{ post.title }} ({{ post.expand?.likes_via_post?.length ?? 0 }} likes)
    <button @click="like(post)">Gilla</button>
  </li>
</ul>
```

Andra gången får du `Fel 400: Failed to create record.`. Det unika indexet på
`post` och `user` i `likes` (kapitel 5) gör att samma användare inte kan gilla
samma inlägg två gånger.

**7.13** Ta bort

```js
async function deletePost(post) {
  try {
    await pb.collection('posts').delete(post.id)
    await loadPosts()
  } catch (e) {
    showError(e)
  }
}
```

```html
<button @click="deletePost(post)">Ta bort</button>
```

Kommentarerna och likesen försvann också. Relationerna `comments.post` och
`likes.post` har **Cascade delete** (kapitel 5), så när inlägget tas bort tas
allt som pekar på det bort.

**7.14** Annas flöde

```js
const feed = ref([])

async function loadFeed() {
  try {
    const follows = await pb.collection('follows').getFullList({
      filter: 'follower.username = "anna"',
    })
    // t.ex. 'author = "abc123" || author = "def456"'
    const filter = follows.map((follow) => `author = "${follow.following}"`).join(' || ')

    feed.value = await pb.collection('posts').getFullList({
      filter: filter,
      sort: 'created',
      expand: 'author',
    })
  } catch (e) {
    showError(e)
  }
}
```

```html
<h2>Annas flöde</h2>
<ul>
  <li v-for="post in feed" :key="post.id">
    {{ post.title }} ({{ post.expand?.author?.username }})
  </li>
</ul>
```

⚠️ Om Anna inte följer någon blir filtret tomt, och då får du **alla** inlägg.
I en riktig app kollar man det först.

Det går också att göra i **en** fråga, med en bakåt-relation i filtret:

```js
filter: 'author.follows_via_following.follower.username ?= "anna"'
```

Läs det som: "inläggets författare finns i någon rad i `follows` (som
`following`) där `follower` är anna". `?=` betyder "minst en av dem är lika
med".

## Kapitel 8 – SQL och View collections

**8.1** Annas inlägg

```sql
SELECT posts.id, posts.title
FROM posts
JOIN users ON users.id = posts.author
WHERE users.username = 'anna'
```

**8.2** Kommentarer med författare

```sql
SELECT comments.id, comments.body, users.username AS author
FROM comments
JOIN users ON users.id = comments.author
```

**8.3** Antal kommentarer per inlägg

```sql
SELECT posts.id, posts.title, COUNT(comments.id) AS comment_count
FROM posts
LEFT JOIN comments ON comments.post = posts.id
GROUP BY posts.id
```

`LEFT JOIN` behövs för att inlägg utan kommentarer ska vara med och visa 0.

**8.4** Antal följare per användare

```sql
SELECT users.id, users.username, COUNT(follows.id) AS followers
FROM users
LEFT JOIN follows ON follows.following = users.id
GROUP BY users.id
ORDER BY followers DESC, users.username
```

Följarna är de rader där användaren står i `following`.

**8.5** Inlägg utan likes

```sql
SELECT posts.id, posts.title
FROM posts
LEFT JOIN likes ON likes.post = posts.id
WHERE likes.id IS NULL
```

När ett inlägg inte har någon like blir alla `likes`-kolumner tomma (`NULL`)
efter `LEFT JOIN`. Dem plockar vi ut med `IS NULL`.

**8.6** Annas flöde

```sql
SELECT posts.id, posts.title, users.username AS author
FROM posts
JOIN users ON users.id = posts.author
JOIN follows ON follows.following = posts.author
JOIN users AS me ON me.id = follows.follower
WHERE me.username = 'anna'
```

Steg för steg: ta alla inlägg → koppla på författaren → koppla på de
följningar där författaren blir följd → koppla på den som följer → behåll bara
raderna där den som följer är Anna.

**8.7** Vilka har gillat Annas inlägg?

```sql
SELECT likes.id, posts.title, liker.username AS liked_by
FROM likes
JOIN posts ON posts.id = likes.post
JOIN users AS author ON author.id = posts.author
JOIN users AS liker ON liker.id = likes.user
WHERE author.username = 'anna'
```

Vi behöver `users` två gånger: en gång för inläggets författare och en gång för
den som gillade. Med `AS` får de olika namn. Vi använder `likes.id` som `id`,
eftersom varje like bara finns en gång.

## Kapitel 9 – Inloggning och API-regler

**9.1** Med tom regel ser du alla inlägg som JSON. Med
`@request.auth.id != ""` får du en tom lista, eftersom webbläsaren inte är
inloggad.

**9.2** Se tabellerna i kapitel 9. Vue-appen från kapitel 7 är inte inloggad,
så `@request.auth.id != ""` är falskt. Listorna blir tomma, och formulären ger
`Fel 400` eller `Fel 404`.

**9.3** Då skulle Anna kunna skapa ett inlägg där `author` är Bertil, alltså
skriva i någon annans namn. `@request.body.author = @request.auth.id` ser till
att `author` alltid är den som är inloggad.

**9.4** Delete-regeln för `likes` är `user = @request.auth.id`. Likens `user` är
Anna, men den inloggade är Bertil, så villkoret är falskt.

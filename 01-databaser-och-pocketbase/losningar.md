# Lösningar

Försök själv innan du tittar här! Det finns ofta fler sätt att skriva en fråga
som ger samma resultat.

## Kapitel 7 – Hämta och lägga till data med Vue

I lösningarna visas bara det du lägger till eller ändrar i `App.vue`. Kod i
`<script setup>` skrivs under `loadUsers`, och funktionerna som hämtar data
anropas i `onMounted`. HTML skrivs i `<template>`.

**7.1** Lägg till i template:

```html
<pre>{{ users }}</pre>
```

`email` syns inte, eftersom PocketBase bara visar e-postadressen för användaren
själv. Lösenordet skickas aldrig ut.

**7.2** Alla inlägg

```js
const posts = ref([])

async function loadPosts() {
  posts.value = await pb.collection('posts').getFullList()
}

onMounted(() => {
  loadUsers()
  loadPosts()
})
```

```html
<h2>Inlägg</h2>
<ul>
  <li v-for="post in posts" :key="post.id">
    <strong>{{ post.title }}</strong> – {{ post.body }}
  </li>
</ul>
```

**7.3** Nyast först

```js
async function loadPosts() {
  posts.value = await pb.collection('posts').getFullList({ sort: '-created' })
}
```

**7.4** Filter

```js
async function loadPosts() {
  posts.value = await pb.collection('posts').getFullList({
    sort: '-created',
    filter: 'title ~ "bröd"',
  })
}
```

Kommatecknet efter `'-created'` behövs mellan två inställningar.

**7.5** Författarens namn

```js
async function loadPosts() {
  posts.value = await pb.collection('posts').getFullList({
    sort: '-created',
    expand: 'author',
  })
}
```

```html
<li v-for="post in posts" :key="post.id">
  <strong>{{ post.title }}</strong> – {{ post.expand?.author?.name }}
</li>
```

**7.6** Annas inlägg

```js
async function loadPosts() {
  posts.value = await pb.collection('posts').getFullList({
    sort: '-created',
    expand: 'author',
    filter: 'author.username = "anna"',
  })
}
```

Punkten går via relationen `author` till fältet `username` i `users`.

**7.7** Antal kommentarer

```js
async function loadPosts() {
  posts.value = await pb.collection('posts').getFullList({
    sort: '-created',
    expand: 'author,comments_via_post',
  })
}
```

```html
<li v-for="post in posts" :key="post.id">
  <strong>{{ post.title }}</strong> – {{ post.expand?.author?.name }}
  ({{ post.expand?.comments_via_post?.length ?? 0 }} kommentarer)
</li>
```

**7.8** Kommentarer

```js
const comments = ref([])

async function loadComments() {
  comments.value = await pb.collection('comments').getFullList({ expand: 'author' })
}

onMounted(() => {
  loadUsers()
  loadPosts()
  loadComments()
})
```

```html
<h2>Kommentarer</h2>
<ul>
  <li v-for="comment in comments" :key="comment.id">
    {{ comment.body }} – {{ comment.expand?.author?.username }}
  </li>
</ul>
```

**7.9** Koden står i avsnittet
[Ett formulär](07-hamta-och-lagga-till-data-med-vue.md#ett-formulär).

**7.10** Ny kommentar

```js
const newComment = ref({ post: '', author: '', body: '' })

async function createComment() {
  await pb.collection('comments').create(newComment.value)
  newComment.value = { post: '', author: '', body: '' }
  await loadComments()
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
  <textarea v-model="newComment.body" placeholder="Kommentar"></textarea>
  <button>Skicka</button>
</form>
```

**7.11** Ta bort

```html
<li v-for="post in posts" :key="post.id">
  <strong>{{ post.title }}</strong> – {{ post.expand?.author?.name }}
  <button @click="deletePost(post)">Ta bort</button>
</li>
```

Om inlägget hade kommentarer försvann de också. Relationen `comments.post` har
**Cascade delete** (kapitel 5).

**7.12** Gilla

```js
const annaId = 'klistra-in-annas-id-här'

async function like(post) {
  await pb.collection('likes').create({ post: post.id, user: annaId })
  await loadPosts()
}

async function loadPosts() {
  posts.value = await pb.collection('posts').getFullList({
    sort: '-created',
    expand: 'author,comments_via_post,likes_via_post',
  })
}
```

```html
<li v-for="post in posts" :key="post.id">
  <strong>{{ post.title }}</strong>
  ({{ post.expand?.likes_via_post?.length ?? 0 }} likes)
  <button @click="like(post)">Gilla</button>
</li>
```

Andra gången får du ett fel i konsolen (`400`). Det unika indexet på `post` och
`user` i `likes` (kapitel 5) gör att samma användare inte kan gilla samma
inlägg två gånger.

**7.13** Sidor

```js
const page = ref(1)
const totalPages = ref(1)

async function loadPosts() {
  const result = await pb.collection('posts').getList(page.value, 2, { sort: '-created' })
  posts.value = result.items
  totalPages.value = result.totalPages
}

function nextPage() {
  page.value++
  loadPosts()
}

function prevPage() {
  page.value--
  loadPosts()
}
```

```html
<p>Sida {{ page }} av {{ totalPages }}</p>
<button :disabled="page <= 1" @click="prevPage">Föregående</button>
<button :disabled="page >= totalPages" @click="nextPage">Nästa</button>
```

Listan med `v-for="post in posts"` fungerar som förut, eftersom `posts` får
`result.items`.

**7.14** Annas flöde

```js
async function loadPosts() {
  const follows = await pb.collection('follows').getFullList({
    filter: 'follower.username = "anna"',
  })
  // t.ex. 'author = "abc123" || author = "def456"'
  const filter = follows.map((follow) => `author = "${follow.following}"`).join(' || ')

  posts.value = await pb.collection('posts').getFullList({
    filter: filter,
    sort: 'created',
    expand: 'author',
  })
}
```

Det går också att göra i **en** fråga, med en bakåt-relation i filtret:

```js
filter: 'author.follows_via_following.follower.username ?= "anna"'
```

Läs det som: "inläggets författare står som `following` i någon rad i
`follows` där `follower` är anna". `?=` betyder "minst en av dem är lika med".

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
fel i konsolen (`400` eller `404`).

**9.3** Då skulle Anna kunna skapa ett inlägg där `author` är Bertil, alltså
skriva i någon annans namn. `@request.body.author = @request.auth.id` ser till
att `author` alltid är den som är inloggad.

**9.4** Delete-regeln för `likes` är `user = @request.auth.id`. Likens `user` är
Anna, men den inloggade är Bertil, så villkoret är falskt.

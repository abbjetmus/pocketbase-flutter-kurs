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

*Svar: Nej, `email` syns inte.* PocketBase visar bara e-postadressen för
användaren själv. Lösenordet skickas aldrig ut.

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

*Svar: 6 inlägg.*

**7.3** Nyast först

```js
async function loadPosts() {
  posts.value = await pb.collection('posts').getFullList({ sort: '-created' })
}
```

*Svar: Andra försöket överst, Höstpromenad nederst (om du lade in inläggen i
samma ordning som i kapitel 6).*

**7.4** Filter

```js
async function loadPosts() {
  posts.value = await pb.collection('posts').getFullList({
    sort: '-created',
    filter: 'title ~ "bröd"',
  })
}
```

*Svar: Mitt första surdegsbröd. Med `filter: 'title ~ "bok"'` blir det Tips på
en bra bok?*

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

*Svar: t.ex. "Matchdag – David Dahl".*

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

*Svar: Höstpromenad, Morgondimma.*

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

*Svar: Höstpromenad 1, Mitt första surdegsbröd 2, Morgondimma 0, Tips på en bra
bok? 2, Matchdag 1, Andra försöket 0.*

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

*Svar: 6 kommentarer, t.ex. "Recept tack! – cissi".*

**7.9** Koden står i avsnittet
[Ett formulär](07-hamta-och-lagga-till-data-med-vue.md#ett-formulär).

*Svar: Ja. Inlägget syns i listan direkt, eftersom `createPost` anropar
`loadPosts()` igen, och det syns i `posts` i Dashboard.*

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

*Svar: Ja, `createComment` anropar `loadComments()`, så kommentaren syns i
listan från 7.8.*

**7.11** Ta bort. Funktionen `deletePost` står i övningen. Knappen läggs inne i
listan:

```html
<li v-for="post in posts" :key="post.id">
  <strong>{{ post.title }}</strong> – {{ post.expand?.author?.name }}
  <button @click="deletePost(post)">Ta bort</button>
</li>
```

Om inlägget hade kommentarer försvann de också. Relationen `comments.post` har
**Cascade delete** (kapitel 5).

## Kapitel 8 – SQL och View collections

**8.1** Alla användare

```sql
SELECT id, username, name
FROM users
```

*Svar: anna, bertil, cissi och david.*

**8.2** Bara cissi

```sql
SELECT id, username, name, bio
FROM users
WHERE username = 'cissi'
```

*Svar: en rad, Cecilia Carlsson. Hennes `bio` är tom.*

**8.3** Inlägg om bröd

```sql
SELECT id, title
FROM posts
WHERE title LIKE '%bröd%'
```

*Svar: Mitt första surdegsbröd.*

`%` betyder "vad som helst". `'%bröd%'` matchar alltså alla titlar där "bröd"
finns någonstans.

**8.4** Titlar i bokstavsordning

```sql
SELECT id, title
FROM posts
ORDER BY title
```

*Svar: Andra försöket, Höstpromenad, Matchdag, Mitt första surdegsbröd,
Morgondimma, Tips på en bra bok?*

**8.5** De två senaste kommentarerna

```sql
SELECT id, body
FROM comments
ORDER BY created DESC
LIMIT 2
```

*Svar: Grattis! och Harry Potter! (om du lade in kommentarerna i samma ordning
som i kapitel 6).*

**8.6** Inlägg med författarens namn

```sql
SELECT posts.id, posts.title, users.name AS author
FROM posts
JOIN users ON users.id = posts.author
```

*Svar: 6 rader, t.ex. Matchdag – David Dahl.*

**8.7** Kommentarer med författare

```sql
SELECT comments.id, comments.body, users.username AS author
FROM comments
JOIN users ON users.id = comments.author
```

*Svar: 6 rader, t.ex. "Recept tack!" – cissi.*

**8.8** Annas inlägg

```sql
SELECT posts.id, posts.title
FROM posts
JOIN users ON users.id = posts.author
WHERE users.username = 'anna'
```

*Svar: Höstpromenad, Morgondimma.*

**8.9** Antal inlägg per användare

```sql
SELECT users.id, users.username, COUNT(posts.id) AS post_count
FROM users
LEFT JOIN posts ON posts.author = users.id
GROUP BY users.id
```

*Svar: anna 2, bertil 2, cissi 1, david 1.*

**8.10** Antal kommentarer per inlägg

```sql
SELECT posts.id, posts.title, COUNT(comments.id) AS comment_count
FROM posts
LEFT JOIN comments ON comments.post = posts.id
GROUP BY posts.id
```

*Svar: Höstpromenad 1, Mitt första surdegsbröd 2, Morgondimma 0, Tips på en bra
bok? 2, Matchdag 1, Andra försöket 0.*

`LEFT JOIN` behövs för att inlägg utan kommentarer ska vara med och visa 0.

**8.11** Antal följare per användare

```sql
SELECT users.id, users.username, COUNT(follows.id) AS followers
FROM users
LEFT JOIN follows ON follows.following = users.id
GROUP BY users.id
ORDER BY followers DESC, users.username
```

*Svar: anna 2, bertil 2, cissi 1, david 0.*

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

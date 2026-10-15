# Lösningar

Försök själv innan du tittar här! Det finns ofta fler sätt att skriva en fråga
som ger samma resultat.

## Kapitel 5 – Bygg Kvittra i PocketBase

**5.1** Det går inte. När du ska välja vilken collection relationsfältet `post`
ska peka på finns `posts` inte i listan. En relation kan bara peka på något som
redan finns.

**5.2** Ett unikt index på `follower` ensamt skulle betyda att varje användare
bara får följa **en** person. Då kan Anna inte följa både Bertil och Cissi. Det
är **kombinationen** som ska vara unik: Anna får följa Bertil en gång.

## Kapitel 6 – Lägg in data

**6.1** PocketBase säger att värdet måste vara unikt. Det är det unika indexet
på `post` + `user` i `likes` som stoppar det.

**6.2** Samma sak: det unika indexet på `username` stoppar det.

**6.3** Det går inte, eftersom `title` är **Nonempty** (måste fyllas i).

**6.4** Både inlägget och gillningen försvann. Det beror på **Cascade delete**
på relationsfälten `posts.author` och `likes.user`.

**6.5** I fältet `author` står användarens **id**, inte namnet. Namnet finns
bara i `users`. (Har du kryssat i *Presentable* på `username` visar Dashboard
användarnamnet bredvid, men det som sparas är fortfarande id:t.)

## Kapitel 7 – SQL och View collections

**7.1** Annas inlägg

```sql
SELECT posts.id, posts.title
FROM posts
JOIN users ON users.id = posts.author
WHERE users.username = 'anna'
```

**7.2** Kommentarer med författare

```sql
SELECT comments.id, comments.body, users.username AS author
FROM comments
JOIN users ON users.id = comments.author
```

**7.3** Antal kommentarer per inlägg

```sql
SELECT posts.id, posts.title, COUNT(comments.id) AS comment_count
FROM posts
LEFT JOIN comments ON comments.post = posts.id
GROUP BY posts.id
```

`LEFT JOIN` behövs för att inlägg utan kommentarer ska vara med och visa 0.

**7.4** Antal följare per användare

```sql
SELECT users.id, users.username, COUNT(follows.id) AS followers
FROM users
LEFT JOIN follows ON follows.following = users.id
GROUP BY users.id
ORDER BY followers DESC, users.username
```

Följarna är de rader där användaren står i `following`.

**7.5** Inlägg utan likes

```sql
SELECT posts.id, posts.title
FROM posts
LEFT JOIN likes ON likes.post = posts.id
WHERE likes.id IS NULL
```

När ett inlägg inte har någon like blir alla `likes`-kolumner tomma (`NULL`)
efter `LEFT JOIN`. Dem plockar vi ut med `IS NULL`.

**7.6** Annas flöde

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

**7.7** Vilka har gillat Annas inlägg?

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

## Kapitel 8 – Inloggning och API-regler

**8.1** Med tom regel ser du alla inlägg som JSON. Med
`@request.auth.id != ""` får du en tom lista, eftersom webbläsaren inte är
inloggad.

**8.2** Se tabellerna i kapitel 8.

**8.3** Då skulle Anna kunna skapa ett inlägg där `author` är Bertil, alltså
skriva i någon annans namn. `@request.body.author = @request.auth.id` ser till
att `author` alltid är den som är inloggad.

**8.4** Delete-regeln för `likes` är `user = @request.auth.id`. Likens `user` är
Anna, men den inloggade är Bertil, så villkoret är falskt.

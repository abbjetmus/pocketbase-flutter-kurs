# 7. SQL och View collections

## Vad är SQL?

**SQL** (*Structured Query Language*) är språket man använder för att prata med
en relationsdatabas. Med SQL kan man hämta, lägga till, ändra och ta bort data.

Du har redan använt SQL utan att märka det. När du klickar i Dashboard
översätter PocketBase dina klick till SQL:

| Du gör i Dashboard | PocketBase kör ungefär |
|--------------------|------------------------|
| Skapar collectionen `posts` | `CREATE TABLE posts (...)` |
| Lägger in ett inlägg | `INSERT INTO posts (...) VALUES (...)` |
| Ändrar ett inlägg | `UPDATE posts SET title = '...' WHERE id = '...'` |
| Tar bort ett inlägg | `DELETE FROM posts WHERE id = '...'` |
| Öppnar listan med inlägg | `SELECT * FROM posts` |

I det här kapitlet skriver vi själva **`SELECT`**-frågor. De **läser** data.
Med en fråga kan man kombinera data från flera tabeller, till exempel "alla
inlägg med författarens namn och antal likes".

## View collections – så testar du SQL

En **View collection** är en sparad `SELECT`-fråga. Den visas som en vanlig
collection i Dashboard, men du kan inte skriva i den. Den visar resultatet av
frågan.

Så skapar du en:

1. Klicka **+ New collection** och välj typen **View**.
2. Ge den ett namn, t.ex. `test_users`.
3. Skriv din fråga i rutan **Select query**.
4. Klicka **Create**. Klicka sedan på collectionen till vänster för att se
   resultatet.

Vill du ändra frågan klickar du på kugghjulet, ändrar och sparar.

⚠️ **Regeln du måste komma ihåg:** Frågan måste ha en kolumn som heter **`id`**,
och den ska vara olika på varje rad. Därför börjar alla frågor nedan med
`posts.id`, `users.id` eller liknande. Annars får du ett felmeddelande.

## SELECT – välj kolumner

```sql
SELECT id, username, name
FROM users
```

- `SELECT` säger **vilka kolumner** du vill ha.
- `FROM` säger **vilken tabell** de ska hämtas från.

Resultat:

| username | name |
|----------|------|
| anna | Anna Andersson |
| bertil | Bertil Berg |
| cissi | Cecilia Carlsson |
| david | David Dahl |

(Vi visar inte `id` i resultaten här, eftersom dina id:n är slumpade.)

⚠️ Skriv aldrig `SELECT *` på `users`. Då kommer även det krypterade lösenordet
och annat hemligt med.

## WHERE – filtrera rader

`WHERE` behåller bara raderna där villkoret är sant.

```sql
SELECT id, username, bio
FROM users
WHERE bio != ''
```

| username | bio |
|----------|-----|
| anna | Gillar promenader och foto |
| bertil | Bakar bröd varje helg |
| david | Spelar fotboll |

Cissi saknas, eftersom hennes `bio` är tom. I PocketBase är tomma textfält
`''` (tom text).

| Jämförelse | Betyder |
|------------|---------|
| `=` | lika med |
| `!=` | inte lika med |
| `>` `<` `>=` `<=` | större / mindre än |
| `LIKE '%bröd%'` | innehåller "bröd" |
| `AND`, `OR` | och, eller |

Text skrivs inom enkla citattecken: `'anna'`.

## ORDER BY och LIMIT – sortera och begränsa

```sql
SELECT id, title, created
FROM posts
ORDER BY created DESC
LIMIT 3
```

`ORDER BY created DESC` sorterar med det nyaste först (`DESC` = fallande,
`ASC` = stigande). `LIMIT 3` tar bara de tre första raderna.

| title | created |
|-------|---------|
| Andra försöket | *(senaste)* |
| Matchdag | |
| Tips på en bra bok? | |

(Om du lade in inläggen i samma ordning som i kapitel 6.)

## JOIN – kombinera tabeller

I `posts` står bara författarens **id**. Vill vi se användarnamnet måste vi
hämta det från `users`. Det gör man med `JOIN`:

```sql
SELECT posts.id, posts.title, users.username AS author
FROM posts
JOIN users ON users.id = posts.author
```

`JOIN users ON users.id = posts.author` betyder: "koppla ihop varje inlägg med
den användare vars `id` är samma som inläggets `author`".

```
   posts                          users
┌──────────────┬────────┐      ┌──────┬──────────┐
│ title        │ author │      │ id   │ username │
├──────────────┼────────┤      ├──────┼──────────┤
│ Höstpromenad │ u1 ────┼─────►│ u1   │ anna     │
│ Matchdag     │ u4 ────┼─────►│ u4   │ david    │
└──────────────┴────────┘      └──────┴──────────┘
```

| title | author |
|-------|--------|
| Höstpromenad | anna |
| Mitt första surdegsbröd | bertil |
| Morgondimma | anna |
| Tips på en bra bok? | cissi |
| Matchdag | david |
| Andra försöket | bertil |

- `posts.title` betyder "kolumnen `title` i tabellen `posts`". Det behövs när
  två tabeller har kolumner med samma namn, t.ex. `id`.
- `AS author` ger kolumnen ett nytt namn i resultatet.

## COUNT och GROUP BY – räkna

Hur många likes har varje inlägg?

```sql
SELECT posts.id, posts.title, COUNT(likes.id) AS like_count
FROM posts
LEFT JOIN likes ON likes.post = posts.id
GROUP BY posts.id
ORDER BY like_count DESC, posts.title
```

| title | like_count |
|-------|-------|
| Mitt första surdegsbröd | 3 |
| Andra försöket | 2 |
| Höstpromenad | 2 |
| Matchdag | 1 |
| Morgondimma | 0 |
| Tips på en bra bok? | 0 |

- `ORDER BY like_count DESC, posts.title` sorterar på antal likes, och på titeln när två inlägg har lika många.
- `GROUP BY posts.id` slår ihop alla rader för samma inlägg till en rad.
- `COUNT(likes.id)` räknar hur många likes som hörde till gruppen.
- `LEFT JOIN` behåller inlägg som **inte** har några likes, och ger dem 0.
  Med vanlig `JOIN` skulle Morgondimma och Tips på en bra bok? försvinna.

Det här är anledningen till att vi inte sparar antalet likes i `posts`. Vi
räknar fram det när vi behöver det, och då blir det alltid rätt.

## Sammanfattning

| Del | Gör |
|-----|-----|
| `SELECT` | Väljer kolumner |
| `FROM` | Väljer tabell |
| `JOIN ... ON ...` | Kopplar ihop tabeller via relationer |
| `LEFT JOIN` | Som JOIN, men behåller rader som saknar en matchning |
| `WHERE` | Filtrerar rader |
| `GROUP BY` | Slår ihop rader till grupper |
| `COUNT(...)` | Räknar rader i varje grupp |
| `ORDER BY ... DESC` | Sorterar |
| `LIMIT` | Tar bara de första raderna |

Delarna skrivs alltid i den här ordningen:
`SELECT` → `FROM` → `JOIN` → `WHERE` → `GROUP BY` → `ORDER BY` → `LIMIT`.

## Övningar

Skapa en View collection för varje övning. Kontrollera att du får samma resultat
som står här. Lösningar finns i [losningar.md](losningar.md#kapitel-7--sql-och-view-collections).

**7.1** Visa titlarna på alla inlägg som `anna` har skrivit.
*Svar: Höstpromenad, Morgondimma.*

**7.2** Visa alla kommentarer med kommentarens text och användarnamnet på den
som skrev den.
*Svar: 6 rader, t.ex. "Recept tack!" – cissi.*

**7.3** Visa hur många kommentarer varje inlägg har. Inlägg utan kommentarer
ska vara med och visa 0.
*Svar: Höstpromenad 1, Mitt första surdegsbröd 2, Morgondimma 0, Tips på en
bra bok? 2, Matchdag 1, Andra försöket 0.*

**7.4** Visa hur många **följare** varje användare har.
*Svar: anna 2, bertil 2, cissi 1, david 0.*

**7.5** Visa de inlägg som saknar likes.
*Svar: Morgondimma, Tips på en bra bok?*
Ledtråd: `LEFT JOIN` och `WHERE likes.id IS NULL`.

**7.6 Annas flöde.** Visa inläggen från de användare som `anna` följer, med
titel och författare.
*Svar: Mitt första surdegsbröd (bertil), Tips på en bra bok? (cissi), Andra
försöket (bertil).*

**7.7 Utmaning.** Vilka användare har gillat inlägg som `anna` har skrivit?
Visa inläggets titel och användarnamnet på den som gillade.
*Svar: Höstpromenad – bertil, Höstpromenad – cissi.*
Ledtråd: du behöver `users` två gånger. Ge dem olika namn med `AS`, t.ex.
`JOIN users AS liker ON ...`.

**7.8 Ditt projekt.** Skriv två View collections för ditt eget projekt: en med
`JOIN` och en med `COUNT` och `GROUP BY`.

Nästa kapitel: [Inloggning och API-regler](08-inloggning-och-api-regler.md)

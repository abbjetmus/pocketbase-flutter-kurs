# Lösningar – Modul 01 Databaser

Här är lösningsförslag till [övningarna](ovningar.md). Det finns ofta flera
korrekta sätt att skriva en fråga – om ditt svar ger samma resultat och är lätt
att läsa är det lika bra.

Alla frågor förutsätter att Kvittra är inmatad exakt som i
[modulens README](README.md) (6 users, 10 posts, 13 comments, 19 likes,
10 follows) och att inläggen har fått sina datum i steg 2d. `SELECT`-frågorna är
skrivna så att de kan klistras in direkt som **View collection** – därför har alla
en `id`-kolumn. I resultattabellerna visas inte id-kolumnen, eftersom dina id:n är
slumpade.

---

## Del A – SQL-frågor

### Nivå 1

**1.1**

```sql
SELECT id, username, website
FROM users
WHERE website != ''
ORDER BY username;
```

| username | website |
|----------|---------|
| anna | https://anna.example.com |
| cissi | https://cissi.example.com |

**1.2**

```sql
SELECT id, username
FROM users
WHERE bio = ''
ORDER BY username;
```

evaek och johan. `bio IS NULL` ger inga rader, eftersom PocketBase sparar tomma
textfält som tom sträng `''` och inte som `NULL`. I en "vanlig" SQL-databas där
kolumnen tillåter `NULL` hade du kunnat behöva `bio IS NULL OR bio = ''` – ett
bra exempel på varför man ska välja *ett* sätt att säga "saknas".

**1.3**

```sql
SELECT (ROW_NUMBER() OVER ()) AS id, COUNT(*) AS antal
FROM posts;
```

En rad: `10`. Utan `ROW_NUMBER()` saknas id-kolumnen och PocketBase vägrar skapa
viewn.

**1.4**

```sql
SELECT p.id, p.title, p.created
FROM posts p
JOIN users u ON u.id = p.author
WHERE u.username = 'anna'
ORDER BY p.created DESC;
```

| title | created |
|-------|---------|
| Morgondimma | 2026-10-11 06:45:00.000Z |
| Höstpromenad i Slottsskogen | 2026-09-01 08:15:00.000Z |

Alternativ med underfråga:
`WHERE author = (SELECT id FROM users WHERE username = 'anna')`.

**1.5**

```sql
SELECT id, title
FROM posts
WHERE title LIKE '%kaffe%'
   OR body  LIKE '%kaffe%'
ORDER BY created;
```

| title |
|-------|
| Kaffe efter löprundan |
| Kanelbullens dag |

"Kanelbullens dag" kommer med tack vare texten ("Kaffe, någon?"). `LIKE` skiljer
inte på stora och små bokstäver för a–z, så `'%kaffe%'` hittar "Kaffe".

⚠️ Tänk på parenteser om du kombinerar `OR` med fler villkor:
`WHERE (title LIKE ... OR body LIKE ...) AND created >= ...`.

**1.6**

```sql
SELECT id, title, created
FROM posts
ORDER BY created DESC
LIMIT 4 OFFSET 4;
```

| title | created |
|-------|---------|
| Kaffe efter löprundan | 2026-09-28 08:10:00.000Z |
| Hej Kvittra! | 2026-09-25 09:00:00.000Z |
| Milen under 50 minuter! | 2026-09-08 07:30:00.000Z |
| Brädspelskväll på fredag | 2026-09-05 12:00:00.000Z |

Sida *n* med *k* per sida är `LIMIT k OFFSET (n - 1) * k`.

**1.7**

```sql
SELECT id, title
FROM posts
WHERE created >= '2026-10-01'
  AND created <  '2026-11-01'
ORDER BY created;
```

Kanelbullens dag, Brädspelskväll igen?, Halvmaran avklarad, Morgondimma.

`BETWEEN '2026-10-01' AND '2026-10-31'` missar allt som skrivs *under* den
31 oktober, eftersom `'2026-10-31 08:00:00.000Z' > '2026-10-31'` när man jämför
text. Det råkar inte spela någon roll med vår data, men det är en bugg som väntar
på att hända.

**1.8**

```sql
SELECT id, body, created
FROM comments
WHERE post = (SELECT id FROM posts WHERE title = 'Halvmaran avklarad')
ORDER BY created;
```

| body |
|------|
| Wow, grattis! |
| Snyggt! |
| Imponerande! |

Underfrågan returnerar *ett* värde (inläggets id), så vi kan jämföra med `=`.
Hade två inlägg haft samma titel hade du behövt `IN`.

**1.9**

1–2. Skapas i Dashboard. Lägg märke till att `id`, `created` och `updated` fylls i
automatiskt – precis som `DEFAULT` i SQL.

3\. I SQL console (byt `kim` mot ditt användarnamn):

```sql
UPDATE users SET bio = 'Kursdeltagare som lär sig SQL.' WHERE username = 'kim';
SELECT username, bio FROM users WHERE username = 'kim';
```

4\. Dashboard visar *"Value must be unique"* på `username`. Det är det unika
indexet du skapade i steg 2a – en regel som ligger i själva databasen.

5\. Inlägget försvann också, tack vare *Cascade delete* på `posts.author`
(`ON DELETE CASCADE`).

6\. Kontroll:

```sql
SELECT (ROW_NUMBER() OVER ()) AS id,
       (SELECT COUNT(*) FROM users) AS users,
       (SELECT COUNT(*) FROM posts) AS posts;
```

💡 Lägg märke till att vi använder `WHERE username = ...` i `UPDATE`. Utan `WHERE`
hade *alla* användare fått din bio.

**1.10**

1. *"Value must be unique"* – det unika indexet på `follows(follower, following)`.
   Regeln ligger i **databasen**.
2. Felet kommer från *Required* på `title`. Regeln ligger i **PocketBase** (i
   tabellen finns bara `NOT NULL DEFAULT ''`, och en tom sträng är inte `NULL`).
3. Det går! Det finns ingen regel som säger `follower <> following`. I ren SQL hade
   man skrivit `CHECK (follower <> following)`. I PocketBase stoppar man det med en
   API-regel (`@request.body.following != @request.auth.id`) eller en hook – det
   gör du i modul 02. Observera att API-regler inte gäller superusers i Dashboard.
4. Det går också, eftersom PocketBases tabeller saknar `REFERENCES`: det är
   PocketBase som kontrollerar relationer, och SQL console går förbi PocketBase.
   Städa upp:

   ```sql
   DELETE FROM comments WHERE post = 'finnsinte12345';
   DELETE FROM follows
   WHERE follower = following;
   ```

   (Den andra satsen tar bort alla självföljningar – det är just den regel vi
   saknade.)

### Nivå 2

**2.1**

```sql
SELECT u.id, u.username, COUNT(c.id) AS kommentarer
FROM users u
LEFT JOIN comments c ON c.author = u.id
GROUP BY u.id, u.username
ORDER BY kommentarer DESC, u.username;
```

| username | kommentarer |
|----------|-------------|
| anna | 5 |
| cissi | 3 |
| bertil | 2 |
| dahl | 2 |
| evaek | 1 |
| johan | 0 |

Två fällor: med `INNER JOIN` försvinner johan, och med `COUNT(*)` får johan värdet
1 i stället för 0 (raden med `NULL`-kommentar räknas).

**2.2**

```sql
SELECT p.id, p.title, COUNT(l.id) AS gillningar
FROM posts p
LEFT JOIN likes l ON l.post = p.id
GROUP BY p.id, p.title
ORDER BY gillningar DESC, p.title;
```

| title | gillningar |
|-------|------------|
| Halvmaran avklarad | 4 |
| Brädspelskväll igen? | 3 |
| Höstpromenad i Slottsskogen | 3 |
| Kanelbullens dag | 2 |
| Milen under 50 minuter! | 2 |
| Morgondimma | 2 |
| Brädspelskväll på fredag | 1 |
| Kaffe efter löprundan | 1 |
| Mitt första surdegsbröd | 1 |
| Hej Kvittra! | 0 |

Det här är exakt frågan en app behöver för att visa hjärtan i flödet – utan att
spara någon räknare.

**2.3 – Annas flöde**

```sql
SELECT p.id, a.username AS author, p.title, p.created
FROM follows f
JOIN users me ON me.id = f.follower
JOIN posts p  ON p.author = f.following
JOIN users a  ON a.id = p.author
WHERE me.username = 'anna'
ORDER BY p.created DESC;
```

| author | title | created |
|--------|-------|---------|
| cissi | Halvmaran avklarad | 2026-10-10 14:00:00.000Z |
| bertil | Kanelbullens dag | 2026-10-04 08:00:00.000Z |
| cissi | Kaffe efter löprundan | 2026-09-28 08:10:00.000Z |
| cissi | Milen under 50 minuter! | 2026-09-08 07:30:00.000Z |
| bertil | Mitt första surdegsbröd | 2026-09-03 19:40:00.000Z |

Läs joinen som en kedja: *jag* → *de jag följer* (`follows`) → *deras inlägg*
(`posts`) → *författarens namn* (`users`). Här går det bra att använda `p.id` som
id, eftersom varje inlägg bara förekommer en gång i Annas flöde.

**2.4 – Vem gillar mina inlägg?**

```sql
SELECT liker.id, liker.username, COUNT(*) AS gillningar
FROM likes l
JOIN posts p      ON p.id = l.post
JOIN users author ON author.id = p.author
JOIN users liker  ON liker.id = l.user
WHERE author.username = 'anna'
GROUP BY liker.id, liker.username
ORDER BY gillningar DESC, liker.username;
```

| username | gillningar |
|----------|------------|
| bertil | 2 |
| cissi | 2 |
| dahl | 1 |

`users` joinas två gånger med olika roller: en gång som *författare* och en gång
som *den som gillar*. Aliasen gör frågan läsbar.

**2.5 – Mest aktiva kommentatorer**

```sql
SELECT u.id, u.username, COUNT(*) AS kommentarer
FROM comments c
JOIN users u ON u.id = c.author
GROUP BY u.id, u.username
HAVING COUNT(*) >= 2
ORDER BY kommentarer DESC, u.username;
```

| username | kommentarer |
|----------|-------------|
| anna | 5 |
| cissi | 3 |
| bertil | 2 |
| dahl | 2 |

Villkoret gäller ett *antal per grupp*, därför `HAVING` och inte `WHERE`.

**2.6**

```sql
-- Med LEFT JOIN: behåll inlägg där ingen kommentar hittades
SELECT p.id, p.title
FROM posts p
LEFT JOIN comments c ON c.post = p.id
WHERE c.id IS NULL
ORDER BY p.created;

-- Med NOT EXISTS
SELECT p.id, p.title
FROM posts p
WHERE NOT EXISTS (SELECT 1 FROM comments c WHERE c.post = p.id)
ORDER BY p.created;
```

Båda ger "Kaffe efter löprundan" och "Morgondimma". Här är `IS NULL` rätt: det är
`LEFT JOIN` som ger `NULL` när ingen kommentar matchar.

**2.7**

```sql
SELECT u.id, u.username, COUNT(*) AS foljare
FROM follows f
JOIN users u ON u.id = f.following
GROUP BY u.id, u.username
HAVING COUNT(*) >= 3
ORDER BY foljare DESC;
```

| username | foljare |
|----------|---------|
| anna | 4 |
| cissi | 3 |

**2.8 – Veckans topplista**

```sql
SELECT p.id, p.title, p.created, COUNT(l.id) AS gillningar
FROM posts p
LEFT JOIN likes l ON l.post = p.id
WHERE p.created >= '2026-10-05'
GROUP BY p.id, p.title, p.created
ORDER BY gillningar DESC
LIMIT 3;
```

| title | created | gillningar |
|-------|---------|------------|
| Halvmaran avklarad | 2026-10-10 14:00:00.000Z | 4 |
| Brädspelskväll igen? | 2026-10-07 12:30:00.000Z | 3 |
| Morgondimma | 2026-10-11 06:45:00.000Z | 2 |

"Kanelbullens dag" skrevs den 4 oktober, dagen innan veckan börjar. `WHERE`
filtrerar bort det *innan* grupperingen – även om det har 2 gillningar.

💡 I en riktig app skriver man `WHERE p.created >= datetime('now', '-7 days')`.
Vi använder ett fast datum så att alla får samma svar.

**2.9**

```sql
SELECT l.id, u.username, p.title
FROM likes l
JOIN posts p ON p.id = l.post
JOIN users u ON u.id = l.user
WHERE l.user = p.author;
```

dahl har gillat sitt eget inlägg "Brädspelskväll igen?". Vill man förbjuda det
behövs en regel som jämför två *olika* tabeller – det går inte med ett vanligt
`CHECK`, utan kräver en API-regel, hook eller trigger.

**2.10**

```sql
SELECT u.id, u.username, COUNT(l.id) AS mottagna
FROM users u
LEFT JOIN posts p ON p.author = u.id
LEFT JOIN likes l ON l.post = p.id
GROUP BY u.id, u.username
ORDER BY mottagna DESC, u.username;
```

| username | mottagna |
|----------|----------|
| cissi | 7 |
| anna | 5 |
| dahl | 4 |
| bertil | 3 |
| evaek | 0 |
| johan | 0 |

Båda `JOIN`:arna måste vara `LEFT`: johan har inga inlägg, och evaek har ett
inlägg utan gillningar. Här är två joins i rad *inte* ett problem (jämför 3.5),
eftersom `likes` hänger på `posts` och inte direkt på `users` – vi räknar
gillningar per inlägg och summerar.

### Nivå 3

**3.1 – Ömsesidiga följare**

```sql
SELECT f1.id, a.username AS person_a, b.username AS person_b
FROM follows f1
JOIN follows f2 ON f2.follower  = f1.following
               AND f2.following = f1.follower     -- det omvända paret finns
JOIN users a ON a.id = f1.follower
JOIN users b ON b.id = f1.following
WHERE a.username < b.username                     -- varje par bara en gång
ORDER BY a.username, b.username;
```

| person_a | person_b |
|----------|----------|
| anna | bertil |
| anna | cissi |
| cissi | dahl |

`follows` joinas med sig själv (en **självjoin**): `f1` är "a följer b" och `f2`
är "b följer a". Villkoret `a.username < b.username` gör att paret anna–bertil
inte också visas som bertil–anna. Vi jämför användarnamn i stället för id:n så
att alla får samma ordning inom paren.

**3.2 – Förslag på vilka du kan följa**

```sql
SELECT s.id, s.username AS forslag, COUNT(*) AS gemensamma
FROM users me
JOIN follows f1 ON f1.follower = me.id            -- de anna följer …
JOIN follows f2 ON f2.follower = f1.following     -- … och de som de följer
JOIN users s    ON s.id = f2.following
WHERE me.username = 'anna'
  AND s.id <> me.id                               -- inte anna själv
  AND NOT EXISTS (                                -- inte redan följd
      SELECT 1 FROM follows x
      WHERE x.follower = me.id AND x.following = s.id
  )
GROUP BY s.id, s.username
ORDER BY gemensamma DESC, s.username;
```

| forslag | gemensamma |
|---------|------------|
| dahl | 2 |

Anna följer bertil och cissi. Bertil följer anna och dahl, och cissi följer anna
och dahl. Anna själv filtreras bort, så kvar blir dahl – via två av hennes
kontakter. Det här är en förenklad variant av "personer du kanske känner" i
riktiga sociala appar.

**3.3**

```sql
SELECT p.id, p.title, COUNT(l.id) AS gillningar
FROM posts p
LEFT JOIN likes l ON l.post = p.id
GROUP BY p.id, p.title
HAVING COUNT(l.id) > (SELECT COUNT(*) * 1.0 / (SELECT COUNT(*) FROM posts) FROM likes)
ORDER BY gillningar DESC, p.title;
```

Genomsnittet är 19 / 10 = **1,9**, och sex inlägg ligger över: Halvmaran avklarad
(4), Brädspelskväll igen? (3), Höstpromenad i Slottsskogen (3), Kanelbullens dag
(2), Milen under 50 minuter! (2) och Morgondimma (2).

Två fällor:

- `* 1.0` behövs, annars blir `19 / 10` heltalsdivision = `1`. Med vår data
  råkar listan bli densamma, men snittet är fel – och med annan data blir även
  listan fel.
- Ett snitt som bara räknas på inlägg *som har* gillningar hade missat
  "Hej Kvittra!" med 0 gillningar och gett ett för högt snitt (19 / 9 ≈ 2,1) –
  då hade bara tre inlägg kommit med.

**3.4 – Senaste inlägget**

```sql
SELECT p.id, u.username, p.title, p.created
FROM posts p
JOIN users u ON u.id = p.author
WHERE p.created = (
    SELECT MAX(p2.created)
    FROM posts p2
    WHERE p2.author = p.author          -- korrelerad: samma författare
)
ORDER BY p.created DESC;
```

| username | title | created |
|----------|-------|---------|
| anna | Morgondimma | 2026-10-11 06:45:00.000Z |
| cissi | Halvmaran avklarad | 2026-10-10 14:00:00.000Z |
| dahl | Brädspelskväll igen? | 2026-10-07 12:30:00.000Z |
| bertil | Kanelbullens dag | 2026-10-04 08:00:00.000Z |
| evaek | Hej Kvittra! | 2026-09-25 09:00:00.000Z |

johan har inga inlägg och kommer inte med – precis som det ska vara.

**3.5 – Statistikvy**

Först den *felaktiga* versionen:

```sql
SELECT u.id, u.username, COUNT(p.id) AS inlagg, COUNT(f.id) AS foljare
FROM users u
LEFT JOIN posts p   ON p.author = u.id
LEFT JOIN follows f ON f.following = u.id
GROUP BY u.id, u.username;
```

| username | inlagg | foljare |
|----------|--------|---------|
| anna | 8 | 8 |
| bertil | 2 | 2 |
| cissi | 9 | 9 |
| dahl | 4 | 4 |
| evaek | 1 | 0 |
| johan | 0 | 0 |

Anna har 2 inlägg och 4 följare. Den första joinen ger 2 rader för henne, och den
andra joinen parar ihop *varje* sådan rad med *var och en* av hennes 4 följare:
2 × 4 = 8 rader. Båda `COUNT` räknar då 8. Det kallas ofta **fan-out** – två
oberoende 1:N-relationer får inte joinas i samma fråga om du ska räkna dem.

Den korrekta versionen räknar varje sak för sig med korrelerade underfrågor:

```sql
SELECT u.id,
       u.username,
       (SELECT COUNT(*) FROM posts p    WHERE p.author    = u.id) AS posts_count,
       (SELECT COUNT(*) FROM comments c WHERE c.author    = u.id) AS comments_count,
       (SELECT COUNT(*) FROM follows f  WHERE f.following = u.id) AS followers_count,
       (SELECT COUNT(*) FROM follows f  WHERE f.follower  = u.id) AS following_count,
       (SELECT COUNT(*) FROM likes l JOIN posts p ON p.id = l.post
        WHERE p.author = u.id)                                    AS likes_received
FROM users u
ORDER BY likes_received DESC, u.username;
```

| username | posts_count | comments_count | followers_count | following_count | likes_received |
|----------|-------------|----------------|-----------------|-----------------|----------------|
| cissi | 3 | 3 | 3 | 2 | 7 |
| anna | 2 | 5 | 4 | 2 | 5 |
| dahl | 2 | 2 | 2 | 1 | 4 |
| bertil | 2 | 2 | 1 | 2 | 3 |
| evaek | 1 | 1 | 0 | 2 | 0 |
| johan | 0 | 0 | 0 | 1 | 0 |

(Alternativ: `COUNT(DISTINCT p.id)` och `COUNT(DISTINCT f.id)` med joinsen ovan –
men det blir snabbt svårläst och långsamt när tabellerna växer.)

**3.6 – Envägsföljare**

```sql
SELECT f.id, u.username
FROM follows f
JOIN users u  ON u.id  = f.follower
JOIN users me ON me.id = f.following
WHERE me.username = 'anna'
  AND NOT EXISTS (
      SELECT 1 FROM follows back
      WHERE back.follower = me.id
        AND back.following = f.follower
  )
ORDER BY u.username;
```

evaek och johan. (Annas följare är bertil, cissi, evaek och johan, och hon följer
själv bertil och cissi.)

**3.7 – Gilla med räknare**

Steg 1 görs i Dashboard. Fältet blir en kolumn `likes_count` (`NUMERIC DEFAULT 0
NOT NULL`). Min 0 kontrolleras av PocketBase – inte av databasen.

Steg 2 – en `UPDATE` med korrelerad underfråga:

```sql
UPDATE posts
SET likes_count = (SELECT COUNT(*) FROM likes l WHERE l.post = posts.id);
```

Steg 3 – View collection `likes_check`:

```sql
SELECT p.id, p.title, p.likes_count, COUNT(l.id) AS faktiskt
FROM posts p
LEFT JOIN likes l ON l.post = p.id
GROUP BY p.id, p.title, p.likes_count
HAVING p.likes_count <> COUNT(l.id);
```

0 rader – räknaren stämmer.

Steg 4 – i en transaktion:

```sql
BEGIN;
INSERT INTO likes (post, user, created)
VALUES ((SELECT id FROM posts WHERE title = 'Morgondimma'),
        (SELECT id FROM users WHERE username = 'johan'),
        '2026-10-12 11:00:00.000Z');
UPDATE posts SET likes_count = likes_count + 1 WHERE title = 'Morgondimma';
COMMIT;
```

`likes_check` är fortfarande tom, och "Morgondimma" har `likes_count = 3`.

Steg 5 – samma två satser utan `BEGIN`/`COMMIT` ger
`UNIQUE constraint failed: likes.post, likes.user`. Eftersom SQL console kör hela
körningen allt-eller-inget ångras även `UPDATE`:en – räknaren är fortfarande 3,
inte 4. Det är **atomicitet**: gillningen och räknaren hänger ihop.

Varför inte `BEGIN` här? För att en sats som misslyckas *efter* `BEGIN` lämnar
transaktionen öppen i SQL console, och då slutar PocketBase svara tills du
startar om den. I en riktig app (eller hook) sköts det åt dig: kastas ett fel
blir det `ROLLBACK`.

Steg 6 – städa, i samma körning:

```sql
DELETE FROM likes
WHERE post = (SELECT id FROM posts WHERE title = 'Morgondimma')
  AND user = (SELECT id FROM users WHERE username = 'johan');
UPDATE posts SET likes_count = likes_count - 1 WHERE title = 'Morgondimma';
```

Ta sedan bort fältet i Dashboard. Fundera på vad som hade hänt med räknaren om
gillningen i stället hade tagits bort via *Cascade delete* när johan raderade
sitt konto: ingen hade minskat `likes_count`. Det är därför härledda värden är
farliga, och varför de måste hållas synkade på *ett* ställe (trigger eller hook)
och inte i varje kodväg.

**3.8 – Idempotent gilla**

```sql
INSERT INTO likes (post, user, created)
VALUES ((SELECT id FROM posts WHERE title = 'Hej Kvittra!'),
        (SELECT id FROM users WHERE username = 'johan'),
        '2026-10-12 12:00:00.000Z')
ON CONFLICT (post, user) DO NOTHING;
SELECT changes() AS andrade;
```

Första gången visar `andrade` **1** (gillningen sparades), andra gången **0**
(den fanns redan – inget fel, inget ändrat). `ON CONFLICT` fungerar eftersom det
finns ett unikt index på exakt `(post, user)`.

Det här är bättre än "kolla först, spara sedan" (övning B.2): kontrollen och
insättningen sker i en och samma sats, så det finns inget "mellan" där ett annat
anrop kan hinna emellan.

Städa:

```sql
DELETE FROM likes
WHERE post = (SELECT id FROM posts WHERE title = 'Hej Kvittra!')
  AND user = (SELECT id FROM users WHERE username = 'johan');
```

**3.9 – Kaskader**

Förutsägelse: bertil har skrivit 2 inlägg ("Mitt första surdegsbröd",
"Kanelbullens dag").

| Tabell | Försvinner | Varför |
|--------|-----------|--------|
| `posts` | 2 | hans inlägg (`posts.author`) |
| `comments` | 4 | 3 på hans inlägg (varav 1 hans egen) + 1 som han skrivit på annas inlägg |
| `likes` | 5 | 3 på hans inlägg + 2 som han gett |
| `follows` | 3 | bertil → anna, bertil → dahl, anna → bertil |

View collection som räknar det utan att ta bort något:

```sql
SELECT u.id,
       (SELECT COUNT(*) FROM posts p WHERE p.author = u.id) AS posts,
       (SELECT COUNT(*) FROM comments c
        WHERE c.author = u.id
           OR c.post IN (SELECT id FROM posts WHERE author = u.id)) AS comments,
       (SELECT COUNT(*) FROM likes l
        WHERE l.user = u.id
           OR l.post IN (SELECT id FROM posts WHERE author = u.id)) AS likes,
       (SELECT COUNT(*) FROM follows f
        WHERE f.follower = u.id OR f.following = u.id) AS follows
FROM users u
WHERE u.username = 'bertil';
```

| posts | comments | likes | follows |
|-------|----------|-------|---------|
| 2 | 4 | 5 | 3 |

Lägg märke till `OR` i `comments` och `likes`: en kommentar som bertil skrivit på
sitt *eget* inlägg ska bara räknas en gång.

Om du i stället kör `DELETE FROM users WHERE username = 'bertil';` i SQL console
försvinner **bara** raden i `users`. Allt annat blir kvar och pekar på ett id som
inte finns (föräldralösa rader), eftersom kaskaden sköts av PocketBase och inte av
SQLite. Det är skälet till att man tar bort records via Dashboard eller API:t.

---

## Del B – ACID och transaktioner

**B.1** Det är **atomiciteten** som saknas: inlägget och notiserna hör ihop men
sparades i två separata transaktioner, så bara det ena blev av. Följarna får
aldrig veta att inlägget finns. Lösning: gör båda insättningarna i **samma
transaktion på servern**. Appen gör ett anrop ("skapa inlägg"), och servern – i
PocketBase en hook med `$app.runInTransaction` – skapar både inlägget och
notiserna. Misslyckas något rullas allt tillbaka. Regeln: logik som måste hålla
ihop ska ligga på servern, inte i klienten.

**B.2**

```
 tid   Tryck 1                               Tryck 2
  1    SELECT ... → 0 (inte gillat)
  2                                          SELECT ... → 0 (inte gillat)
  3    INSERT gillning  ✓
  4                                          INSERT gillning  ✓   ← dubbelgillning
```

| Lösning | Fördelar | Nackdelar |
|---------|----------|-----------|
| **Unikt index** på `(post, user)`, gärna med `ON CONFLICT DO NOTHING` | Enkel, går inte att kringgå, gäller all kod som skriver | Fungerar bara för regler som kan uttryckas som "unikt" |
| **Kontroll + insert i samma skrivtransaktion** (`BEGIN IMMEDIATE`) | Fungerar även för krångligare regler ("max 100 gillningar per timme") | All kod som gillar måste göra rätt; låser databasen kort |
| *(bonus)* Inaktivera knappen i appen efter första trycket | Bättre upplevelse | Skyddar inte alls mot två enheter eller ett skript – bara ett komplement |

Kvittra har redan det unika indexet, så den andra `INSERT`:en misslyckas. Med
`ON CONFLICT DO NOTHING` blir resultatet bara "redan gillat" i stället för ett fel.

**B.3** Det är en **lost update**. Lös det genom att låta databasen räkna i en
enda atomär sats, och lägg till ett villkor så att värdet inte kan gå under noll:

```sql
UPDATE posts SET likes_count = likes_count + 1 WHERE id = ?;   -- gilla

UPDATE posts SET likes_count = likes_count - 1
WHERE id = ? AND likes_count > 0;                               -- ångra
```

Med `CHECK (likes_count >= 0)` i tabellen (eller *Min 0* i PocketBase) får man ett
extra skyddsnät om någon skulle skriva en sats utan `likes_count > 0`.

Men – fundera på om räknaren alls behövs. `likes_count` är ett **härlett värde**
som alltid kan räknas fram med `COUNT(*)` (övning 2.2). Då försvinner problemet
helt. Spara räknaren bara om du har mätt att `COUNT` är för långsamt, och håll den
synkad i samma transaktion som gillningen (trigger eller hook).

**B.4** Ja, inlägget finns – det är **beständighet** (durability). PocketBase
svarar först efter att transaktionen är committad, och SQLite committar först när
ändringen är skriven och synkad till disk (i WAL-läge: till `data.db-wal`). Vid
omstart läser SQLite WAL-filen och allt committat finns kvar. Transaktioner som
*inte* hann committas kastas (atomicitet).

**B.5** I WAL-läge kan de senaste committade ändringarna ligga i `data.db-wal` och
inte ännu i `data.db`. En kopia av bara `data.db` kan därför sakna data, och
kopierar man mitt i en checkpoint kan filen till och med vara trasig. Använd i
stället PocketBase inbyggda backup (**Settings → Backups**, eller via API:t), som
tar en konsistent ögonblicksbild – eller stoppa servern innan du kopierar hela
`pb_data/`.

**B.6**

| # | Problem |
|---|---------|
| a | Phantom read (en ny rad dök upp mellan två frågor) |
| b | Lost update |
| c | Dirty read |
| d | Non-repeatable read (samma rad, nytt värde) |

---

## Del C – Designuppgifter

Det här är *ett* förslag per uppgift. Andra lösningar kan vara lika bra – det
viktiga är att du kan motivera dina val. SQL:en är skriven för ren SQLite med
`PRAGMA foreign_keys = ON` och text-id:n som i PocketBase. I testdatan används
korta id:n som `'k1'` för läsbarhetens skull.

### C.1 – Direktmeddelanden

**Entiteter och attribut**

| Entitet | Attribut |
|---------|----------|
| `conversations` | `title` (bara grupper), `is_group`, `created` |
| `conversation_members` | `conversation`, `user`, `joined`, `left_at`, `last_read_at` |
| `messages` | `conversation`, `sender`, `body`, `created`, `edited`, `deleted` |
| `users` | *(finns redan)* |

**Relationer**

| Relation | Kardinalitet | Motivering |
|----------|--------------|------------|
| `users` – `conversations` | N : M | En användare är med i många konversationer; en konversation har många deltagare → kopplingstabell `conversation_members` med egna attribut (`joined`, `left_at`, `last_read_at`) |
| `conversations` – `messages` | 1 : N | Ett meddelande hör till exakt en konversation |
| `conversation_members` – `messages` | 1 : N | Ett meddelande skickas av exakt en *deltagare* i konversationen |

**ER-diagram**

```
┌──────────────────┐          ┌───────────────────────┐          ┌──────────────────┐
│      users       │          │ conversation_members  │          │  conversations   │
│──────────────────│          │───────────────────────│          │──────────────────│
│ PK id            │┼──────○< │ PK id                 │ >○─────┼ │ PK id            │
│    username      │          │ FK conversation       │          │    title         │
└──────────────────┘          │ FK user               │          │    is_group      │
                              │    joined             │          │    created       │
                              │    left_at            │          └──────────────────┘
                              │    last_read_at       │
                              │ U(conversation, user) │
                              └───────────┬───────────┘
                                          ┼
                                          │ (conversation, sender)
                                          ○<
                              ┌───────────┴───────────┐
                              │       messages        │
                              │───────────────────────│
                              │ PK id                 │
                              │ FK conversation,      │
                              │    sender             │
                              │    body               │
                              │    created, edited,   │
                              │    deleted            │
                              └───────────────────────┘
```

**SQL**

```sql
PRAGMA foreign_keys = ON;

CREATE TABLE conversations (
    id        TEXT PRIMARY KEY,
    title     TEXT,                                   -- NULL för privata (1:1) konversationer
    is_group  INTEGER NOT NULL DEFAULT 0 CHECK (is_group IN (0, 1)),
    created   TEXT NOT NULL,
    CHECK (is_group = 1 OR title IS NULL)             -- bara grupper har namn
);

CREATE TABLE conversation_members (
    id            TEXT PRIMARY KEY,
    conversation  TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    user          TEXT NOT NULL REFERENCES users(id)         ON DELETE CASCADE,
    joined        TEXT NOT NULL,
    left_at       TEXT,                               -- NULL = är fortfarande med
    last_read_at  TEXT,                               -- NULL = har aldrig läst något
    UNIQUE (conversation, user)
);
CREATE INDEX idx_members_user ON conversation_members(user);

CREATE TABLE messages (
    id            TEXT PRIMARY KEY,
    conversation  TEXT NOT NULL,
    sender        TEXT NOT NULL,
    body          TEXT NOT NULL CHECK (length(body) > 0),
    created       TEXT NOT NULL,
    edited        TEXT,                               -- NULL = aldrig redigerat
    deleted       TEXT,                               -- NULL = inte borttaget (soft delete)
    -- avsändaren måste vara medlem i just den här konversationen:
    FOREIGN KEY (conversation, sender)
        REFERENCES conversation_members(conversation, user) ON DELETE CASCADE
);
CREATE INDEX idx_messages_conversation_created ON messages(conversation, created);

-- Testdata
INSERT INTO conversations (id, title, is_group, created) VALUES
    ('k1', NULL,              0, '2026-10-01 10:00:00.000Z'),
    ('k2', 'Brädspelsgänget', 1, '2026-10-02 18:00:00.000Z');

INSERT INTO conversation_members (id, conversation, user, joined, last_read_at) VALUES
    ('m1', 'k1', (SELECT id FROM users WHERE username = 'anna'),   '2026-10-01 10:00:00.000Z', '2026-10-11 20:00:00.000Z'),
    ('m2', 'k1', (SELECT id FROM users WHERE username = 'bertil'), '2026-10-01 10:00:00.000Z', '2026-10-11 21:00:00.000Z'),
    ('m3', 'k2', (SELECT id FROM users WHERE username = 'dahl'),   '2026-10-02 18:00:00.000Z', '2026-10-12 09:00:00.000Z'),
    ('m4', 'k2', (SELECT id FROM users WHERE username = 'cissi'),  '2026-10-02 18:00:00.000Z', '2026-10-12 08:00:00.000Z'),
    ('m5', 'k2', (SELECT id FROM users WHERE username = 'anna'),   '2026-10-02 18:05:00.000Z', NULL);

INSERT INTO messages (id, conversation, sender, body, created) VALUES
    ('d1', 'k1', (SELECT id FROM users WHERE username = 'anna'),   'Har du receptet på bullarna?',  '2026-10-11 19:00:00.000Z'),
    ('d2', 'k1', (SELECT id FROM users WHERE username = 'bertil'), 'Ja! Skickar det i kväll.',      '2026-10-11 20:30:00.000Z'),
    ('d3', 'k2', (SELECT id FROM users WHERE username = 'dahl'),   'Fredag kl 18 hos mig?',         '2026-10-11 12:00:00.000Z'),
    ('d4', 'k2', (SELECT id FROM users WHERE username = 'cissi'),  'Jag kommer!',                   '2026-10-11 12:10:00.000Z'),
    ('d5', 'k2', (SELECT id FROM users WHERE username = 'dahl'),   'Anna, tar du med Carcassonne?', '2026-10-12 08:30:00.000Z');
```

**Frågor**

```sql
-- Antal olästa meddelanden per konversation för anna
SELECT c.id,
       COALESCE(c.title, 'Privat med ' || (
           SELECT u.username
           FROM conversation_members o
           JOIN users u ON u.id = o.user
           WHERE o.conversation = c.id AND o.user <> me.user)) AS konversation,
       COUNT(m.id) AS olasta
FROM conversation_members me
JOIN conversations c ON c.id = me.conversation
LEFT JOIN messages m
       ON m.conversation = me.conversation
      AND m.sender <> me.user                                   -- egna räknas inte
      AND m.deleted IS NULL
      AND (me.last_read_at IS NULL OR m.created > me.last_read_at)
WHERE me.user = (SELECT id FROM users WHERE username = 'anna')
  AND me.left_at IS NULL
GROUP BY c.id
ORDER BY olasta DESC;
```

| konversation | olasta |
|--------------|--------|
| Brädspelsgänget | 3 |
| Privat med bertil | 1 |

```sql
-- "Läst av" under varje meddelande i gruppen
SELECT m.body, group_concat(u.username, ', ') AS last_av
FROM messages m
JOIN conversation_members cm ON cm.conversation = m.conversation
                            AND cm.user <> m.sender
                            AND cm.last_read_at >= m.created
JOIN users u ON u.id = cm.user
WHERE m.conversation = 'k2'
GROUP BY m.id
ORDER BY m.created;
```

| body | last_av |
|------|---------|
| Fredag kl 18 hos mig? | cissi |
| Jag kommer! | dahl |

(Det sista meddelandet har ingen läsare än och saknas därför – använd `LEFT JOIN`
om det ska synas med tom lista.)

```sql
-- Skydd: cissi är inte med i k1 och kan inte skriva där
INSERT INTO messages (id, conversation, sender, body, created)
VALUES ('d9', 'k1', (SELECT id FROM users WHERE username = 'cissi'), 'Hej!',
        '2026-10-12 10:00:00.000Z');
-- Error: FOREIGN KEY constraint failed
```

**Motivering och val**

- **3NF:** Namn och e-post finns bara i `users`. Medlemskap och läsläge ligger i
  `conversation_members`, eftersom de beror på *paret* (konversation, användare)
  – inte på konversationen eller användaren ensam.
- **Avsändaren måste vara medlem:** den sammansatta främmande nyckeln
  `(conversation, sender) → conversation_members(conversation, user)` gör att
  databasen själv vägrar meddelanden från någon som inte är med. Det kräver att
  `(conversation, user)` är `UNIQUE` i föräldratabellen.
- **Läskvitton som `last_read_at` per deltagare** i stället för en rad per
  (meddelande, läsare): en rad per deltagare och konversation i stället för en per
  meddelande och läsare. Det räcker både för "antal olästa" och för "läst av", så
  länge man läser i ordning (som i alla chattappar). Behövs exakta kvitton per
  meddelande blir det en kopplingstabell `message_reads (message, user, read_at)`.
- **`NULL`-fällan:** `m.created > NULL` är aldrig sant. Därför står
  `me.last_read_at IS NULL OR ...` i frågan – annars hade anna fått 0 olästa i en
  konversation hon aldrig öppnat.
- **Lämna en konversation** sätter `left_at` i stället för att ta bort raden,
  annars skulle kaskaden radera personens gamla meddelanden.
- **Redigera/ta bort** med `edited` och `deleted` (soft delete): andra deltagare
  kan se "meddelandet togs bort".
- **Medvetet ej löst i databasen:** "bara en privat konversation per par" och "en
  privat konversation har exakt två medlemmar" kräver regler över flera rader –
  det görs i en hook i PocketBase (modul 02).

### C.2 – Album och foton

**Entiteter och attribut**

| Entitet | Attribut |
|---------|----------|
| `albums` | `owner`, `title`, `description`, `visibility`, `cover_photo`, `created` |
| `photos` | `album`, `title`, `image`, `position`, `created` |
| `photo_tags` | `photo`, `user`, `x`, `y` |
| `users` | *(finns redan)* |

**Relationer**

| Relation | Kardinalitet |
|----------|--------------|
| `users` – `albums` | 1 : N (en ägare, många album) |
| `albums` – `photos` | 1 : N (ett foto ligger i exakt ett album) |
| `albums` – `photos` (omslag) | N : 1, valfri (ett album har noll eller ett omslagsfoto) |
| `photos` – `users` (taggar) | N : M via `photo_tags` (med egna attribut: position på bilden) |

```
users ┼──○< albums ┼──○< photos ┼──○< photo_tags >○──┼ users
              ○│                  ┼
               └── cover_photo ───┘    (noll eller ett omslag per album)
```

**SQL**

```sql
PRAGMA foreign_keys = ON;

CREATE TABLE albums (
    id           TEXT PRIMARY KEY,
    owner        TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title        TEXT NOT NULL CHECK (length(title) > 0),
    description  TEXT NOT NULL DEFAULT '',
    visibility   TEXT NOT NULL DEFAULT 'public'
                 CHECK (visibility IN ('public', 'followers', 'private')),
    cover_photo  TEXT REFERENCES photos(id) ON DELETE SET NULL,   -- NULL = inget omslag valt
    created      TEXT NOT NULL
);
CREATE INDEX idx_albums_owner ON albums(owner);

CREATE TABLE photos (
    id        TEXT PRIMARY KEY,
    album     TEXT NOT NULL REFERENCES albums(id) ON DELETE CASCADE,
    title     TEXT NOT NULL DEFAULT '',
    image     TEXT NOT NULL,                  -- filnamn/URL, inte själva bilden
    position  INTEGER NOT NULL CHECK (position > 0),
    created   TEXT NOT NULL,
    UNIQUE (album, position)                  -- två foton kan inte ha samma plats
);

CREATE TABLE photo_tags (
    photo  TEXT NOT NULL REFERENCES photos(id) ON DELETE CASCADE,
    user   TEXT NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
    x      REAL NOT NULL CHECK (x BETWEEN 0 AND 1),   -- var på bilden (andel av bredden)
    y      REAL NOT NULL CHECK (y BETWEEN 0 AND 1),
    PRIMARY KEY (photo, user)
);
CREATE INDEX idx_photo_tags_user ON photo_tags(user);

-- Testdata. Ordningen spelar roll: album först (utan omslag), sedan foton,
-- sist omslaget.
INSERT INTO albums (id, owner, title, visibility, created) VALUES
    ('a1', (SELECT id FROM users WHERE username = 'anna'),  'Hösten 2026', 'public',    '2026-10-01 09:00:00.000Z'),
    ('a2', (SELECT id FROM users WHERE username = 'cissi'), 'Halvmaran',   'followers', '2026-10-10 16:00:00.000Z'),
    ('a3', (SELECT id FROM users WHERE username = 'dahl'),  'Spelkvällar', 'private',   '2026-10-08 10:00:00.000Z');

INSERT INTO photos (id, album, title, image, position, created) VALUES
    ('f1', 'a1', 'Slottsskogen',  'slottsskogen.jpg', 1, '2026-10-01 09:05:00.000Z'),
    ('f2', 'a1', 'Dimma över ån', 'dimma.jpg',        2, '2026-10-11 07:00:00.000Z'),
    ('f3', 'a2', 'Målgång',       'malgang.jpg',      1, '2026-10-10 16:05:00.000Z'),
    ('f4', 'a2', 'Medaljen',      'medalj.jpg',       2, '2026-10-10 16:06:00.000Z');

UPDATE albums SET cover_photo = 'f2' WHERE id = 'a1';

INSERT INTO photo_tags (photo, user, x, y) VALUES
    ('f3', (SELECT id FROM users WHERE username = 'cissi'), 0.40, 0.55),
    ('f3', (SELECT id FROM users WHERE username = 'anna'),  0.75, 0.50),
    ('f4', (SELECT id FROM users WHERE username = 'cissi'), 0.50, 0.40);
```

**Frågor**

```sql
-- Varje album med ägare, antal foton och omslagsbildens titel
SELECT a.id, a.title, u.username AS owner,
       COUNT(p.id) AS antal_foton,
       cover.title AS omslag
FROM albums a
JOIN users u           ON u.id = a.owner
LEFT JOIN photos p     ON p.album = a.id
LEFT JOIN photos cover ON cover.id = a.cover_photo
GROUP BY a.id, a.title, u.username, cover.title
ORDER BY a.created;
```

| title | owner | antal_foton | omslag |
|-------|-------|-------------|--------|
| Hösten 2026 | anna | 2 | Dimma över ån |
| Spelkvällar | dahl | 0 | NULL |
| Halvmaran | cissi | 2 | NULL |

`photos` joinas två gånger med olika roller: en gång för att räkna fotona och en
gång för att hämta omslaget. (Det går bra här, eftersom omslags-joinen ger högst
en rad per album och inte multiplicerar raderna.)

```sql
-- Vilka album får anna se?
SELECT a.id, a.title, owner.username AS owner, a.visibility
FROM albums a
JOIN users owner ON owner.id = a.owner
JOIN users me    ON me.username = 'anna'
WHERE a.owner = me.id
   OR a.visibility = 'public'
   OR (a.visibility = 'followers'
       AND EXISTS (SELECT 1 FROM follows f
                   WHERE f.follower = me.id AND f.following = a.owner))
ORDER BY a.created;
```

| title | owner | visibility |
|-------|-------|------------|
| Hösten 2026 | anna | public |
| Halvmaran | cissi | followers |

Anna följer cissi och får se "Halvmaran". Dahls privata album syns inte. (I
PocketBase skriver du samma logik som en API-regel på `albums` i modul 02.)

```sql
-- Två foton på samma plats i samma album → fel
INSERT INTO photos (id, album, title, image, position, created)
VALUES ('f5', 'a1', 'Dubblett', 'x.jpg', 2, '2026-10-12 10:00:00.000Z');
-- Error: UNIQUE constraint failed: photos.album, photos.position
```

**Motivering och val**

- **Bilderna** lagras som filer, och tabellen sparar bara filnamnet/URL:en
  (kapitel 4.6). I PocketBase är `image` ett fält av typen *File*, som dessutom
  kan skapa **miniatyrbilder automatiskt** – därför finns ingen kolumn för
  miniatyren. Den vore ett härlett värde.
- **Ordningen** sparas som `position` med `UNIQUE (album, position)`. Att byta plats
  på två foton kräver då ett mellansteg (flytta det ena till en ledig plats först),
  annars krockar det unika villkoret.
- **Cirkulär referens:** `albums.cover_photo` pekar på `photos`, och
  `photos.album` pekar på `albums`. Därför måste `cover_photo` få vara `NULL`:
  albumet skapas först utan omslag, fotona sedan, och omslaget sätts sist.
  `ON DELETE SET NULL` gör att albumet blir utan omslag om omslagsfotot tas bort.
- **Omslaget måste ligga i samma album** – det går inte att uttrycka med en enkel
  främmande nyckel. Det kontrolleras i en hook (eller med en sammansatt främmande
  nyckel, som i C.1, men det blir krångligt i kombination med `SET NULL`).
- **Synlighet** som `TEXT` + `CHECK (... IN (...))` – i PocketBase fälttypen
  *Select*. Tre fasta värden behöver ingen egen tabell.
- **3NF:** Ägarens uppgifter finns bara i `users`, albumets bara i `albums`.
  Taggningens position (`x`, `y`) beror på paret (foto, användare) och ligger
  därför i kopplingstabellen.

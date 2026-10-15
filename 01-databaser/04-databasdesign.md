# Kapitel 4 – Databasdesign

> **Mål med kapitlet:** Du ska kunna gå från en beskrivning i vanlig text till en
> genomtänkt datamodell: hitta entiteter, attribut och relationer, bestämma
> kardinalitet, rita ett ER-diagram och normalisera. Du ska också kunna fatta
> medvetna beslut om nycklar, datatyper, `NULL`, index och borttagning.

En databas är svår att ändra när den väl är full av data och flera appar
använder den. Ett par timmars eftertanke i början sparar veckor senare.

## 4.1 Designprocessen

```
  ┌───────────────┐   ┌───────────────┐   ┌───────────────┐   ┌───────────────┐   ┌───────────────┐
  │ 1. Entiteter  │──►│ 2. Attribut   │──►│ 3. Relationer │──►│ 4. Normalisera│──►│ 5. Villkor,   │
  │  (substantiv) │   │ (egenskaper)  │   │ & kardinalitet│   │  (1NF–3NF)    │   │ typer, index  │
  └───────────────┘   └───────────────┘   └───────────────┘   └───────────────┘   └───────────────┘
```

Vi går igenom stegen med Kvittra. Utgångspunkten är produktidén, skriven i
vanlig text:

> *"Kvittra är en enkel social app. **Användare** registrerar sig med e-post och
> ett unikt **användarnamn**, och kan skriva en kort bio och länka till sin
> webbplats. Användare skriver **inlägg** med rubrik och text. Andra kan
> **kommentera** och **gilla** inlägg – men bara gilla samma inlägg en gång. Man
> kan **följa** andra användare och ser då deras inlägg i sitt **flöde**. Vid
> varje inlägg visas **antal gillningar**."*

### Steg 1: Entiteter – leta efter substantiv

En **entitet** är en "sak" som du vill spara information om och som har en egen
identitet. Ett bra knep är att stryka under substantiven i texten:

| Substantiv | Entitet? | Motivering |
|------------|----------|------------|
| användare | ✅ `users` | Loggar in, gör saker, har egna egenskaper |
| inlägg | ✅ `posts` | Har rubrik, text, författare, tidpunkt |
| kommentar | ✅ `comments` | Har egen text, egen författare, egen tidpunkt |
| gillning | ✅ `likes` | En händelse: *vem* gillade *vad*, *när* |
| följa | ✅ `follows` | En händelse: *vem* följer *vem*, sedan *när* |
| användarnamn, e-post, bio | ❌ attribut | Egenskaper hos en användare |
| flöde | ❌ en **fråga** | Inlägg från dem jag följer – räknas fram, sparas inte |
| antal gillningar | ❌ **härlett** | Kan räknas fram ur `likes` (se 4.3 och 4.9) |

💡 **Tips:** Verb kan också bli entiteter! "Gilla" och "följa" är handlingar, men
eftersom vi vill spara *vem*, *vad* och *när* blir de egna tabeller. Om något bara
har *ett* värde och inga egna egenskaper är det däremot ofta ett attribut.

### Steg 2: Attribut

För varje entitet: vilka egenskaper behöver vi? Fråga dig *"vad ska appen visa,
söka på eller räkna med?"*

| Entitet | Attribut |
|---------|----------|
| `users` | `username`, `name`, `email`, `bio`, `website`, `created` (+ lösenord, som PocketBase sköter) |
| `posts` | `title`, `body`, `created` |
| `comments` | `body`, `created` |
| `likes` | `created` |
| `follows` | `created` |

Relationerna (vem som skrev, vilket inlägg) lägger vi till i steg 3.

### Steg 3: Relationer och kardinalitet

Nu frågar vi hur entiteterna hänger ihop, och **hur många** av varje som kan höra
ihop – det kallas **kardinalitet**. Ställ alltid frågan *åt båda hållen*:

- *En användare* kan skriva *hur många* inlägg? → **många**.
- *Ett inlägg* har *hur många* författare? → **en**.
- ⇒ users **1 : N** posts.

- *En användare* kan gilla *hur många* inlägg? → **många**.
- *Ett inlägg* kan gillas av *hur många* användare? → **många**.
- ⇒ users **N : M** posts (via `likes`).

| Typ | Betydelse | Exempel | Hur det lagras |
|-----|-----------|---------|----------------|
| **1 : 1** | En till en | En användare ↔ en rad med notisinställningar | FK med `UNIQUE` i ena tabellen (eller samma tabell) |
| **1 : N** | En till många | Ett inlägg ↔ många kommentarer | FK på **N**-sidan: `comments.post` |
| **N : M** | Många till många | Användare ↔ inlägg de gillat | **Kopplingstabell** med två FK: `likes` |

### 1:N – främmande nyckel på "många"-sidan

```
posts (1) ─────────< (N) comments
                         └─ post TEXT REFERENCES posts(id)
```

Försök aldrig lägga det åt andra hållet, med en lista av kommentar-id:n i
`posts`. Mer om det i avsnitt 4.9.

### N:M – kopplingstabell

Ett inlägg kan gillas av många, och en användare kan gilla många inlägg. Det går
inte att lösa med en främmande nyckel i någon av tabellerna. Lösningen är en
tredje tabell, en **kopplingstabell** (*junction table*): `likes`.

```
users (1) ───< (N) likes (N) >─── (1) posts

┌──────────┐      ┌──────────────────┐      ┌──────────┐
│  users   │      │      likes       │      │  posts   │
│──────────│      │──────────────────│      │──────────│
│ id    PK │◄─────│ user   FK        │      │ id    PK │
│ username │      │ post   FK        │─────►│ title    │
│ …        │      │ created          │      │ …        │
└──────────┘      │ UNIQUE(post,user)│      └──────────┘
                  └──────────────────┘
```

Kopplingstabellen kan ha egna attribut – här `created` ("gillade för 2 timmar
sedan"). Den har två varianter av nyckel:

| Variant | Exempel | När |
|---------|---------|-----|
| Sammansatt primärnyckel | `PRIMARY KEY (post, user)` | Klassisk SQL, ingen extra kolumn |
| Eget `id` + `UNIQUE (post, user)` | Kvittras `likes` | När varje rad behöver ett eget id – som i PocketBase, där varje record alltid har ett `id` |

Båda ger samma skydd mot dubbelgillningar.

Ett andra exempel på N:M: **hashtaggar**. Ett inlägg kan ha många taggar och en
tagg kan sitta på många inlägg:

```sql
CREATE TABLE tags (
    id    TEXT PRIMARY KEY,
    name  TEXT NOT NULL UNIQUE
);

CREATE TABLE post_tags (
    post  TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    tag   TEXT NOT NULL REFERENCES tags(id)  ON DELETE CASCADE,
    PRIMARY KEY (post, tag)          -- samma tagg kan inte sättas två gånger
);
CREATE INDEX idx_post_tags_tag ON post_tags(tag);

-- Alla inlägg med #kaffe
SELECT p.title
FROM posts p
JOIN post_tags pt ON pt.post = p.id
JOIN tags t       ON t.id = pt.tag
WHERE t.name = 'kaffe';
```

### N:M mot samma tabell – `follows`

`follows` kopplar ihop `users` med `users`. Båda främmande nycklarna pekar på
samma tabell, så de får namn efter sin **roll**: `follower` (den som följer) och
`following` (den som blir följd).

```
          ┌────────────── follower ──────────────┐
          ▼                                      │
   ┌──────────┐                           ┌──────┴──────┐
   │  users   │◄──────── following ───────│   follows   │
   └──────────┘                           └─────────────┘
```

Att följa är **riktat**: att anna följer bertil betyder inte att bertil följer
anna. Därför är `(anna, bertil)` och `(bertil, anna)` två olika rader.

💡 **Tips:** Facebooks "vänner" är däremot **symmetriskt** – är anna vän med
bertil är bertil vän med anna. Då vill man inte spara samma vänskap två gånger.
Ett vanligt knep är en rad per par med `CHECK (user_a < user_b)`, så att
`(anna, bertil)` bara kan sparas på ett sätt.

💡 **Tips:** I PocketBase kan ett *Relation*-fält tillåta flera värden
(*Multiple*). Det lagras som en JSON-lista i en kolumn – praktiskt, men bakom
kulisserna en annan lösning än en kopplingstabell. Vill du ha extra data på
kopplingen (som `created` för en gillning) eller ett unikt villkor behöver du en
egen collection för kopplingen, precis som `likes` och `follows`.

## 4.2 ER-diagram

Ett **ER-diagram** (*Entity–Relationship*) visar entiteter, attribut och
relationer. Det finns flera notationer. Den vanligaste i praktiken är
**kråkfotsnotation** (*crow's foot*):

```
  ──┼──   exakt en               ──○┼──  noll eller en
  ──<     många                  ──○<    noll eller många
  ──┼<    en eller många
```

Kvittra:

```
                         ┌──────────────┐
                         │   follows    │
                         │──────────────│
          ┌─────────────<│ FK follower  │
          │   ┌─────────<│ FK following │
          │   │          │    created   │
          │   │          │ U(follower,  │
          │   │          │   following) │
          │   │          └──────────────┘
          ┼   ┼
     ┌────┴───┴─────┐            ┌──────────────┐
     │    users     │            │    posts     │
     │──────────────│            │──────────────│
     │ PK id        │┼────────○< │ PK id        │
     │    username U│            │ FK author    │
     │    name      │            │    title     │
     │    email    U│            │    body      │
     │    bio       │            │    created   │
     │    website   │            └──┬────────┬──┘
     │    created   │               ┼        ┼
     └──┬────────┬──┘               │        │
        ┼        ┼                  │        │
        │        │                  ○<       ○<
        │        │       ┌──────────┴───┐  ┌─┴────────────┐
        │        └─────○<│   comments   │  │    likes     │
        │                │──────────────│  │──────────────│
        │                │ PK id        │  │ PK id        │
        │                │ FK post      │  │ FK post      │
        │                │ FK author    │  │ FK user      │>○─────┐
        │                │    body      │  │    created   │       │
        │                │    created   │  │ U(post,user) │       │
        │                └──────────────┘  └──────────────┘       │
        └─────────────────────────────────────────────────────────┘

PK = primärnyckel, FK = främmande nyckel, U = unik
```

Läs t.ex. linjen mellan `users` och `posts`: ett inlägg har *exakt en* författare,
och en användare har *noll eller många* inlägg (Johan har inga).

💡 **Tips:** Rita gärna på papper eller använd verktyg som
[dbdiagram.io](https://dbdiagram.io) eller [drawio](https://app.diagrams.net).
Ett ER-diagram är också det bästa sättet att diskutera en design med andra.

## 4.3 Normalisering

**Normalisering** är en metod för att ta bort upprepning (redundans) och därmed
risken att samma sak står olika på olika ställen. Man pratar om *normalformer*.
I praktiken räcker de tre första.

### Verklig data är sällan normaliserad

Test-API:t [JSONPlaceholder](https://jsonplaceholder.typicode.com), som du
använder i modul 03, returnerar kommentarer i den här formen (förkortat, med
påhittade adresser):

```json
[
  { "postId": 1, "id": 1, "name": "id labore ex et quam",  "email": "eliseo@example.com",  "body": "…" },
  { "postId": 1, "id": 2, "name": "quo vero reiciendis",   "email": "jayne@example.com",   "body": "…" },
  { "postId": 2, "id": 6, "name": "et fugit eligendi",     "email": "eliseo@example.com",  "body": "…" }
]
```

Lägg märke till att kommentarens **författare** inte är en främmande nyckel till
`users` – det är bara en e-postadress som upprepas på varje kommentar personen
skrivit. Byter Eliseo e-post finns det inget sätt att veta att de gamla
kommentarerna är hans. Och vem som helst kan skriva vilken adress som helst.
I Kvittra ersätter vi `email` med `author → users`. Det är exakt vad
normalisering handlar om.

### Från kalkylark till tabeller

Vi utgår från Kvittras allra första version – ett kalkylark med inlägg och vem som
gillat dem:

| post | title | author | author_email | author_website | liked_by |
|------|-------|--------|--------------|----------------|----------|
| 1 | Höstpromenad i Slottsskogen | Anna Andersson | anna@example.com | https://anna.example.com | bertil, cissi, dahl |
| 2 | Mitt första surdegsbröd | Bertil Berg | bertil@example.com | – | anna |
| 3 | Morgondimma | Anna Andersson | **ana@example.com** | https://anna.example.com | bertil, cissi |

Problemen syns redan: Annas e-post är felstavad på rad 3. Vilken är rätt? Det här
är **uppdateringsanomalier**:

| Anomali | Exempel |
|---------|---------|
| **Uppdatering** | Anna byter e-post → måste ändras på alla hennes rader. Missas en blir det motsägelser. |
| **Insättning** | Vi kan inte lägga in en ny användare (t.ex. Johan) förrän han har skrivit ett inlägg. |
| **Borttagning** | Tar vi bort Bertils enda inlägg försvinner all information om Bertil. |

### Första normalformen (1NF): ett värde per cell

> **Regel:** Varje cell innehåller ett **enda, odelbart** värde. Inga listor,
> inga upprepade kolumner (`liker1`, `liker2`, `liker3`). Varje rad är unik.

Kolumnen `liked_by` bryter mot 1NF – den innehåller en lista. Vi delar upp den så
att varje gillning blir en egen rad:

| post | title | author | author_email | author_website | liker |
|------|-------|--------|--------------|----------------|-------|
| 1 | Höstpromenad i Slottsskogen | Anna Andersson | anna@example.com | https://anna.example.com | bertil |
| 1 | Höstpromenad i Slottsskogen | Anna Andersson | anna@example.com | https://anna.example.com | cissi |
| 1 | Höstpromenad i Slottsskogen | Anna Andersson | anna@example.com | https://anna.example.com | dahl |
| 2 | Mitt första surdegsbröd | Bertil Berg | bertil@example.com | – | anna |
| 3 | Morgondimma | Anna Andersson | anna@example.com | https://anna.example.com | bertil |
| 3 | Morgondimma | Anna Andersson | anna@example.com | https://anna.example.com | cissi |

Nu är tabellen i 1NF. En rad identifieras av `(post, liker)`. Men upprepningen
är ännu värre!

### Andra normalformen (2NF): hela nyckeln

> **Regel:** 1NF + varje kolumn som inte ingår i nyckeln ska bero på **hela**
> nyckeln, inte bara en del av den.

Nyckeln är `(post, liker)`. Men `title`, `author`, `author_email` och
`author_website` beror bara på `post` – inte på vem som gillade. Det är ett
**partiellt beroende**. Lösning: flytta ut det som bara beror på inlägget till en
egen tabell.

```
posts_2nf                                                    likes
┌──────┬─────────────────────────────┬────────────────┬───┐  ┌──────┬────────┐
│ post │ title                       │ author         │ … │  │ post │ liker  │
├──────┼─────────────────────────────┼────────────────┼───┤  ├──────┼────────┤
│ 1    │ Höstpromenad i Slottsskogen │ Anna Andersson │ … │  │ 1    │ bertil │
│ 2    │ Mitt första surdegsbröd     │ Bertil Berg    │ … │  │ 1    │ cissi  │
│ 3    │ Morgondimma                 │ Anna Andersson │ … │  │ 1    │ dahl   │
└──────┴─────────────────────────────┴────────────────┴───┘  │ 2    │ anna   │
                                                             │ …    │ …      │
                                                             └──────┴────────┘
```

Varje inläggs titel står nu på exakt ett ställe.

💡 **Tips:** 2NF är bara intressant när nyckeln består av flera kolumner. Har
tabellen en enkel `id`-nyckel är den automatiskt i 2NF (om den är i 1NF) – men
läs vidare, för då flyttar problemet till 3NF.

### Tredje normalformen (3NF): inga transitiva beroenden

> **Regel:** 2NF + kolumner som inte är nyckel får inte bero på **andra** kolumner
> som inte är nyckel. "Varje kolumn ska bero på nyckeln, hela nyckeln och inget
> annat än nyckeln."

I `posts_2nf` gäller: inlägg → `author` → `author_email` och
`author` → `author_website`. E-posten beror på författaren, inte på inlägget. Det
är ett **transitivt beroende** – och det är därför Annas e-post kunde stå på två
olika sätt.

Lösning: bryt ut `users`, och låt inlägget bara peka på författaren med en
främmande nyckel. Samtidigt låter vi `likes` peka på `users` i stället för att
spara namnet:

```
users                                              posts
┌─────┬──────────┬──────────────────┬─────────┐    ┌─────┬────────┬─────────────────────────────┐
│ id  │ username │ email            │ website │    │ id  │ author │ title                       │
├─────┼──────────┼──────────────────┼─────────┤    ├─────┼────────┼─────────────────────────────┤
│ u1  │ anna     │ anna@example.com │ https…  │    │ p1  │ u1     │ Höstpromenad i Slottsskogen │
│ u2  │ bertil   │ bertil@example…  │         │    │ p2  │ u2     │ Mitt första surdegsbröd     │
│ u3  │ cissi    │ cecilia@example… │ https…  │    │ p3  │ u1     │ Morgondimma                 │
│ …   │ …        │ …                │ …       │    └─────┴────────┴─────────────────────────────┘
└─────┴──────────┴──────────────────┴─────────┘
likes
┌─────┬──────┬──────┐
│ id  │ post │ user │
├─────┼──────┼──────┤
│ l1  │ p1   │ u2   │
│ l2  │ p1   │ u3   │
│ …   │ …    │ …    │
└─────┴──────┴──────┘
```

Och vips – vi har landat i precis Kvittras datamodell. Alla tre anomalierna är
borta:

| Anomali | Efter normalisering |
|---------|---------------------|
| Anna byter e-post | En rad i `users` ändras |
| Ny användare utan inlägg | En rad i `users` |
| Bertils enda inlägg tas bort | Bertil finns kvar i `users` |

💡 **Tips:** En snabb tumregel för 3NF: *"Om jag ändrar det här värdet, måste jag
då ändra det på flera rader?"* Om ja – bryt ut det i en egen tabell.

### När ska man denormalisera?

**Denormalisering** betyder att man medvetet lägger in upprepad eller härledd data
för att vinna prestanda eller enkelhet. Det är okej – men gör det medvetet och
med en plan för hur datan hålls synkad.

Det klassiska exemplet i en social app är `likes_count` på `posts`. Antalet
gillningar är ett **härlett värde** – det kan alltid räknas fram:

```sql
SELECT COUNT(*) FROM likes WHERE post = ?;
```

Så länge Kvittra är litet är det precis vad vi ska göra. Men när ett flöde ska
visa 20 inlägg med räknare för miljontals användare kan det löna sig att spara
räknaren. Då måste den hållas synkad, alltid i **samma transaktion** som
gillningen (kapitel 3). Ett sätt är en **trigger** – SQL som databasen kör
automatiskt vid varje ändring:

```sql
CREATE TRIGGER likes_after_insert AFTER INSERT ON likes
BEGIN
    UPDATE posts SET likes_count = likes_count + 1 WHERE id = NEW.post;
END;

CREATE TRIGGER likes_after_delete AFTER DELETE ON likes
BEGIN
    UPDATE posts SET likes_count = likes_count - 1 WHERE id = OLD.post;
END;
```

En trigger körs i samma transaktion som satsen som utlöste den, så räknaren och
gillningarna kan aldrig komma i otakt. (I PocketBase gör man samma sak med en
hook, se kapitel 3.6.)

| Situation | Exempel | Varför det kan vara okej |
|-----------|---------|--------------------------|
| Tunga beräkningar som läses ofta | `likes_count`, `comment_count` på `posts` | Slipper räkna vid varje visning av flödet |
| Historik som *inte* ska ändras | En tabell `post_edits` som sparar den gamla texten när ett inlägg redigeras | En kopia med flit: historiken ska visa hur det *såg ut då* |
| Rapporter/statistik | En sammanställningstabell "aktiva användare per dag" | Rapporter ska inte belasta den vanliga databasen |

⚠️ **Varning:** Börja alltid normaliserat. Denormalisera först när du har ett
*mätt* prestandaproblem. Det är mycket lättare att lägga till en kopia senare än
att städa upp i inkonsekvent data.

## 4.4 Välja nycklar

### Surrogatnyckel eller naturlig nyckel?

| | Naturlig nyckel | Surrogatnyckel |
|---|-----------------|----------------|
| Vad | Ett värde som finns "på riktigt" | Ett påhittat id utan betydelse |
| Exempel | `username`, `email`, personnummer | `id = 17`, `id = 'k3j9x0p2m1q8w7e'` |
| Fördel | Ingen extra kolumn, betyder något | Ändras aldrig, alltid unik, kort |
| Nackdel | Kan ändras (folk byter användarnamn och e-post!), kan vara känsligt (personnummer) | Måste joinas för att få något läsbart |

**Rekommendation:** Använd en surrogatnyckel (`id`) som primärnyckel, och lägg
`UNIQUE` på de naturliga nycklarna. Det är precis vad vi gör med
`users.username` och `users.email`. Användaren kan byta användarnamn utan att
ett enda inlägg, en kommentar eller en gillning behöver ändras.

### Auto-increment eller slumpat id?

| | `INTEGER` auto-increment | UUID / slumpad sträng |
|---|--------------------------|------------------------|
| Exempel | `1, 2, 3, …` | `'550e8400-e29b-41d4-a716-446655440000'`, `'k3j9x0p2m1q8w7e'` |
| Storlek | Liten, snabb | Större |
| Läsbarhet | Lätt att prata om ("inlägg 5") | Svårt |
| Kan gissas? | Ja – `/posts/6` ligger nog efter `/posts/5`, och avslöjar hur många inlägg som finns | Nej |
| Kan skapas i appen (offline)? | Nej, databasen delar ut | Ja |
| Slå ihop två databaser | Krockar | Krockar (praktiskt taget) aldrig |

PocketBase använder slumpade 15-teckens id:n som `k3j9x0p2m1q8w7e` – i praktiken
samma idé som UUID. JSONPlaceholder använder heltal (`"id": 1`), vilket är lättare
att läsa i exempel.

⚠️ **Varning:** Att id:n går att gissa är ingen säkerhetsbrist i sig, men du får
aldrig lita på att "ingen vet id:t". Behörighet ska alltid kontrolleras
(i PocketBase: API rules).

## 4.5 Namnkonventioner

Det viktigaste är att vara **konsekvent**. I den här kursen gäller:

| Regel | Exempel | Inte |
|-------|---------|------|
| `snake_case` | `likes_count`, `avatar_url` | `likesCount`, `LikesCount` |
| Engelska namn | `posts`, `comments` | `inlagg`, `kommentarer` |
| Tabeller i plural | `users`, `likes` | `user`, `like` |
| Primärnyckel heter `id` | `id` | `user_id` i `users`-tabellen |
| FK heter som det den pekar på (singular)… | `comments.post`, `likes.user` | `comments.posts` |
| … eller efter sin **roll** | `posts.author`, `follows.follower`, `follows.following` | `follows.user1`, `follows.user2` |
| Enhet i namnet när det inte är självklart | `duration_sec`, `size_bytes` | `duration`, `size` |
| Booleans som påståenden | `is_private`, `verified` | `status2`, `flag` |
| Undvik reserverade ord | `created`, `author` | `order`, `group`, `user`, `end` |

💡 **Tips:** Många projekt döper främmande nycklar till `user_id`, `post_id` osv.
Det är också en bra konvention. Vi använder `user`, `post` eftersom det är så
PocketBase-relationer brukar heta. Huvudsaken är att man väljer *en* stil.

⚠️ **Varning:** Som tabellen visar är `user` egentligen ett dåligt kolumnnamn –
det är ett reserverat ord i SQL, och i PostgreSQL måste det skrivas `"user"`. Vi
behåller `likes.user` i kursen eftersom det är kursens datamodell och SQLite
accepterar det, men i en ny design vore `liked_by` eller `user_id` säkrare.

## 4.6 Datatyper – välj rätt

### Datum och tid: UTC och ISO 8601

- Spara **alltid i UTC** (svensk tid är UTC+1 på vintern och UTC+2 på sommaren).
  Konvertera till lokal tid först när du visar det för användaren.
- Använd formatet **ISO 8601**: `2026-10-11 06:45:00` eller
  `2026-10-11T06:45:00Z`. Det är entydigt (inte "10/11" – oktober eller
  november?) och sorteras rätt som text. PocketBase sparar
  `2026-10-11 06:45:00.000Z`, där `Z` betyder UTC.

```sql
SELECT datetime('now');                        -- nu, i UTC
SELECT datetime('now', 'localtime');           -- nu, i datorns lokala tid
SELECT date('2026-10-12', '-7 days');          -- 2026-10-05: "senaste veckan" börjar här
SELECT (unixepoch('2026-10-11 06:45:00.000Z')
      - unixepoch('2026-10-10 14:00:00.000Z')) / 3600.0 AS timmar;   -- 16.75
```

`unixepoch()` ger antal sekunder sedan 1970-01-01 (finns från SQLite 3.38). Har du
en äldre version, använd `strftime('%s', ...)` i stället.

⚠️ **Varning:** Ett klassiskt fel är att spara lokal tid utan tidszon. Två gånger
om året (sommartid) blir det då en timme som finns två gånger, eller inte alls –
och ett inlägg kan se ut att vara skrivet *före* kommentaren till det.

### Bilder och filer: spara en sökväg, inte filen

En profilbild eller ett foto till ett inlägg *kan* lagras som `BLOB` i databasen,
men gör det inte:

- databasen blir enorm, och varje backup tar med alla bilder,
- bilder kan inte cachas och levereras effektivt av en webbserver eller ett CDN,
- varje fråga som råkar läsa kolumnen drar med sig megabyte av data.

Spara i stället **filen på disk eller i en molnlagring** och bara **filnamnet
eller URL:en** i databasen: `avatar TEXT`, `image_url TEXT`. Så gör PocketBase:
fältet *File* (som `avatar` i `users`) sparar filnamnet i tabellen, och själva
filen hamnar i `pb_data/storage/`. JSONPlaceholder gör likadant – ett foto har
`url` och `thumbnailUrl`, inte bilddata.

### Pengar: heltal i ören

Kvittra hanterar inga pengar än, men om ni inför en betalversion: spara **aldrig**
pengar som flyttal (`REAL`). Flyttal kan inte representera alla decimaltal exakt:

```sql
SELECT 0.1 + 0.2;                 -- 0.30000000000000004 😱
SELECT 10 + 20 AS ore;            -- 30 (exakt)
```

Spara i stället i **minsta enheten som heltal**: `price_ore INTEGER`,
`4900` = 49,00 kr. Dela med 100 först när du visar beloppet. (PostgreSQL har även
den exakta typen `numeric(10,2)`.)

### Booleans

SQLite saknar `BOOLEAN`. Använd `INTEGER` med `CHECK (x IN (0, 1))` och
`NOT NULL DEFAULT 0`, t.ex. `is_private` för ett privat konto. PocketBase-fältet
*Bool* gör just så.

### Text med fasta val (enum)

Använd `TEXT` + `CHECK (... IN (...))`, t.ex.
`visibility TEXT NOT NULL DEFAULT 'public' CHECK (visibility IN ('public', 'followers', 'private'))`.
I PocketBase heter fälttypen *Select*. Om listan ofta ändras eller behöver egna
egenskaper – gör en egen tabell i stället.

## 4.7 NULL eller standardvärde?

`NULL` betyder **"okänt" eller "saknas"** – inte "noll" och inte "tom sträng".

| Kolumn | Tomt tillåtet? | Varför |
|--------|----------------|--------|
| `users.website` | ✅ | Alla har inte en webbplats |
| `users.bio` | ✅ | Frivilligt att skriva |
| `posts.title` | ❌ *Required* | Ett inlägg utan rubrik är inte meningsfullt |
| `comments.body` | ❌ *Required* | En tom kommentar är inte en kommentar |
| `posts.author` | ❌ med `CASCADE` | Varje inlägg har en författare. (Med `SET NULL` hade den *behövt* få vara tom.) |
| `likes.created` | ❌ `DEFAULT` nu | Tiden finns alltid |

Tumregler:

- **Gör kolumner `NOT NULL` som standard.** Tillåt `NULL` bara när "saknas" är ett
  verkligt, meningsfullt tillstånd.
- Använd `DEFAULT` när det finns ett naturligt utgångsvärde.
- Blanda inte ihop "saknas" (`NULL`) och "tom" (`''`) – välj ett av dem.
  PocketBase har valt åt dig: tomma textfält är alltid `''`.

⚠️ **Varning:** `NULL` beter sig konstigt i jämförelser: `NULL = NULL` är inte sant,
`COUNT(kolumn)` hoppar över `NULL`, och `NOT IN` med en `NULL` i listan ger inga
rader. Ju färre `NULL`, desto färre överraskningar.

## 4.8 Villkor, index och borttagning

### Villkor som skydd

Lägg affärsregler i databasen där det går. Appen kan ha buggar, men villkoren
gäller alltid – oavsett om datan kommer från appen, adminpanelen eller ett skript.

```sql
-- utdrag ur CREATE TABLE-satser
username  TEXT NOT NULL UNIQUE CHECK (length(username) BETWEEN 3 AND 20)
UNIQUE (post, user)
UNIQUE (follower, following)
CHECK (follower <> following)
CHECK (likes_count >= 0)
```

I PocketBase blir motsvarigheten: *Required*, *Min/Max length*, unika index och –
för regler som "inte följa sig själv" – API-regler eller hooks (modul 02).

### Index

- Skapa index på **främmande nycklar** – de används i nästan varje `JOIN`.
  (SQLite och PostgreSQL skapar inte det automatiskt!)
- Skapa index på kolumner du ofta **filtrerar** eller **sorterar** på, t.ex.
  `posts(created)` för flödet.
- Ett sammansatt index `(a, b)` hjälper sökningar på `a`, men inte på bara `b`.
- Låt bli att indexera allt. Varje index kostar vid skrivning.

### Soft delete eller hard delete?

När Anna tar bort ett inlägg – ska det försvinna på riktigt?

| | Hard delete | Soft delete |
|---|-------------|-------------|
| Hur | `DELETE FROM posts WHERE id = ?;` | `UPDATE posts SET deleted = '2026-10-12 10:00:00.000Z' WHERE id = ?;` |
| Data | Borta för alltid (och kommentarer/gillningar kaskadraderas) | Ligger kvar, döljs |
| Fördel | Enkelt, inga spöken, bra för integritet (GDPR) | Går att ångra, moderatorer kan se vad som togs bort |
| Nackdel | Går inte att ångra | **Varje** fråga – flödet, räknare, sökningar – måste ha `WHERE deleted = ''`; `UNIQUE` krånglar till sig |

```sql
-- Exempel (kör inte på din Kvittra-data):
-- ett Date-fält "deleted" på posts, där tomt ('') betyder "inte borttaget"
UPDATE posts SET deleted = '2026-10-12 10:00:00.000Z' WHERE id = 'id-på-inlägget';
SELECT id, title FROM posts WHERE deleted = '';
```

Ett mellanting som många sociala appar använder: inlägget *döljs* direkt (soft
delete), och raderas på riktigt efter t.ex. 30 dagar.

💡 **Tips:** Använd hard delete som standard. Välj soft delete för data där
"ångra" eller historik verkligen behövs. Personuppgifter som någon begärt ska
raderas måste raderas på riktigt (GDPR). En View collection som bara visar
inlägg som inte är borttagna gör det lättare att inte glömma villkoret.

### Audit-fält: created och updated

Lägg till `created` och `updated` på nästan alla tabeller. De kostar nästan
ingenting och är ovärderliga vid felsökning ("när ändrades den här
kommentaren?") – och i en social app syns de direkt: "för 5 minuter sedan",
"redigerad".

`updated` måste sättas vid varje ändring – i appen eller med en trigger.
PocketBase lägger till och sköter `created` och `updated` automatiskt.

## 4.9 Två klassiska misstag

### Misstag 1: lagra härledda värden

Spara inte det som kan räknas fram från annan data:

| Spara inte | Räkna i stället |
|------------|-----------------|
| `posts.likes_count` | `SELECT COUNT(*) FROM likes WHERE post = ?` |
| `users.followers_count` | `SELECT COUNT(*) FROM follows WHERE following = ?` |
| `users.age` | Spara `birth_date` och räkna |

Ett härlett värde kan bli **fel** så fort originaldatan ändras och någon glömmer
att uppdatera kopian – t.ex. när en gillning tas bort via kaskad och räknaren
inte minskas. (Undantag: medveten denormalisering, se 4.3.)

### Misstag 2: kommaseparerade listor i en kolumn

```
posts (FEL!)
┌─────┬─────────────┬──────────────────────┐
│ id  │ title       │ liked_by             │
├─────┼─────────────┼──────────────────────┤
│ 1   │ Morgondimma │ '2,3,10'             │
└─────┴─────────────┴──────────────────────┘
```

Det här bryter mot 1NF och ger massor av problem:

- Du kan inte ha en främmande nyckel – `'2,3,999'` accepteras utan protest.
- Att hitta "alla inlägg som användare 1 gillat" kräver `LIKE '%1%'`, som även
  matchar 10, 21 och 100 – och kan inte använda index.
- Att ta bort en gillning kräver strängmanipulering.
- Det går inte att lägga till extra info per koppling (t.ex. *när* man gillade).
- Två personer som gillar samtidigt skriver över varandras ändring av listan
  (lost update!).

Lösningen är alltid en egen tabell (1:N) eller en kopplingstabell (N:M) – som
`likes`.

## 4.10 Checklista: Bra att tänka på när du skapar tabeller

**Struktur**
- [ ] Varje tabell representerar **en** sorts sak (en entitet).
- [ ] Varje tabell har en primärnyckel – helst en surrogatnyckel `id`.
- [ ] Inga listor eller upprepade kolumner (`liker1`, `liker2`) – 1NF.
- [ ] Varje fakta finns på **ett** ställe – 2NF/3NF.
- [ ] 1:N-relationer har FK på N-sidan; N:M har en kopplingstabell.
- [ ] Inga härledda värden sparas (om du inte medvetet denormaliserar och har en
      plan för att hålla dem synkade).

**Kolumner**
- [ ] Konsekventa namn: `snake_case`, engelska, tabeller i plural, FK efter roll.
- [ ] Rätt datatyp: heltal för antal, `TEXT` i ISO 8601 (UTC) för tid, heltal i
      ören för pengar, `0/1` för booleans.
- [ ] Bilder och filer som sökväg/URL, inte `BLOB`.
- [ ] Enhet i namnet när den inte är självklar (`duration_sec`, `price_ore`).
- [ ] `NOT NULL` (*Required*) som standard; tomt bara när "saknas" betyder något.
- [ ] Rimliga `DEFAULT`-värden.

**Skydd**
- [ ] `UNIQUE` på naturliga nycklar (användarnamn, e-post) och på
      kopplingstabellers par (`likes(post, user)`).
- [ ] `CHECK` (eller API-regel/hook) för giltiga värden och intervall.
- [ ] `REFERENCES` (*Relation*) på alla främmande nycklar, med genomtänkt
      `ON DELETE` (*Cascade delete*).
- [ ] Vet du vilka regler som ligger i databasen och vilka som ligger i
      PocketBase/appen?

**Prestanda och drift**
- [ ] Index på främmande nycklar och kolumner som ofta filtreras/sorteras.
- [ ] `created` och `updated` på tabeller där ändringar är intressanta.
- [ ] Beslut om soft delete vs hard delete.
- [ ] Har du ritat ett ER-diagram och visat det för någon annan?

## 4.11 Sammanfattning

- Designprocessen: **entiteter → attribut → relationer & kardinalitet →
  normalisering → villkor, typer, index**.
- **1:N** = FK på många-sidan. **N:M** = kopplingstabell (även mot samma tabell,
  som `follows`). **1:1** = FK med `UNIQUE`.
- **1NF**: ett värde per cell. **2NF**: beroende av hela nyckeln. **3NF**: inga
  beroenden mellan icke-nyckelkolumner.
- Denormalisera bara medvetet och när du har ett skäl – som `likes_count` – och
  håll kopian synkad i samma transaktion.
- Surrogatnyckel som PK, `UNIQUE` på naturliga nycklar.
- Datum i UTC och ISO 8601, bilder som sökvägar, pengar som heltal i ören,
  booleans som 0/1.
- Lagra inte härledda värden och aldrig listor i en kolumn.

Nu är du redo för [övningarna](ovningar.md)! Efter det fortsätter vi med
[modul 02 – PocketBase](../02-pocketbase/), där du går djupare i collections,
regler och API:t för samma modell.

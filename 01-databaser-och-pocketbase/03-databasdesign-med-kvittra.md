# 3. Databasdesign med Kvittra

Innan man bygger något i databasen gör man en **databasdesign**. Den är en
ritning som visar vilka tabeller som behövs, vilka fält de har och hur de hänger
ihop. Det är mycket lättare att ändra på papper än i en färdig app.

Vi går igenom hur idén **Kvittra** blir till tabeller, steg för steg. Samma steg
använder du sedan på ditt eget projekt.

## Steg 1 – Beskriv idén

Skriv några meningar om vad appen ska göra:

> Kvittra är en enkel social app. **Användare** kan skriva **inlägg** med en
> rubrik och en text. Andra användare kan **kommentera** inläggen och **gilla**
> dem. Man kan **följa** andra användare för att se deras inlägg i sitt flöde.

## Steg 2 – Hitta "sakerna" (tabellerna)

Stryk under **substantiven** i beskrivningen. De är kandidater till tabeller.

| Substantiv | Blir tabell? | Varför |
|------------|--------------|--------|
| användare | ✅ `users` | Det finns många, och var och en har egna uppgifter |
| inlägg | ✅ `posts` | Många inlägg, med rubrik, text och författare |
| kommentar | ✅ `comments` | Många kommentarer på varje inlägg |
| gilla | ✅ `likes` | Vi måste komma ihåg *vem* som gillat *vilket* inlägg |
| följa | ✅ `follows` | Vi måste komma ihåg *vem* som följer *vem* |
| rubrik, text | ❌ | Det är egenskaper hos ett inlägg, alltså fält |
| flöde | ❌ | Flödet kan räknas fram ur inlägg och följningar. Det behöver inte sparas |

💡 **Tumregel:** Om det finns **många** av något, och varje sak har egna
uppgifter, blir det en tabell. Om det bara beskriver något annat blir det ett
fält.

## Steg 3 – Bestäm fälten

Skriv vilka uppgifter varje tabell behöver och vilken **datatyp** de har.

**users**

| Fält | Typ | Kommentar |
|------|-----|-----------|
| id | id | Skapas automatiskt |
| email | e-post | Används för att logga in |
| username | text | Måste vara unikt, t.ex. `anna` |
| name | text | Visningsnamn, t.ex. "Anna Andersson" |
| bio | text | Kort presentation (får vara tom) |
| website | url | Får vara tom |

**posts**

| Fält | Typ | Kommentar |
|------|-----|-----------|
| id | id | Automatiskt |
| author | relation → users | Vem som skrev inlägget |
| title | text | |
| body | lång text | |
| created | datum | Sätts automatiskt |

**comments**

| Fält | Typ | Kommentar |
|------|-----|-----------|
| id | id | Automatiskt |
| post | relation → posts | Vilket inlägg kommentaren hör till |
| author | relation → users | Vem som skrev kommentaren |
| body | text | |
| created | datum | Automatiskt |

**likes**

| Fält | Typ | Kommentar |
|------|-----|-----------|
| id | id | Automatiskt |
| post | relation → posts | Inlägget som gillas |
| user | relation → users | Användaren som gillar |
| created | datum | Automatiskt |

**follows**

| Fält | Typ | Kommentar |
|------|-----|-----------|
| id | id | Automatiskt |
| follower | relation → users | Den som följer |
| following | relation → users | Den som blir följd |
| created | datum | Automatiskt |

⚠️ **Spara inte samma sak två gånger.** Inlägget har **inte** ett fält med
författarens namn. Det har bara `author`, som pekar på användaren. Namnet finns
i `users`.

⚠️ **Spara inte sådant som kan räknas fram.** Antalet likes sparas inte i
`posts`. Det räknar vi fram genom att räkna raderna i `likes`.

## Steg 4 – Hitta relationerna

Säg relationen högt i båda riktningarna. Då hör du vilken sort det är.

### En till många (1:N)

> En användare kan skriva **många** inlägg.
> Ett inlägg är skrivet av **en** användare.

Det är en **1:N-relation**. Den löses med ett relationsfält på "många"-sidan:
`posts.author` pekar på `users`.

Kvittra har tre sådana:

| "En" | "Många" | Fält |
|------|---------|------|
| användare | inlägg | `posts.author` |
| inlägg | kommentarer | `comments.post` |
| användare | kommentarer | `comments.author` |

### Många till många (N:M)

> En användare kan gilla **många** inlägg.
> Ett inlägg kan gillas av **många** användare.

Det är en **N:M-relation**. Den går inte att lösa med ett enda fält. I stället
gör man en egen tabell som kopplar ihop de två, en **kopplingstabell**. Varje
rad i `likes` betyder "den här användaren gillar det här inlägget".

```
  users            likes              posts
┌──────┐      ┌─────────────┐      ┌──────┐
│ anna │◄─────│ user  post ─┼─────►│ Höst │
│      │◄─────│ user  post ─┼──┐   │      │
└──────┘      │             │  └──►│ Bröd │
┌────────┐    │             │      └──────┘
│ bertil │◄───│ user  post ─┼─────► (Höst)
└────────┘    └─────────────┘
```

`follows` är också en kopplingstabell, men mellan `users` och `users`: en
användare kan följa många, och följas av många.

### En till en (1:1)

> En användare har **en** profilbild. En profilbild hör till **en** användare.

Sådant blir oftast bara ett fält i samma tabell. Kvittra har inga 1:1-tabeller.

## Steg 5 – Rita designen

En ritning av tabeller och relationer kallas **ER-diagram**. `1` och `*` visar
"en" och "många". `→ users` betyder att fältet är en relation som pekar på
`users`.

```
┌──────────────────────┐            ┌──────────────────────┐
│        users         │ 1        * │        posts         │
│──────────────────────│◄───────────│──────────────────────│
│ id                   │   author   │ id                   │
│ username (unik)      │            │ author   → users     │
│ name                 │            │ title                │
│ email                │            │ body                 │
│ bio                  │            │ created              │
│ website              │            └──────────────────────┘
└──────────────────────┘                 ▲ 1          ▲ 1
                                         │ post       │ post
                                         │ *          │ *
┌──────────────────────┐   ┌─────────────┴────┐  ┌────┴─────────────┐
│       follows        │   │     comments     │  │      likes       │
│──────────────────────│   │──────────────────│  │──────────────────│
│ id                   │   │ id               │  │ id               │
│ follower  → users    │   │ post   → posts   │  │ post  → posts    │
│ following → users    │   │ author → users   │  │ user  → users    │
│ created              │   │ body             │  │ created          │
└──────────────────────┘   │ created          │  └──────────────────┘
                           └──────────────────┘
```

💡 Det går lika bra att rita för hand eller i ett verktyg som
[draw.io](https://app.diagrams.net/) eller [dbdiagram.io](https://dbdiagram.io/).

## Steg 6 – Kontrollera designen

Gå igenom den här listan innan du bygger något:

- [ ] Varje tabell beskriver **en sorts sak**, och namnet är i plural (`posts`, inte `post`).
- [ ] Ingen uppgift står på **två ställen** (t.ex. författarens namn i inläggen).
- [ ] Inget fält innehåller en **lista** (t.ex. "bertil, cissi"). Gör en egen tabell i stället.
- [ ] Inget sparas som kan **räknas fram** (t.ex. antal likes).
- [ ] Varje **N:M-relation** har en kopplingstabell.
- [ ] Du vet vilka fält som **måste** vara ifyllda och vilka som måste vara **unika** (t.ex. `username`).
- [ ] Fältnamnen är på engelska, med små bokstäver och `_` mellan orden (`created_at`, inte `Skapad Datum`).

## Vad händer om man gör fel?

Så här kunde en första, sämre design ha sett ut:

**posts** (dålig)

| id | title | author_name | author_email | liked_by | like_count |
|----|-------|-------------|--------------|----------|------------|
| p1 | Höstpromenad | Anna Andersson | anna@example.com | bertil, cissi | 2 |

| Problem | Lösning i vår design |
|---------|----------------------|
| `author_name` och `author_email` upprepas i varje inlägg | Relationen `author` → `users` |
| `liked_by` är en lista i ett fält | Kopplingstabellen `likes` |
| `like_count` kan bli fel om någon glömmer att uppdatera den | Räkna raderna i `likes` |

Att dela upp data på det här sättet så att inget upprepas kallas
**normalisering**.

Nästa kapitel: [Övning – designa ditt projekt](04-ovning-designa-ditt-projekt.md)

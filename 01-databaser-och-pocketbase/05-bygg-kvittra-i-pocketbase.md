# 5. Bygg Kvittra i PocketBase

Nu bygger vi designen från [kapitel 3](03-databasdesign-med-kvittra.md) i
PocketBase. Starta PocketBase (`.\pocketbase.exe serve`) och logga in i
Dashboard på <http://127.0.0.1:8090/_/>.

## Ord i PocketBase

| Databasord | PocketBase-ord |
|------------|----------------|
| tabell | **collection** |
| rad | **record** |
| kolumn | **field** |

Det finns tre sorters collections:

| Typ | Används till |
|-----|--------------|
| **Base** | Vanliga tabeller, t.ex. `posts` |
| **Auth** | Användare som kan logga in, t.ex. `users` |
| **View** | En sparad SQL-fråga. Den använder vi i kapitel 7 |

💡 Varje ny collection får automatiskt fälten `id`, `created` och `updated`. Dem
behöver du inte skapa.

## Ordningen spelar roll

En relation kan bara peka på en collection som redan finns. Därför skapar vi
dem i den här ordningen:

1. `users` (finns redan, vi lägger bara till fält)
2. `posts` (pekar på `users`)
3. `comments` (pekar på `posts` och `users`)
4. `likes` (pekar på `posts` och `users`)
5. `follows` (pekar två gånger på `users`)

## 1. Bygg ut `users`

`users` finns redan och har bland annat `email`, `password`, `name` och
`avatar`. Vi lägger till tre fält.

1. Klicka på `users` till vänster och sedan på **kugghjulet** (⚙) bredvid
   namnet.
2. Klicka **+ New field** → **Plain text**. Skriv namnet `username`.
3. Klicka på kugghjulet på fältet och kryssa i **Nonempty**. Det betyder att
   fältet måste fyllas i.
4. Lägg till **Plain text** med namnet `bio`.
5. Lägg till **URL** med namnet `website`.
6. Längst ner: klicka **+ New index**, välj fältet `username` och kryssa i
   **Unique**. Nu kan två användare inte ha samma användarnamn.
7. Klicka **Save changes**.

## 2. Skapa `posts`

1. Klicka **+ New collection**. Välj typen **Base** och skriv namnet `posts`.
2. **+ New field** → **Relation**:
   - Namn: `author`
   - Collection: `users`
   - Välj **Single** (ett inlägg har en författare)
   - Kugghjulet: kryssa i **Nonempty** och **Cascade delete**
3. **+ New field** → **Plain text**, namn `title`, kryssa i **Nonempty**.
4. **+ New field** → **Plain text** (eller **Rich editor**), namn `body`.
5. Klicka **Create**.

💡 **Cascade delete** betyder: om användaren tas bort försvinner hennes inlägg
också. Annars skulle det finnas inlägg som pekar på en användare som inte finns.

## 3. Skapa `comments`

Ny **Base**-collection med namnet `comments`:

| Fält | Typ | Inställningar |
|------|-----|---------------|
| `post` | Relation → `posts` | Single, Nonempty, Cascade delete |
| `author` | Relation → `users` | Single, Nonempty, Cascade delete |
| `body` | Plain text | Nonempty |

## 4. Skapa `likes`

Ny **Base**-collection med namnet `likes`:

| Fält | Typ | Inställningar |
|------|-----|---------------|
| `post` | Relation → `posts` | Single, Nonempty, Cascade delete |
| `user` | Relation → `users` | Single, Nonempty, Cascade delete |

Lägg också till ett **unikt index** på **både** `post` och `user`
(**+ New index** → välj båda fälten → **Unique**). Då kan samma användare inte
gilla samma inlägg två gånger.

## 5. Skapa `follows`

Ny **Base**-collection med namnet `follows`:

| Fält | Typ | Inställningar |
|------|-----|---------------|
| `follower` | Relation → `users` | Single, Nonempty, Cascade delete |
| `following` | Relation → `users` | Single, Nonempty, Cascade delete |

Lägg till ett **unikt index** på `follower` och `following` tillsammans.

## Kontrollera

Till vänster i Dashboard ska du nu ha fem collections:

```
Collections
  users      (auth)
  posts
  comments
  likes
  follows
```

Jämför med ER-diagrammet i [kapitel 3](03-databasdesign-med-kvittra.md#steg-5--rita-designen).
Stämmer alla fält och relationer?

Nästa kapitel: [Lägg in data](06-lagg-in-data.md)

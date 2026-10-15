# 02 – Collections och fält

En **collection** är PocketBases motsvarighet till en tabell. I det här kapitlet
går vi igenom de tre sorternas collections, alla fälttyper, de vanligaste
fältinställningarna och hur allt blir SQL i SQLite.

## Tre typer av collections

När du klickar **+ New collection** i Dashboard får du välja typ högst upp i
panelen:

| Typ | Används till | I Kvittra |
|-----|--------------|-----------|
| **Base** | Vanlig data: skapa, läsa, ändra, ta bort | `posts`, `comments`, `likes`, `follows` |
| **Auth** | Användare som kan logga in. Har inbyggda fält för e-post, lösenord m.m. | `users` |
| **View** | Skrivskyddad collection som byggs av en SQL-`SELECT` | t.ex. `user_stats` (antal inlägg per användare) |

```
           ┌──────────────── Collection ────────────────┐
           │                                            │
     ┌─────┴─────┐          ┌─────┴─────┐         ┌─────┴─────┐
     │   base    │          │   auth    │         │   view    │
     │ CRUD-data │          │ base +    │         │ SELECT …  │
     │           │          │ inloggning│         │ bara läsa │
     └───────────┘          └───────────┘         └───────────┘
```

### Base

Standardtypen. Du väljer själv vilka fält som ska finnas. PocketBase lägger
alltid till `id`.

### Auth

En auth-collection är en base-collection med extra systemfält och extra
endpoints för registrering och inloggning:

| Systemfält | Betydelse |
|------------|-----------|
| `email` | E-postadress (unik) |
| `emailVisibility` | Om andra användare får se e-postadressen |
| `verified` | Om e-postadressen har verifierats |
| `password` | Lösenord (sparas som hash, skickas aldrig ut i API-svar) |
| `tokenKey` | Hemlig nyckel som gör att inloggningstoken kan ogiltigförklaras |

Collectionen `users` skapas automatiskt och är en auth-collection. Den har
redan fälten `name` och `avatar`. Vi bygger vidare på den i stället för att
skapa en ny. Mer om inloggning i kapitel 4.

### View

En view-collection definieras av en SQL-fråga, precis som en `CREATE VIEW` i
modul 01. Den kan inte skrivas till och skickar inga realtidshändelser. Frågan
**måste** returnera en kolumn som heter `id`.

```sql
SELECT u.id, u.username, COUNT(p.id) AS posts_count
FROM users u
LEFT JOIN posts p ON p.author = u.id
GROUP BY u.id
```

PocketBase gissar fälttyperna utifrån frågan. I SQLite blir det bokstavligen en
vy:

```sql
CREATE VIEW `user_stats` AS SELECT * FROM (SELECT u.id, u.username, ...);
```

Du har redan sett en view i kapitel 1 (`db_tables`). Vi bygger `user_stats` i
övning 7.

## Systemfält: id, created, updated

| Fält | Typ | Beskrivning |
|------|-----|-------------|
| `id` | text (primärnyckel) | 15 tecken, `a-z0-9`, slumpas automatiskt. Kan inte tas bort. |
| `created` | autodate | Sätts när posten skapas |
| `updated` | autodate | Sätts när posten skapas och varje gång den ändras |

När du skapar en collection i Dashboard läggs `created` och `updated` till
automatiskt som fält av typen **autodate**. De är vanliga fält som du i princip
kan ta bort, men behåll dem – de är nästan alltid användbara (sortera inlägg
på `-created` så att det nyaste kommer först, visa "redigerad" osv.).

⚠️ **Varning:** Skapar du en collection via kod (migration i kapitel 7) läggs
`created`/`updated` **inte** till av sig själva. Då måste du lägga till två
autodate-fält uttryckligen.

## Alla fälttyper

I Dashboard klickar du **+ New field** i collection-panelen och väljer typ.

| Fälttyp | Lagrar | SQL-kolumn | Tomt värde | Använd till |
|---------|--------|------------|------------|-------------|
| `text` | Sträng | `TEXT` | `""` | `username`, `posts.title`, `posts.body`, `comments.body` |
| `editor` | HTML-text | `TEXT` | `""` | Formaterad text med rubriker och fetstil (Kvittra klarar sig med vanlig text) |
| `number` | Tal (decimal) | `NUMERIC` | `0` | Saker man räknar med, t.ex. en gräns eller ett antal |
| `bool` | Sant/falskt | `BOOLEAN` | `false` | `emailVisibility`, `notifications.read` (kapitel 8) |
| `email` | E-postadress | `TEXT` | `""` | Kontaktadress (inte inloggning – det sköter auth) |
| `url` | Webbadress | `TEXT` | `""` | `users.website` |
| `date` | Datum + tid (UTC) | `TEXT` | `""` | T.ex. `publish_at` för ett schemalagt inlägg |
| `autodate` | Datum som sätts automatiskt | `TEXT` | – | `created`, `updated` |
| `select` | Ett eller flera värden från en fast lista | `TEXT` (enkel) / `JSON` (flera) | `""` / `[]` | `groups.visibility`, `group_members.role` (kapitel 8) |
| `file` | Filnamn; själva filen ligger i `pb_data/storage` | `TEXT` / `JSON` | `""` / `[]` | `users.avatar`, `posts.image` |
| `relation` | Id till post(er) i en annan collection | `TEXT` / `JSON` | `""` / `[]` | `posts.author`, `comments.post` |
| `json` | Godtycklig JSON | `JSON` | `null` | Fria inställningar, data du inte vill strukturera |
| `geoPoint` | `{"lon": .., "lat": ..}` | `JSON` | `{"lon":0,"lat":0}` | Var ett inlägg skrevs ("incheckning") |
| `password` | Hashat lösenord | `TEXT` | `""` | Finns i auth-collections. Skapa sällan själv. |

### Hur väljer jag fälttyp?

```
Är det ett val från en fast lista (t.ex. roll, synlighet)? ──► select
Pekar det på en annan post?                              ──► relation
Är det ett datum/klockslag?                              ──► date (eller autodate)
Är det ett tal man räknar med eller jämför (>, <)?       ──► number
  ...men inte ett "nummer" som kan ha bokstäver, mellanslag
  eller nollor först, t.ex. telefonnummer "070-123 45 67"? ──► text
Ja/nej?                                                  ──► bool
En webbadress eller e-postadress?                        ──► url / email
Formaterad text med rubriker och fetstil?                ──► editor
En uppladdad fil?                                        ──► file
Okänd struktur som varierar?                             ──► json (sista utväg)
```

💡 **Tips:** Telefonnummer och postnummer är klassiska exempel på något som
*heter* nummer men ska vara `text`. Man räknar aldrig med dem, och `070…`
skulle tappa sin inledande nolla som tal.

⚠️ **Varning:** Använd inte `json` som genväg för att slippa designa. Det går
dåligt att filtrera och validera på innehållet, och du tappar de fördelar som
normaliseringen i [modul 01](../01-databaser/04-databasdesign.md) gav dig. Ett
klassiskt misstag i en social app är att spara gillningar som en json-lista med
användar-id:n på inlägget – kapitel 3 visar varför en egen collection `likes`
är bättre.

### Select: en eller flera

Ett select-fält har en lista med tillåtna värden. Inställningen **Max select**
(i Dashboard: *Single* / *Multiple*) avgör om fältet håller ett värde (sträng)
eller flera (lista).

```json
{ "visibility": "private" }                  // maxSelect = 1
{ "interests": ["kaffe", "löpning", "bak"] } // maxSelect > 1
```

Försöker någon spara ett värde som inte finns i listan svarar PocketBase med
`400 Bad Request`. Det är som en `CHECK`-constraint i SQL.

### Date

Datum skickas och sparas som text i UTC:

```
2026-10-15 08:00:00.000Z
```

PocketBase accepterar även ISO-formatet `2026-10-15T08:00:00Z`. Appen ansvarar
för att översätta till svensk tid när datumet visas ("för 5 minuter sedan").
`Z` betyder UTC, så `08:00Z` är `10:00` svensk sommartid.

### File

Ett file-fält sparar bara filnamnet i databasen. Själva filen hamnar i
`pb_data/storage/<collection-id>/<post-id>/`. Viktiga inställningar:

| Inställning | Betydelse |
|-------------|-----------|
| Max select | En eller flera filer |
| Max size | Maxstorlek per fil i byte (t.ex. `5242880` = 5 MB) |
| Mime types | Tillåtna filtyper, t.ex. `image/jpeg`, `image/png`, `image/webp` |
| Thumb sizes | Automatiska miniatyrer, t.ex. `100x100` för avatarer, `400x0` för inläggsbilder |
| Protected | Filen kräver en särskild fil-token för att laddas ner |

Filer hämtas via `/api/files/<collection>/<post-id>/<filnamn>`, och en miniatyr
med `?thumb=100x100`.

## Fältinställningar

Varje fält har en kugghjulsikon i Dashboard med inställningar. De viktigaste:

| Inställning | Finns på | Effekt | Motsvarighet i SQL |
|-------------|----------|--------|--------------------|
| **Nonempty** (`required`) | alla | Värdet får inte vara tomt (`""`, `0`, `false`, `[]`) | `NOT NULL` + `CHECK (x <> '')` |
| **Min / Max length** | text, editor, password | Antal tecken | `CHECK (length(x) <= 200)` |
| **Pattern** | text, password | Reguljärt uttryck som värdet måste matcha | `CHECK (x REGEXP ...)` |
| **Min / Max** | number, date | Minsta/största värde | `CHECK (x BETWEEN ...)` |
| **No decimals** (`onlyInt`) | number | Bara heltal | `INTEGER` |
| **Max select** | select, file, relation | En eller flera | – |
| **Hidden** | alla | Fältet skickas aldrig ut i API-svar (bara superusers ser det) | – |
| **Presentable** | alla | Visas som etikett när posten visas i en relation i Dashboard | – |

⚠️ **Varning:** `required` på ett **number**-fält betyder att värdet inte får
vara `0`. Ett `bool`-fält med `required` måste vara `true`. Det överraskar de
flesta! Sätt alltså inte `required` på ett fält som `read` – då kan en notis
aldrig sparas som oläst.

### Pattern-exempel

| Fält | Pattern | Betyder |
|------|---------|---------|
| `users.username` | `^[a-z0-9_]+$` | Bara små bokstäver a–z, siffror och understreck |
| `users.phone` | `^\+?[0-9 -]{7,20}$` | Telefonnummer |

## Unikt värde – med index

I PocketBase v0.23+ finns ingen "Unique"-kryssruta på själva fältet. Unikhet
gör man med ett **unikt index**, precis som i SQL.

**Så här i Dashboard:**

1. Öppna collectionen (kugghjulet).
2. Längst ner under fälten: klicka **+ New index**.
3. Kryssa i **Unique**.
4. Välj kolumn(er), t.ex. `username`.
5. Klicka **Set index** och sedan **Save changes**.

Resultatet är en vanlig SQL-sats:

```sql
CREATE UNIQUE INDEX idx_users_username ON users (username);
```

Försöker någon skapa två användare med användarnamnet `anna` svarar API:t:

```json
{
  "status": 400,
  "message": "Failed to create record.",
  "data": {
    "username": { "code": "validation_not_unique", "message": "Value must be unique." }
  }
}
```

Ett unikt index kan också gälla **flera kolumner**. Det är så Kvittra hindrar
att samma person gillar samma inlägg två gånger:

```sql
CREATE UNIQUE INDEX idx_likes_post_user ON likes (post, user);
```

### Index för snabbhet

Index är inte bara för unikhet. Som du lärde dig i modul 01 gör ett index att
databasen slipper läsa hela tabellen. Inlägg hämtas nästan alltid per
författare och sorteras på tid, så de här är bra index:

```sql
CREATE INDEX idx_posts_author ON posts (author);
CREATE INDEX idx_posts_created ON posts (created);
```

💡 **Tips:** Lägg index på fält som du ofta filtrerar eller sorterar på, och på
relationsfält. PocketBase skapar **inte** index på relationsfält automatiskt.

## Från SQL till collection – jämförelse

I modul 01 kanske du skrev ungefär så här för kopplingstabellen `likes`:

```sql
CREATE TABLE likes (
  id       INTEGER PRIMARY KEY AUTOINCREMENT,
  post_id  INTEGER NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id  INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created  TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (post_id, user_id)
);
```

Samma sak i PocketBase:

| SQL | PocketBase-fält | Inställningar |
|-----|-----------------|---------------|
| `id INTEGER PRIMARY KEY` | `id` (automatiskt) | – |
| `post_id ... REFERENCES posts` | `post` (relation → posts) | Max select 1, Nonempty, Cascade delete |
| `user_id ... REFERENCES users` | `user` (relation → users) | Max select 1, Nonempty, Cascade delete |
| `created TEXT ... DEFAULT CURRENT_TIMESTAMP` | `created` (autodate) | automatiskt |
| `UNIQUE (post_id, user_id)` | – | Unikt index på `(post, user)` |
| "Man får inte gilla sitt eget inlägg" | – | Görs med en hook (kapitel 7) |

Och det här är SQL:en som PocketBase faktiskt skapar (titta själv i
`db_tables` från kapitel 1):

```sql
CREATE TABLE `likes` (
  `created` TEXT DEFAULT '' NOT NULL,
  `id`      TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL,
  `post`    TEXT DEFAULT '' NOT NULL,
  `user`    TEXT DEFAULT '' NOT NULL
)
```

Lägg märke till:

1. Relationsfälten heter `post` och `user`, inte `post_id`. I PocketBase är
   konventionen att relationsfältet heter som det det pekar på.
2. Det finns **ingen** `FOREIGN KEY` i SQL:en. PocketBase kontrollerar själv
   att id:t finns och sköter cascade delete i sin egen kod. Därför är det extra
   viktigt att alltid gå via API:t.
3. `required` och unikheten syns inte i `CREATE TABLE`. `required` kontrolleras
   i PocketBase innan raden skrivs, och det unika indexet är en egen
   `CREATE UNIQUE INDEX`-sats.
4. Villkor som "inte gilla sitt eget inlägg" kan inte uttryckas med
   fältinställningar. Där behövs en hook.

## Steg för steg: utöka `users` i Dashboard

Kvittra behöver ett unikt användarnamn, en kort presentation och en länk.

⚠️ **Varning:** Har du skapat testanvändare i `users` redan? Ta bort dem först.
Annars har flera användare ett tomt `username`, och då går det inte att skapa
det unika indexet.

1. Klicka på `users` och sedan på kugghjulet.
2. **+ New field** → **Plain text**. Namn: `username`. Öppna kugghjulet på
   fältet: kryssa i **Nonempty**, sätt **Min length** `2`, **Max length** `20`
   och **Pattern** `^[a-z0-9_]+$`.
3. **+ New field** → **Plain text**. Namn: `bio`. **Max length** `300`.
4. **+ New field** → **URL**. Namn: `website`.
5. Under **Indexes**: **+ New index** → kryssa i **Unique** → välj `username`.
6. Fliken **API Rules** låter vi vara tills vidare (kapitel 4).
7. Klicka **Save changes**.

Klicka sedan **+ New record** och skapa Anna: e-post `anna@example.com`,
lösenord `hemligt123` (två gånger), username `anna`, name `Anna Andersson`,
bio `Kaffe, kod och katter.`

🧪 **Prova själv:**

- Skapa en till användare med username `anna`. Vad händer?
- Försök med username `Anna Andersson`. Vilket fel får du, och varför?
- Försök sätta `website` till `inte en länk`.

💡 **Tips:** Under fliken **Options** → *Identity/Password* kan du lägga till
`username` bland de fält man får logga in med. Då kan Anna logga in med
antingen `anna@example.com` eller `anna`. Det kräver just ett unikt index på
fältet – därför index först.

## Att ändra en collection i efterhand

Du kan när som helst lägga till, döpa om eller ta bort fält. PocketBase
översätter det till `ALTER TABLE`.

⚠️ **Varning:**

- **Ta bort fält** raderar kolumnen och all data i den. Det går inte att ångra.
- **Byta namn** på ett fält bevarar datan, men alla appar, filter och regler
  som använder det gamla namnet slutar fungera.
- **Byta fälttyp** går inte. Skapa ett nytt fält, flytta datan, ta bort det
  gamla.

Varje ändring du gör i Dashboard skapar dessutom automatiskt en fil i
`pb_migrations/`. Mer om det i kapitel 7.

## Sammanfattning

- Collection-typer: **base** (vanlig data), **auth** (inloggning), **view**
  (skrivskyddad `SELECT`).
- `id` skapas alltid. `created`/`updated` är autodate-fält.
- Välj fälttyp efter vad värdet *betyder*, inte hur det ser ut.
- `required` = "inte tomt", vilket för number betyder ≠ 0 och för bool = true.
- Unikhet och snabbhet görs med **index** – även över flera kolumner, som
  `(post, user)` i `likes`.
- Allt blir vanliga SQLite-tabeller, men utan `FOREIGN KEY` – PocketBase sköter
  integriteten.

Nästa kapitel: [Relationer](03-relationer.md).

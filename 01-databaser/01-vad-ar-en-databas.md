# Kapitel 1 – Vad är en databas?

> **Mål med kapitlet:** Du ska kunna förklara vad en databas är, varför man
> använder en, och känna till grundbegreppen tabell, rad, kolumn, primärnyckel och
> främmande nyckel. Du ska också veta vad SQLite är och hur det hänger ihop med
> PocketBase.

## 1.1 En databas är ett organiserat minne

En **databas** är en samling data som är lagrad på ett strukturerat sätt så att
den går att *söka i*, *ändra* och *skydda* på ett pålitligt sätt.

Nästan alla appar du använder har en databas bakom sig:

| App | Vad som ligger i databasen |
|-----|----------------------------|
| Instagram | Användare, bilder, stories, direktmeddelanden |
| Banken | Konton, saldon, transaktioner |
| Spotify | Låtar, artister, spellistor, vad du har lyssnat på |
| **Kvittra** | Användare, inlägg, kommentarer, gillningar, vem som följer vem |

Programmet som sköter databasen kallas ett **databashanteringssystem**, på
engelska *Database Management System* (**DBMS**). Exempel är SQLite, PostgreSQL,
MySQL, Microsoft SQL Server och MongoDB. I vardagligt tal säger man ofta bara
"databasen" om både datan och programmet.

```
  ┌──────────────┐   frågor (SQL)    ┌──────────────────┐   läser/skriver   ┌───────────┐
  │   Din app    │ ────────────────► │      DBMS        │ ────────────────► │  Filer på │
  │ (Flutter,    │                   │ (SQLite,         │                   │  disken   │
  │  PocketBase) │ ◄──────────────── │  PostgreSQL …)   │ ◄──────────────── │           │
  └──────────────┘   resultat        └──────────────────┘                   └───────────┘
```

Din app pratar alltså aldrig direkt med filerna på disken. Den ber DBMS:et om
saker ("ge mig de 20 senaste inläggen från personer jag följer"), och DBMS:et
tar hand om resten.

## 1.2 Varför inte bara en fil eller ett Excel-ark?

Tänk dig att Kvittras allra första version höll koll på inlägg och gillningar i
ett kalkylark:

| Datum | Författare | E-post | Titel | Gillas av |
|-------|------------|--------|-------|-----------|
| 2026-09-01 | Anna Andersson | anna@example.com | Höstpromenad i Slottsskogen | bertil, cissi, dahl |
| 2026-09-03 | Bertil Berg | bertil@example.com | Mitt första surdegsbröd | anna |
| 2026-10-11 | anna andersson | ana@example.com | Morgondimma | bertil, cissi, Bertil |

Det fungerar för några få inlägg. Men titta noga – det finns redan problem:

1. **Inkonsekvent data.** "Anna Andersson" och "anna andersson" är samma person.
   På sista raden är e-posten felstavad. Vilken är rätt?
2. **Dubbla gillningar.** Bertil gillar "Morgondimma" två gånger ("bertil" och
   "Bertil"). Ingenting hindrade det.
3. **Upprepning.** Annas e-post står på varje inlägg hon skriver. Byter hon adress
   måste alla rader uppdateras – missar man en har man två "sanningar".
4. **Listor i celler.** Vill du veta *vilka inlägg Cissi har gillat* måste du leta
   igenom texten i varje cell i kolumnen "Gillas av".
5. **Samtidighet.** Om två personer öppnar filen samtidigt och sparar, skriver den
   ena över den andras ändringar.
6. **Behörighet.** Alla som kan öppna filen kan se och ändra *allt*.
7. **Skalbarhet.** Med 10 miljoner inlägg blir det omöjligt att läsa hela filen
   bara för att visa ett flöde.

En databas löser just de här problemen:

| Problem | Hur databasen hjälper |
|---------|-----------------------|
| Inkonsekvent data | **Datatyper** och **villkor** (*constraints*) – t.ex. "författaren måste vara en befintlig användare" |
| Upprepning, listor i celler | Data delas upp i **tabeller** som pekar på varandra med **nycklar** |
| Dubbla gillningar | Ett **unikt villkor** och **transaktioner** (kapitel 3) |
| Samtidighet | DBMS:et samordnar många samtidiga läsare och skrivare |
| Behörighet | Användare och rättigheter (i PocketBase: *API rules*) |
| Skalbarhet | **Index** gör att databasen hittar rätt rad utan att läsa allt |
| Krascher | **Transaktionslogg** gör att data inte blir halvskriven om strömmen går |

💡 **Tips:** Kalkylark är utmärkta för analys och engångsjobb. Men så fort flera
personer eller program ska *ändra* samma data samtidigt behöver du en databas.

## 1.3 Relationsdatabaser: tabeller, rader och kolumner

Den vanligaste sortens databas är **relationsdatabasen**. All data ligger i
**tabeller** (kallas formellt *relationer*, därav namnet). En tabell ser ut ungefär
som ett kalkylark, men med strängare regler:

```
                       tabellen  users
           ┌─────────── kolumner (attribut) ────────────┐
           │                                            │
           ▼             ▼                   ▼
        ┌────────┬────────────┬────────────────────┐
        │   id   │  username  │        name        │   ◄── schema: namn + datatyp
        ├────────┼────────────┼────────────────────┤
  rad ─►│ 'k3j…' │  'anna'    │  'Anna Andersson'  │
  rad ─►│ '7rb…' │  'bertil'  │  'Bertil Berg'     │
  rad ─►│ 'q8w…' │  'cissi'   │  'Cecilia Carlsson'│
        │  ...   │    ...     │        ...         │
        └────────┴────────────┴────────────────────┘
```

| Begrepp | Betyder | Exempel |
|---------|---------|---------|
| **Tabell** | En samling av samma sorts sak | `users`, `posts`, `likes` |
| **Kolumn** (attribut, fält) | En egenskap som alla rader har, med en bestämd datatyp | `title` är text, `created` är en tidpunkt |
| **Rad** (post, *record*) | En enskild sak | Inlägget "Morgondimma" |
| **Schema** | Beskrivningen av tabellerna: namn, kolumner, typer, regler | `CREATE TABLE ...` |
| **Värde** | Det som står i en cell | `'anna'` |

Skillnaden mot ett kalkylark:

- Varje kolumn har **en datatyp**. Ett datum ska vara ett datum, inte "i förrgår".
- Raderna har **ingen inbyggd ordning**. Vill du ha dem sorterade måste du be om det.
- Varje rad ska gå att **identifiera unikt** – med en primärnyckel.

🧪 **Prova själv:** Öppna PocketBase Dashboard och klicka på `posts`. Det du ser är
en tabell: varje fält är en kolumn och varje record är en rad.

## 1.4 Primärnyckel – radens personnummer

En **primärnyckel** (*primary key*, PK) är en kolumn (eller kombination av
kolumner) som unikt identifierar varje rad. Två rader får aldrig ha samma
primärnyckel, och den får inte vara tom.

I Kvittra har alla tabeller en kolumn `id` som primärnyckel. PocketBase hittar på
ett slumpat id med 15 tecken åt varje ny record:

```
users
┌─────────────────┬──────────┬──────────────────┐
│ id              │ username │ name             │
├─────────────────┼──────────┼──────────────────┤
│ k3j9x0p2m1q8w7e │ anna     │ Anna Andersson   │
│ 7rbh2m0q9z4x1ty │ bertil   │ Bertil Berg      │
└─────────────────┴──────────┴──────────────────┘
  ▲
  └── primärnyckel: unik, aldrig tom, ändras aldrig
```

Varför inte använda användarnamnet som nyckel? För att folk **vill byta
användarnamn** – och e-postadress. Då skulle alla rader som pekar på "anna" behöva
ändras. Ett bra id är **unikt, stabilt och meningslöst** – det betyder ingenting
annat än "den här raden". Användarnamnet är fortfarande unikt (två personer kan
inte heta `anna`), men det är inte nyckeln. Mer om val av nycklar i
[kapitel 4](04-databasdesign.md).

## 1.5 Främmande nyckel – pilar mellan tabeller

En **främmande nyckel** (*foreign key*, FK) är en kolumn som pekar på
primärnyckeln i en *annan* tabell. Det är så tabeller hänger ihop.

```
   posts                                                users
┌───────┬─────────────────────────┬─────────┐        ┌─────────┬──────────┐
│ id    │ title                   │ author  │        │ id      │ username │
├───────┼─────────────────────────┼─────────┤        ├─────────┼──────────┤
│ 'a1…' │ Höstpromenad i Slottss… │ 'k3j…' ─┼──┬────►│ 'k3j…'  │ anna     │
│ 'b2…' │ Mitt första surdegsbröd │ '7rb…' ─┼──┼────►│ '7rb…'  │ bertil   │
│ 'c3…' │ Morgondimma             │ 'k3j…' ─┼──┘     │  …      │ …        │
└───────┴─────────────────────────┴─────────┘        └─────────┴──────────┘
                                       ▲
                                       └── främmande nyckel → users.id
```

Både "Höstpromenad" och "Morgondimma" är skrivna av Anna. I stället för att
skriva hennes namn och e-post på varje inlägg sparar vi bara en **referens** –
hennes id. Då finns hennes uppgifter på exakt *ett* ställe.

Databasen kan dessutom **vakta** referensen: försöker du skapa ett inlägg med en
författare som inte finns, säger den nej. Det kallas **referensintegritet**. I
PocketBase är en främmande nyckel ett fält av typen **Relation**.

Så här hänger hela Kvittra ihop:

```
users  1 ──── *  posts       (en användare skriver många inlägg)
posts  1 ──── *  comments    (ett inlägg har många kommentarer)
users  1 ──── *  comments    (en användare skriver många kommentarer)
users  * ──── *  posts       via likes    (många användare gillar många inlägg)
users  * ──── *  users       via follows  (användare följer varandra)
```

`1 ──── *` utläses "ett till många". Den främmande nyckeln ligger alltid på
"många"-sidan: `posts.author`, `comments.post`, `comments.author`.
`* ──── *` ("många till många") kräver en egen tabell i mitten med två främmande
nycklar: `likes.post` + `likes.user`, och `follows.follower` + `follows.following`.

🧪 **Prova själv:** Titta på datamodellen i kursens [README](../README.md).
Vilken tabell har *två* främmande nycklar som pekar på *samma* tabell? Varför
behövs två?

## 1.6 Relationsdatabaser vs dokumentdatabaser (NoSQL)

Relationsdatabaser är inte den enda sorten. En annan vanlig familj kallas
**NoSQL**, och den vanligaste varianten är **dokumentdatabaser** (t.ex. MongoDB,
Firestore). Där sparas data som JSON-liknande dokument:

```json
{
  "_id": "p10",
  "title": "Morgondimma",
  "author": { "username": "anna", "name": "Anna Andersson" },
  "comments": [
    { "author": { "username": "bertil", "name": "Bertil Berg" }, "body": "Vackert!" }
  ],
  "likeCount": 2
}
```

| | Relationsdatabas (SQL) | Dokumentdatabas (NoSQL) |
|---|------------------------|-------------------------|
| Struktur | Tabeller med fast schema | Dokument med flexibel struktur |
| Relationer | Främmande nycklar + `JOIN` | Ofta inbäddade kopior av data |
| Frågespråk | SQL (standardiserat) | Eget API per produkt |
| Styrka | Konsistens, komplexa frågor, transaktioner | Flexibilitet, enkel horisontell skalning |
| Exempel | SQLite, PostgreSQL, MySQL | MongoDB, Firestore, CouchDB |

Lägg märke till att dokumentet ovan har en *kopia* av Annas namn – och av
Bertils, inne i kommentaren. Byter Bertil namn måste alla dokument där han
kommenterat letas upp och uppdateras. I en relationsdatabas ändrar du en enda
rad i `users`.

💡 **Tips:** För data med tydliga relationer – användare, inlägg, kommentarer,
gillningar, följare – är en relationsdatabas nästan alltid rätt val att börja
med. Det är därför vi använder det i den här kursen.

## 1.7 SQL – språket man pratar med

Relationsdatabaser styrs med **SQL** (*Structured Query Language*, uttalas
"es-kju-ell" eller "sequel"). Ett smakprov – Annas inlägg, äldst först:

```sql
SELECT p.title, p.created
FROM posts p
JOIN users u ON u.id = p.author
WHERE u.username = 'anna'
ORDER BY p.created;
```

| title | created |
|-------|---------|
| Höstpromenad i Slottsskogen | 2026-09-01 08:15:00.000Z |
| Morgondimma | 2026-10-11 06:45:00.000Z |

Du *beskriver vad* du vill ha, inte *hur* databasen ska leta. Det går vi igenom
ordentligt i [kapitel 2](02-sql-grunder.md).

## 1.8 SQLite, PostgreSQL och MySQL

Det finns många relationsdatabaser. De förstår alla SQL, men med små skillnader
("dialekter").

| | SQLite | PostgreSQL | MySQL / MariaDB |
|---|--------|------------|-----------------|
| Arkitektur | Ett bibliotek inuti ditt program; databasen är **en fil** | Separat server som program ansluter till över nätverk | Separat server |
| Installation | Ingen (finns i macOS, Android, iOS, webbläsare …) | Måste installeras och köras | Måste installeras och köras |
| Samtidiga skrivare | En åt gången | Många | Många |
| Typer | Flexibla ("type affinity") | Strikta och väldigt många | Strikta |
| Passar för | Mobilappar, små/medelstora webbtjänster, tester, inlärning | Stora fleranvändarsystem | Webbtjänster, klassiska LAMP-stackar |

```
SQLite (t.ex. inuti PocketBase)       PostgreSQL / MySQL
┌───────────────────────┐             ┌──────────────┐        ┌───────────────┐
│ PocketBase            │             │ Din app      │  TCP   │ DB-server     │
│ ┌───────────────────┐ │             │              │ ─────► │ (egen process)│
│ │ SQLite-bibliotek  │ │             └──────────────┘        └──────┬────────┘
│ └─────────┬─────────┘ │                                            │
└───────────┼───────────┘                                            ▼
            ▼                                                   datafiler
     pb_data/data.db  (en fil)
```

SQLite är världens mest använda databas – den finns i varje smartphone. Den är
fullt kapabel för riktiga produkter, och har riktiga transaktioner med ACID
(kapitel 3).

⚠️ **Varning:** SQLite är mer förlåtande med datatyper än andra databaser. Du kan
som standard spara texten `'hej'` i en `INTEGER`-kolumn utan att få fel. Därför
lägger man ofta till `CHECK`-villkor, eller skriver `CREATE TABLE ... STRICT`
(från SQLite 3.37) för att få strikta typer. PocketBase kontrollerar typerna
själv innan den sparar något.

## 1.9 PocketBase: en backend ovanpå SQLite

**PocketBase**, som du installerade i [modulens README](README.md), är en färdig
backend i en enda körbar fil. Under huven sparar den allt i en SQLite-databas:
`pb_data/data.db`.

| Det du ser i PocketBase | Det som finns i SQLite |
|-------------------------|------------------------|
| Collection `posts` | Tabell `posts` |
| Fält (field) `title` av typen *Plain text* | Kolumn `title` (`TEXT`) |
| Fält av typen *Relation* till `users` | Kolumn med id:t på en rad i `users` (en främmande nyckel) |
| Record | Rad |
| Fältet `id` (15 tecken, t.ex. `k3j9x0p2m1q8w7e`) | Primärnyckel (text) |
| Fälten `created` / `updated` (*Autodate*) | Kolumner som PocketBase fyller i automatiskt |
| Index med **Unique** ikryssat | `CREATE UNIQUE INDEX ...` |
| *View collection* | En vy: `CREATE VIEW ... AS SELECT ...` |

Allt du lär dig i den här modulen – nycklar, relationer, index, transaktioner,
normalisering – gäller alltså direkt i PocketBase. Skillnaden är att PocketBase
skriver mycket av SQL:en åt dig och ger dig ett REST-API och en adminpanel
ovanpå.

🧪 **Prova själv:** Öppna **Settings → SQL console** och kör

```sql
SELECT sql FROM sqlite_master WHERE name = 'likes';
```

Du ser `CREATE TABLE`-satsen som PocketBase skrev åt dig när du skapade
collectionen `likes`. Känner du igen kolumnerna? (Du kommer att se att kolumnerna
är av typen `TEXT` – mer om det i kapitel 2.)

## 1.10 Sammanfattning

- En **databas** lagrar data strukturerat; ett **DBMS** är programmet som sköter den.
- Databaser slår filer och kalkylark när det gäller konsistens, samtidighet,
  behörighet, prestanda och krascher.
- I en **relationsdatabas** ligger data i **tabeller** med **kolumner** (typade
  egenskaper) och **rader** (enskilda saker).
- **Primärnyckeln** identifierar en rad unikt. **Främmande nycklar** pekar på
  rader i andra tabeller och skapar relationer. Många-till-många kräver en
  tabell i mitten (`likes`, `follows`).
- **SQLite** är en filbaserad relationsdatabas utan server. PostgreSQL och MySQL
  är serverdatabaser.
- **PocketBase** lagrar sina collections som tabeller i SQLite.

## Kontrollfrågor

1. Nämn tre problem med att hålla inlägg och gillningar i ett kalkylark.
2. Vad är skillnaden mellan en primärnyckel och en främmande nyckel?
3. Varför är `username` en dålig primärnyckel för `users`, trots att den är unik?
4. I vilken tabell ligger den främmande nyckeln i en 1-till-många-relation?
5. Varför behöver "gilla" en egen tabell, i stället för en kolumn i `posts`?
6. Vad heter filen där PocketBase sparar sin SQLite-databas?

Nästa kapitel: [Kapitel 2 – SQL-grunder](02-sql-grunder.md)

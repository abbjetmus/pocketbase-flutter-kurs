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
| Instagram | Användare, bilder, likes, kommentarer, vem som följer vem |
| Banken | Konton, saldon, transaktioner |
| Spotify | Låtar, artister, spellistor, vad du har lyssnat på |
| **Föreningsappen** | Lägenheter, medlemmar, tvättstugor, bokningar, anslag |

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
saker ("ge mig alla bokningar för tvättstuga 1 i morgon"), och DBMS:et tar hand
om resten.

## 1.2 Varför inte bara en fil eller ett Excel-ark?

Tänk dig att föreningen håller koll på tvättstugebokningar i ett kalkylark:

| Datum | Tid | Tvättstuga | Namn | Lägenhet | Telefon |
|-------|-----|------------|------|----------|---------|
| 2026-10-12 | 07–10 | 1 | Anna Andersson | 1101 | 070-111 11 11 |
| 2026-10-12 | 10–13 | 1 | Cecilia Carlsson | 1001 | 070-333 33 33 |
| 2026-10-13 | 07–10 | Tvätt 1 | anna andersson | 1101 | 0701111111 |
| 2026-10-12 | 07–10 | 1 | Bertil Berg | 1101 | 070-222 22 22 |

Det fungerar för några få bokningar. Men titta noga – det finns redan problem:

1. **Inkonsekvent data.** "1" och "Tvätt 1" betyder samma sak. "Anna Andersson"
   och "anna andersson" är samma person. Telefonnumret är skrivet på två sätt.
2. **Dubbelbokning.** Rad 1 och rad 4 bokar samma tvättstuga samma tid. Ingenting
   hindrade det.
3. **Upprepning.** Annas telefonnummer står på varje rad hon bokar. Byter hon
   nummer måste alla rader uppdateras – missar man en har man två "sanningar".
4. **Samtidighet.** Om två personer öppnar filen samtidigt och sparar, skriver
   den ena över den andras ändringar.
5. **Behörighet.** Alla som kan öppna filen kan se och ändra *allt*.
6. **Skalbarhet.** Med 100 000 rader blir det långsamt att leta, och appen
   måste läsa hela filen för att hitta en enda bokning.

En databas löser just de här problemen:

| Problem | Hur databasen hjälper |
|---------|-----------------------|
| Inkonsekvent data | **Datatyper** och **villkor** (*constraints*) – t.ex. "resurs måste vara ett giltigt id" |
| Upprepning | Data delas upp i **tabeller** som pekar på varandra med **nycklar** |
| Dubbelbokning | Villkor och **transaktioner** (kapitel 3) |
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
                     tabellen  apartments
           ┌────────── kolumner (attribut) ───────────┐
           │                                          │
           ▼          ▼            ▼          ▼
        ┌──────┬──────────┬──────────┬────────────┐
        │  id  │  number  │  floor   │  size_sqm  │   ◄── schema: namn + datatyp
        ├──────┼──────────┼──────────┼────────────┤
  rad ─►│  1   │  '1001'  │    0     │    34.5    │
  rad ─►│  2   │  '1002'  │    0     │    58.0    │
  rad ─►│  3   │  '1101'  │    1     │    72.0    │
        │ ...  │   ...    │   ...    │    ...     │
        └──────┴──────────┴──────────┴────────────┘
```

| Begrepp | Betyder | Exempel |
|---------|---------|---------|
| **Tabell** | En samling av samma sorts sak | `apartments`, `bookings` |
| **Kolumn** (attribut, fält) | En egenskap som alla rader har, med en bestämd datatyp | `floor` är ett heltal |
| **Rad** (post, *record*) | En enskild sak | Lägenhet 1101 |
| **Schema** | Beskrivningen av tabellerna: namn, kolumner, typer, regler | `CREATE TABLE ...` |
| **Värde** | Det som står i en cell | `72.0` |

Skillnaden mot ett kalkylark:

- Varje kolumn har **en datatyp**. Man kan inte skriva "sjuttiotvå" i `size_sqm`.
- Raderna har **ingen inbyggd ordning**. Vill du ha dem sorterade måste du be om det.
- Varje rad ska gå att **identifiera unikt** – med en primärnyckel.

## 1.4 Primärnyckel – radens personnummer

En **primärnyckel** (*primary key*, PK) är en kolumn (eller kombination av
kolumner) som unikt identifierar varje rad. Två rader får aldrig ha samma
primärnyckel, och den får inte vara tom.

I Föreningsappen har alla tabeller en kolumn `id` som primärnyckel:

```
users
┌────┬─────────────────────┬──────────────────┐
│ id │ email               │ name             │
├────┼─────────────────────┼──────────────────┤
│ 1  │ anna@example.com    │ Anna Andersson   │
│ 2  │ bertil@example.com  │ Bertil Berg      │
└────┴─────────────────────┴──────────────────┘
  ▲
  └── primärnyckel: unik, aldrig tom, ändras aldrig
```

Varför inte använda namnet som nyckel? För att två personer kan heta likadant,
och folk byter namn. Ett bra id är **unikt, stabilt och meningslöst** – det
betyder ingenting annat än "den här raden". Mer om val av nycklar i
[kapitel 4](04-databasdesign.md).

## 1.5 Främmande nyckel – pilar mellan tabeller

En **främmande nyckel** (*foreign key*, FK) är en kolumn som pekar på
primärnyckeln i en *annan* tabell. Det är så tabeller hänger ihop.

```
   users                                         apartments
┌────┬──────────────────┬───────────┐        ┌────┬────────┬───────┐
│ id │ name             │ apartment │        │ id │ number │ floor │
├────┼──────────────────┼───────────┤        ├────┼────────┼───────┤
│ 1  │ Anna Andersson   │     3 ────┼──┐ ┌──►│ 1  │ '1001' │   0   │
│ 2  │ Bertil Berg      │     3 ────┼──┤ │   │ 2  │ '1002' │   0   │
│ 3  │ Cecilia Carlsson │     1 ────┼──┼─┘ ┌►│ 3  │ '1101' │   1   │
└────┴──────────────────┴───────────┘  └───┘ └────┴────────┴───────┘
                              ▲
                              └── främmande nyckel → apartments.id
```

Anna och Bertil bor båda i lägenhet 1101 (id 3). I stället för att skriva
lägenhetsnumret, våningen och storleken på varje användare sparar vi bara en
**referens** – siffran 3. Då finns lägenhetens uppgifter på exakt *ett* ställe.

Databasen kan dessutom **vakta** referensen: försöker du ge en användare
`apartment = 99` och det inte finns någon lägenhet 99, säger databasen nej. Det
kallas **referensintegritet**.

Så här hänger hela Föreningsappen ihop:

```
apartments  1 ──── *  users          (en lägenhet har många medlemmar)
users       1 ──── *  bookings       (en medlem gör många bokningar)
resources   1 ──── *  bookings       (en resurs har många bokningar)
users       1 ──── *  posts          (en medlem skriver många anslag)
```

`1 ──── *` utläses "ett till många". Den främmande nyckeln ligger alltid på
"många"-sidan: `users.apartment`, `bookings.user`, `bookings.resource`,
`posts.author`.

🧪 **Prova själv:** Titta på datamodellen i kursens [README](../README.md).
Vilken tabell har *två* främmande nycklar? Vad pekar de på?

## 1.6 Relationsdatabaser vs dokumentdatabaser (NoSQL)

Relationsdatabaser är inte den enda sorten. En annan vanlig familj kallas
**NoSQL**, och den vanligaste varianten är **dokumentdatabaser** (t.ex. MongoDB,
Firestore). Där sparas data som JSON-liknande dokument:

```json
{
  "_id": "b1",
  "resource": { "name": "Tvättstuga 1", "max_hours": 3 },
  "user": { "name": "Anna Andersson", "email": "anna@example.com" },
  "start": "2026-10-12T07:00:00Z",
  "end": "2026-10-12T10:00:00Z"
}
```

| | Relationsdatabas (SQL) | Dokumentdatabas (NoSQL) |
|---|------------------------|-------------------------|
| Struktur | Tabeller med fast schema | Dokument med flexibel struktur |
| Relationer | Främmande nycklar + `JOIN` | Ofta inbäddade kopior av data |
| Frågespråk | SQL (standardiserat) | Eget API per produkt |
| Styrka | Konsistens, komplexa frågor, transaktioner | Flexibilitet, enkel horisontell skalning |
| Exempel | SQLite, PostgreSQL, MySQL | MongoDB, Firestore, CouchDB |

Lägg märke till att dokumentet ovan har en *kopia* av Annas namn. Byter hon namn
måste alla hennes bokningsdokument uppdateras. I en relationsdatabas ändrar du
en enda rad i `users`.

💡 **Tips:** För data med tydliga relationer – medlemmar, lägenheter, bokningar –
är en relationsdatabas nästan alltid rätt val. Det är därför vi använder det i
den här kursen.

## 1.7 SQL – språket man pratar med

Relationsdatabaser styrs med **SQL** (*Structured Query Language*, uttalas
"es-kju-ell" eller "sequel"). Ett smakprov:

```sql
SELECT name, email
FROM users
WHERE role = 'board';
```

Svaret blir Anna Andersson och David Dahl – styrelsen. Du *beskriver vad* du
vill ha, inte *hur* databasen ska leta. Det går vi igenom ordentligt i
[kapitel 2](02-sql-grunder.md).

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
SQLite                                PostgreSQL / MySQL
┌───────────────────────┐             ┌──────────────┐        ┌──────────────┐
│ Din app               │             │ Din app      │  TCP   │ DB-server    │
│ ┌───────────────────┐ │             │              │ ─────► │ (egen process)│
│ │ SQLite-bibliotek  │ │             └──────────────┘        └──────┬───────┘
│ └─────────┬─────────┘ │                                            │
└───────────┼───────────┘                                            ▼
            ▼                                                   datafiler
      forening.db  (en fil)
```

SQLite är världens mest använda databas – den finns i varje smartphone. Den är
fullt kapabel för riktiga produkter, och har riktiga transaktioner med ACID
(kapitel 3).

⚠️ **Varning:** SQLite är mer förlåtande med datatyper än andra databaser. Du kan
som standard spara texten `'hej'` i en `INTEGER`-kolumn utan att få fel. Det är
en av anledningarna till att vi lägger till `CHECK`-villkor i våra tabeller. Från
SQLite 3.37 kan man också skriva `CREATE TABLE ... STRICT` för att få strikta typer.

## 1.9 Bryggan till modul 02: PocketBase använder SQLite

**PocketBase**, som vi använder i nästa modul, är en färdig backend i en enda
körbar fil. Under huven sparar den allt i en SQLite-databas: `pb_data/data.db`.

| Det du ser i PocketBase | Det som finns i SQLite |
|-------------------------|------------------------|
| Collection `bookings` | Tabell `bookings` |
| Fält (field) `start` av typen *Date* | Kolumn `start` (text med datum) |
| Fält av typen *Relation* till `users` | Kolumn med id:t på en rad i `users` (en främmande nyckel) |
| Record | Rad |
| Fältet `id` (15 tecken, t.ex. `k3j9x0p2m1q8w7e`) | Primärnyckel (text) |
| Fälten `created` / `updated` | Kolumner som PocketBase fyller i automatiskt |
| *Unique index* i collection-inställningarna | `CREATE UNIQUE INDEX ...` |

Allt du lär dig i den här modulen – nycklar, relationer, index, transaktioner,
normalisering – gäller alltså direkt när du bygger din backend i PocketBase.
Skillnaden är att PocketBase sköter SQL:en åt dig och ger dig ett REST-API och
en adminpanel ovanpå.

💡 **Tips:** Du kan öppna en PocketBase-databas med `sqlite3 pb_data/data.db`
och titta in i tabellerna. Gör det gärna när du kommer till modul 02 – men
*ändra* inget där direkt medan PocketBase kör; gå via adminpanelen eller API:et.

## 1.10 Sammanfattning

- En **databas** lagrar data strukturerat; ett **DBMS** är programmet som sköter den.
- Databaser slår filer och kalkylark när det gäller konsistens, samtidighet,
  behörighet, prestanda och krascher.
- I en **relationsdatabas** ligger data i **tabeller** med **kolumner** (typade
  egenskaper) och **rader** (enskilda saker).
- **Primärnyckeln** identifierar en rad unikt. **Främmande nycklar** pekar på
  rader i andra tabeller och skapar relationer.
- **SQLite** är en fil-baserad relationsdatabas utan server. PostgreSQL och MySQL
  är serverdatabaser.
- **PocketBase** lagrar sina collections som tabeller i SQLite.

## Kontrollfrågor

1. Nämn tre problem med att hålla bokningar i ett Excel-ark.
2. Vad är skillnaden mellan en primärnyckel och en främmande nyckel?
3. Varför är `name` en dålig primärnyckel för `users`?
4. I vilken tabell ligger den främmande nyckeln i en 1-till-många-relation?
5. Vad heter filen där PocketBase sparar sin SQLite-databas?

Nästa kapitel: [Kapitel 2 – SQL-grunder](02-sql-grunder.md)

# Modul 01 – Databaser

I den här modulen lär du dig vad en databas är, hur du pratar med den med SQL,
varför transaktioner och ACID är så viktigt, och hur du designar tabeller som
håller i längden. Allt bygger på kursens gemensamma exempel: **Föreningsappen**
med tabellerna `apartments`, `users`, `resources`, `bookings` och `posts`.

Modulen är grunden för resten av kursen. När du i modul 02 skapar *collections*
i PocketBase är det precis samma tabeller, relationer och regler som här – bara
med ett grafiskt gränssnitt och ett färdigt API ovanpå.

## Lärandemål

När du är klar med modulen ska du kunna:

- förklara vad en databas och ett databashanteringssystem (DBMS) är, och varför
  man använder en databas i stället för filer eller kalkylark,
- beskriva begreppen tabell, rad, kolumn, primärnyckel och främmande nyckel,
- skapa tabeller med lämpliga datatyper och villkor (*constraints*) i SQL,
- skriva frågor med `SELECT`, `WHERE`, `ORDER BY`, `GROUP BY`, `JOIN` och
  underfrågor, samt ändra data med `INSERT`, `UPDATE` och `DELETE`,
- förklara vad en transaktion är och vad var och en av bokstäverna i ACID betyder,
- känna igen typiska samtidighetsproblem (t.ex. dubbelbokning) och hur databasen
  skyddar mot dem,
- designa en datamodell: hitta entiteter, relationer och kardinalitet, rita ett
  ER-diagram och normalisera till tredje normalformen,
- fatta medvetna beslut om nycklar, datatyper, datum, pengar, `NULL` och index.

## Innehåll

| # | Kapitel | Innehåll |
|---|---------|----------|
| 1 | [Vad är en databas?](01-vad-ar-en-databas.md) | Databaser, DBMS, tabeller, nycklar, SQLite vs PostgreSQL, PocketBase |
| 2 | [SQL-grunder](02-sql-grunder.md) | `CREATE TABLE`, CRUD, aggregat, `JOIN`, underfrågor, index, vyer |
| 3 | [ACID och transaktioner](03-acid-och-transaktioner.md) | `BEGIN`/`COMMIT`/`ROLLBACK`, ACID, isoleringsproblem, SQLite/WAL |
| 4 | [Databasdesign](04-databasdesign.md) | ER-diagram, kardinalitet, normalisering, nycklar, datatyper, checklista |
| – | [Övningar](ovningar.md) | Nivå 1–3: SQL-frågor, ACID-tankeövningar, designuppgift |
| – | [Lösningar](losningar.md) | Lösningsförslag (försök själv först!) |
| – | [`seed.sql`](seed.sql) | Skript som skapar och fyller exempeldatabasen |

Rekommenderad ordning: läs kapitlen 1–4 i tur och ordning och gör
🧪 *Prova själv*-uppgifterna under tiden. Gör sedan [övningarna](ovningar.md).

## Installera SQLite

Vi använder **SQLite** i hela modulen. SQLite är en databas som ligger i en
enda fil och inte kräver någon server – perfekt för att lära sig. Det är också
samma databasmotor som PocketBase använder under huven.

Du kan välja mellan ett kommandoradsverktyg (`sqlite3`) och ett grafiskt program
(DB Browser for SQLite). Båda fungerar utmärkt – många använder båda.

### Alternativ A: `sqlite3` på kommandoraden

| System | Installation |
|--------|--------------|
| macOS | Finns redan förinstallerat. Testa `sqlite3 --version` i Terminal. |
| Linux (Debian/Ubuntu) | `sudo apt install sqlite3` |
| Windows | `winget install SQLite.SQLite` eller ladda ner *sqlite-tools* från [sqlite.org/download.html](https://sqlite.org/download.html) och lägg `sqlite3.exe` i en mapp som finns i `PATH`. |

Skapa exempeldatabasen (stå i mappen `01-databaser`):

```bash
sqlite3 forening.db < seed.sql
```

Öppna den sedan och gör en första fråga:

```bash
sqlite3 forening.db
```

```text
SQLite version 3.x
sqlite> .headers on
sqlite> .mode box
sqlite> SELECT * FROM resources;
╭────┬──────────────┬───────────────────────────────────────────────────┬───────────┬────────╮
│ id │     name     │                    description                    │ max_hours │ active │
╞════╪══════════════╪═══════════════════════════════════════════════════╪═══════════╪════════╡
│  1 │ Tvättstuga 1 │ Källaren, hus A. Två maskiner och en torktumlare. │         3 │      1 │
│  2 │ Tvättstuga 2 │ Källaren, hus B. Tre maskiner och torkskåp.       │         3 │      1 │
│  3 │ Festlokalen  │ Plan 0. Plats för 30 personer, kök finns.         │        12 │      1 │
│  4 │ Bastun       │ Stängd för renovering.                            │         2 │      0 │
╰────┴──────────────┴───────────────────────────────────────────────────┴───────────┴────────╯
```

Användbara "punkt-kommandon" i `sqlite3` (de är inte SQL och avslutas inte med `;`):

| Kommando | Vad det gör |
|----------|-------------|
| `.tables` | Lista alla tabeller |
| `.schema bookings` | Visa hur tabellen `bookings` skapades |
| `.headers on` | Visa kolumnnamn i resultatet |
| `.mode box` | Snygg tabellutskrift (prova även `.mode column` och `.mode csv`) |
| `.read seed.sql` | Kör en SQL-fil inifrån `sqlite3` |
| `.quit` | Avsluta |

💡 **Tips:** Lägg raderna `.headers on` och `.mode box` i filen `~/.sqliterc`
så gäller de varje gång du startar `sqlite3`.

⚠️ **Varning:** Varje gång du startar `sqlite3` måste du köra
`PRAGMA foreign_keys = ON;` om du vill att främmande nycklar ska kontrolleras.
Det är avstängt som standard i SQLite (av bakåtkompatibilitetsskäl). Lägg gärna
även den raden i `~/.sqliterc`.

💡 **Tips:** Vill du testa något utan att röra din fil kan du köra
`sqlite3 :memory:` – då ligger databasen bara i minnet och försvinner när du
avslutar. Kör `.read seed.sql` för att fylla den.

### Alternativ B: DB Browser for SQLite

1. Ladda ner och installera från [sqlitebrowser.org](https://sqlitebrowser.org/)
   (macOS: även `brew install --cask db-browser-for-sqlite`).
2. Välj **New Database** och spara som `forening.db`.
3. Stäng dialogen som vill att du skapar en tabell (vi gör det med SQL).
4. Gå till fliken **Execute SQL**, öppna `seed.sql` (mappikonen) och kör hela
   skriptet med ▶ (eller `Ctrl/Cmd + Enter`).
5. Klicka på **Write Changes** för att spara.
6. Under **Browse Data** kan du nu bläddra i tabellerna.

⚠️ **Varning:** DB Browser sparar inte förrän du klickar på **Write Changes**.
Det beror på att allt du gör ligger i en öppen *transaktion* – mer om det i
[kapitel 3](03-acid-och-transaktioner.md).

### Återställ databasen

Har du förstört datan i en övning? Kör bara seed-skriptet igen. Det börjar med
att ta bort alla tabeller och bygger sedan upp allt från början:

```bash
sqlite3 forening.db < seed.sql
```

## Om exempeldatan

Seed-skriptet innehåller 8 lägenheter, 10 medlemmar, 4 resurser (varav bastun är
avstängd), 15 bokningar och 6 anslag. I övningarna låtsas vi att **dagens datum
är måndag 12 oktober 2026** så att alla får samma svar, oavsett när du kör
frågorna. Alla tider lagras i UTC som text i formatet `'YYYY-MM-DD HH:MM:SS'`.

Nästa steg: [Kapitel 1 – Vad är en databas?](01-vad-ar-en-databas.md)

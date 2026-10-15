# 2. Vad är en databas?

En **databas** är en plats där en app sparar sin data, så att den finns kvar
när appen stängs. Den är organiserad så att det går snabbt att hitta, ändra och
koppla ihop data.

Nästan alla appar du använder har en databas:

| App | Vad som sparas i databasen |
|-----|----------------------------|
| Instagram | Användare, bilder, kommentarer, likes, följare |
| Spotify | Låtar, artister, spellistor, vad du har lyssnat på |
| Skolans schema | Elever, lärare, kurser, salar, lektioner |
| En webbutik | Produkter, kunder, beställningar |

## Varför inte bara ett Excel-ark?

Tänk dig att vi sparar Kvittras inlägg i ett kalkylark:

| Datum | Författare | E-post | Inlägg | Gillat av |
|-------|------------|--------|--------|-----------|
| 2026-09-01 | Anna Andersson | anna@example.com | Höstpromenad | bertil, cissi |
| 2026-09-03 | Bertil Berg | bertil@example.com | Surdegsbröd | anna |
| 2026-10-11 | anna andersson | anna@exmaple.com | Morgondimma | bertil, cissi, Bertil |

Det fungerar för några rader, men problemen syns redan:

- Annas namn och e-post står **flera gånger**. På sista raden är e-posten
  felstavad. Vilken är rätt?
- Vill Anna byta e-post måste man ändra på **alla** hennes rader.
- "Gillat av" är en lista i en ruta. "Bertil" och "bertil" står två gånger.
- Med en miljon användare som skriver samtidigt går det inte alls.

En databas löser det här genom att dela upp datan i flera **tabeller** som
pekar på varandra, och genom att ha **regler** för vad som får sparas.

## Tabeller, rader och kolumner

I en **relationsdatabas**, den vanligaste typen, ligger datan i tabeller:

```
                     tabellen users
          ┌──────────┬────────────┬──────────────────┐
          │ id       │ username   │ name             │  ← kolumner
          ├──────────┼────────────┼──────────────────┤
   rad →  │ u1       │ anna       │ Anna Andersson   │
   rad →  │ u2       │ bertil     │ Bertil Berg      │
   rad →  │ u3       │ cissi      │ Cecilia Carlsson │
          └──────────┴────────────┴──────────────────┘
```

| Ord | Betyder | Exempel |
|-----|---------|---------|
| **Tabell** | En sorts sak | `users`, `posts` |
| **Rad** | En sak | Användaren Anna |
| **Kolumn** (fält) | En egenskap som alla rader har | `username` |
| **Datatyp** | Vilken sorts värde kolumnen får ha | text, tal, datum, ja/nej |

I PocketBase kallas en tabell för **collection**, en rad för **record** och en
kolumn för **field**.

## Nycklar – så hänger tabellerna ihop

Varje rad har ett unikt **id**. Det kallas **primärnyckel**. Två rader kan
aldrig ha samma id.

När en tabell behöver peka på en rad i en annan tabell sparar den id:t. Det
kallas **främmande nyckel**:

```
            posts                                users
┌─────┬──────────────┬────────┐        ┌─────┬──────────┐
│ id  │ title        │ author │        │ id  │ username │
├─────┼──────────────┼────────┤        ├─────┼──────────┤
│ p1  │ Höstpromenad │ u1  ───┼───────►│ u1  │ anna     │
│ p2  │ Surdegsbröd  │ u2  ───┼───────►│ u2  │ bertil   │
│ p3  │ Morgondimma  │ u1  ───┼───────►│ u3  │ cissi    │
└─────┴──────────────┴────────┘        └─────┴──────────┘
```

Annas namn står bara **en** gång, i `users`. Inläggen pekar på henne med
`author = u1`. Byter Anna namn ändras det på ett enda ställe.

I PocketBase gör man en främmande nyckel med ett **relationsfält**.

## Olika typer av databaser

| Typ | Hur datan sparas | Exempel | Bra till |
|-----|------------------|---------|----------|
| **Relationsdatabas** (SQL) | Tabeller med rader och kolumner som pekar på varandra | SQLite, PostgreSQL, MySQL | De flesta appar: användare, inlägg, beställningar |
| **Dokumentdatabas** (NoSQL) | "Dokument" som liknar JSON, ett per sak | MongoDB, Firebase Firestore | Data som ser olika ut från gång till gång |
| **Nyckel–värde-databas** | Ett namn och ett värde, som en ordlista | Redis | Väldigt snabb tillfällig lagring, t.ex. vem som är inloggad |
| **Grafdatabas** | Punkter och kopplingar mellan dem | Neo4j | Nätverk, t.ex. "vänner till dina vänner" |

Ett dokument i en dokumentdatabas kan se ut så här:

```json
{
  "title": "Höstpromenad",
  "author": { "username": "anna", "name": "Anna Andersson" },
  "likes": ["bertil", "cissi"]
}
```

Det är smidigt att läsa, men samma problem som i Excel kommer tillbaka: Annas
namn kopieras in i varje inlägg.

**PocketBase är en relationsdatabas.** Under huven använder den **SQLite**,
som också finns i nästan alla mobiltelefoner. Därför jobbar vi med tabeller
och relationer i resten av kursen.

## Sammanfattning

- En databas sparar en apps data så att den finns kvar och går att söka i.
- En relationsdatabas delar upp datan i **tabeller** med **rader** och **kolumner**.
- Varje rad har ett unikt **id** (primärnyckel).
- Tabeller pekar på varandra med id:n (främmande nycklar, relationer).
- PocketBase är en relationsdatabas byggd på SQLite.

Nästa kapitel: [Databasdesign med Kvittra](03-databasdesign-med-kvittra.md)

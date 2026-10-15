# 4. Övning – designa ditt projekt

Nu gör ni samma sak som vi gjorde med Kvittra, men med **ert eget projekt** från
förstudien. Målet är en databasdesign som du kan bygga i PocketBase.

Arbeta i ett dokument (eller på papper) och följ stegen.

## Steg 1 – Beskriv idén

Skriv 3–5 meningar om vad appen ska göra och vem som använder den. Utgå från
er förstudie.

> Exempel: *"Läxkollen är en app där elever ser sina läxor. Lärare lägger in
> läxor för en kurs. Eleverna kan bocka av en läxa när de är klara."*

## Steg 2 – Hitta tabellerna

Stryk under alla substantiv. Gör en tabell som den här och bestäm vilka som blir
tabeller:

| Substantiv | Blir tabell? | Varför / varför inte |
|------------|--------------|----------------------|
| | | |
| | | |

💡 Kom ihåg tumregeln: finns det **många** av något, med **egna uppgifter**, blir
det en tabell.

## Steg 3 – Bestäm fälten

Gör en tabell per tabell i din design:

**namn_på_tabellen**

| Fält | Typ | Måste fyllas i? | Unikt? | Kommentar |
|------|-----|-----------------|--------|-----------|
| id | id | ja | ja | Automatiskt |
| | | | | |

Typer du kan välja mellan (de finns i PocketBase):

| Typ | Används till | PocketBase-typ |
|-----|--------------|----------------|
| text | Namn, rubriker, korta texter | Plain text |
| lång text | Beskrivningar med formatering | Rich editor |
| tal | Antal, pris, poäng | Number |
| ja/nej | Klar, publicerad, aktiv | Bool |
| e-post | E-postadresser | Email |
| url | Länkar | URL |
| datum | Datum och tid | DateTime |
| val | Ett av flera bestämda värden, t.ex. "låg/medel/hög" | Select |
| fil | Bilder och dokument | File |
| relation | Pekar på en rad i en annan tabell | Relation |

## Steg 4 – Hitta relationerna

Skriv varje relation som två meningar och bestäm sorten:

| Mening åt ena hållet | Mening åt andra hållet | Sort | Löses med |
|----------------------|------------------------|------|-----------|
| En lärare har många kurser | En kurs har en lärare | 1:N | `courses.teacher` → users |
| | | | |

Kom ihåg: en **N:M-relation** behöver en **kopplingstabell**.

## Steg 5 – Rita ER-diagrammet

Rita alla tabeller som lådor med fälten i. Dra pilar för relationerna och skriv
`1` och `*` vid ändarna. Rita för hand och fota, eller använd
[draw.io](https://app.diagrams.net/) eller [dbdiagram.io](https://dbdiagram.io/).

## Steg 6 – Kontrollera

Gå igenom checklistan från [kapitel 3](03-databasdesign-med-kvittra.md#steg-6--kontrollera-designen)
och skriv en mening per punkt om hur din design klarar den.

## Steg 7 – Byt med en annan grupp

Byt design med en annan grupp och granska varandras. Svara på frågorna:

1. Finns det någon uppgift som står på två ställen?
2. Finns det något fält som innehåller en lista?
3. Saknas någon tabell för att appen ska kunna göra det som beskrivs i steg 1?
4. Finns det något som sparas fast det kan räknas fram?

Ändra din design utifrån svaren.

Nästa kapitel: [Bygg Kvittra i PocketBase](05-bygg-kvittra-i-pocketbase.md)

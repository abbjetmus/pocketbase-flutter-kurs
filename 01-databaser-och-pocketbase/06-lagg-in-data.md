# 6. Lägg in data

Nu fyller vi Kvittra med data. Du skriver in allt för hand i Dashboard. Det tar
en stund, men du ser tydligt hur relationerna fungerar.

Samma data används i SQL-övningarna i nästa kapitel, så skriv in **exakt** det
som står här.

## Så lägger du in en record

1. Klicka på en collection till vänster.
2. Klicka **+ New record**.
3. Fyll i fälten och klicka **Create**.

För ett **relationsfält** klickar du på fältet och väljer vilken record det ska
peka på i listan som visas.

💡 **Gör relationerna lättare att välja:** Öppna kugghjulet på fältet `username`
i `users` och fältet `title` i `posts` och kryssa i **Presentable**. Då visas
användarnamn och rubriker i listorna i stället för bara id:n.

## Ordningen

Du kan bara peka på något som redan finns. Lägg därför in data i den här
ordningen: **users → posts → comments → likes → follows**.

## 1. users

Alla får lösenordet `kvittra123`. Skriv det två gånger (Password och Password
confirm).

| username | name | email | bio |
|----------|------|-------|-----|
| anna | Anna Andersson | anna@example.com | Gillar promenader och foto |
| bertil | Bertil Berg | bertil@example.com | Bakar bröd varje helg |
| cissi | Cecilia Carlsson | cissi@example.com | |
| david | David Dahl | david@example.com | Spelar fotboll |

## 2. posts

| author | title | body |
|--------|-------|------|
| anna | Höstpromenad | Löven har börjat gulna i parken. |
| bertil | Mitt första surdegsbröd | Det blev platt men gott! |
| anna | Morgondimma | Dimman låg tät över sjön i morse. |
| cissi | Tips på en bra bok? | Jag behöver något att läsa på bussen. |
| david | Matchdag | Vi vann med 3–1! |
| bertil | Andra försöket | Nu jäste degen ordentligt. |

## 3. comments

| post | author | body |
|------|--------|------|
| Höstpromenad | bertil | Fina färger! |
| Mitt första surdegsbröd | anna | Snyggt jobbat! |
| Mitt första surdegsbröd | cissi | Recept tack! |
| Tips på en bra bok? | anna | Läs Mio min Mio! |
| Tips på en bra bok? | david | Harry Potter! |
| Matchdag | bertil | Grattis! |

## 4. likes

| post | user |
|------|------|
| Höstpromenad | bertil |
| Höstpromenad | cissi |
| Mitt första surdegsbröd | anna |
| Mitt första surdegsbröd | cissi |
| Mitt första surdegsbröd | david |
| Matchdag | anna |
| Andra försöket | anna |
| Andra försöket | cissi |

## 5. follows

Läs raden som "*follower* följer *following*".

| follower | following |
|----------|-----------|
| anna | bertil |
| anna | cissi |
| bertil | anna |
| cissi | anna |
| david | bertil |

## Kontrollera

Så många records ska varje collection ha:

| Collection | Antal |
|------------|-------|
| users | 4 |
| posts | 6 |
| comments | 6 |
| likes | 8 |
| follows | 5 |

Nästa kapitel: [SQL och View collections](07-sql-och-view-collections.md)

# Övningar – Modul 01 Databaser

Övningarna är indelade i tre nivåer. Börja med nivå 1 och gå vidare när det
känns lätt. Lösningsförslag finns i [losningar.md](losningar.md) – men försök
själv först! Det finns ofta flera korrekta sätt att skriva samma fråga.

## Förberedelser

1. Du har installerat PocketBase och byggt Kvittra med exempeldatan, inklusive
   steg 2d där inläggen fick sina datum (se [modulens README](README.md)).
   Kontrollera antalet: **6 users, 10 posts, 13 comments, 19 likes, 10 follows**.
2. **`SELECT`-övningar löser du som View collections:** *New collection* → typ
   **View** → skriv frågan i *Select query* → *Create*. Döp dem efter övningen,
   t.ex. `ovning_2_3`. Kom ihåg:
   - frågan måste ha en kolumn `id` som är unik per rad – använd t.ex. `p.id`
     eller `u.id`, eller `(ROW_NUMBER() OVER ()) AS id` när inget naturligt id
     finns,
   - din `ORDER BY` bestämmer ordningen i listan.
3. **Övningar som ändrar data** gör du i Dashboard eller i **Settings → SQL
   console**. I SQL console: avsluta alltid `BEGIN` med `COMMIT` eller
   `ROLLBACK` i *samma* körning (se varningen i README).
4. **Vi låtsas att dagens datum är måndag 12 oktober 2026.** "Senaste veckan"
   betyder därför `created >= '2026-10-05'`. Skriv inte `datetime('now')` – då
   får du ett annat svar än alla andra.
5. Använd **användarnamn och titlar** i dina frågor, inte id:n – dina id:n är
   slumpade och ser annorlunda ut än någon annans.

💡 **Tips:** Svaret står ofta i uppgiften som "(förväntat: …)". Använd det för att
kontrollera dig själv. Får du ett annat svar – kontrollera först att datan är
inmatad exakt som i README.

---

## Del A – SQL-frågor

### Nivå 1 – SELECT, WHERE, ORDER BY

**1.1** Visa användarnamn och webbplats för alla användare som **har** en
webbplats. *(förväntat: 2 rader)*

**1.2** Visa användarnamnen på alla som **inte** har skrivit någon bio.
*(förväntat: evaek och johan)* Varför fungerar inte `bio IS NULL` i PocketBase?

**1.3** Hur många inlägg finns det totalt? Gör en view som returnerar en enda rad.
*(förväntat: 10)*

**1.4** Visa titel och datum för alla inlägg skrivna av `anna`, nyaste först.
*(förväntat: 2 rader, "Morgondimma" först)* Du behöver en `JOIN` mot `users`
eller en underfråga för att hitta Annas id.

**1.5** Visa alla inlägg som handlar om kaffe, dvs. där ordet "kaffe" finns i
titeln **eller** i texten. Använd `LIKE`. *(förväntat: 2 rader)*

**1.6** Flödet visar 4 inlägg per sida, nyaste först. Vilka inlägg syns på
**sida 2**? Använd `LIMIT` och `OFFSET`.
*(förväntat: "Kaffe efter löprundan" först, "Brädspelskväll på fredag" sist)*

**1.7** Visa titlarna på alla inlägg från **oktober 2026**, äldst först.
*(förväntat: 4 rader)* Varför är `created BETWEEN '2026-10-01' AND '2026-10-31'`
en farlig lösning?

**1.8** Visa texten i alla kommentarer på inlägget "Halvmaran avklarad", i den
ordning de skrevs. Lös det med en underfråga i `WHERE`. *(förväntat: 3 rader)*

**1.9 – Ändra data.** Gör följande i tur och ordning och kontrollera efter varje
steg:

1. Skapa dig själv som användare i Dashboard (`users` → *New record*). Hitta på
   ett användarnamn och använd en e-post som slutar på `@example.com`.
2. Skriv ett inlägg i ditt namn (`posts` → *New record*).
3. Ändra din bio med en `UPDATE` i SQL console. Kontrollera i Dashboard.
4. Försök ändra ditt användarnamn till `anna` i Dashboard. Vad händer, och varför?
5. Ta bort dig själv i Dashboard. Vad hände med ditt inlägg?
6. Kontrollera att du är tillbaka på 6 users och 10 posts.

**1.10 – Regler.** Testa vad som skyddar Kvittra, och förklara *var* regeln
finns (i databasen eller i PocketBase):

1. Skapa en `follows`-record där `dahl` följer `cissi` (det gör han redan).
2. Skapa ett inlägg utan titel.
3. Skapa en `follows`-record där `johan` följer `johan`. Går det? Vad skulle
   behövas för att stoppa det?
4. Lägg in en kommentar på ett inlägg som inte finns, med SQL console:
   `INSERT INTO comments (post, author, body, created) VALUES ('finnsinte12345', (SELECT id FROM users WHERE username = 'anna'), 'Hallå?', '2026-10-12 12:00:00.000Z');`
   Varför går det? Ta bort kommentaren igen, och ta även bort johans
   självföljning från punkt 3.

### Nivå 2 – Aggregat, GROUP BY, JOIN

**2.1** Hur många kommentarer har varje användare skrivit? Användare som inte
kommenterat något ska också visas, med `0`. Sortera med flest först.
*(förväntat: 6 rader, anna 5 överst, johan 0 sist)*

**2.2** Visa varje inlägg och hur många gillningar det har, mest gillat först.
Inlägg utan gillningar ska visas med `0`.
*(förväntat: 10 rader, "Halvmaran avklarad" 4 överst, "Hej Kvittra!" 0 sist)*

**2.3 – Annas flöde.** Visa alla inlägg från personer som `anna` följer, med
författarens användarnamn, titel och datum, nyaste först. *(förväntat: 5 rader)*

**2.4 – Vem gillar mina inlägg?** Visa vilka som har gillat **Annas** inlägg och
hur många av hennes inlägg var och en har gillat.
*(förväntat: bertil 2, cissi 2, dahl 1)*

**2.5 – Mest aktiva kommentatorer.** Visa användare som har skrivit **minst 2**
kommentarer, flest först. Använd `HAVING`. *(förväntat: 4 rader)*

**2.6** Vilka inlägg har ingen kommentar alls? Lös det på två sätt: med
`LEFT JOIN` och med `NOT EXISTS`. *(förväntat: 2 rader)*

**2.7** Vilka användare har **minst 3 följare**? *(förväntat: anna 4, cissi 3)*

**2.8 – Veckans topplista.** Visa de 3 mest gillade inläggen från den senaste
veckan (skapade från och med 5 oktober 2026), med antal gillningar.
*(förväntat: "Halvmaran avklarad" 4, "Brädspelskväll igen?" 3, "Morgondimma" 2)*
Varför är "Kanelbullens dag" inte med?

**2.9** Har någon gillat sitt **eget** inlägg? Visa användarnamn och titel.
*(förväntat: 1 rad)*

**2.10** Hur många gillningar har varje användare **fått** totalt (på alla sina
inlägg)? Alla användare ska vara med.
*(förväntat: cissi 7 överst; evaek och johan 0)*

### Nivå 3 – Underfrågor, självjoin, vyer, transaktioner

**3.1 – Ömsesidiga följare.** Visa alla par av användare som följer **varandra**.
Varje par ska bara visas en gång (inte både anna–bertil och bertil–anna).
*(Tips: joina `follows` med sig själv.)* *(förväntat: 3 par)*

**3.2 – Förslag på vilka du kan följa.** Hitta personer som de Anna följer i sin
tur följer – men som Anna inte redan följer (och inte Anna själv). Visa hur många
av Annas kontakter som följer var och en, flest först.
*(förväntat: dahl, via 2 av Annas kontakter)*

**3.3** Vilka inlägg har **fler gillningar än genomsnittet**? Genomsnittet är
antal gillningar delat med antal inlägg (även de som inte har några gillningar).
*(förväntat: genomsnittet är 1,9 och 6 inlägg ligger över)*

**3.4 – Senaste inlägget.** Visa varje användares **senaste** inlägg (titel och
datum). Användare utan inlägg ska inte vara med. *(Tips: korrelerad underfråga
med `MAX`.)* *(förväntat: 5 rader)*

**3.5 – Statistikvy.** Skapa en View collection `user_stats` med kolumnerna
`username`, `posts_count`, `comments_count`, `followers_count`,
`following_count` och `likes_received`. Alla användare ska vara med.

Skriv först en version med `LEFT JOIN` mot både `posts` och `follows` och
`COUNT`. Varför blir Annas siffror fel (8 och 8 i stället för 2 och 4)? Skriv
sedan en korrekt version. *(förväntat för cissi: 3, 3, 3, 2, 7)*

**3.6 – Envägsföljare.** Vilka följer Anna, utan att Anna följer dem tillbaka?
*(förväntat: evaek och johan)*

**3.7 – Gilla med räknare (SQL console).** Nu provar vi den denormaliserade
räknaren från kapitel 3 och 4.

1. Lägg till ett fält `likes_count` av typen **Number** (Min 0) på `posts` i
   Dashboard.
2. Fyll i räknaren för alla inlägg med **en** `UPDATE` och en korrelerad
   underfråga.
3. Skriv en View collection `likes_check` som visar alla inlägg där
   `likes_count` **inte** stämmer med det faktiska antalet gillningar.
   *(förväntat: 0 rader)*
4. Låt `johan` gilla "Morgondimma": en `INSERT` i `likes` och en `UPDATE` av
   räknaren, inom `BEGIN ... COMMIT`. Kontrollera `likes_check` igen.
5. Kör samma två satser en gång till, men **utan** `BEGIN`/`COMMIT`. Vilket fel
   får du? Har räknaren ändrats? Varför ska du inte ha `BEGIN` med här?
6. Städa: ta bort johans gillning och minska räknaren – i samma körning. Ta
   sedan bort fältet `likes_count` i Dashboard.

**3.8 – Idempotent gilla.** Skriv en `INSERT` som låter `johan` gilla
"Hej Kvittra!" och som **inte** ger fel om gillningen redan finns. Lägg till
`SELECT changes() AS andrade;` sist i samma körning. Kör den två gånger. Vad
visar `andrade` första och andra gången? Ta bort gillningen efteråt.

**3.9 – Kaskader.** Förutsäg *innan* du kör: om `bertil` tas bort i Dashboard,
hur många rader försvinner från `posts`, `comments`, `likes` och `follows`?
Skriv sedan en View collection som räknar det (en rad, fyra kolumner) – utan att
ta bort något. Vad hade hänt om du i stället hade kört
`DELETE FROM users WHERE username = 'bertil';` i SQL console?

---

## Del B – ACID och transaktioner (tankeövningar)

Svara med egna ord. Det finns inte alltid ett enda rätt svar – motivera!

**B.1** När Anna publicerar ett inlägg ska två saker hända: inlägget sparas och
alla hennes följare får en rad i en tabell `notifications`. Appen gör två
separata API-anrop, och det andra misslyckas på grund av dålig mobiltäckning.
Vilken ACID-egenskap har appen *inte* fått hjälp av? Hur borde det lösas?

**B.2** Johan trycker två gånger snabbt på "Gilla". Appen kontrollerar först med
en `SELECT` om han redan gillat, och gör sedan en `INSERT`. Rita en tidslinje som
visar hur det kan bli två gillningar – i en databas *utan* unikt index. Föreslå två
olika lösningar och beskriv för- och nackdelar med var och en.

**B.3** Kvittra sparar `likes_count` på varje inlägg. Två appar läser värdet 4
samtidigt och skriver tillbaka 5. Vad heter problemet? Skriv en SQL-sats som
ökar räknaren säkert. Hur kan man dessutom förhindra att värdet blir negativt
när gillningar tas bort? Och – behövs räknaren alls?

**B.4** Strömmen går på servern direkt efter att PocketBase svarat "Inlägget är
publicerat" till appen. När servern startar igen – finns inlägget? Vilken
ACID-egenskap handlar det om, och vilken mekanism i SQLite gör det möjligt?

**B.5** En utvecklare tar backup genom att kopiera `pb_data/data.db` varje natt
medan PocketBase kör. Varför är det riskabelt? Vad bör hen göra i stället?

**B.6** Para ihop varje scenario med rätt isoleringsproblem (dirty read,
non-repeatable read, phantom read, lost update):

| # | Scenario |
|---|----------|
| a | Flödet visar rubriken "3 kommentarer", men listan under visar 4, eftersom någon kommenterade mellan de två frågorna. |
| b | Anna redigerar sitt inlägg på mobilen och på datorn samtidigt. Den som sparar sist skriver över den andras ändringar. |
| c | En notistjänst läser ett nytt inlägg och skickar push-notiser, men författaren gör `ROLLBACK` – inlägget publicerades aldrig. |
| d | En transaktion läser Cissis användarnamn två gånger och får `cissi` och sedan `cissi_springer`. |

---

## Del C – Designuppgifter

Välj **en** av uppgifterna (eller gör båda!). Redovisa:

1. en lista över **entiteter** och deras **attribut**,
2. **relationer** med **kardinalitet** (1:1, 1:N, N:M) – motivera åt båda hållen,
3. ett **ER-diagram** (ASCII, papper eller verktyg),
4. `CREATE TABLE`-satser för SQLite med datatyper, villkor, främmande nycklar
   (med `ON DELETE`) och index,
5. lite testdata och **två frågor** som visar att designen fungerar,
6. en kort motivering att designen är i **3NF**, och eventuella medvetna
   avsteg.

Bygg vidare på de befintliga tabellerna – skapa inte en ny `users`-tabell!

💡 **Tips:** Vill du testa din design på riktigt? Bygg tabellerna som collections i
PocketBase (relationer, *Required*, unika index) och skriv frågorna som View
collections. Regler som inte går att uttrycka i Dashboard skriver du som kommentar
– du lär dig API-regler och hooks i modul 02.

### C.1 – Direktmeddelanden

> *"Användare ska kunna skicka privata meddelanden till varandra. En
> **konversation** kan vara mellan två personer eller en grupp (då har den ett
> namn). Varje meddelande har en avsändare, en text och en tidpunkt, och man ska
> kunna redigera eller ta bort sina egna meddelanden. Vi vill visa hur många
> **olästa** meddelanden man har i varje konversation, och i
> gruppkonversationer vill vi kunna visa 'Läst av anna, cissi' under ett
> meddelande. Man ska kunna lämna en konversation."*

Tänk särskilt på:

- Vad är N:M här, och behöver kopplingen egna attribut?
- Hur vet du att avsändaren av ett meddelande faktiskt är med i konversationen?
- Läskvitton: en rad per (meddelande, läsare) – eller en tidpunkt "läst fram
  till" per deltagare? För- och nackdelar?
- Hur skriver du frågan "antal olästa meddelanden per konversation för anna"?

### C.2 – Album och foton

> *"Användare ska kunna skapa **album** med en titel och en beskrivning och ladda
> upp **foton** till dem (inspirerat av JSONPlaceholders `/albums` och
> `/photos`). Ett foto har en titel, en bild och en liten miniatyrbild. Fotona i
> ett album ska ha en bestämd ordning som ägaren kan ändra, och ett av fotona kan
> väljas som albumets **omslagsbild**. Man ska kunna **tagga** användare som syns
> på ett foto. Ett album kan vara synligt för alla, bara för följare eller bara
> för ägaren."*

Tänk särskilt på:

- Var och hur lagrar du själva bilderna?
- Hur ser du till att två foton i samma album inte har samma plats i ordningen?
- Omslagsbilden: en kolumn i `albums` som pekar på `photos` – samtidigt som
  `photos` pekar på `albums`. Vilket problem uppstår, och i vilken ordning måste
  du lägga in data?
- Hur lagrar du synligheten?
- Skriv frågan "visa varje album med ägare, antal foton och omslagsbildens titel".

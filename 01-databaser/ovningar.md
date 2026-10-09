# Övningar – Modul 01 Databaser

Övningarna är indelade i tre nivåer. Börja med nivå 1 och gå vidare när det
känns lätt. Lösningsförslag finns i [losningar.md](losningar.md) – men försök
själv först! Det finns ofta flera korrekta sätt att skriva samma fråga.

## Förberedelser

1. Skapa (eller återställ) exempeldatabasen:

   ```bash
   sqlite3 forening.db < seed.sql
   sqlite3 forening.db
   ```

2. Slå på det här i början av varje session:

   ```text
   .headers on
   .mode box
   PRAGMA foreign_keys = ON;
   ```

3. **Vi låtsas att dagens datum är måndag 12 oktober 2026.** Skriv därför
   `'2026-10-12 00:00:00'` i stället för `datetime('now')` när en uppgift säger
   "i dag" eller "kommande". Då får alla samma svar.

💡 **Tips:** Har du förstört datan? Kör `.read seed.sql` inifrån `sqlite3`
(eller kommandot i steg 1) så är allt som nytt igen.

💡 **Tips:** Svaret står ofta i uppgiften som "(förväntat: …)". Använd det för att
kontrollera dig själv.

---

## Del A – SQL-frågor

### Nivå 1 – SELECT, WHERE, ORDER BY

**1.1** Visa alla resurser som är aktiva. *(förväntat: 3 rader)*

**1.2** Visa nummer och våning för alla lägenheter på våning 2 eller högre,
sorterade på lägenhetsnummer. *(förväntat: 4 rader)*

**1.3** Hur många medlemmar finns det i föreningen? *(förväntat: 10)*

**1.4** Visa id, medlem (id) och anteckning för alla bokningar som **har** en
anteckning. *(förväntat: 4 rader)*

**1.5** Visa titel och datum för alla **publicerade** anslag, nyaste först.
*(förväntat: 5 rader, "Cykelrensning" först)*

**1.6** Vilken är föreningens största lägenhet? Visa nummer och storlek. Lös det
med `ORDER BY` och `LIMIT`.

**1.7** Visa namn och e-post för alla medlemmar vars e-postadress innehåller
bokstäverna `an` (i följd). Använd `LIKE`. *(förväntat: 3 rader)*

**1.8** Visa namnen på alla medlemmar som **inte** har någon lägenhet kopplad.

**1.9 – Ändra data.** Gör följande i tur och ordning, och kontrollera efter varje
steg med en `SELECT`:

1. Lägg till dig själv som medlem i lägenhet `1102` (id 4). Hitta på en e-post.
2. Ändra din roll till `'board'`.
3. Försök ändra din roll till `'kung'`. Vad händer, och varför?
4. Ta bort dig själv igen.

**1.10** Försök lägga in en bokning som slutar innan den börjar. Vilket fel får
du? Försök sedan lägga in en bokning för `user = 42`. Vilket fel får du nu?

### Nivå 2 – Aggregat, GROUP BY, JOIN

**2.1** Hur många medlemmar finns det per roll? Sortera med vanligaste rollen
först. *(förväntat: member 7, board 2, admin 1)*

**2.2** Visa varje lägenhetsnummer och hur många medlemmar som bor där. Lägenheter
utan medlemmar ska också visas, med `0`. *(förväntat: 8 rader)*

**2.3** Visa veckans schema: alla bokningar som startar mellan måndag 12 oktober
och söndag 18 oktober (inklusive), med starttid, sluttid, **resursens namn** och
**medlemmens namn**, sorterade på starttid. *(förväntat: 11 rader)*

**2.4** Visa alla publicerade anslag med titel, författarens namn och
författarens lägenhetsnummer.

**2.5** Hur många timmar har varje resurs bokats totalt? Visa resursens namn och
antal timmar, mest bokad först. *(Tips: `unixepoch()`, se kapitel 4.6.)*
*(förväntat: Festlokalen 24, Tvättstuga 1 21, Tvättstuga 2 15)*

**2.6** Vilka resurser har aldrig bokats? Lös det på två sätt: med `LEFT JOIN`
och med `NOT EXISTS`.

**2.7** Vilka medlemmar har bokat festlokalen? Visa varje namn bara en gång.
*(förväntat: 3 namn)*

**2.8** Visa per våning antal lägenheter och total yta, men bara för våningar där
den totala ytan är större än 120 kvm. *(förväntat: våning 2 och 3)*

**2.9** Vilka medlemmar har bokat **både** Tvättstuga 1 och Tvättstuga 2?
*(Tips: `GROUP BY` + `HAVING COUNT(DISTINCT ...)`.)*

**2.10** Vilka är de tre medlemmar som har bokat flest timmar totalt?

### Nivå 3 – Underfrågor, självjoin, vyer, transaktioner

**3.1 – Dubbelbokningar.** Skriv en fråga som hittar alla par av bokningar på
**samma resurs** vars tider **överlappar**. Varje par ska bara visas en gång.
Seed-datan innehåller inga överlapp, så testa genom att lägga in två bokningar som
krockar, kör frågan, och ta bort dem igen. *(Tips: joina `bookings` med sig själv.)*

**3.2 – Lediga pass.** Tvättstuga 1 har passen 07–10, 10–13, 13–16, 16–19 och
19–22. Skriv en fråga som visar vilka pass som är **lediga** måndag 12 oktober.
*(Tips: skapa passen med `WITH slots(slot_start, slot_end) AS (VALUES (...), ...)`
och använd `NOT EXISTS` med överlappsvillkoret.)* *(förväntat: 3 lediga pass)*

**3.3 – Regelbrott.** Hitta alla bokningar som är längre än resursens
`max_hours`. *(förväntat i seed: 0 rader – testa med en egen felaktig bokning)*

**3.4 – Nästa bokning.** Visa varje medlems **nästa** kommande bokning
(starttid från och med i dag). Medlemmar utan kommande bokning ska inte vara med.

**3.5 – Statistikvy.** Skapa en vy `member_stats` med kolumnerna `id`, `name`,
`apartment_number`, `bookings_count` och `booked_hours`. Alla medlemmar ska vara
med, även de utan bokningar och utan lägenhet (då med `0` timmar).
Använd vyn för att lista medlemmarna sorterade på bokade timmar.

**3.6 – Aktivitet per lägenhet.** Hur många bokningar har gjorts per lägenhet
(alla medlemmar i lägenheten räknas ihop)? Visa alla lägenheter, även de utan
bokningar. *(förväntat: 1101 överst med 6)*

**3.7 – Säker bokning.** Skriv en transaktion där Fredrik (id 6) bokar
festlokalen lördag 31 oktober 12:00–20:00. Gör först en kontroll att tiden är
ledig, och sedan insättningen – i *samma* transaktion. Vilken sorts `BEGIN` ska
du använda i SQLite och varför?

**3.8 – Fast passindelning.** Skapa ett villkor som gör det **omöjligt** att
lägga in två bokningar på samma resurs med samma starttid. Testa att det
fungerar. Varför räcker inte detta som skydd för festlokalen, där man kan boka
fria tider?

**3.9 – Kaskader.** Förutsäg *innan* du kör: vad händer med bokningar och anslag
om du tar bort Anna (id 1)? Och om du tar bort lägenhet 3 (1101)? Kör sedan
inuti en transaktion, kontrollera, och avsluta med `ROLLBACK`.

---

## Del B – ACID och transaktioner (tankeövningar)

Svara med egna ord. Det finns inte alltid ett enda rätt svar – motivera!

**B.1** Föreningen tar ut en avgift på 200 kr för festlokalen. När en medlem bokar
ska två saker hända: en rad läggs in i `bookings` och en rad i en tabell `charges`
(avgifter). Appen gör två separata API-anrop, och det andra misslyckas på grund av
dålig mobiltäckning. Vilken ACID-egenskap har appen *inte* fått hjälp av? Hur
borde det lösas?

**B.2** Bertil och Eva bokar samma tvättpass exakt samtidigt (se kapitel 3.3).
Rita en tidslinje som visar hur det kan bli en dubbelbokning. Föreslå två olika
lösningar och beskriv för- och nackdelar med var och en.

**B.3** Föreningens app visar "Lediga platser i bastun: 4". Två appar läser värdet
4 samtidigt och skriver tillbaka 3. Vad heter problemet? Skriv en SQL-sats som
gör minskningen säkert. Hur kan man dessutom förhindra att värdet blir negativt?

**B.4** Strömmen går på servern direkt efter att PocketBase svarat "Bokning
skapad" till appen. När servern startar igen – finns bokningen? Vilken
ACID-egenskap handlar det om, och vilken mekanism i SQLite gör det möjligt?

**B.5** En utvecklare tar backup genom att kopiera `pb_data/data.db` varje natt
medan PocketBase kör. Varför är det riskabelt? Vad bör hen göra i stället?

**B.6** Para ihop varje scenario med rätt isoleringsproblem (dirty read,
non-repeatable read, phantom read, lost update):

| # | Scenario |
|---|----------|
| a | En rapport räknar bokningar i oktober två gånger i samma transaktion och får olika antal, eftersom någon bokade emellan. |
| b | Två styrelseledamöter redigerar samma anslag samtidigt. Den som sparar sist skriver över den andras ändringar. |
| c | En transaktion läser att bastun är stängd, men den som stängde den gör `ROLLBACK`. |
| d | En transaktion läser festlokalens `max_hours` två gånger och får 12 och sedan 6. |

---

## Del C – Designuppgift

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

### C.1 – Styrelsemöten med protokoll och närvaro

> *"Styrelsen har möten ungefär en gång i månaden. Varje möte har ett datum, en
> plats och en typ (ordinarie styrelsemöte, extra möte eller föreningsstämma).
> Vid varje möte förs ett protokoll med numrerade paragrafer (§1, §2, …); varje
> paragraf har en rubrik och en text och kan ha ett beslut. Vi vill kunna se vilka
> medlemmar som var kallade och vilka som faktiskt närvarade, och vem som var
> ordförande respektive sekreterare på mötet. Ett protokoll ska kunna justeras av
> två justerare, och vi vill veta när det justerades."*

Tänk särskilt på:

- Vad är N:M här, och behöver kopplingen egna attribut?
- Hur säkerställer du att samma paragrafnummer inte finns två gånger på samma möte?
- Ska ordförande/sekreterare vara kolumner på mötet eller en roll i närvarotabellen?
- Hur skriver du en fråga för "närvaroprocent per styrelseledamot under 2026"?

### C.2 – Kö till parkeringsplatser

> *"Föreningen har 12 parkeringsplatser, några med elbilsladdare. Varje plats har
> ett nummer och en månadsavgift. En plats hyrs ut till en lägenhet i taget, och
> vi vill spara historik över vem som hyrt vilken plats och när (från–till). Den
> som vill ha plats ställer sig i en kö; kön gäller per lägenhet och ordningen
> bestäms av datumet man ställde sig i kön. Man kan önska laddplats. När man får
> en plats eller ångrar sig lämnar man kön."*

Tänk särskilt på:

- Hyr *lägenheten* eller *medlemmen* platsen? Vad händer när någon flyttar?
- Hur ser du till att en plats inte är uthyrd till två lägenheter samtidigt?
- Ska köplatsen ("nummer 3 i kön") sparas, eller räknas fram? Varför?
- Hur lagrar du månadsavgiften?
- Skriv frågan "visa kön i ordning, med lägenhetsnummer och placering".

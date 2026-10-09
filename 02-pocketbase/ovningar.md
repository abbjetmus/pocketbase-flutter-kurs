# Övningar – Modul 02: PocketBase

Övningarna bygger på varandra. Gör dem i ordning i **samma** projektmapp
(t.ex. `foreningen-pb`). Svårighetsgrad:

- **Nivå 1** – följ stegen, nästan allt står i texten.
- **Nivå 2** – du behöver kombinera saker från kapitlen själv.
- **Nivå 3** – fria uppgifter, närmare ett riktigt projekt.

Lösningsförslag finns i [losningar.md](losningar.md). Försök själv först!

💡 **Tips:** Har du kört fast? Lösningarna innehåller en migration som bygger
hela schemat med testdata. Lägg den i `pb_migrations/`, starta om servern och
fortsätt därifrån.

| Övning | Innehåll | Nivå | Kapitel |
|--------|----------|------|---------|
| 1 | Installera och skapa alla collections i Dashboard | 1 | 1–3 |
| 2 | Testdata och relationer | 1 | 3 |
| 3 | API-regler | 2 | 4 |
| 4 | CRUD med curl | 1–2 | 5 |
| 5 | Filter, sortering och expand | 2 | 3, 5 |
| 6 | Hook: stoppa dubbelbokningar | 2–3 | 7 |
| 7 | View-collection: statistik | 2 | 2, 7 |
| 8 | Många-till-många: taggar och anmälningar | 3 | 3, 4, 7 |
| 9 | Flera föreningar | 3 | 8 |
| 10 | Behörighetsmatris | 3 | 8 |
| 11 | Notiser och anslagslista | 3 | 8 |
| 12 | Bonus: Dart-program | 2 | 6 |

---

## Övning 1 – Installera och bygg datamodellen (Nivå 1)

**Mål:** Alla fem collections finns, med rätt fält och index.

1. Ladda ner PocketBase, packa upp i en ny mapp `foreningen-pb` och kör
   `./pocketbase --version`.
2. Starta med `./pocketbase serve` och skapa en superuser (via länken i
   terminalen eller `./pocketbase superuser upsert ...`).
3. Logga in på <http://127.0.0.1:8090/_/>.
4. Skapa `apartments` (Base):

   | Fält | Typ | Inställningar |
   |------|-----|---------------|
   | `number` | Plain text | Nonempty, max 10 |
   | `floor` | Number | No decimals, min -2, max 30 |
   | `size_sqm` | Number | min 0 |

   Lägg till ett **unikt index** på `number`.

5. Skapa `resources` (Base) enligt steg-för-steg-instruktionen i
   [kapitel 2](02-collections-och-falt.md#steg-för-steg-skapa-resources-i-dashboard).
6. Öppna `users` (kugghjulet) och lägg till:

   | Fält | Typ | Inställningar |
   |------|-----|---------------|
   | `apartment` | Relation → apartments | Single, *inte* cascade delete |
   | `role` | Select | Värden: `member`, `styrelse`, `admin`. Single |

7. Skapa `bookings` (Base) enligt
   [kapitel 3](03-relationer.md#steg-för-steg-lägg-till-bookings-i-dashboard).
8. Skapa `posts` (Base):

   | Fält | Typ | Inställningar |
   |------|-----|---------------|
   | `title` | Plain text | Nonempty, max 200 |
   | `body` | Rich editor | – |
   | `author` | Relation → users | Single, Nonempty, *inte* cascade delete |
   | `published` | Bool | *inte* Nonempty |

   (`created` och `updated` läggs till automatiskt.)

9. Stoppa servern och öppna databasen:

   ```bash
   sqlite3 pb_data/data.db ".tables"
   sqlite3 pb_data/data.db ".schema bookings"
   ```

**Frågor att besvara:**

a) Vilken SQL-typ fick `bookings.start`? Och `resources.active`?
b) Finns det någon `FOREIGN KEY` i `bookings`? Varför/varför inte?
c) Titta i mappen `pb_migrations/`. Hur många filer finns där, och varför?

---

## Övning 2 – Testdata och relationer (Nivå 1)

**Mål:** Det finns data att testa med, och du förstår hur relationer ser ut.

1. Skapa i Dashboard (eller hoppa till lösningens testdata-migration):

   - 4 lägenheter: `1001` (vån 1, 54,5 kvm), `1002` (vån 1, 72), `2001`
     (vån 2, 88), `3001` (vån 3, 61).
   - 4 användare, alla med lösenordet `hemligt123`:

     | Namn | E-post | Roll | Lägenhet |
     |------|--------|------|----------|
     | Anna Andersson | anna@example.com | member | 1001 |
     | Bo Berg | bo@example.com | styrelse | 1002 |
     | Cecilia Ek | cecilia@example.com | member | 2001 |
     | David Dahl | david@example.com | admin | 3001 |

   - 4 resurser: Tvättstuga 1 (3 h, aktiv), Tvättstuga 2 (3 h, aktiv),
     Festlokalen (12 h, aktiv), Bastun (2 h, **inaktiv**).
   - Minst 5 bokningar fördelade på olika användare och resurser.
   - 3 anslag skrivna av Bo, varav ett **opublicerat**.

2. Kryssa i **Presentable** på `resources.name`, `users.name` och
   `apartments.number`. Hur ändras listan med bokningar i Dashboard?
3. Försök ta bort Bo. Vad händer, och varför? (Tips: `posts.author`.)
4. Ta bort *Tvättstuga 2*. Vad händer med bokningarna av den? Varför?

---

## Övning 3 – API-regler (Nivå 2)

**Mål:** Föreningsappens data är skyddad.

1. Skriv in reglerna från [kapitel 4](04-autentisering-och-api-regler.md#regler-för-föreningsappen)
   för alla fem collections. Skriv dem **själv** utifrån kraven nedan innan
   du tittar:

   | Collection | Krav |
   |------------|------|
   | `apartments` | Inloggade läser. Bara `admin` skriver. |
   | `resources` | Inloggade läser. Bara `admin` skriver. |
   | `bookings` | Man ser sina egna; styrelse/admin ser alla. Man bokar bara i eget namn, bara aktiva resurser. Man ändrar bara egna och får inte byta `user`. Man tar bort egna; admin tar bort alla. |
   | `posts` | Inloggade ser publicerade + sina egna utkast. Styrelse/admin skapar i eget namn. Författaren ändrar (får inte byta författare). Författare eller admin tar bort. |
   | `users` | Inloggade ser varandra. Ingen självregistrering. Man ändrar bara sin egen profil men aldrig `role` eller `apartment`. |

2. Fyll i tabellen genom att **gissa först** och sedan testa med curl
   (övning 4 visar hur). Skriv HTTP-status och vad som hände.

   | # | Som | Försök | Gissning | Resultat |
   |---|-----|--------|----------|----------|
   | 1 | utloggad | Lista `resources` | | |
   | 2 | Anna | Lista `bookings` | | |
   | 3 | Bo (styrelse) | Lista `bookings` | | |
   | 4 | Anna | Boka Tvättstuga 1 i eget namn | | |
   | 5 | Anna | Boka i Cecilias namn | | |
   | 6 | Anna | Boka Bastun | | |
   | 7 | Anna | Ändra `note` på egen bokning | | |
   | 8 | Anna | Ändra `user` på egen bokning till Cecilia | | |
   | 9 | Anna | Ta bort Cecilias bokning | | |
   | 10 | Anna | Skapa ett anslag | | |
   | 11 | Anna | Lista `posts` – syns utkastet? | | |
   | 12 | Anna | Sätta sin egen `role` till `admin` | | |
   | 13 | Anna | Ändra sitt eget `name` | | |

3. **Fundera:** Varför svarar PocketBase `404` (och inte `403`) i vissa fall?

---

## Övning 4 – CRUD med curl (Nivå 1–2)

1. Logga in som Anna och spara token i `$TOKEN` (se
   [kapitel 5](05-rest-api-och-filter.md#förberedelse-spara-en-token-i-en-variabel)).
2. Lista alla resurser.
3. Hämta en resurs med id.
4. Skapa en bokning för Anna i Tvättstuga 1 i morgon 08:00–10:00 (UTC).
   Spara id:t från svaret.
5. Ändra bokningens `note` till `"Glöm inte tvättmedel"`.
6. Ta bort bokningen. Vilken statuskod får du?
7. Försök skapa en bokning **utan** `start`. Vad står det i `data` i svaret?
8. (Nivå 2) Logga in som David (admin) och skapa en ny resurs "Cykelrummet".
   Försök göra samma sak som Anna. Jämför svaren.

---

## Övning 5 – Filter, sortering och expand (Nivå 2)

Skriv **query-parametrarna** (filter/sort/expand/fields) för varje fråga och
testa med curl. Kör som **superuser** eller Bo (styrelse) så att du ser alla
bokningar, om inget annat anges.

1. Alla aktiva resurser, sorterade på namn.
2. Lägenheter på våning 1 eller 2 som är större än 60 kvm.
3. Alla bokningar av Festlokalen, senaste först.
4. Alla bokningar i november 2026, med resursens namn och bokarens namn
   (expand).
5. Bokningar som har en anteckning (`note` är inte tom).
6. Bokningar som är längre än 2 timmar. *(Tips: gick det? Varför/varför inte?
   Vad skulle du göra i stället?)*
7. Bokningar gjorda av någon som bor på våning 1. Använd punkt-notation.
8. Alla resurser **med** sina bokningar (back-relation), men bara fälten
   `name` och bokningarnas `start`.
9. Användare som har skrivit minst ett publicerat anslag.
10. Den andra sidan med bokningar när `perPage` är 2. Hur många sidor finns?
11. Publicerade anslag, nyaste först, med bara de första 50 tecknen av
    brödtexten.
12. Som Anna: "mina kommande bokningar" (start efter nu), med resursen
    expanderad. (Tänk på varningen om `@request` i filter!)

---

## Övning 6 – Hook: stoppa dubbelbokningar (Nivå 2–3)

**Mål:** Servern vägrar bokningar som krockar, är för långa eller har
sluttid före starttid.

1. Skapa mappen `pb_hooks/` och filerna `bookings.pb.js` och
   `booking_utils.js` (se [kapitel 7](07-hooks-och-migrationer.md#exempel-2-ingen-dubbelbokning-och-max_hours)).
   Försök skriva koden själv utifrån kraven:
   - Sluttid måste vara efter starttid.
   - Resursen måste vara aktiv.
   - Längden får inte överstiga resursens `max_hours`.
   - Ingen annan bokning av **samma resurs** får överlappa.
2. Testa med curl:

   | Test | Förväntat |
   |------|-----------|
   | 08:00–10:00 | OK |
   | 09:00–11:00 samma dag och resurs | `400 Tiden är redan bokad.` |
   | 10:00–11:00 (börjar när den första slutar) | OK |
   | 09:00–11:00 men **annan** resurs | OK |
   | 08:00–15:00 i tvättstugan (max 3 h) | `400 Max 3 timmar per bokning.` |
   | 12:00–11:00 | `400 Sluttiden måste vara efter starttiden.` |
   | Ändra en befintlig bokning (PATCH `note`) | OK – krockar inte med sig själv |

3. Skapa en krockande bokning **i Dashboard** som superuser. Stoppas den?
   Varför är det bra?
4. (Nivå 3) Lägg till regeln "en medlem får ha högst 2 **kommande**
   bokningar av tvättstugor". Superusers ska inte begränsas. Fundera över
   vilken hook som passar bäst.
5. (Nivå 3) Två personer trycker "Boka" exakt samtidigt för samma tid. Läs
   om isolering i [ACID-kapitlet](../01-databaser/03-acid-och-transaktioner.md).
   Kan båda bokningarna slinka igenom? Vad skulle du kunna göra åt det?

---

## Övning 7 – View-collection: statistik (Nivå 2)

1. Skapa en view-collection `resource_stats` (+ New collection → **View**)
   som visar för varje resurs: `id`, `name`, antal bokningar
   (`bookings_count`) och senaste bokningens start (`last_booking`).
   Resurser utan bokningar ska också synas (med 0).
2. Sätt List/View-regeln så att alla inloggade får läsa.
3. Hämta viewn sorterad på flest bokningar först.
4. **Fundera:** Anna får bara se sina egna bokningar enligt reglerna på
   `bookings`. Men vad räknar `bookings_count`? Är det ett problem? När skulle
   det vara det?
5. (Nivå 3) Gör en till view, `apartment_booking_hours`, som visar antal
   bokade **timmar** per lägenhet. Tips: SQLite har `julianday()`;
   skillnaden mellan två `julianday` är i dygn.

---

## Övning 8 – Många-till-många (Nivå 3)

**Del A: Taggar på anslag (multi-relation)**

1. Skapa `tags` (fält `name`, unikt index) och lägg till fältet `tags` på
   `posts` (Relation → tags, **Multiple**, max 5).
2. Skapa taggarna `tvätt`, `fest`, `renovering`, `styrelsen`.
3. Ge anslagen några taggar. Lägg till en tagg med `tags+` och ta bort en
   med `tags-` via curl.
4. Hitta alla anslag med taggen `fest`. Vad blir skillnaden om du använder
   `=` i stället för `?=`?
5. Hämta alla taggar med sina anslag (back-relation).
6. Skärp create-regeln på `posts` så att ett anslag får ha **högst 3**
   taggar när det skapas.

**Del B: Anmälan till aktiviteter (kopplings-collection)**

7. Skapa `events` (`title`, `date`, `max_attendees`) och
   `event_attendees` (`event`, `user`, `status` select `yes`/`maybe`) med ett
   **unikt index** på `(event, user)`.
8. Skriv regler: alla inloggade ser aktiviteter och anmälningar; bara
   styrelse/admin skapar aktiviteter; man anmäler bara sig själv och bara
   till framtida aktiviteter; man får ändra status men inte byta event eller
   user; man avanmäler bara sig själv.
9. Skriv en hook som säger `400 Aktiviteten är fullbokad.` när antalet
   `yes` har nått `max_attendees` (0 = obegränsat).
10. Hämta en aktivitet med alla anmälda och deras namn i ett anrop.
11. **Jämför:** Varför är en multi-relation `events.attendees` sämre här än
    `event_attendees`? Ge minst två skäl.

---

## Övning 9 – Flera föreningar (Nivå 3)

Läs [kapitel 8](08-flera-foreningar-och-behorigheter.md).

1. Lägg till `associations` och fältet `association` enligt kapitlet (eller
   använd migrationen i lösningarna). Skapa två föreningar, *Eken* och
   *Björken*, och flytta in befintliga användare/resurser i Eken.
2. Skapa en användare *Cecilia* i Björken och en resurs "Tvättstuga 1" i
   Björken. Varför går det nu, men inte innan du ändrade de unika indexen?
3. Skriv hooken som stämplar `association` på `apartments`, `resources`,
   `bookings` och `posts`.
4. Uppdatera reglerna och kör hela checklistan
   [Testa att föreningarna verkligen hålls isär](08-flera-foreningar-och-behorigheter.md#testa-att-föreningarna-verkligen-hålls-isär)
   med curl. Alla rader ska ge förväntat resultat.
5. Hitta själv ett sätt att läcka data mellan föreningarna som checklistan
   inte täcker – och täpp till det.

---

## Övning 10 – Behörighetsmatris (Nivå 3)

1. Skapa `pb_hooks/utils/permissions.js` med `can(...)` och
   `enforce(e, area, operation)` och koppla in den för `posts`.
2. Organisera hooks med `main.pb.js` + `collections/`, `cron/`, `utils/`.
3. Ge Björken en matris där `member` får `create` på `posts`. Verifiera att
   Cecilia kan skapa anslag men inte Anna.
4. Utöka matrisen med området `resources` och låt `enforce` gälla även där.
   Låt styrelsen i Eken få skapa resurser.
5. Skriv en route `GET /api/foreningen/my-permissions` som returnerar den
   inloggades tillåtna operationer per område – så att appen kan dölja
   knappar. Kräv inloggning.

---

## Övning 11 – Notiser och anslagslista (Nivå 3)

1. Skapa `notifications` och `post_comments` enligt kapitel 8. Kontrollera att
   en medlem **inte** kan skapa notiser och bara kan ändra `read`.
2. Skriv hooken som skapar notiser till alla i föreningen (utom författaren)
   när ett anslag publiceras – både vid create och när ett utkast publiceras
   senare.
3. Skapa `posts_view` med `comments_count`. Kontrollera att utkast och andra
   föreningars anslag **inte** syns.
4. Lägg till en cron som varje dag kl. 16:00 UTC skapar en påminnelse om
   morgondagens bokningar, och en superuser-route för att testa den direkt.
5. (Bonus) Ändra notishooken så att den bara skickar till medlemmar som har
   ett nytt bool-fält `users.notify_posts = true`.

---

## Övning 12 – Bonus: Dart-program (Nivå 2)

Kräver Dart (installeras i modul 03).

1. Skapa ett Dart-projekt: `dart create -t console foreningen_cli` och
   `dart pub add pocketbase`.
2. Skriv modellklasserna `Resource` och `Booking` med `fromRecord`.
3. Programmet ska: logga in som Anna, lista aktiva resurser, försöka boka
   Tvättstuga 1 i morgon 08–10, skriva ut felmeddelandet om det misslyckas,
   och lista Annas kommande bokningar med resursnamn.
4. Lägg till en realtidsprenumeration på `bookings` som skriver ut varje
   händelse. Skapa en bokning i Dashboard och se den dyka upp.

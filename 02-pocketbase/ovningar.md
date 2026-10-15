# Övningar – Modul 02: PocketBase

Övningarna bygger på varandra. Gör dem i ordning i **samma** projektmapp,
t.ex. `kvittra-pb`. Börja med en **ny, tom** mapp och en tom `pb_data` – inte
den PocketBase-installation du använde i modul 01, där schemat redan finns.

Allt görs i PocketBase: i Dashboard, med `curl` mot REST-API:t, med
JavaScript i `pb_hooks/` och med migrationer i `pb_migrations/`.

Svårighetsgrad:

- **Nivå 1** – följ stegen, nästan allt står i texten.
- **Nivå 2** – du behöver kombinera saker från kapitlen själv.
- **Nivå 3** – fria uppgifter, närmare ett riktigt projekt.

Lösningsförslag finns i [losningar.md](losningar.md). Försök själv först!

💡 **Tips:** Har du kört fast? Lösningarna innehåller en migration som bygger
hela schemat med testdata. Lägg den i `pb_migrations/`, starta om servern och
fortsätt därifrån.

| Övning | Innehåll | Nivå | Kapitel |
|--------|----------|------|---------|
| 1 | Installera och bygg datamodellen i Dashboard | 1 | 1–3 |
| 2 | Testdata och relationer | 1 | 3 |
| 3 | API-regler: gissa först, testa sedan | 2 | 4 |
| 4 | CRUD med curl | 1–2 | 5 |
| 5 | Filter, sortering, expand och flödet | 2 | 3, 5 |
| 6 | Hooks: användarnamn, egna inlägg och spamskydd | 2–3 | 7 |
| 7 | View-collection: statistik per användare | 2 | 2, 7 |
| 8 | Många-till-många: taggar, gillningar och följningar | 3 | 3, 4, 7 |
| 9 | Grupper och synlighet | 3 | 8 |
| 10 | Roller och `enforce` | 3 | 8 |
| 11 | Notiser och flödet med räknare | 3 | 8 |
| 12 | Bonus: Dart-program | 2 | 6 |

---

## Övning 1 – Installera och bygg datamodellen (Nivå 1)

**Mål:** Alla fem collections finns, med rätt fält och index.

1. Ladda ner PocketBase från <https://pocketbase.io/docs/>, packa upp i en ny
   mapp `kvittra-pb` och kör `./pocketbase --version`.
2. Starta med `./pocketbase serve` och skapa en superuser (via
   installationslänken eller `./pocketbase superuser upsert ...`).
3. Logga in på <http://127.0.0.1:8090/_/>.
4. Utöka `users` med `username`, `bio` och `website` och ett unikt index på
   `username` enligt
   [kapitel 2](02-collections-och-falt.md#steg-för-steg-utöka-users-i-dashboard).
   Lägg till `username` som identitetsfält under *Options*.
5. Skapa `posts` och `comments` enligt
   [kapitel 3](03-relationer.md#steg-för-steg-lägg-till-posts-och-comments-i-dashboard).
6. Skapa `likes` och `follows` med unika index enligt
   [kapitel 3](03-relationer.md#steg-för-steg-likes-och-follows).
7. Skapa view-collectionen `db_tables` från
   [kapitel 1](01-vad-ar-pocketbase.md#se-sqlen--utan-att-lämna-pocketbase)
   och öppna raderna för `posts` och `likes`.
8. Skapa en view-collection till, `db_indexes`, med frågan
   `SELECT name AS id, tbl_name, sql FROM sqlite_master WHERE type = 'index' AND sql IS NOT NULL`.

**Frågor att besvara:**

a) Vilken SQL-typ fick `posts.created`? Och `users.emailVisibility`?
b) Finns det någon `FOREIGN KEY` i `likes`? Varför/varför inte?
c) Var syns det unika indexet på `likes (post, user)`?
d) Titta i mappen `pb_migrations/`. Hur många filer finns där, och varför?

---

## Övning 2 – Testdata och relationer (Nivå 1)

**Mål:** Det finns data att testa med, och du förstår hur relationer ser ut.

1. Skapa i Dashboard (eller hoppa till lösningens testdata-migration):

   - 4 användare, alla med lösenordet `hemligt123` och `verified` ikryssat:

     | username | Namn | E-post | bio |
     |----------|------|--------|-----|
     | `anna` | Anna Andersson | anna@example.com | Kaffe, kod och katter. |
     | `bo` | Bo Berg | bo@example.com | Springer mest. |
     | `cecilia` | Cecilia Ek | cecilia@example.com | Bakar bröd på helgerna. |
     | `david` | David Dahl | david@example.com | |

   - 6 inlägg:

     | Författare | Titel |
     |------------|-------|
     | bo | Bästa kaffet i stan? |
     | bo | Tips på löparrundor |
     | anna | Mitt första inlägg |
     | cecilia | Surdegsbröd |
     | cecilia | Kaffe eller te? |
     | david | Hej Kvittra! |

   - Kommentarer: Anna och Cecilia på "Bästa kaffet i stan?", Bo på "Mitt
     första inlägg", Anna och David på "Surdegsbröd".
   - Gillningar: Anna, Cecilia och David gillar "Bästa kaffet i stan?", Bo
     gillar "Mitt första inlägg", Anna och Bo gillar "Surdegsbröd".
   - Följningar: Anna följer Bo och Cecilia, Bo följer Anna, Cecilia följer
     Bo, David följer Anna.

2. Kryssa i **Presentable** på `users.username` och `posts.title`. Hur ändras
   listorna med kommentarer och gillningar i Dashboard?
3. Försök ta bort Bo. Vad händer, och varför? (Tips: `posts.author`.)
4. Skapa ett testinlägg, lägg en kommentar och en gillning på det och ta
   sedan bort inlägget. Vad händer med kommentaren och gillningen? Varför?
5. Försök skapa samma gillning två gånger. Försök sedan skapa en följning där
   Anna följer Anna. Gick det? Varför – och vad säger det om var den regeln
   måste ligga?

---

## Övning 3 – API-regler (Nivå 2)

**Mål:** Kvittras data är skyddad.

1. Skriv in reglerna från [kapitel 4](04-autentisering-och-api-regler.md#regler-för-kvittra)
   för alla fem collections. Skriv dem **själv** utifrån kraven nedan innan
   du tittar:

   | Collection | Krav |
   |------------|------|
   | `users` | Inloggade ser varandra. Vem som helst får registrera sig. Man ändrar bara sin egen profil. Ingen tar bort konton via API:t. |
   | `posts` | Inloggade ser alla inlägg. Man skriver bara i eget namn. Författaren ändrar (får inte byta författare) och tar bort. |
   | `comments` | Inloggade ser alla. Man kommenterar i eget namn. Man ändrar bara texten i sina egna kommentarer. Kommentarens eller inläggets författare tar bort. |
   | `likes` | Inloggade ser alla. Man gillar bara i eget namn och tar bara bort sin egen gillning. Gillningar ändras aldrig. |
   | `follows` | Inloggade ser alla. Man följer bara i eget namn och aldrig sig själv. Man slutar bara följa i eget namn. Följningar ändras aldrig. |

2. Fyll i tabellen genom att **gissa först** och sedan testa med curl
   (övning 4 visar hur). Skriv HTTP-status och vad som hände.

   | # | Som | Försök | Gissning | Resultat |
   |---|-----|--------|----------|----------|
   | 1 | utloggad | Lista `posts` | | |
   | 2 | utloggad | Registrera kontot `erik` | | |
   | 3 | utloggad | Registrera ett konto med `"verified": true` | | |
   | 4 | Anna | Lista `posts` | | |
   | 5 | Anna | Skapa ett inlägg i eget namn | | |
   | 6 | Anna | Skapa ett inlägg i Bos namn | | |
   | 7 | Anna | Ändra titeln på sitt eget inlägg | | |
   | 8 | Anna | Byta `author` på sitt eget inlägg till Bo | | |
   | 9 | Anna | Ändra titeln på Bos inlägg | | |
   | 10 | Anna | Gilla "Bästa kaffet i stan?" (som hon redan gillat) | | |
   | 11 | Anna | Gilla ett inlägg i Cecilias namn | | |
   | 12 | Anna | Ta bort Bos gillning | | |
   | 13 | Anna | Ändra en gillning (PATCH) | | |
   | 14 | Anna | Följa sig själv | | |
   | 15 | Anna | Ta bort Bos kommentar under sitt eget inlägg | | |
   | 16 | Anna | Flytta sin kommentar till ett annat inlägg | | |
   | 17 | Anna | Ändra Bos `name` | | |
   | 18 | Anna | Lista `users` – ser hon Bos e-post? | | |

3. **Fundera:** Varför svarar PocketBase `404` (och inte `403`) i vissa fall?

---

## Övning 4 – CRUD med curl (Nivå 1–2)

1. Logga in som Anna och spara token i `$TOKEN` och hennes id i `$ME` (se
   [kapitel 5](05-rest-api-och-filter.md#förberedelse-spara-en-token-i-en-variabel)).
2. Lista alla inlägg.
3. Hämta ett inlägg med id.
4. Skapa ett inlägg "Fikadags" med en valfri text. Spara id:t från svaret.
5. Ändra inläggets `body`.
6. Ta bort inlägget. Vilken statuskod får du?
7. Försök skapa ett inlägg **utan** `title`. Vad står det i `data` i svaret?
8. Gilla Davids inlägg "Hej Kvittra!", och ta sedan bort gillningen igen.
9. Följ David.
10. (Nivå 2) Registrera en ny användare med curl och logga in med
    **användarnamnet** i stället för e-posten.

---

## Övning 5 – Filter, sortering, expand och flödet (Nivå 2)

Skriv **query-parametrarna** (filter/sort/expand/fields) för varje fråga och
testa med curl som Anna. Där det står "Annas id" skickar du id:t som ett värde.

1. Alla inlägg, nyaste först.
2. Inlägg som nämner "kaffe" i titeln eller texten.
3. Bos inlägg. Använd punkt-notation på `author`.
4. Alla inlägg med författarens namn och alla kommentarer med *kommentarernas*
   författare – i ett anrop. Ta bara med fälten `title`, författarens `name`,
   kommentarernas `body` och deras författares `username`.
5. Kommentarerna till "Bästa kaffet i stan?", äldst först, med författaren.
6. Inlägg med minst 2 gillningar. *(Tips: gick det? Varför/varför inte? Vad
   skulle du göra i stället?)*
7. Inlägg som Anna har gillat.
8. Inlägg som Anna **inte** har gillat.
9. Annas flöde: inlägg från dem hon följer, nyast först, med författaren.
   Vad händer om du byter `?=` mot `=`?
10. Användare som Anna följer. Sedan: Annas följare.
11. Bos ömsesidiga följare (följer Bo och följs av Bo).
12. Inlägg utan kommentarer.
13. Den andra sidan med inlägg när `perPage` är 2. Hur många sidor finns?
14. Inlägg från idag, nyast först, med bara de första 50 tecknen av texten.
15. "Mina inlägg" för Anna. (Tänk på varningen om `@request` i filter!)

---

## Övning 6 – Hooks (Nivå 2–3)

**Mål:** Servern normaliserar användarnamn, stoppar gillningar av egna inlägg
och skyddar mot spam.

1. Skapa mappen `pb_hooks/` och filerna från
   [kapitel 7](07-hooks-och-migrationer.md#exempel-2-användarnamn--normalisera-och-validera):
   `utils/constants.js`, `utils/user_rules.js`, `users.pb.js`, `likes.pb.js`
   och `posts.pb.js`. Försök skriva koden själv utifrån kraven:
   - Användarnamn sparas utan mellanslag runt och med små bokstäver.
   - Användarnamnen `admin`, `kvittra`, `support`, `api` och `root` är
     reserverade.
   - Man får inte gilla sitt eget inlägg.
   - Högst 3 inlägg per minut och användare (superusers undantagna).
2. Testa med curl:

   | Test | Förväntat |
   |------|-----------|
   | Registrera `"  Fia_F "` | OK, sparas som `fia_f` |
   | Registrera `"Admin"` | `400 Användarnamnet "admin" är reserverat.` |
   | Registrera `"BO"` | `400`, `validation_not_unique` på `username` |
   | Bo gillar sitt eget inlägg | `400 Du kan inte gilla ditt eget inlägg.` |
   | Anna gillar Bos inlägg "Tips på löparrundor" | OK |
   | Anna skapar 4 inlägg inom en minut | Det fjärde ger `429 Du skriver för snabbt. Vänta en minut.` |

3. Skapa en gillning där Bo gillar sitt eget inlägg **i Dashboard** som
   superuser. Stoppas den? Varför är det bra? Stoppas en superuser av
   spamskyddet? Varför är det rimligt?
4. Lägg till routen `POST /api/kvittra/delete-account` från kapitel 7. Logga
   in som David och anropa den. Kontrollera efteråt: (a) Davids gillningar och
   följningar är borta, (b) hans inlägg finns kvar under "Borttagen
   användare", (c) hans gamla token ger `401`.
5. (Nivå 3) Kommentarer får inte innehålla något av orden i en lista
   `BANNED_WORDS` i `constants.js` (skiftlägesokänsligt). Vilken hook passar,
   och ska regeln gälla superusers?
6. (Nivå 3) Två anrop från Anna kommer *exakt* samtidigt när hon redan har
   skrivit 2 inlägg den senaste minuten. Läs om isolering i
   [ACID-kapitlet](../01-databaser/03-acid-och-transaktioner.md). Kan båda
   slinka igenom spamskyddet? Spelar det någon roll här?

---

## Övning 7 – View-collection: statistik (Nivå 2)

1. Skapa en view-collection `user_stats` (+ New collection → **View**) som
   visar för varje användare: `id`, `username`, antal inlägg (`posts_count`),
   antal följare (`followers_count`) och antal hen följer (`following_count`).
   Användare utan inlägg eller följare ska också synas (med 0).
   *(Tips: vad händer med siffrorna om du gör tre `LEFT JOIN` och `COUNT`?)*
2. Sätt List/View-regeln så att alla inloggade får läsa.
3. Hämta viewn sorterad på flest följare först.
4. **Fundera:** Vem kan se `followers_count`? Vad räknar viewn som Anna inte
   kan se på annat sätt? Är det ett problem här? När skulle det vara det?
   (Tänk på privata grupper i kapitel 8.)
5. (Nivå 3) Gör en till view, `popular_authors`, som visar hur många
   gillningar varje användare har **fått** totalt på sina inlägg.

---

## Övning 8 – Många-till-många (Nivå 3)

**Del A: Taggar på inlägg (multi-relation)**

1. Skapa `tags` (fält `name`, unikt index) och lägg till fältet `tags` på
   `posts` (Relation → tags, **Multiple**, max 5).
2. Skapa taggarna `kaffe`, `löpning`, `bakning`, `fika`.
3. Ge inläggen några taggar. Lägg till en tagg med `tags+` och ta bort en
   med `tags-` via curl.
4. Hitta alla inlägg med taggen `kaffe`. Vad blir skillnaden om du använder
   `=` i stället för `?=`?
5. Hämta alla taggar med sina inlägg (back-relation).
6. Skärp create-regeln på `posts` så att ett inlägg får ha **högst 3**
   taggar när det skapas.

**Del B: Gillningar och följningar (kopplings-collections)**

7. Hämta "Bästa kaffet i stan?" med **användarnamnen** på alla som gillat det,
   i ett anrop.
8. Bygg "Förslag på personer att följa" för David: användare som de David
   följer i sin tur följer – men som David inte redan följer, och inte David
   själv. Ett enda filter på `users`. Vad blir svaret för Anna, och varför?
9. **Jämför:** Varför vore en multi-relation `posts.liked_by` sämre än
   `likes`? Och varför vore en multi-relation `users.following` sämre än
   `follows`? Ge minst två skäl var.

---

## Övning 9 – Grupper och synlighet (Nivå 3)

Läs [kapitel 8](08-grupper-och-behorigheter.md).

1. Lägg till `groups`, `group_members`, `posts.group` och `notifications`
   enligt kapitlet (i Dashboard eller med migrationen i lösningarna).
2. Skriv hooken som stämplar `owner` på nya grupper och gör ägaren till
   `admin`, och hooken som alltid sätter `role = "member"` när någon går med
   via API:t.
3. Som Bo: skapa den **privata** gruppen Löparklubben och lägg till Anna och
   David. Skriv inlägget "Intervaller på torsdag" i gruppen. Som Cecilia:
   skapa den **publika** gruppen Surdegsbagare.
4. Uppdatera reglerna och kör hela checklistan
   [Testa att synligheten och rollerna håller](08-grupper-och-behorigheter.md#testa-att-synligheten-och-rollerna-håller)
   med curl. Alla rader ska ge förväntat resultat.
5. Ändra tillfälligt list-regeln på `posts` till de två felaktiga varianterna
   i kapitlets varningstabell. Vem ser vad? Återställ sedan regeln.
6. Hitta själv ett sätt att läcka privata gruppinlägg som checklistan
   inte täcker – och täpp till det.

---

## Övning 10 – Roller och `enforce` (Nivå 3)

1. Skapa `pb_hooks/utils/group_permissions.js` med `roleInGroup`, `can` och
   `enforce(e, groupId, operation)` och koppla in den för att ta bort inlägg,
   kommentarer och medlemmar.
2. Organisera hooks med `main.pb.js` + `collections/`, `api/`, `cron/`,
   `utils/`.
3. Gör Anna till `moderator` i Löparklubben. Verifiera att hon kan ta bort
   Davids kommentar men inte lägga till Cecilia.
4. Låt varje grupp kunna ha **egna** rättigheter i ett json-fält
   `groups.permissions` (samma form som `ROLE_PERMISSIONS`). Saknas fältet
   gäller standardtabellen. Ge Surdegsbagare en tabell där moderatorer också
   får `edit_group`.
5. Skriv en route `GET /api/kvittra/groups/{id}/my-permissions` som returnerar
   den inloggades roll och tillåtna operationer i gruppen – så att appen kan
   dölja knappar. Kräv inloggning.

---

## Övning 11 – Notiser och flödet med räknare (Nivå 3)

1. Skriv hooks som skapar en notis till inläggets författare när någon gillar
   eller kommenterar inlägget (men inte när man gillar/kommenterar sitt eget).
   Kontrollera att en användare **inte** kan skapa notiser och bara kan ändra
   `read`.
2. Skapa `posts_view` med `likes_count` och `comments_count`. Kontrollera att
   "Bästa kaffet i stan?" får 3 och 2 – och att privata gruppinlägg **inte**
   syns för Cecilia.
3. Hämta flödet med de mest gillade inläggen först.
4. Lägg till veckosammanfattningen (cron måndagar 07:00 UTC) och en
   superuser-route för att testa den direkt.
5. Rätta `/api/kvittra/stats` så att den inte läcker titlar från privata
   grupper.
6. (Bonus) Lägg till ett bool-fält `users.notify_likes`. Notiser om
   gillningar skickas bara till den som har det påslaget. Vilken regel på
   `users` behöver du *inte* ändra, och varför?

---

## Övning 12 – Bonus: Dart-program (Nivå 2)

Kräver Dart (installeras i modul 03).

1. Skapa ett Dart-projekt: `dart create -t console kvittra_cli` och
   `dart pub add pocketbase`.
2. Skriv modellklasserna `AppUser`, `Post` och `Comment` med `fromRecord`.
3. Programmet ska: logga in som Anna, skriva ut hennes flöde med
   författarnamn, gilla det översta inlägget (och skriva ut ett vettigt
   meddelande om hon redan gillat det), och skriva ut hur många inlägg hon
   gillat.
4. Lägg till en realtidsprenumeration på `comments` för ett inlägg (med
   `filter`) som skriver ut varje ny kommentar. Skapa en kommentar på det
   inlägget och en på ett annat i Dashboard – vilken dyker upp?

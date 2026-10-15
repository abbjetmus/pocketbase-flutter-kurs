# Övningar – Modul 03 Flutter

Övningarna är indelade i tre nivåer:

- **Nivå 1**: grundläggande. Alla bör göra dessa.
- **Nivå 2**: kombinerar flera kapitel.
- **Nivå 3**: utmaning. Närmar sig en riktig app.

Försök själv innan du tittar i [lösningarna](losningar.md). Det är okej att titta
tillbaka i kapitlen, och att läsa felmeddelanden noga är en del av övningen.

Skapa gärna ett projekt för övningarna:

```bash
flutter create kvittra_ovningar
cd kvittra_ovningar
```

Dart-övningarna (1.1–1.3) kan du köra i <https://dartpad.dev> eller som
`dart run bin/ovning.dart`.

---

## Nivå 1

### Övning 1.1 – Inlägg och användare (Dart)

Här är data i samma format som JSONPlaceholder:

```dart
final usersJson = <Map<String, dynamic>>[
  {'id': 1, 'name': 'Anna Lind', 'username': 'anna', 'email': 'anna@example.com'},
  {'id': 2, 'name': 'Bo Ek', 'username': 'bo', 'email': 'bo@example.com'},
  {'id': 3, 'name': 'Cecilia Holm', 'username': 'cissi', 'email': 'cecilia@example.com'},
];

final postsJson = <Map<String, dynamic>>[
  {'userId': 1, 'id': 1, 'title': 'Första fikat på nya kontoret', 'body': 'Kanelbullar till alla som kommer före nio'},
  {'userId': 2, 'id': 2, 'title': 'Cykla i regn', 'body': 'Tre veckor i rad nu och regnbyxorna är fortfarande underskattade'},
  {'userId': 1, 'id': 3, 'title': 'Tips: Flutter DevTools', 'body': 'Widget Inspector visar constraints'},
  {'userId': 3, 'id': 4, 'title': 'Söker löparsällskap', 'body': 'Fem kilometer runt sjön på lördag'},
  {'userId': 1, 'id': 5, 'title': 'Hej Kvittra', 'body': 'Mitt första inlägg'},
];
```

1. Skapa klasserna `User` (`id`, `name`, `username`, `email`) och `Post` (`id`,
   `userId`, `title`, `body`). Alla fält ska vara `final`, och båda ska ha en
   `factory ...fromJson(Map<String, dynamic> json)`.
2. Lägg till en getter `handle` på `User` som returnerar t.ex. `"@anna"`, och en
   getter `wordCount` på `Post` som räknar orden i `body`.
3. I `main`: gör om JSON-listorna till objekt och skriv ut
   - titlarna på alla inlägg av användare 1,
   - hur många inlägg varje användare har skrivit, som en `Map<int, int>`
     (t.ex. med `fold`),
   - inlägget med flest ord,
   - varje inlägg som `"Anna Lind (@anna): Första fikat på nya kontoret"`. Tips:
     bygg en `Map<int, User>` först, så att du kan slå upp författaren via `userId`.

### Övning 1.2 – Null safety

Rätta följande kod så att den kompilerar **utan** att använda `!`:

```dart
class User {
  User({required this.name, this.website});
  final String name;
  final String? website;
}

String profileLink(User user) {
  return '${user.name} – https://${user.website.toLowerCase()}';
}

void main() {
  print(profileLink(User(name: 'Anna', website: 'Anna.Example.com')));
  print(profileLink(User(name: 'Bo')));
}
```

Om webbplats saknas ska det stå `"Bo – ingen webbplats"`.

### Övning 1.3 – Flödesfilter, switch och records

1. Skapa en enhanced enum `FeedFilter` med värdena `all`, `following` och `mine`,
   och en svensk etikett för varje ("Alla", "Följer", "Mina").
2. Skriv en funktion med ett `switch`-*uttryck* som ger texten som visas när
   flödet är tomt:

   ```dart
   String emptyMessage(FeedFilter filter) => switch (filter) { ... };
   ```

   Till exempel "Inga inlägg ännu", "Du följer ingen än – hitta någon att följa!"
   och "Du har inte skrivit något än". Testa att ta bort ett av fallen. Vilket fel
   får du?
3. Skriv en funktion `(int likes, int comments) summera(List<(int, int)> inlagg)`
   som summerar gillningar och kommentarer för en lista av inlägg. Anropa den med
   `[(12, 3), (4, 0), (7, 2)]` och destrukturera resultatet i `main`.

### Övning 1.4 – Layout från skiss

Bygg följande profilskärm med `Scaffold`, `Card`, `Row`, `Column`, `Expanded`,
`CircleAvatar`, `Icon` och `Text`. Använd `ColorScheme.fromSeed` med valfri färg.

```
┌────────────────────────────────────────┐
│ @anna                              ⚙   │ ← AppBar med actions
├────────────────────────────────────────┤
│                 (AL)                   │ ← CircleAvatar med initialer
│              Anna Lind                 │ ← titleLarge
│    Utvecklare i Malmö. Gillar fika.    │ ← bodyMedium, dämpad färg
│                                        │
│     12          128          87        │ ← tre lika breda kolumner
│   Inlägg      Följare      Följer      │   (Expanded)
│                                        │
│ Inlägg                                 │ ← titleMedium
│ ┌────────────────────────────────────┐ │
│ │ (AL) Anna Lind · @anna · 5 min     │ │ ← liten avatar + en rad text
│ │ Första fikat på nya kontoret       │ │ ← titel
│ │ Kanelbullar till alla som kommer   │ │ ← text, max två rader med …
│ │ före nio! Ta med egen mugg, vi ... │ │
│ │ ♡ 12   💬 3                        │ │ ← ikoner med siffror
│ └────────────────────────────────────┘ │
│ ┌────────────────────────────────────┐ │
│ │ (AL) Anna Lind · @anna · 2 d       │ │
│ │ Tips: Flutter DevTools             │ │
│ │ Widget Inspector visar ...         │ │
│ │ ♡ 4    💬 0                        │ │
│ └────────────────────────────────────┘ │
└────────────────────────────────────────┘
```

Krav:

- Skärmen ska gå att scrolla om den inte får plats (testa i liggande läge).
- Långa inläggstexter ska kortas med `…` (max två rader).
- Initialerna ska räknas ut med en funktion `initials('Anna Lind')`, inte skrivas
  för hand.
- Inga hårdkodade färger: använd `Theme.of(context)`.

---

## Nivå 2

### Övning 2.1 – Gilla-knapp med state

1. Bygg en `StatefulWidget` `LikeButton(initialCount:, initiallyLiked:)` som visar
   ett hjärta och en siffra. Ett tryck växlar mellan gillad (fyllt rött hjärta,
   siffran + 1) och inte gillad (tomt hjärta, siffran − 1). Siffran får aldrig bli
   negativ.
2. Visa tre inlägg i en lista med var sin `LikeButton`.
3. Lägg till texten "Du gillar X inlägg" i `AppBar`. Märker du att det inte går så
   länge varje knapp har sitt eget state? **Lyft upp state**: gör `LikeButton`
   stateless (`liked`, `count`, `onPressed`) och låt skärmen äga en `List<Post>`
   som uppdateras med `copyWith`.
4. Fundera: vad hade hänt med de *stateful* knapparna från steg 1 om ett nytt
   inlägg lades in överst i listan och du inte använde keys?

### Övning 2.2 – Nytt inlägg med validering

Bygg ett formulär för nya inlägg och en enkel flödesskärm som tar emot resultatet.

1. Formuläret ska ha:
   - ett `TextFormField` för **titel** (obligatorisk, 3–80 tecken),
   - ett `TextFormField` för **text** (obligatorisk, max 280 tecken) med en
     räknare som visar "X tecken kvar" och blir röd när färre än 20 återstår,
   - en `DropdownButtonFormField` för **vem som får se inlägget** (Alla, Mina
     följare, Bara jag). Inget ska vara förvalt, och man måste välja,
   - en `SwitchListTile` "Publicera senare". När den är på visas en datumknapp
     (`showDatePicker`, från idag och högst 7 dagar fram).
2. Om "Publicera senare" är på men inget datum är valt: visa ett rött
   felmeddelande under datumknappen (inte en `SnackBar`).
3. När allt är giltigt: stäng formuläret med `Navigator.pop` och skicka tillbaka
   ett `PostDraft`.
4. Flödesskärmen öppnar formuläret från en `FloatingActionButton`, lägger in det
   nya inlägget **överst** och visar en `SnackBar`: `"Publicerat: <titel>"` eller
   `"Schemalagt till 2026-03-14"`.

Kom ihåg att `dispose`:a dina controllers!

### Övning 2.3 – Flöde → inlägg → profil

Bygg navigationen i Kvittra med `go_router` och lokal, hårdkodad data (några
användare, inlägg och kommentarer).

1. Sökvägar: `/` (flödet), `/posts/:id` (ett inlägg) och `/users/:id` (en profil).
2. Flödet listar inläggen med författarens namn. Tryck → `/posts/:id`.
3. Inläggsskärmen visar författaren (tryck → `/users/:id`), titel och text, och en
   knapp "Visa kommentarer (n)" som öppnar kommentarerna i en **bottom sheet**.
4. Profilskärmen visar namn, `@användarnamn`, bio och användarens inlägg. Tryck på
   ett inlägg → `/posts/:id`.
5. Använd `context.push` så att man kan backa hela vägen till flödet.
6. Ett id som inte finns eller inte är ett tal (`/posts/999`, `/users/abc`) ska ge
   en "Hittades inte"-skärm, inte en krasch.
7. Testa en djuplänk: sätt `initialLocation: '/posts/3'`. Finns det en tillbakapil?
   Varför?

---

## Nivå 3

### Övning 3.1 – Flödet från JSONPlaceholder

Bygg Kvittras flöde med riktig data från <https://jsonplaceholder.typicode.com>.

1. Modellklasserna `Post`, `Comment` och `User` (med valfria `Address` och
   `Company`) med `fromJson` i `lib/models/`.
2. En klass `JsonPlaceholderApi` i `lib/data/` med åtminstone `fetchPosts`,
   `fetchUsers` och `fetchAllComments` (`GET /comments`). Statuskoder utanför
   200-serien och nätverksfel ska ge ett eget undantag med en begriplig text.
3. En funktion `loadFeed` som hämtar inlägg, användare och kommentarer
   **parallellt** och kopplar ihop dem på klienten till en lista av
   `FeedItem(post, author, commentCount)`. `commentCount` räknar du fram genom att
   gruppera de 500 kommentarerna efter `postId`.
4. En `FeedScreen` som visar **laddar**, **fel** (med "Försök igen") och **data**
   (med särskild text när listan är tom). Använd en `sealed class LoadState`.
   Varje inlägg visar författarens namn och `@användarnamn`, titel, två rader text
   och antalet kommentarer.
5. Dra för att uppdatera (`RefreshIndicator`).

### Övning 3.2 – Inlägg, profil och nytt inlägg

Bygg vidare på 3.1:

1. Tryck på ett inlägg → `PostDetailScreen(postId:)` som hämtar inlägget och dess
   kommentarer (`/posts/{id}` och `/comments?postId={id}`) parallellt, och sedan
   författaren (`/users/{userId}`). Visa inlägget och kommentarerna under.
2. Tryck på en författare → `ProfileScreen(userId:)` som hämtar användaren och
   hens inlägg (`/users/{id}` och `/users/{id}/posts`). Visa namn, `@användarnamn`,
   webbplats, stad, företag och antal inlägg, och inläggen under.
3. En `FloatingActionButton` i flödet öppnar ett formulär för nytt inlägg (titel
   obligatorisk, text obligatorisk). Spara med `POST /posts` (som användare 1).
   Visa en `CircularProgressIndicator` i knappen medan anropet pågår, och
   inaktivera knappen så att man inte kan skicka två gånger.
4. Vid lyckat resultat: stäng formuläret, returnera det nya inlägget och lägg in
   det **först** i flödet utan att hämta om allt. Visa en `SnackBar` med id:t.
5. Vid fel: visa felmeddelandet i en `SnackBar` och låt formuläret vara kvar.
6. Svara på frågorna: Vilket id får ditt nya inlägg? Vad händer med det när du drar
   för att uppdatera? Vad händer om du skapar två inlägg och använder
   `ValueKey(post.id)` i listan?

### Övning 3.3 – Tester

Skriv:

1. enhetstester för `User.fromJson` (med och utan `address`/`company`),
2. enhetstester för `JsonPlaceholderApi` med `MockClient`: att `fetchPosts` anropar
   `/posts`, att en 500-status ger ditt eget undantag och att `createPost` godtar
   `201`,
3. ett test för `loadFeed` med en `MockClient` som svarar olika beroende på
   `request.url.path`, och som kontrollerar att `commentCount` blir rätt och att
   inlägg utan känd författare hoppas över,
4. ett widgettest för formuläret i 3.2 som kontrollerar att felmeddelandet visas
   när titeln är tom, och att inget nätverksanrop görs då.

### Reflektion (inför modul 04)

Gå igenom din kod från nivå 2 och 3 och räkna:

- hur många `StatefulWidget`-klasser du har (två klasser vardera),
- hur många `dispose`-metoder du har skrivit, och om du har glömt någon,
- hur många gånger du skrev `if (!mounted) return;` eller `context.mounted`,
- hur många gånger du skrev `setState(() {})` eller `setState(() => _state = const Loading())`
  bara för att "tvinga fram" en ombyggnad,
- hur många gånger du upprepade mönstret "`LoadState`-fält + `initState` som anropar
  `_load` + `try`/`catch` + `mounted`".

Spara siffrorna. I [modul 04](../04-flutter-compositions/README.md) skriver du om
en av skärmarna med `flutter_compositions` och jämför.

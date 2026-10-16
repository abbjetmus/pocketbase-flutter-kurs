# 6. Hämta data från PocketBase

Hittills har alla inlägg varit påhittade och skrivna direkt i koden. Nu hämtar
vi de riktiga inläggen från **din egen PocketBase**, den Kvittra du byggde i
modul 01.

```
  Appen i Chrome                          PocketBase
┌────────────────┐   "ge mig posts"     ┌──────────────────────┐
│                │ ───────────────────► │ http://127.0.0.1:8090│
│   Kvittra      │                      │                      │
│                │ ◄─────────────────── │ users, posts, ...    │
└────────────────┘   inläggen som JSON  └──────────────────────┘
```

## Starta PocketBase

Öppna mappen `kvittra-pb` från modul 01, öppna en terminal där och skriv:

```powershell
.\pocketbase.exe serve
```

Gå till <http://127.0.0.1:8090/_/> och kontrollera att `posts` har de sex
inläggen från modul 01. Låt terminalen vara öppen medan du kör appen.

## Paketet pocketbase

PocketBase har ett eget paket för Dart. Det sköter allt prat med servern åt
dig. Öppna terminalen i VS Code (i projektet `kvittra`) och skriv:

```powershell
flutter pub add pocketbase
```

Skapa sedan en fil med **en** anslutning som hela appen använder:

```dart
// lib/data/pocketbase.dart
import 'package:pocketbase/pocketbase.dart';

final pb = PocketBase('http://127.0.0.1:8090');
```

⚠️ **Android-emulator?** Där betyder `127.0.0.1` emulatorn själv, inte din
dator. Använd `http://10.0.2.2:8090` i stället. I Chrome fungerar `127.0.0.1`.

## Logga in först

I modul 01 (kapitel 8) satte du API-regler. För `posts` gäller:

| Regel | Villkor | Betyder |
|-------|---------|---------|
| List/Search | `@request.auth.id != ""` | Bara inloggade får se inlägg |
| View | `@request.auth.id != ""` | |

Appen måste alltså **logga in** innan den får hämta inlägg. Vi loggar in som
Anna, med lösenordet från modul 01:

```dart
// lib/data/pocketbase.dart (lägg till)
Future<void> loginAsAnna() async {
  if (pb.authStore.isValid) return; // redan inloggad
  await pb.collection('users').authWithPassword('anna@example.com', 'kvittra123');
}
```

- `pb.collection('users')` betyder "collectionen `users`".
- `authWithPassword` loggar in. Sedan skickar paketet med inloggningen i alla
  frågor, så att API-reglerna släpper igenom dig.
- `pb.authStore.isValid` är sant när någon är inloggad.

💡 Ett lösenord skrivet direkt i koden är bara okej när man övar. I modul 03
bygger vi en riktig inloggningssida.

⚠️ Du *kan* i stället sätta List-regeln för `posts` till tom. Men då får hela
internet läsa inläggen. Logga hellre in.

## Hur ser ett inlägg ut?

Så här ser ett inlägg ut när PocketBase skickar det. Med `expand: 'author'`
följer hela författaren med:

```json
{
  "id": "k3j2h1g4f5d6s7a",
  "author": "a1b2c3d4e5f6g7h",
  "title": "Höstpromenad",
  "body": "Löven har börjat gulna i parken.",
  "created": "2026-09-01 10:15:00.000Z",
  "expand": {
    "author": { "id": "a1b2c3d4e5f6g7h", "username": "anna", "name": "Anna Andersson" }
  }
}
```

- `author` är bara ett **id**. Det är relationen från modul 01.
- Användarnamnet finns i `expand.author.username`.

Paketet ger dig varje inlägg som en `RecordModel`. Vi lägger till en
konstruktor i `Post` som gör om en sådan till en `Post`, ungefär som
`fromJson` i kapitel 2:

```dart
// lib/models/post.dart (lägg till import överst och konstruktorn i klassen)
import 'package:pocketbase/pocketbase.dart';

  factory Post.fromRecord(RecordModel record) {
    return Post(
      id: record.id,
      author: record.get<String>('expand.author.username', '?'),
      title: record.get<String>('title'),
      body: record.get<String>('body'),
    );
  }
```

| Kod | Betyder |
|-----|---------|
| `record.id` | Inläggets id |
| `record.get<String>('title')` | Läs fältet `title` som en `String` |
| `record.get<String>('expand.author.username', '?')` | Läs inuti `expand` med punkter. Saknas värdet blir det `'?'` |

## Hämta inläggen

```dart
// lib/data/pocketbase.dart (lägg till)
import '../models/post.dart'; // överst i filen

Future<List<Post>> fetchPosts() async {
  try {
    await loginAsAnna();
    final result = await pb.collection('posts').getList(
      page: 1,
      perPage: 20,
      sort: '-created', // nyaste först
      expand: 'author', // ta med författaren
    );

    final posts = <Post>[];
    for (final record in result.items) {
      posts.add(Post.fromRecord(record));
    }
    return posts;
  } on ClientException catch (e) {
    throw Exception(errorMessage(e));
  }
}
```

| Parameter | Betyder |
|-----------|---------|
| `page: 1, perPage: 20` | Hämta de första 20 inläggen |
| `sort: '-created'` | Sortera på `created`. `-` betyder nyaste först |
| `expand: 'author'` | Ta med hela användaren som `author` pekar på |
| `result.items` | Listan med inlägg i svaret |

### När något går fel

Om något går fel kastar paketet ett **`ClientException`**. Med `try` och
`on ClientException catch (e)` fångar vi felet och gör om det till en text som
användaren förstår. `e.statusCode` säger vad som hände:

```dart
// lib/data/pocketbase.dart (lägg till)
String errorMessage(ClientException e) {
  if (e.statusCode == 0) return 'Kunde inte nå PocketBase. Är den igång?';
  if (e.statusCode == 400) return 'Inloggningen misslyckades. Stämmer e-post och lösenord?';
  if (e.statusCode == 403) return 'Du får inte se det här. Kontrollera API-reglerna.';
  return 'Något gick fel (${e.statusCode})';
}
```

| `statusCode` | Betyder |
|--------------|---------|
| `0` | Fick inget svar alls. PocketBase är troligen inte igång |
| `400` | Något var fel i frågan, här: fel e-post eller lösenord |
| `403` | API-regeln säger nej |
| `404` | Det du frågade efter finns inte |

## FutureBuilder: laddar, fel eller data

`fetchPosts()` ger en `Future`, alltså ett svar som kommer senare. Medan vi
väntar ska användaren se att något händer. Och går det fel ska hen få veta det.

| Läge | Visa |
|------|------|
| **Laddar** | En snurra, `CircularProgressIndicator` |
| **Fel** | Ett felmeddelande och en knapp **Försök igen** |
| **Data** | Listan med inlägg |

Widgeten **FutureBuilder** håller koll på läget åt dig. Byt ut innehållet i
`lib/screens/feed_screen.dart`:

```dart
// lib/screens/feed_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/pocketbase.dart';
import '../models/post.dart';
import '../widgets/post_card.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  // Starta hämtningen EN gång, när skärmen skapas
  Future<List<Post>> _future = fetchPosts();

  void _retry() {
    setState(() {
      _future = fetchPosts(); // hämta igen
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kvittra')),
      body: FutureBuilder<List<Post>>(
        future: _future,
        builder: (context, snapshot) {
          // Läge 1: laddar
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Läge 2: fel
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${snapshot.error}'),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _retry, child: const Text('Försök igen')),
                ],
              ),
            );
          }

          // Läge 3: data
          final posts = snapshot.data ?? [];
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return PostCard(
                post: post,
                onTap: () => context.push('/posts/${post.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
```

- `snapshot` berättar hur det går: `connectionState`, `hasError`, `error` och
  `data`.
- `mainAxisSize: MainAxisSize.min` gör att `Column` bara blir så hög som sitt
  innehåll, så att den hamnar mitt på skärmen.
- `_retry` startar en ny hämtning. `setState` gör att `FutureBuilder` får den
  nya `Future`:n och visar snurran igen.

Gör en hot restart. Först syns snurran en kort stund, sedan inläggen från din
PocketBase, med det nyaste först.

⚠️ **Skapa inte Future:n i `build`.** Skriver du `future: fetchPosts()` direkt
i `FutureBuilder` hämtas allt igen varje gång `build` körs. Spara den i en
variabel, som `_future` ovan.

💡 Står det `@?` i stället för ett användarnamn? Då kom `expand` inte med.
Kontrollera att View-regeln för `users` släpper in inloggade
(`@request.auth.id != ""`).

## Vad hände med resten av appen?

| Det du ser | Varför |
|------------|--------|
| Knappen för nytt inlägg är borta | Att spara nya inlägg i PocketBase gör vi i modul 03 |
| Trycker du på ett inlägg står det "Inlägget finns inte" | `PostDetailScreen` letar fortfarande i `samplePosts`. Det fixar du i övning 6.3 |
| Gillningarna visar 0 | `sampleLikes` har påhittade id:n. Riktiga likes kommer i modul 03 |

## Nästa steg

I [modul 03](../03-flutter-compositions/README.md) bygger vi vidare på det här.
Där gör vi en riktig inloggningssida, skapar och tar bort inlägg, och ser nya
inlägg dyka upp direkt.

## Sammanfattning

| Du vill … | Använd |
|-----------|--------|
| Ansluta till PocketBase | `PocketBase('http://127.0.0.1:8090')` |
| Logga in | `pb.collection('users').authWithPassword(epost, lösenord)` |
| Hämta en lista | `pb.collection('posts').getList(...)` |
| Ta med en relation | `expand: 'author'` |
| Läsa ett fält | `record.get<String>('title')` |
| Fånga fel | `on ClientException catch (e)` |
| Visa laddar, fel och data | `FutureBuilder` |

## Övningar

**6.1** Öppna <http://127.0.0.1:8090/api/collections/posts/records> i Chrome.
Vad ser du? Varför syns inga inlägg, fast appen kan visa dem? (Jämför med
övning 8.1 i modul 01.)

**6.2** Stoppa PocketBase med `Ctrl + C` i terminalen och gör en hot restart av
appen. Vilket felmeddelande visas? Starta PocketBase igen och tryck på
**Försök igen**.

**6.3** Skriv en funktion `fetchPost(String id)` i `pocketbase.dart` som hämtar
ett inlägg med `pb.collection('posts').getOne(id, expand: 'author')`. Gör om
`PostDetailScreen` till en `StatefulWidget` som visar inlägget med en
`FutureBuilder`. Ledtråd: skapa Future:n i `initState`, eftersom du behöver
`widget.postId`.

**6.4** Visa inläggets kommentarer under inlägget i `PostDetailScreen`, i
stället för `CommentSection`. Ge `Comment` från övning 2.6 en
`factory Comment.fromRecord`, och skriv `fetchComments(String postId)`. Ledtråd:

```dart
pb.collection('comments').getList(
  filter: pb.filter('post = {:id}', {'id': postId}), // bara det här inläggets
  sort: 'created',
  expand: 'author',
)
```

**6.5 Utmaning.** Gör en `UsersScreen` på adressen `/users` som visar alla
användare i Kvittra, med `name` som rubrik och `@username` som undertext.
Ledtråd: `pb.collection('users').getFullList(sort: 'username')` ger en lista
med alla.

Lösningar finns i [losningar.md](losningar.md#kapitel-6--hämta-data-från-pocketbase).

Nästa modul: [03 – Flutter Compositions](../03-flutter-compositions/README.md)

# 8. Hämta data från PocketBase

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
.\pocketbase serve
```

Gå till <http://127.0.0.1:8090/_/> och kontrollera att `posts` har de sex
inläggen från modul 01. Låt terminalen vara öppen medan du kör appen.

## Paketet pocketbase

PocketBase har ett eget paket för Dart. Det sköter allt prat med servern åt
dig. Stoppa appen och skriv i terminalen i projektet `kvittra`:

```powershell
flutter pub add pocketbase
```

Starta sedan appen igen med `F5`.

Skapa sedan en fil med **en** anslutning som hela appen använder:

```dart
// lib/data/pocketbase.dart
import 'package:pocketbase/pocketbase.dart';

final pb = PocketBase('http://127.0.0.1:8090');
```

💡 `127.0.0.1` betyder *din egen dator*. Både appen och PocketBase körs på din
dator, så appen hittar PocketBase på den adressen.

## Öppna databasen

I modul 01 (kapitel 9) satte du API-regler, så att bara den som är inloggad får
läsa och skriva. I Flutter-modulen hoppar vi över inloggningen. Därför öppnar vi
databasen, så att appen får läsa och skriva utan att logga in.

Gör så här för **alla fem** collections: `users`, `posts`, `comments`, `likes`
och `follows`.

1. Öppna kugghjulet på collectionen och välj fliken **API Rules**.
2. Lås upp alla fem regler: **List/Search**, **View**, **Create**, **Update**
   och **Delete**.
3. Töm textfältet i varje regel.
4. Klicka **Save changes**.

En tom regel betyder att **alla** får göra det.

⚠️ En öppen databas är bara okej på din egen dator när du övar. I en riktig app
loggar man in och använder regler, som i modul 01.

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
  if (e.statusCode == 403) return 'Du får inte se det här. Kontrollera API-reglerna.';
  return 'Något gick fel (${e.statusCode})';
}
```

| `statusCode` | Betyder |
|--------------|---------|
| `0` | Fick inget svar alls. PocketBase är troligen inte igång |
| `400` | Något var fel i frågan |
| `403` | API-regeln säger nej |
| `404` | Det du frågade efter finns inte |

## useAsyncData: laddar, fel eller data

`fetchPosts()` ger en `Future`, alltså ett svar som kommer senare. Medan vi
väntar ska användaren se att något händer. Och går det fel ska hen få veta det.

| Läge | Visa |
|------|------|
| **Laddar** | En snurra, `CircularProgressIndicator` |
| **Fel** | Ett felmeddelande och en knapp **Försök igen** |
| **Data** | Listan med inlägg |

`useAsyncData` håller koll på läget åt dig. Du får tillbaka två saker: ett
**`AsyncValue`** med läget, och en funktion `refresh` som hämtar igen.

```dart
final (status, refresh) = useAsyncData<List<Post>, void>((_) => fetchPosts());
```

`<List<Post>, void>` betyder att du får tillbaka en `List<Post>`. Vad `void`
betyder tar vi i kapitel 10.

Ett `AsyncValue` är alltid i ett av fyra lägen:

| Läge | Betyder |
|------|---------|
| `AsyncIdle` | Har inte börjat än |
| `AsyncLoading` | Väntar på svar |
| `AsyncData` | Klart. Datan finns i `value` |
| `AsyncError` | Något gick fel. Felet finns i `errorValue` |

Du väljer vad som ska visas med en `switch`. Byt ut innehållet i
`lib/screens/feed_screen.dart`:

```dart
// lib/screens/feed_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';

import '../data/pocketbase.dart';
import '../models/post.dart';
import '../widgets/post_card.dart';

class FeedScreen extends CompositionWidget {
  const FeedScreen({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final (status, refresh) = useAsyncData<List<Post>, void>((_) => fetchPosts());

    return (context) => Scaffold(
          appBar: AppBar(title: const Text('Kvittra')),
          body: switch (status.value) {
            // Läge 1: laddar
            AsyncIdle() || AsyncLoading() =>
              const Center(child: CircularProgressIndicator()),

            // Läge 2: fel
            AsyncError(:final errorValue) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$errorValue'),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: refresh, child: const Text('Försök igen')),
                  ],
                ),
              ),

            // Läge 3: data
            AsyncData(:final value) => ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: value.length,
                itemBuilder: (context, index) {
                  final post = value[index];
                  return PostCard(
                    key: ValueKey(post.id),
                    post: post,
                    onTap: () => context.push('/posts/${post.id}'),
                  );
                },
              ),
          },
        );
  }
}
```

- `AsyncData(:final value)` betyder: "om det är `AsyncData`, ge mig `value`".
  Glömmer du ett läge varnar Dart.
- `mainAxisSize: MainAxisSize.min` gör att `Column` bara blir så hög som sitt
  innehåll, så att den hamnar mitt på skärmen.
- `refresh` hämtar igen och visar snurran under tiden.

Gör en hot restart. Först syns snurran en kort stund, sedan inläggen från din
PocketBase, med det nyaste först.

💡 Står det `@?` i stället för ett användarnamn? Då kom `expand` inte med.
Kontrollera att View-regeln för `users` är upplåst och tom.

### useFuture: hämta en gång

Behöver du aldrig hämta igen är `useFuture` ännu enklare. Den ger bara ett
`AsyncValue`:

```dart
final post = useFuture(() => fetchPost('abc123'));
```

Du visar det med samma `switch`. `post.value.dataOrNull` ger datan, eller `null`
om den inte har kommit än.

## Vad hände med resten av appen?

| Det du ser | Varför |
|------------|--------|
| Knappen för nytt inlägg är borta | Att spara nya inlägg i PocketBase gör vi i kapitel 9 och 11 |
| Trycker du på ett inlägg står det "Inlägget finns inte" | `PostDetailScreen` letar fortfarande i `samplePosts`. Det fixar du i övning 8.3 |
| Gillningarna visar 0 | `sampleLikes` har påhittade id:n. Riktiga likes kommer i kapitel 11 |

## Sammanfattning

| Du vill … | Använd |
|-----------|--------|
| Ansluta till PocketBase | `PocketBase('http://127.0.0.1:8090')` |
| Hämta en lista | `pb.collection('posts').getList(...)` |
| Ta med en relation | `expand: 'author'` |
| Läsa ett fält | `record.get<String>('title')` |
| Fånga fel | `on ClientException catch (e)` |
| Visa laddar, fel och data | `useAsyncData` och en `switch` på `AsyncValue` |
| Hämta en gång | `useFuture` |

## Övningar

**8.1** Öppna <http://127.0.0.1:8090/api/collections/posts/records> i Chrome.
Ser du samma inlägg som i appen? Varför syns de, fast du inte är inloggad?

**8.2** Stoppa PocketBase med `Ctrl + C` i terminalen och gör en hot restart av
appen. Vilket felmeddelande visas? Starta PocketBase igen och tryck på
**Försök igen**.

**8.3** Skriv en funktion `fetchPost(String id)` i `pocketbase.dart` som hämtar
ett inlägg med `pb.collection('posts').getOne(id, expand: 'author')`. Ändra
`PostDetailScreen` så att den visar inlägget med `useFuture`. Ledtråd:
`useFuture(() => fetchPost(props.raw.postId))`. `.raw` läser värdet en gång,
utan att bevaka det.

**8.4** Visa inläggets kommentarer under inlägget i `PostDetailScreen`, i
stället för `CommentSection`. Ge `Comment` från övning 2.6 en
`factory Comment.fromRecord`, och skriv `fetchComments(String postId)`. Ledtråd:

```dart
pb.collection('comments').getList(
  filter: pb.filter('post = {:id}', {'id': postId}), // bara det här inläggets
  sort: 'created',
  expand: 'author',
)
```

**8.5 Utmaning.** Gör en `UsersScreen` på adressen `/users` som visar alla
användare i Kvittra, med `name` som rubrik och `@username` som undertext.
Ledtråd: `pb.collection('users').getFullList(sort: 'username')` ger en lista
med alla.

Lösningar finns i [losningar.md](losningar.md#kapitel-8--hämta-data-från-pocketbase).

Nästa kapitel: [Skriva data och realtid](09-skriva-data-och-realtid.md)

# 05 – Async och nätverk

Hittills har all data i våra exempel varit hårdkodad. En riktig föreningsapp hämtar
resurser, bokningar och anslag från en server, i vårt fall **PocketBase** från
modul 02. Nätverksanrop tar tid och kan misslyckas, och användaren ska varken se en
frusen skärm eller en krasch.

I det här kapitlet lär du dig:

- hur `Future` och `async` fungerar i UI-kod,
- `FutureBuilder` och `StreamBuilder`,
- att alltid hantera tre tillstånd: **laddar**, **fel** och **data**,
- att hämta och skicka JSON med `http`-paketet,
- att använda `pocketbase`-paketet,
- hur man strukturerar ett projekt med modeller, tjänster och skärmar.

## Async i UI: frys aldrig skärmen

Flutter ritar skärmen ungefär 60–120 gånger per sekund på **en** tråd. Om din kod
blockerar den tråden fryser appen. Därför är allt som tar tid asynkront:

```dart
Future<void> _load() async {
  setState(() => _loading = true);
  final posts = await api.fetchPosts(); // UI:t fortsätter ritas under väntan
  if (!mounted) return;
  setState(() {
    _posts = posts;
    _loading = false;
  });
}
```

`await` blockerar **inte** tråden. Funktionen pausas, och resten av appen
fortsätter tills svaret kommer.

### Tre tillstånd: laddar, fel, data

Varje gång du hämtar något finns det minst tre lägen som ska visas på olika sätt:

| Läge | Vad användaren bör se |
|------|----------------------|
| Laddar | En `CircularProgressIndicator` eller skelett-rader |
| Fel | Ett begripligt felmeddelande och en "Försök igen"-knapp |
| Data | Listan, och ett särskilt meddelande om den är tom |

Kommer du ihåg `sealed class` från kapitel 01? Den passar perfekt här:

```dart
sealed class LoadState<T> {
  const LoadState();
}

class Loading<T> extends LoadState<T> {
  const Loading();
}

class Loaded<T> extends LoadState<T> {
  const Loaded(this.data);
  final T data;
}

class Failed<T> extends LoadState<T> {
  const Failed(this.error);
  final Object error;
}
```

Då kan `build` använda ett `switch`-uttryck, och Dart klagar om du glömmer ett läge:

```dart
@override
Widget build(BuildContext context) {
  return switch (_state) {
    Loading() => const Center(child: CircularProgressIndicator()),
    Failed(:final error) => ErrorView(message: '$error', onRetry: _load),
    Loaded(:final data) when data.isEmpty => const Center(child: Text('Inga anslag')),
    Loaded(:final data) => PostList(posts: data),
  };
}
```

## FutureBuilder

`FutureBuilder` är en inbyggd widget som lyssnar på en `Future` och bygger om
sig själv när den blir klar. Du får en `AsyncSnapshot` med tillståndet:

```dart
class ResourceListScreen extends StatefulWidget {
  const ResourceListScreen({super.key});

  @override
  State<ResourceListScreen> createState() => _ResourceListScreenState();
}

class _ResourceListScreenState extends State<ResourceListScreen> {
  late Future<List<Resource>> _future;

  @override
  void initState() {
    super.initState();
    _future = ResourceService().fetchResources(); // skapa Future EN gång
  }

  void _retry() {
    setState(() => _future = ResourceService().fetchResources());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resurser')),
      body: FutureBuilder<List<Resource>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Kunde inte hämta resurser:\n${snapshot.error}',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _retry, child: const Text('Försök igen')),
                ],
              ),
            );
          }
          final resources = snapshot.data!;
          if (resources.isEmpty) {
            return const Center(child: Text('Inga resurser'));
          }
          return ListView.builder(
            itemCount: resources.length,
            itemBuilder: (context, i) => ListTile(title: Text(resources[i].name)),
          );
        },
      ),
    );
  }
}
```

⚠️ **Varning:** Skapa **inte** din `Future` direkt i `build`:

```dart
FutureBuilder(
  future: ResourceService().fetchResources(), // FEL: nytt anrop vid VARJE build!
  builder: ...
)
```

`build` kan köras många gånger (tangentbord som öppnas, skärmen som vrids, en
förälder som bygger om). Varje gång startas ett nytt nätverksanrop, och listan
blinkar till laddningsläge. Skapa den i `initState` och spara den i en variabel.
Det här är ännu en av de saker du måste hålla koll på själv i vanlig Flutter.

## StreamBuilder

`StreamBuilder` fungerar som `FutureBuilder` men för en `Stream`, alltså flera
värden över tid. Den bygger om varje gång ett nytt värde kommer.

```dart
class ClockText extends StatefulWidget {
  const ClockText({super.key});

  @override
  State<ClockText> createState() => _ClockTextState();
}

class _ClockTextState extends State<ClockText> {
  // Skapa strömmen en gång, av samma skäl som med Future
  final Stream<DateTime> _ticks = Stream.periodic(
    const Duration(seconds: 1),
    (_) => DateTime.now(),
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime>(
      stream: _ticks,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Text('--:--:--');
        final t = snapshot.data!;
        String two(int n) => n.toString().padLeft(2, '0');
        return Text('${two(t.hour)}:${two(t.minute)}:${two(t.second)}');
      },
    );
  }
}
```

`StreamBuilder` sköter själv prenumerationen och avslutar den när widgeten
försvinner. Lyssnar du på en ström med `.listen` själv måste du spara
`StreamSubscription` och anropa `cancel()` i `dispose`.

## HTTP och JSON

Lägg till paketet:

```bash
flutter pub add http
```

⚠️ **Varning:** På **Android** måste appen ha tillstånd att använda internet. Lägg
till `<uses-permission android:name="android.permission.INTERNET"/>` i
`android/app/src/main/AndroidManifest.xml` (i debug-läge finns det redan). På
**macOS** behöver du lägga till `com.apple.security.network.client` i
`macos/Runner/DebugProfile.entitlements` och `Release.entitlements`.

### Modellklass med fromJson

PocketBase returnerar anslag som JSON:

```json
{
  "id": "k3j2h1g4f5d6s7a",
  "collectionName": "posts",
  "title": "Vattenavstängning tisdag",
  "body": "Vattnet stängs av 08–12 i hus B.",
  "author": "u1a2b3c4d5e6f7g",
  "published": true,
  "created": "2026-03-10 09:15:00.000Z",
  "updated": "2026-03-10 09:15:00.000Z"
}
```

Motsvarande Dart-klass:

```dart
// lib/models/post.dart
class Post {
  const Post({
    required this.id,
    required this.title,
    required this.body,
    required this.authorId,
    required this.published,
    required this.created,
  });

  final String id;
  final String title;
  final String body;
  final String authorId;
  final bool published;
  final DateTime created;

  factory Post.fromJson(Map<String, dynamic> json) => Post(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        authorId: json['author'] as String? ?? '',
        published: json['published'] as bool? ?? false,
        // PocketBase använder mellanslag i stället för 'T', men DateTime.parse klarar båda
        created: DateTime.parse(json['created'] as String),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'body': body,
        'author': authorId,
        'published': published,
      };
}
```

### GET

```dart
// lib/services/post_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/post.dart';

class ApiException implements Exception {
  ApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;

  @override
  String toString() => statusCode == null ? message : '$message ($statusCode)';
}

class PostService {
  PostService({http.Client? client, this.baseUrl = 'http://127.0.0.1:8090'})
      : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  Future<List<Post>> fetchPosts() async {
    final uri = Uri.parse('$baseUrl/api/collections/posts/records').replace(
      queryParameters: {
        'filter': 'published = true',
        'sort': '-created',
        'perPage': '50',
      },
    );

    final http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 10));
    } on Exception {
      throw ApiException('Kunde inte nå servern. Kontrollera din uppkoppling.');
    }

    if (response.statusCode != 200) {
      throw ApiException('Servern svarade med ett fel', response.statusCode);
    }

    // utf8.decode på bytes ger korrekt å, ä, ö även om servern inte anger charset
    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final items = json['items'] as List<dynamic>;
    return items
        .map((item) => Post.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
```

Steg för steg:

1. Bygg en `Uri`. `replace(queryParameters: ...)` URL-kodar parametrarna åt dig
   (mellanslag, `=` m.m.).
2. `await _client.get(uri)` skickar anropet. `timeout` gör att vi inte väntar för evigt.
3. Kontrollera `statusCode`. `http` kastar **inte** fel för 404 eller 500, det
   måste du göra själv.
4. `jsonDecode` gör om texten till `Map`/`List` med `dynamic`-värden.
5. `fromJson` gör om varje map till ett typat `Post`-objekt.

⚠️ **Varning:** `127.0.0.1` betyder "den här enheten". I **Android-emulatorn** är
det emulatorn själv, inte din dator. Använd `http://10.0.2.2:8090` där. iOS-
simulatorn, Chrome och desktop kan använda `127.0.0.1`. På en riktig telefon
behöver du datorns IP-adress i nätverket och starta PocketBase med
`./pocketbase serve --http=0.0.0.0:8090`.

### POST

```dart
Future<Post> createPost({required String title, required String body, required String authorId}) async {
  final response = await _client.post(
    Uri.parse('$baseUrl/api/collections/posts/records'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'title': title,
      'body': body,
      'author': authorId,
      'published': true,
    }),
  );

  if (response.statusCode != 200) {
    // PocketBase skickar ett JSON-fel med "message" och "data" per fält
    final error = jsonDecode(response.body) as Map<String, dynamic>;
    throw ApiException(error['message'] as String? ?? 'Okänt fel', response.statusCode);
  }
  return Post.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
}
```

💡 **Tips:** Om API-reglerna för `posts` i PocketBase kräver inloggning får du
`403` eller ett tomt svar. Då måste anropet ha en `Authorization`-header med en
token. Det är krångligt att göra för hand, och det är en av anledningarna till att
använda SDK:t nedan.

### Felhantering i UI:t

Fånga fel så nära UI:t som möjligt och översätt dem till något användaren förstår:

```dart
Future<void> _load() async {
  setState(() => _state = const Loading());
  try {
    final posts = await _service.fetchPosts();
    if (!mounted) return;
    setState(() => _state = Loaded(posts));
  } catch (e) {
    if (!mounted) return;
    setState(() => _state = Failed(e));
  }
}
```

Lägg till "dra för att uppdatera" med `RefreshIndicator`. Den vill ha en funktion
som returnerar en `Future`:

```dart
RefreshIndicator(
  onRefresh: _load,
  child: ListView.builder(...),
)
```

## PocketBase-paketet

I modul 02 använde du PocketBase via dess REST-API och SDK. Det officiella
Dart-SDK:t gör allt ovan (URL:er, JSON, felhantering, inloggning, tokens,
realtid) åt dig. Läs [02-pocketbase/06-dart-sdk.md](../02-pocketbase/06-dart-sdk.md)
för detaljerna. Här är en kort introduktion i Flutter-sammanhang.

```bash
flutter pub add pocketbase
```

```dart
// lib/services/pocketbase_client.dart
import 'package:pocketbase/pocketbase.dart';

// En enda instans för hela appen
final pb = PocketBase('http://127.0.0.1:8090');
```

```dart
// lib/repositories/post_repository.dart
import 'package:pocketbase/pocketbase.dart';
import '../models/post.dart';

class PostRepository {
  PostRepository(this._pb);
  final PocketBase _pb;

  Future<List<Post>> fetchPublished() async {
    final result = await _pb.collection('posts').getList(
          page: 1,
          perPage: 50,
          filter: 'published = true',
          sort: '-created',
        );
    // Varje RecordModel kan göras om till JSON och sedan till vår modell
    return result.items.map((r) => Post.fromJson(r.toJson())).toList();
  }

  Future<Post> create({required String title, required String body}) async {
    final record = await _pb.collection('posts').create(body: {
      'title': title,
      'body': body,
      'author': _pb.authStore.record?.id,
      'published': true,
    });
    return Post.fromJson(record.toJson());
  }

  /// Realtid: anropa [onChange] varje gång ett anslag skapas/ändras/tas bort.
  /// Returnerar en funktion som avslutar prenumerationen.
  Future<UnsubscribeFunc> watch(void Function() onChange) {
    return _pb.collection('posts').subscribe('*', (e) => onChange());
  }
}
```

Inloggning:

```dart
try {
  await pb.collection('users').authWithPassword('anna@example.com', 'hemligt123');
  print('Inloggad som ${pb.authStore.record?.getStringValue('name')}');
} on ClientException catch (e) {
  // statusCode 400 = fel e-post eller lösenord
  print('Inloggningen misslyckades: ${e.response['message']}');
}
```

Efter inloggning skickar SDK:t automatiskt med token i alla anrop, så API-reglerna
från modul 02 (`@request.auth.id != ""`) fungerar.

⚠️ **Varning:** En realtidsprenumeration måste avslutas. Spara funktionen som
`subscribe` returnerar och anropa den i `dispose`:

```dart
UnsubscribeFunc? _unsubscribe;

@override
void initState() {
  super.initState();
  _load();
  _repo.watch(_load).then((unsub) => _unsubscribe = unsub);
}

@override
void dispose() {
  _unsubscribe?.call();
  super.dispose();
}
```

Ännu ett `initState`/`dispose`-par att komma ihåg. I modul 04 ser du hur
`onUnmounted` gör det tydligare.

## Projektstruktur

När appen växer blir en enda `main.dart` ohållbar. En vanlig struktur:

```
lib/
├── main.dart                 ← runApp, MaterialApp, tema, router
├── models/                   ← rena dataklasser med fromJson/toJson
│   ├── resource.dart
│   ├── booking.dart
│   └── post.dart
├── services/                 ← kommunikation utåt (pb-klient, http)
│   └── pocketbase_client.dart
├── repositories/             ← en klass per collection: hämta/spara modeller
│   ├── resource_repository.dart
│   ├── booking_repository.dart
│   └── post_repository.dart
├── screens/                  ← hela skärmar (en per route)
│   ├── resource_list_screen.dart
│   ├── booking_form_screen.dart
│   └── post_list_screen.dart
└── widgets/                  ← återanvändbara delar
    ├── resource_card.dart
    └── error_view.dart
```

Tanken är att varje lager bara känner till lagret under sig:

```
screens / widgets   →   repositories   →   services (PocketBase / http)
       ↓                     ↓
                  models (används av alla)
```

- **Skärmar** vet ingenting om URL:er eller JSON. De anropar `repo.fetchPublished()`.
- **Repositories** vet hur man pratar med PocketBase men ingenting om widgets.
- **Modeller** är rena Dart-klasser utan beroenden. De är lätta att testa.

Byter du från `http` till `pocketbase`-paketet (eller till en låtsas-implementation
i ett test) behöver bara repository-lagret ändras.

💡 **Tips:** `services/` och `repositories/` används lite olika i olika projekt.
Det viktiga är principen: **håll nätverkskod borta från widgets**.

## Helt exempel: anslagslista

```dart
// lib/screens/post_list_screen.dart
import 'package:flutter/material.dart';
import '../models/post.dart';
import '../repositories/post_repository.dart';
import '../services/pocketbase_client.dart';

class PostListScreen extends StatefulWidget {
  const PostListScreen({super.key});

  @override
  State<PostListScreen> createState() => _PostListScreenState();
}

class _PostListScreenState extends State<PostListScreen> {
  final _repo = PostRepository(pb);
  LoadState<List<Post>> _state = const Loading();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final posts = await _repo.fetchPublished();
      if (mounted) setState(() => _state = Loaded(posts));
    } catch (e) {
      if (mounted) setState(() => _state = Failed(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Anslag')),
      body: switch (_state) {
        Loading() => const Center(child: CircularProgressIndicator()),
        Failed(:final error) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Något gick fel: $error'),
                TextButton(
                  onPressed: () {
                    setState(() => _state = const Loading());
                    _load();
                  },
                  child: const Text('Försök igen'),
                ),
              ],
            ),
          ),
        Loaded(:final data) when data.isEmpty =>
          const Center(child: Text('Inga anslag ännu')),
        Loaded(:final data) => RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              itemCount: data.length,
              itemBuilder: (context, i) {
                final post = data[i];
                return ListTile(
                  title: Text(post.title),
                  subtitle: Text(post.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: Text('${post.created.day}/${post.created.month}'),
                );
              },
            ),
          ),
      },
    );
  }
}
```

(`LoadState`, `Loading`, `Loaded` och `Failed` ligger i en egen fil, t.ex.
`lib/models/load_state.dart`, och importeras.)

🧪 **Prova själv:**

1. Starta PocketBase från modul 02 med några anslag och kör `PostListScreen`.
2. Stoppa PocketBase och dra för att uppdatera. Får du ett begripligt felmeddelande?
3. Lägg till realtid med `_repo.watch(_load)` och skapa ett anslag i PocketBase
   Admin UI. Dyker det upp i appen utan att du gör något?

**Nästa kapitel:** [06 – Testning](06-testning.md)

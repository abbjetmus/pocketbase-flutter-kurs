# 05 – Async och nätverk

Hittills har all data i våra exempel varit hårdkodad. En riktig Kvittra hämtar
inlägg, kommentarer och användare från en server. Nätverksanrop tar tid och kan
misslyckas, och användaren ska varken se en frusen skärm eller en krasch.

Vi börjar med den publika test-API:n **JSONPlaceholder**, som du kan använda direkt
utan att starta någon egen server. I slutet av kapitlet gör vi samma sak mot vår
egen **PocketBase** från modul 02.

I det här kapitlet lär du dig:

- hur `Future` och `async` fungerar i UI-kod,
- `FutureBuilder` och `StreamBuilder`,
- att alltid hantera tre tillstånd: **laddar**, **fel** och **data**,
- att hämta och skicka JSON med `http`-paketet,
- att tolka nästlad JSON till Dart-klasser,
- att slå ihop data från flera anrop på klienten (inlägg + användare),
- att använda `pocketbase`-paketet,
- hur man strukturerar ett projekt med modeller, datalager och skärmar.

## JSONPlaceholder: ett låtsas-API för övning

[JSONPlaceholder](https://jsonplaceholder.typicode.com) är en gratis webbtjänst med
påhittad data i exakt den form Kvittra behöver: användare, inlägg och kommentarer.
Den kräver ingen inloggning och ingen API-nyckel.

| Anrop | Returnerar |
|-------|-----------|
| `GET /posts` | En lista med 100 inlägg |
| `GET /posts/1` | Inlägg 1 |
| `GET /posts/1/comments` | Kommentarerna till inlägg 1 (5 st) |
| `GET /comments?postId=1` | Samma kommentarer, via en query-parameter |
| `GET /users` | En lista med 10 användare |
| `GET /users/1` | Användare 1 |
| `GET /users/1/posts` | Inläggen som användare 1 har skrivit (10 st) |
| `POST /posts` | "Skapar" ett inlägg (se varningen nedan) |

Alla adresser börjar med `https://jsonplaceholder.typicode.com`. Ett id som inte
finns (`/posts/999`) ger statuskod **404** och ett tomt objekt `{}`.

🧪 **Prova själv:** Öppna <https://jsonplaceholder.typicode.com/posts/1> och
<https://jsonplaceholder.typicode.com/users/1> i webbläsaren. Det du ser är precis
det som din app kommer att få.

⚠️ **Varning:** JSONPlaceholder är ett **låtsas**-API. `POST /posts` svarar med
statuskod `201 Created` och skickar tillbaka det du skickade plus `"id": 101`, men
ingenting sparas. Varje nytt inlägg får id 101, och `GET /posts/101` ger 404.
Samma sak gäller `PUT`, `PATCH` och `DELETE`: de svarar som om de lyckades men
ändrar ingenting. I appen lägger vi därför in det nya inlägget i listan själva. Med
PocketBase (sist i kapitlet) sparas det på riktigt.

💡 **Tips:** Texterna i JSONPlaceholder är på låtsaslatin ("sunt aut facere
repellat..."). Det är normalt. Det är formen på datan som är poängen.

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
| Data | Flödet, och ett särskilt meddelande om det är tomt |

Kommer du ihåg `sealed class` från kapitel 01? Den passar perfekt här:

```dart
// lib/models/load_state.dart
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
    Loaded(:final data) when data.isEmpty => const Center(child: Text('Inga inlägg ännu')),
    Loaded(:final data) => FeedList(items: data),
  };
}
```

## HTTP och JSON

Lägg till paketet:

```bash
flutter pub add http
```

⚠️ **Varning:** På **Android** måste appen ha tillstånd att använda internet. Lägg
till `<uses-permission android:name="android.permission.INTERNET"/>` i
`android/app/src/main/AndroidManifest.xml` (i debug-läge finns det redan, men inte
i release, så appen fungerar hos dig men inte i butiken). På **macOS** behöver du
lägga till `com.apple.security.network.client` i
`macos/Runner/DebugProfile.entitlements` och `Release.entitlements`.

### Hur JSON:en ser ut

Ett inlägg från `GET /posts/1`:

```json
{
  "userId": 1,
  "id": 1,
  "title": "sunt aut facere repellat provident occaecati excepturi optio reprehenderit",
  "body": "quia et suscipit\nsuscipit recusandae consequuntur expedita et cum\n..."
}
```

En kommentar från `GET /posts/1/comments` (listan innehåller fem sådana):

```json
{
  "postId": 1,
  "id": 1,
  "name": "id labore ex et quam laborum",
  "email": "Eliseo@gardner.biz",
  "body": "laudantium enim quasi est quidem magnam voluptate ipsam eos\n..."
}
```

En användare från `GET /users/1`. Lägg märke till de **nästlade** objekten
`address` (med ett eget nästlat `geo`) och `company`:

```json
{
  "id": 1,
  "name": "Leanne Graham",
  "username": "Bret",
  "email": "Sincere@april.biz",
  "address": {
    "street": "Kulas Light",
    "suite": "Apt. 556",
    "city": "Gwenborough",
    "zipcode": "92998-3874",
    "geo": { "lat": "-37.3159", "lng": "81.1496" }
  },
  "phone": "1-770-736-8031 x56442",
  "website": "hildegard.org",
  "company": {
    "name": "Romaguera-Crona",
    "catchPhrase": "Multi-layered client-server neural-net",
    "bs": "harness real-time e-markets"
  }
}
```

Sammanfattat: id:n är **heltal**, ett inlägg pekar på sin författare med `userId`,
och en kommentar pekar på sitt inlägg med `postId`. Kommentarer har ingen
användar-relation alls, bara ett `name` (en sorts rubrik) och en `email`.

### Modellklasser med fromJson

```dart
// lib/models/post.dart
class Post {
  const Post({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
  });

  final int id;
  final int userId;
  final String title;
  final String body;

  factory Post.fromJson(Map<String, dynamic> json) => Post(
        id: json['id'] as int,
        userId: json['userId'] as int,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'title': title,
        'body': body,
      };
}
```

```dart
// lib/models/comment.dart
class Comment {
  const Comment({
    required this.id,
    required this.postId,
    required this.name,
    required this.email,
    required this.body,
  });

  final int id;
  final int postId;
  final String name;
  final String email;
  final String body;

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        id: json['id'] as int,
        postId: json['postId'] as int,
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        body: json['body'] as String? ?? '',
      );
}
```

`User` är intressantare, eftersom den har nästlade objekt. Vi gör en klass för
varje nästlat objekt vi bryr oss om (`Address` och `Company`) och hoppar över
`geo` och `bs`, som appen inte använder. Nästlade objekt gör vi **valfria**
(`Address?`). Då kraschar inte appen om en annan källa, eller en framtida version
av API:t, saknar dem.

```dart
// lib/models/user.dart
class Address {
  const Address({required this.street, required this.suite, required this.city, required this.zipcode});

  final String street;
  final String suite;
  final String city;
  final String zipcode;

  factory Address.fromJson(Map<String, dynamic> json) => Address(
        street: json['street'] as String? ?? '',
        suite: json['suite'] as String? ?? '',
        city: json['city'] as String? ?? '',
        zipcode: json['zipcode'] as String? ?? '',
      );
}

class Company {
  const Company({required this.name, this.catchPhrase});

  final String name;
  final String? catchPhrase;

  factory Company.fromJson(Map<String, dynamic> json) => Company(
        name: json['name'] as String? ?? '',
        catchPhrase: json['catchPhrase'] as String?,
      );
}

class User {
  const User({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    this.phone,
    this.website,
    this.address,
    this.company,
  });

  final int id;
  final String name;
  final String username;
  final String email;
  final String? phone;
  final String? website;
  final Address? address;
  final Company? company;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        username: json['username'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String?,
        website: json['website'] as String?,
        // Nästlade objekt: tolka bara om värdet finns och är ett JSON-objekt
        address: switch (json['address']) {
          Map<String, dynamic> a => Address.fromJson(a),
          _ => null,
        },
        company: switch (json['company']) {
          Map<String, dynamic> c => Company.fromJson(c),
          _ => null,
        },
      );

  String get handle => '@$username';
}
```

`switch (json['address']) { Map<String, dynamic> a => ..., _ => null }` är ett
pattern från kapitel 01: *om* värdet är en map, döp den till `a` och tolka den,
annars (saknas, `null` eller något konstigt) blir det `null`. Det är både kortare
och säkrare än `json['address'] == null ? null : Address.fromJson(json['address'] as Map<String, dynamic>)`.

### Datalagret: JsonPlaceholderApi

All nätverkskod samlar vi i **en** klass. Skärmarna anropar bara metoder som
`fetchPosts()` och vet ingenting om URL:er eller JSON.

```dart
// lib/data/jsonplaceholder_api.dart
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/comment.dart';
import '../models/post.dart';
import '../models/user.dart';

class ApiException implements Exception {
  ApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;

  @override
  String toString() => statusCode == null ? message : '$message ($statusCode)';
}

class JsonPlaceholderApi {
  JsonPlaceholderApi({
    http.Client? client,
    this.baseUrl = 'https://jsonplaceholder.typicode.com',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  // --- Inlägg ---------------------------------------------------------------

  Future<List<Post>> fetchPosts() => _getList('/posts', Post.fromJson);

  Future<Post> fetchPost(int id) async =>
      Post.fromJson(await _getObject('/posts/$id'));

  Future<List<Post>> fetchPostsByUser(int userId) =>
      _getList('/users/$userId/posts', Post.fromJson);

  // --- Kommentarer ----------------------------------------------------------

  /// Samma svar som GET /posts/{postId}/comments.
  Future<List<Comment>> fetchComments(int postId) =>
      _getList('/comments', Comment.fromJson, {'postId': '$postId'});

  // --- Användare ------------------------------------------------------------

  Future<List<User>> fetchUsers() => _getList('/users', User.fromJson);

  Future<User> fetchUser(int id) async =>
      User.fromJson(await _getObject('/users/$id'));

  // --- Skapa ----------------------------------------------------------------

  /// OBS: JSONPlaceholder sparar inget. Svaret har alltid id 101.
  Future<Post> createPost({
    required int userId,
    required String title,
    required String body,
  }) async {
    final json = await _send(() => _client.post(
          _uri('/posts'),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode({'userId': userId, 'title': title, 'body': body}),
        ));
    return Post.fromJson(json as Map<String, dynamic>);
  }

  // --- Hjälpmetoder ---------------------------------------------------------

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  Future<Map<String, dynamic>> _getObject(String path) async {
    final json = await _send(() => _client.get(_uri(path)));
    if (json is! Map<String, dynamic>) {
      throw ApiException('Oväntat svar från servern');
    }
    return json;
  }

  Future<List<T>> _getList<T>(
    String path,
    T Function(Map<String, dynamic> json) fromJson, [
    Map<String, String>? query,
  ]) async {
    final json = await _send(() => _client.get(_uri(path, query)));
    if (json is! List) throw ApiException('Oväntat svar från servern');
    return json.map((e) => fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Skickar anropet, översätter fel till ApiException och avkodar JSON.
  Future<Object?> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request().timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw ApiException('Servern svarade inte i tid');
    } on http.ClientException {
      throw ApiException('Kunde inte nå servern. Kontrollera din uppkoppling.');
    }

    if (response.statusCode == 404) {
      throw ApiException('Hittades inte', 404);
    }
    // Allt i 200-serien är lyckat: 200 OK, 201 Created, 204 No Content ...
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('Servern svarade med ett fel', response.statusCode);
    }
    // utf8.decode på bytes ger korrekt å, ä, ö även om servern inte anger charset
    return jsonDecode(utf8.decode(response.bodyBytes));
  }
}
```

Steg för steg, för ett GET-anrop:

1. Bygg en `Uri`. `replace(queryParameters: ...)` lägger till `?postId=1` och
   URL-kodar värdena åt dig (mellanslag, `&` m.m.).
2. `await _client.get(uri)` skickar anropet. `timeout` gör att vi inte väntar för
   evigt.
3. Fånga nätverksfel. Utan uppkoppling kastar `http` ett `ClientException`, och
   `timeout` kastar ett `TimeoutException`. Vi översätter båda till vårt eget
   `ApiException` med en text som användaren förstår.
4. Kontrollera `statusCode`. `http` kastar **inte** fel för 404 eller 500, det
   måste du göra själv.
5. `jsonDecode` gör om texten till `Map`/`List` med `dynamic`-värden.
6. `fromJson` gör om varje map till ett typat objekt.

`_getList` är **generisk** (`<T>`): samma kod tolkar listor av `Post`, `Comment`
och `User`, eftersom vi skickar med rätt `fromJson` som argument. `Post.fromJson`
utan parenteser är en *tear-off*, alltså själva konstruktorn som ett
funktionsvärde.

Konstruktorn tar emot en valfri `http.Client`. I kapitel 06 skickar vi in en
låtsasklient (`MockClient`) så att vi kan testa utan nätverk.

### POST: skapa ett inlägg

Titta på `createPost` igen. Det som skiljer från GET:

- Metoden är `_client.post`, och datan skickas som en JSON-sträng i `body`.
- Headern `Content-Type: application/json` talar om för servern att det är JSON.
- Svaret har statuskod **201 Created**, inte 200. Därför kontrollerar `_send` hela
  200-serien. En vanlig bugg är `if (response.statusCode != 200) throw ...`, som
  felaktigt kastar fel för ett lyckat POST.

```dart
final api = JsonPlaceholderApi();
final post = await api.createPost(userId: 1, title: 'Hej Kvittra', body: 'Mitt första inlägg');
print(post.id); // 101 – varje gång, eftersom inget sparas
```

### Slå ihop data på klienten

Ett inlägg innehåller bara `userId`, men flödet ska visa författarens namn. Vi
behöver alltså både `/posts` och `/users` och sedan koppla ihop dem, ungefär som
en `JOIN` i SQL (modul 01), fast i Dart.

```dart
// lib/models/feed_item.dart
class FeedItem {
  const FeedItem({required this.post, required this.author});

  final Post post;
  final User author;
}
```

```dart
Future<List<FeedItem>> loadFeed(JsonPlaceholderApi api) async {
  // 1. Starta båda anropen direkt, så att de körs samtidigt
  final postsFuture = api.fetchPosts();
  final usersFuture = api.fetchUsers();

  // 2. Vänta på båda. Misslyckas något kastas det första felet vidare
  await Future.wait([postsFuture, usersFuture]);

  // 3. Båda är klara, så de här await:arna ger värdet direkt
  final posts = await postsFuture;
  final users = await usersFuture;

  // 4. Gör en uppslagstabell: userId -> User
  final usersById = {for (final u in users) u.id: u};

  // 5. Koppla ihop. Inlägg vars författare saknas hoppar vi över
  return [
    for (final post in posts)
      if (usersById[post.userId] case final author?)
        FeedItem(post: post, author: author),
  ];
}
```

- Att starta båda anropen **innan** vi väntar gör att de går parallellt. Två
  anrop à 300 ms tar då cirka 300 ms i stället för 600 ms.
- `{for (final u in users) u.id: u}` är en *map comprehension*: collection-for
  fungerar i maps också.
- `if (usersById[post.userId] case final author?)` betyder "om uppslaget inte är
  null, döp värdet till `author`". Det är en *null-check pattern* inuti
  collection-if.

💡 **Tips:** Dart 3 har också `(api.fetchPosts(), api.fetchUsers()).wait` på ett
record av futures, som ger tillbaka ett typat record. Om ett av anropen
misslyckas får du dock ett `ParallelWaitError` som omsluter det riktiga felet, så
felmeddelandet blir krångligare att visa för användaren.

⚠️ **Varning:** Att hämta allt och koppla ihop på klienten fungerar för 100
inlägg och 10 användare. Med 100 000 inlägg blir det ohållbart. Riktiga backends
gör kopplingen på servern. I PocketBase heter det `expand`, som du ser i slutet av
kapitlet.

## FutureBuilder

`FutureBuilder` är en inbyggd widget som lyssnar på en `Future` och bygger om
sig själv när den blir klar. Du får en `AsyncSnapshot` med tillståndet. Här är en
skärm som listar alla användare, med stad och företag från de nästlade objekten:

```dart
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key, required this.api});

  final JsonPlaceholderApi api;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  late Future<List<User>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchUsers(); // skapa Future EN gång
  }

  void _retry() {
    setState(() => _future = widget.api.fetchUsers());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Personer att följa')),
      body: FutureBuilder<List<User>>(
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
                  Text('Kunde inte hämta användare:\n${snapshot.error}',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _retry, child: const Text('Försök igen')),
                ],
              ),
            );
          }
          final users = snapshot.data!;
          if (users.isEmpty) {
            return const Center(child: Text('Inga användare'));
          }
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, i) {
              final u = users[i];
              return ListTile(
                leading: CircleAvatar(child: Text(u.name.isEmpty ? '?' : u.name[0])),
                title: Text(u.name),
                subtitle: Text([
                  u.handle,
                  ?u.address?.city, // ? först = ta bara med om värdet inte är null
                  ?u.company?.name,
                ].join(' · ')),
              );
            },
          );
        },
      ),
    );
  }
}
```

`?u.address?.city` i listan är ett *null-aware element* (Dart 3.8 och senare): om
användaren saknar adress hoppas elementet över i stället för att `null` hamnar i
listan. Det är samma sak som `if (u.address?.city case final city?) city`, fast
kortare. Resultatet blir t.ex. "@Bret · Gwenborough · Romaguera-Crona".

⚠️ **Varning:** Skapa **inte** din `Future` direkt i `build`:

```dart
FutureBuilder(
  future: widget.api.fetchUsers(), // FEL: nytt anrop vid VARJE build!
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

Ett exempel från Kvittra: tiden på ett inlägg ("nu", "1 min", "2 min" ...) ska
uppdateras av sig själv medan man tittar på skärmen. Vi använder `timeAgo` från
kapitel 02 och en ström som tickar var 30:e sekund:

```dart
class TimeAgoText extends StatefulWidget {
  const TimeAgoText({super.key, required this.time});

  final DateTime time;

  @override
  State<TimeAgoText> createState() => _TimeAgoTextState();
}

class _TimeAgoTextState extends State<TimeAgoText> {
  // Skapa strömmen en gång, av samma skäl som med Future
  final Stream<DateTime> _ticks = Stream.periodic(
    const Duration(seconds: 30),
    (_) => DateTime.now(),
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime>(
      stream: _ticks,
      initialData: DateTime.now(), // visa något direkt, innan första ticket
      builder: (context, snapshot) {
        return Text(timeAgo(widget.time, now: snapshot.data));
      },
    );
  }
}
```

`StreamBuilder` sköter själv prenumerationen och avslutar den när widgeten
försvinner. Lyssnar du på en ström med `.listen` själv måste du spara
`StreamSubscription` och anropa `cancel()` i `dispose`.

## Felhantering i UI:t

Fånga fel så nära UI:t som möjligt och översätt dem till något användaren förstår.
Tack vare `ApiException` är `'$error'` redan en begriplig svensk text:

```dart
Future<void> _load() async {
  try {
    final items = await loadFeed(widget.api);
    if (!mounted) return;
    setState(() => _state = Loaded(items));
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

## Helt exempel: flödet från JSONPlaceholder

```dart
// lib/screens/feed_screen.dart
import 'package:flutter/material.dart';

import '../data/jsonplaceholder_api.dart';
import '../models/feed_item.dart';
import '../models/load_state.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key, required this.api});

  final JsonPlaceholderApi api;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  LoadState<List<FeedItem>> _state = const Loading();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await loadFeed(widget.api);
      if (mounted) setState(() => _state = Loaded(items));
    } catch (e) {
      if (mounted) setState(() => _state = Failed(e));
    }
  }

  void _retry() {
    setState(() => _state = const Loading());
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kvittra')),
      body: switch (_state) {
        Loading() => const Center(child: CircularProgressIndicator()),
        Failed(:final error) => ErrorView(message: '$error', onRetry: _retry),
        Loaded(:final data) when data.isEmpty =>
          const Center(child: Text('Inga inlägg ännu')),
        Loaded(:final data) => RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              itemCount: data.length,
              itemBuilder: (context, i) {
                final FeedItem(:post, :author) = data[i];
                return ListTile(
                  key: ValueKey(post.id),
                  leading: CircleAvatar(child: Text(author.name[0])),
                  title: Text(post.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${author.name} · ${author.handle}\n${post.body}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
                );
              },
            ),
          ),
      },
    );
  }
}

// lib/widgets/error_view.dart
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Försök igen')),
          ],
        ),
      ),
    );
  }
}
```

```dart
// lib/main.dart
import 'package:flutter/material.dart';

import 'data/jsonplaceholder_api.dart';
import 'screens/feed_screen.dart';

void main() {
  final api = JsonPlaceholderApi(); // en instans, skickas in där den behövs
  runApp(MaterialApp(
    title: 'Kvittra',
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo)),
    home: FeedScreen(api: api),
  ));
}
```

(`loadFeed` ligger i `feed_item.dart` eller i datalagret, och `ErrorView` i en egen
fil. Importera dem där de används.)

Lägg märke till `final FeedItem(:post, :author) = data[i];`. Det är ett *object
pattern* som plockar ut två fält till lokala variabler på en rad.

## PocketBase-paketet: samma sak mot vår egen backend

JSONPlaceholder är perfekt för att öva, men den sparar ingenting och har inga
gillningar eller följare. I modul 02 byggde du Kvittras riktiga datamodell i
PocketBase (`users`, `posts`, `comments`, `likes`, `follows`). Det officiella
Dart-SDK:t sköter URL:er, JSON, felhantering, inloggning, tokens och realtid åt
dig. Läs [02-pocketbase/06-dart-sdk.md](../02-pocketbase/06-dart-sdk.md) för
detaljerna. Här är en kort introduktion i Flutter-sammanhang.

### Vad skiljer?

| | JSONPlaceholder | Vår PocketBase |
|---|---|---|
| Id | Heltal: `1`, `2`, `3` | Sträng med 15 tecken: `"k3j2h1g4f5d6s7a"` |
| Inläggets författare | `userId` (ett heltal) | `author`, en **relation** (id-sträng). Med `expand: 'author'` följer hela användaren med i svaret |
| Kommentarens författare | Bara `name` och `email` som fri text | `author`, en relation till `users` |
| Tidsstämpel | Finns inte | `created` och `updated` (sätts automatiskt) |
| Svar på en lista | En ren JSON-lista `[...]` | Ett objekt `{page, perPage, totalItems, totalPages, items: [...]}` |
| Gillningar och följare | Finns inte | Collections `likes` och `follows` |
| Skapa inlägg | Låtsas: alltid id 101, sparas inte | Sparas på riktigt. Kräver oftast inloggning enligt API-reglerna |
| Profil | `address`, `phone`, `company` | `bio` och `website` |

Den viktigaste skillnaden är `userId` mot `author`. Med JSONPlaceholder kopplade vi
ihop inlägg och användare själva på klienten. PocketBase gör det på servern om du
ber om det med `expand`.

### Kod

```bash
flutter pub add pocketbase
```

```dart
// lib/data/pocketbase_client.dart
import 'package:pocketbase/pocketbase.dart';

// En enda instans för hela appen.
// Android-emulatorn: 'http://10.0.2.2:8090'
final pb = PocketBase('http://127.0.0.1:8090');
```

Eftersom id:n är strängar och författaren kommer via `expand` gör vi en egen
modell för PocketBase-inlägg:

```dart
// lib/models/pb_post.dart
import 'package:pocketbase/pocketbase.dart';

class PbPost {
  const PbPost({
    required this.id,
    required this.title,
    required this.body,
    required this.created,
    required this.authorId,
    required this.authorName,
    required this.authorUsername,
  });

  final String id;
  final String title;
  final String body;
  final DateTime created;
  final String authorId;
  final String authorName;     // tom om vi inte hämtade med expand
  final String authorUsername; // tom om vi inte hämtade med expand

  factory PbPost.fromRecord(RecordModel r) => PbPost(
        id: r.id,
        title: r.getStringValue('title'),
        body: r.getStringValue('body'),
        // PocketBase skickar "2026-03-10 09:15:00.000Z". DateTime.parse klarar
        // mellanslaget i stället för 'T'
        created: DateTime.parse(r.getStringValue('created')),
        authorId: r.getStringValue('author'),
        // Punkt-notation läser inuti expand
        authorName: r.getStringValue('expand.author.name'),
        authorUsername: r.getStringValue('expand.author.username'),
      );
}
```

```dart
// lib/data/pocketbase_feed_repository.dart
import 'package:pocketbase/pocketbase.dart';

import '../models/pb_post.dart';

class PocketBaseFeedRepository {
  PocketBaseFeedRepository(this._pb);
  final PocketBase _pb;

  Future<List<PbPost>> fetchFeed() async {
    final result = await _pb.collection('posts').getList(
          page: 1,
          perPage: 30,
          sort: '-created',
          expand: 'author', // servern gör "JOIN:en" åt oss
        );
    return result.items.map(PbPost.fromRecord).toList();
  }

  Future<List<RecordModel>> fetchComments(String postId) {
    return _pb.collection('comments').getFullList(
          filter: _pb.filter('post = {:id}', {'id': postId}),
          sort: 'created',
          expand: 'author',
        );
  }

  Future<PbPost> create({required String title, required String body}) async {
    final record = await _pb.collection('posts').create(
      body: {
        'title': title,
        'body': body,
        'author': _pb.authStore.record?.id, // den inloggade användaren
      },
      expand: 'author',
    );
    return PbPost.fromRecord(record);
  }

  /// Realtid: anropa [onChange] varje gång ett inlägg skapas/ändras/tas bort.
  /// Returnerar en funktion som avslutar prenumerationen.
  Future<UnsubscribeFunc> watch(void Function() onChange) {
    return _pb.collection('posts').subscribe('*', (e) => onChange());
  }
}
```

Jämför med `loadFeed` ovan: i stället för två anrop och en uppslagstabell räcker
det med ett anrop och `expand: 'author'`. `pb.filter(...)` bygger ett filter med
parametrar och sköter citattecken åt dig, så att ett id aldrig kan "bryta sig ut"
ur filtret.

Inloggning:

```dart
try {
  await pb.collection('users').authWithPassword('anna@example.com', 'hemligt123');
  print('Inloggad som @${pb.authStore.record?.getStringValue('username')}');
} on ClientException catch (e) {
  // statusCode 400 = fel e-post eller lösenord
  print('Inloggningen misslyckades: ${e.response['message']}');
}
```

Efter inloggning skickar SDK:t automatiskt med token i alla anrop, så API-reglerna
från modul 02 (t.ex. att bara inloggade får skapa inlägg) fungerar.

⚠️ **Varning:** `127.0.0.1` betyder "den här enheten". I **Android-emulatorn** är
det emulatorn själv, inte din dator. Använd `http://10.0.2.2:8090` där. iOS-
simulatorn, Chrome och desktop kan använda `127.0.0.1`. På en riktig telefon
behöver du datorns IP-adress i nätverket och starta PocketBase med
`./pocketbase serve --http=0.0.0.0:8090`. (Det här gäller inte JSONPlaceholder,
som ligger på internet.)

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
│   ├── post.dart
│   ├── comment.dart
│   ├── user.dart             ← User, Address, Company
│   ├── feed_item.dart
│   └── load_state.dart
├── data/                     ← allt som pratar med omvärlden
│   ├── jsonplaceholder_api.dart
│   ├── pocketbase_client.dart
│   └── pocketbase_feed_repository.dart
├── screens/                  ← hela skärmar (en per route)
│   ├── feed_screen.dart
│   ├── post_detail_screen.dart
│   ├── profile_screen.dart
│   └── new_post_screen.dart
└── widgets/                  ← återanvändbara delar
    ├── post_card.dart
    ├── profile_header.dart
    └── error_view.dart
```

Tanken är att varje lager bara känner till lagret under sig:

```
screens / widgets   →   data (JsonPlaceholderApi, repositories)   →   http / pocketbase
       ↓                          ↓
                    models (används av alla)
```

- **Skärmar** vet ingenting om URL:er eller JSON. De anropar `api.fetchPosts()`.
- **Datalagret** vet hur man pratar med JSONPlaceholder eller PocketBase men
  ingenting om widgets.
- **Modeller** är rena Dart-klasser utan beroenden. De är lätta att testa.

Byter du från JSONPlaceholder till PocketBase (eller till en låtsas-implementation
i ett test) behöver bara datalagret, och möjligen modellerna, ändras.

💡 **Tips:** Namnen `services/`, `repositories/` och `data/` används lite olika i
olika projekt. Det viktiga är principen: **håll nätverkskod borta från widgets**.

🧪 **Prova själv:**

1. Kör `FeedScreen` mot JSONPlaceholder. Du ska se 100 inlägg med författarnamn.
2. Slå på flygplansläge (eller ändra `baseUrl` till `https://finns-inte.invalid`)
   och dra för att uppdatera. Får du ett begripligt felmeddelande?
3. Gör en `PostDetailScreen(postId:)` som hämtar `fetchPost(id)` och
   `fetchComments(id)` och visar inlägget med kommentarerna under. Vad händer med
   `postId: 999`?
4. Om du har PocketBase från modul 02 igång: byt till `PocketBaseFeedRepository`,
   lägg till realtid med `watch(_load)` och skapa ett inlägg i PocketBase Admin UI.
   Dyker det upp i appen utan att du gör något?

**Nästa kapitel:** [06 – Testning](06-testning.md)

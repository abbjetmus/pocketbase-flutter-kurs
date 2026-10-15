# 06 – Dart-SDK

I kapitel 5 pratade vi med PocketBase via `curl`. I Flutter-appen vill vi
slippa bygga URL:er, sätta headers och tolka JSON för hand. Det sköter det
officiella Dart-paketet [`pocketbase`](https://pub.dev/packages/pocketbase).

Du kommer att köra koden på riktigt i modul 03–04. Läs kapitlet nu och känn
igen sambanden med det du gjort med curl. Exemplen fungerar också som vanliga
Dart-program (`dart run`), så du kan prova dem redan nu om du har Dart
installerat.

## Installation

I ett Flutter-projekt:

```bash
flutter pub add pocketbase
```

eller i ett rent Dart-projekt:

```bash
dart pub add pocketbase
```

I `pubspec.yaml` ser det ut ungefär så här:

```yaml
dependencies:
  pocketbase: ^0.25.2   # när materialet skrevs; 0.23 eller senare krävs
```

⚠️ **Varning:** PocketBase-servern v0.23+ kräver Dart-paketet **0.23 eller
senare**. Äldre exempel på nätet använder `pb.authStore.model` eller
`UserModel` – de är för gamla versioner. Observera också att `^0.25.2` i Dart
betyder "0.25.x" (för 0.x-versioner låser `^` minor-versionen). `flutter pub
add` väljer den senaste versionen åt dig.

## Skapa klienten

```dart
import 'package:pocketbase/pocketbase.dart';

final pb = PocketBase('http://127.0.0.1:8090');
```

Skapa **en** instans för hela appen och återanvänd den. Den håller reda på
inloggningen och realtidsanslutningen.

| Var körs appen? | Adress till PocketBase på din dator |
|-----------------|-------------------------------------|
| iOS-simulator, macOS, webb | `http://127.0.0.1:8090` |
| Android-emulator | `http://10.0.2.2:8090` |
| Fysisk telefon på samma wifi | `http://<datorns IP>:8090` och starta med `--http=0.0.0.0:8090` |

## Mappning från curl till SDK

| curl (kapitel 5) | Dart-SDK |
|------------------|----------|
| `POST .../users/records` (registrering) | `pb.collection('users').create(body: {...})` |
| `POST .../users/auth-with-password` | `pb.collection('users').authWithPassword(identity, pw)` |
| `GET .../records?page=1&perPage=20` | `pb.collection('x').getList(page: 1, perPage: 20)` |
| `GET .../records` (alla sidor) | `pb.collection('x').getFullList()` |
| `GET .../records/{id}` | `pb.collection('x').getOne(id)` |
| `POST .../records` | `pb.collection('x').create(body: {...})` |
| `PATCH .../records/{id}` | `pb.collection('x').update(id, body: {...})` |
| `DELETE .../records/{id}` | `pb.collection('x').delete(id)` |
| Header `Authorization: $TOKEN` | Sköts automatiskt via `pb.authStore` |
| `GET /api/realtime` + `POST` | `pb.collection('x').subscribe('*', callback)` |

## Registrering och inloggning

```dart
Future<void> register(String email, String username, String password) async {
  await pb.collection('users').create(body: {
    'email': email,
    'username': username,
    'password': password,
    'passwordConfirm': password,
  });
  // Registrering loggar inte in – gör det direkt efteråt
  await pb.collection('users').authWithPassword(email, password);
}

Future<void> login(String identity, String password) async {
  // identity kan vara e-post eller användarnamn (om username är identitetsfält)
  final auth = await pb.collection('users').authWithPassword(identity, password);

  print(auth.token);                              // token (sparas automatiskt)
  print(auth.record.id);                          // Annas id
  print(auth.record.getStringValue('username'));  // "anna"
}
```

Efter inloggning skickar SDK:n token i alla anrop automatiskt.

### authStore

`pb.authStore` håller koll på vem som är inloggad:

| Egenskap / metod | Betyder |
|------------------|---------|
| `pb.authStore.isValid` | `true` om det finns en token som inte gått ut |
| `pb.authStore.token` | Själva token |
| `pb.authStore.record` | Den inloggade användarens post (`RecordModel?`) |
| `pb.authStore.onChange` | En `Stream` som skickar ett event vid inloggning/utloggning |
| `pb.authStore.clear()` | Logga ut (glömmer token) |

```dart
bool get isLoggedIn => pb.authStore.isValid;

String? get myId => pb.authStore.record?.id;

String get myUsername => pb.authStore.record?.getStringValue('username') ?? '';

void logout() => pb.authStore.clear();
```

### Förnya token

Token går ut efter några dagar. Förnya den när appen startar:

```dart
Future<void> refreshIfNeeded() async {
  if (!pb.authStore.isValid) return;
  try {
    await pb.collection('users').authRefresh();
  } on ClientException {
    pb.authStore.clear(); // token ogiltig, t.ex. lösenordet byttes
  }
}
```

`authRefresh` ger också en uppdaterad `record` – t.ex. om användaren ändrat sin
profil från en annan enhet.

### Kom ihåg inloggningen mellan app-starter

Standard-`AuthStore` ligger bara i minnet. Med `AsyncAuthStore` och paketet
`shared_preferences` sparas inloggningen på telefonen:

```dart
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<PocketBase> createPocketBase() async {
  final prefs = await SharedPreferences.getInstance();

  final store = AsyncAuthStore(
    save: (String data) async => prefs.setString('pb_auth', data),
    initial: prefs.getString('pb_auth'),
    clear: () async => prefs.remove('pb_auth'),
  );

  return PocketBase('http://127.0.0.1:8090', authStore: store);
}
```

💡 **Tips:** För extra säkerhet kan du spara token med
`flutter_secure_storage` i stället för `shared_preferences`. Principen är
densamma.

## Läsa data

### getList – en sida (flödet)

```dart
final myId = pb.authStore.record!.id;

final result = await pb.collection('posts').getList(
  page: 1,
  perPage: 20,
  sort: '-created',
  expand: 'author',
  filter: pb.filter(
    'author.follows_via_following.follower ?= {:me}',
    {'me': myId},
  ),
);

print(result.page);        // 1
print(result.totalItems);  // t.ex. 4
for (final record in result.items) {
  print(record.getStringValue('title'));
}
```

`result` är en `ResultList<RecordModel>` med `page`, `perPage`, `totalItems`,
`totalPages` och `items`. Lägg till `skipTotal: true` för ett oändligt flöde
(kapitel 5).

### getFullList – alla poster

```dart
final comments = await pb.collection('comments').getFullList(
  filter: pb.filter('post = {:post}', {'post': postId}),
  sort: 'created',
  expand: 'author',
);
```

SDK:n hämtar sida efter sida (1000 åt gången som standard) tills allt är
hämtat. Bra för begränsade listor som kommentarerna till *ett* inlägg.
**Använd inte** för alla inlägg eller alla gillningar – de växer hela tiden,
och där är `getList` med paginering rätt.

### getOne och getFirstListItem

```dart
final post = await pb.collection('posts').getOne(postId, expand: 'author');

// Första posten som matchar ett filter (kastar 404 om ingen finns)
final bo = await pb.collection('users').getFirstListItem('username = "bo"');
```

## Filter med parametrar – `pb.filter`

Anta att användaren skriver in en sökterm. Det är frestande att bygga filtret
med strängsammanfogning:

```dart
// ⚠️ GÖR INTE SÅ HÄR
final filter = 'title ~ "$search"';
```

Om `search` innehåller ett citattecken, t.ex. `Annas "bästa" kaffe`, går
filtret sönder. Värre: någon kan skriva `" || author != "` och ändra filtrets
betydelse. Det är samma problem som **SQL-injektion** i modul 01.

Använd i stället `pb.filter` med namngivna platshållare `{:namn}`:

```dart
final result = await pb.collection('posts').getList(
  filter: pb.filter('title ~ {:q} || body ~ {:q}', {'q': search}),
  sort: '-created',
);
```

`pb.filter` sätter citattecken och escapar värdena åt dig. Den klarar
`String`, `num`, `bool`, `null` och **`DateTime`**:

```dart
// Inlägg från idag (lokal tid) och framåt
final now = DateTime.now();
final startOfToday = DateTime(now.year, now.month, now.day); // lokal midnatt

final today = await pb.collection('posts').getList(
  filter: pb.filter('created >= {:from}', {'from': startOfToday}),
  sort: '-created',
);
```

`DateTime` konverteras automatiskt till UTC i PocketBase-format. Det löser
UTC-problemet från kapitel 5: du räknar i lokal tid, SDK:n översätter.

⚠️ **Varning:** Du kan inte skriva `@request.auth.id` i ett filter från appen
– PocketBase svarar `403 Only superusers can filter by @request.`. Skicka ditt
eget id som parameter: `pb.filter('author = {:me}', {'me': myId})`.

## Skapa, ändra, ta bort

```dart
final myId = pb.authStore.record!.id;

// Skapa
final post = await pb.collection('posts').create(body: {
  'author': myId,
  'title': 'Fikadags',
  'body': 'Kanelbullar i fikarummet!',
});

// Ändra
await pb.collection('posts').update(post.id, body: {
  'body': 'Kanelbullar OCH kardemummabullar!',
});

// Ta bort
await pb.collection('posts').delete(post.id);
```

### Gilla och sluta gilla

En gillning är en post i `likes`. "Toggla" betyder: finns min gillning – ta bort
den, annars skapa den.

```dart
/// Returnerar true om inlägget är gillat efteråt.
Future<bool> toggleLike(String postId) async {
  final me = pb.authStore.record!.id;

  final existing = await pb.collection('likes').getList(
    perPage: 1,
    skipTotal: true,
    filter: pb.filter('post = {:post} && user = {:me}', {'post': postId, 'me': me}),
  );

  if (existing.items.isNotEmpty) {
    await pb.collection('likes').delete(existing.items.first.id);
    return false;
  }
  await pb.collection('likes').create(body: {'post': postId, 'user': me});
  return true;
}
```

### Följa och sluta följa

```dart
Future<void> follow(String userId) => pb.collection('follows').create(body: {
      'follower': pb.authStore.record!.id,
      'following': userId,
    });

Future<void> unfollow(String userId) async {
  final row = await pb.collection('follows').getFirstListItem(
    pb.filter('follower = {:me} && following = {:user}',
        {'me': pb.authStore.record!.id, 'user': userId}),
  );
  await pb.collection('follows').delete(row.id);
}
```

### Filer

```dart
import 'package:http/http.dart' as http;

await pb.collection('posts').create(
  body: {'author': myId, 'title': 'Dagens bröd'},
  files: [
    await http.MultipartFile.fromPath('image', '/sökväg/till/brod.jpg'),
  ],
);

// URL till en uppladdad fil (med miniatyr)
final url = pb.files.getURL(post, post.getStringValue('image'), thumb: '400x0');
```

## Läsa fält ur en RecordModel

Varje post är en `RecordModel` med `id`, `collectionId`, `collectionName` och
`data` (en `Map`). Läs värden med `get<T>()` eller hjälpmetoderna:

| Metod | Exempel |
|-------|---------|
| `get<T>(fält, [standard])` | `record.get<String>('title', '')` |
| `getStringValue(fält)` | `record.getStringValue('username')` |
| `getIntValue(fält)` | `record.getIntValue('likes_count')` (i en view) |
| `getDoubleValue(fält)` | `record.getDoubleValue('score')` |
| `getBoolValue(fält)` | `record.getBoolValue('emailVisibility')` |
| `getListValue<T>(fält)` | `record.getListValue<String>('tags')` |

Metoderna klarar punkt-notation, även in i `expand`:

```dart
final authorName = post.get<String>('expand.author.name', '?');

final author = post.get<RecordModel?>('expand.author');

final comments = post.get<List<RecordModel>>('expand.comments_via_post', []);
```

💡 **Tips:** `get` returnerar ett säkert standardvärde (`""`, `0`, `false`,
`[]`) om fältet saknas, i stället för att krascha. Det är praktiskt men kan
också dölja stavfel. Läs därför fälten på **ett** ställe – i en modellklass.

## Modellklasser – från RecordModel till Dart

Att skriva `record.getStringValue('username')` överallt i appen blir rörigt
och felbenäget. Gör i stället en Dart-klass per collection, med en
`fromRecord`-konstruktor. Då pratar resten av appen bara med typade objekt.

```dart
class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.name,
    required this.bio,
    required this.website,
    required this.avatar,
  });

  final String id;
  final String username;
  final String name;
  final String bio;
  final String website;
  final String avatar; // filnamn, "" om ingen bild

  factory AppUser.fromRecord(RecordModel r) => AppUser(
        id: r.id,
        username: r.getStringValue('username'),
        name: r.getStringValue('name'),
        bio: r.getStringValue('bio'),
        website: r.getStringValue('website'),
        avatar: r.getStringValue('avatar'),
      );

  /// Namnet om det finns, annars @användarnamn.
  String get displayName => name.isNotEmpty ? name : '@$username';
}
```

(Klassen heter `AppUser` i stället för `User` för att inte krocka med andra
paket som också har en `User`.)

```dart
class Post {
  const Post({
    required this.id,
    required this.authorId,
    required this.title,
    required this.body,
    required this.image,
    required this.created,
    this.author,
  });

  final String id;
  final String authorId;
  final String title;
  final String body;
  final String image;
  final DateTime created; // lokal tid
  final AppUser? author;  // finns om vi hämtade med expand=author

  factory Post.fromRecord(RecordModel r) {
    final authorRecord = r.get<RecordModel?>('expand.author');
    return Post(
      id: r.id,
      authorId: r.getStringValue('author'),
      title: r.getStringValue('title'),
      body: r.getStringValue('body'),
      image: r.getStringValue('image'),
      created: DateTime.parse(r.getStringValue('created')).toLocal(),
      author: authorRecord == null ? null : AppUser.fromRecord(authorRecord),
    );
  }

  Map<String, dynamic> toBody() => {
        'author': authorId,
        'title': title,
        'body': body,
      };
}
```

```dart
class Comment {
  const Comment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.body,
    required this.created,
    this.author,
  });

  final String id;
  final String postId;
  final String authorId;
  final String body;
  final DateTime created;
  final AppUser? author;

  factory Comment.fromRecord(RecordModel r) {
    final authorRecord = r.get<RecordModel?>('expand.author');
    return Comment(
      id: r.id,
      postId: r.getStringValue('post'),
      authorId: r.getStringValue('author'),
      body: r.getStringValue('body'),
      created: DateTime.parse(r.getStringValue('created')).toLocal(),
      author: authorRecord == null ? null : AppUser.fromRecord(authorRecord),
    );
  }
}
```

`DateTime.parse` klarar PocketBase-formatet `2026-10-15 08:17:41.396Z`.
`.toLocal()` gör om från UTC till telefonens tidszon.

### En liten repository-klass

Samla alla anrop på ett ställe:

```dart
class KvittraRepository {
  KvittraRepository(this.pb);
  final PocketBase pb;

  String get _me => pb.authStore.record!.id;

  /// Flödet: inlägg från dem jag följer, nyast först.
  Future<List<Post>> feed({int page = 1}) async {
    final result = await pb.collection('posts').getList(
          page: page,
          perPage: 20,
          skipTotal: true,
          sort: '-created',
          expand: 'author',
          filter: pb.filter(
            'author.follows_via_following.follower ?= {:me}',
            {'me': _me},
          ),
        );
    return result.items.map(Post.fromRecord).toList();
  }

  Future<List<Comment>> comments(String postId) async {
    final records = await pb.collection('comments').getFullList(
          sort: 'created',
          expand: 'author',
          filter: pb.filter('post = {:post}', {'post': postId}),
        );
    return records.map(Comment.fromRecord).toList();
  }

  Future<Comment> addComment(String postId, String body) async {
    final record = await pb.collection('comments').create(
      body: {'post': postId, 'author': _me, 'body': body},
      expand: 'author',
    );
    return Comment.fromRecord(record);
  }

  // + toggleLike, follow och unfollow från avsnitten ovan
}
```

I modul 04 kopplar vi en sådan klass till widgets med `flutter_compositions`.

## Realtid – nya kommentarer direkt

När ett inlägg visas vill vi att nya kommentarer dyker upp direkt. Med
`filter` får appen bara händelser för *det* inlägget:

```dart
final unsubscribe = await pb.collection('comments').subscribe(
  '*',
  (e) {
    print(e.action);      // 'create', 'update' eller 'delete'
    print(e.record?.id);  // posten som ändrades

    final comment = Comment.fromRecord(e.record!);
    // uppdatera listan i appen...
  },
  filter: pb.filter('post = {:post}', {'post': postId}),
  expand: 'author',
);

// Senare, när skärmen stängs:
await unsubscribe();
```

| Variant | Lyssnar på |
|---------|------------|
| `subscribe('*', cb)` | Alla poster i collectionen (som list-regeln släpper igenom) |
| `subscribe('*', cb, filter: ...)` | Bara de poster som också matchar filtret |
| `subscribe(recordId, cb)` | En enskild post (view-regeln) |
| `unsubscribe()` | Sluta lyssna på allt i collectionen |

Ett vanligt mönster för en lista som ska vara "levande":

```dart
void applyEvent(List<Comment> list, RecordSubscriptionEvent e) {
  final c = Comment.fromRecord(e.record!);
  switch (e.action) {
    case 'create':
      list.add(c);
    case 'update':
      final i = list.indexWhere((x) => x.id == c.id);
      if (i != -1) list[i] = c;
    case 'delete':
      list.removeWhere((x) => x.id == c.id);
  }
  list.sort((a, b) => a.created.compareTo(b.created));
}
```

⚠️ **Varning:** Glöm inte att avsluta prenumerationen (`unsubscribe`) när
skärmen försvinner. Annars fortsätter appen ta emot händelser och uppdatera
data som ingen visar – en klassisk minnesläcka.

## Felhantering – ClientException

Alla fel från SDK:n kastas som `ClientException`:

| Egenskap | Innehåll |
|----------|----------|
| `statusCode` | HTTP-status (`400`, `404`, ...). `0` om servern inte gick att nå |
| `response` | Felsvaret som `Map` – samma JSON som i kapitel 5 |
| `url` | Anropad adress |
| `isAbort` | `true` om anropet avbröts |
| `originalError` | Underliggande fel (t.ex. nätverksfel) |

```dart
Future<String?> tryLike(String postId) async {
  try {
    await pb.collection('likes').create(body: {
      'post': postId,
      'user': pb.authStore.record!.id,
    });
    return null; // inget fel
  } on ClientException catch (e) {
    if (e.statusCode == 0) {
      return 'Ingen kontakt med servern. Kontrollera internetanslutningen.';
    }
    if (e.statusCode == 401 || e.statusCode == 403) {
      return 'Du behöver logga in igen.';
    }

    // Fel per fält, t.ex. det unika indexet på (post, user):
    // {"post": {"code": "validation_not_unique", ...}, "user": {...}}
    final data = e.response['data'];
    if (data is Map && data['post']?['code'] == 'validation_not_unique') {
      return 'Du har redan gillat inlägget.';
    }
    if (data is Map && data.isNotEmpty) {
      final first = data.values.first as Map;
      return first['message'] as String?;
    }

    // Felmeddelande från en hook, t.ex. "Du kan inte gilla ditt eget inlägg."
    return e.response['message'] as String? ?? 'Något gick fel.';
  }
}
```

💡 **Tips:** Meddelandet från en hook (`throw new BadRequestError("Du kan inte
gilla ditt eget inlägg.")` i kapitel 7) kommer fram i `e.response['message']`.
Skriv därför felmeddelanden i hooks på svenska och så att de kan visas direkt
för användaren.

## Ett komplett Dart-program

Spara som `bin/kvittra_cli.dart` i ett Dart-projekt med `pocketbase` som
beroende och kör med `dart run`:

```dart
import 'package:pocketbase/pocketbase.dart';

Future<void> main() async {
  final pb = PocketBase('http://127.0.0.1:8090');

  await pb.collection('users').authWithPassword('anna@example.com', 'hemligt123');
  final me = pb.authStore.record!;
  print('Inloggad som @${me.getStringValue('username')}');

  // Flödet
  final feed = await pb.collection('posts').getList(
    perPage: 20,
    sort: '-created',
    expand: 'author',
    filter: pb.filter('author.follows_via_following.follower ?= {:me}', {'me': me.id}),
  );
  for (final post in feed.items) {
    print('- ${post.getStringValue('title')} '
        '(av ${post.get<String>('expand.author.name', '?')})');
  }

  // Gilla det första inlägget – andra gången ger det unika indexet 400
  final first = feed.items.first;
  try {
    await pb.collection('likes').create(body: {'post': first.id, 'user': me.id});
    print('Gillade "${first.getStringValue('title')}"');
  } on ClientException catch (e) {
    final data = e.response['data'];
    if (e.statusCode == 400 && data is Map && data['post']?['code'] == 'validation_not_unique') {
      print('Du har redan gillat "${first.getStringValue('title')}".');
    } else {
      print('Kunde inte gilla: ${e.response['message']}');
    }
  }

  final liked = await pb.collection('posts').getList(
    filter: pb.filter('likes_via_post.user ?= {:me}', {'me': me.id}),
  );
  print('Du har gillat ${liked.totalItems} inlägg.');
}
```

Med testdatan från lösningarna skriver programmet ut ungefär:

```
Inloggad som @anna
- Kaffe eller te? (av Cecilia Ek)
- Surdegsbröd (av Cecilia Ek)
- Tips på löparrundor (av Bo Berg)
- Bästa kaffet i stan? (av Bo Berg)
Gillade "Kaffe eller te?"
Du har gillat 3 inlägg.
```

🧪 **Prova själv:** Kör programmet två gånger. Andra gången borde det unika
indexet slå till: "Du har redan gillat …". Kör det sedan med Davids
inloggning – vad blir skillnaden i flödet, och varför?

## Sammanfattning

- En `PocketBase`-instans för hela appen. Android-emulatorn når datorn via
  `10.0.2.2`.
- `create` på `users` registrerar, `authWithPassword` loggar in.
  `pb.authStore` håller token och `record`. `AsyncAuthStore` sparar
  inloggningen.
- `getList` (paginerat), `getFullList` (allt), `getOne`, `create`, `update`,
  `delete`. Gilla/följa = skapa/ta bort poster i `likes`/`follows`.
- Använd **alltid** `pb.filter('x = {:v}', {...})` för värden från användaren.
- Läs fält med `get<T>()`, även `expand.x.y`. Kapsla in det i `fromRecord`.
- `subscribe('*', cb, filter: ...)` för realtid – och glöm inte `unsubscribe`.
- Fånga `ClientException` och visa `response['data']` eller
  `response['message']`.

Nästa kapitel: [Hooks och migrationer](07-hooks-och-migrationer.md).

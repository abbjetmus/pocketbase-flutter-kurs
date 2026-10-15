# 06 – Testning

Tester är kod som kontrollerar att annan kod fungerar. De körs på några sekunder och
fångar fel innan användarna hittar dem. Flutter har tre sorters tester:

| Typ | Testar | Hastighet | Kapitel |
|-----|--------|-----------|---------|
| **Enhetstest** (unit test) | En funktion eller klass, utan UI | Millisekunder | Här |
| **Widgettest** | En widget eller skärm i en låtsasmiljö | Snabbt | Här |
| **Integrationstest** | Hela appen på en riktig enhet/emulator | Långsamt | Överkurs |

Tester ligger i mappen `test/`, filnamnen slutar på `_test.dart`, och de körs med:

```bash
flutter test                       # alla tester
flutter test test/models_test.dart # en fil
```

I VS Code kan du också klicka på *Run* ovanför varje test.

## Enhetstester

Ett test består av `test('beskrivning', () { ... })` och en eller flera
`expect(faktiskt, förväntat)`. Med `group` kan du samla relaterade tester.

Vi testar validatorerna från kapitel 04 och modellerna från kapitel 05.

```dart
// test/validators_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kvittra/validators.dart';

void main() {
  group('validateTitle', () {
    test('godkänner en vanlig titel', () {
      expect(validateTitle('Första fikat'), isNull);
    });

    test('nekar tom titel och bara mellanslag', () {
      expect(validateTitle(''), 'Titel krävs');
      expect(validateTitle('   '), 'Titel krävs');
      expect(validateTitle(null), 'Titel krävs');
    });

    test('nekar för kort och för lång titel', () {
      expect(validateTitle('Hj'), isNotNull);
      expect(validateTitle('x' * 81), 'Max 80 tecken');
    });
  });

  group('validateUsername', () {
    test('godkänner små bokstäver, siffror och understreck', () {
      expect(validateUsername('anna_83'), isNull);
    });

    test('nekar versaler, mellanslag och å/ä/ö', () {
      expect(validateUsername('Anna'), isNotNull);
      expect(validateUsername('anna lind'), isNotNull);
      expect(validateUsername('åsa'), isNotNull);
    });
  });

  test('validatePasswordConfirm jämför med lösenordet', () {
    expect(validatePasswordConfirm('hemligt123', 'hemligt123'), isNull);
    expect(validatePasswordConfirm('hemligt12', 'hemligt123'), 'Lösenorden matchar inte');
  });
}
```

```dart
// test/models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kvittra/models/post.dart';
import 'package:kvittra/models/user.dart';

void main() {
  test('Post.fromJson tolkar JSONPlaceholder-format', () {
    final post = Post.fromJson({
      'userId': 1,
      'id': 7,
      'title': 'Första fikat',
      'body': 'Kanelbullar till alla',
    });

    expect(post.id, 7);
    expect(post.userId, 1);
    expect(post.title, 'Första fikat');
  });

  group('User.fromJson', () {
    test('tolkar nästlade address och company', () {
      final user = User.fromJson({
        'id': 1,
        'name': 'Leanne Graham',
        'username': 'Bret',
        'email': 'Sincere@april.biz',
        'address': {'street': 'Kulas Light', 'city': 'Gwenborough'},
        'company': {'name': 'Romaguera-Crona'},
      });

      expect(user.handle, '@Bret');
      expect(user.address?.city, 'Gwenborough');
      expect(user.company?.name, 'Romaguera-Crona');
    });

    test('klarar sig utan nästlade objekt', () {
      final user = User.fromJson({
        'id': 2,
        'name': 'Anna Lind',
        'username': 'anna',
        'email': 'anna@example.com',
      });

      expect(user.address, isNull);
      expect(user.company, isNull);
      expect(user.website, isNull);
    });
  });
}
```

Användbara *matchers*: `isNull`, `isNotNull`, `isTrue`, `isFalse`, `equals(x)`,
`contains('text')`, `hasLength(3)`, `isEmpty`, `greaterThan(5)`, `throwsA(isA<FormatException>())`.

```dart
test('Post.fromJson kastar fel om id saknas', () {
  expect(() => Post.fromJson({'title': 'Utan id'}), throwsA(anything));
});
```

💡 **Tips:** Det är därför vi lägger validators och modeller i egna filer utan
Flutter-beroenden. Då blir de lätta att testa.

### Asynkrona tester och låtsas-HTTP

Att testa mot den riktiga JSONPlaceholder vore dumt: testerna skulle bli långsamma,
kräva internet och gå sönder om tjänsten ligger nere. `http`-paketet har en
`MockClient` som svarar med det du bestämmer, utan nätverk:

```dart
// test/jsonplaceholder_api_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kvittra/data/jsonplaceholder_api.dart';

/// Ett JSON-svar som är UTF-8-kodat, precis som från en riktig server.
http.Response jsonResponse(Object? body, int statusCode) => http.Response(
      jsonEncode(body),
      statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  test('fetchPosts anropar /posts och tolkar listan', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/posts');
      return jsonResponse([
        {'userId': 1, 'id': 1, 'title': 'Hej', 'body': 'Text'},
        {'userId': 2, 'id': 2, 'title': 'Hallå', 'body': 'Mer text'},
      ], 200);
    });

    final posts = await JsonPlaceholderApi(client: client).fetchPosts();

    expect(posts, hasLength(2));
    expect(posts.first.title, 'Hej');
    expect(posts.last.userId, 2);
  });

  test('fetchComments skickar postId som query-parameter', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/comments');
      expect(request.url.queryParameters, {'postId': '1'});
      return jsonResponse([
        {'postId': 1, 'id': 1, 'name': 'Rubrik', 'email': 'bo@example.com', 'body': 'Snyggt!'},
      ], 200);
    });

    final comments = await JsonPlaceholderApi(client: client).fetchComments(1);
    expect(comments.single.email, 'bo@example.com');
  });

  test('createPost skickar JSON och godtar 201 Created', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      final sent = jsonDecode(request.body) as Map<String, dynamic>;
      expect(sent['title'], 'Hej Kvittra');
      // Svara som JSONPlaceholder: samma data plus id 101
      return jsonResponse({...sent, 'id': 101}, 201);
    });

    final post = await JsonPlaceholderApi(client: client)
        .createPost(userId: 1, title: 'Hej Kvittra', body: 'Mitt första inlägg');

    expect(post.id, 101);
  });

  test('404 ger ApiException med statuskod', () async {
    final client = MockClient((_) async => jsonResponse({}, 404));
    expect(
      JsonPlaceholderApi(client: client).fetchPost(999),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404)),
    );
  });

  test('nätverksfel ger ett begripligt ApiException', () async {
    final client = MockClient((_) async => throw http.ClientException('offline'));
    expect(
      JsonPlaceholderApi(client: client).fetchPosts(),
      throwsA(isA<ApiException>()),
    );
  });
}
```

Det är därför `JsonPlaceholderApi` tog emot en `http.Client?` i konstruktorn: vi kan
skicka in en låtsasklient i testet. Det kallas **dependency injection**.

⚠️ **Varning:** `http.Response('...', 200)` utan headers kodar texten som
**Latin-1**, inte UTF-8. Innehåller svaret å, ä eller ö ("Hallå") kraschar då
`utf8.decode(response.bodyBytes)` i `_send` med `FormatException: Invalid UTF-8
byte`, trots att koden är rätt. Riktiga servrar skickar UTF-8, så testet ska också
göra det. Därför har vi hjälpfunktionen `jsonResponse` med
`charset=utf-8` i headern.

`isA<ApiException>().having(...)` kontrollerar både typen och ett fält på
undantaget. Bra när samma klass används för flera sorters fel.

## Widgettester

Ett widgettest bygger en widget i en testmiljö, utan riktig skärm, och låter dig
leta efter widgets, trycka på dem och kontrollera resultatet.

| Funktion | Gör |
|----------|-----|
| `testWidgets('...', (tester) async { ... })` | Definierar ett widgettest |
| `await tester.pumpWidget(widget)` | Bygger och ritar widgeten |
| `find.text('Publicera')` | Hittar widgets med en viss text |
| `find.textContaining('@anna')` | Hittar widgets vars text innehåller något |
| `find.byType(TextField)` | Hittar widgets av en viss typ |
| `find.byIcon(Icons.favorite)` | Hittar en ikon |
| `find.byKey(const Key('submit'))` | Hittar en widget med en viss key |
| `await tester.tap(finder)` | Trycker |
| `await tester.enterText(finder, 'text')` | Skriver i ett textfält |
| `await tester.pump()` | Ritar en bildruta till (efter `setState`) |
| `await tester.pumpAndSettle()` | Ritar tills alla animationer är klara (dialoger, navigation) |
| `expect(finder, findsOneWidget)` | Kontrollerar antal: `findsNothing`, `findsOneWidget`, `findsNWidgets(2)`, `findsWidgets` |

### Testa gilla-knappen från kapitel 03

```dart
// test/like_button_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvittra/widgets/like_button.dart';

void main() {
  testWidgets('LikeButton gillar och ogillar', (tester) async {
    // Widgets som behöver tema/Material måste ligga i en MaterialApp
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LikeButton(initialCount: 12))),
    );

    expect(find.text('12'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);

    await tester.tap(find.byType(LikeButton));
    await tester.pump(); // bygg om efter setState

    expect(find.text('13'), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsOneWidget);

    // Ett tryck till tar tillbaka gillningen
    await tester.tap(find.byType(LikeButton));
    await tester.pump();
    expect(find.text('12'), findsOneWidget);
  });
}
```

### Testa PostCard från kapitel 02

`PostCard` är stateless och tar emot en `FeedPost` och callbacks. Då testar vi två
saker: att den visar rätt data, och att den anropar rätt callback när man trycker.

```dart
// test/post_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvittra/models/feed_post.dart';
import 'package:kvittra/widgets/post_card.dart';

void main() {
  final post = FeedPost(
    id: 1,
    author: const Author(name: 'Anna Lind', username: 'anna'),
    title: 'Första fikat på nya kontoret',
    body: 'Kanelbullar till alla!',
    created: DateTime.now().subtract(const Duration(minutes: 5)),
    likeCount: 12,
    commentCount: 3,
  );

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('visar författare, initialer och titel', (tester) async {
    await tester.pumpWidget(wrap(PostCard(post: post)));

    expect(find.text('Anna Lind'), findsOneWidget);
    expect(find.text('AL'), findsOneWidget);
    expect(find.textContaining('@anna'), findsOneWidget);
    expect(find.text('Första fikat på nya kontoret'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('hjärtat anropar onLike', (tester) async {
    var likes = 0;
    await tester.pumpWidget(wrap(PostCard(post: post, onLike: () => likes++)));

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pump();

    expect(likes, 1);
  });
}
```

Lägg märke till att testet räknar anrop med en vanlig variabel (`likes++`). Kortet
behöver inte veta vad som händer vid en gillning, och det behöver inte testet heller.

### Testa ett formulär

```dart
testWidgets('nytt inlägg visar fel när titeln är tom', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: NewPostScreen()));

  await tester.tap(find.text('Publicera'));
  await tester.pump();

  expect(find.text('Titel krävs'), findsOneWidget);
  expect(find.text('Skriv något'), findsOneWidget);
});

testWidgets('för kort titel ger fel', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: NewPostScreen()));

  await tester.enterText(find.widgetWithText(TextFormField, 'Titel'), 'Hj');
  await tester.tap(find.text('Publicera'));
  await tester.pump();

  expect(find.text('Minst 3 tecken'), findsOneWidget);
});
```

`find.widgetWithText(TextFormField, 'Titel')` hittar det `TextFormField` som har
etiketten "Titel", så att vi skriver i rätt fält när det finns flera.

⚠️ **Varning:** Glömmer du `await tester.pump()` efter ett `tap` ser testet det
*gamla* UI:t, och `expect` misslyckas trots att koden fungerar.

⚠️ **Varning:** Om en `find.text(...)` hittar flera widgets (t.ex. "Publicera" både
i AppBar och på en knapp) misslyckas `tap`. Använd en `Key` på knappen:
`FilledButton(key: const Key('submit'), ...)` och `find.byKey(const Key('submit'))`.

### Testa en skärm som hämtar data

Skärmar som hämtar data testar du lättast genom att skicka in en låtsasversion av
datalagret. Det kräver att skärmen tar emot sitt `JsonPlaceholderApi` i
konstruktorn i stället för att skapa det själv, precis som `FeedScreen` i
kapitel 05:

```dart
// Ärver det riktiga API:t men skriver över metoderna vi behöver.
// Ingen http-anrop görs, eftersom metoderna aldrig når _send.
class FakeApi extends JsonPlaceholderApi {
  @override
  Future<List<Post>> fetchPosts() async => const [
        Post(id: 1, userId: 1, title: 'Testinlägg', body: 'Hej från testet'),
      ];

  @override
  Future<List<User>> fetchUsers() async => const [
        User(id: 1, name: 'Anna Lind', username: 'anna', email: 'anna@example.com'),
      ];
}

class FailingApi extends JsonPlaceholderApi {
  @override
  Future<List<Post>> fetchPosts() async => throw ApiException('Kunde inte nå servern');

  @override
  Future<List<User>> fetchUsers() async => const [];
}

testWidgets('visar flödet efter laddning', (tester) async {
  await tester.pumpWidget(MaterialApp(home: FeedScreen(api: FakeApi())));

  expect(find.byType(CircularProgressIndicator), findsOneWidget);
  await tester.pumpAndSettle(); // vänta tills Future är klar och UI ombyggt
  expect(find.text('Testinlägg'), findsOneWidget);
  expect(find.textContaining('@anna'), findsOneWidget);
});

testWidgets('visar fel och Försök igen', (tester) async {
  await tester.pumpWidget(MaterialApp(home: FeedScreen(api: FailingApi())));
  await tester.pumpAndSettle();

  expect(find.text('Kunde inte nå servern'), findsOneWidget);
  expect(find.text('Försök igen'), findsOneWidget);
});
```

💡 **Tips:** I widgettester är riktiga nätverksanrop avstängda: varje HTTP-anrop
får statuskod 400. Ser du konstiga 400-fel i ett test har du glömt att byta ut
datalagret mot en låtsasversion.

💡 **Tips:** Paket som [`mocktail`](https://pub.dev/packages/mocktail) gör det
enklare att skapa låtsasobjekt när du har många metoder.

## Sammanfattning

- Lägg logik (validators, modeller, datalager) i rena Dart-filer och enhetstesta dem.
- Skicka in beroenden (`http.Client`, `JsonPlaceholderApi`) via konstruktorn så att
  de kan bytas mot låtsasversioner i tester.
- `MockClient` låter dig testa JSON-tolkning, URL:er och felhantering utan nätverk.
- Widgettester: `pumpWidget` → `find` → `tap`/`enterText` → `pump` → `expect`.

🧪 **Prova själv:** Skriv ett widgettest för `PostCard` som kontrollerar att
pratbubblan anropar `onComment`, och att ett gillat inlägg (`liked: true`) visar
`Icons.favorite` men inte `Icons.favorite_border`. Skriv sedan ett test för
`ProfileHeader` som kontrollerar att knappen heter "Följer" när
`isFollowing: true`.

**Vidare:** [Övningar](ovningar.md)

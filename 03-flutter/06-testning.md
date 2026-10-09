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

Vi testar `Post.fromJson` från kapitel 05 och validatorerna från kapitel 04.

```dart
// lib/validators.dart
String? validateRequired(String? value) =>
    (value == null || value.trim().isEmpty) ? 'Fältet måste fyllas i' : null;

String? validateGuests(String? value) {
  final n = int.tryParse(value ?? '');
  if (n == null) return 'Ange ett heltal';
  if (n < 1 || n > 40) return 'Mellan 1 och 40 gäster';
  return null;
}
```

```dart
// test/validators_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:forening_app/models/post.dart';
import 'package:forening_app/validators.dart';

void main() {
  group('validateGuests', () {
    test('godkänner ett tal inom gränserna', () {
      expect(validateGuests('25'), isNull);
    });

    test('nekar text som inte är ett tal', () {
      expect(validateGuests('många'), 'Ange ett heltal');
    });

    test('nekar för många gäster', () {
      expect(validateGuests('41'), isNotNull);
      expect(validateGuests('0'), isNotNull);
    });
  });

  group('validateRequired', () {
    test('nekar tom sträng och bara mellanslag', () {
      expect(validateRequired(''), isNotNull);
      expect(validateRequired('   '), isNotNull);
      expect(validateRequired(null), isNotNull);
    });
  });

  group('Post.fromJson', () {
    test('tolkar ett PocketBase-svar', () {
      final post = Post.fromJson({
        'id': 'p1',
        'title': 'Vårstädning',
        'body': 'Lördag kl 10',
        'author': 'u1',
        'published': true,
        'created': '2026-04-01 10:00:00.000Z',
      });

      expect(post.title, 'Vårstädning');
      expect(post.published, isTrue);
      expect(post.created.month, 4);
    });

    test('ger standardvärden när fält saknas', () {
      final post = Post.fromJson({'id': 'p2', 'created': '2026-04-01 10:00:00.000Z'});
      expect(post.title, '');
      expect(post.published, isFalse);
    });
  });
}
```

Användbara *matchers*: `isNull`, `isNotNull`, `isTrue`, `isFalse`, `equals(x)`,
`contains('text')`, `hasLength(3)`, `isEmpty`, `greaterThan(5)`, `throwsA(isA<FormatException>())`.

```dart
test('fromJson kastar fel om created saknas', () {
  expect(() => Post.fromJson({'id': 'x'}), throwsA(anything));
});
```

💡 **Tips:** Det är därför vi lägger validators och modeller i egna filer utan
Flutter-beroenden. Då blir de lätta att testa.

### Asynkrona tester och låtsas-HTTP

`http`-paketet har en `MockClient` som låter dig testa `PostService` utan nätverk:

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:forening_app/services/post_service.dart';

void main() {
  test('fetchPosts tolkar items-listan', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/collections/posts/records');
      return http.Response(
        jsonEncode({
          'items': [
            {'id': 'p1', 'title': 'Hej', 'created': '2026-01-01 00:00:00.000Z'},
          ],
        }),
        200,
      );
    });

    final service = PostService(client: client);
    final posts = await service.fetchPosts();

    expect(posts, hasLength(1));
    expect(posts.first.title, 'Hej');
  });

  test('fetchPosts kastar ApiException vid 500', () async {
    final client = MockClient((_) async => http.Response('fel', 500));
    expect(PostService(client: client).fetchPosts(), throwsA(isA<ApiException>()));
  });
}
```

Det är därför `PostService` tog emot en `http.Client?` i konstruktorn: vi kan skicka
in en låtsasklient i testet. Det kallas **dependency injection**.

## Widgettester

Ett widgettest bygger en widget i en testmiljö, utan riktig skärm, och låter dig
leta efter widgets, trycka på dem och kontrollera resultatet.

| Funktion | Gör |
|----------|-----|
| `testWidgets('...', (tester) async { ... })` | Definierar ett widgettest |
| `await tester.pumpWidget(widget)` | Bygger och ritar widgeten |
| `find.text('Boka')` | Hittar widgets med en viss text |
| `find.byType(TextField)` | Hittar widgets av en viss typ |
| `find.byIcon(Icons.add)` | Hittar en ikon |
| `find.byKey(const Key('submit'))` | Hittar en widget med en viss key |
| `await tester.tap(finder)` | Trycker |
| `await tester.enterText(finder, 'text')` | Skriver i ett textfält |
| `await tester.pump()` | Ritar en bildruta till (efter `setState`) |
| `await tester.pumpAndSettle()` | Ritar tills alla animationer är klara (dialoger, navigation) |
| `expect(finder, findsOneWidget)` | Kontrollerar antal: `findsNothing`, `findsOneWidget`, `findsNWidgets(2)`, `findsWidgets` |

### Testa räknaren från kapitel 03

```dart
// test/hours_picker_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forening_app/widgets/hours_picker.dart';

void main() {
  testWidgets('HoursPicker ökar och stannar vid max', (tester) async {
    // Widgets som behöver tema/Material måste ligga i en MaterialApp
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HoursPicker(maxHours: 2))),
    );

    expect(find.text('1 h'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump(); // bygg om efter setState

    expect(find.text('2 h'), findsOneWidget);
    expect(find.text('1 h'), findsNothing);

    // Vid max är +-knappen inaktiverad. Ett tryck ska inte göra något
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('2 h'), findsOneWidget);
  });
}
```

### Testa ett formulär

```dart
testWidgets('bokningsformuläret visar fel när resurs saknas', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: BookingFormScreen()));

  await tester.tap(find.text('Boka'));
  await tester.pump();

  expect(find.text('Välj en resurs'), findsOneWidget);
});

testWidgets('för lång notering ger fel', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: BookingFormScreen()));

  await tester.enterText(find.byType(TextFormField), 'x' * 101);
  await tester.tap(find.text('Boka'));
  await tester.pump();

  expect(find.text('Max 100 tecken'), findsOneWidget);
});
```

⚠️ **Varning:** Glömmer du `await tester.pump()` efter ett `tap` ser testet det
*gamla* UI:t, och `expect` misslyckas trots att koden fungerar.

⚠️ **Varning:** Om en `find.text(...)` hittar flera widgets (t.ex. "Boka" både i
AppBar och på en knapp) misslyckas `tap`. Använd en `Key` på knappen:
`FilledButton(key: const Key('submit'), ...)` och `find.byKey(const Key('submit'))`.

### Testa en skärm som hämtar data

Skärmar som hämtar data testar du lättast genom att skicka in ett låtsas-repository.
Det kräver att skärmen tar emot sitt repository i konstruktorn i stället för att
skapa det själv:

```dart
// Ärver det riktiga repositoryt men skriver över metoden vi behöver.
// PocketBase-klienten pekar på en adress som aldrig anropas.
class FakePostRepository extends PostRepository {
  FakePostRepository() : super(PocketBase('http://test.invalid'));

  @override
  Future<List<Post>> fetchPublished() async => [
        Post(id: '1', title: 'Testanslag', body: '', authorId: 'u',
            published: true, created: DateTime(2026)),
      ];
}

testWidgets('visar anslag efter laddning', (tester) async {
  await tester.pumpWidget(
    MaterialApp(home: PostListScreen(repository: FakePostRepository())),
  );

  expect(find.byType(CircularProgressIndicator), findsOneWidget);
  await tester.pumpAndSettle(); // vänta tills Future är klar och UI ombyggt
  expect(find.text('Testanslag'), findsOneWidget);
});
```

💡 **Tips:** Paket som [`mocktail`](https://pub.dev/packages/mocktail) gör det
enklare att skapa låtsasobjekt när du har många metoder.

## Sammanfattning

- Lägg logik (validators, modeller, tjänster) i rena Dart-filer och enhetstesta dem.
- Skicka in beroenden (`http.Client`, repositories) via konstruktorn så att de kan
  bytas mot låtsasversioner i tester.
- Widgettester: `pumpWidget` → `find` → `tap`/`enterText` → `pump` → `expect`.

🧪 **Prova själv:** Skriv ett widgettest för `ResourceCard` från kapitel 02 som
kontrollerar att "Boka"-knappen anropar `onBook` när resursen är aktiv, och att den
är inaktiverad (`tester.widget<FilledButton>(...).onPressed == null`) när
`active: false`.

**Vidare:** [Övningar](ovningar.md)

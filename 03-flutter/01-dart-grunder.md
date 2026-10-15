# 01 – Dart-grunder

Flutter-appar skrivs i **Dart**, ett språk från Google. Om du kan lite JavaScript
känner du igen dig: syntaxen liknar JS/TypeScript, men Dart är **statiskt typat**
och har **null safety** inbyggt. Det betyder att många fel upptäcks redan när du
skriver koden, inte när appen kraschar hos användaren.

Du kan testa alla exempel i det här kapitlet utan Flutter:

- i webbläsaren på <https://dartpad.dev>, eller
- lokalt: skapa filen `exempel.dart` och kör `dart run exempel.dart`.

Varje Dart-program startar i funktionen `main`:

```dart
void main() {
  print('Hej Kvittra!');
}
```

## Variabler: `var`, `final` och `const`

```dart
void main() {
  var gillningar = 3;          // typen (int) räknas ut automatiskt
  gillningar = 4;              // OK, var kan ändras
  // gillningar = 'fyra';      // FEL: gillningar är en int

  final anvandarnamn = 'anna'; // kan bara tilldelas en gång
  // anvandarnamn = 'bo';      // FEL

  const maxTecken = 280;       // kompileringstidskonstant
  final nu = DateTime.now();   // OK med final, värdet räknas ut när programmet kör
  // const nu2 = DateTime.now(); // FEL: inte känt vid kompilering

  String bio = 'Gillar fika och Flutter'; // explicit typ
  print('@$anvandarnamn: $bio ($gillningar gillningar, max $maxTecken tecken, $nu)');
}
```

| Dart | JavaScript | Betydelse |
|------|-----------|-----------|
| `var x = 1;` | `let x = 1;` | kan ändras |
| `final x = 1;` | `const x = 1;` | kan inte tilldelas om |
| `const x = 1;` | (finns inte) | värdet är känt redan vid kompilering, och är djupt oföränderligt |

💡 **Tips:** Använd `final` som standard och `var` bara när värdet faktiskt
ändras. I Flutter används `const` flitigt på widgets (`const Text('Hej')`), eftersom
Flutter då kan återanvända samma objekt och slipper bygga om det.

## Grundtyper

```dart
int foljare = 128;
double snittGillningar = 4.5;
num tal = 5;          // int eller double
bool gillad = true;
String anvandarnamn = 'anna';
DateTime skapad = DateTime(2026, 3, 14, 18, 0);
Duration sedan = const Duration(minutes: 42);
dynamic vadSomHelst = 'undvik detta'; // stänger av typkontrollen
```

Konvertering görs med metoder, inte med magi som i JS:

```dart
final n = int.parse('42');          // 42
final m = int.tryParse('abc');      // null i stället för krasch
final s = 3.14159.toStringAsFixed(2); // '3.14'
final t = 7.toString();             // '7'
```

⚠️ **Varning:** I JavaScript blir `'5' + 1` till `'51'`. I Dart får du ett
kompileringsfel. Det är en fördel!

## Null safety

I Dart kan en variabel **inte** vara `null` om du inte uttryckligen säger det med
ett frågetecken efter typen.

```dart
String namn = 'Anna Lind';
// namn = null;            // FEL: String kan inte vara null

String? webbplats;         // String? = "String eller null". Startar som null
webbplats = 'anna.example.com';
webbplats = null;          // OK
```

Verktygen för att jobba med nullbara värden:

```dart
void visaProfil(String? bio) {
  // 1. Kontroll med if. Efter kontrollen vet Dart att bio inte är null
  if (bio != null) {
    print(bio.length); // OK
  }

  // 2. ?. – anropa bara om inte null (ger null annars)
  final langd = bio?.length; // int?

  // 3. ?? – reservvärde om null
  final text = bio ?? 'Ingen bio ännu';

  // 4. ??= – tilldela bara om variabeln är null
  String? cache;
  cache ??= 'första värdet';

  // 5. ! – "jag lovar att det inte är null". Kraschar om du har fel!
  final versaler = bio!.toUpperCase();

  print('$langd $text $cache $versaler');
}
```

⚠️ **Varning:** `!` stänger av säkerheten. Om värdet ändå är `null` kraschar appen
med `Null check operator used on a null value`, ett av de vanligaste felen i
Flutter. Föredra `if`, `?.` och `??`.

### `late`

`late` betyder "den här variabeln är inte null, men jag tilldelar den lite senare".
Du ser det ofta i Flutter för controllers som skapas i `initState` (kapitel 03).

```dart
class ProfilSkarm {
  late final String anvandarnamn; // tilldelas senare, men bara en gång

  void init() {
    anvandarnamn = 'anna';
  }
}
```

Om du läser en `late`-variabel innan den har fått ett värde får du ett körfel
(`LateInitializationError`).

## Strängar

```dart
final anvandarnamn = 'anna';
final gillningar = 12;

print('Inlägg av @$anvandarnamn');                 // enkel variabel
print('${gillningar + 1} personer gillar detta');  // uttryck kräver {}
print('Namnet har ${anvandarnamn.length} tecken');

final flerrader = '''
Välkommen till Kvittra!
Följ några konton för att fylla ditt flöde.
''';

final rad = 'Kvitt' + 'ra';  // fungerar, men interpolation är vanligare
final ra = r'C:\temp\$inte_variabel'; // r = raw string, ingen interpolation
```

⚠️ **Varning:** Identifierare (variabel-, funktions- och klassnamn) i Dart får
bara innehålla engelska bokstäver, siffror, `_` och `$`. Därför skriver vi
`antalFoljare` och inte `antalFöljare`, och `inlagg` i stället för `inlägg`. I
strängar går det förstås bra med å, ä och ö.

Användbara metoder: `toUpperCase()`, `trim()`, `contains()`, `startsWith()`,
`split(',')`, `replaceAll('a', 'b')`, `isEmpty`, `isNotEmpty`, `padLeft(2, '0')`.

💡 **Tips:** Dart accepterar både `'enkla'` och `"dubbla"` citattecken. Flutter-
världen använder oftast enkla.

## Samlingar: List, Map och Set

```dart
// List – ordnad lista (som Array i JS)
final anvandare = <String>['anna', 'bo'];
anvandare.add('cecilia');
print(anvandare[0]);      // anna
print(anvandare.length);  // 3

// Map – nyckel/värde (som ett objekt eller Map i JS)
final gillningarPerInlagg = <int, int>{1: 12, 2: 0};
gillningarPerInlagg[3] = 5;
print(gillningarPerInlagg[1]);   // 12
print(gillningarPerInlagg[99]);  // null – därför är typen int?

// Set – unika värden
final hashtaggar = <String>{'#flutter', '#fika', '#flutter'};
print(hashtaggar);        // {#flutter, #fika}
```

### Funktionella metoder

Samma idéer som `map`/`filter`/`reduce` i JavaScript:

```dart
final gillningar = [12, 0, 5, 30];

final dubbla = gillningar.map((g) => g * 2).toList();     // [24, 0, 10, 60]
final populara = gillningar.where((g) => g >= 10).toList(); // [12, 30]  (filter i JS)
final summa = gillningar.fold(0, (sum, g) => sum + g);    // 47        (reduce i JS)
final nagonViral = gillningar.any((g) => g > 25);         // true      (some i JS)
final allaUnder100 = gillningar.every((g) => g < 100);    // true
final forstaGillade = gillningar.firstWhere((g) => g > 0); // 12
```

⚠️ **Varning:** `map` och `where` returnerar en *lat* `Iterable`, inte en `List`.
Glöm inte `.toList()` när du behöver en lista.

### Spread, collection-if och collection-for

Det här används hela tiden i Flutter för att bygga listor av widgets.

```dart
final flikar = ['Flöde', 'Sök'];
final arInloggad = true;

final meny = [
  ...flikar,                          // spread, som ... i JS
  if (arInloggad) 'Min profil',       // collection-if
  for (final n in [1, 2]) 'Förslag $n', // collection-for
];
print(meny);
// [Flöde, Sök, Min profil, Förslag 1, Förslag 2]

List<String>? kanskeNull;
final saker = [...?kanskeNull, 'Inställningar']; // ...? hoppar över null
```

## Funktioner

```dart
// Vanlig funktion med typer
int lastidSekunder(int antalOrd) {
  return (antalOrd / 200 * 60).round(); // ca 200 ord per minut
}

// Pilfunktion (arrow) för ett enda uttryck
String handle(String anvandarnamn) => '@$anvandarnamn';

// Valfria positionella parametrar med []
String halsa(String namn, [String? halsning]) =>
    '${halsning ?? 'Hej'} $namn';

// Namngivna parametrar med {} – standard i Flutter
String inlaggsRubrik({
  required String forfattare, // måste anges
  int gillningar = 0,         // standardvärde
  String? plats,              // valfri, kan vara null
}) {
  final extra = plats == null ? '' : ' i $plats';
  return '$forfattare$extra · $gillningar gillningar';
}

void main() {
  print(halsa('Anna'));                    // Hej Anna
  print(halsa('Anna', 'Tjena'));           // Tjena Anna
  print(inlaggsRubrik(forfattare: 'Anna', gillningar: 12));
  print(inlaggsRubrik(plats: 'Malmö', forfattare: 'Bo'));
}
```

Namngivna parametrar kan anges i valfri ordning och gör anropet självförklarande.
Det är därför Flutter-widgets ser ut som `Text('Hej', style: ..., maxLines: 2)`.

Funktioner är värden och kan skickas som argument, precis som i JS:

```dart
void utforTvaGanger(void Function() handling) {
  handling();
  handling();
}

void main() {
  utforTvaGanger(() => print('Kvitt!'));
}
```

`void Function()` är typen "en funktion som inte tar några argument och inte
returnerar något". I Flutter heter den `VoidCallback` och används för `onPressed`.

## Klasser

Låt oss modellera ett inlägg. JSON-nycklarna är samma som i JSONPlaceholder
(`userId`, `id`, `title`, `body`), som vi hämtar riktig data från i kapitel 05.
Utöver dem har vi två fält som appen själv håller reda på: hur många som gillar
inlägget och om *du* gillar det.

```dart
class Post {
  // Fält. final = kan inte ändras efter att objektet skapats
  final int id;
  final int userId;
  final String title;
  final String body;
  final int likeCount;
  final bool liked;

  // Konstruktor med namngivna parametrar. this.x tilldelar fältet direkt
  const Post({
    required this.id,
    required this.userId,
    required this.title,
    this.body = '',
    this.likeCount = 0,
    this.liked = false,
  });

  // Namngiven konstruktor: ett tomt utkast som ännu inte har fått något id
  const Post.draft({required this.userId, required this.title})
      : id = 0,
        body = '',
        likeCount = 0,
        liked = false;

  // factory-konstruktor: skapar objekt från JSON (t.ex. från ett API)
  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as int,
      userId: json['userId'] as int,
      title: json['title'] as String,
      body: json['body'] as String? ?? '',
      // Finns inte i JSONPlaceholder, så vi har reservvärden
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      liked: json['liked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'title': title,
        'body': body,
      };

  // Getters – beräknade värden som ser ut som fält
  String get preview => body.length > 40 ? '${body.substring(0, 40)}…' : body;
  String get likeLabel => likeCount == 1 ? '1 gillning' : '$likeCount gillningar';

  // copyWith – skapa en kopia med vissa fält ändrade
  Post copyWith({String? title, String? body, int? likeCount, bool? liked}) {
    return Post(
      id: id,
      userId: userId,
      title: title ?? this.title,
      body: body ?? this.body,
      likeCount: likeCount ?? this.likeCount,
      liked: liked ?? this.liked,
    );
  }

  // Gilla/ogilla: en ny kopia, originalet ändras inte
  Post toggleLike() => copyWith(
        liked: !liked,
        likeCount: liked ? likeCount - 1 : likeCount + 1,
      );

  @override
  String toString() => 'Post($id, "$title", $likeLabel)';
}

void main() {
  final json = {
    'userId': 1,
    'id': 1,
    'title': 'Första fikat på nya kontoret',
    'body': 'Kanelbullar till alla som kommer före nio!',
  };

  final post = Post.fromJson(json);
  final gillad = post.toggleLike();

  print(post);           // Post(1, "Första fikat på nya kontoret", 0 gillningar)
  print(gillad);         // Post(1, "Första fikat på nya kontoret", 1 gillning)
  print(gillad.liked);   // true
  print(post.liked);     // false – originalet är oförändrat
  print(post.preview);   // Kanelbullar till alla som kommer före ni…
}
```

Några saker att lägga märke till:

- Dart har inget `new`-nyckelord (det är valfritt och används inte).
- Med bara `final`-fält blir objektet **oföränderligt** (immutable). I stället för
  att ändra ett objekt skapar du en ny kopia med `copyWith`. `toggleLike` gör just
  det. Flutter bygger mycket på den idén.
- `factory` används när konstruktorn behöver göra något mer än att bara tilldela
  fält, till exempel tolka JSON.
- `as String` är en typomvandling ("cast"). Den kraschar om värdet har fel typ, så
  `fromJson` är ett bra ställe att vara noggrann.

💡 **Tips:** Privata medlemmar börjar med understreck: `_hemlig`. De syns bara
inom samma fil (inte samma klass som i Java). Det finns inga `public`/`private`-
nyckelord.

### Arv och abstrakta klasser

```dart
abstract class Entity {
  int get id;
}

class User extends Entity {
  @override
  final int id;
  final String name;
  final String username;
  final String email;

  User({required this.id, required this.name, required this.username, required this.email});

  String get handle => '@$username';
}
```

Du kommer att använda `extends` mest för att skapa widgets
(`extends StatelessWidget`).

## Enums

En enum är en fast uppsättning värden. Dart har *enhanced enums*, som kan ha fält
och metoder. Här är de tre flikarna överst i Kvittras flöde:

```dart
enum FeedFilter {
  all('Alla'),
  following('Följer'),
  mine('Mina');

  const FeedFilter(this.label);
  final String label;

  bool get requiresLogin => this != all;

  static FeedFilter fromString(String value) => FeedFilter.values
      .firstWhere((f) => f.name == value, orElse: () => FeedFilter.all);
}

void main() {
  final filter = FeedFilter.fromString('following');
  print(filter.label);         // Följer
  print(filter.name);          // following
  print(filter.requiresLogin); // true
}
```

## Records och destrukturering

Ett **record** är ett litet anonymt "paket" med värden, praktiskt när en funktion
vill returnera mer än en sak.

```dart
(int likes, int comments) rakna(List<Map<String, int>> inlagg) {
  var likes = 0;
  var comments = 0;
  for (final p in inlagg) {
    likes += p['likes'] ?? 0;
    comments += p['comments'] ?? 0;
  }
  return (likes, comments);
}

({int followers, int following}) profilSiffror() => (followers: 128, following: 87);

void main() {
  final (likes, comments) = rakna([
    {'likes': 12, 'comments': 3},
    {'likes': 5, 'comments': 0},
  ]);
  print('$likes gillningar, $comments kommentarer'); // 17 gillningar, 3 kommentarer

  final siffror = profilSiffror();
  print(siffror.followers);    // fält med namn

  final (:followers, :following) = siffror; // destrukturera namngivna fält
  print(followers - following); // 41
}
```

Jämför med JavaScript: `const [likes, comments] = ...` och
`const { followers, following } = ...`.

## Patterns och switch-uttryck

Dart 3 har kraftfulla **patterns**. `switch` kan användas som ett *uttryck* som
returnerar ett värde:

```dart
String gillaText(int likes) => switch (likes) {
      0 => 'Bli först att gilla',
      1 => '1 person gillar detta',
      >= 2 && <= 99 => '$likes personer gillar detta',
      _ => '99+ personer gillar detta', // _ = allt annat
    };

String tomtFlode(FeedFilter filter) => switch (filter) {
      FeedFilter.all => 'Inga inlägg ännu',
      FeedFilter.following || FeedFilter.mine => 'Inget här – följ någon eller skriv något!',
    };
```

Eftersom `FeedFilter` är en enum vet Dart vilka värden som finns. Glömmer du ett
fall får du ett **kompileringsfel**. Det är mycket säkrare än `switch` i JS.

Patterns fungerar också på JSON (maps), vilket gör tolkning både kortare och säkrare:

```dart
String? hamtaHandle(Map<String, dynamic> json) {
  if (json case {'username': String namn, 'email': String _}) {
    return '@$namn'; // matchar bara om username OCH email finns och är strängar
  }
  return null;
}
```

## Sealed classes

En `sealed class` är en basklass där alla subklasser måste ligga i samma fil.
Då vet Dart exakt vilka varianter som finns, och `switch` kan kontrollera att du
har hanterat alla. Det är perfekt för att beskriva **tillstånd**, till exempel när
data laddas från nätet:

```dart
sealed class LoadState<T> {}

class Loading<T> extends LoadState<T> {}

class Loaded<T> extends LoadState<T> {
  Loaded(this.data);
  final T data;
}

class Failed<T> extends LoadState<T> {
  Failed(this.message);
  final String message;
}

String beskriv(LoadState<List<String>> state) => switch (state) {
      Loading() => 'Laddar flödet...',
      Loaded(data: final lista) when lista.isEmpty => 'Inga inlägg',
      Loaded(:final data) => '${data.length} inlägg',
      Failed(:final message) => 'Fel: $message',
    };

void main() {
  print(beskriv(Loading()));
  print(beskriv(Loaded(['Första fikat på nya kontoret'])));
  print(beskriv(Failed('Ingen uppkoppling')));
}
```

Vi använder exakt det här mönstret i kapitel 05 för att visa laddning, fel och data.

## Asynkron kod: Future, async/await och Stream

Allt som tar tid, som nätverksanrop, filer eller databaser, är **asynkront** i Dart.

- En `Future<T>` är ett värde av typen `T` som kommer *senare*, som ett `Promise`
  i JavaScript.
- `async`/`await` fungerar som i JS.

```dart
Future<List<String>> hamtaInlagg() async {
  // Låtsas att vi väntar på nätverket
  await Future.delayed(const Duration(seconds: 1));
  return ['Första fikat på nya kontoret', 'Tips: Flutter DevTools'];
}

Future<void> main() async {
  print('Hämtar...');
  try {
    final inlagg = await hamtaInlagg();
    print('Fick: $inlagg');
  } catch (e) {
    print('Något gick fel: $e');
  } finally {
    print('Klart');
  }
}
```

| JavaScript | Dart |
|-----------|------|
| `Promise<T>` | `Future<T>` |
| `async function f()` | `Future<void> f() async` |
| `Promise.all([a, b])` | `Future.wait([a, b])` |
| `.then(x => ...)` | `.then((x) => ...)` |

⚠️ **Varning:** Glömmer du `await` får du en `Future` i stället för värdet. Dart
varnar ofta, men inte alltid. Om du ser `Instance of 'Future<...>'` i en utskrift
har du glömt `await`.

En `Stream<T>` är en *ström* av värden över tid, till exempel nya kommentarer som
kommer i realtid från PocketBase:

```dart
Stream<int> nedrakning(int fran) async* {
  for (var i = fran; i > 0; i--) {
    await Future.delayed(const Duration(milliseconds: 500));
    yield i; // skicka ut ett värde
  }
}

Future<void> main() async {
  await for (final tal in nedrakning(3)) {
    print(tal); // 3, 2, 1
  }

  // Eller lyssna med en callback
  final sub = nedrakning(2).listen((tal) => print('Lyssnare: $tal'));
  await Future.delayed(const Duration(seconds: 2));
  await sub.cancel(); // sluta lyssna – viktigt i appar!
}
```

## Paket och imports

```dart
import 'dart:convert';                    // från Darts standardbibliotek
import 'dart:math' as math;               // med prefix
import 'package:http/http.dart' as http;  // från ett paket i pubspec.yaml
import 'package:kvittra/models/post.dart'; // från ditt eget projekt
import 'models/comment.dart';             // relativ sökväg i projektet

void main() {
  final json = jsonEncode({'title': 'Hej Kvittra'});
  print(json);
  print(math.max(3, 7));
}
```

Paket hittar du på <https://pub.dev>. Lägg till dem med `dart pub add <namn>`
(eller `flutter pub add` i ett Flutter-projekt).

## Sammanfattning

- Använd `final` som standard, `var` när något ändras och `const` för konstanter.
- `String?` kan vara null, `String` kan inte. Undvik `!`.
- Samlingar har `map`/`where`/`fold`, och listor kan byggas med spread, `if` och `for`.
- Namngivna parametrar (`{required ...}`) används överallt i Flutter.
- Modellklasser har `final`-fält, `fromJson`, `toJson` och `copyWith`.
- Enums, records, patterns och sealed classes gör koden säker och uttrycksfull.
- `Future` + `async`/`await` för saker som tar tid, `Stream` för flera värden över tid.

🧪 **Prova själv:** Skriv en klass `Comment` med samma fält som en kommentar i
JSONPlaceholder: `id` (int), `postId` (int), `name`, `email` och `body`. Lägg till
`fromJson`, en getter `wordCount` (antal ord i `body`, använd `split`) och en getter
`emailUser` (delen före `@` i e-postadressen). Skapa några kommentarer från
JSON-maps i `main` och skriv ut de som har fler än fem ord.

**Nästa kapitel:** [02 – Widgets och layout](02-widgets-och-layout.md)

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
  print('Hej föreningen!');
}
```

## Variabler: `var`, `final` och `const`

```dart
void main() {
  var antal = 3;            // typen (int) räknas ut automatiskt
  antal = 4;                // OK, var kan ändras
  // antal = 'fyra';        // FEL: antal är en int

  final namn = 'Tvättstuga 1'; // kan bara tilldelas en gång
  // namn = 'Festlokalen';  // FEL

  const maxTimmar = 3;      // kompileringstidskonstant
  final nu = DateTime.now(); // OK med final, värdet räknas ut när programmet kör
  // const nu2 = DateTime.now(); // FEL: inte känt vid kompilering

  String beskrivning = 'Källaren, hus B'; // explicit typ
  print('$namn: $beskrivning, max $maxTimmar h, antal $antal, $nu');
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
int vaning = 3;
double storlek = 74.5;
num tal = 5;          // int eller double
bool aktiv = true;
String nummer = '1102';
DateTime start = DateTime(2026, 3, 14, 18, 0);
Duration langd = const Duration(hours: 2);
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
String namn = 'Festlokalen';
// namn = null;            // FEL: String kan inte vara null

String? notering;          // String? = "String eller null". Startar som null
notering = 'Ta med egen duk';
notering = null;           // OK
```

Verktygen för att jobba med nullbara värden:

```dart
void visaBokning(String? notering) {
  // 1. Kontroll med if. Efter kontrollen vet Dart att notering inte är null
  if (notering != null) {
    print(notering.length); // OK
  }

  // 2. ?. – anropa bara om inte null (ger null annars)
  final langd = notering?.length; // int?

  // 3. ?? – reservvärde om null
  final text = notering ?? 'Ingen notering';

  // 4. ??= – tilldela bara om variabeln är null
  String? cache;
  cache ??= 'första värdet';

  // 5. ! – "jag lovar att det inte är null". Kraschar om du har fel!
  final saker = notering!.toUpperCase();

  print('$langd $text $cache $saker');
}
```

⚠️ **Varning:** `!` stänger av säkerheten. Om värdet ändå är `null` kraschar appen
med `Null check operator used on a null value`, ett av de vanligaste felen i
Flutter. Föredra `if`, `?.` och `??`.

### `late`

`late` betyder "den här variabeln är inte null, men jag tilldelar den lite senare".
Du ser det ofta i Flutter för controllers som skapas i `initState` (kapitel 03).

```dart
class BokningsSkarm {
  late final String resursNamn; // tilldelas senare, men bara en gång

  void init() {
    resursNamn = 'Tvättstuga 1';
  }
}
```

Om du läser en `late`-variabel innan den har fått ett värde får du ett körfel
(`LateInitializationError`).

## Strängar

```dart
final resurs = 'Tvättstuga 1';
final timmar = 2;

print('Du har bokat $resurs');                    // enkel variabel
print('Totalt ${timmar * 60} minuter');           // uttryck kräver {}
print('Namnet har ${resurs.length} tecken');

final flerrader = '''
Välkommen till föreningen!
Läs anslagstavlan regelbundet.
''';

final rad = 'Tvätt' + 'stuga';  // fungerar, men interpolation är vanligare
final ra = r'C:\temp\$inte_variabel'; // r = raw string, ingen interpolation
```

⚠️ **Varning:** Identifierare (variabel-, funktions- och klassnamn) i Dart får
bara innehålla engelska bokstäver, siffror, `_` och `$`. Därför skriver vi
`vaning` och inte `våning` i koden. I strängar går det förstås bra med å, ä och ö.

Användbara metoder: `toUpperCase()`, `trim()`, `contains()`, `startsWith()`,
`split(',')`, `replaceAll('a', 'b')`, `isEmpty`, `isNotEmpty`, `padLeft(2, '0')`.

💡 **Tips:** Dart accepterar både `'enkla'` och `"dubbla"` citattecken. Flutter-
världen använder oftast enkla.

## Samlingar: List, Map och Set

```dart
// List – ordnad lista (som Array i JS)
final resurser = <String>['Tvättstuga 1', 'Tvättstuga 2'];
resurser.add('Festlokalen');
print(resurser[0]);      // Tvättstuga 1
print(resurser.length);  // 3

// Map – nyckel/värde (som ett objekt eller Map i JS)
final vaningar = <String, int>{'1101': 1, '1201': 2};
vaningar['1301'] = 3;
print(vaningar['1101']);  // 1
print(vaningar['9999']);  // null – därför är typen int?

// Set – unika värden
final roller = <String>{'member', 'admin', 'member'};
print(roller);           // {member, admin}
```

### Funktionella metoder

Samma idéer som `map`/`filter`/`reduce` i JavaScript:

```dart
final timmar = [2, 3, 1, 4];

final dubbla = timmar.map((t) => t * 2).toList();   // [4, 6, 2, 8]
final langa = timmar.where((t) => t >= 3).toList(); // [3, 4]  (filter i JS)
final summa = timmar.fold(0, (sum, t) => sum + t);  // 10      (reduce i JS)
final finnsLang = timmar.any((t) => t > 3);         // true    (some i JS)
final allaKorta = timmar.every((t) => t < 5);       // true
final forsta = timmar.firstWhere((t) => t > 2);     // 3
```

⚠️ **Varning:** `map` och `where` returnerar en *lat* `Iterable`, inte en `List`.
Glöm inte `.toList()` när du behöver en lista.

### Spread, collection-if och collection-for

Det här används hela tiden i Flutter för att bygga listor av widgets.

```dart
final ordinarie = ['Tvättstuga 1', 'Tvättstuga 2'];
final arAdmin = true;

final alla = [
  ...ordinarie,                     // spread, som ... i JS
  if (arAdmin) 'Styrelserummet',    // collection-if
  for (final n in [1, 2]) 'Förråd $n', // collection-for
];
print(alla);
// [Tvättstuga 1, Tvättstuga 2, Styrelserummet, Förråd 1, Förråd 2]

List<String>? kanskeNull;
final saker = [...?kanskeNull, 'Cykelrum']; // ...? hoppar över null
```

## Funktioner

```dart
// Vanlig funktion med typer
int beraknaMinuter(int timmar) {
  return timmar * 60;
}

// Pilfunktion (arrow) för ett enda uttryck
int beraknaMinuter2(int timmar) => timmar * 60;

// Valfria positionella parametrar med []
String halsa(String namn, [String? halsning]) =>
    '${halsning ?? 'Hej'} $namn';

// Namngivna parametrar med {} – standard i Flutter
String bokningsText({
  required String resurs,    // måste anges
  int timmar = 1,            // standardvärde
  String? notering,          // valfri, kan vara null
}) {
  final extra = notering == null ? '' : ' ($notering)';
  return '$resurs i $timmar h$extra';
}

void main() {
  print(halsa('Anna'));                    // Hej Anna
  print(halsa('Anna', 'Tjena'));           // Tjena Anna
  print(bokningsText(resurs: 'Festlokalen', timmar: 4));
  print(bokningsText(notering: 'Kväll', resurs: 'Tvättstuga 1'));
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
  utforTvaGanger(() => print('Pling!'));
}
```

`void Function()` är typen "en funktion som inte tar några argument och inte
returnerar något". I Flutter heter den `VoidCallback` och används för `onPressed`.

## Klasser

Låt oss modellera en resurs från föreningens databas.

```dart
class Resource {
  // Fält. final = kan inte ändras efter att objektet skapats
  final String id;
  final String name;
  final String description;
  final int maxHours;
  final bool active;

  // Konstruktor med namngivna parametrar. this.x tilldelar fältet direkt
  const Resource({
    required this.id,
    required this.name,
    this.description = '',
    this.maxHours = 2,
    this.active = true,
  });

  // Namngiven konstruktor
  const Resource.tvattstuga(this.id, int nummer)
      : name = 'Tvättstuga',
        description = 'Källaren',
        maxHours = 3,
        active = true;

  // factory-konstruktor: skapar objekt från JSON (t.ex. från PocketBase)
  factory Resource.fromJson(Map<String, dynamic> json) {
    return Resource(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      maxHours: (json['max_hours'] as num?)?.toInt() ?? 2,
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'max_hours': maxHours,
        'active': active,
      };

  // Getter – ett beräknat värde som ser ut som ett fält
  String get label => active ? name : '$name (avstängd)';

  // copyWith – skapa en kopia med vissa fält ändrade
  Resource copyWith({
    String? name,
    String? description,
    int? maxHours,
    bool? active,
  }) {
    return Resource(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      maxHours: maxHours ?? this.maxHours,
      active: active ?? this.active,
    );
  }

  @override
  String toString() => 'Resource($id, $name, max $maxHours h)';
}

void main() {
  final json = {
    'id': 'r1',
    'name': 'Festlokalen',
    'description': 'Plan 1, hus A',
    'max_hours': 6,
    'active': true,
  };

  final fest = Resource.fromJson(json);
  final avstangd = fest.copyWith(active: false);

  print(fest);           // Resource(r1, Festlokalen, max 6 h)
  print(avstangd.label); // Festlokalen (avstängd)
  print(fest.label);     // Festlokalen – originalet är oförändrat
}
```

Några saker att lägga märke till:

- Dart har inget `new`-nyckelord (det är valfritt och används inte).
- Med bara `final`-fält blir objektet **oföränderligt** (immutable). I stället för
  att ändra ett objekt skapar du en ny kopia med `copyWith`. Flutter bygger mycket
  på den idén.
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
  String get id;
}

class Post extends Entity {
  @override
  final String id;
  final String title;
  final String body;
  final DateTime created;

  Post({required this.id, required this.title, required this.body, required this.created});
}
```

Du kommer att använda `extends` mest för att skapa widgets
(`extends StatelessWidget`).

## Enums

En enum är en fast uppsättning värden. Dart har *enhanced enums*, som kan ha fält
och metoder.

```dart
enum Role {
  member('Medlem'),
  board('Styrelse'),
  admin('Administratör');

  const Role(this.label);
  final String label;

  bool get canPublishPosts => this == board || this == admin;

  static Role fromString(String value) =>
      Role.values.firstWhere((r) => r.name == value, orElse: () => Role.member);
}

void main() {
  final roll = Role.fromString('board');
  print(roll.label);           // Styrelse
  print(roll.name);            // board
  print(roll.canPublishPosts); // true
}
```

## Records och destrukturering

Ett **record** är ett litet anonymt "paket" med värden, praktiskt när en funktion
vill returnera mer än en sak.

```dart
(int, int) timmarOchMinuter(Duration d) =>
    (d.inHours, d.inMinutes.remainder(60));

({DateTime start, DateTime end}) kvallspass(DateTime dag) => (
      start: DateTime(dag.year, dag.month, dag.day, 18),
      end: DateTime(dag.year, dag.month, dag.day, 21),
    );

void main() {
  final (h, m) = timmarOchMinuter(const Duration(minutes: 135));
  print('$h h $m min'); // 2 h 15 min

  final pass = kvallspass(DateTime(2026, 3, 14));
  print(pass.start);    // fält med namn

  final (:start, :end) = pass; // destrukturera namngivna fält
  print(end.difference(start).inHours); // 3
}
```

Jämför med JavaScript: `const [h, m] = ...` och `const { start, end } = ...`.

## Patterns och switch-uttryck

Dart 3 har kraftfulla **patterns**. `switch` kan användas som ett *uttryck* som
returnerar ett värde:

```dart
String beskrivTimmar(int timmar) => switch (timmar) {
      0 => 'Ingen tid',
      1 => 'En timme',
      >= 2 && <= 4 => 'Ett kortare pass',
      _ => 'Heldag', // _ = allt annat
    };

String rollText(Role roll) => switch (roll) {
      Role.member => 'Du kan boka och läsa anslag',
      Role.board || Role.admin => 'Du kan även publicera anslag',
    };
```

Eftersom `Role` är en enum vet Dart vilka värden som finns. Glömmer du ett fall
får du ett **kompileringsfel**. Det är mycket säkrare än `switch` i JS.

Patterns fungerar också på JSON (maps), vilket gör tolkning både kortare och säkrare:

```dart
String? hamtaNamn(Map<String, dynamic> json) {
  if (json case {'name': String namn, 'active': true}) {
    return namn;  // matchar bara om name är en String OCH active är true
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
      Loading() => 'Laddar...',
      Loaded(data: final lista) when lista.isEmpty => 'Inga resurser',
      Loaded(:final data) => '${data.length} resurser',
      Failed(:final message) => 'Fel: $message',
    };

void main() {
  print(beskriv(Loading()));
  print(beskriv(Loaded(['Tvättstuga 1'])));
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
Future<List<String>> hamtaResurser() async {
  // Låtsas att vi väntar på nätverket
  await Future.delayed(const Duration(seconds: 1));
  return ['Tvättstuga 1', 'Festlokalen'];
}

Future<void> main() async {
  print('Hämtar...');
  try {
    final resurser = await hamtaResurser();
    print('Fick: $resurser');
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

En `Stream<T>` är en *ström* av värden över tid, till exempel nya anslag som
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
import 'package:forening_app/models/resource.dart'; // från ditt eget projekt
import 'models/booking.dart';             // relativ sökväg i projektet

void main() {
  final json = jsonEncode({'name': 'Festlokalen'});
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

🧪 **Prova själv:** Skriv en klass `Booking` med fälten `id`, `resourceId`,
`userId`, `start`, `end` och `note` (nullbar). Lägg till `fromJson` (datum kommer
som strängar, använd `DateTime.parse`), en getter `duration` och en getter
`isPast`. Skapa några bokningar i `main` och skriv ut de som är längre än två
timmar.

**Nästa kapitel:** [02 – Widgets och layout](02-widgets-och-layout.md)

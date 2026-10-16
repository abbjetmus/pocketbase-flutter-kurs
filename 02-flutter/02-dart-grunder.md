# 2. Dart-grunder

Flutter-appar skrivs i språket **Dart**. Om du har skrivit JavaScript känner du
igen dig. Den stora skillnaden är att Dart har **typer**: en variabel som
innehåller ett tal kan inte plötsligt innehålla en text. Det gör att många fel
syns redan när du skriver koden.

## Testa koden i webbläsaren

Du kan prova alla exempel i det här kapitlet på <https://dartpad.dev>. Klistra
in koden och klicka **Run**.

Ett Dart-program startar alltid i funktionen `main`:

```dart
void main() {
  print('Hej Kvittra!');
}
```

`print` skriver ut text, som `console.log` i JavaScript.

💡 Många exempel nedan är bara några rader kod. Lägg dem inuti
`void main() { ... }` när du testar dem.

## Variabler: `var`, `final` och `const`

```dart
void main() {
  var likes = 3;        // kan ändras
  likes = 4;

  final username = 'anna'; // kan inte ändras efter att den fått ett värde
  const maxLength = 280;   // ett värde som aldrig ändras

  print(likes);
}
```

| Dart | JavaScript | Betyder |
|------|------------|---------|
| `var x = 1;` | `let x = 1;` | Kan ändras |
| `final x = 1;` | `const x = 1;` | Kan inte ändras |
| `const x = 1;` | – | Kan inte ändras, och värdet är känt redan innan appen körs |

💡 **Tumregel:** Använd `final` för det mesta. Använd `var` när värdet ska
ändras.

## Typer

Dart räknar själv ut typen när du skriver `var` eller `final`. Du kan också
skriva typen själv:

| Typ | Innehåller | Exempel |
|-----|------------|---------|
| `int` | Heltal | `int likes = 12;` |
| `double` | Decimaltal | `double rating = 4.5;` |
| `String` | Text | `String name = 'Anna Andersson';` |
| `bool` | Sant eller falskt | `bool liked = true;` |

```dart
var likes = 12;
// likes = 'tolv'; // FEL: likes är en int
```

⚠️ **Inga å, ä, ö i namn.** Variabelnamn får bara ha engelska bokstäver, siffror
och `_`. Skriv `antalFoljare`, inte `antalFöljare`. Inuti text går å, ä och ö
bra.

## Text och interpolation

Med `$` stoppar du in en variabel i en text. Med `${}` kan du stoppa in ett
helt uttryck:

```dart
final username = 'anna';
final likes = 12;

print('Inlägg av @$username');           // Inlägg av @anna
print('${likes + 1} personer gillar det'); // 13 personer gillar det
print('Namnet har ${username.length} bokstäver');
```

Det motsvarar `` `Inlägg av @${username}` `` i JavaScript.

## Listor och maps

En **List** är en lista med värden i ordning, som en array i JavaScript.
En **Map** kopplar ihop en nyckel med ett värde, som ett objekt i JavaScript.

```dart
final usernames = ['anna', 'bertil', 'cissi'];
usernames.add('david');
print(usernames[0]);     // anna
print(usernames.length); // 4

final user = {
  'username': 'anna',
  'name': 'Anna Andersson',
};
print(user['name']); // Anna Andersson
```

## if och for

```dart
final likes = 3;

if (likes == 0) {
  print('Bli först att gilla!');
} else if (likes == 1) {
  print('1 person gillar detta');
} else {
  print('$likes personer gillar detta');
}

final usernames = ['anna', 'bertil', 'cissi'];
for (final name in usernames) {
  print('@$name');
}
```

`for (final name in usernames)` går igenom listan, ett värde i taget. Det är som
`for (const name of usernames)` i JavaScript.

## Funktioner

```dart
// Funktion som tar ett tal och returnerar en text
String likeText(int likes) {
  return '$likes gillningar';
}

// Samma sak kortare, med =>
String handle(String username) => '@$username';
```

### Namngivna parametrar

Parametrar inom `{ }` är **namngivna**. Man skriver namnet när man anropar
funktionen. `required` betyder att den måste anges.

```dart
String postTitle({required String author, int likes = 0}) {
  return '$author · $likes gillningar';
}

void main() {
  print(postTitle(author: 'anna', likes: 12)); // anna · 12 gillningar
  print(postTitle(author: 'bertil'));          // bertil · 0 gillningar
}
```

Det här är viktigt, för Flutter använder namngivna parametrar överallt:
`Text('Hej', style: ..., maxLines: 2)`.

## Null safety

`null` betyder "inget värde". I Dart får en variabel **inte** vara `null`, om
du inte skriver ett `?` efter typen.

```dart
String name = 'Anna';
// name = null;    // FEL

String? bio;       // String? = en text eller null. Startar som null
bio = 'Gillar promenader';
bio = null;        // OK
```

Så använder du ett värde som kan vara `null`:

```dart
String? bio;

// ?? ger ett reservvärde om bio är null
print(bio ?? 'Ingen bio ännu');

// Efter en if vet Dart att bio inte är null
if (bio != null) {
  print(bio.length);
}
```

⚠️ Du kommer att se `!`, till exempel `bio!.length`. Det betyder "jag lovar att
det inte är null". Har du fel kraschar appen. Använd hellre `??` eller `if`.

## Klasser

En **klass** är en mall för en sorts sak. Vi gör en klass för ett inlägg i
Kvittra. Fälten är nästan samma som i collectionen `posts` från modul 01.
För enkelhetens skull sparar vi författarens **användarnamn** i `author`.

```dart
class Post {
  final String id;
  final String author; // användarnamnet på den som skrev inlägget
  final String title;
  final String body;

  // Konstruktor: så skapar man en Post
  const Post({
    required this.id,
    required this.author,
    required this.title,
    required this.body,
  });
}

void main() {
  final post = Post(
    id: 'p1',
    author: 'anna',
    title: 'Höstpromenad',
    body: 'Löven har börjat gulna i parken.',
  );
  print(post.title); // Höstpromenad
}
```

- `this.id` i konstruktorn sparar värdet direkt i fältet `id`.
- Fälten är `final`. Ett inlägg ändras inte efter att det har skapats.
- Dart använder inte ordet `new`. Du skriver bara `Post(...)`.

### `fromJson` – från JSON till Post

Data från en server kommer ofta som **JSON**. I Dart blir JSON en
`Map<String, dynamic>`: nycklarna är text, och värdena kan vara vad som helst
(`dynamic`). Vi lägger till en konstruktor som gör om en sådan map till en
`Post`:

```dart
class Post {
  // ... fälten och konstruktorn från ovan ...

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as String,
      author: json['author'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
    );
  }
}

void main() {
  final json = {
    'id': 'p1',
    'author': 'anna',
    'title': 'Höstpromenad',
    'body': 'Löven har börjat gulna i parken.',
  };
  final post = Post.fromJson(json);
  print(post.title);
}
```

`as String` betyder "det här värdet är en String". Om det inte stämmer
kraschar programmet, så det är viktigt att fältnamnen stavas exakt som i
JSON:en. I kapitel 6 gör vi en liknande konstruktor för data från PocketBase.

## async och await

Att hämta något från en server tar tid. Under tiden ska appen inte frysa. Därför
får man en **Future**, ett värde som kommer *senare*. Det är samma sak som ett
`Promise` i JavaScript.

```dart
Future<String> fetchGreeting() async {
  await Future.delayed(const Duration(seconds: 2)); // låtsas att vi väntar på servern
  return 'Hej från servern!';
}

Future<void> main() async {
  print('Hämtar...');
  final text = await fetchGreeting();
  print(text); // skrivs ut efter 2 sekunder
}
```

- `async` skrivs på en funktion som ska vänta på något.
- `await` väntar tills värdet finns.
- `Future<String>` betyder "en String som kommer senare".

⚠️ Glömmer du `await` får du en `Future` i stället för värdet. Ser du texten
`Instance of 'Future<...>'` har du glömt `await`.

## Sammanfattning

| Dart | JavaScript |
|------|------------|
| `var`, `final`, `const` | `let`, `const` |
| `'Hej $namn'` | `` `Hej ${namn}` `` |
| `List`, `Map` | array, objekt |
| `for (final x in lista)` | `for (const x of lista)` |
| `String?` (kan vara null) | alla variabler kan vara null |
| `bio ?? 'Ingen bio'` | `bio ?? 'Ingen bio'` |
| `class Post { ... }` | `class Post { ... }` |
| `Future`, `async`, `await` | `Promise`, `async`, `await` |

## Övningar

Gör övningarna i <https://dartpad.dev>.

**2.1** Skapa variabler för en användare: `username` (`'bertil'`), `name`
(`'Bertil Berg'`) och `followers` (`2`). Skriv ut
`Bertil Berg (@bertil) har 2 följare`.

**2.2** Gör en lista med användarnamnen `anna`, `bertil`, `cissi` och `david`.
Gå igenom listan med `for` och skriv ut varje namn med `@` före.

**2.3** Skriv en funktion `likeText(int likes)` som returnerar
`'Bli först att gilla!'` för 0, `'1 person gillar detta'` för 1 och
`'5 personer gillar detta'` för 5 (och så vidare).

**2.4** Skriv en funktion `greet({required String name, String greeting = 'Hej'})`
som returnerar till exempel `'Hej Anna!'`. Anropa den med och utan `greeting`.

**2.5** Skriv en funktion `showBio(String? bio)` som skriver ut bion, eller
`Ingen bio ännu` om den är `null`. Testa med `'Bakar bröd varje helg'` och
`null`.

**2.6** Skriv en klass `Comment` med fälten `id`, `post`, `author` och `body`
(alla är `String`), och en `factory Comment.fromJson`. Testa med den här
JSON:en och skriv ut `bertil: Fina färger!`:

```dart
final json = {
  'id': 'c1',
  'post': 'p1',
  'author': 'bertil',
  'body': 'Fina färger!',
};
```

Lösningar finns i [losningar.md](losningar.md#kapitel-2--dart-grunder).

Nästa kapitel: [Widgets och layout](03-widgets-och-layout.md)

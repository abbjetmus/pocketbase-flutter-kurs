# 3. Widgets och layout

Nu bygger vi Kvittras första skärm: ett flöde med inlägg. Varje inlägg visas i
ett kort med användarnamn, rubrik och text.

## Allt är en widget

I Flutter är allt du ser en **widget**: en text, en knapp, en ikon. Även saker
som inte syns är widgets, till exempel luft runt något (`Padding`) eller en rad
(`Row`). Widgets läggs i varandra och bildar ett **träd**:

```
MaterialApp
└── Scaffold
    ├── AppBar
    │   └── Text("Kvittra")
    └── Center
        └── Text("Välkommen till Kvittra!")
```

💡 **Kan du Vue?** En widget är ungefär som en komponent. Skillnaden är att allt
skrivs i Dart, även det som i Vue står i `<template>`.

## Din första egna app

Ta bort allt i `lib/main.dart` och skriv det här i stället:

```dart
import 'package:flutter/material.dart';

void main() {
  runApp(const KvittraApp());
}

class KvittraApp extends StatelessWidget {
  const KvittraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kvittra',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('Kvittra')),
        body: const Center(
          child: Text('Välkommen till Kvittra!'),
        ),
      ),
    );
  }
}
```

| Del | Vad den gör |
|-----|-------------|
| `runApp(...)` | Startar appen och visar widgeten på skärmen |
| `StatelessWidget` | En widget som bara visar något. Den har inget eget minne (mer om det i kapitel 4) |
| `build` | Beskriver hur widgeten ser ut. Flutter anropar den när skärmen ska ritas |
| `MaterialApp` | Ligger överst i alla appar. Bestämmer bland annat färgerna (`theme`) |
| `Scaffold` | Skelettet för en skärm: en `appBar` överst och en `body` |
| `child` | Widgeten som ligger inuti. Har en widget flera barn heter det `children` |

⚠️ Visar VS Code nu ett rött fel i filen `test/widget_test.dart`? Den filen
skapades av `flutter create` och letar efter räknarappen som du tog bort. Vi
använder den inte, så du kan ta bort hela mappen `test`.

💡 `const` framför en widget betyder att den aldrig ändras. Då slipper Flutter
bygga om den. VS Code föreslår ofta var du kan lägga till `const`.

## Vanliga widgets

| Widget | Gör | Exempel |
|--------|-----|---------|
| `Text` | Visar text | `Text('Höstpromenad')` |
| `Icon` | Visar en ikon | `Icon(Icons.favorite)` |
| `Padding` | Luft runt ett barn | `Padding(padding: EdgeInsets.all(16), child: ...)` |
| `SizedBox` | Tomrum, eller en fast storlek | `SizedBox(height: 8)` |
| `Center` | Lägger barnet i mitten | `Center(child: ...)` |
| `Container` | Färg, ram och rundade hörn | `Container(color: Colors.amber, child: ...)` |
| `CircleAvatar` | En rund bild eller bokstav | `CircleAvatar(child: Text('A'))` |

## Row och Column

`Row` lägger barnen **bredvid** varandra. `Column` lägger dem **under**
varandra.

```
Row                              Column
┌──────┬──────┬──────┐           ┌──────────┐
│  A   │  B   │  C   │           │    A     │
└──────┴──────┴──────┘           ├──────────┤
                                 │    B     │
                                 ├──────────┤
                                 │    C     │
                                 └──────────┘
```

Här är en rad med en avatar och ett namn:

```dart
const Row(
  children: [
    CircleAvatar(child: Text('A')),
    SizedBox(width: 8),
    Column(
      crossAxisAlignment: CrossAxisAlignment.start, // vänsterställ texterna
      children: [
        Text('Anna Andersson'),
        Text('@anna'),
      ],
    ),
  ],
)
```

`crossAxisAlignment: CrossAxisAlignment.start` gör att texterna i `Column`
börjar vid vänsterkanten i stället för att centreras.

### Expanded

Ett barn i en `Row` tar bara den plats det behöver. Med `Expanded` tar barnet
**all plats som är kvar**:

```dart
const Row(
  children: [
    CircleAvatar(child: Text('A')),
    SizedBox(width: 8),
    Expanded(
      child: Text('Anna gillar promenader, foto och att baka bröd på helgerna'),
    ),
  ],
)
```

Utan `Expanded` försöker texten bli lika bred som hela meningen. Med
`Expanded` får den plats som finns kvar bredvid avataren, och bryts till flera
rader.

⚠️ **Gul-svarta ränder?** Det betyder att något inte får plats. Felet heter
ofta `A RenderFlex overflowed`. En lång text i en `Row` är den vanligaste
orsaken. Lösningen är nästan alltid att lägga texten i en `Expanded`.

## Card och ListTile

`Card` är en yta med skugga och rundade hörn. `ListTile` är en färdig rad med
plats för en bild till vänster, en rubrik och en undertext.

```dart
const Card(
  child: ListTile(
    leading: CircleAvatar(child: Text('A')),
    title: Text('Anna Andersson'),
    subtitle: Text('@anna'),
  ),
)
```

## Bygg ett PostCard

Nu bygger vi kortet som visar ett inlägg:

```
┌──────────────────────────────────────┐
│ (A)  @anna                           │
│                                      │
│ Höstpromenad                         │
│ Löven har börjat gulna i parken.     │
└──────────────────────────────────────┘
```

Vi delar upp koden i flera filer. Skapa mapparna och filerna i `lib/`:

```
lib/
├── main.dart
├── models/
│   └── post.dart         ← klassen Post från kapitel 2
├── data/
│   └── sample_data.dart  ← påhittade inlägg
└── widgets/
    └── post_card.dart    ← kortet
```

Lägg klassen `Post` med `fromJson` från kapitel 2 i `lib/models/post.dart`.

Sedan några påhittade inlägg. De är samma som i modul 01. I kapitel 6 byter
vi ut dem mot riktiga inlägg från din PocketBase.

```dart
// lib/data/sample_data.dart
import '../models/post.dart';

// final och inte const: i kapitel 5 lägger vi till nya inlägg i listan
final samplePosts = [
  Post(id: 'p1', author: 'anna', title: 'Höstpromenad', body: 'Löven har börjat gulna i parken.'),
  Post(id: 'p2', author: 'bertil', title: 'Mitt första surdegsbröd', body: 'Det blev platt men gott!'),
  Post(id: 'p3', author: 'anna', title: 'Morgondimma', body: 'Dimman låg tät över sjön i morse.'),
  Post(id: 'p4', author: 'cissi', title: 'Tips på en bra bok?', body: 'Jag behöver något att läsa på bussen.'),
  Post(id: 'p5', author: 'david', title: 'Matchdag', body: 'Vi vann med 3–1!'),
  Post(id: 'p6', author: 'bertil', title: 'Andra försöket', body: 'Nu jäste degen ordentligt.'),
];
```

Sedan kortet:

```dart
// lib/widgets/post_card.dart
import 'package:flutter/material.dart';

import '../models/post.dart';

class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final username = post.author;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text(username[0].toUpperCase())),
                const SizedBox(width: 12),
                Text('@$username', style: textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 12),
            Text(post.title, style: textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(post.body),
          ],
        ),
      ),
    );
  }
}
```

- `PostCard` får sitt inlägg via konstruktorn, precis som `Post` fick sina fält
  i kapitel 2. Så kan samma kort visa vilket inlägg som helst.
- `username[0]` är första bokstaven i namnet.
- `Theme.of(context).textTheme` hämtar färdiga textstilar från temat, till
  exempel `titleMedium` för rubriker.

## Flödet: en lista med kort

En `Column` kan inte scrolla. För en lista som kan bli lång använder vi
`ListView.builder`. Den bygger bara de kort som syns på skärmen.

```dart
// lib/main.dart
import 'package:flutter/material.dart';

import 'data/sample_data.dart';
import 'widgets/post_card.dart';

void main() {
  runApp(const KvittraApp());
}

class KvittraApp extends StatelessWidget {
  const KvittraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kvittra',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const FeedScreen(),
    );
  }
}

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kvittra')),
      body: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: samplePosts.length,
        itemBuilder: (context, index) {
          return PostCard(post: samplePosts[index]);
        },
      ),
    );
  }
}
```

`ListView.builder` behöver två saker:

| Parameter | Betyder |
|-----------|---------|
| `itemCount` | Hur många rader listan har |
| `itemBuilder` | En funktion som bygger raden med nummer `index` (0, 1, 2 …) |

Spara och titta i Chrome. Du ska se sex kort som du kan scrolla mellan.

## Övningar

**3.1** Byt `seedColor` till en annan färg, till exempel `Colors.teal`. Vad
ändras i appen?

**3.2** Lägg till två egna inlägg i `samplePosts`. Ge dem id:na `'p7'` och `'p8'`.

**3.3** Ändra `PostCard` så att texten (`post.body`) visas med högst två rader.
Ledtråd: `Text` har parametrarna `maxLines` och `overflow: TextOverflow.ellipsis`.

**3.4** Lägg till en rad längst ner i `PostCard` med en hjärtikon
(`Icons.favorite_border`) och en pratbubbla (`Icons.chat_bubble_outline`) bredvid
varandra. Knapparna ska inte göra något än.

**3.5** Gör en ny widget `UserTile` som visar en användare i ett `Card` med en
`ListTile`: en `CircleAvatar` med första bokstaven, användarnamnet som `title` och
`Kvittra-användare` som `subtitle`. Visa användarna i listan
`['anna', 'bertil', 'cissi', 'david']` i en `ListView.builder`.

Lösningar finns i [losningar.md](losningar.md#kapitel-3--widgets-och-layout).

Nästa kapitel: [State och interaktion](04-state-och-interaktion.md)

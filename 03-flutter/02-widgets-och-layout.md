# 02 – Widgets och layout

## Allt är en widget

I Flutter är **allt du ser på skärmen en widget**: text, knappar, ikoner, men också
sådant som inte syns, som marginaler (`Padding`), centrering (`Center`) och
layout (`Row`, `Column`). En widget är en **beskrivning** av en del av
gränssnittet. Den är oföränderlig (immutable) och billig att skapa.

Widgets placeras i varandra och bildar ett **widgetträd**:

```dart
import 'package:flutter/material.dart';

void main() {
  runApp(const ForeningApp());
}

class ForeningApp extends StatelessWidget {
  const ForeningApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Föreningen',
      home: Scaffold(
        appBar: AppBar(title: const Text('Föreningen')),
        body: const Center(
          child: Text('Välkommen hem!'),
        ),
      ),
    );
  }
}
```

Trädet ser ut så här:

```
ForeningApp
└── MaterialApp
    └── Scaffold
        ├── AppBar
        │   └── Text("Föreningen")
        └── Center
            └── Text("Välkommen hem!")
```

- `runApp` tar den översta widgeten och fäster den på skärmen.
- `build` är metoden som beskriver hur widgeten ser ut. Flutter anropar den när
  widgeten behöver ritas, och ibland väldigt ofta.
- `child` (ett barn) och `children` (en lista av barn) är hur widgets nästlas.

💡 **Tips:** Om du kan Vue: en widget motsvarar ungefär en komponent, och `build`
motsvarar `<template>`. Skillnaden är att allt skrivs i Dart, även layouten.

### Tre träd: widget, element och render

Det finns faktiskt tre träd under huven. Du behöver inte kunna dem i detalj, men
det förklarar varför Flutter är snabbt:

| Träd | Vad det är | Livslängd |
|------|-----------|-----------|
| **Widget-trädet** | Dina beskrivningar (`Text('Hej')`) | Kortlivat, skapas om vid varje `build` |
| **Element-trädet** | Flutters "instanser" som håller koll på var varje widget sitter och på dess `State` | Långlivat |
| **Render-trädet** | Objekt som mäter, placerar och ritar | Långlivat |

När `build` körs igen jämför Flutter de nya widgetarna med de gamla. Om typen är
densamma på samma plats uppdateras det befintliga elementet och render-objektet i
stället för att skapas om. Därför är det billigt att bygga om widgets, och därför
spelar `const` roll: en `const`-widget är *samma objekt* varje gång och kan hoppas
över helt.

## MaterialApp, Scaffold och AppBar

- **`MaterialApp`** ligger nästan alltid överst. Den ställer in tema, navigation,
  språk m.m. enligt Googles designsystem *Material Design 3*.
- **`Scaffold`** är "skelettet" för en skärm: plats för `appBar`, `body`,
  `floatingActionButton`, `bottomNavigationBar`, `drawer` m.m.
- **`AppBar`** är listen överst med titel och eventuella knappar (`actions`).

```dart
Scaffold(
  appBar: AppBar(
    title: const Text('Bokningar'),
    actions: [
      IconButton(
        icon: const Icon(Icons.refresh),
        onPressed: () {},
      ),
    ],
  ),
  body: const Center(child: Text('Inga bokningar ännu')),
  floatingActionButton: FloatingActionButton(
    onPressed: () {},
    child: const Icon(Icons.add),
  ),
)
```

## Grundläggande widgets

### Text, Icon och Image

```dart
const Text(
  'Tvättstuga 1',
  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
  maxLines: 1,
  overflow: TextOverflow.ellipsis, // "Tvättstu…" om texten inte får plats
)

const Icon(Icons.local_laundry_service, size: 32, color: Colors.teal)

Image.network('https://picsum.photos/400/200', fit: BoxFit.cover)
Image.asset('assets/logo.png') // kräver att filen listas under flutter: assets: i pubspec.yaml
```

Bättre än att hårdkoda textstil är att hämta den från temat:

```dart
Text('Festlokalen', style: Theme.of(context).textTheme.titleLarge)
```

### Knappar

Material 3 har flera knapptyper. Alla tar `onPressed`. Om `onPressed` är `null`
blir knappen inaktiverad (grå).

```dart
FilledButton(onPressed: () {}, child: const Text('Boka'))       // huvudåtgärd
OutlinedButton(onPressed: () {}, child: const Text('Avbryt'))
TextButton(onPressed: () {}, child: const Text('Läs mer'))
IconButton(onPressed: () {}, icon: const Icon(Icons.delete))
FilledButton.icon(
  onPressed: null, // inaktiverad
  icon: const Icon(Icons.event),
  label: const Text('Fullbokat'),
)
```

### Container, Padding och SizedBox

```dart
// Padding – luft runt ett barn
const Padding(
  padding: EdgeInsets.all(16),
  child: Text('Anslag'),
)

// SizedBox – fast storlek, eller bara mellanrum
const SizedBox(height: 12)                 // tomrum mellan widgets
const SizedBox(width: 100, height: 40, child: Text('Fast'))

// Container – "allt-i-ett": storlek, marginaler, bakgrund, ram, rundade hörn
Container(
  width: 120,
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  margin: const EdgeInsets.only(bottom: 8),
  decoration: BoxDecoration(
    color: Colors.teal.shade50,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.teal),
  ),
  child: const Text('Ledig'),
)
```

💡 **Tips:** Använd `Padding` och `SizedBox` när det räcker. `Container` är bra
när du behöver dekoration, men den gör mycket och kan vara svårare att läsa.

## Row och Column

`Row` lägger barn **horisontellt**, `Column` **vertikalt**. Det är de två
viktigaste layout-widgetarna.

```dart
Row(
  children: const [
    Icon(Icons.local_laundry_service),
    SizedBox(width: 8),
    Text('Tvättstuga 1'),
  ],
)
```

### mainAxis och crossAxis

Varje `Row`/`Column` har en **huvudaxel** (main axis), som är riktningen barnen
läggs i, och en **tväraxel** (cross axis), som går vinkelrätt mot den.

```
Row:     main axis →            Column:  main axis ↓
         cross axis ↓                    cross axis →
```

```dart
Column(
  mainAxisAlignment: MainAxisAlignment.center,    // vertikalt i en Column
  crossAxisAlignment: CrossAxisAlignment.start,   // horisontellt i en Column
  children: const [
    Text('Festlokalen'),
    Text('Plan 1, hus A'),
  ],
)
```

| `MainAxisAlignment` | Effekt |
|--------------------|--------|
| `start` | Allt i början (standard) |
| `center` | Allt i mitten |
| `end` | Allt i slutet |
| `spaceBetween` | Första och sista vid kanterna, jämnt mellanrum mellan |
| `spaceAround` / `spaceEvenly` | Jämnt mellanrum, även vid kanterna |

`mainAxisSize: MainAxisSize.min` gör att en `Column` bara blir så hög som sitt
innehåll i stället för att ta all tillgänglig höjd.

💡 **Tips:** Sedan Flutter 3.27 har `Row` och `Column` en `spacing`-parameter:
`Column(spacing: 8, children: [...])` ger 8 pixlars mellanrum mellan barnen, så du
slipper lägga in `SizedBox` överallt.

### Expanded, Flexible och Spacer

Som standard tar barnen i en `Row` bara den plats de behöver. Med `Expanded` tar
ett barn **all återstående plats**:

```dart
Row(
  children: [
    const Icon(Icons.celebration),
    const SizedBox(width: 8),
    const Expanded(
      child: Text('Festlokalen – plan 1, hus A, med kök och 40 sittplatser'),
    ),
    TextButton(onPressed: () {}, child: const Text('Boka')),
  ],
)
```

Texten får nu exakt den plats som blir över mellan ikonen och knappen, och radbryts
i stället för att flöda över.

- `Expanded(flex: 2, ...)` och `Expanded(flex: 1, ...)` delar platsen 2:1.
- `Flexible` får *ta upp till* den plats som finns, men måste inte fylla den.
- `Spacer()` är ett tomt `Expanded` som trycker isär barn.

```dart
Row(
  children: const [
    Text('Anslag'),
    Spacer(),          // trycker datumet till höger kant
    Text('14 mars'),
  ],
)
```

## Stack

`Stack` lägger barn **ovanpå varandra**. Med `Positioned` placerar du dem exakt.
Det är bra för till exempel en etikett ovanpå en bild.

```dart
Stack(
  children: [
    Image.network('https://picsum.photos/400/200', height: 160, fit: BoxFit.cover),
    Positioned(
      top: 8,
      right: 8,
      child: Chip(label: const Text('Ledig nu')),
    ),
  ],
)
```

## Listor: ListView och ListView.builder

En `Column` kan inte scrolla. Har du fler saker än vad som får plats behöver du en
`ListView`.

```dart
// För ett fåtal, kända barn
ListView(
  padding: const EdgeInsets.all(16),
  children: const [
    Text('Anslag 1'),
    Text('Anslag 2'),
  ],
)
```

För långa eller dynamiska listor använder du `ListView.builder`. Den bygger bara de
rader som syns på skärmen, så den fungerar lika bra med 10 som med 10 000 poster:

```dart
final posts = List.generate(100, (i) => 'Anslag nummer ${i + 1}');

ListView.builder(
  itemCount: posts.length,
  itemBuilder: (context, index) {
    return ListTile(title: Text(posts[index]));
  },
)
```

`ListView.separated` fungerar likadant men har även en `separatorBuilder`, till
exempel för `Divider()` mellan raderna.

### Card och ListTile

`ListTile` är en färdig rad med plats för ikon, titel, undertitel och något till
höger. `Card` är en upphöjd yta med rundade hörn.

```dart
Card(
  child: ListTile(
    leading: const Icon(Icons.local_laundry_service),
    title: const Text('Tvättstuga 1'),
    subtitle: const Text('Källaren, hus B · max 3 h'),
    trailing: const Icon(Icons.chevron_right),
    onTap: () {},
  ),
)
```

## Constraints: hur Flutter bestämmer storlekar

Det här är den viktigaste regeln för att förstå layout i Flutter:

> **Constraints go down. Sizes go up. Parent sets position.**
>
> Begränsningar skickas nedåt. Storlekar skickas uppåt. Föräldern bestämmer
> positionen.

1. Föräldern säger till barnet: "Du får vara mellan *min* och *max* bredd, och
   mellan *min* och *max* höjd." (constraints)
2. Barnet väljer en storlek **inom** de gränserna och berättar den för föräldern.
3. Föräldern bestämmer var barnet placeras.

Konsekvenser som förvånar nybörjare:

- En widget **kan inte** välja vilken storlek som helst. `Container(width: 100)`
  direkt i `body` på en `Scaffold` blir ändå full bredd om föräldern kräver det
  ("tight constraints"). Lägg den i en `Center` eller `Align` så får den bli 100 bred.
- En widget vet inte var den ligger på skärmen, bara hur stor den är.
- `Row` ger sina barn **obegränsad bredd** och `Column` ger **obegränsad höjd**
  (längs huvudaxeln). Därför uppstår de vanligaste felen nedan.

### Vanliga layoutfel

**1. Gul-svarta ränder: "A RenderFlex overflowed by 42 pixels on the right."**

```dart
// FEL: lång text i en Row – Text får obegränsad bredd och blir för bred
Row(children: [
  Icon(Icons.campaign),
  Text('Viktigt: vattnet stängs av på tisdag mellan 08 och 12 i hela huset'),
])

// RÄTT: låt texten ta den plats som finns och radbryta
Row(children: [
  Icon(Icons.campaign),
  Expanded(child: Text('Viktigt: vattnet stängs av på tisdag ...')),
])
```

Samma sak händer vertikalt när en `Column` får fler barn än vad som får plats.
Lösningen är då en `ListView` eller `SingleChildScrollView`.

**2. "Vertical viewport was given unbounded height."**

```dart
// FEL: ListView i en Column – Column ger obegränsad höjd, ListView vill bli oändligt hög
Column(children: [
  Text('Anslag'),
  ListView(children: [...]),
])

// RÄTT: ge ListView den återstående höjden
Column(children: [
  Text('Anslag'),
  Expanded(child: ListView(children: [...])),
])
```

**3. "BoxConstraints forces an infinite width."** Det kan till exempel vara en
`TextField` direkt i en `Row`. Lösningen är densamma: wrappa den i `Expanded`.

⚠️ **Varning:** Felmeddelandena i Flutter är långa men bra. Läs de första raderna
i konsolen. De säger oftast exakt vilken widget som är problemet och föreslår en
lösning.

💡 **Tips:** Starta **Flutter DevTools** (i VS Code: *Dart: Open DevTools*) och öppna
*Widget Inspector*. Där ser du trädet, storlekar och constraints för varje widget.
*Layout Explorer* visar Row/Column-inställningar visuellt.

## Tema: ThemeData och ColorScheme.fromSeed

I Material 3 räcker det att välja **en färg**. Flutter räknar ut en hel palett
(primär, sekundär, ytor, fel m.m.) som fungerar ihop, både för ljust och mörkt läge.

```dart
MaterialApp(
  title: 'Föreningen',
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
  ),
  darkTheme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E7D32),
      brightness: Brightness.dark,
    ),
  ),
  themeMode: ThemeMode.system, // följ telefonens inställning
  home: const ResourceListScreen(),
)
```

Hämta färger och textstilar från temat i stället för att hårdkoda dem. Då fungerar
mörkt läge automatiskt:

```dart
final colors = Theme.of(context).colorScheme;
final text = Theme.of(context).textTheme;

Container(
  color: colors.primaryContainer,
  child: Text('Ledig', style: text.labelLarge?.copyWith(color: colors.onPrimaryContainer)),
)
```

Varje färg har en "on"-färg (`primary`/`onPrimary`, `surface`/`onSurface` …) som är
den färg text ska ha *ovanpå* den. Då blir kontrasten alltid rätt.

## Exempel: ResourceCard

Nu bygger vi en återanvändbar widget för en resurs. Vi använder `Resource`-klassen
från kapitel 01 (förenklad här).

```dart
import 'package:flutter/material.dart';

class Resource {
  const Resource({
    required this.id,
    required this.name,
    required this.description,
    required this.maxHours,
    this.active = true,
  });

  final String id;
  final String name;
  final String description;
  final int maxHours;
  final bool active;
}

class ResourceCard extends StatelessWidget {
  const ResourceCard({super.key, required this.resource, this.onBook});

  final Resource resource;
  final VoidCallback? onBook; // vad som händer när man trycker på "Boka"

  IconData get _icon => resource.name.toLowerCase().contains('tvätt')
      ? Icons.local_laundry_service
      : Icons.celebration;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
              child: Icon(_icon),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(resource.name, style: text.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    resource.description,
                    style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: colors.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text('Max ${resource.maxHours} h', style: text.labelMedium),
                      const Spacer(),
                      FilledButton.tonal(
                        // Inaktiv knapp om resursen är avstängd
                        onPressed: resource.active ? onBook : null,
                        child: Text(resource.active ? 'Boka' : 'Avstängd'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

Lägg märke till:

- Widgeten tar emot **data** (`resource`) och en **callback** (`onBook`) via
  konstruktorn. Den vet inte själv vad "boka" innebär. Det bestämmer den som
  använder den. Det gör kortet återanvändbart.
- Alla fält är `final`. En widget ändras aldrig, den byggs om med nya värden.
- `Expanded` runt kolumnen förhindrar overflow om beskrivningen är lång.

## Exempel: Skärm med bokningslista

```dart
import 'package:flutter/material.dart';

class Booking {
  const Booking({
    required this.resourceName,
    required this.start,
    required this.end,
    this.note,
  });

  final String resourceName;
  final DateTime start;
  final DateTime end;
  final String? note;
}

String _tid(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _datum(DateTime d) => '${d.day}/${d.month}';

class BookingListScreen extends StatelessWidget {
  const BookingListScreen({super.key, required this.bookings});

  final List<Booking> bookings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mina bokningar')),
      body: bookings.isEmpty
          ? const Center(child: Text('Du har inga bokningar'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final b = bookings[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text(_datum(b.start))),
                    title: Text(b.resourceName),
                    subtitle: Text(
                      '${_tid(b.start)}–${_tid(b.end)}'
                      '${b.note != null ? ' · ${b.note}' : ''}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('Ny bokning'),
      ),
    );
  }
}

void main() {
  runApp(
    MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: BookingListScreen(
        bookings: [
          Booking(
            resourceName: 'Tvättstuga 1',
            start: DateTime(2026, 3, 14, 8),
            end: DateTime(2026, 3, 14, 11),
          ),
          Booking(
            resourceName: 'Festlokalen',
            start: DateTime(2026, 3, 20, 17),
            end: DateTime(2026, 3, 20, 23),
            note: '40-årsfest',
          ),
        ],
      ),
    ),
  );
}
```

🧪 **Prova själv:**

1. Ersätt `ListView.separated` med en `Column` och lägg till 20 bokningar. Vilket
   fel får du? Byt tillbaka.
2. Byt `seedColor` till din favoritfärg och kör med mörkt läge på telefonen/datorn.
3. Gör en `ResourceListScreen` som visar en lista av `ResourceCard`. Skicka in en
   `onBook` som skriver ut resursens namn med `print`.

## Sammanfattning

- Ett gränssnitt är ett träd av oföränderliga widgets som beskrivs i `build`.
- `Row`/`Column` + `Expanded`/`SizedBox`/`Padding` räcker för de flesta layouter.
- Använd `ListView.builder` för listor som kan bli långa.
- *Constraints go down, sizes go up, parent sets position.* De flesta layoutfel
  löses med `Expanded` eller en scrollbar widget.
- Hämta färger och textstilar från `Theme.of(context)` och använd
  `ColorScheme.fromSeed`.

Hittills har alla widgets varit `StatelessWidget`, som bara visar data som de får
in. I nästa kapitel gör vi saker *interaktiva*.

**Nästa kapitel:** [03 – State och livscykel](03-state-och-livscykel.md)

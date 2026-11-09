# 4. State och interaktion

Hittills visar appen bara saker. Nu ska man kunna **göra** något, till exempel
gilla ett inlägg.

## Vad är state?

**State** (tillstånd) är data som kan ändras medan appen körs, och som påverkar
vad som syns. Till exempel:

- om du har gillat ett inlägg
- hur många gillningar inlägget har
- vad du har skrivit i ett textfält

När state ändras ska skärmen ritas om:

```
 du trycker      state ändras         builder körs        skärmen
 på hjärtat  ──►  liked.value = true ──► igen         ──►  visar ♥
```

## En gilla-knapp

Inläggen i modul 01 hade olika många likes. Lägg till dem i
`lib/data/sample_data.dart` som en map från inläggets id till antal likes:

```dart
// lib/data/sample_data.dart (lägg till)
const sampleLikes = {'p1': 2, 'p2': 3, 'p5': 1, 'p6': 2};
```

Sedan knappen:

```dart
// lib/widgets/like_button.dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

class LikeButton extends CompositionWidget {
  const LikeButton({super.key, this.initialLikes = 0});

  final int initialLikes;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();

    // 1. State
    final liked = ref(false);

    // 2. Ett värde som räknas fram av sig själv
    final count = computed(
      () => props.value.initialLikes + (liked.value ? 1 : 0),
    );

    // 3. En vanlig funktion
    void toggle() => liked.value = !liked.value;

    // 4. Builder-funktionen ritar UI:t
    return (context) => TextButton.icon(
          onPressed: toggle,
          icon: Icon(
            liked.value ? Icons.favorite : Icons.favorite_border,
            color: liked.value ? Colors.red : null,
          ),
          label: Text('${count.value}'),
        );
  }
}
```

Det här är nytt:

| Ord | Betyder |
|-----|---------|
| `ref(false)` | En "låda" med ett värde. Du läser och ändrar det med `.value` |
| `computed(...)` | Ett värde som räknas fram av andra värden |
| `liked.value ? a : b` | Om `liked.value` är sant, ta `a`, annars `b`. Det fungerar som i JavaScript |

### Sätt knappen i PostCard

Lägg till knappen längst ner i `Column` i `PostCard`:

```dart
// lib/widgets/post_card.dart (längst ner i children)
const SizedBox(height: 4),
Text(post.body),
LikeButton(initialLikes: sampleLikes[post.id] ?? 0),
```

Glöm inte att importera filerna överst i `post_card.dart`:
`import '../data/sample_data.dart';` och `import 'like_button.dart';`.

Spara och klicka på hjärtana. Varje knapp minns sitt eget state.

## Så fungerar det

Det här är det viktigaste i hela modulen:

```
  Widgeten skapas
        │
        ▼
  ┌─────────────────────────────┐
  │ setup()   körs EN gång      │
  │  • skapar ref och computed  │
  │  • returnerar builder ──┐   │
  └─────────────────────────┼───┘
                            ▼
  ┌─────────────────────────────┐
  │ builder  (context) => ...   │◄──┐
  │  • läser liked.value        │   │ körs igen av sig själv
  └─────────────────────────────┘   │
                                    │
  liked.value = true ───────────────┘
```

1. **`setup()` körs en gång** när widgeten skapas. Allt du skapar där lever lika
   länge som widgeten.
2. **Builder-funktionen** ritar UI:t. Medan den körs kommer systemet ihåg vilka
   `.value` den läste.
3. **När ett av de värdena ändras** körs builder-funktionen igen, och skärmen
   uppdateras av sig själv.

💡 Läser builder-funktionen inte ett värde, så körs den inte heller om när det
värdet ändras. Det gör appen snabb.

## Kan du Vue?

Då känner du igen nästan allt. Flutter Compositions bygger på Vue 3:s
*Composition API*.

| Vue 3 (`<script setup>`) | Flutter Compositions | Kapitel |
|--------------------------|----------------------|---------|
| `<script setup>` | `setup()` | 3 |
| `<template>` | builder-funktionen `(context) => ...` | 3 |
| `const n = ref(0)` | `final n = ref(0);` | 5 |
| `{{ n }}` i template | `Text('${n.value}')`, **alltid** `.value` | 5 |
| `computed(() => ...)` | `computed(() => ...)` | 5 |
| `watch` / `watchEffect` | `watch` / `watchEffect` | 6 |
| `onMounted` / `onUnmounted` | `onMounted` / `onUnmounted` | 6 |
| `defineProps` | fält i klassen + `widget()` | 7 |
| `v-model` | `useTextEditingController()` | 7 |
| `provide` / `inject` | `provide` / `inject` med `InjectionKey` | 11 |
| `v-if` / `v-for` | `if` / `for` i en lista med widgets | 5 |

⚠️ **Den största skillnaden:** I Vue packar templaten upp `ref` åt dig. I Dart
gör ingen det. Skriver du `Text('$count')` i stället för
`Text('${count.value}')` står det något i stil med `Instance of 'ComputedRef<int>'`
på skärmen.

## Regler att komma ihåg

Det här är de fem viktigaste reglerna. Vi förklarar dem mer i kapitlen som
kommer.

| # | Regel | Varför |
|---|-------|--------|
| 1 | `setup()` körs **en gång** och får **aldrig** vara `async` | Den måste returnera builder-funktionen direkt. Hämta data med `onMounted` eller `useAsyncData` (kapitel 6 och 9) |
| 2 | Läs och skriv alltid med **`.value`**. Skapa `ref` i `setup()`, **aldrig** i builder-funktionen | Builder-funktionen körs många gånger. En `ref` där skulle börja om från början varje gång |
| 3 | **Ersätt** listor, ändra dem inte | `posts.value.add(x)` märks inte. Skriv `posts.value = [...posts.value, x]` (kapitel 5) |
| 4 | Anropa `ref`, `computed`, `watch`, `onMounted`, `use...` och `inject` **direkt i `setup()`** | Inte i en `if`, inte i en knapp och inte inuti `onMounted` |
| 5 | Läs props med **`widget()`** och temat med **`useTheme()`** | Annars ser du bara det första värdet (kapitel 7) |

## Övningar

**4.1** Sätt `LikeButton` i `PostCard` som i kapitlet. Tryck på hjärtat på två
olika kort. Vad händer med siffrorna?

**4.2** Skriv en `CompositionWidget` som heter `FollowButton`. Den ska ha en
`ref` `following` (`false` från början) och en `ref` `followers` (`12` från
början). När man trycker på knappen ska `following` växla, och `followers` öka
eller minska med 1. Knappen ska visa texten "Följ" eller "Sluta följa". Använd
en `computed` för texten.

**4.3** Ändra builder-funktionen i `FollowButton` så att den har en
block-kropp, och lägg till `debugPrint('builder körs')` först:

```dart
return (context) {
  debugPrint('builder körs');
  return Column(children: [ /* ... */ ]);
};
```

Hur ofta skrivs texten ut? Lägg sedan till en `ref` som builder-funktionen
**inte** läser, och en knapp som ändrar den. Skrivs något ut när du trycker?

**4.4** Koden nedan kompilerar, men den fungerar inte. Hitta de tre felen.
Använd reglerna ovan.

```dart
class TagList extends CompositionWidget {
  const TagList({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final tags = ref(<String>['#kvittra']);

    return (context) {
      final clicks = ref(0);
      return Column(
        children: [
          Text('Antal klick: $clicks'),
          TextButton(
            onPressed: () {
              clicks.value++;
              tags.value.add('#flutter');
            },
            child: const Text('Lägg till'),
          ),
          for (final t in tags.value) Text(t),
        ],
      );
    };
  }
}
```

Lösningar finns i [losningar.md](losningar.md#kapitel-4--state-och-interaktion).

Nästa kapitel: [ref och computed](05-ref-och-computed.md)

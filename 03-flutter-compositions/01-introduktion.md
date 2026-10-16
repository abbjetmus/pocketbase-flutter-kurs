# 1. Introduktion

## Varför något nytt?

I [modul 02](../02-flutter/04-state-och-interaktion.md) skrev du en gilla-knapp
som `StatefulWidget`. Den såg ut ungefär så här:

```dart
class LikeButton extends StatefulWidget {
  const LikeButton({super.key});

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  bool _liked = false;

  void _toggle() {
    setState(() {
      _liked = !_liked;
    });
  }

  @override
  Widget build(BuildContext context) {
    final count = 41 + (_liked ? 1 : 0);
    return Row(
      children: [
        IconButton(
          onPressed: _toggle,
          icon: Icon(_liked ? Icons.favorite : Icons.favorite_border),
        ),
        Text('$count gillningar'),
      ],
    );
  }
}
```

Det fungerar, men det finns några jobbiga saker:

| Problem | Varför är det jobbigt? |
|---------|------------------------|
| Två klasser för varje widget | `LikeButton` och `_LikeButtonState`. Mycket kod för lite |
| Du måste komma ihåg `setState` | Glömmer du det ändras inte skärmen |
| Controllers måste städas | `TextEditingController` ska `dispose`:as, annars läcker minne |
| Logik går inte att återanvända | Samma kod måste skrivas om i varje widget |

## Samma knapp med Flutter Compositions

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

class LikeButton extends CompositionWidget {
  const LikeButton({super.key});

  @override
  Widget Function(BuildContext) setup() {
    // 1. State
    final liked = ref(false);

    // 2. Ett värde som räknas fram av sig själv
    final count = computed(() => 41 + (liked.value ? 1 : 0));

    // 3. En vanlig funktion. Ingen setState!
    void toggle() => liked.value = !liked.value;

    // 4. Builder-funktionen ritar UI:t
    return (context) => Row(
          children: [
            IconButton(
              onPressed: toggle,
              icon: Icon(liked.value ? Icons.favorite : Icons.favorite_border),
            ),
            Text('${count.value} gillningar'),
          ],
        );
  }
}
```

Det här är nytt:

| Ord | Betyder |
|-----|---------|
| `CompositionWidget` | Ersätter `StatefulWidget`. Bara **en** klass |
| `setup()` | En metod där du skapar ditt state |
| `ref(false)` | En "låda" med ett värde. Du läser och ändrar det med `.value` |
| `computed(...)` | Ett värde som räknas fram av andra värden |
| `(context) => ...` | **Builder-funktionen**. Den ritar UI:t, som `build()` |

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
   uppdateras. Du skriver aldrig `setState`.

💡 Läser builder-funktionen inte ett värde, så körs den inte heller om när det
värdet ändras. Det gör appen snabb.

## Jämför med StatefulWidget

| | `StatefulWidget` | `CompositionWidget` |
|---|---|---|
| Antal klasser | Två | En |
| Var finns state? | Fält i `State`-klassen | `ref` i `setup()` |
| Hur uppdateras skärmen? | Du anropar `setState()` | Av sig själv när en `ref` ändras |
| Värden som räknas fram | Räknas i `build()` varje gång | `computed`, räknas bara när det behövs |
| `initState` | `initState()` | Koden i `setup()` |
| `build` | `build()` | Builder-funktionen |
| `dispose` | `dispose()` | `onUnmounted()`, och controllers städas själva |

## Kan du Vue?

Då känner du igen nästan allt. Flutter Compositions bygger på Vue 3:s
*Composition API*.

| Vue 3 (`<script setup>`) | Flutter Compositions | Kapitel |
|--------------------------|----------------------|---------|
| `<script setup>` | `setup()` | 1 |
| `<template>` | builder-funktionen `(context) => ...` | 1 |
| `const n = ref(0)` | `final n = ref(0);` | 2 |
| `{{ n }}` i template | `Text('${n.value}')`, **alltid** `.value` | 2 |
| `computed(() => ...)` | `computed(() => ...)` | 2 |
| `watch` / `watchEffect` | `watch` / `watchEffect` | 3 |
| `onMounted` / `onUnmounted` | `onMounted` / `onUnmounted` | 3 |
| `defineProps` | fält i klassen + `widget()` | 4 |
| `v-model` | `useTextEditingController()` | 4 |
| `provide` / `inject` | `provide` / `inject` med `InjectionKey` | 6 |
| `v-if` / `v-for` | `if` / `for` i en lista med widgets | 2 |

⚠️ **Den största skillnaden:** I Vue packar templaten upp `ref` åt dig. I Dart
gör ingen det. Skriver du `Text('$count')` i stället för
`Text('${count.value}')` står det något i stil med `Instance of 'ComputedRef<int>'`
på skärmen.

## Regler att komma ihåg

Det här är de fem viktigaste reglerna. Vi förklarar dem mer i kapitlen som
kommer.

| # | Regel | Varför |
|---|-------|--------|
| 1 | `setup()` körs **en gång** och får **aldrig** vara `async` | Den måste returnera builder-funktionen direkt. Hämta data med `onMounted` eller `useAsyncData` (kapitel 3 och 7) |
| 2 | Läs och skriv alltid med **`.value`**. Skapa `ref` i `setup()`, **aldrig** i builder-funktionen | Builder-funktionen körs många gånger. En `ref` där skulle börja om från början varje gång |
| 3 | **Ersätt** listor, ändra dem inte | `posts.value.add(x)` märks inte. Skriv `posts.value = [...posts.value, x]` (kapitel 2) |
| 4 | Anropa `ref`, `computed`, `watch`, `onMounted`, `use...` och `inject` **direkt i `setup()`** | Inte i en `if`, inte i en knapp och inte inuti `onMounted` |
| 5 | Läs props med **`widget()`** och temat med **`useTheme()`** | Annars ser du bara det första värdet (kapitel 4) |

## Övningar

Skapa ett projekt enligt [README](README.md#installation) och kör det i Chrome.

**1.1** Lägg in `LikeButton` från kapitlet i appen, mitt på skärmen. Tryck på
hjärtat några gånger. Vad händer med siffran?

**1.2** Skriv en `CompositionWidget` som heter `FollowButton`. Den ska ha en
`ref` `following` (`false` från början) och en `ref` `followers` (`12` från
början). När man trycker på knappen ska `following` växla, och `followers` öka
eller minska med 1. Knappen ska visa texten "Följ" eller "Sluta följa". Använd
en `computed` för texten.

**1.3** Ändra builder-funktionen i `FollowButton` så att den har en
block-kropp, och lägg till `debugPrint('builder körs')` först:

```dart
return (context) {
  debugPrint('builder körs');
  return Column(children: [ /* ... */ ]);
};
```

Hur ofta skrivs texten ut? Lägg sedan till en `ref` som builder-funktionen
**inte** läser, och en knapp som ändrar den. Skrivs något ut när du trycker?

**1.4** Koden nedan kompilerar, men den fungerar inte. Hitta de tre felen.
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

Lösningar finns i [losningar.md](losningar.md#kapitel-1--introduktion).

Nästa kapitel: [ref och computed](02-ref-och-computed.md)

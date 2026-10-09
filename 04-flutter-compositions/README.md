# Modul 04 – Flutter Compositions

> Vue-liknande reaktivitet i Flutter: `ref`, `computed`, `watch`, composables och
> `provide`/`inject` – utan `StatefulWidget` och `setState`.

I modul 03 byggde du widgets med `StatefulWidget`, `setState()` och livscykel­metoder
som `initState` och `dispose` (se [03 – State och livscykel](../03-flutter/03-state-och-livscykel.md)).
Det fungerar, men koden blir snabbt pratig: en separat `State`-klass, manuella
`dispose()`-anrop, `didUpdateWidget` för att upptäcka nya props och `mounted`-kontroller
efter varje `await`.

I den här modulen lär du dig paketet
[`flutter_compositions`](https://yoyo930021.github.io/flutter_compositions), som tar
idéerna från **Vue 3:s Composition API** och flyttar in dem i Flutter. Kan du Vue
kommer du att känna igen nästan allt. Kan du inte Vue gör det inget, eftersom vi alltid
jämför med `StatefulWidget` också.

## Lärandemål

När du är klar med modulen ska du kunna:

1. Förklara den mentala modellen: **`setup()` körs en gång**, och **builder-funktionen
   körs om automatiskt** när reaktiva värden den läser ändras.
2. Använda `ref`, `computed`, `watch` och `watchEffect` och välja rätt verktyg för
   rätt uppgift.
3. Förstå *grund* (shallow) reaktivitet och uppdatera listor och objekt på rätt sätt
   (ersätt, mutera inte).
4. Använda livscykel­hooks (`onMounted`, `onUnmounted`, `onBuild`) och reaktiva props
   via `widget()`.
5. Använda inbyggda composables (`useTextEditingController`, `useScrollController`,
   `useTheme` …) och skriva egna (`useBookingForm`, `useDebounced` …).
6. Dela tjänster och state i widgetträdet med `provide`/`inject` och `InjectionKey`.
7. Hämta data asynkront med `useFuture`/`useAsyncData`, rendera `AsyncValue` med
   `switch` och prenumerera på PocketBase realtime med korrekt städning.
8. Följa bästa praxis, använda lint-reglerna och skriva tester för composables och
   widgets.
9. Migrera en befintlig `StatefulWidget` till en `CompositionWidget`.
10. Strukturera en större app: feature-mappar, stores, sidindelade listor, åtgärdsmenyer,
    auth-guard och roller, och lägga till en ny feature på egen hand.

## Innehåll

| # | Kapitel | Innehåll |
|---|---------|----------|
| 1 | [Introduktion](01-introduktion.md) | Varför? Mental modell, signaler, de tre widget-typerna, första räknaren, Vue-jämförelse |
| 2 | [Reaktivitet: ref och computed](02-reaktivitet-ref-och-computed.md) | `ref`, `.value`, `computed`, grund reaktivitet, listor, immutabla modeller med `copyWith` |
| 3 | [watch och watchEffect](03-watch-och-watcheffect.md) | Sidoeffekter, `watch` vs `watchEffect` vs `computed`, `immediate`, städning |
| 4 | [Livscykel och props](04-livscykel-och-props.md) | `onMounted`/`onUnmounted`/`onBuild`, `widget()`, destrukturering, vanliga misstag |
| 5 | [Composables](05-composables.md) | `use*` vs `manage*`, controllers, `useContextRef`/`useTheme`, egna composables |
| 6 | [Provide och inject](06-provide-inject.md) | `InjectionKey`, PocketBase-klient och auth i roten, scope, test-överskuggning |
| 7 | [Asynkron data](07-async-data.md) | `useFuture`, `useAsyncData`, `AsyncValue`, `useStream`, PocketBase realtime |
| 8 | [Best practices och lints](08-best-practices-och-lints.md) | Regler för `setup()`, ren builder, lints, projektstruktur, tester, migrering |
| 9 | [Arkitektur för en riktig app](09-arkitektur-for-en-riktig-app.md) | Feature-mappar, stores, `Paginated<T>`, åtgärdsmenyer, auth-guard, roller och föreningar |
| – | [Övningar](ovningar.md) | Nivå 1–3 |
| – | [Lösningar](losningar.md) | Lösningsförslag. Försök själv först! |

Räkna med 2–3 dagar. Kapitel 1–4 är grunden. Kapitel 5–7 är det du använder mest i
vardagen. Kapitel 9 knyter ihop allt till arkitekturen för en riktig föreningsapp, som
du kan bygga vidare på egen hand.

## Förkunskaper

- Modul 03: widgets, layout, `StatefulWidget`, `setState`, `go_router`, formulär.
- Modul 02: PocketBase-collections och Dart-SDK:t
  ([02 – Dart SDK](../02-pocketbase/06-dart-sdk.md)).
- Vue 3 är **inte** ett krav, men hjälper. Vue-exemplen i modulen använder alltid
  `<script setup>`.

## Installation

Vi använder version **0.1.x** av paketet, samma som i kursens referensapp.

### 1. Lägg till beroenden

Från roten av ditt Flutter-projekt:

```bash
flutter pub add flutter_compositions:^0.1.1
flutter pub add --dev flutter_compositions_lints:^0.1.1 custom_lint:^0.8.0
```

Din `pubspec.yaml` ska då innehålla ungefär:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_compositions: ^0.1.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  custom_lint: ^0.8.0
  flutter_compositions_lints: ^0.1.1
```

`flutter_compositions` drar automatiskt in signalbiblioteket
[`alien_signals`](https://pub.dev/packages/alien_signals), som är motorn under huven.

### 2. Aktivera lint-reglerna

Lint-paketet i version 0.1.x är ett plugin till
[`custom_lint`](https://pub.dev/packages/custom_lint). Lägg till detta i
`analysis_options.yaml`:

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  plugins:
    - custom_lint

custom_lint:
  enable_all_lint_rules: true
```

Kör sedan:

```bash
dart run custom_lint          # analysera en gång
dart run custom_lint --watch  # analysera löpande medan du kodar
```

> 💡 **Tips:** I VS Code visas custom_lint-varningarna direkt i editorn när
> pluginet är aktiverat. Starta om Dart Analysis Server
> (`Ctrl/Cmd+Shift+P` → *Dart: Restart Analysis Server*) om de inte dyker upp.

> ⚠️ **Varning:** Nyare versioner (0.2+) av `flutter_compositions_lints` har gått
> över till Darts inbyggda analyzer-plugins och konfigureras i stället med
> `plugins: flutter_compositions_lints: …` i `analysis_options.yaml`. Om du läser
> den officiella dokumentationen kan du se båda varianterna. Med 0.1.x gäller
> `custom_lint`-varianten ovan.

### 3. Importera

Allt du behöver finns i en enda import:

```dart
import 'package:flutter_compositions/flutter_compositions.dart';
```

### 4. Kontrollera att allt fungerar

Ersätt innehållet i `lib/main.dart` med:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

void main() => runApp(const MaterialApp(home: HelloCompositions()));

class HelloCompositions extends CompositionWidget {
  const HelloCompositions({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final clicks = ref(0);

    return (context) => Scaffold(
          body: Center(child: Text('Klick: ${clicks.value}')),
          floatingActionButton: FloatingActionButton(
            onPressed: () => clicks.value++,
            child: const Icon(Icons.add),
          ),
        );
  }
}
```

Kör `flutter run`. Räknaren ökar när du trycker, och du har inte skrivit något
`setState`. Hur det går till förklaras i [kapitel 1](01-introduktion.md).

## Snabbreferens: Vue ↔ Flutter Compositions

| Vue 3 (`<script setup>`) | Flutter Compositions | Kapitel |
|--------------------------|----------------------|---------|
| `const n = ref(0)` | `final n = ref(0);` | 2 |
| `n.value++` (i script) / `{{ n }}` (i template) | `n.value++` / `Text('${n.value}')`, alltid `.value` | 2 |
| `computed(() => …)` | `computed(() => …)` | 2 |
| `watch(src, (nytt, gammalt) => …)` | `watch(() => src.value, (nytt, gammalt) { … })` | 3 |
| `watchEffect(() => …)` | `watchEffect(() { … })` | 3 |
| `onMounted` / `onUnmounted` | `onMounted` / `onUnmounted` | 4 |
| `defineProps<{ name: string }>()` | fält i widget-klassen + `final props = widget();` | 4 |
| `defineEmits` | callback-props, t.ex. `final ValueChanged<String> onChanged;` | 4 |
| Composable `useMouse()` | Composable `useMouse()`, en vanlig funktion som anropas i `setup()` | 5 |
| `v-model="text"` | `final (controller, text, _) = useTextEditingController();` | 5 |
| `provide(key, value)` / `inject(key)` | `provide(key, value)` / `inject(key)` med `InjectionKey<T>` | 6 |
| `<template>` | builder-funktionen `(context) => …` som `setup()` returnerar | 1 |
| `v-if` / `v-for` | `if (…)` / `for (… in …)` i listor, eller ternär `?:` | 1 |

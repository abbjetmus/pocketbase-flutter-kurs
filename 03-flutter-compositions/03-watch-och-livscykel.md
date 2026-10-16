# 3. watch och livscykel

`computed` räknar fram **värden**. Ibland vill du i stället **göra något** när
ett värde ändras: skriva ut något, spara, visa ett meddelande eller hämta data.
Sådant kallas **sidoeffekter**. För dem finns `watch` och `watchEffect`.

Vi går också igenom `onMounted` och `onUnmounted`, som körs när widgeten visas
och försvinner.

## watch

```dart
final likes = ref(0);

watch(() => likes.value, (newValue, oldValue) {
  debugPrint('likes ändrades från $oldValue till $newValue');
});
```

`watch` har två delar:

| Del | Exempel | Betyder |
|-----|---------|---------|
| Vad ska bevakas? | `() => likes.value` | En funktion som returnerar värdet |
| Vad ska göras? | `(newValue, oldValue) { ... }` | Körs när värdet ändras. Du får både det nya och det gamla värdet |

`watch` körs **inte** när widgeten startar, bara när värdet ändras. Vill du att
den ska köras direkt också skriver du `immediate: true`:

```dart
watch(() => likes.value, (n, o) => debugPrint('$o → $n'), immediate: true);
// Första gången är o null
```

Vill du bevaka flera värden returnerar du en *record* med parenteser:

```dart
watch(() => (filter.value, search.value), (nytt, gammalt) {
  debugPrint('Filter: ${nytt.$1}, sök: ${nytt.$2}');
});
```

### Vue och Dart

| Vue | Flutter Compositions |
|-----|----------------------|
| `watch(likes, (n, o) => ...)` | `watch(() => likes.value, (n, o) { ... })` |
| `watch([a, b], ...)` | `watch(() => (a.value, b.value), ...)` |

I Dart är det första argumentet **alltid en funktion**.

## watchEffect

```dart
watchEffect(() {
  debugPrint('likes är nu ${likes.value}');
});
```

`watchEffect` körs **direkt en gång**. Sedan körs den igen varje gång något
som den läste ändras. Du behöver inte säga vad den ska bevaka, och du får inget
gammalt värde.

## När körs de?

`watch` och `watchEffect` körs **direkt** vid varje ändring. Tre ändringar i
rad ger tre körningar:

```dart
likes.value++; // skriver ut 0 → 1
likes.value++; // skriver ut 1 → 2
likes.value++; // skriver ut 2 → 3
```

Skärmen ritas däremot bara om en gång.

## Vanliga misstag

**Använda watch för att räkna fram ett värde**

```dart
// ❌ Fel verktyg
final fullName = ref('');
watch(() => firstName.value, (name, _) => fullName.value = '$name Andersson');

// ✅ Rätt verktyg
final fullName = computed(() => '${firstName.value} Andersson');
```

**Läsa och ändra samma ref i en watchEffect**

```dart
// ❌ Oändlig loop: den läser count, ändrar count, körs igen, ...
watchEffect(() {
  count.value = count.value + 1;
});
```

## onMounted och onUnmounted

| Hook | När körs den? | Används till |
|------|---------------|--------------|
| `onMounted(() { ... })` | När widgeten har visats första gången | Starta en timer, hämta data, börja lyssna på något |
| `onUnmounted(() { ... })` | Precis innan widgeten tas bort | Stoppa timern, sluta lyssna |

| `StatefulWidget` | `CompositionWidget` |
|------------------|---------------------|
| `initState()` | Koden i `setup()`, eller `onMounted` |
| `dispose()` | `onUnmounted` |

### Exempel: en timer

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

class ReadingTimer extends CompositionWidget {
  const ReadingTimer({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final seconds = ref(0);
    Timer? timer;

    onMounted(() {
      debugPrint('onMounted: startar timern');
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        seconds.value++;
      });
    });

    onUnmounted(() {
      debugPrint('onUnmounted: stoppar timern');
      timer?.cancel();
    });

    final label = computed(() => 'Du har läst i ${seconds.value} sekunder');

    return (context) => Text(label.value);
  }
}
```

En sida som kan visa och dölja timern:

```dart
class TimerPage extends CompositionWidget {
  const TimerPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final show = ref(true);

    return (context) => Scaffold(
          body: Column(
            children: [
              SwitchListTile(
                title: const Text('Visa timern'),
                value: show.value,
                onChanged: (v) => show.value = v,
              ),
              if (show.value) const ReadingTimer(),
            ],
          ),
        );
  }
}
```

Slå av switchen. Då försvinner `ReadingTimer`, och `onUnmounted` stoppar
timern.

⚠️ **Städa alltid.** En `Timer` stoppas inte av sig själv. Glömmer du
`timer?.cancel()` fortsätter den att gå fast widgeten är borta. `watch` och
`watchEffect` städas däremot automatiskt.

### Registrera båda direkt i setup()

Lägg **aldrig** `onUnmounted` inuti `onMounted`. Det fungerar inte i version
0.1, och timern stoppas aldrig. Dela i stället en variabel, som `timer` ovan.

```dart
// ❌ Fungerar inte
onMounted(() {
  final t = Timer.periodic(const Duration(seconds: 1), (_) => seconds.value++);
  onUnmounted(() => t.cancel());
});

// ✅ Båda direkt i setup(), med en delad variabel
Timer? timer;
onMounted(() => timer = Timer.periodic(const Duration(seconds: 1), (_) => seconds.value++));
onUnmounted(() => timer?.cancel());
```

Samma sak gäller `watch`, `computed` och `inject`. Anropa dem bara direkt i
`setup()`.

### Async i onMounted

`setup()` får inte vara `async`, men `onMounted` får det:

```dart
final titles = ref(<String>[]);
final loading = ref(true);

onMounted(() async {
  titles.value = await fetchTitles();
  loading.value = false;
});
```

I kapitel 7 lär du dig `useAsyncData`, som gör det här enklare och dessutom tar
hand om fel.

## När använder jag vad?

| Du vill … | Använd |
|-----------|--------|
| Räkna fram ett värde från annat state | `computed` |
| Göra något när ett värde ändras, och veta det gamla värdet | `watch` |
| Göra något direkt och sedan vid varje ändring | `watchEffect` |
| Starta något när widgeten visas | `onMounted` |
| Stoppa något när widgeten försvinner | `onUnmounted` |

## Övningar

**3.1** Gör en widget med `final likes = ref(0)` och två knappar, "Gilla" och
"Ta bort like". Lägg till en `watch` som skriver ut "ökade" eller "minskade"
med `debugPrint`.

**3.2** Lägg till en `watchEffect` i samma widget som skriver ut `likes`. Starta
om appen. Vilken av `watch` och `watchEffect` skriver ut något direkt? Lägg
sedan till `immediate: true` på din `watch`. Vad är `oldValue` första gången?

**3.3** Bygg `ReadingTimer` och `TimerPage`. Slå av och på switchen och titta i
terminalen. Börjar sekunderna om från 0 när timern visas igen? Varför?

**3.4** Ta bort `onUnmounted` från `ReadingTimer` och lägg till
`debugPrint('tick')` i timern. Vad händer när du slår av switchen? Lägg sedan
tillbaka `onUnmounted`.

**3.5** Vilket verktyg passar? Välj `computed`, `watch`, `watchEffect`,
`onMounted` eller `onUnmounted`:

1. Visa "3 kommentarer" utifrån en lista med kommentarer.
2. Visa en SnackBar när antalet likes går från 9 till 10.
3. Sluta lyssna på nya kommentarer när sidan stängs.
4. Hämta inlägg när sidan öppnas.

Lösningar finns i [losningar.md](losningar.md#kapitel-3--watch-och-livscykel).

Nästa kapitel: [Props och composables](04-props-och-composables.md)

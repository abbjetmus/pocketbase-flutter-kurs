# 6. Livscykel

En widget **visas** och **försvinner**. Ibland vill du göra något just då,
till exempel starta en timer när widgeten visas och stoppa den när widgeten
försvinner. För det finns `onMounted` och `onUnmounted`.

## onMounted och onUnmounted

| Hook | När körs den? | Används till |
|------|---------------|--------------|
| `onMounted(() { ... })` | När widgeten har visats första gången | Starta en timer, hämta data, börja lyssna på något |
| `onUnmounted(() { ... })` | Precis innan widgeten tas bort | Stoppa timern, sluta lyssna |

| Vue | Flutter Compositions |
|-----|----------------------|
| `onMounted(() => { ... })` | `onMounted(() { ... });` |
| `onUnmounted(() => { ... })` | `onUnmounted(() { ... });` |

## Exempel: en timer

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

    return (context) => Text('Du har läst i ${seconds.value} sekunder');
  }
}
```

- `Timer.periodic` kör funktionen en gång i sekunden.
- `Timer? timer` delas av `onMounted` och `onUnmounted`. Så kan
  `onUnmounted` stoppa samma timer som `onMounted` startade.

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

Visa sidan genom att tillfälligt byta `home:` i `main.dart` till
`const TimerPage()`. Slå av switchen. Då försvinner `ReadingTimer`, och
`onUnmounted` stoppar timern.

⚠️ **Städa alltid.** En `Timer` stoppas inte av sig själv. Glömmer du
`timer?.cancel()` fortsätter den att gå fast widgeten är borta.

## Registrera båda direkt i setup()

Lägg **aldrig** `onUnmounted` inuti `onMounted`. Då får du ett fel. Skriv båda
direkt i `setup()`, och dela en variabel som `timer` ovan.

```dart
// ❌ Ger ett fel
onMounted(() {
  final t = Timer.periodic(const Duration(seconds: 1), (_) => seconds.value++);
  onUnmounted(() => t.cancel());
});

// ✅ Båda direkt i setup(), med en delad variabel
Timer? timer;
onMounted(() => timer = Timer.periodic(const Duration(seconds: 1), (_) => seconds.value++));
onUnmounted(() => timer?.cancel());
```

## Async i onMounted

`setup()` får inte vara `async`, men `onMounted` får det:

```dart
final titles = ref(<String>[]);
final loading = ref(true);

onMounted(() async {
  titles.value = await fetchTitles();
  loading.value = false;
});
```

I kapitel 8 lär du dig `useAsyncData`, som gör det här enklare och dessutom tar
hand om fel.

## När använder jag vad?

| Du vill … | Använd |
|-----------|--------|
| Starta något när widgeten visas | `onMounted` |
| Stoppa något när widgeten försvinner | `onUnmounted` |

## Övningar

**6.1** Bygg `ReadingTimer` och `TimerPage`. Slå av och på switchen och titta i
konsolen (`F12` → **Console**). Börjar sekunderna om från 0 när timern visas
igen? Varför?

**6.2** Ta bort `onUnmounted` från `ReadingTimer` och lägg till
`debugPrint('tick')` i timern. Vad händer när du slår av switchen? Lägg sedan
tillbaka `onUnmounted`.

**6.3** Vilket verktyg passar? Välj `onMounted` eller `onUnmounted`:

1. Starta en timer när sidan visas.
2. Sluta lyssna på nya kommentarer när sidan stängs.
3. Hämta inlägg när sidan öppnas.

Lösningar finns i [losningar.md](losningar.md#kapitel-6--livscykel).

Nästa kapitel: [Navigation och formulär](07-navigation-och-formular.md)

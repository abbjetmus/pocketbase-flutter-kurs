# 1. Introduktion till Flutter Compositions

## Vilket problem löser vi?

Titta på en helt vanlig räknare skriven som `StatefulWidget`, alltså det du lärde dig i
[modul 03](../03-flutter/03-state-och-livscykel.md):

```dart
class Counter extends StatefulWidget {
  const Counter({super.key});

  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  int _count = 0;

  void _increment() {
    setState(() {
      _count++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Antal: $_count'),
        Text('Dubbelt: ${_count * 2}'),
        ElevatedButton(onPressed: _increment, child: const Text('+1')),
      ],
    );
  }
}
```

Det går bra så länge widgeten är liten. I riktiga skärmar, som bokningsformuläret i
föreningsappen, växer det snabbt:

- **Två klasser** för varje widget med state (`Counter` + `_CounterState`).
- **`setState()` måste komma ihåg att anropas.** Glömmer du det uppdateras inte UI:t.
- **Härledda värden** (t.ex. "är formuläret giltigt?") räknas om i `build()` varje
  gång, eller så lagras de i ett eget fält som du måste hålla i synk manuellt.
- **Controllers** (`TextEditingController`, `ScrollController`, `AnimationController`)
  ska skapas i `initState` och städas i `dispose`. Glömmer du det läcker minne.
- **Nya props** från föräldern upptäcks bara om du skriver `didUpdateWidget`.
- **Async** kräver `if (mounted)` efter varje `await`.
- **Logik går inte att återanvända** mellan widgets utan mixins eller arv.

Vue-utvecklare har haft samma problem. Vue 2:s "Options API" spred ut logiken över
`data`, `computed`, `watch` och `methods`. Vue 3 löste det med **Composition API**:
logik som hör ihop skrivs ihop i en `setup`-funktion och kan brytas ut i återanvändbara
*composables*. `flutter_compositions` gör samma sak för Flutter.

## Samma räknare med Flutter Compositions

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

class Counter extends CompositionWidget {
  const Counter({super.key});

  @override
  Widget Function(BuildContext) setup() {
    // 1. Reaktivt state
    final count = ref(0);

    // 2. Härlett värde, räknas om automatiskt när count ändras
    final doubled = computed(() => count.value * 2);

    // 3. Vanlig funktion, ingen setState
    void increment() => count.value++;

    // 4. Builder-funktionen = "template"
    return (context) => Column(
          children: [
            Text('Antal: ${count.value}'),
            Text('Dubbelt: ${doubled.value}'),
            ElevatedButton(onPressed: increment, child: const Text('+1')),
          ],
        );
  }
}
```

Det här har försvunnit: `State`-klassen, `setState` och den manuella omräkningen.
Det här har tillkommit: `ref`, `computed` och en `setup()`-metod som **returnerar en
funktion**.

## Den mentala modellen

Det här är det viktigaste i hela modulen. Läs det två gånger.

```
            ┌──────────────────────────────────────────┐
  Widgeten  │ setup()  körs EN gång                    │
  monteras ─►  • skapar ref, computed, watch           │
            │  • registrerar onMounted/onUnmounted     │
            │  • returnerar builder-funktionen ───┐    │
            └─────────────────────────────────────┼────┘
                                                  ▼
            ┌──────────────────────────────────────────┐
            │ builder (context) => Widget              │◄─┐
            │  • läser count.value, doubled.value …    │  │ körs om automatiskt
            │  • systemet minns VILKA refs som lästes  │  │ när någon av de
            └──────────────────────────────────────────┘  │ lästa refs ändras
                                                          │
  count.value++ ──────────────────────────────────────────┘
```

1. **`setup()` körs en gång** när widgeten skapas, ungefär som `initState`. Allt du
   deklarerar där (refs, computed, funktioner) lever lika länge som widgeten.
2. **Builder-funktionen är en *effect*.** Den körs första gången för att bygga UI:t.
   Medan den körs registrerar systemet varje `.value` som läses. Det kallas
   *dependency tracking*.
3. **När en av de lästa refs ändras** körs builder-funktionen om, och Flutter
   uppdaterar skärmen. Du anropar aldrig `setState` själv.

### Signaler och alien_signals

Under huven är varje `ref` en **signal** från biblioteket
[`alien_signals`](https://pub.dev/packages/alien_signals). En signal är en låda med ett
värde som håller reda på vem som läser den och meddelar dem när värdet ändras. Samma
idé finns i Vue (`ref`), SolidJS (signals), Preact Signals och Angular Signals.

Det kallas **finkornig reaktivitet** (fine-grained reactivity). Uppdateringen drivs av
exakt vilka värden som lästes, inte av att "något i widgeten ändrades".

> 💡 **Tips:** Läser builder-funktionen inte `count.value` körs den inte om när `count`
> ändras. Det är därför du får prestanda "gratis": widgets som inte bryr sig om ett
> värde påverkas inte.

### Jämförelse med StatefulWidget

| | `StatefulWidget` | `CompositionWidget` |
|---|---|---|
| Var lever state? | Fält i en separat `State`-klass | Lokala variabler (refs) i `setup()` |
| Hur triggas omritning? | Manuellt med `setState()` | Automatiskt när en läst ref ändras |
| Härledda värden | Räknas i `build()` eller hålls i synk för hand | `computed()`, cachat |
| Controllers | Skapas i `initState`, städas i `dispose` | `use*`-composables, städas automatiskt |
| Nya props | `didUpdateWidget` | `widget()` är reaktivt |
| Återanvändning | Mixins, arv | Composables (vanliga funktioner) |

## De tre widget-typerna

`flutter_compositions` ger dig tre widgets. Den första använder du 95 % av tiden.

### `CompositionWidget`

En återanvändbar widget-klass med props (fält) och en `setup()`-metod. Det är din
ersättare för `StatefulWidget`.

```dart
class ResourceCard extends CompositionWidget {
  const ResourceCard({super.key, required this.name});

  final String name;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget(); // reaktiv åtkomst till props, se kapitel 4
    final title = computed(() => 'Resurs: ${props.value.name}');
    return (context) => Card(child: Text(title.value));
  }
}
```

### `CompositionBuilder`

Samma sak men *inline*, utan egen klass. Bra för engångs-UI, dialoger och tester.

```dart
CompositionBuilder(
  setup: () {
    final open = ref(false);
    return (context) => SwitchListTile(
          title: const Text('Visa endast lediga tider'),
          value: open.value,
          onChanged: (v) => open.value = v,
        );
  },
)
```

### `ComputedBuilder`

Avgränsar en del av UI:t till en egen effect. Bara den delen byggs om när de refs den
läser ändras. Den används för prestanda.

```dart
@override
Widget Function(BuildContext) setup() {
  final seconds = ref(0);   // ändras varje sekund
  final title = ref('Tvättstuga 1');

  // ... en timer ökar seconds ...

  return (context) => Column(
        children: [
          Text(title.value),           // byggs om när title ändras
          ComputedBuilder(             // byggs om ENDAST när seconds ändras
            builder: (context) => Text('Tid kvar: ${seconds.value}s'),
          ),
          const ExpensiveChart(),      // const: byggs aldrig om
        ],
      );
}
```

| Situation | Använd |
|-----------|--------|
| Återanvändbar komponent med props | `CompositionWidget` |
| Engångs-UI, dialog, test-harness | `CompositionBuilder` |
| Isolera en ofta uppdaterad del av en stor widget | `ComputedBuilder` |
| Helt statiskt UI utan state | Vanlig `StatelessWidget` eller `const`-widget |

## Vue-jämförelse: samma komponent i båda världarna

Så här ser räknaren ut i Vue 3 med `<script setup>`:

```vue
<script setup lang="ts">
import { ref, computed } from 'vue'

const count = ref(0)
const doubled = computed(() => count.value * 2)

function increment() {
  count.value++
}
</script>

<template>
  <div>
    <p>Antal: {{ count }}</p>
    <p>Dubbelt: {{ doubled }}</p>
    <button @click="increment">+1</button>
  </div>
</template>
```

Och i Flutter Compositions:

```dart
class Counter extends CompositionWidget {
  const Counter({super.key});

  @override
  Widget Function(BuildContext) setup() {           // ≈ <script setup>
    final count = ref(0);                            // ≈ const count = ref(0)
    final doubled = computed(() => count.value * 2); // ≈ computed(...)
    void increment() => count.value++;               // ≈ function increment()

    return (context) => Column(children: [           // ≈ <template>
          Text('Antal: ${count.value}'),             // ≈ {{ count }}
          Text('Dubbelt: ${doubled.value}'),
          ElevatedButton(                            // ≈ <button @click=...>
            onPressed: increment,
            child: const Text('+1'),
          ),
        ]);
  }
}
```

| Begrepp | Vue 3 | Flutter Compositions | Skillnad att tänka på |
|---------|-------|----------------------|------------------------|
| Setup-kod | `<script setup>` | `setup()`-metoden | Båda körs en gång per komponentinstans |
| Template | `<template>` med HTML-liknande syntax | builder-funktion som returnerar widgets | Dart-kod, inte en mall |
| Läsa en ref | `.value` i script, automatiskt i template | **alltid** `.value` | Ingen auto-unwrap i Dart |
| Reaktivitetsmotor | Proxy-baserad, djup som standard | `alien_signals`, **grund** | Se kapitel 2 |
| Villkor | `v-if` | `if` i listor eller `?:` | |
| Loopar | `v-for` | `for (final x in lista)` i listor | |
| Event | `@click="fn"` | `onPressed: fn` | |
| Props | `defineProps` | fält + `widget()` | Se kapitel 4 |
| DI-nycklar | `InjectionKey` (Symbol) | `InjectionKey<T>` | Se kapitel 6 |

> ⚠️ **Varning:** Det vanligaste nybörjarfelet för Vue-utvecklare är att glömma
> `.value` i builder-funktionen. `Text('$count')` skriver ut något i stil med
> `Instance of 'Ref<int>'` i stället för siffran. I Dart finns ingen template som packar
> upp refs åt dig.

## Villkor och listor i builder-funktionen

Builder-funktionen är vanlig Dart. Det som i Vue heter `v-if` och `v-for` skriver du med
Darts *collection if* och *collection for*:

```dart
@override
Widget Function(BuildContext) setup() {
  final resources = ref(<String>['Tvättstuga 1', 'Tvättstuga 2', 'Festlokalen']);
  final showAll = ref(true);
  final visible = computed(
    () => showAll.value ? resources.value : resources.value.take(1).toList(),
  );

  return (context) => Column(
        children: [
          SwitchListTile(
            title: const Text('Visa alla'),
            value: showAll.value,
            onChanged: (v) => showAll.value = v,
          ),
          for (final r in visible.value) ListTile(title: Text(r)), // v-for
          if (visible.value.isEmpty) const Text('Inga resurser'),  // v-if
        ],
      );
}
```

Lägg märke till att *filtreringen* görs i en `computed` i `setup()`, inte i
builder-funktionen. Det är en viktig vana som du lär dig mer om i
[kapitel 8](08-best-practices-och-lints.md).

## Signaturen `Widget Function(BuildContext) setup()`

`setup()` har en ovanlig returtyp: den returnerar en **funktion** som tar en
`BuildContext` och returnerar en `Widget`. Det är builder-funktionen.

```dart
@override
Widget Function(BuildContext) setup() {
  // ... setup-kod, körs en gång ...
  return (context) => Text('hej');   // pilsyntax
}

// eller med block-kropp när du behöver destrukturera props (kapitel 4):
@override
Widget Function(BuildContext) setup() {
  final props = widget();
  return (context) {
    final MyWidget(:title) = props.value;
    return Text(title);
  };
}
```

> ⚠️ **Varning:** `setup()` får **inte** vara `async`. Den måste returnera
> builder-funktionen direkt. Asynkront arbete gör du i `onMounted` eller med
> `useFuture`/`useAsyncData` (kapitel 4 och 7).

## 🧪 Prova själv

1. Skapa en `CompositionWidget` `LikeButton` med en ref `likes` och en ref `liked`
   (bool). Knappen ska växla `liked` och öka eller minska `likes`.
2. Lägg till en `computed` `label` som blir `"1 gillning"` eller `"N gillningar"`.
3. Lägg till `print('builder körs')` överst i builder-funktionen (använd block-kropp).
   Hur ofta skrivs det ut? Lägg sedan till en ref som inte läses i builder-funktionen
   och ändra den från en knapp. Skrivs något ut?

Svaret på fråga 3: builder-funktionen körs bara när en ref som den *läser* ändras.
Det är finkornig reaktivitet i praktiken.

## Sammanfattning

- `CompositionWidget` ersätter `StatefulWidget`. `setup()` körs **en** gång och
  returnerar en builder-funktion.
- Builder-funktionen är en effect som körs om när de refs den läser ändras.
- `ref` håller state, `computed` håller härledda värden, och båda läses med `.value`.
- `CompositionBuilder` är för inline-UI och tester. `ComputedBuilder` används för att
  isolera ofta uppdaterade delar.
- Modellen är nästan identisk med Vue 3:s `<script setup>`. Skillnaden är att Dart
  alltid kräver `.value` och att reaktiviteten är grund.

Nästa kapitel: [Reaktivitet: ref och computed →](02-reaktivitet-ref-och-computed.md)

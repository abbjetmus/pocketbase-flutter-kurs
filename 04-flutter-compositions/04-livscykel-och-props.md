# 4. Livscykel och props

## Livscykel-hooks

En `StatefulWidget` har `initState`, `didChangeDependencies`, `didUpdateWidget`,
`build` och `dispose`. En `CompositionWidget` har i stället tre hooks som du registrerar
i `setup()`:

| Hook | När den körs | Typisk användning |
|------|-------------|-------------------|
| `onMounted(() { … })` | Efter första framen, när widgeten finns på skärmen | Nätverksanrop, starta timers och animationer, prenumerationer |
| `onUnmounted(() { … })` | Precis innan widgeten tas bort | Städa timers, streams och annat som inte städas automatiskt |
| `onBuild((context) { … })` | Varje gång builder-funktionen körs, med `BuildContext` | Används främst internt av composables, sällan direkt |

### Mappning från StatefulWidget

| StatefulWidget | CompositionWidget |
|----------------|-------------------|
| Konstruktor i `State` + fält | Lokala variabler och refs i `setup()` |
| `initState()` | Kroppen i `setup()` |
| `WidgetsBinding.instance.addPostFrameCallback` i `initState` | `onMounted()` |
| `build()` | Builder-funktionen som `setup()` returnerar |
| `didUpdateWidget()` | Automatiskt via `widget()` (se nedan) |
| `didChangeDependencies()` | Automatiskt via `useContextRef()`/`useTheme()` … (kapitel 5) |
| `dispose()` | `onUnmounted()` + automatisk städning |
| `setState()` | Skriv till en ref |
| `mounted` | Behövs sällan. Refs kan skrivas även efter avmontering utan krasch |

### Vue ↔ Dart

```vue
<script setup lang="ts">
import { onMounted, onUnmounted, ref } from 'vue'

const now = ref(new Date())
let timer: number | undefined

onMounted(() => {
  timer = setInterval(() => (now.value = new Date()), 1000)
})

onUnmounted(() => {
  clearInterval(timer)
})
</script>
```

```dart
@override
Widget Function(BuildContext) setup() {
  final now = ref(DateTime.now());
  Timer? timer;

  onMounted(() {
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      now.value = DateTime.now();
    });
  });

  onUnmounted(() {
    timer?.cancel();
  });

  return (context) => Text('${now.value.hour}:${now.value.minute}:${now.value.second}');
}
```

### Async i `onMounted`

`setup()` får inte vara `async`, men `onMounted` får det:

```dart
final resources = ref(<Resource>[]);
final loading = ref(true);

onMounted(() async {
  resources.value = await service.fetchActiveResources();
  loading.value = false;
});
```

Det fungerar, men i [kapitel 7](07-async-data.md) lär du dig `useFuture` och
`useAsyncData`, som också hanterar fel och laddningsstatus åt dig.

### Flera hooks av samma sort

Du kan registrera flera `onMounted` och `onUnmounted`. De körs i den ordning de
registrerades. Därför kan varje composable registrera sina egna hooks utan att störa
de andra.

```dart
onMounted(() => debugPrint('första'));
onMounted(() => debugPrint('andra'));
```

### ⚠️ Registrera `onUnmounted` direkt i `setup()`

Den officiella dokumentationen visar ett mönster där `onUnmounted` anropas *inuti*
`onMounted`. **I version 0.1.1 fungerar det inte.** Hooks får bara registreras medan
`setup()` körs, och när `onMounted`-callbacken körs är `setup()` redan klar. Du får ett
assertion-fel i debug-läge, och i release-läge körs städningen aldrig.

```dart
// ❌ Fungerar inte i 0.1.1
onMounted(() {
  final sub = stream.listen(handle);
  onUnmounted(() => sub.cancel());   // assertion: "must be called within setup()"
});

// ✅ Registrera båda direkt i setup och dela en variabel
StreamSubscription<Event>? sub;

onMounted(() {
  sub = stream.listen(handle);
});

onUnmounted(() {
  sub?.cancel();
});
```

Samma regel gäller `watch`, `computed`, `provide` och `inject`. Anropa dem aldrig från
callbacks, bara från `setup()` eller från composables som anropas från `setup()`.

### `onBuild`

`onBuild` får en `BuildContext` varje gång builder-funktionen körs (och när
`InheritedWidget`-beroenden ändras). Den finns främst för att composables som
`useTheme()` ska kunna läsa från `context`. I din egen kod använder du nästan alltid
`useContextRef` i stället (kapitel 5).

## Props: `widget()`

### Problemet

`setup()` körs **en gång**. Läser du ett fält i widgeten direkt i `setup()` får du
värdet från första gången, och sedan aldrig mer:

```dart
class ResourceTitle extends CompositionWidget {
  const ResourceTitle({super.key, required this.name});
  final String name;

  @override
  Widget Function(BuildContext) setup() {
    // ❌ Läser name EN gång. Om föräldern skickar ett nytt namn syns det inte.
    final title = computed(() => 'Resurs: $name');
    return (context) => Text(title.value);
  }
}
```

I en `StatefulWidget` hade du löst det med `didUpdateWidget`.

### Lösningen

`widget()` returnerar en reaktiv `ComputedRef` som alltid innehåller den **senaste**
widget-instansen. När föräldern byggs om med nya värden uppdateras den, och allt som
läst `props.value.…` uppdateras med.

```dart
class ResourceTitle extends CompositionWidget {
  const ResourceTitle({super.key, required this.name});
  final String name;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();   // ComputedRef<ResourceTitle>
    final title = computed(() => 'Resurs: ${props.value.name}'); // ✅
    return (context) => Text(title.value);
  }
}
```

### Vue ↔ Dart: props och events

I Vue deklarerar du props med `defineProps` och events med `defineEmits`. I Flutter är
props vanliga `final`-fält i widget-klassen, och "events" är callback-fält.

```vue
<!-- BookingTile.vue -->
<script setup lang="ts">
import { computed } from 'vue'

const props = defineProps<{
  resourceName: string
  start: Date
  end: Date
}>()
const emit = defineEmits<{ (e: 'cancel'): void }>()

const hours = computed(() =>
  (props.end.getTime() - props.start.getTime()) / 3_600_000)
</script>

<template>
  <div>
    <strong>{{ resourceName }}</strong> ({{ hours }} h)
    <button @click="emit('cancel')">Avboka</button>
  </div>
</template>
```

```dart
class BookingTile extends CompositionWidget {
  const BookingTile({
    super.key,
    required this.resourceName,
    required this.start,
    required this.end,
    required this.onCancel,         // ≈ emit('cancel')
  });

  final String resourceName;
  final DateTime start;
  final DateTime end;
  final VoidCallback onCancel;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final hours = computed(
      () => props.value.end.difference(props.value.start).inHours,
    );

    return (context) {
      final BookingTile(:resourceName, :onCancel) = props.value;
      return ListTile(
        title: Text('$resourceName (${hours.value} h)'),
        trailing: TextButton(onPressed: onCancel, child: const Text('Avboka')),
      );
    };
  }
}

// Användning:
BookingTile(
  resourceName: 'Tvättstuga 1',
  start: DateTime(2025, 3, 1, 8),
  end: DateTime(2025, 3, 1, 10),
  onCancel: () => bookings.remove(id),
);
```

| Vue | Flutter Compositions |
|-----|----------------------|
| `defineProps<{ name: string }>()` | `final String name;` + konstruktorparameter |
| `props.name` i script | `props.value.name` (efter `final props = widget();`) |
| `name` i template | destrukturera i builder: `final MyWidget(:name) = props.value;` |
| `defineEmits` + `emit('x', v)` | callback-fält: `final ValueChanged<T> onX;` → `onX(v)` |
| Props är skrivskyddade | Fälten är `final`, och widgeten är immutabel |
| `v-model` på komponent | `value` + `onChanged`-par av props |

### Destrukturerings-mönstret

När du har många props kan du destrukturera dem överst i builder-funktionen med Darts
*object pattern*:

```dart
return (context) {
  final BookingTile(:resourceName, :start, :end) = props.value;
  return Text('$resourceName ${start.hour}–${end.hour}');
};
```

- `:resourceName` är kortform för `resourceName: final resourceName`.
- Eftersom det sker **i builder-funktionen** via `props.value` är det reaktivt. När
  föräldern skickar nya värden körs builder-funktionen om.
- Destrukturering av props är det **enda** som bör stå i builder-funktionen förutom
  själva widgetträdet (se [kapitel 8](08-best-practices-och-lints.md)).

### Reagera på prop-ändringar med `watch`

```dart
final props = widget();

watch(() => props.value.resourceId, (newId, oldId) {
  debugPrint('Laddar bokningar för $newId (tidigare $oldId)');
  // ladda om ...
});
```

Det ersätter `didUpdateWidget`:

```dart
// StatefulWidget-varianten
@override
void didUpdateWidget(ResourceBookings oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (widget.resourceId != oldWidget.resourceId) {
    _load();
  }
}
```

### Props som startvärde för state

Ibland ska en prop bara vara ett *startvärde*, t.ex. en initial anteckning i ett
redigeringsformulär. Då är det helt okej att läsa den en gång. Gör det tydligt med
namnet:

```dart
class NoteEditor extends CompositionWidget {
  const NoteEditor({super.key, required this.initialNote});
  final String initialNote;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final note = ref(props.value.initialNote); // medvetet: bara startvärdet
    // ...
    return (context) => Text(note.value);
  }
}
```

> 💡 **Tips:** Vill du att state ska nollställas när en viss prop ändras? Ge widgeten en
> ny `key` från föräldern, t.ex. `NoteEditor(key: ValueKey(bookingId), …)`. En ny key
> ger en ny widget-instans, och `setup()` körs då på nytt.

## Vanliga misstag

### 1. Läsa props direkt

```dart
// ❌
final id = resourceId;                       // eller this.resourceId
final label = computed(() => 'Resurs $id');

// ✅
final props = widget();
final label = computed(() => 'Resurs ${props.value.resourceId}');
```

Lint-regeln `flutter_compositions_ensure_reactive_props` varnar för det här.

### 2. Föränderliga fält i widgeten

```dart
class Bad extends CompositionWidget {
  Bad({super.key});
  int count = 0;          // ❌ fältet är inte reaktivt och widgeten ska vara immutabel
  // ...
}
```

All föränderlig data ska ligga i refs i `setup()`. Lint-regeln
`flutter_compositions_no_mutable_fields` varnar för det.

### 3. Async `setup()`

```dart
@override
Future<Widget Function(BuildContext)> setup() async { … } // ❌ kompilerar inte ens
```

Använd `onMounted` eller `useAsyncData`.

### 4. Använda `BuildContext` i `setup()`

I `setup()` finns ingen `context`. Den finns bara i builder-funktionen och i `onBuild`.
Behöver du t.ex. temat använder du `useTheme()`. Behöver du context för imperativa anrop
(`showDialog`, `Navigator`) gör du det i en event-callback i builder-funktionen, eller
med `useContext()` (kapitel 5).

### 5. Glömma städning av egna resurser

`Timer`, `StreamSubscription` och PocketBase-prenumerationer städas **inte** automatiskt.
Registrera alltid ett `onUnmounted` för dem. Controllers från `use*`-composables städas
däremot automatiskt.

## 🧪 Prova själv

1. Skapa `ClockText`, en `CompositionWidget` som visar aktuell tid och uppdateras varje
   sekund. Starta timern i `onMounted` och stoppa den i `onUnmounted`.
2. Bygg en förälder med en `Switch` som visar eller döljer `ClockText`. Lägg in
   `debugPrint` i båda hooks och verifiera att timern stoppas när klockan döljs.
3. Ge `ClockText` en prop `showSeconds` och gör formatet reaktivt via `widget()`.
   Verifiera att formatet ändras när föräldern växlar `showSeconds`, utan att timern
   startas om.

## Sammanfattning

- `onMounted` körs efter första framen, `onUnmounted` precis före borttagning och
  `onBuild` vid varje build.
- Registrera alla hooks **direkt i `setup()`** (eller i composables). Använd delade
  variabler för att koppla ihop start och städning.
- Läs props via `final props = widget();` och `props.value.x`. Det ersätter
  `didUpdateWidget`.
- Events skickas uppåt med callback-props (Vues `emit`).
- Destrukturera props i builder-funktionen med
  `final MinWidget(:a, :b) = props.value;`.

Nästa kapitel: [Composables →](05-composables.md)

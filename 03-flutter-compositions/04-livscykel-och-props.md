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
final posts = ref(<Post>[]);
final loading = ref(true);

onMounted(() async {
  posts.value = await service.fetchFeed();
  loading.value = false;
});
```

Det fungerar, men i [kapitel 8](08-async-data.md) lär du dig `useFuture` och
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
class UserHandle extends CompositionWidget {
  const UserHandle({super.key, required this.username});
  final String username;

  @override
  Widget Function(BuildContext) setup() {
    // ❌ Läser username EN gång. Om föräldern skickar ett nytt namn syns det inte.
    final handle = computed(() => '@$username');
    return (context) => Text(handle.value);
  }
}
```

I en `StatefulWidget` hade du löst det med `didUpdateWidget`.

### Lösningen

`widget()` returnerar en reaktiv `ComputedRef` som alltid innehåller den **senaste**
widget-instansen. När föräldern byggs om med nya värden uppdateras den, och allt som
läst `props.value.…` uppdateras med.

```dart
class UserHandle extends CompositionWidget {
  const UserHandle({super.key, required this.username});
  final String username;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();   // ComputedRef<UserHandle>
    final handle = computed(() => '@${props.value.username}'); // ✅
    return (context) => Text(handle.value);
  }
}
```

### Vue ↔ Dart: props och events

I Vue deklarerar du props med `defineProps` och events med `defineEmits`. I Flutter är
props vanliga `final`-fält i widget-klassen, och "events" är callback-fält.

```vue
<!-- CommentTile.vue -->
<script setup lang="ts">
import { computed } from 'vue'

const props = defineProps<{
  authorName: string
  body: string
  likes: number
}>()
const emit = defineEmits<{ (e: 'delete'): void }>()

const likesLabel = computed(() =>
  props.likes === 1 ? '1 gillning' : `${props.likes} gillningar`)
</script>

<template>
  <div>
    <strong>{{ authorName }}</strong>: {{ body }} ({{ likesLabel }})
    <button @click="emit('delete')">Radera</button>
  </div>
</template>
```

```dart
class CommentTile extends CompositionWidget {
  const CommentTile({
    super.key,
    required this.authorName,
    required this.body,
    required this.likes,
    required this.onDelete,         // ≈ emit('delete')
  });

  final String authorName;
  final String body;
  final int likes;
  final VoidCallback onDelete;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final likesLabel = computed(
      () => props.value.likes == 1 ? '1 gillning' : '${props.value.likes} gillningar',
    );

    return (context) {
      final CommentTile(:authorName, :body, :onDelete) = props.value;
      return ListTile(
        title: Text(body),
        subtitle: Text('$authorName · ${likesLabel.value}'),
        trailing: TextButton(onPressed: onDelete, child: const Text('Radera')),
      );
    };
  }
}

// Användning:
CommentTile(
  authorName: 'Bo Berg',
  body: 'Snyggt inlägg!',
  likes: 3,
  onDelete: () => deleteComment(id),
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
  final CommentTile(:authorName, :body, :likes) = props.value;
  return Text('$authorName: $body ($likes)');
};
```

- `:authorName` är kortform för `authorName: final authorName`.
- Eftersom det sker **i builder-funktionen** via `props.value` är det reaktivt. När
  föräldern skickar nya värden körs builder-funktionen om.
- Destrukturering av props är det **enda** som bör stå i builder-funktionen förutom
  själva widgetträdet (se [kapitel 9](09-best-practices-och-lints.md)).

### Reagera på prop-ändringar med `watch`

```dart
final props = widget();

watch(() => props.value.postId, (newId, oldId) {
  debugPrint('Laddar kommentarer för $newId (tidigare $oldId)');
  // ladda om kommentarerna ...
});
```

Det ersätter `didUpdateWidget`:

```dart
// StatefulWidget-varianten
@override
void didUpdateWidget(PostComments oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (widget.postId != oldWidget.postId) {
    _loadComments();
  }
}
```

### Props som startvärde för state

Ibland ska en prop bara vara ett *startvärde*, t.ex. den nuvarande profiltexten i ett
redigeringsformulär. Då är det helt okej att läsa den en gång. Gör det tydligt med
namnet:

```dart
class BioEditor extends CompositionWidget {
  const BioEditor({super.key, required this.initialBio});
  final String initialBio;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final bio = ref(props.value.initialBio); // medvetet: bara startvärdet
    // ...
    return (context) => Text(bio.value);
  }
}
```

> 💡 **Tips:** Vill du att state ska nollställas när en viss prop ändras? Ge widgeten en
> ny `key` från föräldern, t.ex. `BioEditor(key: ValueKey(userId), …)`. En ny key
> ger en ny widget-instans, och `setup()` körs då på nytt.

## Vanliga misstag

### 1. Läsa props direkt

```dart
// ❌
final id = postId;                           // eller this.postId
final label = computed(() => 'Inlägg $id');

// ✅
final props = widget();
final label = computed(() => 'Inlägg ${props.value.postId}');
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

### 5. Glömma att städa timers och prenumerationer

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

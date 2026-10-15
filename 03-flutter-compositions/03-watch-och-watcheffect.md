# 3. `watch` och `watchEffect`

`computed` räknar fram **värden**. Ibland vill du i stället **göra något** när ett
värde ändras: spara till disk, logga, navigera, anropa ett API eller starta en timer.
Sådant kallas **sidoeffekter**, och för dem finns `watch` och `watchEffect`.

## Tumregel: computed först

> Om du kan uttrycka det som "X är en funktion av Y", använd `computed`.
> Om du behöver "när Y ändras, gör Z", använd `watch`/`watchEffect`.

```dart
// ❌ Fel verktyg: watch används för att räkna fram ett värde
final fullName = ref('');
watch(
  () => (firstName.value, lastName.value),
  (names, _) => fullName.value = '${names.$1} ${names.$2}',
);

// ✅ Rätt verktyg
final fullName = computed(() => '${firstName.value} ${lastName.value}');
```

Varför? `computed` är cachad, lat och kan aldrig hamna ur synk. Varianten med `watch`
har ett gammalt värde fram till att watchern har körts, och mer kod att underhålla.

## `watch()`: explicit källa, nytt och gammalt värde

```dart
final selectedPostId = ref<String?>(null);

watch(
  () => selectedPostId.value,            // källa: VAD ska bevakas
  (newId, oldId) {                       // callback: VAD ska göras
    debugPrint('Inlägg bytt från $oldId till $newId');
  },
);
```

Signaturen är:

```dart
void Function() watch<T>(
  T Function() source,
  void Function(T newValue, T? oldValue) callback, {
  bool immediate = false,
});
```

- **`source`** är en funktion som returnerar det du vill bevaka. Bara de refs som läses
  *i source* blir beroenden. Refs som läses i callbacken spåras inte.
- **`callback`** får det nya värdet och det föregående (`oldValue` är nullable).
- **`immediate: true`** kör callbacken direkt en gång vid start, med `oldValue == null`.
- **Returvärdet** är en funktion som stoppar watchern.

### Bevaka flera källor

Returnera en *record* från source:

```dart
watch(
  () => (filter.value, search.value),
  (nytt, gammalt) {
    debugPrint('Flödet ändrat: ${gammalt?.$1} "${gammalt?.$2}" → ${nytt.$1} "${nytt.$2}"');
  },
);
```

Records jämförs med `==` på sina fält, så callbacken körs när något av fälten ändras.

### Vue ↔ Dart

```vue
<script setup lang="ts">
import { ref, watch } from 'vue'

const postId = ref<string | null>(null)

watch(postId, (newId, oldId) => {
  console.log(`Bytt från ${oldId} till ${newId}`)
}, { immediate: true })

watch([filter, search], ([f, q], [oldF, oldQ]) => { /* ... */ })
</script>
```

```dart
final postId = ref<String?>(null);

watch(() => postId.value, (newId, oldId) {
  debugPrint('Bytt från $oldId till $newId');
}, immediate: true);

watch(() => (filter.value, search.value), (nytt, gammalt) { /* ... */ });
```

Skillnader att lägga märke till:

- I Vue kan källan vara själva refen (`watch(postId, …)`). I Dart är källan
  **alltid en funktion** (`() => postId.value`).
- Vue har `{ deep: true }`. Det finns inte här, eftersom reaktiviteten är grund (se
  kapitel 2). Ersätter du objekt i stället för att mutera dem behövs det inte heller.

## `watchEffect()`: automatisk spårning

```dart
watchEffect(() {
  debugPrint('Valt inlägg: ${selectedPostId.value}, filter: ${filter.value}');
});
```

`watchEffect` körs **direkt en gång** och spårar alla refs som läses i funktionen. Den
körs sedan om när någon av dem ändras. Du får inget gammalt värde.

```vue
<!-- Vue -->
<script setup>
watchEffect(() => {
  console.log(`Valt inlägg: ${selectedPostId.value}`)
})
</script>
```

```dart
// Dart
watchEffect(() {
  debugPrint('Valt inlägg: ${selectedPostId.value}');
});
```

### Exempel: spara utkast lokalt

```dart
final draft = ref('');

watchEffect(() {
  // Körs vid start och varje gång draft ändras
  draftStorage.save('post_draft', draft.value);
});
```

## När använder jag vad?

| Situation | Verktyg |
|-----------|---------|
| Räkna fram ett nytt värde från state | `computed` |
| Sidoeffekt som behöver gamla värdet | `watch` |
| Sidoeffekt som bara ska köras vid *ändring*, inte vid start | `watch` |
| Exakt kontroll över vilka beroenden som gäller | `watch` |
| Enkel sidoeffekt som ska köras direkt och vid varje ändring | `watchEffect` |
| Många beroenden som du inte vill lista själv | `watchEffect` |

## Exempel från Kvittra

### Rensa serverfel när användaren ändrar formuläret

```dart
final serverError = ref<String?>(null);

watch(
  () => (title.value, body.value),
  (_, _) => serverError.value = null,
);
```

Här är det rimligt att en watcher skriver till en annan ref. Felet kommer från servern,
inte från formulärets fält, så det går inte att uttrycka som `computed`.

### Visa en snackbar när ett inlägg publicerats

```dart
final lastPublished = ref<DateTime?>(null);
final context = useContext(); // rå BuildContext för imperativa anrop, kapitel 5

watch(() => lastPublished.value, (published, _) {
  if (published == null) return;
  ScaffoldMessenger.of(context.value!).showSnackBar(
    const SnackBar(content: Text('Inlägget är publicerat')),
  );
});
```

### Ladda om när ett filter ändras

```dart
final onlyFollowing = ref(false);

watch(() => onlyFollowing.value, (only, _) {
  reloadFeed(onlyFollowing: only);
});
```

(I kapitel 8 ser du att `useAsyncData(…, watch: …)` gör just det här åt dig.)

## Städning

### Automatisk städning

Alla `watch` och `watchEffect` som skapas i `setup()` (eller i en composable som anropas
från `setup()`) **stoppas automatiskt** när widgeten avmonteras. Du behöver inte städa
dem själv.

### Stoppa en watcher tidigt

Både `watch` och `watchEffect` returnerar en stopp-funktion:

```dart
final stop = watch(() => count.value, (n, _) {
  if (n >= 10) {
    debugPrint('Nådde 10!');
  }
});

// senare, t.ex. i en knapp:
void stopWatching() => stop();
```

### Städa en sidoeffekt mellan körningar

Vue har en `onCleanup`-parameter i `watchEffect` och `watch`. Den finns inte i
Flutter Compositions 0.1. Behöver du städa den förra körningens sidoeffekt (t.ex. avbryta
en timer) sparar du den i en variabel:

```dart
Timer? debounce;

watch(() => searchText.value, (text, _) {
  debounce?.cancel();                          // städa förra körningen
  debounce = Timer(const Duration(milliseconds: 300), () {
    searchUsers(text);
  });
});

onUnmounted(() => debounce?.cancel());         // städa när widgeten försvinner
```

Det här mönstret blir composablen `useDebounced` i [kapitel 5](05-composables.md).

## Timing: när körs watchers?

I version 0.1 körs `watch` och `watchEffect` **synkront** direkt vid varje skrivning.
Tre skrivningar i rad ger tre körningar:

```dart
watch(() => count.value, (n, o) => debugPrint('$o → $n'));

count.value++;  // skriver ut 0 → 1
count.value++;  // skriver ut 1 → 2
```

Skärmen ritas däremot bara om en gång per frame. Flutter samlar ihop omritningarna, så
flera skrivningar i samma händelsehanterare kostar inte flera frames.

> ⚠️ **Varning:** Den officiella dokumentationen beskriver att flera skrivningar i samma
> microtask "slås ihop" till en körning. Bygg inte din logik på något av beteendena. Om
> två värden alltid ändras tillsammans är det oftast bättre att lägga dem i **en** ref
> (t.ex. en record eller ett objekt med `copyWith`).

## Vanliga misstag

### 1. Oändlig loop

```dart
// ❌ Läser OCH skriver count i samma effect
watchEffect(() {
  count.value = count.value + 1;
});
```

Effecten läser `count` och blir beroende av den. Sedan skriver den till `count`, vilket
triggar effecten igen, och så vidare. Använd en händelsehanterare eller `watch` med en
annan källa.

### 2. Async i `watchEffect`

```dart
// ⚠️ Bara refs som läses FÖRE första await spåras
watchEffect(() async {
  final id = postId.value;           // spåras
  final data = await api.fetchComments(id);
  comments.value = data;
  debugPrint('${filter.value}');     // spåras INTE, läses efter await
});
```

Spårningen sker bara medan funktionen körs synkront. Läs alla beroenden först, eller
använd `watch` (där källan alltid är synkron) eller `useAsyncData` (kapitel 8).

### 3. `watch` utanför `setup()`

`watch` och `watchEffect` måste anropas under `setup()` (direkt eller via en
composable), annars kan de inte städas automatiskt. I debug-läge får du ett
assertion-fel. Anropa dem alltså inte i en knapp-callback eller i `onMounted`.

### 4. Watch för att synka props till state

```dart
// ❌ Kopierar en prop till en ref med watch
final username = ref('');
watch(() => props.value.username, (u, _) => username.value = u, immediate: true);

// ✅ computed direkt från props
final username = computed(() => props.value.username);
```

## 🧪 Prova själv

1. Skapa en `CompositionWidget` med `final likes = ref(0)` och två knappar (gilla, sluta
   gilla).
2. Lägg till en `watch` som skriver ut `"ökade"` eller `"minskade"` beroende på om
   `newValue > oldValue`.
3. Lägg till en `watchEffect` som skriver ut `likes` varje gång. Lägg märke till att den
   också körs direkt vid start, men inte `watch`.
4. Lägg till `immediate: true` på din `watch`. Vad blir `oldValue` första gången?

## Sammanfattning

- `computed` för värden. `watch`/`watchEffect` för sidoeffekter.
- `watch(source, (nytt, gammalt) { … })` har explicita beroenden, kör inte vid start
  (om du inte anger `immediate: true`) och ger tillgång till gamla värdet.
- `watchEffect(() { … })` spårar automatiskt, körs direkt och ger inget gammalt värde.
- Watchers som skapas i `setup()` städas automatiskt. Egna timers och
  prenumerationer städar du med `onUnmounted`.
- Undvik loopar (läsa och skriva samma ref) och async-spårning efter `await`.

Nästa kapitel: [Livscykel och props →](04-livscykel-och-props.md)

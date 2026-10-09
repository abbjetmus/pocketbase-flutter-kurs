# 2. Reaktivitet: `ref` och `computed`

Reaktivitet bygger på två verktyg:

- **`ref`**: state som du kan läsa och skriva.
- **`computed`**: värden som *härleds* från annat state och räknas om automatiskt.

(Det tredje, `watch`/`watchEffect` för sidoeffekter, kommer i nästa kapitel.)

## `ref`: reaktivt state

```dart
final count = ref(0);          // Ref<int>
final name = ref('Anna');      // Ref<String>
final selected = ref<String?>(null); // ange typen när startvärdet är null

print(count.value);  // läs: 0
count.value = 5;     // skriv: triggar alla som läst count
count.value++;       // fungerar också
```

En `Ref<T>` är en låda med ett värde. Allt går via `.value`:

- **Läsa `.value`** inuti en builder, `computed` eller `watchEffect` registrerar ett
  *beroende*.
- **Skriva `.value`** meddelar alla beroenden att värdet har ändrats.

### Vue ↔ Dart

```vue
<script setup lang="ts">
import { ref } from 'vue'

const count = ref(0)
const selectedResource = ref<string | null>(null)

function choose(id: string) {
  selectedResource.value = id
}
</script>

<template>
  <p>{{ count }}</p>
  <p v-if="selectedResource">Vald: {{ selectedResource }}</p>
</template>
```

```dart
@override
Widget Function(BuildContext) setup() {
  final count = ref(0);
  final selectedResource = ref<String?>(null);

  void choose(String id) => selectedResource.value = id;

  return (context) => Column(
        children: [
          Text('${count.value}'),
          if (selectedResource.value != null)
            Text('Vald: ${selectedResource.value}'),
        ],
      );
}
```

> ⚠️ **Varning:** Jämför aldrig själva ref-objektet. `if (count == 5)` jämför en
> `Ref<int>` med en `int` och blir aldrig sant. Skriv `if (count.value == 5)`.

### Skriver du samma värde händer ingenting

En ref meddelar bara när det nya värdet är **olikt** det gamla (jämfört med `==`).
`count.value = count.value` gör alltså ingenting. Det är bra för prestandan, men det
spelar roll för listor, som du ser längre ner.

### `.raw`: läsa utan att registrera beroende

Ibland vill du läsa ett värde *utan* att din builder eller computed ska bero på det.
Då använder du `.raw`:

```dart
final scrollController = useScrollController();

return (context) => ListView(
      controller: scrollController.raw, // läs utan tracking, se kapitel 5
      children: const [/* ... */],
    );
```

`.raw` motsvarar ungefär Vues `toRaw()`/`untracked`. Du använder det framför allt när du
skickar controllers till widgets (kapitel 5) och när du läser ett värde i en callback
utanför en reaktiv kontext.

## `computed`: härlett state

```dart
final firstName = ref('Anna');
final lastName = ref('Svensson');
final fullName = computed(() => '${firstName.value} ${lastName.value}');

print(fullName.value);   // Anna Svensson
firstName.value = 'Bo';
print(fullName.value);   // Bo Svensson
```

Egenskaper hos `computed`:

- **Automatisk beroendespårning.** Alla `.value` som läses i funktionen blir beroenden.
- **Cachad.** Funktionen körs bara om när ett beroende har ändrats. Läser du
  `fullName.value` tio gånger i rad räknas den ut en gång.
- **Lat.** Den räknas inte ut förrän någon läser den.
- **Skrivskyddad.** `computed` returnerar en `ReadonlyRef<T>`. Försöker du skriva
  `fullName.value = …` blir det kompileringsfel.

### Exempel: lediga tider för en resurs

```dart
final bookedHours = ref(<int>[8, 9, 13]);    // bokade starttimmar idag
final openingHours = List.generate(14, (i) => i + 7); // 07–20

final freeHours = computed(
  () => openingHours.where((h) => !bookedHours.value.contains(h)).toList(),
);
final freeCount = computed(() => freeHours.value.length);
final isFullyBooked = computed(() => freeCount.value == 0);
```

Lägg märke till att en `computed` kan bero på en annan `computed`. Det bildar en kedja
där bara det som påverkas räknas om.

> 💡 **Tips:** En `computed` ska vara en **ren funktion**: samma indata ger samma utdata
> och inga sidoeffekter. Inga `print`, inga API-anrop, inga skrivningar till andra refs.
> Behöver du göra något när ett värde ändras använder du `watch` (kapitel 3).

### Skrivbar computed

Ibland vill du ha ett härlett värde som också går att skriva till, t.ex. för
tvåvägsbindning. Det finns `writableComputed`:

```dart
final minutes = ref(90);

final hours = writableComputed<double>(
  get: () => minutes.value / 60,
  set: (h) => minutes.value = (h * 60).round(),
);

hours.value = 2; // minutes.value blir 120
```

Vue har samma sak: `computed({ get, set })`. Du kommer att använda den sällan. Den
används bland annat internt av `useTextEditingController` (kapitel 5).

## Grund (shallow) reaktivitet

Här skiljer sig Flutter Compositions mest från Vue.

I Vue är `ref([])` och `reactive({})` **djupt** reaktiva. Vue lägger en Proxy runt
objektet, så `todos.value.push(x)` triggar en uppdatering.

I Flutter Compositions är reaktiviteten **grund**. Bara själva tilldelningen till
`.value` triggar. Ändrar du *inuti* objektet märker systemet ingenting.

```dart
final items = ref(<String>['Tvättstuga 1']);

// ❌ Muterar listan, men ingen tilldelning till .value, alltså ingen uppdatering
items.value.add('Festlokalen');

// ❌ Samma lista-instans igen; == är sant, alltså ingen uppdatering
items.value.add('Festlokalen');
items.value = items.value;

// ✅ Ny lista, tilldelning, uppdatering
items.value = [...items.value, 'Festlokalen'];
```

### Recept för listor, maps och sets

Tänk "ersätt, mutera inte":

```dart
final bookings = ref(<Booking>[]);

// Lägg till
bookings.value = [...bookings.value, nyBokning];

// Ta bort
bookings.value = bookings.value.where((b) => b.id != id).toList();

// Ersätt ett element
bookings.value = [
  for (final b in bookings.value) b.id == uppdaterad.id ? uppdaterad : b,
];

// Sortera (sort() muterar, så kopiera först)
bookings.value = [...bookings.value]..sort((a, b) => a.start.compareTo(b.start));

// Map
final counts = ref(<String, int>{});
counts.value = {...counts.value, 'tvatt': 3};

// Set
final selectedIds = ref(<String>{});
selectedIds.value = {...selectedIds.value, 'abc'};
selectedIds.value = {...selectedIds.value}..remove('abc');
```

### Vue ↔ Dart: lägga till en todo

```vue
<script setup lang="ts">
const todos = ref<string[]>([])
function add(t: string) {
  todos.value.push(t)        // fungerar i Vue (djup reaktivitet)
}
</script>
```

```dart
final todos = ref(<String>[]);
void add(String t) {
  todos.value = [...todos.value, t]; // måste ersättas i Dart
}
```

> 💡 **Tips:** Den här regeln känns ovan i början men ger en stor fördel: det syns
> tydligt i koden var state ändras, och gamla värden förblir oförändrade (bra för
> `watch`, där du får både nytt och gammalt värde).

## Immutabla modeller med `copyWith`

Samma regel gäller för egna klasser. Om en `Ref<Booking>` håller ett objekt och du
ändrar ett fält inuti det triggas ingenting. Gör därför modellerna **immutabla**
(`final`-fält) och skapa nya instanser med en `copyWith`-metod:

```dart
class Booking {
  const Booking({
    required this.id,
    required this.resourceId,
    required this.start,
    required this.end,
    this.note = '',
  });

  final String id;
  final String resourceId;
  final DateTime start;
  final DateTime end;
  final String note;

  Booking copyWith({DateTime? start, DateTime? end, String? note}) => Booking(
        id: id,
        resourceId: resourceId,
        start: start ?? this.start,
        end: end ?? this.end,
        note: note ?? this.note,
      );
}
```

```dart
final draft = ref(Booking(
  id: 'ny',
  resourceId: 'tvatt1',
  start: DateTime(2025, 3, 1, 8),
  end: DateTime(2025, 3, 1, 10),
));

// ❌ Kompilerar inte ens, fälten är final. Bra!
// draft.value.note = 'Tar med egen tvättmedel';

// ✅ Ny instans
draft.value = draft.value.copyWith(note: 'Tar med eget tvättmedel');

final durationHours = computed(
  () => draft.value.end.difference(draft.value.start).inHours,
);
```

> 💡 **Tips:** I större projekt genererar man ofta `copyWith`, `==` och `hashCode` med
> paket som `freezed`. Det är inte nödvändigt i kursen, men bra att känna till.

### Alternativ: en ref per fält

För formulär är det ofta enklare att ha en ref per fält i stället för ett stort objekt:

```dart
final date = ref<DateTime?>(null);
final hours = ref(1);
final note = ref('');

final isValid = computed(() => date.value != null && hours.value <= 4);
```

Då kan varje fält ändras för sig, och en `computed` ser bara de fält den läser. Vi
använder det mönstret i bokningsformuläret i [kapitel 5](05-composables.md).

## Var får jag skapa refs?

- **I `setup()`.** Det vanligaste. Refs lever lika länge som widgeten. De bevaras också
  vid *hot reload* så länge du inte ändrar ordningen på dem.
- **I vanliga klasser (tjänster).** Det fungerar, eftersom en ref bara är ett objekt. Vi
  använder det för `AuthService` i [kapitel 6](06-provide-inject.md):

  ```dart
  class AuthService {
    final user = ref<RecordModel?>(null);
    late final isLoggedIn = computed(() => user.value != null);
  }
  ```

- **I composables** (funktioner som anropas från `setup()`), se kapitel 5.

> ⚠️ **Varning:** Skapa **aldrig** refs inne i builder-funktionen. Den körs om vid varje
> uppdatering, så du skulle få en ny ref (med startvärdet) varje gång och tappa state.

## Vanliga fallgropar

| Symptom | Orsak | Lösning |
|---------|-------|---------|
| UI uppdateras inte efter `list.add()` | Mutation utan ny tilldelning | `items.value = [...items.value, x]` |
| Texten visar `Instance of 'Ref<int>'` | Glömt `.value` | `'${count.value}'` |
| `if (count == 0)` är aldrig sant | Jämför Ref-objekt | `count.value == 0` |
| State nollställs hela tiden | `ref()` anropas i builder | Flytta till `setup()` |
| `computed` uppdateras inte | Värdet lästes med `.raw` eller via en vanlig variabel | Läs med `.value` inne i funktionen |
| Prop-värde uppdateras inte | Prop lästes direkt i `setup()` | `widget()`, se kapitel 4 |

Det näst sista fallet ser ut så här:

```dart
final count = ref(0);
final current = count.value;                 // ❌ läses EN gång i setup
final label = computed(() => 'Antal $current');  // beror inte på count!

final label2 = computed(() => 'Antal ${count.value}'); // ✅
```

## 🧪 Prova själv

Bygg en `CompositionWidget` "Tvättlista":

1. `final items = ref(<String>[]);` och ett textfält (använd `onSubmitted` tills vidare;
   i kapitel 5 lär du dig `useTextEditingController`).
2. En `computed` `count` och en `computed` `sorted` som returnerar en sorterad kopia.
3. En knapp "Ta bort första". Prova först att skriva `items.value.removeAt(0)` och se
   att ingenting händer. Skriv sedan om det korrekt.

## Sammanfattning

- `ref(x)` skapar state. Läs och skriv via `.value`. `.raw` läser utan beroende.
- `computed(() => …)` skapar cachade, härledda, skrivskyddade värden. De ska vara rena
  funktioner.
- Reaktiviteten är **grund**. Ersätt listor, maps och objekt i stället för att mutera
  dem.
- Använd immutabla modeller med `copyWith`, eller en ref per fält.
- Skapa refs i `setup()`, i composables eller i tjänsteklasser, aldrig i
  builder-funktionen.

Nästa kapitel: [watch och watchEffect →](03-watch-och-watcheffect.md)

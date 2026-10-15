# 2. Reaktivitet: `ref` och `computed`

Reaktivitet bygger på två verktyg:

- **`ref`**: state som du kan läsa och skriva.
- **`computed`**: värden som *härleds* från annat state och räknas om automatiskt.

(Det tredje, `watch`/`watchEffect` för sidoeffekter, kommer i nästa kapitel.)

## `ref`: reaktivt state

```dart
final count = ref(0);          // Ref<int>
final name = ref('Anna');      // Ref<String>
final selectedPostId = ref<String?>(null); // ange typen när startvärdet är null

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
const selectedPostId = ref<string | null>(null)

function choose(id: string) {
  selectedPostId.value = id
}
</script>

<template>
  <p>{{ count }}</p>
  <p v-if="selectedPostId">Valt inlägg: {{ selectedPostId }}</p>
</template>
```

```dart
@override
Widget Function(BuildContext) setup() {
  final count = ref(0);
  final selectedPostId = ref<String?>(null);

  void choose(String id) => selectedPostId.value = id;

  return (context) => Column(
        children: [
          Text('${count.value}'),
          if (selectedPostId.value != null)
            Text('Valt inlägg: ${selectedPostId.value}'),
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

### Exempel: filtrera och sök i flödet

Flödet i Kvittra kan visa alla inlägg, bara inlägg från dem du följer eller bara dina
egna. Dessutom finns en sökruta. Allt det är *härlett* från tre refs:

```dart
enum FeedFilter { all, following, mine }

class Post {
  const Post({required this.id, required this.author, required this.title});
  final String id;
  final String author; // användarnamn
  final String title;
}

const me = 'anna';

final posts = ref(<Post>[
  const Post(id: '1', author: 'anna', title: 'Hej Kvittra!'),
  const Post(id: '2', author: 'bo', title: 'Flutter är kul'),
  const Post(id: '3', author: 'cecilia', title: 'Tips om Dart'),
]);
final following = ref(<String>{'bo'});
final filter = ref(FeedFilter.all);
final search = ref('');

final filtered = computed(() => switch (filter.value) {
      FeedFilter.all => posts.value,
      FeedFilter.following =>
        posts.value.where((p) => following.value.contains(p.author)).toList(),
      FeedFilter.mine => posts.value.where((p) => p.author == me).toList(),
    });

final visible = computed(() {
  final q = search.value.trim().toLowerCase();
  if (q.isEmpty) return filtered.value;
  return filtered.value.where((p) => p.title.toLowerCase().contains(q)).toList();
});

final summary = computed(() => '${visible.value.length} av ${posts.value.length} inlägg');
```

Lägg märke till att en `computed` kan bero på en annan `computed`. Det bildar en kedja
där bara det som påverkas räknas om. Skriver användaren i sökrutan räknas `visible` och
`summary` om, men `filtered` återanvänds från cachen eftersom varken `posts`,
`following` eller `filter` har ändrats.

> 💡 **Tips:** En `computed` ska vara en **ren funktion**: samma indata ger samma utdata
> och inga sidoeffekter. Inga `print`, inga API-anrop, inga skrivningar till andra refs.
> Behöver du göra något när ett värde ändras använder du `watch` (kapitel 3).

### Skrivbar computed

Ibland vill du ha ett härlett värde som också går att skriva till, t.ex. för
tvåvägsbindning. Det finns `writableComputed`:

```dart
final username = ref('anna');

// "@anna" i UI:t, men lagrat utan @
final handle = writableComputed<String>(
  get: () => '@${username.value}',
  set: (h) => username.value = h.startsWith('@') ? h.substring(1) : h,
);

handle.value = '@bo'; // username.value blir 'bo'
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
final tags = ref(<String>['#flutter']);

// ❌ Muterar listan, men ingen tilldelning till .value, alltså ingen uppdatering
tags.value.add('#dart');

// ❌ Samma lista-instans igen; == är sant, alltså ingen uppdatering
tags.value.add('#dart');
tags.value = tags.value;

// ✅ Ny lista, tilldelning, uppdatering
tags.value = [...tags.value, '#dart'];
```

### Recept för listor, maps och sets

Tänk "ersätt, mutera inte":

```dart
final posts = ref(<Post>[]);

// Lägg till (nyast först)
posts.value = [nyttInlagg, ...posts.value];

// Ta bort
posts.value = posts.value.where((p) => p.id != id).toList();

// Ersätt ett element
posts.value = [
  for (final p in posts.value) p.id == uppdaterat.id ? uppdaterat : p,
];

// Sortera (sort() muterar, så kopiera först)
posts.value = [...posts.value]..sort((a, b) => a.title.compareTo(b.title));

// Map: antal gillningar per inlägg
final likeCounts = ref(<String, int>{});
likeCounts.value = {...likeCounts.value, 'post1': 3};

// Set: vilka användare jag följer
final following = ref(<String>{});
following.value = {...following.value, 'bo'};
following.value = {...following.value}..remove('bo');
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

Samma regel gäller för egna klasser. Om en `Ref<Post>` håller ett objekt och du
ändrar ett fält inuti det triggas ingenting. Gör därför modellerna **immutabla**
(`final`-fält) och skapa nya instanser med en `copyWith`-metod:

```dart
class Post {
  const Post({
    required this.id,
    required this.author,
    required this.title,
    required this.body,
    this.likeCount = 0,
    this.likedByMe = false,
  });

  final String id;
  final String author;
  final String title;
  final String body;
  final int likeCount;
  final bool likedByMe;

  Post copyWith({String? title, String? body, int? likeCount, bool? likedByMe}) =>
      Post(
        id: id,
        author: author,
        title: title ?? this.title,
        body: body ?? this.body,
        likeCount: likeCount ?? this.likeCount,
        likedByMe: likedByMe ?? this.likedByMe,
      );
}
```

```dart
final post = ref(const Post(
  id: 'p1',
  author: 'anna',
  title: 'Hej Kvittra!',
  body: 'Mitt första inlägg.',
  likeCount: 41,
));

// ❌ Kompilerar inte ens, fälten är final. Bra!
// post.value.likedByMe = true;

// ✅ Ny instans
void toggleLike() {
  final p = post.value;
  post.value = p.copyWith(
    likedByMe: !p.likedByMe,
    likeCount: p.likeCount + (p.likedByMe ? -1 : 1),
  );
}

final likeLabel = computed(() => '${post.value.likeCount} gillningar');
```

> 💡 **Tips:** I större projekt genererar man ofta `copyWith`, `==` och `hashCode` med
> paket som `freezed`. Det är inte nödvändigt i kursen, men bra att känna till.

### Alternativ: en ref per fält

För formulär är det ofta enklare att ha en ref per fält i stället för ett stort objekt:

```dart
final title = ref('');
final body = ref('');
final groupId = ref<String?>(null); // valfri grupp

final isValid = computed(
  () => title.value.trim().length >= 3 && body.value.trim().isNotEmpty,
);
```

Då kan varje fält ändras för sig, och en `computed` ser bara de fält den läser. Vi
använder det mönstret i kommentarsfältet i [kapitel 5](05-composables.md) och i
formuläret för nya inlägg i [kapitel 10](10-arkitektur-for-en-riktig-app.md).

## Var får jag skapa refs?

- **I `setup()`.** Det vanligaste. Refs lever lika länge som widgeten. De bevaras också
  vid *hot reload* så länge du inte ändrar ordningen på dem.
- **I vanliga klasser (tjänster).** Det fungerar, eftersom en ref bara är ett objekt. Vi
  använder det för `AuthService` i [kapitel 7](07-provide-inject.md):

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

Bygg en `CompositionWidget` "Tagglista" för hashtaggar till ett inlägg:

1. `final tags = ref(<String>[]);` och ett textfält (använd `onSubmitted` tills vidare;
   i kapitel 5 lär du dig `useTextEditingController`). Lägg till `#` först om
   användaren glömt det.
2. En `computed` `count` och en `computed` `sorted` som returnerar en sorterad kopia.
3. En knapp "Ta bort första". Prova först att skriva `tags.value.removeAt(0)` och se
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

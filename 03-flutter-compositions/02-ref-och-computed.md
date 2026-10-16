# 2. ref och computed

Allt state i Flutter Compositions bygger på två verktyg:

| Verktyg | Används till | Exempel |
|---------|--------------|---------|
| `ref` | State som du kan läsa och ändra | Vilket filter som är valt |
| `computed` | Värden som räknas fram av annat state | Inläggen som ska visas |

## ref

```dart
final count = ref(0);                     // en int
final name = ref('Anna');                 // en String
final selectedPostId = ref<String?>(null); // skriv typen när startvärdet är null

print(count.value); // läs: 0
count.value = 5;    // ändra
count.value++;      // fungerar också
```

En `ref` är en låda med ett värde. Allt går via `.value`:

- När builder-funktionen **läser** `.value` kommer systemet ihåg det.
- När du **ändrar** `.value` körs allt som läst värdet igen.

💡 Om du sätter **samma** värde igen händer ingenting. `count.value = 5` två
gånger i rad uppdaterar bara skärmen en gång.

⚠️ Jämför inte själva lådan. `if (count == 5)` är aldrig sant. Skriv
`if (count.value == 5)`.

## computed

```dart
final firstName = ref('Anna');
final lastName = ref('Andersson');
final fullName = computed(() => '${firstName.value} ${lastName.value}');

print(fullName.value); // Anna Andersson
firstName.value = 'Bertil';
print(fullName.value); // Bertil Andersson
```

| Egenskap | Betyder |
|----------|---------|
| Räknas om av sig själv | När `firstName` eller `lastName` ändras |
| Sparar resultatet | Läser du `fullName.value` tio gånger räknas det bara ut en gång |
| Går inte att ändra | `fullName.value = 'x'` ger ett fel |

💡 **Tumregel:** Kan du säga "X räknas fram av Y"? Då ska X vara en `computed`,
inte en egen `ref`.

## Räkna i computed, inte i builder-funktionen

Builder-funktionen ska bara **rita**. Lägg filtrering, sortering och text som
räknas fram i en `computed` i `setup()`:

```dart
// ❌ Räknas om varje gång builder-funktionen körs
return (context) => Text('${posts.value.where((p) => p.likes > 0).length} gillade');

// ✅ Räknas bara om när posts ändras
final likedCount = computed(() => posts.value.where((p) => p.likes > 0).length);
return (context) => Text('${likedCount.value} gillade');
```

Enkla saker som `liked.value ? 'Sluta följa' : 'Följ'` går bra i
builder-funktionen. Det är längre uträkningar som ska flyttas.

## Listor: ersätt, ändra inte

Här skiljer sig Flutter Compositions från Vue. En `ref` märker bara när du
sätter ett **nytt** värde med `=`. Ändrar du *inuti* listan märks ingenting.

```dart
final tags = ref(<String>['#kvittra']);

tags.value.add('#flutter');             // ❌ listan ändras, men skärmen gör det inte
tags.value = [...tags.value, '#flutter']; // ✅ ny lista, skärmen uppdateras
```

| Vue | Flutter Compositions |
|-----|----------------------|
| `tags.value.push('#flutter')` fungerar | `tags.value = [...tags.value, '#flutter']` |

Så här gör du de vanligaste sakerna:

| Du vill … | Skriv |
|-----------|-------|
| Lägga till först | `posts.value = [nytt, ...posts.value];` |
| Lägga till sist | `posts.value = [...posts.value, nytt];` |
| Ta bort | `posts.value = posts.value.where((p) => p.id != id).toList();` |
| Sortera | `posts.value = [...posts.value]..sort((a, b) => a.title.compareTo(b.title));` |
| Lägga till i ett `Set` | `following.value = {...following.value, 'bertil'};` |

`...` kallas *spread* och kopierar alla element till en ny lista.

## Exempel: flöde med filter och sök

Vi bygger ett flöde med Kvittras inlägg från modul 01. Man kan välja **Alla**,
**Följer** (de Anna följer) eller **Mina**, och söka på rubrik. Datan ligger i
appen tills vidare. I kapitel 7 hämtar vi den från PocketBase.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

class Post {
  const Post({required this.author, required this.title, this.likes = 0});
  final String author; // användarnamn
  final String title;
  final int likes;
}

enum FeedFilter { all, following, mine }

class FeedDemo extends CompositionWidget {
  const FeedDemo({super.key});

  @override
  Widget Function(BuildContext) setup() {
    const me = 'anna';

    // State
    final posts = ref(const [
      Post(author: 'anna', title: 'Höstpromenad', likes: 2),
      Post(author: 'bertil', title: 'Mitt första surdegsbröd', likes: 3),
      Post(author: 'anna', title: 'Morgondimma'),
      Post(author: 'cissi', title: 'Tips på en bra bok?'),
      Post(author: 'david', title: 'Matchdag', likes: 1),
      Post(author: 'bertil', title: 'Andra försöket', likes: 2),
    ]);
    final following = ref(<String>{'bertil', 'cissi'}); // de Anna följer
    final filter = ref(FeedFilter.all);
    final search = ref('');

    // Härledda värden
    final filtered = computed(() => switch (filter.value) {
          FeedFilter.all => posts.value,
          FeedFilter.following => posts.value
              .where((p) => following.value.contains(p.author))
              .toList(),
          FeedFilter.mine => posts.value.where((p) => p.author == me).toList(),
        });

    final visible = computed(() {
      final q = search.value.trim().toLowerCase();
      if (q.isEmpty) return filtered.value;
      return filtered.value
          .where((p) => p.title.toLowerCase().contains(q))
          .toList();
    });

    final summary = computed(
      () => 'Visar ${visible.value.length} av ${posts.value.length} inlägg',
    );

    void addPost() {
      posts.value = [const Post(author: 'anna', title: 'Nytt inlägg'), ...posts.value];
    }

    return (context) => Scaffold(
          appBar: AppBar(title: const Text('Flöde')),
          floatingActionButton: FloatingActionButton(
            onPressed: addPost,
            child: const Icon(Icons.add),
          ),
          body: Column(
            children: [
              SegmentedButton<FeedFilter>(
                segments: const [
                  ButtonSegment(value: FeedFilter.all, label: Text('Alla')),
                  ButtonSegment(value: FeedFilter.following, label: Text('Följer')),
                  ButtonSegment(value: FeedFilter.mine, label: Text('Mina')),
                ],
                selected: {filter.value},
                onSelectionChanged: (s) => filter.value = s.first,
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Sök'),
                onChanged: (text) => search.value = text,
              ),
              Text(summary.value),
              Expanded(
                child: ListView(
                  children: [
                    for (final p in visible.value)            // som v-for
                      ListTile(title: Text(p.title), subtitle: Text(p.author)),
                    if (visible.value.isEmpty)                // som v-if
                      const ListTile(title: Text('Inga inlägg')),
                  ],
                ),
              ),
            ],
          ),
        );
  }
}
```

Lägg märke till:

- Det finns bara **fyra** `ref`. Allt annat räknas fram.
- `visible` bygger på `filtered`. En `computed` kan använda en annan `computed`.
- Skriver du i sökrutan räknas `visible` och `summary` om, men inte `filtered`.
- `addPost` skapar en **ny** lista. Därför syns det nya inlägget direkt.
- `for` och `if` inne i `children` fungerar som `v-for` och `v-if` i Vue.

## Övningar

Utgå från `FeedDemo`.

**2.1** Lägg till en `computed` som heter `totalLikes`. Den ska räkna ihop
`likes` för alla inlägg som syns. Visa den under `summary`.

**2.2** Lägg till en knapp "Mest gillade först". Den ska sortera `posts` så att
inlägget med flest likes kommer först. Tänk på att `sort()` ändrar listan.

**2.3** Lägg till en knapp "Ta bort första". Prova först att skriva
`posts.value.removeAt(0)`. Vad händer? Skriv sedan om det så att det fungerar.

**2.4** Lägg till en `IconButton` vid varje inlägg som följer eller slutar
följa författaren. Den ska ändra `following`. Vad händer med listan när filtret
**Följer** är valt?

Lösningar finns i [losningar.md](losningar.md#kapitel-2--ref-och-computed).

Nästa kapitel: [watch och livscykel](03-watch-och-livscykel.md)

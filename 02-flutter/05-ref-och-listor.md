# 5. ref och listor

Allt state i Flutter Compositions bygger på `ref`. I det här kapitlet lär du
dig mer om `ref`, hur du räknar fram värden och hur du ändrar listor.

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
- När du **ändrar** `.value` körs builder-funktionen igen.

💡 Om du sätter **samma** värde igen händer ingenting. `count.value = 5` två
gånger i rad uppdaterar bara skärmen en gång.

⚠️ Jämför inte själva lådan. `if (count == 5)` är aldrig sant. Skriv
`if (count.value == 5)`.

## Räkna fram värden

Ett värde som räknas fram av andra värden ska **inte** vara en egen `ref`.
Räkna fram det i builder-funktionen i stället:

```dart
final firstName = ref('Anna');
final lastName = ref('Andersson');

return (context) => Text('${firstName.value} ${lastName.value}');
```

Ändras `firstName` körs builder-funktionen igen, och texten blir rätt av sig
själv.

Blir uträkningen lång lägger du den i en **vanlig funktion** i `setup()`. Den
fungerar likadant, så länge den anropas i builder-funktionen:

```dart
String fullName() => '${firstName.value} ${lastName.value}';

return (context) => Text(fullName());
```

💡 **Tumregel:** Kan du säga "X räknas fram av Y"? Då ska X vara en funktion
eller en uträkning i builder-funktionen, inte en egen `ref`.

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

Vi bygger ett flöde av `samplePosts` från kapitel 3. Man kan välja **Alla**,
**Följer** (de Anna följer) eller **Mina**, och söka på rubrik. Skapa filen
`lib/feed_demo.dart` och byt tillfälligt till `home: const FeedDemo()` i
`main.dart`.

```dart
// lib/feed_demo.dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

import 'data/sample_data.dart';
import 'models/post.dart';

enum FeedFilter { all, following, mine }

int likesOf(Post post) => sampleLikes[post.id] ?? 0;

class FeedDemo extends CompositionWidget {
  const FeedDemo({super.key});

  @override
  Widget Function(BuildContext) setup() {
    const me = 'anna';

    // State
    final posts = ref(samplePosts);
    final following = ref(<String>{'bertil', 'cissi'}); // de Anna följer
    final filter = ref(FeedFilter.all);
    final search = ref('');

    // Räknar fram vilka inlägg som ska synas
    List<Post> visiblePosts() {
      var result = posts.value;

      if (filter.value == FeedFilter.following) {
        result = result.where((p) => following.value.contains(p.author)).toList();
      } else if (filter.value == FeedFilter.mine) {
        result = result.where((p) => p.author == me).toList();
      }

      final q = search.value.trim().toLowerCase();
      if (q.isNotEmpty) {
        result = result.where((p) => p.title.toLowerCase().contains(q)).toList();
      }
      return result;
    }

    void addPost() {
      final post = Post(id: 'ny', author: 'anna', title: 'Nytt inlägg', body: '');
      posts.value = [post, ...posts.value];
    }

    return (context) {
      final visible = visiblePosts();

      return Scaffold(
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
            Text('Visar ${visible.length} av ${posts.value.length} inlägg'),
            Expanded(
              child: ListView(
                children: [
                  for (final p in visible)             // som v-for
                    ListTile(title: Text(p.title), subtitle: Text(p.author)),
                  if (visible.isEmpty)                 // som v-if
                    const ListTile(title: Text('Inga inlägg')),
                ],
              ),
            ),
          ],
        ),
      );
    };
  }
}
```

Lägg märke till:

- Det finns bara **fyra** `ref`. Allt annat räknas fram.
- `visiblePosts()` är en vanlig funktion. Den läser `posts`, `filter`,
  `following` och `search`. Ändras något av dem körs builder-funktionen igen.
- Builder-funktionen har nu `{ }` och `return`, eftersom den först räknar fram
  `visible`.
- `addPost` skapar en **ny** lista. Därför syns det nya inlägget direkt.
- `for` och `if` inne i `children` fungerar som `v-for` och `v-if` i Vue.

## Textfält med useTextEditingController

Ett `TextField` styrs av en **controller**. En rad ger dig allt du behöver:

```dart
final (controller, text, _) = useTextEditingController();
```

| Del | Vad är det? |
|-----|-------------|
| `controller` | Skickas till `TextField(controller: ...)` |
| `text` | En `ref` med texten. Den uppdateras när användaren skriver |
| `_` | Den tredje delen behöver vi inte |

Skriver du `text.value = ''` töms textfältet. Det fungerar åt båda hållen, som
`v-model` i Vue.

⚠️ Skapa aldrig `TextEditingController()` själv i en `CompositionWidget`.
Använd `useTextEditingController()`, så städas controllern automatiskt.

### Exempel: en kommentarsdel

Nu gör vi en kommentarsdel: ett textfält, en skicka-knapp och en lista med
kommentarerna.

```
┌──────────────────────────────────────┐
│ o  Fina färger!                      │
│ o  Snyggt jobbat!                    │
│                                      │
│ ┌──────────────────────────────┐     │
│ │ Skriv en kommentar…          │  >  │
│ └──────────────────────────────┘     │
└──────────────────────────────────────┘
```

```dart
// lib/widgets/comment_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

class CommentSection extends CompositionWidget {
  const CommentSection({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final (controller, text, _) = useTextEditingController();
    final comments = ref(<String>[]);

    void send() {
      comments.value = [...comments.value, text.value.trim()];
      text.value = ''; // tömmer textfältet
    }

    return (context) => Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  for (final comment in comments.value)
                    ListTile(
                      leading: const Icon(Icons.chat_bubble_outline),
                      title: Text(comment),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: 'Skriv en kommentar…',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: text.value.trim().isNotEmpty ? send : null, // null = grå knapp
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        );
  }
}
```

Testa den genom att tillfälligt byta `home:` i `main.dart`:

```dart
home: Scaffold(
  appBar: AppBar(title: const Text('Kommentarer')),
  body: const CommentSection(),
),
```

Knappen blir grå av sig själv när fältet är tomt. I kapitel 7 får
kommentarsdelen en egen plats på inläggets sida.

## Övningar

Utgå från `FeedDemo`.

**5.1** Skriv en funktion `totalLikes()` i `setup()`. Den ska räkna ihop
`likesOf(post)` för alla inlägg som syns. Visa summan under texten
"Visar X av Y inlägg".

**5.2** Lägg till en knapp "Mest gillade först". Den ska sortera `posts` så att
inlägget med flest likes kommer först. Tänk på att `sort()` ändrar listan.

**5.3** Lägg till en knapp "Ta bort första". Prova först att skriva
`posts.value.removeAt(0)`. Vad händer? Skriv sedan om det så att det fungerar.

**5.4** Lägg till en `IconButton` vid varje inlägg som följer eller slutar
följa författaren. Den ska ändra `following`. Vad händer med listan när filtret
**Följer** är valt?

**5.5** Visa antalet kommentarer överst i `CommentSection`, till exempel
`2 kommentarer`.

**5.6** Lägg till en text under textfältet i `CommentSection` som visar
"Du har skrivit X tecken".

Lösningar finns i [losningar.md](losningar.md#kapitel-5--ref-och-listor).

Nästa kapitel: [Livscykel](06-livscykel.md)

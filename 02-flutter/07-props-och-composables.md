# 7. Props och composables

I kapitel 3 använde du `widget()` utan att vi förklarade varför. I det här
kapitlet lär du dig tre saker:

1. Hur en widget tar emot **props** från sin förälder, och varför `widget()`
   behövs.
2. Hur du gör ett **textfält**.
3. Hur du skriver en egen **composable**, alltså logik som går att återanvända.

## Props med widget()

Props är de värden som föräldern skickar in, till exempel `PostCard(title: ...)`.
I Flutter är de vanliga `final`-fält i klassen.

### Problemet

`setup()` körs bara **en** gång. Läser du ett fält direkt i `setup()` får du
bara det första värdet:

```dart
class UserHandle extends CompositionWidget {
  const UserHandle({super.key, required this.username});
  final String username;

  @override
  Widget Function(BuildContext) setup() {
    // ❌ Läser username en gång. Skickar föräldern ett nytt namn syns det inte.
    final handle = computed(() => '@$username');
    return (context) => Text(handle.value);
  }
}
```

### Lösningen

`widget()` ger dig en `ref` med den **senaste** versionen av widgeten. Läs props
med `props.value`:

```dart
  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final handle = computed(() => '@${props.value.username}'); // ✅
    return (context) => Text(handle.value);
  }
```

### Exempel: PostCard

Nu gör vi `PostCard` från kapitel 3 lite smartare. Användarnamnet och
bokstaven i avataren räknas fram av propen, och kortet får en `onTap`:

```dart
// lib/widgets/post_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

import '../data/sample_data.dart';
import '../models/post.dart';
import 'like_button.dart';

class PostCard extends CompositionWidget {
  const PostCard({super.key, required this.post, this.onTap});

  final Post post;
  final VoidCallback? onTap; // som emit i Vue

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final theme = useTheme();

    final handle = computed(() => '@${props.value.post.author}');
    final initial = computed(() => props.value.post.author[0].toUpperCase());

    return (context) {
      final PostCard(:post, :onTap) = props.value;
      final textTheme = theme.value.textTheme;

      return Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(child: Text(initial.value)),
                    const SizedBox(width: 12),
                    Text(handle.value, style: textTheme.titleSmall),
                  ],
                ),
                const SizedBox(height: 12),
                Text(post.title, style: textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(post.body),
                LikeButton(initialLikes: sampleLikes[post.id] ?? 0),
              ],
            ),
          ),
        ),
      );
    };
  }
}
```

Så här används kortet:

```dart
PostCard(
  post: samplePosts[0],
  onTap: () => debugPrint('Öppna inlägget'),
)
```

Lägg märke till tre saker:

- `final PostCard(:post, :onTap) = props.value;` plockar ut flera props på en
  gång. `:post` betyder "skapa variabeln `post` från fältet `post`".
- `onTap` är en **callback-prop**. Så skickar barnet något uppåt till
  föräldern, som `emit` i Vue. `VoidCallback` betyder "en funktion som inte tar
  några parametrar", och `InkWell` gör en yta klickbar.
- Temat läses med `useTheme()`, inte `Theme.of(context)`. Läser du
  `Theme.of(context)` i builder-funktionen märks det inte när temat ändras.

| Vue | Flutter Compositions |
|-----|----------------------|
| `defineProps<{ title: string }>()` | `final String title;` i klassen |
| `props.title` | `props.value.title` |
| `emit('tap')` | en callback-prop, t.ex. `onTap()` |

## Textfält med useTextEditingController

Ett `TextField` styrs av en **controller**. En rad ger dig allt du behöver:

```dart
final (controller, text, _) = useTextEditingController();
```

| Del | Vad är det? |
|-----|-------------|
| `controller` | Skickas till `TextField(controller: ...)` |
| `text` | En `ref` med texten. Den uppdateras när användaren skriver |
| `_` | Den tredje delen (text + markör) behöver vi sällan |

Controllern städas **automatiskt** när widgeten försvinner. Och skriver du
`text.value = ''` töms textfältet. Det fungerar åt båda hållen, som `v-model` i
Vue.

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
    const maxLength = 280;
    final (controller, text, _) = useTextEditingController();
    final comments = ref(<String>[]);

    final remaining = computed(() => maxLength - text.value.length);
    final error = computed(() =>
        remaining.value < 0 ? '${-remaining.value} tecken för mycket' : null);
    final canSend = computed(
      () => text.value.trim().isNotEmpty && remaining.value >= 0,
    );

    void send() {
      comments.value = [...comments.value, text.value.trim()];
      text.value = ''; // tömmer textfältet
    }

    return (context) => Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: comments.value.length,
                itemBuilder: (context, index) => ListTile(
                  leading: const Icon(Icons.chat_bubble_outline),
                  title: Text(comments.value[index]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: 'Skriv en kommentar…',
                        errorText: error.value,
                        suffixText: '${remaining.value}',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: canSend.value ? send : null, // null = grå knapp
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

Knappen blir grå av sig själv när fältet är tomt, och controllern städas när
widgeten försvinner. I nästa kapitel får kommentarsdelen en egen plats på
inläggets sida.

### Andra controllers: använd .raw

Det finns fler `use...`-funktioner, till exempel `useScrollController()` och
`useFocusNode()`. De returnerar controllern inslagen i en `ref`. När du skickar
den till en widget skriver du **`.raw`**:

```dart
final scrollController = useScrollController();

return (context) => ListView(
      controller: scrollController.raw, // .raw!
      children: const [/* ... */],
    );
```

`.raw` läser värdet utan att builder-funktionen börjar bevaka det. Annars skulle
hela listan ritas om vid varje pixel man scrollar.

⚠️ Skapa aldrig `TextEditingController()` eller `ScrollController()` själv i en
`CompositionWidget`. Använd `use...`-funktionerna, så slipper du städa.

## Egna composables

En **composable** är en vanlig funktion som:

- har ett namn som börjar med `use`,
- anropas i `setup()`,
- skapar `ref`, `computed`, `watch` och liknande, och returnerar det som behövs.

`useTextEditingController` är en composable. Du kan skriva egna.

### Exempel: useCounter

```dart
(ReadonlyRef<int>, void Function(), void Function()) useCounter({
  int initial = 0,
  int? max,
}) {
  final count = ref(initial);

  void inc() {
    if (max != null && count.value >= max) return;
    count.value++;
  }

  void dec() => count.value--;

  return (count, inc, dec);
}
```

Funktionen returnerar en *record* med tre saker. `ReadonlyRef<int>` betyder att
den som använder räknaren kan läsa `count`, men inte ändra den direkt.

Använd den i `setup()`:

```dart
@override
Widget Function(BuildContext) setup() {
  final (likes, like, unlike) = useCounter(max: 10);
  final (views, view, _) = useCounter();

  return (context) => Column(
        children: [
          Text('${likes.value} likes, ${views.value} visningar'),
          TextButton(onPressed: like, child: const Text('Gilla')),
          TextButton(onPressed: unlike, child: const Text('Ta bort like')),
          TextButton(onPressed: view, child: const Text('Visa')),
        ],
      );
}
```

Varje anrop skapar **egna** `ref`. Därför påverkar `likes` och `views` inte
varandra.

| Vue | Flutter Compositions |
|-----|----------------------|
| `const { count, inc } = useCounter()` | `final (count, inc, dec) = useCounter();` |
| Returnerar ett objekt | Returnerar oftast en record |

### Regler för composables

| Regel | Varför |
|-------|--------|
| Namnet börjar med `use` | Då syns det att den måste anropas i `setup()` |
| Anropa den direkt i `setup()`, aldrig i en `if` eller i en knapp | Annars kan den inte städas |
| Städa det du startar | Startar den en timer behöver den en `onUnmounted` |

## Övningar

**7.1** Ge `PostCard` en ny prop `likeCount` (`int`, `0` från början). Visa
`1 gillning` eller `5 gillningar` under texten. Använd en `computed`.

**7.2** Ge `PostCard` en ny callback-prop `onAuthorTap` som anropas med
användarnamnet när man trycker på raden med avatar och namn. Låt föräldern
skriva ut namnet med `debugPrint`.

**7.3** Ändra `CommentSection` så att max är 140 tecken. Lägg till en text under
fältet som visar "Du har skrivit X tecken". Använd en `computed`.

**7.4** Visa antalet kommentarer överst i `CommentSection`, till exempel
`2 kommentarer`. Använd en `computed`.

**7.5** Lägg till en papperskorg (`Icons.delete_outline`) till höger på varje
kommentar. När man trycker ska kommentaren tas bort. Ledtråd: `ListTile` har
`trailing`, och kom ihåg att **ersätta** listan.

**7.6** Bygg en inloggningsruta med två `useTextEditingController`: e-post och
lösenord. Knappen "Logga in" ska bara gå att trycka på när e-posten innehåller
`@` och lösenordet har minst 8 tecken.

**7.7** Skriv en composable `useToggle({bool initial = false})` som returnerar
`(ReadonlyRef<bool>, void Function())`. Använd den för att visa och dölja
kommentarerna under ett inlägg.

**7.8 Utmaning.** Skriv `useDebounced(ReadonlyRef<String> source)`. Den ska
returnera en `ref` som får samma värde som `source`, men först 300 ms efter att
användaren slutat skriva. Använd `watch`, en `Timer` och `onUnmounted`.

Lösningar finns i [losningar.md](losningar.md#kapitel-7--props-och-composables).

Nästa kapitel: [Navigation och formulär](08-navigation-och-formular.md)

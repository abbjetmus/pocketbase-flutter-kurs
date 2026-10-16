# 4. Props och composables

I det här kapitlet lär du dig tre saker:

1. Hur en widget tar emot **props** från sin förälder.
2. Hur du gör ett **textfält** utan att städa controllers själv.
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

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

class PostCard extends CompositionWidget {
  const PostCard({
    super.key,
    required this.title,
    required this.author,
    required this.likeCount,
    this.onTap,
  });

  final String title;
  final String author;
  final int likeCount;
  final VoidCallback? onTap; // som emit i Vue

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final theme = useTheme();

    final likeLabel = computed(() => props.value.likeCount == 1
        ? '1 gillning'
        : '${props.value.likeCount} gillningar');
    final titleStyle = computed(() => theme.value.textTheme.titleMedium);

    return (context) {
      final PostCard(:title, :author, :onTap) = props.value;
      return Card(
        child: ListTile(
          title: Text(title, style: titleStyle.value),
          subtitle: Text('av $author · ${likeLabel.value}'),
          onTap: onTap,
        ),
      );
    };
  }
}
```

Så här används kortet:

```dart
PostCard(
  title: 'Höstpromenad',
  author: 'anna',
  likeCount: 2,
  onTap: () => debugPrint('Öppna inlägget'),
)
```

Lägg märke till tre saker:

- `final PostCard(:title, :author, :onTap) = props.value;` plockar ut flera
  props på en gång. `:title` betyder "skapa variabeln `title` från fältet
  `title`".
- `onTap` är en **callback-prop**. Så skickar barnet något uppåt till
  föräldern, som `emit` i Vue.
- Temat läses med `useTheme()`, inte `Theme.of(context)`. Läser du
  `Theme.of(context)` i builder-funktionen märks det inte när temat ändras.

| Vue | Flutter Compositions |
|-----|----------------------|
| `defineProps<{ title: string }>()` | `final String title;` i klassen |
| `props.title` | `props.value.title` |
| `emit('tap')` | en callback-prop, t.ex. `onTap()` |

## Textfält med useTextEditingController

I modul 02 behövde ett textfält en `TextEditingController` som skapades i
`initState` och städades i `dispose`. Här gör en rad allt:

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

### Exempel: kommentarsfält

```dart
class CommentBox extends CompositionWidget {
  const CommentBox({super.key});

  @override
  Widget Function(BuildContext) setup() {
    const maxLength = 280;
    final (controller, text, _) = useTextEditingController();

    final remaining = computed(() => maxLength - text.value.length);
    final error = computed(() =>
        remaining.value < 0 ? '${-remaining.value} tecken för mycket' : null);
    final canSend = computed(
      () => text.value.trim().isNotEmpty && remaining.value >= 0,
    );

    void send() {
      debugPrint('Skickar: ${text.value.trim()}');
      text.value = ''; // tömmer textfältet
    }

    return (context) => Row(
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
              onPressed: canSend.value ? send : null, // null = gråtonad knapp
              icon: const Icon(Icons.send),
            ),
          ],
        );
  }
}
```

Det finns ingen `setState`, ingen `addListener` och ingen `dispose`. Knappen
blir grå av sig själv när fältet är tomt.

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

**4.1** Bygg `PostCard` och visa tre kort i en `ListView`. Prova `likeCount: 1`
och `likeCount: 5`. Står det "gillning" eller "gillningar"?

**4.2** Ge `PostCard` en ny callback-prop `onAuthorTap` som anropas när man
trycker på författarens namn. Låt föräldern skriva ut namnet med `debugPrint`.

**4.3** Ändra `CommentBox` så att max är 140 tecken. Lägg till en text under
fältet som visar "Du har skrivit X tecken". Använd en `computed`.

**4.4** Bygg en inloggningsruta med två `useTextEditingController`: e-post och
lösenord. Knappen "Logga in" ska bara gå att trycka på när e-posten innehåller
`@` och lösenordet har minst 8 tecken.

**4.5** Skriv en composable `useToggle({bool initial = false})` som returnerar
`(ReadonlyRef<bool>, void Function())`. Använd den för att visa och dölja
kommentarerna under ett inlägg.

**4.6 Utmaning.** Skriv `useDebounced(ReadonlyRef<String> source)`. Den ska
returnera en `ref` som får samma värde som `source`, men först 300 ms efter att
användaren slutat skriva. Använd `watch`, en `Timer` och `onUnmounted`.

Lösningar finns i [losningar.md](losningar.md#kapitel-4--props-och-composables).

Nästa kapitel: [Skriva data och realtid](05-skriva-data-och-realtid.md)

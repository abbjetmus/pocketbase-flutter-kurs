# 4. State och interaktion

Hittills visar appen bara saker. Nu ska man kunna **göra** något: gilla ett
inlägg och skriva en kommentar.

## Vad är state?

**State** (tillstånd) är data som kan ändras medan appen körs, och som påverkar
vad som syns. Till exempel:

- om du har gillat ett inlägg
- hur många gillningar inlägget har
- vad du har skrivit i ett textfält

När state ändras ska skärmen ritas om:

```
 du trycker      state ändras       build() körs        skärmen
 på hjärtat  ──►  _liked = true  ──►  igen          ──►  visar ♥
```

## Stateless eller Stateful?

| | `StatelessWidget` | `StatefulWidget` |
|---|---|---|
| Har eget minne? | Nej | Ja |
| Kan ändra sig själv? | Nej | Ja, med `setState` |
| Exempel | `Text`, vårt `PostCard` | En gilla-knapp, ett textfält |

## En gilla-knapp

Inläggen i modul 01 hade olika många likes. Lägg till dem i
`lib/data/sample_data.dart` som en map från inläggets id till antal likes:

```dart
// lib/data/sample_data.dart (lägg till)
const sampleLikes = {'p1': 2, 'p2': 3, 'p5': 1, 'p6': 2};
```

Sedan knappen:

```dart
// lib/widgets/like_button.dart
import 'package:flutter/material.dart';

// 1. Widgeten. Den tar emot startvärdet
class LikeButton extends StatefulWidget {
  const LikeButton({super.key, this.initialLikes = 0});

  final int initialLikes;

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

// 2. State-klassen. Här bor det som ändras
class _LikeButtonState extends State<LikeButton> {
  bool _liked = false;
  int _likes = 0;

  @override
  void initState() {
    super.initState();
    _likes = widget.initialLikes; // körs en gång, när knappen skapas
  }

  void _toggle() {
    setState(() {
      _liked = !_liked;
      if (_liked) {
        _likes++;
      } else {
        _likes--;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _toggle,
      icon: Icon(
        _liked ? Icons.favorite : Icons.favorite_border,
        color: _liked ? Colors.red : null,
      ),
      label: Text('$_likes'),
    );
  }
}
```

Det är mycket kod för ett hjärta. Så här hänger delarna ihop:

| Del | Vad den gör |
|-----|-------------|
| `LikeButton` | Själva widgeten. Den tar emot `initialLikes` |
| `_LikeButtonState` | Håller det som ändras: `_liked` och `_likes` |
| `createState()` | Kopplar ihop widgeten med sin State-klass |
| `initState()` | Körs **en** gång, när knappen skapas |
| `widget.initialLikes` | Så läser State-klassen värden från widgeten |
| `setState(() { ... })` | Ändrar state **och** säger åt Flutter att köra `build` igen |

- Namn som börjar med `_` är **privata**. De syns bara i den här filen.
- `_liked ? Icons.favorite : Icons.favorite_border` betyder "om `_liked` är
  sant, ta det första, annars det andra". Det fungerar som i JavaScript.

⚠️ **Glöm inte `setState`!** Om du skriver `_liked = !_liked;` utan `setState`
ändras variabeln, men skärmen ritas inte om. Det är ett av de vanligaste felen i
Flutter.

### Sätt knappen i PostCard

Lägg till knappen längst ner i `Column` i `PostCard`:

```dart
// lib/widgets/post_card.dart (längst ner i children)
const SizedBox(height: 4),
Text(post.body),
LikeButton(initialLikes: sampleLikes[post.id] ?? 0),
```

Glöm inte att importera filerna överst i `post_card.dart`:
`import '../data/sample_data.dart';` och `import 'like_button.dart';`.

Spara och klicka på hjärtana. Varje knapp minns sitt eget state.

## Textfält och TextEditingController

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

Ett `TextField` styrs av en **controller**. Med den kan du läsa texten
(`controller.text`) och tömma fältet (`controller.clear()`).

```dart
// lib/widgets/comment_section.dart
import 'package:flutter/material.dart';

class CommentSection extends StatefulWidget {
  const CommentSection({super.key});

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  final _controller = TextEditingController();
  final List<String> _comments = [];

  void _send() {
    final text = _controller.text.trim(); // trim() tar bort mellanslag i kanterna
    if (text.isEmpty) return;
    setState(() {
      _comments.add(text);
    });
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose(); // städa bort controllern
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _comments.length,
            itemBuilder: (context, index) => ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: Text(_comments[index]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'Skriv en kommentar…',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _send(), // Enter skickar också
                ),
              ),
              IconButton(onPressed: _send, icon: const Icon(Icons.send)),
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

I nästa kapitel får den en egen plats på inläggets sida.

### Varför `dispose`?

En controller tar upp minne. När widgeten försvinner måste den städas bort med
`dispose()`. Glömmer du det märks inget direkt, men appen läcker minne.

En `State`-klass har tre viktiga metoder:

| Metod | När körs den? | Används till |
|-------|---------------|--------------|
| `initState()` | En gång, när widgeten skapas | Sätta startvärden |
| `build()` | Varje gång något ändras | Rita skärmen |
| `dispose()` | En gång, när widgeten tas bort | Städa, t.ex. `controller.dispose()` |

⚠️ Skapa **aldrig** en controller inuti `build`. `build` körs många gånger, så
du skulle få en ny controller varje gång, och texten skulle försvinna.

## Det här blir jobbigt

Det fungerar, och många appar är byggda så här. Men titta på vad du själv
måste komma ihåg:

| Jobbigt | Exempel |
|---------|---------|
| **Två klasser** för varje widget som ändrar sig | `LikeButton` och `_LikeButtonState` |
| **`setState` överallt.** Glömmer du det uppdateras inte skärmen | `_toggle()` |
| **`dispose`** för varje controller | `_controller.dispose()` |
| **`initState`** för att kopiera startvärden | `_likes = widget.initialLikes` |
| **State sitter fast** i en widget | Appens `AppBar` kan inte visa hur många inlägg du har gillat, för det vet bara varje knapp |

Om du har skrivit Vue finns det enklare sätt: en `ref` uppdaterar skärmen av
sig själv, och `onUnmounted` städar. I
[modul 03 – Flutter Compositions](../03-flutter-compositions/README.md) får
Flutter samma verktyg.

## Övningar

**4.1** Gör en `FollowButton` som `StatefulWidget`. Den visar en `FilledButton`
med texten `Följ`. När man trycker blir den en `OutlinedButton` med texten
`Följer`, och trycker man igen blir den `Följ`.

**4.2** Ta bort `setState(() { ... })` runt koden i `_toggle()` i `LikeButton`
(behåll koden inuti). Vad händer när du klickar? Varför? Lägg sedan tillbaka
`setState`.

**4.3** Visa antalet kommentarer överst i `CommentSection`, till exempel
`2 kommentarer`. Ledtråd: lägg en `Text` först i `Column` och använd
`_comments.length`.

**4.4** Skicka-knappen ska vara grå när textfältet är tomt. Ledtråd: en knapp
med `onPressed: null` är grå. Lägg till `onChanged: (_) => setState(() {})` på
`TextField`, så att `build` körs när man skriver.

**4.5 Utmaning.** Lägg till en papperskorg (`Icons.delete_outline`) till höger
på varje kommentar. När man trycker ska kommentaren tas bort. Ledtråd:
`ListTile` har `trailing`, och listor har `removeAt(index)`.

Lösningar finns i [losningar.md](losningar.md#kapitel-4--state-och-interaktion).

Nästa kapitel: [Navigation och formulär](05-navigation-och-formular.md)

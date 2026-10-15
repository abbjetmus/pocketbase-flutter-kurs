# 03 – State och livscykel

**State** (tillstånd) är data som kan ändras medan appen körs och som påverkar vad
som visas: om ett inlägg är gillat, vad användaren har skrivit i kommentarsfältet,
om flödet laddas, vilka inlägg som finns.

I Flutter gäller en enkel formel:

> **UI = f(state)**
>
> Gränssnittet är en funktion av tillståndet. När state ändras körs `build` igen
> och skärmen ritas om.

## StatelessWidget vs StatefulWidget

| | `StatelessWidget` | `StatefulWidget` |
|---|---|---|
| Har eget, föränderligt state? | Nej | Ja, i ett separat `State`-objekt |
| Byggs om när… | föräldern bygger om den med nya värden | föräldern bygger om den **eller** den själv anropar `setState` |
| Exempel | `Text`, `Icon`, vår `PostCard` | `TextField`, `Checkbox`, en gilla-knapp, ett formulär |

En `StatelessWidget` har vi redan sett:

```dart
class Greeting extends StatelessWidget {
  const Greeting({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => Text('Hej $name!');
}
```

## Första StatefulWidget: en gilla-knapp

Vi gör en knapp med ett hjärta och en siffra. Trycker man blir hjärtat fyllt och
siffran ökar, trycker man igen går det tillbaka.

```dart
import 'package:flutter/material.dart';

// 1. Själva widgeten – oföränderlig, precis som en StatelessWidget
class LikeButton extends StatefulWidget {
  const LikeButton({super.key, this.initialCount = 0, this.initiallyLiked = false});

  final int initialCount;
  final bool initiallyLiked;

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

// 2. State-klassen – här bor det som ändras
class _LikeButtonState extends State<LikeButton> {
  late bool _liked;
  late int _count;

  @override
  void initState() {
    super.initState();
    // widget.x = läs fält från widgeten
    _liked = widget.initiallyLiked;
    _count = widget.initialCount;
  }

  void _toggle() {
    setState(() {
      _liked = !_liked;
      _count += _liked ? 1 : -1;
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
      label: Text('$_count'),
    );
  }
}
```

Det här är mycket kod för ett hjärta! Låt oss gå igenom delarna:

1. **Två klasser.** `LikeButton` är widgeten (oföränderlig konfiguration), och
   `_LikeButtonState` är tillståndet (lever länge). Widgeten skapas om varje gång
   föräldern bygger om, men `State`-objektet behålls.
2. **`createState()`** kopplar ihop dem.
3. **`widget.`**: inne i `State` når du widgetens fält via `widget.initialCount`.
4. **`initState()`** körs en gång när `State` skapas. Där kopierar vi startvärdena.
5. **`setState(() { ... })`** ändrar state *och* talar om för Flutter att `build`
   ska köras igen.

⚠️ **Varning:** Om du ändrar `_liked` **utan** `setState` ändras variabeln, men
skärmen uppdateras inte. Flutter vet inte att något har hänt. Det är ett av de
vanligaste nybörjarfelen.

```dart
void _toggle() {
  _liked = !_liked; // FEL: värdet ändras men UI ritas inte om
  _count += _liked ? 1 : -1;
}
```

💡 **Tips:** Om du kommer från Vue: där är `const liked = ref(false)` *reaktivt*,
och när du skriver `liked.value = true` uppdateras vyn automatiskt. I vanlig
Flutter finns ingen sådan automatik. Du måste själv komma ihåg `setState`. Det är
precis det som modul 03 löser.

### Vad händer vid setState?

1. Funktionen du skickar in körs (state ändras).
2. Elementet markeras som "dirty".
3. Vid nästa bildruta (frame) anropar Flutter `build()` igen.
4. Flutter jämför det nya widgetträdet med det gamla och uppdaterar bara det som
   har ändrats.

`setState` bygger om **hela** widgeten, inklusive alla barn i dess `build`. För
små widgets som `LikeButton` spelar det ingen roll, men i en stor skärm kan ett
`setState` högt upp bygga om väldigt mycket. Därför bör state ligga så långt ner i
trädet som möjligt.

## State-livscykeln

Ett `State`-objekt går igenom ett antal steg. Du kan haka på dem genom att
överskugga (override) metoder.

```
 createState()
      │
      ▼
 initState()               ← en gång: skapa controllers, starta prenumerationer
      │
      ▼
 didChangeDependencies()   ← efter initState, och när ett InheritedWidget du läser ändras
      │
      ▼
 build()  ◄──────────────┐ ← många gånger
      │                  │
      ├─ setState() ─────┤
      ├─ didUpdateWidget(old) ┘ ← föräldern byggde om med ny konfiguration
      │
      ▼
 dispose()                 ← en gång: städa upp (controllers, streams, timers)
```

| Metod | När | Används till |
|-------|-----|-------------|
| `initState()` | En gång, när State skapas | Initiera controllers, starta hämtning av data, lyssna på streams. Anropa `super.initState()` **först** |
| `didChangeDependencies()` | Direkt efter `initState` och när beroenden (t.ex. `Theme`, `MediaQuery`) ändras | Sällan. Kod som behöver `context` för att läsa ärvda värden |
| `build()` | Varje gång något ändras | Returnera UI. Ska vara snabb och utan sidoeffekter |
| `didUpdateWidget(oldWidget)` | När föräldern bygger om med en ny widget av samma typ | Reagera på ändrade parametrar (t.ex. nytt `postId`) |
| `dispose()` | En gång, när widgeten tas bort för gott | Städa: `controller.dispose()`, `subscription.cancel()`, `timer.cancel()`. Anropa `super.dispose()` **sist** |

Här är en widget som skriver ut varje steg. Kör den och titta i konsolen:

```dart
class LifecycleDemo extends StatefulWidget {
  const LifecycleDemo({super.key, required this.title});
  final String title;

  @override
  State<LifecycleDemo> createState() => _LifecycleDemoState();
}

class _LifecycleDemoState extends State<LifecycleDemo> {
  int _count = 0;

  @override
  void initState() {
    super.initState();
    debugPrint('initState');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    debugPrint('didChangeDependencies');
  }

  @override
  void didUpdateWidget(LifecycleDemo oldWidget) {
    super.didUpdateWidget(oldWidget);
    debugPrint('didUpdateWidget: ${oldWidget.title} -> ${widget.title}');
  }

  @override
  void dispose() {
    debugPrint('dispose');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('build');
    return TextButton(
      onPressed: () => setState(() => _count++),
      child: Text('${widget.title}: $_count'),
    );
  }
}
```

⚠️ **Varning:** Du kan inte använda `context` för att läsa ärvda värden
(t.ex. `Theme.of(context)`) i `initState`. Gör det i `build` eller
`didChangeDependencies`. Och du får inte anropa `setState` efter `dispose`. Kontrollera
`if (!mounted) return;` efter varje `await` innan du anropar `setState`.

## Controllers och varför dispose spelar roll

Många widgets styrs av ett **controller-objekt** som du skapar själv:

- `TextEditingController` läser och ändrar texten i ett `TextField`,
- `ScrollController` läser och styr scrollposition,
- `AnimationController`, `TabController`, `PageController` …

Controllers håller resurser (lyssnare, och för animationer en "ticker" som körs
varje bildruta). De måste **skapas en gång** och **städas bort** med `dispose()`.
Annars får du minnesläckor och ibland felmeddelanden.

Här är en kommentarsskärm för ett inlägg. Längst ner finns ett textfält och en
skicka-knapp som bara är aktiv när något har skrivits. När man skickar läggs
kommentaren till och listan scrollar ner till den.

```dart
class CommentsScreen extends StatefulWidget {
  const CommentsScreen({super.key, required this.initialComments});
  final List<String> initialComments;

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  // 1. Deklarera – late eftersom de skapas i initState
  late final TextEditingController _textController;
  late final ScrollController _scrollController;
  late final List<String> _comments;

  @override
  void initState() {
    super.initState();
    // 2. Skapa
    _textController = TextEditingController();
    _textController.addListener(_onTextChanged);
    _scrollController = ScrollController();
    _comments = [...widget.initialComments]; // egen kopia som vi får ändra i
  }

  void _onTextChanged() {
    setState(() {}); // bygg om så att skicka-knappen aktiveras/inaktiveras
  }

  void _send() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    setState(() => _comments.add(text));
    _textController.clear();

    // Vänta tills listan har ritats med den nya raden, scrolla sedan längst ner
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    // 3. Städa – lätt att glömma!
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _textController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text('${_comments.length} kommentarer')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _comments.length,
              itemBuilder: (context, i) => ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: Text(_comments[i]),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        hintText: 'Skriv en kommentar…',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: canSend ? _send : null,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

Räkna raderna som bara handlar om att *hantera* state, inte om att visa något:
`late final`-deklarationer, `initState`, `addListener`, `removeListener`, två
`dispose`, `setState(() {})`, `addPostFrameCallback` och `hasClients`-kontrollen.
Det är ungefär hälften av klassen.

⚠️ **Varning:** Skapa **aldrig** en controller i `build`:

```dart
@override
Widget build(BuildContext context) {
  final controller = TextEditingController(); // FEL! Ny controller varje build
  return TextField(controller: controller);   // texten nollställs, och ingen dispose
}
```

`build` körs många gånger. Då skapas en ny controller varje gång, texten
försvinner och de gamla städas aldrig bort.

## didUpdateWidget: när parametrarna ändras

Anta att en widget visar kommentarerna till ett inlägg och hämtar dem i `initState`:

```dart
class PostComments extends StatefulWidget {
  const PostComments({super.key, required this.postId});
  final int postId;

  @override
  State<PostComments> createState() => _PostCommentsState();
}

class _PostCommentsState extends State<PostComments> {
  List<String> _comments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Utan den här metoden visas fel inläggs kommentarer efter byte!
  @override
  void didUpdateWidget(PostComments oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId != widget.postId) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final id = widget.postId;
    await Future.delayed(const Duration(milliseconds: 500)); // låtsas-API
    final result = ['Kommentar A till inlägg $id', 'Kommentar B till inlägg $id'];
    if (!mounted) return; // widgeten kan ha tagits bort under väntan
    setState(() {
      _comments = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(children: [for (final c in _comments) Text(c)]);
  }
}
```

Om föräldern byter `postId` från `1` till `2` (till exempel när man bläddrar till
nästa inlägg) körs **inte** `initState` igen, eftersom `State`-objektet
återanvänds. Utan `didUpdateWidget` skulle widgeten fortsätta visa kommentarerna
till inlägg 1. Det här är ett klassiskt och svårhittat fel: allt ser rätt ut tills
någon byter inlägg.

Samma fälla finns i `LikeButton` ovan: `initialCount` och `initiallyLiked` läses
bara i `initState`. Om föräldern bygger om knappen med ett annat inlägg visar den
fortfarande det gamla inläggets siffra. Antingen lägger du till en
`didUpdateWidget`, eller så låter du någon annan äga statet. Det är nästa avsnitt.

💡 **Tips:** I Vue skulle du skriva `watch(() => props.postId, load)`. I vanlig
Flutter måste du själv jämföra gammalt och nytt i `didUpdateWidget`.

## Lyfta state uppåt och callbacks

Ofta behöver **två** widgets samma state. Exempel: flödet har en gilla-knapp på
varje kort, och uppe i `AppBar` står det hur många inlägg du har gillat. Om varje
`LikeButton` har sitt eget state vet `AppBar` ingenting. Lösningen är att **lyfta
upp** state till närmaste gemensamma förälder och skicka ner:

- **data** nedåt via konstruktorparametrar, och
- **händelser** uppåt via callbacks (`ValueChanged<T>`, `VoidCallback`).

```dart
class Post {
  const Post({required this.id, required this.title, this.likeCount = 0, this.liked = false});

  final int id;
  final String title;
  final int likeCount;
  final bool liked;

  Post toggleLike() => Post(
        id: id,
        title: title,
        liked: !liked,
        likeCount: liked ? likeCount - 1 : likeCount + 1,
      );
}

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  // State bor här, i föräldern
  List<Post> _posts = const [
    Post(id: 1, title: 'Första fikat på nya kontoret', likeCount: 12),
    Post(id: 2, title: 'Cykla till jobbet i regn', likeCount: 4, liked: true),
    Post(id: 3, title: 'Tips: Flutter DevTools'),
  ];

  void _toggleLike(Post post) {
    setState(() {
      // Ny lista där bara det tryckta inlägget är utbytt
      _posts = [for (final p in _posts) p.id == post.id ? p.toggleLike() : p];
    });
  }

  @override
  Widget build(BuildContext context) {
    final likedCount = _posts.where((p) => p.liked).length;

    return Scaffold(
      appBar: AppBar(title: Text('Flöde · du gillar $likedCount')),
      body: FeedList(
        posts: _posts,           // data ner
        onLike: _toggleLike,     // händelse upp
      ),
    );
  }
}

// Barnen är stateless! De visar bara det de får och rapporterar klick.
class FeedList extends StatelessWidget {
  const FeedList({super.key, required this.posts, required this.onLike});

  final List<Post> posts;
  final ValueChanged<Post> onLike; // = void Function(Post)

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        for (final post in posts)
          ListTile(
            key: ValueKey(post.id),
            title: Text(post.title),
            trailing: TextButton.icon(
              onPressed: () => onLike(post),
              icon: Icon(
                post.liked ? Icons.favorite : Icons.favorite_border,
                color: post.liked ? Colors.red : null,
              ),
              label: Text('${post.likeCount}'),
            ),
          ),
      ],
    );
  }
}
```

Det här mönstret motsvarar **props ner, events upp** i Vue (`:post` och `@like`).
Nu finns det bara **en** sanning om vilka inlägg som är gillade, och både listan och
`AppBar` visar den. Det fungerar bra, men när appen växer måste state ofta skickas
genom många nivåer av widgets som själva inte bryr sig om det ("prop drilling"):
`FeedScreen` → `FeedList` → `PostCard` → gilla-knappen.

## InheritedWidget, Theme.of och MediaQuery

För data som många widgets långt ner i trädet behöver har Flutter
**`InheritedWidget`**. Det är en widget som gör data tillgänglig för *alla*
ättlingar utan att den skickas manuellt. Du har redan använt det:

```dart
final theme = Theme.of(context);          // temat från MaterialApp
final size = MediaQuery.sizeOf(context);  // skärmens storlek
final navigator = Navigator.of(context);  // navigationen (kapitel 04)
```

Mönstret `Xxx.of(context)` betyder "gå uppåt i trädet från där jag är och hitta
närmaste `Xxx`". Dessutom registreras din widget som beroende: om temat eller
skärmstorleken ändras (t.ex. när telefonen vrids) byggs den om automatiskt.

```dart
@override
Widget build(BuildContext context) {
  final wide = MediaQuery.sizeOf(context).width > 600;
  return wide
      ? Row(children: const [Expanded(child: Text('Flöde')), Expanded(child: Text('Inlägg'))])
      : const Text('Flöde');
}
```

`BuildContext` är alltså din widgets **plats i trädet**. Det är därför `of`
behöver den.

💡 **Tips:** Att skriva egna `InheritedWidget` är ganska omständligt. I praktiken
används paket som `provider` eller `riverpod`, eller `provide`/`inject` i
`flutter_compositions` (modul 03). Typiskt exempel: den inloggade användaren, som
nästan alla skärmar i Kvittra behöver.

## Keys (kort)

Normalt matchar Flutter gamla och nya widgets efter **typ och position**. Det går
fel när du har en lista av *stateful* widgets som byter ordning eller tas bort:
statet följer positionen, inte datan. Tänk dig ett flöde av kort med var sin
`LikeButton` där ett nytt inlägg läggs in överst. Utan keys "flyttar" alla hjärtan
ett steg ner till fel inlägg.

```dart
ListView(
  children: [
    for (final post in posts)
      PostTile(key: ValueKey(post.id), post: post),
  ],
)
```

Med en `ValueKey` som bygger på ett unikt id kan Flutter se att "det här är
fortfarande inlägg 42" även om det har flyttats, och behålla rätt state.

Tumregel: ge widgets i dynamiska listor en key om de har eget state eller om
listan kan sorteras om eller filtreras. `super.key` i konstruktorn finns där just
för att den som använder widgeten ska kunna skicka in en key.

## Sammanfattning – och smärtpunkterna

Vi har sett hur vanlig Flutter hanterar state. Det fungerar, och stora appar är
byggda så här. Men lägg märke till vad du som utvecklare själv måste komma ihåg:

| Smärtpunkt | Exempel i kapitlet |
|-----------|-------------------|
| **Två klasser per stateful widget** (`Widget` + `State`) och `createState` | `LikeButton` / `_LikeButtonState` |
| **Manuell `setState`.** Glömmer du den uppdateras inte UI | `_liked = !_liked` utan `setState` |
| **Grovkornig ombyggnad.** `setState` bygger om hela widgeten | Hela `CommentsScreen`, med listan, byggs om vid varje tangenttryck |
| **Controllers måste skapas i `initState` och städas i `dispose`** | `late final` + `addListener` + `removeListener` + `dispose` |
| **Glömd `dispose` ger minnesläckor** som inte syns direkt | Controller i `build` |
| **`didUpdateWidget` för att reagera på ändrade parametrar** | `PostComments` som visar fel inläggs kommentarer, `LikeButton` med gammal siffra |
| **`mounted`-kontroller efter `await`** | `if (!mounted) return;` |
| **Härledda värden räknas om i `build`** | `canSend` och `likedCount` beräknas på nytt vid varje build |
| **Prop drilling** när state behövs långt ner | `FeedScreen` → `FeedList` → gilla-knappen |

Om du har skrivit Vue känner du igen motsvarigheterna: `ref`, `computed`, `watch`,
`onUnmounted` och `provide`/`inject`. I [modul 03](../03-flutter-compositions/README.md)
ser du hur `flutter_compositions` ger Flutter just de verktygen, med en
`CompositionWidget` och en `setup()`-metod som körs en gång.

🧪 **Prova själv:**

1. Kör `LifecycleDemo` inuti en förälder som har en knapp som byter `title`.
   Vilka metoder skrivs ut när du trycker på knappen i föräldern? Och när du trycker
   på knappen i `LifecycleDemo`?
2. Ta bort `didUpdateWidget` från `PostComments` och bygg en förälder med knapparna
   "Inlägg 1" och "Inlägg 2" som växlar `postId`. Se felet uppstå.
3. Kommentera bort `_textController.dispose()` och kör appen. Märks något? (Nej,
   inte direkt. Det är just därför felet är lömskt.)

**Nästa kapitel:** [04 – Navigation och formulär](04-navigation-och-formular.md)

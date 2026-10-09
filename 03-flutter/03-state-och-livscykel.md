# 03 – State och livscykel

**State** (tillstånd) är data som kan ändras medan appen körs och som påverkar vad
som visas: vilken flik som är vald, vad användaren har skrivit i ett textfält, om
en lista laddas, vilka bokningar som finns.

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
| Exempel | `Text`, `Icon`, vår `ResourceCard` | `TextField`, `Checkbox`, en räknare, ett formulär |

En `StatelessWidget` har vi redan sett:

```dart
class Greeting extends StatelessWidget {
  const Greeting({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => Text('Hej $name!');
}
```

## Första StatefulWidget: en räknare

Vi gör en widget där man väljer hur många timmar man vill boka tvättstugan.

```dart
import 'package:flutter/material.dart';

// 1. Själva widgeten – oföränderlig, precis som en StatelessWidget
class HoursPicker extends StatefulWidget {
  const HoursPicker({super.key, this.maxHours = 3});

  final int maxHours;

  @override
  State<HoursPicker> createState() => _HoursPickerState();
}

// 2. State-klassen – här bor det som ändras
class _HoursPickerState extends State<HoursPicker> {
  int _hours = 1;

  void _increment() {
    setState(() {
      _hours++;
    });
  }

  void _decrement() {
    setState(() => _hours--);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _hours > 1 ? _decrement : null,
          icon: const Icon(Icons.remove),
        ),
        Text('$_hours h', style: Theme.of(context).textTheme.headlineSmall),
        IconButton(
          // widget.maxHours = läs fält från widgeten
          onPressed: _hours < widget.maxHours ? _increment : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
```

Det här är mycket kod för en räknare! Låt oss gå igenom delarna:

1. **Två klasser.** `HoursPicker` är widgeten (oföränderlig konfiguration), och
   `_HoursPickerState` är tillståndet (lever länge). Widgeten skapas om varje gång
   föräldern bygger om, men `State`-objektet behålls.
2. **`createState()`** kopplar ihop dem.
3. **`widget.`**: inne i `State` når du widgetens fält via `widget.maxHours`.
4. **`setState(() { ... })`** ändrar state *och* talar om för Flutter att `build`
   ska köras igen.

⚠️ **Varning:** Om du ändrar `_hours++` **utan** `setState` ändras variabeln, men
skärmen uppdateras inte. Flutter vet inte att något har hänt. Det är ett av de
vanligaste nybörjarfelen.

```dart
void _increment() {
  _hours++; // FEL: värdet ändras men UI ritas inte om
}
```

💡 **Tips:** Om du kommer från Vue: där är `const hours = ref(1)` *reaktivt*, och
när du skriver `hours.value++` uppdateras vyn automatiskt. I vanlig Flutter finns
ingen sådan automatik. Du måste själv komma ihåg `setState`. Det är precis det som
modul 04 löser.

### Vad händer vid setState?

1. Funktionen du skickar in körs (state ändras).
2. Elementet markeras som "dirty".
3. Vid nästa bildruta (frame) anropar Flutter `build()` igen.
4. Flutter jämför det nya widgetträdet med det gamla och uppdaterar bara det som
   har ändrats.

`setState` bygger om **hela** widgeten, inklusive alla barn i dess `build`. För
små widgets spelar det ingen roll, men i en stor skärm kan ett `setState` högt upp
bygga om väldigt mycket. Därför bör state ligga så långt ner i trädet som möjligt.

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
| `didUpdateWidget(oldWidget)` | När föräldern bygger om med en ny widget av samma typ | Reagera på ändrade parametrar (t.ex. ny `resourceId`) |
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

Här är ett sökfält för anslag med både text- och scroll-controller:

```dart
class PostSearchScreen extends StatefulWidget {
  const PostSearchScreen({super.key, required this.posts});
  final List<String> posts;

  @override
  State<PostSearchScreen> createState() => _PostSearchScreenState();
}

class _PostSearchScreenState extends State<PostSearchScreen> {
  // 1. Deklarera – late eftersom de skapas i initState
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  bool _showToTop = false;

  @override
  void initState() {
    super.initState();
    // 2. Skapa
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);

    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  void _onSearchChanged() {
    setState(() {}); // bygg om så att filtreringen syns
  }

  void _onScroll() {
    final show = _scrollController.offset > 300;
    if (show != _showToTop) {
      setState(() => _showToTop = show);
    }
  }

  @override
  void dispose() {
    // 3. Städa – lätt att glömma!
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.toLowerCase();
    final filtered =
        widget.posts.where((p) => p.toLowerCase().contains(query)).toList();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Sök bland anslag',
            border: InputBorder.none,
          ),
        ),
      ),
      body: ListView.builder(
        controller: _scrollController,
        itemCount: filtered.length,
        itemBuilder: (context, i) => ListTile(title: Text(filtered[i])),
      ),
      floatingActionButton: _showToTop
          ? FloatingActionButton.small(
              onPressed: () => _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              ),
              child: const Icon(Icons.arrow_upward),
            )
          : null,
    );
  }
}
```

Räkna raderna som bara handlar om att *hantera* state, inte om att visa något:
`late final`-deklarationer, `initState`, `addListener`, `removeListener`, `dispose`,
`setState(() {})` och jämförelsen i `_onScroll`. Det är ungefär hälften av klassen.

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

Anta att en widget visar bokningar för en resurs och hämtar dem i `initState`:

```dart
class ResourceBookings extends StatefulWidget {
  const ResourceBookings({super.key, required this.resourceId});
  final String resourceId;

  @override
  State<ResourceBookings> createState() => _ResourceBookingsState();
}

class _ResourceBookingsState extends State<ResourceBookings> {
  List<String> _bookings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Utan den här metoden visas fel resurs efter byte!
  @override
  void didUpdateWidget(ResourceBookings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resourceId != widget.resourceId) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final id = widget.resourceId;
    await Future.delayed(const Duration(milliseconds: 500)); // låtsas-API
    final result = ['Bokning A för $id', 'Bokning B för $id'];
    if (!mounted) return; // widgeten kan ha tagits bort under väntan
    setState(() {
      _bookings = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(children: [for (final b in _bookings) Text(b)]);
  }
}
```

Om föräldern byter `resourceId` från `'tvatt1'` till `'fest'` körs **inte**
`initState` igen, eftersom `State`-objektet återanvänds. Utan `didUpdateWidget`
skulle widgeten fortsätta visa tvättstugans bokningar. Det här är ett klassiskt och
svårhittat fel: allt ser rätt ut tills någon byter resurs.

💡 **Tips:** I Vue skulle du skriva `watch(() => props.resourceId, load)`. I
vanlig Flutter måste du själv jämföra gammalt och nytt i `didUpdateWidget`.

## Lyfta state uppåt och callbacks

Ofta behöver **två** widgets samma state. Exempel: en lista med resurser där man
kan välja en, och en knapp längst ner som visar vilken som är vald. Lösningen är
att **lyfta upp** state till närmaste gemensamma förälder och skicka ner:

- **data** nedåt via konstruktorparametrar, och
- **händelser** uppåt via callbacks (`ValueChanged<T>`, `VoidCallback`).

```dart
class ResourcePickerScreen extends StatefulWidget {
  const ResourcePickerScreen({super.key});

  @override
  State<ResourcePickerScreen> createState() => _ResourcePickerScreenState();
}

class _ResourcePickerScreenState extends State<ResourcePickerScreen> {
  static const _resources = ['Tvättstuga 1', 'Tvättstuga 2', 'Festlokalen'];
  String? _selected; // state bor här, i föräldern

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Välj resurs')),
      body: ResourceSelector(
        resources: _resources,
        selected: _selected,                                 // data ner
        onSelected: (r) => setState(() => _selected = r),    // händelse upp
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _selected == null ? null : () {},
            child: Text(_selected == null ? 'Välj en resurs' : 'Boka $_selected'),
          ),
        ),
      ),
    );
  }
}

// Barnet är stateless! Det visar bara det det får och rapporterar klick.
class ResourceSelector extends StatelessWidget {
  const ResourceSelector({
    super.key,
    required this.resources,
    required this.selected,
    required this.onSelected,
  });

  final List<String> resources;
  final String? selected;
  final ValueChanged<String> onSelected; // = void Function(String)

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        for (final r in resources)
          ListTile(
            title: Text(r),
            leading: Icon(
              r == selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            ),
            selected: r == selected,
            onTap: () => onSelected(r),
          ),
      ],
    );
  }
}
```

Det här mönstret motsvarar **props ner, events upp** i Vue (`:selected` och
`@selected`). Det fungerar bra, men när appen växer måste state ofta skickas genom
många nivåer av widgets som själva inte bryr sig om det ("prop drilling").

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
      ? Row(children: const [Expanded(child: Text('Lista')), Expanded(child: Text('Detalj'))])
      : const Text('Lista');
}
```

`BuildContext` är alltså din widgets **plats i trädet**. Det är därför `of`
behöver den.

💡 **Tips:** Att skriva egna `InheritedWidget` är ganska omständligt. I praktiken
används paket som `provider` eller `riverpod`, eller `provide`/`inject` i
`flutter_compositions` (modul 04).

## Keys (kort)

Normalt matchar Flutter gamla och nya widgets efter **typ och position**. Det går
fel när du har en lista av *stateful* widgets som byter ordning eller tas bort:
statet följer positionen, inte datan.

```dart
ListView(
  children: [
    for (final booking in bookings)
      BookingTile(key: ValueKey(booking.id), booking: booking),
  ],
)
```

Med en `ValueKey` som bygger på ett unikt id kan Flutter se att "det här är
fortfarande bokning `b42`" även om den har flyttats, och behålla rätt state.

Tumregel: ge widgets i dynamiska listor en key om de har eget state eller om
listan kan sorteras om eller filtreras. `super.key` i konstruktorn finns där just
för att den som använder widgeten ska kunna skicka in en key.

## Sammanfattning – och smärtpunkterna

Vi har sett hur vanlig Flutter hanterar state. Det fungerar, och stora appar är
byggda så här. Men lägg märke till vad du som utvecklare själv måste komma ihåg:

| Smärtpunkt | Exempel i kapitlet |
|-----------|-------------------|
| **Två klasser per stateful widget** (`Widget` + `State`) och `createState` | `HoursPicker` / `_HoursPickerState` |
| **Manuell `setState`.** Glömmer du den uppdateras inte UI | `_hours++` utan `setState` |
| **Grovkornig ombyggnad.** `setState` bygger om hela widgeten | Hela `PostSearchScreen` byggs om vid varje tangenttryck |
| **Controllers måste skapas i `initState` och städas i `dispose`** | `late final` + `addListener` + `removeListener` + `dispose` |
| **Glömd `dispose` ger minnesläckor** som inte syns direkt | Controller i `build` |
| **`didUpdateWidget` för att reagera på ändrade parametrar** | `ResourceBookings` som visar fel resurs |
| **`mounted`-kontroller efter `await`** | `if (!mounted) return;` |
| **Härledda värden räknas om i `build`** | `filtered` beräknas på nytt vid varje build |
| **Prop drilling** när state behövs långt ner | `ResourceSelector` |

Om du har skrivit Vue känner du igen motsvarigheterna: `ref`, `computed`, `watch`,
`onUnmounted` och `provide`/`inject`. I [modul 04](../04-flutter-compositions/README.md)
ser du hur `flutter_compositions` ger Flutter just de verktygen, med en
`CompositionWidget` och en `setup()`-metod som körs en gång.

🧪 **Prova själv:**

1. Kör `LifecycleDemo` inuti en förälder som har en knapp som byter `title`.
   Vilka metoder skrivs ut när du trycker på knappen i föräldern? Och när du trycker
   på knappen i `LifecycleDemo`?
2. Ta bort `didUpdateWidget` från `ResourceBookings` och bygg en förälder som växlar
   mellan två resurs-id. Se felet uppstå.
3. Kommentera bort `_searchController.dispose()` och kör appen. Märks något? (Nej,
   inte direkt. Det är just därför felet är lömskt.)

**Nästa kapitel:** [04 – Navigation och formulär](04-navigation-och-formular.md)

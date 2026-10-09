# 8. Best practices, lints, tester och migrering

Det här kapitlet samlar reglerna från modulen, visar hur lint-reglerna hjälper dig att
följa dem, hur du testar och hur du migrerar en befintlig `StatefulWidget`.

## Reglerna för `setup()`

| # | Regel | Varför |
|---|-------|--------|
| 1 | `setup()` är **synkron** | Den måste returnera builder-funktionen direkt. Async görs i `onMounted`/`useAsyncData` |
| 2 | `setup()` körs **en gång** | State lever i refs. Logik som ska köras om hör hemma i `computed`/`watch` |
| 3 | **Inga villkorliga** anrop av composition-API:er | `ref`, `computed`, `watch`, `use*`, `provide`, `inject` ska anropas i samma ordning varje gång (hot reload bygger på ordningen) |
| 4 | **Ingen `BuildContext`** i `setup()` | Context finns bara i builder-funktionen. Använd `useTheme`/`useContextRef`/`useContext` |
| 5 | **Props via `widget()`** | Direkt åtkomst ger bara startvärdet |
| 6 | **Hooks och watchers registreras i `setup()`** | Inte i callbacks eller i `onMounted` (se kapitel 4) |

### Regel 3 i praktiken

```dart
// ❌ Villkorligt anrop
if (props.value.editable) {
  final (controller, text, _) = useTextEditingController();
}

// ✅ Anropa alltid och styr i stället vad som visas
final (controller, text, _) = useTextEditingController();
final editable = computed(() => props.value.editable);
```

Samma regel finns för React Hooks, och av samma skäl: systemet håller reda på dina refs
via deras **position** i `setup()`.

## Håll builder-funktionen ren

Builder-funktionen ska bara **beskriva widgetträdet**. Beräkningar, filtrering, formatering
och villkorslogik som går att bryta ut flyttas till `computed` i `setup()`. Det enda
undantaget är destrukturering av props.

```dart
// ❌ Logik i builder: körs om vid varje build och cachas inte
return (context) {
  final upcoming = bookings.value
      .where((b) => b.end.isAfter(DateTime.now()))
      .toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  final title = upcoming.isEmpty ? 'Inga bokningar' : '${upcoming.length} bokningar';
  return Column(children: [
    Text(title),
    for (final b in upcoming) BookingTile(booking: b),
  ]);
};

// ✅ Logik i setup() som computed
final upcoming = computed(() => bookings.value
    .where((b) => b.end.isAfter(DateTime.now()))
    .toList()
  ..sort((a, b) => a.start.compareTo(b.start)));
final title = computed(() =>
    upcoming.value.isEmpty ? 'Inga bokningar' : '${upcoming.value.length} bokningar');

return (context) => Column(children: [
      Text(title.value),
      for (final b in upcoming.value) BookingTile(booking: b),
    ]);
```

Enkla `if`/`for` i widgetlistor (motsvarande `v-if`/`v-for`) är okej. Det som ska bort är
*beräkningar*.

## Övriga riktlinjer

- **`computed` före `watch`** för härledda värden (kapitel 3).
- **Ersätt, mutera inte** listor och objekt (kapitel 2).
- **`use*` för controllers**, aldrig `XController()` + manuell `dispose()` (kapitel 5).
- **`.raw` för controllers** som skickas till widgets (kapitel 5).
- **`useTheme`/`useContextRef`** i stället för `Theme.of`/`MediaQuery.of` i builder
  (kapitel 5).
- **Bryt ut composables** när `setup()` växer eller samma logik behövs på två ställen.
- **Dela upp stora widgets** (över ca 150 rader) så att bara den del som ändras byggs om.
- **`const`-widgets** för statiska delar.
- **`StatelessWidget` är fortfarande okej** för rent presentations-UI utan state.

## Lint-reglerna

Med `flutter_compositions_lints` (installation i [README](README.md#installation))
fångas de vanligaste misstagen redan i editorn. Version 0.1.1 har dessa regler:

| Regel | Nivå | Fångar |
|-------|------|--------|
| `flutter_compositions_ensure_reactive_props` | Varning | Props som läses direkt (`this.name`) i stället för via `widget()` |
| `flutter_compositions_no_async_setup` | Fel | `setup()` markerad som `async` |
| `flutter_compositions_controller_lifecycle` | Varning | Controllers som skapas utan `use*` eller `dispose()` i `onUnmounted` |
| `flutter_compositions_no_conditional_composition` | Fel | Composition-API:er i `if`, loopar och liknande |
| `flutter_compositions_no_mutable_fields` | Varning | Icke-`final` fält i en `CompositionWidget` |

Nyare versioner av paketet lägger till fler regler, bland annat
`no_logic_in_builder` (ren builder), `prefer_raw_controller` (`.raw` för controllers)
och `shallow_reactivity` (mutation av listor). Även om din version inte har dem är de
bra att följa.

```bash
dart run custom_lint            # kör alla regler
dart run custom_lint --watch    # löpande
```

Behöver du stänga av en regel på en enstaka rad:

```dart
// ignore: flutter_compositions_ensure_reactive_props
final initial = initialNote;
```

Gör det sparsamt, och skriv en kommentar om varför.

## Projektstruktur

För kursens projekt räcker en enkel uppdelning per *typ*:

```
lib/
├── main.dart                 # rot-widget: provide + router
├── models/                   # immutabla klasser med fromRecord + copyWith
│   ├── booking.dart
│   ├── post.dart
│   └── resource.dart
├── services/
│   └── pocketbase_service.dart   # InjectionKeys, AuthService, BookingService
├── composables/              # use_auth.dart, use_bookings.dart, use_booking_form.dart …
├── screens/                  # en CompositionWidget per skärm
└── widgets/                  # små återanvändbara widgets
```

I större appar grupperar man hellre per *feature* (se [kapitel 9](09-arkitektur-for-en-riktig-app.md),
`lib/features/bookings/…`), men principen är densamma.

- Filnamn med `snake_case`, och composables i filer som heter `use_xxx.dart`.
- En composable per fil, med namn som beskriver avsikten (`useDebouncedSearch` är
  tydligare än `useSearch`).

## Testa

### 1. Rena composables, utan widget

Composables som bara använder `ref` och `computed` kan testas som vanliga funktioner:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

(Ref<int>, void Function()) useCounter({int initialValue = 0}) {
  final count = ref(initialValue);
  void increment() => count.value++;
  return (count, increment);
}

void main() {
  test('useCounter ökar', () {
    final (count, increment) = useCounter(initialValue: 1);
    final doubled = computed(() => count.value * 2);

    increment();

    expect(count.value, 2);
    expect(doubled.value, 4);
  });
}
```

### 2. Composables med `watch`, hooks eller `inject`: kör dem i en `CompositionBuilder`

`watch`, `onMounted`, `inject` och `use*`-controllers kräver en setup-kontext. Kör
composablen i en `CompositionBuilder` i ett widget-test och fånga resultatet:

```dart
testWidgets('useDebounced väntar 300 ms', (tester) async {
  late Ref<String> source;
  late ReadonlyRef<String> debounced;

  await tester.pumpWidget(CompositionBuilder(setup: () {
    source = ref('');
    debounced = useDebounced(source);
    return (context) => const SizedBox();
  }));

  source.value = 'tvätt';
  await tester.pump(const Duration(milliseconds: 100));
  expect(debounced.value, '');

  await tester.pump(const Duration(milliseconds: 300));
  expect(debounced.value, 'tvätt');
});
```

### 3. Widgets med fejkade tjänster via `provide`

```dart
class FakeBookingService implements BookingService {
  @override
  Future<List<Resource>> fetchActiveResources() async => const [
        Resource(id: 'r1', name: 'Tvättstuga 1', description: '', maxHours: 3, active: true),
      ];
  // ... övriga metoder kastar UnimplementedError
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

testWidgets('ResourcesScreen visar resurser', (tester) async {
  await tester.pumpWidget(CompositionBuilder(setup: () {
    provide<BookingService>(bookingServiceKey, FakeBookingService());
    return (context) => const MaterialApp(home: Scaffold(body: ResourcesScreen()));
  }));

  expect(find.byType(CircularProgressIndicator), findsOneWidget);
  await tester.pumpAndSettle();               // låt useAsyncData bli klar
  expect(find.text('Tvättstuga 1'), findsOneWidget);
});
```

### 4. Text och interaktion

```dart
await tester.enterText(find.byType(TextField).first, 'anna@example.com');
await tester.pump();                 // låt refs och builder uppdateras
expect(find.text('Logga in'), findsOneWidget);
```

> 💡 **Tips:** Anropa alltid `tester.pump()` efter en interaktion så att
> builder-funktionen hinner köras om. Använd `pumpAndSettle()` när futures och
> animationer ska bli klara.

## Migrera från StatefulWidget: checklista

- [ ] Byt `extends StatefulWidget` mot `extends CompositionWidget` och ta bort
      `createState` och `State`-klassen.
- [ ] Flytta fälten från `State` till `ref(...)` i `setup()`.
- [ ] Byt `setState(() => x = v)` mot `x.value = v`.
- [ ] Flytta innehållet i `initState` till `setup()`. Det som kräver en färdig frame
      flyttas till `onMounted`.
- [ ] Byt controllers mot `use*`, och ta bort deras `dispose()`.
- [ ] Byt kvarvarande `dispose`-logik (timers, prenumerationer) mot `onUnmounted`.
- [ ] Byt `widget.x` mot `final props = widget();` och `props.value.x`.
- [ ] Byt `didUpdateWidget` mot `watch(() => props.value.x, …)` eller
      `useAsyncData(watch: …)`.
- [ ] Byt härledda fält som hålls i synk manuellt mot `computed`.
- [ ] Byt `addListener` mot `computed`/`watch` på refs från `use*`.
- [ ] Byt `Theme.of`/`MediaQuery.of` i `build` mot `useTheme`/`useMediaQuery`.
- [ ] Ta bort `if (mounted)`-kontroller.
- [ ] Kör `dart run custom_lint` och testerna, och prova hot reload.

## Fullständigt exempel: före och efter

En skärm som söker bland anslag. Den har ett sökfält med debounce, en lista som laddas
från PocketBase, en "till toppen"-knapp och en prop `onlyPublished` som kan ändras.

### Före: StatefulWidget (≈110 rader)

```dart
class PostSearchScreen extends StatefulWidget {
  const PostSearchScreen({super.key, required this.pb, this.onlyPublished = true});
  final PocketBase pb;
  final bool onlyPublished;

  @override
  State<PostSearchScreen> createState() => _PostSearchScreenState();
}

class _PostSearchScreenState extends State<PostSearchScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  List<RecordModel> _posts = [];
  bool _loading = true;
  String? _error;
  bool _showToTop = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void didUpdateWidget(PostSearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onlyPublished != widget.onlyPublished) _load();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  void _onScroll() {
    final show = _scrollController.offset > 400;
    if (show != _showToTop) setState(() => _showToTop = show);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final q = _searchController.text.trim();
      final filter = widget.onlyPublished
          ? widget.pb.filter('published = true && title ~ {:q}', {'q': q})
          : widget.pb.filter('title ~ {:q}', {'q': q});
      final posts = await widget.pb
          .collection('posts')
          .getFullList(filter: filter, sort: '-created');
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(hintText: 'Sök anslag…'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)))
              : ListView(
                  controller: _scrollController,
                  children: [
                    for (final p in _posts)
                      ListTile(title: Text(p.getStringValue('title'))),
                  ],
                ),
      floatingActionButton: _showToTop
          ? FloatingActionButton(
              onPressed: () => _scrollController.animateTo(0,
                  duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
              child: const Icon(Icons.arrow_upward),
            )
          : null,
    );
  }
}
```

### Efter: CompositionWidget

```dart
class PostSearchScreen extends CompositionWidget {
  const PostSearchScreen({super.key, this.onlyPublished = true});
  final bool onlyPublished;

  @override
  Widget Function(BuildContext) setup() {
    final pb = inject(pocketBaseKey);            // DI i stället för prop
    final props = widget();
    final theme = useTheme();

    final (searchController, search, _) = useTextEditingController();
    final debouncedSearch = useDebounced(search); // composable från kapitel 5
    final scrollController = useScrollController();

    final (status, _) = useAsyncData<List<RecordModel>, (String, bool)>(
      (args) {
        final (q, onlyPublished) = args;
        final filter = onlyPublished
            ? pb.filter('published = true && title ~ {:q}', {'q': q.trim()})
            : pb.filter('title ~ {:q}', {'q': q.trim()});
        return pb
            .collection('posts')
            .getFullList(filter: filter, sort: '-created');
      },
      watch: () => (debouncedSearch.value, props.value.onlyPublished),
    );

    final showToTop = computed(() =>
        scrollController.value.hasClients && scrollController.value.offset > 400);
    final errorStyle = computed(() => TextStyle(color: theme.value.colorScheme.error));

    void scrollToTop() => scrollController.raw.animateTo(0,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);

    return (context) => Scaffold(
          appBar: AppBar(
            title: TextField(
              controller: searchController,
              decoration: const InputDecoration(hintText: 'Sök anslag…'),
            ),
          ),
          body: switch (status.value) {
            AsyncIdle() || AsyncLoading() =>
              const Center(child: CircularProgressIndicator()),
            AsyncError(:final errorValue) =>
              Center(child: Text('$errorValue', style: errorStyle.value)),
            AsyncData(:final value) => ListView(
                controller: scrollController.raw,
                children: [
                  for (final p in value)
                    ListTile(title: Text(p.getStringValue('title'))),
                ],
              ),
          },
          floatingActionButton: showToTop.value
              ? FloatingActionButton(
                  onPressed: scrollToTop,
                  child: const Icon(Icons.arrow_upward),
                )
              : null,
        );
  }
}
```

### Vad försvann?

| Före | Efter |
|------|-------|
| `State`-klass, `createState` | – |
| 7 fält + `setState` på 4 ställen | 0 `setState`, state i refs/computed |
| `addListener` × 2, `dispose()` × 3, `Timer`-städning | `useTextEditingController`, `useScrollController`, `useDebounced` |
| `didUpdateWidget` | `watch:` i `useAsyncData` läser `props.value.onlyPublished` |
| `if (!mounted) return;` × 2 | – |
| Manuell `_loading`/`_error`-hantering | `AsyncValue` + `switch` |
| `Theme.of(context)` i `build` | `useTheme()` + `computed` |
| `pb` skickas som prop | `inject(pocketBaseKey)` |

Lägg också märke till att `useAsyncData` bevakar **två** värden genom att returnera en
record från `watch`.

## Sammanfattning

- Följ reglerna för `setup()`: synkron, en gång, ovillkorlig, ingen context, props via
  `widget()`.
- Håll builder-funktionen ren och flytta beräkningar till `computed`.
- Aktivera lint-reglerna. De fångar många misstag direkt.
- Testa rena composables som funktioner. Composables med hooks eller inject testar du i
  en `CompositionBuilder`, och widgets med fejkade tjänster via `provide`.
- Migrera stegvis med checklistan.

Nästa kapitel: [Arkitektur för en riktig app →](09-arkitektur-for-en-riktig-app.md)

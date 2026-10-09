# Lösningar – Modul 04: Flutter Compositions

> ⚠️ **Varning:** Försök själv först! Det finns ofta flera bra lösningar. Det här är
> *förslag*. All kod nedan är testad mot `flutter_compositions` 0.1.1.

---

## Nivå 1

### Lösning 1.1 – LimitedCounter

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

class LimitedCounter extends CompositionWidget {
  const LimitedCounter({super.key, this.min = 0, this.max = 10});
  final int min;
  final int max;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final count = ref(props.value.min);

    final canDecrement = computed(() => count.value > props.value.min);
    final canIncrement = computed(() => count.value < props.value.max);
    final label = computed(() => 'Antal: ${count.value} (max ${props.value.max})');

    void increment() => count.value++;
    void decrement() => count.value--;
    void reset() => count.value = props.value.min;

    return (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label.value),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: canDecrement.value ? decrement : null,
                  icon: const Icon(Icons.remove),
                ),
                IconButton(
                  onPressed: canIncrement.value ? increment : null,
                  icon: const Icon(Icons.add),
                ),
                TextButton(onPressed: reset, child: const Text('Nollställ')),
              ],
            ),
          ],
        );
  }
}
```

**Kommentarer:**

- `count` startar på `props.value.min`. Det är ett medvetet *startvärde* (kapitel 4).
- `canDecrement`/`canIncrement` läser `props.value.min/max`. Ändrar föräldern `max`
  uppdateras knapparna automatiskt, vilket originalet bara klarade för att `build()`
  kördes om.
- Ingen `initState`, inget `setState` och ingen `State`-klass.

### Lösning 1.2 – Tvättlistan

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

class LaundryList extends CompositionWidget {
  const LaundryList({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final (inputController, input, _) = useTextEditingController();
    final items = ref(<String>[]);
    final sorted = computed(() => [...items.value]..sort());
    final countLabel = computed(() => '${items.value.length} saker');
    final canAdd = computed(() => input.value.trim().isNotEmpty);

    void add() {
      items.value = [...items.value, input.value.trim()];
      input.value = '';
    }

    void remove(String item) {
      items.value = items.value.where((i) => i != item).toList();
    }

    void removeFirst() {
      if (items.value.isEmpty) return;
      items.value = items.value.sublist(1);
    }

    return (context) => Column(
          children: [
            Row(
              children: [
                Expanded(child: TextField(controller: inputController)),
                IconButton(
                  onPressed: canAdd.value ? add : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            Text(countLabel.value),
            TextButton(onPressed: removeFirst, child: const Text('Ta bort första')),
            for (final item in sorted.value)
              ListTile(
                title: Text(item),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => remove(item),
                ),
              ),
          ],
        );
  }
}
```

**Kommentarer:**

- `[...items.value]..sort()` sorterar en **kopia**. `items.value..sort()` hade muterat
  originalet, och eftersom det är samma lista-instans hade ingen uppdatering triggats.
- `input.value = ''` tömmer textfältet tack vare tvåvägsbindningen.
- `sublist(1)` skapar en ny lista. `removeAt(0)` hade muterat den gamla.

### Lösning 1.3 – Hitta felen

| # | Fel | Varför | Rättning |
|---|-----|--------|----------|
| 1 | `int clicks = 0;`, ett föränderligt fält i widgeten | Inte reaktivt, och widgets ska vara immutabla (`no_mutable_fields`) | Lägg state i en `ref` i `setup()` |
| 2 | Konstruktorn är inte `const` | Följer av fel 1. Med bara `final`-fält kan den vara `const` | `const Greeting(...)` |
| 3 | `'Hej $name!'` läser prop direkt | Bara startvärdet fångas (`ensure_reactive_props`) | `props.value.name` via `widget()` |
| 4 | `if (name.isEmpty) { watchEffect(...) }` | Villkorligt composition-anrop (`no_conditional_composition`) | Anropa alltid och lägg villkoret *inuti* effekten, eller ta bort den |
| 5 | `Theme.of(context)` i builder | Uppdateras inte reaktivt när temat byts | `useTheme()` + `computed` |
| 6 | `Text('$message')` | Glömt `.value`, skriver ut `Instance of …` | `message.value` |
| 7 | `tags.value.add('ny')` | Mutation, ingen uppdatering (grund reaktivitet) | `tags.value = [...tags.value, 'ny']` |
| 8 | `clicks++` | Varken reaktivt eller tillåtet (fel 1) | `visits.value++` |

Rättad version:

```dart
class Greeting extends CompositionWidget {
  const Greeting({super.key, required this.name});
  final String name;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final theme = useTheme();
    final visits = ref(0);
    final tags = ref(<String>[]);
    final message = computed(() => 'Hej ${props.value.name}! Besök: ${visits.value}');
    final style = computed(() => theme.value.textTheme.titleLarge);

    onMounted(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      visits.value = 1;
    });

    return (context) => Column(
          children: [
            Text(message.value, style: style.value),
            Text(tags.value.join(', ')),
            TextButton(
              onPressed: () => tags.value = [...tags.value, 'ny'],
              child: const Text('Lägg till tagg'),
            ),
            TextButton(
              onPressed: () => visits.value++,
              child: const Text('+1'),
            ),
          ],
        );
  }
}
```

---

## Nivå 2

### Lösning 2.1 – Todo-lista med filter

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

enum TodoFilter { all, active, done }

class Todo {
  const Todo({required this.id, required this.title, this.done = false});
  final int id;
  final String title;
  final bool done;
  Todo copyWith({bool? done}) => Todo(id: id, title: title, done: done ?? this.done);
}

class TodoScreen extends CompositionWidget {
  const TodoScreen({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final (inputController, input, _) = useTextEditingController();
    final todos = ref(<Todo>[]);
    final filter = ref(TodoFilter.all);
    var nextId = 1;

    final visible = computed(() => switch (filter.value) {
          TodoFilter.all => todos.value,
          TodoFilter.active => todos.value.where((t) => !t.done).toList(),
          TodoFilter.done => todos.value.where((t) => t.done).toList(),
        });
    final remaining = computed(() => todos.value.where((t) => !t.done).length);
    final summary = computed(() => '${remaining.value} av ${todos.value.length} kvar');
    final canAdd = computed(() => input.value.trim().isNotEmpty);
    final hasDone = computed(() => todos.value.any((t) => t.done));

    void add() {
      todos.value = [...todos.value, Todo(id: nextId++, title: input.value.trim())];
      input.value = '';
    }

    void toggle(Todo todo) {
      todos.value = [
        for (final t in todos.value) t.id == todo.id ? t.copyWith(done: !t.done) : t,
      ];
    }

    void clearDone() {
      todos.value = todos.value.where((t) => !t.done).toList();
    }

    return (context) => Scaffold(
          appBar: AppBar(title: Text(summary.value)),
          body: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: inputController,
                      onSubmitted: (_) => canAdd.value ? add() : null,
                    ),
                  ),
                  IconButton(onPressed: canAdd.value ? add : null, icon: const Icon(Icons.add)),
                ],
              ),
              SegmentedButton<TodoFilter>(
                segments: const [
                  ButtonSegment(value: TodoFilter.all, label: Text('Alla')),
                  ButtonSegment(value: TodoFilter.active, label: Text('Aktiva')),
                  ButtonSegment(value: TodoFilter.done, label: Text('Klara')),
                ],
                selected: {filter.value},
                onSelectionChanged: (s) => filter.value = s.first,
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final t in visible.value)
                      CheckboxListTile(
                        value: t.done,
                        title: Text(t.title),
                        onChanged: (_) => toggle(t),
                      ),
                  ],
                ),
              ),
              TextButton(
                onPressed: hasDone.value ? clearDone : null,
                child: const Text('Rensa klara'),
              ),
            ],
          ),
        );
  }
}
```

**Kommentarer:**

- `visible` använder en `switch`-expression över enumen. Lägger du till ett nytt
  filter tvingar kompilatorn dig att hantera det.
- `toggle` bygger en ny lista med `copyWith` för den todo som ändras. Övriga element
  återanvänds.
- `nextId` är en vanlig lokal variabel. Den behöver inte vara reaktiv, eftersom ingen
  UI läser den.

### Lösning 2.2 – Registreringsformulär

```dart
class RegisterForm extends CompositionWidget {
  const RegisterForm({super.key, required this.onSubmit});
  final void Function(String name, String email, String apartment, String password) onSubmit;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final (nameController, name, _) = useTextEditingController();
    final (emailController, email, _) = useTextEditingController();
    final (aptController, apartment, _) = useTextEditingController();
    final (pwController, password, _) = useTextEditingController();
    final (pw2Controller, password2, _) = useTextEditingController();
    final touched = ref(false);

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    final aptRegex = RegExp(r'^\d{4}$');

    final nameError = computed(() => name.value.trim().length < 2 ? 'Ange ditt namn' : null);
    final emailError = computed(() => emailRegex.hasMatch(email.value.trim()) ? null : 'Ogiltig e-postadress');
    final aptError = computed(() => aptRegex.hasMatch(apartment.value) ? null : 'Lägenhetsnummer är fyra siffror, t.ex. 1101');
    final passwordError = computed(() => password.value.length < 8 ? 'Minst 8 tecken' : null);
    final password2Error = computed(() => password2.value != password.value ? 'Lösenorden matchar inte' : null);

    final isValid = computed(() => [
          nameError.value,
          emailError.value,
          aptError.value,
          passwordError.value,
          password2Error.value,
        ].every((e) => e == null));

    String? show(ReadonlyRef<String?> error) => touched.value ? error.value : null;

    void submit() {
      touched.value = true;
      if (!isValid.value) return;
      props.value.onSubmit(name.value.trim(), email.value.trim(), apartment.value, password.value);
    }

    return (context) => Column(
          children: [
            TextField(controller: nameController, decoration: InputDecoration(labelText: 'Namn', errorText: show(nameError))),
            TextField(controller: emailController, decoration: InputDecoration(labelText: 'E-post', errorText: show(emailError))),
            TextField(controller: aptController, decoration: InputDecoration(labelText: 'Lägenhet', errorText: show(aptError))),
            TextField(controller: pwController, obscureText: true, decoration: InputDecoration(labelText: 'Lösenord', errorText: show(passwordError))),
            TextField(controller: pw2Controller, obscureText: true, decoration: InputDecoration(labelText: 'Bekräfta lösenord', errorText: show(password2Error))),
            FilledButton(onPressed: submit, child: const Text('Registrera')),
          ],
        );
  }
}
```

**Kommentarer:**

- Varje fel är en egen `computed`, och de räknas bara om när sitt eget fält ändras.
  `password2Error` beror på **både** `password` och `password2`, så ändrar du det första
  lösenordet uppdateras felet för bekräftelsen automatiskt.
- `show(...)` är en liten hjälpfunktion som läser `touched.value` och felet. Den anropas
  i builder-funktionen, så båda blir beroenden.
- `props.value.onSubmit(...)` motsvarar `emit('submit', ...)` i Vue.

**Bonus – `useValidatedField`:**

```dart
(TextEditingController, WritableRef<String>, ReadonlyRef<String?>) useValidatedField(
  String? Function(String value) validator,
) {
  final (controller, text, _) = useTextEditingController();
  final error = computed(() => validator(text.value));
  return (controller, text, error);
}
```

```dart
// Användning i setup():
final (emailController, email, emailError) = useValidatedField(
  (v) => v.contains('@') ? null : 'Ogiltig e-post',
);
```

### Lösning 2.3 – `useCountdown`

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

class Countdown {
  Countdown({
    required this.remaining,
    required this.isRunning,
    required this.isFinished,
    required this.start,
    required this.pause,
    required this.reset,
  });
  final ReadonlyRef<Duration> remaining;
  final ReadonlyRef<bool> isRunning;
  final ReadonlyRef<bool> isFinished;
  final void Function() start;
  final void Function() pause;
  final void Function() reset;
}

Countdown useCountdown(Duration total, {Duration tick = const Duration(seconds: 1)}) {
  final remaining = ref(total);
  final isRunning = ref(false);
  final isFinished = computed(() => remaining.value <= Duration.zero);
  Timer? timer;

  void pause() {
    timer?.cancel();
    timer = null;
    isRunning.value = false;
  }

  void start() {
    if (isRunning.value || isFinished.value) return;
    isRunning.value = true;
    timer = Timer.periodic(tick, (_) {
      final next = remaining.value - tick;
      remaining.value = next < Duration.zero ? Duration.zero : next;
      if (remaining.value == Duration.zero) pause();
    });
  }

  void reset() {
    pause();
    remaining.value = total;
  }

  onUnmounted(() => timer?.cancel());

  return Countdown(
    remaining: remaining,
    isRunning: isRunning,
    isFinished: isFinished,
    start: start,
    pause: pause,
    reset: reset,
  );
}
```

Widgeten:

```dart
class LaundryTimer extends CompositionWidget {
  const LaundryTimer({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final countdown = useCountdown(const Duration(minutes: 45));
    final label = computed(() {
      final r = countdown.remaining.value;
      final m = r.inMinutes.toString().padLeft(2, '0');
      final s = (r.inSeconds % 60).toString().padLeft(2, '0');
      return countdown.isFinished.value ? 'Tvätten är klar!' : '$m:$s';
    });
    final buttonLabel = computed(() => countdown.isRunning.value ? 'Pausa' : 'Starta');

    watch(() => countdown.isFinished.value, (finished, _) {
      if (finished) debugPrint('Dags att hämta tvätten');
    });

    return (context) => Column(
          children: [
            Text(label.value, style: const TextStyle(fontSize: 48)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton(
                  onPressed: countdown.isRunning.value ? countdown.pause : countdown.start,
                  child: Text(buttonLabel.value),
                ),
                TextButton(onPressed: countdown.reset, child: const Text('Nollställ')),
              ],
            ),
          ],
        );
  }
}
```

Testet (`test/countdown_test.dart`):

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:komp_ovningar/ovningar/countdown.dart';

void main() {
  testWidgets('useCountdown räknar ner och stannar på noll', (tester) async {
    late Countdown c;
    await tester.pumpWidget(CompositionBuilder(setup: () {
      c = useCountdown(const Duration(seconds: 3));
      return (context) => const SizedBox();
    }));
    c.start();
    expect(c.isRunning.value, isTrue);
    await tester.pump(const Duration(seconds: 1));
    expect(c.remaining.value, const Duration(seconds: 2));
    c.pause();
    await tester.pump(const Duration(seconds: 5));
    expect(c.remaining.value, const Duration(seconds: 2));
    c.start();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    expect(c.isFinished.value, isTrue);
    expect(c.isRunning.value, isFalse);
    c.reset();
    expect(c.remaining.value, const Duration(seconds: 3));
  });
}
```

**Kommentarer:**

- `onUnmounted` registreras direkt i composablen, **inte** i `start()`. `start()` körs
  från en knapp, alltså utanför `setup()`, och då fungerar inga hooks (kapitel 4).
- `isFinished` är `computed`, eftersom det är ett härlett värde.
- I testet styr `tester.pump(Duration)` den fejkade klockan. Timern i `Timer.periodic`
  följer den, så testet tar inga riktiga sekunder.

---

## Nivå 3

### Lösning 3.1 – Tema och inloggning

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

class FakeUser {
  const FakeUser({required this.name, required this.apartment});
  final String name;
  final String apartment;
}

class SessionService {
  final Ref<FakeUser?> _user = ref<FakeUser?>(null);
  ReadonlyRef<FakeUser?> get user => _user;
  late final ReadonlyRef<bool> isLoggedIn = computed(() => _user.value != null);

  Future<void> login(String name) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _user.value = FakeUser(name: name, apartment: '1101');
  }

  void logout() => _user.value = null;
}

const sessionKey = InjectionKey<SessionService>('session');
const themeModeKey = InjectionKey<Ref<ThemeMode>>('themeMode');

class AppShell extends CompositionWidget {
  const AppShell({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final session = SessionService();
    final themeMode = ref(ThemeMode.light);
    provide(sessionKey, session);
    provide(themeModeKey, themeMode);

    return (context) => MaterialApp(
          themeMode: themeMode.value,
          theme: ThemeData(colorSchemeSeed: Colors.teal),
          darkTheme: ThemeData(colorSchemeSeed: Colors.teal, brightness: Brightness.dark),
          home: session.isLoggedIn.value ? const HomePage() : const FakeLoginPage(),
        );
  }
}

class FakeLoginPage extends CompositionWidget {
  const FakeLoginPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final session = inject(sessionKey);
    final (nameController, name, _) = useTextEditingController();
    final loading = ref(false);
    final canLogin = computed(() => name.value.trim().isNotEmpty && !loading.value);

    Future<void> login() async {
      loading.value = true;
      await session.login(name.value.trim());
      loading.value = false;
    }

    return (context) => Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Namn')),
                FilledButton(onPressed: canLogin.value ? login : null, child: const Text('Logga in')),
              ],
            ),
          ),
        );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const ProfileHeader(), actions: const [ThemeToggle()]),
        body: const Center(child: Text('Välkommen till föreningen')),
      );
}

class ProfileHeader extends CompositionWidget {
  const ProfileHeader({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final session = inject(sessionKey);
    final title = computed(() {
      final u = session.user.value;
      return u == null ? '' : '${u.name} (lgh ${u.apartment})';
    });
    return (context) => Row(
          children: [
            Text(title.value),
            IconButton(onPressed: session.logout, icon: const Icon(Icons.logout)),
          ],
        );
  }
}

class ThemeToggle extends CompositionWidget {
  const ThemeToggle({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final themeMode = inject(themeModeKey);
    final isDark = computed(() => themeMode.value == ThemeMode.dark);
    final icon = computed(() => isDark.value ? Icons.light_mode : Icons.dark_mode);
    void toggle() => themeMode.value = isDark.value ? ThemeMode.light : ThemeMode.dark;
    return (context) => IconButton(onPressed: toggle, icon: Icon(icon.value));
  }
}
```

Testet:

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:komp_ovningar/ovningar/app_shell.dart';

void main() {
  testWidgets('ProfileHeader visar inloggad användare', (tester) async {
    final session = SessionService();
    unawaited(session.login('Anna'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(session.isLoggedIn.value, isTrue);

    await tester.pumpWidget(CompositionBuilder(setup: () {
      provide(sessionKey, session);
      provide(themeModeKey, ref(ThemeMode.light));
      return (context) => const MaterialApp(home: HomePage());
    }));

    expect(find.text('Anna (lgh 1101)'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.logout));
    await tester.pump();
    expect(session.isLoggedIn.value, isFalse);
  });
}
```

**Kommentarer:**

- `SessionService` exponerar `user` som `ReadonlyRef`. Bara `login`/`logout` kan ändra
  den.
- `HomePage` är en vanlig `StatelessWidget`. Den har inget eget state, och barnen
  hämtar det de behöver med `inject`.
- `AppShell` läser `session.isLoggedIn.value` i builder-funktionen, och byter därför
  skärm automatiskt vid in- och utloggning.
- I testet loggar vi in *innan* `pumpWidget` och låter `tester.pump(300 ms)` köra
  fördröjningen.

### Lösning 3.2 – Resurslista med refresh och realtime

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';

const pocketBaseKey = InjectionKey<PocketBase>('pocketBase');

class Resource {
  const Resource({required this.id, required this.name, required this.description, required this.maxHours, required this.active});
  final String id;
  final String name;
  final String description;
  final int maxHours;
  final bool active;
  factory Resource.fromRecord(RecordModel r) => Resource(
        id: r.id,
        name: r.getStringValue('name'),
        description: r.getStringValue('description'),
        maxHours: r.getIntValue('max_hours'),
        active: r.getBoolValue('active'),
      );
}

class ResourcesPage extends CompositionWidget {
  const ResourcesPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final pb = inject(pocketBaseKey);
    final showInactive = ref(false);

    final (status, refresh) = useAsyncData<List<Resource>, bool>(
      (includeInactive) async {
        final records = await pb.collection('resources').getFullList(
              filter: includeInactive ? '' : 'active = true',
              sort: 'name',
            );
        return records.map(Resource.fromRecord).toList();
      },
      watch: () => showInactive.value,
    );

    final title = computed(() => switch (status.value) {
          AsyncData(:final value) => 'Resurser (${value.length})',
          _ => 'Resurser',
        });

    UnsubscribeFunc? unsubscribe;
    var disposed = false;
    onMounted(() async {
      final unsub = await pb.collection('resources').subscribe('*', (_) => refresh());
      if (disposed) {
        await unsub();
      } else {
        unsubscribe = unsub;
      }
    });
    onUnmounted(() {
      disposed = true;
      unsubscribe?.call();
    });

    return (context) => Scaffold(
          appBar: AppBar(
            title: Text(title.value),
            actions: [
              Switch(value: showInactive.value, onChanged: (v) => showInactive.value = v),
            ],
          ),
          body: switch (status.value) {
            AsyncIdle() || AsyncLoading() => const Center(child: CircularProgressIndicator()),
            AsyncError(:final errorValue) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Kunde inte hämta resurser:\n$errorValue', textAlign: TextAlign.center),
                    FilledButton(onPressed: refresh, child: const Text('Försök igen')),
                  ],
                ),
              ),
            AsyncData(:final value) => RefreshIndicator(
                onRefresh: () async => refresh(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (value.isEmpty) const ListTile(title: Text('Inga resurser')),
                    for (final r in value)
                      ListTile(
                        title: Text(r.name),
                        subtitle: Text('${r.description} · max ${r.maxHours} h'),
                        trailing: r.active ? null : const Chip(label: Text('Inaktiv')),
                      ),
                  ],
                ),
              ),
          },
        );
  }
}
```

I `main.dart`:

```dart
class App extends CompositionWidget {
  const App({super.key});

  @override
  Widget Function(BuildContext) setup() {
    provide(pocketBaseKey, PocketBase('http://127.0.0.1:8090'));
    return (context) => const MaterialApp(home: ResourcesPage());
  }
}
```

**Kommentarer:**

- `watch: () => showInactive.value` gör att `useAsyncData` hämtar om när switchen
  ändras. Värdet skickas som argument (`includeInactive`) till hämtfunktionen.
- `title` använder en `switch` på `status.value` i en `computed`, inte i builder.
- `physics: AlwaysScrollableScrollPhysics()` gör att pull-to-refresh fungerar även när
  listan är kort.
- Realtime-prenumerationen följer mönstret från kapitel 7: `onMounted` +
  `onUnmounted` registrerade i `setup()`, plus en `disposed`-flagga för fallet där
  widgeten försvinner innan `subscribe` hunnit bli klar.
- Kom ihåg att API-regeln för `resources` (List/View) måste tillåta användaren att se
  posterna, annars kommer varken data eller händelser
  ([02 – API-regler](../02-pocketbase/04-autentisering-och-api-regler.md)). I den här
  övningen är ingen inloggad, så reglerna måste tillåta anonym läsning, eller så loggar du
  in först.

### Lösning 3.4 – Felanmälan

Lösningen följer checklistan i kapitel 9. Allt nedan är analyserat med
`dart analyze`, och reglerna är provkörda med `curl`.

#### Backend

`pb_migrations/1700000300_issues.js`:

```js
/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const users = app.findCollectionByNameOrId("users")
  const associations = app.findCollectionByNameOrId("associations")
  const tenant = '@request.auth.id != "" && association = @request.auth.association'
  const board = '(@request.auth.role = "styrelse" || @request.auth.role = "admin")'

  const issues = new Collection({
    type: "base",
    name: "issues",
    fields: [
      { name: "title", type: "text", required: true, max: 200 },
      { name: "description", type: "text", required: true },
      { name: "reported_by", type: "relation", collectionId: users.id, maxSelect: 1, required: true },
      { name: "assigned_to", type: "relation", collectionId: users.id, maxSelect: 1 },
      { name: "is_resolved", type: "bool" },
      { name: "association", type: "relation", collectionId: associations.id, maxSelect: 1 },
      { name: "created", type: "autodate", onCreate: true },
      { name: "updated", type: "autodate", onCreate: true, onUpdate: true },
    ],
    listRule: tenant,
    viewRule: tenant,
    createRule: '@request.auth.id != "" && @request.body.reported_by = @request.auth.id && @request.body.is_resolved:isset = false',
    // Anmälaren får ändra text (inte status) tills den är åtgärdad. Styrelsen får ändra allt.
    updateRule:
      'association = @request.auth.association && @request.body.reported_by:changed = false && (' +
      '(reported_by = @request.auth.id && is_resolved = false && @request.body.is_resolved:isset = false) || ' + board + ')',
    deleteRule: 'reported_by = @request.auth.id || (@request.auth.role = "admin" && association = @request.auth.association)',
  })
  app.save(issues)
}, (app) => {
  app.delete(app.findCollectionByNameOrId("issues"))
})
```

I `pb_hooks/tenant.pb.js` läggs `"issues"` till i listan av collections i **både**
create- och update-hooken:

```js
}, "posts", "post_comments", "bookings", "issues");
```

Provkört:

| Försök | Resultat |
|--------|----------|
| Anna anmäler ett fel | Sparas, med `association` stämplad och `is_resolved = false` |
| Anna skickar `"is_resolved": true` vid skapande | `400` |
| Anna ändrar rubriken på sin öppna anmälan | OK |
| Anna markerar sin anmälan som åtgärdad | `404` (update-regeln) |
| Bo (styrelse) markerar den som åtgärdad | OK |
| Anna ändrar texten efter att den åtgärdats | `404` |
| Cecilia (förening B) listar anmälningar | 0 träffar |
| Anna raderar sin anmälan | `204` |

> 💡 **Tips:** Regeln `@request.body.is_resolved:isset = false` betyder att klienten
> inte ens får *skicka med* fältet. Därför skickar store:n inte `is_resolved` när en ny
> anmälan skapas.

#### Modell: `lib/core/models/issue_record.dart`

```dart
class IssueRecord {
  const IssueRecord({
    required this.id,
    required this.title,
    required this.description,
    required this.reportedBy,
    required this.reporterName,
    required this.isResolved,
    required this.created,
  });

  final String id;
  final String title;
  final String description;
  final String reportedBy;    // relation-id → users
  final String reporterName;  // från expand.reported_by
  final bool isResolved;
  final DateTime? created;

  factory IssueRecord.fromJson(Map<String, dynamic> json) {
    final expand = json['expand'] as Map<String, dynamic>? ?? const {};
    final reporter = expand['reported_by'] as Map<String, dynamic>?;
    return IssueRecord(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      reportedBy: json['reported_by'] as String? ?? '',
      reporterName: reporter?['name'] as String? ?? 'Okänd',
      isResolved: json['is_resolved'] as bool? ?? false,
      created: DateTime.tryParse(json['created'] as String? ?? '')?.toLocal(),
    );
  }
}
```

#### Store: `lib/features/issues/issues_store.dart`

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart' hide AuthStore;

import '../../core/models/issue_record.dart';
import '../../core/pagination/paginated.dart';
import '../auth/auth_store.dart';

class IssuesStore {
  IssuesStore(this._pb, this._auth);

  final PocketBase _pb;
  final AuthStore _auth;

  static const _collection = 'issues';

  /// Filter: visa åtgärdade felanmälningar eller inte.
  final showResolved = ref(false);

  late final issues = Paginated<IssueRecord>((page, perPage) async {
    final res = await _pb.collection(_collection).getList(
          page: page,
          perPage: perPage,
          filter: showResolved.value ? '' : 'is_resolved = false',
          sort: '-created',
          expand: 'reported_by',
        );
    return PageResult(
      res.items.map((r) => IssueRecord.fromJson(r.toJson())).toList(),
      res.totalPages,
    );
  });

  final _saving = ref(false);
  ReadonlyRef<bool> get saving => _saving;

  Future<IssueRecord?> fetchIssue(String id) async {
    try {
      final r = await _pb.collection(_collection).getOne(id, expand: 'reported_by');
      return IssueRecord.fromJson(r.toJson());
    } catch (e) {
      debugPrint('IssuesStore.fetchIssue: $e');
      return null;
    }
  }

  Future<bool> saveIssue({
    String? id,
    required String title,
    required String description,
  }) async {
    final user = _auth.user.value;
    if (user == null) return false;
    _saving.value = true;
    try {
      final data = {'title': title, 'description': description};
      if (id == null) {
        await _pb.collection(_collection).create(
              // is_resolved skickas inte: create-regeln förbjuder det.
              body: {...data, 'reported_by': user.id},
            );
      } else {
        await _pb.collection(_collection).update(id, body: data);
      }
      await issues.refresh();
      return true;
    } catch (e) {
      debugPrint('IssuesStore.saveIssue: $e');
      return false;
    } finally {
      _saving.value = false;
    }
  }

  Future<bool> setResolved(String id, bool resolved) async {
    try {
      await _pb.collection(_collection).update(id, body: {'is_resolved': resolved});
      await issues.refresh();
      return true;
    } catch (e) {
      debugPrint('IssuesStore.setResolved: $e');
      return false;
    }
  }

  Future<bool> deleteIssue(String id) async {
    try {
      await _pb.collection(_collection).delete(id);
      issues.removeWhere((i) => i.id == id);
      return true;
    } catch (e) {
      debugPrint('IssuesStore.deleteIssue: $e');
      return false;
    }
  }
}
```

#### Koppla in: DI, `MyApp`, router, behörighet och dashboard

```dart
// lib/core/di/injection_keys.dart
import '../../features/issues/issues_store.dart';
const issuesStoreKey = InjectionKey<IssuesStore>('issuesStore');

// lib/main.dart, i MyApp.setup()
final issuesStore = IssuesStore(pb, authStore);
provide(issuesStoreKey, issuesStore);

// lib/core/router/router.dart, '/issues/new' före '/issues/:id'
GoRoute(path: IssuesListPage.path, builder: (_, _) => const IssuesListPage()),
GoRoute(path: CreateIssuePage.path, builder: (_, _) => const CreateIssuePage()),
GoRoute(
  path: CreateIssuePage.editPath,
  builder: (_, state) => CreateIssuePage(issueId: state.pathParameters['id']),
),
GoRoute(
  path: IssueDetailPage.path,
  builder: (_, state) => IssueDetailPage(issueId: state.pathParameters['id']!),
),

// lib/core/utils/permissions.dart
enum AppMenu { posts, bookings, members, issues }
// ... och i defaultPermissions:
AppMenu.issues: {
  UserRole.admin: {PermissionOp.read, PermissionOp.create, PermissionOp.update, PermissionOp.delete},
  UserRole.styrelse: {PermissionOp.read, PermissionOp.create, PermissionOp.update},
  UserRole.member: {PermissionOp.read, PermissionOp.create},
},

// lib/features/dashboard/pages/dashboard_page.dart, i _allItems
_MenuItem(AppMenu.issues, 'Felanmälan', Icons.build, IssuesListPage.path),
```

#### Lista: `lib/features/issues/pages/issues_list_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/paginated_list_view.dart';
import '../../../core/di/injection_keys.dart';
import 'create_issue_page.dart';
import 'issue_detail_page.dart';

class IssuesListPage extends CompositionWidget {
  const IssuesListPage({super.key});

  static const path = '/issues';

  @override
  Widget Function(BuildContext) setup() {
    final store = inject(issuesStoreKey);
    final issues = store.issues;
    final showSpinner = computed(
      () => issues.loading.value && issues.items.value.isEmpty,
    );

    // Byt filter → hämta om första sidan.
    watch(() => store.showResolved.value, (_, _) => issues.refresh());
    onMounted(issues.refresh);

    return (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Felanmälan'),
            actions: [
              Row(
                children: [
                  const Text('Visa åtgärdade'),
                  Switch(
                    value: store.showResolved.value,
                    onChanged: (v) => store.showResolved.value = v,
                  ),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => context.push(CreateIssuePage.path),
            child: const Icon(Icons.add),
          ),
          body: showSpinner.value
              ? const Center(child: CircularProgressIndicator())
              : PaginatedListView(
                  itemCount: issues.items.value.length,
                  hasMore: issues.hasMore.value,
                  loadingMore: issues.loadingMore.value,
                  onLoadMore: issues.loadMore,
                  onRefresh: issues.refresh,
                  emptyText: 'Inga felanmälningar',
                  itemBuilder: (context, i) {
                    final issue = issues.items.value[i];
                    return ListTile(
                      leading: Icon(
                        issue.isResolved ? Icons.check_circle : Icons.report_problem,
                        color: issue.isResolved ? Colors.green : Colors.orange,
                      ),
                      title: Text(issue.title),
                      subtitle: Text(issue.reporterName),
                      onTap: () => context.push(IssueDetailPage.pathFor(issue.id)),
                    );
                  },
                ),
        );
  }
}
```

#### Detalj: `lib/features/issues/pages/issue_detail_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection_keys.dart';
import '../../../core/models/issue_record.dart';
import '../../../core/models/user_record.dart';
import '../../../shared/widgets/entity_action_menu.dart';
import 'create_issue_page.dart';
import 'issues_list_page.dart';

class IssueDetailPage extends CompositionWidget {
  const IssueDetailPage({super.key, required this.issueId});

  final String issueId;

  static const path = '${IssuesListPage.path}/:id';
  static String pathFor(String id) => '${IssuesListPage.path}/$id';

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final store = inject(issuesStoreKey);
    final auth = inject(authStoreKey);
    final context = useContext();

    final issue = ref<IssueRecord?>(null);

    final isOwner = computed(
      () => issue.value != null && issue.value!.reportedBy == auth.user.value?.id,
    );
    final isBoard = computed(() {
      final role = auth.user.value?.role;
      return role == UserRole.styrelse || role == UserRole.admin;
    });
    final canEdit = computed(() => isOwner.value && !(issue.value?.isResolved ?? true));
    final canDelete = computed(() => isOwner.value || auth.isAdmin.value);
    final statusLabel = computed(
      () => (issue.value?.isResolved ?? false) ? 'Åtgärdad' : 'Öppen',
    );
    final toggleLabel = computed(
      () => (issue.value?.isResolved ?? false) ? 'Öppna igen' : 'Markera som åtgärdad',
    );

    Future<void> load() async {
      issue.value = await store.fetchIssue(props.value.issueId);
    }

    onMounted(load);

    void snack(String text) {
      final ctx = context.value;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(text)));
      }
    }

    Future<void> toggleResolved() async {
      final current = issue.value;
      if (current == null) return;
      final ok = await store.setResolved(current.id, !current.isResolved);
      if (ok) {
        await load();
      } else {
        snack('Kunde inte uppdatera');
      }
    }

    Future<void> delete() async {
      final ok = await store.deleteIssue(props.value.issueId);
      final ctx = context.value;
      if (ok && ctx != null && ctx.mounted) {
        ctx.pop();
      } else if (!ok) {
        snack('Kunde inte radera');
      }
    }

    return (context) => Scaffold(
          appBar: AppBar(
            title: Text(issue.value?.title ?? 'Felanmälan'),
            actions: [
              EntityActionMenu(actions: [
                if (canEdit.value)
                  EntityAction.update(
                    () => context.push(CreateIssuePage.editPathFor(props.value.issueId)),
                  ),
                if (canDelete.value) EntityAction.delete(delete),
              ]),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Chip(label: Text(statusLabel.value)),
              const SizedBox(height: 8),
              Text(issue.value?.description ?? ''),
              const SizedBox(height: 8),
              Text('Anmäld av ${issue.value?.reporterName ?? ''}'),
              const SizedBox(height: 24),
              if (isBoard.value)
                FilledButton(onPressed: toggleResolved, child: Text(toggleLabel.value)),
            ],
          ),
        );
  }
}
```

#### Skapa och redigera: `lib/features/issues/pages/create_issue_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection_keys.dart';
import 'issues_list_page.dart';

class CreateIssuePage extends CompositionWidget {
  const CreateIssuePage({super.key, this.issueId});

  final String? issueId;

  static const path = '${IssuesListPage.path}/new';
  static const editPath = '${IssuesListPage.path}/:id/edit';
  static String editPathFor(String id) => '${IssuesListPage.path}/$id/edit';

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final store = inject(issuesStoreKey);
    final context = useContext();

    final (titleController, title, _) = useTextEditingController();
    final (descController, description, _) = useTextEditingController();
    final touched = ref(false);

    final pageTitle = computed(
      () => props.value.issueId == null ? 'Ny felanmälan' : 'Redigera felanmälan',
    );
    final titleError = computed(
      () => title.value.trim().length < 3 ? 'Beskriv felet kort (minst 3 tecken)' : null,
    );
    final descError = computed(
      () => description.value.trim().length < 10 ? 'Minst 10 tecken' : null,
    );
    final visibleTitleError = computed(() => touched.value ? titleError.value : null);
    final visibleDescError = computed(() => touched.value ? descError.value : null);
    final canSave = computed(() => !store.saving.value);

    onMounted(() async {
      final id = props.value.issueId;
      if (id == null) return;
      final existing = await store.fetchIssue(id);
      if (existing != null) {
        title.value = existing.title;
        description.value = existing.description;
      }
    });

    Future<void> save() async {
      touched.value = true;
      if (titleError.value != null || descError.value != null) return;
      final ok = await store.saveIssue(
        id: props.value.issueId,
        title: title.value.trim(),
        description: description.value.trim(),
      );
      final ctx = context.value;
      if (ctx == null || !ctx.mounted) return;
      if (ok) {
        ctx.pop();
      } else {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Kunde inte spara')),
        );
      }
    }

    return (context) => Scaffold(
          appBar: AppBar(title: Text(pageTitle.value)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Rubrik',
                  errorText: visibleTitleError.value,
                ),
              ),
              TextField(
                controller: descController,
                minLines: 3,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: 'Beskrivning',
                  errorText: visibleDescError.value,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: canSave.value ? save : null,
                child: const Text('Spara'),
              ),
            ],
          ),
        );
  }
}
```

**Kommentarer:**

- `showResolved` ligger i store:n, så filtret överlever att man går in i en anmälan och
  tillbaka. Listan hämtar om via `watch`. Det är en sidoeffekt (ett nätverksanrop),
  inte ett härlett värde.
- I `IssueDetailPage` är alla behörighetsbeslut (`canEdit`, `canDelete`, `isBoard`)
  `computed`. Builder-funktionen bara läser dem.
- `CreateIssuePage` visar fel först efter första sparförsöket (`touched`), precis som
  i övning 2.2.
- Behörigheterna i appen speglar API-reglerna. Om de skulle skilja sig åt vinner alltid
  servern.

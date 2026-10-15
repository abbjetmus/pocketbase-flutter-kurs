# Lösningar – Modul 03: Flutter Compositions

> ⚠️ **Varning:** Försök själv först! Det finns ofta flera bra lösningar. Det här är
> *förslag*. All kod nedan är analyserad med `dart analyze` mot `flutter_compositions`
> 0.1.1, och testerna går igenom.

---

## Nivå 1

### Lösning 1.1 – PostPager

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

class PostPager extends CompositionWidget {
  const PostPager({super.key, required this.titles, this.pageSize = 3});
  final List<String> titles;
  final int pageSize;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final page = ref(0);

    final pageCount = computed(
      () => (props.value.titles.length / props.value.pageSize).ceil(),
    );
    final canPrev = computed(() => page.value > 0);
    final canNext = computed(() => page.value < pageCount.value - 1);
    final visible = computed(() => props.value.titles
        .skip(page.value * props.value.pageSize)
        .take(props.value.pageSize)
        .toList());
    final label = computed(() => 'Sida ${page.value + 1} av ${pageCount.value}');

    void prev() => page.value--;
    void next() => page.value++;
    void first() => page.value = 0;

    return (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in visible.value) ListTile(title: Text(t)),
            Text(label.value),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: canPrev.value ? prev : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  onPressed: canNext.value ? next : null,
                  icon: const Icon(Icons.chevron_right),
                ),
                TextButton(onPressed: first, child: const Text('Till början')),
              ],
            ),
          ],
        );
  }
}
```

**Kommentarer:**

- `page` är det enda egentliga state:t. Allt annat (`pageCount`, `canPrev`, `canNext`,
  `visible`, `label`) är härlett och därför `computed`.
- `pageCount` och `visible` läser `props.value.titles` och `props.value.pageSize`.
  Skickar föräldern en ny lista uppdateras sidan automatiskt, vilket originalet bara
  klarade för att `build()` kördes om.
- Ingen `State`-klass, inget `setState` och inga beräkningar i builder.

### Lösning 1.2 – Hashtaggar

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

class HashtagEditor extends CompositionWidget {
  const HashtagEditor({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final (inputController, input, _) = useTextEditingController();
    final tags = ref(<String>[]);

    // "flutter" → "#flutter", " #Dart " → "#dart"
    final normalized = computed(() {
      final t = input.value.trim().toLowerCase().replaceAll(' ', '');
      if (t.isEmpty) return '';
      return t.startsWith('#') ? t : '#$t';
    });
    final canAdd = computed(
      () => normalized.value.length > 1 && !tags.value.contains(normalized.value),
    );
    final sorted = computed(() => [...tags.value]..sort());
    final countLabel = computed(() => '${tags.value.length} taggar');

    void add() {
      tags.value = [...tags.value, normalized.value];
      input.value = ''; // tvåvägsbindning: tömmer fältet
    }

    void remove(String tag) {
      tags.value = tags.value.where((t) => t != tag).toList();
    }

    void removeFirst() {
      if (tags.value.isEmpty) return;
      tags.value = tags.value.sublist(1);
    }

    return (context) => Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: inputController,
                    decoration: const InputDecoration(hintText: 'Ny tagg, t.ex. #dart'),
                    onSubmitted: (_) => canAdd.value ? add() : null,
                  ),
                ),
                IconButton(
                  onPressed: canAdd.value ? add : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            Text(countLabel.value),
            TextButton(onPressed: removeFirst, child: const Text('Ta bort första')),
            for (final tag in sorted.value)
              ListTile(
                title: Text(tag),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => remove(tag),
                ),
              ),
          ],
        );
  }
}
```

**Kommentarer:**

- `normalized` är en `computed` av textfältet, så "+"-knappen (`canAdd`) vet redan när
  användaren skriver om taggen finns.
- `[...tags.value]..sort()` sorterar en **kopia**. `tags.value..sort()` hade muterat
  originalet, och eftersom det är samma lista-instans hade ingen uppdatering triggats.
- `input.value = ''` tömmer textfältet tack vare tvåvägsbindningen.
- `sublist(1)` skapar en ny lista. `removeAt(0)` hade muterat den gamla.

### Lösning 1.3 – Hitta felen

| # | Fel | Varför | Rättning |
|---|-----|--------|----------|
| 1 | `int clicks = 0;`, ett föränderligt fält i widgeten | Inte reaktivt, och widgets ska vara immutabla (`no_mutable_fields`) | Lägg state i en `ref` i `setup()` |
| 2 | Konstruktorn är inte `const` | Följer av fel 1. Med bara `final`-fält kan den vara `const` | `const ProfileGreeting(...)` |
| 3 | `'Hej $name!'` läser prop direkt | Bara startvärdet fångas (`ensure_reactive_props`) | `props.value.name` via `widget()` |
| 4 | `if (name.isEmpty) { watchEffect(...) }` | Villkorligt composition-anrop (`no_conditional_composition`) | Anropa alltid och lägg villkoret *inuti* effekten, eller ta bort den |
| 5 | `Theme.of(context)` i builder | Uppdateras inte reaktivt när temat byts | `useTheme()` + `computed` |
| 6 | `Text('$message')` | Glömt `.value`, skriver ut `Instance of …` | `message.value` |
| 7 | `interests.value.add('Flutter')` | Mutation, ingen uppdatering (grund reaktivitet) | `interests.value = [...interests.value, 'Flutter']` |
| 8 | `clicks++` | Varken reaktivt eller tillåtet (fel 1) | `views.value++` |

Rättad version:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

class ProfileGreeting extends CompositionWidget {
  const ProfileGreeting({super.key, required this.name});
  final String name;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final theme = useTheme();
    final views = ref(0);
    final interests = ref(<String>[]);
    final message = computed(
      () => 'Hej ${props.value.name}! Profilvisningar: ${views.value}',
    );
    final style = computed(() => theme.value.textTheme.titleLarge);

    onMounted(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      views.value = 1;
    });

    return (context) => Column(
          children: [
            Text(message.value, style: style.value),
            Text(interests.value.join(', ')),
            TextButton(
              onPressed: () => interests.value = [...interests.value, 'Flutter'],
              child: const Text('Lägg till intresse'),
            ),
            TextButton(
              onPressed: () => views.value++,
              child: const Text('+1'),
            ),
          ],
        );
  }
}
```

---

## Nivå 2

### Lösning 2.1 – Flöde med filter och sök

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

enum FeedFilter { all, following, mine }

class Post {
  const Post({
    required this.id,
    required this.author,
    required this.title,
    this.liked = false,
  });
  final int id;
  final String author;
  final String title;
  final bool liked;

  Post copyWith({bool? liked}) =>
      Post(id: id, author: author, title: title, liked: liked ?? this.liked);
}

const me = 'anna';
const following = {'bo', 'cecilia'};

class FeedScreen extends CompositionWidget {
  const FeedScreen({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final posts = ref(const <Post>[
      Post(id: 1, author: 'anna', title: 'Hej Kvittra!'),
      Post(id: 2, author: 'bo', title: 'Flutter är kul'),
      Post(id: 3, author: 'cecilia', title: 'Tips om Dart'),
      Post(id: 4, author: 'david', title: 'Min första app'),
      Post(id: 5, author: 'anna', title: 'Vem kan PocketBase?'),
      Post(id: 6, author: 'bo', title: 'Fredagsfika'),
    ]);
    final filter = ref(FeedFilter.all);
    final (searchController, search, _) = useTextEditingController();

    final filtered = computed(() => switch (filter.value) {
          FeedFilter.all => posts.value,
          FeedFilter.following =>
            posts.value.where((p) => following.contains(p.author)).toList(),
          FeedFilter.mine => posts.value.where((p) => p.author == me).toList(),
        });
    final visible = computed(() {
      final q = search.value.trim().toLowerCase();
      if (q.isEmpty) return filtered.value;
      return filtered.value
          .where((p) => p.title.toLowerCase().contains(q))
          .toList();
    });
    final likedCount = computed(() => posts.value.where((p) => p.liked).length);
    final summary = computed(() =>
        '${visible.value.length} av ${posts.value.length} inlägg · '
        '${likedCount.value} gillade');
    final hasLiked = computed(() => likedCount.value > 0);

    void toggleLike(Post post) {
      posts.value = [
        for (final p in posts.value)
          p.id == post.id ? p.copyWith(liked: !p.liked) : p,
      ];
    }

    void unlikeAll() {
      posts.value = [for (final p in posts.value) p.copyWith(liked: false)];
    }

    return (context) => Scaffold(
          appBar: AppBar(title: Text(summary.value)),
          body: Column(
            children: [
              TextField(
                controller: searchController,
                decoration: const InputDecoration(hintText: 'Sök…'),
              ),
              SegmentedButton<FeedFilter>(
                segments: const [
                  ButtonSegment(value: FeedFilter.all, label: Text('Alla')),
                  ButtonSegment(value: FeedFilter.following, label: Text('Följer')),
                  ButtonSegment(value: FeedFilter.mine, label: Text('Mina')),
                ],
                selected: {filter.value},
                onSelectionChanged: (s) => filter.value = s.first,
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final p in visible.value)
                      ListTile(
                        title: Text(p.title),
                        subtitle: Text('@${p.author}'),
                        trailing: IconButton(
                          onPressed: () => toggleLike(p),
                          icon: Icon(
                            p.liked ? Icons.favorite : Icons.favorite_border,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              TextButton(
                onPressed: hasLiked.value ? unlikeAll : null,
                child: const Text('Sluta gilla alla'),
              ),
            ],
          ),
        );
  }
}
```

**Kommentarer:**

- `filtered` använder en `switch`-expression över enumen. Lägger du till ett nytt
  filter tvingar kompilatorn dig att hantera det.
- `visible` bygger på `filtered`. Skriver användaren i sökfältet räknas bara `visible`
  (och `summary`) om. `filtered` tas från cachen.
- `toggleLike` bygger en ny lista med `copyWith` för det inlägg som ändras. Övriga
  element återanvänds.
- `me` och `following` är konstanter. De ändras aldrig, så de behöver inte vara
  reaktiva. (I kapitel 10 kommer de från servern.)

### Lösning 2.2 – Registreringsformulär

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

class RegisterForm extends CompositionWidget {
  const RegisterForm({super.key, required this.onSubmit});
  final void Function(String name, String email, String username, String password)
      onSubmit;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final (nameController, name, _) = useTextEditingController();
    final (emailController, email, _) = useTextEditingController();
    final (usernameController, username, _) = useTextEditingController();
    final (pwController, password, _) = useTextEditingController();
    final (pw2Controller, password2, _) = useTextEditingController();
    final touched = ref(false);

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    final usernameRegex = RegExp(r'^[a-z0-9_]{3,20}$');

    final nameError = computed(
      () => name.value.trim().length < 2 ? 'Ange ditt namn' : null,
    );
    final emailError = computed(
      () => emailRegex.hasMatch(email.value.trim()) ? null : 'Ogiltig e-postadress',
    );
    final usernameError = computed(
      () => usernameRegex.hasMatch(username.value)
          ? null
          : '3–20 tecken: a–z, 0–9 och _',
    );
    final passwordError = computed(
      () => password.value.length < 8 ? 'Minst 8 tecken' : null,
    );
    final password2Error = computed(
      () => password2.value != password.value ? 'Lösenorden matchar inte' : null,
    );

    final isValid = computed(() => [
          nameError.value,
          emailError.value,
          usernameError.value,
          passwordError.value,
          password2Error.value,
        ].every((e) => e == null));

    String? show(ReadonlyRef<String?> error) => touched.value ? error.value : null;

    void submit() {
      touched.value = true;
      if (!isValid.value) return;
      props.value.onSubmit(
        name.value.trim(),
        email.value.trim(),
        username.value,
        password.value,
      );
    }

    return (context) => Column(
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'Namn', errorText: show(nameError)),
            ),
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: 'E-post', errorText: show(emailError)),
            ),
            TextField(
              controller: usernameController,
              decoration: InputDecoration(
                labelText: 'Användarnamn',
                prefixText: '@',
                errorText: show(usernameError),
              ),
            ),
            TextField(
              controller: pwController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Lösenord',
                errorText: show(passwordError),
              ),
            ),
            TextField(
              controller: pw2Controller,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Bekräfta lösenord',
                errorText: show(password2Error),
              ),
            ),
            FilledButton(onPressed: submit, child: const Text('Skapa konto')),
          ],
        );
  }
}

(TextEditingController, WritableRef<String>, ReadonlyRef<String?>) useValidatedField(
  String? Function(String value) validator,
) {
  final (controller, text, _) = useTextEditingController();
  final error = computed(() => validator(text.value));
  return (controller, text, error);
}
```

**Kommentarer:**

- Varje fel är en egen `computed`, och de räknas bara om när sitt eget fält ändras.
  `password2Error` beror på **både** `password` och `password2`, så ändrar du det första
  lösenordet uppdateras felet för bekräftelsen automatiskt.
- `show(...)` är en liten hjälpfunktion som läser `touched.value` och felet. Den anropas
  i builder-funktionen, så båda blir beroenden.
- `props.value.onSubmit(...)` motsvarar `emit('submit', ...)` i Vue.
- Användarnamnets regex motsvarar det som ett unikt `username`-fält i PocketBase
  brukar tillåta. Servern har ändå sista ordet (t.ex. om namnet redan är taget).

**Bonus – `useValidatedField`** (längst ner i filen ovan). Användning i `setup()`:

```dart
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

class QuietModeTimer extends CompositionWidget {
  const QuietModeTimer({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final countdown = useCountdown(const Duration(minutes: 30));
    final label = computed(() {
      final r = countdown.remaining.value;
      final m = r.inMinutes.toString().padLeft(2, '0');
      final s = (r.inSeconds % 60).toString().padLeft(2, '0');
      return countdown.isFinished.value ? 'Tyst läge är slut' : 'Tyst läge i $m:$s';
    });
    final buttonLabel = computed(() => countdown.isRunning.value ? 'Pausa' : 'Starta');

    watch(() => countdown.isFinished.value, (finished, _) {
      if (finished) debugPrint('Notiser är på igen');
    });

    return (context) => Column(
          children: [
            Text(label.value, style: const TextStyle(fontSize: 32)),
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
  const FakeUser({required this.name, required this.username});
  final String name;
  final String username;
}

class SessionService {
  final Ref<FakeUser?> _user = ref<FakeUser?>(null);
  ReadonlyRef<FakeUser?> get user => _user;
  late final ReadonlyRef<bool> isLoggedIn = computed(() => _user.value != null);

  Future<void> login(String name) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _user.value = FakeUser(
      name: name,
      username: name.toLowerCase().replaceAll(' ', '_'),
    );
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
          theme: ThemeData(colorSchemeSeed: Colors.indigo),
          darkTheme: ThemeData(
            colorSchemeSeed: Colors.indigo,
            brightness: Brightness.dark,
          ),
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
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Namn'),
                ),
                FilledButton(
                  onPressed: canLogin.value ? login : null,
                  child: const Text('Logga in'),
                ),
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
        body: const Center(child: Text('Välkommen till Kvittra')),
      );
}

class ProfileHeader extends CompositionWidget {
  const ProfileHeader({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final session = inject(sessionKey);
    final title = computed(() {
      final u = session.user.value;
      return u == null ? '' : '${u.name} (@${u.username})';
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

    expect(find.text('Anna (@anna)'), findsOneWidget);
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

### Lösning 3.2 – Inlägg med refresh och realtime

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';

const pocketBaseKey = InjectionKey<PocketBase>('pocketBase');

class Post {
  const Post({
    required this.id,
    required this.title,
    required this.body,
    required this.authorName,
  });
  final String id;
  final String title;
  final String body;
  final String authorName;

  factory Post.fromRecord(RecordModel r) {
    final author = r.toJson()['expand']?['author'] as Map<String, dynamic>?;
    return Post(
      id: r.id,
      title: r.getStringValue('title'),
      body: r.getStringValue('body'),
      authorName: author?['name'] as String? ?? 'Okänd',
    );
  }
}

class PostsPage extends CompositionWidget {
  const PostsPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final pb = inject(pocketBaseKey);
    final oldestFirst = ref(false);

    final (status, refresh) = useAsyncData<List<Post>, bool>(
      (oldest) async {
        final records = await pb.collection('posts').getFullList(
              sort: oldest ? 'created' : '-created',
              expand: 'author',
            );
        return records.map(Post.fromRecord).toList();
      },
      watch: () => oldestFirst.value,
    );

    final title = computed(() => switch (status.value) {
          AsyncData(:final value) => 'Inlägg (${value.length})',
          _ => 'Inlägg',
        });

    UnsubscribeFunc? unsubscribe;
    var disposed = false;
    onMounted(() async {
      final unsub = await pb.collection('posts').subscribe('*', (_) => refresh());
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
              const Text('Äldst först'),
              Switch(
                value: oldestFirst.value,
                onChanged: (v) => oldestFirst.value = v,
              ),
            ],
          ),
          body: switch (status.value) {
            AsyncIdle() || AsyncLoading() =>
              const Center(child: CircularProgressIndicator()),
            AsyncError(:final errorValue) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Kunde inte hämta inlägg:\n$errorValue',
                      textAlign: TextAlign.center,
                    ),
                    FilledButton(onPressed: refresh, child: const Text('Försök igen')),
                  ],
                ),
              ),
            AsyncData(:final value) => RefreshIndicator(
                onRefresh: () async => refresh(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (value.isEmpty) const ListTile(title: Text('Inga inlägg ännu')),
                    for (final p in value)
                      ListTile(
                        title: Text(p.title),
                        subtitle: Text(
                          '${p.authorName} · ${p.body}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
          },
        );
  }
}

class App extends CompositionWidget {
  const App({super.key});

  @override
  Widget Function(BuildContext) setup() {
    provide(pocketBaseKey, PocketBase('http://127.0.0.1:8090'));
    return (context) => const MaterialApp(home: PostsPage());
  }
}
```

I `main.dart`: `runApp(const App());`

**Kommentarer:**

- `watch: () => oldestFirst.value` gör att `useAsyncData` hämtar om när switchen
  ändras. Värdet skickas som argument (`oldest`) till hämtfunktionen.
- `authorName` läses ur `expand.author`. Utan `expand: 'author'` i anropet blir det
  "Okänd".
- `title` använder en `switch` på `status.value` i en `computed`, inte i builder.
- `physics: AlwaysScrollableScrollPhysics()` gör att pull-to-refresh fungerar även när
  listan är kort.
- Realtime-prenumerationen följer mönstret från kapitel 8: `onMounted` +
  `onUnmounted` registrerade i `setup()`, plus en `disposed`-flagga för fallet där
  widgeten försvinner innan `subscribe` hunnit bli klar.
- Kom ihåg att API-regeln för `posts` (List/View) måste tillåta användaren att se
  posterna, annars kommer varken data eller händelser
  ([01 – Inloggning och API-regler](../01-databaser-och-pocketbase/08-inloggning-och-api-regler.md)). Kräver
  reglerna inloggning loggar du in först, t.ex. med
  `pb.collection('users').authWithPassword('anna@example.com', '…')` i `App`.

### Lösning 3.4 – Notiser

Lösningen följer checklistan i kapitel 10. Dart-koden är analyserad med `dart analyze`,
reglerna och hookarna är provkörda med `curl`, och store:n är provkörd mot en riktig
PocketBase (Bo gillar Annas inlägg → Annas `unreadCount` blir 1 via realtime).

#### Backend

`pb_migrations/1700000400_notifications.js`:

```js
/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const users = app.findCollectionByNameOrId("users")
  const posts = app.findCollectionByNameOrId("posts")

  const notifications = new Collection({
    type: "base",
    name: "notifications",
    fields: [
      // Mottagaren
      { name: "user", type: "relation", collectionId: users.id, maxSelect: 1, required: true, cascadeDelete: true },
      // Den som gjorde något
      { name: "actor", type: "relation", collectionId: users.id, maxSelect: 1, required: true, cascadeDelete: true },
      { name: "type", type: "select", values: ["like", "comment", "follow"], maxSelect: 1, required: true },
      // Inlägget det gäller (saknas för "follow")
      { name: "post", type: "relation", collectionId: posts.id, maxSelect: 1, cascadeDelete: true },
      { name: "read", type: "bool" },
      { name: "created", type: "autodate", onCreate: true },
    ],
    indexes: ["CREATE INDEX idx_notifications_user_read ON notifications (user, read)"],
    // Bara mottagaren ser och hanterar sina notiser.
    listRule: 'user = @request.auth.id',
    viewRule: 'user = @request.auth.id',
    // null = bara superuser. Notiser skapas av hooks på servern, aldrig av appen.
    createRule: null,
    // Mottagaren får bara ändra "read".
    updateRule:
      'user = @request.auth.id && @request.body.user:changed = false && ' +
      '@request.body.actor:changed = false && @request.body.type:changed = false && ' +
      '@request.body.post:changed = false',
    deleteRule: 'user = @request.auth.id',
  })
  app.save(notifications)
}, (app) => {
  app.delete(app.findCollectionByNameOrId("notifications"))
})
```

`pb_hooks/notify.js` (delad kod, hämtas med `require` inuti varje hook):

```js
module.exports = {
  /** Skapar en notis, utom när man gör något mot sig själv. */
  notify: (app, { user, actor, type, post }) => {
    if (!user || user === actor) return
    const n = new Record(app.findCollectionByNameOrId("notifications"))
    n.set("user", user)
    n.set("actor", actor)
    n.set("type", type)
    if (post) n.set("post", post)
    n.set("read", false)
    app.save(n) // app.save går förbi API-reglerna (createRule = null)
  },
}
```

`pb_hooks/notifications.pb.js`:

```js
/// <reference path="../pb_data/types.d.ts" />

// Någon gillade ett inlägg → notis till inläggets författare.
onRecordAfterCreateSuccess((e) => {
  const post = e.app.findRecordById("posts", e.record.getString("post"))
  require(`${__hooks}/notify.js`).notify(e.app, {
    user: post.getString("author"),
    actor: e.record.getString("user"),
    type: "like",
    post: post.id,
  })
  e.next()
}, "likes")

// Någon kommenterade → notis till inläggets författare.
onRecordAfterCreateSuccess((e) => {
  const post = e.app.findRecordById("posts", e.record.getString("post"))
  require(`${__hooks}/notify.js`).notify(e.app, {
    user: post.getString("author"),
    actor: e.record.getString("author"),
    type: "comment",
    post: post.id,
  })
  e.next()
}, "comments")

// Någon började följa → notis till den som blev följd.
onRecordAfterCreateSuccess((e) => {
  require(`${__hooks}/notify.js`).notify(e.app, {
    user: e.record.getString("following"),
    actor: e.record.getString("follower"),
    type: "follow",
  })
  e.next()
}, "follows")
```

Provkört:

| Försök | Resultat |
|--------|----------|
| Bo gillar och kommenterar Annas inlägg, Cecilia följer Anna | Anna får tre notiser (`like`, `comment`, `follow`) |
| Anna gillar sitt eget inlägg | Ingen notis |
| Anna listar olästa (`perPage=1&filter=read = false`) | `totalItems: 3` |
| Bo listar notiser | 0 träffar (bara mottagaren ser sina) |
| Bo skapar en notis till Anna | `403` (`createRule: null`) |
| Anna sätter `read: true` | OK |
| Anna ändrar `type` på sin notis | `404` (update-regeln) |
| Bo markerar Annas notis som oläst | `404` |

> 💡 **Tips:** `createRule: null` betyder "bara superuser". Hookarna använder
> `app.save(...)`, som går förbi API-reglerna. Därför kan servern skapa notiser men
> ingen klient.

#### Modell: `lib/core/models/notification_record.dart`

```dart
enum NotificationType { like, comment, follow }

class NotificationRecord {
  const NotificationRecord({
    required this.id,
    required this.type,
    required this.actor,
    required this.actorName,
    required this.post,
    required this.postTitle,
    required this.read,
    required this.created,
  });

  final String id;
  final NotificationType type;
  final String actor; // relation-id → users
  final String actorName; // från expand.actor
  final String post; // relation-id → posts, '' för "follow"
  final String postTitle; // från expand.post
  final bool read;
  final DateTime? created;

  /// "Bo gillade ditt inlägg" osv.
  String get text => switch (type) {
        NotificationType.like => '$actorName gillade ditt inlägg',
        NotificationType.comment => '$actorName kommenterade ditt inlägg',
        NotificationType.follow => '$actorName började följa dig',
      };

  NotificationRecord copyWith({bool? read}) => NotificationRecord(
        id: id,
        type: type,
        actor: actor,
        actorName: actorName,
        post: post,
        postTitle: postTitle,
        read: read ?? this.read,
        created: created,
      );

  factory NotificationRecord.fromJson(Map<String, dynamic> json) {
    final expand = json['expand'] as Map<String, dynamic>? ?? const {};
    final actor = expand['actor'] as Map<String, dynamic>?;
    final post = expand['post'] as Map<String, dynamic>?;
    return NotificationRecord(
      id: json['id'] as String,
      type: NotificationType.values.asNameMap()[json['type']] ??
          NotificationType.like,
      actor: json['actor'] as String? ?? '',
      actorName: actor?['name'] as String? ?? 'Någon',
      post: json['post'] as String? ?? '',
      postTitle: post?['title'] as String? ?? '',
      read: json['read'] as bool? ?? false,
      created: DateTime.tryParse(json['created'] as String? ?? '')?.toLocal(),
    );
  }
}
```

Lägg också till `static const notifications = 'notifications';` i `Collections`.

#### Store: `lib/features/notifications/notifications_store.dart`

Store:n använder en ny metod i `Paginated<T>` från kapitel 10, `updateWhere`, för att
byta ut ett element lokalt:

```dart
/// Byt ut element lokalt (t.ex. efter en uppdatering) utan att hämta om.
void updateWhere(bool Function(T item) test, T Function(T item) update) {
  _items.value = [for (final i in _items.value) test(i) ? update(i) : i];
}
```

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/models/collections.dart';
import '../../core/models/notification_record.dart';
import '../../core/pagination/paginated.dart';

class NotificationsStore {
  NotificationsStore(this._pb);

  final PocketBase _pb;

  RecordService get _col => _pb.collection(Collections.notifications);

  /// Mina notiser, nyast först. listRule ser till att jag bara får mina.
  late final notifications = Paginated<NotificationRecord>((
    page,
    perPage,
  ) async {
    final res = await _col.getList(
      page: page,
      perPage: perPage,
      sort: '-created',
      expand: 'actor,post',
    );
    return PageResult(
      res.items.map((r) => NotificationRecord.fromJson(r.toJson())).toList(),
      res.totalPages,
    );
  });

  final _unread = ref(0);
  ReadonlyRef<int> get unreadCount => _unread;
  late final ReadonlyRef<String> badgeLabel = computed(
    () => _unread.value > 9 ? '9+' : '${_unread.value}',
  );

  @visibleForTesting
  void debugSetUnread(int n) => _unread.value = n;

  Future<void> refreshUnreadCount() async {
    try {
      final res = await _col.getList(perPage: 1, filter: 'read = false');
      _unread.value = res.totalItems;
    } catch (e) {
      debugPrint('NotificationsStore.refreshUnreadCount: $e');
    }
  }

  // ---- Realtime, styrs av MyApp vid in-/utloggning ------------------------

  UnsubscribeFunc? _unsubscribe;
  int _session = 0; // ökas vid varje start/stop, skyddar mot race-fall

  Future<void> start() async {
    await stop();
    final session = _session;
    await refreshUnreadCount();
    try {
      final unsub = await _col.subscribe('*', (e) {
        if (session != _session) return; // gammal prenumeration
        if (e.action == 'create') {
          _unread.value++;
          notifications.refresh();
        } else {
          refreshUnreadCount();
        }
      });
      if (session != _session) {
        await unsub(); // stop() hann anropas medan vi prenumererade
      } else {
        _unsubscribe = unsub;
      }
    } catch (e) {
      debugPrint('NotificationsStore.start: $e');
    }
  }

  Future<void> stop() async {
    _session++;
    _unread.value = 0;
    final unsub = _unsubscribe;
    _unsubscribe = null;
    if (unsub != null) await unsub();
  }

  // ---- Mutationer -----------------------------------------------------------

  /// Optimistisk: listan och räknaren uppdateras direkt, och ångras vid fel.
  Future<bool> markAsRead(NotificationRecord n) async {
    if (n.read) return true;
    notifications.updateWhere(
      (x) => x.id == n.id,
      (x) => x.copyWith(read: true),
    );
    _unread.value = _unread.value > 0 ? _unread.value - 1 : 0;
    try {
      await _col.update(n.id, body: {'read': true});
      return true;
    } on ClientException catch (e) {
      debugPrint('NotificationsStore.markAsRead: ${e.response}');
      notifications.updateWhere(
        (x) => x.id == n.id,
        (x) => x.copyWith(read: false),
      );
      _unread.value++;
      return false;
    }
  }

  Future<bool> markAllAsRead() async {
    try {
      final unread = await _col.getFullList(filter: 'read = false');
      await Future.wait([
        for (final r in unread) _col.update(r.id, body: {'read': true}),
      ]);
      await Future.wait([notifications.refresh(), refreshUnreadCount()]);
      return true;
    } on ClientException catch (e) {
      debugPrint('NotificationsStore.markAllAsRead: ${e.response}');
      return false;
    }
  }
}
```

#### Koppla in: DI, `MyApp`, router och flödet

```dart
// lib/core/di/injection_keys.dart
import '../../features/notifications/notifications_store.dart';
const notificationsStoreKey =
    InjectionKey<NotificationsStore>('notificationsStore');

// lib/main.dart, i MyApp.setup()
final notificationsStore = NotificationsStore(pb);
provide(notificationsStoreKey, notificationsStore);

// ... och i den befintliga watch:en på användarens id:
watch(() => authStore.user.value?.id, (userId, _) {
  if (userId == null) {
    groupsStore.clear();
    notificationsStore.stop();
  } else {
    groupsStore.loadMyRoles();
    notificationsStore.start();
  }
}, immediate: true);

// lib/core/router/router.dart
GoRoute(
  path: NotificationsPage.path,
  builder: (_, _) => const NotificationsPage(),
),

// lib/features/feed/pages/posts_feed_page.dart, först i AppBar:ens actions
const NotificationsBell(),
```

#### Sida: `lib/features/notifications/pages/notifications_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection_keys.dart';
import '../../../core/models/notification_record.dart';
import '../../../core/utils/time_ago.dart';
import '../../../shared/widgets/paginated_list_view.dart';
import '../../posts/pages/post_detail_page.dart';
import '../../profile/pages/profile_page.dart';

class NotificationsPage extends CompositionWidget {
  const NotificationsPage({super.key});

  static const path = '/notifications';

  @override
  Widget Function(BuildContext) setup() {
    final store = inject(notificationsStoreKey);
    final list = store.notifications;
    final context = useContext();

    final showSpinner = computed(
      () => list.loading.value && list.items.value.isEmpty,
    );
    final hasUnread = computed(() => store.unreadCount.value > 0);
    final title = computed(
      () => hasUnread.value
          ? 'Notiser (${store.unreadCount.value} olästa)'
          : 'Notiser',
    );

    onMounted(list.refresh);

    Future<void> open(NotificationRecord n) async {
      final ok = await store.markAsRead(n);
      final ctx = context.value;
      if (ctx == null || !ctx.mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Kunde inte markera som läst')),
        );
      }
      // Följ-notiser leder till profilen, övriga till inlägget.
      ctx.push(
        n.type == NotificationType.follow
            ? ProfilePage.pathFor(n.actor)
            : PostDetailPage.pathFor(n.post),
      );
    }

    IconData iconFor(NotificationType type) => switch (type) {
          NotificationType.like => Icons.favorite,
          NotificationType.comment => Icons.chat_bubble,
          NotificationType.follow => Icons.person_add,
        };

    return (context) => Scaffold(
          appBar: AppBar(
            title: Text(title.value),
            actions: [
              IconButton(
                tooltip: 'Markera alla som lästa',
                icon: const Icon(Icons.done_all),
                onPressed: hasUnread.value ? store.markAllAsRead : null,
              ),
            ],
          ),
          body: showSpinner.value
              ? const Center(child: CircularProgressIndicator())
              : PaginatedListView(
                  itemCount: list.items.value.length,
                  hasMore: list.hasMore.value,
                  loadingMore: list.loadingMore.value,
                  onLoadMore: list.loadMore,
                  onRefresh: list.refresh,
                  emptyText: 'Inga notiser ännu',
                  itemBuilder: (context, i) {
                    final n = list.items.value[i];
                    return ListTile(
                      leading: Icon(iconFor(n.type)),
                      title: Text(
                        n.text,
                        style: TextStyle(
                          fontWeight:
                              n.read ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        n.postTitle.isEmpty
                            ? timeAgo(n.created)
                            : '${n.postTitle} · ${timeAgo(n.created)}',
                      ),
                      trailing: n.read
                          ? null
                          : const Icon(Icons.circle,
                              size: 10, color: Colors.blue),
                      onTap: () => open(n),
                    );
                  },
                ),
        );
  }
}
```

#### Klockan: `lib/features/notifications/widgets/notifications_bell.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection_keys.dart';
import '../pages/notifications_page.dart';

/// Klocka med antal olästa. Läggs i AppBar:ens actions.
class NotificationsBell extends CompositionWidget {
  const NotificationsBell({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final store = inject(notificationsStoreKey);
    final hasUnread = computed(() => store.unreadCount.value > 0);

    return (context) => IconButton(
          tooltip: 'Notiser',
          onPressed: () => context.push(NotificationsPage.path),
          icon: Badge(
            isLabelVisible: hasUnread.value,
            label: Text(store.badgeLabel.value),
            child: const Icon(Icons.notifications),
          ),
        );
  }
}
```

#### Test: `test/notifications_bell_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:kvittra/core/di/injection_keys.dart';
import 'package:kvittra/features/notifications/notifications_store.dart';
import 'package:kvittra/features/notifications/widgets/notifications_bell.dart';

void main() {
  testWidgets('klockan visar antal olästa', (tester) async {
    final store = NotificationsStore(PocketBase('http://127.0.0.1:8090'));

    await tester.pumpWidget(CompositionBuilder(setup: () {
      provide(notificationsStoreKey, store);
      return (context) => MaterialApp(
            home: Scaffold(appBar: AppBar(actions: const [NotificationsBell()])),
          );
    }));

    // 0 olästa: ingen siffra syns.
    expect(find.text('0'), findsNothing);

    store.debugSetUnread(3);
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);

    store.debugSetUnread(12);
    await tester.pumpAndSettle();
    expect(find.text('9+'), findsOneWidget);
  });
}
```

**Kommentarer:**

- Notiser skapas **bara på servern**. Appen kan inte fuska fram en notis, och
  logiken "ingen notis till sig själv" finns på ett enda ställe.
- Realtime startas och stoppas av `MyApp`, inte av en sida, eftersom klockan ska
  uppdateras var man än är i appen. `_session` skyddar mot att en gammal prenumeration
  (från förra inloggningen) blir kvar, på samma sätt som `_activePostId` i
  `CommentsStore`.
- `markAsRead` är optimistisk: fetstilen försvinner och siffran minskar direkt, och
  allt rullas tillbaka om servern säger nej.
- `badgeLabel` och `hasUnread` är `computed`, så klockan byggs bara om när siffran
  faktiskt ändras.
- Testet använder `pumpAndSettle()` efter att ha ändrat en ref direkt (se
  [kapitel 9](09-best-practices-och-lints.md#testa)).

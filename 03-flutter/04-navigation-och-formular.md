# 04 – Navigation och formulär

En riktig app har flera skärmar: ett flöde, en detaljsida för ett inlägg, en
profilsida och ett formulär för nya inlägg. I det här kapitlet lär du dig att
navigera mellan dem, skicka data fram och tillbaka och bygga formulär med
validering.

## Navigator: en stack av skärmar

Flutters inbyggda `Navigator` fungerar som en **stack** (en hög med tallrikar):

- `push` lägger en ny skärm överst,
- `pop` tar bort den översta och visar den under.

```
push(Inlägg)        push(Profil)          pop()
┌──────────┐        ┌──────────┐          ┌──────────┐
│          │        │ Profil   │          │          │
│          │        │ Inlägg   │          │ Inlägg   │
│ Flöde    │ ──►    │ Flöde    │   ──►    │ Flöde    │
└──────────┘        └──────────┘          └──────────┘
```

```dart
// Gå till en ny skärm
Navigator.of(context).push(
  MaterialPageRoute(builder: (context) => const PostDetailScreen()),
);

// Gå tillbaka (samma som tillbakapilen i AppBar)
Navigator.of(context).pop();
```

`Scaffold` med en `AppBar` lägger automatiskt till en tillbakapil när det finns en
skärm att gå tillbaka till. På Android fungerar även systemets bakåtknapp/gest.

### Skicka data till en skärm

Data skickas helt enkelt via **konstruktorn**:

```dart
class PostDetailScreen extends StatelessWidget {
  const PostDetailScreen({super.key, required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(post.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(post.body),
      ),
    );
  }
}

// I flödet:
PostCard(
  post: post,
  onComment: () => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => PostDetailScreen(post: post),
    ),
  ),
)
```

### Få tillbaka ett resultat

`push` returnerar en `Future` som blir klar när skärmen poppas. Värdet du skickar
till `pop` blir resultatet. Perfekt för "skriv nytt inlägg":

```dart
// Skärm A (flödet): öppna formuläret och vänta på svar
Future<void> _openNewPost() async {
  final draft = await Navigator.of(context).push<PostDraft>(
    MaterialPageRoute(builder: (context) => const NewPostScreen()),
  );
  if (!mounted) return;
  if (draft != null) {
    setState(() => _drafts.insert(0, draft)); // nytt inlägg överst
  }
}

// Skärm B (formuläret): stäng och skicka tillbaka utkastet
Navigator.of(context).pop(draft);
```

Resultatet är alltid nullbart (`PostDraft?`), eftersom användaren kan trycka på
tillbaka utan att publicera.

## go_router: navigation med URL:er

`Navigator.push` räcker långt i små appar. Men när appen växer vill man ofta ha:

- **namngivna sökvägar** (`/posts/42`, `/users/3`) i stället för konstruktoranrop
  överallt,
- **djuplänkar**: en länk i ett mejl eller en push-notis ("Bo kommenterade ditt
  inlägg") öppnar rätt skärm direkt,
- riktiga URL:er när appen körs på webben,
- en samlad plats där alla skärmar definieras.

Paketet [`go_router`](https://pub.dev/packages/go_router) från Flutter-teamet är
standardvalet.

```bash
flutter pub add go_router
```

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const FeedScreen(),
      routes: [
        // /posts/new – måste stå FÖRE posts/:id, annars tolkas "new" som ett id
        GoRoute(
          path: 'posts/new',
          builder: (context, state) => const NewPostScreen(),
        ),
        // /posts/:id
        GoRoute(
          path: 'posts/:id',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '');
            if (id == null) return const NotFoundScreen();
            return PostDetailScreen(postId: id);
          },
        ),
        // /users/:id
        GoRoute(
          path: 'users/:id',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '');
            if (id == null) return const NotFoundScreen();
            return ProfileScreen(userId: id);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/search',
      builder: (context, state) {
        // Query-parameter: /search?q=fika
        final query = state.uri.queryParameters['q'] ?? '';
        return SearchScreen(initialQuery: query);
      },
    ),
  ],
);

void main() {
  runApp(MaterialApp.router(
    routerConfig: router,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo)),
  ));
}
```

Lägg märke till:

- `MaterialApp.router` i stället för `MaterialApp(home: ...)`.
- Path-parametrar (`:id`) är alltid **strängar**. JSONPlaceholder och vår modell
  använder heltal, så vi tolkar med `int.tryParse`. En trasig djuplänk som
  `/posts/abc` ska ge en "hittades inte"-skärm, inte en krasch.
- `go_router` matchar routes i den ordning de står. Därför ligger `posts/new`
  före `posts/:id`.

### Navigera med go_router

`go_router` lägger till extension-metoder på `context`:

```dart
context.go('/posts/42');      // byt plats – stacken byggs om efter URL:en
context.push('/users/3');     // lägg ovanpå nuvarande skärm
context.pop();                // tillbaka
context.pop(result);          // tillbaka med resultat

final draft = await context.push<PostDraft>('/posts/new');
```

| | `context.go` | `context.push` |
|---|---|---|
| Vad händer | Navigerar till sökvägen. Stacken blir det som route-trädet säger | Lägger skärmen överst på nuvarande stack |
| Typiskt för | Flikbyten, djuplänkar, efter inloggning | "Öppna inlägg", "visa profil", formulär som ska returnera något |
| Tillbakapil | Bara om sökvägen är nästlad (t.ex. `/posts/:id` under `/`) | Ja, alltid |

Flödet i Kvittra blir alltså: flödet → tryck på ett kort →
`context.push('/posts/${post.id}')` → tryck på författarens namn →
`context.push('/users/${post.userId}')`. Med `push` kan användaren backa hela
vägen tillbaka till flödet.

⚠️ **Varning:** Skicka helst **id:n** i sökvägen och hämta objektet på
målskärmen, inte hela objekt. Det finns `extra: post` för att skicka objekt, men
det överlever inte en djuplänk eller en omladdning på webben.

💡 **Tips:** `go_router` har också `redirect`, som används för att skicka
utloggade användare till `/login`. Det visas i modul 04 (Flutter Compositions).

## Dialoger, bottom sheets och SnackBar

Dialoger och bottom sheets är också routes. De visas med en funktion som
returnerar en `Future` med resultatet.

### AlertDialog

```dart
Future<void> _confirmDelete(Post post) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Ta bort inlägg?'),
      content: Text('"${post.title}" försvinner för alla, även kommentarerna.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Avbryt'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Ta bort'),
        ),
      ],
    ),
  );

  if (ok == true) {
    // ok kan vara null om användaren tryckte utanför dialogen
    _deletePost(post);
  }
}
```

### Bottom sheet för kommentarer

Många sociala appar visar kommentarerna i ett "ark" som glider upp nerifrån och
kan dras högre. Med `isScrollControlled: true` och en `DraggableScrollableSheet`
får arket en egen höjd och scrollar sin lista:

```dart
void _showComments(List<Comment> comments) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true, // arket får bli högre än halva skärmen
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6, // 60 % av skärmhöjden från början
      maxChildSize: 0.9,
      builder: (context, scrollController) => ListView.builder(
        controller: scrollController, // låt arket och listan dela på scrollningen
        itemCount: comments.length,
        itemBuilder: (context, i) {
          final c = comments[i];
          return ListTile(
            leading: CircleAvatar(child: Text(initials(c.name))),
            title: Text(c.name),
            subtitle: Text(c.body),
          );
        },
      ),
    ),
  );
}
```

`initials` är hjälpfunktionen från kapitel 02, och `Comment` har fälten `name` och
`body` (som i JSONPlaceholder, kapitel 05).

### SnackBar

En kort bekräftelse längst ner på skärmen:

```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: const Text('Inlägget är publicerat'),
    action: SnackBarAction(label: 'Ångra', onPressed: () {}),
  ),
);
```

⚠️ **Varning:** Om du använder `context` efter en `await` kan widgeten ha hunnit
försvinna. Kontrollera `if (!context.mounted) return;` (i en `StatelessWidget` eller
callback) eller `if (!mounted) return;` (i en `State`) innan du visar en SnackBar
eller navigerar. Lint-regeln `use_build_context_synchronously` varnar för detta.

## Formulär

Ett formulär i Flutter består av:

- **`Form`**: en behållare som håller ihop fälten och kan validera alla på en gång,
- **`GlobalKey<FormState>`**: ett "handtag" till formuläret så att du kan anropa
  `validate()` och `save()`,
- **`TextFormField`** och andra `FormField`s: fält med inbyggd validering.

### TextFormField och validators

En **validator** är en funktion som får fältets värde och returnerar:

- `null` om värdet är OK, eller
- en **felmeddelande-sträng** som visas under fältet.

```dart
// lib/validators.dart
String? validateTitle(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Titel krävs';
  if (v.length < 3) return 'Minst 3 tecken';
  if (v.length > 80) return 'Max 80 tecken';
  return null; // OK
}

String? validateBody(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Skriv något';
  if (v.length > 280) return 'Max 280 tecken';
  return null;
}
```

```dart
TextFormField(
  controller: _titleController,
  decoration: const InputDecoration(
    labelText: 'Titel',
    hintText: 'T.ex. "Första fikat på nya kontoret"',
    border: OutlineInputBorder(),
    prefixIcon: Icon(Icons.title),
  ),
  validator: validateTitle,
  textInputAction: TextInputAction.next,
)
```

💡 **Tips:** Validators är vanliga Dart-funktioner. Lägg dem i en egen fil så kan
du enhetstesta dem enkelt (kapitel 06).

### Teckenräknare

Sätter du `maxLength` på ett textfält får du en räknare ("42/280") under fältet
på köpet, och det går inte att skriva fler tecken. Vill du visa något annat, till
exempel hur många tecken som är **kvar** och göra texten röd när det börjar ta
slut, använder du `buildCounter`:

```dart
TextFormField(
  controller: _bodyController,
  maxLength: 280,
  minLines: 4,
  maxLines: 8,
  decoration: const InputDecoration(
    labelText: 'Vad har du på hjärtat?',
    border: OutlineInputBorder(),
    alignLabelWithHint: true,
  ),
  validator: validateBody,
  buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
    final left = (maxLength ?? 0) - currentLength;
    return Text(
      '$left tecken kvar',
      style: TextStyle(color: left < 20 ? Theme.of(context).colorScheme.error : null),
    );
  },
)
```

Räknaren byggs om automatiskt när texten ändras. Du behöver ingen egen lyssnare
eller `setState`.

### DropdownButtonFormField

En rullgardinsmeny som också är ett formulärfält. Här väljer man vem som ska se
inlägget. Alternativen är en enhanced enum:

```dart
enum Audience {
  everyone('Alla'),
  followers('Mina följare'),
  onlyMe('Bara jag');

  const Audience(this.label);
  final String label;
}
```

```dart
DropdownButtonFormField<Audience>(
  initialValue: _audience,
  decoration: const InputDecoration(
    labelText: 'Vem får se inlägget?',
    border: OutlineInputBorder(),
  ),
  items: [
    for (final a in Audience.values)
      DropdownMenuItem(value: a, child: Text(a.label)),
  ],
  onChanged: (value) => setState(() => _audience = value),
  validator: (value) => value == null ? 'Välj vem som får se inlägget' : null,
)
```

⚠️ **Varning:** I Flutter-versioner före 3.35 heter parametern `value` i stället
för `initialValue`. Ser du en varning om `value` som "deprecated" är det den som
ska bytas.

💡 **Tips:** Döp aldrig en egen enum eller klass till något som redan finns i
Flutter, som `Visibility`, `Card` eller `Icon`. Då krockar namnen med
`package:flutter/material.dart`. Därför heter vår enum `Audience`.

### Datum- och tidsväljare

Kvittra låter dig **schemalägga** ett inlägg så att det publiceras senare.
`showDatePicker` och `showTimePicker` öppnar Material-dialoger och returnerar det
valda värdet, eller `null` om användaren avbröt.

```dart
Future<void> _pickDate() async {
  final now = DateTime.now();
  final picked = await showDatePicker(
    context: context,
    initialDate: _date ?? now,
    firstDate: now,                             // inte bakåt i tiden
    lastDate: now.add(const Duration(days: 30)), // max en månad fram
  );
  if (picked != null) setState(() => _date = picked);
}

Future<void> _pickTime() async {
  final picked = await showTimePicker(
    context: context,
    initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
  );
  if (picked != null) setState(() => _time = picked);
}
```

`TimeOfDay` innehåller bara timme och minut. Kombinera med datumet för att få en
`DateTime`:

```dart
final publishAt = DateTime(_date!.year, _date!.month, _date!.day,
    _time!.hour, _time!.minute);
```

💡 **Tips:** För svenska månadsnamn och veckor som börjar på måndag, lägg till
`flutter_localizations` och ställ in `locale: const Locale('sv')` i `MaterialApp`.
Se <https://docs.flutter.dev/ui/accessibility-and-internationalization/internationalization>.

## Helt exempel: nytt inlägg

Nu sätter vi ihop allt till en skärm där man skriver ett inlägg. Formuläret
returnerar ett `PostDraft` till föregående skärm med `Navigator.pop`. Det är ett
*utkast*: det har ännu inget id, eftersom det är servern som delar ut id:n
(kapitel 05).

```dart
import 'package:flutter/material.dart';

// Audience, validateTitle och validateBody från avsnitten ovan

class PostDraft {
  const PostDraft({
    required this.title,
    required this.body,
    required this.audience,
    this.publishAt,
  });

  final String title;
  final String body;
  final Audience audience;
  final DateTime? publishAt; // null = publicera direkt
}

class NewPostScreen extends StatefulWidget {
  const NewPostScreen({super.key, this.initialAudience = Audience.everyone});

  final Audience initialAudience;

  @override
  State<NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends State<NewPostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  Audience? _audience; // sätts i initState
  bool _schedule = false;
  DateTime? _date;
  TimeOfDay? _time;

  @override
  void initState() {
    super.initState();
    _audience = widget.initialAudience;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _submit() {
    // validate() kör alla validators och visar felmeddelanden
    if (!_formKey.currentState!.validate()) return;

    DateTime? publishAt;
    if (_schedule) {
      if (_date == null || _time == null) {
        _showError('Välj datum och tid för publicering');
        return;
      }
      publishAt = DateTime(_date!.year, _date!.month, _date!.day,
          _time!.hour, _time!.minute);
      if (publishAt.isBefore(DateTime.now())) {
        _showError('Tiden har redan passerat');
        return;
      }
    }

    final draft = PostDraft(
      title: _titleController.text.trim(),
      body: _bodyController.text.trim(),
      audience: _audience!,
      publishAt: publishAt,
    );

    Navigator.of(context).pop(draft); // skicka tillbaka resultatet
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dateText = _date == null
        ? 'Välj datum'
        : '${_date!.year}-${_date!.month.toString().padLeft(2, '0')}-'
            '${_date!.day.toString().padLeft(2, '0')}';
    final timeText = _time == null ? 'Välj tid' : _time!.format(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Nytt inlägg')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Titel',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: validateTitle,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bodyController,
              maxLength: 280,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Vad har du på hjärtat?',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: validateBody,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
                final left = (maxLength ?? 0) - currentLength;
                return Text(
                  '$left tecken kvar',
                  style: TextStyle(color: left < 20 ? colors.error : null),
                );
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Audience>(
              initialValue: _audience,
              decoration: const InputDecoration(
                labelText: 'Vem får se inlägget?',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final a in Audience.values)
                  DropdownMenuItem(value: a, child: Text(a.label)),
              ],
              onChanged: (value) => setState(() => _audience = value),
              validator: (value) => value == null ? 'Välj vem som får se inlägget' : null,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Publicera senare'),
              value: _schedule,
              onChanged: (v) => setState(() => _schedule = v),
            ),
            if (_schedule)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today),
                      label: Text(dateText),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.schedule),
                      label: Text(timeText),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.send),
              label: Text(_schedule ? 'Schemalägg' : 'Publicera'),
            ),
          ],
        ),
      ),
    );
  }
}
```

Saker att lägga märke till:

- `_formKey.currentState!.validate()` kör **alla** validators och returnerar
  `true` om inga fel finns.
- Datum och tid ligger inte i ett `FormField`, så de kontrolleras manuellt i
  `_submit`. (Man kan bygga egna `FormField`s, men det är överkurs.)
- `if (_schedule) Row(...)` är collection-if från kapitel 01: datum- och
  tidsknapparna finns bara i trädet när brytaren är på.
- `for (final a in Audience.values)` bygger menyalternativen direkt från enumen.
  Lägger någon till ett nytt alternativ i `Audience` dyker det upp automatiskt.
- `_audience` är `Audience?` eftersom `onChanged` kan ge `null`. Validatorn ser
  till att det aldrig är null när vi kommer till `_audience!` i `_submit`.
- Båda controllers skapas och `dispose`:as, som vi lärde oss i kapitel 03.

💡 **Tips:** Sätt `autovalidateMode: AutovalidateMode.onUserInteraction` på `Form`
om du vill att fel ska visas direkt medan användaren skriver, och inte först när
hen trycker på "Publicera".

### Använd formuläret

```dart
class MyPostsScreen extends StatefulWidget {
  const MyPostsScreen({super.key});

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  final List<PostDraft> _drafts = [];

  Future<void> _newPost() async {
    final draft = await Navigator.of(context).push<PostDraft>(
      MaterialPageRoute(builder: (_) => const NewPostScreen()),
    );
    if (draft == null || !mounted) return;
    setState(() => _drafts.insert(0, draft));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(draft.publishAt == null
            ? 'Inlägget är publicerat'
            : 'Inlägget publiceras ${draft.publishAt}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mina inlägg')),
      body: ListView(
        children: [
          for (final d in _drafts)
            ListTile(
              title: Text(d.title),
              subtitle: Text(d.body, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Text(d.audience.label),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _newPost,
        child: const Icon(Icons.edit),
      ),
    );
  }
}
```

## Exempel: registreringsformulär

Ett formulär till som alla sociala appar har: skapa konto. Här finns några nya
saker: ett reguljärt uttryck för användarnamn, lösenordsfält med en "visa"-knapp
och en validator som jämför två fält.

```dart
// lib/validators.dart (fortsättning)
final _usernamePattern = RegExp(r'^[a-z0-9_]{3,20}$');
final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateUsername(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Välj ett användarnamn';
  if (!_usernamePattern.hasMatch(v)) return '3–20 tecken: små bokstäver a–z, siffror och _';
  return null;
}

String? validateEmail(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Ange din e-postadress';
  if (!_emailPattern.hasMatch(v)) return 'Det ser inte ut som en e-postadress';
  return null;
}

String? validatePassword(String? value) =>
    (value == null || value.length < 8) ? 'Minst 8 tecken' : null;

String? validatePasswordConfirm(String? value, String password) =>
    value != password ? 'Lösenorden matchar inte' : null;
```

`RegExp(r'^[a-z0-9_]{3,20}$')` betyder: från början (`^`) till slutet (`$`) får det
bara finnas a–z, 0–9 och `_`, och det ska vara mellan 3 och 20 tecken. `r` före
strängen gör den "raw", så att `\s` inte tolkas som en escape-sekvens i Dart.

```dart
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Välkommen till Kvittra, @${_username.text.trim()}!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Skapa konto')),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _username,
              decoration: const InputDecoration(
                labelText: 'Användarnamn',
                prefixText: '@',
                border: OutlineInputBorder(),
              ),
              autocorrect: false,
              validator: validateUsername,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(
                labelText: 'E-post',
                hintText: 'anna@example.com',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              validator: validateEmail,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Lösenord',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                ),
              ),
              validator: validatePassword,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirm,
              obscureText: _obscure,
              decoration: const InputDecoration(
                labelText: 'Upprepa lösenord',
                border: OutlineInputBorder(),
              ),
              // Jämför med det andra fältet via dess controller
              validator: (v) => validatePasswordConfirm(v, _password.text),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _submit, child: const Text('Skapa konto')),
          ],
        ),
      ),
    );
  }
}
```

- `obscureText` döljer lösenordet. `suffixIcon` med en `IconButton` växlar en
  `bool` i state, och båda lösenordsfälten följer den.
- `validatePasswordConfirm` tar emot det andra fältets text som argument. Så blir
  den en ren funktion som är lätt att testa, trots att den beror på två fält.
- Fyra controllers betyder fyra rader i `dispose`. Glöm inte någon!

🧪 **Prova själv:**

1. Lägg till en `SwitchListTile` "Lägg till länk" i `NewPostScreen` och ett
   `TextFormField` för en URL som bara visas när brytaren är på (collection-if!).
   Validera att länken börjar med `https://` och går att tolka med `Uri.tryParse`.
2. Gör om navigationen till `go_router` med sökvägarna `/`, `/posts/new` och
   `/posts/new?audience=followers`, där query-parametern förväljer `Audience`
   (`Audience.values.byName(...)`, men tänk på att den kastar fel för okända namn).
3. Visa en bekräftelsedialog ("Publicera för Mina följare?") innan formuläret
   stängs.

**Nästa kapitel:** [05 – Async och nätverk](05-async-och-natverk.md)

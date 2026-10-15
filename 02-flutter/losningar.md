# Lösningar – Modul 02 Flutter

> Titta här först när du har försökt själv. Det finns alltid flera sätt att lösa en
> uppgift. Om din lösning fungerar och är läsbar är den lika bra.

---

## Nivå 1

### Lösning 1.1 – Inlägg och användare

```dart
class User {
  const User({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
  });

  final int id;
  final String name;
  final String username;
  final String email;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        name: json['name'] as String,
        username: json['username'] as String,
        email: json['email'] as String,
      );

  String get handle => '@$username';
}

class Post {
  const Post({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
  });

  final int id;
  final int userId;
  final String title;
  final String body;

  factory Post.fromJson(Map<String, dynamic> json) => Post(
        id: json['id'] as int,
        userId: json['userId'] as int,
        title: json['title'] as String,
        body: json['body'] as String? ?? '',
      );

  // split på ett eller flera blanksteg; en tom text har noll ord
  int get wordCount => body.trim().isEmpty ? 0 : body.trim().split(RegExp(r'\s+')).length;
}

void main() {
  final usersJson = <Map<String, dynamic>>[
    {'id': 1, 'name': 'Anna Lind', 'username': 'anna', 'email': 'anna@example.com'},
    {'id': 2, 'name': 'Bo Ek', 'username': 'bo', 'email': 'bo@example.com'},
    {'id': 3, 'name': 'Cecilia Holm', 'username': 'cissi', 'email': 'cecilia@example.com'},
  ];

  final postsJson = <Map<String, dynamic>>[
    {'userId': 1, 'id': 1, 'title': 'Första fikat på nya kontoret', 'body': 'Kanelbullar till alla som kommer före nio'},
    {'userId': 2, 'id': 2, 'title': 'Cykla i regn', 'body': 'Tre veckor i rad nu och regnbyxorna är fortfarande underskattade'},
    {'userId': 1, 'id': 3, 'title': 'Tips: Flutter DevTools', 'body': 'Widget Inspector visar constraints'},
    {'userId': 3, 'id': 4, 'title': 'Söker löparsällskap', 'body': 'Fem kilometer runt sjön på lördag'},
    {'userId': 1, 'id': 5, 'title': 'Hej Kvittra', 'body': 'Mitt första inlägg'},
  ];

  final users = usersJson.map(User.fromJson).toList();
  final posts = postsJson.map(Post.fromJson).toList();

  print('Inlägg av användare 1:');
  for (final p in posts.where((p) => p.userId == 1)) {
    print('  ${p.title}');
  }

  // Räkna inlägg per userId. fold bygger upp en map steg för steg
  final postsPerUser = posts.fold(<int, int>{}, (counts, p) {
    counts[p.userId] = (counts[p.userId] ?? 0) + 1;
    return counts;
  });
  print('Inlägg per användare: $postsPerUser');

  final longest = posts.reduce((a, b) => a.wordCount >= b.wordCount ? a : b);
  print('Flest ord: "${longest.title}" (${longest.wordCount} ord)');

  // "JOIN": slå upp författaren för varje inlägg
  final usersById = {for (final u in users) u.id: u};
  for (final p in posts) {
    final author = usersById[p.userId];
    final who = author == null ? 'Okänd' : '${author.name} (${author.handle})';
    print('$who: ${p.title}');
  }
}
```

Utskrift:

```
Inlägg av användare 1:
  Första fikat på nya kontoret
  Tips: Flutter DevTools
  Hej Kvittra
Inlägg per användare: {1: 3, 2: 1, 3: 1}
Flest ord: "Cykla i regn" (10 ord)
Anna Lind (@anna): Första fikat på nya kontoret
Bo Ek (@bo): Cykla i regn
...
```

💡 `usersJson.map(User.fromJson)` skickar konstruktorn direkt som funktion
("tear-off"). Det är samma sak som `usersJson.map((j) => User.fromJson(j))`.

💡 `{for (final u in users) u.id: u}` är samma uppslagsteknik som `loadFeed` i
kapitel 05. Utan den skulle du behöva leta igenom hela användarlistan för varje
inlägg.

### Lösning 1.2 – Null safety

```dart
class User {
  User({required this.name, this.website});
  final String name;
  final String? website;
}

String profileLink(User user) {
  final website = user.website;
  if (website == null) {
    return '${user.name} – ingen webbplats';
  }
  // Här vet Dart att website är en String (inte null)
  return '${user.name} – https://${website.toLowerCase()}';
}

// Alternativ med ?. och ??:
String profileLink2(User user) {
  final url = user.website?.toLowerCase();
  return '${user.name} – ${url == null ? 'ingen webbplats' : 'https://$url'}';
}

void main() {
  print(profileLink(User(name: 'Anna', website: 'Anna.Example.com')));
  print(profileLink(User(name: 'Bo')));
  print(profileLink2(User(name: 'Bo')));
}
```

⚠️ Varför kopierar vi `user.website` till en lokal variabel? Dart kan bara
"befordra" (promote) **lokala variabler** och privata `final`-fält till icke-null
efter en `if`-kontroll. Ett publikt fält skulle i teorin kunna vara en getter som
returnerar olika värden varje gång. `profileLink2` visar samma idé: `?.` ger `null`
om webbplats saknas, och sedan väljer vi text med `?:`.

### Lösning 1.3 – Flödesfilter, switch och records

```dart
enum FeedFilter {
  all('Alla'),
  following('Följer'),
  mine('Mina');

  const FeedFilter(this.label);
  final String label;
}

String emptyMessage(FeedFilter filter) => switch (filter) {
      FeedFilter.all => 'Inga inlägg ännu',
      FeedFilter.following => 'Du följer ingen än – hitta någon att följa!',
      FeedFilter.mine => 'Du har inte skrivit något än',
    };

(int likes, int comments) summera(List<(int, int)> inlagg) {
  var likes = 0;
  var comments = 0;
  for (final (l, c) in inlagg) {
    likes += l;
    comments += c;
  }
  return (likes, comments);
}

void main() {
  for (final filter in FeedFilter.values) {
    print('${filter.label}: ${emptyMessage(filter)}');
  }

  final (likes, comments) = summera([(12, 3), (4, 0), (7, 2)]);
  print('Totalt $likes gillningar och $comments kommentarer');
}
```

Tar du bort `FeedFilter.mine => ...` får du kompileringsfelet:

```
The type 'FeedFilter' isn't exhaustively matched by the switch cases since it doesn't match the pattern 'FeedFilter.mine'.
```

Det är just poängen: lägger någon till ett nytt filter senare (t.ex. `popular`)
tvingar kompilatorn dig att ta ställning på alla ställen där filter hanteras.

`for (final (l, c) in inlagg)` destrukturerar varje record direkt i loopen.

### Lösning 1.4 – Layout från skiss

```dart
import 'package:flutter/material.dart';

void main() => runApp(const ProfileApp());

class ProfileApp extends StatelessWidget {
  const ProfileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F51B5)),
      ),
      home: const ProfileScreen(),
    );
  }
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  final last = parts.length > 1 ? parts.last[0] : '';
  return (parts.first[0] + last).toUpperCase();
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('@anna'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.settings)),
        ],
      ),
      // ListView gör att allt kan scrollas om det inte får plats
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
              child: Text(initials('Anna Lind'), style: text.headlineSmall),
            ),
          ),
          const SizedBox(height: 12),
          Text('Anna Lind', style: text.titleLarge, textAlign: TextAlign.center),
          Text(
            'Utvecklare i Malmö. Gillar fika.',
            style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(child: _Stat(value: 12, label: 'Inlägg')),
              Expanded(child: _Stat(value: 128, label: 'Följare')),
              Expanded(child: _Stat(value: 87, label: 'Följer')),
            ],
          ),
          const SizedBox(height: 24),
          Text('Inlägg', style: text.titleMedium),
          const SizedBox(height: 8),
          const _PostTile(
            name: 'Anna Lind',
            username: 'anna',
            time: '5 min',
            title: 'Första fikat på nya kontoret',
            body: 'Kanelbullar till alla som kommer före nio! Ta med egen mugg, '
                'vi har bara tolv koppar och de brukar ta slut direkt.',
            likes: 12,
            comments: 3,
          ),
          const _PostTile(
            name: 'Anna Lind',
            username: 'anna',
            time: '2 d',
            title: 'Tips: Flutter DevTools',
            body: 'Widget Inspector visar constraints för varje widget. '
                'Perfekt när något flödar över och du inte förstår varför.',
            likes: 4,
            comments: 0,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Text('$value', style: text.titleLarge),
        Text(label, style: text.bodySmall),
      ],
    );
  }
}

class _PostTile extends StatelessWidget {
  const _PostTile({
    required this.name,
    required this.username,
    required this.time,
    required this.title,
    required this.body,
    required this.likes,
    required this.comments,
  });

  final String name;
  final String username;
  final String time;
  final String title;
  final String body;
  final int likes;
  final int comments;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 16, child: Text(initials(name))),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$name · @$username · $time',
                    style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: text.titleSmall),
            Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.favorite_border, size: 18, color: colors.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('$likes'),
                const SizedBox(width: 16),
                Icon(Icons.chat_bubble_outline, size: 18, color: colors.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('$comments'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

Lägg märke till:

- Små privata widgets (`_Stat`, `_PostTile`) gör `build` i `ProfileScreen` mycket
  lättare att läsa än en enda jättemetod.
- `ListView` som `body` ger scroll gratis. En `Column` hade gett overflow i liggande läge.
- `Expanded` på de tre siffrorna gör dem lika breda.
- `Expanded` runt raden "Anna Lind · @anna · 5 min" gör att den kortas med `…` i
  stället för att flöda över på en smal skärm.
- Strängar som är för långa för en rad i koden kan delas upp: `'...' '...'` (två
  strängar direkt efter varandra) slås ihop till en.

---

## Nivå 2

### Lösning 2.1 – Gilla-knapp med state

**Steg 1–2: stateful knapp**

```dart
import 'package:flutter/material.dart';

class LikeButton extends StatefulWidget {
  const LikeButton({super.key, this.initialCount = 0, this.initiallyLiked = false});

  final int initialCount;
  final bool initiallyLiked;

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  late bool _liked;
  late int _count;

  @override
  void initState() {
    super.initState();
    _liked = widget.initiallyLiked;
    _count = widget.initialCount;
  }

  void _toggle() {
    setState(() {
      _liked = !_liked;
      // Aldrig under 0, även om startvärdena var konstiga
      _count = _liked ? _count + 1 : (_count > 0 ? _count - 1 : 0);
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

void main() => runApp(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Gilla')),
          body: ListView(
            children: const [
              ListTile(title: Text('Första fikat'), trailing: LikeButton(initialCount: 12)),
              ListTile(title: Text('Cykla i regn'), trailing: LikeButton(initialCount: 4, initiallyLiked: true)),
              ListTile(title: Text('Tips: DevTools'), trailing: LikeButton()),
            ],
          ),
        ),
      ),
    );
```

**Steg 3: lyft upp state**

Varje knapp hade sitt eget `_liked`, så ingen annan widget kunde veta hur många som
var gillade. Nu äger `FeedScreen` listan, och knappen är stateless:

```dart
import 'package:flutter/material.dart';

void main() => runApp(
      MaterialApp(
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo)),
        home: const FeedScreen(),
      ),
    );

class Post {
  const Post({required this.id, required this.title, this.likeCount = 0, this.liked = false});

  final int id;
  final String title;
  final int likeCount;
  final bool liked;

  Post copyWith({int? likeCount, bool? liked}) => Post(
        id: id,
        title: title,
        likeCount: likeCount ?? this.likeCount,
        liked: liked ?? this.liked,
      );

  Post toggleLike() => copyWith(
        liked: !liked,
        likeCount: liked ? (likeCount > 0 ? likeCount - 1 : 0) : likeCount + 1,
      );
}

// Stateless och "kontrollerad": visar bara det den får och rapporterar tryck
class LikeButton extends StatelessWidget {
  const LikeButton({
    super.key,
    required this.liked,
    required this.count,
    required this.onPressed,
  });

  final bool liked;
  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(
        liked ? Icons.favorite : Icons.favorite_border,
        color: liked ? Colors.red : null,
      ),
      label: Text('$count'),
    );
  }
}

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<Post> _posts = const [
    Post(id: 1, title: 'Första fikat på nya kontoret', likeCount: 12),
    Post(id: 2, title: 'Cykla i regn', likeCount: 4, liked: true),
    Post(id: 3, title: 'Tips: Flutter DevTools'),
  ];

  void _toggle(Post post) {
    setState(() {
      _posts = [for (final p in _posts) p.id == post.id ? p.toggleLike() : p];
    });
  }

  @override
  Widget build(BuildContext context) {
    final likedCount = _posts.where((p) => p.liked).length;

    return Scaffold(
      appBar: AppBar(title: Text('Du gillar $likedCount inlägg')),
      body: ListView(
        children: [
          for (final post in _posts)
            ListTile(
              key: ValueKey(post.id),
              title: Text(post.title),
              trailing: LikeButton(
                liked: post.liked,
                count: post.likeCount,
                onPressed: () => _toggle(post),
              ),
            ),
        ],
      ),
    );
  }
}
```

- Det finns bara **en** sanning: `_posts`. Både `AppBar` och knapparna visar den.
- `LikeButton` är nu en "kontrollerad" widget, precis som `Checkbox` eller `Switch`
  i Flutter: den får sitt värde utifrån och rapporterar tryck med en callback.
- `[for (final p in _posts) p.id == post.id ? p.toggleLike() : p]` skapar en ny
  lista där bara det tryckta inlägget är utbytt. Inga objekt ändras på plats.

**Steg 4:** Med de stateful knapparna följer `State`-objekten **positionen** i
listan. Läggs ett nytt inlägg in överst utan keys "flyttar" alla hjärtan ett steg:
inlägg 2 visar plötsligt inlägg 1:s gillning. Med `key: ValueKey(post.id)` på
raden kan Flutter flytta statet tillsammans med inlägget. Med upplyft state finns
problemet inte alls, eftersom knapparna inte har något eget state.

### Lösning 2.2 – Nytt inlägg med validering

```dart
import 'package:flutter/material.dart';

void main() => runApp(
      MaterialApp(
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo)),
        home: const MyFeedScreen(),
      ),
    );

// --- Modell och validators: rena Dart, lätta att testa --------------------

enum Audience {
  everyone('Alla'),
  followers('Mina följare'),
  onlyMe('Bara jag');

  const Audience(this.label);
  final String label;
}

class PostDraft {
  const PostDraft({
    required this.title,
    required this.body,
    required this.audience,
    this.publishOn,
  });

  final String title;
  final String body;
  final Audience audience;
  final DateTime? publishOn; // null = publicera direkt
}

String? validateTitle(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Titel krävs';
  if (v.length < 3) return 'Minst 3 tecken';
  if (v.length > 80) return 'Max 80 tecken';
  return null;
}

String? validateBody(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Skriv något';
  if (v.length > 280) return 'Max 280 tecken';
  return null;
}

String formatDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// --- Formuläret -----------------------------------------------------------

class NewPostScreen extends StatefulWidget {
  const NewPostScreen({super.key});

  @override
  State<NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends State<NewPostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  Audience? _audience; // inget förval: användaren måste välja
  bool _schedule = false;
  DateTime? _date;
  bool _showDateError = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 7)),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _showDateError = false;
      });
    }
  }

  void _submit() {
    final formOk = _formKey.currentState!.validate();
    final dateMissing = _schedule && _date == null;
    setState(() => _showDateError = dateMissing);
    if (!formOk || dateMissing) return;

    Navigator.of(context).pop(PostDraft(
      title: _titleController.text.trim(),
      body: _bodyController.text.trim(),
      audience: _audience!,
      publishOn: _schedule ? _date : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Nytt inlägg')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              key: const Key('title'),
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
              key: const Key('body'),
              controller: _bodyController,
              maxLength: 280,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Text',
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
              onChanged: (v) => setState(() => _audience = v),
              validator: (v) => v == null ? 'Välj vem som får se inlägget' : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Publicera senare'),
              value: _schedule,
              onChanged: (v) => setState(() {
                _schedule = v;
                if (!v) _showDateError = false;
              }),
            ),
            if (_schedule) ...[
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today),
                label: Text(_date == null ? 'Välj datum' : formatDate(_date!)),
              ),
              if (_showDateError)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 12),
                  child: Text(
                    'Välj ett datum',
                    style: TextStyle(color: colors.error, fontSize: 12),
                  ),
                ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('submit'),
              onPressed: _submit,
              child: const Text('Publicera'),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Flödet som tar emot resultatet ---------------------------------------

class MyFeedScreen extends StatefulWidget {
  const MyFeedScreen({super.key});

  @override
  State<MyFeedScreen> createState() => _MyFeedScreenState();
}

class _MyFeedScreenState extends State<MyFeedScreen> {
  final List<PostDraft> _posts = [];

  Future<void> _newPost() async {
    final draft = await Navigator.of(context).push<PostDraft>(
      MaterialPageRoute(builder: (_) => const NewPostScreen()),
    );
    if (draft == null || !mounted) return;

    setState(() => _posts.insert(0, draft)); // nyast överst
    final publishOn = draft.publishOn;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(publishOn == null
            ? 'Publicerat: ${draft.title}'
            : 'Schemalagt till ${formatDate(publishOn)}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kvittra')),
      body: _posts.isEmpty
          ? const Center(child: Text('Inga inlägg ännu'))
          : ListView(
              children: [
                for (final p in _posts)
                  ListTile(
                    title: Text(p.title),
                    subtitle: Text(p.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: Text(p.audience.label),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newPost,
        icon: const Icon(Icons.edit),
        label: const Text('Nytt inlägg'),
      ),
    );
  }
}
```

Designval:

- Validators ligger utanför widgeten som vanliga funktioner, så de kan testas utan
  Flutter (kapitel 06).
- Datumfelet visas med collection-if (`if (_showDateError) ...`) och temats
  `error`-färg, så att det ser ut som de andra fältens fel.
- `if (_schedule) ...[ ... ]` lägger till **flera** widgets (knappen och felet)
  när brytaren är på.
- `_audience` startar som `null` och `initialValue: _audience` ger då en tom meny.
  Validatorn tvingar användaren att välja. (I Flutter före 3.35 hette parametern
  `value`.)
- `_submit` kör `validate()` *och* kontrollerar datumet innan den avbryter, så att
  användaren ser alla fel på en gång.

### Lösning 2.3 – Flöde → inlägg → profil

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// --- Data (lokal, hårdkodad) ----------------------------------------------

class User {
  const User({required this.id, required this.name, required this.username, this.bio});
  final int id;
  final String name;
  final String username;
  final String? bio;
}

class Post {
  const Post({required this.id, required this.userId, required this.title, required this.body});
  final int id;
  final int userId;
  final String title;
  final String body;
}

class Comment {
  const Comment({required this.postId, required this.name, required this.body});
  final int postId;
  final String name;
  final String body;
}

const users = [
  User(id: 1, name: 'Anna Lind', username: 'anna', bio: 'Utvecklare i Malmö. Gillar fika.'),
  User(id: 2, name: 'Bo Ek', username: 'bo', bio: 'Cyklar året runt.'),
  User(id: 3, name: 'Cecilia Holm', username: 'cissi'),
];

const posts = [
  Post(id: 1, userId: 1, title: 'Första fikat på nya kontoret', body: 'Kanelbullar till alla som kommer före nio!'),
  Post(id: 2, userId: 2, title: 'Cykla i regn', body: 'Tre veckor i rad nu. Regnbyxor är underskattade.'),
  Post(id: 3, userId: 1, title: 'Tips: Flutter DevTools', body: 'Widget Inspector visar constraints.'),
  Post(id: 4, userId: 3, title: 'Söker löparsällskap', body: 'Fem kilometer runt sjön på lördag.'),
];

const comments = [
  Comment(postId: 1, name: 'Bo Ek', body: 'Jag kommer 08:59!'),
  Comment(postId: 1, name: 'Cecilia Holm', body: 'Finns det glutenfria?'),
  Comment(postId: 3, name: 'Bo Ek', body: 'Tack, det här behövde jag.'),
];

// Uppslag från en path-parameter (sträng) till ett objekt, eller null
int? _parseId(String? raw) => int.tryParse(raw ?? '');
User? userById(int id) => users.where((u) => u.id == id).firstOrNull;
Post? postById(int id) => posts.where((p) => p.id == id).firstOrNull;

String initials(String name) =>
    name.trim().split(RegExp(r'\s+')).map((p) => p[0]).take(2).join().toUpperCase();

// --- Router ---------------------------------------------------------------

final router = GoRouter(
  initialLocation: '/', // prova '/posts/3' för att testa en djuplänk
  errorBuilder: (context, state) => const NotFoundScreen(), // okända sökvägar
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const FeedScreen(),
      routes: [
        GoRoute(
          path: 'posts/:id',
          builder: (context, state) {
            final id = _parseId(state.pathParameters['id']);
            final post = id == null ? null : postById(id);
            return post == null ? const NotFoundScreen() : PostDetailScreen(post: post);
          },
        ),
        GoRoute(
          path: 'users/:id',
          builder: (context, state) {
            final id = _parseId(state.pathParameters['id']);
            final user = id == null ? null : userById(id);
            return user == null ? const NotFoundScreen() : ProfileScreen(user: user);
          },
        ),
      ],
    ),
  ],
);

void main() {
  runApp(MaterialApp.router(
    routerConfig: router,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo)),
  ));
}

// --- Skärmar --------------------------------------------------------------

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kvittra')),
      body: ListView(
        children: [
          for (final post in posts)
            ListTile(
              leading: CircleAvatar(child: Text(initials(userById(post.userId)?.name ?? '?'))),
              title: Text(post.title),
              subtitle: Text(userById(post.userId)?.name ?? 'Okänd'),
              onTap: () => context.push('/posts/${post.id}'),
            ),
        ],
      ),
    );
  }
}

class PostDetailScreen extends StatelessWidget {
  const PostDetailScreen({super.key, required this.post});

  final Post post;

  void _showComments(BuildContext context, List<Comment> list) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: list.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Inga kommentarer ännu'),
              )
            : ListView(
                shrinkWrap: true, // arket blir bara så högt som innehållet
                children: [
                  for (final c in list)
                    ListTile(
                      leading: CircleAvatar(child: Text(initials(c.name))),
                      title: Text(c.name),
                      subtitle: Text(c.body),
                    ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final author = userById(post.userId);
    final postComments = comments.where((c) => c.postId == post.id).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Inlägg')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (author != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text(initials(author.name))),
              title: Text(author.name),
              subtitle: Text('@${author.username}'),
              onTap: () => context.push('/users/${author.id}'),
            ),
          const SizedBox(height: 8),
          Text(post.title, style: text.headlineSmall),
          const SizedBox(height: 8),
          Text(post.body, style: text.bodyLarge),
          const SizedBox(height: 24),
          FilledButton.tonalIcon(
            onPressed: () => _showComments(context, postComments),
            icon: const Icon(Icons.chat_bubble_outline),
            label: Text('Visa kommentarer (${postComments.length})'),
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bio = user.bio;
    final userPosts = posts.where((p) => p.userId == user.id).toList();

    return Scaffold(
      appBar: AppBar(title: Text('@${user.username}')),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          Center(child: CircleAvatar(radius: 40, child: Text(initials(user.name)))),
          const SizedBox(height: 8),
          Text(user.name, style: text.titleLarge, textAlign: TextAlign.center),
          if (bio != null) Text(bio, textAlign: TextAlign.center),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('${userPosts.length} inlägg', style: text.titleMedium),
          ),
          for (final p in userPosts)
            ListTile(
              title: Text(p.title),
              subtitle: Text(p.body, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/posts/${p.id}'),
            ),
        ],
      ),
    );
  }
}

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hittades inte')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Det du letar efter finns inte.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Till flödet'),
            ),
          ],
        ),
      ),
    );
  }
}
```

Lägg märke till:

- Path-parametrar är strängar. `int.tryParse` + uppslag som kan ge `null` gör att
  både `/posts/abc` och `/posts/999` hamnar på `NotFoundScreen`. `errorBuilder`
  fångar sökvägar som inte matchar någon route alls (t.ex. `/foo`).
- `firstOrNull` (inbyggt i Dart 3) ger `null` i stället för att kasta fel som
  `firstWhere` gör när inget matchar.
- `context.push` lägger skärmar ovanpå varandra, så tillbakapilen går
  profil → inlägg → flöde. Med `context.go` hade stacken byggts från route-trädet.
- **Djuplänken** `/posts/3`: ja, det finns en tillbakapil. Eftersom `posts/:id` är
  **nästlad** under `/` bygger `go_router` stacken `[flöde, inlägg 3]`, precis som
  om användaren hade navigerat dit själv.
- Bottom sheeten använder `shrinkWrap: true` så att arket bara blir så högt som
  kommentarerna kräver. Med många kommentarer är `DraggableScrollableSheet` från
  kapitel 04 bättre.

---

## Nivå 3

Modellerna `Post`, `Comment`, `User` (med `Address` och `Company`) och
`LoadState` är exakt samma som i [kapitel 05](05-async-och-natverk.md), och
`JsonPlaceholderApi` likaså. Här visas bara det som är nytt.

### Lösning 3.1 – Flödet från JSONPlaceholder

**`lib/data/jsonplaceholder_api.dart`** – lägg till en metod i klassen från kapitel 05:

```dart
  /// Alla 500 kommentarer. Används för att räkna kommentarer per inlägg.
  Future<List<Comment>> fetchAllComments() => _getList('/comments', Comment.fromJson);
```

**`lib/models/feed_item.dart`**

```dart
import '../data/jsonplaceholder_api.dart';
import 'post.dart';
import 'user.dart';

class FeedItem {
  const FeedItem({required this.post, required this.author, this.commentCount = 0});

  final Post post;
  final User author;
  final int commentCount;
}

/// Hämtar inlägg, användare och kommentarer parallellt och kopplar ihop dem.
Future<List<FeedItem>> loadFeed(JsonPlaceholderApi api) async {
  final postsFuture = api.fetchPosts();
  final usersFuture = api.fetchUsers();
  final commentsFuture = api.fetchAllComments();
  await Future.wait([postsFuture, usersFuture, commentsFuture]);

  final posts = await postsFuture;
  final users = await usersFuture;
  final comments = await commentsFuture;

  // userId -> User
  final usersById = {for (final u in users) u.id: u};

  // postId -> antal kommentarer
  final commentCounts = <int, int>{};
  for (final c in comments) {
    commentCounts.update(c.postId, (n) => n + 1, ifAbsent: () => 1);
  }

  return [
    for (final post in posts)
      if (usersById[post.userId] case final author?)
        FeedItem(
          post: post,
          author: author,
          commentCount: commentCounts[post.id] ?? 0,
        ),
  ];
}
```

- Tre anrop startas innan vi väntar, så de körs parallellt.
- `commentCounts.update(key, (n) => n + 1, ifAbsent: () => 1)` ökar räknaren om
  nyckeln finns och sätter den till 1 annars. Det är en "GROUP BY postId" med
  `COUNT(*)` i Dart.
- Inlägg vars `userId` inte finns bland användarna hoppas över med
  `if (... case final author?)`.

**`lib/widgets/error_view.dart`**

```dart
import 'package:flutter/material.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Försök igen')),
          ],
        ),
      ),
    );
  }
}
```

**`lib/screens/feed_screen.dart`** (delarna märkta 3.2 lägger du till i nästa
övning)

```dart
import 'package:flutter/material.dart';

import '../data/jsonplaceholder_api.dart';
import '../models/feed_item.dart';
import '../models/load_state.dart';
import '../models/post.dart';
import '../widgets/error_view.dart';
import 'new_post_screen.dart';
import 'post_detail_screen.dart';
import 'profile_screen.dart';

/// Vi låtsas att den inloggade användaren är användare 1.
const currentUserId = 1;

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key, required this.api});

  final JsonPlaceholderApi api;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  LoadState<List<FeedItem>> _state = const Loading();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await loadFeed(widget.api);
      if (!mounted) return;
      setState(() => _state = Loaded(items));
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = Failed(e));
    }
  }

  void _retry() {
    setState(() => _state = const Loading());
    _load();
  }

  void _openPost(int postId) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PostDetailScreen(api: widget.api, postId: postId),
    ));
  }

  void _openProfile(int userId) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProfileScreen(api: widget.api, userId: userId),
    ));
  }

  // 3.2: skapa inlägg och lägg in det först utan att hämta om allt
  Future<void> _create() async {
    final post = await Navigator.of(context).push<Post>(MaterialPageRoute(
      builder: (_) => NewPostScreen(api: widget.api, userId: currentUserId),
    ));
    if (post == null || !mounted) return;

    if (_state case Loaded(:final data)) {
      final me = data.map((i) => i.author).where((u) => u.id == post.userId).firstOrNull;
      if (me != null) {
        setState(() => _state = Loaded([FeedItem(post: post, author: me), ...data]));
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Publicerat (id ${post.id})')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kvittra')),
      floatingActionButton: FloatingActionButton(
        onPressed: _state is Loaded ? _create : null,
        child: const Icon(Icons.edit),
      ),
      body: switch (_state) {
        Loading() => const Center(child: CircularProgressIndicator()),
        Failed(:final error) => ErrorView(message: '$error', onRetry: _retry),
        Loaded(:final data) => RefreshIndicator(
            onRefresh: _load,
            child: data.isEmpty
                // ListView även när det är tomt, så att man kan dra för att uppdatera
                ? ListView(children: const [
                    SizedBox(height: 200),
                    Center(child: Text('Inga inlägg ännu')),
                  ])
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: data.length,
                    itemBuilder: (context, i) => FeedTile(
                      item: data[i],
                      onTap: () => _openPost(data[i].post.id),
                      onAuthorTap: () => _openProfile(data[i].author.id),
                    ),
                  ),
          ),
      },
    );
  }
}

class FeedTile extends StatelessWidget {
  const FeedTile({super.key, required this.item, this.onTap, this.onAuthorTap});

  final FeedItem item;
  final VoidCallback? onTap;
  final VoidCallback? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final FeedItem(:post, :author, :commentCount) = item;

    return Card(
      clipBehavior: Clip.antiAlias, // krusningen följer de rundade hörnen
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: onAuthorTap,
                child: Row(
                  children: [
                    CircleAvatar(radius: 16, child: Text(author.name[0])),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${author.name} · ${author.handle}',
                        style: text.labelLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(post.title, style: text.titleMedium),
              Text(post.body, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.chat_bubble_outline, size: 16, color: colors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('$commentCount', style: text.labelMedium),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

**`lib/main.dart`**

```dart
import 'package:flutter/material.dart';

import 'data/jsonplaceholder_api.dart';
import 'screens/feed_screen.dart';

void main() {
  final api = JsonPlaceholderApi();
  runApp(MaterialApp(
    title: 'Kvittra',
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo)),
    home: FeedScreen(api: api),
  ));
}
```

💡 `JsonPlaceholderApi` skapas i `main` och skickas in. Det gör att testerna i 3.3
kan skicka in ett med `MockClient`.

💡 `final FeedItem(:post, :author, :commentCount) = item;` i `FeedTile` är ett
object pattern som plockar ut tre fält på en rad.

### Lösning 3.2 – Inlägg, profil och nytt inlägg

**`lib/screens/post_detail_screen.dart`**

```dart
import 'package:flutter/material.dart';

import '../data/jsonplaceholder_api.dart';
import '../models/comment.dart';
import '../models/load_state.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../widgets/error_view.dart';
import 'profile_screen.dart';

/// Allt som skärmen visar, i ett enda record
typedef PostDetails = ({Post post, User author, List<Comment> comments});

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.api, required this.postId});

  final JsonPlaceholderApi api;
  final int postId;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  LoadState<PostDetails> _state = const Loading();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<PostDetails> _fetch() async {
    // Inlägget och kommentarerna behöver bara postId, så de hämtas samtidigt
    final postFuture = widget.api.fetchPost(widget.postId);
    final commentsFuture = widget.api.fetchComments(widget.postId);
    await Future.wait([postFuture, commentsFuture]);
    final post = await postFuture;

    // Författaren kan vi hämta först när vi vet userId
    final author = await widget.api.fetchUser(post.userId);
    return (post: post, author: author, comments: await commentsFuture);
  }

  Future<void> _load() async {
    try {
      final details = await _fetch();
      if (!mounted) return;
      setState(() => _state = Loaded(details));
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = Failed(e));
    }
  }

  void _retry() {
    setState(() => _state = const Loading());
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Inlägg')),
      body: switch (_state) {
        Loading() => const Center(child: CircularProgressIndicator()),
        Failed(:final error) => ErrorView(message: '$error', onRetry: _retry),
        Loaded(data: (:final post, :final author, :final comments)) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text(author.name[0])),
                title: Text(author.name),
                subtitle: Text(author.handle),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ProfileScreen(api: widget.api, userId: author.id),
                )),
              ),
              Text(post.title, style: text.headlineSmall),
              const SizedBox(height: 8),
              Text(post.body, style: text.bodyLarge),
              const Divider(height: 32),
              Text('${comments.length} kommentarer', style: text.titleMedium),
              for (final c in comments)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(c.email, style: text.labelLarge),
                  subtitle: Text(c.body),
                ),
            ],
          ),
      },
    );
  }
}
```

- `typedef PostDetails = ({Post post, User author, List<Comment> comments});` ger
  ett namn åt ett record-typ. Då kan `LoadState<PostDetails>` hålla tre saker utan
  att vi behöver skriva en klass.
- `Loaded(data: (:final post, :final author, :final comments))` är ett pattern i
  två nivåer: först `Loaded`, sedan recordet inuti `data`.
- Med `postId: 999` svarar JSONPlaceholder 404. `_send` gör det till
  `ApiException('Hittades inte', 404)`, och skärmen visar "Hittades inte (404)".

**`lib/screens/profile_screen.dart`**

```dart
import 'package:flutter/material.dart';

import '../data/jsonplaceholder_api.dart';
import '../models/load_state.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../widgets/error_view.dart';
import 'post_detail_screen.dart';

typedef ProfileData = ({User user, List<Post> posts});

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.api, required this.userId});

  final JsonPlaceholderApi api;
  final int userId;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  LoadState<ProfileData> _state = const Loading();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final userFuture = widget.api.fetchUser(widget.userId);
      final postsFuture = widget.api.fetchPostsByUser(widget.userId);
      await Future.wait([userFuture, postsFuture]);
      final data = (user: await userFuture, posts: await postsFuture);
      if (!mounted) return;
      setState(() => _state = Loaded(data));
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = Failed(e));
    }
  }

  void _retry() {
    setState(() => _state = const Loading());
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: switch (_state) {
        Loading() => const Center(child: CircularProgressIndicator()),
        Failed(:final error) => ErrorView(message: '$error', onRetry: _retry),
        Loaded(data: (:final user, :final posts)) => ListView(
            children: [
              _ProfileInfo(user: user, postCount: posts.length),
              for (final p in posts)
                ListTile(
                  title: Text(p.title),
                  subtitle: Text(p.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PostDetailScreen(api: widget.api, postId: p.id),
                  )),
                ),
            ],
          ),
      },
    );
  }
}

class _ProfileInfo extends StatelessWidget {
  const _ProfileInfo({required this.user, required this.postCount});

  final User user;
  final int postCount;

  Widget _info(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 16), const SizedBox(width: 4), Text(text)],
      );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Lokala kopior så att null-kontrollerna nedan fungerar
    final website = user.website;
    final city = user.address?.city;
    final company = user.company?.name;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          CircleAvatar(radius: 40, child: Text(user.name[0], style: text.headlineSmall)),
          const SizedBox(height: 8),
          Text(user.name, style: text.titleLarge),
          Text(user.handle),
          const SizedBox(height: 8),
          if (website != null) _info(Icons.link, website),
          if (city != null) _info(Icons.place_outlined, city),
          if (company != null) _info(Icons.work_outline, company),
          const SizedBox(height: 16),
          Text('$postCount inlägg', style: text.titleMedium),
        ],
      ),
    );
  }
}
```

💡 JSONPlaceholder har inga följare, så vi visar adress och företag i stället. Med
PocketBase och collectionen `follows` kan du räkna följare på riktigt (modul 01).

💡 `post_detail_screen.dart` och `profile_screen.dart` importerar varandra. Det är
tillåtet i Dart.

**`lib/screens/new_post_screen.dart`**

```dart
import 'package:flutter/material.dart';

import '../data/jsonplaceholder_api.dart';

class NewPostScreen extends StatefulWidget {
  const NewPostScreen({super.key, required this.api, required this.userId});

  final JsonPlaceholderApi api;
  final int userId;

  @override
  State<NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends State<NewPostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final post = await widget.api.createPost(
        userId: widget.userId,
        title: _title.text.trim(),
        body: _body.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(post);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kunde inte publicera: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nytt inlägg')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              key: const Key('title'),
              controller: _title,
              enabled: !_saving,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Titel',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Titel krävs' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('body'),
              controller: _body,
              enabled: !_saving,
              maxLength: 280,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Text',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Text krävs' : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('save'),
              onPressed: _saving ? null : _save, // null = inaktiverad
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Publicera'),
            ),
          ],
        ),
      ),
    );
  }
}
```

Flödets `_create` (i `feed_screen.dart` ovan) tar emot det returnerade `Post`,
letar upp den inloggade användaren bland författarna som redan finns i flödet och
lägger in ett nytt `FeedItem` först.

**Svar på frågorna:**

- Det nya inlägget får **id 101**, varje gång. JSONPlaceholder låtsas bara spara.
- När du drar för att uppdatera hämtas flödet från servern igen, och där finns
  inlägget inte. Det försvinner. Mot PocketBase hade det funnits kvar.
- Skapar du två inlägg får båda id 101. Med `ValueKey(post.id)` får två rader då
  samma key, och Flutter kan inte längre skilja dem åt (i värsta fall får du
  felet "Duplicate keys"). Därför använder lösningen ingen `ValueKey` i flödet.
  Mot en riktig backend är id:n unika och problemet finns inte.

### Lösning 3.3 – Tester

**`test/models_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kvittra_ovningar/models/user.dart';

void main() {
  test('User.fromJson med nästlade objekt', () {
    final user = User.fromJson({
      'id': 1,
      'name': 'Leanne Graham',
      'username': 'Bret',
      'email': 'Sincere@april.biz',
      'address': {'street': 'Kulas Light', 'suite': 'Apt. 556', 'city': 'Gwenborough', 'zipcode': '92998-3874'},
      'website': 'hildegard.org',
      'company': {'name': 'Romaguera-Crona', 'catchPhrase': 'Multi-layered client-server neural-net'},
    });

    expect(user.handle, '@Bret');
    expect(user.address?.city, 'Gwenborough');
    expect(user.company?.name, 'Romaguera-Crona');
    expect(user.website, 'hildegard.org');
  });

  test('User.fromJson utan nästlade objekt', () {
    final user = User.fromJson({
      'id': 2,
      'name': 'Anna Lind',
      'username': 'anna',
      'email': 'anna@example.com',
    });

    expect(user.address, isNull);
    expect(user.company, isNull);
  });
}
```

**`test/api_test.dart`**

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kvittra_ovningar/data/jsonplaceholder_api.dart';
import 'package:kvittra_ovningar/models/feed_item.dart';

/// UTF-8-kodat JSON-svar (http.Response kodar annars som Latin-1)
http.Response jsonResponse(Object? body, int statusCode) => http.Response(
      jsonEncode(body),
      statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  test('fetchPosts anropar /posts', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/posts');
      return jsonResponse([
        {'userId': 1, 'id': 1, 'title': 'Hej', 'body': 'Text'},
      ], 200);
    });

    final posts = await JsonPlaceholderApi(client: client).fetchPosts();
    expect(posts.single.title, 'Hej');
  });

  test('500 ger ApiException', () {
    final client = MockClient((_) async => jsonResponse({}, 500));
    expect(
      JsonPlaceholderApi(client: client).fetchPosts(),
      throwsA(isA<ApiException>()),
    );
  });

  test('createPost godtar 201 Created', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      final sent = jsonDecode(request.body) as Map<String, dynamic>;
      return jsonResponse({...sent, 'id': 101}, 201);
    });

    final post = await JsonPlaceholderApi(client: client)
        .createPost(userId: 1, title: 'Hej', body: 'Text');
    expect(post.id, 101);
    expect(post.userId, 1);
  });

  test('loadFeed kopplar ihop, räknar kommentarer och hoppar över okända författare',
      () async {
    final client = MockClient((request) async => switch (request.url.path) {
          '/posts' => jsonResponse([
              {'userId': 1, 'id': 1, 'title': 'Hej', 'body': ''},
              {'userId': 99, 'id': 2, 'title': 'Utan författare', 'body': ''},
            ], 200),
          '/users' => jsonResponse([
              {'id': 1, 'name': 'Anna Lind', 'username': 'anna', 'email': 'anna@example.com'},
            ], 200),
          '/comments' => jsonResponse([
              {'postId': 1, 'id': 1, 'name': 'a', 'email': 'bo@example.com', 'body': 'Kul!'},
              {'postId': 1, 'id': 2, 'name': 'b', 'email': 'cecilia@example.com', 'body': 'Snyggt'},
            ], 200),
          _ => jsonResponse({}, 404),
        });

    final items = await loadFeed(JsonPlaceholderApi(client: client));

    expect(items, hasLength(1)); // inlägg 2 har ingen känd författare
    expect(items.single.author.username, 'anna');
    expect(items.single.commentCount, 2);
  });
}
```

Lägg märke till hur `MockClient` med ett `switch` på `request.url.path` låtsas vara
hela API:t. Samma `loadFeed` som i appen körs, men utan nätverk.

**`test/new_post_screen_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kvittra_ovningar/data/jsonplaceholder_api.dart';
import 'package:kvittra_ovningar/screens/new_post_screen.dart';

void main() {
  testWidgets('visar fel när titeln är tom', (tester) async {
    var called = false;
    final client = MockClient((_) async {
      called = true;
      return http.Response('{}', 201);
    });

    await tester.pumpWidget(MaterialApp(
      home: NewPostScreen(api: JsonPlaceholderApi(client: client), userId: 1),
    ));

    await tester.enterText(find.byKey(const Key('body')), 'Lite text');
    await tester.tap(find.byKey(const Key('save')));
    await tester.pump();

    expect(find.text('Titel krävs'), findsOneWidget);
    expect(find.text('Text krävs'), findsNothing);
    expect(called, isFalse); // inget nätverksanrop när formuläret är ogiltigt
  });
}
```

---

## Reflektion

Ett typiskt resultat för nivå 2–3:

| | Antal |
|---|---|
| `StatefulWidget` + `State`-klasser | 6–7 widgets = 12–14 klasser |
| `dispose`-metoder | 3 (och lätt att glömma en controller) |
| `if (!mounted) return;` / `context.mounted` | 10–12 |
| `setState(() => _state = const Loading())` + `_load()` i en `_retry` | 3, ett per skärm som hämtar data |
| Mönstret "`LoadState`-fält + `initState` + `try`/`catch` + `mounted`" | 3 nästan identiska kopior (flöde, inlägg, profil) |

Det sista är värt att stanna vid: `FeedScreen`, `PostDetailScreen` och
`ProfileScreen` innehåller nästan exakt samma 20 rader för att hämta data. I vanlig
Flutter är det svårt att bryta ut dem, eftersom de är knutna till `State` och
`setState`. Ta med dig siffrorna till
[modul 03 – Flutter Compositions](../03-flutter-compositions/README.md), där samma
logik blir en återanvändbar *composable*.

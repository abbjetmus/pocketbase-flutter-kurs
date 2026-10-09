# Lösningar – Modul 03 Flutter

> Titta här först när du har försökt själv. Det finns alltid flera sätt att lösa en
> uppgift. Om din lösning fungerar och är läsbar är den lika bra.

---

## Nivå 1

### Lösning 1.1 – Lägenheter

```dart
class Apartment {
  const Apartment({
    required this.id,
    required this.number,
    required this.floor,
    required this.sizeSqm,
  });

  final String id;
  final String number;
  final int floor;
  final double sizeSqm;

  factory Apartment.fromJson(Map<String, dynamic> json) => Apartment(
        id: json['id'] as String,
        number: json['number'] as String,
        floor: json['floor'] as int,
        // num täcker både int och double
        sizeSqm: (json['size_sqm'] as num).toDouble(),
      );

  String get label => 'Lgh $number (vån $floor, $sizeSqm m²)';
}

void main() {
  final data = [
    {'id': 'a1', 'number': '1101', 'floor': 1, 'size_sqm': 52},
    {'id': 'a2', 'number': '1102', 'floor': 1, 'size_sqm': 74.5},
    {'id': 'a3', 'number': '1201', 'floor': 2, 'size_sqm': 61},
    {'id': 'a4', 'number': '1202', 'floor': 2, 'size_sqm': 98.5},
  ];

  final apartments = data.map(Apartment.fromJson).toList();

  print('Våning 2:');
  for (final a in apartments.where((a) => a.floor == 2)) {
    print('  ${a.label}');
  }

  final total = apartments.fold(0.0, (sum, a) => sum + a.sizeSqm);
  print('Total yta: $total m²');

  final largest = apartments.reduce((a, b) => a.sizeSqm >= b.sizeSqm ? a : b);
  print('Störst: ${largest.label}');
}
```

💡 `data.map(Apartment.fromJson)` skickar konstruktorn direkt som funktion
("tear-off"). Det är samma sak som `data.map((j) => Apartment.fromJson(j))`.

### Lösning 1.2 – Null safety

```dart
class User {
  User({required this.name, this.apartmentNumber});
  final String name;
  final String? apartmentNumber;
}

String doorSign(User user) {
  final number = user.apartmentNumber;
  if (number == null) {
    return '${user.name} – ingen lägenhet';
  }
  // Här vet Dart att number är en String (inte null)
  return '${user.name} – lgh ${number.toUpperCase()}';
}

// Alternativ med ?. och ??:
String doorSign2(User user) {
  final number = user.apartmentNumber?.toUpperCase();
  return '${user.name} – ${number == null ? 'ingen lägenhet' : 'lgh $number'}';
}

void main() {
  print(doorSign(User(name: 'Anna', apartmentNumber: '1102a')));
  print(doorSign(User(name: 'Styrelsen')));
}
```

⚠️ Varför kopierar vi `user.apartmentNumber` till en lokal variabel? Dart kan
bara "befordra" (promote) **lokala variabler** och privata `final`-fält till
icke-null efter en `if`-kontroll. Ett publikt fält skulle i teorin kunna vara en
getter som returnerar olika värden varje gång. `doorSign2` visar samma idé:
`?.` ger `null` om lägenhetsnummer saknas, och sedan väljer vi text med `?:`.

### Lösning 1.3 – Roller och switch

```dart
enum Role {
  member('Medlem'),
  board('Styrelse'),
  admin('Administratör');

  const Role(this.label);
  final String label;
}

int maxActiveBookings(Role role) => switch (role) {
      Role.member => 2,
      Role.board => 5,
      Role.admin => 99,
    };

void main() {
  for (final role in Role.values) {
    print('${role.label}: ${maxActiveBookings(role)} bokningar');
  }
}
```

Tar du bort `Role.admin => 99` får du kompileringsfelet:

```
The type 'Role' is not exhaustively matched by the switch cases since it doesn't match 'Role.admin'.
```

Det är just poängen: lägger någon till en ny roll senare tvingar kompilatorn dig att
ta ställning på alla ställen där roller hanteras.

### Lösning 1.4 – Layout från skiss

```dart
import 'package:flutter/material.dart';

void main() => runApp(const HomeApp());

class HomeApp extends StatelessWidget {
  const HomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Brf Solgläntan'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.settings)),
        ],
      ),
      // ListView gör att allt kan scrollas om det inte får plats
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Hej Anna!', style: text.headlineSmall),
          Text(
            'Lägenhet 1102',
            style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(
                child: _ResourceSummaryCard(
                  icon: Icons.local_laundry_service,
                  title: 'Tvättstuga',
                  subtitle: 'Nästa: tis 08:00',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _ResourceSummaryCard(
                  icon: Icons.celebration,
                  title: 'Festlokal',
                  subtitle: 'Ingen bokning',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Senaste anslag', style: text.titleMedium),
          const SizedBox(height: 8),
          const _PostTile(
            title: 'Vattenavstängning tisdag',
            body: 'Vattnet stängs av 08–12 i hela hus B på grund av stambyte i källaren.',
          ),
          const _PostTile(
            title: 'Vårstädning 12 april',
            body: 'Samling på gården kl 10. Föreningen bjuder på fika och korv efteråt.',
          ),
        ],
      ),
    );
  }
}

class _ResourceSummaryCard extends StatelessWidget {
  const _ResourceSummaryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colors.primary, size: 32),
            const SizedBox(height: 8),
            Text(title, style: text.titleSmall),
            Text(
              subtitle,
              style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  const _PostTile({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.campaign),
        title: Text(title),
        subtitle: Text(body, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {},
      ),
    );
  }
}
```

Lägg märke till:

- Små privata widgets (`_ResourceSummaryCard`, `_PostTile`) gör `build` i
  `HomeScreen` mycket lättare att läsa än en enda jättemetod.
- `ListView` som `body` ger scroll gratis. En `Column` hade gett overflow i liggande läge.
- `Expanded` på båda korten gör dem lika breda.

---

## Nivå 2

### Lösning 2.1 – Från räknare till bokningsformulär

```dart
import 'package:flutter/material.dart';

void main() => runApp(
      MaterialApp(
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
        home: const QuickBookingScreen(),
      ),
    );

// --- Validators: rena funktioner, lätta att testa -------------------------

String? validateName(String? v) {
  if (v == null || v.trim().isEmpty) return 'Ange ditt namn';
  if (v.trim().length < 2) return 'Minst 2 tecken';
  return null;
}

final _apartmentPattern = RegExp(r'^\d{4}$');

String? validateApartment(String? v) {
  if (v == null || v.isEmpty) return 'Ange lägenhetsnummer';
  if (!_apartmentPattern.hasMatch(v)) return 'Exakt 4 siffror, t.ex. 1102';
  return null;
}

// --- HoursPicker ----------------------------------------------------------

class HoursPicker extends StatelessWidget {
  const HoursPicker({
    super.key,
    required this.hours,
    required this.onChanged,
    this.min = 1,
    this.max = 4,
  });

  final int hours;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Timmar:'),
        const Spacer(),
        IconButton.outlined(
          onPressed: hours > min ? () => onChanged(hours - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('$hours', style: Theme.of(context).textTheme.titleLarge),
        ),
        IconButton.outlined(
          onPressed: hours < max ? () => onChanged(hours + 1) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

// --- Skärmen --------------------------------------------------------------

class QuickBookingScreen extends StatefulWidget {
  const QuickBookingScreen({super.key});

  @override
  State<QuickBookingScreen> createState() => _QuickBookingScreenState();
}

class _QuickBookingScreenState extends State<QuickBookingScreen> {
  static const _resources = ['Tvättstuga 1', 'Tvättstuga 2', 'Festlokalen'];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _apartmentController = TextEditingController();

  int _hours = 1;
  String? _resource;
  DateTime? _date;
  bool _showDateError = false;

  @override
  void dispose() {
    _nameController.dispose();
    _apartmentController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 14)),
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
    setState(() => _showDateError = _date == null);
    if (!formOk || _date == null) return;

    final summary = '${_nameController.text.trim()} (${_apartmentController.text}) '
        'bokade $_resource den ${_formatDate(_date!)} i $_hours h';

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(summary)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Snabbokning')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Namn',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: validateName,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _apartmentController,
              decoration: const InputDecoration(
                labelText: 'Lägenhetsnummer',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              maxLength: 4,
              validator: validateApartment,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _resource,
              decoration: const InputDecoration(
                labelText: 'Resurs',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final r in _resources)
                  DropdownMenuItem(value: r, child: Text(r)),
              ],
              onChanged: (v) => setState(() => _resource = v),
              validator: (v) => v == null ? 'Välj en resurs' : null,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today),
              label: Text(_date == null ? 'Välj datum' : _formatDate(_date!)),
            ),
            if (_showDateError)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 12),
                child: Text(
                  'Välj ett datum',
                  style: TextStyle(color: colors.error, fontSize: 12),
                ),
              ),
            const SizedBox(height: 16),
            HoursPicker(
              hours: _hours,
              onChanged: (h) => setState(() => _hours = h),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _submit, child: const Text('Boka')),
          ],
        ),
      ),
    );
  }
}
```

Designval:

- `HoursPicker` är **stateless**. State (`_hours`) är lyft upp till formuläret,
  eftersom formuläret behöver värdet vid "Boka". Det är "lyfta state uppåt" från
  kapitel 03.
- Validators ligger utanför widgeten som vanliga funktioner.
- Datumfelet visas med collection-if (`if (_showDateError) ...`) och temats
  `error`-färg.

### Lösning 2.2 – Lista med navigation till detalj

```dart
import 'package:flutter/material.dart';

void main() => runApp(
      MaterialApp(
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo)),
        home: const ResourceListScreen(),
      ),
    );

class Resource {
  const Resource({
    required this.id,
    required this.name,
    required this.description,
    required this.maxHours,
    this.active = true,
  });

  final String id;
  final String name;
  final String description;
  final int maxHours;
  final bool active;
}

const resources = [
  Resource(id: 't1', name: 'Tvättstuga 1', description: 'Källaren, hus A', maxHours: 3),
  Resource(id: 't2', name: 'Tvättstuga 2', description: 'Källaren, hus B', maxHours: 3),
  Resource(id: 'f', name: 'Festlokalen', description: 'Plan 1, 40 platser', maxHours: 8),
  Resource(id: 'g', name: 'Gästlägenheten', description: 'Två bäddar', maxHours: 24),
  Resource(
    id: 'b',
    name: 'Bastun',
    description: 'Stängd för renovering',
    maxHours: 2,
    active: false,
  ),
];

// --- Lista ----------------------------------------------------------------

class ResourceListScreen extends StatelessWidget {
  const ResourceListScreen({super.key});

  Future<void> _open(BuildContext context, Resource resource) async {
    final hours = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => ResourceDetailScreen(resource: resource)),
    );
    if (hours == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Du bokade ${resource.name} i $hours h')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resurser')),
      body: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: resources.length,
        itemBuilder: (context, i) {
          final r = resources[i];
          return Card(
            child: ListTile(
              enabled: r.active, // gråar ut och inaktiverar onTap
              leading: const Icon(Icons.meeting_room),
              title: Text(r.name),
              subtitle: Text(r.active ? r.description : 'Ej bokningsbar'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(context, r),
            ),
          );
        },
      ),
    );
  }
}

// --- Detalj ---------------------------------------------------------------

class ResourceDetailScreen extends StatelessWidget {
  const ResourceDetailScreen({super.key, required this.resource});

  final Resource resource;

  Future<void> _book(BuildContext context) async {
    final hours = await showDialog<int>(
      context: context,
      builder: (_) => HoursDialog(maxHours: resource.maxHours),
    );
    if (hours == null || !context.mounted) return;
    Navigator.of(context).pop(hours); // stäng detaljskärmen med resultatet
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(resource.name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(resource.description, style: text.bodyLarge),
            const SizedBox(height: 8),
            Text('Max ${resource.maxHours} timmar per bokning', style: text.bodyMedium),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => _book(context),
              icon: const Icon(Icons.event_available),
              label: const Text('Boka'),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Dialog med eget state ------------------------------------------------

class HoursDialog extends StatefulWidget {
  const HoursDialog({super.key, required this.maxHours});
  final int maxHours;

  @override
  State<HoursDialog> createState() => _HoursDialogState();
}

class _HoursDialogState extends State<HoursDialog> {
  int _hours = 1;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hur länge?'),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _hours > 1 ? () => setState(() => _hours--) : null,
            icon: const Icon(Icons.remove),
          ),
          Text('$_hours h', style: Theme.of(context).textTheme.headlineSmall),
          IconButton(
            onPressed: _hours < widget.maxHours ? () => setState(() => _hours++) : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Avbryt'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_hours),
          child: const Text('Bekräfta'),
        ),
      ],
    );
  }
}
```

Flödet av resultat: `HoursDialog` → `pop(_hours)` → `ResourceDetailScreen._book`
→ `pop(hours)` → `ResourceListScreen._open` → `SnackBar`. Varje `await` följs av en
`context.mounted`-kontroll.

⚠️ Varför är `HoursDialog` en egen `StatefulWidget`? En dialog byggs av sin egen
`builder`, och ett `setState` i `ResourceDetailScreen` (som dessutom är stateless)
skulle inte bygga om dialogen.

### Lösning 2.3 – Sök och filtrera

Ersätt `ResourceListScreen` i 2.2 med:

```dart
class ResourceListScreen extends StatefulWidget {
  const ResourceListScreen({super.key});

  @override
  State<ResourceListScreen> createState() => _ResourceListScreenState();
}

class _ResourceListScreenState extends State<ResourceListScreen> {
  final _search = TextEditingController();
  bool _onlyActive = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearch);
  }

  void _onSearch() => setState(() {});

  @override
  void dispose() {
    _search.removeListener(_onSearch);
    _search.dispose();
    super.dispose();
  }

  List<Resource> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return resources
        .where((r) => !_onlyActive || r.active)
        .where((r) => r.name.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _open(Resource resource) async {
    final hours = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => ResourceDetailScreen(resource: resource)),
    );
    if (hours == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Du bokade ${resource.name} i $hours h')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return Scaffold(
      appBar: AppBar(title: const Text('Resurser')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Sök resurs',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                label: const Text('Visa bara aktiva'),
                selected: _onlyActive,
                onSelected: (v) => setState(() => _onlyActive = v),
              ),
            ),
          ),
          Expanded( // ListView i Column kräver Expanded!
            child: items.isEmpty
                ? const Center(child: Text('Inga träffar'))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final r = items[i];
                      return ListTile(
                        key: ValueKey(r.id),
                        enabled: r.active,
                        title: Text(r.name),
                        subtitle: Text(r.description),
                        onTap: () => _open(r),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
```

Svar på frågorna: State (söktext och filter) ligger i listskärmen, eftersom det är
den som filtrerar. `TextEditingController` måste `dispose`:as, och lyssnaren tas
bort först. `_filtered` räknas om vid **varje** `build`. Det är billigt här, men
värt att notera. I modul 04 blir det ett `computed`.

---

## Nivå 3

Lösningen använder PocketBase via `http` (alternativ A). Kommentarer visar vad som
ändras för jsonplaceholder (alternativ B).

### Lösning 3.1 – Hämta anslag

**`lib/models/post.dart`**

```dart
class Post {
  const Post({
    required this.id,
    required this.title,
    required this.body,
    required this.created,
  });

  final String id;
  final String title;
  final String body;
  final DateTime? created;

  factory Post.fromJson(Map<String, dynamic> json) => Post(
        // jsonplaceholder: id är en int, så vi gör om till sträng
        id: json['id'].toString(),
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        created: DateTime.tryParse(json['created'] as String? ?? ''),
      );
}
```

**`lib/models/load_state.dart`**

```dart
sealed class LoadState<T> {
  const LoadState();
}

class Loading<T> extends LoadState<T> {
  const Loading();
}

class Loaded<T> extends LoadState<T> {
  const Loaded(this.data);
  final T data;
}

class Failed<T> extends LoadState<T> {
  const Failed(this.message);
  final String message;
}
```

**`lib/repositories/post_repository.dart`**

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/post.dart';

class PostException implements Exception {
  PostException(this.message);
  final String message;

  @override
  String toString() => message;
}

class PostRepository {
  PostRepository({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        // Android-emulator: 'http://10.0.2.2:8090'
        _baseUrl = baseUrl ?? 'http://127.0.0.1:8090';

  final http.Client _client;
  final String _baseUrl;

  Uri get _postsUri => Uri.parse('$_baseUrl/api/collections/posts/records');

  Future<List<Post>> fetchPosts() async {
    final uri = _postsUri.replace(queryParameters: {
      'filter': 'published = true',
      'sort': '-created',
    });

    final http.Response res;
    try {
      res = await _client.get(uri).timeout(const Duration(seconds: 10));
    } on Exception {
      throw PostException('Kunde inte nå servern');
    }

    if (res.statusCode != 200) {
      throw PostException('Servern svarade med status ${res.statusCode}');
    }

    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    // PocketBase: { "items": [...] }   jsonplaceholder: [...]
    final items = switch (decoded) {
      {'items': List<dynamic> list} => list,
      List<dynamic> list => list,
      _ => throw PostException('Oväntat svar från servern'),
    };
    return items.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Post> createPost({required String title, required String body}) async {
    final res = await _client.post(
      _postsUri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'title': title, 'body': body, 'published': true}),
    );
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw PostException(json['message'] as String? ?? 'Kunde inte spara');
    }
    return Post.fromJson(json);
  }
}
```

Lägg märke till `switch`-uttrycket med patterns som klarar båda JSON-formaten.

**`lib/screens/post_list_screen.dart`**

```dart
import 'package:flutter/material.dart';

import '../models/load_state.dart';
import '../models/post.dart';
import '../repositories/post_repository.dart';
import 'post_detail_screen.dart';
import 'post_form_screen.dart';

class PostListScreen extends StatefulWidget {
  const PostListScreen({super.key, required this.repository});

  final PostRepository repository;

  @override
  State<PostListScreen> createState() => _PostListScreenState();
}

class _PostListScreenState extends State<PostListScreen> {
  LoadState<List<Post>> _state = const Loading();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final posts = await widget.repository.fetchPosts();
      if (!mounted) return;
      setState(() => _state = Loaded(posts));
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = Failed(e.toString()));
    }
  }

  void _retry() {
    setState(() => _state = const Loading());
    _load();
  }

  Future<void> _create() async {
    final post = await Navigator.of(context).push<Post>(
      MaterialPageRoute(
        builder: (_) => PostFormScreen(repository: widget.repository),
      ),
    );
    if (post == null || !mounted) return;
    // Lägg in först utan att hämta om allt
    if (_state case Loaded(:final data)) {
      setState(() => _state = Loaded([post, ...data]));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Anslag')),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        child: const Icon(Icons.add),
      ),
      body: switch (_state) {
        Loading() => const Center(child: CircularProgressIndicator()),
        Failed(:final message) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 48),
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _retry, child: const Text('Försök igen')),
                ],
              ),
            ),
          ),
        Loaded(:final data) => RefreshIndicator(
            onRefresh: _load,
            child: data.isEmpty
                // ListView även när tomt, så att man kan dra för att uppdatera
                ? ListView(children: const [
                    SizedBox(height: 200),
                    Center(child: Text('Inga anslag ännu')),
                  ])
                : ListView.separated(
                    itemCount: data.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final post = data[i];
                      return ListTile(
                        key: ValueKey(post.id),
                        title: Text(post.title),
                        subtitle: Text(
                          post.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PostDetailScreen(post: post),
                          ),
                        ),
                      );
                    },
                  ),
          ),
      },
    );
  }
}
```

**`lib/screens/post_detail_screen.dart`**

```dart
import 'package:flutter/material.dart';

import '../models/post.dart';

class PostDetailScreen extends StatelessWidget {
  const PostDetailScreen({super.key, required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final created = post.created;
    return Scaffold(
      appBar: AppBar(title: const Text('Anslag')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(post.title, style: text.headlineSmall),
          if (created != null) ...[
            const SizedBox(height: 4),
            Text(
              '${created.year}-${created.month.toString().padLeft(2, '0')}-'
              '${created.day.toString().padLeft(2, '0')}',
              style: text.labelMedium,
            ),
          ],
          const SizedBox(height: 16),
          Text(post.body, style: text.bodyLarge),
        ],
      ),
    );
  }
}
```

**`lib/main.dart`**

```dart
import 'package:flutter/material.dart';

import 'repositories/post_repository.dart';
import 'screens/post_list_screen.dart';

void main() {
  final repository = PostRepository();
  runApp(MaterialApp(
    title: 'Föreningen',
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.green)),
    home: PostListScreen(repository: repository),
  ));
}
```

💡 Repositoryt skapas i `main` och skickas in. Det gör att testerna i 3.3 kan
skicka in ett med `MockClient`.

### Lösning 3.2 – Skapa anslag

**`lib/screens/post_form_screen.dart`**

```dart
import 'package:flutter/material.dart';

import '../repositories/post_repository.dart';

class PostFormScreen extends StatefulWidget {
  const PostFormScreen({super.key, required this.repository});

  final PostRepository repository;

  @override
  State<PostFormScreen> createState() => _PostFormScreenState();
}

class _PostFormScreenState extends State<PostFormScreen> {
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
      final post = await widget.repository.createPost(
        title: _title.text.trim(),
        body: _body.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(post);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kunde inte spara: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nytt anslag')),
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
              minLines: 4,
              maxLines: 10,
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

⚠️ För att `POST` ska fungera utan inloggning måste *create rule* för `posts` vara
öppen i PocketBase, och fältet `author` får inte vara obligatoriskt. I en riktig app
loggar man in först (se kapitel 05 och modul 02).

### Lösning 3.3 – Tester

**`test/post_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:forening_app/models/post.dart';

void main() {
  test('fromJson med komplett PocketBase-data', () {
    final post = Post.fromJson({
      'id': 'abc',
      'title': 'Vårstädning',
      'body': 'Lördag kl 10',
      'created': '2026-04-01 10:00:00.000Z',
    });
    expect(post.id, 'abc');
    expect(post.title, 'Vårstädning');
    expect(post.created?.day, 1);
  });

  test('fromJson med saknade fält och int-id', () {
    final post = Post.fromJson({'id': 7});
    expect(post.id, '7');
    expect(post.title, '');
    expect(post.created, isNull);
  });
}
```

**`test/post_repository_test.dart`**

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:forening_app/repositories/post_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('fetchPosts tolkar PocketBase-format', () async {
    final client = MockClient((_) async => http.Response(
          jsonEncode({
            'items': [
              {'id': '1', 'title': 'Hej', 'body': 'Text'},
            ],
          }),
          200,
        ));
    final posts = await PostRepository(client: client).fetchPosts();
    expect(posts.single.title, 'Hej');
  });

  test('fetchPosts kastar PostException vid 500', () {
    final client = MockClient((_) async => http.Response('Server error', 500));
    expect(
      PostRepository(client: client).fetchPosts(),
      throwsA(isA<PostException>()),
    );
  });
}
```

**`test/post_form_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forening_app/repositories/post_repository.dart';
import 'package:forening_app/screens/post_form_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('visar fel när titeln är tom', (tester) async {
    var called = false;
    final client = MockClient((_) async {
      called = true;
      return http.Response('{}', 200);
    });

    await tester.pumpWidget(MaterialApp(
      home: PostFormScreen(repository: PostRepository(client: client)),
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
| `StatefulWidget` + `State`-klasser | 5 widgets = 10 klasser |
| `dispose`-metoder | 3 (och lätt att glömma en controller) |
| `if (!mounted) return;` / `context.mounted` | 7–8 |
| `setState(() {})` bara för ombyggnad | 1–2 |

Ta med dig siffrorna till [modul 04 – Flutter Compositions](../04-flutter-compositions/README.md).

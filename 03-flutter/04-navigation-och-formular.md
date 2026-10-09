# 04 – Navigation och formulär

En riktig app har flera skärmar: en lista med resurser, en detaljsida, ett
bokningsformulär. I det här kapitlet lär du dig att navigera mellan dem, skicka
data fram och tillbaka och bygga formulär med validering.

## Navigator: en stack av skärmar

Flutters inbyggda `Navigator` fungerar som en **stack** (en hög med tallrikar):

- `push` lägger en ny skärm överst,
- `pop` tar bort den översta och visar den under.

```
push(Detalj)        push(Formulär)        pop()
┌──────────┐        ┌──────────┐          ┌──────────┐
│          │        │ Formulär │          │          │
│          │        │ Detalj   │          │ Detalj   │
│ Lista    │ ──►    │ Lista    │   ──►    │ Lista    │
└──────────┘        └──────────┘          └──────────┘
```

```dart
// Gå till en ny skärm
Navigator.of(context).push(
  MaterialPageRoute(builder: (context) => const ResourceDetailScreen()),
);

// Gå tillbaka (samma som tillbakapilen i AppBar)
Navigator.of(context).pop();
```

`Scaffold` med en `AppBar` lägger automatiskt till en tillbakapil när det finns en
skärm att gå tillbaka till. På Android fungerar även systemets bakåtknapp/gest.

### Skicka data till en skärm

Data skickas helt enkelt via **konstruktorn**:

```dart
class ResourceDetailScreen extends StatelessWidget {
  const ResourceDetailScreen({super.key, required this.resource});
  final Resource resource;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(resource.name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(resource.description),
      ),
    );
  }
}

// I listan:
ListTile(
  title: Text(resource.name),
  onTap: () => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => ResourceDetailScreen(resource: resource),
    ),
  ),
)
```

### Få tillbaka ett resultat

`push` returnerar en `Future` som blir klar när skärmen poppas. Värdet du skickar
till `pop` blir resultatet:

```dart
// Skärm A: öppna formuläret och vänta på svar
Future<void> _openBookingForm() async {
  final booking = await Navigator.of(context).push<Booking>(
    MaterialPageRoute(builder: (context) => const BookingFormScreen()),
  );
  if (!mounted) return;
  if (booking != null) {
    setState(() => _bookings.add(booking));
  }
}

// Skärm B: stäng och skicka tillbaka en bokning
Navigator.of(context).pop(newBooking);
```

Resultatet är alltid nullbart (`Booking?`), eftersom användaren kan trycka på
tillbaka utan att spara.

## go_router: navigation med URL:er

`Navigator.push` räcker långt i små appar. Men när appen växer vill man ofta ha:

- **namngivna sökvägar** (`/resources/abc123`) i stället för konstruktoranrop överallt,
- **djuplänkar**: en länk i ett mejl eller en push-notis öppnar rätt skärm direkt,
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
      builder: (context, state) => const ResourceListScreen(),
      routes: [
        // Nästlad route: /resources/:id
        GoRoute(
          path: 'resources/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return ResourceDetailScreen(resourceId: id);
          },
          routes: [
            // /resources/:id/book
            GoRoute(
              path: 'book',
              builder: (context, state) => BookingFormScreen(
                resourceId: state.pathParameters['id']!,
              ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/posts',
      builder: (context, state) {
        // Query-parameter: /posts?q=vatten
        final query = state.uri.queryParameters['q'] ?? '';
        return PostListScreen(initialQuery: query);
      },
    ),
  ],
);

void main() {
  runApp(MaterialApp.router(
    routerConfig: router,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.green)),
  ));
}
```

Lägg märke till `MaterialApp.router` i stället för `MaterialApp(home: ...)`.

### Navigera med go_router

`go_router` lägger till extension-metoder på `context`:

```dart
context.go('/resources/abc123');       // byt plats – stacken byggs om efter URL:en
context.push('/resources/abc123/book'); // lägg ovanpå nuvarande skärm
context.pop();                          // tillbaka
context.pop(result);                    // tillbaka med resultat

final booking = await context.push<Booking>('/resources/abc123/book');
```

| | `context.go` | `context.push` |
|---|---|---|
| Vad händer | Navigerar till sökvägen. Stacken blir det som route-trädet säger | Lägger skärmen överst på nuvarande stack |
| Typiskt för | Flikbyten, djuplänkar, efter inloggning | "Öppna detalj", formulär som ska returnera något |
| Tillbakapil | Bara om sökvägen är nästlad (t.ex. `/resources/:id` under `/`) | Ja, alltid |

⚠️ **Varning:** Skicka helst **id:n** i sökvägen och hämta objektet på
målskärmen, inte hela objekt. Det finns `extra: resource` för att skicka objekt,
men det överlever inte en djuplänk eller en omladdning på webben.

💡 **Tips:** `go_router` har också `redirect`, som används för att skicka
utloggade användare till `/login`. Det visas i modul 04 (Flutter Compositions).

## Dialoger, bottom sheets och SnackBar

Dialoger och bottom sheets är också routes. De visas med en funktion som
returnerar en `Future` med resultatet.

### AlertDialog

```dart
Future<void> _confirmDelete(Booking booking) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Avboka?'),
      content: Text('Vill du avboka ${booking.resourceName}?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Nej'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Ja, avboka'),
        ),
      ],
    ),
  );

  if (ok == true) {
    // ok kan vara null om användaren tryckte utanför dialogen
    _deleteBooking(booking);
  }
}
```

### Bottom sheet

```dart
showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.edit),
          title: const Text('Ändra bokning'),
          onTap: () => Navigator.of(context).pop(),
        ),
        ListTile(
          leading: const Icon(Icons.delete),
          title: const Text('Avboka'),
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  ),
);
```

### SnackBar

En kort bekräftelse längst ner på skärmen:

```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: const Text('Bokningen är sparad'),
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
String? validateNote(String? value) {
  if (value != null && value.length > 100) {
    return 'Max 100 tecken';
  }
  return null; // OK
}

String? validateRequired(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Fältet måste fyllas i';
  }
  return null;
}
```

```dart
TextFormField(
  controller: _noteController,
  decoration: const InputDecoration(
    labelText: 'Notering',
    hintText: 'T.ex. "Födelsedagsfest"',
    border: OutlineInputBorder(),
    prefixIcon: Icon(Icons.notes),
  ),
  maxLines: 3,
  validator: validateNote,
  textInputAction: TextInputAction.done,
)
```

💡 **Tips:** Validators är vanliga Dart-funktioner. Lägg dem i en egen fil så kan
du enhetstesta dem enkelt (kapitel 06).

### DropdownButtonFormField

En rullgardinsmeny som också är ett formulärfält:

```dart
DropdownButtonFormField<String>(
  initialValue: _resourceId,
  decoration: const InputDecoration(
    labelText: 'Resurs',
    border: OutlineInputBorder(),
  ),
  items: const [
    DropdownMenuItem(value: 'tvatt1', child: Text('Tvättstuga 1')),
    DropdownMenuItem(value: 'tvatt2', child: Text('Tvättstuga 2')),
    DropdownMenuItem(value: 'fest', child: Text('Festlokalen')),
  ],
  onChanged: (value) => setState(() => _resourceId = value),
  validator: (value) => value == null ? 'Välj en resurs' : null,
)
```

⚠️ **Varning:** I Flutter-versioner före 3.35 heter parametern `value` i stället
för `initialValue`. Ser du en varning om `value` som "deprecated" är det den som
ska bytas.

### Datum- och tidsväljare

`showDatePicker` och `showTimePicker` öppnar Material-dialoger och returnerar det
valda värdet, eller `null` om användaren avbröt.

```dart
Future<void> _pickDate() async {
  final now = DateTime.now();
  final picked = await showDatePicker(
    context: context,
    initialDate: _date ?? now,
    firstDate: now,                              // inte bakåt i tiden
    lastDate: now.add(const Duration(days: 60)), // max två månader fram
  );
  if (picked != null) setState(() => _date = picked);
}

Future<void> _pickTime() async {
  final picked = await showTimePicker(
    context: context,
    initialTime: _startTime ?? const TimeOfDay(hour: 8, minute: 0),
  );
  if (picked != null) setState(() => _startTime = picked);
}
```

`TimeOfDay` innehåller bara timme och minut. Kombinera med datumet för att få en
`DateTime`:

```dart
final start = DateTime(_date!.year, _date!.month, _date!.day,
    _startTime!.hour, _startTime!.minute);
```

💡 **Tips:** För svenska månadsnamn och veckor som börjar på måndag, lägg till
`flutter_localizations` och ställ in `locale: const Locale('sv')` i `MaterialApp`.
Se <https://docs.flutter.dev/ui/accessibility-and-internationalization/internationalization>.

## Helt exempel: bokningsformulär

Nu sätter vi ihop allt till en skärm där man bokar en resurs. Formuläret
returnerar en `Booking` till föregående skärm med `Navigator.pop`.

```dart
import 'package:flutter/material.dart';

class Booking {
  const Booking({
    required this.resourceId,
    required this.start,
    required this.end,
    this.note,
  });

  final String resourceId;
  final DateTime start;
  final DateTime end;
  final String? note;
}

class BookingFormScreen extends StatefulWidget {
  const BookingFormScreen({super.key, this.initialResourceId});

  final String? initialResourceId;

  @override
  State<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends State<BookingFormScreen> {
  static const _resources = {
    'tvatt1': ('Tvättstuga 1', 3),
    'tvatt2': ('Tvättstuga 2', 3),
    'fest': ('Festlokalen', 8),
  };

  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();

  String? _resourceId;
  DateTime? _date;
  TimeOfDay? _startTime;
  int _hours = 1;

  @override
  void initState() {
    super.initState();
    _resourceId = widget.initialResourceId;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  // Max-timmar för vald resurs (3 om ingen är vald än)
  int get _maxHours => _resources[_resourceId]?.$2 ?? 3;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 60)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null) setState(() => _startTime = picked);
  }

  void _submit() {
    // validate() kör alla validators och visar felmeddelanden
    final formOk = _formKey.currentState!.validate();
    if (!formOk || _date == null || _startTime == null) {
      if (_date == null || _startTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Välj datum och starttid')),
        );
      }
      return;
    }

    final start = DateTime(_date!.year, _date!.month, _date!.day,
        _startTime!.hour, _startTime!.minute);

    if (start.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Starttiden har redan passerat')),
      );
      return;
    }

    final note = _noteController.text.trim();
    final booking = Booking(
      resourceId: _resourceId!,
      start: start,
      end: start.add(Duration(hours: _hours)),
      note: note.isEmpty ? null : note,
    );

    Navigator.of(context).pop(booking); // skicka tillbaka resultatet
  }

  @override
  Widget build(BuildContext context) {
    final dateText = _date == null
        ? 'Välj datum'
        : '${_date!.year}-${_date!.month.toString().padLeft(2, '0')}-'
            '${_date!.day.toString().padLeft(2, '0')}';
    final timeText =
        _startTime == null ? 'Välj starttid' : _startTime!.format(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Ny bokning')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _resourceId,
              decoration: const InputDecoration(
                labelText: 'Resurs',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final MapEntry(:key, :value) in _resources.entries)
                  DropdownMenuItem(value: key, child: Text(value.$1)),
              ],
              onChanged: (value) => setState(() {
                _resourceId = value;
                _hours = _hours.clamp(1, _maxHours); // ny resurs kan ha lägre max
              }),
              validator: (value) => value == null ? 'Välj en resurs' : null,
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            Text('Antal timmar: $_hours (max $_maxHours)'),
            Slider(
              value: _hours.toDouble(),
              min: 1,
              max: _maxHours.toDouble(),
              divisions: _maxHours - 1, // ett steg per timme
              label: '$_hours h',
              onChanged: (v) => setState(() => _hours = v.round()),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Notering (valfri)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (v) =>
                  (v != null && v.length > 100) ? 'Max 100 tecken' : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submit,
              child: const Text('Boka'),
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
- Records (`('Tvättstuga 1', 3)`) används som en enkel tabell över resurser och
  deras max-timmar. Pattern-destruktureringen `MapEntry(:key, :value)` plockar ut
  nyckel och värde.
- `_noteController` skapas och `dispose`:as, som vi lärde oss i kapitel 03.
- `Slider` arbetar med `double`, så vi konverterar med `toDouble()` och `round()`.
  `divisions` gör att reglaget hoppar i hela timmar. (Om en resurs hade
  `max_hours == 1` skulle `min == max` och reglaget krascha. Sådana gränsfall är
  vanliga i UI-kod.)

💡 **Tips:** Sätt `autovalidateMode: AutovalidateMode.onUserInteraction` på `Form`
om du vill att fel ska visas direkt medan användaren skriver, och inte först när
hen trycker på "Boka".

### Använd formuläret

```dart
class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final List<Booking> _bookings = [];

  Future<void> _newBooking() async {
    final booking = await Navigator.of(context).push<Booking>(
      MaterialPageRoute(builder: (_) => const BookingFormScreen()),
    );
    if (booking == null || !mounted) return;
    setState(() => _bookings.add(booking));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bokningen är sparad')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mina bokningar')),
      body: ListView(
        children: [
          for (final b in _bookings)
            ListTile(
              title: Text(b.resourceId),
              subtitle: Text('${b.start} – ${b.end}'),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _newBooking,
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

🧪 **Prova själv:**

1. Lägg till ett `TextFormField` för "Antal gäster" som bara visas när resursen är
   festlokalen (collection-if!). Validera att det är ett heltal mellan 1 och 40
   (`int.tryParse`).
2. Gör om navigationen till `go_router` med sökvägarna `/`, `/bookings/new` och
   `/bookings/new?resource=fest`, där query-parametern förväljer resurs.
3. Visa en bekräftelsedialog ("Vill du boka Festlokalen den 2026-03-20 kl 17:00?")
   innan formuläret stängs.

**Nästa kapitel:** [05 – Async och nätverk](05-async-och-natverk.md)

# 06 – Dart-SDK

I kapitel 5 pratade vi med PocketBase via `curl`. I Flutter-appen vill vi
slippa bygga URL:er, sätta headers och tolka JSON för hand. Det sköter det
officiella Dart-paketet [`pocketbase`](https://pub.dev/packages/pocketbase).

Du kommer att köra koden på riktigt i modul 03–04. Läs kapitlet nu och känn
igen sambanden med det du gjort med curl. Exemplen fungerar också som vanliga
Dart-program (`dart run`), så du kan prova dem redan nu om du har Dart
installerat.

## Installation

I ett Flutter-projekt:

```bash
flutter pub add pocketbase
```

eller i ett rent Dart-projekt:

```bash
dart pub add pocketbase
```

I `pubspec.yaml` ser det ut ungefär så här:

```yaml
dependencies:
  pocketbase: ^0.23.0   # eller senare
```

⚠️ **Varning:** PocketBase-servern v0.23+ kräver Dart-paketet **0.23 eller
senare**. Äldre exempel på nätet använder `pb.authStore.model`,
`getStringValue` på fel sätt eller `UserModel` – de är för gamla versioner.
Observera också att `^0.23.0` i Dart betyder "0.23.x" (för 0.x-versioner låser
`^` minor-versionen). `flutter pub add` väljer den senaste versionen åt dig.

## Skapa klienten

```dart
import 'package:pocketbase/pocketbase.dart';

final pb = PocketBase('http://127.0.0.1:8090');
```

Skapa **en** instans för hela appen och återanvänd den. Den håller reda på
inloggningen och realtidsanslutningen.

| Var körs appen? | Adress till PocketBase på din dator |
|-----------------|-------------------------------------|
| iOS-simulator, macOS, webb | `http://127.0.0.1:8090` |
| Android-emulator | `http://10.0.2.2:8090` |
| Fysisk telefon på samma wifi | `http://<datorns IP>:8090` och starta med `--http=0.0.0.0:8090` |

## Mappning från curl till SDK

| curl (kapitel 5) | Dart-SDK |
|------------------|----------|
| `POST .../users/auth-with-password` | `pb.collection('users').authWithPassword(email, pw)` |
| `GET .../records?page=1&perPage=20` | `pb.collection('x').getList(page: 1, perPage: 20)` |
| `GET .../records` (alla sidor) | `pb.collection('x').getFullList()` |
| `GET .../records/{id}` | `pb.collection('x').getOne(id)` |
| `POST .../records` | `pb.collection('x').create(body: {...})` |
| `PATCH .../records/{id}` | `pb.collection('x').update(id, body: {...})` |
| `DELETE .../records/{id}` | `pb.collection('x').delete(id)` |
| Header `Authorization: $TOKEN` | Sköts automatiskt via `pb.authStore` |
| `GET /api/realtime` + `POST` | `pb.collection('x').subscribe('*', callback)` |

## Inloggning

```dart
Future<void> login(String email, String password) async {
  final auth = await pb.collection('users').authWithPassword(email, password);

  print(auth.token);                          // token (sparas automatiskt)
  print(auth.record.id);                      // Annas id
  print(auth.record.getStringValue('name'));  // "Anna"
}
```

Efter inloggning skickar SDK:n token i alla anrop automatiskt.

### authStore

`pb.authStore` håller koll på vem som är inloggad:

| Egenskap / metod | Betyder |
|------------------|---------|
| `pb.authStore.isValid` | `true` om det finns en token som inte gått ut |
| `pb.authStore.token` | Själva token |
| `pb.authStore.record` | Den inloggade användarens post (`RecordModel?`) |
| `pb.authStore.onChange` | En `Stream` som skickar ett event vid inloggning/utloggning |
| `pb.authStore.clear()` | Logga ut (glömmer token) |

```dart
bool get isLoggedIn => pb.authStore.isValid;

String? get myId => pb.authStore.record?.id;

String get myRole => pb.authStore.record?.getStringValue('role') ?? 'member';

void logout() => pb.authStore.clear();
```

### Förnya token

Token går ut efter några dagar. Förnya den när appen startar:

```dart
Future<void> refreshIfNeeded() async {
  if (!pb.authStore.isValid) return;
  try {
    await pb.collection('users').authRefresh();
  } on ClientException {
    pb.authStore.clear(); // token ogiltig, t.ex. lösenordet byttes
  }
}
```

`authRefresh` ger också en uppdaterad `record` – t.ex. om styrelsen ändrat din
roll.

### Kom ihåg inloggningen mellan app-starter

Standard-`AuthStore` ligger bara i minnet. Med `AsyncAuthStore` och paketet
`shared_preferences` sparas inloggningen på telefonen:

```dart
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<PocketBase> createPocketBase() async {
  final prefs = await SharedPreferences.getInstance();

  final store = AsyncAuthStore(
    save: (String data) async => prefs.setString('pb_auth', data),
    initial: prefs.getString('pb_auth'),
    clear: () async => prefs.remove('pb_auth'),
  );

  return PocketBase('http://127.0.0.1:8090', authStore: store);
}
```

💡 **Tips:** För extra säkerhet kan du spara token med
`flutter_secure_storage` i stället för `shared_preferences`. Principen är
densamma.

## Läsa data

### getList – en sida

```dart
final result = await pb.collection('bookings').getList(
  page: 1,
  perPage: 20,
  filter: 'start >= @now',
  sort: 'start',
  expand: 'resource,user',
);

print(result.page);        // 1
print(result.totalItems);  // t.ex. 42
for (final record in result.items) {
  print(record.id);
}
```

`result` är en `ResultList<RecordModel>` med `page`, `perPage`, `totalItems`,
`totalPages` och `items`.

### getFullList – alla poster

```dart
final resources = await pb.collection('resources').getFullList(
  filter: 'active = true',
  sort: 'name',
);
```

SDK:n hämtar sida efter sida (1000 åt gången som standard) tills allt är
hämtat. Bra för små listor som resurser. **Använd inte** för bokningar eller
anslag som växer hela tiden – där är `getList` med paginering rätt.

### getOne och getFirstListItem

```dart
final resource = await pb.collection('resources').getOne('yj5nd2n7f6ckups');

// Första posten som matchar ett filter (kastar 404 om ingen finns)
final laundry = await pb.collection('resources').getFirstListItem(
  'name = "Tvättstuga 1"',
);
```

## Filter med parametrar – `pb.filter`

Anta att användaren skriver in en sökterm. Det är frestande att bygga filtret
med strängsammanfogning:

```dart
// ⚠️ GÖR INTE SÅ HÄR
final filter = 'title ~ "$search"';
```

Om `search` innehåller ett citattecken, t.ex. `Annas "fest"`, går filtret
sönder. Värre: någon kan skriva `" || published = false || title ~ "` och
ändra filtrets betydelse. Det är samma problem som **SQL-injektion** i modul 01.

Använd i stället `pb.filter` med namngivna platshållare `{:namn}`:

```dart
final result = await pb.collection('posts').getList(
  filter: pb.filter(
    'published = true && (title ~ {:q} || body ~ {:q})',
    {'q': search},
  ),
  sort: '-created',
);
```

`pb.filter` sätter citattecken och escapar värdena åt dig. Den klarar
`String`, `num`, `bool`, `null` och **`DateTime`**:

```dart
// Annas bokningar från idag (lokal tid) och framåt
final now = DateTime.now();
final startOfToday = DateTime(now.year, now.month, now.day); // lokal midnatt

final result = await pb.collection('bookings').getList(
  filter: pb.filter(
    'user = {:user} && start >= {:from}',
    {'user': pb.authStore.record!.id, 'from': startOfToday},
  ),
  sort: 'start',
);
```

`DateTime` konverteras automatiskt till UTC i PocketBase-format. Det löser
UTC-problemet från kapitel 5: du räknar i lokal tid, SDK:n översätter.

### Kolla om en tid är ledig

```dart
Future<bool> isSlotFree(String resourceId, DateTime start, DateTime end) async {
  final result = await pb.collection('bookings').getList(
    perPage: 1,
    skipTotal: true,
    filter: pb.filter(
      'resource = {:r} && start < {:end} && end > {:start}',
      {'r': resourceId, 'start': start, 'end': end},
    ),
  );
  return result.items.isEmpty;
}
```

⚠️ **Varning:** Den här kontrollen är bra för att ge användaren snabb
återkoppling, men den **skyddar inte**. Om list-regeln bara visar egna
bokningar ser Anna inte Bos bokningar, och två personer kan dessutom boka
samtidigt. Det riktiga skyddet är en hook på servern (kapitel 7).

## Skapa, ändra, ta bort

```dart
// Skapa
final booking = await pb.collection('bookings').create(body: {
  'resource': resourceId,
  'user': pb.authStore.record!.id,
  'start': start.toUtc().toIso8601String(),
  'end': end.toUtc().toIso8601String(),
  'note': 'Två maskiner',
});

// Ändra
await pb.collection('bookings').update(booking.id, body: {
  'note': 'Bara en maskin',
});

// Ta bort
await pb.collection('bookings').delete(booking.id);
```

Multi-relationer med `+`/`-` (kapitel 3):

```dart
await pb.collection('posts').update(postId, body: {'tags+': tagId});
await pb.collection('posts').update(postId, body: {'tags-': tagId});
```

### Filer

```dart
import 'package:http/http.dart' as http;

await pb.collection('posts').create(
  body: {'title': 'Städdag', 'author': myId, 'published': true},
  files: [
    await http.MultipartFile.fromPath('image', '/sökväg/till/bild.jpg'),
  ],
);

// URL till en uppladdad fil (med miniatyr)
final url = pb.files.getURL(post, post.getStringValue('image'), thumb: '200x200');
```

## Läsa fält ur en RecordModel

Varje post är en `RecordModel` med `id`, `collectionId`, `collectionName` och
`data` (en `Map`). Läs värden med `get<T>()` eller hjälpmetoderna:

| Metod | Exempel |
|-------|---------|
| `get<T>(fält, [standard])` | `record.get<int>('max_hours', 0)` |
| `getStringValue(fält)` | `record.getStringValue('name')` |
| `getIntValue(fält)` | `record.getIntValue('floor')` |
| `getDoubleValue(fält)` | `record.getDoubleValue('size_sqm')` |
| `getBoolValue(fält)` | `record.getBoolValue('active')` |
| `getListValue<T>(fält)` | `record.getListValue<String>('tags')` |

Metoderna klarar punkt-notation, även in i `expand`:

```dart
final resourceName = booking.get<String>('expand.resource.name', '?');

final resource = booking.get<RecordModel?>('expand.resource');

final tags = post.get<List<RecordModel>>('expand.tags', []);

final aptNumber = booking.get<String>('expand.user.expand.apartment.number', '');
```

💡 **Tips:** `get` returnerar ett säkert standardvärde (`""`, `0`, `false`,
`[]`) om fältet saknas, i stället för att krascha. Det är praktiskt men kan
också dölja stavfel. Läs därför fälten på **ett** ställe – i en modellklass.

## Modellklasser – från RecordModel till Dart

Att skriva `record.getStringValue('name')` överallt i appen blir rörigt och
felbenäget. Gör i stället en Dart-klass per collection, med en
`fromRecord`-konstruktor. Då pratar resten av appen bara med typade objekt.

```dart
class Resource {
  const Resource({
    required this.id,
    required this.name,
    required this.description,
    required this.maxHours,
    required this.active,
  });

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
```

```dart
class Booking {
  const Booking({
    required this.id,
    required this.resourceId,
    required this.userId,
    required this.start,
    required this.end,
    required this.note,
    this.resource,
    this.userName,
  });

  final String id;
  final String resourceId;
  final String userId;
  final DateTime start; // lokal tid
  final DateTime end;
  final String note;
  final Resource? resource; // finns om vi hämtade med expand=resource
  final String? userName;   // finns om vi hämtade med expand=user

  factory Booking.fromRecord(RecordModel r) {
    final resourceRecord = r.get<RecordModel?>('expand.resource');
    final userRecord = r.get<RecordModel?>('expand.user');

    return Booking(
      id: r.id,
      resourceId: r.getStringValue('resource'),
      userId: r.getStringValue('user'),
      start: DateTime.parse(r.getStringValue('start')).toLocal(),
      end: DateTime.parse(r.getStringValue('end')).toLocal(),
      note: r.getStringValue('note'),
      resource: resourceRecord == null ? null : Resource.fromRecord(resourceRecord),
      userName: userRecord?.getStringValue('name'),
    );
  }

  Duration get duration => end.difference(start);

  Map<String, dynamic> toBody() => {
        'resource': resourceId,
        'user': userId,
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
        'note': note,
      };
}
```

`DateTime.parse` klarar PocketBase-formatet `2026-10-12 08:00:00.000Z`.
`.toLocal()` gör om från UTC till telefonens tidszon.

### En liten repository-klass

Samla alla anrop för en collection på ett ställe:

```dart
class BookingRepository {
  BookingRepository(this.pb);
  final PocketBase pb;

  RecordService get _col => pb.collection('bookings');

  Future<List<Booking>> upcomingForResource(String resourceId) async {
    final result = await _col.getList(
      perPage: 50,
      sort: 'start',
      expand: 'resource,user',
      filter: pb.filter(
        'resource = {:r} && end >= {:now}',
        {'r': resourceId, 'now': DateTime.now()},
      ),
    );
    return result.items.map(Booking.fromRecord).toList();
  }

  Future<Booking> create(Booking b) async {
    final record = await _col.create(body: b.toBody(), expand: 'resource,user');
    return Booking.fromRecord(record);
  }

  Future<void> delete(String id) => _col.delete(id);
}
```

I modul 04 kopplar vi en sådan klass till widgets med `flutter_compositions`.

## Realtid

```dart
final unsubscribe = await pb.collection('bookings').subscribe('*', (e) {
  print(e.action);      // 'create', 'update' eller 'delete'
  print(e.record?.id);  // posten som ändrades

  final booking = Booking.fromRecord(e.record!);
  // uppdatera listan i appen...
}, filter: pb.filter('resource = {:r}', {'r': resourceId}), expand: 'user');

// Senare, när skärmen stängs:
await unsubscribe();
```

| Variant | Lyssnar på |
|---------|------------|
| `subscribe('*', cb)` | Alla poster i collectionen (som list-regeln släpper igenom) |
| `subscribe(recordId, cb)` | En enskild post (view-regeln) |
| `unsubscribe()` | Sluta lyssna på allt i collectionen |

Ett vanligt mönster för en lista som ska vara "levande":

```dart
void applyEvent(List<Booking> list, RecordSubscriptionEvent e) {
  final b = Booking.fromRecord(e.record!);
  switch (e.action) {
    case 'create':
      list.add(b);
    case 'update':
      final i = list.indexWhere((x) => x.id == b.id);
      if (i != -1) list[i] = b;
    case 'delete':
      list.removeWhere((x) => x.id == b.id);
  }
  list.sort((a, b) => a.start.compareTo(b.start));
}
```

⚠️ **Varning:** Glöm inte att avsluta prenumerationen (`unsubscribe`) när
skärmen försvinner. Annars fortsätter appen ta emot händelser och uppdatera
data som ingen visar – en klassisk minnesläcka.

## Felhantering – ClientException

Alla fel från SDK:n kastas som `ClientException`:

| Egenskap | Innehåll |
|----------|----------|
| `statusCode` | HTTP-status (`400`, `404`, ...). `0` om servern inte gick att nå |
| `response` | Felsvaret som `Map` – samma JSON som i kapitel 5 |
| `url` | Anropad adress |
| `isAbort` | `true` om anropet avbröts |
| `originalError` | Underliggande fel (t.ex. nätverksfel) |

```dart
Future<String?> tryCreateBooking(Booking b) async {
  try {
    await pb.collection('bookings').create(body: b.toBody());
    return null; // inget fel
  } on ClientException catch (e) {
    if (e.statusCode == 0) {
      return 'Ingen kontakt med servern. Kontrollera internetanslutningen.';
    }
    if (e.statusCode == 401 || e.statusCode == 403) {
      return 'Du behöver logga in igen.';
    }

    // Fel per fält, t.ex. {"start": {"code": "validation_required", ...}}
    final data = e.response['data'];
    if (data is Map && data.isNotEmpty) {
      final first = data.values.first as Map;
      return first['message'] as String?;
    }

    // Felmeddelande från en hook, t.ex. "Tiden är redan bokad."
    return e.response['message'] as String? ?? 'Något gick fel.';
  }
}
```

💡 **Tips:** Meddelandet från en hook (`throw new BadRequestError("Tiden är
redan bokad.")` i kapitel 7) kommer fram i `e.response['message']`. Skriv
därför felmeddelanden i hooks på svenska och så att de kan visas direkt för
användaren.

## Ett komplett Dart-program

Spara som `bin/demo.dart` i ett Dart-projekt med `pocketbase` som beroende och
kör med `dart run`:

```dart
import 'package:pocketbase/pocketbase.dart';

Future<void> main() async {
  final pb = PocketBase('http://127.0.0.1:8090');

  await pb.collection('users').authWithPassword('anna@example.com', 'hemligt123');
  print('Inloggad som ${pb.authStore.record!.getStringValue('name')}');

  final resources = await pb.collection('resources').getFullList(
    filter: 'active = true',
    sort: 'name',
  );
  for (final r in resources) {
    print('- ${r.getStringValue('name')} (max ${r.getIntValue('max_hours')} h)');
  }

  final laundry = resources.first;
  final start = DateTime.now().add(const Duration(days: 1));
  final end = start.add(const Duration(hours: 2));

  try {
    final booking = await pb.collection('bookings').create(
      body: {
        'resource': laundry.id,
        'user': pb.authStore.record!.id,
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
      },
      expand: 'resource',
    );
    print('Bokade ${booking.get<String>('expand.resource.name')}');
  } on ClientException catch (e) {
    print('Kunde inte boka: ${e.response['message']}');
  }

  final mine = await pb.collection('bookings').getList(
    filter: pb.filter('user = {:me}', {'me': pb.authStore.record!.id}),
    sort: 'start',
    expand: 'resource',
  );
  print('Du har ${mine.totalItems} bokningar.');
}
```

🧪 **Prova själv:** Kör programmet två gånger. Andra gången borde
dubbelbokningsskyddet från kapitel 7 slå till (om du har lagt in hooken).
Kör det sedan med Bos inloggning – ser Bo Annas bokningar?

## Sammanfattning

- En `PocketBase`-instans för hela appen. Android-emulatorn når datorn via
  `10.0.2.2`.
- `authWithPassword` loggar in. `pb.authStore` håller token och `record`.
  `AsyncAuthStore` sparar inloggningen.
- `getList` (paginerat), `getFullList` (allt), `getOne`, `create`, `update`,
  `delete`.
- Använd **alltid** `pb.filter('x = {:v}', {...})` för värden från användaren.
- Läs fält med `get<T>()`, även `expand.x.y`. Kapsla in det i `fromRecord`.
- `subscribe('*', cb)` för realtid – och glöm inte `unsubscribe`.
- Fånga `ClientException` och visa `response['data']` eller
  `response['message']`.

Nästa kapitel: [Hooks och migrationer](07-hooks-och-migrationer.md).

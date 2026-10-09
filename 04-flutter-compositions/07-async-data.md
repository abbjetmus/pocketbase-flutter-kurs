# 7. Asynkron data

Nästan allt i föreningsappen är asynkront: hämta anslag, hämta resurser, skapa en
bokning och lyssna på realtidsändringar. Det här kapitlet visar hur du gör det med
Flutter Compositions, utan `FutureBuilder`, `setState` eller `if (mounted)`.

## Översikt

| Behov | Verktyg | Returnerar |
|-------|---------|------------|
| Kör en Future en gång när widgeten monteras | `useFuture` | `Ref<AsyncValue<T>>` |
| Future som ska köras om när något ändras, plus manuell refresh | `useAsyncData` | `(ReadonlyRef<AsyncValue<T>>, void Function() refresh)` |
| Dela upp ett `AsyncValue` i separata refs | `useAsyncValue` | `(data, error, loading, hasData)` |
| Senaste värdet från en `Stream` | `useStream` | `Ref<T>` |
| PocketBase realtime | `onMounted` + `subscribe` + `onUnmounted` | egen kod |

## `AsyncValue<T>`: fyra tillstånd

`AsyncValue<T>` är en *sealed class* med fyra underklasser:

| Klass | Betydelse | Fält |
|-------|-----------|------|
| `AsyncIdle<T>` | Inte startad än | – |
| `AsyncLoading<T>` | Väntar på svar | – |
| `AsyncData<T>` | Klar | `value` |
| `AsyncError<T>` | Misslyckades | `errorValue`, `stackTrace` |

Eftersom klassen är *sealed* kan du använda en `switch`-expression, och kompilatorn
varnar om du glömmer ett fall:

```dart
return (context) => switch (status.value) {
      AsyncIdle() || AsyncLoading() =>
        const Center(child: CircularProgressIndicator()),
      AsyncError(:final errorValue) => Text('Något gick fel: $errorValue'),
      AsyncData(:final value) => PostList(posts: value),
    };
```

Det finns också hjälpgetters: `isLoading`, `isError`, `isData`, `dataOrNull` och
`errorOrNull`.

> 💡 **Tips:** `AsyncData(:final value)` är Darts *object pattern*. Det matchar om
> värdet är en `AsyncData` och binder samtidigt fältet `value` till en lokal variabel.
> Samma syntax som props-destruktureringen i kapitel 4.

## `useFuture`: hämta en gång

```dart
class PostsScreen extends CompositionWidget {
  const PostsScreen({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final pb = inject(pocketBaseKey);

    final posts = useFuture(() => pb.collection('posts').getFullList(
          filter: 'published = true',
          sort: '-created',
        ));

    return (context) => switch (posts.value) {
          AsyncIdle() || AsyncLoading() =>
            const Center(child: CircularProgressIndicator()),
          AsyncError(:final errorValue) => Center(child: Text('Fel: $errorValue')),
          AsyncData(:final value) => ListView(
              children: [
                for (final r in value)
                  ListTile(
                    title: Text(r.getStringValue('title')),
                    subtitle: Text(r.getStringValue('body'), maxLines: 2),
                  ),
              ],
            ),
        };
  }
}
```

`useFuture` startar i `AsyncLoading`, kör funktionen i `onMounted` och sätter sedan
`AsyncData` eller `AsyncError`.

### Samma sak med StatefulWidget + FutureBuilder

```dart
class _PostsScreenState extends State<PostsScreen> {
  late final Future<List<RecordModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = pb.collection('posts').getFullList(filter: 'published = true');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const CircularProgressIndicator();
        }
        if (snapshot.hasError) return Text('Fel: ${snapshot.error}');
        return ListView(/* ... snapshot.data! ... */);
      },
    );
  }
}
```

Det fungerar, men det är lätt att råka skapa en ny Future i `build()`, så att anropet
körs vid varje omritning. Det går inte heller enkelt att "ladda om".

## `useAsyncData`: reaktiv hämtning med refresh

```dart
(ReadonlyRef<AsyncValue<T>>, void Function()) useAsyncData<T, W>(
  Future<T> Function(W watchValue) future, {
  W Function()? watch,
});
```

- `future` får värdet från `watch` som argument.
- `watch` är en getter som läser reaktiva värden. När dess resultat ändras körs
  `future` om automatiskt.
- `refresh()` kör om manuellt, till exempel för pull-to-refresh eller en
  "Försök igen"-knapp.
- Utan `watch` sätter du typparametern `W` till `void` och ignorerar argumentet:
  `(_) => …`.

### Vue/Nuxt ↔ Dart

Använder du Nuxt känner du igen namnet: Nuxts `useAsyncData` har nästan samma API.

```ts
// Nuxt 3
const resourceId = ref('tvatt1')
const { data, status, error, refresh } = await useAsyncData(
  'bookings',
  () => pb.collection('bookings').getFullList({
    filter: `resource = "${resourceId.value}"`,
  }),
  { watch: [resourceId] },
)
```

```dart
// Flutter Compositions
final resourceId = ref('tvatt1');

final (status, refresh) = useAsyncData<List<RecordModel>, String>(
  (id) => pb.collection('bookings').getFullList(
    filter: pb.filter('resource = {:id}', {'id': id}),
  ),
  watch: () => resourceId.value,
);
```

> ⚠️ **Varning:** Bygg aldrig PocketBase-filter med stränginterpolation av
> användardata. Använd `pb.filter('... {:param}', {...})` som escapar värdena (se
> [02 – Dart SDK](../02-pocketbase/06-dart-sdk.md)).

### Exempel: bokningar för vald resurs

```dart
class ResourceBookings extends CompositionWidget {
  const ResourceBookings({super.key, required this.resourceId});
  final String resourceId;

  @override
  Widget Function(BuildContext) setup() {
    final pb = inject(pocketBaseKey);
    final props = widget();

    final (status, refresh) = useAsyncData<List<Booking>, String>(
      (id) async {
        final records = await pb.collection('bookings').getFullList(
              filter: pb.filter('resource = {:id} && end >= @now', {'id': id}),
              sort: 'start',
              expand: 'resource',
            );
        return records.map(Booking.fromRecord).toList();
      },
      watch: () => props.value.resourceId,   // ny resurs → hämta om
    );

    return (context) => switch (status.value) {
          AsyncIdle() || AsyncLoading() =>
            const Center(child: CircularProgressIndicator()),
          AsyncError(:final errorValue) => Column(
              children: [
                Text('Kunde inte hämta bokningar: $errorValue'),
                TextButton(onPressed: refresh, child: const Text('Försök igen')),
              ],
            ),
          AsyncData(:final value) => RefreshIndicator(
              onRefresh: () async => refresh(),
              child: ListView(
                children: [
                  for (final b in value)
                    ListTile(title: Text('${b.start} – ${b.end}')),
                ],
              ),
            ),
        };
  }
}
```

Saker att lägga märke till:

- `watch: () => props.value.resourceId` ersätter `didUpdateWidget`.
- `refresh` har typen `void Function()`, så den kan skickas direkt till `onPressed`.
  `RefreshIndicator.onRefresh` vill ha en funktion som returnerar en `Future`, så där
  skriver vi `() async => refresh()`.
- `refresh()` ignoreras om en hämtning redan pågår. Du kan inte råka starta två
  parallella anrop.
- Vid varje omladdning går statusen till `AsyncLoading`, och den gamla datan visas
  inte under tiden. Vill du behålla listan medan du laddar om, se avsnittet om
  realtime nedan.

> 💡 **Tips:** `Booking.fromRecord` är en factory som gör om en PocketBase-`RecordModel`
> till en typad Dart-klass. Mönstret för modeller visas i
> [kapitel 9](09-arkitektur-for-en-riktig-app.md#modeller).

### Dela async-state med ättlingar

```dart
const resourcesKey =
    InjectionKey<ReadonlyRef<AsyncValue<List<Resource>>>>('resources');

// i en förfader:
final (resources, _) = useAsyncData<List<Resource>, void>(
  (_) => service.fetchActiveResources(),
);
provide(resourcesKey, resources);

// i en ättling:
final resources = inject(resourcesKey);
final names = computed(
  () => resources.value.dataOrNull?.map((r) => r.name).toList() ?? const [],
);
```

### `useAsyncValue`: separata refs

Vill du hellre ha `data`, `error` och `loading` var för sig, som i många
Vue-bibliotek:

```dart
final (status, refresh) = useAsyncData<List<Post>, void>((_) => service.fetchPosts());
final (data, error, loading, hasData) = useAsyncValue(status);

final postCount = computed(() => data.value?.length ?? 0);
```

## `useStream`

```dart
Ref<T> useStream<T>(Stream<T> stream, {required T initialValue});
```

`useStream` prenumererar på en stream, håller senaste värdet i en ref och avbryter
prenumerationen automatiskt vid unmount.

```dart
final pb = inject(pocketBaseKey);

// authStore.onChange är en Stream<AuthStoreEvent>
final lastAuthEvent = useStream<AuthStoreEvent?>(
  pb.authStore.onChange,
  initialValue: null,
);
final status = computed(
  () => lastAuthEvent.value?.record == null ? 'Utloggad' : 'Inloggad',
);
```

> ⚠️ **Varning:** `useStream` hanterar inte stream-fel. Om felen spelar roll lyssnar du
> själv och lägger felet i en egen ref. I den officiella dokumentationen står ibland
> `initialData:`. I version 0.1.1 heter parametern `initialValue:`.

## PocketBase realtime

PocketBase kan skicka ändringar i realtid via `subscribe`. Det returnerar en
`Future<UnsubscribeFunc>` som du **måste** anropa när widgeten försvinner, annars
fortsätter appen att ta emot (och hantera) händelser för en skärm som inte längre finns.

### Rätt mönster i version 0.1.1

Som du såg i [kapitel 4](04-livscykel-och-props.md) får `onUnmounted` inte registreras
inuti `onMounted`. Dessutom är `subscribe` asynkront, så widgeten kan hinna försvinna
innan prenumerationen är klar. Så här hanterar vi båda fallen:

```dart
UnsubscribeFunc? unsubscribe;
var disposed = false;

onMounted(() async {
  final unsub = await pb.collection('bookings').subscribe('*', (e) {
    debugPrint('${e.action}: ${e.record?.id}');
  });
  if (disposed) {
    await unsub();          // widgeten hann försvinna, städa direkt
  } else {
    unsubscribe = unsub;
  }
});

onUnmounted(() {
  disposed = true;
  unsubscribe?.call();
});
```

### Mönster: initial hämtning + realtidspatchning

Det enklaste sättet att reagera på en realtidshändelse är att anropa `refresh()`. Men
då blinkar listan (statusen går till `AsyncLoading`), och en händelse som kommer under
en pågående hämtning ignoreras. Ett robustare mönster:

1. `useAsyncData` gör den första hämtningen (och pull-to-refresh).
2. En lokal `ref<List<Booking>>` innehåller det som visas.
3. En `watch` kopierar in ny data varje gång en hämtning blir klar.
4. Realtidshändelser **patchar** den lokala listan (lägg till, ersätt, ta bort).

```dart
final (status, refresh) = useAsyncData<List<Booking>, void>(
  (_) => service.fetchMyBookings(userId),
);

final items = ref(<Booking>[]);

watch(() => status.value, (s, _) {
  if (s case AsyncData(:final value)) items.value = value;
});

void applyEvent(RecordSubscriptionEvent e) {
  final record = e.record;
  if (record == null) return;
  final booking = Booking.fromRecord(record);
  final current = items.value;

  items.value = switch (e.action) {
    'create' => [...current, booking],
    'update' => [for (final b in current) b.id == booking.id ? booking : b],
    'delete' => current.where((b) => b.id != booking.id).toList(),
    _ => current,
  };
}

// + subscribe/unsubscribe-mönstret från ovan, med applyEvent som callback
```

Här är `watch` rätt verktyg trots tumregeln "computed först". `items` ändras från
**två** håll (hämtningar och händelser), så det är state och inte ett härlett värde.

Samma idé, flyttad in i en *store* (kommentarer i realtid med skydd mot race-fall),
finns i [kapitel 9](09-arkitektur-for-en-riktig-app.md#kommentarer-i-realtid).

> ⚠️ **Varning:** Realtidshändelser respekterar collectionens **List/View-regler**. En
> användare får bara händelser för poster den har rätt att se (se
> [02 – Autentisering och API-regler](../02-pocketbase/04-autentisering-och-api-regler.md)).
> Ser du inga händelser, kontrollera reglerna först.

## Skicka data: knappar och formulär

För *skrivningar* (skapa, uppdatera, ta bort) behövs ingen speciell composable. Använd
en vanlig async-funktion och ett par refs för status:

```dart
final saving = ref(false);
final error = ref<String?>(null);

Future<void> save() async {
  saving.value = true;
  error.value = null;
  try {
    await pb.collection('bookings').create(body: {
      'resource': resourceId,
      'user': userId,
      'start': start.toUtc().toIso8601String(),
      'end': end.toUtc().toIso8601String(),
    });
  } on ClientException catch (e) {
    error.value = e.response['message']?.toString() ?? 'Kunde inte spara';
  } finally {
    saving.value = false;
  }
}

final buttonLabel = computed(() => saving.value ? 'Sparar…' : 'Boka');
```

`ClientException.response` innehåller PocketBase-svaret. Om du har en hook som stoppar
dubbelbokningar (modul 02) hamnar dess felmeddelande här.

## Vanliga misstag

| Misstag | Följd | Rätt |
|---------|-------|------|
| `async setup()` | Kompilerar inte | `useFuture`/`useAsyncData`/`onMounted` |
| `useFuture(...)` inuti en `if` | Bryter regeln om ovillkorliga anrop | Alltid anropa, styr med `watch`-värdet |
| Glömt `unsubscribe` | Händelser fortsätter efter att skärmen stängts | `onUnmounted` + `disposed`-flagga |
| `onUnmounted` inuti `onMounted` | Assertion-fel / läcka | Registrera i `setup()` |
| `items.value.add(x)` i realtids-callback | UI uppdateras inte | `items.value = [...items.value, x]` |
| Stränginterpolerade filter | Säkerhetshål | `pb.filter(..., {...})` |

## 🧪 Prova själv

1. Bygg en `ResourcesScreen` som hämtar aktiva resurser med `useAsyncData` och visar
   dem i en lista med pull-to-refresh.
2. Lägg till en `Switch` "Visa även inaktiva" (`final showInactive = ref(false)`) och
   låt `watch: () => showInactive.value` styra filtret.
3. Öppna PocketBase Admin UI, ändra en resurs och dra för att ladda om. Lägg sedan till
   en realtidsprenumeration som anropar `refresh()` på varje händelse, och se listan
   uppdateras av sig själv.

## Sammanfattning

- `AsyncValue` har fyra tillstånd: `AsyncIdle`, `AsyncLoading`, `AsyncData` och
  `AsyncError`. Rendera dem med `switch`.
- `useFuture` kör en gång. `useAsyncData` kör om när `watch` ändras och har `refresh()`.
- `useStream` ger senaste värdet och städar själv.
- PocketBase realtime: `subscribe` i `onMounted`, `unsubscribe` i `onUnmounted`
  (registrerat i `setup()`), plus en `disposed`-flagga.
- För listor som ändras både av hämtningar och händelser: lokal ref + `watch` +
  patchning.

Nästa kapitel: [Best practices och lints →](08-best-practices-och-lints.md)

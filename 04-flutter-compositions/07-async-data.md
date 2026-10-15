# 7. Asynkron data

Nästan allt i Kvittra är asynkront: hämta flödet, hämta ett inlägg, skicka en
kommentar, gilla och lyssna på nya kommentarer i realtid. Det här kapitlet visar hur du gör det med
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
          sort: '-created',
          expand: 'author',
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
    _future = pb.collection('posts').getFullList(sort: '-created');
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
const postId = ref('abc123')
const { data, status, error, refresh } = await useAsyncData(
  'comments',
  () => pb.collection('comments').getFullList({
    filter: pb.filter('post = {:id}', { id: postId.value }),
  }),
  { watch: [postId] },
)
```

```dart
// Flutter Compositions
final postId = ref('abc123');

final (status, refresh) = useAsyncData<List<RecordModel>, String>(
  (id) => pb.collection('comments').getFullList(
    filter: pb.filter('post = {:id}', {'id': id}),
  ),
  watch: () => postId.value,
);
```

> ⚠️ **Varning:** Bygg aldrig PocketBase-filter med stränginterpolation av
> användardata. Använd `pb.filter('... {:param}', {...})` som escapar värdena (se
> [02 – Dart SDK](../02-pocketbase/06-dart-sdk.md)).

### Exempel: ett inlägg via id, med refresh

```dart
class PostDetail extends CompositionWidget {
  const PostDetail({super.key, required this.postId});
  final String postId;

  @override
  Widget Function(BuildContext) setup() {
    final pb = inject(pocketBaseKey);
    final props = widget();

    final (status, refresh) = useAsyncData<Post, String>(
      (id) async {
        final record = await pb.collection('posts').getOne(id, expand: 'author');
        return Post.fromRecord(record);
      },
      watch: () => props.value.postId,   // nytt id → hämta om
    );

    return (context) => switch (status.value) {
          AsyncIdle() || AsyncLoading() =>
            const Center(child: CircularProgressIndicator()),
          AsyncError(:final errorValue) => Column(
              children: [
                Text('Kunde inte hämta inlägget: $errorValue'),
                TextButton(onPressed: refresh, child: const Text('Försök igen')),
              ],
            ),
          AsyncData(:final value) => RefreshIndicator(
              onRefresh: () async => refresh(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(value.title, style: const TextStyle(fontSize: 22)),
                  Text('av ${value.authorName}'),
                  const SizedBox(height: 12),
                  Text(value.body),
                ],
              ),
            ),
        };
  }
}
```

Saker att lägga märke till:

- `watch: () => props.value.postId` ersätter `didUpdateWidget`. Visar föräldern ett
  annat inlägg hämtas det nya automatiskt.
- `refresh` har typen `void Function()`, så den kan skickas direkt till `onPressed`.
  `RefreshIndicator.onRefresh` vill ha en funktion som returnerar en `Future`, så där
  skriver vi `() async => refresh()`.
- `refresh()` ignoreras om en hämtning redan pågår. Du kan inte råka starta två
  parallella anrop.
- Vid varje omladdning går statusen till `AsyncLoading`, och den gamla datan visas
  inte under tiden. Vill du behålla datan medan du laddar om, se avsnittet om
  realtime nedan.
- Kastar funktionen (t.ex. 404 för ett inlägg som raderats) blir statusen
  `AsyncError`.

> 💡 **Tips:** `Post.fromRecord` är en factory som gör om en PocketBase-`RecordModel`
> till en typad Dart-klass, med `authorName` från `expand.author`. Mönstret för modeller
> visas i [kapitel 9](09-arkitektur-for-en-riktig-app.md#modeller).

### Dela async-state med ättlingar

```dart
const feedKey = InjectionKey<ReadonlyRef<AsyncValue<List<Post>>>>('feed');

// i en förfader:
final (feed, _) = useAsyncData<List<Post>, void>(
  (_) => service.fetchFeed(),
);
provide(feedKey, feed);

// i en ättling:
final feed = inject(feedKey);
final titles = computed(
  () => feed.value.dataOrNull?.map((p) => p.title).toList() ?? const [],
);
```

### `useAsyncValue`: separata refs

Vill du hellre ha `data`, `error` och `loading` var för sig, som i många
Vue-bibliotek:

```dart
final (status, refresh) = useAsyncData<List<Post>, void>((_) => service.fetchFeed());
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
  final unsub = await pb.collection('comments').subscribe(
    '*',
    (e) => debugPrint('${e.action}: ${e.record?.id}'),
    // Bara kommentarer på det här inlägget:
    filter: pb.filter('post = {:id}', {'id': props.value.postId}),
  );
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
2. En lokal `ref<List<Comment>>` innehåller det som visas.
3. En `watch` kopierar in ny data varje gång en hämtning blir klar.
4. Realtidshändelser **patchar** den lokala listan (lägg till, ersätt, ta bort).

```dart
final (status, refresh) = useAsyncData<List<Comment>, String>(
  (postId) => service.fetchComments(postId),
  watch: () => props.value.postId,
);

final items = ref(<Comment>[]);

watch(() => status.value, (s, _) {
  if (s case AsyncData(:final value)) items.value = value;
});

void applyEvent(RecordSubscriptionEvent e) {
  final record = e.record;
  if (record == null) return;
  final comment = Comment.fromRecord(record);
  final current = items.value;

  items.value = switch (e.action) {
    // Kan redan finnas om hämtningen och händelsen korsade varandra
    'create' => current.any((c) => c.id == comment.id) ? current : [...current, comment],
    'update' => [for (final c in current) c.id == comment.id ? comment : c],
    'delete' => current.where((c) => c.id != comment.id).toList(),
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
final sending = ref(false);
final error = ref<String?>(null);

Future<void> sendComment(String body) async {
  sending.value = true;
  error.value = null;
  try {
    await pb.collection('comments').create(body: {
      'post': props.value.postId,
      'author': pb.authStore.record!.id,
      'body': body,
    });
  } on ClientException catch (e) {
    error.value = e.response['message']?.toString() ?? 'Kunde inte skicka';
  } finally {
    sending.value = false;
  }
}

final buttonLabel = computed(() => sending.value ? 'Skickar…' : 'Skicka');
```

`ClientException.response` innehåller PocketBase-svaret. Om en regel eller hook på
servern säger nej (t.ex. för en för lång kommentar) hamnar dess felmeddelande här.

### Optimistisk uppdatering: gilla direkt, ångra vid fel

En gilla-knapp ska kännas omedelbar. Att vänta på servern innan hjärtat blir rött
känns segt. Ett vanligt mönster är **optimistisk uppdatering**:

1. Uppdatera UI:t direkt, som om anropet redan lyckats.
2. Skicka anropet.
3. Om servern svarar med fel: **rulla tillbaka** till det gamla värdet.

```dart
final liked = ref(props.value.post.likedByMe);
final likeCount = ref(props.value.post.likeCount);

Future<void> toggleLike() async {
  final wasLiked = liked.value;
  final postId = props.value.post.id;
  final me = pb.authStore.record!.id;

  liked.value = !wasLiked;                    // 1. optimistiskt
  likeCount.value += wasLiked ? -1 : 1;

  try {                                       // 2. servern
    final likes = pb.collection('likes');
    if (wasLiked) {
      final like = await likes.getFirstListItem(
        pb.filter('post = {:p} && user = {:u}', {'p': postId, 'u': me}),
      );
      await likes.delete(like.id);
    } else {
      await likes.create(body: {'post': postId, 'user': me});
    }
  } on ClientException catch (e) {            // 3. rulla tillbaka
    debugPrint('Gilla misslyckades: ${e.statusCode}');
    liked.value = wasLiked;
    likeCount.value += wasLiked ? 1 : -1;
  }
}
```

Unikhetsindexet på `likes (post, user)` från modul 02 gör att servern svarar `400` om
du försöker gilla samma inlägg två gånger. Då rullas UI:t tillbaka. I
[kapitel 9](09-arkitektur-for-en-riktig-app.md) flyttar vi logiken till en composable,
`useLikeToggle`, och serveranropet till en store.

## Vanliga misstag

| Misstag | Följd | Rätt |
|---------|-------|------|
| `async setup()` | Kompilerar inte | `useFuture`/`useAsyncData`/`onMounted` |
| `useFuture(...)` inuti en `if` | Bryter regeln om ovillkorliga anrop | Alltid anropa, styr med `watch`-värdet |
| Glömt `unsubscribe` | Händelser fortsätter efter att skärmen stängts | `onUnmounted` + `disposed`-flagga |
| `onUnmounted` inuti `onMounted` | Assertion-fel / läcka | Registrera i `setup()` |
| `items.value.add(x)` i realtids-callback | UI uppdateras inte | `items.value = [...items.value, x]` |
| Optimistisk uppdatering utan `catch` | UI:t visar fel värde när servern säger nej | Spara gamla värdet och rulla tillbaka |
| Stränginterpolerade filter | Säkerhetshål | `pb.filter(..., {...})` |

## 🧪 Prova själv

1. Bygg en `PostsScreen` som hämtar inlägg (`expand: 'author'`) med `useAsyncData` och
   visar dem i en lista med pull-to-refresh.
2. Lägg till en `Switch` "Bara inlägg med bild" (`final onlyImages = ref(false)`) och
   låt `watch: () => onlyImages.value` styra filtret (`image != ""`).
3. Öppna PocketBase Admin UI, ändra rubriken på ett inlägg och dra för att ladda om.
   Lägg sedan till en realtidsprenumeration på `posts` som anropar `refresh()` på varje
   händelse, och se listan uppdateras av sig själv.

## Sammanfattning

- `AsyncValue` har fyra tillstånd: `AsyncIdle`, `AsyncLoading`, `AsyncData` och
  `AsyncError`. Rendera dem med `switch`.
- `useFuture` kör en gång. `useAsyncData` kör om när `watch` ändras och har `refresh()`.
- `useStream` ger senaste värdet och städar själv.
- PocketBase realtime: `subscribe` i `onMounted`, `unsubscribe` i `onUnmounted`
  (registrerat i `setup()`), plus en `disposed`-flagga.
- För listor som ändras både av hämtningar och händelser: lokal ref + `watch` +
  patchning.
- Optimistiska uppdateringar (som gilla) ändrar UI:t direkt och rullas tillbaka vid
  `ClientException`.

Nästa kapitel: [Best practices och lints →](08-best-practices-och-lints.md)

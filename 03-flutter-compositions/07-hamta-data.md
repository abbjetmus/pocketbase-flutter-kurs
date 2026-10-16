# 7. Hämta data

I modul 02 visade du data från PocketBase med `FutureBuilder`. Här gör vi
samma sak med Flutter Compositions. Det blir kortare, och det blir lätt att
ladda om.

| Du vill … | Använd |
|-----------|--------|
| Hämta något en gång när sidan öppnas | `useFuture` |
| Hämta igen när något ändras, eller när användaren drar för att ladda om | `useAsyncData` |
| Visa laddning, fel eller data | `switch` på ett `AsyncValue` |
| Lyssna på ändringar i realtid | `subscribe` i `onMounted`, `unsubscribe` i `onUnmounted` |

## AsyncValue: fyra lägen

Både `useFuture` och `useAsyncData` ger dig ett `AsyncValue`. Det är alltid i
ett av fyra lägen:

| Läge | Betyder |
|------|---------|
| `AsyncIdle` | Har inte börjat än |
| `AsyncLoading` | Väntar på svar |
| `AsyncData` | Klart. Datan finns i `value` |
| `AsyncError` | Något gick fel. Felet finns i `errorValue` |

Du väljer vad som ska visas med en `switch`:

```dart
return (context) => switch (posts.value) {
      AsyncIdle() || AsyncLoading() =>
        const Center(child: CircularProgressIndicator()),
      AsyncError(:final errorValue) => Text('Fel: $errorValue'),
      AsyncData(:final value) => Text('${value.length} inlägg'),
    };
```

`AsyncData(:final value)` betyder: "om det är `AsyncData`, ge mig `value`".
Glömmer du ett läge varnar Dart.

💡 Behöver du bara datan, till exempel i en `computed`, finns
`posts.value.dataOrNull`. Den är `null` tills datan har kommit.

## useFuture: hämta en gång

```dart
class FeedSimple extends CompositionWidget {
  const FeedSimple({super.key});

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
                    subtitle: Text(r.get<String>('expand.author.name', '?')),
                  ),
              ],
            ),
        };
  }
}
```

| `FutureBuilder` (modul 02) | `useFuture` |
|----------------------------|-------------|
| Spara Future i `initState` | Skriv funktionen direkt i `setup()` |
| `snapshot.connectionState`, `snapshot.hasError` … | `switch` med fyra lägen |
| Svårt att ladda om | Byt till `useAsyncData` och få `refresh` |

## useAsyncData: hämta igen

```dart
final (posts, refresh) = useAsyncData<List<RecordModel>, bool>(
  (mine) => pb.collection('posts').getFullList(
        sort: '-created',
        expand: 'author',
        filter: mine ? pb.filter('author = {:me}', {'me': auth.myId}) : '',
      ),
  watch: () => onlyMine.value,
);
```

| Del | Betyder |
|-----|---------|
| `<List<RecordModel>, bool>` | Vad du får tillbaka, och vilken typ `watch` har |
| `(mine) => ...` | Funktionen som hämtar. Den får värdet från `watch` |
| `watch: () => onlyMine.value` | När det här ändras hämtas allt igen |
| `refresh` | En funktion som hämtar igen när du anropar den |

Behöver du ingen `watch` skriver du `void` som andra typ:
`useAsyncData<List<RecordModel>, void>((_) => ...)`.

Så här ser hela sidan ut, med en switch och "dra för att ladda om":

```dart
class FeedRefresh extends CompositionWidget {
  const FeedRefresh({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final pb = inject(pocketBaseKey);
    final auth = inject(authKey);
    final onlyMine = ref(false);

    final (posts, refresh) = useAsyncData<List<RecordModel>, bool>(
      (mine) => pb.collection('posts').getFullList(
            sort: '-created',
            expand: 'author',
            filter: mine ? pb.filter('author = {:me}', {'me': auth.myId}) : '',
          ),
      watch: () => onlyMine.value,
    );

    final count = computed(() => posts.value.dataOrNull?.length ?? 0);

    return (context) => Scaffold(
          appBar: AppBar(title: Text('Flöde (${count.value})')),
          body: Column(
            children: [
              SwitchListTile(
                title: const Text('Bara mina inlägg'),
                value: onlyMine.value,
                onChanged: (v) => onlyMine.value = v,
              ),
              Expanded(
                child: switch (posts.value) {
                  AsyncIdle() || AsyncLoading() =>
                    const Center(child: CircularProgressIndicator()),
                  AsyncError(:final errorValue) => Center(
                      child: TextButton(
                        onPressed: refresh,
                        child: Text('Fel: $errorValue. Försök igen'),
                      ),
                    ),
                  AsyncData(:final value) => RefreshIndicator(
                      onRefresh: () async => refresh(),
                      child: ListView(
                        children: [
                          for (final r in value)
                            ListTile(title: Text(r.getStringValue('title'))),
                        ],
                      ),
                    ),
                },
              ),
            ],
          ),
        );
  }
}
```

### Ett inlägg via id

På en detaljsida kommer id:t som en prop. Med `watch` hämtas ett nytt inlägg
om id:t ändras:

```dart
final props = widget();

final (post, refresh) = useAsyncData<RecordModel, String>(
  (id) => pb.collection('posts').getOne(id, expand: 'author'),
  watch: () => props.value.postId,
);
```

Hela detaljsidan bygger du i kapitel 8.

## Kommentarer i realtid

Vi vill att nya kommentarer ska dyka upp av sig själva. Planen:

1. `useAsyncData` hämtar kommentarerna en gång.
2. En `ref` med listan som **visas**. En `watch` kopierar in datan när den
   kommer.
3. Realtidshändelser lägger till eller tar bort i listan.

```dart
class LiveComments extends CompositionWidget {
  const LiveComments({super.key, required this.postId});

  final String postId;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final pb = inject(pocketBaseKey);
    final filter = pb.filter('post = {:id}', {'id': props.raw.postId});

    // 1. Hämta en gång
    final (status, _) = useAsyncData<List<RecordModel>, void>(
      (_) => pb.collection('comments').getFullList(
            filter: filter,
            sort: 'created',
            expand: 'author',
          ),
    );

    // 2. Listan som visas
    final comments = ref(<RecordModel>[]);
    watch(() => status.value, (s, _) {
      if (s case AsyncData(:final value)) comments.value = value;
    });

    // 3. Realtid
    void onEvent(RecordSubscriptionEvent e) {
      final record = e.record;
      if (record == null) return;
      if (e.action == 'create') {
        comments.value = [...comments.value, record];
      } else if (e.action == 'delete') {
        comments.value = comments.value.where((c) => c.id != record.id).toList();
      }
    }

    UnsubscribeFunc? unsubscribe;
    var disposed = false;

    onMounted(() async {
      final unsub = await pb
          .collection('comments')
          .subscribe('*', onEvent, filter: filter, expand: 'author');
      if (disposed) {
        await unsub(); // sidan hann stängas medan vi väntade
      } else {
        unsubscribe = unsub;
      }
    });

    onUnmounted(() {
      disposed = true;
      unsubscribe?.call();
    });

    return (context) => ListView(
          children: [
            for (final c in comments.value)
              ListTile(
                title: Text(c.getStringValue('body')),
                subtitle: Text(c.get<String>('expand.author.name', '?')),
              ),
          ],
        );
  }
}
```

Varför `disposed`? `subscribe` tar en stund. Stänger användaren sidan innan den
är klar har `onUnmounted` redan körts, och då finns inget att avbryta. Därför
kollar vi `disposed` när `subscribe` är klar, och avbryter direkt om sidan är
borta.

⚠️ Kom ihåg regeln från kapitel 3: `onUnmounted` registreras **direkt i
`setup()`**, aldrig inuti `onMounted`.

💡 `props.raw.postId` läser id:t en gång. Byts inlägget ger vi widgeten en ny
`key`, så skapas en ny widget: `LiveComments(key: ValueKey(id), postId: id)`.

## Gilla direkt

En gilla-knapp ska kännas snabb. Vi ändrar därför hjärtat **direkt**, och frågar
servern efteråt. Säger servern nej ändrar vi tillbaka. Det kallas en
**optimistisk uppdatering**.

```dart
final liked = ref(props.raw.likedByMe); // startvärde från propen
final count = ref(props.raw.likeCount);

Future<void> toggleLike() async {
  final wasLiked = liked.value;
  final postId = props.value.postId;
  final likes = pb.collection('likes');

  liked.value = !wasLiked; // 1. ändra direkt
  count.value += wasLiked ? -1 : 1;

  try {
    // 2. fråga servern
    if (wasLiked) {
      final like = await likes.getFirstListItem(pb.filter(
        'post = {:p} && user = {:u}',
        {'p': postId, 'u': auth.myId},
      ));
      await likes.delete(like.id);
    } else {
      await likes.create(body: {'post': postId, 'user': auth.myId});
    }
  } on ClientException {
    liked.value = wasLiked; // 3. ångra om servern sa nej
    count.value += wasLiked ? 1 : -1;
  }
}
```

## useStream

Har du en `Stream` kan du läsa senaste värdet med `useStream`. Den slutar
lyssna själv när widgeten försvinner:

```dart
final last = useStream<AuthStoreEvent?>(pb.authStore.onChange, initialValue: null);
```

⚠️ Parametern heter `initialValue:`, inte `initialData:` som i `StreamBuilder`.

## Vanliga misstag

| Misstag | Vad händer | Gör så här |
|---------|------------|------------|
| `setup()` är `async` | Kompilerar inte | `useFuture` eller `useAsyncData` |
| `comments.value.add(x)` i realtid | Skärmen uppdateras inte | `comments.value = [...comments.value, x]` |
| Glömt `unsubscribe` | Appen lyssnar fast sidan är stängd | `onUnmounted` + `disposed` |
| Optimistisk uppdatering utan `catch` | Hjärtat visar fel om servern säger nej | Spara det gamla värdet och ändra tillbaka |

## Övningar

Gör övningarna i appen från kapitel 6, på `HomePage`.

**7.1** Visa `FeedSimple`. Byt sedan till `useAsyncData` och lägg till "dra för
att ladda om". Ändra en rubrik i Dashboard och dra. Syns ändringen?

**7.2** Lägg till "Bara mina inlägg" som i `FeedRefresh`. Logga in som Bertil
och prova.

**7.3** Visa `LiveComments` för inlägget "Mitt första surdegsbröd". Kopiera
dess id från Dashboard. Skriv en kommentar i Dashboard. Dyker den upp i appen
utan att du laddar om?

**7.4** Lägg till en knapp som tar bort den senaste kommentaren med
`pb.collection('comments').delete(id)`. Försvinner den från listan av sig själv?
Varför fungerar det bara på dina egna kommentarer?

**7.5** Bygg en `LikeButton` med props `postId`, `likedByMe` och `likeCount`,
och `toggleLike` från kapitlet. Testa att ångra fungerar: lås Create-regeln för
`likes` i Dashboard (🔒) och tryck på hjärtat. Vad händer? Lås upp regeln igen.

Lösningar finns i [losningar.md](losningar.md#kapitel-7--hämta-data).

Nästa kapitel: [Bygg Kvittra-appen](08-bygg-kvittra-appen.md)

# 12. Ladda om och realtid

I [kapitel 9](09-hamta-data-fran-pocketbase.md) visade du data från PocketBase
med `useFuture`, `useAsyncData` och en `switch` på `AsyncValue`. Nu bygger vi
vidare på det: hämta igen när något ändras, dra för att ladda om och lyssna på
ändringar i realtid.

| Du vill … | Använd |
|-----------|--------|
| Hämta igen när något ändras, eller när användaren drar för att ladda om | `useAsyncData` med `watch` och `refresh` |
| Lyssna på ändringar i realtid | `subscribe` i `onMounted`, `unsubscribe` i `onUnmounted` |
| Visa ett gillande direkt, innan servern har svarat | En optimistisk uppdatering |

## useAsyncData: hämta när något ändras

Till `useAsyncData` kan du lägga till en `watch`. Då hämtas datan igen när värdet
ändras:

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

I kapitel 9 skrev du `void` som andra typ, eftersom det inte fanns någon `watch`.

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

Hela detaljsidan bygger du i kapitel 13.

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

⚠️ Kom ihåg regeln från kapitel 6: `onUnmounted` registreras **direkt i
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

⚠️ Parametern heter `initialValue:`.

## Vanliga misstag

| Misstag | Vad händer | Gör så här |
|---------|------------|------------|
| `setup()` är `async` | Kompilerar inte | `useFuture` eller `useAsyncData` |
| `comments.value.add(x)` i realtid | Skärmen uppdateras inte | `comments.value = [...comments.value, x]` |
| Glömt `unsubscribe` | Appen lyssnar fast sidan är stängd | `onUnmounted` + `disposed` |
| Optimistisk uppdatering utan `catch` | Hjärtat visar fel om servern säger nej | Spara det gamla värdet och ändra tillbaka |

## Övningar

Gör övningarna i appen från kapitel 11, på `HomePage`.

**12.1** Visa `FeedRefresh` på `HomePage`. Ändra en rubrik i Dashboard och dra
för att ladda om. Syns ändringen?

**12.2** Slå på "Bara mina inlägg". Logga sedan in som Bertil och prova igen.
Vilka inlägg ser han?

**12.3** Visa `LiveComments` för inlägget "Mitt första surdegsbröd". Kopiera
dess id från Dashboard. Skriv en kommentar i Dashboard. Dyker den upp i appen
utan att du laddar om?

**12.4** Lägg till en knapp som tar bort den senaste kommentaren med
`pb.collection('comments').delete(id)`. Försvinner den från listan av sig själv?
Varför fungerar det bara på dina egna kommentarer?

**12.5** Bygg en `LikeButton` med props `postId`, `likedByMe` och `likeCount`,
och `toggleLike` från kapitlet. Testa att ångra fungerar: lås Create-regeln för
`likes` i Dashboard (🔒) och tryck på hjärtat. Vad händer? Lås upp regeln igen.

Lösningar finns i [losningar.md](losningar.md#kapitel-12--ladda-om-och-realtid).

Nästa kapitel: [Bygg Kvittra-appen](13-bygg-kvittra-appen.md)

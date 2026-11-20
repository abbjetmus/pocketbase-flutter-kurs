# 10. Ladda om och realtid

I [kapitel 8](08-hamta-data-fran-pocketbase.md) visade du data från PocketBase
med `useAsyncData` och en `switch` på `AsyncValue`. Nu bygger vi vidare på det:
hämta igen, dra för att ladda om och lyssna på ändringar i realtid.

| Du vill … | Använd |
|-----------|--------|
| Hämta igen, till exempel när användaren drar för att ladda om | `refresh` från `useAsyncData` |
| Lyssna på ändringar i realtid | `subscribe` i `onMounted`, `unsubscribe` i `onUnmounted` |
| Visa ett gillande direkt, innan servern har svarat | En optimistisk uppdatering |

Gör allt i projektet `kvittra`. Du visar en widget genom att byta `void main()`
i `lib/main.dart`, precis som med `PbTestPage` i kapitel 9:

```dart
void main() => runApp(const MaterialApp(home: FeedRefresh()));
```

## Hämta igen med refresh

`useAsyncData` ger dig två saker: datan och `refresh`. När du anropar `refresh()`
hämtas allt igen.

Här är ett flöde där man kan dra för att ladda om, och välja att bara se Annas
inlägg:

```dart
// lib/feed_refresh.dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';

import 'data/pocketbase.dart';

class FeedRefresh extends CompositionWidget {
  const FeedRefresh({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final onlyAnna = ref(false);

    final (posts, refresh) = useAsyncData<List<RecordModel>, void>(
      (_) => pb.collection('posts').getFullList(
            sort: '-created',
            expand: 'author',
            filter: onlyAnna.value
                ? pb.filter('author = {:id}', {'id': annaId})
                : '',
          ),
    );

    void setOnlyAnna(bool value) {
      onlyAnna.value = value;
      refresh(); // hämta igen med det nya filtret
    }

    return (context) => Scaffold(
          appBar: AppBar(title: Text('Flöde (${posts.value.dataOrNull?.length ?? 0})')),
          body: Column(
            children: [
              SwitchListTile(
                title: const Text('Bara Annas inlägg'),
                value: onlyAnna.value,
                onChanged: setOnlyAnna,
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

- `RefreshIndicator` visar en snurra när man drar listan nedåt, och anropar
  `onRefresh`.
- `setOnlyAnna` ändrar filtret och anropar `refresh()`. Då hämtas listan igen
  med det nya filtret.
- `posts.value.dataOrNull` är listan, eller `null` om den inte har kommit än.

## Ett inlägg via id

På en sida för ett inlägg kommer id:t som en prop:

```dart
final props = widget();

final (post, refresh) = useAsyncData<RecordModel, void>(
  (_) => pb.collection('posts').getOne(props.value.postId, expand: 'author'),
);
```

Hela sidan bygger du i kapitel 11.

## Kommentarer i realtid

Vi vill att nya kommentarer ska dyka upp av sig själva. Planen:

1. En `ref` med listan som **visas**.
2. I `onMounted` hämtar vi kommentarerna och börjar lyssna på ändringar.
3. Varje realtidshändelse lägger till eller tar bort en kommentar i listan.
4. I `onUnmounted` slutar vi lyssna.

```dart
// lib/live_comments.dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';

import 'data/pocketbase.dart';

class LiveComments extends CompositionWidget {
  const LiveComments({super.key, required this.postId});

  final String postId;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final filter = pb.filter('post = {:id}', {'id': props.value.postId});

    // 1. Listan som visas
    final comments = ref(<RecordModel>[]);

    // 3. Det här händer vid varje ändring
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

    // 2. Hämta och börja lyssna
    onMounted(() async {
      comments.value = await pb.collection('comments').getFullList(
            filter: filter,
            sort: 'created',
            expand: 'author',
          );
      final unsub = await pb
          .collection('comments')
          .subscribe('*', onEvent, filter: filter, expand: 'author');
      if (disposed) {
        await unsub(); // sidan hann stängas medan vi väntade
      } else {
        unsubscribe = unsub;
      }
    });

    // 4. Sluta lyssna
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

Varför `disposed`? Det tar en stund att hämta och börja lyssna. Stänger
användaren sidan innan dess har `onUnmounted` redan körts, och då finns inget
att avbryta. Därför kollar vi `disposed` när `subscribe` är klar, och avbryter
direkt om sidan är borta.

⚠️ Kom ihåg regeln från kapitel 6: `onUnmounted` skrivs **direkt i `setup()`**,
aldrig inuti `onMounted`.

## Gilla direkt

En gilla-knapp ska kännas snabb. Vi ändrar därför hjärtat **direkt**, och frågar
servern efteråt. Säger servern nej ändrar vi tillbaka. Det kallas en
**optimistisk uppdatering**.

```dart
final liked = ref(props.value.likedByMe); // startvärde från propen
final count = ref(props.value.likeCount);

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
        {'p': postId, 'u': annaId},
      ));
      await likes.delete(like.id);
    } else {
      await likes.create(body: {'post': postId, 'user': annaId});
    }
  } on ClientException {
    liked.value = wasLiked; // 3. ångra om servern sa nej
    count.value += wasLiked ? 1 : -1;
  }
}
```

## Vanliga misstag

| Misstag | Vad händer | Gör så här |
|---------|------------|------------|
| `setup()` är `async` | Kompilerar inte | `useAsyncData`, eller `async` i `onMounted` |
| `comments.value.add(x)` i realtid | Skärmen uppdateras inte | `comments.value = [...comments.value, x]` |
| Glömt `unsubscribe` | Appen lyssnar fast sidan är stängd | `onUnmounted` + `disposed` |
| Optimistisk uppdatering utan `catch` | Hjärtat visar fel om servern säger nej | Spara det gamla värdet och ändra tillbaka |

## Övningar

**10.1** Visa `FeedRefresh`. Ändra en rubrik i Dashboard och dra för att ladda
om. Syns ändringen?

**10.2** Slå på "Bara Annas inlägg". Hur många inlägg ser du? Stämmer det med
Dashboard?

**10.3** Visa `LiveComments` för inlägget "Mitt första surdegsbröd". Kopiera
dess id från Dashboard. Skriv en kommentar i Dashboard. Dyker den upp i appen
utan att du laddar om?

**10.4** Lägg till en knapp i `LiveComments` som tar bort den senaste
kommentaren med `pb.collection('comments').delete(id)`. Försvinner den från
listan av sig själv?

**10.5** Gör en widget `PbLikeButton` med props `postId`, `likedByMe` och
`likeCount`, och `toggleLike` från kapitlet. Testa att ångra fungerar: lås
Create-regeln för `likes` i Dashboard (🔒) och tryck på hjärtat. Vad händer?
Lås upp regeln igen.

Lösningar finns i [losningar.md](losningar.md#kapitel-10--ladda-om-och-realtid).

Nästa kapitel: [Bygg Kvittra-appen](11-bygg-kvittra-appen.md)

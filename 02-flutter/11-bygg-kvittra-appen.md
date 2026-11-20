# 11. Bygg Kvittra-appen

Nu bygger vi ihop allt till en enkel app som du kan visa upp. Den pratar med din
PocketBase. Vi fortsätter i projektet `kvittra` och bygger vidare på skärmarna
från kapitel 7.

| Skärm | Adress | Vad man gör där |
|-------|--------|-----------------|
| Flödet | `/` | Läser inläggen, gillar och drar för att ladda om |
| Ett inlägg | `/posts/:id` | Läser inlägget och kommenterar. Nya kommentarer dyker upp direkt |
| Nytt inlägg | `/posts/new` | Skriver ett inlägg som sparas i PocketBase |

Innan du börjar:

- [ ] PocketBase är startad (`.\pocketbase serve`).
- [ ] API-reglerna är öppna ([kapitel 8](08-hamta-data-fran-pocketbase.md#öppna-databasen)).
- [ ] `annaId` finns i `lib/data/pocketbase.dart` ([kapitel 9](09-skriva-data-och-realtid.md#appen-är-anna)).
- [ ] `lib/main.dart` startar `KvittraApp` med routern igen. Har du bytt
  `void main()` i kapitel 9 eller 10, byt tillbaka till
  `void main() => runApp(const KvittraApp());`.

Det här är filerna du ändrar:

```
lib/
├── data/pocketbase.dart           ← Steg 1
├── models/post.dart               ← Steg 1
├── widgets/like_button.dart       ← Steg 2
├── widgets/post_card.dart         ← Steg 2
├── screens/feed_screen.dart       ← Steg 3
├── widgets/comment_section.dart   ← Steg 4
├── screens/post_detail_screen.dart ← Steg 4
└── screens/new_post_screen.dart   ← Steg 5
```

`main.dart` och `router.dart` från kapitel 7 behöver du inte ändra.

## Steg 1 – Data

Ett inlägg ska nu också veta hur många som gillar det, och om Anna gillar det.
Med `expand: 'likes_via_post'` får vi alla rader i `likes` som pekar på
inlägget. Det kallas en **bakåtrelation**: `likes` har ett fält `post`, så
PocketBase kan hitta likes "via post".

Byt ut hela `lib/models/post.dart`:

```dart
// lib/models/post.dart
import 'package:pocketbase/pocketbase.dart';

import '../data/pocketbase.dart';

class Post {
  final String id;
  final String author;
  final String title;
  final String body;
  final int likeCount; // hur många som gillar inlägget
  final bool likedByMe; // gillar Anna inlägget?

  const Post({
    required this.id,
    required this.author,
    required this.title,
    required this.body,
    this.likeCount = 0,
    this.likedByMe = false,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as String,
      author: json['author'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
    );
  }

  factory Post.fromRecord(RecordModel record) {
    final likes = record.get<List<RecordModel>>('expand.likes_via_post', []);
    return Post(
      id: record.id,
      author: record.get<String>('expand.author.username', '?'),
      title: record.get<String>('title'),
      body: record.get<String>('body'),
      likeCount: likes.length,
      likedByMe: likes.any((like) => like.get<String>('user') == annaId),
    );
  }
}
```

- `likeCount` och `likedByMe` har startvärden (`= 0` och `= false`). Därför
  fungerar `samplePosts` som förut.
- `likes.any(...)` är sant om **någon** like i listan är Annas.

Byt sedan ut hela `lib/data/pocketbase.dart`. Klistra in Annas id igen:

```dart
// lib/data/pocketbase.dart
import 'package:pocketbase/pocketbase.dart';

import '../models/post.dart';

final pb = PocketBase('http://127.0.0.1:8090');

// Appen är alltid Anna. Klistra in hennes id från Dashboard.
const annaId = 'a1b2c3d4e5f6g7h';

String errorMessage(ClientException e) {
  if (e.statusCode == 0) return 'Kunde inte nå PocketBase. Är den igång?';
  if (e.statusCode == 403) return 'Du får inte se det här. Kontrollera API-reglerna.';
  return 'Något gick fel (${e.statusCode})';
}

// Alla inlägg, nyaste först
Future<List<Post>> fetchPosts() async {
  try {
    final result = await pb.collection('posts').getList(
      perPage: 50,
      sort: '-created',
      expand: 'author,likes_via_post',
    );
    final posts = <Post>[];
    for (final record in result.items) {
      posts.add(Post.fromRecord(record));
    }
    return posts;
  } on ClientException catch (e) {
    throw Exception(errorMessage(e));
  }
}

// Ett inlägg
Future<Post> fetchPost(String id) async {
  try {
    final record = await pb
        .collection('posts')
        .getOne(id, expand: 'author,likes_via_post');
    return Post.fromRecord(record);
  } on ClientException catch (e) {
    throw Exception(errorMessage(e));
  }
}

// Spara ett nytt inlägg
Future<void> createPost(String title, String body) async {
  await pb.collection('posts').create(body: {
    'author': annaId,
    'title': title,
    'body': body,
  });
}
```

## Steg 2 – Gilla-knappen

`LikeButton` från kapitel 4 räknade bara på skärmen. Nu sparar den i
PocketBase. Det är den optimistiska uppdateringen från
[kapitel 10](10-ladda-om-och-realtid.md#gilla-direkt): hjärtat ändras direkt,
och ändras tillbaka om servern säger nej.

Byt ut hela `lib/widgets/like_button.dart`:

```dart
// lib/widgets/like_button.dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';

import '../data/pocketbase.dart';

class LikeButton extends CompositionWidget {
  const LikeButton({
    super.key,
    required this.postId,
    required this.likedByMe,
    required this.likeCount,
  });

  final String postId;
  final bool likedByMe;
  final int likeCount;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();

    // Startvärdena kommer från propsen
    final liked = ref(props.value.likedByMe);
    final count = ref(props.value.likeCount);

    Future<void> toggle() async {
      final wasLiked = liked.value;
      final likes = pb.collection('likes');

      liked.value = !wasLiked; // 1. ändra direkt
      count.value += wasLiked ? -1 : 1;

      try {
        // 2. fråga servern
        if (wasLiked) {
          final like = await likes.getFirstListItem(pb.filter(
            'post = {:p} && user = {:u}',
            {'p': props.value.postId, 'u': annaId},
          ));
          await likes.delete(like.id);
        } else {
          await likes.create(body: {'post': props.value.postId, 'user': annaId});
        }
      } on ClientException {
        liked.value = wasLiked; // 3. ångra om servern sa nej
        count.value += wasLiked ? 1 : -1;
      }
    }

    return (context) => TextButton.icon(
          onPressed: toggle,
          icon: Icon(
            liked.value ? Icons.favorite : Icons.favorite_border,
            color: liked.value ? Colors.red : null,
          ),
          label: Text('${count.value}'),
        );
  }
}
```

I `PostCard` byter du raden med `LikeButton` mot den här:

```dart
// lib/widgets/post_card.dart (längst ner i children)
LikeButton(
  postId: post.id,
  likedByMe: post.likedByMe,
  likeCount: post.likeCount,
),
```

Ta också bort `import '../data/sample_data.dart';` från `post_card.dart`. Den
behövs inte längre.

## Steg 3 – Flödet

Flödet från kapitel 8 får två nya saker: man kan dra för att ladda om, och en
knapp för nytt inlägg. Byt ut hela `lib/screens/feed_screen.dart`:

```dart
// lib/screens/feed_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';

import '../data/pocketbase.dart';
import '../models/post.dart';
import '../widgets/post_card.dart';

class FeedScreen extends CompositionWidget {
  const FeedScreen({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final (status, refresh) = useAsyncData<List<Post>, void>((_) => fetchPosts());

    Future<void> newPost(BuildContext context) async {
      // Öppna formuläret och vänta tills det stängs
      final created = await context.push<bool>('/posts/new');
      if (created == true) refresh(); // hämta igen så att inlägget syns
    }

    return (context) => Scaffold(
          appBar: AppBar(title: const Text('Kvittra')),
          floatingActionButton: FloatingActionButton(
            onPressed: () => newPost(context),
            child: const Icon(Icons.add),
          ),
          body: switch (status.value) {
            AsyncIdle() || AsyncLoading() =>
              const Center(child: CircularProgressIndicator()),
            AsyncError(:final errorValue) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$errorValue'),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: refresh, child: const Text('Försök igen')),
                  ],
                ),
              ),
            AsyncData(:final value) => RefreshIndicator(
                onRefresh: () async => refresh(),
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: value.length,
                  itemBuilder: (context, index) {
                    final post = value[index];
                    return PostCard(
                      key: ValueKey(post.id),
                      post: post,
                      onTap: () => context.push('/posts/${post.id}'),
                    );
                  },
                ),
              ),
          },
        );
  }
}
```

- `context.push<bool>('/posts/new')` väntar tills formuläret stängs. Får vi
  `true` tillbaka har ett inlägg sparats, och då hämtar vi flödet igen.
- `RefreshIndicator` anropar `refresh` när man drar listan nedåt.

## Steg 4 – Inlägget och kommentarerna

`CommentSection` från kapitel 5 sparade kommentarerna bara på skärmen. Nu blir
den `LiveComments` från [kapitel 10](10-ladda-om-och-realtid.md#kommentarer-i-realtid)
med ett textfält. Byt ut hela `lib/widgets/comment_section.dart`:

```dart
// lib/widgets/comment_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';

import '../data/pocketbase.dart';

class CommentSection extends CompositionWidget {
  const CommentSection({super.key, required this.postId});

  final String postId;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final filter = pb.filter('post = {:id}', {'id': props.value.postId});
    final comments = ref(<RecordModel>[]);

    // Realtid: lägg till nya kommentarer, ta bort raderade
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
      comments.value = await pb.collection('comments').getFullList(
            filter: filter,
            sort: 'created',
            expand: 'author',
          );
      final unsub = await pb
          .collection('comments')
          .subscribe('*', onEvent, filter: filter, expand: 'author');
      if (disposed) {
        await unsub(); // sidan hann stängas
      } else {
        unsubscribe = unsub;
      }
    });

    onUnmounted(() {
      disposed = true;
      unsubscribe?.call();
    });

    // Skriva en kommentar
    final (controller, text, _) = useTextEditingController();

    Future<void> send() async {
      await pb.collection('comments').create(body: {
        'post': props.value.postId,
        'author': annaId,
        'body': text.value.trim(),
      });
      text.value = ''; // töm fältet. Kommentaren kommer via realtid.
    }

    return (context) => Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  for (final c in comments.value)
                    ListTile(
                      leading: const Icon(Icons.chat_bubble_outline),
                      title: Text(c.get<String>('body')),
                      subtitle: Text(c.get<String>('expand.author.name', '?')),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: 'Skriv en kommentar…',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: text.value.trim().isNotEmpty ? send : null,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        );
  }
}
```

- En skickad kommentar läggs **inte** in i listan av `send()`. Den kommer
  tillbaka som en `create`-händelse i realtid, precis som andras kommentarer.
- `'author': annaId` gör att kommentaren skrivs av Anna.

Sedan sidan för ett inlägg. Den hämtar inlägget från PocketBase i stället för
från `samplePosts`. Byt ut hela `lib/screens/post_detail_screen.dart`:

```dart
// lib/screens/post_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

import '../data/pocketbase.dart';
import '../models/post.dart';
import '../widgets/comment_section.dart';
import '../widgets/post_card.dart';

class PostDetailScreen extends CompositionWidget {
  const PostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final (status, refresh) =
        useAsyncData<Post, void>((_) => fetchPost(props.value.postId));

    return (context) => Scaffold(
          appBar: AppBar(title: const Text('Inlägg')),
          body: switch (status.value) {
            AsyncIdle() || AsyncLoading() =>
              const Center(child: CircularProgressIndicator()),
            AsyncError(:final errorValue) => Center(
                child: TextButton(
                  onPressed: refresh,
                  child: Text('$errorValue. Försök igen'),
                ),
              ),
            AsyncData(:final value) => Column(
                children: [
                  PostCard(post: value),
                  Expanded(child: CommentSection(postId: value.id)),
                ],
              ),
          },
        );
  }
}
```

## Steg 5 – Nytt inlägg

Formuläret från kapitel 7 fungerar som det är. Det enda som ändras är vad som
händer när man trycker **Publicera**: inlägget sparas i PocketBase.

Öppna `lib/screens/new_post_screen.dart`. Byt
`import '../models/post.dart';` mot `import '../data/pocketbase.dart';`, och
byt ut funktionen `publish`:

```dart
// lib/screens/new_post_screen.dart (byt ut publish)
Future<void> publish(BuildContext context) async {
  // validate() kör alla validators och visar felen
  if (!formKey.currentState!.validate()) return;

  await createPost(title.value.trim(), body.value.trim());
  if (context.mounted) context.pop(true); // true = "ett inlägg sparades"
}
```

- `await createPost(...)` väntar tills PocketBase har sparat inlägget.
- `if (context.mounted)` behövs efter `await`. Användaren kan ha stängt sidan
  medan vi väntade.
- `context.pop(true)` stänger formuläret och säger till flödet att hämta igen.

## Steg 6 – Testa

Klicka **Build** och gå igenom listan. Fungerar allt?

- [ ] Flödet visar inläggen från modul 01, nyaste först.
- [ ] Hjärtat ändras direkt, och antalet stämmer med Dashboard.
- [ ] Ett nytt inlägg syns först i flödet efter **Publicera**.
- [ ] Trycker du på ett inlägg ser du det och dess kommentarer.
- [ ] En kommentar som du skriver i appen dyker upp i listan.
- [ ] En kommentar som skrivs i Dashboard dyker upp i appen direkt.

Grattis! Nu har du en app som du kan visa upp. 🎉

## Övningar

**11.1** Gör appen till din egen. Byt färgen i `colorSchemeSeed` och rubriken i
flödet.

**11.2** Visa inläggets rubrik i `AppBar` på inläggssidan i stället för
"Inlägg". Ledtråd: `status.value.dataOrNull?.title`.

**11.3** Lägg till en papperskorg (`Icons.delete_outline`) i `AppBar` på
inläggssidan. Den ska ta bort inlägget med
`pb.collection('posts').delete(id)` och sedan gå tillbaka till flödet med
`context.pop()`. Dra för att ladda om flödet. Är inlägget borta?

**11.4 Ditt projekt.** Välj **en** sida i ditt eget projekt från modul 01. Bygg
den med en `CompositionWidget` och `useAsyncData`, så att den visar data från
din PocketBase.

Lösningar finns i [losningar.md](losningar.md#kapitel-11--bygg-kvittra-appen).

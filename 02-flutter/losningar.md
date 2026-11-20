# Lösningar

Försök själv innan du tittar här! Det finns ofta flera sätt att lösa en uppgift.
Här visar vi bara den kod som är ny eller ändrad. Importerna
(`package:flutter/material.dart`,
`package:flutter_compositions/flutter_compositions.dart` och ibland
`package:pocketbase/pocketbase.dart`) är ofta bortplockade för att spara plats.

## Kapitel 2 – Dart-grunder

**2.1**

```dart
void main() {
  final username = 'bertil';
  final name = 'Bertil Berg';
  final followers = 2;
  print('$name (@$username) har $followers följare');
}
```

**2.2**

```dart
void main() {
  final usernames = ['anna', 'bertil', 'cissi', 'david'];
  for (final name in usernames) {
    print('@$name');
  }
}
```

**2.3**

```dart
String likeText(int likes) {
  if (likes == 0) {
    return 'Bli först att gilla!';
  } else if (likes == 1) {
    return '1 person gillar detta';
  } else {
    return '$likes personer gillar detta';
  }
}

void main() {
  print(likeText(0));
  print(likeText(1));
  print(likeText(5));
}
```

**2.4**

```dart
String greet({required String name, String greeting = 'Hej'}) {
  return '$greeting $name!';
}

void main() {
  print(greet(name: 'Anna'));                   // Hej Anna!
  print(greet(name: 'Anna', greeting: 'Tjena')); // Tjena Anna!
}
```

**2.5**

```dart
void showBio(String? bio) {
  print(bio ?? 'Ingen bio ännu');
}

void main() {
  showBio('Bakar bröd varje helg');
  showBio(null);
}
```

**2.6**

```dart
class Comment {
  final String id;
  final String post;
  final String author;
  final String body;

  const Comment({
    required this.id,
    required this.post,
    required this.author,
    required this.body,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as String,
      post: json['post'] as String,
      author: json['author'] as String,
      body: json['body'] as String,
    );
  }
}

void main() {
  final json = {
    'id': 'c1',
    'post': 'p1',
    'author': 'bertil',
    'body': 'Fina färger!',
  };
  final comment = Comment.fromJson(json);
  print('${comment.author}: ${comment.body}'); // bertil: Fina färger!
}
```

## Kapitel 3 – Widgets och layout

**3.1** Färgerna på bland annat avatarerna, korten och knapparna ändras.
Flutter räknar fram en hel färgpalett från en enda färg.

**3.2**

```dart
Post(id: 'p7', author: 'cissi', title: 'Ny cykel', body: 'Nu cyklar jag till skolan varje dag.'),
Post(id: 'p8', author: 'david', title: 'Träning i regnet', body: 'Blöta skor men glada miner.'),
```

**3.3**

```dart
Text(
  post.body,
  maxLines: 2,
  overflow: TextOverflow.ellipsis, // visar … när texten inte får plats
),
```

**3.4** Längst ner i `children` i `PostCard`:

```dart
const SizedBox(height: 8),
const Row(
  children: [
    Icon(Icons.favorite_border),
    SizedBox(width: 16),
    Icon(Icons.chat_bubble_outline),
  ],
),
```

**3.5**

```dart
// lib/widgets/user_tile.dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

class UserTile extends CompositionWidget {
  const UserTile({super.key, required this.username});

  final String username;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();

    return (context) {
      final username = props.value.username;
      return Card(
        child: ListTile(
          leading: CircleAvatar(child: Text(username[0].toUpperCase())),
          title: Text('@$username'),
          subtitle: const Text('Kvittra-användare'),
        ),
      );
    };
  }
}
```

I `main.dart`, byt tillfälligt `home:`:

```dart
home: Scaffold(
  appBar: AppBar(title: const Text('Användare')),
  body: ListView.builder(
    itemCount: users.length,
    itemBuilder: (context, index) => UserTile(username: users[index]),
  ),
),
```

där `users` är en lista överst i `main.dart`:

```dart
const users = ['anna', 'bertil', 'cissi', 'david'];
```

## Kapitel 4 – State och interaktion

**4.1** Siffran ökar med 1 när du gillar, och minskar med 1 när du trycker igen.
Varje kort har sin egen `LikeButton`, och därmed sin egen `liked`.

**4.2**

```dart
class FollowButton extends CompositionWidget {
  const FollowButton({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final following = ref(false);
    final followers = ref(12);

    void toggle() {
      following.value = !following.value;
      followers.value += following.value ? 1 : -1;
    }

    return (context) => Column(
          children: [
            Text('${followers.value} följare'),
            FilledButton(
              onPressed: toggle,
              child: Text(following.value ? 'Sluta följa' : 'Följ'),
            ),
          ],
        );
  }
}
```

**4.3** Texten skrivs ut en gång när appen startar, och sedan en gång för varje
tryck på följ-knappen. Ändrar du en `ref` som builder-funktionen **inte** läser
skrivs ingenting ut. Builder-funktionen körs bara om när något den läste har
ändrats.

**4.4**

| Fel | Regel | Rättning |
|-----|-------|----------|
| `final clicks = ref(0);` ligger i builder-funktionen | 2 | Flytta den till `setup()`. Annars blir den en ny `ref` med värdet 0 varje gång |
| `Text('Antal klick: $clicks')` | 2 | Skriv `${clicks.value}` |
| `tags.value.add('#flutter')` | 3 | Skriv `tags.value = [...tags.value, '#flutter']` |

```dart
class TagList extends CompositionWidget {
  const TagList({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final tags = ref(<String>['#kvittra']);
    final clicks = ref(0); // ✅ i setup(), inte i builder-funktionen

    void add() {
      clicks.value++;
      tags.value = [...tags.value, '#flutter']; // ✅ ny lista
    }

    return (context) => Column(
          children: [
            Text('Antal klick: ${clicks.value}'), // ✅ .value
            TextButton(onPressed: add, child: const Text('Lägg till')),
            for (final t in tags.value) Text(t),
          ],
        );
  }
}
```

## Kapitel 5 – ref och listor

**5.1**

```dart
int totalLikes() {
  var sum = 0;
  for (final p in visiblePosts()) {
    sum += likesOf(p);
  }
  return sum;
}

// I builder-funktionen, under texten "Visar X av Y inlägg":
Text('${totalLikes()} likes totalt'),
```

**5.2**

```dart
void sortByLikes() {
  posts.value = [...posts.value]..sort((a, b) => likesOf(b).compareTo(likesOf(a)));
}
// ...
TextButton(onPressed: sortByLikes, child: const Text('Mest gillade först')),
```

`[...posts.value]` gör en kopia först. `sort()` ändrar listan den anropas på.
Sorterar du originalet är det fortfarande samma lista, och ingenting uppdateras.
`b` före `a` ger störst först.

**5.3** `posts.value.removeAt(0)` ändrar listan, men eftersom ingen ny lista
sätts märks ingenting. Skärmen ändras inte. Rätt:

```dart
void removeFirst() {
  if (posts.value.isEmpty) return;
  posts.value = posts.value.sublist(1);
}
```

**5.4**

```dart
void toggleFollow(String author) {
  following.value = following.value.contains(author)
      ? following.value.where((u) => u != author).toSet()
      : {...following.value, author};
}
// I ListTile:
trailing: IconButton(
  icon: Icon(following.value.contains(p.author)
      ? Icons.person_remove
      : Icons.person_add),
  onPressed: () => toggleFollow(p.author),
),
```

När filtret **Följer** är valt försvinner författarens inlägg direkt när du
slutar följa. `visiblePosts()` läser `following.value`, så builder-funktionen
körs igen av sig själv.

**5.5**

```dart
// I builder-funktionen, först i Column:
Padding(
  padding: const EdgeInsets.all(8),
  child: Text('${comments.value.length} kommentarer'),
),
```

**5.6**

```dart
// I builder-funktionen, sist i Column:
Text('Du har skrivit ${text.value.length} tecken'),
```

## Kapitel 6 – Livscykel

**6.1** Ja, sekunderna börjar om från 0. När switchen slås av tas widgeten bort.
När den slås på igen skapas en **ny** widget, och `setup()` körs från början med
`ref(0)`.

**6.2** Utan `onUnmounted` fortsätter `tick` att skrivas ut fast timern inte
syns. Timern lever kvar och slösar på datorn. Varje gång du slår på switchen
startar dessutom en ny timer.

**6.3**

| Situation | Verktyg |
|-----------|---------|
| 1. Starta en timer när sidan visas | `onMounted` |
| 2. Sluta lyssna när sidan stängs | `onUnmounted` |
| 3. Hämta inlägg när sidan öppnas | `onMounted` (eller `useAsyncData` i kapitel 8) |

## Kapitel 7 – Navigation och formulär

**7.1** Under `FilledButton` i formuläret:

```dart
TextButton(
  onPressed: () => context.pop(), // tillbaka, utan inlägg
  child: const Text('Avbryt'),
),
```

**7.2**

```dart
String? validateTitle(String? value) {
  if (value == null || value.trim().isEmpty) return 'Skriv en rubrik';
  if (value.trim().length < 3) return 'Minst 3 tecken';
  if (value.trim().length > 60) return 'Högst 60 tecken';
  return null;
}
```

**7.3** I `newPost` i `FeedScreen`, sist i funktionen:

```dart
ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(content: Text('Inlägget är publicerat')),
);
```

Ändra också raden efter `await` till
`if (post == null || !context.mounted) return;`. Den ser till att skärmen finns
kvar innan vi använder `context`.

**7.4** En ny route i `router.dart`:

```dart
GoRoute(
  path: '/users/:username',
  builder: (context, state) {
    final username = state.pathParameters['username'] ?? '';
    return ProfileScreen(username: username);
  },
),
```

Och skärmen:

```dart
// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

import '../data/sample_data.dart';
import '../models/post.dart';
import '../widgets/post_card.dart';

class ProfileScreen extends CompositionWidget {
  const ProfileScreen({super.key, required this.username});

  final String username;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();

    List<Post> userPosts() {
      final result = <Post>[];
      for (final post in samplePosts) {
        if (post.author == props.value.username) result.add(post);
      }
      return result;
    }

    return (context) {
      final posts = userPosts();
      return Scaffold(
        appBar: AppBar(title: Text('@${props.value.username}')),
        body: ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: posts.length,
          itemBuilder: (context, index) => PostCard(post: posts[index]),
        ),
      );
    };
  }
}
```

💡 Loopen kan också skrivas kortare:
`final userPosts = samplePosts.where((post) => post.author == username).toList();`

## Kapitel 8 – Hämta data från PocketBase

**8.1** Ja, du ser samma inlägg som JSON. List-regeln för `posts` är tom, och
då får **alla** se inläggen, även Chrome som inte är inloggat.

**8.2** Felmeddelandet `Exception: Kunde inte nå PocketBase. Är den igång?`
visas. `statusCode` är `0`, eftersom appen inte fick något svar alls. När
PocketBase är igång igen och du trycker på **Försök igen** kommer inläggen
tillbaka.

**8.3 och 8.4** Ge `Comment` från övning 2.6 en konstruktor till (och
`import 'package:pocketbase/pocketbase.dart';` överst i filen):

```dart
// lib/models/comment.dart (lägg till i klassen)
factory Comment.fromRecord(RecordModel record) {
  return Comment(
    id: record.id,
    post: record.get<String>('post'),
    author: record.get<String>('expand.author.username', '?'),
    body: record.get<String>('body'),
  );
}
```

I `lib/data/pocketbase.dart`:

```dart
import '../models/comment.dart'; // överst i filen

Future<Post> fetchPost(String id) async {
  try {
    final record = await pb.collection('posts').getOne(id, expand: 'author');
    return Post.fromRecord(record);
  } on ClientException catch (e) {
    throw Exception(errorMessage(e));
  }
}

Future<List<Comment>> fetchComments(String postId) async {
  try {
    final result = await pb.collection('comments').getList(
      filter: pb.filter('post = {:id}', {'id': postId}),
      sort: 'created',
      expand: 'author',
    );
    final comments = <Comment>[];
    for (final record in result.items) {
      comments.add(Comment.fromRecord(record));
    }
    return comments;
  } on ClientException catch (e) {
    throw Exception(errorMessage(e));
  }
}
```

`pb.filter('post = {:id}', {'id': postId})` bygger filtret `post = "..."` och
sätter in id:t på ett säkert sätt.

Skärmen:

```dart
// lib/screens/post_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

import '../data/pocketbase.dart';
import '../widgets/post_card.dart';

class PostDetailScreen extends CompositionWidget {
  const PostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final post = useFuture(() => fetchPost(props.raw.postId));
    final comments = useFuture(() => fetchComments(props.raw.postId));

    return (context) => Scaffold(
          appBar: AppBar(title: const Text('Inlägg')),
          body: Column(
            children: [
              switch (post.value) {
                AsyncIdle() || AsyncLoading() => const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                AsyncError() => const Text('Kunde inte hämta inlägget'),
                AsyncData(:final value) => PostCard(post: value),
              },
              Expanded(
                child: switch (comments.value) {
                  AsyncIdle() || AsyncLoading() =>
                    const Center(child: CircularProgressIndicator()),
                  AsyncError() =>
                    const Center(child: Text('Kunde inte hämta kommentarer')),
                  AsyncData(:final value) => ListView.builder(
                      itemCount: value.length,
                      itemBuilder: (context, index) => ListTile(
                        leading: const Icon(Icons.chat_bubble_outline),
                        title: Text('@${value[index].author}'),
                        subtitle: Text(value[index].body),
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

Testa med ett id som inte finns, till exempel `#/posts/finnsinte`. PocketBase
svarar då med `404`, och skärmen visar `Kunde inte hämta inlägget`.

**8.5** I `lib/data/pocketbase.dart`:

```dart
Future<List<RecordModel>> fetchUsers() async {
  try {
    return await pb.collection('users').getFullList(sort: 'username');
  } on ClientException catch (e) {
    throw Exception(errorMessage(e));
  }
}
```

Här gör vi ingen egen klass, utan läser fälten direkt med `get` i skärmen:

```dart
// lib/screens/users_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

import '../data/pocketbase.dart';

class UsersScreen extends CompositionWidget {
  const UsersScreen({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final users = useFuture(fetchUsers);

    return (context) => Scaffold(
          appBar: AppBar(title: const Text('Användare')),
          body: switch (users.value) {
            AsyncIdle() || AsyncLoading() =>
              const Center(child: CircularProgressIndicator()),
            AsyncError(:final errorValue) => Center(child: Text('$errorValue')),
            AsyncData(:final value) => ListView.builder(
                itemCount: value.length,
                itemBuilder: (context, index) {
                  final user = value[index];
                  final username = user.get<String>('username', '?');
                  return ListTile(
                    leading: CircleAvatar(child: Text(username[0].toUpperCase())),
                    title: Text(user.get<String>('name')),
                    subtitle: Text('@$username'),
                  );
                },
              ),
          },
        );
  }
}
```

Och i `router.dart`:

```dart
GoRoute(
  path: '/users',
  builder: (context, state) => const UsersScreen(),
),
```

## Kapitel 9 – Skriva data och realtid

Koden ligger i `run()`, efter att Anna har loggat in.

**9.1**

```dart
final comments = await pb.collection('comments').getFullList(
      filter: pb.filter('post.title = {:t}', {'t': 'Mitt första surdegsbröd'}),
      expand: 'author',
    );
for (final c in comments) {
  final name = c.get<String>('expand.author.name', '?');
  debugPrint('$name: ${c.getStringValue('body')}');
}
```

**9.2**

```dart
final posts = pb.collection('posts');
final post = await posts.create(body: {
  'author': annaId,
  'title': 'Test',
  'body': 'Ett testinlägg',
});
await posts.update(post.id, body: {'title': 'Test 2'});
await posts.delete(post.id);
```

**9.3** Det går. I Dashboard står Bertil som författare. Create-regeln för
`posts` är tom, så PocketBase kontrollerar inte vem som skickar. I en riktig app
med inloggning och regler från modul 01 hade det gett `400`.

```dart
final bertil = await pb.collection('users').getFirstListItem(
      pb.filter('username = {:u}', {'u': 'bertil'}),
    );
await pb.collection('posts').create(body: {
  'author': bertil.id,
  'title': 'Jag är Bertil',
  'body': 'Eller?',
});
```

**9.4** Första försöket ger `400`, eftersom det unika indexet på
`likes (post, user)` säger nej.

```dart
final likes = pb.collection('likes');
final post = await pb.collection('posts').getFirstListItem(
      pb.filter('title = {:t}', {'t': 'Matchdag'}),
    );
try {
  await likes.create(body: {'post': post.id, 'user': annaId});
} on ClientException catch (e) {
  debugPrint('${e.statusCode}'); // 400: Anna har redan gillat
}
final like = await likes.getFirstListItem(
  pb.filter('post = {:p} && user = {:u}', {'p': post.id, 'u': annaId}),
);
await likes.delete(like.id);
await likes.create(body: {'post': post.id, 'user': annaId});
```

**9.5** Anna har 2 följare (Bertil och Cissi) och följer 2 (Bertil och Cissi),
om du inte har ändrat i testdatan.

```dart
final follows = pb.collection('follows');
final followers = await follows.getList(
  perPage: 1,
  filter: pb.filter('following = {:me}', {'me': annaId}),
);
final following = await follows.getList(
  perPage: 1,
  filter: pb.filter('follower = {:me}', {'me': annaId}),
);
debugPrint('${followers.totalItems} följare, följer ${following.totalItems}');
```

**9.6** Det skrivs ut `create: ` följt av kommentarens text. Ändrar du
kommentaren i Dashboard kommer `update`, och tar du bort den kommer `delete`.

## Kapitel 10 – Ladda om och realtid

**10.1** Ja. När du drar listan nedåt anropas `refresh`, och listan hämtas igen
från PocketBase.

**10.2** Du ser Annas två inlägg från modul 01, "Höstpromenad" och
"Morgondimma", plus de inlägg du själv har skapat som Anna i kapitel 9.

**10.3** Ja. PocketBase skickar en `create`-händelse, och `onEvent` lägger till
kommentaren i listan.

**10.4** Lägg funktionen i `LiveComments` och anropa den från en knapp:

```dart
Future<void> deleteLast() async {
  if (comments.value.isEmpty) return;
  await pb.collection('comments').delete(comments.value.last.id);
}
```

```dart
return (context) => Column(
      children: [
        FilledButton(
          onPressed: deleteLast,
          child: const Text('Ta bort senaste'),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final c in comments.value)
                ListTile(
                  title: Text(c.getStringValue('body')),
                  subtitle: Text(c.get<String>('expand.author.name', '?')),
                ),
            ],
          ),
        ),
      ],
    );
```

Ja, kommentaren försvinner av sig själv. PocketBase skickar en
`delete`-händelse, och `onEvent` tar bort den ur listan.

**10.5**

```dart
// lib/pb_like_button.dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';

import 'data/pocketbase.dart';

class PbLikeButton extends CompositionWidget {
  const PbLikeButton({
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
    final liked = ref(props.value.likedByMe);
    final count = ref(props.value.likeCount);

    Future<void> toggleLike() async {
      final wasLiked = liked.value;
      final postId = props.value.postId;
      final likes = pb.collection('likes');

      liked.value = !wasLiked;
      count.value += wasLiked ? -1 : 1;

      try {
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
        liked.value = wasLiked;
        count.value += wasLiked ? 1 : -1;
      }
    }

    return (context) => TextButton.icon(
          onPressed: toggleLike,
          icon: Icon(
            liked.value ? Icons.favorite : Icons.favorite_border,
            color: liked.value ? Colors.red : null,
          ),
          label: Text('${count.value}'),
        );
  }
}
```

När Create-regeln är låst blir hjärtat rött en kort stund och går sedan
tillbaka. PocketBase svarar `403`, och `catch` ändrar tillbaka.

## Kapitel 11 – Bygg Kvittra-appen

**11.1** I `lib/main.dart`:

```dart
theme: ThemeData(colorSchemeSeed: Colors.orange),
```

Och i `FeedScreen`:

```dart
appBar: AppBar(title: const Text('Mitt Kvittra')),
```

**11.2** I builder-funktionen i `PostDetailScreen`:

```dart
appBar: AppBar(title: Text(status.value.dataOrNull?.title ?? 'Inlägg')),
```

**11.3** I `PostDetailScreen`. Lägg till
`import 'package:go_router/go_router.dart';` överst.

```dart
Future<void> deletePost(BuildContext context) async {
  await pb.collection('posts').delete(props.value.postId);
  if (context.mounted) context.pop();
}
```

```dart
appBar: AppBar(
  title: const Text('Inlägg'),
  actions: [
    IconButton(
      onPressed: () => deletePost(context),
      icon: const Icon(Icons.delete_outline),
    ),
  ],
),
```

Ja, inlägget är borta när du har dragit för att ladda om.

**11.4** Ingen lösning. Fråga din lärare om du kör fast!


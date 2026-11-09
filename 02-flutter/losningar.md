# Lösningar

Försök själv innan du tittar här! Det finns ofta flera sätt att lösa en uppgift.
Här visar vi bara den kod som är ny eller ändrad. Importerna
(`package:flutter/material.dart`,
`package:flutter_compositions/flutter_compositions.dart` och ibland
`package:pocketbase/pocketbase.dart`) är ofta bortplockade för att spara plats.

## Kapitel 1 – Kom igång

**1.1** Efter en hot reload (`Ctrl + S`) byts färgen, men siffran är kvar.
Efter en hot restart börjar appen om, och siffran blir 0 igen.

**1.2**

```dart
appBar: AppBar(title: const Text('Kvittra')),
body: Center(child: Text('Så här många gillar: ${likes.value}')),
```

**1.3** Du behöver **Flutter**, **Chrome** och **VS Code**. Android toolchain
och Visual Studio behövs bara om du vill köra appen på en Android-emulator
eller som Windows-app.

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

    final buttonText = computed(() => following.value ? 'Sluta följa' : 'Följ');

    void toggle() {
      following.value = !following.value;
      followers.value += following.value ? 1 : -1;
    }

    return (context) => Column(
          children: [
            Text('${followers.value} följare'),
            FilledButton(onPressed: toggle, child: Text(buttonText.value)),
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

## Kapitel 5 – ref och computed

**5.1**

```dart
final totalLikes = computed(
  () => visible.value.fold(0, (sum, p) => sum + likesOf(p)),
);
// I builder-funktionen, under Text(summary.value):
Text('${totalLikes.value} likes totalt'),
```

`fold` går igenom listan och lägger ihop. Man kan också använda en vanlig
`for`-loop i `computed`.

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
slutar följa. `filtered` läser `following.value`, så den räknas om av sig själv.

## Kapitel 6 – watch och livscykel

**6.1** och **6.2**

```dart
class LikesWatch extends CompositionWidget {
  const LikesWatch({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final likes = ref(0);

    watch(() => likes.value, (newValue, oldValue) {
      if (oldValue == null) return;
      debugPrint(newValue > oldValue ? 'ökade' : 'minskade');
    });

    watchEffect(() {
      debugPrint('likes: ${likes.value}');
    });

    return (context) => Row(
          children: [
            Text('${likes.value}'),
            TextButton(onPressed: () => likes.value++, child: const Text('Gilla')),
            TextButton(
              onPressed: () => likes.value--,
              child: const Text('Ta bort like'),
            ),
          ],
        );
  }
}
```

`watchEffect` skriver ut direkt när appen startar. `watch` skriver bara ut när
`likes` ändras. Med `immediate: true` körs `watch` också direkt, och då är
`oldValue` `null`. Det är därför lösningen har `if (oldValue == null) return;`.

**6.3** Ja, sekunderna börjar om från 0. När switchen slås av tas widgeten bort.
När den slås på igen skapas en **ny** widget, och `setup()` körs från början med
`ref(0)`.

**6.4** Utan `onUnmounted` fortsätter `tick` att skrivas ut fast timern inte
syns. Timern lever kvar och slösar på datorn. Varje gång du slår på switchen
startar dessutom en ny timer.

**6.5**

| Situation | Verktyg |
|-----------|---------|
| 1. "3 kommentarer" | `computed` |
| 2. SnackBar när likes går från 9 till 10 | `watch` (du behöver gamla värdet) |
| 3. Sluta lyssna när sidan stängs | `onUnmounted` |
| 4. Hämta inlägg när sidan öppnas | `onMounted` (eller `useAsyncData` i kapitel 9) |

## Kapitel 7 – Props och composables

**7.1** I `PostCard`:

```dart
const PostCard({super.key, required this.post, this.onTap, this.likeCount = 0});

final int likeCount;

// I setup():
final likeLabel = computed(() => props.value.likeCount == 1
    ? '1 gillning'
    : '${props.value.likeCount} gillningar');

// I builder-funktionen, under Text(post.body):
Text(likeLabel.value),
```

**7.2** I `PostCard`:

```dart
const PostCard({super.key, required this.post, this.onTap, this.onAuthorTap});

final ValueChanged<String>? onAuthorTap;

// I builder-funktionen:
final PostCard(:post, :onTap, :onAuthorTap) = props.value;

// Runt raden med avatar och namn:
InkWell(
  onTap: () => onAuthorTap?.call(post.author),
  child: Row(
    children: [
      CircleAvatar(child: Text(initial.value)),
      const SizedBox(width: 12),
      Text(handle.value, style: textTheme.titleSmall),
    ],
  ),
),
```

Föräldern:

```dart
PostCard(
  post: samplePosts[0],
  onAuthorTap: (name) => debugPrint('Tryckte på $name'),
)
```

`ValueChanged<String>` betyder "en funktion som tar emot en `String`".

**7.3** Ändra `maxLength` till `140` och lägg till:

```dart
final written = computed(() => 'Du har skrivit ${text.value.length} tecken');

// I builder-funktionen, sist i Column:
Text(written.value),
```

**7.4**

```dart
final countLabel = computed(() => '${comments.value.length} kommentarer');

// I builder-funktionen, först i Column:
Padding(
  padding: const EdgeInsets.all(8),
  child: Text(countLabel.value),
),
```

**7.5**

```dart
void removeAt(int index) {
  comments.value = [...comments.value]..removeAt(index);
}

// I ListTile:
trailing: IconButton(
  icon: const Icon(Icons.delete_outline),
  onPressed: () => removeAt(index),
),
```

`[...comments.value]` gör en kopia, så att `comments` får en **ny** lista.

**7.6**

```dart
class LoginBox extends CompositionWidget {
  const LoginBox({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final (emailController, email, _) = useTextEditingController();
    final (passwordController, password, _) = useTextEditingController();

    final canLogin = computed(
      () => email.value.contains('@') && password.value.length >= 8,
    );

    void login() => debugPrint('Loggar in som ${email.value}');

    return (context) => Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'E-post'),
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Lösenord'),
            ),
            FilledButton(
              onPressed: canLogin.value ? login : null,
              child: const Text('Logga in'),
            ),
          ],
        );
  }
}
```

**7.7**

```dart
(ReadonlyRef<bool>, void Function()) useToggle({bool initial = false}) {
  final state = ref(initial);
  void toggle() => state.value = !state.value;
  return (state, toggle);
}

class CommentsToggle extends CompositionWidget {
  const CommentsToggle({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final (showComments, toggleComments) = useToggle();
    final buttonText = computed(
      () => showComments.value ? 'Dölj kommentarer' : 'Visa kommentarer',
    );

    return (context) => Column(
          children: [
            TextButton(onPressed: toggleComments, child: Text(buttonText.value)),
            if (showComments.value) ...[
              const ListTile(title: Text('Fina färger!')),
              const ListTile(title: Text('Snyggt jobbat!')),
            ],
          ],
        );
  }
}
```

**7.8**

```dart
ReadonlyRef<String> useDebounced(
  ReadonlyRef<String> source, {
  Duration delay = const Duration(milliseconds: 300),
}) {
  final debounced = ref(source.raw);
  Timer? timer;

  watch(() => source.value, (value, _) {
    timer?.cancel(); // börja om när användaren skriver igen
    timer = Timer(delay, () => debounced.value = value);
  });

  onUnmounted(() => timer?.cancel());

  return debounced;
}

class SearchBox extends CompositionWidget {
  const SearchBox({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final (controller, search, _) = useTextEditingController();
    final debounced = useDebounced(search);

    watch(() => debounced.value, (q, _) => debugPrint('Söker efter: $q'));

    return (context) => TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Sök'),
        );
  }
}
```

Varje gång `search` ändras stoppas den förra timern och en ny startas. Först
när användaren har slutat skriva i 300 ms hinner timern gå klart.

## Kapitel 8 – Navigation och formulär

**8.1** Under `FilledButton` i formuläret:

```dart
TextButton(
  onPressed: () => context.pop(), // tillbaka, utan inlägg
  child: const Text('Avbryt'),
),
```

**8.2**

```dart
String? validateTitle(String? value) {
  if (value == null || value.trim().isEmpty) return 'Skriv en rubrik';
  if (value.trim().length < 3) return 'Minst 3 tecken';
  if (value.trim().length > 60) return 'Högst 60 tecken';
  return null;
}
```

**8.3** I `newPost` i `FeedScreen`, sist i funktionen:

```dart
ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(content: Text('Inlägget är publicerat')),
);
```

Ändra också raden efter `await` till
`if (post == null || !context.mounted) return;`. Den ser till att skärmen finns
kvar innan vi använder `context`.

**8.4** En ny route i `router.dart`:

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

    final userPosts = computed(() {
      final result = <Post>[];
      for (final post in samplePosts) {
        if (post.author == props.value.username) result.add(post);
      }
      return result;
    });

    return (context) => Scaffold(
          appBar: AppBar(title: Text('@${props.value.username}')),
          body: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: userPosts.value.length,
            itemBuilder: (context, index) => PostCard(post: userPosts.value[index]),
          ),
        );
  }
}
```

💡 Loopen kan också skrivas kortare:
`final userPosts = samplePosts.where((post) => post.author == username).toList();`

**8.5** Med `onAuthorTap` från övning 7.2 behöver du bara ändra i `FeedScreen`:

```dart
return PostCard(
  key: ValueKey(post.id),
  post: post,
  onTap: () => context.push('/posts/${post.id}'),
  onAuthorTap: (name) => context.push('/users/$name'),
);
```

## Kapitel 9 – Hämta data från PocketBase

**9.1** Du ser ungefär `{"items":[],"page":1,"perPage":30,"totalItems":0,...}`,
alltså en tom lista. Chrome är inte inloggat, och List-regeln för `posts` är
`@request.auth.id != ""`. Appen loggar in som Anna först, och därför får den se
inläggen.

**9.2** Felmeddelandet `Exception: Kunde inte nå PocketBase. Är den igång?`
visas. `statusCode` är `0`, eftersom appen inte fick något svar alls. När
PocketBase är igång igen och du trycker på **Försök igen** kommer inläggen
tillbaka.

**9.3 och 6.4** Ge `Comment` från övning 2.6 en konstruktor till (och
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
    await loginAsAnna();
    final record = await pb.collection('posts').getOne(id, expand: 'author');
    return Post.fromRecord(record);
  } on ClientException catch (e) {
    throw Exception(errorMessage(e));
  }
}

Future<List<Comment>> fetchComments(String postId) async {
  try {
    await loginAsAnna();
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

**9.5** I `lib/data/pocketbase.dart`:

```dart
Future<List<RecordModel>> fetchUsers() async {
  try {
    await loginAsAnna();
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

## Kapitel 10 – Skriva data och realtid

Koden ligger i `run()`, efter att Anna har loggat in.

**10.1**

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

**10.2**

```dart
final me = pb.authStore.record!.id;
final posts = pb.collection('posts');
final post = await posts.create(body: {
  'author': me,
  'title': 'Test',
  'body': 'Ett testinlägg',
});
await posts.update(post.id, body: {'title': 'Test 2'});
await posts.delete(post.id);
```

**10.3** Du får ett `ClientException` med statuskod `400`. Create-regeln för
`posts` är `@request.auth.id != "" && @request.body.author = @request.auth.id`.
Anna är inloggad, men `author` är inte hon.

```dart
final bertil = await pb.collection('users').getFirstListItem(
      pb.filter('username = {:u}', {'u': 'bertil'}),
    );
try {
  await pb.collection('posts').create(body: {
    'author': bertil.id,
    'title': 'Jag är Bertil',
    'body': 'Eller?',
  });
} on ClientException catch (e) {
  debugPrint('${e.statusCode}: ${e.response['message']}');
}
```

**10.4** Första försöket ger `400`, eftersom det unika indexet på
`likes (post, user)` säger nej.

```dart
final me = pb.authStore.record!.id;
final likes = pb.collection('likes');
final post = await pb.collection('posts').getFirstListItem(
      pb.filter('title = {:t}', {'t': 'Matchdag'}),
    );
try {
  await likes.create(body: {'post': post.id, 'user': me});
} on ClientException catch (e) {
  debugPrint('${e.statusCode}'); // 400: Anna har redan gillat
}
final like = await likes.getFirstListItem(
  pb.filter('post = {:p} && user = {:u}', {'p': post.id, 'u': me}),
);
await likes.delete(like.id);
await likes.create(body: {'post': post.id, 'user': me});
```

**10.5** Anna har 2 följare (Bertil och Cissi) och följer 2 (Bertil och Cissi),
om du inte har ändrat i testdatan.

```dart
final me = pb.authStore.record!.id;
final follows = pb.collection('follows');
final followers = await follows.getList(
  perPage: 1,
  filter: pb.filter('following = {:me}', {'me': me}),
);
final following = await follows.getList(
  perPage: 1,
  filter: pb.filter('follower = {:me}', {'me': me}),
);
debugPrint('${followers.totalItems} följare, följer ${following.totalItems}');
```

**10.6** Det skrivs ut `create: ` följt av kommentarens text. Ändrar du
kommentaren i Dashboard kommer `update`, och tar du bort den kommer `delete`.

## Kapitel 11 – Provide och inject

**11.1** Ja, de håller sig i synk. Båda hämtar **samma** `ref` med `inject`.

```dart
const counterKey = InjectionKey<Ref<int>>('counter');

class CounterRoot extends CompositionWidget {
  const CounterRoot({super.key});

  @override
  Widget Function(BuildContext) setup() {
    provide(counterKey, ref(0));
    return (context) => const MaterialApp(
          home: Scaffold(body: Column(children: [CounterText(), CounterButton()])),
        );
  }
}

class CounterText extends CompositionWidget {
  const CounterText({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final counter = inject(counterKey);
    return (context) => Text('Talet är ${counter.value}');
  }
}

class CounterButton extends CompositionWidget {
  const CounterButton({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final counter = inject(counterKey);
    return (context) => TextButton(
          onPressed: () => counter.value++,
          child: const Text('Öka'),
        );
  }
}
```

**11.2** och **11.5** `HomePage` med `LogoutButton` och mörkt läge.
`LoginPage` och `LogoutButton` är samma som i kapitlet.

```dart
const themeModeKey = InjectionKey<Ref<ThemeMode>>('themeMode');

class KvittraApp extends CompositionWidget {
  const KvittraApp({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final pb = PocketBase('http://127.0.0.1:8090');
    final auth = AuthService(pb);
    final themeMode = ref(ThemeMode.light);

    provide(pocketBaseKey, pb);
    provide(authKey, auth);
    provide(themeModeKey, themeMode);

    return (context) => MaterialApp(
          title: 'Kvittra',
          themeMode: themeMode.value,
          theme: ThemeData(colorSchemeSeed: Colors.teal),
          darkTheme: ThemeData(
            colorSchemeSeed: Colors.teal,
            brightness: Brightness.dark,
          ),
          home: auth.isLoggedIn.value ? const HomePage() : const LoginPage(),
        );
  }
}

class HomePage extends CompositionWidget {
  const HomePage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final themeMode = inject(themeModeKey);
    final isDark = computed(() => themeMode.value == ThemeMode.dark);

    return (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Kvittra'),
            actions: const [LogoutButton()],
          ),
          body: Column(
            children: [
              const WhoAmI(),
              SwitchListTile(
                title: const Text('Mörkt läge'),
                value: isDark.value,
                onChanged: (on) =>
                    themeMode.value = on ? ThemeMode.dark : ThemeMode.light,
              ),
            ],
          ),
        );
  }
}
```

**11.3**

```dart
class WhoAmI extends CompositionWidget {
  const WhoAmI({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final auth = inject(authKey);
    final text = computed(() {
      final username = auth.user.value?.getStringValue('username') ?? '';
      return 'Inloggad som @$username';
    });
    return (context) => Text(text.value);
  }
}
```

**11.4** Appen kraschar med ett fel om att det inte finns någon provider för
nyckeln (`No provider found`). `inject` letar uppåt i trädet, och där finns
ingen `provide(authKey, ...)`.

## Kapitel 12 – Ladda om och realtid

**12.1** Ja, ändringen syns när du drar för att ladda om. `refresh` hämtar
allt igen.

**12.2** Bertil ser bara sina två inlägg: "Mitt första surdegsbröd" och "Andra
försöket".

**12.3** Ja. PocketBase skickar en `create`-händelse, och `onEvent` lägger till
kommentaren i listan.

**12.4** Lägg funktionen i `LiveComments` och anropa den från en knapp:

```dart
Future<void> deleteLast() async {
  if (comments.value.isEmpty) return;
  try {
    await pb.collection('comments').delete(comments.value.last.id);
    // Ingen ändring i listan här: delete-händelsen tar bort den
  } on ClientException catch (e) {
    debugPrint('Kunde inte ta bort: ${e.statusCode}'); // 404 om den inte är din
  }
}
```

Kommentaren försvinner av sig själv, eftersom en `delete`-händelse kommer i
realtid. Delete-regeln för `comments` är `author = @request.auth.id`. Är
kommentaren någon annans hittar PocketBase den inte för dig, och du får `404`.

**12.5**

```dart
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
    final pb = inject(pocketBaseKey);
    final auth = inject(authKey);

    final liked = ref(props.raw.likedByMe);
    final count = ref(props.raw.likeCount);

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
            {'p': postId, 'u': auth.myId},
          ));
          await likes.delete(like.id);
        } else {
          await likes.create(body: {'post': postId, 'user': auth.myId});
        }
      } on ClientException {
        liked.value = wasLiked;
        count.value += wasLiked ? 1 : -1;
      }
    }

    return (context) => Row(
          children: [
            IconButton(
              onPressed: toggleLike,
              icon: Icon(liked.value ? Icons.favorite : Icons.favorite_border),
            ),
            Text('${count.value}'),
          ],
        );
  }
}
```

Med låst Create-regel blir hjärtat fyllt en kort stund och går sedan tillbaka.
Servern svarar `403`, och `catch` ångrar ändringen.

## Kapitel 13 – Bygg Kvittra-appen

**13.1** Ändra i `FeedPage`:

```dart
final onlyFollowing = ref(false);

final (feed, refresh) = useAsyncData<List<Post>, bool>(
  (following) async {
    final result = await pb.collection('posts').getList(
          perPage: 50,
          sort: '-created',
          expand: 'author,likes_via_post',
          filter: following
              ? pb.filter('author.follows_via_following.follower ?= {:me}',
                  {'me': auth.myId})
              : '',
        );
    return result.items
        .map((r) => Post.fromRecord(r, myId: auth.myId))
        .toList();
  },
  watch: () => onlyFollowing.value,
);
```

Lägg sedan en `Column` runt listan med en `SwitchListTile` överst:

```dart
SwitchListTile(
  title: const Text('Följer'),
  value: onlyFollowing.value,
  onChanged: (v) => onlyFollowing.value = v,
),
```

Filtret betyder: "författaren har en rad i `follows` där `following` är
författaren och `follower` är jag". `?=` betyder "minst en av raderna".

**13.2** I `Post`:

```dart
final int commentCount;

// I fromRecord:
final comments = expand['comments_via_post'] as List<dynamic>? ?? [];
// ...
commentCount: comments.length,
```

Lägg till `comments_via_post` i `expand` i `FeedPage`, `PostPage` och
`ProfilePage`: `expand: 'author,likes_via_post,comments_via_post'`. Visa
`Text('${post.commentCount} kommentarer')` i `PostCard`.

**13.3** I `PostPage`:

```dart
final isMine = computed(
  () => status.value.dataOrNull?.authorId == auth.myId,
);

Future<void> deletePost(BuildContext context) async {
  try {
    await pb.collection('posts').delete(props.value.postId);
    if (context.mounted) context.pop(true); // true = "något ändrades"
  } on ClientException catch (e) {
    debugPrint('Kunde inte radera: ${e.statusCode}');
  }
}

// I AppBar:
actions: [
  if (isMine.value)
    IconButton(
      tooltip: 'Radera',
      icon: const Icon(Icons.delete),
      onPressed: () => deletePost(context),
    ),
],
```

Och i `FeedPage`, så att flödet hämtas igen:

```dart
onTap: () async {
  final changed = await context.push<bool>('/posts/${post.id}');
  if (changed == true) refresh();
},
```

**13.4**

```dart
class EditBioPage extends CompositionWidget {
  const EditBioPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final pb = inject(pocketBaseKey);
    final auth = inject(authKey);
    final (controller, bio, _) = useTextEditingController(
      text: auth.user.raw?.getStringValue('bio') ?? '',
    );
    final saving = ref(false);

    Future<void> save(BuildContext context) async {
      saving.value = true;
      try {
        await pb.collection('users').update(auth.myId, body: {
          'bio': bio.value.trim(),
        });
        if (context.mounted) context.pop(true);
      } on ClientException catch (e) {
        debugPrint('Kunde inte spara: ${e.statusCode}');
      } finally {
        saving.value = false;
      }
    }

    return (context) => Scaffold(
          appBar: AppBar(title: const Text('Ändra bio')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Bio'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: saving.value ? null : () => save(context),
                child: const Text('Spara'),
              ),
            ],
          ),
        );
  }
}
```

I `router.dart`, i listan `routes`:

```dart
GoRoute(path: '/profile/edit', builder: (_, _) => const EditBioPage()),
```

I `ProfilePage`, ändra `final (status, _)` till `final (status, refresh)` och
lägg till en knapp när `isMe.value` är sant:

```dart
TextButton(
  onPressed: () async {
    final saved = await context.push<bool>('/profile/edit');
    if (saved == true) refresh();
  },
  child: const Text('Ändra bio'),
),
```

**13.5** Ingen lösning. Fråga din lärare om du kör fast!

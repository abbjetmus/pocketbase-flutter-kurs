# Lösningar

Försök själv innan du tittar här! Det finns ofta flera sätt att lösa en uppgift.
Här visar vi bara den kod som är ny eller ändrad.

## Kapitel 1 – Kom igång

**1.1** Efter en hot reload (`Ctrl + S`) byts färgen, men siffran är kvar.
Efter en hot restart börjar appen om, och siffran blir 0 igen.

**1.2**

```dart
home: const MyHomePage(title: 'Kvittra'),
// ...
const Text('Du har tryckt på knappen så här många gånger:'),
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

class UserTile extends StatelessWidget {
  const UserTile({super.key, required this.username});

  final String username;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(username[0].toUpperCase())),
        title: Text('@$username'),
        subtitle: const Text('Kvittra-användare'),
      ),
    );
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

**4.1**

```dart
// lib/widgets/follow_button.dart
import 'package:flutter/material.dart';

class FollowButton extends StatefulWidget {
  const FollowButton({super.key});

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  bool _following = false;

  void _toggle() {
    setState(() {
      _following = !_following;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_following) {
      return OutlinedButton(onPressed: _toggle, child: const Text('Följer'));
    }
    return FilledButton(onPressed: _toggle, child: const Text('Följ'));
  }
}
```

**4.2** Ingenting händer på skärmen. Variablerna `_liked` och `_likes` ändras,
men Flutter vet inte om det och kör inte `build` igen. Det är `setState` som
säger till Flutter att rita om.

**4.3** Först i `children` i `Column`:

```dart
Padding(
  padding: const EdgeInsets.all(8),
  child: Text('${_comments.length} kommentarer'),
),
```

**4.4** I `build`, före `return`:

```dart
final canSend = _controller.text.trim().isNotEmpty;
```

Sedan i `TextField` och knappen:

```dart
TextField(
  controller: _controller,
  onChanged: (_) => setState(() {}), // kör build när texten ändras
  // ... som förut ...
),
IconButton(
  onPressed: canSend ? _send : null, // null = grå knapp
  icon: const Icon(Icons.send),
),
```

**4.5**

```dart
itemBuilder: (context, index) => ListTile(
  leading: const Icon(Icons.chat_bubble_outline),
  title: Text(_comments[index]),
  trailing: IconButton(
    icon: const Icon(Icons.delete_outline),
    onPressed: () {
      setState(() {
        _comments.removeAt(index);
      });
    },
  ),
),
```

## Kapitel 5 – Navigation och formulär

**5.1** Under `FilledButton` i formuläret:

```dart
TextButton(
  onPressed: () => context.pop(), // tillbaka, utan inlägg
  child: const Text('Avbryt'),
),
```

**5.2**

```dart
String? validateTitle(String? value) {
  if (value == null || value.trim().isEmpty) return 'Skriv en rubrik';
  if (value.trim().length < 3) return 'Minst 3 tecken';
  if (value.trim().length > 60) return 'Högst 60 tecken';
  return null;
}
```

**5.3** I `_newPost` i `FeedScreen`, efter `setState`:

```dart
ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(content: Text('Inlägget är publicerat')),
);
```

Raden `if (post == null || !mounted) return;` ser till att skärmen finns kvar
innan vi använder `context`.

**5.4** En ny route i `router.dart`:

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

import '../data/sample_data.dart';
import '../models/post.dart';
import '../widgets/post_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.username});

  final String username;

  @override
  Widget build(BuildContext context) {
    final userPosts = <Post>[];
    for (final post in samplePosts) {
      if (post.author == username) userPosts.add(post);
    }

    return Scaffold(
      appBar: AppBar(title: Text('@$username')),
      body: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: userPosts.length,
        itemBuilder: (context, index) => PostCard(post: userPosts[index]),
      ),
    );
  }
}
```

💡 Loopen kan också skrivas kortare:
`final userPosts = samplePosts.where((post) => post.author == username).toList();`

**5.5** I `PostCard`, lägg till parametern och en `InkWell` runt raden:

```dart
const PostCard({super.key, required this.post, this.onTap, this.onAuthorTap});

final Post post;
final VoidCallback? onTap;
final VoidCallback? onAuthorTap;

// ... i build:
InkWell(
  onTap: onAuthorTap,
  child: Row(
    children: [
      CircleAvatar(child: Text(username[0].toUpperCase())),
      const SizedBox(width: 12),
      Text('@$username', style: textTheme.titleSmall),
    ],
  ),
),
```

I `FeedScreen`:

```dart
return PostCard(
  post: post,
  onTap: () => context.push('/posts/${post.id}'),
  onAuthorTap: () => context.push('/users/${post.author}'),
);
```


## Kapitel 6 – Hämta data från PocketBase

**6.1** Du ser ungefär `{"items":[],"page":1,"perPage":30,"totalItems":0,...}`,
alltså en tom lista. Chrome är inte inloggat, och List-regeln för `posts` är
`@request.auth.id != ""`. Appen loggar in som Anna först, och därför får den se
inläggen.

**6.2** Felmeddelandet `Exception: Kunde inte nå PocketBase. Är den igång?`
visas. `statusCode` är `0`, eftersom appen inte fick något svar alls. När
PocketBase är igång igen och du trycker på **Försök igen** kommer inläggen
tillbaka.

**6.3 och 6.4** Ge `Comment` från övning 2.6 en konstruktor till (och
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

import '../data/pocketbase.dart';
import '../models/comment.dart';
import '../models/post.dart';
import '../widgets/post_card.dart';

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  // late = variabeln får sitt värde lite senare, i initState
  late Future<Post> _post;
  late Future<List<Comment>> _comments;

  @override
  void initState() {
    super.initState();
    _post = fetchPost(widget.postId);
    _comments = fetchComments(widget.postId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inlägg')),
      body: Column(
        children: [
          FutureBuilder<Post>(
            future: _post,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                );
              }
              final post = snapshot.data;
              if (snapshot.hasError || post == null) {
                return const Text('Kunde inte hämta inlägget');
              }
              return PostCard(post: post);
            },
          ),
          Expanded(
            child: FutureBuilder<List<Comment>>(
              future: _comments,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Kunde inte hämta kommentarer'));
                }
                final comments = snapshot.data ?? [];
                return ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, index) => ListTile(
                    leading: const Icon(Icons.chat_bubble_outline),
                    title: Text('@${comments[index].author}'),
                    subtitle: Text(comments[index].body),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

Testa med ett id som inte finns, till exempel `#/posts/finnsinte`. PocketBase
svarar då med `404`, och skärmen visar `Kunde inte hämta inlägget`.

**6.5** I `lib/data/pocketbase.dart`:

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
import 'package:pocketbase/pocketbase.dart';

import '../data/pocketbase.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final Future<List<RecordModel>> _future = fetchUsers();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Användare')),
      body: FutureBuilder<List<RecordModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final users = snapshot.data ?? [];
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final username = user.get<String>('username', '?');
              return ListTile(
                leading: CircleAvatar(child: Text(username[0].toUpperCase())),
                title: Text(user.get<String>('name')),
                subtitle: Text('@$username'),
              );
            },
          );
        },
      ),
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

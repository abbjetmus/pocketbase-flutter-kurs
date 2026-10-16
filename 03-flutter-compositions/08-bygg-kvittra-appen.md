# 8. Bygg Kvittra-appen

Nu bygger vi ihop allt till en riktig app. Den pratar med din PocketBase från
modul 01, och den använder allt du har lärt dig i modulen.

| Sida | Adress | Vad man gör där |
|------|--------|-----------------|
| `LoginPage` | `/login` | Loggar in |
| `FeedPage` | `/` | Läser flödet, gillar, drar för att ladda om |
| `PostPage` | `/posts/:id` | Läser ett inlägg och kommenterar i realtid |
| `NewPostPage` | `/posts/new` | Skriver ett nytt inlägg |
| `ProfilePage` | `/users/:id` | Ser en profil och följer eller slutar följa |

Innan du börjar:

- [ ] PocketBase är startad (`.\pocketbase.exe serve`).
- [ ] Kvittras collections, testdata och API-regler från modul 01 finns.
- [ ] Du har ett projekt med paketen från [README](README.md#installation).

## Steg 1 – Mappar

Skapa de här mapparna och filerna i `lib`. Vi fyller dem steg för steg.

```
lib/
├── main.dart              ← appens rot: provide + router
├── router.dart            ← alla sidor och inloggningskravet
├── models/
│   ├── post.dart
│   ├── comment.dart
│   └── user.dart
├── services/
│   ├── auth_service.dart  ← samma som i kapitel 6
│   └── keys.dart          ← samma som i kapitel 6
├── pages/
│   ├── login_page.dart    ← samma som i kapitel 6
│   ├── feed_page.dart
│   ├── post_page.dart
│   ├── new_post_page.dart
│   └── profile_page.dart
└── widgets/
    ├── post_card.dart
    └── comments_section.dart
```

| Mapp | Innehåller |
|------|------------|
| `models` | Vanliga Dart-klasser för datan |
| `services` | Saker som delas med hela appen via `provide` |
| `pages` | En `CompositionWidget` per sida |
| `widgets` | Mindre delar som används på flera sidor |

## Steg 2 – Modeller

Modellerna gör om en `RecordModel` från PocketBase till en vanlig Dart-klass,
som `Post.fromRecord` i modul 02.

`Post` räknar också ut likes. Med `expand: 'likes_via_post'` får vi alla rader i
`likes` som pekar på inlägget. Det kallas en **bakåtrelation**: `likes` har ett
fält `post`, så PocketBase kan hitta likes "via post".

```dart
// lib/models/post.dart
import 'package:pocketbase/pocketbase.dart';

class Post {
  const Post({
    required this.id,
    required this.title,
    required this.body,
    required this.authorId,
    required this.authorName,
    required this.likeCount,
    required this.likedByMe,
  });

  final String id;
  final String title;
  final String body;
  final String authorId;
  final String authorName; // från expand.author
  final int likeCount; // antal i expand.likes_via_post
  final bool likedByMe; // finns min like bland dem?

  factory Post.fromRecord(RecordModel r, {required String myId}) {
    final json = r.toJson();
    final expand = json['expand'] as Map<String, dynamic>? ?? {};
    final author = expand['author'] as Map<String, dynamic>?;
    final likes = (expand['likes_via_post'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    return Post(
      id: r.id,
      title: r.getStringValue('title'),
      body: r.getStringValue('body'),
      authorId: r.getStringValue('author'),
      authorName: author?['name'] as String? ?? 'Okänd',
      likeCount: likes.length,
      likedByMe: likes.any((l) => l['user'] == myId),
    );
  }
}
```

<details>
<summary>Visa <code>comment.dart</code> och <code>user.dart</code></summary>

```dart
// lib/models/comment.dart
import 'package:pocketbase/pocketbase.dart';

class Comment {
  const Comment({
    required this.id,
    required this.body,
    required this.authorName,
  });

  final String id;
  final String body;
  final String authorName;

  factory Comment.fromRecord(RecordModel r) {
    final expand = r.toJson()['expand'] as Map<String, dynamic>? ?? {};
    final author = expand['author'] as Map<String, dynamic>?;
    return Comment(
      id: r.id,
      body: r.getStringValue('body'),
      authorName: author?['name'] as String? ?? 'Okänd',
    );
  }
}
```

```dart
// lib/models/user.dart
import 'package:pocketbase/pocketbase.dart';

class User {
  const User({
    required this.id,
    required this.username,
    required this.name,
    required this.bio,
  });

  final String id;
  final String username;
  final String name;
  final String bio;

  factory User.fromRecord(RecordModel r) => User(
        id: r.id,
        username: r.getStringValue('username'),
        name: r.getStringValue('name'),
        bio: r.getStringValue('bio'),
      );
}
```

</details>

## Steg 3 – Tjänster och inloggning

Kopiera `auth_service.dart`, `keys.dart` och `login_page.dart` från
[kapitel 6](06-provide-inject.md). De fungerar som de är.

<details>
<summary>Visa koden igen</summary>

```dart
// lib/services/auth_service.dart
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';

class AuthService {
  AuthService(this.pb) {
    _update();
    // onChange skickar en händelse vid inloggning och utloggning
    pb.authStore.onChange.listen((_) => _update());
  }

  final PocketBase pb;

  /// Den inloggade användaren (en record i users), eller null.
  final user = ref<RecordModel?>(null);

  late final isLoggedIn = computed(() => user.value != null);

  /// Mitt id, eller '' om ingen är inloggad.
  String get myId => user.raw?.id ?? '';

  void _update() {
    user.value = pb.authStore.isValid ? pb.authStore.record : null;
  }

  Future<void> login(String email, String password) async {
    await pb.collection('users').authWithPassword(email, password);
  }

  void logout() => pb.authStore.clear();
}
```

```dart
// lib/services/keys.dart
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';

import 'auth_service.dart';

const pocketBaseKey = InjectionKey<PocketBase>('pocketBase');
const authKey = InjectionKey<AuthService>('auth');
```

```dart
// lib/pages/login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';

import '../services/keys.dart';

class LoginPage extends CompositionWidget {
  const LoginPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final auth = inject(authKey);
    final (emailController, email, _) = useTextEditingController();
    final (passwordController, password, _) = useTextEditingController();
    final loading = ref(false);
    final error = ref<String?>(null);

    final canLogin = computed(() =>
        email.value.contains('@') &&
        password.value.length >= 8 &&
        !loading.value);

    // Ta bort felet så fort användaren skriver något nytt
    watch(() => (email.value, password.value), (_, _) => error.value = null);

    Future<void> login() async {
      loading.value = true;
      try {
        await auth.login(email.value.trim(), password.value);
        // Ingen navigering här: appen byter sida av sig själv
      } on ClientException {
        error.value = 'Fel e-post eller lösenord';
      } finally {
        loading.value = false;
      }
    }

    return (context) => Scaffold(
          appBar: AppBar(title: const Text('Logga in på Kvittra')),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'E-post'),
              ),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Lösenord',
                  errorText: error.value,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: canLogin.value ? login : null,
                child: Text(loading.value ? 'Loggar in…' : 'Logga in'),
              ),
            ],
          ),
        );
  }
}
```

</details>

## Steg 4 – Router med inloggningskrav

I kapitel 6 valde `KvittraApp` sida med `auth.isLoggedIn.value ? ... : ...`.
Nu har vi flera sidor, så vi använder `go_router` som i modul 02.

`redirect` körs vid varje navigering. Är man inte inloggad skickas man till
`/login`. Är man inloggad och står på `/login` skickas man till flödet.

```dart
// lib/router.dart
import 'package:go_router/go_router.dart';

import 'pages/feed_page.dart';
import 'pages/login_page.dart';
import 'pages/new_post_page.dart';
import 'pages/post_page.dart';
import 'pages/profile_page.dart';
import 'services/auth_service.dart';

GoRouter createRouter(AuthService auth) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final loggedIn = auth.isLoggedIn.raw; // .raw: vi är inte i en builder
      final onLogin = state.matchedLocation == '/login';
      if (!loggedIn && !onLogin) return '/login';
      if (loggedIn && onLogin) return '/';
      return null; // stanna där du är
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/', builder: (_, _) => const FeedPage()),
      // '/posts/new' måste stå före '/posts/:id'
      GoRoute(path: '/posts/new', builder: (_, _) => const NewPostPage()),
      GoRoute(
        path: '/posts/:id',
        builder: (_, state) => PostPage(postId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/users/:id',
        builder: (_, state) => ProfilePage(userId: state.pathParameters['id']!),
      ),
    ],
  );
}
```

- `redirect` körs av `go_router`, inte i en `setup()`. Därför kan den inte
  använda `inject`. Vi skickar in `auth` som argument i stället.
- `.raw` läser värdet utan att bevaka det. Vi är inte i en builder-funktion.
- `/posts/new` måste stå före `/posts/:id`, annars tror routern att `new` är ett
  id.

## Steg 5 – main.dart

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';

import 'router.dart';
import 'services/auth_service.dart';
import 'services/keys.dart';

void main() => runApp(const KvittraApp());

class KvittraApp extends CompositionWidget {
  const KvittraApp({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final pb = PocketBase('http://127.0.0.1:8090');
    final auth = AuthService(pb);

    provide(pocketBaseKey, pb);
    provide(authKey, auth);

    final router = createRouter(auth);
    onUnmounted(router.dispose);

    // Loggar man in eller ut körs routerns redirect igen
    watch(() => auth.isLoggedIn.value, (_, _) => router.refresh());

    return (context) => MaterialApp.router(
          title: 'Kvittra',
          theme: ThemeData(colorSchemeSeed: Colors.teal),
          routerConfig: router,
        );
  }
}
```

Det här händer när Anna loggar in:

1. `authWithPassword` ändrar `pb.authStore`.
2. `AuthService` uppdaterar `user`, och `isLoggedIn` blir `true`.
3. `watch` i `KvittraApp` anropar `router.refresh()`.
4. `redirect` körs igen och skickar Anna till flödet.

Ingen sida behöver navigera själv. Utloggning fungerar likadant åt andra hållet.

`router.dart` importerar alla sidor, så appen kompilerar inte förrän de finns.
Skapa dem först som tomma sidor, till exempel:

```dart
// lib/pages/feed_page.dart (tillfälligt)
import 'package:flutter/material.dart';

class FeedPage extends StatelessWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('Flöde'));
}
```

`PostPage` och `ProfilePage` behöver också fältet `postId` respektive `userId`.
Kör sedan `flutter run -d chrome`. Du ska komma till inloggningen, och efter
inloggningen till den tomma flödessidan.

## Steg 6 – Inläggskortet

`PostCard` visar ett inlägg och en gilla-knapp. Den används både i flödet, på
inläggssidan och på profilen. Gilla-knappen är den optimistiska uppdateringen
från [kapitel 7](07-hamta-data.md#gilla-direkt).

```dart
// lib/widgets/post_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';

import '../models/post.dart';
import '../services/keys.dart';

class PostCard extends CompositionWidget {
  const PostCard({super.key, required this.post, this.onTap});

  final Post post;
  final VoidCallback? onTap;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final pb = inject(pocketBaseKey);
    final auth = inject(authKey);
    final theme = useTheme();

    // Lokalt state för gilla-knappen. Startvärdet kommer från propen.
    final liked = ref(props.raw.post.likedByMe);
    final count = ref(props.raw.post.likeCount);

    // Får kortet nytt data (t.ex. efter refresh) vinner servern
    watch(() => props.value.post, (post, _) {
      liked.value = post.likedByMe;
      count.value = post.likeCount;
    });

    final likeLabel = computed(
      () => count.value == 1 ? '1 gillning' : '${count.value} gillningar',
    );
    final titleStyle = computed(() => theme.value.textTheme.titleMedium);

    Future<void> toggleLike() async {
      final wasLiked = liked.value;
      final postId = props.value.post.id;
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

    return (context) {
      final PostCard(:post, :onTap) = props.value;
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post.title, style: titleStyle.value),
                Text('av ${post.authorName}'),
                const SizedBox(height: 8),
                Text(post.body),
                Row(
                  children: [
                    IconButton(
                      onPressed: toggleLike,
                      icon: Icon(
                        liked.value ? Icons.favorite : Icons.favorite_border,
                        color: liked.value ? Colors.red : null,
                      ),
                    ),
                    Text(likeLabel.value),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    };
  }
}
```

- `liked` och `count` är **lokalt state**. De börjar med värdena från propen
  (`props.raw`), och `watch` skriver över dem när kortet får ny data.
- Kortet hämtar `pb` och `auth` själv med `inject`. Föräldern behöver bara skicka
  in inlägget.

## Steg 7 – Flödet

```dart
// lib/pages/feed_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';

import '../models/post.dart';
import '../services/keys.dart';
import '../widgets/post_card.dart';

class FeedPage extends CompositionWidget {
  const FeedPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final pb = inject(pocketBaseKey);
    final auth = inject(authKey);

    final (feed, refresh) = useAsyncData<List<Post>, void>((_) async {
      final result = await pb.collection('posts').getList(
            perPage: 50,
            sort: '-created',
            expand: 'author,likes_via_post',
          );
      return result.items
          .map((r) => Post.fromRecord(r, myId: auth.myId))
          .toList();
    });

    Future<void> newPost(BuildContext context) async {
      final created = await context.push<bool>('/posts/new');
      if (created == true) refresh();
    }

    return (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Kvittra'),
            actions: [
              IconButton(
                tooltip: 'Min profil',
                icon: const Icon(Icons.person),
                onPressed: () => context.push('/users/${auth.myId}'),
              ),
              IconButton(
                tooltip: 'Logga ut',
                icon: const Icon(Icons.logout),
                onPressed: auth.logout,
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => newPost(context),
            child: const Icon(Icons.edit),
          ),
          body: switch (feed.value) {
            AsyncIdle() || AsyncLoading() =>
              const Center(child: CircularProgressIndicator()),
            AsyncError(:final errorValue) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Kunde inte hämta flödet: $errorValue'),
                    TextButton(
                        onPressed: refresh, child: const Text('Försök igen')),
                  ],
                ),
              ),
            AsyncData(:final value) => RefreshIndicator(
                onRefresh: () async => refresh(),
                child: ListView(
                  children: [
                    for (final post in value)
                      PostCard(
                        key: ValueKey(post.id),
                        post: post,
                        onTap: () => context.push('/posts/${post.id}'),
                      ),
                  ],
                ),
              ),
          },
        );
  }
}
```

- `context.push<bool>('/posts/new')` väntar tills sidan för nytt inlägg stängs.
  Får vi `true` tillbaka hämtar vi flödet igen.
- `newPost` får `context` som argument, eftersom det inte finns någon `context`
  i `setup()`.
- `key: ValueKey(post.id)` gör att Flutter håller isär korten. Utan den kan ett
  korts gilla-state hamna på fel inlägg när listan ändras.

## Steg 8 – Inläggssidan och kommentarer

`PostPage` hämtar inlägget via id, så sidan fungerar även om man går direkt
till `/posts/abc123`.

```dart
// lib/pages/post_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';

import '../models/post.dart';
import '../services/keys.dart';
import '../widgets/comments_section.dart';
import '../widgets/post_card.dart';

class PostPage extends CompositionWidget {
  const PostPage({super.key, required this.postId});

  final String postId;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final pb = inject(pocketBaseKey);
    final auth = inject(authKey);

    final (status, refresh) = useAsyncData<Post, String>(
      (id) async {
        final r = await pb
            .collection('posts')
            .getOne(id, expand: 'author,likes_via_post');
        return Post.fromRecord(r, myId: auth.myId);
      },
      watch: () => props.value.postId, // nytt id → hämta igen
    );

    final title = computed(() => status.value.dataOrNull?.title ?? 'Inlägg');

    return (context) => Scaffold(
          appBar: AppBar(title: Text(title.value)),
          body: switch (status.value) {
            AsyncIdle() || AsyncLoading() =>
              const Center(child: CircularProgressIndicator()),
            AsyncError(:final errorValue) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Kunde inte hämta inlägget: $errorValue'),
                    TextButton(
                        onPressed: refresh, child: const Text('Försök igen')),
                  ],
                ),
              ),
            AsyncData(:final value) => Column(
                children: [
                  PostCard(
                    post: value,
                    onTap: () => context.push('/users/${value.authorId}'),
                  ),
                  Expanded(
                    child: CommentsSection(
                      key: ValueKey(value.id),
                      postId: value.id,
                    ),
                  ),
                ],
              ),
          },
        );
  }
}
```

`CommentsSection` är `LiveComments` från [kapitel 7](07-hamta-data.md#kommentarer-i-realtid),
med en modell och ett fält för att skriva en kommentar.

<details>
<summary>Visa <code>comments_section.dart</code></summary>

```dart
// lib/widgets/comments_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';

import '../models/comment.dart';
import '../services/keys.dart';

class CommentsSection extends CompositionWidget {
  const CommentsSection({super.key, required this.postId});

  final String postId;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final pb = inject(pocketBaseKey);
    final auth = inject(authKey);
    final filter = pb.filter('post = {:id}', {'id': props.raw.postId});

    // 1. Hämta kommentarerna en gång
    final (status, _) = useAsyncData<List<Comment>, void>((_) async {
      final list = await pb.collection('comments').getFullList(
            filter: filter,
            sort: 'created',
            expand: 'author',
          );
      return list.map(Comment.fromRecord).toList();
    });

    // 2. Det som visas. Ändras både av hämtningen och av realtid.
    final comments = ref(<Comment>[]);
    watch(() => status.value, (s, _) {
      if (s case AsyncData(:final value)) comments.value = value;
    });

    // 3. Realtid: lägg till nya kommentarer, ta bort raderade
    void onEvent(RecordSubscriptionEvent e) {
      final record = e.record;
      if (record == null) return;
      final c = Comment.fromRecord(record);
      if (e.action == 'create' && !comments.value.any((x) => x.id == c.id)) {
        comments.value = [...comments.value, c];
      } else if (e.action == 'delete') {
        comments.value = comments.value.where((x) => x.id != c.id).toList();
      }
    }

    UnsubscribeFunc? unsubscribe;
    var disposed = false;

    onMounted(() async {
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

    // 4. Skriva en kommentar
    final (textController, text, _) = useTextEditingController();
    final sending = ref(false);
    final canSend = computed(
      () => text.value.trim().isNotEmpty && !sending.value,
    );

    Future<void> send() async {
      sending.value = true;
      try {
        await pb.collection('comments').create(body: {
          'post': props.value.postId,
          'author': auth.myId,
          'body': text.value.trim(),
        });
        text.value = ''; // töm fältet. Kommentaren kommer via realtid.
      } on ClientException catch (e) {
        debugPrint('Kunde inte skicka: ${e.response}');
      } finally {
        sending.value = false;
      }
    }

    final heading = computed(() => 'Kommentarer (${comments.value.length})');

    return (context) => Column(
          children: [
            ListTile(title: Text(heading.value)),
            Expanded(
              child: ListView(
                children: [
                  for (final c in comments.value)
                    ListTile(title: Text(c.body), subtitle: Text(c.authorName)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: textController,
                      decoration: const InputDecoration(
                        hintText: 'Skriv en kommentar…',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: canSend.value ? send : null,
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

</details>

- En skickad kommentar läggs **inte** in i listan av `send()`. Den kommer
  tillbaka som en `create`-händelse i realtid, precis som andras kommentarer.
- `!comments.value.any(...)` ser till att samma kommentar inte läggs in två
  gånger, om hämtningen och händelsen råkar komma samtidigt.
- `'author': auth.myId` krävs av Create-regeln för `comments`.

## Steg 9 – Nytt inlägg

```dart
// lib/pages/new_post_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketbase/pocketbase.dart';

import '../services/keys.dart';

class NewPostPage extends CompositionWidget {
  const NewPostPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final pb = inject(pocketBaseKey);
    final auth = inject(authKey);
    final (titleController, title, _) = useTextEditingController();
    final (bodyController, body, _) = useTextEditingController();
    final saving = ref(false);
    final error = ref<String?>(null);

    final titleError = computed(() =>
        title.value.isNotEmpty && title.value.trim().length < 3
            ? 'Minst 3 tecken'
            : null);
    final canSave = computed(() =>
        title.value.trim().length >= 3 &&
        body.value.trim().isNotEmpty &&
        !saving.value);

    Future<void> save(BuildContext context) async {
      saving.value = true;
      error.value = null;
      try {
        await pb.collection('posts').create(body: {
          'author': auth.myId,
          'title': title.value.trim(),
          'body': body.value.trim(),
        });
        if (context.mounted) context.pop(true); // true = "något skapades"
      } on ClientException catch (e) {
        error.value = 'Kunde inte spara (${e.statusCode})';
      } finally {
        saving.value = false;
      }
    }

    return (context) => Scaffold(
          appBar: AppBar(title: const Text('Nytt inlägg')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Rubrik',
                  errorText: titleError.value,
                ),
              ),
              TextField(
                controller: bodyController,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(labelText: 'Text'),
              ),
              if (error.value != null)
                Text(error.value!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: canSave.value ? () => save(context) : null,
                child: Text(saving.value ? 'Sparar…' : 'Publicera'),
              ),
            ],
          ),
        );
  }
}
```

- `titleError` visar inget fel förrän användaren har börjat skriva.
- `context.pop(true)` stänger sidan och säger till flödet att något har skapats.
- `if (context.mounted)` behövs efter `await`. Användaren kan ha stängt sidan
  medan vi väntade.

## Steg 10 – Profilen

Profilen hämtar fyra saker: användaren, antal följare, om **jag** följer
användaren och användarens inlägg. Följ-knappen fungerar som gilla-knappen: den
ändras direkt och ångras om servern säger nej.

<details>
<summary>Visa <code>profile_page.dart</code></summary>

```dart
// lib/pages/profile_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketbase/pocketbase.dart';

import '../models/post.dart';
import '../models/user.dart';
import '../services/keys.dart';
import '../widgets/post_card.dart';

class Profile {
  const Profile({
    required this.user,
    required this.followers,
    required this.followedByMe,
    required this.posts,
  });

  final User user;
  final int followers;
  final bool followedByMe;
  final List<Post> posts;
}

class ProfilePage extends CompositionWidget {
  const ProfilePage({super.key, required this.userId});

  final String userId;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final pb = inject(pocketBaseKey);
    final auth = inject(authKey);
    final follows = pb.collection('follows');

    Future<Profile> fetchProfile(String userId) async {
      final user = await pb.collection('users').getOne(userId);
      final followers = await follows.getList(
        perPage: 1,
        filter: pb.filter('following = {:id}', {'id': userId}),
      );
      final mine = await follows.getList(
        perPage: 1,
        filter: pb.filter(
          'follower = {:me} && following = {:id}',
          {'me': auth.myId, 'id': userId},
        ),
      );
      final posts = await pb.collection('posts').getList(
            perPage: 50,
            sort: '-created',
            filter: pb.filter('author = {:id}', {'id': userId}),
            expand: 'author,likes_via_post',
          );
      return Profile(
        user: User.fromRecord(user),
        followers: followers.totalItems,
        followedByMe: mine.totalItems > 0,
        posts: posts.items
            .map((r) => Post.fromRecord(r, myId: auth.myId))
            .toList(),
      );
    }

    final (status, _) = useAsyncData<Profile, String>(
      fetchProfile,
      watch: () => props.value.userId,
    );

    // Lokalt state för följ-knappen. Synkas från servern.
    final followedByMe = ref(false);
    final followers = ref(0);
    watch(() => status.value, (s, _) {
      if (s case AsyncData(:final value)) {
        followedByMe.value = value.followedByMe;
        followers.value = value.followers;
      }
    });

    final isMe = computed(() => props.value.userId == auth.myId);
    final followLabel =
        computed(() => followedByMe.value ? 'Sluta följa' : 'Följ');
    final followersLabel = computed(() => '${followers.value} följare');

    Future<void> toggleFollow() async {
      final id = props.value.userId;
      final was = followedByMe.value;
      followedByMe.value = !was; // ändra direkt
      followers.value += was ? -1 : 1;
      try {
        if (was) {
          final row = await follows.getFirstListItem(pb.filter(
            'follower = {:me} && following = {:id}',
            {'me': auth.myId, 'id': id},
          ));
          await follows.delete(row.id);
        } else {
          await follows.create(body: {'follower': auth.myId, 'following': id});
        }
      } on ClientException {
        followedByMe.value = was; // ångra
        followers.value += was ? 1 : -1;
      }
    }

    return (context) => Scaffold(
          appBar: AppBar(title: const Text('Profil')),
          body: switch (status.value) {
            AsyncIdle() || AsyncLoading() =>
              const Center(child: CircularProgressIndicator()),
            AsyncError(:final errorValue) =>
              Center(child: Text('Kunde inte hämta profilen: $errorValue')),
            AsyncData(:final value) => ListView(
                children: [
                  ListTile(
                    title: Text(value.user.name),
                    subtitle: Text('@${value.user.username}\n${value.user.bio}'),
                    isThreeLine: true,
                  ),
                  ListTile(
                    title: Text(followersLabel.value),
                    trailing: isMe.value
                        ? null
                        : FilledButton.tonal(
                            onPressed: toggleFollow,
                            child: Text(followLabel.value),
                          ),
                  ),
                  for (final post in value.posts)
                    PostCard(
                      key: ValueKey(post.id),
                      post: post,
                      onTap: () => context.push('/posts/${post.id}'),
                    ),
                ],
              ),
          },
        );
  }
}
```

</details>

- `useAsyncData` med `watch: () => props.value.userId` hämtar en ny profil om
  man går från en profil till en annan.
- `followedByMe` och `followers` är lokala `ref` som synkas från servern med
  `watch`. Samma mönster som i `PostCard`.
- På sin egen profil ser man ingen följ-knapp (`isMe`).

## Steg 11 – Testa

Gå igenom listan. Fungerar allt?

- [ ] Fel lösenord ger "Fel e-post eller lösenord".
- [ ] Anna kommer till flödet och ser inläggen från modul 01.
- [ ] Hjärtat ändras direkt, och antalet stämmer med Dashboard.
- [ ] Ett nytt inlägg syns först i flödet efter **Publicera**.
- [ ] En kommentar som skrivs i Dashboard dyker upp på inläggssidan direkt.
- [ ] Anna kan följa David, och antalet följare ökar.
- [ ] Efter **Logga ut** kommer man till inloggningen.

💡 Laddar du om sidan i Chrome är du utloggad. Inloggningen sparas bara i
minnet. Vill du spara den finns `AsyncAuthStore` i paketet `pocketbase`.

## Övningar

**8.1** Lägg till en knapp **Följer** i flödet som bara visar inlägg från dem
du följer. Filtret är
`pb.filter('author.follows_via_following.follower ?= {:me}', {'me': auth.myId})`.
Använd en `ref` och `watch` i `useAsyncData`.

**8.2** Visa antal kommentarer på varje `PostCard`. Tips: lägg till
`comments_via_post` i `expand` och ett fält `commentCount` i `Post`.

**8.3** Låt författaren radera sitt eget inlägg från `PostPage`. Visa en
`IconButton` i `AppBar` bara om inlägget är ditt, och gå tillbaka till flödet
efteråt.

**8.4** Gör en sida där man kan ändra sin egen `bio`. Använd
`useTextEditingController` och `pb.collection('users').update(...)`. Öppna den
från profilen när `isMe` är sant.

**8.5 Ditt projekt.** Välj **en** sida i ditt eget projekt från modul 01. Bygg
den med en `CompositionWidget`, `useAsyncData` och `inject(pocketBaseKey)`.

Lösningar finns i [losningar.md](losningar.md#kapitel-8--bygg-kvittra-appen).

Grattis! Du har byggt en hel app med Flutter Compositions och PocketBase. 🎉

# Lösningar

Försök själv innan du tittar här! Det finns ofta flera sätt att lösa samma
uppgift. Importerna (`package:flutter/material.dart`,
`package:flutter_compositions/flutter_compositions.dart` och ibland
`package:pocketbase/pocketbase.dart`) är bortplockade för att spara plats.

## Kapitel 1 – Introduktion

**1.1** Siffran går mellan 41 och 42. Hjärtat blir fyllt när du har gillat.

**1.2**

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

**1.3** Texten skrivs ut en gång när appen startar, och sedan en gång för varje
tryck på följ-knappen. Ändrar du en `ref` som builder-funktionen **inte** läser
skrivs ingenting ut. Builder-funktionen körs bara om när något den läste har
ändrats.

**1.4**

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

## Kapitel 2 – ref och computed

**2.1**

```dart
final totalLikes = computed(
  () => visible.value.fold(0, (sum, p) => sum + p.likes),
);
// I builder-funktionen, under Text(summary.value):
Text('${totalLikes.value} likes totalt'),
```

`fold` går igenom listan och lägger ihop. Man kan också använda en vanlig
`for`-loop i `computed`.

**2.2**

```dart
void sortByLikes() {
  posts.value = [...posts.value]..sort((a, b) => b.likes.compareTo(a.likes));
}
// ...
TextButton(onPressed: sortByLikes, child: const Text('Mest gillade först')),
```

`[...posts.value]` gör en kopia först. `sort()` ändrar listan den anropas på.
Sorterar du originalet är det fortfarande samma lista, och ingenting uppdateras.
`b` före `a` ger störst först.

**2.3** `posts.value.removeAt(0)` ändrar listan, men eftersom ingen ny lista
sätts märks ingenting. Skärmen ändras inte. Rätt:

```dart
void removeFirst() {
  if (posts.value.isEmpty) return;
  posts.value = posts.value.sublist(1);
}
```

**2.4**

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

## Kapitel 3 – watch och livscykel

**3.1** och **3.2**

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

**3.3** Ja, sekunderna börjar om från 0. När switchen slås av tas widgeten bort.
När den slås på igen skapas en **ny** widget, och `setup()` körs från början med
`ref(0)`.

**3.4** Utan `onUnmounted` fortsätter `tick` att skrivas ut fast timern inte
syns. Timern lever kvar och slösar på datorn. Varje gång du slår på switchen
startar dessutom en ny timer.

**3.5**

| Situation | Verktyg |
|-----------|---------|
| 1. "3 kommentarer" | `computed` |
| 2. SnackBar när likes går från 9 till 10 | `watch` (du behöver gamla värdet) |
| 3. Sluta lyssna när sidan stängs | `onUnmounted` |
| 4. Hämta inlägg när sidan öppnas | `onMounted` (eller `useAsyncData` i kapitel 7) |

## Kapitel 4 – Props och composables

**4.1** Med `likeCount: 1` står det "1 gillning". Med `likeCount: 5` står det
"5 gillningar".

**4.2**

```dart
class PostCard extends CompositionWidget {
  const PostCard({
    super.key,
    required this.title,
    required this.author,
    required this.likeCount,
    this.onTap,
    this.onAuthorTap,
  });

  final String title;
  final String author;
  final int likeCount;
  final VoidCallback? onTap;
  final ValueChanged<String>? onAuthorTap;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final theme = useTheme();

    final likeLabel = computed(() => props.value.likeCount == 1
        ? '1 gillning'
        : '${props.value.likeCount} gillningar');
    final titleStyle = computed(() => theme.value.textTheme.titleMedium);

    return (context) {
      final PostCard(:title, :author, :onTap, :onAuthorTap) = props.value;
      return Card(
        child: ListTile(
          title: Text(title, style: titleStyle.value),
          subtitle: InkWell(
            onTap: () => onAuthorTap?.call(author),
            child: Text('av $author · ${likeLabel.value}'),
          ),
          onTap: onTap,
        ),
      );
    };
  }
}
```

Föräldern:

```dart
PostCard(
  title: 'Höstpromenad',
  author: 'anna',
  likeCount: 2,
  onAuthorTap: (name) => debugPrint('Tryckte på $name'),
)
```

**4.3**

```dart
class CommentBox extends CompositionWidget {
  const CommentBox({super.key});

  @override
  Widget Function(BuildContext) setup() {
    const maxLength = 140;
    final (controller, text, _) = useTextEditingController();

    final remaining = computed(() => maxLength - text.value.length);
    final error = computed(() =>
        remaining.value < 0 ? '${-remaining.value} tecken för mycket' : null);
    final canSend = computed(
      () => text.value.trim().isNotEmpty && remaining.value >= 0,
    );
    final written = computed(() => 'Du har skrivit ${text.value.length} tecken');

    void send() {
      debugPrint('Skickar: ${text.value.trim()}');
      text.value = '';
    }

    return (context) => Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Skriv en kommentar…',
                      errorText: error.value,
                      suffixText: '${remaining.value}',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: canSend.value ? send : null,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
            Text(written.value),
          ],
        );
  }
}
```

**4.4**

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

**4.5**

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

**4.6**

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

## Kapitel 5 – Skriva data och realtid

Koden ligger i `run()`, efter att Anna har loggat in.

**5.1**

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

**5.2**

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

**5.3** Du får ett `ClientException` med statuskod `400`. Create-regeln för
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

**5.4** Första försöket ger `400`, eftersom det unika indexet på
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

**5.5** Anna har 2 följare (Bertil och Cissi) och följer 2 (Bertil och Cissi),
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

**5.6** Det skrivs ut `create: ` följt av kommentarens text. Ändrar du
kommentaren i Dashboard kommer `update`, och tar du bort den kommer `delete`.

## Kapitel 6 – Provide och inject

**6.1** Ja, de håller sig i synk. Båda hämtar **samma** `ref` med `inject`.

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

**6.2** och **6.5** `HomePage` med `LogoutButton` och mörkt läge.
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

**6.3**

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

**6.4** Appen kraschar med ett fel om att det inte finns någon provider för
nyckeln (`No provider found`). `inject` letar uppåt i trädet, och där finns
ingen `provide(authKey, ...)`.

## Kapitel 7 – Hämta data

**7.1** Ja, ändringen syns när du drar för att ladda om.

```dart
class FeedSimple extends CompositionWidget {
  const FeedSimple({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final pb = inject(pocketBaseKey);

    final (posts, refresh) = useAsyncData<List<RecordModel>, void>(
      (_) => pb.collection('posts').getFullList(
            sort: '-created',
            expand: 'author',
          ),
    );

    return (context) => switch (posts.value) {
          AsyncIdle() || AsyncLoading() =>
            const Center(child: CircularProgressIndicator()),
          AsyncError(:final errorValue) => Center(child: Text('Fel: $errorValue')),
          AsyncData(:final value) => RefreshIndicator(
              onRefresh: () async => refresh(),
              child: ListView(
                children: [
                  for (final r in value)
                    ListTile(
                      title: Text(r.getStringValue('title')),
                      subtitle: Text(r.get<String>('expand.author.name', '?')),
                    ),
                ],
              ),
            ),
        };
  }
}
```

**7.2** Bertil ser bara sina två inlägg: "Mitt första surdegsbröd" och "Andra
försöket".

**7.3** Ja. PocketBase skickar en `create`-händelse, och `onEvent` lägger till
kommentaren i listan.

**7.4** Lägg funktionen i `LiveComments` och anropa den från en knapp:

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

**7.5**

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

## Kapitel 8 – Bygg Kvittra-appen

**8.1** Ändra i `FeedPage`:

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

**8.2** I `Post`:

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

**8.3** I `PostPage`:

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

**8.4**

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

**8.5** Ingen lösning. Fråga din lärare om du kör fast!

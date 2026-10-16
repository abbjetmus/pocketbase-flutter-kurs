# 5. Navigation och formulär

En riktig app har flera skärmar. I det här kapitlet får Kvittra tre:

| Skärm | Adress | Visar |
|-------|--------|-------|
| Flödet | `/` | Alla inlägg |
| Ett inlägg | `/posts/p1` | Inlägget och kommentarerna |
| Nytt inlägg | `/posts/new` | Ett formulär |

## Skärmar ligger i en stapel

När du öppnar en ny skärm läggs den **överst**, som en tallrik på en stapel.
När du går tillbaka tas den översta bort.

```
 push('/posts/p1')           pop()
┌──────────┐   ┌──────────┐   ┌──────────┐
│          │   │ Inlägg   │   │          │
│ Flöde    │──►│ Flöde    │──►│ Flöde    │
└──────────┘   └──────────┘   └──────────┘
```

## go_router

Vi använder paketet **go_router** för att navigera. Där får varje skärm en
adress, ungefär som sidor på en webbplats. Öppna terminalen i VS Code och skriv:

```powershell
flutter pub add go_router
```

Skapa en mapp `lib/screens/` för skärmarna. Flytta `FeedScreen` från
`main.dart` till `lib/screens/feed_screen.dart`.

### Bestäm adresserna

```dart
// lib/router.dart
import 'package:go_router/go_router.dart';

import 'screens/feed_screen.dart';
import 'screens/new_post_screen.dart';
import 'screens/post_detail_screen.dart';

final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const FeedScreen(),
    ),
    GoRoute(
      path: '/posts/new',
      builder: (context, state) => const NewPostScreen(),
    ),
    GoRoute(
      path: '/posts/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return PostDetailScreen(postId: id);
      },
    ),
  ],
);
```

- En `GoRoute` kopplar en adress (`path`) till en skärm (`builder`).
- `:id` är en **parameter**. För adressen `/posts/p3` blir `id` texten `'p3'`.
- `state.pathParameters['id']` kan i teorin vara `null`, så vi använder `??`
  och får en tom text i stället.

⚠️ **Ordningen spelar roll.** `/posts/new` måste stå **före** `/posts/:id`.
Annars tror go_router att `new` är ett id.

### Använd routern i main.dart

Byt `MaterialApp(home: ...)` mot `MaterialApp.router`:

```dart
// lib/main.dart
import 'package:flutter/material.dart';

import 'router.dart';

void main() {
  runApp(const KvittraApp());
}

class KvittraApp extends StatelessWidget {
  const KvittraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Kvittra',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      routerConfig: router,
    );
  }
}
```

## Navigera

go_router ger dig tre kommandon:

| Kommando | Gör | Exempel |
|----------|-----|---------|
| `context.push('/posts/p1')` | Lägger en skärm överst. Du kan gå tillbaka | Öppna ett inlägg |
| `context.pop()` | Tar bort den översta skärmen | Tillbaka-knappen |
| `context.go('/')` | Byter till skärmen. Stapeln byggs om | Gå till startsidan |

Alla tre kräver `import 'package:go_router/go_router.dart';` överst i filen.

💡 `AppBar` visar själv en tillbaka-pil när det finns en skärm att gå tillbaka
till.

### Gör PostCard klickbart

Lägg till en parameter `onTap` i `PostCard`. Den som använder kortet bestämmer
vad som händer när man trycker.

```dart
// lib/widgets/post_card.dart (ändringar)
class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post, this.onTap});

  final Post post;
  final VoidCallback? onTap; // en funktion, eller null

  @override
  Widget build(BuildContext context) {
    // ... som förut ...
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          // ... som förut ...
        ),
      ),
    );
  }
}
```

`VoidCallback` betyder "en funktion som inte tar några parametrar". `InkWell`
gör en yta klickbar.

## Skärmen för ett inlägg

Först en funktion som letar upp ett inlägg med ett visst id:

```dart
// lib/data/sample_data.dart (lägg till)
Post? findPost(String id) {
  for (final post in samplePosts) {
    if (post.id == id) return post;
  }
  return null; // hittades inte
}
```

Sedan skärmen. Den visar kortet överst och `CommentSection` från kapitel 4
under:

```dart
// lib/screens/post_detail_screen.dart
import 'package:flutter/material.dart';

import '../data/sample_data.dart';
import '../widgets/comment_section.dart';
import '../widgets/post_card.dart';

class PostDetailScreen extends StatelessWidget {
  const PostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  Widget build(BuildContext context) {
    final post = findPost(postId);

    if (post == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Inlägget finns inte')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(post.title)),
      body: Column(
        children: [
          PostCard(post: post),
          const Expanded(child: CommentSection()),
        ],
      ),
    );
  }
}
```

## Flödet

`FeedScreen` blir en `StatefulWidget`, eftersom listan ska kunna få nya inlägg.

```dart
// lib/screens/feed_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/sample_data.dart';
import '../models/post.dart';
import '../widgets/post_card.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  Future<void> _newPost() async {
    // Öppna formuläret och vänta tills det stängs
    final post = await context.push<Post>('/posts/new');
    if (post == null || !mounted) return;
    setState(() {
      samplePosts.insert(0, post); // nya inlägg hamnar först
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kvittra')),
      body: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: samplePosts.length,
        itemBuilder: (context, index) {
          final post = samplePosts[index];
          return PostCard(
            post: post,
            onTap: () => context.push('/posts/${post.id}'),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _newPost,
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

- `context.push<Post>(...)` öppnar formuläret. Med `await` väntar vi tills det
  stängs. Formuläret kan skicka tillbaka en `Post`.
- Blir svaret `null` har användaren gått tillbaka utan att publicera.
- `mounted` är sant så länge skärmen finns kvar. Efter en `await` är det bra
  att kolla det.

## Formulär

Ett formulär i Flutter har tre delar:

| Del | Gör |
|-----|-----|
| `Form` | Håller ihop alla fält |
| `GlobalKey<FormState>` | Ett "handtag" till formuläret. Med det kan du kontrollera alla fält på en gång |
| `TextFormField` | Ett textfält med en `validator` |

En **validator** är en funktion som kontrollerar det man har skrivit. Den
returnerar `null` om allt är okej, eller ett **felmeddelande** som visas under
fältet.

```dart
// lib/validators.dart
String? validateTitle(String? value) {
  if (value == null || value.trim().isEmpty) return 'Skriv en rubrik';
  if (value.trim().length < 3) return 'Minst 3 tecken';
  return null; // okej
}

String? validateBody(String? value) {
  if (value == null || value.trim().isEmpty) return 'Skriv något';
  return null;
}
```

### Skärmen för nytt inlägg

```dart
// lib/screens/new_post_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/post.dart';
import '../validators.dart';

class NewPostScreen extends StatefulWidget {
  const NewPostScreen({super.key});

  @override
  State<NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends State<NewPostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _publish() {
    // validate() kör alla validators och visar felen
    if (!_formKey.currentState!.validate()) return;

    final post = Post(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // ett id som inte finns än
      author: 'anna', // vi låtsas att du är anna
      title: _titleController.text.trim(),
      body: _bodyController.text.trim(),
    );
    context.pop(post); // stäng och skicka tillbaka inlägget
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nytt inlägg')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Rubrik',
                border: OutlineInputBorder(),
              ),
              validator: validateTitle,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bodyController,
              maxLines: 5,
              maxLength: 280,
              decoration: const InputDecoration(
                labelText: 'Vad har du på hjärtat?',
                border: OutlineInputBorder(),
              ),
              validator: validateBody,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _publish, child: const Text('Publicera')),
          ],
        ),
      ),
    );
  }
}
```

- `_formKey.currentState!.validate()` kontrollerar alla fält. Är något fel
  visas felmeddelandet och funktionen returnerar `false`. Här är `!` okej,
  eftersom formuläret alltid finns när knappen visas.
- `maxLength: 280` gör att man inte kan skriva mer än 280 tecken. En räknare
  visas under fältet.
- Två controllers betyder två rader i `dispose`.

Testa: klicka **+**, tryck **Publicera** utan att skriva något, och se
felmeddelandena. Skriv sedan ett inlägg och publicera det.

💡 Du kan också skriva adressen själv i Chrome. Lägg till `#/posts/p2` sist i
adressen, till exempel `http://localhost:12345/#/posts/p2`.

## Övningar

**5.1** Lägg till en knapp **Avbryt** (`TextButton`) under **Publicera** i
formuläret. Den ska stänga formuläret utan att skapa något inlägg.

**5.2** Rubriken får vara högst 60 tecken. Lägg till det i `validateTitle` med
felmeddelandet `Högst 60 tecken`.

**5.3** Visa en `SnackBar` med texten `Inlägget är publicerat` i flödet när ett
nytt inlägg har lagts till. Ledtråd:
`ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('...')));`

**5.4** Lägg till adressen `/users/:username` och en
`ProfileScreen(username: ...)`. Den visar `@användarnamn` i `AppBar` och
användarens inlägg som `PostCard`. Testa genom att skriva `#/users/anna` sist i
adressen i Chrome.

**5.5 Utmaning.** Gör så att man kommer till profilen när man trycker på
användarnamnet i `PostCard`. Ledtråd: lägg till en till parameter,
`onAuthorTap`, och en `InkWell` runt raden med avatar och namn.

Lösningar finns i [losningar.md](losningar.md#kapitel-5--navigation-och-formulär).

Nästa kapitel: [Hämta data från PocketBase](06-hamta-data-fran-pocketbase.md)

# 10. Arkitektur för en riktig app

Kapitel 1–9 visade byggstenarna. Det här kapitlet visar hur de passar ihop i en app
av produktionskaraktär: en riktig version av **Kvittra** med inloggning som överlever
omstart, ett oändligt flöde, gillningar som känns omedelbara, kommentarer i realtid,
profiler med följare och **grupper med roller** (`admin`, `moderator`, `member`), en
router med auth-guard och åtgärdsmenyer som bara visar det man får göra.

Förstår du mönstren här kan du bygga nya funktioner (notiser, sparade inlägg,
direktmeddelanden …) på egen hand, och det är precis vad
[övning 3.4](ovningar.md#övning-34--ny-feature-notiser) går ut på.

All Dart-kod i kapitlet är analyserad med `dart analyze` (och `custom_lint`) mot
`flutter_compositions` 0.1.1, `pocketbase` 0.25 och `go_router` 17, och testerna i
slutet av kapitlet går igenom. Serverkoden (JavaScript) är provkörd mot PocketBase.

> 💡 **Tips:** Kapitlet är långt och kodtungt. Läs först texten och tabellerna för att
> förstå *varför*, och fäll sedan ut koden (`▶ Visa koden`) när du bygger själv.

## Översikt

```
/login ──► /  (flödet: Alla / Följer / Mina, oändlig scroll)
            ├── /posts/new              Nytt inlägg (?group=<id> → i en grupp)
            ├── /posts/:id              Inlägg + kommentarer i realtid
            ├── /posts/:id/edit         Redigera (samma sida som "nytt")
            ├── /users/:id              Profil: följare, följ/sluta följa, inlägg
            └── /groups                 Grupper
                  ├── /groups/new       Ny grupp
                  ├── /groups/:id       Gruppens flöde, gå med/lämna
                  ├── /groups/:id/edit  Redigera gruppen (admin)
                  └── /groups/:id/members  Medlemmar och roller
```

Utanför grupper gäller enkla regler: alla inloggade läser och skriver, och man
redigerar och raderar bara sitt eget. **I en grupp** styr rollen i `group_members`:

| Roll i gruppen (`group_members.role`) | Får |
|---------------------------------------|-----|
| `member` | Läsa, skriva inlägg och kommentera i gruppen. Radera sitt eget |
| `moderator` | Som member, plus radera andras inlägg och kommentarer i gruppen |
| `admin` | Som moderator, plus ändra och radera gruppen, ändra roller och ta bort medlemmar |
| *(inte medlem)* | Läsa i publika grupper, gå med. Ser inte privata grupper alls |

### Mappstruktur: feature-first

```
lib/
├── main.dart                          # MyApp: skapar stores, provide, router
├── core/
│   ├── di/injection_keys.dart         # en InjectionKey per store + pocketBaseKey
│   ├── pocketbase/pocketbase_client.dart
│   ├── models/                        # Collections + XxxRecord.fromJson
│   ├── pagination/paginated.dart      # Paginated<T>, PageResult<T>
│   ├── router/router.dart             # createRouter(authStore) med redirect
│   └── utils/{permissions.dart, time_ago.dart}
├── features/
│   ├── auth/{auth_store.dart, pages/login_page.dart}
│   ├── feed/{feed_store.dart, pages/posts_feed_page.dart}
│   ├── posts/{posts_store.dart, pages/…, widgets/post_card.dart,
│   │          composables/use_like_toggle.dart}
│   ├── comments/{comments_store.dart, widgets/…, composables/use_comment_composer.dart}
│   ├── profile/{profile_store.dart, pages/profile_page.dart}
│   └── groups/{groups_store.dart, pages/…}
└── shared/widgets/{paginated_list_view, entity_action_menu, confirm_dialog}.dart
```

Varje **feature** har en *store* och (oftast) en `pages/`-mapp. Inläggen har den
klassiska trion **lista / detalj / skapa-redigera**: `posts_feed_page`,
`post_detail_page` och `create_post_page`. Den sista hanterar **både skapa och
redigera**: får sidan ett id är den i redigeringsläge. Grupperna har samma trio
(`groups_list_page`, `group_detail_page`, `create_group_page`) plus en medlemssida.

### De fem mönstren

| Mönster | Vad | Kapitel i modulen |
|---------|-----|-------------------|
| **Store per feature** | Vanlig Dart-klass med privata `ref`s, publika `ReadonlyRef`-getters, `computed` och async-metoder som returnerar `Future<bool>` | 2, 6 |
| **Provide i roten** | `MyApp.setup()` skapar alla stores en gång och `provide`:ar dem. Sidor gör `inject` | 6 |
| **`Paginated<T>` + `PaginatedListView`** | Sidindelade listor med oändlig scroll och pull-to-refresh | 5, 7 |
| **`EntityActionMenu`** | Redigera/radera via en `more_vert`-meny med bekräftelse, i stället för lösa knappar | – |
| **Auth-guard + rollkontroll** | `redirect` i go_router och `hasPermission(grupp, åtgärd)` i UI:t, som speglar API-regler och hooks på servern | 6 |

---

## Backend i korthet

Vi utgår från din egen PocketBase med Kvittras collections från
[modul 01](../01-databaser-och-pocketbase/README.md): `users`, `posts`, `comments`, `likes` och
`follows`. Grupperna (`groups` och `group_members`) är nya och läggs till här.

💡 **Migrationer och hooks.** Backend-koden i det här kapitlet är JavaScript-filer som
du lägger i två mappar bredvid `pocketbase.exe`:

| Mapp | Innehåll | När körs den? |
|------|----------|---------------|
| `pb_migrations/` | Filer som skapar eller ändrar collections och regler (`migrate(...)`) | När PocketBase startar. Varje fil körs en gång |
| `pb_hooks/` | Filer som slutar på `.pb.js` och kör kod när något händer, t.ex. när en post skapas | Hela tiden. PocketBase laddar om dem när du sparar |

Skapa mapparna om de inte finns och starta om PocketBase när du har lagt in en ny
migration. Det du gör i en migration kan du också göra för hand i Dashboard.

| Collection | Fält som appen använder |
|------------|-------------------------|
| `users` (auth) | `username`, `name`, `email`, `bio`, `website` |
| `posts` | `author` → users, `title`, `body`, `group` → groups (valfri), `created` |
| `comments` | `post` → posts (cascade delete), `author` → users, `body`, `created` |
| `likes` | `post` → posts, `user` → users, unikt index på `(post, user)` |
| `follows` | `follower` → users, `following` → users, unikt index på `(follower, following)` |
| `groups` | `name`, `description`, `owner` → users, `visibility` (`public`/`private`) |
| `group_members` | `group` → groups, `user` → users, `role` (`admin`/`moderator`/`member`), unikt index på `(group, user)` |

<details>
<summary>▶ Visa migrationen <code>pb_migrations/1700000100_groups.js</code></summary>

```js
/// <reference path="../pb_data/types.d.ts" />

// Grupper med roller.
migrate((app) => {
  const users = app.findCollectionByNameOrId("users")

  // 1. groups
  const groups = new Collection({
    type: "base",
    name: "groups",
    fields: [
      { name: "name", type: "text", required: true, max: 80 },
      { name: "description", type: "text", max: 500 },
      { name: "owner", type: "relation", collectionId: users.id, maxSelect: 1, required: true },
      { name: "visibility", type: "select", values: ["public", "private"], maxSelect: 1, required: true },
      { name: "created", type: "autodate", onCreate: true },
    ],
  })
  app.save(groups)

  // 2. group_members: vem är med i vilken grupp, och med vilken roll
  const members = new Collection({
    type: "base",
    name: "group_members",
    fields: [
      { name: "group", type: "relation", collectionId: groups.id, maxSelect: 1, required: true, cascadeDelete: true },
      { name: "user", type: "relation", collectionId: users.id, maxSelect: 1, required: true, cascadeDelete: true },
      { name: "role", type: "select", values: ["admin", "moderator", "member"], maxSelect: 1, required: true },
      { name: "created", type: "autodate", onCreate: true },
    ],
    // Samma användare kan bara vara med en gång per grupp.
    indexes: ["CREATE UNIQUE INDEX idx_group_members_pair ON group_members (`group`, user)"],
  })
  app.save(members)

  // 3. Ett inlägg kan (valfritt) höra till en grupp.
  const posts = app.findCollectionByNameOrId("posts")
  posts.fields.add(new RelationField({
    name: "group",
    collectionId: groups.id,
    maxSelect: 1,
    cascadeDelete: true,
  }))
  app.save(posts)
}, (app) => {
  const posts = app.findCollectionByNameOrId("posts")
  posts.fields.removeByName("group")
  app.save(posts)
  app.delete(app.findCollectionByNameOrId("group_members"))
  app.delete(app.findCollectionByNameOrId("groups"))
})
```

</details>

Säkerheten ligger på servern. Appen *speglar* reglerna för en bra upplevelse, men det
är reglerna och hookarna som bestämmer:

| Vad | Var |
|-----|-----|
| Inlägg i privata grupper syns bara för medlemmar | API-regel (List/View på `posts`, `comments`, `groups`) |
| Skriva i en grupp kräver medlemskap | API-regel (Create på `posts`, `comments`) |
| Radera andras inlägg i en grupp kräver `moderator`/`admin` | API-regel (Delete på `posts`, `comments`) |
| Ändra roller, ta bort medlemmar, ändra gruppen kräver `admin` | API-regel (`group_members`, `groups`) |
| `author` och `owner` sätts av servern, aldrig av klienten | Hook `onRecordCreateRequest` |
| Den som skapar en grupp blir dess `admin` | Hook `onRecordAfterCreateSuccess` |

Reglerna använder `@collection.group_members` för att slå upp **min** rad i gruppen.
Villkoren på samma `@collection`-koppling gäller samma rad, så
`group ?= X && user ?= mig && role ?= "admin"` betyder "jag är admin i X".

<details>
<summary>▶ Visa API-reglerna <code>pb_migrations/1700000200_rules.js</code></summary>

```js
/// <reference path="../pb_data/types.d.ts" />

// API-regler för Kvittra med grupper.
migrate((app) => {
  const loggedIn = '@request.auth.id != ""'

  // "Jag är medlem i gruppen X" (X är ett uttryck, t.ex. group eller id)
  const memberOf = (x) =>
    `(@collection.group_members.group ?= ${x} && @collection.group_members.user ?= @request.auth.id)`
  // "Jag har någon av rollerna i gruppen X"
  const hasRole = (x, roles) =>
    `(@collection.group_members.group ?= ${x} && @collection.group_members.user ?= @request.auth.id && (` +
    roles.map((r) => `@collection.group_members.role ?= "${r}"`).join(" || ") + "))"

  // Ett inlägg syns om det inte hör till någon grupp, om gruppen är
  // publik eller om jag är medlem i gruppen.
  const canSeePost = (p) =>
    `(${p}group = "" || ${p}group.visibility = "public" || ${memberOf(p + "group")})`

  const rules = {
    posts: {
      listRule: `${loggedIn} && ${canSeePost("")}`,
      viewRule: `${loggedIn} && ${canSeePost("")}`,
      // author stämplas av en hook. I en grupp måste man vara medlem.
      createRule: `${loggedIn} && (@request.body.group = "" || ${memberOf("@request.body.group")})`,
      updateRule: 'author = @request.auth.id && @request.body.group:changed = false',
      deleteRule: `author = @request.auth.id || (group != "" && ${hasRole("group", ["admin", "moderator"])})`,
    },
    comments: {
      listRule: `${loggedIn} && ${canSeePost("post.")}`,
      viewRule: `${loggedIn} && ${canSeePost("post.")}`,
      createRule: `${loggedIn} && (@request.body.post.group = "" || ${memberOf("@request.body.post.group")})`,
      updateRule: 'author = @request.auth.id && @request.body.post:changed = false',
      deleteRule: `author = @request.auth.id || post.author = @request.auth.id || ` +
        `(post.group != "" && ${hasRole("post.group", ["admin", "moderator"])})`,
    },
    likes: {
      listRule: loggedIn,
      viewRule: loggedIn,
      createRule: `${loggedIn} && @request.body.user = @request.auth.id`,
      updateRule: null, // en gillning ändras aldrig, den skapas eller raderas
      deleteRule: 'user = @request.auth.id',
    },
    follows: {
      listRule: loggedIn,
      viewRule: loggedIn,
      createRule: `${loggedIn} && @request.body.follower = @request.auth.id && @request.body.following != @request.auth.id`,
      updateRule: null,
      deleteRule: 'follower = @request.auth.id',
    },
    groups: {
      listRule: `${loggedIn} && (visibility = "public" || ${memberOf("id")})`,
      viewRule: `${loggedIn} && (visibility = "public" || ${memberOf("id")})`,
      createRule: loggedIn, // owner stämplas av en hook
      updateRule: `${hasRole("id", ["admin"])} && @request.body.owner:changed = false`,
      deleteRule: hasRole("id", ["admin"]),
    },
    group_members: {
      listRule: `${loggedIn} && (group.visibility = "public" || ${memberOf("group")})`,
      viewRule: `${loggedIn} && (group.visibility = "public" || ${memberOf("group")})`,
      // Gå med själv i en publik grupp som member, ELLER bli tillagd av en admin.
      createRule:
        `(${loggedIn} && @request.body.user = @request.auth.id && @request.body.role = "member" && @request.body.group.visibility = "public") || ` +
        hasRole("@request.body.group", ["admin"]),
      // Bara admin får byta roll, och bara rollen.
      updateRule: `${hasRole("group", ["admin"])} && @request.body.group:changed = false && @request.body.user:changed = false`,
      // Lämna själv, eller bli borttagen av en admin.
      deleteRule: `user = @request.auth.id || ${hasRole("group", ["admin"])}`,
    },
  }

  for (const [name, r] of Object.entries(rules)) {
    const c = app.findCollectionByNameOrId(name)
    Object.assign(c, r)
    app.save(c)
  }
}, (app) => {})
```

</details>

Fält som klienten **inte** får välja stämplas av servern. `pb_hooks/author.pb.js`:

```js
/// <reference path="../pb_data/types.d.ts" />

// Fält som klienten INTE får välja stämplas av servern.
onRecordCreateRequest((e) => {
  if (!e.hasSuperuserAuth()) {
    if (!e.auth) throw new UnauthorizedError("Logga in först.")
    const field = e.collection.name === "groups" ? "owner" : "author"
    e.record.set(field, e.auth.id)
  }
  e.next()
}, "posts", "comments", "groups")

// Författare och ägare kan aldrig bytas i efterhand.
onRecordUpdateRequest((e) => {
  if (!e.hasSuperuserAuth()) {
    const field = e.collection.name === "groups" ? "owner" : "author"
    e.record.set(field, e.record.original().getString(field))
  }
  e.next()
}, "posts", "comments", "groups")

// Den som skapar en grupp blir automatiskt dess admin.
onRecordAfterCreateSuccess((e) => {
  const members = e.app.findCollectionByNameOrId("group_members")
  const m = new Record(members)
  m.set("group", e.record.id)
  m.set("user", e.record.getString("owner"))
  m.set("role", "admin")
  e.app.save(m)
  e.next()
}, "groups")
```

Provkört med `curl` (Anna, Bo och Cecilia; Anna har skapat en publik och en privat
grupp):

| Försök | Resultat |
|--------|----------|
| Anna skapar ett inlägg och skickar Bos id som `author` | Sparas med Anna som författare (hooken) |
| Anna skapar en grupp | Hon blir automatiskt `admin` i den (hooken) |
| Bo listar grupper | Ser bara den publika |
| Bo listar inlägg | Ser inte inlägg i den privata gruppen |
| Bo skriver i eller kommenterar i den privata gruppen | `400` |
| Bo går med i den publika gruppen som `member` | OK |
| Bo går med i den privata gruppen, eller Cecilia som `admin` i den publika | `400` |
| Bo gör sig själv till `moderator` | `404` (update-regeln) |
| Cecilia (`member`) raderar Bos gruppinlägg | `404` |
| Anna (`admin`) gör Cecilia till `moderator`, och Cecilia raderar inlägget | OK, `204` |
| Bo redigerar Annas inlägg | `404` |
| Anna flyttar sitt inlägg till en grupp i efterhand | `404` (`@request.body.group:changed = false`) |
| Bo gillar samma inlägg två gånger | `400` (unikt index) |
| Bo följer sig själv | `400` |

> 💡 **Tips:** `404` i stället för `403` är medvetet. PocketBase avslöjar inte om en post
> finns när reglerna säger nej.

---

## PocketBase-klient, DI och appens rot

Projektet skapas med `flutter create kvittra` (därav `package:kvittra/…` i testerna)
och behöver paketen `flutter_compositions`, `pocketbase`, `go_router` och
`shared_preferences`.

### En klient som minns inloggningen

```dart
import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Skapar EN PocketBase-klient för hela appen.
///
/// Inloggningen sparas i SharedPreferences via AsyncAuthStore, så att
/// användaren förblir inloggad efter omstart.
class PocketBaseClient {
  PocketBaseClient._();

  static PocketBase? _instance;

  /// Android-emulatorn når datorns localhost via 10.0.2.2.
  /// Kör t.ex. `flutter run --dart-define=PB_URL=http://10.0.2.2:8090`.
  static const _url = String.fromEnvironment(
    'PB_URL',
    defaultValue: 'http://127.0.0.1:8090',
  );

  static Future<void> initialize() async {
    if (_instance != null) return;
    final prefs = await SharedPreferences.getInstance();

    final authStore = AsyncAuthStore(
      save: (data) => prefs.setString('pb_auth', data),
      initial: prefs.getString('pb_auth'),
      clear: () => prefs.remove('pb_auth'),
    );

    debugPrint('PocketBase: $_url');
    _instance = PocketBase(_url, authStore: authStore);
  }

  static PocketBase get instance {
    final pb = _instance;
    if (pb == null) {
      throw StateError('Anropa PocketBaseClient.initialize() i main() först.');
    }
    return pb;
  }
}
```

`AsyncAuthStore` sparar token och användarpost i `shared_preferences`
(`flutter pub add shared_preferences`) och läser tillbaka dem vid start.
`String.fromEnvironment('PB_URL')` sätts vid körning:
`flutter run --dart-define=PB_URL=http://10.0.2.2:8090` (Android-emulatorn når datorns
localhost via `10.0.2.2`).

### Nycklar

```dart
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart' show PocketBase;

import '../../features/auth/auth_store.dart';
import '../../features/comments/comments_store.dart';
import '../../features/feed/feed_store.dart';
import '../../features/groups/groups_store.dart';
import '../../features/posts/posts_store.dart';
import '../../features/profile/profile_store.dart';

const pocketBaseKey = InjectionKey<PocketBase>('pocketBase');
const authStoreKey = InjectionKey<AuthStore>('authStore');
const feedStoreKey = InjectionKey<FeedStore>('feedStore');
const postsStoreKey = InjectionKey<PostsStore>('postsStore');
const commentsStoreKey = InjectionKey<CommentsStore>('commentsStore');
const profileStoreKey = InjectionKey<ProfileStore>('profileStore');
const groupsStoreKey = InjectionKey<GroupsStore>('groupsStore');
```

> ⚠️ **Varning:** Paketet `pocketbase` har redan en klass `AuthStore`
> (`pb.authStore`). Importera därför med `show PocketBase` eller `hide AuthStore` där
> båda behövs.

### `main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

import 'core/di/injection_keys.dart';
import 'core/pocketbase/pocketbase_client.dart';
import 'core/router/router.dart';
import 'features/auth/auth_store.dart';
import 'features/comments/comments_store.dart';
import 'features/feed/feed_store.dart';
import 'features/groups/groups_store.dart';
import 'features/posts/posts_store.dart';
import 'features/profile/profile_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PocketBaseClient.initialize();
  runApp(const MyApp());
}

class MyApp extends CompositionWidget {
  const MyApp({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final pb = PocketBaseClient.instance;

    // Skapa alla stores EN gång.
    final authStore = AuthStore(pb);
    final feedStore = FeedStore(pb, authStore);
    final postsStore = PostsStore(pb, authStore, feedStore);
    final commentsStore = CommentsStore(pb);
    final profileStore = ProfileStore(pb, authStore);
    final groupsStore = GroupsStore(pb, authStore);

    provide(pocketBaseKey, pb);
    provide(authStoreKey, authStore);
    provide(feedStoreKey, feedStore);
    provide(postsStoreKey, postsStore);
    provide(commentsStoreKey, commentsStore);
    provide(profileStoreKey, profileStore);
    provide(groupsStoreKey, groupsStore);

    final router = createRouter(authStore);
    onUnmounted(router.dispose);

    // Vid in-/utloggning: kör om routerns redirect.
    watch(() => authStore.isAuthenticated.value, (_, _) => router.refresh());

    // Ny användare: ladda mina grupproller. Utloggad: glöm dem.
    watch(() => authStore.user.value?.id, (userId, _) {
      if (userId == null) {
        groupsStore.clear();
      } else {
        groupsStore.loadMyRoles();
      }
    }, immediate: true);

    return (context) => MaterialApp.router(
          title: 'Kvittra',
          theme: ThemeData(colorSchemeSeed: Colors.indigo),
          darkTheme: ThemeData(
            colorSchemeSeed: Colors.indigo,
            brightness: Brightness.dark,
          ),
          routerConfig: router,
        );
  }
}
```

- Alla stores skapas **en gång** och delas med `provide`. Beroenden mellan stores
  skickas i konstruktorn (`PostsStore` behöver `FeedStore` för att hämta om flödet).
- Routern skapas i `setup()` med `createRouter(authStore)` (se nedan) och disposas i
  `onUnmounted`, som är registrerat direkt i `setup()`.
- `watch` på `isAuthenticated` anropar `router.refresh()`, så att guarden körs direkt
  vid in- och utloggning.
- `watch` på användarens id med `immediate: true` laddar mina grupproller vid start och
  vid varje inloggning, och glömmer dem vid utloggning. Med `watchEffect` hade
  `loadMyRoles` riskerat att spåra refs som den själv skriver till. Med `watch` är
  beroendet explicit.

---

## Modeller

```dart
/// Collection-namn samlade på ett ställe, så att stavfel blir kompileringsfel.
abstract final class Collections {
  static const users = 'users';
  static const posts = 'posts';
  static const comments = 'comments';
  static const likes = 'likes';
  static const follows = 'follows';
  static const groups = 'groups';
  static const groupMembers = 'group_members';
}
```

```dart
class UserRecord {
  const UserRecord({
    required this.id,
    required this.username,
    required this.name,
    required this.email,
    this.bio = '',
    this.website = '',
  });

  final String id;
  final String username;
  final String name;
  final String email;
  final String bio;
  final String website;

  /// Namnet om det finns, annars @användarnamn.
  String get displayName => name.isEmpty ? '@$username' : name;

  factory UserRecord.fromJson(Map<String, dynamic> json) => UserRecord(
        id: json['id'] as String,
        username: json['username'] as String? ?? '',
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        bio: json['bio'] as String? ?? '',
        website: json['website'] as String? ?? '',
      );
}
```

```dart
class PostRecord {
  const PostRecord({
    required this.id,
    required this.title,
    required this.body,
    required this.author,
    required this.authorName,
    required this.group,
    required this.groupName,
    required this.likeCount,
    required this.likedByMe,
    required this.created,
  });

  final String id;
  final String title;
  final String body;
  final String author; // relation-id → users
  final String authorName; // från expand.author
  final String group; // relation-id → groups, '' om inget
  final String groupName; // från expand.group
  final int likeCount; // antal i expand.likes_via_post
  final bool likedByMe; // finns min gillning bland dem?
  final DateTime? created;

  bool get inGroup => group.isNotEmpty;

  factory PostRecord.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final expand = json['expand'] as Map<String, dynamic>? ?? const {};
    final author = expand['author'] as Map<String, dynamic>?;
    final group = expand['group'] as Map<String, dynamic>?;
    // Bakåtrelation: alla likes vars `post` pekar på det här inlägget.
    final likes = (expand['likes_via_post'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    return PostRecord(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      author: json['author'] as String? ?? '',
      authorName: author?['name'] as String? ?? 'Okänd',
      group: json['group'] as String? ?? '',
      groupName: group?['name'] as String? ?? '',
      likeCount: likes.length,
      likedByMe:
          currentUserId != null && likes.any((l) => l['user'] == currentUserId),
      created: DateTime.tryParse(json['created'] as String? ?? '')?.toLocal(),
    );
  }
}
```

<details>
<summary>▶ Visa <code>comment_record.dart</code> och <code>group_record.dart</code></summary>

```dart
class CommentRecord {
  const CommentRecord({
    required this.id,
    required this.post,
    required this.author,
    required this.authorName,
    required this.body,
    required this.created,
  });

  final String id;
  final String post;
  final String author;
  final String authorName;
  final String body;
  final DateTime? created;

  factory CommentRecord.fromJson(Map<String, dynamic> json) {
    final expand = json['expand'] as Map<String, dynamic>? ?? const {};
    final author = expand['author'] as Map<String, dynamic>?;
    return CommentRecord(
      id: json['id'] as String,
      post: json['post'] as String? ?? '',
      author: json['author'] as String? ?? '',
      authorName: author?['name'] as String? ?? 'Okänd',
      body: json['body'] as String? ?? '',
      created: DateTime.tryParse(json['created'] as String? ?? '')?.toLocal(),
    );
  }
}
```

```dart
import '../utils/permissions.dart';

enum GroupVisibility { public, private }

class GroupRecord {
  const GroupRecord({
    required this.id,
    required this.name,
    required this.description,
    required this.owner,
    required this.visibility,
  });

  final String id;
  final String name;
  final String description;
  final String owner;
  final GroupVisibility visibility;

  bool get isPrivate => visibility == GroupVisibility.private;

  factory GroupRecord.fromJson(Map<String, dynamic> json) => GroupRecord(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        owner: json['owner'] as String? ?? '',
        visibility: GroupVisibility.values.asNameMap()[json['visibility']] ??
            GroupVisibility.public,
      );
}

class GroupMemberRecord {
  const GroupMemberRecord({
    required this.id,
    required this.group,
    required this.user,
    required this.userName,
    required this.role,
  });

  final String id;
  final String group;
  final String user;
  final String userName; // från expand.user
  final GroupRole role;

  factory GroupMemberRecord.fromJson(Map<String, dynamic> json) {
    final expand = json['expand'] as Map<String, dynamic>? ?? const {};
    final user = expand['user'] as Map<String, dynamic>?;
    return GroupMemberRecord(
      id: json['id'] as String,
      group: json['group'] as String? ?? '',
      user: json['user'] as String? ?? '',
      userName: user?['name'] as String? ?? 'Okänd',
      role: GroupRole.values.asNameMap()[json['role']] ?? GroupRole.member,
    );
  }
}
```

</details>

**Mönstret:**

- `XxxRecord.fromJson(record.toJson())`, så att UI:t aldrig behöver se `RecordModel`.
- **Relationer** är id-strängar. **Expanderad data** (`expand: 'author'`) läses ur
  `json['expand']` till extra fält som `authorName`.
- **Bakåtrelationer**: `expand: 'likes_via_post'` ger alla `likes` vars `post` pekar på
  inlägget. Antalet blir `likeCount`, och om min gillning finns bland dem blir
  `likedByMe` sant. Därför tar `PostRecord.fromJson` emot `currentUserId`.
- **Enums** läses med `values.asNameMap()[…] ?? standardvärde`.
- **Datum** görs om med `.toLocal()` vid inläsning.
- Collection-namnen ligger i `Collections`, så att ett stavfel blir ett kompileringsfel.

---

## Store-mönstret: `AuthStore`

```dart
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart' hide AuthStore;

import '../../core/models/collections.dart';
import '../../core/models/user_record.dart';

class AuthStore {
  AuthStore(this._pb) {
    _syncFromPocketBase();
    // authStore.onChange triggas vid inloggning, token-förnyelse och utloggning.
    _pb.authStore.onChange.listen((_) => _syncFromPocketBase());
  }

  final PocketBase _pb;

  final _user = ref<UserRecord?>(null);
  final _loading = ref(false);

  ReadonlyRef<UserRecord?> get user => _user;
  ReadonlyRef<bool> get loading => _loading;

  late final ReadonlyRef<bool> isAuthenticated =
      computed(() => _user.value != null);

  void _syncFromPocketBase() {
    final record = _pb.authStore.record;
    _user.value = _pb.authStore.isValid && record != null
        ? UserRecord.fromJson(record.toJson())
        : null;
  }

  /// Kastar vidare ett begripligt felmeddelande till UI:t.
  Future<void> signIn(String email, String password) async {
    _loading.value = true;
    try {
      await _pb.collection(Collections.users).authWithPassword(email, password);
    } on ClientException catch (e) {
      throw e.response['message']?.toString() ?? 'Inloggningen misslyckades';
    } finally {
      _loading.value = false;
    }
  }

  void signOut() => _pb.authStore.clear();
}
```

| Del | Exempel | Varför |
|-----|---------|--------|
| Privata refs | `final _user = ref<UserRecord?>(null);` | Bara store:n skriver |
| Publika `ReadonlyRef` | `ReadonlyRef<UserRecord?> get user => _user;` | Sidor läser och reagerar |
| `computed` | `isAuthenticated` | Härledd, cachad data |
| Async-metoder | `signIn` | All PocketBase-kod samlad |
| Felmeddelanden | `throw e.response['message']` | UI:t visar serverns text |

Andra stores följer samma mönster. Deras mutationsmetoder returnerar `Future<bool>`
(fångar `ClientException` och loggar), och sidan visar en SnackBar vid `false`.

### `FeedStore`: flödet och gillningar

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart' hide AuthStore;

import '../../core/models/collections.dart';
import '../../core/models/post_record.dart';
import '../../core/pagination/paginated.dart';
import '../auth/auth_store.dart';

enum FeedFilter { all, following, mine }

class FeedStore {
  FeedStore(this._pb, this._auth);

  final PocketBase _pb;
  final AuthStore _auth;

  final _filter = ref(FeedFilter.all);
  ReadonlyRef<FeedFilter> get filter => _filter;

  /// Huvudflödet. API-reglerna ser till att man bara får inlägg man får se
  /// (inga inlägg från privata grupper man inte är med i).
  late final posts = Paginated<PostRecord>(
    (page, perPage) =>
        fetchPosts(page: page, perPage: perPage, filter: _filter.value),
  );

  void setFilter(FeedFilter value) {
    if (_filter.value == value) return;
    _filter.value = value;
    posts.refresh();
  }

  /// Används av flödet, profilsidan och gruppsidan.
  Future<PageResult<PostRecord>> fetchPosts({
    required int page,
    required int perPage,
    FeedFilter filter = FeedFilter.all,
    String? authorId,
    String? groupId,
  }) async {
    final me = _auth.user.value?.id ?? '';
    final parts = [
      if (filter == FeedFilter.mine) _pb.filter('author = {:me}', {'me': me}),
      // Bakåtrelation: författare som har en follows-post där jag är follower.
      if (filter == FeedFilter.following)
        _pb.filter(
            'author.follows_via_following.follower ?= {:me}', {'me': me}),
      if (authorId != null) _pb.filter('author = {:a}', {'a': authorId}),
      if (groupId != null) _pb.filter('group = {:g}', {'g': groupId}),
    ];
    final res = await _pb.collection(Collections.posts).getList(
          page: page,
          perPage: perPage,
          filter: parts.join(' && '),
          sort: '-created',
          expand: 'author,group,likes_via_post',
        );
    return PageResult(
      res.items
          .map((r) => PostRecord.fromJson(r.toJson(), currentUserId: me))
          .toList(),
      res.totalPages,
    );
  }

  /// Gilla eller sluta gilla. Returnerar false om servern sa nej, så att
  /// anroparen kan ångra sin optimistiska uppdatering.
  Future<bool> setLiked(String postId, bool liked) async {
    final me = _auth.user.value?.id;
    if (me == null) return false;
    final likes = _pb.collection(Collections.likes);
    try {
      if (liked) {
        await likes.create(body: {'post': postId, 'user': me});
      } else {
        final like = await likes.getFirstListItem(
          _pb.filter('post = {:p} && user = {:u}', {'p': postId, 'u': me}),
        );
        await likes.delete(like.id);
      }
      return true;
    } on ClientException catch (e) {
      debugPrint(
          'FeedStore.setLiked: ${e.statusCode} ${e.response['message']}');
      return false;
    }
  }
}
```

- `posts` är en `Paginated<PostRecord>` (se nedan) som **lever i store:n**. Går man in
  på ett inlägg och tillbaka finns flödet kvar.
- Filtret **Följer** använder en bakåtrelation i filtret:
  `author.follows_via_following.follower ?= {:me}` betyder "författaren har en
  `follows`-rad där `following` är författaren och `follower` är jag".
- `fetchPosts` återanvänds av profilsidan (`authorId`) och gruppsidan (`groupId`).
- `setLiked` returnerar `false` vid `ClientException`, så att den som anropade kan
  rulla tillbaka en optimistisk uppdatering.

---

## Router och auth-guard

```dart
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_store.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/feed/pages/posts_feed_page.dart';
import '../../features/groups/pages/create_group_page.dart';
import '../../features/groups/pages/group_detail_page.dart';
import '../../features/groups/pages/group_members_page.dart';
import '../../features/groups/pages/groups_list_page.dart';
import '../../features/posts/pages/create_post_page.dart';
import '../../features/posts/pages/post_detail_page.dart';
import '../../features/profile/pages/profile_page.dart';

/// Routern skapas i MyApp.setup() och får AuthStore som argument.
/// redirect körs UTANFÖR alla setup() (av go_router), så där går det inte
/// att använda inject(). Därför skickar vi in store:n här i stället.
GoRouter createRouter(AuthStore auth) {
  return GoRouter(
    initialLocation: PostsFeedPage.path,
    redirect: (context, state) {
      final loggedIn = auth.isAuthenticated.raw; // .raw: ingen reaktiv kontext
      final onLogin = state.matchedLocation == LoginPage.path;
      if (!loggedIn && !onLogin) return LoginPage.path;
      if (loggedIn && onLogin) return PostsFeedPage.path;
      return null; // släpp igenom
    },
    routes: [
      GoRoute(path: LoginPage.path, builder: (_, _) => const LoginPage()),
      GoRoute(
          path: PostsFeedPage.path, builder: (_, _) => const PostsFeedPage()),
      // OBS: '/posts/new' måste stå före '/posts/:id', annars tolkas "new" som ett id.
      GoRoute(
        path: CreatePostPage.path,
        builder: (_, state) =>
            CreatePostPage(groupId: state.uri.queryParameters['group']),
      ),
      GoRoute(
        path: CreatePostPage.editPath,
        builder: (_, state) =>
            CreatePostPage(postId: state.pathParameters['id']),
      ),
      GoRoute(
        path: PostDetailPage.path,
        builder: (_, state) =>
            PostDetailPage(postId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: ProfilePage.path,
        builder: (_, state) => ProfilePage(userId: state.pathParameters['id']!),
      ),
      GoRoute(
          path: GroupsListPage.path, builder: (_, _) => const GroupsListPage()),
      GoRoute(
          path: CreateGroupPage.path,
          builder: (_, _) => const CreateGroupPage()),
      GoRoute(
        path: CreateGroupPage.editPath,
        builder: (_, state) =>
            CreateGroupPage(groupId: state.pathParameters['id']),
      ),
      GoRoute(
        path: GroupMembersPage.path,
        builder: (_, state) =>
            GroupMembersPage(groupId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: GroupDetailPage.path,
        builder: (_, state) =>
            GroupDetailPage(groupId: state.pathParameters['id']!),
      ),
    ],
  );
}
```

- Varje sida har `static const path`, och detaljsidor har `pathFor(id)`.
- `/posts/new` står före `/posts/:id` och `/groups/new` före `/groups/:id`, annars
  tolkas `new` som ett id.
- Navigering sker med `context.push(...)`. Efter sparning går man tillbaka med
  `context.pop(true)`, så att föregående sida vet att något ändrats.

**Varför skickas `AuthStore` in i `createRouter`?** `inject` fungerar bara i `setup()`.
go_router:s `redirect` körs av routern vid varje navigering, utanför alla `setup()`.
Därför får routern store:n som argument när den skapas i `MyApp.setup()`. Ett
alternativ som du kan se i andra projekt är en **global accessor**
(`setGlobalAuthStore(store)` i `MyApp` och `getGlobalAuthStore()` i guarden). Det
viktiga är att **sidorna** fortfarande använder `inject`. Routern är undantaget.

### Inloggningssidan navigerar inte själv

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

import '../../../core/di/injection_keys.dart';

class LoginPage extends CompositionWidget {
  const LoginPage({super.key});

  static const path = '/login';

  @override
  Widget Function(BuildContext) setup() {
    final auth = inject(authStoreKey);
    final (emailController, email, _) = useTextEditingController();
    final (passwordController, password, _) = useTextEditingController();
    final error = ref<String?>(null);

    final canSubmit = computed(
      () =>
          email.value.contains('@') &&
          password.value.length >= 8 &&
          !auth.loading.value,
    );
    final buttonLabel = computed(
      () => auth.loading.value ? 'Loggar in…' : 'Logga in',
    );

    // Rensa felet när användaren ändrar något.
    watch(() => (email.value, password.value), (_, _) => error.value = null);

    Future<void> submit() async {
      try {
        await auth.signIn(email.value.trim(), password.value);
        // Ingen navigering här: routerns redirect skickar oss till flödet.
      } catch (e) {
        error.value = '$e';
      }
    }

    return (context) => Scaffold(
          appBar: AppBar(title: const Text('Kvittra')),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'E-post'),
              ),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Lösenord',
                  errorText: error.value,
                ),
                onSubmitted: (_) => canSubmit.value ? submit() : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: canSubmit.value ? submit : null,
                child: Text(buttonLabel.value),
              ),
            ],
          ),
        );
  }
}
```

När inloggningen lyckas ändras `pb.authStore`, `AuthStore._user` uppdateras, `watch` i
`MyApp` anropar `router.refresh()`, och guarden skickar användaren till flödet.
Utloggning fungerar likadant åt andra hållet, och ingen sida behöver känna till det.

---

## Sidindelade listor

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

/// En sida med resultat + totalt antal sidor (från PocketBase ResultList).
class PageResult<T> {
  const PageResult(this.items, this.totalPages);
  final List<T> items;
  final int totalPages;
}

typedef PageFetcher<T> = Future<PageResult<T>> Function(int page, int perPage);

/// Återanvändbar "markör" för sidindelade PocketBase-listor.
class Paginated<T> {
  Paginated(this._fetch, {this.pageSize = 20});

  final PageFetcher<T> _fetch;
  final int pageSize;

  final _items = ref<List<T>>([]);
  final _loading = ref(false);
  final _loadingMore = ref(false);
  final _hasMore = ref(false);
  final _error = ref<Object?>(null);
  int _page = 1;

  ReadonlyRef<List<T>> get items => _items;
  ReadonlyRef<bool> get loading => _loading;
  ReadonlyRef<bool> get loadingMore => _loadingMore;
  ReadonlyRef<bool> get hasMore => _hasMore;
  ReadonlyRef<Object?> get error => _error;

  /// Ladda (om) första sidan.
  Future<void> refresh() async {
    _loading.value = true;
    _error.value = null;
    _page = 1;
    try {
      final result = await _fetch(_page, pageSize);
      _items.value = result.items;
      _hasMore.value = _page < result.totalPages;
    } catch (e) {
      debugPrint('Paginated<$T>.refresh: $e');
      _error.value = e;
      _items.value = [];
      _hasMore.value = false;
    } finally {
      _loading.value = false;
    }
  }

  /// Lägg till nästa sida.
  Future<void> loadMore() async {
    if (!_hasMore.value || _loadingMore.value || _loading.value) return;
    _loadingMore.value = true;
    _page++;
    try {
      final result = await _fetch(_page, pageSize);
      _items.value = [..._items.value, ...result.items];
      _hasMore.value = _page < result.totalPages;
    } catch (e) {
      debugPrint('Paginated<$T>.loadMore: $e');
      _page--; // försök samma sida nästa gång
    } finally {
      _loadingMore.value = false;
    }
  }

  /// Ta bort ett element lokalt (t.ex. efter radering) utan att hämta om.
  void removeWhere(bool Function(T item) test) {
    _items.value = _items.value.where((i) => !test(i)).toList();
  }

  /// Byt ut element lokalt (t.ex. efter en uppdatering) utan att hämta om.
  void updateWhere(bool Function(T item) test, T Function(T item) update) {
    _items.value = [for (final i in _items.value) test(i) ? update(i) : i];
  }
}
```

`Paginated<T>` är en vanlig klass, inte en composable. Den kan därför leva i en store
(flödet, grupplistan) **eller** skapas i en sidas `setup()` (profilens och gruppens
inlägg) och då leva lika länge som sidan.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

/// Lista med "oändlig scroll" och pull-to-refresh. Kopplas till en `Paginated<T>`.
class PaginatedListView extends CompositionWidget {
  const PaginatedListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.hasMore,
    required this.loadingMore,
    required this.onLoadMore,
    required this.onRefresh,
    this.emptyText = 'Inget att visa',
    this.scrollThreshold = 200,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final bool hasMore;
  final bool loadingMore;
  final Future<void> Function() onLoadMore;
  final Future<void> Function() onRefresh;
  final String emptyText;
  final double scrollThreshold;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final scroll = useScrollController();

    void onScroll() {
      final c = scroll.raw;
      final p = props.raw; // läs utan att skapa beroende
      if (!c.hasClients) return;
      final nearBottom =
          c.position.pixels >= c.position.maxScrollExtent - p.scrollThreshold;
      if (nearBottom && p.hasMore && !p.loadingMore) p.onLoadMore();
    }

    // Controllern skapas synkront av useScrollController och disposas
    // automatiskt, vilket också tar bort lyssnaren.
    scroll.raw.addListener(onScroll);

    final showSpinner = computed(
      () => props.value.hasMore || props.value.loadingMore,
    );
    final count = computed(
      () => props.value.itemCount + (showSpinner.value ? 1 : 0),
    );
    final isEmpty = computed(
      () => props.value.itemCount == 0 && !showSpinner.value,
    );

    return (context) {
      final PaginatedListView(
        :itemBuilder,
        :itemCount,
        :onRefresh,
        :emptyText
      ) = props.value;
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: isEmpty.value
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [ListTile(title: Text(emptyText))],
              )
            : ListView.builder(
                controller: scroll.raw,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: count.value,
                itemBuilder: (context, i) => i >= itemCount
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : itemBuilder(context, i),
              ),
      );
    };
  }
}
```

- `useScrollController()` skapar och disposar controllern, och lyssnaren försvinner med
  den.
- `onScroll` läser `props.raw` och `scroll.raw`. Det är en callback, så inget beroende
  behövs.
- Beräkningarna är `computed`, och builder-funktionen destrukturerar bara props.
- När man närmar sig botten anropas `onLoadMore`. Det är hela "oändliga flödet".

---

## Åtgärdsmeny med bekräftelse

<details>
<summary>▶ Visa <code>confirm_dialog.dart</code></summary>

```dart
import 'package:flutter/material.dart';

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String okLabel = 'OK',
  String cancelLabel = 'Avbryt',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: Colors.red)
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(okLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
```

</details>

```dart
import 'package:flutter/material.dart';

import 'confirm_dialog.dart';

class EntityAction {
  const EntityAction({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.destructive = false,
    this.confirmMessage,
  });

  final IconData icon;
  final String label;
  final VoidCallback onSelected;
  final bool destructive;

  /// Om satt visas en bekräftelsedialog innan [onSelected] körs.
  final String? confirmMessage;

  factory EntityAction.update(VoidCallback onSelected,
          {String label = 'Redigera'}) =>
      EntityAction(
          icon: Icons.edit_outlined, label: label, onSelected: onSelected);

  factory EntityAction.delete(
    VoidCallback onSelected, {
    String label = 'Radera',
    String confirmMessage = 'Är du säker? Det går inte att ångra.',
  }) =>
      EntityAction(
        icon: Icons.delete_outline,
        label: label,
        onSelected: onSelected,
        destructive: true,
        confirmMessage: confirmMessage,
      );
}

/// `more_vert`-meny som ersätter lösa redigera/radera-knappar.
/// Skicka bara in de val användaren har behörighet till. Tom lista → inget visas.
class EntityActionMenu extends StatelessWidget {
  const EntityActionMenu({super.key, required this.actions});

  final List<EntityAction> actions;

  Future<void> _run(BuildContext context, EntityAction action) async {
    final message = action.confirmMessage;
    if (message != null) {
      final ok = await showConfirmDialog(
        context,
        title: action.label,
        message: message,
        okLabel: action.label,
        destructive: action.destructive,
      );
      if (!ok) return;
    }
    action.onSelected();
  }

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    return PopupMenuButton<EntityAction>(
      icon: const Icon(Icons.more_vert),
      tooltip: 'Fler val',
      onSelected: (action) => _run(context, action),
      itemBuilder: (context) => [
        for (final a in actions)
          PopupMenuItem(
            value: a,
            child: ListTile(
              leading: Icon(a.icon, color: a.destructive ? Colors.red : null),
              title: Text(
                a.label,
                style:
                    a.destructive ? const TextStyle(color: Colors.red) : null,
              ),
            ),
          ),
      ],
    );
  }
}
```

Skicka **bara** de val användaren har rätt till. En tom lista ritar ingenting:

```dart
EntityActionMenu(actions: [
  if (isMine.value) EntityAction.update(edit),
  if (canDelete.value) EntityAction.delete(delete),
]),
```

---

## Feature: inlägg

### Store

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart' hide AuthStore;

import '../../core/models/collections.dart';
import '../../core/models/post_record.dart';
import '../auth/auth_store.dart';
import '../feed/feed_store.dart';

class PostsStore {
  PostsStore(this._pb, this._auth, this._feed);

  final PocketBase _pb;
  final AuthStore _auth;
  final FeedStore _feed;

  final _saving = ref(false);
  ReadonlyRef<bool> get saving => _saving;

  Future<PostRecord?> fetchPost(String id) async {
    try {
      final r = await _pb
          .collection(Collections.posts)
          .getOne(id, expand: 'author,group,likes_via_post');
      return PostRecord.fromJson(r.toJson(),
          currentUserId: _auth.user.value?.id);
    } catch (e) {
      debugPrint('PostsStore.fetchPost: $e');
      return null;
    }
  }

  /// Skapar (id == null) eller uppdaterar ett inlägg.
  Future<bool> savePost({
    String? id,
    required String title,
    required String body,
    String? groupId,
  }) async {
    if (_auth.user.value == null) return false;
    _saving.value = true;
    try {
      final col = _pb.collection(Collections.posts);
      final data = {'title': title, 'body': body};
      if (id == null) {
        // author skickas inte: servern stämplar den (hook).
        if (groupId != null) data['group'] = groupId;
        await col.create(body: data);
      } else {
        await col.update(id, body: data);
      }
      await _feed.posts.refresh(); // hämta om efter mutation
      return true;
    } on ClientException catch (e) {
      debugPrint('PostsStore.savePost: ${e.response}');
      return false;
    } finally {
      _saving.value = false;
    }
  }

  Future<bool> deletePost(String id) async {
    try {
      await _pb.collection(Collections.posts).delete(id);
      _feed.posts.removeWhere((p) => p.id == id);
      return true;
    } on ClientException catch (e) {
      debugPrint('PostsStore.deletePost: ${e.response}');
      return false;
    }
  }
}
```

Två strategier för färsk data:

- **Hämta om efter mutation.** `savePost` anropar `posts.refresh()` på flödet, och
  `deletePost` tar bort lokalt. Det räcker för de flesta listor.
- **Realtime** för kommentarer, se nedan.

### Gilla: composable + store

Gillningen är **optimistisk** ([kapitel 8](08-async-data.md#optimistisk-uppdatering-gilla-direkt-ångra-vid-fel)).
Logiken bor i en composable så att alla kort (flödet, profilen, gruppen, detaljsidan)
beter sig likadant, medan serveranropet bor i `FeedStore`:

```dart
import 'package:flutter_compositions/flutter_compositions.dart';

import '../../../core/di/injection_keys.dart';
import '../../../core/models/post_record.dart';

class LikeToggle {
  const LikeToggle({
    required this.liked,
    required this.count,
    required this.label,
    required this.toggle,
  });

  final ReadonlyRef<bool> liked;
  final ReadonlyRef<int> count;
  final ReadonlyRef<String> label;
  final Future<void> Function() toggle;
}

/// Optimistisk gillning: UI:t ändras direkt och rullas tillbaka om
/// servern säger nej.
LikeToggle useLikeToggle(ReadonlyRef<PostRecord> post) {
  final feed = inject(feedStoreKey);

  final liked = ref(post.raw.likedByMe); // startvärden, utan beroende
  final count = ref(post.raw.likeCount);
  var busy = false; // inte reaktiv: ingen UI läser den

  // Ny data från servern (t.ex. efter pull-to-refresh) vinner.
  watch(() => post.value, (p, _) {
    liked.value = p.likedByMe;
    count.value = p.likeCount;
  });

  final label = computed(
    () => count.value == 1 ? '1 gillning' : '${count.value} gillningar',
  );

  Future<void> toggle() async {
    if (busy) return;
    busy = true;
    final wasLiked = liked.value;
    liked.value = !wasLiked; // 1. optimistiskt
    count.value += wasLiked ? -1 : 1;

    final ok = await feed.setLiked(post.raw.id, !wasLiked); // 2. servern

    if (!ok) {
      liked.value = wasLiked; // 3. rulla tillbaka
      count.value += wasLiked ? 1 : -1;
    }
    busy = false;
  }

  return LikeToggle(liked: liked, count: count, label: label, toggle: toggle);
}
```

- Startvärdena läses med `.raw`, eftersom de bara ska läsas en gång.
- `watch(() => post.value, …)` skriver över det lokala state:t när kortet får ny data
  från servern (t.ex. efter pull-to-refresh). Det är "lokal ref + watch" från kapitel 8.
- `busy` är en vanlig variabel. Ingen UI läser den, så den behöver inte vara reaktiv.

### Inläggskortet

`PostCard` används i alla listor. Den visar gilla-knappen och en `EntityActionMenu`
med **bara** de val användaren har rätt till:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection_keys.dart';
import '../../../core/models/post_record.dart';
import '../../../core/utils/permissions.dart';
import '../../../core/utils/time_ago.dart';
import '../../../shared/widgets/entity_action_menu.dart';
import '../../profile/pages/profile_page.dart';
import '../composables/use_like_toggle.dart';
import '../pages/create_post_page.dart';

/// Ett inlägg i en lista: författare, text, gilla-knapp och åtgärdsmeny.
class PostCard extends CompositionWidget {
  const PostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onEdited,
    this.onDeleted,
    this.maxLines = 4,
  });

  final PostRecord post;
  final VoidCallback? onTap;

  /// Anropas när redigeringssidan stängts efter en lyckad sparning.
  final VoidCallback? onEdited;

  /// Anropas efter lyckad radering, t.ex. för att ta bort kortet ur en
  /// lokal lista eller stänga detaljsidan.
  final VoidCallback? onDeleted;
  final int? maxLines;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final auth = inject(authStoreKey);
    final groups = inject(groupsStoreKey);
    final postsStore = inject(postsStoreKey);
    final theme = useTheme();
    final context = useContext();

    final post = computed(() => props.value.post);
    final like = useLikeToggle(post);

    final isMine = computed(() => post.value.author == auth.user.value?.id);
    final canDelete = computed(
      () =>
          isMine.value ||
          (post.value.inGroup &&
              groups.hasPermission(
                  post.value.group, GroupAction.deleteOthersPosts)),
    );
    final meta = computed(() {
      final p = post.value;
      final where = p.inGroup ? ' · ${p.groupName}' : '';
      return '${timeAgo(p.created)}$where';
    });
    final initial = computed(() {
      final name = post.value.authorName;
      return name.isEmpty ? '?' : name.characters.first.toUpperCase();
    });
    final titleStyle = computed(() => theme.value.textTheme.titleMedium);
    final likeColor = computed(() => like.liked.value ? Colors.red : null);
    final likeIcon = computed(
      () => like.liked.value ? Icons.favorite : Icons.favorite_border,
    );

    Future<void> edit() async {
      final ctx = context.value;
      if (ctx == null) return;
      final saved =
          await ctx.push<bool>(CreatePostPage.editPathFor(post.value.id));
      if (saved == true) props.value.onEdited?.call();
    }

    Future<void> delete() async {
      final ok = await postsStore.deletePost(post.value.id);
      final ctx = context.value;
      if (ok) {
        props.value.onDeleted?.call();
      } else if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Kunde inte radera inlägget')),
        );
      }
    }

    return (context) {
      final PostCard(:onTap, :maxLines) = props.value;
      final p = post.value;
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: CircleAvatar(child: Text(initial.value)),
              title: Text(p.authorName),
              subtitle: Text(meta.value),
              onTap: () => context.push(ProfilePage.pathFor(p.author)),
              trailing: EntityActionMenu(actions: [
                if (isMine.value) EntityAction.update(edit),
                if (canDelete.value)
                  EntityAction.delete(
                    delete,
                    confirmMessage: 'Vill du radera "${p.title}"?',
                  ),
              ]),
            ),
            InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.title, style: titleStyle.value),
                    const SizedBox(height: 4),
                    Text(p.body,
                        maxLines: maxLines, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                IconButton(
                  tooltip: 'Gilla',
                  onPressed: like.toggle,
                  icon: Icon(likeIcon.value, color: likeColor.value),
                ),
                Text(like.label.value),
              ],
            ),
          ],
        ),
      );
    };
  }
}
```

- `canDelete` kombinerar "mitt eget" med `groups.hasPermission(…, deleteOthersPosts)`.
  `hasPermission` läser en ref i `GroupsStore`, så menyn uppdateras av sig själv om
  min roll ändras.
- `onEdited` och `onDeleted` är callback-props (Vues `emit`), så att varje sida kan
  uppdatera *sin* lista.
- Temat läses med `useTheme()` i en `computed`, inte med `Theme.of(context)` i builder.

### Flödet

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection_keys.dart';
import '../../../shared/widgets/paginated_list_view.dart';
import '../../groups/pages/groups_list_page.dart';
import '../../posts/pages/create_post_page.dart';
import '../../posts/pages/post_detail_page.dart';
import '../../posts/widgets/post_card.dart';
import '../../profile/pages/profile_page.dart';
import '../feed_store.dart';

class PostsFeedPage extends CompositionWidget {
  const PostsFeedPage({super.key});

  static const path = '/';

  @override
  Widget Function(BuildContext) setup() {
    final feed = inject(feedStoreKey);
    final auth = inject(authStoreKey);
    final posts = feed.posts;

    final showSpinner = computed(
      () => posts.loading.value && posts.items.value.isEmpty,
    );
    final emptyText = computed(() => switch (feed.filter.value) {
          FeedFilter.all => 'Inga inlägg ännu. Skriv det första!',
          FeedFilter.following =>
            'Du följer ingen än, eller så har de inte skrivit något',
          FeedFilter.mine => 'Du har inte skrivit något än',
        });
    final myId = computed(() => auth.user.value?.id ?? '');

    onMounted(posts.refresh);

    return (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Kvittra'),
            actions: [
              IconButton(
                tooltip: 'Grupper',
                icon: const Icon(Icons.groups),
                onPressed: () => context.push(GroupsListPage.path),
              ),
              IconButton(
                tooltip: 'Min profil',
                icon: const Icon(Icons.person),
                onPressed: () => context.push(ProfilePage.pathFor(myId.value)),
              ),
              IconButton(
                tooltip: 'Logga ut',
                icon: const Icon(Icons.logout),
                onPressed: auth.signOut,
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            tooltip: 'Nytt inlägg',
            onPressed: () => context.push(CreatePostPage.path),
            child: const Icon(Icons.edit),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: SegmentedButton<FeedFilter>(
                  segments: const [
                    ButtonSegment(value: FeedFilter.all, label: Text('Alla')),
                    ButtonSegment(
                        value: FeedFilter.following, label: Text('Följer')),
                    ButtonSegment(value: FeedFilter.mine, label: Text('Mina')),
                  ],
                  selected: {feed.filter.value},
                  onSelectionChanged: (s) => feed.setFilter(s.first),
                ),
              ),
              Expanded(
                child: showSpinner.value
                    ? const Center(child: CircularProgressIndicator())
                    : PaginatedListView(
                        itemCount: posts.items.value.length,
                        hasMore: posts.hasMore.value,
                        loadingMore: posts.loadingMore.value,
                        onLoadMore: posts.loadMore,
                        onRefresh: posts.refresh,
                        emptyText: emptyText.value,
                        itemBuilder: (context, i) {
                          final post = posts.items.value[i];
                          return PostCard(
                            key: ValueKey(post.id),
                            post: post,
                            onTap: () =>
                                context.push(PostDetailPage.pathFor(post.id)),
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

`key: ValueKey(post.id)` är viktigt: utan den kan Flutter återanvända ett kort (och
dess lokala gilla-state) för ett annat inlägg när listan ändras.

### Detaljsidan

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection_keys.dart';
import '../../../core/models/post_record.dart';
import '../../comments/widgets/comments_section.dart';
import '../widgets/post_card.dart';

class PostDetailPage extends CompositionWidget {
  const PostDetailPage({super.key, required this.postId});

  final String postId;

  static const path = '/posts/:id';
  static String pathFor(String id) => '/posts/$id';

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final store = inject(postsStoreKey);

    // Hämtas via id, så sidan fungerar även vid direktlänk till /posts/:id.
    final (status, refresh) = useAsyncData<PostRecord, String>(
      (id) async {
        final post = await store.fetchPost(id);
        return post ??
            (throw 'Inlägget finns inte eller så får du inte se det');
      },
      watch: () => props.value.postId,
    );

    final title = computed(() => status.value.dataOrNull?.title ?? 'Inlägg');

    return (context) => Scaffold(
          appBar: AppBar(title: Text(title.value)),
          body: switch (status.value) {
            AsyncIdle() ||
            AsyncLoading() =>
              const Center(child: CircularProgressIndicator()),
            AsyncError(:final errorValue) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$errorValue'),
                    TextButton(
                        onPressed: refresh, child: const Text('Försök igen')),
                  ],
                ),
              ),
            AsyncData(:final value) => CommentsSection(
                post: value,
                header: PostCard(
                  post: value,
                  maxLines: null, // visa hela texten
                  onEdited: refresh, // hämta om efter redigering
                  onDeleted: () => context.pop(),
                ),
              ),
          },
        );
  }
}
```

Sidan hämtar inlägget **via id** med `useAsyncData`, så den fungerar även vid
direktlänk till `/posts/:id`. `onEdited: refresh` hämtar om efter redigering.
Kommentarerna kommer i nästa avsnitt.

### Skapa och redigera, samma sida

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection_keys.dart';

/// Skapa ELLER redigera. Med postId → redigeringsläge.
/// Med groupId (bara vid nytt inlägg) → inlägget hamnar i gruppen.
class CreatePostPage extends CompositionWidget {
  const CreatePostPage({super.key, this.postId, this.groupId});

  final String? postId;
  final String? groupId;

  static const path = '/posts/new';
  static String pathForGroup(String groupId) => '/posts/new?group=$groupId';
  static const editPath = '/posts/:id/edit';
  static String editPathFor(String id) => '/posts/$id/edit';

  static const maxBody = 2000;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final store = inject(postsStoreKey);
    final context = useContext();

    final (titleController, title, _) = useTextEditingController();
    final (bodyController, body, _) = useTextEditingController();
    final loadingExisting = ref(false);

    final isEdit = computed(() => props.value.postId != null);
    final pageTitle =
        computed(() => isEdit.value ? 'Redigera inlägg' : 'Nytt inlägg');
    final titleError = computed(
      () => title.value.trim().length < 3 ? 'Minst 3 tecken' : null,
    );
    final bodyError = computed(() {
      final length = body.value.trim().length;
      if (length == 0) return 'Skriv något';
      if (length > maxBody) {
        return 'Max $maxBody tecken (${length - maxBody} för mycket)';
      }
      return null;
    });
    // Visa inte felen förrän användaren börjat skriva.
    final visibleTitleError = computed(
      () => title.value.isEmpty ? null : titleError.value,
    );
    final visibleBodyError = computed(
      () => body.value.isEmpty ? null : bodyError.value,
    );
    final canSave = computed(() =>
        titleError.value == null &&
        bodyError.value == null &&
        !store.saving.value &&
        !loadingExisting.value);
    final saveLabel =
        computed(() => store.saving.value ? 'Sparar…' : 'Publicera');

    // Förifyll i redigeringsläge (fungerar även vid direktlänk).
    onMounted(() async {
      final id = props.value.postId;
      if (id == null) return;
      loadingExisting.value = true;
      final existing = await store.fetchPost(id);
      if (existing != null) {
        title.value = existing.title; // tvåvägsbindning fyller fälten
        body.value = existing.body;
      }
      loadingExisting.value = false;
    });

    Future<void> save() async {
      final ok = await store.savePost(
        id: props.value.postId,
        title: title.value.trim(),
        body: body.value.trim(),
        groupId: props.value.groupId,
      );
      final ctx = context.value;
      if (ctx == null || !ctx.mounted) return;
      if (ok) {
        ctx.pop(true); // true = "sparat", så att föregående sida kan hämta om
      } else {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Kunde inte spara inlägget')),
        );
      }
    }

    return (context) => Scaffold(
          appBar: AppBar(title: Text(pageTitle.value)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (loadingExisting.value) const LinearProgressIndicator(),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Rubrik',
                  errorText: visibleTitleError.value,
                ),
              ),
              TextField(
                controller: bodyController,
                minLines: 4,
                maxLines: 12,
                decoration: InputDecoration(
                  labelText: 'Vad vill du berätta?',
                  errorText: visibleBodyError.value,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: canSave.value ? save : null,
                child: Text(saveLabel.value),
              ),
            ],
          ),
        );
  }
}
```

- `postId == null` betyder nytt, annars redigering. `groupId` (från `?group=…`)
  lägger det nya inlägget i en grupp.
- Förifyllning sker i `onMounted`. Tvåvägsbindningen gör att `title.value = …` räcker.
- `canSave` kombinerar validering med `store.saving` och `loadingExisting`.
- `ctx.pop(true)` talar om för föregående sida att något sparats.

---

## Kommentarer i realtid

Store:n hämtar kommentarerna och prenumererar sedan på ändringar, med skydd mot
race-fall:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/models/collections.dart';
import '../../core/models/comment_record.dart';

class CommentsStore {
  CommentsStore(this._pb);

  final PocketBase _pb;

  final _comments = ref<List<CommentRecord>>([]);
  final _loading = ref(false);
  ReadonlyRef<List<CommentRecord>> get comments => _comments;
  ReadonlyRef<bool> get loading => _loading;

  String? _activePostId;
  UnsubscribeFunc? _unsubscribe;

  /// Hämtar kommentarer för ett inlägg och prenumererar på ändringar.
  Future<void> watchComments(String postId) async {
    await stopWatching();
    _activePostId = postId;
    _comments.value = [];
    _loading.value = true;
    final col = _pb.collection(Collections.comments);
    final filter = _pb.filter('post = {:id}', {'id': postId});
    try {
      final list = await col.getFullList(
        filter: filter,
        sort: 'created',
        expand: 'author',
      );
      if (_activePostId != postId) return; // sidan hann stängas
      _comments.value =
          list.map((r) => CommentRecord.fromJson(r.toJson())).toList();

      final unsub = await col.subscribe(
        '*',
        (e) => _applyEvent(postId, e),
        filter: filter,
        expand: 'author',
      );
      if (_activePostId != postId) {
        await unsub(); // sidan stängdes medan vi prenumererade
      } else {
        _unsubscribe = unsub;
      }
    } catch (e) {
      debugPrint('CommentsStore.watchComments: $e');
    } finally {
      if (_activePostId == postId) _loading.value = false;
    }
  }

  void _applyEvent(String postId, RecordSubscriptionEvent e) {
    final record = e.record;
    if (record == null || _activePostId != postId) return;
    final c = CommentRecord.fromJson(record.toJson());
    final current = _comments.value;
    _comments.value = switch (e.action) {
      'create' => current.any((x) => x.id == c.id) ? current : [...current, c],
      'update' => [for (final x in current) x.id == c.id ? c : x],
      'delete' => current.where((x) => x.id != c.id).toList(),
      _ => current,
    };
  }

  Future<void> stopWatching() async {
    _activePostId = null;
    final unsub = _unsubscribe;
    _unsubscribe = null;
    if (unsub != null) await unsub();
  }

  Future<bool> addComment(String postId, String body) async {
    try {
      // author stämplas av servern. Kommentaren läggs in i listan av
      // realtime-händelsen, så egna och andras kommentarer går samma väg.
      await _pb
          .collection(Collections.comments)
          .create(body: {'post': postId, 'body': body});
      return true;
    } on ClientException catch (e) {
      debugPrint('CommentsStore.addComment: ${e.response}');
      return false;
    }
  }

  Future<bool> deleteComment(String id) async {
    try {
      await _pb.collection(Collections.comments).delete(id);
      _comments.value = _comments.value.where((c) => c.id != id).toList();
      return true;
    } on ClientException catch (e) {
      debugPrint('CommentsStore.deleteComment: ${e.response}');
      return false;
    }
  }
}
```

Widgeten kopplar ihop store:n med `useCommentComposer` från
[kapitel 5](05-composables.md):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

import '../../../core/di/injection_keys.dart';
import '../../../core/models/comment_record.dart';
import '../../../core/models/post_record.dart';
import '../../../core/utils/permissions.dart';
import '../../../core/utils/time_ago.dart';
import '../../../shared/widgets/entity_action_menu.dart';
import '../composables/use_comment_composer.dart';

/// Kommentarer i realtid + ett fält för att skriva en ny.
/// [header] visas överst i samma scrollbara lista (t.ex. själva inlägget).
class CommentsSection extends CompositionWidget {
  const CommentsSection({super.key, required this.post, required this.header});

  final PostRecord post;
  final Widget header;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final store = inject(commentsStoreKey);
    final auth = inject(authStoreKey);
    final groups = inject(groupsStoreKey);
    final context = useContext();

    final composer = useCommentComposer(
      onSend: (body) => store.addComment(props.value.post.id, body),
    );

    final title = computed(
      () => 'Kommentarer (${store.comments.value.length})',
    );
    // I en grupp får bara medlemmar kommentera. Utanför grupper får alla.
    final canComment = computed(() {
      final p = props.value.post;
      return !p.inGroup || groups.hasPermission(p.group, GroupAction.comment);
    });

    // Vilka kommentarer får jag radera? Mina egna, alla på mitt eget inlägg,
    // och alla i gruppen om jag är moderator eller admin där.
    final deletableIds = computed(() {
      final me = auth.user.value?.id;
      final p = props.value.post;
      final moderates = p.inGroup &&
          groups.hasPermission(p.group, GroupAction.deleteOthersPosts);
      return {
        for (final c in store.comments.value)
          if (moderates || c.author == me || p.author == me) c.id,
      };
    });

    // Starta realtime när sidan visas. Byts inlägget (ny prop) startar vi om.
    onMounted(() => store.watchComments(props.value.post.id));
    watch(() => props.value.post.id, (id, _) => store.watchComments(id));
    // Registrerat direkt i setup(), inte inuti onMounted.
    onUnmounted(store.stopWatching);

    Future<void> delete(CommentRecord c) async {
      final ok = await store.deleteComment(c.id);
      final ctx = context.value;
      if (!ok && ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Kunde inte radera kommentaren')),
        );
      }
    }

    return (context) {
      final CommentsSection(:header) = props.value;
      return Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                header,
                ListTile(title: Text(title.value)),
                if (store.loading.value) const LinearProgressIndicator(),
                for (final c in store.comments.value)
                  ListTile(
                    title: Text(c.body),
                    subtitle: Text('${c.authorName} · ${timeAgo(c.created)}'),
                    trailing: EntityActionMenu(
                      actions: [
                        if (deletableIds.value.contains(c.id))
                          EntityAction.delete(() => delete(c)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (canComment.value)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: composer.controller,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Skriv en kommentar…',
                          errorText: composer.error.value,
                          suffixText: composer.counterLabel.value,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: composer.canSend.value ? composer.send : null,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Gå med i gruppen för att kommentera'),
            ),
        ],
      );
    };
  }
}
```

**Livscykeln i detalj:**

1. `onMounted` startar realtime (`store.watchComments`). Byts inlägget (ny prop)
   startar `watch(() => props.value.post.id, …)` om prenumerationen, precis som
   `didUpdateWidget` hade gjort.
2. `onUnmounted(store.stopWatching)` registreras **direkt i `setup()`**
   ([kapitel 4](04-livscykel-och-props.md): hooks får inte registreras inuti
   `onMounted` i 0.1.1).
3. I store:n skyddar `_activePostId` mot race-fall. Om sidan stängs medan `subscribe`
   pågår avslutas prenumerationen direkt. Det är samma idé som `disposed`-flaggan i
   kapitel 8.
4. `subscribe` får ett `filter`, så att servern bara skickar händelser för det här
   inlägget. API-reglerna gäller även för realtime, så kommentarer i en privat grupp
   når bara medlemmar.
5. En skickad kommentar läggs **inte** in manuellt. `create`-händelsen gör det, vilket
   ger samma kodväg för egna och andras kommentarer.
6. Vem som får radera vad är en `computed` (`deletableIds`), inte logik i builder.

---

## Profil: följa och sluta följa

<details>
<summary>▶ Visa <code>profile_store.dart</code></summary>

```dart
import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart' hide AuthStore;

import '../../core/models/collections.dart';
import '../../core/models/user_record.dart';
import '../auth/auth_store.dart';

class ProfileData {
  const ProfileData({
    required this.user,
    required this.followers,
    required this.following,
    required this.followedByMe,
  });

  final UserRecord user;
  final int followers; // hur många som följer användaren
  final int following; // hur många användaren följer
  final bool followedByMe;
}

class ProfileStore {
  ProfileStore(this._pb, this._auth);

  final PocketBase _pb;
  final AuthStore _auth;

  /// Antal poster som matchar ett filter, utan att hämta dem.
  Future<int> _count(String filter) async {
    final res = await _pb
        .collection(Collections.follows)
        .getList(perPage: 1, filter: filter);
    return res.totalItems;
  }

  /// Kastar vid fel, så att useAsyncData kan visa AsyncError.
  Future<ProfileData> fetchProfile(String userId) async {
    final me = _auth.user.value?.id ?? '';
    final record = await _pb.collection(Collections.users).getOne(userId);
    final results = await Future.wait([
      _count(_pb.filter('following = {:id}', {'id': userId})),
      _count(_pb.filter('follower = {:id}', {'id': userId})),
      _count(_pb.filter(
        'follower = {:me} && following = {:id}',
        {'me': me, 'id': userId},
      )),
    ]);
    return ProfileData(
      user: UserRecord.fromJson(record.toJson()),
      followers: results[0],
      following: results[1],
      followedByMe: results[2] > 0,
    );
  }

  Future<bool> follow(String userId) async {
    final me = _auth.user.value?.id;
    if (me == null) return false;
    try {
      await _pb
          .collection(Collections.follows)
          .create(body: {'follower': me, 'following': userId});
      return true;
    } on ClientException catch (e) {
      debugPrint('ProfileStore.follow: ${e.response}');
      return false;
    }
  }

  Future<bool> unfollow(String userId) async {
    final me = _auth.user.value?.id;
    if (me == null) return false;
    try {
      final col = _pb.collection(Collections.follows);
      final row = await col.getFirstListItem(
        _pb.filter(
            'follower = {:me} && following = {:id}', {'me': me, 'id': userId}),
      );
      await col.delete(row.id);
      return true;
    } on ClientException catch (e) {
      debugPrint('ProfileStore.unfollow: ${e.response}');
      return false;
    }
  }
}
```

</details>

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection_keys.dart';
import '../../../core/models/post_record.dart';
import '../../../core/pagination/paginated.dart';
import '../../../shared/widgets/paginated_list_view.dart';
import '../../posts/pages/post_detail_page.dart';
import '../../posts/widgets/post_card.dart';
import '../profile_store.dart';

class ProfilePage extends CompositionWidget {
  const ProfilePage({super.key, required this.userId});

  final String userId;

  static const path = '/users/:id';
  static String pathFor(String id) => '/users/$id';

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final store = inject(profileStoreKey);
    final feed = inject(feedStoreKey);
    final auth = inject(authStoreKey);
    final theme = useTheme();
    final context = useContext();

    // 1. Profilen (användare + antal följare). Hämtas om vid nytt userId.
    final (status, _) = useAsyncData<ProfileData, String>(
      store.fetchProfile,
      watch: () => props.value.userId,
    );

    // 2. Lokalt state för följ-knappen: synkas från servern, ändras
    //    optimistiskt (samma mönster som "lokal ref + watch" i kapitel 8).
    final followedByMe = ref(false);
    final followers = ref(0);
    watch(() => status.value, (s, _) {
      if (s case AsyncData(:final value)) {
        followedByMe.value = value.followedByMe;
        followers.value = value.followers;
      }
    });

    // 3. Användarens inlägg. Paginated är en vanlig klass, så den kan
    //    skapas här i setup() och leva lika länge som sidan.
    final posts = Paginated<PostRecord>(
      (page, perPage) => feed.fetchPosts(
        page: page,
        perPage: perPage,
        authorId: props.raw.userId,
      ),
    );
    onMounted(posts.refresh);
    watch(() => props.value.userId, (_, _) => posts.refresh());

    final isMe = computed(() => props.value.userId == auth.user.value?.id);
    final user = computed(() => status.value.dataOrNull?.user);
    final title = computed(() => user.value?.displayName ?? 'Profil');
    final username = computed(() => '@${user.value?.username ?? ''}');
    final bio = computed(() => user.value?.bio ?? '');
    final stats = computed(() {
      final following = status.value.dataOrNull?.following ?? 0;
      return '${followers.value} följare · följer $following';
    });
    final followLabel = computed(
      () => followedByMe.value ? 'Sluta följa' : 'Följ',
    );
    final nameStyle = computed(() => theme.value.textTheme.headlineSmall);

    Future<void> toggleFollow() async {
      final id = props.value.userId;
      final was = followedByMe.value;
      followedByMe.value = !was; // optimistiskt
      followers.value += was ? -1 : 1;
      final ok = was ? await store.unfollow(id) : await store.follow(id);
      if (ok) return;
      followedByMe.value = was; // rulla tillbaka
      followers.value += was ? 1 : -1;
      final ctx = context.value;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Det gick inte, försök igen')),
        );
      }
    }

    Widget header() => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title.value, style: nameStyle.value),
              Text(username.value),
              if (bio.value.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(bio.value),
              ],
              const SizedBox(height: 8),
              Text(stats.value),
              if (!isMe.value) ...[
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: status.value.isData ? toggleFollow : null,
                  child: Text(followLabel.value),
                ),
              ],
            ],
          ),
        );

    return (context) => Scaffold(
          appBar: AppBar(title: Text(title.value)),
          body: switch (status.value) {
            AsyncIdle() ||
            AsyncLoading() =>
              const Center(child: CircularProgressIndicator()),
            AsyncError(:final errorValue) =>
              Center(child: Text('Kunde inte hämta profilen: $errorValue')),
            AsyncData() => PaginatedListView(
                // Rad 0 är profilhuvudet, resten är inlägg.
                itemCount: posts.items.value.length + 1,
                hasMore: posts.hasMore.value,
                loadingMore: posts.loadingMore.value,
                onLoadMore: posts.loadMore,
                onRefresh: posts.refresh,
                itemBuilder: (context, i) {
                  if (i == 0) return header();
                  final post = posts.items.value[i - 1];
                  return PostCard(
                    key: ValueKey(post.id),
                    post: post,
                    onTap: () => context.push(PostDetailPage.pathFor(post.id)),
                    onEdited: posts.refresh,
                    onDeleted: () => posts.removeWhere((p) => p.id == post.id),
                  );
                },
              ),
          },
        );
  }
}
```

Profilsidan kombinerar tre mönster:

1. **`useAsyncData` med `watch`** för profilen. Byts `userId` hämtas den nya.
2. **Lokal ref + `watch`** för följ-knappen och antalet följare. De synkas från servern
   och ändras optimistiskt, med tillbakarullning vid fel.
3. **En `Paginated` i `setup()`** för användarens inlägg. Hämtfunktionen läser
   `props.raw.userId` (en callback, inget beroende behövs) och en `watch` på
   `props.value.userId` hämtar om.

---

## Grupper och roller

### Rollmatrisen

```dart
/// Roller i en grupp (`group_members.role`).
enum GroupRole { admin, moderator, member }

/// Saker man kan vilja göra i en grupp.
enum GroupAction {
  createPost,
  comment,
  deleteOthersPosts,
  editGroup,
  manageMembers,
  deleteGroup,
}

/// Rollmatrisen. API-reglerna på servern speglar samma matris.
const Map<GroupRole, Set<GroupAction>> groupPermissions = {
  GroupRole.admin: {
    GroupAction.createPost,
    GroupAction.comment,
    GroupAction.deleteOthersPosts,
    GroupAction.editGroup,
    GroupAction.manageMembers,
    GroupAction.deleteGroup,
  },
  GroupRole.moderator: {
    GroupAction.createPost,
    GroupAction.comment,
    GroupAction.deleteOthersPosts,
  },
  GroupRole.member: {
    GroupAction.createPost,
    GroupAction.comment,
  },
};

/// `role == null` betyder "inte medlem", och då får man ingenting.
bool roleAllows(GroupRole? role, GroupAction action) =>
    role != null && (groupPermissions[role]?.contains(action) ?? false);
```

Matrisen är en **ren funktion** som är lätt att testa. Samma matris finns på servern,
uttryckt som API-regler (och, i fördjupningen nedan, som en hook).

### Store

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart' hide AuthStore;

import '../../core/models/collections.dart';
import '../../core/models/group_record.dart';
import '../../core/pagination/paginated.dart';
import '../../core/utils/permissions.dart';
import '../auth/auth_store.dart';

class GroupsStore {
  GroupsStore(this._pb, this._auth);

  final PocketBase _pb;
  final AuthStore _auth;

  /// Alla grupper jag får se: publika + privata där jag är medlem.
  late final groups = Paginated<GroupRecord>((page, perPage) async {
    final res = await _pb.collection(Collections.groups).getList(
          page: page,
          perPage: perPage,
          sort: 'name',
        );
    return PageResult(
      res.items.map((r) => GroupRecord.fromJson(r.toJson())).toList(),
      res.totalPages,
    );
  });

  /// Mina medlemskap: grupp-id → roll. Laddas vid inloggning.
  final _myRoles = ref<Map<String, GroupRole>>({});
  final _saving = ref(false);
  ReadonlyRef<Map<String, GroupRole>> get myRoles => _myRoles;
  ReadonlyRef<bool> get saving => _saving;

  Future<void> loadMyRoles() async {
    final me = _auth.user.value?.id;
    if (me == null) return clear();
    try {
      final list = await _pb.collection(Collections.groupMembers).getFullList(
            filter: _pb.filter('user = {:me}', {'me': me}),
          );
      _myRoles.value = {
        for (final m in list.map((r) => GroupMemberRecord.fromJson(r.toJson())))
          m.group: m.role,
      };
    } catch (e) {
      debugPrint('GroupsStore.loadMyRoles: $e');
    }
  }

  void clear() => _myRoles.value = {};

  /// Läser en ref, så anrop i computed eller builder blir reaktiva.
  GroupRole? roleIn(String groupId) => _myRoles.value[groupId];

  bool isMember(String groupId) => roleIn(groupId) != null;

  bool hasPermission(String groupId, GroupAction action) =>
      roleAllows(roleIn(groupId), action);

  @visibleForTesting
  void debugSetRoles(Map<String, GroupRole> roles) => _myRoles.value = roles;

  // ---- Grupper ------------------------------------------------------------

  /// Kastar vid fel, så att useAsyncData kan visa AsyncError.
  Future<GroupRecord> fetchGroup(String id) async {
    final r = await _pb.collection(Collections.groups).getOne(id);
    return GroupRecord.fromJson(r.toJson());
  }

  /// Skapar (id == null) eller uppdaterar en grupp.
  Future<bool> saveGroup({
    String? id,
    required String name,
    required String description,
    required GroupVisibility visibility,
  }) async {
    _saving.value = true;
    try {
      final col = _pb.collection(Collections.groups);
      final data = {
        'name': name,
        'description': description,
        'visibility': visibility.name,
      };
      if (id == null) {
        // owner stämplas av servern, och en hook gör mig till admin.
        await col.create(body: data);
        await loadMyRoles();
      } else {
        await col.update(id, body: data);
      }
      await groups.refresh();
      return true;
    } on ClientException catch (e) {
      debugPrint('GroupsStore.saveGroup: ${e.response}');
      return false;
    } finally {
      _saving.value = false;
    }
  }

  Future<bool> deleteGroup(String id) async {
    try {
      await _pb.collection(Collections.groups).delete(id);
      groups.removeWhere((g) => g.id == id);
      _myRoles.value = {..._myRoles.value}..remove(id);
      return true;
    } on ClientException catch (e) {
      debugPrint('GroupsStore.deleteGroup: ${e.response}');
      return false;
    }
  }

  // ---- Medlemskap ---------------------------------------------------------

  Future<bool> join(String groupId) async {
    final me = _auth.user.value?.id;
    if (me == null) return false;
    try {
      await _pb.collection(Collections.groupMembers).create(body: {
        'group': groupId,
        'user': me,
        'role': GroupRole.member.name,
      });
      _myRoles.value = {..._myRoles.value, groupId: GroupRole.member};
      return true;
    } on ClientException catch (e) {
      debugPrint('GroupsStore.join: ${e.response}');
      return false;
    }
  }

  Future<bool> leave(String groupId) async {
    final me = _auth.user.value?.id;
    if (me == null) return false;
    try {
      final col = _pb.collection(Collections.groupMembers);
      final row = await col.getFirstListItem(
        _pb.filter('group = {:g} && user = {:me}', {'g': groupId, 'me': me}),
      );
      await col.delete(row.id);
      _myRoles.value = {..._myRoles.value}..remove(groupId);
      return true;
    } on ClientException catch (e) {
      debugPrint('GroupsStore.leave: ${e.response}');
      return false;
    }
  }

  Future<List<GroupMemberRecord>> fetchMembers(String groupId) async {
    final list = await _pb.collection(Collections.groupMembers).getFullList(
          filter: _pb.filter('group = {:g}', {'g': groupId}),
          expand: 'user',
          sort: 'role,created',
        );
    return list.map((r) => GroupMemberRecord.fromJson(r.toJson())).toList();
  }

  /// Bara gruppens admin (update-regeln på group_members kontrollerar det).
  Future<bool> setRole(String memberId, GroupRole role) async {
    try {
      await _pb
          .collection(Collections.groupMembers)
          .update(memberId, body: {'role': role.name});
      return true;
    } on ClientException catch (e) {
      debugPrint('GroupsStore.setRole: ${e.response}');
      return false;
    }
  }

  Future<bool> removeMember(String memberId) async {
    try {
      await _pb.collection(Collections.groupMembers).delete(memberId);
      return true;
    } on ClientException catch (e) {
      debugPrint('GroupsStore.removeMember: ${e.response}');
      return false;
    }
  }
}
```

- `_myRoles` är en `Map<String, GroupRole>` (grupp-id → min roll). Den laddas vid
  inloggning (`watch` i `MyApp`) och uppdateras lokalt vid `join`, `leave` och
  `deleteGroup`.
- `hasPermission` är en vanlig metod, men eftersom den läser `_myRoles.value` blir den
  reaktiv när den anropas i en `computed` eller i builder.
- Efter `saveGroup` för en ny grupp laddas rollerna om, eftersom hooken på servern
  gjorde mig till `admin`.
- `debugSetRoles` finns bara för tester (`@visibleForTesting`).

### Gruppsidan: FAB och meny styrs av rollen

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection_keys.dart';
import '../../../core/models/group_record.dart';
import '../../../core/models/post_record.dart';
import '../../../core/pagination/paginated.dart';
import '../../../core/utils/permissions.dart';
import '../../../shared/widgets/entity_action_menu.dart';
import '../../../shared/widgets/paginated_list_view.dart';
import '../../posts/pages/create_post_page.dart';
import '../../posts/pages/post_detail_page.dart';
import '../../posts/widgets/post_card.dart';
import 'create_group_page.dart';
import 'group_members_page.dart';
import 'groups_list_page.dart';

class GroupDetailPage extends CompositionWidget {
  const GroupDetailPage({super.key, required this.groupId});

  final String groupId;

  static const path = '${GroupsListPage.path}/:id';
  static String pathFor(String id) => '${GroupsListPage.path}/$id';

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final store = inject(groupsStoreKey);
    final feed = inject(feedStoreKey);
    final context = useContext();

    final (status, refresh) = useAsyncData<GroupRecord, String>(
      store.fetchGroup,
      watch: () => props.value.groupId,
    );

    final posts = Paginated<PostRecord>(
      (page, perPage) => feed.fetchPosts(
        page: page,
        perPage: perPage,
        groupId: props.raw.groupId,
      ),
    );
    onMounted(posts.refresh);

    // Behörigheter: computed som läser store:ns roller → reaktiva.
    final id = computed(() => props.value.groupId);
    final role = computed(() => store.roleIn(id.value));
    final canPost = computed(
      () => store.hasPermission(id.value, GroupAction.createPost),
    );
    final canEdit = computed(
      () => store.hasPermission(id.value, GroupAction.editGroup),
    );
    final canDelete = computed(
      () => store.hasPermission(id.value, GroupAction.deleteGroup),
    );
    final canJoin = computed(
      () => role.value == null && status.value.dataOrNull?.isPrivate == false,
    );
    final title = computed(() => status.value.dataOrNull?.name ?? 'Grupp');
    final description =
        computed(() => status.value.dataOrNull?.description ?? '');
    final roleLabel = computed(() => switch (role.value) {
          null => 'Du är inte medlem',
          final r => 'Du är ${r.name}',
        });

    void snack(String text) {
      final ctx = context.value;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(text)));
      }
    }

    Future<void> join() async {
      if (await store.join(id.value)) {
        await posts.refresh(); // privata inlägg kan nu synas
      } else {
        snack('Kunde inte gå med i gruppen');
      }
    }

    Future<void> leave() async {
      if (!await store.leave(id.value)) snack('Kunde inte lämna gruppen');
    }

    Future<void> edit() async {
      final ctx = context.value;
      if (ctx == null) return;
      final saved = await ctx.push<bool>(CreateGroupPage.editPathFor(id.value));
      if (saved == true) refresh();
    }

    Future<void> delete() async {
      final ok = await store.deleteGroup(id.value);
      final ctx = context.value;
      if (ok && ctx != null && ctx.mounted) {
        ctx.pop();
      } else if (!ok) {
        snack('Kunde inte radera gruppen');
      }
    }

    Future<void> newPost() async {
      final ctx = context.value;
      if (ctx == null) return;
      final saved = await ctx.push<bool>(CreatePostPage.pathForGroup(id.value));
      if (saved == true) await posts.refresh();
    }

    Widget header() => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (description.value.isNotEmpty) Text(description.value),
              const SizedBox(height: 8),
              Text(roleLabel.value),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (canJoin.value)
                    FilledButton(onPressed: join, child: const Text('Gå med')),
                  if (role.value != null)
                    OutlinedButton(
                        onPressed: leave, child: const Text('Lämna')),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () =>
                        context.value?.push(GroupMembersPage.pathFor(id.value)),
                    icon: const Icon(Icons.people),
                    label: const Text('Medlemmar'),
                  ),
                ],
              ),
            ],
          ),
        );

    return (context) => Scaffold(
          appBar: AppBar(
            title: Text(title.value),
            actions: [
              EntityActionMenu(actions: [
                if (canEdit.value) EntityAction.update(edit),
                if (canDelete.value)
                  EntityAction.delete(
                    delete,
                    confirmMessage: 'Gruppen och alla dess inlägg raderas.',
                  ),
              ]),
            ],
          ),
          // FAB:en syns bara för den som får skriva i gruppen.
          floatingActionButton: canPost.value
              ? FloatingActionButton(
                  tooltip: 'Nytt inlägg i gruppen',
                  onPressed: newPost,
                  child: const Icon(Icons.edit),
                )
              : null,
          body: switch (status.value) {
            AsyncIdle() ||
            AsyncLoading() =>
              const Center(child: CircularProgressIndicator()),
            AsyncError(:final errorValue) =>
              Center(child: Text('Kunde inte hämta gruppen: $errorValue')),
            AsyncData() => PaginatedListView(
                itemCount: posts.items.value.length + 1, // rad 0 = huvudet
                hasMore: posts.hasMore.value,
                loadingMore: posts.loadingMore.value,
                onLoadMore: posts.loadMore,
                onRefresh: posts.refresh,
                itemBuilder: (context, i) {
                  if (i == 0) return header();
                  final post = posts.items.value[i - 1];
                  return PostCard(
                    key: ValueKey(post.id),
                    post: post,
                    onTap: () => context.push(PostDetailPage.pathFor(post.id)),
                    onEdited: posts.refresh,
                    onDeleted: () => posts.removeWhere((p) => p.id == post.id),
                  );
                },
              ),
          },
        );
  }
}
```

Alla behörighetsbeslut (`canPost`, `canEdit`, `canDelete`, `canJoin`) är `computed`.
FAB:en för nya inlägg finns bara för medlemmar, och åtgärdsmenyn har bara de val
rollen tillåter. Går användaren med i gruppen ändras `_myRoles`, och FAB:en dyker upp
utan att sidan laddas om.

> ⚠️ **Varning:** Att dölja en knapp är **UX**, inte säkerhet. API-reglerna stoppar
> samma sak på servern, och det är dem som räknas.

<details>
<summary>▶ Visa övriga gruppsidor: lista, skapa/redigera och medlemmar</summary>

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection_keys.dart';
import '../../../shared/widgets/paginated_list_view.dart';
import 'create_group_page.dart';
import 'group_detail_page.dart';

class GroupsListPage extends CompositionWidget {
  const GroupsListPage({super.key});

  static const path = '/groups';

  @override
  Widget Function(BuildContext) setup() {
    final store = inject(groupsStoreKey);
    final groups = store.groups;

    final showSpinner = computed(
      () => groups.loading.value && groups.items.value.isEmpty,
    );

    onMounted(groups.refresh);

    return (context) => Scaffold(
          appBar: AppBar(title: const Text('Grupper')),
          floatingActionButton: FloatingActionButton(
            tooltip: 'Ny grupp',
            onPressed: () => context.push(CreateGroupPage.path),
            child: const Icon(Icons.group_add),
          ),
          body: showSpinner.value
              ? const Center(child: CircularProgressIndicator())
              : PaginatedListView(
                  itemCount: groups.items.value.length,
                  hasMore: groups.hasMore.value,
                  loadingMore: groups.loadingMore.value,
                  onLoadMore: groups.loadMore,
                  onRefresh: groups.refresh,
                  emptyText: 'Inga grupper ännu',
                  itemBuilder: (context, i) {
                    final g = groups.items.value[i];
                    final role = store.myRoles.value[g.id];
                    return ListTile(
                      leading: Icon(g.isPrivate ? Icons.lock : Icons.public),
                      title: Text(g.name),
                      subtitle: Text(
                        g.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing:
                          role == null ? null : Chip(label: Text(role.name)),
                      onTap: () => context.push(GroupDetailPage.pathFor(g.id)),
                    );
                  },
                ),
        );
  }
}
```

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection_keys.dart';
import '../../../core/models/group_record.dart';
import 'groups_list_page.dart';

/// Skapa ELLER redigera en grupp. Med groupId → redigeringsläge.
class CreateGroupPage extends CompositionWidget {
  const CreateGroupPage({super.key, this.groupId});

  final String? groupId;

  static const path = '${GroupsListPage.path}/new';
  static const editPath = '${GroupsListPage.path}/:id/edit';
  static String editPathFor(String id) => '${GroupsListPage.path}/$id/edit';

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final store = inject(groupsStoreKey);
    final context = useContext();

    final (nameController, name, _) = useTextEditingController();
    final (descController, description, _) = useTextEditingController();
    final visibility = ref(GroupVisibility.public);
    final touched = ref(false);

    final pageTitle = computed(
      () => props.value.groupId == null ? 'Ny grupp' : 'Redigera grupp',
    );
    final nameError = computed(
      () => name.value.trim().length < 3 ? 'Minst 3 tecken' : null,
    );
    final visibleNameError =
        computed(() => touched.value ? nameError.value : null);
    final visibilityHelp = computed(() => switch (visibility.value) {
          GroupVisibility.public => 'Alla kan se gruppen och gå med',
          GroupVisibility.private =>
            'Bara medlemmar ser gruppen. En admin lägger till nya',
        });
    final canSave = computed(() => !store.saving.value);

    onMounted(() async {
      final id = props.value.groupId;
      if (id == null) return;
      try {
        final g = await store.fetchGroup(id);
        name.value = g.name;
        description.value = g.description;
        visibility.value = g.visibility;
      } catch (_) {
        // Sidan visar tomt formulär; sparningen misslyckas i så fall.
      }
    });

    Future<void> save() async {
      touched.value = true;
      if (nameError.value != null) return;
      final ok = await store.saveGroup(
        id: props.value.groupId,
        name: name.value.trim(),
        description: description.value.trim(),
        visibility: visibility.value,
      );
      final ctx = context.value;
      if (ctx == null || !ctx.mounted) return;
      if (ok) {
        ctx.pop(true);
      } else {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Kunde inte spara gruppen')),
        );
      }
    }

    return (context) => Scaffold(
          appBar: AppBar(title: Text(pageTitle.value)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Namn',
                  errorText: visibleNameError.value,
                ),
              ),
              TextField(
                controller: descController,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Beskrivning'),
              ),
              const SizedBox(height: 16),
              SegmentedButton<GroupVisibility>(
                segments: const [
                  ButtonSegment(
                    value: GroupVisibility.public,
                    icon: Icon(Icons.public),
                    label: Text('Publik'),
                  ),
                  ButtonSegment(
                    value: GroupVisibility.private,
                    icon: Icon(Icons.lock),
                    label: Text('Privat'),
                  ),
                ],
                selected: {visibility.value},
                onSelectionChanged: (s) => visibility.value = s.first,
              ),
              const SizedBox(height: 8),
              Text(visibilityHelp.value),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: canSave.value ? save : null,
                child: const Text('Spara'),
              ),
            ],
          ),
        );
  }
}
```

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

import '../../../core/di/injection_keys.dart';
import '../../../core/models/group_record.dart';
import '../../../core/utils/permissions.dart';
import '../../../shared/widgets/entity_action_menu.dart';
import 'groups_list_page.dart';

class GroupMembersPage extends CompositionWidget {
  const GroupMembersPage({super.key, required this.groupId});

  final String groupId;

  static const path = '${GroupsListPage.path}/:id/members';
  static String pathFor(String id) => '${GroupsListPage.path}/$id/members';

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final store = inject(groupsStoreKey);
    final auth = inject(authStoreKey);
    final context = useContext();

    final (status, refresh) = useAsyncData<List<GroupMemberRecord>, String>(
      store.fetchMembers,
      watch: () => props.value.groupId,
    );

    final canManage = computed(
      () => store.hasPermission(props.value.groupId, GroupAction.manageMembers),
    );
    final myId = computed(() => auth.user.value?.id);
    final title = computed(() => switch (status.value) {
          AsyncData(:final value) => 'Medlemmar (${value.length})',
          _ => 'Medlemmar',
        });

    void snack(String text) {
      final ctx = context.value;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(text)));
      }
    }

    Future<void> setRole(GroupMemberRecord m, GroupRole role) async {
      if (await store.setRole(m.id, role)) {
        refresh();
      } else {
        snack('Kunde inte ändra rollen');
      }
    }

    Future<void> remove(GroupMemberRecord m) async {
      if (await store.removeMember(m.id)) {
        refresh();
      } else {
        snack('Kunde inte ta bort ${m.userName}');
      }
    }

    return (context) => Scaffold(
          appBar: AppBar(title: Text(title.value)),
          body: switch (status.value) {
            AsyncIdle() ||
            AsyncLoading() =>
              const Center(child: CircularProgressIndicator()),
            AsyncError(:final errorValue) => Center(child: Text('$errorValue')),
            AsyncData(:final value) => ListView(
                children: [
                  for (final m in value)
                    ListTile(
                      title: Text(m.userName),
                      // Admin ser en rollväljare, andra ser bara rollen.
                      subtitle: canManage.value && m.user != myId.value
                          ? DropdownButton<GroupRole>(
                              value: m.role,
                              items: [
                                for (final r in GroupRole.values)
                                  DropdownMenuItem(
                                      value: r, child: Text(r.name)),
                              ],
                              onChanged: (r) =>
                                  r == null ? null : setRole(m, r),
                            )
                          : Text(m.role.name),
                      trailing: EntityActionMenu(actions: [
                        if (canManage.value && m.user != myId.value)
                          EntityAction.delete(
                            () => remove(m),
                            label: 'Ta bort ur gruppen',
                            confirmMessage: 'Ta bort ${m.userName} ur gruppen?',
                          ),
                      ]),
                    ),
                ],
              ),
          },
        );
  }
}
```

</details>

---

## Tester

En ren funktion:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kvittra/core/utils/permissions.dart';

void main() {
  test('member får skriva men inte radera andras inlägg', () {
    expect(roleAllows(GroupRole.member, GroupAction.createPost), isTrue);
    expect(
        roleAllows(GroupRole.member, GroupAction.deleteOthersPosts), isFalse);
  });

  test('moderator får radera andras inlägg men inte hantera medlemmar', () {
    expect(
        roleAllows(GroupRole.moderator, GroupAction.deleteOthersPosts), isTrue);
    expect(roleAllows(GroupRole.moderator, GroupAction.manageMembers), isFalse);
  });

  test('den som inte är medlem får ingenting', () {
    for (final action in GroupAction.values) {
      expect(roleAllows(null, action), isFalse);
    }
  });
}
```

Ett widget-test med riktiga stores och fejkad inloggning. `pb.authStore.save` loggar in
utan nätverk. Token måste vara en JWT med `exp` i framtiden för att `isValid` ska bli
sant.

```dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart' hide AuthStore;
import 'package:kvittra/core/di/injection_keys.dart';
import 'package:kvittra/core/models/post_record.dart';
import 'package:kvittra/core/utils/permissions.dart';
import 'package:kvittra/features/auth/auth_store.dart';
import 'package:kvittra/features/feed/feed_store.dart';
import 'package:kvittra/features/groups/groups_store.dart';
import 'package:kvittra/features/posts/posts_store.dart';
import 'package:kvittra/features/posts/widgets/post_card.dart';

/// En JWT med `exp` långt fram i tiden, så att authStore.isValid blir sant.
String fakeJwt() {
  String b64(Map<String, Object> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${b64({'alg': 'HS256'})}.${b64({'exp': 4102444800})}.sig';
}

/// "Loggar in" som Anna utan nätverk.
PocketBase pbAsAnna() {
  final pb = PocketBase('http://127.0.0.1:8090');
  pb.authStore.save(
    fakeJwt(),
    RecordModel({'id': 'anna', 'username': 'anna', 'name': 'Anna'}),
  );
  return pb;
}

PostRecord post({required String author, String group = ''}) => PostRecord(
      id: 'p1',
      title: 'Hej Kvittra',
      body: 'Mitt första inlägg',
      author: author,
      authorName: author == 'anna' ? 'Anna' : 'Bo',
      group: group,
      groupName: group.isEmpty ? '' : 'Flutter',
      likeCount: 1,
      likedByMe: false,
      created: DateTime.now(),
    );

void main() {
  late AuthStore auth;
  late GroupsStore groups;

  Future<void> pumpCard(WidgetTester tester, PostRecord p) async {
    final pb = pbAsAnna();
    auth = AuthStore(pb);
    final feed = FeedStore(pb, auth);
    groups = GroupsStore(pb, auth);
    await tester.pumpWidget(CompositionBuilder(setup: () {
      provide(authStoreKey, auth);
      provide(feedStoreKey, feed);
      provide(groupsStoreKey, groups);
      provide(postsStoreKey, PostsStore(pb, auth, feed));
      return (context) => MaterialApp(home: Scaffold(body: PostCard(post: p)));
    }));
  }

  testWidgets('mitt eget inlägg: redigera och radera', (tester) async {
    await pumpCard(tester, post(author: 'anna'));
    expect(find.text('1 gillning'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Redigera'), findsOneWidget);
    expect(find.text('Radera'), findsOneWidget);
  });

  testWidgets('någon annans inlägg utanför grupp: ingen meny', (tester) async {
    await pumpCard(tester, post(author: 'bo'));
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets('moderator i gruppen får radera, men inte redigera',
      (tester) async {
    await pumpCard(tester, post(author: 'bo', group: 'g1'));
    expect(find.byIcon(Icons.more_vert), findsNothing);

    // Rollerna är refs i store:n: ändras de byggs kortet om av sig självt.
    groups.debugSetRoles({'g1': GroupRole.moderator});
    await tester.pump();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Redigera'), findsNothing);
    expect(find.text('Radera'), findsOneWidget);
  });
}
```

Testet verifierar tre saker: att `provide`/`inject` fungerar, att åtgärdsmenyn bara
visar tillåtna val, och att UI:t reagerar när rollen i store:n ändras.

---

## Fördjupning: rollmatris på servern

API-reglerna ovan räknar upp rollerna (`role ?= "admin" || role ?= "moderator"`) i
varje regel. Vill du ha matrisen på **ett** ställe även på servern kan en hook göra
kontrollen, med samma matris som `permissions.dart`. Lätta då på raderingsreglerna och
låt hooken avgöra.

💡 **Tips:** Operationerna heter exakt som Dart-enumen `GroupAction`
(`deleteOthersPosts`, `manageMembers` …), så att appen och servern delar samma namn.
Ha bara **en** rollmatris på servern.

<details>
<summary>▶ Visa <code>pb_hooks/group_permissions.js</code>, <code>group_permissions.pb.js</code> och migrationen</summary>

```js
// Samma rollmatris som lib/core/utils/permissions.dart i appen.
const GROUP_PERMISSIONS = {
  admin: ["createPost", "comment", "deleteOthersPosts", "editGroup", "manageMembers", "deleteGroup"],
  moderator: ["createPost", "comment", "deleteOthersPosts"],
  member: ["createPost", "comment"],
}

/** Min roll i gruppen, eller null om jag inte är medlem. */
function roleIn(app, groupId, userId) {
  if (!groupId || !userId) return null
  try {
    const m = app.findFirstRecordByFilter(
      "group_members",
      "group = {:g} && user = {:u}",
      { g: groupId, u: userId },
    )
    return m.getString("role")
  } catch (_) {
    return null // ingen rad = inte medlem
  }
}

module.exports = {
  /** Kastar ForbiddenError om min roll i gruppen saknar rätt till action. */
  enforce: (e, groupId, action) => {
    if (e.hasSuperuserAuth()) return
    if (!e.auth) throw new UnauthorizedError("Logga in först.")
    const role = roleIn(e.app, groupId, e.auth.id)
    const allowed = (role && GROUP_PERMISSIONS[role]) || []
    if (allowed.indexOf(action) === -1) {
      throw new ForbiddenError("Din roll i gruppen saknar behörighet för detta.")
    }
  },
}
```

```js
/// <reference path="../pb_data/types.d.ts" />

// Radera ett inlägg: egna går alltid, andras kräver deleteOthersPosts i gruppen.
onRecordDeleteRequest((e) => {
  const post = e.record
  if (!e.auth || post.getString("author") !== e.auth.id) {
    require(`${__hooks}/group_permissions.js`)
      .enforce(e, post.getString("group"), "deleteOthersPosts")
  }
  e.next()
}, "posts")

// Radera en kommentar: egen, eller på mitt eget inlägg, eller som moderator.
onRecordDeleteRequest((e) => {
  const post = e.app.findRecordById("posts", e.record.getString("post"))
  const me = e.auth ? e.auth.id : ""
  if (e.record.getString("author") !== me && post.getString("author") !== me) {
    require(`${__hooks}/group_permissions.js`)
      .enforce(e, post.getString("group"), "deleteOthersPosts")
  }
  e.next()
}, "comments")
```

```js
/// <reference path="../pb_data/types.d.ts" />

// Raderingsreglerna blir enkla: rollkontrollen sköts av group_permissions.pb.js.
migrate((app) => {
  for (const name of ["posts", "comments"]) {
    const c = app.findCollectionByNameOrId(name)
    c.deleteRule = '@request.auth.id != ""'
    app.save(c)
  }
}, (app) => {
  const mod = (x) =>
    `(@collection.group_members.group ?= ${x} && @collection.group_members.user ?= @request.auth.id && ` +
    `(@collection.group_members.role ?= "admin" || @collection.group_members.role ?= "moderator"))`
  const posts = app.findCollectionByNameOrId("posts")
  posts.deleteRule = `author = @request.auth.id || (group != "" && ${mod("group")})`
  app.save(posts)
  const comments = app.findCollectionByNameOrId("comments")
  comments.deleteRule = `author = @request.auth.id || post.author = @request.auth.id || (post.group != "" && ${mod("post.group")})`
  app.save(comments)
})
```

</details>

Provkört: en `member` som raderar någon annans kommentar eller gruppinlägg får
`403 Din roll i gruppen saknar behörighet för detta.` När admin gjort personen till
`moderator` lyckas samma anrop (`204`). Egna inlägg och kommentarer på egna inlägg går
alltid att radera.

> ⚠️ **Varning:** Hookar körs i en isolerad kontext. Funktioner och variabler som
> deklareras utanför en hook-callback syns inte inuti den. Lägg delad kod i en egen
> fil och hämta den med `require(`${__hooks}/…`)` *inuti* callbacken, som ovan.

---

## Så bygger du nästa feature

1. **Backend:** en collection med relationer, API-regler (vem ser, skapar, ändrar,
   raderar?) och vid behov en hook som stämplar serverfält. Testa med `curl` som "fel"
   användare.
2. **Modell:** `XxxRecord.fromJson` och namnet i `Collections`.
3. **Store:** `Paginated<XxxRecord>` för listan, `fetchXxx(id)`, `saveXxx({id, …})` och
   `deleteXxx(id)` som returnerar `Future<bool>`, plus en `saving`-ref. Realtime i
   store:n om datan ska uppdateras av sig själv.
4. **DI:** `InjectionKey` i `injection_keys.dart`, skapa och `provide` i `MyApp`. Ska
   store:n starta något vid inloggning? Lägg det i `watch` på användarens id.
5. **Sidor:** lista (`PaginatedListView`, FAB med behörighet), detalj (hämta via id,
   `EntityActionMenu`) och skapa/redigera (samma sida, `pop(true)` efter sparning).
6. **Router:** routes med `static const path`, med `new` före `:id`.
7. **Behörighet:** behövs en ny `GroupAction`? Lägg till den i matrisen **och** i
   reglerna på servern.
8. **Test:** minst ett widget-test med `provide`.

Prova själv i [övning 3.4](ovningar.md#övning-34--ny-feature-notiser).

## Sammanfattning

- **Feature-first** med en store per domän. Stores exponerar `ReadonlyRef` och
  `computed` och har async-metoder som returnerar `Future<bool>`.
- Alla stores skapas och `provide`:as i `MyApp`. Sidor gör `inject`. Routern får
  `AuthStore` som argument (eller via en global accessor), eftersom `redirect` körs
  utanför `setup()`.
- `Paginated<T>` + `PaginatedListView` för långa listor och det oändliga flödet, och
  `EntityActionMenu` för åtgärder.
- Optimistiska uppdateringar (gilla, följa) i composables eller sidor, med
  serveranropet i en store som returnerar `false` vid fel.
- Realtime i en store med skydd mot race-fall, startad i `onMounted` och stoppad i
  `onUnmounted` som registrerats direkt i `setup()`.
- Roller per grupp: `hasPermission` i UI:t, API-regler (och valfritt en hook) på
  servern. Säkerheten ligger alltid på servern.

# 9. Arkitektur för en riktig app

Kapitel 1–8 visade byggstenarna. Det här kapitlet visar hur de passar ihop i en app
av produktionskaraktär för en bostadsrättsförening: inloggning som överlever omstart,
roller, flera föreningar i samma backend, sidindelade listor, åtgärdsmenyer, en router
med auth-guard och data i realtid.

Mönstren här är samma som i riktiga föreningsappar. Förstår du dem kan du bygga nya
funktioner (felanmälan, dokumentarkiv, styrelseprotokoll …) på egen hand, och det är
precis vad [övning 3.4](ovningar.md#övning-34--ny-feature-felanmälan) går ut på.

All Dart-kod i kapitlet är analyserad med `dart analyze` mot `flutter_compositions`
0.1.1, `pocketbase` 0.23 och `go_router` 17. Serverkoden (JavaScript) är provkörd mot
PocketBase.

> 💡 **Tips:** Kapitlet är långt och kodtungt. Läs först texten och tabellerna för att
> förstå *varför*, och fäll sedan ut koden (`▶ Visa koden`) när du bygger själv.

## Översikt

```
/login ──► /  (dashboard: rutnät med de funktioner rollen har tillgång till)
            ├── /posts                 Anslag (sidindelad lista, fästa först)
            │     ├── /posts/new       Nytt anslag
            │     ├── /posts/:id       Anslag + kommentarer i realtid
            │     └── /posts/:id/edit  Redigera (samma sida som "ny")
            ├── /resources             Bokningsbara lokaler
            │     └── /resources/:id/book   Boka: datum, längd, lediga tider
            ├── /my-bookings           Mina kommande bokningar
            └── /members               Medlemslista med sök (admin)
```

| Roll (`users.role`) | Får |
|---------------------|-----|
| `member` | Läsa anslag, kommentera, boka, se och avboka egna bokningar |
| `styrelse` | Som member, plus skapa och redigera anslag |
| `admin` | Allt, plus radera anslag, se medlemmar och ändra roller |

### Mappstruktur: feature-first

```
lib/
├── main.dart                          # MyApp: skapar stores, provide, router
├── core/
│   ├── di/injection_keys.dart         # en InjectionKey per store + pocketBaseKey
│   ├── pocketbase/pocketbase_client.dart
│   ├── models/                        # Collections + XxxRecord.fromJson
│   ├── pagination/paginated.dart      # Paginated<T>, PageResult<T>
│   ├── router/{router.dart, auth_guard.dart}
│   └── utils/permissions.dart
├── features/
│   ├── auth/{auth_store.dart, pages/login_page.dart}
│   ├── dashboard/pages/dashboard_page.dart
│   ├── posts/{posts_store.dart, pages/…}
│   ├── bookings/{bookings_store.dart, composables/use_booking_form.dart, pages/…}
│   └── members/{members_store.dart, pages/…}
└── shared/widgets/{paginated_list_view, entity_action_menu, confirm_dialog}.dart
```

Varje **feature** har en *store* och en `pages/`-mapp med (oftast) tre sidor:
`x_list_page`, `x_detail_page` och `create_x_page`. Den sista hanterar **både skapa och
redigera**: får sidan ett id är den i redigeringsläge.

### De fem mönstren

| Mönster | Vad | Kapitel i modulen |
|---------|-----|-------------------|
| **Store per feature** | Vanlig Dart-klass med privata `ref`s, publika `ReadonlyRef`-getters, `computed` och async-metoder som returnerar `Future<bool>` | 2, 6 |
| **Provide i roten** | `MyApp.setup()` skapar alla stores en gång och `provide`:ar dem. Sidor gör `inject` | 6 |
| **`Paginated<T>` + `PaginatedListView`** | Sidindelade listor med oändlig scroll och pull-to-refresh | 5, 7 |
| **`EntityActionMenu`** | Redigera/radera via en `more_vert`-meny med bekräftelse, i stället för lösa knappar | – |
| **Auth-guard + rollkontroll** | `redirect` i go_router och `hasPermission(meny, op)` i UI:t, som speglar regler och hooks på servern | 6 |

---

## Backend i korthet

Datamodellen från kursens README utökas med **föreningar** (multi-tenancy). Allt
bygger på collections, regler och hooks från [modul 02](../02-pocketbase/README.md),
inklusive dubbelbokningshooken i
[02 – Hooks och migrationer](../02-pocketbase/07-hooks-och-migrationer.md).

| Collection | Tillägg |
|------------|---------|
| `associations` | **Ny.** `name`, `org_number`, `permissions` (json) |
| `users` | `association` (relation), `role` (`member`/`styrelse`/`admin`, från modul 02) |
| `resources` | `association`, `requires_approval` (bool) |
| `bookings` | `association`, `approval_status` (`pending`/`approved`/`rejected`) |
| `posts` | `association`, `pinned` (bool) |
| `post_comments` | **Ny.** `post` (cascade delete), `author`, `body`, `association`, `created`/`updated` |

Grundregeln för all data är:

```
@request.auth.id != "" && association = @request.auth.association
```

| Vad | Var |
|-----|-----|
| Se bara den egna föreningens data | API-regel (ovan) |
| Skriva bara i eget namn | API-regel: `@request.body.user = @request.auth.id` |
| Ingen dubbelbokning, `max_hours` | Hook `onRecordValidate` (modul 02) |
| `association` och `approval_status` sätts av servern | Hook `onRecordCreateRequest` (nedan) |
| Rollmatris (vem får skapa/ändra/radera) | Appen döljer knappar, och regel eller hook stoppar anropet |

<details>
<summary>▶ Visa migrationen <code>pb_migrations/1700000100_foreningar.js</code></summary>

```js
/// <reference path="../pb_data/types.d.ts" />

// Föreningar (multi-tenancy), fästa anslag, kommentarer och
// godkännandestatus på bokningar.
migrate((app) => {
  // 1. Ny collection: associations
  const associations = new Collection({
    type: "base",
    name: "associations",
    fields: [
      { name: "name", type: "text", required: true },
      { name: "org_number", type: "text" },
      { name: "permissions", type: "json" },
    ],
    // Man ser bara sin egen förening
    listRule: 'id = @request.auth.association',
    viewRule: 'id = @request.auth.association',
    updateRule: '@request.auth.role = "admin" && id = @request.auth.association',
  })
  app.save(associations)

  // 2. association-relation på users och på allt innehåll
  for (const name of ["users", "resources", "bookings", "posts"]) {
    const c = app.findCollectionByNameOrId(name)
    c.fields.add(new RelationField({
      name: "association",
      collectionId: associations.id,
      maxSelect: 1,
    }))
    app.save(c)
  }

  // 3. Nya fält
  const posts = app.findCollectionByNameOrId("posts")
  posts.fields.add(new BoolField({ name: "pinned" }))
  app.save(posts)

  const resources = app.findCollectionByNameOrId("resources")
  resources.fields.add(new BoolField({ name: "requires_approval" }))
  app.save(resources)

  const bookings = app.findCollectionByNameOrId("bookings")
  bookings.fields.add(new SelectField({
    name: "approval_status",
    values: ["pending", "approved", "rejected"],
    maxSelect: 1,
  }))
  app.save(bookings)

  // 4. Ny collection: post_comments
  const users = app.findCollectionByNameOrId("users")
  const comments = new Collection({
    type: "base",
    name: "post_comments",
    fields: [
      { name: "post", type: "relation", collectionId: posts.id, maxSelect: 1, required: true, cascadeDelete: true },
      { name: "author", type: "relation", collectionId: users.id, maxSelect: 1, required: true },
      { name: "body", type: "text", required: true, max: 1000 },
      { name: "association", type: "relation", collectionId: associations.id, maxSelect: 1 },
      { name: "created", type: "autodate", onCreate: true },
      { name: "updated", type: "autodate", onCreate: true, onUpdate: true },
    ],
    listRule: '@request.auth.id != "" && association = @request.auth.association',
    viewRule: '@request.auth.id != "" && association = @request.auth.association',
    createRule: '@request.auth.id != "" && @request.body.author = @request.auth.id && @request.body.post.association = @request.auth.association',
    updateRule: 'author = @request.auth.id && @request.body.author:changed = false',
    deleteRule: 'author = @request.auth.id || (@request.auth.role = "admin" && association = @request.auth.association)',
  })
  app.save(comments)
}, (app) => {
  // Ned-migrering: ta bort i omvänd ordning
  app.delete(app.findCollectionByNameOrId("post_comments"))
  for (const [name, field] of [["bookings", "approval_status"], ["resources", "requires_approval"], ["posts", "pinned"]]) {
    const c = app.findCollectionByNameOrId(name)
    c.fields.removeByName(field)
    app.save(c)
  }
  for (const name of ["users", "resources", "bookings", "posts"]) {
    const c = app.findCollectionByNameOrId(name)
    c.fields.removeByName("association")
    app.save(c)
  }
  app.delete(app.findCollectionByNameOrId("associations"))
})
```

</details>

<details>
<summary>▶ Visa API-reglerna <code>pb_migrations/1700000200_rules.js</code></summary>

```js
/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const tenant = '@request.auth.id != "" && association = @request.auth.association'
  const rules = {
    resources: {
      listRule: tenant,
      viewRule: tenant,
      createRule: '@request.auth.role = "admin"',
      updateRule: '@request.auth.role = "admin" && association = @request.auth.association',
      deleteRule: '@request.auth.role = "admin" && association = @request.auth.association',
    },
    bookings: {
      listRule: tenant + ' && (user = @request.auth.id || @request.auth.role = "styrelse" || @request.auth.role = "admin")',
      viewRule: tenant + ' && (user = @request.auth.id || @request.auth.role = "styrelse" || @request.auth.role = "admin")',
      createRule: '@request.auth.id != "" && @request.body.user = @request.auth.id && @request.body.resource.active = true && @request.body.resource.association = @request.auth.association',
      updateRule: 'user = @request.auth.id && @request.body.user:changed = false',
      deleteRule: 'user = @request.auth.id || (@request.auth.role = "admin" && association = @request.auth.association)',
    },
    posts: {
      listRule: tenant + ' && (published = true || author = @request.auth.id)',
      viewRule: tenant + ' && (published = true || author = @request.auth.id)',
      createRule: '(@request.auth.role = "styrelse" || @request.auth.role = "admin") && @request.body.author = @request.auth.id',
      updateRule: 'association = @request.auth.association && (author = @request.auth.id || @request.auth.role = "admin") && @request.body.author:changed = false',
      deleteRule: 'association = @request.auth.association && (author = @request.auth.id || @request.auth.role = "admin")',
    },
    users: {
      listRule: tenant,
      viewRule: 'id = @request.auth.id || (' + tenant + ')',
      // Egen profil (utan roll/lägenhet/förening) ELLER admin i samma förening
      updateRule:
        '(id = @request.auth.id && @request.body.role:isset = false && ' +
        '@request.body.apartment:isset = false && @request.body.association:isset = false) || ' +
        '(@request.auth.role = "admin" && association = @request.auth.association && ' +
        '@request.body.association:isset = false)',
    },
  }
  for (const [name, r] of Object.entries(rules)) {
    const c = app.findCollectionByNameOrId(name)
    Object.assign(c, r)
    app.save(c)
  }
})
```

</details>

Fält som klienten **inte** får välja stämplas av servern. `pb_hooks/tenant.pb.js`:

```js
/// <reference path="../pb_data/types.d.ts" />

// Fält som klienten INTE får välja stämplas av servern.
onRecordCreateRequest((e) => {
  if (!e.hasSuperuserAuth()) {
    if (!e.auth) throw new UnauthorizedError("Logga in först.");
    e.record.set("association", e.auth.getString("association"));
  }
  e.next();
}, "posts", "post_comments", "bookings");

onRecordCreateRequest((e) => {
  if (!e.hasSuperuserAuth()) {
    const resource = e.app.findRecordById("resources", e.record.getString("resource"));
    e.record.set("approval_status", resource.getBool("requires_approval") ? "pending" : "approved");
  }
  e.next();
}, "bookings");

// Association och status får inte ändras av vanliga användare i efterhand.
onRecordUpdateRequest((e) => {
  if (!e.hasSuperuserAuth()) {
    const original = e.record.original();
    e.record.set("association", original.getString("association"));
    if (e.collection.name === "bookings") {
      e.record.set("approval_status", original.getString("approval_status"));
    }
  }
  e.next();
}, "posts", "post_comments", "bookings");
```

Provkört med `curl`:

| Försök | Resultat |
|--------|----------|
| Anna bokar och skickar `"approval_status": "rejected"` och fel förening | Sparas med Annas förening och `approved` |
| Anna bokar en överlappande tid | `400 Tiden är redan bokad.` |
| Anna bokar festlokalen (`requires_approval`) | Sparas som `pending` |
| Cecilia (förening B) bokar förening A:s tvättstuga | `400` (create-regeln följer `@request.body.resource.association`) |
| Cecilia listar förening A:s anslag och resurser | 0 träffar |
| Anna (member) skapar ett anslag | `400` (create-regeln kräver styrelse/admin) |
| Anna gör sig själv till admin | `404` (update-regeln på `users`) |

---

## PocketBase-klient, DI och appens rot

Projektet skapas med `flutter create foreningsappen` (därav `package:foreningsappen/…` i
testerna) och behöver paketen `flutter_compositions`, `pocketbase`, `go_router` och
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
import '../../features/bookings/bookings_store.dart';
import '../../features/members/members_store.dart';
import '../../features/posts/posts_store.dart';

const pocketBaseKey = InjectionKey<PocketBase>('pocketBase');
const authStoreKey = InjectionKey<AuthStore>('authStore');
const postsStoreKey = InjectionKey<PostsStore>('postsStore');
const bookingsStoreKey = InjectionKey<BookingsStore>('bookingsStore');
const membersStoreKey = InjectionKey<MembersStore>('membersStore');

// go_router:s redirect körs UTANFÖR composition-scope (inte i någon setup()),
// så där fungerar inte inject(). Därför sparar vi även en global referens.
AuthStore? _globalAuthStore;
void setGlobalAuthStore(AuthStore store) => _globalAuthStore = store;
AuthStore? getGlobalAuthStore() => _globalAuthStore;
```

> ⚠️ **Varning:** Paketet `pocketbase` har redan en klass `AuthStore`
> (`pb.authStore`). Importera därför med `show PocketBase` eller `hide AuthStore` där
> båda behövs.

**Varför en global accessor?** `inject` fungerar bara i `setup()`. go_router:s
`redirect` körs av routern vid varje navigering, utanför alla `setup()`. Därför sparas
`AuthStore` även i en global variabel som routern kan läsa. Alternativet är att skapa
routern i `MyApp.setup()` med `createRouter(authStore)`. Det viktiga är att **sidorna**
fortfarande använder `inject`. Accessorn är ett undantag för routern.

### `main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

import 'core/di/injection_keys.dart';
import 'core/pocketbase/pocketbase_client.dart';
import 'core/router/router.dart';
import 'features/auth/auth_store.dart';
import 'features/bookings/bookings_store.dart';
import 'features/members/members_store.dart';
import 'features/posts/posts_store.dart';

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
    final postsStore = PostsStore(pb, authStore);
    final bookingsStore = BookingsStore(pb, authStore);
    final membersStore = MembersStore(pb);

    provide(pocketBaseKey, pb);
    provide(authStoreKey, authStore);
    provide(postsStoreKey, postsStore);
    provide(bookingsStoreKey, bookingsStore);
    provide(membersStoreKey, membersStore);

    // Routerns redirect körs utanför setup() och kan inte använda inject().
    setGlobalAuthStore(authStore);

    // Vid in-/utloggning: kör om redirect och ladda föreningens data.
    watch(() => authStore.isAuthenticated.value, (loggedIn, _) {
      router.refresh();
    });
    watchEffect(() {
      if (authStore.user.value != null) authStore.loadAssociation();
    });

    return (context) => MaterialApp.router(
          title: 'Föreningsappen',
          theme: ThemeData(colorSchemeSeed: Colors.teal),
          darkTheme: ThemeData(
            colorSchemeSeed: Colors.teal,
            brightness: Brightness.dark,
          ),
          routerConfig: router,
        );
  }
}
```

- Alla stores skapas **en gång** och delas med `provide`.
- `watch` på `isAuthenticated` anropar `router.refresh()`, så att guarden körs direkt vid
  in- och utloggning.
- `watchEffect` laddar föreningens data när en användare finns.

---

## Modeller

```dart
/// Collection-namn samlade på ett ställe, så att stavfel blir kompileringsfel.
abstract final class Collections {
  static const associations = 'associations';
  static const users = 'users';
  static const posts = 'posts';
  static const postComments = 'post_comments';
  static const resources = 'resources';
  static const bookings = 'bookings';
}
```

```dart
enum UserRole { admin, styrelse, member }

class UserRecord {
  const UserRecord({
    required this.id,
    required this.email,
    required this.name,
    required this.association,
    required this.apartment,
    required this.role,
  });

  final String id;
  final String email;
  final String name;
  final String association; // relation = id-sträng
  final String apartment;   // relation = id-sträng
  final UserRole role;

  bool get isAdmin => role == UserRole.admin;

  factory UserRecord.fromJson(Map<String, dynamic> json) => UserRecord(
        id: json['id'] as String,
        email: json['email'] as String? ?? '',
        name: json['name'] as String? ?? '',
        association: json['association'] as String? ?? '',
        apartment: json['apartment'] as String? ?? '',
        role: UserRole.values.asNameMap()[json['role']] ?? UserRole.member,
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
    required this.published,
    required this.pinned,
    required this.created,
  });

  final String id;
  final String title;
  final String body;
  final String author;       // relation-id
  final String authorName;   // från expand.author
  final bool published;
  final bool pinned;
  final DateTime? created;

  factory PostRecord.fromJson(Map<String, dynamic> json) {
    final expand = json['expand'] as Map<String, dynamic>? ?? const {};
    final author = expand['author'] as Map<String, dynamic>?;
    return PostRecord(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      author: json['author'] as String? ?? '',
      authorName: author?['name'] as String? ?? 'Okänd',
      published: json['published'] as bool? ?? false,
      pinned: json['pinned'] as bool? ?? false,
      created: DateTime.tryParse(json['created'] as String? ?? '')?.toLocal(),
    );
  }
}

class PostCommentRecord {
  const PostCommentRecord({
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

  factory PostCommentRecord.fromJson(Map<String, dynamic> json) {
    final expand = json['expand'] as Map<String, dynamic>? ?? const {};
    final author = expand['author'] as Map<String, dynamic>?;
    return PostCommentRecord(
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

<details>
<summary>▶ Visa <code>resource_record.dart</code> (ResourceRecord + BookingRecord)</summary>

```dart
class ResourceRecord {
  const ResourceRecord({
    required this.id,
    required this.name,
    required this.description,
    required this.maxHours,
    required this.active,
  });

  final String id;
  final String name;
  final String description;
  final int maxHours;
  final bool active;

  factory ResourceRecord.fromJson(Map<String, dynamic> json) => ResourceRecord(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        maxHours: (json['max_hours'] as num?)?.toInt() ?? 1,
        active: json['active'] as bool? ?? false,
      );
}

enum ApprovalStatus { pending, approved, rejected }

class BookingRecord {
  const BookingRecord({
    required this.id,
    required this.resource,
    required this.resourceName,
    required this.user,
    required this.start,
    required this.end,
    required this.note,
    required this.approvalStatus,
  });

  final String id;
  final String resource;
  final String resourceName; // från expand.resource
  final String user;
  final DateTime start;
  final DateTime end;
  final String note;
  final ApprovalStatus approvalStatus;

  factory BookingRecord.fromJson(Map<String, dynamic> json) {
    final expand = json['expand'] as Map<String, dynamic>? ?? const {};
    final resource = expand['resource'] as Map<String, dynamic>?;
    return BookingRecord(
      id: json['id'] as String,
      resource: json['resource'] as String? ?? '',
      resourceName: resource?['name'] as String? ?? '–',
      user: json['user'] as String? ?? '',
      // PocketBase lagrar datum i UTC: "2025-03-01 08:00:00.000Z"
      start: DateTime.parse(json['start'] as String).toLocal(),
      end: DateTime.parse(json['end'] as String).toLocal(),
      note: json['note'] as String? ?? '',
      approvalStatus: ApprovalStatus.values.asNameMap()[json['approval_status']] ??
          ApprovalStatus.pending,
    );
  }
}
```

</details>

**Mönstret:**

- `XxxRecord.fromJson(record.toJson())`, så att UI:t aldrig behöver se `RecordModel`.
- **Relationer** är id-strängar. **Expanderad data** (`expand: 'author'`) läses ur
  `json['expand']` till extra fält som `authorName`.
- **Enums** läses med `values.asNameMap()[…] ?? standardvärde`.
- **Datum** görs om med `.toLocal()` vid inläsning och `.toUtc().toIso8601String()` vid
  sparande.
- Collection-namnen ligger i `Collections`, så att ett stavfel blir ett kompileringsfel.

---

## Store-mönstret: `AuthStore`

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart' hide AuthStore;

import '../../core/models/collections.dart';
import '../../core/models/user_record.dart';
import '../../core/utils/permissions.dart';

class AuthStore {
  AuthStore(this._pb) {
    _syncFromPocketBase();
    // authStore.onChange triggas vid inloggning, token-förnyelse och utloggning.
    _pb.authStore.onChange.listen((_) => _syncFromPocketBase());
  }

  final PocketBase _pb;

  final _user = ref<UserRecord?>(null);
  final _permissionOverrides = ref<Map<String, dynamic>?>(null);
  final _loading = ref(false);

  ReadonlyRef<UserRecord?> get user => _user;
  ReadonlyRef<bool> get loading => _loading;

  late final ReadonlyRef<bool> isAuthenticated =
      computed(() => _user.value != null);
  late final ReadonlyRef<bool> isAdmin =
      computed(() => _user.value?.isAdmin ?? false);

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

  void signOut() {
    _pb.authStore.clear();
    _permissionOverrides.value = null;
  }

  /// Hämtar föreningens eventuella behörighetsöverskuggningar.
  Future<void> loadAssociation() async {
    final associationId = _user.value?.association;
    if (associationId == null || associationId.isEmpty) return;
    try {
      final record = await _pb
          .collection(Collections.associations)
          .getOne(associationId);
      final json = record.toJson()['permissions'];
      _permissionOverrides.value = json is Map<String, dynamic> ? json : null;
    } catch (e) {
      debugPrint('AuthStore.loadAssociation: $e');
    }
  }

  /// Används av UI:t för att visa/dölja knappar och menyer. Läser refs, så
  /// anrop i computed eller builder blir reaktiva.
  bool hasPermission(AppMenu menu, PermissionOp op) {
    final user = _user.value;
    if (user == null) return false;
    return resolvePermissions(menu, user.role, _permissionOverrides.value)
        .contains(op);
  }
}
```

| Del | Exempel | Varför |
|-----|---------|--------|
| Privata refs | `final _user = ref<UserRecord?>(null);` | Bara store:n skriver |
| Publika `ReadonlyRef` | `ReadonlyRef<UserRecord?> get user => _user;` | Sidor läser och reagerar |
| `computed` | `isAuthenticated`, `isAdmin` | Härledd, cachad data |
| Async-metoder | `signIn`, `loadAssociation` | All PocketBase-kod samlad |
| Felmeddelanden | `throw e.response['message']` | UI:t visar serverns text |

`hasPermission` är en vanlig metod, men eftersom den läser refs blir den reaktiv när den
anropas i en `computed` eller i builder.

Andra stores (`PostsStore`, `BookingsStore` …) följer samma mönster. Deras
mutationsmetoder returnerar `Future<bool>`, och sidan visar en SnackBar vid `false`.

---

## Router och auth-guard

```dart
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/pages/login_page.dart';
import '../di/injection_keys.dart';

const _authRoutes = {LoginPage.path};

/// Körs av go_router före varje navigering. Returnerar en ny sökväg för att
/// omdirigera, eller null för att släppa igenom.
String? authGuard(BuildContext context, GoRouterState state) {
  final auth = getGlobalAuthStore();
  final loggedIn = auth?.isAuthenticated.raw ?? false;
  final onAuthRoute = _authRoutes.contains(state.matchedLocation);

  if (!loggedIn && !onAuthRoute) return LoginPage.path;
  if (loggedIn && onAuthRoute) return '/';
  return null;
}
```

```dart
import 'package:go_router/go_router.dart';

import '../../features/auth/pages/login_page.dart';
import '../../features/bookings/pages/book_resource_page.dart';
import '../../features/bookings/pages/my_bookings_page.dart';
import '../../features/bookings/pages/resources_list_page.dart';
import '../../features/dashboard/pages/dashboard_page.dart';
import '../../features/members/pages/members_list_page.dart';
import '../../features/posts/pages/create_post_page.dart';
import '../../features/posts/pages/post_detail_page.dart';
import '../../features/posts/pages/posts_list_page.dart';
import 'auth_guard.dart';

final router = GoRouter(
  initialLocation: DashboardPage.path,
  redirect: authGuard,
  routes: [
    GoRoute(path: LoginPage.path, builder: (_, _) => const LoginPage()),
    GoRoute(path: DashboardPage.path, builder: (_, _) => const DashboardPage()),
    GoRoute(path: PostsListPage.path, builder: (_, _) => const PostsListPage()),
    // OBS: '/posts/new' måste stå före '/posts/:id', annars tolkas "new" som ett id.
    GoRoute(path: CreatePostPage.path, builder: (_, _) => const CreatePostPage()),
    GoRoute(
      path: CreatePostPage.editPath,
      builder: (_, state) => CreatePostPage(postId: state.pathParameters['id']),
    ),
    GoRoute(
      path: PostDetailPage.path,
      builder: (_, state) => PostDetailPage(postId: state.pathParameters['id']!),
    ),
    GoRoute(path: ResourcesListPage.path, builder: (_, _) => const ResourcesListPage()),
    GoRoute(
      path: BookResourcePage.path,
      builder: (_, state) => BookResourcePage(resourceId: state.pathParameters['id']!),
    ),
    GoRoute(path: MyBookingsPage.path, builder: (_, _) => const MyBookingsPage()),
    GoRoute(path: MembersListPage.path, builder: (_, _) => const MembersListPage()),
  ],
);
```

- Varje sida har `static const path`, och detaljsidor har `pathFor(id)`.
- `/posts/new` står före `/posts/:id`, annars tolkas `new` som ett id.
- Navigering sker med `context.push(...)`. Efter sparning går man tillbaka med
  `context.pop()`.

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
      () => email.value.contains('@') &&
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
        // Ingen navigering här: routerns redirect skickar oss till '/'.
      } catch (e) {
        error.value = '$e';
      }
    }

    return (context) => Scaffold(
          appBar: AppBar(title: const Text('Föreningsappen')),
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
`MyApp` anropar `router.refresh()`, och guarden skickar användaren till `/`. Utloggning
fungerar likadant åt andra hållet, och ingen sida behöver känna till det.

---

## Behörigheter och dashboard

```dart
import '../models/user_record.dart';

/// Funktioner (menyer) i appen.
enum AppMenu { posts, bookings, members }

/// Operationer som kan tillåtas per roll.
enum PermissionOp { read, create, update, delete }

/// Standardmatris: meny → roll → tillåtna operationer.
/// En förening kan skriva över den via JSON-fältet `associations.permissions`.
const Map<AppMenu, Map<UserRole, Set<PermissionOp>>> defaultPermissions = {
  AppMenu.posts: {
    UserRole.admin: {PermissionOp.read, PermissionOp.create, PermissionOp.update, PermissionOp.delete},
    UserRole.styrelse: {PermissionOp.read, PermissionOp.create, PermissionOp.update},
    UserRole.member: {PermissionOp.read},
  },
  AppMenu.bookings: {
    UserRole.admin: {PermissionOp.read, PermissionOp.create, PermissionOp.update, PermissionOp.delete},
    UserRole.styrelse: {PermissionOp.read, PermissionOp.create},
    UserRole.member: {PermissionOp.read, PermissionOp.create},
  },
  AppMenu.members: {
    UserRole.admin: {PermissionOp.read, PermissionOp.update},
    UserRole.styrelse: {PermissionOp.read},
    UserRole.member: {},
  },
};

/// Läser en eventuell överskuggning från föreningens JSON, t.ex.
/// `{"posts": {"member": ["read", "create"]}}`.
Set<PermissionOp> resolvePermissions(
  AppMenu menu,
  UserRole role,
  Map<String, dynamic>? overrides,
) {
  final menuJson = overrides?[menu.name];
  if (menuJson is Map && menuJson[role.name] is List) {
    final names = (menuJson[role.name] as List).cast<String>();
    return {
      for (final op in PermissionOp.values)
        if (names.contains(op.name)) op,
    };
  }
  return defaultPermissions[menu]?[role] ?? const {};
}
```

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection_keys.dart';
import '../../../core/utils/permissions.dart';
import '../../bookings/pages/my_bookings_page.dart';
import '../../bookings/pages/resources_list_page.dart';
import '../../members/pages/members_list_page.dart';
import '../../posts/pages/posts_list_page.dart';

class _MenuItem {
  const _MenuItem(this.menu, this.label, this.icon, this.path);
  final AppMenu menu;
  final String label;
  final IconData icon;
  final String path;
}

const _allItems = [
  _MenuItem(AppMenu.posts, 'Anslag', Icons.campaign, PostsListPage.path),
  _MenuItem(AppMenu.bookings, 'Boka', Icons.event_available, ResourcesListPage.path),
  _MenuItem(AppMenu.bookings, 'Mina bokningar', Icons.bookmark, MyBookingsPage.path),
  _MenuItem(AppMenu.members, 'Medlemmar', Icons.people, MembersListPage.path),
];

class DashboardPage extends CompositionWidget {
  const DashboardPage({super.key});

  static const path = '/';

  @override
  Widget Function(BuildContext) setup() {
    final auth = inject(authStoreKey);

    // Visa bara de rutor användaren har läsrätt till.
    final items = computed(() => _allItems
        .where((i) => auth.hasPermission(i.menu, PermissionOp.read))
        .toList());
    final greeting = computed(() => 'Hej ${auth.user.value?.name ?? ''}!');

    return (context) => Scaffold(
          appBar: AppBar(
            title: Text(greeting.value),
            actions: [
              IconButton(
                tooltip: 'Logga ut',
                icon: const Icon(Icons.logout),
                onPressed: auth.signOut,
              ),
            ],
          ),
          body: GridView.count(
            crossAxisCount: 2,
            padding: const EdgeInsets.all(16),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              for (final item in items.value)
                Card(
                  child: InkWell(
                    onTap: () => context.push(item.path),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(item.icon, size: 40),
                        const SizedBox(height: 8),
                        Text(item.label),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
  }
}
```

`items` är en `computed` som anropar `hasPermission`, som läser `auth.user.value`.
Loggar man ut blir rutnätet tomt direkt.

> ⚠️ **Varning:** Att dölja en knapp är **UX**, inte säkerhet. API-regler och hooks
> måste stoppa samma sak på servern.

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
}
```

`Paginated<T>` är en vanlig klass, inte en composable. Den kan därför leva i en store
och behålla sin data när sidan stängs och öppnas igen.

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
      final PaginatedListView(:itemBuilder, :itemCount, :onRefresh, :emptyText) =
          props.value;
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

  factory EntityAction.update(VoidCallback onSelected, {String label = 'Redigera'}) =>
      EntityAction(icon: Icons.edit_outlined, label: label, onSelected: onSelected);

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
                style: a.destructive ? const TextStyle(color: Colors.red) : null,
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
  if (canEdit.value) EntityAction.update(() => context.push(editPath)),
  if (canDelete.value) EntityAction.delete(delete),
]),
```

---

## Feature: anslag

### Store

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart' hide AuthStore;

import '../../core/models/collections.dart';
import '../../core/models/post_record.dart';
import '../../core/pagination/paginated.dart';
import '../auth/auth_store.dart';

class PostsStore {
  PostsStore(this._pb, this._auth);

  final PocketBase _pb;
  final AuthStore _auth;

  /// Publicerade anslag, fästa först, nyast överst. API-regeln i PocketBase
  /// ser till att bara den egna föreningens anslag kommer med.
  late final posts = Paginated<PostRecord>((page, perPage) async {
    final res = await _pb.collection(Collections.posts).getList(
          page: page,
          perPage: perPage,
          filter: 'published = true',
          sort: '-pinned,-created',
          expand: 'author',
        );
    return PageResult(
      res.items.map((r) => PostRecord.fromJson(r.toJson())).toList(),
      res.totalPages,
    );
  });

  final _saving = ref(false);
  ReadonlyRef<bool> get saving => _saving;

  Future<PostRecord?> fetchPost(String id) async {
    try {
      final r = await _pb.collection(Collections.posts).getOne(id, expand: 'author');
      return PostRecord.fromJson(r.toJson());
    } catch (e) {
      debugPrint('PostsStore.fetchPost: $e');
      return null;
    }
  }

  /// Skapar (id == null) eller uppdaterar ett anslag.
  Future<bool> savePost({
    String? id,
    required String title,
    required String body,
    required bool published,
    required bool pinned,
  }) async {
    final user = _auth.user.value;
    if (user == null) return false;
    _saving.value = true;
    try {
      final data = {
        'title': title,
        'body': body,
        'published': published,
        'pinned': pinned,
      };
      final col = _pb.collection(Collections.posts);
      if (id == null) {
        // author och association sätts av servern (hook), men vi skickar author
        // ändå så att API-regeln kan kontrollera den.
        await col.create(body: {...data, 'author': user.id});
      } else {
        await col.update(id, body: data);
      }
      await posts.refresh(); // hämta om efter mutation
      return true;
    } catch (e) {
      debugPrint('PostsStore.savePost: $e');
      return false;
    } finally {
      _saving.value = false;
    }
  }

  Future<bool> deletePost(String id) async {
    try {
      await _pb.collection(Collections.posts).delete(id);
      posts.removeWhere((p) => p.id == id);
      return true;
    } catch (e) {
      debugPrint('PostsStore.deletePost: $e');
      return false;
    }
  }

  // ---- Kommentarer (realtime) --------------------------------------------

  final _comments = ref<List<PostCommentRecord>>([]);
  ReadonlyRef<List<PostCommentRecord>> get comments => _comments;
  String? _activePostId;
  UnsubscribeFunc? _commentsUnsub;

  /// Hämtar kommentarer för ett anslag och prenumererar på ändringar.
  Future<void> watchComments(String postId) async {
    await stopWatchingComments();
    _activePostId = postId;
    _comments.value = [];
    try {
      final list = await _pb.collection(Collections.postComments).getFullList(
            filter: _pb.filter('post = {:id}', {'id': postId}),
            sort: 'created',
            expand: 'author',
          );
      if (_activePostId != postId) return; // sidan hann stängas
      _comments.value =
          list.map((r) => PostCommentRecord.fromJson(r.toJson())).toList();

      final unsub = await _pb.collection(Collections.postComments).subscribe(
            '*',
            (e) => _applyCommentEvent(postId, e),
            filter: _pb.filter('post = {:id}', {'id': postId}),
            expand: 'author',
          );
      if (_activePostId != postId) {
        await unsub(); // sidan stängdes medan vi prenumererade
      } else {
        _commentsUnsub = unsub;
      }
    } catch (e) {
      debugPrint('PostsStore.watchComments: $e');
    }
  }

  void _applyCommentEvent(String postId, RecordSubscriptionEvent e) {
    final record = e.record;
    if (record == null || _activePostId != postId) return;
    final c = PostCommentRecord.fromJson(record.toJson());
    final current = _comments.value;
    _comments.value = switch (e.action) {
      'create' => current.any((x) => x.id == c.id) ? current : [...current, c],
      'update' => [for (final x in current) x.id == c.id ? c : x],
      'delete' => current.where((x) => x.id != c.id).toList(),
      _ => current,
    };
  }

  Future<void> stopWatchingComments() async {
    _activePostId = null;
    final unsub = _commentsUnsub;
    _commentsUnsub = null;
    if (unsub != null) await unsub();
  }

  Future<bool> addComment(String postId, String body) async {
    final user = _auth.user.value;
    if (user == null) return false;
    try {
      await _pb.collection(Collections.postComments).create(body: {
        'post': postId,
        'author': user.id,
        'body': body,
      });
      return true; // realtime-händelsen lägger in kommentaren i listan
    } catch (e) {
      debugPrint('PostsStore.addComment: $e');
      return false;
    }
  }
}
```

Två strategier för färsk data:

- **Hämta om efter mutation.** `savePost` anropar `posts.refresh()`, och `deletePost`
  tar bort lokalt. Det räcker för de flesta listor.
- **Realtime** för kommentarer, se nedan.

### Lista

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection_keys.dart';
import '../../../core/utils/permissions.dart';
import '../../../shared/widgets/paginated_list_view.dart';
import 'create_post_page.dart';
import 'post_detail_page.dart';

class PostsListPage extends CompositionWidget {
  const PostsListPage({super.key});

  static const path = '/posts';

  @override
  Widget Function(BuildContext) setup() {
    final store = inject(postsStoreKey);
    final auth = inject(authStoreKey);
    final posts = store.posts;

    final canCreate = computed(
      () => auth.hasPermission(AppMenu.posts, PermissionOp.create),
    );
    final showSpinner = computed(
      () => posts.loading.value && posts.items.value.isEmpty,
    );

    onMounted(posts.refresh);

    return (context) => Scaffold(
          appBar: AppBar(title: const Text('Anslag')),
          floatingActionButton: canCreate.value
              ? FloatingActionButton(
                  onPressed: () => context.push(CreatePostPage.path),
                  child: const Icon(Icons.add),
                )
              : null,
          body: showSpinner.value
              ? const Center(child: CircularProgressIndicator())
              : PaginatedListView(
                  itemCount: posts.items.value.length,
                  hasMore: posts.hasMore.value,
                  loadingMore: posts.loadingMore.value,
                  onLoadMore: posts.loadMore,
                  onRefresh: posts.refresh,
                  emptyText: 'Inga anslag ännu',
                  itemBuilder: (context, i) {
                    final post = posts.items.value[i];
                    return ListTile(
                      leading: post.pinned ? const Icon(Icons.push_pin) : null,
                      title: Text(post.title),
                      subtitle: Text(
                        '${post.authorName} · ${post.body}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => context.push(PostDetailPage.pathFor(post.id)),
                    );
                  },
                ),
        );
  }
}
```

### Kommentarer i realtid

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection_keys.dart';
import '../../../core/models/post_record.dart';
import '../../../core/utils/permissions.dart';
import '../../../shared/widgets/entity_action_menu.dart';
import 'create_post_page.dart';
import 'posts_list_page.dart';

class PostDetailPage extends CompositionWidget {
  const PostDetailPage({super.key, required this.postId});

  final String postId;

  static const path = '${PostsListPage.path}/:id';
  static String pathFor(String id) => '${PostsListPage.path}/$id';

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final store = inject(postsStoreKey);
    final auth = inject(authStoreKey);
    final context = useContext();

    final post = ref<PostRecord?>(null);
    final notFound = ref(false);
    final (commentController, commentText, _) = useTextEditingController();
    final sending = ref(false);

    final canEdit = computed(() =>
        auth.hasPermission(AppMenu.posts, PermissionOp.update) ||
        post.value?.author == auth.user.value?.id);
    final canDelete = computed(
      () => auth.hasPermission(AppMenu.posts, PermissionOp.delete),
    );
    final canSend = computed(
      () => commentText.value.trim().isNotEmpty && !sending.value,
    );

    // Hämta anslaget + starta realtime för kommentarer. Fungerar även vid
    // deep link direkt till /posts/:id, eftersom vi hämtar via id.
    onMounted(() async {
      final id = props.value.postId;
      post.value = await store.fetchPost(id);
      notFound.value = post.value == null;
      await store.watchComments(id);
    });

    // Registrerat direkt i setup(), inte inuti onMounted.
    onUnmounted(store.stopWatchingComments);

    Future<void> send() async {
      sending.value = true;
      final ok = await store.addComment(props.value.postId, commentText.value.trim());
      sending.value = false;
      if (ok) {
        commentText.value = '';
      } else if (context.value?.mounted ?? false) {
        ScaffoldMessenger.of(context.value!).showSnackBar(
          const SnackBar(content: Text('Kunde inte skicka kommentaren')),
        );
      }
    }

    Future<void> delete() async {
      final ok = await store.deletePost(props.value.postId);
      final ctx = context.value;
      if (ctx == null || !ctx.mounted) return;
      if (ok) {
        ctx.pop();
      } else {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Kunde inte radera anslaget')),
        );
      }
    }

    return (context) => Scaffold(
          appBar: AppBar(
            title: Text(post.value?.title ?? 'Anslag'),
            actions: [
              EntityActionMenu(actions: [
                if (canEdit.value)
                  EntityAction.update(
                    () => context.push(CreatePostPage.editPathFor(props.value.postId)),
                  ),
                if (canDelete.value) EntityAction.delete(delete),
              ]),
            ],
          ),
          body: notFound.value
              ? const Center(child: Text('Anslaget finns inte'))
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(post.value?.body ?? ''),
                          const Divider(height: 32),
                          Text('Kommentarer (${store.comments.value.length})'),
                          for (final c in store.comments.value)
                            ListTile(
                              title: Text(c.body),
                              subtitle: Text(c.authorName),
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
                              controller: commentController,
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
                ),
        );
  }
}
```

**Livscykeln i detalj:**

1. `onMounted` hämtar anslaget **via id**, så sidan fungerar även vid direktlänk, och
   startar realtime (`store.watchComments`).
2. `onUnmounted(store.stopWatchingComments)` registreras **direkt i `setup()`**
   ([kapitel 4](04-livscykel-och-props.md): hooks får inte registreras inuti
   `onMounted` i 0.1.1).
3. I store:n skyddar `_activePostId` mot race-fall. Om sidan stängs medan `subscribe`
   pågår avslutas prenumerationen direkt.
4. `subscribe` får ett `filter`, så att servern bara skickar händelser för det här
   anslaget. API-reglerna gäller även för realtime.
5. En skickad kommentar läggs **inte** in manuellt. `create`-händelsen gör det, vilket
   ger samma kodväg för egna och andras kommentarer.

### Skapa och redigera, samma sida

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection_keys.dart';
import 'posts_list_page.dart';

/// Skapa ELLER redigera. Med postId → redigeringsläge.
class CreatePostPage extends CompositionWidget {
  const CreatePostPage({super.key, this.postId});

  final String? postId;

  static const path = '${PostsListPage.path}/new';
  static const editPath = '${PostsListPage.path}/:id/edit';
  static String editPathFor(String id) => '${PostsListPage.path}/$id/edit';

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final store = inject(postsStoreKey);
    final context = useContext();

    final (titleController, title, _) = useTextEditingController();
    final (bodyController, body, _) = useTextEditingController();
    final published = ref(true);
    final pinned = ref(false);
    final loadingExisting = ref(false);

    final isEdit = computed(() => props.value.postId != null);
    final pageTitle = computed(() => isEdit.value ? 'Redigera anslag' : 'Nytt anslag');
    final titleError = computed(
      () => title.value.trim().length < 3 ? 'Minst 3 tecken' : null,
    );
    // Visa inte felet förrän användaren börjat skriva.
    final visibleTitleError = computed(
      () => title.value.isEmpty ? null : titleError.value,
    );
    final canSave = computed(() =>
        titleError.value == null &&
        body.value.trim().isNotEmpty &&
        !store.saving.value &&
        !loadingExisting.value);

    // Förifyll i redigeringsläge (fungerar även vid deep link).
    onMounted(() async {
      final id = props.value.postId;
      if (id == null) return;
      loadingExisting.value = true;
      final existing = await store.fetchPost(id);
      if (existing != null) {
        title.value = existing.title;
        body.value = existing.body;
        published.value = existing.published;
        pinned.value = existing.pinned;
      }
      loadingExisting.value = false;
    });

    Future<void> save() async {
      final ok = await store.savePost(
        id: props.value.postId,
        title: title.value.trim(),
        body: body.value.trim(),
        published: published.value,
        pinned: pinned.value,
      );
      final ctx = context.value;
      if (ctx == null || !ctx.mounted) return;
      if (ok) {
        ctx.pop();
      } else {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Kunde inte spara anslaget')),
        );
      }
    }

    return (context) => Scaffold(
          appBar: AppBar(title: Text(pageTitle.value)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
                maxLines: 10,
                decoration: const InputDecoration(labelText: 'Text'),
              ),
              SwitchListTile(
                title: const Text('Publicerat'),
                value: published.value,
                onChanged: (v) => published.value = v,
              ),
              SwitchListTile(
                title: const Text('Fäst överst'),
                value: pinned.value,
                onChanged: (v) => pinned.value = v,
              ),
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

- `postId == null` betyder ny, annars redigering.
- Förifyllning sker i `onMounted`. Tvåvägsbindningen gör att `title.value = …` räcker.
- `canSave` kombinerar validering med `store.saving` och `loadingExisting`.

---

## Bokningsformulär med lediga tider

Bokningsformuläret visar hur en **composable** och en **store** samarbetar. Store:n
pratar med servern, och composablen äger formulärets state och validering.

<details>
<summary>▶ Visa <code>bookings_store.dart</code></summary>

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart' hide AuthStore;

import '../../core/models/collections.dart';
import '../../core/models/resource_record.dart';
import '../auth/auth_store.dart';

class BookingsStore {
  BookingsStore(this._pb, this._auth);

  final PocketBase _pb;
  final AuthStore _auth;

  final _resources = ref<List<ResourceRecord>>([]);
  final _myBookings = ref<List<BookingRecord>>([]);
  final _loading = ref(false);
  final _saving = ref(false);
  final _lastError = ref<String?>(null);

  ReadonlyRef<List<ResourceRecord>> get resources => _resources;
  ReadonlyRef<List<BookingRecord>> get myBookings => _myBookings;
  ReadonlyRef<bool> get loading => _loading;
  ReadonlyRef<bool> get saving => _saving;

  /// Senaste felmeddelandet från servern (t.ex. från dubbelbokningshooken).
  ReadonlyRef<String?> get lastError => _lastError;

  Future<void> loadResources() async {
    _loading.value = true;
    try {
      final list = await _pb.collection(Collections.resources).getFullList(
            filter: 'active = true',
            sort: 'name',
          );
      _resources.value =
          list.map((r) => ResourceRecord.fromJson(r.toJson())).toList();
    } catch (e) {
      debugPrint('BookingsStore.loadResources: $e');
    } finally {
      _loading.value = false;
    }
  }

  ResourceRecord? resourceById(String id) =>
      _resources.value.where((r) => r.id == id).firstOrNull;

  Future<void> loadMyBookings() async {
    final userId = _auth.user.value?.id;
    if (userId == null) return;
    _loading.value = true;
    try {
      final list = await _pb.collection(Collections.bookings).getFullList(
            filter: _pb.filter('user = {:uid} && end >= @now', {'uid': userId}),
            sort: 'start',
            expand: 'resource',
          );
      _myBookings.value =
          list.map((r) => BookingRecord.fromJson(r.toJson())).toList();
    } catch (e) {
      debugPrint('BookingsStore.loadMyBookings: $e');
    } finally {
      _loading.value = false;
    }
  }

  /// Alla bokningar av en resurs ett visst dygn, för att räkna ut lediga tider.
  Future<List<BookingRecord>> fetchBookingsForDay(
    String resourceId,
    DateTime day,
  ) async {
    final from = DateTime(day.year, day.month, day.day);
    final to = from.add(const Duration(days: 1));
    final list = await _pb.collection(Collections.bookings).getFullList(
          filter: _pb.filter(
            'resource = {:res} && start < {:to} && end > {:from}',
            {
              'res': resourceId,
              'from': from.toUtc().toIso8601String(),
              'to': to.toUtc().toIso8601String(),
            },
          ),
          sort: 'start',
        );
    return list.map((r) => BookingRecord.fromJson(r.toJson())).toList();
  }

  Future<bool> createBooking({
    required String resourceId,
    required DateTime start,
    required DateTime end,
    String note = '',
  }) async {
    final user = _auth.user.value;
    if (user == null) return false;
    _saving.value = true;
    _lastError.value = null;
    try {
      // Vi skickar INTE association eller approval_status. De stämplas av
      // servern (hook), så att en klient inte kan fuska.
      await _pb.collection(Collections.bookings).create(body: {
        'resource': resourceId,
        'user': user.id,
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
        'note': note,
      });
      await loadMyBookings(); // hämta om efter mutation
      return true;
    } on ClientException catch (e) {
      _lastError.value =
          e.response['message']?.toString() ?? 'Kunde inte spara bokningen';
      return false;
    } finally {
      _saving.value = false;
    }
  }

  Future<bool> deleteBooking(String id) async {
    final before = _myBookings.value;
    _myBookings.value = before.where((b) => b.id != id).toList(); // optimistiskt
    try {
      await _pb.collection(Collections.bookings).delete(id);
      return true;
    } catch (e) {
      debugPrint('BookingsStore.deleteBooking: $e');
      _myBookings.value = before; // ångra
      return false;
    }
  }

  void clearError() => _lastError.value = null;
}
```

</details>

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

import '../../../core/di/injection_keys.dart';
import '../../../core/models/resource_record.dart';

/// Öppettider för bokningsbara resurser (timmar, lokal tid).
const openingHour = 7;
const closingHour = 22;

class TimeSlot {
  const TimeSlot(this.hour, {required this.available});
  final int hour;
  final bool available;
  String get label => '${hour.toString().padLeft(2, '0')}:00';
}

class BookingForm {
  BookingForm({
    required this.date,
    required this.startHour,
    required this.hours,
    required this.noteController,
    required this.slots,
    required this.loadingSlots,
    required this.errors,
    required this.canSubmit,
    required this.summary,
    required this.submit,
  });

  final Ref<DateTime> date;
  final Ref<int?> startHour;
  final Ref<int> hours;
  final TextEditingController noteController;
  final ReadonlyRef<List<TimeSlot>> slots;
  final ReadonlyRef<bool> loadingSlots;
  final ReadonlyRef<List<String>> errors;
  final ReadonlyRef<bool> canSubmit;
  final ReadonlyRef<String> summary;
  final Future<bool> Function() submit;
}

BookingForm useBookingForm(ReadonlyRef<ResourceRecord?> resource) {
  final store = inject(bookingsStoreKey);

  final today = DateUtils.dateOnly(DateTime.now());
  final date = ref(today);
  final startHour = ref<int?>(null);
  final hours = ref(1);
  final (noteController, note, _) = useTextEditingController();

  // Hämta dagens bokningar för resursen. Hämtas om när resurs eller datum ändras.
  final (dayStatus, _) = useAsyncData<List<BookingRecord>, (String?, DateTime)>(
    (args) async {
      final (resourceId, day) = args;
      if (resourceId == null) return const [];
      return store.fetchBookingsForDay(resourceId, day);
    },
    watch: () => (resource.value?.id, date.value),
  );
  final loadingSlots = computed(() => dayStatus.value.isLoading);

  bool isFree(int hour, int length, List<BookingRecord> taken) {
    final d = date.value;
    final s = DateTime(d.year, d.month, d.day, hour);
    final e = s.add(Duration(hours: length));
    if (s.isBefore(DateTime.now())) return false;
    if (hour + length > closingHour) return false;
    return !taken.any((b) => b.start.isBefore(e) && b.end.isAfter(s));
  }

  final slots = computed(() {
    final taken = dayStatus.value.dataOrNull ?? const <BookingRecord>[];
    return [
      for (var h = openingHour; h < closingHour; h++)
        TimeSlot(h, available: isFree(h, hours.value, taken)),
    ];
  });

  final start = computed<DateTime?>(() {
    final h = startHour.value;
    final d = date.value;
    return h == null ? null : DateTime(d.year, d.month, d.day, h);
  });
  final end = computed(() => start.value?.add(Duration(hours: hours.value)));

  final errors = computed<List<String>>(() {
    final r = resource.value;
    final h = startHour.value;
    return [
      if (r == null) 'Resursen kunde inte hittas',
      if (h == null) 'Välj en starttid',
      if (h != null && !slots.value.any((s) => s.hour == h && s.available))
        'Vald tid är inte ledig',
      if (r != null && hours.value > r.maxHours)
        '${r.name} kan bokas max ${r.maxHours} h',
      if (note.value.length > 200) 'Anteckningen får vara max 200 tecken',
    ];
  });

  final canSubmit = computed(
    () => errors.value.isEmpty && !store.saving.value && !loadingSlots.value,
  );

  final summary = computed(() {
    final s = start.value;
    final e = end.value;
    if (s == null || e == null) return 'Ingen tid vald';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${s.year}-${two(s.month)}-${two(s.day)} '
        '${two(s.hour)}:00–${two(e.hour)}:00';
  });

  // Byter man datum eller längd nollställs vald tid och gamla serverfel.
  watch(() => (date.value, hours.value), (_, _) {
    startHour.value = null;
    store.clearError();
  });

  Future<bool> submit() async {
    final r = resource.value;
    if (!canSubmit.value || r == null) return false;
    return store.createBooking(
      resourceId: r.id,
      start: start.value!,
      end: end.value!,
      note: note.value.trim(),
    );
  }

  return BookingForm(
    date: date,
    startHour: startHour,
    hours: hours,
    noteController: noteController,
    slots: slots,
    loadingSlots: loadingSlots,
    errors: errors,
    canSubmit: canSubmit,
    summary: summary,
    submit: submit,
  );
}
```

Följ beroendekedjan:

```
resource ─┐
date ─────┼─► useAsyncData (dagens bokningar) ─┐
          │                                    ├─► slots ─┐
hours ────┼────────────────────────────────────┘          ├─► errors ─► canSubmit
startHour ┴─► start ─► end ─► summary                     │
note ─────────────────────────────────────────────────────┘
```

- `useAsyncData` med `watch: () => (resource.value?.id, date.value)` hämtar om dagens
  bokningar vid nytt datum.
- `slots` räknas om när bokningarna **eller** längden ändras.
- `watch` på `(date, hours)` nollställer vald tid. Det är en sidoeffekt, så `watch` är
  rätt verktyg.
- Klienten visar bara lediga tider, men **servern har sista ordet** (två personer kan
  välja samma tid samtidigt). Felet från hooken exponeras som `store.lastError`.

<details>
<summary>▶ Visa sidan <code>book_resource_page.dart</code></summary>

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection_keys.dart';
import '../../../core/models/resource_record.dart';
import '../composables/use_booking_form.dart';
import 'resources_list_page.dart';

class BookResourcePage extends CompositionWidget {
  const BookResourcePage({super.key, required this.resourceId});

  final String resourceId;

  static const path = '${ResourcesListPage.path}/:id/book';
  static String pathFor(String id) => '${ResourcesListPage.path}/$id/book';

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final store = inject(bookingsStoreKey);
    final context = useContext();

    final resource = computed<ResourceRecord?>(
      () => store.resourceById(props.value.resourceId),
    );
    final form = useBookingForm(resource);

    final title = computed(() => 'Boka ${resource.value?.name ?? ''}');
    final dateLabel = computed(() {
      final d = form.date.value;
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    });
    final hourOptions = computed(() => [
          for (var h = 1; h <= (resource.value?.maxHours ?? 1); h++) h,
        ]);
    final submitLabel = computed(() => store.saving.value ? 'Sparar…' : 'Boka');

    // Deep link direkt till sidan: resurserna är kanske inte hämtade än.
    onMounted(() async {
      if (resource.value == null) await store.loadResources();
    });

    Future<void> pickDate() async {
      final ctx = context.value!;
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: ctx,
        firstDate: DateUtils.dateOnly(now),
        lastDate: now.add(const Duration(days: 60)),
        initialDate: form.date.value,
      );
      if (picked != null) form.date.value = picked;
    }

    Future<void> submit() async {
      final ok = await form.submit();
      final ctx = context.value;
      if (ok && ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('Bokat: ${form.summary.value}')),
        );
        ctx.pop();
      }
    }

    return (context) => Scaffold(
          appBar: AppBar(title: Text(title.value)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Datum'),
                subtitle: Text(dateLabel.value),
                onTap: pickDate,
              ),
              DropdownButtonFormField<int>(
                initialValue: form.hours.value,
                decoration: const InputDecoration(labelText: 'Antal timmar'),
                items: [
                  for (final h in hourOptions.value)
                    DropdownMenuItem(value: h, child: Text('$h h')),
                ],
                onChanged: (h) => form.hours.value = h ?? 1,
              ),
              const SizedBox(height: 16),
              const Text('Starttid'),
              const SizedBox(height: 8),
              if (form.loadingSlots.value)
                const LinearProgressIndicator()
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final slot in form.slots.value)
                      ChoiceChip(
                        label: Text(slot.label),
                        selected: form.startHour.value == slot.hour,
                        onSelected: slot.available
                            ? (_) => form.startHour.value = slot.hour
                            : null,
                      ),
                  ],
                ),
              TextField(
                controller: form.noteController,
                decoration: const InputDecoration(labelText: 'Anteckning (valfri)'),
              ),
              const SizedBox(height: 16),
              Text(form.summary.value),
              for (final e in form.errors.value)
                Text('• $e', style: const TextStyle(color: Colors.orange)),
              if (store.lastError.value case final msg?)
                Text(msg, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: form.canSubmit.value ? submit : null,
                child: Text(submitLabel.value),
              ),
            ],
          ),
        );
  }
}
```

</details>

<details>
<summary>▶ Visa övriga sidor: resurslista, mina bokningar och medlemmar</summary>

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection_keys.dart';
import 'book_resource_page.dart';

class ResourcesListPage extends CompositionWidget {
  const ResourcesListPage({super.key});

  static const path = '/resources';

  @override
  Widget Function(BuildContext) setup() {
    final store = inject(bookingsStoreKey);
    final showSpinner = computed(
      () => store.loading.value && store.resources.value.isEmpty,
    );

    onMounted(store.loadResources);

    return (context) => Scaffold(
          appBar: AppBar(title: const Text('Boka lokal')),
          body: showSpinner.value
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: store.loadResources,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      for (final r in store.resources.value)
                        ListTile(
                          leading: const Icon(Icons.meeting_room),
                          title: Text(r.name),
                          subtitle: Text('${r.description}\nMax ${r.maxHours} h per bokning'),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(BookResourcePage.pathFor(r.id)),
                        ),
                    ],
                  ),
                ),
        );
  }
}
```

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

import '../../../core/di/injection_keys.dart';
import '../../../core/models/resource_record.dart';
import '../../../shared/widgets/entity_action_menu.dart';

String formatRange(DateTime s, DateTime e) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${s.year}-${two(s.month)}-${two(s.day)} ${two(s.hour)}:${two(s.minute)}'
      '–${two(e.hour)}:${two(e.minute)}';
}

class MyBookingsPage extends CompositionWidget {
  const MyBookingsPage({super.key});

  static const path = '/my-bookings';

  @override
  Widget Function(BuildContext) setup() {
    final store = inject(bookingsStoreKey);
    final context = useContext();

    final showSpinner = computed(
      () => store.loading.value && store.myBookings.value.isEmpty,
    );
    final isEmpty = computed(
      () => !store.loading.value && store.myBookings.value.isEmpty,
    );

    onMounted(store.loadMyBookings);

    Future<void> cancel(BookingRecord b) async {
      final ok = await store.deleteBooking(b.id);
      final ctx = context.value;
      if (!ok && ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Kunde inte avboka')),
        );
      }
    }

    return (context) => Scaffold(
          appBar: AppBar(title: const Text('Mina bokningar')),
          body: showSpinner.value
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: store.loadMyBookings,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (isEmpty.value)
                        const ListTile(title: Text('Du har inga kommande bokningar')),
                      for (final b in store.myBookings.value)
                        ListTile(
                          leading: Icon(
                            b.approvalStatus == ApprovalStatus.approved
                                ? Icons.check_circle
                                : Icons.hourglass_top,
                          ),
                          title: Text(b.resourceName),
                          subtitle: Text(formatRange(b.start, b.end)),
                          trailing: EntityActionMenu(actions: [
                            EntityAction.delete(
                              () => cancel(b),
                              label: 'Avboka',
                              confirmMessage: 'Vill du avboka ${b.resourceName}?',
                            ),
                          ]),
                        ),
                    ],
                  ),
                ),
        );
  }
}
```

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/models/collections.dart';
import '../../core/models/user_record.dart';
import '../../core/pagination/paginated.dart';

class MembersStore {
  MembersStore(this._pb);

  final PocketBase _pb;

  final search = ref('');

  late final members = Paginated<UserRecord>((page, perPage) async {
    final q = search.value.trim();
    final res = await _pb.collection(Collections.users).getList(
          page: page,
          perPage: perPage,
          sort: 'name',
          filter: q.isEmpty
              ? ''
              : _pb.filter('name ~ {:q} || email ~ {:q}', {'q': q}),
        );
    return PageResult(
      res.items.map((r) => UserRecord.fromJson(r.toJson())).toList(),
      res.totalPages,
    );
  });

  /// Endast admin (API-regeln på users kontrollerar det också).
  Future<bool> setRole(String userId, UserRole role) async {
    try {
      await _pb.collection(Collections.users).update(userId, body: {'role': role.name});
      await members.refresh();
      return true;
    } catch (e) {
      debugPrint('MembersStore.setRole: $e');
      return false;
    }
  }
}
```

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

import '../../../core/di/injection_keys.dart';
import '../../../core/models/user_record.dart';
import '../../../core/utils/permissions.dart';
import '../../../shared/widgets/paginated_list_view.dart';

class MembersListPage extends CompositionWidget {
  const MembersListPage({super.key});

  static const path = '/members';

  @override
  Widget Function(BuildContext) setup() {
    final store = inject(membersStoreKey);
    final auth = inject(authStoreKey);
    final members = store.members;
    final (searchController, search, _) = useTextEditingController();

    final canEditRoles = computed(
      () => auth.hasPermission(AppMenu.members, PermissionOp.update),
    );

    // Enkel debounce: sök 300 ms efter sista tangenttrycket.
    Timer? debounce;
    watch(() => search.value, (q, _) {
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 300), () {
        store.search.value = q;
        members.refresh();
      });
    });
    onUnmounted(() => debounce?.cancel());

    onMounted(members.refresh);

    return (context) => Scaffold(
          appBar: AppBar(
            title: TextField(
              controller: searchController,
              decoration: const InputDecoration(hintText: 'Sök medlem…'),
            ),
          ),
          body: PaginatedListView(
            itemCount: members.items.value.length,
            hasMore: members.hasMore.value,
            loadingMore: members.loadingMore.value,
            onLoadMore: members.loadMore,
            onRefresh: members.refresh,
            emptyText: 'Inga medlemmar hittades',
            itemBuilder: (context, i) {
              final m = members.items.value[i];
              return ListTile(
                title: Text(m.name),
                subtitle: Text(m.email),
                trailing: canEditRoles.value
                    ? DropdownButton<UserRole>(
                        value: m.role,
                        items: [
                          for (final r in UserRole.values)
                            DropdownMenuItem(value: r, child: Text(r.name)),
                        ],
                        onChanged: (r) => r == null ? null : store.setRole(m.id, r),
                      )
                    : Text(m.role.name),
              );
            },
          ),
        );
  }
}
```

</details>

Lägg märke till att avbokningen i `BookingsStore.deleteBooking` är **optimistisk**:
bokningen tas bort ur listan direkt och läggs tillbaka om servern svarar med fel.

---

## Tester

En ren funktion:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:foreningsappen/core/models/user_record.dart';
import 'package:foreningsappen/core/utils/permissions.dart';

void main() {
  test('member får läsa men inte skapa anslag som standard', () {
    final ops = resolvePermissions(AppMenu.posts, UserRole.member, null);
    expect(ops, {PermissionOp.read});
  });

  test('föreningens JSON skriver över standardmatrisen', () {
    final ops = resolvePermissions(AppMenu.posts, UserRole.member, {
      'posts': {'member': ['read', 'create']},
    });
    expect(ops, {PermissionOp.read, PermissionOp.create});
  });
}
```

Ett widget-test med en riktig `AuthStore` och fejkad inloggning. `pb.authStore.save`
loggar in utan nätverk. Token måste vara en JWT med `exp` i framtiden för att `isValid`
ska bli sant.

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart' hide AuthStore;
import 'package:foreningsappen/core/di/injection_keys.dart';
import 'package:foreningsappen/features/auth/auth_store.dart';
import 'package:foreningsappen/features/dashboard/pages/dashboard_page.dart';

String fakeJwt() {
  String b64(Map m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${b64({'alg': 'HS256'})}.${b64({'exp': 4102444800})}.sig';
}

PocketBase pbAs(String role) {
  final pb = PocketBase('http://127.0.0.1:8090');
  pb.authStore.save(fakeJwt(), RecordModel({
    'id': 'u1', 'name': 'Anna', 'email': 'anna@example.com',
    'association': '', 'role': role,
  }));
  return pb;
}

void main() {
  for (final (role, seesMembers) in [('member', false), ('admin', true)]) {
    testWidgets('dashboard för $role', (tester) async {
      final auth = AuthStore(pbAs(role));
      expect(auth.isAuthenticated.value, isTrue);
      await tester.pumpWidget(CompositionBuilder(setup: () {
        provide(authStoreKey, auth);
        return (context) => const MaterialApp(home: DashboardPage());
      }));
      expect(find.text('Hej Anna!'), findsOneWidget);
      expect(find.text('Anslag'), findsOneWidget);
      expect(find.text('Medlemmar'), seesMembers ? findsOneWidget : findsNothing);
      auth.signOut();
      await tester.pump();
      expect(find.text('Anslag'), findsNothing);
    });
  }
}
```

Testet verifierar tre saker: att `provide`/`inject` fungerar, att dashboarden filtrerar
per roll, och att UI:t reagerar på utloggning.

---

## Fördjupning: rollmatris på servern

API-regler kan inte utvärdera en **JSON-matris** som
`{"posts": {"member": ["read", "create"]}}` på föreningen. En hook kan det. Lätta då på
`posts.createRule` till `@request.auth.id != "" && @request.body.author = @request.auth.id`
och låt hooken avgöra rollen, med samma standardmatris som `permissions.dart`.

<details>
<summary>▶ Visa <code>pb_hooks/permissions_utils.js</code> och <code>permissions.pb.js</code></summary>

```js
// Samma standardmatris som lib/core/utils/permissions.dart i appen.
const DEFAULTS = {
  posts:    { admin: ["read", "create", "update", "delete"], styrelse: ["read", "create", "update"], member: ["read"] },
  bookings: { admin: ["read", "create", "update", "delete"], styrelse: ["read", "create"], member: ["read", "create"] },
  members:  { admin: ["read", "update"], styrelse: ["read"], member: [] },
};

// Vilken "meny" en collection hör till.
const MENU_BY_COLLECTION = { posts: "posts", post_comments: "posts", bookings: "bookings" };

function readOverrides(app, associationId) {
  if (!associationId) return null;
  try {
    const assoc = app.findRecordById("associations", associationId);
    // JSON-fält kan komma som en byte-array; toString() + JSON.parse normaliserar.
    const raw = toString(assoc.get("permissions"));
    const parsed = raw ? JSON.parse(raw) : null;
    return parsed && typeof parsed === "object" ? parsed : null;
  } catch (_) {
    return null;
  }
}

module.exports = {
  /** Kastar ForbiddenError om inloggad användares roll saknar rätt till op. */
  enforce: (e, op) => {
    if (e.hasSuperuserAuth()) return;
    const auth = e.auth;
    if (!auth) throw new UnauthorizedError("Logga in först.");

    const menu = MENU_BY_COLLECTION[e.collection.name];
    if (!menu) return;
    // Kommentarer: alla som får läsa anslag får kommentera.
    const effectiveOp = e.collection.name === "post_comments" ? "read" : op;

    const role = auth.getString("role") || "member";
    const overrides = readOverrides(e.app, auth.getString("association"));
    const allowed =
      (overrides && overrides[menu] && overrides[menu][role]) ||
      DEFAULTS[menu][role] || [];

    if (allowed.indexOf(effectiveOp) === -1) {
      throw new ForbiddenError("Din roll saknar behörighet för detta.");
    }
  },
};
```

```js
/// <reference path="../pb_data/types.d.ts" />
onRecordCreateRequest((e) => {
  require(`${__hooks}/permissions_utils.js`).enforce(e, "create");
  e.next();
}, "posts", "post_comments", "bookings");

onRecordUpdateRequest((e) => {
  require(`${__hooks}/permissions_utils.js`).enforce(e, "update");
  e.next();
}, "posts", "bookings");

onRecordDeleteRequest((e) => {
  require(`${__hooks}/permissions_utils.js`).enforce(e, "delete");
  e.next();
}, "posts", "bookings");
```

</details>

Provkört: en `member` får `403 Din roll saknar behörighet för detta.`, och efter att
admin satt matrisen ovan på föreningen lyckas samma anrop.

> ⚠️ **Varning:** Ett JSON-fält kan i hooks komma som en byte-array. `toString(...)` +
> `JSON.parse` normaliserar det.

---

## Så bygger du nästa feature

1. **Backend:** collection med `association`-relation, tenant-regler och vid behov en
   hook som stämplar serverfält. Testa med `curl` som "fel" användare.
2. **Modell:** `XxxRecord.fromJson` och namnet i `Collections`.
3. **Store:** `Paginated<XxxRecord>` för listan, `fetchXxx(id)`, `saveXxx({id, …})` och
   `deleteXxx(id)` som returnerar `Future<bool>`, plus en `saving`-ref.
4. **DI:** `InjectionKey` i `injection_keys.dart`, skapa och `provide` i `MyApp`.
5. **Sidor:** `XxxListPage` (PaginatedListView + FAB med behörighet), `XxxDetailPage`
   (hämta via id, `EntityActionMenu`) och `CreateXxxPage` (skapa och redigera).
6. **Router:** routes med `static const path`, med `new` före `:id`.
7. **Behörighet:** ett `AppMenu`-värde, matrisen och en ruta på dashboarden.
8. **Test:** minst ett widget-test med `provide`.

Prova själv i [övning 3.4](ovningar.md#övning-34--ny-feature-felanmälan).

## Sammanfattning

- **Feature-first** med en store per domän. Stores exponerar `ReadonlyRef` och
  `computed` och har async-metoder som returnerar `Future<bool>`.
- Alla stores skapas och `provide`:as i `MyApp`. Sidor gör `inject`. Bara routern
  använder en global accessor.
- `Paginated<T>` + `PaginatedListView` för långa listor, och `EntityActionMenu` för
  åtgärder.
- Auth-guard i `redirect` plus `router.refresh()` vid inloggningsändring.
- Säkerhet ligger på servern (regler och hooks). Appen speglar den för en bra
  upplevelse.

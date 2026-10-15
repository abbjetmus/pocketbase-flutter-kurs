# 6. PocketBase från Flutter

Nu kopplar vi ihop appen med din PocketBase från
[modul 01](../01-databaser-och-pocketbase/README.md). Det görs med paketet
[`pocketbase`](https://pub.dev/packages/pocketbase).

Exemplen i det här kapitlet är vanlig Dart-kod. I nästa kapitel delar vi
klienten med hela appen via `provide`/`inject`, och i kapitel 8 visar vi datan
reaktivt med `useAsyncData`.

## Installera paketet

Kör i terminalen, i ditt Flutter-projekt:

```powershell
flutter pub add pocketbase
```

## Anslut

```dart
import 'package:pocketbase/pocketbase.dart';

final pb = PocketBase('http://127.0.0.1:8090');
```

| Appen körs i … | Adress |
|----------------|--------|
| Windows, webben eller iOS-simulator | `http://127.0.0.1:8090` |
| Android-emulator | `http://10.0.2.2:8090` |

⚠️ I Android-emulatorn betyder `127.0.0.1` emulatorn själv, inte din dator.
Därför används `10.0.2.2` där.

## Logga in

```dart
await pb.collection('users').authWithPassword('anna@example.com', 'kvittra123');

print(pb.authStore.isValid);     // true
print(pb.authStore.record?.id);  // Annas id
```

`pb.authStore` kommer ihåg vem som är inloggad. Alla anrop efteråt görs som
Anna, och API-reglerna från [modul 01, kapitel 8](../01-databaser-och-pocketbase/08-inloggning-och-api-regler.md)
gäller.

Logga ut med `pb.authStore.clear()`.

## Hämta inlägg

```dart
final result = await pb.collection('posts').getList(
  page: 1,
  perPage: 20,
  sort: '-created',     // nyaste först
  expand: 'author',     // hämta även författaren
);

for (final post in result.items) {
  final title = post.get<String>('title');
  final author = post.get<String>('expand.author.username', '?');
  print('$title – $author');
}
```

- `sort: '-created'` motsvarar `ORDER BY created DESC` i SQL.
- `expand: 'author'` motsvarar en `JOIN`. Utan den får du bara författarens id.

## Filtrera

```dart
final annasPosts = await pb.collection('posts').getFullList(
  filter: pb.filter('author.username = {:name}', {'name': 'anna'}),
);
```

`pb.filter` fyller i värdet på ett säkert sätt. Klistra aldrig ihop filter med
text som användaren har skrivit.

## Skapa, ändra och ta bort

```dart
final me = pb.authStore.record!.id;

// Skapa ett inlägg
final post = await pb.collection('posts').create(body: {
  'author': me,
  'title': 'Hej från appen',
  'body': 'Mitt första inlägg från Flutter!',
});

// Ändra
await pb.collection('posts').update(post.id, body: {'title': 'Ny rubrik'});

// Gilla
await pb.collection('likes').create(body: {'post': post.id, 'user': me});

// Ta bort
await pb.collection('posts').delete(post.id);
```

## När något går fel

Om en regel stoppar anropet, eller om data saknas, kastas ett `ClientException`:

```dart
try {
  await pb.collection('likes').create(body: {'post': postId, 'user': me});
} on ClientException catch (e) {
  print(e.statusCode);  // t.ex. 400 om du redan har gillat inlägget
  print(e.response);    // PocketBase förklaring
}
```

## Realtid

PocketBase kan meddela appen direkt när något ändras, till exempel när någon
skriver en ny kommentar:

```dart
final unsubscribe = await pb.collection('comments').subscribe('*', (event) {
  print('${event.action}: ${event.record?.get<String>('body')}');
});

// När du inte vill lyssna längre:
await unsubscribe();
```

Nästa kapitel: [Provide och inject →](07-provide-inject.md)

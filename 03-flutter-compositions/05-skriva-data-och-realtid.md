# 5. Skriva data och realtid

I [modul 02, kapitel 6](../02-flutter/06-hamta-data-fran-pocketbase.md) lärde du
dig att ansluta till PocketBase, logga in och **hämta** inlägg med `getList`.
Nu lär du dig resten: filtrera, **skapa, ändra och ta bort**, ta hand om fel
och lyssna på ändringar i **realtid**.

Koden i det här kapitlet är vanlig Dart. I kapitel 6 delar vi PocketBase med
hela appen, och i kapitel 7 visar vi datan på skärmen.

⚠️ **Starta PocketBase först.** Öppna terminalen i mappen `kvittra-pb` och kör
`.\pocketbase serve`. Låt fönstret vara öppet.

## Snabb repetition

| Du vill … | Skriv |
|-----------|-------|
| Ansluta | `final pb = PocketBase('http://127.0.0.1:8090');` |
| Logga in | `await pb.collection('users').authWithPassword(email, lösenord);` |
| Hämta en sida | `await pb.collection('posts').getList(sort: '-created', expand: 'author');` |
| Läsa ett fält | `record.getStringValue('title')` eller `record.get<String>('expand.author.name')` |

## En sida att testa på

Lägg koden i en knapp, så kan du köra den när du vill. Det som skrivs ut med
`debugPrint` syns i terminalen där du körde `flutter run -d chrome`.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';

void main() => runApp(const MaterialApp(home: PbTestPage()));

class PbTestPage extends CompositionWidget {
  const PbTestPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final pb = PocketBase('http://127.0.0.1:8090');

    Future<void> run() async {
      await pb.collection('users').authWithPassword('anna@example.com', 'kvittra123');
      // Här lägger du koden från kapitlet
    }

    return (context) => Scaffold(
          body: Center(
            child: FilledButton(onPressed: run, child: const Text('Kör')),
          ),
        );
  }
}
```

## Vem är inloggad?

`pb.authStore` kommer ihåg vem som är inloggad:

| Kod | Ger |
|-----|-----|
| `pb.authStore.isValid` | `true` om någon är inloggad |
| `pb.authStore.record` | Den inloggade användaren (en record i `users`), eller `null` |
| `pb.authStore.record!.id` | Den inloggades id |
| `pb.authStore.clear()` | Loggar ut |

Alla anrop görs som den som är inloggad, och API-reglerna från
[modul 01, kapitel 8](../01-databaser-och-pocketbase/08-inloggning-och-api-regler.md)
gäller.

## Filtrera

```dart
final annasPosts = await pb.collection('posts').getFullList(
  filter: pb.filter('author.username = {:name}', {'name': 'anna'}),
);
```

`getList` hämtar en sida. `getFullList` hämtar allt. `getFirstListItem` hämtar
den första som matchar:

```dart
final me = pb.authStore.record!.id;

final myLike = await pb.collection('likes').getFirstListItem(
  pb.filter('post = {:p} && user = {:u}', {'p': postId, 'u': me}),
);
```

| Filter | Betyder |
|--------|---------|
| `author = {:id}` | Författaren har det här id:t |
| `author.username = {:name}` | Följ relationen och jämför användarnamnet |
| `post = {:p} && user = {:u}` | Båda måste stämma (`&&` = och, `\|\|` = eller) |
| `title ~ {:q}` | Rubriken **innehåller** texten |

⚠️ Använd alltid `pb.filter` med `{:namn}`. Den fyller i värdet på ett säkert
sätt. Klistra aldrig ihop ett filter med text som användaren har skrivit.

## Skapa, ändra och ta bort

```dart
final me = pb.authStore.record!.id;
final posts = pb.collection('posts');

// Skapa ett inlägg
final post = await posts.create(body: {
  'author': me,
  'title': 'Hej från appen',
  'body': 'Mitt första inlägg från Flutter!',
});

// Ändra
await posts.update(post.id, body: {'title': 'Ny rubrik'});

// Ta bort
await posts.delete(post.id);
```

`'author': me` måste vara med. Create-regeln från modul 01 kräver att `author`
är den som är inloggad.

### Gilla och sluta gilla

En like är en rad i `likes`. Att sluta gilla är att ta bort raden:

```dart
final likes = pb.collection('likes');

// Gilla
await likes.create(body: {'post': postId, 'user': me});

// Sluta gilla: hitta raden och ta bort den
final like = await likes.getFirstListItem(
  pb.filter('post = {:p} && user = {:u}', {'p': postId, 'u': me}),
);
await likes.delete(like.id);
```

### Följa och sluta följa

Samma idé med `follows`:

```dart
final follows = pb.collection('follows');

// Följ
await follows.create(body: {'follower': me, 'following': userId});

// Sluta följa
final row = await follows.getFirstListItem(
  pb.filter('follower = {:me} && following = {:id}', {'me': me, 'id': userId}),
);
await follows.delete(row.id);
```

💡 Vill du bara veta **hur många** som matchar? Hämta en enda rad och läs
`totalItems`:

```dart
final result = await follows.getList(
  perPage: 1,
  filter: pb.filter('following = {:id}', {'id': userId}),
);
debugPrint('${result.totalItems} följare');
```

## När något går fel

Om en API-regel stoppar anropet, eller om något är fel i datan, kastas ett
`ClientException`:

```dart
try {
  await pb.collection('likes').create(body: {'post': postId, 'user': me});
} on ClientException catch (e) {
  debugPrint('${e.statusCode}');          // 400 om du redan har gillat
  debugPrint('${e.response['message']}'); // PocketBase förklaring
}
```

Gillar du samma inlägg två gånger säger det **unika indexet** på
`likes (post, user)` från modul 01 nej, och du får `400`.

| Statuskod | Betyder oftast |
|-----------|----------------|
| `400` | Något är fel i datan (t.ex. en like som redan finns), fel lösenord, eller Create-regeln säger nej |
| `403` | Regeln är låst 🔒, bara superusers får |
| `404` | Recorden finns inte, eller så får du inte se eller ändra den |
| `0` | Appen når inte PocketBase. Är den startad? |

## Realtid

PocketBase kan säga till appen direkt när något ändras, till exempel när någon
skriver en kommentar:

```dart
final unsubscribe = await pb.collection('comments').subscribe('*', (e) {
  debugPrint('${e.action}: ${e.record?.getStringValue('body')}');
});

// När du inte vill lyssna längre:
await unsubscribe();
```

| Del | Betyder |
|-----|---------|
| `'*'` | Lyssna på alla records i collectionen |
| `e.action` | `create`, `update` eller `delete` |
| `e.record` | Recorden som ändrades |
| `unsubscribe` | En funktion som du anropar för att sluta lyssna |

Du kan också skicka med `filter:` och `expand:`. Då får du bara händelser för
ett visst inlägg, med författaren inbakad:

```dart
final unsubscribe = await pb.collection('comments').subscribe(
  '*',
  (e) => debugPrint('${e.action}: ${e.record?.get<String>('expand.author.name')}'),
  filter: pb.filter('post = {:id}', {'id': postId}),
  expand: 'author',
);
```

⚠️ Glöm inte att anropa `unsubscribe()`. Annars fortsätter appen att lyssna
fast sidan är stängd. I kapitel 7 ser du hur det görs i `onUnmounted`.

💡 Realtid följer API-reglerna. Du får bara händelser för records du har rätt
att se.

## Kom ihåg

| Du vill … | Skriv |
|-----------|-------|
| Hämta första som matchar | `getFirstListItem(pb.filter(...))` |
| Skapa | `create(body: {...})` |
| Ändra | `update(id, body: {...})` |
| Ta bort | `delete(id)` |
| Fånga fel | `on ClientException catch (e)` |
| Lyssna på ändringar | `subscribe('*', (e) { ... })` |
| Sluta lyssna | `await unsubscribe()` |
| Logga ut | `pb.authStore.clear()` |

## Övningar

Gör övningarna i `PbTestPage`, inne i `run()`.

**5.1** Skriv ut alla kommentarer på inlägget "Mitt första surdegsbröd", med
författarens namn. Tips: filtrera på `post.title` och använd `expand`.

**5.2** Skapa ett inlägg som Anna, ändra rubriken och ta bort det. Kontrollera
i Dashboard efter varje steg.

**5.3** Prova att skapa ett inlägg där `author` är Bertils id. Vad händer, och
vilken regel från modul 01 är det som stoppar dig?

**5.4** Låt Anna gilla "Matchdag". Hon har redan gillat det i testdatan. Fånga
felet och skriv ut statuskoden. Ta sedan bort hennes like och gilla igen.

**5.5** Skriv ut hur många följare Anna har, och hur många hon själv följer.

**5.6** Starta en prenumeration på `comments` och låt bli att anropa
`unsubscribe()`. Öppna Dashboard och skriv en ny kommentar. Vad skrivs ut i
terminalen?

Lösningar finns i [losningar.md](losningar.md#kapitel-5--skriva-data-och-realtid).

Nästa kapitel: [Provide och inject](06-provide-inject.md)

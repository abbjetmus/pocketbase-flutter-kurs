# 9. Skriva data och realtid

I [kapitel 8](08-hamta-data-fran-pocketbase.md) lärde du
dig att ansluta till PocketBase och **hämta** inlägg med `getList`.
Nu lär du dig resten: filtrera, **skapa, ändra och ta bort**, ta hand om fel
och lyssna på ändringar i **realtid**.

Koden i det här kapitlet är vanlig Dart. I kapitel 10 visar vi datan på
skärmen.

⚠️ **Starta PocketBase först.** Öppna terminalen i mappen `kvittra-pb` och kör
`.\pocketbase serve`. Låt fönstret vara öppet.

## Snabb repetition

| Du vill … | Skriv |
|-----------|-------|
| Ansluta | `final pb = PocketBase('http://127.0.0.1:8090');` |
| Hämta en sida | `await pb.collection('posts').getList(sort: '-created', expand: 'author');` |
| Läsa ett fält | `record.getStringValue('title')` eller `record.get<String>('expand.author.name')` |

## En sida att testa på

Lägg koden i en knapp, så kan du köra den när du vill. Skapa filen
`lib/pb_test.dart`:

```dart
// lib/pb_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';

import 'data/pocketbase.dart';

class PbTestPage extends CompositionWidget {
  const PbTestPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    Future<void> run() async {
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

Öppna sedan `lib/main.dart`. Lägg till `import 'pb_test.dart';` högst upp och
byt `void main()` mot den här raden:

```dart
void main() => runApp(const MaterialApp(home: PbTestPage()));
```

Klicka **Build**. Nu visar appen bara knappen **Kör**. Det som skrivs ut med
`debugPrint` syns i konsolen (`F12` → **Console**).

💡 Spara den gamla `void main()`-raden som en kommentar (`//` först), så kan du
byta tillbaka. I kapitel 11 börjar vi på ett nytt projekt.

## Appen är Anna

Appen loggar inte in. I stället låtsas den alltid vara **Anna**. Då behöver den
veta Annas **id**:

1. Öppna Dashboard och collectionen `users`.
2. Klicka på Anna.
3. Kopiera hennes id. Det står överst och ser ut ungefär som `a1b2c3d4e5f6g7h`.

Lägg id:t i `lib/data/pocketbase.dart`:

```dart
// lib/data/pocketbase.dart (lägg till)
// Appen är alltid Anna. Klistra in hennes id från Dashboard.
const annaId = 'a1b2c3d4e5f6g7h';
```

Varje gång appen skapar något åt Anna skickar den med `annaId`.

## Filtrera

```dart
final annasPosts = await pb.collection('posts').getFullList(
  filter: pb.filter('author.username = {:name}', {'name': 'anna'}),
);
```

`getList` hämtar en sida. `getFullList` hämtar allt. `getFirstListItem` hämtar
den första som matchar:

```dart
final myLike = await pb.collection('likes').getFirstListItem(
  pb.filter('post = {:p} && user = {:u}', {'p': postId, 'u': annaId}),
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
final posts = pb.collection('posts');

// Skapa ett inlägg
final post = await posts.create(body: {
  'author': annaId,
  'title': 'Hej från appen',
  'body': 'Mitt första inlägg från Flutter!',
});

// Ändra
await posts.update(post.id, body: {'title': 'Ny rubrik'});

// Ta bort
await posts.delete(post.id);
```

`'author': annaId` säger att det är Anna som har skrivit inlägget.

### Gilla och sluta gilla

En like är en rad i `likes`. Att sluta gilla är att ta bort raden:

```dart
final likes = pb.collection('likes');

// Gilla
await likes.create(body: {'post': postId, 'user': annaId});

// Sluta gilla: hitta raden och ta bort den
final like = await likes.getFirstListItem(
  pb.filter('post = {:p} && user = {:u}', {'p': postId, 'u': annaId}),
);
await likes.delete(like.id);
```

### Följa och sluta följa

Samma idé med `follows`:

```dart
final follows = pb.collection('follows');

// Följ
await follows.create(body: {'follower': annaId, 'following': userId});

// Sluta följa
final row = await follows.getFirstListItem(
  pb.filter('follower = {:me} && following = {:id}', {'me': annaId, 'id': userId}),
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
  await pb.collection('likes').create(body: {'post': postId, 'user': annaId});
} on ClientException catch (e) {
  debugPrint('${e.statusCode}');          // 400 om du redan har gillat
  debugPrint('${e.response['message']}'); // PocketBase förklaring
}
```

Gillar du samma inlägg två gånger säger det **unika indexet** på
`likes (post, user)` från modul 01 nej, och du får `400`.

| Statuskod | Betyder oftast |
|-----------|----------------|
| `400` | Något är fel i datan, till exempel en like som redan finns |
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
fast sidan är stängd. I kapitel 10 ser du hur det görs i `onUnmounted`.

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

## Övningar

Gör övningarna i `PbTestPage`, inne i `run()`.

**9.1** Skriv ut alla kommentarer på inlägget "Mitt första surdegsbröd", med
författarens namn. Tips: filtrera på `post.title` och använd `expand`.

**9.2** Skapa ett inlägg som Anna, ändra rubriken och ta bort det. Kontrollera
i Dashboard efter varje steg.

**9.3** Skapa ett inlägg där `author` är Bertils id. Vems namn står som
författare i Dashboard? Varför går det, när reglerna är öppna?

**9.4** Låt Anna gilla "Matchdag". Hon har redan gillat det i testdatan. Fånga
felet och skriv ut statuskoden. Ta sedan bort hennes like och gilla igen.

**9.5** Skriv ut hur många följare Anna har, och hur många hon själv följer.

**9.6** Starta en prenumeration på `comments` och låt bli att anropa
`unsubscribe()`. Öppna Dashboard och skriv en ny kommentar. Vad skrivs ut i
konsolen?

Lösningar finns i [losningar.md](losningar.md#kapitel-9--skriva-data-och-realtid).

Nästa kapitel: [Ladda om och realtid](10-ladda-om-och-realtid.md)

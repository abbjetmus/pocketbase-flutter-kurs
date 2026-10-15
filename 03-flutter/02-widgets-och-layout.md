# 02 – Widgets och layout

## Allt är en widget

I Flutter är **allt du ser på skärmen en widget**: text, knappar, ikoner, men också
sådant som inte syns, som marginaler (`Padding`), centrering (`Center`) och
layout (`Row`, `Column`). En widget är en **beskrivning** av en del av
gränssnittet. Den är oföränderlig (immutable) och billig att skapa.

Widgets placeras i varandra och bildar ett **widgetträd**:

```dart
import 'package:flutter/material.dart';

void main() {
  runApp(const KvittraApp());
}

class KvittraApp extends StatelessWidget {
  const KvittraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kvittra',
      home: Scaffold(
        appBar: AppBar(title: const Text('Kvittra')),
        body: const Center(
          child: Text('Välkommen till Kvittra!'),
        ),
      ),
    );
  }
}
```

Trädet ser ut så här:

```
KvittraApp
└── MaterialApp
    └── Scaffold
        ├── AppBar
        │   └── Text("Kvittra")
        └── Center
            └── Text("Välkommen till Kvittra!")
```

- `runApp` tar den översta widgeten och fäster den på skärmen.
- `build` är metoden som beskriver hur widgeten ser ut. Flutter anropar den när
  widgeten behöver ritas, och ibland väldigt ofta.
- `child` (ett barn) och `children` (en lista av barn) är hur widgets nästlas.

💡 **Tips:** Om du kan Vue: en widget motsvarar ungefär en komponent, och `build`
motsvarar `<template>`. Skillnaden är att allt skrivs i Dart, även layouten.

### Tre träd: widget, element och render

Det finns faktiskt tre träd under huven. Du behöver inte kunna dem i detalj, men
det förklarar varför Flutter är snabbt:

| Träd | Vad det är | Livslängd |
|------|-----------|-----------|
| **Widget-trädet** | Dina beskrivningar (`Text('Hej')`) | Kortlivat, skapas om vid varje `build` |
| **Element-trädet** | Flutters "instanser" som håller koll på var varje widget sitter och på dess `State` | Långlivat |
| **Render-trädet** | Objekt som mäter, placerar och ritar | Långlivat |

När `build` körs igen jämför Flutter de nya widgetarna med de gamla. Om typen är
densamma på samma plats uppdateras det befintliga elementet och render-objektet i
stället för att skapas om. Därför är det billigt att bygga om widgets, och därför
spelar `const` roll: en `const`-widget är *samma objekt* varje gång och kan hoppas
över helt.

## MaterialApp, Scaffold och AppBar

- **`MaterialApp`** ligger nästan alltid överst. Den ställer in tema, navigation,
  språk m.m. enligt Googles designsystem *Material Design 3*.
- **`Scaffold`** är "skelettet" för en skärm: plats för `appBar`, `body`,
  `floatingActionButton`, `bottomNavigationBar`, `drawer` m.m.
- **`AppBar`** är listen överst med titel och eventuella knappar (`actions`).

```dart
Scaffold(
  appBar: AppBar(
    title: const Text('Flöde'),
    actions: [
      IconButton(
        icon: const Icon(Icons.refresh),
        onPressed: () {},
      ),
    ],
  ),
  body: const Center(child: Text('Inga inlägg ännu')),
  floatingActionButton: FloatingActionButton(
    onPressed: () {},
    child: const Icon(Icons.edit),
  ),
)
```

## Grundläggande widgets

### Text, Icon och Image

```dart
const Text(
  'Första fikat på nya kontoret',
  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
  maxLines: 1,
  overflow: TextOverflow.ellipsis, // "Första fikat på…" om texten inte får plats
)

const Icon(Icons.favorite, size: 32, color: Colors.red)

Image.network('https://picsum.photos/400/200', fit: BoxFit.cover)
Image.asset('assets/logo.png') // kräver att filen listas under flutter: assets: i pubspec.yaml
```

Bättre än att hårdkoda textstil är att hämta den från temat:

```dart
Text('Anna Lind', style: Theme.of(context).textTheme.titleLarge)
```

### Knappar

Material 3 har flera knapptyper. Alla tar `onPressed`. Om `onPressed` är `null`
blir knappen inaktiverad (grå).

```dart
FilledButton(onPressed: () {}, child: const Text('Följ'))          // huvudåtgärd
OutlinedButton(onPressed: () {}, child: const Text('Avbryt'))
TextButton(onPressed: () {}, child: const Text('Visa kommentarer'))
IconButton(onPressed: () {}, icon: const Icon(Icons.favorite_border))
FilledButton.icon(
  onPressed: null, // inaktiverad
  icon: const Icon(Icons.send),
  label: const Text('Publicera'),
)
```

### Container, Padding och SizedBox

```dart
// Padding – luft runt ett barn
const Padding(
  padding: EdgeInsets.all(16),
  child: Text('Inlägg'),
)

// SizedBox – fast storlek, eller bara mellanrum
const SizedBox(height: 12)                 // tomrum mellan widgets
const SizedBox(width: 100, height: 40, child: Text('Fast'))

// Container – "allt-i-ett": storlek, marginaler, bakgrund, ram, rundade hörn
Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
  margin: const EdgeInsets.only(bottom: 8),
  decoration: BoxDecoration(
    color: Colors.indigo.shade50,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.indigo),
  ),
  child: const Text('#flutter'),
)
```

💡 **Tips:** Använd `Padding` och `SizedBox` när det räcker. `Container` är bra
när du behöver dekoration, men den gör mycket och kan vara svårare att läsa.

## Row och Column

`Row` lägger barn **horisontellt**, `Column` **vertikalt**. Det är de två
viktigaste layout-widgetarna.

```dart
Row(
  children: const [
    Icon(Icons.person),
    SizedBox(width: 8),
    Text('@anna'),
  ],
)
```

### mainAxis och crossAxis

Varje `Row`/`Column` har en **huvudaxel** (main axis), som är riktningen barnen
läggs i, och en **tväraxel** (cross axis), som går vinkelrätt mot den.

```
Row:     main axis →            Column:  main axis ↓
         cross axis ↓                    cross axis →
```

```dart
Column(
  mainAxisAlignment: MainAxisAlignment.center,    // vertikalt i en Column
  crossAxisAlignment: CrossAxisAlignment.start,   // horisontellt i en Column
  children: const [
    Text('Anna Lind'),
    Text('@anna'),
  ],
)
```

| `MainAxisAlignment` | Effekt |
|--------------------|--------|
| `start` | Allt i början (standard) |
| `center` | Allt i mitten |
| `end` | Allt i slutet |
| `spaceBetween` | Första och sista vid kanterna, jämnt mellanrum mellan |
| `spaceAround` / `spaceEvenly` | Jämnt mellanrum, även vid kanterna |

`mainAxisSize: MainAxisSize.min` gör att en `Column` bara blir så hög som sitt
innehåll i stället för att ta all tillgänglig höjd.

💡 **Tips:** Sedan Flutter 3.27 har `Row` och `Column` en `spacing`-parameter:
`Column(spacing: 8, children: [...])` ger 8 pixlars mellanrum mellan barnen, så du
slipper lägga in `SizedBox` överallt.

### Expanded, Flexible och Spacer

Som standard tar barnen i en `Row` bara den plats de behöver. Med `Expanded` tar
ett barn **all återstående plats**:

```dart
Row(
  children: [
    const CircleAvatar(child: Text('BE')),
    const SizedBox(width: 8),
    const Expanded(
      child: Text('Bo Ek – fotograf, cyklist och självutnämnd kanelbullekännare'),
    ),
    TextButton(onPressed: () {}, child: const Text('Följ')),
  ],
)
```

Texten får nu exakt den plats som blir över mellan avataren och knappen, och
radbryts i stället för att flöda över.

- `Expanded(flex: 2, ...)` och `Expanded(flex: 1, ...)` delar platsen 2:1.
- `Flexible` får *ta upp till* den plats som finns, men måste inte fylla den.
- `Spacer()` är ett tomt `Expanded` som trycker isär barn.

```dart
Row(
  children: const [
    Text('@anna'),
    Spacer(),          // trycker tiden till höger kant
    Text('2 tim'),
  ],
)
```

## Stack

`Stack` lägger barn **ovanpå varandra**. Med `Positioned` placerar du dem exakt.
Det är perfekt för en profilsida där avataren "sticker ut" nedanför omslagsbilden:

```dart
SizedBox(
  height: 180,
  child: Stack(
    children: [
      // Omslagsbilden fyller allt utom de nedersta 40 pixlarna
      Positioned.fill(
        bottom: 40,
        child: Image.network('https://picsum.photos/800/300', fit: BoxFit.cover),
      ),
      // Avataren hamnar nere till vänster, halvvägs över bildkanten
      const Positioned(
        left: 16,
        bottom: 0,
        child: CircleAvatar(
          radius: 40,
          backgroundColor: Colors.white,
          child: CircleAvatar(radius: 36, child: Text('AL')),
        ),
      ),
    ],
  ),
)
```

## Listor: ListView och ListView.builder

En `Column` kan inte scrolla. Har du fler saker än vad som får plats behöver du en
`ListView`.

```dart
// För ett fåtal, kända barn
ListView(
  padding: const EdgeInsets.all(16),
  children: const [
    Text('Inlägg 1'),
    Text('Inlägg 2'),
  ],
)
```

För långa eller dynamiska listor, som ett flöde, använder du `ListView.builder`.
Den bygger bara de rader som syns på skärmen, så den fungerar lika bra med 10 som
med 10 000 inlägg:

```dart
final titlar = List.generate(100, (i) => 'Inlägg nummer ${i + 1}');

ListView.builder(
  itemCount: titlar.length,
  itemBuilder: (context, index) {
    return ListTile(title: Text(titlar[index]));
  },
)
```

`ListView.separated` fungerar likadant men har även en `separatorBuilder`, till
exempel för `Divider()` mellan raderna.

### Card och ListTile

`ListTile` är en färdig rad med plats för ikon, titel, undertitel och något till
höger. `Card` är en upphöjd yta med rundade hörn.

```dart
Card(
  child: ListTile(
    leading: const CircleAvatar(child: Text('AL')),
    title: const Text('Anna Lind'),
    subtitle: const Text('@anna · 12 inlägg'),
    trailing: const Icon(Icons.chevron_right),
    onTap: () {},
  ),
)
```

## Constraints: hur Flutter bestämmer storlekar

Det här är den viktigaste regeln för att förstå layout i Flutter:

> **Constraints go down. Sizes go up. Parent sets position.**
>
> Begränsningar skickas nedåt. Storlekar skickas uppåt. Föräldern bestämmer
> positionen.

1. Föräldern säger till barnet: "Du får vara mellan *min* och *max* bredd, och
   mellan *min* och *max* höjd." (constraints)
2. Barnet väljer en storlek **inom** de gränserna och berättar den för föräldern.
3. Föräldern bestämmer var barnet placeras.

Konsekvenser som förvånar nybörjare:

- En widget **kan inte** välja vilken storlek som helst. `Container(width: 100)`
  direkt i `body` på en `Scaffold` blir ändå full bredd om föräldern kräver det
  ("tight constraints"). Lägg den i en `Center` eller `Align` så får den bli 100 bred.
- En widget vet inte var den ligger på skärmen, bara hur stor den är.
- `Row` ger sina barn **obegränsad bredd** och `Column` ger **obegränsad höjd**
  (längs huvudaxeln). Därför uppstår de vanligaste felen nedan.

### Vanliga layoutfel

**1. Gul-svarta ränder: "A RenderFlex overflowed by 42 pixels on the right."**

```dart
// FEL: lång text i en Row – Text får obegränsad bredd och blir för bred
Row(children: [
  Icon(Icons.chat_bubble_outline),
  Text('Cecilia Holm kommenterade ditt inlägg "Första fikat på nya kontoret"'),
])

// RÄTT: låt texten ta den plats som finns och radbryta
Row(children: [
  Icon(Icons.chat_bubble_outline),
  Expanded(child: Text('Cecilia Holm kommenterade ditt inlägg ...')),
])
```

Samma sak händer vertikalt när en `Column` får fler barn än vad som får plats.
Lösningen är då en `ListView` eller `SingleChildScrollView`.

**2. "Vertical viewport was given unbounded height."**

```dart
// FEL: ListView i en Column – Column ger obegränsad höjd, ListView vill bli oändligt hög
Column(children: [
  Text('Senaste inläggen'),
  ListView(children: [...]),
])

// RÄTT: ge ListView den återstående höjden
Column(children: [
  Text('Senaste inläggen'),
  Expanded(child: ListView(children: [...])),
])
```

**3. "BoxConstraints forces an infinite width."** Det kan till exempel vara en
`TextField` direkt i en `Row` (som kommentarsfältet bredvid en skicka-knapp).
Lösningen är densamma: wrappa den i `Expanded`.

⚠️ **Varning:** Felmeddelandena i Flutter är långa men bra. Läs de första raderna
i konsolen. De säger oftast exakt vilken widget som är problemet och föreslår en
lösning.

💡 **Tips:** Starta **Flutter DevTools** (i VS Code: *Dart: Open DevTools*) och öppna
*Widget Inspector*. Där ser du trädet, storlekar och constraints för varje widget.
*Layout Explorer* visar Row/Column-inställningar visuellt.

## Tema: ThemeData och ColorScheme.fromSeed

I Material 3 räcker det att välja **en färg**. Flutter räknar ut en hel palett
(primär, sekundär, ytor, fel m.m.) som fungerar ihop, både för ljust och mörkt läge.

```dart
MaterialApp(
  title: 'Kvittra',
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F51B5)),
  ),
  darkTheme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF3F51B5),
      brightness: Brightness.dark,
    ),
  ),
  themeMode: ThemeMode.system, // följ telefonens inställning
  home: const FeedScreen(),
)
```

Hämta färger och textstilar från temat i stället för att hårdkoda dem. Då fungerar
mörkt läge automatiskt:

```dart
final colors = Theme.of(context).colorScheme;
final text = Theme.of(context).textTheme;

Container(
  color: colors.primaryContainer,
  child: Text('Ny', style: text.labelLarge?.copyWith(color: colors.onPrimaryContainer)),
)
```

Varje färg har en "on"-färg (`primary`/`onPrimary`, `surface`/`onSurface` …) som är
den färg text ska ha *ovanpå* den. Då blir kontrasten alltid rätt.

## Exempel: PostCard

Nu bygger vi den viktigaste widgeten i Kvittra: kortet som visar ett inlägg i
flödet. Det ska se ut ungefär så här:

```
┌──────────────────────────────────────┐
│ (AL)  Anna Lind                      │ ← avatar med initialer, namn
│       @anna · 5 min                  │ ← användarnamn och tid
│                                      │
│ Första fikat på nya kontoret         │ ← titel
│ Kanelbullar till alla som kommer     │ ← text, max tre rader
│ före nio! ...                        │
│                                      │
│ ♥ 12    💬 3                          │ ← gilla- och kommentarsknappar
└──────────────────────────────────────┘
```

Först modellerna och två hjälpfunktioner. Kortet behöver mer än vad `Post` i
kapitel 01 har: författarens namn i stället för bara ett `userId`, och antal
kommentarer. Därför gör vi en **visningsmodell**, `FeedPost`, som innehåller
precis det som ett kort i flödet visar. I kapitel 05 ser du hur den riktiga datan
från JSONPlaceholder hämtas och kopplas ihop med författaren.

```dart
// lib/models/feed_post.dart
class Author {
  const Author({required this.name, required this.username});

  final String name;
  final String username;
}

class FeedPost {
  const FeedPost({
    required this.id,
    required this.author,
    required this.title,
    required this.body,
    this.created,
    this.likeCount = 0,
    this.commentCount = 0,
    this.liked = false,
  });

  final int id;
  final Author author;
  final String title;
  final String body;
  final DateTime? created; // valfri: JSONPlaceholder har inga tidsstämplar
  final int likeCount;
  final int commentCount;
  final bool liked;
}

// lib/utils/format.dart
/// "Anna Lind" → "AL", "anna" → "A"
String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  final first = parts.first[0];
  final last = parts.length > 1 ? parts.last[0] : '';
  return (first + last).toUpperCase();
}

/// Relativ tid som i sociala appar: "nu", "5 min", "3 tim", "2 d".
String timeAgo(DateTime time, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(time);
  return switch (diff) {
    Duration(inMinutes: < 1) => 'nu',
    Duration(inHours: < 1, :final inMinutes) => '$inMinutes min',
    Duration(inDays: < 1, :final inHours) => '$inHours tim',
    Duration(:final inDays) => '$inDays d',
  };
}
```

`timeAgo` använder **object patterns** från kapitel 01: `Duration(inMinutes: < 1)`
matchar en `Duration` vars getter `inMinutes` är mindre än 1, och `:final inHours`
plockar ut getterns värde till en variabel.

Sedan själva kortet:

```dart
// lib/widgets/post_card.dart
import 'package:flutter/material.dart';

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    this.onLike,
    this.onComment,
    this.onAuthorTap,
  });

  final FeedPost post;
  final VoidCallback? onLike;      // vad som händer när man trycker på hjärtat
  final VoidCallback? onComment;   // ... på pratbubblan
  final VoidCallback? onAuthorTap; // ... på namnet eller avataren

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final created = post.created; // lokal kopia, så att null-kontrollen fungerar
    final handle = '@${post.author.username}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rad 1: avatar + namn/@användarnamn · tid
            InkWell(
              onTap: onAuthorTap,
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colors.primaryContainer,
                    foregroundColor: colors.onPrimaryContainer,
                    child: Text(initials(post.author.name)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.author.name,
                          style: text.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          created == null ? handle : '$handle · ${timeAgo(created)}',
                          style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Rad 2: titel och text
            Text(post.title, style: text.titleMedium),
            const SizedBox(height: 4),
            Text(
              post.body,
              style: text.bodyMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            // Rad 3: knappar
            Row(
              children: [
                TextButton.icon(
                  onPressed: onLike,
                  icon: Icon(
                    post.liked ? Icons.favorite : Icons.favorite_border,
                    // Ett rött hjärta oavsett tema – ett medvetet undantag
                    color: post.liked ? Colors.red : null,
                  ),
                  label: Text('${post.likeCount}'),
                ),
                TextButton.icon(
                  onPressed: onComment,
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: Text('${post.commentCount}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

Lägg märke till:

- Widgeten tar emot **data** (`post`) och **callbacks** (`onLike`, `onComment`,
  `onAuthorTap`) via konstruktorn. Den vet inte själv vad "gilla" innebär. Det
  bestämmer den som använder den. Det gör kortet återanvändbart: samma `PostCard`
  kan visas i flödet, på en profil och i sökresultat.
- Alla fält är `final`. En widget ändras aldrig, den byggs om med nya värden. När
  någon gillar inlägget skapas ett nytt `FeedPost` (med `copyWith`, som i kapitel 01)
  och kortet byggs om.
- `Expanded` runt namn-kolumnen förhindrar overflow om namnet är långt.
- `InkWell` gör raden tryckbar och ger den typiska Material-"krusningen".

## Exempel: ProfileHeader

Överst på en profilsida visas vem användaren är och hur många som följer hen:

```
            (AL)
         Anna Lind
           @anna
  Utvecklare i Malmö. Gillar fika.

    12         128         87
  Inlägg     Följare     Följer

  [            Följ             ]
```

```dart
// lib/widgets/profile_header.dart
import 'package:flutter/material.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.name,
    required this.username,
    this.bio,
    required this.postCount,
    required this.followers,
    required this.following,
    this.isFollowing = false,
    this.onFollow,
  });

  final String name;
  final String username;
  final String? bio;
  final int postCount;
  final int followers;
  final int following;
  final bool isFollowing;
  final VoidCallback? onFollow;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final bio = this.bio; // lokal kopia, så att Dart kan veta att den inte är null

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            child: Text(initials(name), style: text.headlineSmall),
          ),
          const SizedBox(height: 12),
          Text(name, style: text.titleLarge),
          Text('@$username', style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
          if (bio != null) ...[
            const SizedBox(height: 8),
            Text(bio, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _Stat(value: postCount, label: 'Inlägg')),
              Expanded(child: _Stat(value: followers, label: 'Följare')),
              Expanded(child: _Stat(value: following, label: 'Följer')),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, // knappen fyller hela bredden
            child: isFollowing
                ? OutlinedButton(onPressed: onFollow, child: const Text('Följer'))
                : FilledButton(onPressed: onFollow, child: const Text('Följ')),
          ),
        ],
      ),
    );
  }
}

// En liten privat widget för "siffra ovanför etikett"
class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Text('$value', style: text.titleLarge),
        Text(label, style: text.bodySmall),
      ],
    );
  }
}
```

- `Expanded` på de tre siffrorna gör att de delar bredden lika.
- `if (bio != null) ...[ ... ]` är collection-if med spread: om användaren har en
  bio läggs *två* widgets till (mellanrum och text), annars ingen.
- `_Stat` är privat (understreck) och används bara i den här filen. Att bryta ut
  små widgets gör `build` mycket lättare att läsa.

## Exempel: Flödet

Nu sätter vi ihop allt till en skärm med en lista av `PostCard`:

```dart
import 'package:flutter/material.dart';

// FeedPost, Author, initials, timeAgo och PostCard från exemplen ovan

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key, required this.posts});

  final List<FeedPost> posts;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kvittra')),
      body: posts.isEmpty
          ? const Center(child: Text('Inga inlägg ännu'))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return PostCard(
                  post: post,
                  onLike: () => debugPrint('Gilla ${post.id}'),
                  onComment: () => debugPrint('Kommentera ${post.id}'),
                  onAuthorTap: () => debugPrint('Visa @${post.author.username}'),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.edit),
        label: const Text('Nytt inlägg'),
      ),
    );
  }
}

void main() {
  const anna = Author(name: 'Anna Lind', username: 'anna');
  const bo = Author(name: 'Bo Ek', username: 'bo');
  final now = DateTime.now();

  runApp(
    MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F51B5)),
      ),
      home: FeedScreen(
        posts: [
          FeedPost(
            id: 1,
            author: anna,
            title: 'Första fikat på nya kontoret',
            body: 'Kanelbullar till alla som kommer före nio! Ta med egen mugg.',
            created: now.subtract(const Duration(minutes: 5)),
            likeCount: 12,
            commentCount: 3,
            liked: true,
          ),
          FeedPost(
            id: 2,
            author: bo,
            title: 'Cykla till jobbet i regn',
            body: 'Tre veckor i rad nu. Regnbyxor är underskattade.',
            created: now.subtract(const Duration(hours: 3)),
            likeCount: 4,
          ),
        ],
      ),
    ),
  );
}
```

🧪 **Prova själv:**

1. Ersätt `ListView.builder` med en `Column` och lägg till 20 inlägg (använd
   `List.generate`). Vilket fel får du? Byt tillbaka.
2. Byt `seedColor` till din favoritfärg och kör med mörkt läge på telefonen/datorn.
3. Gör en `ProfileScreen` som visar en `ProfileHeader` överst och användarens
   inlägg som `PostCard` under. Tips: använd **en** `ListView.builder` med
   `itemCount: posts.length + 1`, där index 0 är headern och resten är inlägg. Då
   scrollar headern med listan.

## Sammanfattning

- Ett gränssnitt är ett träd av oföränderliga widgets som beskrivs i `build`.
- `Row`/`Column` + `Expanded`/`SizedBox`/`Padding` räcker för de flesta layouter.
- Använd `ListView.builder` för listor som kan bli långa, som ett flöde.
- *Constraints go down, sizes go up, parent sets position.* De flesta layoutfel
  löses med `Expanded` eller en scrollbar widget.
- Hämta färger och textstilar från `Theme.of(context)` och använd
  `ColorScheme.fromSeed`.
- Bra widgets tar emot data och callbacks via konstruktorn, som `PostCard`.

Hittills har alla widgets varit `StatelessWidget`, som bara visar data som de får
in. I nästa kapitel gör vi saker *interaktiva*: hjärtat ska gå att trycka på.

**Nästa kapitel:** [03 – State och livscykel](03-state-och-livscykel.md)

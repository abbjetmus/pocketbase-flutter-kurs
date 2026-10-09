# Övningar – Modul 03 Flutter

Övningarna är indelade i tre nivåer:

- **Nivå 1**: grundläggande. Alla bör göra dessa.
- **Nivå 2**: kombinerar flera kapitel.
- **Nivå 3**: utmaning. Närmar sig en riktig app.

Försök själv innan du tittar i [lösningarna](losningar.md). Det är okej att titta
tillbaka i kapitlen, och att läsa felmeddelanden noga är en del av övningen.

Skapa gärna ett projekt för övningarna:

```bash
flutter create forening_ovningar
cd forening_ovningar
```

Dart-övningarna (1.1–1.3) kan du köra i <https://dartpad.dev> eller som
`dart run bin/ovning.dart`.

---

## Nivå 1

### Övning 1.1 – Lägenheter (Dart)

Skapa en klass `Apartment` med fälten `id` (String), `number` (String), `floor`
(int) och `sizeSqm` (double). Alla fält ska vara `final`.

1. Lägg till en `factory Apartment.fromJson(Map<String, dynamic> json)`. JSON-nyckeln
   för storleken är `size_sqm`, och den kan komma som heltal (`74`) eller decimaltal
   (`74.5`).
2. Lägg till en getter `label` som returnerar t.ex. `"Lgh 1102 (vån 1, 74.5 m²)"`.
3. I `main`: skapa en lista med minst fyra lägenheter från JSON-maps och skriv ut:
   - alla lägenheter på våning 2,
   - den sammanlagda ytan (använd `fold`),
   - den största lägenheten.

### Övning 1.2 – Null safety

Rätta följande kod så att den kompilerar **utan** att använda `!`:

```dart
class User {
  User({required this.name, this.apartmentNumber});
  final String name;
  final String? apartmentNumber;
}

String doorSign(User user) {
  return '${user.name} – lgh ${user.apartmentNumber.toUpperCase()}';
}

void main() {
  print(doorSign(User(name: 'Anna', apartmentNumber: '1102a')));
  print(doorSign(User(name: 'Styrelsen')));
}
```

Om lägenhetsnummer saknas ska det stå `"Styrelsen – ingen lägenhet"`.

### Övning 1.3 – Roller och switch

Skapa en enhanced enum `Role` med värdena `member`, `board` och `admin`, och en
svensk etikett för varje. Skriv sedan en funktion med ett `switch`-*uttryck*:

```dart
int maxActiveBookings(Role role) => switch (role) { ... };
```

som returnerar 2 för medlemmar, 5 för styrelsen och 99 för admin. Testa att ta bort
ett av fallen. Vilket fel får du?

### Övning 1.4 – Layout från skiss

Bygg följande skärm med `Scaffold`, `Card`, `Row`, `Column`, `Expanded`, `Icon` och
`Text`. Använd `ColorScheme.fromSeed` med valfri färg.

```
┌────────────────────────────────────────┐
│ Brf Solgläntan                     ⚙   │ ← AppBar med actions
├────────────────────────────────────────┤
│ Hej Anna!                              │ ← headlineSmall
│ Lägenhet 1102                          │ ← bodyMedium, dämpad färg
│                                        │
│ ┌──────────────────┐┌────────────────┐ │
│ │ 🧺               ││ 🎉             │ │ ← två kort bredvid varandra,
│ │ Tvättstuga       ││ Festlokal      │ │   lika breda (Expanded)
│ │ Nästa: tis 08:00 ││ Ingen bokning  │ │
│ └──────────────────┘└────────────────┘ │
│                                        │
│ Senaste anslag                         │ ← titleMedium
│ ┌────────────────────────────────────┐ │
│ │ 📢 Vattenavstängning tisdag     ›  │ │ ← ListTile i Card
│ │    Vattnet stängs av 08–12 ...     │ │
│ └────────────────────────────────────┘ │
│ ┌────────────────────────────────────┐ │
│ │ 📢 Vårstädning 12 april         ›  │ │
│ │    Samling på gården kl 10 ...     │ │
│ └────────────────────────────────────┘ │
└────────────────────────────────────────┘
```

Krav:

- Skärmen ska gå att scrolla om den inte får plats (testa i liggande läge).
- Långa anslagstexter ska kortas med `…` (max en rad).
- Inga hårdkodade färger: använd `Theme.of(context)`.

---

## Nivå 2

### Övning 2.1 – Från räknare till bokningsformulär

Utgå från räknarappen som `flutter create` skapar.

1. Byt ut räknaren mot en `HoursPicker`: knappar för − och +, minst 1 och max 4 timmar.
   −-knappen ska vara inaktiverad vid 1 och +-knappen vid 4.
2. Lägg till ett `Form` med:
   - ett `TextFormField` för **namn** (obligatoriskt, minst 2 tecken),
   - ett `TextFormField` för **lägenhetsnummer** (obligatoriskt, exakt 4 siffror,
     använd `RegExp(r'^\d{4}$')`),
   - en `DropdownButtonFormField` för **resurs** (Tvättstuga 1, Tvättstuga 2,
     Festlokalen; obligatorisk),
   - en datumväljare (`showDatePicker`, från idag och högst 14 dagar fram).
3. När användaren trycker på "Boka" och allt är giltigt: visa en `SnackBar` med en
   sammanfattning, t.ex. `"Anna (1102) bokade Tvättstuga 1 den 2026-03-14 i 2 h"`.
4. Om datum saknas: visa ett rött felmeddelande under datumknappen (inte en SnackBar).

Kom ihåg att `dispose`:a dina controllers!

### Övning 2.2 – Lista med navigation till detalj

1. Skapa en lista med minst fem `Resource`-objekt (id, namn, beskrivning, maxHours,
   active) och visa dem i en `ListView.builder` med `ResourceCard` från kapitel 02.
2. När man trycker på ett kort ska en **detaljskärm** öppnas med `Navigator.push`.
   Den visar namn, beskrivning och max-timmar, och har en knapp "Boka".
3. "Boka" öppnar en dialog med en `HoursPicker` (eller `Slider`). När användaren
   bekräftar ska detaljskärmen **stängas och returnera** antalet timmar till listan.
4. Listan visar en `SnackBar`: `"Du bokade Festlokalen i 3 h"`.
5. Inaktiva resurser ska synas i listan men inte gå att öppna.

### Övning 2.3 – Sök och filtrera

Lägg till ett sökfält överst i listan från 2.2 som filtrerar resurserna på namn
medan man skriver, och ett `FilterChip` "Visa bara aktiva". Använd en
`TextEditingController`. Fundera på: var ska state ligga, och vad måste `dispose`:as?

---

## Nivå 3

### Övning 3.1 – Hämta anslag

Bygg en anslagsskärm som hämtar riktiga data.

**Alternativ A – PocketBase (rekommenderas):** Starta PocketBase från modul 02 med
collectionen `posts` (title, body, author, published, created) och några anslag.
Gör listregeln öppen (tom) så att du slipper logga in.

**Alternativ B – öppen JSON-källa:** Använd
`https://jsonplaceholder.typicode.com/posts`, som returnerar en lista med objekt
med `id` (int), `title` och `body`. Anpassa `fromJson`.

Krav:

1. En modellklass `Post` med `fromJson` i `lib/models/post.dart`.
2. En `PostRepository` i `lib/repositories/` med metoden `Future<List<Post>> fetchPosts()`
   som använder `http` (eller `pocketbase`-paketet). Felaktiga statuskoder ska ge ett
   eget undantag.
3. En `PostListScreen` i `lib/screens/` som visar **laddar**, **fel** (med
   "Försök igen") och **data** (med särskild text när listan är tom). Använd antingen
   `FutureBuilder` eller en `sealed class LoadState`.
4. Dra för att uppdatera (`RefreshIndicator`).
5. Tryck på ett anslag → detaljskärm med hela texten.

### Övning 3.2 – Skapa anslag (PocketBase)

Bygg vidare på 3.1:

1. Lägg till en `FloatingActionButton` som öppnar ett formulär för nytt anslag
   (titel obligatorisk, max 80 tecken; text obligatorisk).
2. Spara med `POST` (eller `pb.collection('posts').create`). Visa en
   `CircularProgressIndicator` i knappen medan anropet pågår, och inaktivera knappen
   så att man inte kan skicka två gånger.
3. Vid lyckat resultat: stäng formuläret, returnera det nya anslaget och lägg in
   det **först** i listan utan att hämta om allt.
4. Vid fel: visa felmeddelandet från PocketBase i en `SnackBar` och låt formuläret
   vara kvar.

### Övning 3.3 – Tester

Skriv:

1. enhetstester för `Post.fromJson` (komplett JSON och JSON med fält som saknas),
2. ett enhetstest för `PostRepository.fetchPosts` med `MockClient` som kontrollerar
   att en 500-status ger ditt eget undantag,
3. ett widgettest för formuläret i 3.2 som kontrollerar att felmeddelandet visas när
   titeln är tom.

### Reflektion (inför modul 04)

Gå igenom din kod från nivå 2 och 3 och räkna:

- hur många `StatefulWidget`-klasser du har (två klasser vardera),
- hur många `dispose`-metoder du har skrivit, och om du har glömt någon,
- hur många gånger du skrev `if (!mounted) return;`,
- hur många gånger du skrev `setState(() {})` bara för att "tvinga fram" en ombyggnad.

Spara siffrorna. I [modul 04](../04-flutter-compositions/README.md) skriver du om
en av skärmarna med `flutter_compositions` och jämför.

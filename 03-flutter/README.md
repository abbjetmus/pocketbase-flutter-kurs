# Modul 03 – Flutter

I den här modulen lär du dig grunderna i **Dart** och **Flutter**: hur du bygger
gränssnitt av widgets, hur du hanterar tillstånd (state), navigerar mellan skärmar,
hämtar data från nätet och testar din kod.

Vi bygger vidare på **Kvittra**, den enkla sociala appen från kursens README.
Användare, inlägg, kommentarer, gillningar och följare som du har sett som
SQL-tabeller (modul 01) och PocketBase-collections (modul 02) blir här Dart-klasser
och widgets. Ett flöde med inläggskort, en profilsida, en gilla-knapp och ett
formulär för nya inlägg är exemplen som återkommer i alla kapitel.

För att du ska kunna hämta riktig data från nätet **utan att först sätta upp en
egen server** använder vi den publika test-API:n
[JSONPlaceholder](https://jsonplaceholder.typicode.com). Den har just de delar
Kvittra behöver (`/posts`, `/comments`, `/users`) och svarar med vanlig JSON. I
slutet av kapitel 05 ser du hur samma sak görs mot vår egen PocketBase.

> I nästa modul, [04 – Flutter Compositions](../04-flutter-compositions/README.md),
> byter vi ut en del av det "vanliga" Flutter-sättet att hantera state mot ett
> Vue-liknande sätt. För att förstå *varför* det är skönt behöver du först känna
> till hur vanlig Flutter fungerar, inklusive dess jobbiga delar. Det är den här
> modulens uppgift.

## Lärandemål

Efter modulen ska du kunna:

- skriva Dart-kod med variabler, null safety, samlingar, funktioner, klasser,
  enums, records, patterns och `async`/`await`,
- förklara vad en widget är och hur widgetträdet byggs upp,
- bygga layouter med `Row`, `Column`, `Stack`, `ListView`, `Card` m.fl. och
  förstå Flutters regel för constraints,
- skilja på `StatelessWidget` och `StatefulWidget` och förklara `State`-livscykeln,
- använda controllers (t.ex. `TextEditingController`) och veta varför de måste
  `dispose`:as,
- navigera mellan skärmar med `Navigator` och `go_router`,
- bygga ett formulär med validering, rullgardinsmeny och datum-/tidsväljare,
- hämta JSON med `http`-paketet (från JSONPlaceholder) och med `pocketbase`-paketet,
  och visa laddning/fel/data,
- skriva enkla enhetstester och widgettester.

## Innehåll

| Kapitel | Innehåll |
|---------|----------|
| [01 – Dart-grunder](01-dart-grunder.md) | Variabler, null safety, samlingar, funktioner, klasser, enums, records, patterns, sealed classes, async |
| [02 – Widgets och layout](02-widgets-och-layout.md) | Widgetträdet, Material 3, Row/Column/Stack, listor, constraints, tema, `PostCard` och `ProfileHeader` |
| [03 – State och livscykel](03-state-och-livscykel.md) | Stateless vs Stateful, `setState`, livscykeln, controllers, lyfta state |
| [04 – Navigation och formulär](04-navigation-och-formular.md) | `Navigator`, `go_router`, dialoger, bottom sheets, formulär, validering, datumväljare |
| [05 – Async och nätverk](05-async-och-natverk.md) | `FutureBuilder`, `StreamBuilder`, `http`, JSON från JSONPlaceholder, PocketBase, projektstruktur |
| [06 – Testning](06-testning.md) | Enhetstester, `MockClient` och widgettester |
| [Övningar](ovningar.md) | Övningar i nivå 1–3 |
| [Lösningar](losningar.md) | Lösningsförslag (titta först när du har försökt själv!) |

## Installation

### 1. Installera Flutter SDK

Följ den officiella guiden för ditt operativsystem:
<https://docs.flutter.dev/get-started/install>. Välj den **stabila kanalen**
(stable). Flutter innehåller Dart, så du behöver inte installera Dart separat.
Materialet är skrivet för Flutter 3.35 eller senare.

Kontrollera att allt är på plats:

```bash
flutter --version
flutter doctor
```

`flutter doctor` går igenom din miljö och visar en checklista:

```
Doctor summary (to see all details, run flutter doctor -v):
[✓] Flutter (Channel stable, 3.x.x, ...)
[✓] Android toolchain - develop for Android devices
[✓] Xcode - develop for iOS and macOS
[✓] Chrome - develop for the web
[✓] VS Code
[✓] Connected device (2 available)
```

Du behöver **inte** ha bocken i alla rader. För kursen räcker det med *en*
plattform att köra på: en Android-emulator, en iOS-simulator (bara macOS), Chrome
eller desktop (macOS/Windows/Linux).

⚠️ **Varning:** Om `flutter doctor` klagar på Android-licenser, kör
`flutter doctor --android-licenses` och svara `y` på frågorna.

### 2. VS Code

1. Installera [VS Code](https://code.visualstudio.com/).
2. Installera tilläggen **Flutter** och **Dart** (Flutter-tillägget drar in Dart
   automatiskt).
3. Öppna kommandopaletten (`Cmd/Ctrl + Shift + P`) och skriv `Flutter: New Project`
   om du vill skapa projekt därifrån.

💡 **Tips:** Längst ner till höger i VS Code ser du vilken enhet appen körs på.
Klicka där för att byta mellan emulator, simulator, Chrome och desktop.

### 3. Emulator eller simulator

- **Android-emulator:** Installera [Android Studio](https://developer.android.com/studio),
  öppna *Device Manager* och skapa en virtuell enhet (t.ex. Pixel med senaste
  Android-versionen). Starta den därifrån eller med `flutter emulators --launch <namn>`.
- **iOS-simulator (macOS):** Installera Xcode från App Store och kör sedan
  `open -a Simulator`.
- **Utan emulator:** `flutter run -d chrome` eller `flutter run -d macos`
  (respektive `windows`/`linux`) fungerar bra för att lära sig.

Lista tillgängliga enheter:

```bash
flutter devices
```

## Skapa ditt första projekt

```bash
flutter create kvittra
cd kvittra
flutter run
```

`flutter create` skapar ett komplett projekt med en räknar-app. `flutter run`
bygger och startar den på den enhet som är vald (eller frågar dig vilken).

💡 **Tips:** Projektnamn i Dart skrivs med `snake_case` (små bokstäver och
understreck). `kvittra` eller `kvittra_app` fungerar, `KvittraApp` och `kvittra-app`
gör det inte. Undvik också å, ä och ö i projektnamnet.

### Projektstruktur

```
kvittra/
├── android/          ← native Android-projekt (rör sällan)
├── ios/              ← native iOS-projekt (rör sällan)
├── web/, macos/, ... ← andra plattformar
├── lib/
│   └── main.dart     ← HÄR skriver du din kod. Appen startar i main()
├── test/
│   └── widget_test.dart  ← tester
├── pubspec.yaml      ← projektets namn, version och beroenden (paket)
├── pubspec.lock      ← exakta versioner som installerats (genereras)
└── analysis_options.yaml ← regler för kodanalys (lint)
```

Nästan allt arbete sker i `lib/`. När appen växer delar vi upp den i mappar
(`models/`, `data/`, `screens/`, `widgets/`). Det visar vi i kapitel 05.

### pubspec.yaml

`pubspec.yaml` motsvarar `package.json` i JavaScript-världen:

```yaml
name: kvittra
description: "Kvittra – en enkel social app"
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.9.0

dependencies:
  flutter:
    sdk: flutter
  http: ^1.5.0          # ← paket du lägger till

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true
```

Lägg till paket med kommandot `flutter pub add`, som uppdaterar filen åt dig och
väljer den senaste versionen som passar ditt Flutter:

```bash
flutter pub add http
flutter pub add go_router
```

⚠️ **Varning:** YAML är känsligt för indentering. Använd mellanslag, aldrig tabbar.

## Hot reload vs hot restart

En av Flutters största styrkor är att du ser ändringar nästan direkt.

| | Hot reload | Hot restart | Full restart |
|---|---|---|---|
| Kortkommando (terminal) | `r` | `R` | stoppa och kör `flutter run` igen |
| I VS Code | spara filen (⚡-ikonen) | 🔄 (grön pil) | stoppa + starta |
| Tid | under en sekund | några sekunder | längre |
| **Behåller state?** | **Ja** | Nej, appen börjar om | Nej |
| När behövs det? | Ändrat i `build()`, färger, text | Ändrat i `main()`, `initState`, globala variabler, enums | Ändrat i native-kod eller lagt till paket med native-delar |

**Hot reload** laddar in den nya koden i den körande appen och bygger om
widgetträdet, men behåller tillståndet. Om du har gillat tre inlägg och ändrar
hjärtats färg är inläggen fortfarande gillade.

**Hot restart** startar om Dart-koden från `main()`. Allt state försvinner.

🧪 **Prova själv:** Kör räknarappen från `flutter create`. Tryck på `+` några
gånger. Byt `Colors.deepPurple` mot `Colors.indigo` i `main.dart` och spara. Färgen
byts men räknaren behåller sitt värde. Tryck sedan `R` i terminalen och se att
räknaren börjar om på 0.

💡 **Tips:** Om något beter sig konstigt efter en hot reload, gör en hot restart.
Ändringar i `initState` körs till exempel inte vid hot reload, eftersom den bara
anropas när widgeten skapas första gången.

## Hur du läser modulen

Läs kapitlen i ordning och skriv av kodexemplen själv i stället för att kopiera.
Det går långsammare, men du lär dig mer. Varje kapitel avslutas med något att prova.
När du har läst alla kapitel gör du [övningarna](ovningar.md).

**Nästa kapitel:** [01 – Dart-grunder](01-dart-grunder.md)

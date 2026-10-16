# Modul 03 – Flutter Compositions

I modul 02 skrev du widgets med `StatefulWidget` och `setState()`. Det fungerar,
men koden blir lång. I den här modulen lär du dig paketet
[`flutter_compositions`](https://yoyo930021.github.io/flutter_compositions). Det
gör state i Flutter enklare, och det fungerar nästan som Vue.

I slutet av modulen bygger du en egen **Kvittra-app** som pratar med din
PocketBase från modul 01. Man kan logga in, läsa flödet, skriva inlägg,
kommentera, gilla och följa andra.

## Det här kan du efter modulen

- Förklara hur en `CompositionWidget` fungerar: `setup()` körs en gång, och
  builder-funktionen körs om när något ändras
- Använda `ref`, `computed`, `watch` och `watchEffect`
- Använda `onMounted` och `onUnmounted`, till exempel för en timer
- Ta emot props med `widget()` och skriva en egen composable
- Logga in och hämta, skapa och ta bort data i PocketBase från Flutter
- Dela PocketBase och den inloggade användaren med `provide` och `inject`
- Visa laddning, fel och data med `useAsyncData` och `AsyncValue`
- Bygga en hel liten app med flera sidor

## Upplägg

### Del 1 – Grunderna

| Kapitel | Vad du gör |
|---------|------------|
| [01 – Introduktion](01-introduktion.md) | Ser varför vi byter från `setState` och skriver din första `CompositionWidget` |
| [02 – ref och computed](02-ref-och-computed.md) | Lär dig reaktivt state och bygger ett flöde med filter och sök |
| [03 – watch och livscykel](03-watch-och-livscykel.md) | Reagerar på ändringar och startar och stoppar en timer |
| [04 – Props och composables](04-props-och-composables.md) | Bygger ett inläggskort, ett kommentarsfält och en egen composable |

### Del 2 – Prata med PocketBase

| Kapitel | Vad du gör |
|---------|------------|
| [05 – Skriva data och realtid](05-skriva-data-och-realtid.md) | Filtrerar, skapar, ändrar och tar bort data, och lyssnar på ändringar |
| [06 – Provide och inject](06-provide-inject.md) | Delar PocketBase och den inloggade användaren med hela appen |
| [07 – Hämta data](07-hamta-data.md) | Visar flödet med `useAsyncData`, kommentarer i realtid och gilla-knappen |

### Del 3 – Bygg appen

| Kapitel | Vad du gör |
|---------|------------|
| [08 – Bygg Kvittra-appen](08-bygg-kvittra-appen.md) | Bygger hela appen steg för steg |

Varje kapitel slutar med övningar. Lösningsförslag finns i
[losningar.md](losningar.md). Försök själv först!

## Det här behöver du

- **Modul 02:** widgets, layout, `StatefulWidget`, `setState`, `go_router` och
  formulär, och att hämta data från PocketBase ([kapitel 6](../02-flutter/06-hamta-data-fran-pocketbase.md)).
- **Modul 01:** din egen PocketBase med Kvittras collections (`users`, `posts`,
  `comments`, `likes` och `follows`), testdatan och API-reglerna.
- Flutter och VS Code från modul 02.
- Vue behövs inte. Kan du lite Vue känner du igen mycket.

Vi kör appen i **Chrome** på Windows. Det är enklast, och appen når din
PocketBase på `http://127.0.0.1:8090` direkt.

## Installation

### 1. Skapa ett projekt

Öppna en terminal i mappen där du vill ha projektet:

```powershell
flutter create kvittra
cd kvittra
```

### 2. Lägg till paketen

```powershell
flutter pub add flutter_compositions:^0.1.1 pocketbase go_router
```

| Paket | Används till |
|-------|--------------|
| `flutter_compositions` | Reaktivt state, som i Vue. Vi använder version **0.1.x** |
| `pocketbase` | Prata med din PocketBase (som i modul 02) |
| `go_router` | Flera sidor i appen (som i modul 02) |

⚠️ Skriv `:^0.1.1` efter `flutter_compositions`. Nyare versioner (0.2 och
uppåt) fungerar lite annorlunda än det som står här.

### 3. Testa att det fungerar

Ersätt allt i `lib/main.dart` med:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

void main() => runApp(const MaterialApp(home: HelloKvittra()));

class HelloKvittra extends CompositionWidget {
  const HelloKvittra({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final likes = ref(0);

    return (context) => Scaffold(
          body: Center(child: Text('Gillningar: ${likes.value}')),
          floatingActionButton: FloatingActionButton(
            onPressed: () => likes.value++,
            child: const Icon(Icons.favorite),
          ),
        );
  }
}
```

Kör appen i Chrome:

```powershell
flutter run -d chrome
```

Tryck på hjärtat. Siffran ökar, fast du inte har skrivit något `setState`. Hur
det fungerar går vi igenom i [kapitel 1](01-introduktion.md).

## Snabbreferens

| Du vill … | Skriv |
|-----------|-------|
| Skapa state | `final n = ref(0);` |
| Läsa och ändra state | `n.value` och `n.value++` |
| Räkna fram ett värde | `final dubbel = computed(() => n.value * 2);` |
| Göra något när ett värde ändras | `watch(() => n.value, (nytt, gammalt) { … });` |
| Köra kod när widgeten visas och försvinner | `onMounted(() { … });` och `onUnmounted(() { … });` |
| Läsa props | `final props = widget();` och `props.value.title` |
| Textfält | `final (controller, text, _) = useTextEditingController();` |
| Dela något med hela appen | `provide(key, värde);` och `inject(key);` |
| Hämta data | `final (status, refresh) = useAsyncData(…);` |

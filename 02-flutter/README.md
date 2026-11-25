# Modul 02 – Flutter

I den här modulen lär du dig **Flutter** och språket **Dart**. Vi skriver alla
widgets med paketet
[`flutter_compositions`](https://yoyo930021.github.io/flutter_compositions). Det
gör att state i Flutter fungerar nästan som i Vue.

Du bygger **Kvittra**, den enkla sociala appen från modul 01. Först med
påhittade inlägg, sedan mot din egen PocketBase. I slutet av modulen har du en
enkel app som du kan visa upp: man kan läsa flödet, gilla, skriva inlägg och
kommentera.

**Flutter** är ett verktyg från Google för att bygga appar. Du skriver koden
**en** gång, och sedan kan appen köras på Android, iPhone, i webbläsaren och på
Windows.

I den här modulen kör vi **bara Flutter för webben**. Du skriver koden i VS Code
på din egen dator och kör appen i Chrome. Din PocketBase körs också på din
dator. Du behöver inte Android Studio, och du ser dina ändringar direkt. Koden
är samma som i en mobilapp.

## Det här kan du efter modulen

- Installera Flutter, skapa ett projekt och köra det i Chrome
- Skriva enkel Dart-kod: variabler, listor, funktioner och klasser
- Bygga ett gränssnitt av widgets, till exempel ett kort som visar ett inlägg
- Förklara hur en `CompositionWidget` fungerar: `setup()` körs en gång, och
  builder-funktionen körs om när något ändras
- Ta emot props med `widget()`
- Använda `ref`, ändra listor och göra ett textfält
- Använda `onMounted` och `onUnmounted`, till exempel för en timer
- Navigera mellan skärmar och bygga ett formulär med kontroll av det man skriver
- Hämta, skapa och ta bort data i PocketBase från Flutter
- Visa laddning, fel och data med `useAsyncData` och `AsyncValue`
- Bygga en liten app med tre sidor

## Upplägg

### Del 1 – Grunderna

| Kapitel | Vad du gör |
|---------|------------|
| [01 – Kom igång](01-kom-igang.md) | Installerar Flutter, skapar projektet `kvittra` och kör det i Chrome |
| [02 – Dart-grunder](02-dart-grunder.md) | Lär dig språket Dart och skriver klassen `Post` |
| [03 – Widgets och layout](03-widgets-och-layout.md) | Bygger ett `PostCard` med props och ett flöde med inlägg |

### Del 2 – State

| Kapitel | Vad du gör |
|---------|------------|
| [04 – State och interaktion](04-state-och-interaktion.md) | Gör en gilla-knapp och lär dig hur en `CompositionWidget` fungerar |
| [05 – ref och listor](05-ref-och-listor.md) | Lär dig mer om `ref` och listor, bygger ett flöde med filter och sök och gör ett kommentarsfält |
| [06 – Livscykel](06-livscykel.md) | Startar och stoppar en timer med `onMounted` och `onUnmounted` |
| [07 – Navigation och formulär](07-navigation-och-formular.md) | Lägger till fler skärmar och ett formulär för nya inlägg |

### Del 3 – Prata med PocketBase

| Kapitel | Vad du gör |
|---------|------------|
| [08 – Hämta data från PocketBase](08-hamta-data-fran-pocketbase.md) | Öppnar databasen och hämtar Kvittras inlägg från din PocketBase |
| [09 – Skriva data och realtid](09-skriva-data-och-realtid.md) | Filtrerar, skapar, ändrar och tar bort data, och lyssnar på ändringar |
| [10 – Ladda om och realtid](10-ladda-om-och-realtid.md) | Laddar om, visar kommentarer i realtid och gör gilla-knappen snabb |

### Del 4 – Bygg appen

| Kapitel | Vad du gör |
|---------|------------|
| [11 – Bygg Kvittra-appen](11-bygg-kvittra-appen.md) | Bygger ihop en enkel app med tre sidor som du kan visa upp |

Varje kapitel slutar med övningar. Lösningsförslag finns i
[losningar.md](losningar.md). Försök själv först!

## Det här behöver du

- En Windows-dator
- Internet, för att ladda ner Flutter
- Din PocketBase från modul 01, med Kvittras collections (`users`, `posts`,
  `comments`, `likes` och `follows`) och testdatan. API-reglerna öppnar du i
  kapitel 8, så att appen inte behöver logga in
- Webbläsaren **Chrome**. Där kör vi appen under hela modulen, och den når din
  PocketBase på `http://127.0.0.1:8090` direkt
- VS Code, Git och Flutter, som du installerar i kapitel 1. Du behöver **inte**
  Android Studio eller Visual Studio

💡 **Kan du lite JavaScript eller Vue?** Då känner du igen mycket. Vi jämför med
Vue här och där, men du behöver inte kunna det.

## Paketen

| Paket | Används till | Installeras i |
|-------|--------------|---------------|
| `flutter_compositions` | Reaktivt state, som i Vue. Vi använder version **0.2.6** | Kapitel 1 |
| `go_router` | Flera sidor i appen | Kapitel 7 |
| `pocketbase` | Prata med din PocketBase | Kapitel 8 |

## Snabbreferens

| Du vill … | Skriv |
|-----------|-------|
| Skapa state | `final n = ref(0);` |
| Läsa och ändra state | `n.value` och `n.value++` |
| Räkna fram ett värde | Direkt i builder-funktionen: `Text('${n.value * 2}')` |
| Köra kod när widgeten visas och försvinner | `onMounted(() { … });` och `onUnmounted(() { … });` |
| Läsa props | `final props = widget();` och `props.value.title` |
| Textfält | `final (controller, text, _) = useTextEditingController();` |
| Hämta data | `final (status, refresh) = useAsyncData(…);` |

Nästa kapitel: [Kom igång](01-kom-igang.md)

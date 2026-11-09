# Modul 02 – Flutter

I den här modulen lär du dig **Flutter** och språket **Dart**. Vi skriver alla
widgets med paketet
[`flutter_compositions`](https://yoyo930021.github.io/flutter_compositions). Det
gör att state i Flutter fungerar nästan som i Vue.

Du bygger **Kvittra**, den enkla sociala appen från modul 01. Först med
påhittade inlägg, sedan mot din egen PocketBase. I slutet av modulen har du en
hel app där man kan logga in, läsa flödet, skriva inlägg, kommentera, gilla och
följa andra.

**Flutter** är ett verktyg från Google för att bygga appar. Du skriver koden
**en** gång, och sedan kan appen köras på Android, iPhone, i webbläsaren och på
Windows.

## Det här kan du efter modulen

- Installera Flutter, skapa ett projekt och köra det i Chrome
- Skriva enkel Dart-kod: variabler, listor, funktioner och klasser
- Bygga ett gränssnitt av widgets, till exempel ett kort som visar ett inlägg
- Förklara hur en `CompositionWidget` fungerar: `setup()` körs en gång, och
  builder-funktionen körs om när något ändras
- Använda `ref`, `computed`, `watch` och `watchEffect`
- Använda `onMounted` och `onUnmounted`, till exempel för en timer
- Ta emot props med `widget()` och skriva en egen composable
- Navigera mellan skärmar och bygga ett formulär med kontroll av det man skriver
- Logga in och hämta, skapa och ta bort data i PocketBase från Flutter
- Dela PocketBase och den inloggade användaren med `provide` och `inject`
- Visa laddning, fel och data med `useAsyncData` och `AsyncValue`
- Bygga en hel liten app med flera sidor

## Upplägg

### Del 1 – Grunderna

| Kapitel | Vad du gör |
|---------|------------|
| [01 – Kom igång](01-kom-igang.md) | Installerar Flutter, skapar projektet `kvittra` och kör det i Chrome |
| [02 – Dart-grunder](02-dart-grunder.md) | Lär dig språket Dart och skriver klassen `Post` |
| [03 – Widgets och layout](03-widgets-och-layout.md) | Bygger ett `PostCard` och ett flöde med inlägg |

### Del 2 – State

| Kapitel | Vad du gör |
|---------|------------|
| [04 – State och interaktion](04-state-och-interaktion.md) | Gör en gilla-knapp och lär dig hur en `CompositionWidget` fungerar |
| [05 – ref och computed](05-ref-och-computed.md) | Lär dig reaktivt state och bygger ett flöde med filter och sök |
| [06 – watch och livscykel](06-watch-och-livscykel.md) | Reagerar på ändringar och startar och stoppar en timer |
| [07 – Props och composables](07-props-och-composables.md) | Bygger ut inläggskortet, gör ett kommentarsfält och en egen composable |
| [08 – Navigation och formulär](08-navigation-och-formular.md) | Lägger till fler skärmar och ett formulär för nya inlägg |

### Del 3 – Prata med PocketBase

| Kapitel | Vad du gör |
|---------|------------|
| [09 – Hämta data från PocketBase](09-hamta-data-fran-pocketbase.md) | Loggar in och hämtar Kvittras inlägg från din PocketBase |
| [10 – Skriva data och realtid](10-skriva-data-och-realtid.md) | Filtrerar, skapar, ändrar och tar bort data, och lyssnar på ändringar |
| [11 – Provide och inject](11-provide-inject.md) | Delar PocketBase och den inloggade användaren med hela appen |
| [12 – Ladda om och realtid](12-ladda-om-och-realtid.md) | Hämtar igen när något ändras, visar kommentarer i realtid och gör gilla-knappen snabb |

### Del 4 – Bygg appen

| Kapitel | Vad du gör |
|---------|------------|
| [13 – Bygg Kvittra-appen](13-bygg-kvittra-appen.md) | Bygger hela appen steg för steg |

Varje kapitel slutar med övningar. Lösningsförslag finns i
[losningar.md](losningar.md). Försök själv först!

## Det här behöver du

- En Windows-dator (det går lika bra med Mac eller Linux)
- Internet, för att ladda ner Flutter
- Din PocketBase från modul 01, med Kvittras collections (`users`, `posts`,
  `comments`, `likes` och `follows`), testdatan och API-reglerna
- Webbläsaren **Chrome**. Där kör vi appen under hela modulen, och den når din
  PocketBase på `http://127.0.0.1:8090` direkt
- VS Code och Flutter, som du installerar i kapitel 1

💡 **Kan du lite JavaScript eller Vue?** Då känner du igen mycket. Vi jämför med
Vue här och där, men du behöver inte kunna det.

## Paketen

| Paket | Används till | Installeras i |
|-------|--------------|---------------|
| `flutter_compositions` | Reaktivt state, som i Vue. Vi använder version **0.1.x** | Kapitel 1 |
| `go_router` | Flera sidor i appen | Kapitel 8 |
| `pocketbase` | Prata med din PocketBase | Kapitel 9 |

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

Nästa kapitel: [Kom igång](01-kom-igang.md)

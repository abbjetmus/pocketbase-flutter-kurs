# Modul 02 – Flutter

I den här modulen lär du dig grunderna i **Flutter** och språket **Dart**. Du
bygger en första version av **Kvittra**, den enkla sociala appen från modul 01:
ett flöde med inlägg, en gilla-knapp, kommentarer och ett formulär för nya
inlägg. I sista kapitlet hämtar appen riktiga inlägg från din egen PocketBase
från modul 01.

**Flutter** är ett verktyg från Google för att bygga appar. Du skriver koden
**en** gång, och sedan kan appen köras på Android, iPhone, i webbläsaren och på
Windows.

## Det här kan du efter modulen

- Installera Flutter, skapa ett projekt och köra det i Chrome
- Skriva enkel Dart-kod: variabler, listor, funktioner och klasser
- Bygga ett gränssnitt av widgets, till exempel ett kort som visar ett inlägg
- Göra appen interaktiv med `StatefulWidget` och `setState`
- Navigera mellan skärmar och bygga ett formulär med kontroll av det man skriver
- Logga in i PocketBase och visa inläggen därifrån i appen

## Upplägg

| Kapitel | Vad du gör |
|---------|------------|
| [01 – Kom igång](01-kom-igang.md) | Installerar Flutter, skapar projektet `kvittra` och kör det i Chrome |
| [02 – Dart-grunder](02-dart-grunder.md) | Lär dig språket Dart och skriver klassen `Post` |
| [03 – Widgets och layout](03-widgets-och-layout.md) | Bygger ett `PostCard` och ett flöde med inlägg |
| [04 – State och interaktion](04-state-och-interaktion.md) | Gör en gilla-knapp och ett kommentarsfält som fungerar |
| [05 – Navigation och formulär](05-navigation-och-formular.md) | Lägger till fler skärmar och ett formulär för nya inlägg |
| [06 – Hämta data från PocketBase](06-hamta-data-fran-pocketbase.md) | Loggar in och hämtar Kvittras inlägg från din PocketBase |

Varje kapitel slutar med övningar. Lösningsförslag finns i
[losningar.md](losningar.md). Försök själv först!

## Det här behöver du

- En Windows-dator (det går lika bra med Mac eller Linux)
- Internet, för att ladda ner Flutter
- Din PocketBase med Kvittra från modul 01 (används i kapitel 6)
- Webbläsaren **Chrome**. Där kör vi appen under hela modulen
- VS Code och Flutter, som du installerar i kapitel 1

💡 **Kan du lite JavaScript eller Vue?** Då känner du igen mycket. Vi jämför med
JavaScript här och där, men du behöver inte kunna det.

## Sedan då?

I [modul 03 – Flutter Compositions](../03-flutter-compositions/README.md) gör vi
appen enklare att skriva, med ett sätt som liknar Vue. Där bygger vi också
vidare på PocketBase: inloggning, nya inlägg, likes och mycket mer.

Nästa kapitel: [Kom igång](01-kom-igang.md)

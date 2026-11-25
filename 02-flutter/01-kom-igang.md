# 1. Kom igång

I det här kapitlet skapar du ett konto på FlutLab, skapar projektet `kvittra`
och kör det i webbläsaren. När du är klar har du en app som körs, och du vet
hur du ser dina ändringar direkt.

## Vad är Flutter?

**Flutter** är ett verktyg för att bygga appar. Koden skrivs i språket
**Dart**. Samma kod kan sedan köras på många ställen:

```
                ┌──────────────┐
                │  Din kod     │
                │  (lib/*.dart)│
                └──────┬───────┘
      ┌──────────┬─────┴────┬──────────┐
      ▼          ▼          ▼          ▼
   Android    iPhone     Webben    Windows
```

I den här kursen använder vi **bara webben**. Vi skriver och kör koden i
**FlutLab**, en editor för Flutter som finns direkt i webbläsaren. Det har tre
fördelar:

- Du behöver **inte** installera något. Allt du behöver är **Chrome**.
- Appen startar snabbt, och du ser dina ändringar direkt.
- Det fungerar likadant på alla datorer, och du kommer åt dina projekt
  hemifrån också.

Koden du skriver är samma som i en mobilapp. Vill du senare köra appen på en
telefon behöver du inte skriva om den.

## Steg 1 – Skapa ett konto

1. Öppna <https://flutlab.io> i Chrome.
2. Skapa ett konto. Det enklaste är att logga in med ditt Google- eller
   GitHub-konto.
3. Gå till <https://flutlab.io/editor>. Där ser du dina projekt.

## Steg 2 – Skapa projektet

1. Skapa ett nytt projekt.
2. Ge det namnet `kvittra`.

Projektet öppnas. Till vänster ser du projektets filer, i mitten koden och till
höger appen när den körs.

⚠️ **Projektnamn** skrivs med små bokstäver och `_` mellan orden, till exempel
`kvittra` eller `kvittra_app`. Namn som `Kvittra-App` eller `kvittra_åäö`
fungerar inte.

## Steg 3 – Kör appen

1. Välj **Web** som plattform i verktygsfältet längst upp.
2. Klicka **Build**.

Första gången tar det en stund. När appen är byggd startar **Web Emulator**,
och du ser en exempelapp. Då vet du att allt fungerar.

## Steg 4 – Lägg till Flutter Compositions

I den här kursen skriver vi alla widgets med paketet
[`flutter_compositions`](https://yoyo930021.github.io/flutter_compositions). Det
gör det enkelt att bygga appar som ändrar sig, och det fungerar nästan som Vue.

Öppna först filen **pubspec.yaml**. Leta upp `environment:` och ändra den så
att den ser ut så här:

```yaml
environment:
  sdk: ^3.11.0
  flutter: ">=3.41.0"
```

Spara med `Ctrl + S`.

⚠️ **Indraget räknas.** I `pubspec.yaml` är det mellanslagen i början av raden
som visar vad som hör ihop. Använd två mellanslag, aldrig tab.

Lägg sedan till paketet. Det gör du i panelen längst ner:

1. Välj fliken **Pub Commands**.
2. Klicka **pub add** och skriv:

   ```
   flutter_compositions:^0.2.6
   ```

3. Klicka **pub get**. Vänta tills det står **Process finished successfully**.

⚠️ Skriv `:^0.2.6` efter namnet. Då får du version 0.2.6 eller en senare
0.2-version, men inte 0.3. Version 0.3 kan fungera annorlunda än det som står
här.

Öppna nu `lib/main.dart`. Ta bort allt i filen och skriv det här i stället:

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

void main() => runApp(const HelloKvittra());

class HelloKvittra extends CompositionWidget {
  const HelloKvittra({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final likes = ref(0);

    return (context) => MaterialApp(
          theme: ThemeData(colorSchemeSeed: Colors.deepPurple),
          home: Scaffold(
            appBar: AppBar(title: const Text('Hej Kvittra')),
            body: Center(child: Text('Gillningar: ${likes.value}')),
            floatingActionButton: FloatingActionButton(
              onPressed: () => likes.value++,
              child: const Icon(Icons.favorite),
            ),
          ),
        );
  }
}
```

Klicka **Build** och tryck på hjärtat. Siffran ökar. Hur koden fungerar går vi
igenom i kapitel 3 och 4.

⚠️ Visar FlutLab ett rött fel i filen `test/widget_test.dart`? Den filen letar
efter exempelappen som du tog bort. Vi använder den inte, så du kan ta bort hela
mappen `test`.

## Hot reload – se ändringar direkt

Låt appen vara igång. Byt `Colors.deepPurple` till `Colors.green` i
`lib/main.dart`. Klicka sedan **Hot Reload**.

Färgen byts direkt, och siffran är kvar. Det kallas **hot reload**.

| | Hot reload | Hot restart |
|---|---|---|
| Så gör du | Klicka **Hot Reload** | Klicka **Build** igen |
| Vad händer | Ändringen syns, appen fortsätter där den var | Appen startar om från början |
| Siffran | Är kvar | Blir 0 igen |

💡 Om något beter sig konstigt efter en ändring, gör en **hot restart**.

💡 Har du lagt till ett paket? Klicka **Build**. Hot reload räcker inte då.

## Projektets filer

```
kvittra/
├── lib/
│   └── main.dart      ← HÄR skriver du din kod. Appen startar här
├── pubspec.yaml       ← appens namn och vilka paket den använder
├── web/               ← filer för webben, till exempel index.html (rör dem inte)
└── ...                ← andra mappar, till exempel android/ (rör dem inte)
```

Nästan allt arbete sker i mappen `lib/`. Nya filer och mappar skapar du i
filträdet till vänster. Högerklicka på mappen där filen ska ligga, till exempel
`lib`.

**pubspec.yaml** liknar `package.json` i JavaScript. Där står vilka **paket**
appen använder. Ett paket är kod som någon annan har skrivit, och du hittar dem
på <https://pub.dev>. När du klickar **pub add** skrivs paketet in i
`pubspec.yaml` åt dig. Det gör vi igen i kapitel 7 och 8.

## Se vad appen skriver ut

Med `print` och `debugPrint` kan appen skriva ut text, till exempel för att du
ska se vad som händer. Texten syns i Chromes **konsol**. Tryck `F12` och välj
fliken **Console**.

## Alternativ: Flutter för webben i VS Code

Vill du hellre skriva koden i **VS Code** på din egen dator? Det går också. Du
behöver bara Flutter för webben, så du behöver **inte** Android Studio eller
Visual Studio.

1. **Installera tillägget Flutter.** Öppna VS Code och klicka på
   **Extensions** till vänster (fyra rutor), eller tryck `Ctrl + Shift + X`.
   Sök på **Flutter** och klicka **Install** på tillägget från *Dart Code*.
2. **Skapa ett projekt.** Tryck `Ctrl + Shift + P` och skriv
   `Flutter: New Project`. VS Code säger att den inte hittar Flutter. Klicka
   **Download SDK** och välj en mapp, till exempel `C:\Users\dittnamn\dev`.
3. **Lägg Flutter i PATH.** När nedladdningen är klar frågar VS Code om
   Flutter ska läggas i **PATH**. Klicka **Add SDK to PATH**. Då hittar
   terminalen kommandot `flutter`.
4. **Starta om VS Code.** Stäng VS Code och öppna det igen.
5. **Skapa projektet igen.** Tryck `Ctrl + Shift + P`, välj
   `Flutter: New Project` och sedan **Application**. Välj en mapp och skriv
   namnet `kvittra`.
6. **Välj Chrome.** Längst ner till höger i VS Code står vilken enhet appen
   körs på. Klicka där och välj **Chrome**.
7. **Kör appen.** Tryck `F5`. Efter en stund öppnas Chrome med exempelappen.
8. **Lägg till paketet.** Öppna en terminal med **Terminal → New Terminal** och
   skriv:

   ```powershell
   flutter pub add flutter_compositions:^0.2.6
   ```

Sedan gör du som i steg 4 ovan: byt ut koden i `lib/main.dart` och tryck `F5`.

⚠️ **Välj en enkel mapp för Flutter.** Den får inte ligga i
`C:\Program Files`, och sökvägen ska inte innehålla mellanslag eller å, ä, ö.

💡 Säger VS Code att **Git** saknas? Installera **Git for Windows** från
<https://git-scm.com/downloads/win> och klicka **Next** på alla frågor. Starta
sedan om VS Code.

Resten av kursen beskriver knapparna i FlutLab. I VS Code gör du så här:

| I FlutLab | I VS Code |
|-----------|-----------|
| **Build** | `F5` |
| **Hot Reload** | Spara filen med `Ctrl + S` |
| **Build** igen (hot restart) | Den gröna runda pilen högst upp |
| **Pub Commands** → **pub add** → **pub get** | `flutter pub add namn` i terminalen |
| Högerklicka i filträdet | Högerklicka i **Explorer** till vänster |

## Kom ihåg

| Du vill … | Gör så här |
|-----------|------------|
| Öppna dina projekt | <https://flutlab.io/editor> |
| Köra appen | Välj **Web** och klicka **Build** |
| Se en ändring | **Hot Reload** |
| Starta om appen från början | **Build** igen (hot restart) |
| Lägga till ett paket | **Pub Commands** → **pub add** → **pub get**, sedan **Build** |
| Skapa en fil | Högerklicka på mappen i filträdet till vänster |
| Se det appen skriver ut | `F12` → **Console** |

Nästa kapitel: [Dart-grunder](02-dart-grunder.md)

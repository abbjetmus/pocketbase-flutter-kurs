# 1. Kom igång

I det här kapitlet installerar du Flutter, skapar projektet `kvittra` och kör
det i Chrome. När du är klar har du en app som körs, och du vet
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

I den här kursen använder vi **bara webben**. Du skriver koden i **VS Code** på
din egen dator, och appen körs i **Chrome**. Det har tre fördelar:

- Du behöver **inte** installera Android Studio eller Xcode. De är stora program
  och tar lång tid att installera.
- Appen startar snabbt, och du ser dina ändringar direkt.
- Appen och din PocketBase körs på samma dator, så de hittar varandra direkt.

Koden du skriver är samma som i en mobilapp. Vill du senare köra appen på en
telefon behöver du inte skriva om den.

## Steg 1 – Installera VS Code och Chrome

1. Ladda ner och installera **VS Code** från <https://code.visualstudio.com/>.
2. Har du inte **Chrome** installerar du det från <https://www.google.com/chrome/>.

## Steg 2 – Installera tillägget Flutter

1. Öppna VS Code. Klicka på **Extensions** till vänster (fyra rutor), eller
   tryck `Ctrl + Shift + X`.
2. Sök på **Flutter** och klicka **Install** på tillägget från *Dart Code*. Då
   installeras tillägget *Dart* också.

## Steg 3 – Ladda ner Flutter och lägg det i PATH

Det enklaste är att låta VS Code ladda ner Flutter åt dig.

1. Tryck `Ctrl + Shift + P`. Då öppnas **kommandopaletten**, en ruta där du kan
   skriva kommandon.
2. Skriv `Flutter: New Project` och tryck Enter.
3. VS Code säger att den inte hittar Flutter. Klicka **Download SDK**.
4. Välj en mapp, till exempel `C:\Users\dittnamn\dev`. Det tar några minuter.
5. När VS Code frågar om du vill lägga till Flutter i **PATH**, klicka
   **Add SDK to PATH**. Då hittar terminalen kommandot `flutter`.
6. Stäng VS Code och öppna det igen.

💡 Frågar VS Code efter nedladdningen vilken sorts projekt du vill skapa? Tryck
`Esc`. Vi skapar projektet i steg 5.

⚠️ **Välj en enkel mapp.** Mappen får inte ligga i `C:\Program Files`, och
sökvägen ska inte innehålla mellanslag eller å, ä, ö.

## Steg 4 – Bara webben

Flutter vill gärna bygga appar för Android och Windows också. Det behöver vi
inte. Öppna en terminal i VS Code med **Terminal → New Terminal** och skriv:

```powershell
flutter config --no-enable-android --no-enable-windows-desktop
```

Kontrollera sedan att allt är rätt installerat:

```powershell
flutter doctor
```

Raderna **Flutter**, **Chrome** och **VS Code** ska ha ✓. Det räcker för
kursen.

💡 Står det ✗ vid **Android toolchain** eller **Visual Studio**? Kör kommandot
`flutter config` ovan igen. Du ska **inte** installera de programmen.

## Steg 5 – Skapa projektet

Gå till mappen där projektet ska ligga och skapa projektet i terminalen:

```powershell
cd ~\Documents
flutter create --platforms web kvittra
cd kvittra
code .
```

`--platforms web` betyder att projektet bara görs för webben. Det sista
kommandot, `code .`, öppnar projektet i VS Code.

⚠️ **Projektnamn** skrivs med små bokstäver och `_` mellan orden, till exempel
`kvittra` eller `kvittra_app`. Namn som `Kvittra-App` eller `kvittra_åäö`
fungerar inte.

## Steg 6 – Kör appen

1. Längst ner till höger i VS Code står vilken **enhet** appen körs på. Klicka
   där och välj **Chrome**.
2. Tryck `F5` (eller **Run → Start Debugging**).

Första gången tar det en stund. Sedan öppnas Chrome med en exempelapp, och du
vet att allt fungerar. Stoppa appen med den röda fyrkanten i VS Code.

## Steg 7 – Lägg till Flutter Compositions

I den här kursen skriver vi alla widgets med paketet
[`flutter_compositions`](https://yoyo930021.github.io/flutter_compositions). Det
gör det enkelt att bygga appar som ändrar sig, och det fungerar nästan som Vue.
Skriv i terminalen:

```powershell
flutter pub add flutter_compositions:^0.2.6
```

⚠️ Skriv `:^0.2.6` efter namnet. Då får du version 0.2.6 eller en senare
0.2-version, men inte 0.3. Version 0.3 kan fungera annorlunda än det som står
här.

💡 Får du ett fel om att paketet kräver en nyare **SDK version**? Då är din
Flutter för gammal. Skriv `flutter upgrade` och försök igen.

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

Tryck `F5` och sedan på hjärtat. Siffran ökar. Hur koden fungerar går vi
igenom i kapitel 3 och 4.

⚠️ Visar VS Code ett rött fel i filen `test/widget_test.dart`? Den filen letar
efter exempelappen som du tog bort. Vi använder den inte, så du kan ta bort hela
mappen `test`.

## Hot reload – se ändringar direkt

Låt appen vara igång. Byt `Colors.deepPurple` till `Colors.green` i
`lib/main.dart` och spara med `Ctrl + S`.

Färgen byts direkt, och siffran är kvar. Det kallas **hot reload**.

| | Hot reload | Hot restart |
|---|---|---|
| Så gör du | Spara filen (`Ctrl + S`) | Klicka på den gröna runda pilen i VS Code |
| Vad händer | Ändringen syns, appen fortsätter där den var | Appen startar om från början |
| Siffran | Är kvar | Blir 0 igen |

💡 Om något beter sig konstigt efter en ändring, gör en **hot restart**.

💡 Har du lagt till ett paket? Stoppa appen och starta den igen med `F5`. Hot
reload räcker inte då.

## Projektets filer

```
kvittra/
├── lib/
│   └── main.dart      ← HÄR skriver du din kod. Appen startar här
├── pubspec.yaml       ← appens namn och vilka paket den använder
├── web/               ← filer för webben, till exempel index.html (rör dem inte)
└── ...
```

Nästan allt arbete sker i mappen `lib/`. Nya filer och mappar skapar du i
**Explorer** till vänster i VS Code. Högerklicka på mappen där filen ska ligga,
till exempel `lib`.

**pubspec.yaml** liknar `package.json` i JavaScript. Där står vilka **paket**
appen använder. Ett paket är kod som någon annan har skrivit, och du hittar dem
på <https://pub.dev>. När du skriver `flutter pub add namn` skrivs paketet in
i `pubspec.yaml` åt dig. Det gör vi igen i kapitel 7 och 8.

## Se vad appen skriver ut

Med `print` och `debugPrint` kan appen skriva ut text, till exempel för att du
ska se vad som händer. Texten syns i VS Code, i fliken **Debug Console**
längst ner.

## Kom ihåg

| Du vill … | Gör så här |
|-----------|------------|
| Öppna kommandopaletten | `Ctrl + Shift + P` |
| Skapa ett projekt | `flutter create --platforms web namn` |
| Välja Chrome | Klicka på enheten längst ner till höger |
| Köra appen | `F5` |
| Se en ändring | Spara (`Ctrl + S`) = hot reload |
| Starta om appen från början | Den gröna runda pilen (hot restart) |
| Lägga till ett paket | `flutter pub add namn` i terminalen |
| Se det appen skriver ut | **Debug Console** i VS Code |
| Stoppa appen | Den röda fyrkanten i VS Code |

Nästa kapitel: [Dart-grunder](02-dart-grunder.md)

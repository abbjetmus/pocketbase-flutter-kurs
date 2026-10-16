# 1. Kom igång

I det här kapitlet installerar du Flutter, skapar projektet `kvittra` och kör
det i Chrome. När du är klar har du en app som körs, och du vet hur du ser
dina ändringar direkt.

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

Vi kör appen i **Chrome** under hela modulen. Det kräver minst installation,
och det fungerar på alla datorer.

## Steg 1 – Installera Git och VS Code

Flutter behöver programmet **Git** för att laddas ner.

1. Ladda ner och installera **Git for Windows** från <https://git-scm.com/downloads/win>.
   Du kan klicka **Next** på alla frågor.
2. Ladda ner och installera **VS Code** från <https://code.visualstudio.com/>.
3. Öppna VS Code. Klicka på ikonen **Extensions** till vänster (fyra rutor),
   eller tryck `Ctrl + Shift + X`.
4. Sök på **Flutter** och klicka **Install** på tillägget från *Dart Code*. Då
   installeras tillägget *Dart* också.

## Steg 2 – Ladda ner Flutter via VS Code

Det enklaste är att låta VS Code ladda ner Flutter åt dig.

1. Tryck `Ctrl + Shift + P`. Då öppnas **kommandopaletten**, en ruta där du kan
   skriva kommandon.
2. Skriv `Flutter: New Project` och tryck Enter.
3. VS Code säger att den inte hittar Flutter. Klicka **Download SDK**.
4. Välj en mapp, till exempel `C:\Users\dittnamn\dev`. Det tar några minuter.
5. När VS Code frågar om du vill lägga till Flutter i **PATH**, klicka
   **Add SDK to PATH**. Då hittar terminalen kommandot `flutter`.
6. Stäng VS Code och öppna det igen.

⚠️ **Välj en enkel mapp.** Mappen får inte ligga i `C:\Program Files`, och
sökvägen ska inte innehålla mellanslag eller å, ä, ö.

💡 **Om det inte fungerar:** Följ den officiella guiden på
<https://docs.flutter.dev/get-started/install/windows>. På skoldatorer kan
installationen vara blockerad. Fråga då din lärare.

## Steg 3 – Kontrollera med `flutter doctor`

Öppna en terminal i VS Code med **Terminal → New Terminal**. Skriv:

```powershell
flutter doctor
```

Flutter kontrollerar din dator och visar en lista. Den kan se ut ungefär så här:

```
[✓] Flutter (Channel stable, 3.x.x)
[✓] Windows Version
[✗] Android toolchain - develop for Android devices
[✓] Chrome - develop for the web
[✗] Visual Studio - develop Windows apps
[✓] VS Code
[✓] Connected device (2 available)
```

Du behöver **inte** bocka av allt. Det här räcker för kursen:

| Rad | Behövs? | Används till |
|-----|---------|--------------|
| Flutter | ✅ Ja | Allt |
| Chrome | ✅ Ja | Köra appen i webbläsaren |
| VS Code | ✅ Ja | Skriva koden |
| Android toolchain | Frivilligt | Android-emulator. Kräver Android Studio |
| Visual Studio | Frivilligt | Windows-appar. Det är ett annat program än VS Code |

## Steg 4 – Skapa projektet

1. Tryck `Ctrl + Shift + P` och välj `Flutter: New Project`.
2. Välj **Application**.
3. Välj en mapp där projektet ska ligga, till exempel `Dokument`.
4. Skriv namnet `kvittra` och tryck Enter.

VS Code skapar projektet och öppnar det.

Vill du hellre använda terminalen fungerar det lika bra:

```powershell
flutter create kvittra
cd kvittra
code .
```

⚠️ **Projektnamn** skrivs med små bokstäver och `_` mellan orden, till exempel
`kvittra` eller `kvittra_app`. Namn som `Kvittra-App` eller `kvittra_åäö`
fungerar inte.

## Steg 5 – Kör appen

1. Längst ner till höger i VS Code står vilken **enhet** appen körs på. Klicka
   där och välj **Chrome**.
2. Tryck `F5` (eller **Run → Start Debugging**).

Efter en stund öppnas Chrome med en räknarapp. Klicka på **+**-knappen och se
hur siffran ökar.

Från terminalen gör du samma sak med:

```powershell
flutter run -d chrome
```

💡 Första gången tar det lång tid. Sedan går det mycket snabbare.

## Hot reload – se ändringar direkt

Låt appen vara igång. Öppna `lib/main.dart` och leta upp raden med
`seedColor: Colors.deepPurple`. Byt till `Colors.green` och spara med
`Ctrl + S`.

Färgen byts direkt, och siffran på räknaren är kvar. Det kallas **hot reload**.

| | Hot reload | Hot restart |
|---|---|---|
| Så gör du | Spara filen (`Ctrl + S`) | Klicka på den gröna runda pilen i VS Code |
| Vad händer | Ändringen syns, appen fortsätter där den var | Appen startar om från början |
| Siffran på räknaren | Är kvar | Blir 0 igen |

💡 Om något beter sig konstigt efter en ändring, gör en **hot restart**.

## Projektets filer

```
kvittra/
├── lib/
│   └── main.dart      ← HÄR skriver du din kod. Appen startar här
├── pubspec.yaml       ← appens namn och vilka paket den använder
├── web/               ← filer för webben
├── windows/, android/ ← filer för andra plattformar (rör dem inte)
└── ...
```

Nästan allt arbete sker i mappen `lib/`.

**pubspec.yaml** liknar `package.json` i JavaScript. Där står vilka **paket**
appen använder. Ett paket är kod som någon annan har skrivit, och du hittar
dem på <https://pub.dev>. Du lägger till ett paket med ett kommando, till
exempel:

```powershell
flutter pub add go_router
```

Det gör vi i kapitel 5 och 6.

## Kom ihåg

| Du vill … | Gör så här |
|-----------|------------|
| Öppna kommandopaletten | `Ctrl + Shift + P` |
| Skapa ett projekt | `Flutter: New Project` eller `flutter create namn` |
| Välja Chrome | Klicka på enheten längst ner till höger |
| Köra appen | `F5` eller `flutter run -d chrome` |
| Se en ändring | Spara (`Ctrl + S`) = hot reload |
| Stoppa appen | Röda fyrkanten i VS Code, eller `q` i terminalen |

## Övningar

**1.1** Kör räknarappen i Chrome. Tryck på **+** några gånger. Byt färgen i
`seedColor` och spara. Är siffran kvar? Gör sedan en hot restart. Vad händer
med siffran?

**1.2** Leta upp texten `'Flutter Demo Home Page'` i `main.dart` och byt den
till `'Kvittra'`. Byt också `'You have pushed the button this many times:'`
till en svensk text. Spara och titta.

**1.3** Kör `flutter doctor` och skriv av vilka rader som har ✓ och vilka som
har ✗ på din dator. Vilka av dem behöver du för kursen?

Lösningar finns i [losningar.md](losningar.md#kapitel-1--kom-igång).

Nästa kapitel: [Dart-grunder](02-dart-grunder.md)

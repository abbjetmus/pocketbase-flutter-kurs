# Undervisningsmaterial: Databaser, PocketBase, Flutter & Flutter Compositions

Det här materialet tar dig från "vad är en databas?" hela vägen till att kunna bygga
egna mobilappar i Flutter med `flutter_compositions` som pratar med en
PocketBase-backend.

## Kursens upplägg

| Modul | Innehåll | Ungefärlig tid |
|-------|----------|----------------|
| [01 – Databaser](01-databaser/) | Vad en databas är, SQL, ACID, databasdesign | 2–3 dagar |
| [02 – PocketBase](02-pocketbase/) | Collections, fält, relationer, API-regler, Dart-SDK, JS-hooks, flera föreningar och behörigheter | 3–4 dagar |
| [03 – Flutter](03-flutter/) | Dart, widgets, layout, state, navigation, async | 3–4 dagar |
| [04 – Flutter Compositions](04-flutter-compositions/) | Vue-liknande reaktivitet i Flutter, arkitektur för en riktig app | 3–4 dagar |

Läs modulerna i ordning. Varje modul har en `README.md` med innehållsförteckning,
numrerade kapitel och en eller flera övningsfiler. Lösningsförslag finns i
separata filer (`losningar*.md`), så försök själv först.

## Det gemensamma exemplet: Föreningsappen

Genom hela kursen återkommer samma exempel: en app för en bostadsrättsförening där
medlemmar kan läsa anslag och boka tvättstuga och festlokal. Tack vare det kan du
se samma data som:

1. **tabeller och SQL** (modul 01),
2. **collections i PocketBase** (modul 02),
3. **Dart-klasser och widgets** (modul 03–04).

### Datamodell

```
┌──────────────┐        ┌──────────────┐
│  apartments  │ 1    * │    users     │
│──────────────│◄───────│──────────────│
│ id           │        │ id           │
│ number       │        │ email        │
│ floor        │        │ name         │
│ size_sqm     │        │ apartment ───┘
└──────────────┘        │ role         │
                        └──────┬───────┘
                               │ 1
              ┌────────────────┼─────────────────┐
              │ *              │ *               │
┌─────────────┴┐       ┌───────┴──────┐   ┌──────┴───────┐
│   bookings   │ *   1 │  resources   │   │    posts     │
│──────────────│──────►│──────────────│   │──────────────│
│ id           │       │ id           │   │ id           │
│ resource     │       │ name         │   │ title        │
│ user         │       │ description  │   │ body         │
│ start        │       │ max_hours    │   │ author       │
│ end          │       │ active       │   │ published    │
│ note         │       └──────────────┘   │ created      │
└──────────────┘                          └──────────────┘
```

| Tabell / collection | Beskrivning |
|---------------------|-------------|
| `apartments` | Föreningens lägenheter (nummer, våning, storlek) |
| `users` | Medlemmar. Inloggningsbara, och varje medlem hör till en lägenhet |
| `resources` | Bokningsbara resurser, t.ex. "Tvättstuga 1" och "Festlokalen" |
| `bookings` | En bokning av en resurs, gjord av en medlem, med start- och sluttid |
| `posts` | Anslag/nyheter skrivna av en medlem (t.ex. styrelsen) |

## Förkunskaper och verktyg

- Grundläggande programmering (variabler, loopar, funktioner) i valfritt språk
- En dator med macOS, Windows eller Linux
- [VS Code](https://code.visualstudio.com/) med tilläggen *Flutter* och *Dart*
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stabil kanal)
- [PocketBase](https://pocketbase.io/docs/) (en enda körbar fil)
- [DB Browser for SQLite](https://sqlitebrowser.org/) eller kommandot `sqlite3` för SQL-övningarna

## Konventioner i materialet

- 💡 **Tips**: bra att veta men inte nödvändigt
- ⚠️ **Varning**: vanliga fallgropar
- 🧪 **Prova själv**: en liten övning direkt i texten
- Kodexempel är skrivna för att kunna köras. Kör dem och experimentera!

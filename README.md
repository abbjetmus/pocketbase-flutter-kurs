# Undervisningsmaterial: Databaser, PocketBase, Flutter & Flutter Compositions

Det här materialet tar dig från "vad är en databas?" hela vägen till att kunna bygga
egna mobilappar i Flutter med `flutter_compositions` som pratar med en
PocketBase-backend.

## Kursens upplägg

| Modul | Innehåll |
|-------|----------|
| [01 – Databaser och PocketBase](01-databaser-och-pocketbase/) | Vad en databas är, databasdesign, collections i PocketBase, SQL, API-regler |
| [02 – Flutter](02-flutter/) | Dart, widgets, layout, state, navigation, hämta data från PocketBase |
| [03 – Flutter Compositions](03-flutter-compositions/) | Vue-liknande reaktivitet i Flutter, och en hel Kvittra-app mot PocketBase |

Läs modulerna i ordning. Varje modul har en `README.md` med innehållsförteckning
och numrerade kapitel. Övningarna står i slutet av varje kapitel, och
lösningsförslagen finns i `losningar.md` i varje modul. Försök själv först.

## Det gemensamma exemplet: Kvittra – en enkel social app

Genom hela kursen återkommer samma exempel: **Kvittra**, en förenklad social app i
stil med Facebook. Användare skriver inlägg, kommenterar, gillar och följer
varandra. Tack vare det gemensamma exemplet ser du samma data som:

1. **tabeller, collections i PocketBase och SQL** (modul 01),
2. **Dart-klasser och widgets som hämtar data från PocketBase** (modul 02),
3. **en reaktiv app med `flutter_compositions`** (modul 03).

### Datamodell

```
┌──────────────────────┐            ┌──────────────────────┐
│        users         │ 1        * │        posts         │
│──────────────────────│◄───────────│──────────────────────│
│ id                   │   author   │ id                   │
│ username (unik)      │            │ author   → users     │
│ name                 │            │ title                │
│ email                │            │ body                 │
│ bio                  │            │ created              │
│ website              │            └──────────────────────┘
└──────────────────────┘                 ▲ 1          ▲ 1
                                         │ post       │ post
                                         │ *          │ *
┌──────────────────────┐   ┌─────────────┴────┐  ┌────┴─────────────┐
│       follows        │   │     comments     │  │      likes       │
│──────────────────────│   │──────────────────│  │──────────────────│
│ id                   │   │ id               │  │ id               │
│ follower  → users    │   │ post   → posts   │  │ post  → posts    │
│ following → users    │   │ author → users   │  │ user  → users    │
│ created              │   │ body             │  │ created          │
└──────────────────────┘   │ created          │  └──────────────────┘
                           └──────────────────┘
```

Relationerna i ord:

- en **user** skriver många **posts** (`posts.author`)
- en **post** har många **comments** (`comments.post`), och varje kommentar har en författare (`comments.author`)
- **likes** kopplar ihop users och posts (N:M). Samma användare kan bara gilla ett inlägg en gång
- **follows** kopplar ihop users med users (N:M mot samma tabell). Man kan inte följa sig själv

| Tabell / collection | Beskrivning | Relationstyp som övas |
|---------------------|-------------|-----------------------|
| `users` | Användare. Inloggningsbara, med unikt användarnamn | – |
| `posts` | Ett inlägg skrivet av en användare (`author`) | 1:N (user → posts) |
| `comments` | En kommentar på ett inlägg, skriven av en användare | 1:N (post → comments) |
| `likes` | En användare gillar ett inlägg. Unik per (`post`, `user`) | N:M via kopplingstabell |
| `follows` | En användare följer en annan. Unik per (`follower`, `following`) | N:M mot samma tabell |

I modul 03 bygger du en hel Kvittra-app mot just den här modellen: inloggning,
flöde, inlägg, kommentarer i realtid, likes och följningar.

## Förkunskaper och verktyg

- Grundläggande programmering (variabler, loopar, funktioner) i valfritt språk
- En dator med macOS, Windows eller Linux
- [VS Code](https://code.visualstudio.com/) med tilläggen *Flutter* och *Dart*
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stabil kanal)
- [PocketBase](https://pocketbase.io/docs/) – en enda körbar fil som du laddar ner i modul 01. **Alla databasövningar görs direkt i PocketBase**: collections, data och regler skapas i PocketBase Dashboard, och SQL-frågor skrivs som *View collections*.

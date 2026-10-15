# Undervisningsmaterial: Databaser, PocketBase, Flutter & Flutter Compositions

Det här materialet tar dig från "vad är en databas?" hela vägen till att kunna bygga
egna mobilappar i Flutter med `flutter_compositions` som pratar med en
PocketBase-backend.

## Kursens upplägg

| Modul | Innehåll | Ungefärlig tid |
|-------|----------|----------------|
| [01 – Databaser](01-databaser/) | Vad en databas är, SQL, ACID, databasdesign | 2–3 dagar |
| [02 – PocketBase](02-pocketbase/) | Collections, fält, relationer, API-regler, Dart-SDK, JS-hooks, grupper och behörigheter | 3–4 dagar |
| [03 – Flutter](03-flutter/) | Dart, widgets, layout, state, navigation, async | 3–4 dagar |
| [04 – Flutter Compositions](04-flutter-compositions/) | Vue-liknande reaktivitet i Flutter, arkitektur för en riktig app | 3–4 dagar |

Läs modulerna i ordning. Varje modul har en `README.md` med innehållsförteckning,
numrerade kapitel och en eller flera övningsfiler. Lösningsförslag finns i
separata filer (`losningar*.md`), så försök själv först.

## Det gemensamma exemplet: Kvittra – en enkel social app

Genom hela kursen återkommer samma exempel: **Kvittra**, en förenklad social app i
stil med Facebook. Användare skriver inlägg, kommenterar, gillar och följer
varandra. Datan är inspirerad av den publika test-API:n
[JSONPlaceholder](https://jsonplaceholder.typicode.com) (`/users`, `/posts`,
`/comments`), så du kan börja hämta riktig JSON i Flutter innan du har en egen
backend. Tack vare det gemensamma exemplet ser du samma data som:

1. **tabeller och SQL** (modul 01),
2. **collections i PocketBase** (modul 02),
3. **JSON från JSONPlaceholder, Dart-klasser och widgets** (modul 03),
4. **en reaktiv app med `flutter_compositions`** (modul 04).

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

Senare i kursen (modul 02 kapitel 8 och modul 04 kapitel 9) utökas modellen med
**grupper** (`groups`, `group_members` med rollerna `admin`, `moderator` och `member`)
för att visa behörigheter i en riktig app.

## Förkunskaper och verktyg

- Grundläggande programmering (variabler, loopar, funktioner) i valfritt språk
- En dator med macOS, Windows eller Linux
- [VS Code](https://code.visualstudio.com/) med tilläggen *Flutter* och *Dart*
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stabil kanal)
- [PocketBase](https://pocketbase.io/docs/) – en enda körbar fil som du laddar ner redan i modul 01. **Alla databas- och backendövningar görs direkt i PocketBase**: SQL-frågor skrivs som *View collections* i PocketBase Dashboard, och tabeller, relationer, regler och hooks byggs i samma verktyg.

## Konventioner i materialet

- 💡 **Tips**: bra att veta men inte nödvändigt
- ⚠️ **Varning**: vanliga fallgropar
- 🧪 **Prova själv**: en liten övning direkt i texten
- Kodexempel är skrivna för att kunna köras. Kör dem och experimentera!

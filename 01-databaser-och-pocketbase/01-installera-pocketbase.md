# 1. Installera PocketBase

**PocketBase** är en databas och en server i ett enda program. Det är bara en
fil som du laddar ner och startar. Den behöver ingen installation.

PocketBase ger dig:

- en **databas** där all data sparas
- en **Dashboard** i webbläsaren där du skapar tabeller och lägger in data
- ett **API** som apparna du bygger senare kan prata med

## Steg 1 – Ladda ner

1. Gå till <https://pocketbase.io/docs/>.
2. Ladda ner zip-filen för **Windows**. Den heter ungefär
   `pocketbase_0.xx.x_windows_amd64.zip`.

| Dator | Välj fil som slutar på |
|-------|------------------------|
| Windows (nästan alla datorer) | `windows_amd64.zip` |
| Windows på ARM-processor (ovanligt) | `windows_arm64.zip` |
| Mac med M-processor | `darwin_arm64.zip` |

## Steg 2 – Packa upp

1. Skapa en ny mapp, till exempel `Dokument\kvittra-pb`.
2. Högerklicka på zip-filen → **Extrahera alla…** → välj mappen `kvittra-pb`.
3. I mappen ska det nu finnas en fil som heter `pocketbase.exe`.

## Steg 3 – Starta PocketBase

1. Öppna mappen `kvittra-pb` i Utforskaren.
2. Högerklicka på en tom yta i mappen → **Öppna i terminal**.
   (Saknas valet? Klicka i adressfältet, skriv `powershell` och tryck Enter.)
3. Skriv det här och tryck Enter:

```powershell
.\pocketbase serve
```

💡 `.\` betyder "programmet i den här mappen". Det behövs i PowerShell, som är
det som öppnas med **Öppna i terminal**. Använder du Kommandotolken (`cmd`)
räcker det att skriva `pocketbase serve`.

Du ser ungefär det här:

```
Server started at http://127.0.0.1:8090
├─ REST API:  http://127.0.0.1:8090/api/
└─ Dashboard: http://127.0.0.1:8090/_/
```

⚠️ **Låt terminalfönstret vara öppet.** PocketBase körs bara så länge fönstret
är öppet. Du stänger av servern med `Ctrl + C`.

💡 **Om Windows varnar:** Om du får rutan "Windows skyddade datorn" klickar du
på **Mer information** → **Kör ändå**. På skoldatorer kan det vara blockerat.
Fråga då din lärare.

## Steg 4 – Skapa ditt administratörskonto

Första gången PocketBase startar öppnas webbläsaren av sig själv. Om den inte
gör det, kopiera länken som står i terminalen (den börjar med
`http://127.0.0.1:8090/_/#/pbinstal`) till webbläsaren.

Fyll i en e-postadress och ett lösenord. Det här kontot kallas **superuser**.
Det är du som administratör, och kontot får göra allt i din PocketBase.

💡 Det här kontot finns bara på din dator, så e-postadressen behöver inte vara
riktig. Till exempel `admin@example.com` fungerar. Skriv upp lösenordet!

## Steg 5 – Logga in i Dashboard

Gå till <http://127.0.0.1:8090/_/> och logga in. Du ser nu **Dashboard**:

```
┌──────────────┬────────────────────────────────────────────┐
│ Collections  │                                            │
│              │   Här visas data i den collection          │
│  users       │   du har valt.                             │
│              │                                            │
│ + New        │                                            │
│   collection │                                            │
├──────────────┤                                            │
│ Settings     │                                            │
└──────────────┴────────────────────────────────────────────┘
```

Till vänster finns dina **collections**. Det är PocketBase-ordet för tabeller.
Det finns redan en: `users`. Den skapas automatiskt och används för
användarkonton.

## Var sparas datan?

När PocketBase har startat finns en ny mapp, `pb_data`, bredvid
`pocketbase.exe`. Där ligger databasen. Tar du bort `pb_data` börjar du om från
noll.

```
kvittra-pb/
├── pocketbase.exe   ← programmet
└── pb_data/         ← din databas (skapas vid första start)
```

## Kom ihåg

| Du vill … | Gör så här |
|-----------|------------|
| Starta PocketBase | Öppna terminal i mappen → `.\pocketbase serve` |
| Öppna Dashboard | <http://127.0.0.1:8090/_/> |
| Stänga av | `Ctrl + C` i terminalen |

Nästa kapitel: [Vad är en databas?](02-vad-ar-en-databas.md)

# Övningar – Modul 04: Flutter Compositions

Övningarna är indelade i tre nivåer. Gör Nivå 1 innan du går vidare. Lösningsförslag
finns i [losningar.md](losningar.md), men försök själv först. Det är i felsökningen du
lär dig mest.

**Förberedelse:** Skapa ett nytt projekt (`flutter create komp_ovningar`), installera
`flutter_compositions` och lint-reglerna enligt [README](README.md#installation). Lägg
varje övning i en egen fil under `lib/ovningar/` och visa den från `main.dart`.

> 💡 **Tips:** Kör `dart run custom_lint --watch` i en terminal medan du arbetar.

---

## Nivå 1 – Grunderna

### Övning 1.1 – Skriv om en StatefulWidget

Skriv om den här widgeten till en `CompositionWidget`. Beteendet ska vara identiskt.

```dart
class LimitedCounter extends StatefulWidget {
  const LimitedCounter({super.key, this.min = 0, this.max = 10});
  final int min;
  final int max;

  @override
  State<LimitedCounter> createState() => _LimitedCounterState();
}

class _LimitedCounterState extends State<LimitedCounter> {
  late int _count;

  @override
  void initState() {
    super.initState();
    _count = widget.min;
  }

  @override
  Widget build(BuildContext context) {
    final canDecrement = _count > widget.min;
    final canIncrement = _count < widget.max;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Antal: $_count (max ${widget.max})'),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: canDecrement ? () => setState(() => _count--) : null,
              icon: const Icon(Icons.remove),
            ),
            IconButton(
              onPressed: canIncrement ? () => setState(() => _count++) : null,
              icon: const Icon(Icons.add),
            ),
            TextButton(
              onPressed: () => setState(() => _count = widget.min),
              child: const Text('Nollställ'),
            ),
          ],
        ),
      ],
    );
  }
}
```

**Krav:**

- [ ] Ingen `State`-klass och inget `setState`.
- [ ] `canDecrement`, `canIncrement` och texten är `computed`.
- [ ] `min` och `max` läses via `widget()` så att ändrade props slår igenom.

### Övning 1.2 – Tvättlistan (grund reaktivitet)

Bygg en `LaundryList` där man skriver in saker att tvätta.

**Krav:**

- [ ] Ett textfält med `useTextEditingController` och en "+"-knapp som bara är aktiv när
      fältet inte är tomt (`computed`).
- [ ] Efter tillägg töms fältet **via tvåvägsbindningen** (`text.value = ''`).
- [ ] Listan visas **sorterad** i bokstavsordning (`computed`, utan att originallistan
      muteras).
- [ ] Varje rad har en ta bort-knapp. Det finns också en knapp "Ta bort första".
- [ ] Ingen `add`, `remove` eller `removeAt` får anropas direkt på `items.value`.

### Övning 1.3 – Hitta felen

Följande widget har **minst sex** fel eller avvikelser från best practice. Hitta dem,
förklara varför de är fel och skriv en rättad version.

```dart
class Greeting extends CompositionWidget {
  Greeting({super.key, required this.name});
  final String name;
  int clicks = 0;

  @override
  Widget Function(BuildContext) setup() {
    final visits = ref(0);
    final tags = ref(<String>[]);
    final message = computed(() => 'Hej $name! Besök: ${visits.value}');

    onMounted(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      visits.value = 1;
    });

    if (name.isEmpty) {
      watchEffect(() => debugPrint('Tomt namn!'));
    }

    return (context) {
      final style = Theme.of(context).textTheme.titleLarge;
      return Column(
        children: [
          Text('$message', style: style),
          Text(tags.value.join(', ')),
          TextButton(
            onPressed: () => tags.value.add('ny'),
            child: const Text('Lägg till tagg'),
          ),
          TextButton(
            onPressed: () => clicks++,
            child: const Text('+1'),
          ),
        ],
      );
    };
  }
}
```

---

## Nivå 2 – Composables och formulär

### Övning 2.1 – Todo-lista med filter

Bygg en todo-lista för styrelsens att göra-punkter.

**Krav:**

- [ ] En immutabel modell `Todo { id, title, done }` med `copyWith`.
- [ ] `final todos = ref(<Todo>[]);` och `final filter = ref(TodoFilter.all);`
      (`enum TodoFilter { all, active, done }`).
- [ ] `computed`: `visible` (filtrerad lista), `remaining` (antal ej klara) och
      `summary` (`"2 av 5 kvar"`, visas i AppBar).
- [ ] Filterval med `SegmentedButton`.
- [ ] Bocka i och ur med `CheckboxListTile`. Uppdatera listan med `copyWith`, utan
      mutation.
- [ ] Knappen "Rensa klara" är bara aktiv om det finns klara todos.
- [ ] Builder-funktionen innehåller **ingen** filtrering eller räkning.

### Övning 2.2 – Registreringsformulär med validering

Bygg ett registreringsformulär för nya medlemmar i föreningen.

**Fält:** namn, e-post, lägenhetsnummer (fyra siffror, t.ex. `1101`), lösenord och
bekräfta lösenord.

**Krav:**

- [ ] En `useTextEditingController` per fält.
- [ ] En `computed<String?>` per fält med felmeddelande (eller `null`).
- [ ] `isValid` som `computed` av alla fel.
- [ ] Felen visas först efter första försöket att skicka (`touched`-ref).
- [ ] Widgeten tar en callback-prop `onSubmit(name, email, apartment, password)`
      (motsvarar Vues `emit`) som anropas när allt är giltigt.
- [ ] Inga `addListener`, inget `setState` och ingen manuell `dispose`.

**Bonus:** Bryt ut valideringen av ett fält i en composable
`useValidatedField(String? Function(String) validator)` som returnerar
`(controller, text, error)`.

### Övning 2.3 – `useCountdown`

Skriv en composable för tvättstugans nedräkning ("Tvätten är klar om 44:59").

```dart
Countdown useCountdown(Duration total, {Duration tick = const Duration(seconds: 1)});
```

`Countdown` är en liten klass med:

| Fält | Typ |
|------|-----|
| `remaining` | `ReadonlyRef<Duration>` |
| `isRunning` | `ReadonlyRef<bool>` |
| `isFinished` | `ReadonlyRef<bool>` (computed) |
| `start`, `pause`, `reset` | `void Function()` |

**Krav:**

- [ ] Timern städas i `onUnmounted`, och `onUnmounted` registreras direkt i
      composablen (inte i `start`).
- [ ] `start` gör ingenting om nedräkningen redan körs eller är klar.
- [ ] Nedräkningen stannar automatiskt på noll.
- [ ] En widget `LaundryTimer` använder composablen och visar `mm:ss` eller
      "Tvätten är klar!" (computed). En `watch` skriver ut ett meddelande när
      `isFinished` blir sant.
- [ ] **Test:** Skriv ett widget-test som kör composablen i en `CompositionBuilder` och
      använder `tester.pump(Duration)` för att flytta tiden framåt.

---

## Nivå 3 – Provide/inject och asynkron data

### Övning 3.1 – Tema och inloggning med provide/inject

Bygg ett litet app-skal **utan** backend.

**Krav:**

- [ ] En `SessionService` med en privat `Ref<FakeUser?>`, en publik
      `ReadonlyRef<FakeUser?> user`, `isLoggedIn` (computed), `login(name)` (async,
      fördröjning 300 ms) och `logout()`.
- [ ] `InjectionKey`s: `sessionKey` och `themeModeKey` (`Ref<ThemeMode>`).
- [ ] `AppShell` (rot-`CompositionWidget`) gör `provide` på båda och väljer
      `home:` utifrån `isLoggedIn`.
- [ ] `FakeLoginPage`: namnfält + knapp, med knappen inaktiverad under inloggning.
- [ ] `ProfileHeader` (i AppBar) visar `"Anna (lgh 1101)"` och en utloggningsknapp.
- [ ] `ThemeToggle` (i AppBar actions) växlar ljust/mörkt.
- [ ] Inga props skickas mellan widgetarna. Allt går via `inject`.
- [ ] **Test:** Skriv ett widget-test som tillhandahåller en redan inloggad
      `SessionService` och verifierar att `ProfileHeader` visar namnet.

### Övning 3.2 – Resurslista från PocketBase med refresh

Använd PocketBase-instansen från modul 02 (collection `resources`).

**Krav:**

- [ ] `PocketBase`-klienten tillhandahålls i roten med `pocketBaseKey`.
- [ ] `ResourcesPage` hämtar resurser med `useAsyncData`. Som standard visas bara
      `active = true`.
- [ ] En `Switch` "visa inaktiva" (`ref<bool>`) styr filtret via `watch:`.
- [ ] Alla fyra `AsyncValue`-tillstånd hanteras med `switch`. Vid fel visas en
      "Försök igen"-knapp som anropar `refresh`.
- [ ] Pull-to-refresh med `RefreshIndicator`.
- [ ] Titeln visar `"Resurser (3)"` när data finns (computed).
- [ ] Data mappas till en immutabel `Resource`-klass med `factory Resource.fromRecord`.
- [ ] **Realtime:** prenumerera på `resources` och anropa `refresh()` vid varje
      händelse. Städa korrekt (`disposed`-flagga, se kapitel 7). Testa genom att ändra
      en resurs i Admin UI.

### Övning 3.3 (utmaning) – Migrera en egen widget

Ta den mest komplexa `StatefulWidget` du skrev i modul 03 (t.ex. formuläret) och
migrera den med checklistan i [kapitel 8](08-best-practices-och-lints.md#migrera-från-statefulwidget-checklista).
Skriv kort (3–5 meningar) om vad som blev enklare och vad som var svårt. Det finns inget
lösningsförslag för den här övningen. Diskutera med en kurskamrat.

### Övning 3.4 – Ny feature: Felanmälan

Bygg vidare på arkitekturen i [kapitel 9](09-arkitektur-for-en-riktig-app.md) och lägg
till en helt ny feature: **felanmälan**. Medlemmar anmäler fel (t.ex. "droppande kran i
tvättstugan") och styrelsen markerar dem som åtgärdade. Följ checklistan
[Så bygger du nästa feature](09-arkitektur-for-en-riktig-app.md#så-bygger-du-nästa-feature).

**Backend (JavaScript, `pb_migrations/` och `pb_hooks/`):**

- [ ] En migration som skapar `issues`: `title` (text, krävs), `description` (text,
      krävs), `reported_by` (relation → users, krävs), `assigned_to` (relation →
      users), `is_resolved` (bool), `association` (relation) och `created`/`updated`
      (autodate).
- [ ] Regler: alla i föreningen ser föreningens anmälningar. Man anmäler i eget namn och
      får inte sätta `is_resolved` själv. Anmälaren får ändra text tills felet är
      åtgärdat. `styrelse`/`admin` får ändra allt. Anmälaren eller admin får radera.
- [ ] `association` stämplas av servern (lägg till `"issues"` i tenant-hooken).
- [ ] Testa reglerna med `curl` som anmälare, som styrelse och som medlem i en annan
      förening.

**App:**

- [ ] `IssueRecord.fromJson` med `reporterName` från `expand.reported_by`.
- [ ] `IssuesStore` med `Paginated<IssueRecord>`, en `showResolved`-ref som styr
      filtret, `fetchIssue`, `saveIssue({id, …})`, `setResolved` och `deleteIssue`
      (alla mutationer returnerar `Future<bool>`).
- [ ] `issuesStoreKey`, och store:n skapas och `provide`:as i `MyApp`.
- [ ] `IssuesListPage` (`PaginatedListView`, switch "Visa åtgärdade" som hämtar om via
      `watch`, FAB), `IssueDetailPage` (`EntityActionMenu` med *Redigera* för anmälaren
      så länge felet är öppet och *Radera* för anmälaren eller admin, plus knappen
      "Markera som åtgärdad" bara för styrelsen) och `CreateIssuePage` (skapa och
      redigera, med validering via `computed`).
- [ ] Routes med `static const path` (och `/issues/new` före `/issues/:id`), en ny
      `AppMenu.issues` i behörighetsmatrisen och en ruta på dashboarden.

**Bonus:** Kommentarer på felanmälningar i realtid, på samma sätt som för anslag.

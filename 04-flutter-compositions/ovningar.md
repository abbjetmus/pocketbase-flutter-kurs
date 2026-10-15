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

Den här widgeten bläddrar igenom en användares inlägg några i taget. Skriv om den till
en `CompositionWidget`. Beteendet ska vara identiskt.

```dart
class PostPager extends StatefulWidget {
  const PostPager({super.key, required this.titles, this.pageSize = 3});
  final List<String> titles;
  final int pageSize;

  @override
  State<PostPager> createState() => _PostPagerState();
}

class _PostPagerState extends State<PostPager> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final pageCount = (widget.titles.length / widget.pageSize).ceil();
    final canPrev = _page > 0;
    final canNext = _page < pageCount - 1;
    final visible = widget.titles
        .skip(_page * widget.pageSize)
        .take(widget.pageSize)
        .toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final t in visible) ListTile(title: Text(t)),
        Text('Sida ${_page + 1} av $pageCount'),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: canPrev ? () => setState(() => _page--) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              onPressed: canNext ? () => setState(() => _page++) : null,
              icon: const Icon(Icons.chevron_right),
            ),
            TextButton(
              onPressed: () => setState(() => _page = 0),
              child: const Text('Till början'),
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
- [ ] `pageCount`, `canPrev`, `canNext`, `visible` och texten är `computed`.
- [ ] `titles` och `pageSize` läses via `widget()` så att ändrade props slår igenom.

### Övning 1.2 – Hashtaggar (grund reaktivitet)

Bygg en `HashtagEditor` där man lägger till hashtaggar till ett inlägg.

**Krav:**

- [ ] Ett textfält med `useTextEditingController` och en "+"-knapp som bara är aktiv när
      fältet inte är tomt (`computed`).
- [ ] Glömmer användaren `#` läggs det till automatiskt (`flutter` blir `#flutter`).
      Samma tagg kan inte läggas till två gånger.
- [ ] Efter tillägg töms fältet **via tvåvägsbindningen** (`text.value = ''`).
- [ ] Listan visas **sorterad** i bokstavsordning (`computed`, utan att originallistan
      muteras).
- [ ] Varje rad har en ta bort-knapp. Det finns också en knapp "Ta bort första".
- [ ] Ingen `add`, `remove` eller `removeAt` får anropas direkt på `tags.value`.

### Övning 1.3 – Hitta felen

Följande widget har **minst sex** fel eller avvikelser från best practice. Hitta dem,
förklara varför de är fel och skriv en rättad version.

```dart
class ProfileGreeting extends CompositionWidget {
  ProfileGreeting({super.key, required this.name});
  final String name;
  int clicks = 0;

  @override
  Widget Function(BuildContext) setup() {
    final views = ref(0);
    final interests = ref(<String>[]);
    final message = computed(() => 'Hej $name! Profilvisningar: ${views.value}');

    onMounted(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      views.value = 1;
    });

    if (name.isEmpty) {
      watchEffect(() => debugPrint('Tomt namn!'));
    }

    return (context) {
      final style = Theme.of(context).textTheme.titleLarge;
      return Column(
        children: [
          Text('$message', style: style),
          Text(interests.value.join(', ')),
          TextButton(
            onPressed: () => interests.value.add('Flutter'),
            child: const Text('Lägg till intresse'),
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

### Övning 2.1 – Flöde med filter och sök

Bygg ett lokalt flöde (ingen backend än) med filter, sök och gillningar.

**Krav:**

- [ ] En immutabel modell `Post { id, author, title, liked }` med `copyWith`.
- [ ] `final posts = ref(<Post>[...])` med minst fem exempelinlägg från olika
      författare, `const me = 'anna'` och `const following = {'bo', 'cecilia'}`.
- [ ] `final filter = ref(FeedFilter.all);` (`enum FeedFilter { all, following, mine }`)
      och ett sökfält med `useTextEditingController`.
- [ ] `computed`: `visible` (filtrerad och sökt lista), `likedCount` (antal gillade)
      och `summary` (`"3 av 6 inlägg · 2 gillade"`, visas i AppBar).
- [ ] Filterval med `SegmentedButton`.
- [ ] Gilla och sluta gilla med en hjärtknapp per rad. Uppdatera listan med `copyWith`,
      utan mutation.
- [ ] Knappen "Sluta gilla alla" är bara aktiv om något inlägg är gillat.
- [ ] Builder-funktionen innehåller **ingen** filtrering eller räkning.

### Övning 2.2 – Registreringsformulär med validering

Bygg ett registreringsformulär för nya användare i Kvittra.

**Fält:** namn, e-post, användarnamn (3–20 tecken, bara `a–z`, `0–9` och `_`, t.ex.
`anna_a`), lösenord och bekräfta lösenord.

**Krav:**

- [ ] En `useTextEditingController` per fält.
- [ ] En `computed<String?>` per fält med felmeddelande (eller `null`).
- [ ] `isValid` som `computed` av alla fel.
- [ ] Felen visas först efter första försöket att skicka (`touched`-ref).
- [ ] Widgeten tar en callback-prop `onSubmit(name, email, username, password)`
      (motsvarar Vues `emit`) som anropas när allt är giltigt.
- [ ] Inga `addListener`, inget `setState` och ingen manuell `dispose`.

**Bonus:** Bryt ut valideringen av ett fält i en composable
`useValidatedField(String? Function(String) validator)` som returnerar
`(controller, text, error)`.

### Övning 2.3 – `useCountdown`

Kvittra har ett "tyst läge" som stänger av notiser en stund. Skriv en composable för
nedräkningen ("Tyst läge i 29:59").

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
- [ ] En widget `QuietModeTimer` använder composablen (30 minuter) och visar
      `"Tyst läge i mm:ss"` eller `"Tyst läge är slut"` (computed). En `watch` skriver
      ut "Notiser är på igen" när `isFinished` blir sant.
- [ ] **Test:** Skriv ett widget-test som kör composablen i en `CompositionBuilder` och
      använder `tester.pump(Duration)` för att flytta tiden framåt.

---

## Nivå 3 – Provide/inject och asynkron data

### Övning 3.1 – Tema och inloggning med provide/inject

Bygg ett litet app-skal **utan** backend.

**Krav:**

- [ ] En `SessionService` med en privat `Ref<FakeUser?>`, en publik
      `ReadonlyRef<FakeUser?> user`, `isLoggedIn` (computed), `login(name)` (async,
      fördröjning 300 ms, användarnamnet blir namnet i gemener) och `logout()`.
- [ ] `InjectionKey`s: `sessionKey` och `themeModeKey` (`Ref<ThemeMode>`).
- [ ] `AppShell` (rot-`CompositionWidget`) gör `provide` på båda och väljer
      `home:` utifrån `isLoggedIn`.
- [ ] `FakeLoginPage`: namnfält + knapp, med knappen inaktiverad under inloggning.
- [ ] `ProfileHeader` (i AppBar) visar `"Anna (@anna)"` och en utloggningsknapp.
- [ ] `ThemeToggle` (i AppBar actions) växlar ljust/mörkt.
- [ ] Inga props skickas mellan widgetarna. Allt går via `inject`.
- [ ] **Test:** Skriv ett widget-test som tillhandahåller en redan inloggad
      `SessionService` och verifierar att `ProfileHeader` visar namnet.

### Övning 3.2 – Inlägg från PocketBase med refresh

Använd din PocketBase från modul 02 (collection `posts` med `author` → `users`).

**Krav:**

- [ ] `PocketBase`-klienten tillhandahålls i roten med `pocketBaseKey`.
- [ ] `PostsPage` hämtar inlägg med `useAsyncData` och `expand: 'author'`. Som standard
      visas nyast först.
- [ ] En `Switch` "Äldst först" (`ref<bool>`) styr sorteringen via `watch:`.
- [ ] Alla fyra `AsyncValue`-tillstånd hanteras med `switch`. Vid fel visas en
      "Försök igen"-knapp som anropar `refresh`.
- [ ] Pull-to-refresh med `RefreshIndicator`.
- [ ] Titeln visar `"Inlägg (12)"` när data finns (computed).
- [ ] Data mappas till en immutabel `Post`-klass med `factory Post.fromRecord`, där
      `authorName` läses från `expand.author`.
- [ ] **Realtime:** prenumerera på `posts` och anropa `refresh()` vid varje händelse.
      Städa korrekt (`disposed`-flagga, se kapitel 7). Testa genom att ändra ett inlägg
      i Admin UI.

### Övning 3.3 (utmaning) – Migrera en egen widget

Ta den mest komplexa `StatefulWidget` du skrev i modul 03 (t.ex. formuläret) och
migrera den med checklistan i [kapitel 8](08-best-practices-och-lints.md#migrera-från-statefulwidget-checklista).
Skriv kort (3–5 meningar) om vad som blev enklare och vad som var svårt. Det finns inget
lösningsförslag för den här övningen. Diskutera med en kurskamrat.

### Övning 3.4 – Ny feature: Notiser

Bygg vidare på arkitekturen i [kapitel 9](09-arkitektur-for-en-riktig-app.md) och lägg
till en helt ny feature: **notiser**. När någon gillar eller kommenterar ditt inlägg,
eller börjar följa dig, får du en notis. En klocka i flödets AppBar visar antalet
olästa, och på notissidan kan du läsa dem och markera dem som lästa. Följ checklistan
[Så bygger du nästa feature](09-arkitektur-for-en-riktig-app.md#så-bygger-du-nästa-feature).

**Backend (JavaScript, `pb_migrations/` och `pb_hooks/`):**

- [ ] En migration som skapar `notifications`: `user` (mottagaren, relation → users,
      krävs), `actor` (den som gjorde något, relation → users, krävs), `type` (select:
      `like`, `comment`, `follow`), `post` (relation → posts, valfri, cascade delete),
      `read` (bool) och `created` (autodate).
- [ ] Regler: man ser och raderar bara sina egna notiser. **Ingen** klient får skapa
      notiser. Mottagaren får bara ändra `read`.
- [ ] Hooks som skapar notiser **på servern** när en `likes`-, `comments`- eller
      `follows`-post skapas. Ingen notis när man gillar eller kommenterar sitt eget
      inlägg.
- [ ] Testa reglerna med `curl`: kan Bo läsa Annas notiser? Kan Bo skapa en notis? Kan
      Anna ändra `type` på sin notis?

**App:**

- [ ] `NotificationRecord.fromJson` med `actorName` och `postTitle` från `expand`, en
      getter `text` ("Bo gillade ditt inlägg") och `copyWith(read:)`.
- [ ] `NotificationsStore` med `Paginated<NotificationRecord>`, en `unreadCount`-ref,
      `badgeLabel` (computed, `"9+"` över nio), `start()`/`stop()` för realtime (med
      skydd mot race-fall), `markAsRead` (optimistisk, med tillbakarullning vid fel) och
      `markAllAsRead`. Mutationer returnerar `Future<bool>`.
- [ ] `notificationsStoreKey`, och store:n skapas och `provide`:as i `MyApp`. Realtime
      startas vid inloggning och stoppas vid utloggning (samma `watch` som laddar
      grupproller).
- [ ] `NotificationsPage` (`PaginatedListView`, olästa i fetstil, tryck → markera som läst
      och öppna inlägget eller profilen, knapp "Markera alla som lästa") och
      `NotificationsBell` (en `Badge` med antal olästa i flödets AppBar).
- [ ] Route `/notifications` med `static const path`.
- [ ] **Test:** ett widget-test som visar att klockan visar `3` och sedan `9+`.

**Bonus:** Lägg till ett "tyst läge" med `useCountdown` från övning 2.3. Under tyst
läge visas ingen siffra på klockan.

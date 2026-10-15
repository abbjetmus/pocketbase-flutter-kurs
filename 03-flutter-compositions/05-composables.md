# 5. Composables

En **composable** är en vanlig Dart-funktion vars namn börjar med `use` och som anropas
från `setup()`. Den kan skapa refs, computed, watchers och lifecycle-hooks och
returnerar det som anroparen behöver. Det är Flutter Compositions sätt att
**återanvända logik med state**, precis som composables i Vue (`useMouse`, `useFetch`
…).

Kapitlet har två delar:

1. **Inbyggda composables**: controllers, context, tema, mediaquery.
2. **Egna composables**: hur du skriver `useDebounced`, `useCommentComposer` med flera.

---

## Del 1: Inbyggda composables

### `use*` mot `manage*`

| | `use*`-funktioner | `manage*`-funktioner |
|---|---|---|
| Skapar instansen | ✅ Ja | ❌ Nej, du skickar in en befintlig |
| Tar bort lyssnare vid unmount | ✅ | ✅ |
| Anropar `dispose()` vid unmount | ✅ | `manageChangeNotifier`: ✅, `manageListenable`/`manageValueListenable`: ❌ (kan inte) |
| Exempel | `useScrollController()` | `manageChangeNotifier(befintligController)` |
| Använd när | Widgeten behöver en *egen* controller | Du har fått ett objekt utifrån och vill göra det reaktivt |

Tumregel: **skapa aldrig controllers manuellt** i en `CompositionWidget`. Använd
`use*`. Då slipper du `dispose()` helt.

### `useTextEditingController`: Flutters `v-model`

```dart
final (controller, text, value) = useTextEditingController(text: 'startvärde');
```

Den returnerar en *record* med tre delar:

| Del | Typ | Vad |
|-----|-----|-----|
| `controller` | `TextEditingController` | Skickas till `TextField(controller: …)` |
| `text` | `WritableRef<String>` | Reaktiv **tvåvägsbunden** text |
| `value` | `WritableRef<TextEditingValue>` | Text + markering/cursor, tvåvägsbunden |

- När användaren skriver uppdateras `text.value`. Allt som läser den, som computed och
  builder, uppdateras automatiskt.
- När **du** skriver `text.value = 'x'` uppdateras textfältet.
- Controllern städas (`dispose`) automatiskt när widgeten försvinner.

#### Vue ↔ Dart

```vue
<script setup lang="ts">
import { ref, computed } from 'vue'

const comment = ref('')
const remaining = computed(() => 280 - comment.value.length)
const canSend = computed(() =>
  comment.value.trim().length > 0 && remaining.value >= 0)
</script>

<template>
  <textarea v-model="comment" />
  <p>{{ remaining }} tecken kvar</p>
  <button :disabled="!canSend" @click="comment = ''">Skicka</button>
</template>
```

```dart
@override
Widget Function(BuildContext) setup() {
  final (commentController, comment, _) = useTextEditingController();
  final remaining = computed(() => 280 - comment.value.length);
  final canSend = computed(
    () => comment.value.trim().isNotEmpty && remaining.value >= 0,
  );

  void send() {
    debugPrint('Skickar: ${comment.value.trim()}');
    comment.value = '';   // tvåvägsbindning: tömmer fältet
  }

  return (context) => Column(
        children: [
          TextField(controller: commentController, maxLines: 3),
          Text('${remaining.value} tecken kvar'),
          FilledButton(
            onPressed: canSend.value ? send : null,
            child: const Text('Skicka'),
          ),
        ],
      );
}
```

Behöver du inte alla tre delarna använder du `_`:

```dart
final (emailController, email, _) = useTextEditingController();
final (_, query, _) = useTextEditingController(); // om du bara vill ha texten
```

> ⚠️ **Varning:** Skapa aldrig `TextEditingController()` själv och anropa aldrig
> `dispose()` på den du fått från `useTextEditingController`. Ett vanligt krasch-fall är
> en dialog där controllern disposas direkt efter att `showDialog` returnerat, medan
> dialogens stängningsanimation fortfarande använder den: *"A TextEditingController was
> used after being disposed."* Med `useTextEditingController` i dialogens egen
> `CompositionWidget` sköts det rätt automatiskt.

#### Validering med computed

```dart
final (emailController, email, _) = useTextEditingController();
final (passwordController, password, _) = useTextEditingController();

final emailError = computed(() =>
    email.value.isEmpty || email.value.contains('@') ? null : 'Ogiltig e-post');
final canSubmit = computed(() =>
    email.value.contains('@') && password.value.length >= 8);

return (context) => Column(
      children: [
        TextField(
          controller: emailController,
          decoration: InputDecoration(
            labelText: 'E-post',
            errorText: emailError.value,
          ),
        ),
        TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Lösenord'),
        ),
        FilledButton(
          onPressed: canSubmit.value ? submit : null,
          child: const Text('Logga in'),
        ),
      ],
    );
```

Jämför med `StatefulWidget`-versionen från modul 02: där behövdes två controllers, två
`addListener`, en `_validate()` med `setState` och en `dispose()`. Här är allt
deklarativt.

### `useScrollController`, `usePageController`, `useFocusNode`

Dessa returnerar en `ReadonlyRef<Controller>`. Refen notifieras när controllern
notifierar, t.ex. vid scroll eller fokusbyte.

```dart
final scrollController = useScrollController();

// computed räknas om när controllern notifierar (vid scroll)
final showToTop = computed(() =>
    scrollController.value.hasClients && scrollController.value.offset > 400);

return (context) => Scaffold(
      body: ListView.builder(
        controller: scrollController.raw,   // ← .raw!
        itemCount: 100,
        itemBuilder: (context, i) => ListTile(title: Text('Inlägg $i')),
      ),
      floatingActionButton: showToTop.value
          ? FloatingActionButton(
              onPressed: () => scrollController.raw.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              ),
              child: const Icon(Icons.arrow_upward),
            )
          : null,
    );
```

#### Varför `.raw`?

Läser du `scrollController.value` i builder-funktionen blir builder-funktionen beroende
av controllern och byggs om **vid varje scroll-pixel**. Det vill du inte. Med `.raw`
får du samma controller-objekt utan att registrera ett beroende. Det enda som byggs om
är det som går via `showToTop`, och det ändras bara när gränsen passeras.

> 💡 **Tips:** Regel: när du skickar en controller eller `FocusNode` till en widget
> (`controller:`, `focusNode:`) använder du **`.raw`**. Läser du ett värde *från*
> controllern i en computed använder du `.value`.

`useTextEditingController` returnerar controllern **oinpackad** (en vanlig
`TextEditingController`, inte en ref), så där skickar du `controller` direkt utan `.raw`.

#### `useFocusNode`

```dart
final focusNode = useFocusNode();
final hasFocus = computed(() => focusNode.value.hasFocus);

return (context) => Column(
      children: [
        TextField(
          focusNode: focusNode.raw,
          decoration: InputDecoration(
            labelText: hasFocus.value ? 'Skriv en kommentar…' : 'Kommentar',
          ),
        ),
        TextButton(
          onPressed: () => focusNode.raw.requestFocus(),
          child: const Text('Fokusera'),
        ),
      ],
    );
```

### `useAnimationController`

Returnerar `(AnimationController, ReadonlyRef<double>)`. Ingen
`SingleTickerProviderStateMixin` behövs, och controllern disposas automatiskt.

```dart
final (controller, progress) = useAnimationController(
  duration: const Duration(milliseconds: 600),
);

onMounted(() => controller.forward());

return (context) => Opacity(
      opacity: progress.value,           // 0.0 → 1.0, builder körs om varje frame
      child: const Text('Välkommen till Kvittra!'),
    );
```

> 💡 **Tips:** Animationsvärdet ändras varje frame. Lägg det animerade i en liten
> separat widget eller en `ComputedBuilder` så att inte hela skärmen byggs om 60 gånger
> per sekund.

### InheritedWidget-composables: `useTheme`, `useMediaQuery`, `useContextRef`

Builder-funktionen körs bara om när **refs** ändras. Läser du `Theme.of(context)` eller
`MediaQuery.of(context)` direkt i builder-funktionen märker systemet inte när temat
eller skärmstorleken ändras.

```dart
// ❌ Uppdateras inte när temat byts (t.ex. mörkt läge)
return (context) {
  final theme = Theme.of(context);
  return Text('Hej', style: theme.textTheme.headlineSmall);
};

// ✅ Reaktivt
final theme = useTheme();
final titleStyle = computed(() => theme.value.textTheme.headlineSmall);
return (context) => Text('Hej', style: titleStyle.value);
```

| Composable | Returnerar | Ersätter |
|------------|-----------|----------|
| `useTheme()` | `ReadonlyRef<ThemeData>` | `Theme.of(context)` |
| `useMediaQuery()` | `ReadonlyRef<MediaQueryData>` | `MediaQuery.of(context)` |
| `useMediaQueryInfo()` | `(ReadonlyRef<Size>, ReadonlyRef<Orientation>)` | storlek och orientering var för sig |
| `usePlatformBrightness()` | `ReadonlyRef<Brightness>` | `MediaQuery.platformBrightnessOf` |
| `useTextScale()` | `ReadonlyRef<TextScaler>` | `MediaQuery.textScalerOf` |
| `useLocale()` | `ReadonlyRef<Locale>` | `Localizations.localeOf` |
| `useContextRef(selektor)` | `ReadonlyRef<T>` | Vilket `X.of(context)` som helst |

```dart
// Responsiv layout: en eller två kolumner
final (size, _) = useMediaQueryInfo();
final columns = computed(() => size.value.width < 600 ? 1 : 2);

// Egen InheritedWidget eller lokalisering
final l10n = useContextRef(
  (context) => AppLocalizations.of(context)!,
  equals: (a, b) => a.localeName == b.localeName,
);
```

`equals` bestämmer när värdet räknas som ändrat. Standard är `identical`.

### `useContext`: för imperativa anrop

Behöver du en `BuildContext` utanför builder-funktionen, t.ex. för att visa en dialog i
`onMounted`, finns `useContext()`. Den ger en `Ref<BuildContext?>` som är `null` tills
första build har körts.

```dart
final context = useContext();

onMounted(() {
  ScaffoldMessenger.of(context.value!).showSnackBar(
    const SnackBar(content: Text('Välkommen tillbaka!')),
  );
});
```

Använd den **inte** för att läsa tema eller mediaquery. Där gäller `useTheme` och
`useContextRef`.

### `manageValueListenable` och `manageChangeNotifier`

Har du redan en `ValueNotifier` eller `ChangeNotifier` från annan kod?

```dart
// Någon annanstans i appen:
final unreadCount = ValueNotifier<int>(0);

// I setup():
final (_, unread) = manageValueListenable(unreadCount);
final badge = computed(() => unread.value > 9 ? '9+' : '${unread.value}');
```

`manageChangeNotifier(x)` gör samma sak för en `ChangeNotifier` och anropar dessutom
`x.dispose()` vid unmount. Använd den bara om widgeten *äger* objektet.

---

## Del 2: Egna composables

### Vue ↔ Dart: samma idé

```ts
// Vue: useToggle.ts
import { ref } from 'vue'

export function useToggle(initial = false) {
  const state = ref(initial)
  const toggle = () => (state.value = !state.value)
  return { state, toggle }
}

// i en komponent:
const { state: isOpen, toggle } = useToggle()
```

```dart
// Dart: lib/composables/use_toggle.dart
import 'package:flutter_compositions/flutter_compositions.dart';

(Ref<bool>, void Function()) useToggle([bool initial = false]) {
  final state = ref(initial);
  void toggle() => state.value = !state.value;
  return (state, toggle);
}

// i setup():
final (isOpen, toggle) = useToggle();
```

I Vue returnerar man ett objekt och destrukturerar det. I Dart returnerar man oftast en
**record** och destrukturerar den med `final (a, b) = …`. För större composables är en
liten klass tydligare, som du ser nedan.

### Regler för composables

1. **Namnet börjar med `use`.** Det signalerar "måste anropas i `setup()`".
2. **Anropas bara från `setup()`** eller från en annan composable. Aldrig från en
   callback, `onMounted` eller builder-funktionen.
3. **Anropas ovillkorligt och i samma ordning varje gång.** Inga `if (x) useY();`.
4. **Ingen `BuildContext`-parameter.** Använd `useContextRef`/`useTheme` inuti.
5. **Städa det du startar.** Registrera `onUnmounted` för timers och prenumerationer.
6. **Returnera reaktiva värden** (`ReadonlyRef`/`Ref`), inte `.value`-ögonblicksbilder.
7. **Ta emot reaktiva indata** som `ReadonlyRef<T>`, eller en getter `T Function()`, om
   de kan ändras över tid.
8. **Exponera skrivskyddat när det går.** Returnera `ReadonlyRef` om anroparen inte ska
   skriva direkt.

### Exempel 1: `useDebounced`

Vänta tills användaren slutat skriva innan något händer, t.ex. när man söker efter
andra användare att följa.

```dart
import 'dart:async';
import 'package:flutter_compositions/flutter_compositions.dart';

ReadonlyRef<T> useDebounced<T>(
  ReadonlyRef<T> source, {
  Duration delay = const Duration(milliseconds: 300),
}) {
  final debounced = ref(source.raw);
  Timer? timer;

  watch(() => source.value, (value, _) {
    timer?.cancel();
    timer = Timer(delay, () => debounced.value = value);
  });

  onUnmounted(() => timer?.cancel());

  return debounced;
}
```

Användning:

```dart
final (searchController, search, _) = useTextEditingController();
final debouncedSearch = useDebounced(search);

final (status, _) = useAsyncData<List<User>, String>(
  (q) => service.searchUsers(q),        // t.ex. username ~ q || name ~ q
  watch: () => debouncedSearch.value,   // söker 300 ms efter sista tangenttrycket
);
```

`search` är en `WritableRef<String>`, och den kan skickas där en `ReadonlyRef<String>`
förväntas.

### Exempel 2: `useNow`, en tickande klocka

```dart
ReadonlyRef<DateTime> useNow({Duration interval = const Duration(seconds: 1)}) {
  final now = ref(DateTime.now());
  Timer? timer;

  onMounted(() {
    timer = Timer.periodic(interval, (_) => now.value = DateTime.now());
  });
  onUnmounted(() => timer?.cancel());

  return now;
}

// "Publicerat för 12 min sedan", uppdateras av sig själv
final now = useNow(interval: const Duration(minutes: 1));
final minutesAgo = computed(
  () => now.value.difference(post.value.created).inMinutes,
);
```

### Exempel 3: `useCommentComposer`

Kommentarsfältet under ett inlägg har mer logik än man tror: text, max 280 tecken, en
räknare för tecken kvar, ett felmeddelande, "får man skicka?", skickar-status och
tömning efter lyckad sändning. Lägger vi den i en composable blir skärmen ren och
logiken återanvändbar (samma fält kan användas för svar, gruppinlägg …).

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

class CommentComposer {
  const CommentComposer({
    required this.controller,
    required this.remaining,
    required this.counterLabel,
    required this.error,
    required this.canSend,
    required this.sending,
    required this.send,
  });

  final TextEditingController controller;
  final ReadonlyRef<int> remaining;
  final ReadonlyRef<String> counterLabel;
  final ReadonlyRef<String?> error;
  final ReadonlyRef<bool> canSend;
  final ReadonlyRef<bool> sending;
  final Future<void> Function() send;
}

/// Textfält + validering + skicka för en kommentar (max [maxLength] tecken).
CommentComposer useCommentComposer({
  required Future<bool> Function(String body) onSend,
  int maxLength = 280,
}) {
  final (controller, text, _) = useTextEditingController();
  final sending = ref(false);

  final trimmed = computed(() => text.value.trim());
  final remaining = computed(() => maxLength - text.value.length);
  final counterLabel = computed(() => '${remaining.value}');
  final error = computed<String?>(
    () => remaining.value < 0 ? '${-remaining.value} tecken för mycket' : null,
  );
  final canSend = computed(
    () => trimmed.value.isNotEmpty && remaining.value >= 0 && !sending.value,
  );

  Future<void> send() async {
    if (!canSend.value) return;
    sending.value = true;
    try {
      final ok = await onSend(trimmed.value);
      if (ok) text.value = ''; // tvåvägsbindning: tömmer fältet
    } finally {
      sending.value = false;
    }
  }

  return CommentComposer(
    controller: controller,
    remaining: remaining,
    counterLabel: counterLabel,
    error: error,
    canSend: canSend,
    sending: sending,
    send: send,
  );
}
```

Lägg märke till:

- `onSend` är en **callback** som returnerar `Future<bool>`. Composablen vet inget om
  PocketBase. Den som anropar bestämmer vart kommentaren skickas.
- `remaining`, `error` och `canSend` är en kedja av `computed`. Bara det som beror på
  texten räknas om när användaren skriver.
- Efter lyckad sändning töms fältet med `text.value = ''`, tack vare
  tvåvägsbindningen.

I skärmen:

```dart
@override
Widget Function(BuildContext) setup() {
  final props = widget();
  final composer = useCommentComposer(
    onSend: (body) => commentsService.add(props.value.postId, body),
  );

  return (context) => Row(
        children: [
          Expanded(
            child: TextField(
              controller: composer.controller,
              decoration: InputDecoration(
                hintText: 'Skriv en kommentar…',
                errorText: composer.error.value,
                suffixText: composer.counterLabel.value,
              ),
            ),
          ),
          IconButton(
            onPressed: composer.canSend.value ? composer.send : null,
            icon: const Icon(Icons.send),
          ),
        ],
      );
}
```

Samma composable används i kommentarerna i realtid i
[kapitel 10](10-arkitektur-for-en-riktig-app.md#kommentarer-i-realtid).

> 💡 **Tips:** Record eller klass? En composable som returnerar 2–3 saker kan använda en
> record: `(Ref<bool>, void Function())`. Returnerar den fler, eller ska den skickas
> vidare till andra widgets, är en liten klass med namngivna fält tydligare.

### Composables som använder andra composables

Composables kan anropa varandra fritt. Det är det som gör dem kraftfulla:

```dart
(ReadonlyRef<String>, ReadonlyRef<List<Post>>) usePostSearch(
  ReadonlyRef<List<Post>> allPosts,
) {
  final (_, query, _) = useTextEditingController();
  final debounced = useDebounced(query);
  final results = computed(() => allPosts.value
      .where((p) => p.title.toLowerCase().contains(debounced.value.toLowerCase()))
      .toList());
  return (debounced, results);
}
```

Allt som skapas, som controllern, watchern och timern, hör till widgeten som anropade
`setup()` och städas när den försvinner.

## 🧪 Prova själv

1. Skriv `useCounter({int initial = 0, int? max})` som returnerar
   `(ReadonlyRef<int> count, void Function() inc, void Function() dec)`. `inc` ska inte
   gå över `max`.
2. Använd `useCounter` två gånger i samma widget. Är räknarna oberoende? (De ska vara
   det: varje anrop skapar egna refs.)
3. Bygg en sökruta med `useTextEditingController` + `useDebounced` som skriver ut den
   debouncade texten med `watch`.

## Sammanfattning

- `use*` skapar och städar. `manage*` gör befintliga objekt reaktiva.
- `useTextEditingController` ger `(controller, text, value)`, vilket motsvarar Vues
  `v-model`. Skapa eller disposa aldrig textcontrollers själv.
- Skicka ref-inpackade controllers med `.raw`. Läs värden ur dem med `.value` i
  computed.
- Läs aldrig `Theme.of`/`MediaQuery.of` i builder-funktionen. Använd
  `useTheme`/`useMediaQuery`/`useContextRef`.
- Egna composables är vanliga funktioner som börjar med `use`. De anropas
  ovillkorligt från `setup()`, städar efter sig och returnerar reaktiva värden.

Nästa kapitel: [Provide och inject →](07-provide-inject.md)

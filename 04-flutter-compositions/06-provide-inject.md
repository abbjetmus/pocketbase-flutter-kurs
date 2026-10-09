# 6. Provide och inject

## Problemet: prop drilling

Föreningsappen behöver en PocketBase-klient och information om inloggad användare på
många ställen: anslagslistan, resurslistan, bokningsformuläret, "mina bokningar" och
utloggningsknappen. Skickar vi dem som props får vi *prop drilling*:

```dart
// ❌ Varje mellanliggande widget måste ta emot och skicka vidare pb och auth,
//    även om den själv aldrig använder dem.
HomeScreen(pb: pb, auth: auth)
  └─ ResourcesTab(pb: pb, auth: auth)
       └─ ResourceList(pb: pb, auth: auth)
            └─ BookButton(pb: pb, auth: auth)   // det är bara här de behövs
```

Lösningen är **dependency injection** med `provide` och `inject`:

- En förfader **tillhandahåller** (`provide`) ett värde under en nyckel.
- Vilken ättling som helst **hämtar** (`inject`) värdet med samma nyckel.

## `InjectionKey<T>`

En nyckel är en typad konstant:

```dart
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';

const pocketBaseKey = InjectionKey<PocketBase>('pocketBase');
const authServiceKey = InjectionKey<AuthService>('authService');
```

- **Typparametern** (`<PocketBase>`) gör att `inject(pocketBaseKey)` returnerar en
  `PocketBase`, inte `dynamic`. Kompilatorn hjälper dig.
- **Strängen** är ett namn som syns i felmeddelanden. Gör den beskrivande.
- Lägg nycklarna i en egen fil, t.ex. `lib/di/keys.dart` eller bredvid tjänsten.

## Vue ↔ Dart

Vue har exakt samma koncept, till och med med en typad `InjectionKey`:

```ts
// keys.ts
import type { InjectionKey, Ref } from 'vue'
import type PocketBase from 'pocketbase'

export const pocketBaseKey: InjectionKey<PocketBase> = Symbol('pocketBase')
```

```vue
<!-- App.vue -->
<script setup lang="ts">
import { provide } from 'vue'
import PocketBase from 'pocketbase'
import { pocketBaseKey } from './keys'

provide(pocketBaseKey, new PocketBase('http://127.0.0.1:8090'))
</script>
```

```vue
<!-- ResourceList.vue (djupt ner i trädet) -->
<script setup lang="ts">
import { inject } from 'vue'
import { pocketBaseKey } from './keys'

const pb = inject(pocketBaseKey)!
</script>
```

```dart
// keys.dart
const pocketBaseKey = InjectionKey<PocketBase>('pocketBase');

// app.dart
class ForeningsApp extends CompositionWidget {
  const ForeningsApp({super.key});

  @override
  Widget Function(BuildContext) setup() {
    provide(pocketBaseKey, PocketBase('http://127.0.0.1:8090'));
    return (context) => const MaterialApp(home: HomeScreen());
  }
}

// resource_list.dart (djupt ner i trädet)
class ResourceList extends CompositionWidget {
  const ResourceList({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final pb = inject(pocketBaseKey);   // typ: PocketBase
    // ...
    return (context) => const SizedBox();
  }
}
```

| | Vue | Flutter Compositions |
|---|---|---|
| Nyckel | `Symbol` typad som `InjectionKey<T>` | `const InjectionKey<T>('namn')` |
| Tillhandahålla | `provide(key, value)` i `setup` | `provide(key, value)` i `setup()` |
| Hämta | `inject(key)` → `T \| undefined` | `inject(key)` → `T` (kastar fel om saknas) |
| Standardvärde | `inject(key, default)` | `inject(key, defaultValue: …)` |
| App-nivå | `app.provide(...)` | `provide` i rot-widgetens `setup()` |

## Tillhandahålla PocketBase och auth i appens rot

Det vanligaste mönstret är en rot-widget som skapar tjänsterna en gång och tillhandahåller
dem till hela appen.

### En reaktiv `AuthService`

PocketBase-SDK:t ([02 – Dart SDK](../02-pocketbase/06-dart-sdk.md)) har en `authStore`
med en `onChange`-stream. Vi gör om den till en reaktiv `Ref`, så att alla widgets som
läser `auth.user.value` uppdateras automatiskt vid in- och utloggning.

```dart
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';

class AuthService {
  AuthService(this._pb) {
    user.value = _pb.authStore.isValid ? _pb.authStore.record : null;
    _pb.authStore.onChange.listen((event) {
      user.value = _pb.authStore.isValid ? event.record : null;
    });
  }

  final PocketBase _pb;

  /// Inloggad användare (en record i collection `users`) eller null.
  final Ref<RecordModel?> user = ref<RecordModel?>(null);

  late final ReadonlyRef<bool> isLoggedIn = computed(() => user.value != null);

  Future<void> login(String email, String password) =>
      _pb.collection('users').authWithPassword(email, password);

  void logout() => _pb.authStore.clear();
}

const pocketBaseKey = InjectionKey<PocketBase>('pocketBase');
const authServiceKey = InjectionKey<AuthService>('authService');
```

> 💡 **Tips:** `ref` och `computed` fungerar utmärkt i vanliga klasser. Det är bara
> `watch`, `watchEffect`, hooks, `provide` och `inject` som kräver `setup()`.

### Rot-widgeten

```dart
class ForeningsApp extends CompositionWidget {
  const ForeningsApp({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final pb = PocketBase('http://127.0.0.1:8090');
    final auth = AuthService(pb);

    provide(pocketBaseKey, pb);
    provide(authServiceKey, auth);

    return (context) => MaterialApp(
          title: 'Föreningsappen',
          home: auth.isLoggedIn.value
              ? const HomeScreen()
              : const LoginScreen(),
        );
  }
}
```

Lägg märke till `auth.isLoggedIn.value` i builder-funktionen. När användaren loggar in
ändras `user`, då ändras `isLoggedIn`, och rot-widgeten byggs om och visar `HomeScreen`.
(I [kapitel 9](09-arkitektur-for-en-riktig-app.md#router-och-auth-guard) ersätter vi det här med `go_router` och en `redirect`.)

### Hämta i en ättling

```dart
class LogoutButton extends CompositionWidget {
  const LogoutButton({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final auth = inject(authServiceKey);
    final name = computed(
      () => auth.user.value?.getStringValue('name') ?? 'Okänd',
    );

    return (context) => TextButton.icon(
          onPressed: auth.logout,
          icon: const Icon(Icons.logout),
          label: Text('Logga ut ${name.value}'),
        );
  }
}
```

## Tillhandahålla reaktiva värden

`provide` i sig är inte reaktivt. Värdet läses en gång av `inject`. Vill du dela
något som **ändras** tillhandahåller du en `Ref`:

```dart
const themeModeKey = InjectionKey<Ref<ThemeMode>>('themeMode');

class ForeningsApp extends CompositionWidget {
  const ForeningsApp({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final themeMode = ref(ThemeMode.system);
    provide(themeModeKey, themeMode);

    return (context) => MaterialApp(
          themeMode: themeMode.value,
          theme: ThemeData(colorSchemeSeed: Colors.teal),
          darkTheme: ThemeData(
            colorSchemeSeed: Colors.teal,
            brightness: Brightness.dark,
          ),
          home: const SettingsScreen(),
        );
  }
}

class SettingsScreen extends CompositionWidget {
  const SettingsScreen({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final themeMode = inject(themeModeKey);
    final isDark = computed(() => themeMode.value == ThemeMode.dark);

    return (context) => Scaffold(
          body: SwitchListTile(
            title: const Text('Mörkt läge'),
            value: isDark.value,
            onChanged: (on) =>
                themeMode.value = on ? ThemeMode.dark : ThemeMode.light,
          ),
        );
  }
}
```

### Skrivskyddat utåt

Ska ättlingar bara **läsa** värdet? Tillhandahåll en `ReadonlyRef` och exponera
ändringar via funktioner. Det är samma princip som Vues `readonly()`:

```dart
const cartCountKey = InjectionKey<ReadonlyRef<int>>('cartCount');

final count = ref(0);
provide(cartCountKey, count);   // Ref<int> är en ReadonlyRef<int>
```

En klass som `AuthService` ovan är ofta det tydligaste sättet att samla state och de
operationer som får ändra det.

## Standardvärden och valfria beroenden

Saknas en provider kastar `inject` ett `StateError` med ett tydligt meddelande. Är
beroendet valfritt anger du ett standardvärde:

```dart
const loggerKey = InjectionKey<Logger>('logger');

final logger = inject(loggerKey, defaultValue: ConsoleLogger());
```

## Scope: närmaste provider vinner

`inject` letar uppåt i widgetträdet och tar den **närmaste** providern. Det gör det
enkelt att byta ut en tjänst för en del av appen:

```dart
class DemoArea extends CompositionWidget {
  const DemoArea({super.key});

  @override
  Widget Function(BuildContext) setup() {
    // Inom DemoArea används en fejkad bokningstjänst
    provide(bookingServiceKey, FakeBookingService());
    return (context) => const ResourcesScreen();
  }
}
```

Providers försvinner automatiskt med widgeten som skapade dem.

## Testa med fejkade beroenden

Det här är en av de största vinsterna med DI. I ett test tillhandahåller du en fejk i en
`CompositionBuilder` runt widgeten du testar:

```dart
class FakeAuthService implements AuthService {
  @override
  final Ref<RecordModel?> user =
      ref<RecordModel?>(RecordModel({'id': 'u1', 'name': 'Anna'}));
  @override
  late final ReadonlyRef<bool> isLoggedIn = computed(() => user.value != null);
  @override
  Future<void> login(String email, String password) async {}
  @override
  void logout() => user.value = null;
}

testWidgets('LogoutButton visar namnet och loggar ut', (tester) async {
  final fake = FakeAuthService();

  await tester.pumpWidget(
    CompositionBuilder(
      setup: () {
        provide<AuthService>(authServiceKey, fake);
        return (context) => const MaterialApp(
              home: Scaffold(body: LogoutButton()),
            );
      },
    ),
  );

  expect(find.text('Logga ut Anna'), findsOneWidget);
  await tester.tap(find.byType(TextButton));
  await tester.pump();
  expect(fake.user.value, isNull);
});
```

Mer om tester i [kapitel 8](08-best-practices-och-lints.md).

## Anti-mönster

| ❌ | Varför | ✅ |
|----|--------|----|
| Globala variabler (`final pb = PocketBase(...)` på toppnivå) | Svårt att testa och byta ut | `provide` i roten, `inject` där det behövs |
| `provide` djupt ner i trädet "för säkerhets skull" | Svårt att se var värdet kommer ifrån | Provide på högsta rimliga nivå |
| `inject` i builder-funktionen eller i en callback | `inject` fungerar bara i `setup()` | Anropa i `setup()` och spara i en variabel |
| Ett vanligt (icke-ref) värde som ska ändras | Ättlingar ser aldrig ändringen | Tillhandahåll en `Ref` |
| En nyckel per *widget* | För finkornigt | En nyckel per *tjänst* eller delat state |

> ⚠️ **Varning:** `provide` gäller bara **ättlingar**. Syskon och förfäder ser inte
> värdet. Får du "No provider found for injection key" ligger widgeten troligen utanför
> det delträd där värdet tillhandahålls, eller så har du skapat en ny nyckel i stället
> för att återanvända samma `const`.

## 🧪 Prova själv

1. Skapa `const counterKey = InjectionKey<Ref<int>>('counter');`.
2. I en rot-`CompositionWidget`: `provide(counterKey, ref(0))`.
3. Skapa två *olika* ättlingar: en som visar värdet och en knapp som ökar det. Verifiera
   att de håller sig i synk utan att något skickas via props.
4. Lägg en ny `provide(counterKey, ref(100))` i en mellanliggande widget runt bara den
   ena ättlingen. Vad händer nu?

## Sammanfattning

- `InjectionKey<T>` ger typsäker DI. Samma idé som Vues `InjectionKey`.
- `provide(key, value)` i en förfaders `setup()`, `inject(key)` i en ättlings
  `setup()`.
- Tillhandahåll tjänster (PocketBase, AuthService) i appens rot.
- Tillhandahåll `Ref`s för delat state som ändras, eller en tjänsteklass med refs i.
- Närmaste provider vinner, vilket är perfekt för tester och lokala överskuggningar.

Nästa kapitel: [Asynkron data →](07-async-data.md)

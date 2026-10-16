# 6. Provide och inject

## Problemet

Nästan alla sidor i Kvittra behöver PocketBase och veta vem som är inloggad:
flödet, gilla-knappen, kommentarerna och profilen. Om vi skickar dem som props
måste varje widget på vägen ta emot dem och skicka dem vidare:

```
KvittraApp(pb, auth)
  └─ FeedPage(pb, auth)
       └─ PostList(pb, auth)
            └─ PostCard(pb, auth)   ← det är bara här de behövs
```

Det kallas *prop drilling*. Lösningen är `provide` och `inject`:

- En widget högt upp **lägger fram** (`provide`) ett värde.
- Vilken widget som helst längre ner **hämtar** (`inject`) det.

## InjectionKey

Ett värde läggs fram under en **nyckel**. Nyckeln talar om vilken typ värdet
har:

```dart
// lib/services/keys.dart
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';

import 'auth_service.dart';

const pocketBaseKey = InjectionKey<PocketBase>('pocketBase');
const authKey = InjectionKey<AuthService>('auth');
```

Texten `'pocketBase'` är bara ett namn som syns i felmeddelanden.

## provide och inject

```dart
// Högt upp, i setup():
provide(pocketBaseKey, PocketBase('http://127.0.0.1:8090'));

// Längre ner, i en annan widgets setup():
final pb = inject(pocketBaseKey); // pb är en PocketBase
```

| Vue | Flutter Compositions |
|-----|----------------------|
| `const key: InjectionKey<PocketBase> = Symbol()` | `const key = InjectionKey<PocketBase>('namn');` |
| `provide(key, pb)` | `provide(key, pb);` |
| `const pb = inject(key)!` | `final pb = inject(key);` |

⚠️ `provide` och `inject` fungerar bara **direkt i `setup()`**, inte i
builder-funktionen eller i en knapp.

## En AuthService som är reaktiv

Vi vill att appen ska uppdateras av sig själv när någon loggar in eller ut. Då
lägger vi den inloggade användaren i en `ref`, i en vanlig klass:

```dart
// lib/services/auth_service.dart
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';

class AuthService {
  AuthService(this.pb) {
    _update();
    // onChange skickar en händelse vid inloggning och utloggning
    pb.authStore.onChange.listen((_) => _update());
  }

  final PocketBase pb;

  /// Den inloggade användaren (en record i users), eller null.
  final user = ref<RecordModel?>(null);

  late final isLoggedIn = computed(() => user.value != null);

  /// Mitt id, eller '' om ingen är inloggad.
  String get myId => user.raw?.id ?? '';

  void _update() {
    user.value = pb.authStore.isValid ? pb.authStore.record : null;
  }

  Future<void> login(String email, String password) async {
    await pb.collection('users').authWithPassword(email, password);
  }

  void logout() => pb.authStore.clear();
}
```

- `ref` och `computed` fungerar i vanliga klasser också.
- När Anna loggar in ändras `pb.authStore`. Då körs `_update()`, och `user`
  får ett nytt värde. Alla widgets som läser `user.value` eller
  `isLoggedIn.value` uppdateras.
- `myId` läser med `.raw`, eftersom den används i vanliga funktioner och inte
  behöver bevakas.

⚠️ Paketet `pocketbase` har redan en klass som heter `AuthStore`. Döper du din
egen klass till `AuthStore` får du ett namnkrock-fel. Döp den till något annat,
som `AuthService`, eller importera med
`import 'package:pocketbase/pocketbase.dart' hide AuthStore;`.

## Appens rot

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';

import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'services/auth_service.dart';
import 'services/keys.dart';

void main() => runApp(const KvittraApp());

class KvittraApp extends CompositionWidget {
  const KvittraApp({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final pb = PocketBase('http://127.0.0.1:8090');
    final auth = AuthService(pb);

    provide(pocketBaseKey, pb);
    provide(authKey, auth);

    return (context) => MaterialApp(
          title: 'Kvittra',
          home: auth.isLoggedIn.value ? const HomePage() : const LoginPage(),
        );
  }
}
```

Builder-funktionen läser `auth.isLoggedIn.value`. När någon loggar in eller ut
ritas appen om och visar rätt sida. I kapitel 8 byter vi till `go_router`.

## Hämta tjänsten i en widget

```dart
// lib/widgets/logout_button.dart
class LogoutButton extends CompositionWidget {
  const LogoutButton({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final auth = inject(authKey);
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

Ingen förälder behöver skicka in något. `LogoutButton` hämtar `auth` själv.

## Inloggningssidan

```dart
// lib/pages/login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';

import '../services/keys.dart';

class LoginPage extends CompositionWidget {
  const LoginPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final auth = inject(authKey);
    final (emailController, email, _) = useTextEditingController();
    final (passwordController, password, _) = useTextEditingController();
    final loading = ref(false);
    final error = ref<String?>(null);

    final canLogin = computed(() =>
        email.value.contains('@') &&
        password.value.length >= 8 &&
        !loading.value);

    // Ta bort felet så fort användaren skriver något nytt
    watch(() => (email.value, password.value), (_, _) => error.value = null);

    Future<void> login() async {
      loading.value = true;
      try {
        await auth.login(email.value.trim(), password.value);
        // Ingen navigering här: appen byter sida av sig själv
      } on ClientException {
        error.value = 'Fel e-post eller lösenord';
      } finally {
        loading.value = false;
      }
    }

    return (context) => Scaffold(
          appBar: AppBar(title: const Text('Logga in på Kvittra')),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'E-post'),
              ),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Lösenord',
                  errorText: error.value,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: canLogin.value ? login : null,
                child: Text(loading.value ? 'Loggar in…' : 'Logga in'),
              ),
            ],
          ),
        );
  }
}
```

Logga in med `anna@example.com` och `kvittra123` från modul 01.

## Dela något som ändras

`provide` lägger fram värdet **en gång**. Ska värdet kunna ändras lägger du fram
en `ref`:

```dart
const themeModeKey = InjectionKey<Ref<ThemeMode>>('themeMode');

// I roten:
final themeMode = ref(ThemeMode.light);
provide(themeModeKey, themeMode);
// ... MaterialApp(themeMode: themeMode.value, ...)

// Längre ner:
final themeMode = inject(themeModeKey);
// ... onChanged: (on) => themeMode.value = on ? ThemeMode.dark : ThemeMode.light
```

## Bra att veta

| Situation | Vad händer? |
|-----------|-------------|
| Ingen har lagt fram nyckeln | `inject` ger ett fel: "No provider found" |
| Två widgets lägger fram samma nyckel | Den **närmaste** ovanför vinner |
| Widgeten som lade fram värdet försvinner | Värdet försvinner också |

## Övningar

**6.1** Skapa `const counterKey = InjectionKey<Ref<int>>('counter');`. Lägg fram
`ref(0)` i roten. Gör två olika widgets längre ner: en som visar talet och en
knapp som ökar det. Håller de sig i synk?

**6.2** Bygg `KvittraApp`, `LoginPage`, `LogoutButton` och en enkel `HomePage`
med `LogoutButton` i `AppBar`. Logga in som Anna och logga ut igen.

**6.3** Gör en widget `WhoAmI` som visar "Inloggad som @anna". Använd
`inject(authKey)` och en `computed` som läser `username` från `auth.user`.

**6.4** Vad händer om du lägger `inject(authKey)` i en widget som **inte**
ligger under `KvittraApp`, till exempel i ett test med bara
`MaterialApp(home: WhoAmI())`? Prova.

**6.5** Lägg till mörkt läge. Lägg fram en `Ref<ThemeMode>` i `KvittraApp` och
gör en switch på `HomePage` som byter tema.

Lösningar finns i [losningar.md](losningar.md#kapitel-6--provide-och-inject).

Nästa kapitel: [Hämta data](07-hamta-data.md)

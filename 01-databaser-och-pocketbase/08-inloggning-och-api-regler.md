# 8. Inloggning och API-regler

Hittills har du varit **superuser** i Dashboard. En superuser får göra allt.
Men när Kvittra-appen används är det vanliga **användare** (records i `users`)
som loggar in. De ska bara få göra vissa saker. Till exempel ska Anna inte kunna
ta bort Bertils inlägg.

Det styr man med **API-regler**.

## Två sorters konton

| Konto | Var finns det? | Vad får det göra? |
|-------|----------------|-------------------|
| **Superuser** | Settings → Superusers | Allt, i Dashboard. API-reglerna gäller inte |
| **Användare** | Collectionen `users` | Bara det som API-reglerna tillåter |

## Fem regler per collection

Öppna kugghjulet på en collection och välj fliken **API Rules**. Där finns fem
regler:

| Regel | Gäller när någon vill … |
|-------|------------------------|
| **List/Search** | se en lista med records |
| **View** | se en enskild record |
| **Create** | skapa en record |
| **Update** | ändra en record |
| **Delete** | ta bort en record |

Varje regel kan vara på tre sätt:

| Inställning | Hur det ser ut | Vem får? |
|-------------|----------------|----------|
| **Låst** | Ett hänglås 🔒 | Bara superusers. Så är det från början |
| **Tom** | Upplåst och tomt textfält | **Alla**, även de som inte är inloggade |
| **Villkor** | Upplåst med text | Bara om villkoret stämmer |

⚠️ En tom regel betyder att **hela internet** får göra det. Var försiktig med den.

## Villkor du behöver

| Villkor | Betyder |
|---------|---------|
| `@request.auth.id != ""` | Den som frågar är inloggad |
| `author = @request.auth.id` | Recorden är skriven av den som är inloggad |
| `@request.body.author = @request.auth.id` | Den nya recorden sätter `author` till den inloggade (används i Create) |
| `id = @request.auth.id` | Recorden är den inloggade användaren själv (används i `users`) |

`@request.auth` är den inloggade användaren. `@request.body` är det som skickas
in när man skapar eller ändrar något.

## Reglerna för Kvittra

**posts** (och **comments** på samma sätt)

| Regel | Villkor | På svenska |
|-------|---------|------------|
| List/Search | `@request.auth.id != ""` | Inloggade får se inlägg |
| View | `@request.auth.id != ""` | |
| Create | `@request.auth.id != "" && @request.body.author = @request.auth.id` | Man får bara skriva inlägg i sitt eget namn |
| Update | `author = @request.auth.id` | Bara författaren får ändra |
| Delete | `author = @request.auth.id` | Bara författaren får ta bort |

**likes**

| Regel | Villkor |
|-------|---------|
| List/Search, View | `@request.auth.id != ""` |
| Create | `@request.body.user = @request.auth.id` |
| Update | 🔒 låst (en like ändras aldrig) |
| Delete | `user = @request.auth.id` |

**follows**

| Regel | Villkor |
|-------|---------|
| List/Search, View | `@request.auth.id != ""` |
| Create | `@request.body.follower = @request.auth.id && @request.body.following != @request.auth.id` |
| Update | 🔒 låst |
| Delete | `follower = @request.auth.id` |

Create-regeln för `follows` stoppar också att man följer sig själv.

**users**

| Regel | Villkor | På svenska |
|-------|---------|------------|
| List/Search, View | `@request.auth.id != ""` | Inloggade får se andras profiler |
| Create | *(tom)* | Vem som helst får registrera sig |
| Update, Delete | `id = @request.auth.id` | Man får bara ändra och ta bort sig själv |

💡 E-postadresser visas inte för andra användare, så det är säkert att låta
inloggade se `users`.

## Testa i webbläsaren

PocketBase har ett **API** som apparna använder. Du kan läsa från det direkt i
webbläsaren. Öppna:

<http://127.0.0.1:8090/api/collections/posts/records>

Webbläsaren är **inte inloggad**, så du är en okänd besökare.

| Om List-regeln för `posts` är … | ser du … |
|---------------------------------|----------|
| 🔒 låst | ett felmeddelande om att bara superusers får göra det |
| tom | alla inlägg som JSON |
| `@request.auth.id != ""` | en tom lista, `"items": []` |

## Övningar

**8.1** Sätt List-regeln för `posts` till tom, och öppna länken ovan. Vad ser
du? Ändra sedan till `@request.auth.id != ""` och ladda om sidan. Vad händer?

**8.2** Skriv in reglerna för alla fem collections enligt tabellerna ovan.

**8.3** Varför räcker det inte att Create-regeln för `posts` är
`@request.auth.id != ""`? Vad skulle Anna kunna göra då?

**8.4** Bertil vill ta bort Annas like på Höstpromenad. Vilken regel stoppar
honom, och varför?

**8.5 Ditt projekt.** Skriv en regeltabell för ditt eget projekt. Vem ska få
se, skapa, ändra och ta bort i varje tabell?

Lösningar finns i [losningar.md](losningar.md#kapitel-8--inloggning-och-api-regler).

Nästa modul: [02 – Flutter](../02-flutter/README.md). Hur en Flutter-app loggar in och
hämtar data från PocketBase går vi igenom i
[modul 02, kapitel 6](../02-flutter/06-hamta-data-fran-pocketbase.md).

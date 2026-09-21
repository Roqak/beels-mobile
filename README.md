# Beels Mobile

Flutter app for Beels — a group savings (ajo/esusu) platform. Member-core
scope: authentication, dashboard, beels (contributions), transactions,
groups with invite links, and profile.

## Requirements

- Flutter 3.22.x (the repo is developed against the Flutter pinned at
  `~/tools/flutter`; run `source ~/tools/env.sh` to get Flutter, JDK 17 and
  the Android SDK on PATH).
- A NestJS backend exposing the Beels member API.

## Run

```bash
flutter pub get
flutter run
```

The API base URL and the web-frontend base URL (used for shareable payment
links) are compile-time constants:

```bash
flutter run \
  --dart-define=BEELS_BASE_URL=https://your-api.example.com \
  --dart-define=BEELS_FRONTEND_URL=https://your-web.example.com
```

Defaults point at the deployed Railway stack
(`https://dev-production-80a4.up.railway.app` and
`https://beels-frontend-production.up.railway.app`).

## Build

```bash
flutter build apk --debug   # build/app/outputs/flutter-apk/app-debug.apk
```

`android/gradle.properties` caps the Gradle JVM at `-Xmx1536m` for
low-memory machines; raise it when building on beefier hardware.

## Tests

```bash
flutter analyze
flutter test
```

- `test/_visual/golden_screens_test.dart` renders four golden screenshots
  (`login`, `dashboard`, `beels list`, `beel detail`) at 780×1688 and
  pixel-compares them. Regenerate after an intentional UI change with
  `flutter test test/_visual --update-goldens`.
- Fonts (Inter, Bricolage Grotesque) are bundled as assets under
  `assets/google_fonts/`, so the app renders offline and widget tests do not
  fetch fonts at runtime. google_fonts 6.x registers them to the engine as
  `<Family>_<variant>` families; the golden harness preloads all weights in
  `setUpAll` to avoid async font-load races.

## Backend contract notes

The NestJS API drives a few non-obvious rules baked into the app:

- Auth returns the bearer token at the top level (`access_token`), while
  most list endpoints nest payloads as `data.data`.
- `POST /contributions/closed` and `POST /contributions/open` reject
  `day_of_week` for non-weekly and `day_of_month` for non-monthly beels.
  The payload builders in `lib/features/beels/data/beels_repository.dart`
  gate those fields on `recurrence_type`.
- A closed beel is created only after every contributor pays; the create
  response contains no id, so the UI returns to the beel list. Open-link
  beels return a `payment_link_token` and the app deep-links to
  `<frontend>/pay/join/<token>`.
- Cancellation is only offered for recurring beels (`canCancel`).
- Numeric fields may arrive as strings (`"10000"`); models coerce them.

## Android

- `minSdk 24`, adaptive launcher icon (`mipmap-anydpi-v26`) with a vector
  foreground; API 25 and below fall back to the bundled PNG mipmaps.
- `AndroidManifest.xml` declares `INTERNET` only.
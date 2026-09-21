# beels-mobile — Agent Guide

Guidance for AI agents (and humans) working in this repo. Read this before changing anything.

## Project

Beels (ajo/esusu group savings fintech) member app. Flutter, Android-first, iOS-ready later.
Backend: NestJS at `https://dev-production-80a4.up.railway.app` (source: `../beels`).
Web frontend reference: `../beels-frontend`. PRD: `../PRD.md`.

Shipped scope (v0.1.0 + main): auth (password login, register, forgot password, session), biometric quick-unlock (local_auth; lock screen at boot when enabled, profile toggle), dashboard, beels (list/detail/create/cancel/retry/disburse), transactions, groups with invite links, profile. Out of scope for now: bills payment, chatbot, financial wrapped.

## Environment (this machine — non-negotiable)

- Flutter 3.22.3 (Dart 3.4) at `~/tools/flutter`. ALWAYS `source ~/tools/env.sh` first (exports `JAVA_HOME=~/tools/jdk17`, `ANDROID_HOME=~/tools/android-sdk`, PATH). Do NOT download another SDK.
- 16 GB RAM machine with ~13 GB consumed by unrelated services. Expect flutter/gradle commands to take 1–5 min; long ones auto-background after ~2 min and deliver results later. Run heavy commands with `timeout: 0` (no deadline) as background jobs, never two flutter commands at once.
- JDK 17 only. Never touch other projects' gradle daemons (e.g. `/home/akinkunmi/projects/USSD` builds).

## APK builds and releases

### Build config (USSD-parity, do not "optimize" it)

`android/gradle.properties` stays:

```
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
android.useAndroidX=true
android.enableJetifier=true
```

Do NOT add `org.gradle.workers.max`, `org.gradle.parallel=false`, or `org.gradle.daemon=false` — restricting workers/heap makes builds SLOWER and longer-lived under memory pressure, which is what causes OOM kills on this box. Plain defaults + patience win.

### Commands

```bash
source ~/tools/env.sh && flutter build apk --release   # ~5 min, first clean build longer
```

- Output: `build/app/outputs/flutter-apk/app-release.apk` (all 3 ABIs, ~50 MB).
- Debug build: `flutter build apk --debug` (same duration; only needed for install-debug checks).

### Signing (same pattern as USSD)

- Release key: `android/beels-release.keystore` + `android/keystore.properties` (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`). Both are **gitignored and local-only**. Losing them orphans the update chain — back them up.
- `android/app/build.gradle` reads `keystore.properties` at the **gradle root (`android/`)** — note: for Flutter that is `android/`, not the repo root.
- Without the properties file the release build falls back to debug signing (CI-safe).
- Verify a built APK: `~/tools/android-sdk/build-tools/*/apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk` → expect `CN=Beels Mobile, O=Beels, C=NG`.

### Known build pitfalls

- **Duplicate kotlin classes** (`kotlin.collections.jdk8.*` in checkDebugDuplicateClasses): fixed via the `constraints { implementation(kotlin-stdlib-jdk7/jdk8: 1.8.22) }` block in `android/app/build.gradle`. Do not remove.
- A build that exits 0 with **no APK** means the gradle client died mid-run — just re-run; do not reconfigure anything.
- Never run `flutter test` and `flutter build apk` concurrently — compile-step OOM under contention.

### Release checklist (vX.Y.Z)

GitHub Actions is currently **blocked by a billing lock** on this account (CI fails in seconds with no steps run). Releases are therefore built locally, like USSD:

1. `flutter analyze` → "No issues found".
2. `flutter test -j 1 --timeout 600s` → all green (currently 136 tests incl. 4 goldens).
3. Bump `version:` in `pubspec.yaml` (e.g. `0.2.0+2`).
4. `flutter build apk --release`; verify signature (see above).
5. Commit, `git tag vX.Y.Z`, push `main` + tag.
6. `gh release create vX.Y.Z --title "Beels Mobile vX.Y.Z — <summary>" --notes-file <notes.md>` then `gh release upload vX.Y.Z <copy-of-apk-named-beels-mobile-vX.Y.Z.apk>`.
   - Note: snap-installed `gh` cannot read files under `/tmp` (snap confinement) — keep release notes and the APK copy inside the repo dir, and delete them after upload.
7. Release notes format (match v0.1.0): "What's new" bullets + "## APK" section with size, signing digest, ABI coverage.

## Backend contract rules (hard-won, verified live)

- Envelope: `{statusCode, message, data}`; `access_token` is TOP-LEVEL on login responses. Validation errors can arrive as 401/422 with `message` as string or array — `ApiException.fromResponse` joins arrays.
- Pagination: **`/transactions` REQUIRES `page`** (400 without it). Send `{page: N, per_page: M}` on all list endpoints. `/contributions` tolerates missing `page`.
- Groups list payload is double-nested: `data.data`.
- Recurrence gating: `day_of_week` is weekly-only, `day_of_month` monthly-only — enforce in beels create payloads (both closed and open).
- Closed beel create returns NO `id` (pop to list); open create returns `payment_link_token`.
- Beneficiary allocations in a beel create must sum to the beel `amount` (mismatch → 401 "Beneficiary Allocation Mismatch").
- Contributor rows in `GET /contributions/:id` include `payment_id` and `quick_debit_identifier` (only `meta` is excluded). `GET /contributions/my-participation` does NOT include them (computed projection only).
- Payments surface (verified on dev API): `POST /payment/initialize {payment_id}` → `data.url` (Flutterwave checkout; currently 500s in dev — gateway keys absent); `GET/POST /contributions/contributors/quick-debit/:identifier`; `POST /payment/verify {transaction_reference, transaction_id}`.
- Mandates surface (auth): `GET /mandate`, `POST /mandate/name-enquiry {account_number, bank_code}` → `data.account_name`, `POST /mandate/setup {first_name,last_name,email,phone_number,account_number,bank_name,bank_code,bvn}` (bvn 11 digits), `DELETE /mandate/:id`. Bank list: `GET /get-banks?pwa_enabled_only=false` → `data.banks[]` with `bank_name`, `bank_cbn_code`, `logo_url`.
- Smoke account on the dev API: `smoke.mobile+1@beels.test` / `smoke-test-123` (do NOT commit these anywhere in the repo).

## Code conventions

- State: flutter_riverpod 2.6 — `Notifier`/`AsyncNotifier`; transitional states carry previous data (`unwrapPrevious()`; `isAuthenticated` = `state.unwrapPrevious().valueOrNull != null`).
- Router: go_router 14, shell with 4 branches (`/`, `/beels`, `/transactions`, `/groups`), protected routes redirect via auth state.
- Models: every `fromJson` tolerant — nullable stays nullable, unknown keys ignored, numeric fields accept int/double/String.
- No new dependencies without explicit user approval (contract rule).
- UI text English, **no emojis** in UI code. Theme tokens in `lib/core/theme.dart` (accent `#4F46E5`).
- Tests mirror `lib/` under `test/`; run `flutter test -j 1 --timeout 600s`.
- Goldens in `test/_visual/goldens/`: after a legitimate UI change regenerate with `flutter test test/_visual --update-goldens`, then pixel-audit with python3+Pillow (corner `#FCFCFE`, no overflow stripes) — no vision model on this machine, don't try image reads.
- Fonts: 8 static TTFs bundled in `assets/google_fonts/`; engine family names are `<Family>_<variant>` (`Inter_regular`, …); `GoogleFonts.config.allowRuntimeFetching = false`.

## Definition of done

`flutter analyze` clean + full suite green + (if UI-shipped) release APK built and verified before pushing a release tag. Never push a tag without a locally built, signature-verified APK attached to its GitHub release.
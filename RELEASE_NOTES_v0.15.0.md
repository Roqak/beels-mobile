# Release notes — Beels Mobile v0.15.0

## Polish and hardening

### Fixes
- **Beel amounts that only differ in rounding no longer rejected**: contributor and payout sums now compare in exact kobo, so `100.10 + 50.05 + 49.85` against a ₦200 target is accepted (previously it failed with a confusing "₦200 vs ₦200" message).
- **No more startup crash loop**: if Android's Keystore-backed secure storage becomes unreadable (OS update, backup restore), the app now degrades to a normal re-login instead of dying before any UI.
- **A 401 on login no longer logs you out globally**: wrong-password attempts no longer clear the session or interrupt other requests; only requests that actually carried a token can trigger sign-out.
- **Dashboard and groups pull-to-refresh** keep the current data on screen instead of flashing back to a skeleton.
- **Friendlier errors everywhere**: unexpected errors (malformed payloads, raw exception text) no longer reach the screen; error views normalize internally, removing crash-prone casts.

### UX
- Text palette now meets WCAG AA on light mode (muted metadata text darkened; hint text aligned), and the dark accent was lifted above the contrast threshold on dark mode.
- Filter chips announce their selected state to screen readers; touch targets on filter chips, the hide-balances control and "Pay now" now meet the 44 dp minimum.
- Dark mode no longer flashes white at cold start: day/night splash backgrounds match the app surface.

### Hardening
- **In-progress beel drafts survive app restarts** — a phone call, app kill or background reclaim no longer destroys a half-finished beel. The draft is saved after every change and cleared on successful creation or discard.
- **Token ciphertext excluded from Android backups** (`allowBackup="false"`), which also removes the main trigger for corrupted-storage crash loops.
- **Release builds fail fast** if the release keystore is missing (instead of silently producing a debug-signed "release" APK), and refuse to run release binaries that point at the dev backend. CI smoke-builds the debug variant.

## Notes
- APK signed with the Beels release key (`CN=Beels Mobile, O=Beels, C=NG`).
- Remember to back up `android/beels-release.keystore` and `android/keystore.properties` — gitignored, local-only.
- Regenerated golden snapshots reflect the accessible palette and control sizes (Pillow-audited: surface corners, no overflow stripes).
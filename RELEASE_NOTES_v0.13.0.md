# Release notes — Beels Mobile v0.13.0

## Automated collection from bank accounts (auto-debit)
- Contributor rows on a beel now surface **Set up auto-debit** when automated collection is available: the organizer taps once and the app requests the OnePipe confirmation account and shows it in a sheet (account number, bank, name, expiry) with copy support.
- The contributor sends the one-time 100 naira confirmation deposit to that account; recurring billing activates automatically once it lands.
- States are visible at a glance: **Auto-debit pending** (confirmation deposit not yet received) and **Auto-debit on** (recurring billing active) chips on the contributor card. The action re-opens the account sheet for pending activations.
- Hidden for settled/cancelled contributors and when the contributor's bank details are unknown.

## Fixes
- Dashboard greeting no longer depends on the device clock in golden tests — the time-of-day line is now driven by the app's injectable clock, ending time-of-day golden flakiness.
- Golden failure artifacts under `test/_visual/failures/` are no longer committed to the repo (gitignored).

## Notes
- APK signed with the Beels release key (`CN=Beels Mobile, O=Beels, C=NG`).
- Remember to back up `android/beels-release.keystore` and `android/keystore.properties` — gitignored, local-only.
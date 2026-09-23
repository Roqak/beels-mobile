# Release notes — Beels Mobile v0.14.0

## Member view: Beels I pay into
- Profile → **Participation → Beels I pay into**: the member side of ajo is finally in the app. Every beel you pay into (joined via a payment link or added by an organizer) shows: paid vs expected amount, outstanding balance, pending payment count, next occurrence and last payment date.
- Pull-to-refresh, skeletons, friendly error retry, and an empty state that explains how to join.

## Group health on beel detail
- New **Group health** card on a beel: nightly composite health score (0-100) with a risk chip (Healthy / Watch / At risk / Critical), whether the beel is on pace for its target, and the collection shortfall / late-contributor summary.
- Suggested interventions from the backend run in-app: **Nudge late contributors** sends reminder emails with one tap and confirms with "Nudge sent to X of Y late contributors". Manual suggestions (extend cycle, pause withdrawals, reduce amount) are surfaced with their guidance.
- The card appears only when the backend serves a report; on backends without the group-health module it degrades to nothing instead of showing an error.

## Fixes
- Beel detail no longer reserves dead space where the health card would be hidden; hidden sections collapse completely.

## Notes
- APK signed with the Beels release key (`CN=Beels Mobile, O=Beels, C=NG`).
- Remember to back up `android/beels-release.keystore` and `android/keystore.properties` — gitignored, local-only.
- Note: the current dev backend does not yet deploy the group-health module (404s); the mobile UI is built to the backend contract in `beels/src/group-health` and will light up once deployed.
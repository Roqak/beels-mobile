# Release notes — Beels Mobile v0.16.1

## Fixes
- **Direct debit setup messaging.** After submitting a mandate, the app now says
  "Direct debit mandate submitted" instead of implying the mandate was already
  active. The mandate only becomes debitable once your bank approves the
  instruction and Beels receives the activation notification; the mandate list
  already shows that state as a Pending chip.

## Notes
- No backend behaviour change for the app itself; the backend counterpart is the
  direct-debit mandate lifecycle (pending → active via webhook) — see the
  beels repo release notes when it ships.
- APK signed with the Beels release key (`CN=Beels Mobile, O=Beels, C=NG`).
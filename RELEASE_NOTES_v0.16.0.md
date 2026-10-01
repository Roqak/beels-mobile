# Release notes — Beels Mobile v0.16.0

## New: tap-to-join Beels (NFC)
- **Invite nearby friends without typing anything.** On a beel you own, tap the
  contactless "Invite nearby" button, pick how many friends are joining, and
  hold your phone near theirs. Your phone acts as an NFC tag; their phone opens
  the beel invite automatically.
- The friend sees the beel name, organizer, their share, and slots left, then
  accepts or declines. Details (name, email, phone) come straight from their
  signed-in account — nothing to type.
- Friends with the app jump straight in; without it, the tap opens a web join
  page in the browser. Every invite also shows a QR code and a shareable link
  as fallbacks.
- Invites are short-lived (15 minutes) with a slot count you choose, so a
  stale or passed-around invite adds nobody who wasn't meant to join.

## Fixes
- Repository test expectations aligned with the v0.15.2 money convention
  (app speaks naira; API speaks kobo).

## Notes
- NFC tap-to-join requires both phones on Android with NFC; the QR/link
  fallback works everywhere. iPhone users: use the QR or link.
- APK signed with the Beels release key (`CN=Beels Mobile, O=Beels, C=NG`).
- Backend counterpart: invites API + migration `20261001130000-create-beel-invites`.
  The backend must deploy with the migration applied before invites work.
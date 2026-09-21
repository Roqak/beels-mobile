## What's new

**Dark mode**
- The app follows your phone's light/dark setting and switches live. Indigo-tinted night palette; the indigo hero panels and turmeric accents carry over.

**More screens on the Adire Ledger identity**
- Transactions: pinned All / Deposits / Withdrawals filters, grouped by Today / Yesterday / date, direction icons and a type label on each row.
- Groups: indigo initial tiles with overlapping member avatars. Group detail has an indigo banner.
- Profile: indigo banner with your details; Account is now a settings list, and Edit profile / Change password open in bottom sheets.
- Lock screen: full-bleed indigo with a turmeric fingerprint tile.
- Create beel: always-visible naira sign, full-width Closed / Open link selector with a one-line explanation of each.

## Fixes
- "successful" transactions now show as green (they were shown as neutral grey).
- Floating labels no longer clip in filled text fields; long transaction dates wrap instead of truncating.

## Notes
- Switching between light and dark rebuilds the screens, so any half-typed form text is lost. Navigation position is kept.
- Dark mode has been reviewed on Home, Transactions and Login; other screens use the same tokens but have not been reviewed individually.

## APK
- Size: ~52 MB, all 3 ABIs.
- Signed with the Beels release key (`CN=Beels Mobile, O=Beels, C=NG`).
- Version 0.5.0 (build 5). 188 tests passing, `flutter analyze` clean. Not yet verified on a physical device.

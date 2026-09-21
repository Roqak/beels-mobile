## What's new

**UI/UX overhaul (same brand, higher craft)**
- Dashboard: total deposited as a single indigo hero panel with withdrawn beneath, tappable Beels/Transactions counters, grouped recent activity, time-of-day greeting.
- Beels: cards rebuilt with schedule row and press feedback. Beel detail shows a collected-vs-expected progress bar, contributor avatars, section counts and empty states.
- Skeleton loading on every list and detail screen instead of spinners (respects reduced motion).
- Status chips now carry an icon so state never relies on colour alone; amounts use tabular figures.
- Haptics on tab changes, confirmations, copy, success and errors.
- Create beel / group: animated review step, chained keyboard actions, digits-only money fields, drag-to-dismiss keyboard.
- Direct debit setup: progress bar stepper, searchable bank picker, digits-only account (10) and BVN (11), verified-account confirmation with icon.
- Group detail: invite link pill, grouped member list, 48px tap targets, red destructive confirmations.
- Login, lock screen and profile refreshed; all screens use shared theme tokens.

## Fixes
- Removed leftover lints; `flutter analyze` is clean.

## APK
- Size: ~52 MB, all 3 ABIs (arm64-v8a, armeabi-v7a, x86_64).
- Signed with the Beels release key (`CN=Beels Mobile, O=Beels, C=NG`).
- SHA-256 of signing cert: `078938932528e9da62e3aa622be02530f56266d26f9c32eb524ace9a9bc8550a`.
- Tests: 178 passing (4 goldens regenerated). Not yet verified on a physical device.

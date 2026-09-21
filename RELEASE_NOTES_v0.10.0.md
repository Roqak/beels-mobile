## What's new

**Home, in the style of a trading app**
- **Net flow chart:** a card under the banner shows your net flow (settled deposits minus withdrawals) as a big figure with a line chart. Choose 1W, 1M, 3M or All. Touch and drag along the line to read the value and date at your finger, with a light haptic tick at each point. The line draws itself in.
- **Quick actions:** New beel, Groups and Direct debit as round buttons under the balance.

**Floating navigation**
- The bottom bar is now a floating pill with a raised centre **Create** button. It opens a sheet with New beel, New group and Set up direct debit.
- The separate floating buttons on Home, Beels and Groups are gone. Beels and Groups have a + in the top bar, and their empty states have a create button.
- Screen readers now announce each tab once (they were reading the name twice).

## Notes
- The chart uses your most recent 50 transactions, so "All" means all loaded activity, not your full history. Only settled transactions count. If the chart data cannot load, that section hides and the rest of Home is unaffected.
- The card-to-detail expand transition is not included; pages still fade in with a short rise.

## APK
- Size: ~52 MB, all 3 ABIs.
- Signed with the Beels release key (`CN=Beels Mobile, O=Beels, C=NG`).
- Version 0.10.0 (build 10). 258 tests passing, `flutter analyze` clean. Not yet verified on a physical device.

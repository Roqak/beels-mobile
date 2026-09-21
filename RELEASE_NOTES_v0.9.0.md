## What's new

**Status filters on Beels**
- The Beels list now has filter chips: All plus a chip for each status present (Active, Pending, Processing, Completed, Failed, Cancelled, in that order). No chip appears for a status you have none of, and the row is hidden when every beel has the same status.
- Filters apply to the beels already loaded. When more pages exist, a **Load more** button appears under a filtered list (a short filtered list cannot scroll far enough to load more by itself). Transactions gets the same button.
- Transactions and Beels now share one filter-chip component, so they look and behave the same. It scrolls sideways if there are more chips than fit.

**Choose your auto-lock delay**
- Profile > Security > **Lock after**: Right away, 30 seconds, 1 minute or 5 minutes. Saved on your phone. Only shown when biometric login is on.
- The default is now 1 minute (it was a fixed 45 seconds). "Right away" keeps about 3 seconds of grace so the system fingerprint dialog cannot immediately re-lock a session it just unlocked.

## Fixes
- Filter chips were centred instead of left-aligned when placed in a column; they now start at the left edge.

## APK
- Size: ~52 MB, all 3 ABIs.
- Signed with the Beels release key (`CN=Beels Mobile, O=Beels, C=NG`).
- Version 0.9.0 (build 9). 239 tests passing, `flutter analyze` clean. Not yet verified on a physical device.

# Release notes — Beels Mobile v0.15.2 (fix)

## Fix
- **Money amounts displayed 100× too large**: the backend stores every amount in
  kobo; the web app converts but the mobile app rendered the raw numbers. A ₦500
  beel showed as "₦50,000 total", a ₦100 share as "₦10,000". Beel details,
  transactions, Home stats (net flow, totals), and group-health figures now read
  naira directly.
- **Beels created from the app were stored 100× too small**: the creation
  payload sent naira where the backend expects kobo, so typing ₦500 actually
  created a ₦5 beel — it looked right on the phone but anyone paying through the
  payment link was charged kobo-level amounts. Creation now sends proper kobo.

## Notes
- Beels created from the app **before** this release are mis-sized (1/100 of the
  intended amount). Recreate them instead of editing.
- APK signed with the Beels release key (`CN=Beels Mobile, O=Beels, C=NG`).
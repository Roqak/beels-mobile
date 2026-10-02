# Release notes — Beels Mobile v0.16.2

## New: pay your share in one tap
- **"Beels I pay into" now has a Pay now action** on anything you owe. It opens
  a native payment screen with your two options:
  - **Direct debit** — every account you have linked for automatic collection
    appears as a card; tap one and confirm. OnePipe debits it immediately and
    the beel updates on the spot (no waiting for a banking app or manual
    transfer).
  - **Bank transfer** — same fallback as the web: account details and your
    payment reference, right in the app.
- Paying from the app shows a receipt (amount + reference) and the beel's
  outstanding balance refreshes when you go back.

## Notes
- Same payment endpoints as the web pay page — behavior between app and web is
  identical, keyed by the payment link's reference.
- Linked accounts follow your mandate activation: only accounts your bank has
  approved (active) are offered for debit. Pending ones keep out of the way
  until they activate.
- APK signed with the Beels release key (`CN=Beels Mobile, O=Beels, C=NG`).
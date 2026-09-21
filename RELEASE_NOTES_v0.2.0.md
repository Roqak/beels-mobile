# Release notes — Beels Mobile v0.2.0

## Payments (pay now)
- Beel detail: contributors with an outstanding payment now show a **Pay now** action. It initializes a Flutterwave checkout with the backend (`POST /payment/initialize`) and hands the checkout URL to the system **share sheet** so you can open it in any browser. The beel refreshes afterwards; the payment itself settles asynchronously via webhook.
- Pay now is hidden for settled/cancelled contributors and for contributors without a server payment reference.

## Direct debit mandates
- Profile → **Mandates**: list your direct debit mandates with bank, masked account and status.
- **Set up mandate** wizard: pick a bank, verify the account (name enquiry), review, then submit personal details + BVN (`POST /mandate/setup`).
- **Revoke** a mandate with a confirmation dialog (`DELETE /mandate/:id`).

## Fixes
- Mandate setup submit no longer leaves the button stuck in a loading state when the API rejects the request.
- Contributions parse the `payment_id` field, enabling per-contributor payment actions.

## Known limitations
- `POST /payment/initialize` returns **HTTP 500 in the current dev/staging backend** until Flutterwave gateway keys are configured; the app surfaces a "Payment link unavailable" message in that case.
- Opening the checkout in an in-app browser (instead of the share sheet) is planned — needs the `url_launcher` dependency (upgrade path is a one-line change).
- Quick-debit activation from `my-participation` is deferred; the backend projection does not expose `quick_debit_identifier` yet.

## Notes
- APK signed with the Beels release key (`CN=Beels Mobile, O=Beels, C=NG`).
- Remember to back up `android/beels-release.keystore` and `android/keystore.properties` — they are gitignored and exist only on the build machine.
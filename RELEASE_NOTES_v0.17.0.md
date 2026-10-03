# Release notes — Beels Mobile v0.17.0

## New: list what you are collecting for
- **"How much do you want to collect?" now offers One total or List items.**
  With List items you add each thing the money is for (e.g. Cleaner ₦23,000,
  Light for pumping ₦10,000) and where its money goes. The beel's target is
  the sum, shown live as you add items.
- Items come right after the name, before the schedule and the people, so the
  flow matches how organisers already work it out: items first, then split.
- Splitting evenly still works to the kobo: ₦33,000 between 14 people is
  ₦2,357.14 each, with a few people paying 1 kobo more so it adds up exactly.
- Each item is paid directly to its own account or bill when the beel pays out.

## New: data, cable TV and electricity payouts
- Bills payouts now use real provider lists instead of typed names:
  - **Data and cable TV**: pick the provider, then a plan from a priced list.
    The plan sets the amount.
  - **Airtime and electricity**: pick the network or electricity company, then
    enter the amount.
- All payout types can be items.

## Fixes
- Data, cable TV and electricity payouts were rejected when creating a beel,
  and airtime sent the network's name where the provider id was needed.

## Notes
- No backend changes are needed for itemised beels; the electricity payout fix
  ships separately on the backend.
- APK signed with the Beels release key (`CN=Beels Mobile, O=Beels, C=NG`).

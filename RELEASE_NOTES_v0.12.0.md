## What's new

**Automatic split: the app works out what each person pays**
On the "Who is paying?" step you can now choose how amounts are decided:
- **Split evenly (new default):** you just add the people. Each person's share is worked out for you (the target divided between everyone, exact to the kobo) and updates live as people are added or removed. The Add person sheet no longer asks for an amount, and a line pinned above Continue shows the maths ("₦60,000 ÷ 3 = ₦20,000 each"). If it does not divide exactly, a few people pay 1 kobo more so the total is always exact, and the app says so ("about ₦33.33").
- **Set amounts myself:** the previous behaviour, for uneven shares. Switching to it copies the current shares into each person so you can adjust from there; the running total still shows how much is left.

The created beel carries the derived amounts, and Review shows each person's share.

## Notes
- The default changed: new beels start on **Split evenly**. Choose **Set amounts myself** for uneven shares.
- Open-link beels already split evenly or by a fixed price and are unchanged. Payout accounts keep their own "Split equally" button.

## APK
- Size: ~52 MB, all 3 ABIs.
- Signed with the Beels release key (`CN=Beels Mobile, O=Beels, C=NG`).
- Version 0.12.0 (build 13). 338 tests passing, `flutter analyze` clean. Not yet verified on a physical device.

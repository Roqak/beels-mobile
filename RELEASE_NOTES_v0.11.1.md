## What's new

**No more scrolling up and down when adding payers or payout accounts**
The two busiest steps of New beel were long inline forms with the running total at the top and the Add button at the bottom, so with the keyboard open you kept scrolling back and forth. They now work like this:

**Who is paying**
- Each person is one compact row (number, name, phone, amount). Tap a row to edit it.
- **Add person** opens a small sheet with just that person's fields. The amount is pre-filled with what is left to assign.
- **Save and add another** keeps the sheet open for the next person ("Added Ada Obi"), clears the fields and offers the new remainder, so adding several people is a quick loop.
- If something is missing, the sheet shows it under the field and does not save.
- The running total ("₦40,000 of ₦60,000 assigned, ₦20,000 left" then "All set") is pinned just above Continue, so you never scroll up to check it.
- "Add person" and "From contacts" wrap onto two lines on narrow screens or with large text instead of squeezing each other.

**Where should the money go?**
- Accounts are rows too, with one focused sheet for the type, bank, account number (with the name lookup) and name.
- Adding a second account suggests half of the target, and the first account automatically takes the rest so they add up.
- **Split equally** appears once there are two or more accounts, and the total is pinned here as well.

## Notes
- Rules are unchanged: contributor amounts and payouts must add up to the target, and a single payout takes the whole target.
- Keyboard behaviour with the new sheets has not been checked on a physical device.

## APK
- Size: ~52 MB, all 3 ABIs.
- Signed with the Beels release key (`CN=Beels Mobile, O=Beels, C=NG`).
- Version 0.11.1 (build 12). 321 tests passing, `flutter analyze` clean. Not yet verified on a physical device.

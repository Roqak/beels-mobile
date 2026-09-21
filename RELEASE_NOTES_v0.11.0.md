## What's new

**A guided "New beel" flow**
Creating a beel is now five short steps with a progress bar, one decision per step, instead of one long form.
1. **What are you collecting for?** Choose "I choose the people" or "Anyone with a link", then name it and set the target. Amounts get thousands separators as you type.
2. **When does it repeat?** Tap chips for how often; day pickers appear only when needed, with a sentence showing the result ("Every Friday, next collection Friday 25 Sep").
3. **Who is paying?**
   - People you choose: compact expandable cards, **Add from contacts**, a **Split equally** button, and a live bar ("₦40,000 of ₦60,000 assigned, ₦20,000 left to go") so you fix a mismatch as you go.
   - Anyone with a link: split evenly with a − / + counter, or set a price per person, with a live "Each person pays" line.
4. **Where should the money go?** Pick the bank from the searchable list and enter the account number; Beels checks the account and fills in the name. If the check fails you can type the name yourself. You can split the payout across several accounts, with the same live bar.
5. **Review and create:** a summary with an Edit button per section.

- **A proper finish:** an animated "Your beel is live" screen with Share link (open-link beels), View beel / View my beels, and Create another.
- Errors appear under the field and scroll into view; going back keeps your answers; leaving with unsaved input asks "Discard this beel?"; if creating fails you stay on Review with the reason.
- The bank picker is now a shared component used by both New beel and Direct debit setup.

## Notes
- Beel rules are unchanged: contributor amounts and payouts must add up to the target, and a single payout defaults to the whole target.
- The account-name check uses the same lookup as Direct debit setup. If the backend does not resolve a beneficiary account, you are told and can type the name.
- The old single-page form is gone.

## APK
- Size: ~52 MB, all 3 ABIs.
- Signed with the Beels release key (`CN=Beels Mobile, O=Beels, C=NG`).
- Version 0.11.0 (build 11). 308 tests passing, `flutter analyze` clean. Not yet verified on a physical device.

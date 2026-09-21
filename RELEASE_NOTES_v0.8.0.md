## What's new

**Pick people from your contacts**
- New beel (each contributor), New group (each member) and Group detail (Add a member) now have a **From contacts** button.
- Picking a contact fills first name, last name, phone and email. Fields the contact does not have are left as you typed them; cancelling changes nothing.
- Names split on the first space ("Ada Ngozi Okafor" becomes Ada / Ngozi Okafor). Nigerian numbers written as +234 or 234 are converted to the local 08... form.

## Privacy
- Uses Android's system contact picker, so Beels asks for **no contacts permission** and only ever sees the one contact you pick.
- Because of that, the email is best-effort and may be blank; fill it in by hand if so.

## Notes
- Android only for now; the button is hidden elsewhere.
- Beneficiaries are unchanged (they are bank details, not contacts).

## APK
- Size: ~52 MB, all 3 ABIs.
- Signed with the Beels release key (`CN=Beels Mobile, O=Beels, C=NG`).
- Version 0.8.0 (build 8). 228 tests passing, `flutter analyze` clean. The contact picker itself has not been verified on a physical device.

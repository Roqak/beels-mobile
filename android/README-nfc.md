# NFC invite emitter (Android HCE)

## What it does
`BeelInviteApduService` turns the host phone into an NFC Forum **Type 4 Tag**
over ISO-DEP so a friend's phone reads the beel join URL straight from an NFC
tap — no app, no typing, no web fallback required on their side. Dart arms and
disarms it through the `"beels/nfc"` MethodChannel (registered in
`MainActivity`): `setInviteUrl(url|null)` and `clearInviteToken()`. Updates are
live; a new invite works without restarting the app.

## Protocol notes
- The reader stack always addresses files with SELECT `P2=0x0C`
  ("no FCI returned"), so every select answers a bare `90 00`; nothing else is
  sent by Android's reader implementation.
- Only three commands are implemented: SELECT (`00 A4`), READ BINARY (`00 B0`)
  and the implicit fallthrough. Anything else, and every command when **no
  invite is armed**, answers `6D00` so the tag is simply not discoverable.
- The Capability Container advertises the NDEF file `E1 04`; the file's NLEN
  (first 2 bytes) and the CC's advertised size are kept in sync with the real
  record length whenever the URL changes.
- The NDEF message is a single well-known URI record
  (`91 01 <len> 55 <URI>`) built by `BeelNdefCodec` (pure Kotlin, unit tested
  in `app/src/test/.../BeelNdefCodecTest.kt`).

## Manifest wiring
- Service intent-filter
  `android.nfc.cardemulation.action.HOST_APDU_SERVICE` + meta-data resource
  `@xml/apduservice` (category `other`, AID `D2760000850101`).
- `<uses-permission android:name="android.permission.NFC"/>` and a
  non-required `<uses-feature android:name="android.hardware.nfc"/>` so
  devices without NFC can still install (QR / share link then carry the same
  `/join/<token>` URL).

## Manual device checklist (cannot be automated here)
1. Create an invite on an NFC-capable Android phone; tap it against a friend's
   unlocked phone with NFC on → the join URL opens (browser, or the app when
   installed) on `/join/<token>`.
2. Closing the invite screen stops tag emulation (further taps are ignored).
3. When all slots are used or the invite expires, the emitter disarms itself.
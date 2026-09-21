## What's new

**Easy biometric setup**
- After you sign in on a phone that supports it, Beels offers to unlock with your fingerprint or face in one tap. Asked at most twice ("Not now" counts once), and at most once per app launch.
- The Profile toggle now re-checks support when opened (it could wrongly say "Not available" right after a fresh sign-in) and explains what to do if the phone has no fingerprint or face set up.

**Security**
- Auto-lock: when biometric login is on, Beels asks for it again if you have been away for more than 45 seconds, then returns you to the screen you were on.
- Disbursing funds and revoking a direct-debit mandate ask for biometric confirmation when biometric login is on.
- Fixed: the unlock redirect accepted protocol-relative links (`//example.com`) as in-app paths; only real in-app paths are honoured now.

**Nice to haves**
- Hide balances: eye icon on Home masks your deposited and withdrawn totals; the choice is remembered.
- Copy reference: one tap on an expanded transaction copies its reference.
- New users with no beels see a "Start your first beel" card on Home.

## Notes
- The biometric offer sheet and the first-beel card have not been reviewed in dark mode.
- Auto-lock delay is 45 seconds (one constant, `kAutoLockAfter`).

## APK
- Size: ~52 MB, all 3 ABIs.
- Signed with the Beels release key (`CN=Beels Mobile, O=Beels, C=NG`).
- Version 0.7.0 (build 7). 213 tests passing, `flutter analyze` clean. Not yet verified on a physical device.

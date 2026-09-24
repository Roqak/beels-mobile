# Release notes — Beels Mobile v0.15.1 (hotfix)

## Fix
- **App froze on the splash screen at startup (v0.15.0 regression)**: the new release-configuration guard aborted `main()` in release builds because the default API base URL is currently the intended backend. The guard is removed; release binaries boot normally. The keystore fail-fast remains.

## Notes
- Install this build over v0.15.0; APK signed with the Beels release key (`CN=Beels Mobile, O=Beels, C=NG`).

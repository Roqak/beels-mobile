# Release assets

Marketing assets for each app release, one folder per version
(`v0.17.0/`, ...). Not part of the Flutter build.

## Release videos

Each release folder holds `index.html`, an animation driven entirely by a
time value, and the rendered `beels-<version>.mp4` (1080x1920, 30 fps, no
audio). The page uses the app's fonts from `../../assets/google_fonts/` and
the Adire Ledger palette from `lib/core/theme.dart`.

To make a new one, copy the previous release folder, edit its `index.html`
(text, timings in `render(t)`, `DURATION`), then:

```bash
cd release-assets
npm i --no-save playwright-core@1.59   # one-off; node_modules is gitignored
node render.js stills v0.18.0 2 10 20   # spot-check frames in v0.18.0/stills/
node render.js video v0.18.0            # writes v0.18.0/beels-v0.18.0.mp4
```

Needs `ffmpeg` and a Chromium binary. The default path is Playwright's cached
Chromium (`~/.cache/ms-playwright/chromium-1243`); set `CHROME=/path/to/chrome`
to use another.

Use made-up names and account numbers in videos, never real member data.

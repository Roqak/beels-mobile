// Renders a release video page (<release>/index.html) to MP4 or stills.
//
//   node render.js video v0.17.0            -> v0.17.0/beels-v0.17.0.mp4
//   node render.js stills v0.17.0 2.5 10 24 -> v0.17.0/stills/still_<t>.png
//
// The page must define window.render(t), window.DURATION (seconds) and set
// window.ready once its fonts load. Every frame is computed from t, so the
// capture is exact regardless of how slow screenshots are.
const { chromium } = require('playwright-core');
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

const exe =
  process.env.CHROME ||
  path.join(process.env.HOME, '.cache/ms-playwright/chromium-1243/chrome-linux64/chrome');
const [mode, release, ...times] = process.argv.slice(2);
if (!['video', 'stills'].includes(mode) || !release) {
  console.error('usage: node render.js video|stills <release-folder> [t...]');
  process.exit(1);
}
const dir = path.resolve(__dirname, release);

(async () => {
  const browser = await chromium.launch({
    executablePath: exe,
    args: ['--allow-file-access-from-files'],
  });
  const page = await browser.newPage({ viewport: { width: 1080, height: 1920 } });
  await page.goto('file://' + path.join(dir, 'index.html'));
  await page.waitForFunction(() => window.ready === true);

  if (mode === 'stills') {
    fs.mkdirSync(path.join(dir, 'stills'), { recursive: true });
    for (const t of times) {
      await page.evaluate((t) => render(t), +t);
      await page.screenshot({ path: path.join(dir, 'stills', `still_${t}.png`) });
    }
  } else {
    const fps = 30;
    const duration = await page.evaluate(() => window.DURATION);
    const out = path.join(dir, `beels-${path.basename(dir)}.mp4`);
    const ff = spawn('ffmpeg', [
      '-y', '-loglevel', 'error',
      '-f', 'image2pipe', '-framerate', String(fps), '-c:v', 'mjpeg', '-i', '-',
      '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '18', '-preset', 'medium',
      '-movflags', '+faststart', out,
    ], { stdio: ['pipe', 'inherit', 'inherit'] });
    for (let f = 0; f < fps * duration; f++) {
      await page.evaluate((t) => render(t), f / fps);
      const frame = await page.screenshot({ type: 'jpeg', quality: 95 });
      if (!ff.stdin.write(frame)) await new Promise((r) => ff.stdin.once('drain', r));
    }
    ff.stdin.end();
    await new Promise((r) => ff.on('close', r));
    console.log(out);
  }
  await browser.close();
})();

// Render the promo: headless Chrome screenshots each frame of index.html, ffmpeg encodes them.
//   node render.mjs                 16:9, 1920x1080
//   node render.mjs portrait        9:16, 1080x1920
//   node render.mjs stills 4 10     PNG stills at those seconds (both orientations)
// CHROME=/path/to/chrome overrides the browser. SCALE=2 renders 4K.
import { spawn, execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import puppeteer from 'puppeteer-core';

const FPS = 30, DURATION = 78;
const here = new URL('.', import.meta.url).pathname;
const out = here + 'out/';
mkdirSync(out + 'stills', { recursive: true });

// Wallpaper from the theme template, filled in from the tokens.
const tokens = JSON.parse(readFileSync(here + '../theme/tokens.json'));
const wallSrc = here + '../theme/wallpaper.svg';
// ponytail: falls back to PR #3's branch until it merges; drop the fallback after that.
const svg = existsSync(wallSrc) ? readFileSync(wallSrc, 'utf8')
  : execFileSync('git', ['show', 'origin/claude/wallpaper-light-dark-c19de8:theme/wallpaper.svg'], { cwd: here, encoding: 'utf8' });
writeFileSync(out + 'wallpaper.svg', svg.replace(/\{\{(\w+)\}\}/g, (_, k) => tokens[k]));

const [mode = 'landscape', ...times] = process.argv.slice(2);
const scale = +(process.env.SCALE || 1);
const browser = await puppeteer.launch({
  executablePath: process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  headless: true,
  args: ['--allow-file-access-from-files', '--force-color-profile=srgb', '--hide-scrollbars'],
});

async function open(portrait) {
  const page = await browser.newPage();
  await page.setViewport(portrait ? { width: 1080, height: 1920, deviceScaleFactor: scale }
    : { width: 1920, height: 1080, deviceScaleFactor: scale });
  await page.goto('file://' + here + 'index.html', { waitUntil: 'networkidle0' });
  await page.evaluate(() => document.fonts.ready);
  return page;
}

if (mode === 'stills') {
  for (const portrait of [false, true]) {
    const page = await open(portrait);
    for (const t of times) {
      await page.evaluate(t => seek(t), +t);
      await page.screenshot({ path: `${out}stills/${portrait ? 'v' : 'h'}-${t}.png` });
    }
  }
} else {
  const portrait = mode === 'portrait';
  const file = `${out}krissos-promo-${portrait ? '9x16' : '16x9'}.mp4`;
  const music = out + 'music.wav';
  const page = await open(portrait);
  const ff = spawn('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'image2pipe', '-framerate', FPS, '-i', '-',
    ...(existsSync(music) ? ['-i', music, '-c:a', 'aac', '-b:a', '256k', '-shortest'] : []),
    '-c:v', 'libx264', '-preset', 'slow', '-crf', '16', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', file],
    { stdio: ['pipe', 'inherit', 'inherit'] });
  for (let f = 0; f < FPS * DURATION; f++) {
    await page.evaluate(t => seek(t), f / FPS);
    const png = await page.screenshot({ type: 'png', optimizeForSpeed: true });
    if (!ff.stdin.write(png)) await new Promise(r => ff.stdin.once('drain', r));
    if (f % 300 === 0) console.log(`${mode}: ${f / FPS}s`);
  }
  ff.stdin.end();
  await new Promise(r => ff.on('close', r));
  console.log(file);
}
await browser.close();

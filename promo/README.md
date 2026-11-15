# KrissOS promo video

A 78-second launch film, built as code. `SCRIPT.md` is the storyboard; `CREDITS.md` lists
every asset and its licence.

- `index.html`: every scene, as a pure function of time (`seek(t)`). Open `index.html#24` in
  a browser to preview second 24 (after one render has written `out/wallpaper.svg`).
- `render.mjs`: headless Chrome screenshots each frame and ffmpeg encodes it to H.264.
- `music.py`: synthesises the score into `out/music.wav`. `render.mjs` muxes it in if it exists.

```bash
cd promo && npm ci
```

```bash
python3 music.py
```

```bash
node render.mjs && node render.mjs portrait
```

Output lands in `promo/out/` (gitignored): `krissos-promo-16x9.mp4` (1920×1080) and
`krissos-promo-9x16.mp4` (1080×1920), 30 fps. `SCALE=2 node render.mjs` renders 4K.
`node render.mjs stills 6.5 24.5` writes PNG stills at those seconds.

Needs Node 20+, Google Chrome (or `CHROME=/path/to/chrome`), ffmpeg, and Python 3 with numpy.
Fonts load from Google Fonts, so rendering needs a network connection.

Why HTML and not Remotion: the scenes are plain HTML/CSS, the whole renderer is one 70-line
script, and there is no licence question. Remotion's free licence covers companies of up to
three people, which fits Kraze Tech today, but it is a source-available licence with a paid
tier above that size, so it would need revisiting as the team grows.

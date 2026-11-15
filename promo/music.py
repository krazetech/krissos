"""Original score for the promo, synthesised from scratch: python3 music.py -> out/music.wav.

120 BPM in A minor (Am F C G). Pad swell over the cold open, a hit at 3.5 s (the reveal),
four-on-the-floor groove, a breath at 45.5-50 s (Secure Boot), a final hit at 73 s.
"""
import wave
from pathlib import Path

import numpy as np

SR, LEN, BEAT = 48000, 78.0, 0.5
HIT, BREAK, END = 3.5, (45.5, 50.0), 73.0
t = np.arange(int(SR * LEN)) / SR
rng = np.random.default_rng(110)
CHORDS = [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]]  # Am F C G (MIDI)
hz = lambda n: 440 * 2 ** ((n - 69) / 12)


def env(n, attack, decay):
    x = np.arange(n) / SR
    return np.minimum(x / attack, 1) * np.exp(-x / decay)


def place(out, sound, at):
    i = int(at * SR)
    if i < len(out):
        out[i:i + len(sound)] += sound[:len(out) - i]


def saw(f, x):
    # three detuned band-limited-ish saws (first 12 harmonics)
    return sum(sum(np.sin(2 * np.pi * k * f * d * x) / k for k in range(1, 13)) for d in (0.996, 1, 1.004)) / 3


def lowpass(x, alpha):
    return np.convolve(x, np.ones(alpha) / alpha, mode='same')


kick_n = int(0.35 * SR)
kx = np.arange(kick_n) / SR
kick = np.sin(2 * np.pi * (45 * kx + 90 * (1 - np.exp(-kx * 30)) / 30)) * np.exp(-kx * 9)
hat = np.diff(rng.standard_normal(int(0.06 * SR)), prepend=0) * env(int(0.06 * SR), .001, .015) * .25
crash = lowpass(rng.standard_normal(int(2.5 * SR)), 2) * env(int(2.5 * SR), .002, .6) * .35

drums, bass, pad, duck = (np.zeros_like(t) for _ in range(4))
grooving = lambda s: HIT <= s < END and not BREAK[0] <= s < BREAK[1]

for b in range(int(LEN / BEAT)):
    s = b * BEAT
    if grooving(s):
        place(drums, kick, s)
        place(duck, env(int(.4 * SR), .001, .12), s)
        place(drums, hat, s + BEAT / 2)
        if b % 4 in (1, 3):
            place(drums, lowpass(rng.standard_normal(int(.18 * SR)), 3) * env(int(.18 * SR), .001, .05) * .35, s)

for bar in range(int(LEN / 2)):
    s, notes = bar * 2.0, CHORDS[bar % 4]
    n = int(2.0 * SR)
    x = np.arange(n) / SR
    chord = sum(saw(hz(m), x) for m in notes) / 3
    place(pad, lowpass(chord, 24) * env(n, .25, 6), s)
    if grooving(s) or grooving(s + 1):
        for e in range(8):                                 # eighth-note bass, root an octave down
            if grooving(s + e * .25):
                m = notes[0] - 12
                bn = int(.24 * SR)
                bx = np.arange(bn) / SR
                place(bass, lowpass(saw(hz(m), bx), 10) * env(bn, .003, .12), s + e * .25)

# cold open: pad swells in under a noise riser into the hit
swell = np.clip(t / HIT, 0, 1) ** 2
riser = lowpass(rng.standard_normal(len(t)), 6) * np.where(t < HIT, (t / HIT) ** 3, 0) * .25
pad *= np.where(t < HIT, swell, 1)
for at in (HIT, END):
    place(drums, crash, at)
    place(drums, kick * 1.3, at)

mix = pad * .35 * (1 - .6 * np.clip(duck, 0, 1)) + bass * .45 + drums * .8 + riser
mix *= np.clip((LEN - t) / (LEN - END - 1), 0, 1)             # fade out over the close
mix = np.tanh(mix * 1.2) / np.tanh(1.2)
mix *= .89 / np.abs(mix).max()                                # peak at -1 dBFS

out = Path(__file__).parent / 'out' / 'music.wav'
out.parent.mkdir(exist_ok=True)
with wave.open(str(out), 'wb') as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes((mix * 32767).astype('<i2').tobytes())
print(out)

# KrissOS promo: script and storyboard

Length: 78 s. 16:9 at 1920×1080 and a 9:16 cut at 1080×1920, 30 fps.
Stage: black. Headlines in Figtree, terminals in JetBrains Mono, Sky Cyan `#29B2E8` as the
only accent. Motion: things rise 24 px and unblur into place on an ease-out curve (0.7 s);
each beat fades and pulls back slightly on exit.

**Honesty rule.** Anything not in `main` yet carries a small `Coming in 110` tag. No
benchmark numbers. The desktop is a concept of KrissOS Shell, and is labelled as one.

| # | Time | Beat | On screen | Tag |
|---|---|---|---|---|
| 1 | 0.0–3.5 | Cold open | Black. **"This is not a theme."** One word at a time. | |
| 2 | 3.5–8.0 | Reveal | Wallpaper glows in. **"KrissOS."** Sub: *Arch Linux, rebuilt around how you actually use your PC.* | |
| 3 | 8.0–13.0 | Desktop | The desktop rises: floating windows, cyan focus ring, one bottom bar. Caption: *KrissOS Shell concept.* | Coming in 110 |
| 4 | 13.0–19.5 | Pillars | **"Built for three things."** Then three cards: **Work** (productivity), **Play** (gaming), **Think** (local AI). | |
| 5 | 19.5–27.0 | `kriss` | **"One command. Your whole system."** Terminal types `kriss` → info rows, then `kriss --kapcai` → the ASCII Kriss and `Modenas Kriss 110`. Caption: *Psst. It's not in --help.* | |
| 6 | 27.0–33.5 | `kriss-tune` | **"Tuned in one word."** Pills: performance · balanced · powersave · kapcai. The highlight slides to performance. Terminal: `kriss-tune performance` → sched_ext scheduler on, GameMode ready. | Coming in 110 |
| 7 | 33.5–39.5 | Kernel | **"A kernel built for your CPU."** Giant `x86-64-v3`. Chips: CachyOS patches · BORE · sched_ext · LTO · built from source in CI. Footnote: *Older CPU? The installer picks linux-kriss-generic.* | Coming in 110 |
| 8 | 39.5–45.5 | Snapshots | **"Break it. Boot yesterday."** A boot menu lists btrfs snapshots; the selection steps down to one from before the update. | Coming in 110 |
| 9 | 45.5–50.0 | Secure Boot | **"Secure Boot. Stays on."** Shield. *sbctl re-signs the kernel and bootloader on every update.* | |
| 10 | 50.0–57.0 | `kriss-vm` | **"Hand your GPU to Windows."** Terminal: `kriss-vm start` → stop Ollama, bind dGPU to vfio-pci, start VM, open Looking Glass. *And `kriss-vm revert` undoes all of it.* | Coming in 110 |
| 11 | 57.0–61.5 | WinBoat | **"Windows apps, on your desktop."** A Windows app window floats beside native ones. `kriss winapps setup`. | Coming in 110 |
| 12 | 61.5–68.5 | Local AI | **"AI that stays on your machine."** Terminal: `ollama run` answers a question; a last line reads `gpu: detected · runs offline`. Then an opt-in checklist: Claude Code, Codex CLI, Gemini CLI, Antigravity. | Coming in 110 |
| 13 | 68.5–73.0 | `[kriss]` | **"Every package. Signed."** The `[kriss]` block from `pacman.conf`. *Built in CI. Published on GitHub Releases.* | |
| 14 | 73.0–78.0 | Close | **"KrissOS 110."** *Work. Play. Think.* Then `krazetech.github.io/krissos` and `github.com/krazetech/krissos`. | |

## Audio

Original score from `music.py`: 120 BPM, A minor (Am F C G). A pad swells under a riser through
the cold open, a hit lands on the reveal at 3.5 s, then a four-on-the-floor groove. The drums drop
out for Secure Boot (45.5–50 s) and come back for `kriss-vm`. A final hit at 73.0 s, then a fade.
Mixed to about −14 LUFS. To swap in another track, replace `out/music.wav` and re-render. No
voiceover.

## Not shown, on purpose

- Benchmarks, FPS counters, boot times: we have none yet.
- Game, app or vendor logos.
- Apple Silicon (after 110).

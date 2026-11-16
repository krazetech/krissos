# KrissOS Architecture

KrissOS is a thin overlay on Arch Linux by Kraze Tech, built around three pillars:
productivity, gaming, and local AI. Everything here is shaped by one constraint:
**one or two maintainers must be able to keep it alive.** We ship a small set of our own
packages and configs on top of upstream Arch. We do not fork the Arch repos.

Release codenames follow the Modenas Kriss line: `110` (1.0), `115`, `MR3`.

---

## 1. Base and update model

| Decision | Choice |
|---|---|
| Base | Arch Linux, x86_64 only at 1.0. Apple Silicon comes later as a separate image (§13) |
| Update model | Rolling. Upstream Arch packages come straight from Arch mirrors |
| Our packages | A single `[kriss]` repo, ideally fewer than 25 packages |
| Rollback | btrfs + snapper, with snapshots bootable from the Limine menu |
| Installer | Calamares on an archiso live image |
| Secure Boot | Supported at 1.0 via `sbctl`. A pacman hook re-signs the kernel and bootloader on every update |

Only our own packages are built for x86-64-v3. Rebuilding all of Arch for v3 is a full
distro team's workload, and it is out of scope.

## 2. The `[kriss]` package set

| Package | Purpose |
|---|---|
| `linux-kriss` | Kernel for x86-64-v3, built with CachyOS patches (EEVDF/BORE, sched_ext) and LTO |
| `linux-kriss-generic` | The same kernel for baseline x86-64. The installer picks it when the CPU lacks v3 |
| `kriss-tools` | `kriss` (with `kriss tune`), `kriss-ctl`, `kriss-vm` |
| `kriss-shell` | The KrissOS Shell (panel, dock, launcher, notifications, lock screen) |
| `kriss-theme` | Wallpapers, icons, cursors, GTK/Qt/terminal colors, Plymouth, Limine, SDDM/greeter |
| `kriss-settings` | Default configs in `/etc/skel` and `/usr/share/kriss`, plus pacman/snapper/sbctl hooks |
| `kriss-installer` | The Calamares sequence, module configs, desktop picker and install scripts (branding ships in `kriss-theme`) |
| `calamares` | A pinned build of upstream Calamares, which Arch does not package |
| `kriss-keyring` | The public key for signing packages |
| `kriss-meta-*` | Metapackages: `-base`, `-gaming`, `-ai`, `-winapps`, `-vfio` |

Rule: a package goes into `[kriss]` only if it is ours or needs patching. Anything else
comes from Arch or a pinned AUR build, and the AUR builds are kept to a minimum.

### Licensing and provenance
- Kernel patches come from CachyOS's public PKGBUILDs and patch sets (GPL-2.0). We keep each
  patch's upstream header and credit it in `pkgs/linux-kriss/SOURCES.md`.
- All CachyOS names, logos and branding are removed.
- We **never** fetch CachyOS's prebuilt binaries or point at their mirrors. Every kernel is
  built from source in our CI.
- KrissOS tooling is licensed GPL-3.0-or-later (subject to the open decision in §11).

### The installer

Calamares on the live ISO (`kriss-install`, also the boot menu's *Install KrissOS* entry).
It never needs the internet: Calamares' `unpackfs` copies the live system to the disk and
`installer/lib/unlive` strips the live-only parts (live user, autologin, archiso config,
the installer itself, and the NVIDIA driver on PCs without a Turing or newer card). Online
is a bonus only: `installer/lib/online` then switches to `linux-kriss`, runs `pacman -Syu`
and installs KDE Plasma, which is not on the ISO. Offline, Plasma falls back to the shell.

- **Disk:** GPT and UEFI only. Dual-boot alongside Windows is the default, erase disk the
  other choice; manual partitioning and disk encryption are off for now. `kriss-install`
  stops before the installer with steps to follow when BitLocker is on, or when the USB
  started in legacy BIOS mode.
- **Layout:** the ESP at `/efi` holds only Limine, so Windows' small ESP is enough. The
  kernels go on a 2 GiB FAT32 `/boot` (XBOOTLDR), because Limine reads only FAT. btrfs
  root with `@`, `@home`, `@cache`, `@log` and `@snapshots`; zram, no swap partition.
- **Boot menu:** `kriss-limine-update` (`kriss-settings`) writes `limine.conf`: KrissOS,
  Windows when the installer found its boot manager, and the 15 newest snapper snapshots.
  A snapshot boots with the kernel it was taken with (old kernels are kept under
  `/boot/kriss/`) and a RAM overlay from the `kriss-snapshot` initramfs hook.
- **Kernel:** the ISO's kernel offline; `linux-kriss` on x86-64-v3 CPUs when online.
- **NVIDIA:** `nvidia-open-dkms` on Turing and newer, on the ISO so the live session uses
  it too. Older cards keep nouveau, since no driver in Arch's repos supports them any more.
- **Secure Boot:** not set up by the installer yet. Limine needs `limine enroll-config`
  and hashed kernel paths before an `sbctl` signature means anything.

## 3. Repository layout (monorepo, public GitHub org)

```
krissos/
├── ARCHITECTURE.md
├── pkgs/            # one PKGBUILD directory per [kriss] package
├── tools/           # kriss, kriss-ctl, kriss-vm (source)
├── shell/           # KrissOS Shell source
├── theme/           # design tokens + generated assets
├── installer/       # Calamares sequence, module configs and install scripts
├── iso/             # archiso profile
└── .github/workflows/
```

## 4. Build and distribution

- **CI:** GitHub-hosted runners, which are free and unlimited for public repos.
  - Your desktop is **not** a CI runner. A self-hosted runner on a public repo would execute
    code from pull requests on your own machine.
  - Your desktop stays the local box for test builds and VM testing.
- **Pipelines:**
  - `pkgs.yml`: rebuilds any package whose PKGBUILD changed, signs it, and publishes it to the
    repo.
  - `kernel.yml`: runs on a schedule, checks for new CachyOS kernel patch releases, opens a
    version-bump PR, and builds both kernels.
  - `iso.yml`: builds the live ISO on every tag (`110`, `115`, …), nightly, and on PRs that
    touch `iso/`, then boots it in QEMU until the KrissOS Shell starts. Tags attach the ISO to a release.
- **Repo hosting:** the pacman database and packages are uploaded as assets to a GitHub
  Release, and pacman fetches them over plain HTTPS. No server to run.
- **Signing:** one GPG key, stored only in a GitHub Actions secret. Its public half ships in
  `kriss-keyring`.

## 5. Desktop

The KrissOS Shell is the default, and the live ISO boots straight into it. Plasma stays
available as the installer's alternative.

| Option | What the user gets |
|---|---|
| **KrissOS Shell** (default) | Our own shell on `cosmic-comp`, fully themed, with the KrissOS login screen on greetd |
| KDE Plasma | Stock Plasma with the KrissOS colour scheme, global theme, wallpaper and SDDM look |

- **Plasma theming:** `kriss-theme` ships the colour scheme, a look-and-feel package and
  the wallpaper, all generated from `theme/tokens.json`. `kriss-settings` makes them the
  default through `/etc/xdg` (kdeglobals, plasmarc, kcminputrc) and `/etc/sddm.conf.d`.
- **KrissOS Shell:** runs as Wayland layer-shell clients on top of `cosmic-comp`. We don't fork
  the compositor, which keeps the maintenance cost low.
  - **Phase 1 test:** confirm that cosmic-comp's layer-shell and protocol support covers a
    panel, dock, launcher, notifications and lock screen without running the rest of the
    COSMIC session.
  - **If it fails:** keep the shell and swap the compositor.
  - **Result (cosmic-comp 1.11, Nov 2026):** it passes. cosmic-comp offers wlr-layer-shell,
    ext-session-lock, ext-idle-notify, ext-workspace and ext-image-copy-capture to any
    unsandboxed client. It lacks wlr-foreign-toplevel-management, which Quickshell uses to
    list windows, so `kriss-shell-toplevels` (a small Python helper) reads windows through
    COSMIC's own toplevel protocols instead.
  - **Toolkit:** QML on Quickshell. It ships in Arch `extra`, covers every surface we need
    (layer-shell windows, session lock, PAM, notifications, PipeWire, UPower, NetworkManager)
    and needs no compiled code of ours.
- **Display GPU on laptops:**
  - On laptops with no MUX switch, the compositor is pinned to the iGPU through the render
    device setting (`COSMIC_RENDER_DEVICE` / `KWIN_DRM_DEVICES`).
  - `kriss-vm` uses that to keep the dGPU free for passthrough.

## 6. Visual language

| Token | Value |
|---|---|
| `bg` | `#000000` Obsidian |
| `surface` | `#0B0D0F` |
| `accent` | `#24B1E6` Sky Cyan (sampled from the Kraze Tech logo) |
| `fg` | `#E6EDF2` |
| `muted` | `#6B7680` |

- **Style:** soft and rounded. Floating windows with large corner radii and a light rim, and
  the focused window ringed in Sky Cyan. Light and dark window themes over a dark wallpaper.
  One bottom bar holds the launcher, apps and status. Sky Cyan is the only accent; no neon.
- **Type:** Figtree + JetBrains Mono (OFL) proposed.
- **Reference:** the concept mockup at https://claude.ai/artifact/Cye2G1TUoXHAGoNX3typoD.
- **Behaviour and motion references:** every UI surface (shell, `kriss-welcome`, installer,
  website) copies how these behave. They are rebuilt in QML, never added as dependencies.

  | Surface | Reference | What to copy |
  |---|---|---|
  | Launcher | [cmdk](https://cmdk.paco.me) | One search field, fuzzy results grouped by type, keyboard first |
  | Notifications | [Sonner](https://sonner.emilkowal.ski) | Stacked toasts that expand on hover, swipe to dismiss, a pause on hover |
  | Quick settings | [Vaul](https://vaul.emilkowal.ski) | A sheet you drag to close, with snap points |
  | Bar numbers | [NumberFlow](https://number-flow.barvian.me) | Digits that roll when the clock, battery or volume changes |
  | Menus and focus | [Radix](https://www.radix-ui.com) / [Base UI](https://base-ui.com) | Arrow keys, Esc, focus trap, type-ahead |

  Effect-heavy libraries (Magic UI, Aceternity and the like) are out: no glows, beams or
  particles. Every animation respects reduced motion.
- **Logo:** the Kraze Tech emblem, a keris hilt on a Sky Cyan disc, redrawn as a vector at
  `theme/templates/usr/share/pixmaps/krissos.svg`. All assets are generated from these tokens
  so a change in one place updates everything.

## 7. Windows apps

### Tier 1: productivity (WinBoat)
- The `kriss-meta-winapps` package installs WinBoat with Podman, Compose v2, KVM and FreeRDP
  3.x.
- `kriss winapps setup` checks for KVM and group membership, then provisions the Windows
  container.

### Tier 2: gaming and heavy GPU apps (`kriss-vm`)
`kriss-vm` follows the approach of Omarchy PR #3454; that PR is to be reviewed before
implementation.

```
kriss-vm check          # IOMMU groups, ACS needs, GPU reset behaviour, CPU/boot readiness
kriss-vm setup          # kernel params (Limine/systemd-boot/GRUB), vfio, kvmfr, libvirt
kriss-vm bind|unbind    # move the dGPU between its host driver and vfio-pci
kriss-vm start|stop     # stop Ollama, bind, start the VM, open Looking Glass; reverse on stop
kriss-vm revert         # restore every file `kriss-vm` changed from its backups
```

- **Backups:** every file is backed up to `/var/lib/kriss-vm/backup/<timestamp>/` before it
  is edited. `revert` is the guaranteed undo.
- **Hardware handling:**
  - The `kvmfr` buffer is sized from the guest's display resolution.
  - AMD GPUs with the reset bug stay in VFIO mode persistently.
  - The ACS override is applied only when `check` finds bad IOMMU groups.
- **Laptops:** a MUX-less dGPU has no display output, so the guest needs a virtual display
  driver.
- **Anti-cheat:** SMBIOS spoofing is **off by default**. The installer's gaming step warns that
  some anti-cheat systems (Vanguard, Javelin, and some EAC/BattlEye titles) ban VMs and that
  hiding a VM can break a game's terms of service. Turning spoofing on needs explicit opt-in.

## 8. Gaming

- **Packages:** `kriss-meta-gaming` installs Steam, GameMode, Gamescope, MangoHud, the
  current Mesa and Vulkan drivers (with lib32), power-profiles-daemon and `scx-tools`.
- **multilib:** Steam and the lib32 packages are in Arch's `[multilib]`, which must be
  enabled before the metapackage installs. The installer (or kriss-welcome, before it installs
  the gaming pack) runs the same step as doing it by hand:
  `sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf && sudo pacman -Sy`.
- **NVIDIA:** the NVIDIA open kernel modules are used on Turing and newer GPUs.
- **`kriss tune` profiles:**

  | Profile | Use | power-profiles-daemon | sched_ext (scx_loader mode) |
  |---|---|---|---|
  | `performance` | gaming | `performance` | `scx_lavd` (gaming) |
  | `balanced` | default | `balanced` | `scx_bpfland` (auto) |
  | `powersave` | battery | `power-saver` | `scx_lavd` (powersave) |
  | `kapcai` | quiet alias for `powersave` | | |

  `kriss tune status` shows the active profile and scheduler.
- **How it applies:** no daemon of our own. power-profiles-daemon sets the profile (and EPP on
  amd-pstate and intel_pstate, so `kriss tune` does not touch the governor). Schedulers start
  through `scx_loader` from Arch's `scx-tools`. Both are D-Bus services checked by polkit;
  `kriss-tools` ships a polkit rule that lets active local `wheel` users switch schedulers
  without a password, as power-profiles-daemon already allows for profiles.
- **After a reboot:** power-profiles-daemon restores the profile. An XDG autostart entry runs
  `kriss tune sync` at login to start the matching scheduler.

## 9. Local AI

- **Inference:** Ollama on the host, with GPU detection for CUDA, ROCm and Vulkan.
- **Setup step:** optional installs for Claude Code, Codex CLI, Gemini CLI and Antigravity.
- **GPU sharing:** `kriss-vm start` stops Ollama before taking the dGPU, and `stop` starts it
  again.

## 10. Easter eggs

- **`kriss --kapcai`:** a small ASCII Kriss and the build codename. It is not shown in `--help`.
- **Codenames:** visible in `kriss version` and `/etc/os-release` (`VERSION_CODENAME`).

## 11. Open decisions

1. Font: confirm Figtree.
2. License for the tooling: GPL-3.0-or-later (assumed) or MIT.
3. ~~Results of the cosmic-comp layer-shell test.~~ Passed; see §5.

## 12. Roadmap to `110`

0. Repo, CI skeleton, signing key, `[kriss]` repo on GitHub Releases.
1. `linux-kriss` builds in CI and boots on the dev desktop.
2. `kriss-theme`, `kriss-settings`, and a live ISO that boots to the KrissOS Shell.
3. Calamares installer with the desktop picker (KrissOS Shell or Plasma), btrfs + snapper and
   sbctl.
4. `kriss tune` and the gaming metapackage.
5. `kriss-vm` (desktop first), then the laptop paths for systems with no MUX switch.
6. WinBoat tier and the AI setup.
7. `110`: the first tagged release.

## 13. Later: Apple Silicon image

A separate image, built after `110`, on Arch Linux ARM with the Asahi tooling.
- **Reused as-is:** the shell, theme, `kriss` (with `kriss tune`) and the AI setup.
- **New:** `linux-kriss-asahi`, installed through the Asahi installer from macOS. It needs
  aarch64 CI runners.
- **Not on this image:** the CachyOS kernel, x86-64-v3, WinBoat and `kriss-vm`. Games go through
  FEX + muvm.

Shared code stays architecture-neutral from day one so this image costs as little as possible.

## 14. Built for Windows switchers

KrissOS's first audience is people leaving Windows: gamers, everyday home users, students and
office users, and creators and AI tinkerers. Every default is checked against one question:
*would someone fresh from Windows get stuck here?*

| Area | Decision |
|---|---|
| Desktop | The KrissOS Shell (§5) with Windows habits in the KrissOS look: bottom taskbar, Start-style launcher, close button top-right, the Win key opens the menu. Not a Windows 11 clone. KDE Plasma is the installer's alternative |
| Install | Dual-boot alongside Windows by default. The installer resizes Windows safely, detects BitLocker and stops with clear steps if it's on, and keeps Windows in the boot menu |
| NVIDIA | The installer detects the GPU and installs the right driver (open modules on Turing and newer), so games work on first boot |
| Apps | Discover with Flathub on by default, pacman underneath |
| Updates | A desktop notification with an Update button (`kriss-update-notify.timer`). One click runs `kriss update`, which takes a btrfs snapshot through snapper first, so a bad update rolls back from the boot menu |
| Windows apps | WinBoat up front, adapted to the hardware (see `kriss-welcome`). The Windows licence follows WinBoat's own approach; KrissOS adds no licence step |
| Anti-cheat | Said upfront: gamers check their games before switching, on the website and in `kriss-welcome` |
| Language | English and Bahasa Melayu from day one: installer, `kriss-welcome`, website |

### `kriss-welcome`: the first-boot app

A new `[kriss]` package. It opens on first login and stays in the menu.

1. **Bring your apps.** The user picks the Windows apps they use. Each gets one answer: a native
   alternative, Wine/Proton, or WinBoat. A hardware check decides what is offered: WinBoat only
   when the PC can run a Windows VM well (about 16 GB RAM, CPU virtualisation on, enough cores);
   otherwise Wine/Proton and native apps.
2. **Game checker.** Search a game and see whether it runs, and whether its anti-cheat blocks
   Linux. Data from a public anti-cheat database and ProtonDB ratings (licences to confirm),
   bundled and refreshed with package updates. The website uses the same data.
3. **Copy from Windows.** On dual-boot systems, copy Documents, Pictures, Desktop, Music, Videos
   and browser bookmarks from the Windows partition. The partition is mounted read-only and never
   written to; BitLocker-locked partitions are skipped with an explanation.
4. **Drivers and extras.** Codecs, printers, the gaming pack (`kriss-meta-gaming`), and the local
   AI setup (Ollama plus the AI CLIs from §9).

- **Stack:** Qt/QML (Kirigami) to match KDE. Every system change goes through `kriss` / `pkexec`
  commands, or through udisks and Flatpak, which ask polkit themselves, so the app holds no root
  logic of its own.
- **Strings:** every string is translatable from the start, with English and Bahasa Melayu shipped.
- **Roadmap:** `kriss-welcome` lands with the installer (§12 step 3); the game checker and
  Bring your apps go first, because they decide whether people switch at all.

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
| `kriss-tools` | `kriss`, `kriss-ctl`, `kriss-tune`, `kriss-vm` |
| `kriss-shell` | The KrissOS Shell (panel, dock, launcher, notifications, lock screen) |
| `kriss-theme` | Wallpapers, icons, cursors, GTK/Qt/terminal colors, Plymouth, Limine, SDDM/greeter |
| `kriss-settings` | Default configs in `/etc/skel` and `/usr/share/kriss`, plus pacman/snapper/sbctl hooks |
| `kriss-installer` | Calamares branding, modules and the desktop picker |
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

## 3. Repository layout (monorepo, public GitHub org)

```
krissos/
├── ARCHITECTURE.md
├── pkgs/            # one PKGBUILD directory per [kriss] package
├── tools/           # kriss, kriss-ctl, kriss-tune, kriss-vm (source)
├── shell/           # KrissOS Shell source
├── theme/           # design tokens + generated assets
├── installer/       # Calamares config/branding
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
    touch `iso/`, then boots it in QEMU until Plasma starts. Tags attach the ISO to a release.
- **Repo hosting:** the pacman database and packages are uploaded as assets to a GitHub
  Release, and pacman fetches them over plain HTTPS. No server to run.
- **Signing:** one GPG key, stored only in a GitHub Actions secret. Its public half ships in
  `kriss-keyring`.

## 5. Desktop

KDE first: the first ISO and the installer ship stock Plasma with the KrissOS theme, so
the shell does not block them. KrissOS Shell becomes the default at `110`.

| Option | What the user gets |
|---|---|
| **KDE Plasma** (default until `110`) | Stock Plasma with the KrissOS colour scheme, global theme, wallpaper and SDDM look |
| KrissOS Shell (default from `110`) | Our own shell on `cosmic-comp`, fully themed |

- **Plasma theming:** `kriss-theme` ships the colour scheme, a look-and-feel package and
  the wallpaper, all generated from `theme/tokens.json`. `kriss-settings` makes them the
  default through `/etc/xdg` (kdeglobals, plasmarc, kcminputrc) and `/etc/sddm.conf.d`.
- **KrissOS Shell:** runs as Wayland layer-shell clients on top of `cosmic-comp`. We don't fork
  the compositor, which keeps the maintenance cost low.
  - **Phase 1 test:** confirm that cosmic-comp's layer-shell and protocol support covers a
    panel, dock, launcher, notifications and lock screen without running the rest of the
    COSMIC session.
  - **If it fails:** keep the shell and swap the compositor.
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

- **Packages:** `kriss-meta-gaming` installs Steam, GameMode, Gamescope, MangoHud, and the
  current Mesa and Vulkan drivers.
- **NVIDIA:** the NVIDIA open kernel modules are used on Turing and newer GPUs.
- **`kriss-tune` profiles:**

  | Profile | Use |
  |---|---|
  | `performance` | gaming |
  | `balanced` | default |
  | `powersave` | battery |
  | `kapcai` | quiet alias for `powersave` |

- **Scheduler:** sched_ext schedulers come from the `scx` packages; `kriss-tune` chooses one per
  profile.

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
3. Results of the cosmic-comp layer-shell test.

## 12. Roadmap to `110`

0. Repo, CI skeleton, signing key, `[kriss]` repo on GitHub Releases.
1. `linux-kriss` builds in CI and boots on the dev desktop.
2. `kriss-theme`, `kriss-settings`, and a live ISO that boots to KDE Plasma with the theme.
3. Calamares installer for Plasma, with btrfs + snapper and sbctl.
4. `kriss-tune` and the gaming metapackage.
5. `kriss-vm` (desktop first), then the laptop paths for systems with no MUX switch.
6. WinBoat tier and the AI setup.
7. `110`: the cosmic-comp shell test, then KrissOS Shell as the default desktop, with
   Plasma kept as the installer's alternative.

## 13. Later: Apple Silicon image

A separate image, built after `110`, on Arch Linux ARM with the Asahi tooling.
- **Reused as-is:** the shell, theme, `kriss`, `kriss-tune` and the AI setup.
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
| Desktop | KDE Plasma with Windows habits in the KrissOS look: bottom taskbar, Start-style launcher, close button top-right, the Win key opens the menu. Not a Windows 11 clone |
| Install | Dual-boot alongside Windows by default. The installer resizes Windows safely, detects BitLocker and stops with clear steps if it's on, and keeps Windows in the boot menu |
| NVIDIA | The installer detects the GPU and installs the right driver (open modules on Turing and newer), so games work on first boot |
| Apps | Discover with Flathub on by default, pacman underneath |
| Updates | A tray notice; one click updates, after an automatic btrfs snapshot, so a bad update rolls back from the boot menu |
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
  commands, so the app holds no root logic of its own.
- **Strings:** every string is translatable from the start, with English and Bahasa Melayu shipped.
- **Roadmap:** `kriss-welcome` lands with the installer (§12 step 3); the game checker and
  Bring your apps go first, because they decide whether people switch at all.

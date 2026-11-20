# KrissOS Shell: behaviour audit

How the shell *acts*: keyboard focus, which screen a surface opens on, fullscreen games,
closing, overlap, fast and held keys, hotplug, suspend and restart. Looks are covered by
`shell-polish-audit.md`. The reference is Windows 11, and macOS for the Mac layout.

Audited on main at 74ab99b, against cosmic-comp `epoch-1.11.0` with patches 0001 to 0003.
The test PC has two 2560x1440 screens.

Sizes: **XS** is a few lines, **S** is under 30 lines or one small patch, **M** needs a design choice.
"Verify" means the cause is clear from the code but has to be confirmed on the PC before the fix lands.

## How a surface gets the keyboard in cosmic-comp

You need this to follow most of the bugs below.

- When a Top or Overlay layer surface with keyboard interactivity appears, cosmic-comp gives
  it the keyboard (`Shell::map_layer`, `src/shell/mod.rs:3208`). It does this on any screen.
- On every loop it then checks the focus (`Common::refresh_focus`). While any exclusive layer
  surface exists, only exclusive surfaces on the highest such layer are valid, and they can be
  on any screen (`focus_target_is_valid`, `src/shell/focus/mod.rs:751`).
- If something else takes the focus for a moment (a game raising itself, an X11 focus
  request, a window closing), the fix-up runs `update_focus_target`. That function only looks
  on the seat's focused-or-active output (`src/shell/focus/mod.rs:840`). The focused output is
  the screen of the window with the keyboard. With nothing focused, it is the screen under the
  pointer.
- So an exclusive surface on the "wrong" screen keeps the keyboard only until the first
  fix-up. After that the keyboard goes to **nothing**. A fullscreen window with no keyboard
  focus still counts as "focused fullscreen" (`src/shell/focus/order.rs:223`), so Top-layer
  panels such as Start, quick settings and the calendar are drawn *behind* the game as well.

Both halves need fixing. The shell has to pick the right screen, and the compositor has to
stop dropping the keyboard when the shell gets it wrong.

## Bugs

### Alt+Tab (group `kz/behaviour-alt-tab`, do first)

**AT-1. Windows report a screen they have left, so the switcher opens on the other screen.** Size S.
- Repro: start a game windowed so it straddles both screens (a centred window on 5120x1440
  does), then make it fullscreen on the left screen. Press Alt+Tab: the switcher opens on the
  right screen. Snap layouts (Windows+Z) for that window also use the right screen's geometry.
- Cause: `shell/kriss-shell-toplevels:281-283` sets `output` on every `output_enter` and
  never handles `output_leave`. A window that entered both screens keeps whichever it entered
  *last*, even after it has left that screen. `geo` (`:293-294`) also keeps every screen the
  window ever touched. `Desktop.focusedScreen()` (`shell/qml/Desktop.qml:95`),
  `Windows.fullscreenOn()` and `Snap.qml:49` all read these fields.
- Fix: track the window's current screens, drop a screen and its `geo` entry on
  `output_leave`, and report as `output` the screen that holds most of the window.
- Windows 11: the switcher is on the screen of the window you are in.

**AT-2. An exclusive surface on a screen other than the seat's focused one loses the keyboard.** Size S (compositor patch).
- Repro: with AT-1 in place, so the switcher is on the other screen, have the game take the
  focus back for a moment. Many SDL and X11 games do this when they lose focus. The keys go
  nowhere, Alt release is never seen, and the switcher closes on its own (see AT-3). With the
  pointer on screen B and a window focused on A, hovering a taskbar preview on B (exclusive
  while hovered) has the same effect.
- Cause: `update_focus_target` only looks for the exclusive surface on
  `seat.focused_or_active_output()`, as described above.
- Fix: `pkgs/cosmic-comp-kriss/0004-exclusive-layer-any-output.patch`. It looks on the focused
  output first, then on every other output, which matches what `focus_target_is_valid`
  already accepts. This fixes the same keyboard loss for Start, quick settings, the calendar,
  Windows+V, Task View, tray menus and previews too. Kept in KrissOS, not sent upstream.

**AT-3. Holding Alt for more than 0.6 s after opening switches on its own.** Size XS. Fixed in #99.
- Repro: press Alt+Tab, keep Alt held and look at the list. After 600 ms it switches without
  Alt being released. Pressing Tab again (still holding Alt) does not help.
- Cause: `Switcher.qml:41` starts the `settle` timer once at open. Only key events that reach
  the surface stop it (`:75`, `:83`). cosmic-comp keeps Alt+Tab and Alt+Shift+Tab for its
  bindings (`WindowSwitcher`), including their releases, so the switcher never sees them.
  Each Tab arrives as `kriss-shell switcher next` instead, and `step()` does not restart the
  timer.
- Fix (#99): `settle` only runs until the switcher has the keyboard, and stops when it gets
  it. Measured on the PC, the keyboard arrives about 50 ms after Tab, and the Alt release
  reaches the switcher from then on, so holding Alt keeps the list open for any length of
  time, as on Windows. If the keyboard is taken away while the list is open, `settle` starts
  again.
- Left: letting go of Alt in the ~50 ms before the keyboard arrives leaves the list open
  until the next key or click. Qt only learns modifiers from key events, so the shell can't
  read them at that point. Reading the key state when the keyboard arrives would close it.

**AT-4. The switcher follows the shared `Desktop.screen`, so other code can move it while it is open.** Size XS.
- Repro: a notification arrives while Alt+Tab is up. `Notifs.qml:118-119` sets
  `Desktop.screen = Desktop.focusedScreen()`, and the switcher jumps to that screen. A click
  on the other screen's taskbar while it is open does the same.
- Cause: `Switcher.qml:44` binds `screen: Desktop.screen`. `Notifs.qml:118` only skips the
  move for Start, notifications, quick settings and the calendar.
- Fix: the switcher sets its own `screen` when it opens, as `Clipboard.qml:45` does. Opening
  it also closes Task View, as on Windows.

**AT-5. Wine and Proton games in fullscreen block Alt+Tab altogether.** Size M. Fixed in #100.
- Repro: a Proton game that grabs the keyboard (XWayland keyboard grab). Alt+Tab goes to the
  game and the switcher never opens.
- Cause: cosmic-comp treats an active XWayland grab like a shortcuts inhibitor
  (`src/input/mod.rs:2156-2160`), so no binding fires.
- Fix (#100): `pkgs/cosmic-comp-kriss/0005-alt-tab-through-x11-grab.patch` lets the
  WindowSwitcher bindings (Alt+Tab and Alt+Shift+Tab) through an XWayland keyboard grab, the
  way Windows always keeps Alt+Tab. Every other binding, Super included, still goes to the
  game. A Wayland shortcuts inhibitor (a VM, remote desktop) still holds every key. Checked on
  the PC with an X11 client that grabs the keyboard: before, Alt+Tab went to the client;
  after, the switcher opens and switches.
- Left: Super, Ctrl+Alt+Del and lock still go to a game that grabs the keyboard. Add them to
  0005 if that shows up in use.

### Panels and screens (group `kz/behaviour-panel-screen`)

**PS-1. A notification moves Task View's keyboard to the other screen.** Size XS.
- Repro: open Task View (Windows+Tab) and have a notification arrive. If the focused window's
  reported screen is the other one (AT-1), `Desktop.screen` changes. Task View's exclusive
  keyboard (`TaskView.qml:157`) then flips to the other screen's pane, which cosmic-comp does
  not focus, and the arrow keys stop working.
- Cause: `Notifs.qml:118` does not skip Task View (or Windows+V).
- Fix: also skip the move while Task View, Alt+Tab or Windows+V is open.

**PS-2. `Desktop.screen` can still hold a screen that has been unplugged.** Size XS, verify.
- Repro: open quick settings on screen B, then unplug B. Press Windows+A: it opens on the
  removed screen object, which Quickshell gives no output, so the compositor picks one.
  `focusedScreen()` falls back to the same stale object when no window is focused.
- Cause: `Desktop.qml:30` and `:97` never check the screen against `Quickshell.screens`.
- Fix: fall back to `Quickshell.screens[0]` when `screen` is no longer in the list.

### Lock and suspend (group `kz/behaviour-lock`)

**LK-1. Open surfaces survive the lock, and Alt+Tab switches windows under it.** Size S.
- Repro 1: open Windows+V (or Task View, or quick settings) and press Windows+L, or close the
  lid. After unlocking, the panel is still open with its old state.
- Repro 2: press Alt+Tab and lock within 600 ms. The `settle` timer fires under the lock and
  activates a window.
- Cause: nothing reacts to `Desktop.locked` apart from the OSD (`Osd.qml:22`). The panels are
  hidden by the session lock but not closed.
- Fix: when `Desktop.locked` turns on, close Start, quick settings, notifications, the
  calendar and Task View, cancel Alt+Tab, close Windows+V and Snap Assist. Windows 11 closes
  them all on lock.
- Out of scope: menus and the tray flyout stay up under the lock. They are hidden there and
  close on the first click after unlocking. Fix them if it shows up in use.

## Checked and fine

- Escape closes every panel: Start (search first, then the menu), quick settings,
  notifications, the calendar, Task View, Alt+Tab, Windows+V, Snap layouts and Assist, menus,
  the tray flyout, previews and Personalise. Click-outside closes all of the layer panels.
- Focus comes back after a panel opened from the bar's keyboard mode (Windows+T, then Esc)
  through `Bar.returnTo` and `Desktop.backOut`.
- Fast hotkeys: the toggles are idempotent. Held hotkeys: cosmic-comp never repeats a
  binding (key repeat is client-side on Wayland), so a held Windows+V does not flicker.
- Two exclusive surfaces at once: the newer one gets the keyboard when it appears. When it
  closes, the fix-up hands the keyboard to the older one (such as the bar's key proxy). With
  0004 this works across screens too.
- Focus after a window closes or minimizes is cosmic-comp's focus stack, which matches Windows.
- Fullscreen: the bar hides and toasts wait behind the bell (`Windows.fullscreenOn`, which
  depends on AT-1's `output` being right).
- After the shell restarts, `kriss-shell --inside` brings it back, and the toplevels helper
  sends the full window list again. Only the Alt+Tab most-recent order is lost
  (`Windows.qml:280`). It starts again from the focused window, which Windows also does after
  an Explorer restart.

Not audited here: widgets (#72) and the Mac layout (#75), which are still in flight.

## Fix PRs

| PR | Bugs | Files |
| --- | --- | --- |
| `kz/behaviour-alt-tab` | AT-1, AT-2, AT-3, AT-4 | `kriss-shell-toplevels`, `Switcher.qml`, cosmic-comp-kriss 0004 + pkgrel |
| `kz/behaviour-panel-screen` | PS-1, PS-2 | `Notifs.qml`, `Desktop.qml` |
| `kz/behaviour-lock` | LK-1 | `shell.qml` |
| `kz/behaviour-alt-hold` (#99) | AT-3 | `Switcher.qml` |
| `kz/behaviour-game-alt-tab` (#100) | AT-5 | cosmic-comp-kriss 0005 + pkgrel |

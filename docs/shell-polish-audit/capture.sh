#!/bin/bash
# Screenshots every shell surface in 8 states (layout x mode x text size) into $OUT.
# Run in the user's session on the test PC. Restores shell.json, text size and mode afterwards.
set -u
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)} WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-1}
export YDOTOOL_SOCKET=${YDOTOOL_SOCKET:-$XDG_RUNTIME_DIR/.ydotool_socket}
P=${KRISS_QML:-$HOME/.local/share/kriss-shell-dev/qml}
OUT=${OUT:-/tmp/kaudit}; mkdir -p "$OUT"
CFG=$HOME/.config/kriss/shell.json; cp "$CFG" "$OUT/shell.json.backup"
SCALE=$(gsettings get org.gnome.desktop.interface text-scaling-factor)
q() { qs -p "$P" ipc call "$@" >/dev/null 2>&1; }
esc() { ydotool key 1:1 1:0 >/dev/null 2>&1; }
shot() { sleep "${2:-0.8}"; grim "$OUT/$T-$1.png"; }
surfaces() {
    shot desk 0.3
    notify-send -a "KrissOS audit" -i dialog-information "Audit toast" "Checking spacing and type in this toast"; shot toast 0.7
    for s in launcher quick notifications calendar taskview; do q $s toggle; shot $s; q $s toggle; sleep 0.6; done
    q clipboard history; shot clip; q clipboard history; sleep 0.5
    q clipboard emoji; shot emoji; q clipboard emoji; sleep 0.5
    q taskbar startMenu; shot winx; esc; sleep 0.5
    q taskbar jumpList 1; shot jump; esc; sleep 0.5
    wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%+; shot osd 0.35; wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%-; sleep 1.5
    for p in colours taskbar text; do q personalise open $p; shot pers-$p 0.8; done; esc; sleep 0.5
}
for lay in windows mac; do
    q layout set $lay; sleep 2
    for th in dark light; do
        q theme set mode $th; sleep 2
        for sc in 1.0 1.5; do
            gsettings set org.gnome.desktop.interface text-scaling-factor $sc; sleep 1.5
            T=$lay-$th-$sc; surfaces
        done
    done
done
gsettings set org.gnome.desktop.interface text-scaling-factor "$SCALE"
cp "$OUT/shell.json.backup" "$CFG"

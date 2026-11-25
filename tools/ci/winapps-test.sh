#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Kraze Tech
# Checks kriss winapps' detection against fixture /proc, /sys, /dev and /etc trees and
# stub podman, podman-compose, xfreerdp3 and winpodx. Touches nothing outside a temp dir.
set -euo pipefail
kriss=$(realpath "$(dirname "$0")/../kriss")
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
me=$(id -un)

# Only these commands exist for kriss, so "not installed" can be tested on any machine.
mkdir -p "$t/bin" "$t/proc" "$t/sys/module/kvm_intel" "$t/sys/fs/cgroup" "$t/dev" "$t/etc"
for c in env bash id grep cut awk cat df sed setsid uname; do
  ln -s "$(command -v "$c")" "$t/bin/$c"
done
stub() { # stub NAME OUTPUT: a command that logs its args and prints OUTPUT
  printf '#!/bin/sh\necho "%s $*" >> "%s/log"\necho "%s"\n' "$1" "$t" "$2" > "$t/bin/$1"
  chmod +x "$t/bin/$1"
}
stub podman 'podman version 5.4.0'
stub podman-compose 'podman-compose version 1.6.0'
stub xfreerdp3 'This is FreeRDP version 3.10.3 (n/a)'
stub winpodx ''
stub ss ''
stub sudo ''

reset() {
  printf 'processor : 0\nflags : fpu vmx sse\nprocessor : 1\nprocessor : 2\nprocessor : 3\n' > "$t/proc/cpuinfo"
  echo 'MemTotal:       32000000 kB' > "$t/proc/meminfo"
  mkdir -p "$t/sys/module/kvm_intel"
  : > "$t/sys/fs/cgroup/cgroup.controllers"
  : > "$t/dev/kvm"
  printf 'alice:100000:65536\n%s:165536:65536\n' "$me" | tee "$t/etc/subuid" > "$t/etc/subgid"
  : > "$t/log"
}
run() { # run ARGS...: kriss output in $out, exit status in $rc
  rc=0
  out=$(PATH="$t/bin" KRISS_PROC="$t/proc" KRISS_SYS="$t/sys" KRISS_DEV="$t/dev" KRISS_ETC="$t/etc" \
    "$kriss" winapps "$@" 2>&1 < "${input:-/dev/null}") || rc=$?
}
has() { [[ $out == *"$1"* ]] || { printf 'FAIL %s: no "%s" in:\n%s\n' "$2" "$1" "$out"; exit 1; }; }
want_rc() { [[ $rc == "$1" ]] || { printf 'FAIL %s: exit %s, want %s\n%s\n' "$2" "$rc" "$1" "$out"; exit 1; }; }

reset; run check; want_rc 0 ready; has 'podman    ok: version 5.4.0' ready; has 'freerdp   ok: xfreerdp3 3.10.3' ready
[[ $out != *FAIL* ]] || { echo "FAIL ready: $out"; exit 1; }

reset; sed -i 's/ vmx//' "$t/proc/cpuinfo"; run check; want_rc 1 no-virt; has 'cpu       FAIL: virtualisation is off' no-virt
reset; sed -i 's/vmx/svm/' "$t/proc/cpuinfo"; run check; want_rc 1 amd; has 'fix: sudo modprobe kvm_amd' amd
reset; rm -r "$t/sys/module/kvm_intel" "$t/dev/kvm"; run check; want_rc 1 no-kvm
has 'fix: sudo modprobe kvm_intel' no-kvm; has '/dev/kvm is missing' no-kvm
reset; rm "$t/sys/fs/cgroup/cgroup.controllers"; run check; want_rc 1 cgroup-v1; has 'cgroups   FAIL' cgroup-v1

# One install fix for every missing package, not one per package.
reset; rm "$t/bin/podman-compose" "$t/bin/winpodx"; run check; want_rc 1 no-pkgs
[[ $(grep -c 'fix: sudo pacman' <<<"$out") == 2 ]] || { echo "FAIL no-pkgs: $out"; exit 1; }
stub podman-compose 'podman-compose version 1.6.0'; stub winpodx ''
reset; stub xfreerdp3 'This is FreeRDP version 2.11.7'; run check; want_rc 1 rdp2; has 'freerdp   FAIL' rdp2
stub xfreerdp3 'This is FreeRDP version 3.10.3 (n/a)'
reset; stub podman 'podman version 3.4.4'; run check; want_rc 1 old-podman; has 'version 3.4.4 is too old' old-podman
stub podman 'podman version 5.4.0'

# No subordinate IDs: the fix picks a range after everyone else's.
reset; echo 'alice:100000:65536' | tee "$t/etc/subuid" > "$t/etc/subgid"; run check; want_rc 1 no-subid
has "usermod --add-subuids 165536-231071 --add-subgids 165536-231071 $me" no-subid
reset; : > "$t/etc/subuid"; : > "$t/etc/subgid"; run check; has 'add-subuids 100000-165535' empty-subid

# A port WinPodX needs is taken: FAIL and name the program when ss can.
reset; printf '#!/bin/sh\ncase "$*" in *:8765*) echo "LISTEN 0 4096 127.0.0.1:8765 0.0.0.0:* users:((\\"syncthing\\",pid=42,fd=9))";; esac\n' > "$t/bin/ss"
chmod +x "$t/bin/ss"; run check; want_rc 1 port-taken; has 'port      FAIL: 127.0.0.1:8765 is in use by syncthing' port-taken
[[ $out != *4445* ]] || { echo "FAIL port-taken flagged a free port: $out"; exit 1; }
# shellcheck disable=SC2016
printf '#!/bin/sh\ncase "$*" in *:3390*) echo "LISTEN 0 5 0.0.0.0:3390 0.0.0.0:*";; esac\n' > "$t/bin/ss"; run check; want_rc 1 port-rdp
has '127.0.0.1:3390 is in use. WinPodX needs it for its RDP connection' port-rdp; has 'winpodx config set rdp.port' port-rdp
# WinPodX's own container holds them once it runs: no FAIL then.
# shellcheck disable=SC2016 # the stub expands $1 itself
printf '#!/bin/sh\ncase "$1" in inspect) echo true;; *) echo "podman version 5.4.0";; esac\n' > "$t/bin/podman"; run check; want_rc 0 port-own
stub podman 'podman version 5.4.0'; stub ss ''

# Low memory and threads only warn.
reset; echo 'MemTotal: 8000000 kB' > "$t/proc/meminfo"; printf 'flags : vmx\nprocessor : 0\n' > "$t/proc/cpuinfo"
run check; has 'memory    warn' low-ram; has 'threads   warn: 1' low-threads
[[ $out != *FAIL* ]] || { echo "FAIL low-ram: $out"; exit 1; }

# check never runs a fix.
reset; rm -r "$t/sys/module/kvm_intel"; run check; [[ ! -s $t/log || $(cat "$t/log") != *sudo* ]] || { echo 'FAIL check ran sudo'; exit 1; }

# setup refuses root, so its prompts are tested only as a normal user.
if ((EUID != 0)); then
  reset; rm -r "$t/sys/module/kvm_intel"; echo n > "$t/in"; input=$t/in run setup; want_rc 2 setup-no
  [[ $(cat "$t/log") != *sudo* ]] || { echo 'FAIL setup ran a fix after n'; exit 1; }
  reset; rm -r "$t/sys/module/kvm_intel"; echo y > "$t/in"; input=$t/in run setup; want_rc 2 setup-yes
  grep -q '^sudo modprobe kvm_intel$' "$t/log" || { echo "FAIL setup-yes: $(cat "$t/log")"; exit 1; }
  # Ready: say what WinPodX changes in Windows, then run its setup only on y.
  reset; run setup; want_rc 0 setup-ready; has 'winpodx guest multi-session off' setup-ready
  has 'pod.disguise_level off' setup-ready; has 'not to scan C:\OEM' setup-ready; [[ $(cat "$t/log") != *'winpodx setup'* ]] || { echo 'FAIL setup without y'; exit 1; }
  reset; echo y > "$t/in"; input=$t/in run setup; want_rc 0 setup-go
  grep -qx 'winpodx setup' "$t/log" || { echo "FAIL setup-go: $(cat "$t/log")"; exit 1; }
else
  echo 'winapps: setup prompts skipped (running as root)'
fi
# office: a set-up WinPodX whose run of our installer app "installs" Office by leaving the
# marker the Windows script writes.
if ((EUID != 0)); then
  for c in mkdir rm cp sed; do ln -sf "$(command -v "$c")" "$t/bin/$c"; done
  h=$t/home; mkdir -p "$h/.config" "$t/etc/xdg"
  wpx=$h/.local/share/winpodx apps=$h/.local/share/winpodx/apps ico=$h/.local/share/icons/hicolor
  mkdir -p "$h/.local/share/applications"
  # A set-up WinPodX: running our installer app "installs" Office (the marker the Windows
  # script writes); refresh discovers Word, Excel and Edge as WinPodX stores them.
  cat > "$t/bin/winpodx" <<EOF
#!/bin/sh
echo "winpodx \$*" >> "$t/log"
case "\$*" in
  "app run kriss-office-setup --wait")
    cp "$apps/kriss-office-setup/app.toml" "$t/app.toml"
    [ -n "\$FAIL" ] || echo ok > "$h/.local/share/kriss/office/installed" ;;
  "app refresh")
    for a in microsoft-word:WINWORD microsoft-excel:EXCEL microsoft-edge:msedge; do
      mkdir -p "$wpx/discovered/\${a%%:*}"
      printf 'name = "%s"\\nfull_name = "%s"\\nexecutable = "C:\\\\\\\\Program Files\\\\\\\\X\\\\\\\\%s.EXE"\\nmime_types = ["text/plain"]\\nurl_schemes = ["https"]\\nsource = "win32"\\n' \\
        "\${a%%:*}" "\${a%%:*}" "\${a#*:}" > "$wpx/discovered/\${a%%:*}/app.toml"
      printf '[Desktop Entry]\\nName=%s\\nIcon=winpodx-%s\\n' "\${a%%:*}" "\${a%%:*}" > "$h/.local/share/applications/winpodx-\${a%%:*}.desktop"
    done
    # Icons as WinPodX installs them: Word in two sizes, Excel as SVG, Edge none.
    mkdir -p "$ico/256x256/apps" "$ico/48x48/apps" "$ico/scalable/apps"
    : > "$ico/256x256/apps/winpodx-microsoft-word.png"; : > "$ico/48x48/apps/winpodx-microsoft-word.png"
    : > "$ico/scalable/apps/winpodx-microsoft-excel.svg" ;;
  "app install "*)
    printf '[Desktop Entry]\\nName=%s\\nIcon=winpodx-%s\\n' "\$3" "\$3" > "$h/.local/share/applications/winpodx-\$3.desktop" ;;
esac
exit 0
EOF
  chmod +x "$t/bin/winpodx"; stub curl ''; stub xdg-mime ''
  # .docx already has the user's explicit default: Office must leave it alone.
  printf '[Default Applications]\napplication/vnd.openxmlformats-officedocument.wordprocessingml.document=writer.desktop\n' > "$h/.config/mimeapps.list"
  orun() { rc=0; out=$(HOME=$h DISPLAY=${NODISPLAY-:0} KRISS_ETC="$t/etc" PATH="$t/bin" "$kriss" winapps "$@" 2>&1 < "${input:-/dev/null}") || rc=$?; }

  : > "$t/log"; echo n > "$t/in"; input=$t/in orun office; want_rc 0 office-no; has 'about 3 GB' office-no
  [[ ! -s $t/log ]] || { echo "FAIL office did something after n: $(cat "$t/log")"; exit 1; }

  : > "$t/log"; orun office --yes; want_rc 0 office-yes; has 'Word, Excel and PowerPoint are in Start' office-yes
  grep -q 'O365HomePremRetail' "$h/.local/share/kriss/office/configuration.xml" || { echo 'FAIL office product'; exit 1; }
  grep -q 'AcceptEULA="FALSE"' "$h/.local/share/kriss/office/configuration.xml" || { echo 'FAIL office accepted the EULA'; exit 1; }
  grep -q 'officecdn.microsoft.com' "$h/.local/share/kriss/office/install.ps1" || { echo 'FAIL office source'; exit 1; }
  # WinPodX starts Windows, runs our installer app, then finds Word, Excel and PowerPoint.
  [[ $(grep "^winpodx " "$t/log") == $'winpodx pod start --wait\nwinpodx app run kriss-office-setup --wait\nwinpodx app refresh\nwinpodx app install microsoft-word\nwinpodx app install microsoft-excel' ]] ||
    { echo "FAIL office steps: $(cat "$t/log")"; exit 1; }
  grep -qF '\\tsclient\home\.local\share\kriss\office\install.ps1' "$t/app.toml" || { echo "FAIL office path: $(cat "$t/app.toml")"; exit 1; }
  [[ ! -e $apps/kriss-office-setup ]] || { echo 'FAIL installer app left behind'; exit 1; }
  if command -v python3 >/dev/null; then  # WinPodX reads it with tomllib
    python3 -c 'import sys, tomllib; d = tomllib.load(open(sys.argv[1], "rb")); assert d["name"] == "kriss-office-setup" and "," not in d["args"], d' "$t/app.toml" ||
      { echo 'FAIL app.toml'; exit 1; }
  fi

  # File types: Word and Excel get their own Office formats only, as user apps of WinPodX's;
  # Edge gets nothing. A type with an explicit default (.docx here) is left alone.
  w=$apps/microsoft-word/app.toml
  if ! grep -q '^executable = .*WINWORD.EXE"$' "$w" || ! grep -q '^mime_types = \["application/msword", ' "$w"; then
    echo "FAIL word types: $(cat "$w")"; exit 1
  fi
  ! grep -q 'text/plain\|url_schemes\|source' "$w" || { echo "FAIL word claims more: $(cat "$w")"; exit 1; }
  grep -q 'spreadsheetml.sheet' "$apps/microsoft-excel/app.toml" || { echo 'FAIL excel types'; exit 1; }
  [[ ! -e $apps/microsoft-edge ]] || { echo 'FAIL edge got file types'; exit 1; }
  grep -q '^xdg-mime default winpodx-microsoft-word.desktop application/msword$' "$t/log" || { echo "FAIL doc default: $(cat "$t/log")"; exit 1; }
  ! grep -q 'xdg-mime default .*wordprocessingml.document$' "$t/log" || { echo 'FAIL overrode the .docx default'; exit 1; }
  ! grep -q 'xdg-mime default .*text/plain' "$t/log" || { echo 'FAIL took text/plain'; exit 1; }
  [[ $(cat "$h/.local/share/kriss/office/apps") == $'WINWORD=microsoft-word\nEXCEL=microsoft-excel' ]] || { echo 'FAIL apps record'; exit 1; }
  if command -v python3 >/dev/null; then
    python3 -c 'import sys, tomllib; d = tomllib.load(open(sys.argv[1], "rb")); assert len(d["mime_types"]) == 5 and d["name"] == "microsoft-word", d' "$w" || { echo 'FAIL word toml'; exit 1; }
  fi

  # Icons: Start entries point at the icon file (the running shell's icon cache misses new
  # theme icons): the SVG, else the largest PNG; a name with no file stays a name.
  e=$h/.local/share/applications
  grep -qx "Icon=$ico/256x256/apps/winpodx-microsoft-word.png" "$e/winpodx-microsoft-word.desktop" || { echo "FAIL word icon: $(cat "$e/winpodx-microsoft-word.desktop")"; exit 1; }
  grep -qx "Icon=$ico/scalable/apps/winpodx-microsoft-excel.svg" "$e/winpodx-microsoft-excel.desktop" || { echo 'FAIL excel icon'; exit 1; }
  grep -qx 'Icon=winpodx-microsoft-edge' "$e/winpodx-microsoft-edge.desktop" || { echo 'FAIL edge icon'; exit 1; }

  # No display (an ssh shell): say so, start nothing.
  : > "$t/log"; NODISPLAY='' orun office --yes; want_rc 2 office-nodisplay; has 'no display' office-nodisplay
  [[ ! -s $t/log ]] || { echo "FAIL office ran without a display: $(cat "$t/log")"; exit 1; }

  orun office --business --yes; grep -q 'O365BusinessRetail' "$h/.local/share/kriss/office/configuration.xml" || { echo 'FAIL business'; exit 1; }

  # Setup that did not finish: no app refresh, a clear message.
  : > "$t/log"; FAIL=1 orun office --yes; want_rc 2 office-failed; has 'Office was not installed' office-failed
  [[ $(cat "$t/log") != *refresh* ]] || { echo 'FAIL refreshed after a failed setup'; exit 1; }

  # WinPodX missing: point at kriss winapps setup.
  rm "$t/bin/winpodx"; orun office --yes; want_rc 2 office-no-winpodx; has "kriss winapps setup" office-no-winpodx
fi
echo 'winapps: ok'

#!/bin/bash
# Checks kriss winapps' detection against fixture /proc, /sys, /dev and /etc trees and
# stub podman, podman-compose, xfreerdp3 and winboat. Touches nothing outside a temp dir.
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
stub winboat ''
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
reset; rm "$t/bin/podman-compose" "$t/bin/winboat"; run check; want_rc 1 no-pkgs
[[ $(grep -c 'fix: sudo pacman' <<<"$out") == 2 ]] || { echo "FAIL no-pkgs: $out"; exit 1; }
stub podman-compose 'podman-compose version 1.6.0'; stub winboat ''
reset; stub xfreerdp3 'This is FreeRDP version 2.11.7'; run check; want_rc 1 rdp2; has 'freerdp   FAIL' rdp2
stub xfreerdp3 'This is FreeRDP version 3.10.3 (n/a)'
reset; stub podman 'podman version 3.4.4'; run check; want_rc 1 old-podman; has 'version 3.4.4 is too old' old-podman
stub podman 'podman version 5.4.0'

# No subordinate IDs: the fix picks a range after everyone else's.
reset; echo 'alice:100000:65536' | tee "$t/etc/subuid" > "$t/etc/subgid"; run check; want_rc 1 no-subid
has "usermod --add-subuids 165536-231071 --add-subgids 165536-231071 $me" no-subid
reset; : > "$t/etc/subuid"; : > "$t/etc/subgid"; run check; has 'add-subuids 100000-165535' empty-subid

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
  reset; run setup; want_rc 0 setup-ready; has 'pick Podman' setup-ready
else
  echo 'winapps: setup prompts skipped (running as root)'
fi
# office and run: a set-up WinBoat (compose file, running container) and FreeRDP that
# "installs" Office by leaving the marker the Windows script writes.
if ((EUID != 0)); then
  for c in realpath mkdir rm head tr basename; do ln -sf "$(command -v "$c")" "$t/bin/$c"; done
  h=$t/home; mkdir -p "$h/.winboat" "$h/Documents"
  # shellcheck disable=SC2016 # literal ${HOME} for compose; the stub expands $1 and $* itself
  printf '    environment:\n      USERNAME: "MyWindowsUser"\n      PASSWORD: s3cret\n    volumes:\n      - ${HOME}:/shared\n' > "$h/.winboat/podman-compose.yml"
  # shellcheck disable=SC2016
  printf '#!/bin/sh\necho "podman $*" >> "%s/log"\ncase "$1" in inspect) echo true;; port) echo 127.0.0.1:40000;; esac\n' "$t" > "$t/bin/podman"
  printf '#!/bin/sh\necho "xfreerdp3 $*" >> "%s/log"\ncase "$*" in *Office\\ setup*) echo ok > "%s/.local/share/kriss/office/installed";; esac\n' "$t" "$h" > "$t/bin/xfreerdp3"
  for c in curl xdg-mime update-desktop-database; do stub "$c" ''; done
  chmod +x "$t/bin/podman" "$t/bin/xfreerdp3"
  orun() { rc=0; out=$(HOME=$h PATH="$t/bin" "$kriss" winapps "$@" 2>&1 < "${input:-/dev/null}") || rc=$?; }

  : > "$t/log"; echo n > "$t/in"; input=$t/in orun office; want_rc 0 office-no; has 'about 3 GB' office-no
  [[ $(cat "$t/log") != *xfreerdp3* ]] || { echo 'FAIL office ran setup after n'; exit 1; }

  : > "$t/log"; orun office --yes; want_rc 0 office-yes; has 'Word, Excel and PowerPoint are in Start' office-yes
  grep -q 'O365HomePremRetail' "$h/.local/share/kriss/office/configuration.xml" || { echo 'FAIL office product'; exit 1; }
  grep -q 'AcceptEULA="FALSE"' "$h/.local/share/kriss/office/configuration.xml" || { echo 'FAIL office accepted the EULA'; exit 1; }
  grep -q 'officecdn.microsoft.com' "$h/.local/share/kriss/office/install.ps1" || { echo 'FAIL office source'; exit 1; }
  { grep -qF '/port:40000' "$t/log" && grep -qF '/u:MyWindowsUser /p:s3cret' "$t/log"; } || { echo "FAIL office rdp: $(cat "$t/log")"; exit 1; }
  grep -qF 'cmd:-NoProfile -ExecutionPolicy Bypass -File "\\host.lan\Data\.local\share\kriss\office\install.ps1"' "$t/log" ||
    { echo "FAIL office path: $(cat "$t/log")"; exit 1; }
  for a in word excel powerpoint; do
    grep -q "^Exec=kriss winapps run $a %f$" "$h/.local/share/applications/kriss-office-$a.desktop" || { echo "FAIL launcher $a"; exit 1; }
  done
  grep -q 'xdg-mime default kriss-office-word.desktop application/vnd.openxmlformats-officedocument.wordprocessingml.document' "$t/log" ||
    { echo "FAIL docx default: $(cat "$t/log")"; exit 1; }

  orun office --business --yes; grep -q 'O365BusinessRetail' "$h/.local/share/kriss/office/configuration.xml" || { echo 'FAIL business'; exit 1; }

  # Setup that did not finish leaves no launchers behind it.
  rm "$h"/.local/share/applications/kriss-office-*.desktop
  printf '#!/bin/sh\n:\n' > "$t/bin/xfreerdp3"; orun office --yes; want_rc 2 office-failed; has 'Office was not installed' office-failed
  [[ ! -e $h/.local/share/applications/kriss-office-word.desktop ]] || { echo 'FAIL launchers after a failed setup'; exit 1; }
  printf '#!/bin/sh\necho "xfreerdp3 $*" >> "%s/log"\n' "$t" > "$t/bin/xfreerdp3"

  : > "$h/Documents/Report 1.docx"; : > "$t/log"; orun run word "$h/Documents/Report 1.docx"; want_rc 0 run-word
  grep -qF '/app:program:C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE,name:Word,cmd:"\\host.lan\Data\Documents\Report 1.docx"' "$t/log" ||
    { echo "FAIL run word: $(cat "$t/log")"; exit 1; }
  : > "$t/outside.docx"; orun run word "$t/outside.docx"; want_rc 2 run-outside; has 'only open files in your home folder' run-outside
  orun run notepad; want_rc 2 run-unknown

  # Not set up yet: point at kriss winapps setup.
  rm "$h/.winboat/podman-compose.yml"; orun office --yes; want_rc 2 office-no-winboat; has "kriss winapps setup" office-no-winboat
fi
echo 'winapps: ok'

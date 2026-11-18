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
echo 'winapps: ok'

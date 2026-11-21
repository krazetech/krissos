#!/usr/bin/env bash
# Upgrade path: install a released ISO with that release's own scripted install
# (TAG:iso/test/autoinstall), then boot it with internet and do what someone on that release
# does to reach main: its own `kriss update`, then `kriss channel testing` and `kriss update`
# again with the kriss the first update brought. Last, boot to the login screen.
# Checks: both updates finish, the renamed packages replaced the old ones, main's packages
# are there, and greetd starts the KrissOS login screen.
# Needs qemu-system-x86, qemu-utils, ovmf, libarchive-tools, gh, and sudo for qemu-nbd.
# usage: tools/ci/upgrade-test.sh TAG OUT_DIR
set -euo pipefail

tag=$1 out=$2
repo=$(cd "$(dirname "$0")/../.." && pwd)
mkdir -p "$out" && out=$(cd "$out" && pwd)
disk=$out/disk.qcow2
# shellcheck disable=SC2054 # the commas are QEMU option lists
qemu=(qemu-system-x86_64 -enable-kvm -cpu host -smp 4 -m 4096 -device virtio-vga -display none
      -bios "${OVMF:-/usr/share/ovmf/OVMF.fd}" -nic user,model=virtio-net-pci
      -drive "file=$disk,if=virtio,format=qcow2")

gh release download "$tag" -R krazetech/krissos -p '*.iso' -D "$out" --clobber
iso=$(ls "$out"/*.iso)
# Today's stable [kriss] instead of the ISO's own copy (/opt/kriss-local): the ISO's copy
# lacks kriss-welcome, which came from the online [kriss] of the day, and that repo state is
# gone. Mixed, old local packages meet new online ones whose dependencies they cannot meet.
# So this is the release's installer, config and keyring with today's stable packages.
cat >"$out/online-only" <<'ONLINE'
sed -i 's|^pacman --config "$conf" -Sy$|sed -i "/^\\[kriss-local\\]/,/^\$/d" "$conf"\n&|' /usr/lib/kriss-installer/pacstrap
grep -B2 -A1 'config "$conf" -Sy' /usr/lib/kriss-installer/pacstrap
grep -q '^sed -i "/^\\\[kriss-local' /usr/lib/kriss-installer/pacstrap
ONLINE
git -C "$repo" show "$tag:iso/test/autoinstall" |
  awk -v f="$out/online-only" '/^\/usr\/lib\/kriss-installer\/pacstrap / { while ((getline l < f) > 0) print l } 1' |
  # Today's kriss-tools nests Snapshots under the KrissOS entry (//Snapshots); accept both.
  sed "s|grep -q '^/Snapshots'|grep -q '^//*Snapshots'|" >"$out/autoinstall"
grep -q "^sed -i 's|^pacman --config" "$out/autoinstall" || { echo "$tag: no pacstrap step in its autoinstall" >&2; exit 1; }
# What main's ISO installs, less what only the live system has, to see what an update misses.
grep -v '^#' "$repo/iso/packages.x86_64" | grep -vxE 'kriss-installer|calamares|archinstall|.*-live|' |
  sort -u >"$out/main-packages"

# 1. Install the release, unattended, as its CI did.
tmp=$(mktemp -d)
bsdtar -xf "$iso" -C "$tmp" loader/entries/01-krissos.conf 'kriss/boot/x86_64/*'
opts=$(sed -n 's/^options *//p' "$tmp/loader/entries/01-krissos.conf")
qemu-img create -f qcow2 "$disk" 40G
timeout 40m "${qemu[@]}" -cdrom "$iso" \
  -kernel "$tmp"/kriss/boot/x86_64/vmlinuz-* -initrd "$tmp"/kriss/boot/x86_64/initramfs-*.img \
  -fw_cfg "name=opt/kriss/autoinstall,file=$out/autoinstall" \
  -append "$opts console=ttyS0,115200 systemd.journald.forward_to_console=1 \
systemd.run=\"/usr/bin/bash /sys/firmware/qemu_fw_cfg/by_name/opt/kriss/autoinstall/raw\" \
systemd.run_success_action=poweroff systemd.run_failure_action=poweroff" \
  -serial "file:$out/install.log" || true
grep -q 'kriss-autoinstall: done' "$out/install.log" || {
  grep -n 'error\|failed' "$out/install.log" | tail -30 >&2; echo "$tag: the install failed; see install.log" >&2; exit 1; }
echo "$tag: installed"

# 2. A one-shot unit on the installed disk runs the updates at its next boot, then powers off.
cat >"$out/steps" <<'STEPS'
#!/bin/bash
# Lines starting "upgrade:" are what upgrade-test.sh reads.
set -x
rm -f /etc/systemd/system/multi-user.target.wants/kriss-upgrade-test.service
echo "upgrade: from $(kriss version | head -n1)"
kriss update && echo "upgrade: stable ok" || echo "upgrade: FAIL kriss update on stable"
echo "upgrade: now $(kriss version | head -n1)"
# Stable's kriss may predate `kriss channel` (0.4.0 does); on release day stable carries main's,
# so switch with main's own kriss then, and say so.
if kriss help 2>&1 | grep -q '^ *channel '; then kriss channel testing
else echo "upgrade: note stable's kriss has no channel command; used main's"; kriss-main channel testing; fi &&
  kriss update && echo "upgrade: testing ok" || echo "upgrade: FAIL kriss update on testing"
echo "upgrade: now $(kriss version | head -n1)"
# The update above ran the old kriss. Once more with this branch's, as the next update would.
kriss-main update && echo "upgrade: again ok" || echo "upgrade: FAIL the second kriss update"
echo "upgrade: now $(kriss version | head -n1)"
for p in cosmic-settings cosmic-comp; do
  pacman -Q "$p-kriss" >/dev/null 2>&1 || echo "upgrade: FAIL $p was not replaced by $p-kriss"
done
while read -r p; do
  pacman -Qq "$p" >/dev/null 2>&1 || pacman -Qqs "^$p\$" >/dev/null 2>&1 || echo "upgrade: missing $p"
done </usr/local/share/main-packages
grep -h 'kriss-shell' /etc/greetd/config.toml | sed 's/^/upgrade: greetd /'
echo "upgrade: done"
systemctl poweroff
STEPS
cat >"$out/unit" <<'UNIT'
[Unit]
Description=Upgrade test
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/kriss-upgrade-test
# The journal, which the test kernel line forwards to ttyS0: the serial getty that starts
# meanwhile hangs up a direct tty and the rest of the output is lost.
StandardOutput=journal
StandardError=journal
UNIT
sudo modprobe nbd max_part=8
sudo qemu-nbd -c /dev/nbd0 "$disk"
sudo udevadm settle
mnt=$(mktemp -d)
sudo mount -o subvol=@ /dev/nbd0p3 "$mnt"
sudo install -Dm755 "$out/steps" "$mnt/usr/local/bin/kriss-upgrade-test"
sudo install -Dm755 "$repo/tools/kriss" "$mnt/usr/local/bin/kriss-main"
sudo install -Dm644 "$out/main-packages" "$mnt/usr/local/share/main-packages"
sudo install -Dm644 "$out/unit" "$mnt/etc/systemd/system/kriss-upgrade-test.service"
sudo ln -sf ../kriss-upgrade-test.service "$mnt/etc/systemd/system/multi-user.target.wants/"
sudo umount "$mnt"
sudo qemu-nbd -d /dev/nbd0

timeout 60m "${qemu[@]}" -serial "file:$out/update.log" || true
grep -a 'kriss-upgrade-test\[[0-9]*\]: upgrade: ' "$out/update.log" | tr -d '\r' | sed 's/^.*\]: //' |
  tee "$out/result"
grep -q '^upgrade: done' "$out/result" || { echo "$tag: the update run did not finish; see update.log" >&2; exit 1; }

# 3. The updated system boots to the KrissOS login screen.
"${qemu[@]}" -serial "file:$out/boot.log" &
pid=$!
ok=0
for _ in $(seq 60); do
  if grep -aqE 'Started.*Greeter daemon|session opened for user greeter' "$out/boot.log"; then ok=1; break; fi
  sleep 5
done
kill "$pid" && wait "$pid" || true
((ok)) || echo "upgrade: FAIL no login screen after the update" | tee -a "$out/result"
! grep -q 'FAIL' "$out/result" || { echo "$tag: the upgrade path is broken (see above)." >&2; exit 1; }
echo "$tag: reaches main with kriss update"

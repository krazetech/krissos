#!/usr/bin/env bash
# Build the KrissOS live ISO. Run as root on Arch (CI runs it in a privileged
# archlinux container).
# usage: iso/build.sh OUT_DIR WORK_DIR
# env: KRISS_CHANNEL  stable (the default): packages from [kriss], as for a release.
#                     testing: [kriss-testing] ahead of [kriss], so nightly and PR ISOs test
#                     what is about to be promoted. Only the build sees it: the live system
#                     and installs keep [kriss] alone (`kriss channel testing` opts in).
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
out=$1 work=$2
mkdir -p "$out" "$work"

pacman -Syu --noconfirm --needed archiso
# Trust the [kriss] key from this checkout. The live system trusts it through
# kriss-keyring and `pacman-key --populate` in pacman-init.service.
pacman-key --init
pacman-key --add "$here/../pkgs/kriss-keyring/krissos.gpg"
pacman-key --lsign-key 7C92AE8B599AF81321666CA31317AA31B21C5F87

profile="$work/profile"
rm -rf "$profile"
cp -a "$here/." "$profile"

# Build the small [kriss] packages from this checkout and put them ahead of the
# published repo, so an ISO from a branch carries that branch's theme and tools.
# nodejs runs kriss-shell's check(); qt6-tools builds kriss-store's translations.
pacman -S --noconfirm --needed base-devel python librsvg python-pywayland wayland wayland-protocols rust qt6-shadertools nodejs qt6-tools
id builder >/dev/null 2>&1 || useradd -m builder
src="$work/src" local_repo="$work/kriss-local"
rm -rf "$src" "$local_repo"
mkdir -p "$src" "$local_repo"
cp -a "$here/../pkgs" "$here/../theme" "$here/../tools" "$here/../shell" "$here/../installer" "$here/../store" "$src/"
chown -R builder "$src" "$local_repo"
for p in kriss-keyring kriss-settings kriss-theme kriss-tools kriss-shell kriss-installer shim-signed; do
  su builder -c "cd '$src/pkgs/$p' && PKGDEST='$local_repo' makepkg --noconfirm --nodeps"
done
# The Store's tests need PySide6 and Kirigami; the packages workflow runs them.
su builder -c "cd '$src/pkgs/kriss-store' && PKGDEST='$local_repo' makepkg --noconfirm --nodeps --nocheck"
# The repos this build installs from. Until the first publish there is no [kriss-testing].
conf=$work/pacman.conf
cp "$here/pacman.conf" "$conf"
testing_url=https://github.com/krazetech/krissos/releases/download/testing-x86_64
add_testing() { sed -i "/^\[kriss\]/i [kriss-testing]\nSigLevel = Required\nServer = $testing_url\n" "$1"; }
if [ "${KRISS_CHANNEL:-stable}" = testing ]; then
  if curl -fsIL -o /dev/null "$testing_url/kriss-testing.db"; then
    add_testing "$conf"
  else
    echo "There is no [kriss-testing] yet; building from [kriss]."
  fi
fi
# Calamares, cosmic-comp-kriss and cosmic-settings-kriss take a while to compile: build them only when the repos
# lack this version. pacman lists repos in order, so [kriss-testing] wins when it is there.
pacman --config "$conf" -Sy
for p in calamares cosmic-comp-kriss cosmic-settings-kriss; do
  dir=$src/pkgs/$p
  want=$(source "$dir/PKGBUILD" && echo "$pkgver-$pkgrel")
  have=$(pacman --config "$conf" -Sl | awk -v p="$p" '$2 == p {print $3; exit}')
  if [ "$want" != "$have" ]; then
    echo "Building $p $want (the repos have '${have:-none}')"
    (source "$dir/PKGBUILD" && pacman -S --noconfirm --needed "${depends[@]}" "${makedepends[@]}")
    su builder -c "cd '$dir' && PKGDEST='$local_repo' makepkg --noconfirm --nodeps"
  fi
done
repo-add "$local_repo/kriss-local.db.tar.zst" "$local_repo"/*.pkg.tar.zst
# sed -i replaces the pacman.conf symlink with a file, so the live system's copy keeps
# only the published [kriss]. Order: this checkout, then [kriss-testing], then [kriss].
sed -i "/^\[kriss\]/i [kriss-local]\nSigLevel = Optional TrustAll\nServer = file://$local_repo\n" \
  "$profile/pacman.conf"
if grep -q '^\[kriss-testing\]' "$conf"; then add_testing "$profile/pacman.conf"; fi

# BIOS boot menu background: the logo above the menu (systemd-boot shows no images).
python "$here/../theme/generate.py" "$here/../theme/templates/usr/share/pixmaps" "$work/logo"
{
  echo '<svg xmlns="http://www.w3.org/2000/svg" width="640" height="480"><rect width="640" height="480"/>'
  echo '<svg x="264" y="24" width="112" height="112" viewBox="0 0 569 569">'
  sed '1,/<svg /d' "$work/logo/krissos.svg"  # the logo's shapes and its closing </svg>
  echo '</svg>'
} | rsvg-convert -o "$profile/syslinux/splash.png"

w=$work/mkarchiso
rm -rf "$w"
mkarchiso -v -w "$w" -o "$out" "$profile"

# Secure Boot with the PC's stock keys: firmware -> Fedora's shim (signed by Microsoft) ->
# systemd-boot (as grubx64.efi, the name shim starts) -> the kernel. Both are signed with a
# key made for this build only. Its private half is deleted when this script ends, so
# nothing else can ever be signed with it. With Secure Boot on, shim cannot check
# systemd-boot until that key is trusted, so it opens MokManager: "Enroll key from disk",
# then KRISSOS.cer at the top of the USB (docs/secure-boot.md). The ISO's GPG signature
# vouches for the certificate. Then mkarchiso runs again: with its step markers in place,
# it only writes the ISO image again (efiboot.img keeps 8 MiB free for this).
pacman -S --noconfirm --needed sbsigntools mtools openssl
sb=$(mktemp -d)
trap 'rm -rf "$sb"' EXIT
openssl req -new -x509 -newkey rsa:2048 -nodes -sha256 -days 3650 \
  -subj "/CN=KrissOS live USB $(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)" \
  -keyout "$sb/sb.key" -out "$sb/sb.crt" 2>/dev/null
openssl x509 -in "$sb/sb.crt" -outform der -out "$sb/KRISSOS.cer"
sign() { sbsign --key "$sb/sb.key" --cert "$sb/sb.crt" --output "$2" "$1" >/dev/null; }
iso=$w/iso img=$w/efiboot.img shim=$w/x86_64/airootfs/usr/share/shim-signed
sign "$iso/EFI/BOOT/BOOTX64.EFI" "$sb/grubx64.efi"
cp "$shim/shimx64.efi" "$iso/EFI/BOOT/BOOTX64.EFI"
cp "$shim/mmx64.efi" "$sb/grubx64.efi" "$iso/EFI/BOOT/"
cp "$sb/KRISSOS.cer" "$iso/"
mcopy -o -i "$img" "$iso/EFI/BOOT/BOOTX64.EFI" "$iso/EFI/BOOT/mmx64.efi" "$iso/EFI/BOOT/grubx64.efi" ::/EFI/BOOT/
mcopy -o -i "$img" "$sb/KRISSOS.cer" ::/
for k in "$iso/kriss/boot/x86_64/vmlinuz-"* "$iso/boot/memtest86+/memtest86x64.efi"; do
  [ -f "$k" ] || continue
  sign "$k" "$k"
  case $k in
  */vmlinuz-*) mcopy -o -i "$img" "$k" ::/kriss/boot/x86_64/ ;;
  *) mcopy -o -i "$img" "$k" ::/boot/memtest86+/ ;;
  esac
done
rm -f "$out"/*.iso "$w/iso._build_iso_image" "$w/build._build_buildmode_iso"
mkarchiso -v -w "$w" -o "$out" "$profile"
rm -rf "$w"

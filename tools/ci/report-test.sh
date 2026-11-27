#!/bin/bash
# Checks kriss report takes out names, Wi-Fi names, serials and addresses before showing it.
set -euo pipefail
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
mkdir -p "$t/etc" "$t/sys/class/dmi/id"
export KRISS_ETC=$t/etc KRISS_SYS=$t/sys USER=ana
# shellcheck source=/dev/null # tools/kriss is linted on its own
. "$(dirname "$0")/../kriss"

fail() { echo "FAIL: $*"; exit 1; }
printf 'root:x:0:0::/root:/bin/bash\nana:x:1000:1000::/home/ana:/bin/bash\n' >"$t/etc/passwd"
echo 'anas-laptop' >"$t/etc/hostname"
echo 'PF3XK9Z2' >"$t/sys/class/dmi/id/product_serial"
nmcli() { printf '%s\n' 'Rumah Ana 5G' 'Kedai (5G)+{Free}' 'Unclosed (SSID'; }

in="Nov 21 anas-laptop kernel: wlan0 connected to Rumah Ana 5G (aa:bb:cc:dd:ee:ff) at 192.168.1.20
Joined Kedai (5G)+{Free} and Unclosed (SSID
/home/ana/.config/kriss/shell.conf: owned by ana, serial PF3XK9Z2, mail ana.z@example.com
linux-kriss 7.3.4 upgraded"
out=$(report_scrub <<<"$in")
for bad in anas-laptop 'Rumah Ana' 'Kedai (5G)+{Free}' 'Unclosed (SSID' aa:bb 192.168 /home/ana 'by ana' PF3XK9Z2 example.com; do
  [[ $out != *"$bad"* ]] || fail "'$bad' is still in: $out"
done
[[ $out == *'linux-kriss 7.3.4 upgraded'* ]] || fail "versions should stay: $out"
[[ $out == *'[removed]/.config/kriss'* ]] || fail "the home path goes as a whole: $out"

# Default hostname `krissos` must not scrub ID=krissos or repo URLs.
echo 'krissos' >"$t/etc/hostname"
out2=$(report_scrub <<<'ID=krissos https://github.com/krazetech/krissos')
[[ $out2 == 'ID=krissos https://github.com/krazetech/krissos' ]] || fail "default hostname scrubbed krissos: $out2"
echo "report-test: ok"

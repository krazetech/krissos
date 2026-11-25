#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Kraze Tech
# Checks kriss tune's profile table against stub powerprofilesctl and scxctl.
set -euo pipefail
kriss=$(realpath "$(dirname "$0")/../kriss")
bin=$(mktemp -d)
trap 'rm -rf "$bin"' EXIT
for c in powerprofilesctl scxctl; do
  # shellcheck disable=SC2016 # the stub expands $1 and $* itself
  printf '#!/bin/sh\necho "%s $*" >> "%s/log"\n[ "$1" != get ] || echo "${STUB_GET:-balanced}"\n' "$c" "$bin" > "$bin/$c"
  chmod +x "$bin/$c"
done

check() { # check ARGS... -- EXPECTED_LOG
  local args=() want
  while [ "$1" != -- ]; do args+=("$1"); shift; done
  want=$2
  : > "$bin/log"
  PATH="$bin:$PATH" "$kriss" tune "${args[@]}" >/dev/null
  [ "$(paste -sd';' "$bin/log")" = "$want" ] || { echo "FAIL: tune ${args[*]}: $(paste -sd';' "$bin/log")"; exit 1; }
}

check performance -- 'powerprofilesctl set performance;scxctl switch -s lavd -m gaming'
check balanced -- 'powerprofilesctl set balanced;scxctl switch -s bpfland -m auto'
check powersave -- 'powerprofilesctl set power-saver;scxctl switch -s lavd -m powersave'
check kapcai -- 'powerprofilesctl set power-saver;scxctl switch -s lavd -m powersave'
STUB_GET=power-saver check sync -- 'powerprofilesctl get;powerprofilesctl set power-saver;scxctl switch -s lavd -m powersave'
STUB_GET=performance check sync -- 'powerprofilesctl get;powerprofilesctl set performance;scxctl switch -s lavd -m gaming'
if PATH="$bin:$PATH" "$kriss" tune turbo 2>/dev/null; then echo 'FAIL: unknown profile accepted'; exit 1; fi
echo 'tune: ok'

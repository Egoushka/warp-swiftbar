#!/bin/bash
# Exercises freeze / unfreeze with a dry run and a fake launchd state: no admin prompt, no daemon.
cd "$(dirname "$0")/.." || exit 1
fail=0
check() { # name, expected exit, expected substring, actual exit, actual output
  if [[ "$4" != "$2" || "$5" != *"$3"* ]]; then echo "FAIL $1: exit $4, '$5'"; fail=1; else echo "ok   $1"; fi
}
refute() { # name, forbidden substring, actual output
  if [[ "$3" == *"$2"* ]]; then echo "FAIL $1: found '$2' in '$3'"; fail=1; else echo "ok   $1"; fi
}
label="com.cloudflare.1dot1dot1dot1.macos.warp.daemon"
dir=$(mktemp -d "${TMPDIR:-/tmp}/warp-freeze.XXXXXX") || exit 1; trap 'rm -rf "$dir"' EXIT
run() { WARP_SWIFTBAR_DRY_RUN=1 SWIFTBAR_PLUGIN_CACHE_PATH="$dir" bash warp.10s.sh "$@"; }

out=$(run freeze); check "freeze disables the job" 0 "launchctl disable system/$label" $? "$out"
check "freeze unloads the job" 0 "launchctl bootout system/$label" 0 "$out"
out=$(run unfreeze); check "unfreeze enables the job" 0 "launchctl enable system/$label" $? "$out"
check "unfreeze starts the job" 0 "launchctl kickstart -k system/$label" 0 "$out"
out=$(run start-daemon); check "start-daemon also enables the job" 0 "launchctl enable system/$label" $? "$out"

# Menu with a fake frozen state, if this machine has warp-cli and jq.
if command -v warp-cli >/dev/null && command -v jq >/dev/null; then
  out=$(WARP_SWIFTBAR_FROZEN=1 SWIFTBAR_PLUGIN_CACHE_PATH="$dir" bash warp.10s.sh)
  check "frozen menu says so" 0 "WARP is frozen" $? "$out"
  check "frozen menu offers unfreeze" 0 "param1=unfreeze" 0 "$out"
  check "frozen menu has its own icon" 0 "sfimage=snowflake" 0 "$out"
  out=$(WARP_SWIFTBAR_FROZEN=0 SWIFTBAR_PLUGIN_CACHE_PATH="$dir" bash warp.10s.sh)
  refute "unfrozen menu is not the frozen one" "WARP is frozen" "$out"
fi
exit $fail

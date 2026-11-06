#!/bin/bash
# Exercises the tailnet flap detection with a fake clock and fake route table: no network.
cd "$(dirname "$0")/.." || exit 1
fail=0
check() { # name, expected exit, expected substring, actual exit, actual output
  if [[ "$4" != "$2" || "$5" != *"$3"* ]]; then echo "FAIL $1: exit $4, '$5'"; fail=1; else echo "ok   $1"; fi
}
step() { # time iface
  WARP_SWIFTBAR_NOW=$1 WARP_SWIFTBAR_ROUTE_IFACE=$2 SWIFTBAR_PLUGIN_CACHE_PATH="$dir" bash warp.10s.sh flap-check
}
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT

out=$(step 1000 en0); check "first sample is a baseline" 0 "stable: 0" $? "$out"
out=$(step 1010 en0); check "same interface is no change" 0 "stable: 0" $? "$out"
out=$(step 1020 utun4); check "one change" 0 "stable: 1" $? "$out"
out=$(step 1030 en0); check "two changes" 0 "stable: 2" $? "$out"
out=$(step 1040 utun4); check "third change in window flaps" 1 "flapping: 3" $? "$out"
out=$(step 1400 utun4); check "changes age out of the window" 0 "stable: 0" $? "$out"

# Full plugin output with the same fake route, if this machine has warp-cli.
if command -v warp-cli >/dev/null && command -v jq >/dev/null; then
  for t in 2000 2010 2020; do for i in en0 utun4; do step $t $i >/dev/null; t=$((t + 1)); done; done
  head=$(WARP_SWIFTBAR_NOW=2030 WARP_SWIFTBAR_ROUTE_IFACE=en0 SWIFTBAR_PLUGIN_CACHE_PATH="$dir" bash warp.10s.sh | head -n 1)
  check "menu bar shows the flap" 0 "tailnet flapping" 0 "$head"
fi
exit $fail

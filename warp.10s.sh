#!/bin/bash
# <xbar.title>Cloudflare WARP</xbar.title>
# <xbar.version>v0.1.0</xbar.version>
# <xbar.author>Yehor Hrabovskyi</xbar.author>
# <xbar.author.github>Egoushka</xbar.author.github>
# <xbar.desc>Status and controls for the Cloudflare WARP / Zero Trust client, so you can quit its GUI.</xbar.desc>
# <xbar.dependencies>warp-cli,jq</xbar.dependencies>
# <xbar.abouturl>https://github.com/Egoushka/warp-swiftbar</xbar.abouturl>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>

export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"

DAEMON_LABEL="com.cloudflare.1dot1dot1dot1.macos.warp.daemon"
DAEMON_PLIST="/Library/LaunchDaemons/$DAEMON_LABEL.plist"
CACHE="${SWIFTBAR_PLUGIN_CACHE_PATH:-${TMPDIR:-/tmp}/warp-swiftbar}"
PAUSED_AT="$CACHE/paused_at"
SELF="$0"
mkdir -p "$CACHE"

# --- actions (menu items call the script back with an argument) ---
case "$1" in
  connect)    warp-cli connect >/dev/null 2>&1; rm -f "$PAUSED_AT"; exit 0 ;;
  disconnect) warp-cli disconnect >/dev/null 2>&1; date +%s >"$PAUSED_AT"; exit 0 ;;
  vnet)       warp-cli vnet "$2" >/dev/null 2>&1; exit 0 ;;
  copy)       printf '%s' "$2" | pbcopy; exit 0 ;;
  start-daemon)
    # The daemon plist is RunAtLoad+KeepAlive; if launchd didn't load it at boot,
    # macOS background-item approval is usually off. Load and start it as root.
    osascript -e "do shell script \"launchctl bootstrap system '$DAEMON_PLIST' 2>/dev/null; launchctl kickstart -k system/$DAEMON_LABEL\" with administrator privileges" >/dev/null 2>&1
    exit 0 ;;
  quit-gui)   osascript -e 'quit app "Cloudflare WARP"' >/dev/null 2>&1; exit 0 ;;
  open-gui)   open -a "Cloudflare WARP"; exit 0 ;;
  login-items) open "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"; exit 0 ;;
esac

# SwiftBar treats "|" as the parameter separator.
clean() { tr '|' '/' ; }
# shellcheck disable=SC2016  # single quotes are literal SwiftBar quoting
item() { echo "$1 | bash='$SELF' param1=$2 ${3:+param2='$3'} terminal=false refresh=true"; }

if ! command -v warp-cli >/dev/null || ! command -v jq >/dev/null; then
  echo " | sfimage=exclamationmark.shield"
  echo "---"
  echo "warp-cli or jq not found on PATH"
  echo "Install Cloudflare WARP | href=https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/warp/download-warp/"
  exit 0
fi

status_json=$(warp-cli --json status 2>/dev/null)
if ! jq -e .status >/dev/null 2>&1 <<<"$status_json"; then
  echo " | sfimage=exclamationmark.shield"
  echo "---"
  echo "WARP daemon is not running"
  echo "Usually: Cloudflare WARP is off under Login Items → Allow in the Background | size=11"
  item "Start daemon now (asks for admin password)" start-daemon
  item "Open Login Items settings…" login-items
  exit 0
fi

status=$(jq -r .status <<<"$status_json")
reason=$(jq -r '.reason // empty' <<<"$status_json")
settings=$(warp-cli --json settings 2>/dev/null | jq '.settings')
s() { jq -r "$1 // empty" <<<"$settings"; }

case "$status" in
  Connected)  icon="lock.shield.fill"; rm -f "$PAUSED_AT" ;;
  Connecting) icon="arrow.triangle.2.circlepath" ;;
  *)          icon="shield.slash" ;;
esac
echo " | sfimage=$icon"
echo "---"

echo "${status}${reason:+ — $reason}"

# The org's "auto connect" policy turns WARP back on N minutes after a manual disconnect.
auto_min=$(s .auto_connect_after_min)
if [[ "$status" == Disconnected && "${auto_min:-0}" -gt 0 ]]; then
  approx=""
  if [[ ! -f "$PAUSED_AT" ]]; then date +%s >"$PAUSED_AT"; approx="~"; fi
  left=$(( auto_min - ( $(date +%s) - $(cat "$PAUSED_AT") ) / 60 ))
  (( left < 0 )) && left=0
  echo "Org reconnects it in ${approx}${left} min | size=11"
fi

if [[ "$(s .switch_locked)" == true ]]; then
  echo "Switch locked by your organization | size=11"
elif [[ "$status" == Connected || "$status" == Connecting ]]; then
  item "Disconnect" disconnect
else
  item "Connect" connect
fi

echo "---"
org=$(s .organization)
[[ -n "$org" ]] && echo "Organization: $org | size=12"
echo "Mode: $(s .operation_mode)  ·  $(s .warp_tunnel_protocol) | size=12"

vnets=$(warp-cli --json vnet 2>/dev/null)
if [[ $(jq '.virtual_networks | length' <<<"$vnets" 2>/dev/null) -gt 1 ]]; then
  active=$(jq -r .active_vnet_id <<<"$vnets")
  echo "Virtual network"
  jq -r '.virtual_networks[] | "\(.id)\t\(.name)"' <<<"$vnets" | clean | while IFS=$'\t' read -r id name; do
    item "--$name" vnet "$id" | sed "s/refresh=true/refresh=true checked=$([[ $id == "$active" ]] && echo true || echo false)/"
  done
fi

mode=$(s .split_tunnel_mode)
echo "Split tunnel ($mode)"
jq -r '(.split_tunnel_ips // [])[], (.split_tunnel_hosts // [])[] | "\(.value // .address // .host)\t\(.description // "")"' <<<"$settings" \
  | clean | while IFS=$'\t' read -r value desc; do
    item "--$value${desc:+  ($desc)}" copy "$value"
  done

echo "---"
if pgrep -xq "Cloudflare WARP"; then
  item "Quit official WARP app (tunnel keeps running)" quit-gui
else
  item "Open official WARP app" open-gui
fi
echo "Refresh | refresh=true"

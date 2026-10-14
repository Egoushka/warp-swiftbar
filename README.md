# warp-swiftbar

A [SwiftBar](https://swiftbar.app) menu-bar plugin for the Cloudflare WARP client (consumer or Zero Trust),
so you can quit Cloudflare's GUI and keep the tunnel.

It talks to the WARP daemon through `warp-cli`, the same way the official app does.

- Status icon: connected, connecting, disconnected, daemon down
- Connect / disconnect (hidden when your org locks the switch)
- Countdown to your org's auto-reconnect after a manual disconnect
- Organization, mode, tunnel protocol, virtual-network switcher
- Split-tunnel list (click an entry to copy it)
- When the daemon isn't running after a reboot: start it (admin prompt) or open Login Items

## Install

```bash
brew install --cask swiftbar
```

```bash
curl -fsSL https://raw.githubusercontent.com/Egoushka/warp-swiftbar/main/warp.10s.sh -o "$HOME/Library/Application Support/SwiftBar/Plugins/warp.10s.sh"
```

```bash
chmod +x "$HOME/Library/Application Support/SwiftBar/Plugins/warp.10s.sh"
```

Use your own plugin folder if you picked a different one in SwiftBar. Needs `jq` (built into macOS 15+, otherwise `brew install jq`).
The `10s` in the file name is the refresh interval.

## Daemon missing after a reboot?

The daemon is a launchd job with `RunAtLoad`. If macOS doesn't start it at boot, check
**System Settings → General → Login Items & Extensions → Allow in the Background → Cloudflare WARP**.
Reinstalling the app "fixes" it only because it re-registers that background item.

## What it can't do

It can't override Zero Trust policy: auto-reconnect timers, locked switches, split-tunnel lists and mode
come from your organization's device profile. The plugin shows them; your admin changes them.

## License

MIT

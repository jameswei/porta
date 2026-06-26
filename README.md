# Porta

> A lightweight macOS menu-bar app that finds and kills orphan dev-server ports left by coding agents.

When AI coding agents launch development servers during sessions, those servers often keep running after the session ends. Porta sits in your menu bar, shows you all listening ports matching your dev-tool presets, and lets you kill them with one click.

## Screenshot

*(coming soon)*

## Features

- 📡 **Detect listening ports** — powered by `lsof`, shows TCP LISTEN-state ports from your dev tools
- 🔪 **Kill with one click** — sends SIGTERM then SIGKILL to the owning process, with confirmation
- ⚙️ **Configurable presets** — filter by tool category (Node.js, Python, Go, Ruby, databases…) with toggles
- ➕ **Custom ports** — add your own port numbers or ranges
- 🚀 **Launch at login** — stays ready in the background
- 🪶 **Lightweight** — menu-bar only, no Dock icon, near-zero resource usage

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| macOS 13.0 (Ventura) or later | Required for modern launch-at-login API |
| Xcode 15+ | To build from source |
| Any Apple ID (free) | For local code signing in Xcode |

## Build from Source

```bash
git clone https://github.com/jameswei/porta.git
cd porta
open Porta.xcodeproj
```

In Xcode:
1. Select the **Porta** scheme in the toolbar
2. Choose **My Mac** as the run destination
3. Press **⌘R** to build and run

> **First run tip:** If Xcode asks about signing, go to **Xcode → Settings → Accounts**, add your Apple ID, click **Manage Certificates**, and create an *Apple Development* certificate.

## Running a Downloaded Release

If you download a `.app` from GitHub Releases and macOS shows a Gatekeeper warning (because the build isn't signed with a paid Developer ID):

```bash
# Option A — strip the quarantine flag
xattr -cr /path/to/Porta.app
open /path/to/Porta.app

# Option B — right-click the .app → Open → "Open Anyway"
```

## Usage

1. Click the **⚓** icon in the menu bar
2. See all listening ports from your configured dev tools
3. Click **✕** next to any port to kill the owning process (confirmation dialog shown)
4. Open **Settings** to:
   - Toggle preset port groups (Node.js, Python, Go, etc.)
   - Add custom port numbers
   - Enable/disable **Launch at Login**

## Architecture

See [`AGENTS.md`](./AGENTS.md) for architecture overview and coding conventions.

## License

MIT — see [LICENSE](./LICENSE).

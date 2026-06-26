# Porta — Agent Instructions

This file provides context and guidelines for coding agents working in this repository.

## Project Overview

Porta is a lightweight macOS status-bar application that detects and manages orphan TCP ports left by development tools and coding agents. It surfaces listening ports, shows the owning process, and lets the user terminate them with one click.

## Architecture

```
PortaApp (SwiftUI @main)
  └── AppDelegate (NSApplicationDelegate)
        ├── NSStatusItem — menu bar icon and click handler
        └── NSPopover — transient dropdown panel
              └── ContentView (SwiftUI)
                    ├── PortDetector (ObservableObject)
                    │     ├── Detects ports via: lsof -iTCP -sTCP:LISTEN -P -n
                    │     └── Terminates processes via SIGTERM → SIGKILL
                    └── SettingsView (SwiftUI)

PortSettings (UserDefaults-backed)
  ├── Preset port groups (togglable, default-on)
  └── Custom port numbers / ranges (user-added)
```

## Build

1. Open `Porta.xcodeproj` in Xcode 15+
2. Select the `Porta` scheme
3. Choose your Mac as the run destination
4. Press ⌘R to build and run

**Minimum requirement:** macOS 13.0 (Ventura) deployment target.

## Key Files

| File | Purpose |
|------|---------|
| `Porta/PortaApp.swift` | SwiftUI `@main` entry point; wires `AppDelegate` |
| `Porta/AppDelegate.swift` | Status bar setup, popover management |
| `Porta/Views/ContentView.swift` | Main dropdown panel UI |
| `Porta/Views/SettingsView.swift` | Settings panel (presets, custom ports, launch-at-login) |
| `Porta/Models/PortModel.swift` | `OpenPort` data model; `PortSettings` (UserDefaults config) |
| `Porta/Services/PortDetector.swift` | `lsof` wrapper, port filter, kill logic |
| `Porta/Info.plist` | App metadata; `LSUIElement = YES` hides the Dock icon |
| `Porta/Porta.entitlements` | Minimal entitlements; no App Sandbox |

## Coding Conventions

- **Language:** Swift 5.9+, targeting macOS 13.0+
- **UI framework:** SwiftUI for views; AppKit (`NSStatusItem`, `NSPopover`) for menu-bar plumbing
- **Reactivity:** `ObservableObject` + `@Published` for data flow
- **Persistence:** `UserDefaults` only — no CoreData, no files
- **Dependencies:** Zero third-party dependencies
- **Process invocation:** Use `Foundation.Process` for `lsof` and `kill` calls — never shell string interpolation

## Port Detection

- Command: `lsof -iTCP -sTCP:LISTEN -P -n`
- Only LISTEN-state TCP ports are shown (not established connections, not UDP)
- Filtered by `PortSettings.activePorts` — the union of enabled preset groups and user-added custom ports
- Default refresh interval: 5 seconds (user-configurable)

## Kill Strategy

1. Send **SIGTERM** to the owning PID
2. Wait 2 seconds
3. If the process is still alive, send **SIGKILL**
4. Refresh the port list 0.5 seconds after kill

## What NOT to Do

- Do not add App Sandbox entitlements — sandboxing blocks `lsof` and `kill` on arbitrary processes
- Do not target the App Store
- Do not add third-party dependencies without strong justification
- Do not store settings in a database — `UserDefaults` is sufficient

## Testing

There are no automated tests at this stage. Manual verification steps:
1. Build and run; confirm app appears in menu bar with no Dock icon
2. Start a dev server (e.g., `python3 -m http.server 8000`) and confirm it appears in the list
3. Kill it from the UI and confirm the process is gone

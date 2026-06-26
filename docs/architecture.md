# Architecture Overview

## Component Tree

```
PortaApp (SwiftUI @main)
  └── AppDelegate (NSApplicationDelegate)
        ├── NSStatusItem — RJ45 icon in the system menu bar
        └── NSPopover (.transient) — dropdown panel
              └── PopoverContentViewController (NSViewController)
                    ├── CursorCapturingView (NSView root)
                    │     └── NSHostingController<ContentView>
                    └── ContentView (SwiftUI)
                          ├── PortDetector (ObservableObject)
                          │     ├── Detects ports via lsof
                          │     └── Terminates processes via SIGTERM → SIGKILL
                          └── SettingsView (SwiftUI sheet)

PortSettings (ObservableObject, singleton, UserDefaults-backed)
  ├── Preset port groups — togglable, all enabled by default
  └── Custom port entries — validated add/remove list
```

## Key Files

| File | Purpose |
|------|---------|
| `Porta/PortaApp.swift` | SwiftUI `@main` entry; wires `AppDelegate` via `@NSApplicationDelegateAdaptor` |
| `Porta/AppDelegate.swift` | Status bar icon setup, popover lifecycle, cursor-capture infrastructure |
| `Porta/Views/ContentView.swift` | Main port list panel; `PortRowView` cards |
| `Porta/Views/SettingsView.swift` | Settings sheet: presets, custom ports, refresh interval, launch at login |
| `Porta/Models/PortModel.swift` | `OpenPort` model, `PortPresetGroup` definitions, `PortSettings` persistence |
| `Porta/Services/PortDetector.swift` | `lsof` subprocess, output parser, port coalescing, kill logic |
| `Porta/Info.plist` | `LSUIElement = YES` — hides the app from the Dock and app switcher |
| `Porta/Porta.entitlements` | Minimal entitlements; no App Sandbox (see note below) |
| `PortaTests/PortaTests.swift` | 28 unit tests covering validation, parsing, and coalescing |

## Port Detection

Porta runs `lsof -iTCP -sTCP:LISTEN -P -n -F pcPtn` on a configurable timer (default 5 s). The `-F` flag requests machine-readable output:

- `p<pid>` — process ID
- `c<cmd>` — command name
- `P<proto>` — protocol (TCP)
- `t<type>` — address family (IPv4 / IPv6)
- `n<addr:port>` — network name field

Results are filtered to `PortSettings.activePorts` (the union of enabled preset groups and user-added custom ports), then coalesced: separate IPv4 and IPv6 entries for the same `(port, pid, process)` tuple are merged into one row with a combined `addressFamily` string.

Process start time is read via `sysctl(KERN_PROC_PID)` from `kinfo_proc.kp_proc.p_starttime` and displayed as a relative time ("5h ago") using `RelativeDateTimeFormatter`.

## Kill Strategy

1. Re-verify the target PID still owns the port via a second `lsof` call (guards against PID reuse between the user clicking and the kill executing).
2. Send **SIGTERM** — allows graceful shutdown.
3. Wait 2 seconds.
4. If the process is still alive and still owns the port, escalate to **SIGKILL**.
5. Refresh the port list 0.5 s after signaling.

## Settings and Persistence

All settings are stored in `UserDefaults.standard`:

| Key | Type | Default |
|-----|------|---------|
| `enabledPresetKeys` | `[String]` | All preset keys |
| `customPortsInput` | `String` | `""` |
| `refreshIntervalSeconds` | `Int` | `5` |

`customPortsInput` is a comma-separated string of validated tokens (e.g. `"9000, 9300-9310"`). Each token is validated individually on Add; degenerate ranges (`9300-9300`) are normalized to single ports on entry. The refresh interval is snapped to the nearest allowed value `[1, 3, 5, 10, 30, 60]` on load.

## Non-Obvious Design Decisions

**No App Sandbox.** `lsof` and `kill` on arbitrary third-party processes require unrestricted access. App Sandbox blocks both. The app is not distributed via the App Store.

**CursorCapturingView.** `NSPopover` backed by a plain `NSHostingController` does not claim cursor ownership over non-interactive areas, causing the cursor and click events to fall through to whatever window is underneath. The fix is a full-coverage `NSTrackingArea` with the `.cursorUpdate` option on a custom `NSView` root. `cursorUpdate(with:)` resets the cursor to the standard arrow, preventing bleed-through.

**Custom ports as a list, not a text field.** Free-text entry makes it hard to surface per-entry validation errors and to support deduplication and normalization. Each entry is validated on Add; the stored representation is always a set of individually-valid tokens.

**`@testable` access via `internal` (not `private`) functions.** `parseLsofMachineOutput`, `coalesceOpenPorts`, and `parseNameField` are the highest-value unit-testable surfaces in `PortDetector`. They are declared `internal` rather than `private` so `@testable import Porta` can reach them in the test bundle. All other implementation details remain `private`.

**`Text(verbatim:)` for PIDs.** SwiftUI's string interpolation inside `Text("PID \(pid)")` uses `LocalizedStringKey`, which formats integers with thousands separators (`65,523`). `Text(verbatim: "PID \(pid)")` bypasses localization formatting.

## Coding Conventions

- Swift 5.9+, macOS 13.0+ deployment target
- SwiftUI for all views; AppKit only where SwiftUI has no equivalent (status bar, popover)
- `ObservableObject` + `@Published` for reactive data flow; no Combine pipelines beyond settings observation
- Zero third-party dependencies
- `Foundation.Process` for subprocess invocation — never shell string interpolation
- No comments except where the reason is non-obvious (hidden constraints, workarounds)

## Testing

The `PortaTests` target uses `@testable import Porta` with the app as the test host (`TEST_HOST` / `BUNDLE_LOADER`). Tests cover:

- `PortSettings.isValidEntry` — port number and range validation rules, boundary conditions
- `PortSettings.addCustomEntry` / `removeCustomEntry` — deduplication, normalization, mutation
- `PortPresetGroup.portsLabel` — consecutive range compression
- `PortDetector.parseNameField` — wildcard, IPv4, IPv6, invalid inputs
- `PortDetector.parseLsofMachineOutput` — single entry, filter exclusion, multiple processes
- `PortDetector.coalesceOpenPorts` — IPv4/IPv6 merging, distinct port preservation
- `OpenPort.isLocalhostOnly` — localhost, wildcard, coalesced mixed addresses

Run locally:

```bash
xcodebuild test \
  -project Porta.xcodeproj \
  -scheme Porta \
  -destination "platform=macOS" \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

CI runs the same command on every push and pull request to `main`.

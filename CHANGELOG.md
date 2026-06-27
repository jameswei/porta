# Changelog

All notable changes to Porta are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.1.0] - 2026-06-27

### Added

- **Simplified Chinese support** — in-app language switch via the translate icon in the header; preference is remembered across sessions, independent of OS locale
- **Monitor All Ports toggle** — footer filter icon bypasses all preset and custom filters, showing every TCP LISTEN port instantly; macOS system daemons are always excluded
- **Smart system daemon exclusion** — 14 known macOS system processes (ControlCenter, mDNSResponder, rapportd, and more) are always hidden, keeping the list focused on dev processes
- **App version** shown in the Settings footer
- Architecture documentation (`docs/architecture.md`)
- Project landing page (<https://jameswei.github.io/porta/>)

### Fixed

- Popover layout stability when switching languages (fixed 340 pt width prevents reflow)
- Default keyboard focus set to the refresh button on open

## [1.0.0] - 2026-06-26

### Added

- **Scope badge** — each port card shows `local` (localhost-only) or `public` (all interfaces) at a glance
- **Relative uptime** — displays how long the owning process has been running ("5h ago", "2 min ago") via `sysctl` + `RelativeDateTimeFormatter`
- **PID display** + Activity Monitor shortcut — magnifying glass button copies the process name to the clipboard and opens Activity Monitor
- **Validated custom ports list** — add/remove individual ports or ranges (e.g. `9000–9010`) with per-entry validation; replaces the earlier free-text input
- **Segmented refresh interval picker** — choose 1 s / 3 s / 5 s / 10 s / 30 s / 60 s
- **RJ45 status bar icon** — template image, adapts to light/dark menu bar automatically
- **Launch at login** via `SMAppService`
- **11 preset port-group categories** — Node.js/npm, Vite/Webpack, Python, Ruby/Rails, Go, Java/Spring, PostgreSQL, MySQL, Redis, MongoDB, Common Dev
- **28 unit tests** covering port validation, lsof output parsing, and IPv4/IPv6 coalescing
- GitHub Actions CI workflow (`xcodebuild test` on `macos-15`)
- GitHub Actions release workflow — builds Release config, zips `Porta.app`, and publishes a GitHub Release on `v*.*.*` tags
- Kill strategy: SIGTERM → 2 s wait → SIGKILL, with PID re-verification before signaling to guard against PID reuse

### Fixed

- Cursor penetration bug — `CursorCapturingView` with `NSTrackingArea` prevents click and cursor events from falling through to windows behind the popover
- IPv4 and IPv6 entries for the same `(port, pid, process)` tuple are coalesced into a single row

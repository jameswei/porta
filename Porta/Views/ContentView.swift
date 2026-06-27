import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject var portDetector = PortDetector()
    @StateObject private var settings = PortSettings.shared
    @EnvironmentObject var lm: LanguageManager
    @State private var showingSettings = false
    @FocusState private var refreshFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(verbatim: L("app_title"))
                    .font(.headline)
                Spacer()
                Button(action: {
                    lm.language = lm.language == "en" ? "zh-Hans" : "en"
                }) {
                    Image(systemName: "translate")
                }
                .buttonStyle(.plain)
                .help(lm.language == "en"
                    ? L("tooltip_switch_to_chinese")
                    : L("tooltip_switch_to_english"))
                Button(action: { portDetector.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .focused($refreshFocused)
                .help(L("tooltip_refresh"))
            }
            .padding(.bottom, 8)

            if let detectionError = portDetector.detectionError {
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: L("error_detect_ports"))
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text(verbatim: detectionError.userMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
            } else if portDetector.ports.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: emptyStateTitle)
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(verbatim: emptyStateDescription)
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: 360, alignment: .leading)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(portDetector.ports.enumerated()), id: \.element.id) { index, port in
                            PortRowView(port: port, onKill: {
                                portDetector.killPort(port)
                            })

                            if index < portDetector.ports.count - 1 {
                                Divider()
                                    .padding(.leading, 12)
                            }
                        }
                    }
                }
                .frame(maxWidth: 400)
                .frame(height: portListHeight)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Divider()

            HStack(spacing: 8) {
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape")
                }
                .help(L("tooltip_settings"))
                Spacer()
                Button(action: { settings.monitorAllPorts.toggle() }) {
                    Image(systemName: settings.monitorAllPorts
                        ? "line.3.horizontal.decrease.circle.fill"
                        : "line.3.horizontal.decrease.circle")
                    .foregroundColor(settings.monitorAllPorts ? .accentColor : .secondary)
                }
                .help(settings.monitorAllPorts
                    ? L("tooltip_monitor_all_on")
                    : L("tooltip_monitor_all_off"))
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Image(systemName: "power")
                }
                .keyboardShortcut("q", modifiers: .command)
                .help(L("tooltip_quit"))
            }
            .padding(.top, 8)
        }
        .padding(12)
        .frame(width: 340)
        .onAppear {
            portDetector.startMonitoring()
            refreshFocused = true
        }
        .onChange(of: showingSettings) { isPresented in
            if !isPresented {
                portDetector.refresh()
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(settings: settings)
                .environmentObject(lm)
        }
        .alert(
            L("alert_kill_failed_title"),
            isPresented: Binding(
                get: { portDetector.lastKillError != nil },
                set: { if !$0 { portDetector.lastKillError = nil } }
            )
        ) {
            Button(L("btn_ok")) { portDetector.lastKillError = nil }
        } message: {
            Text(verbatim: portDetector.lastKillError?.userMessage ?? "")
        }
    }

    private var emptyStateTitle: String {
        if settings.monitorAllPorts { return L("empty_monitor_all_title") }
        return settings.activePorts.isEmpty
            ? L("empty_no_presets_title")
            : L("empty_no_match_title")
    }

    private var emptyStateDescription: String {
        if settings.monitorAllPorts { return L("empty_monitor_all_desc") }
        return settings.activePorts.isEmpty
            ? L("empty_no_presets_desc")
            : L("empty_no_match_desc")
    }

    private var portListHeight: CGFloat {
        min(CGFloat(portDetector.ports.count) * 66, 300)
    }
}

struct PortRowView: View {
    let port: OpenPort
    let onKill: () -> Void
    @EnvironmentObject var lm: LanguageManager
    @State private var showConfirmation = false

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 8) {
                    Text(String(port.number))
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.semibold)
                        .textSelection(.enabled)

                    scopeBadge
                }

                HStack(spacing: 6) {
                    Text(port.processName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Text(verbatim: "PID \(port.pid)")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.6))

                    if let startTime = port.startTime {
                        Spacer()
                        Text(Self.relativeFormatter.localizedString(for: startTime, relativeTo: Date()))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            HStack(spacing: 2) {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(port.processName, forType: .string)
                    NSWorkspace.shared.open(
                        URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
                    )
                } label: {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(Lf("tooltip_activity_monitor_fmt", port.processName))

                Button(action: { showConfirmation = true }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .help(L("tooltip_kill_process"))
                .buttonStyle(.plain)
                .confirmationDialog(
                    L("dialog_kill_title"),
                    isPresented: $showConfirmation
                ) {
                    Button(L("btn_kill"), role: .destructive) { onKill() }
                } message: {
                    Text(verbatim: Lf("kill_confirm_fmt", port.processName, port.pid, port.number))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minHeight: 64, alignment: .center)
    }

    private var scopeBadge: some View {
        let isPublic = !port.isLocalhostOnly
        return Text(verbatim: L(isPublic ? "badge_public" : "badge_local"))
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isPublic ? Color.orange.opacity(0.15) : Color.secondary.opacity(0.12))
            .foregroundColor(isPublic ? .orange : .secondary)
            .clipShape(Capsule())
            .help(isPublic
                ? L("help_public_scope")
                : L("help_local_scope")
            )
    }
}

#Preview {
    ContentView()
        .environmentObject(LanguageManager.shared)
}

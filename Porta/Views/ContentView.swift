import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject var portDetector = PortDetector()
    @StateObject private var settings = PortSettings.shared
    @State private var showingSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Porta")
                    .font(.headline)
                Spacer()
                Button(action: { portDetector.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh port list")
            }
            .padding(.bottom, 8)

            if let detectionError = portDetector.detectionError {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Could not detect ports")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text(detectionError.userMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
            } else if portDetector.ports.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(emptyStateTitle)
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(emptyStateDescription)
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
                .help("Settings")
                Spacer()
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Image(systemName: "power")
                }
                .keyboardShortcut("q", modifiers: .command)
                .help("Quit Porta")
            }
            .padding(.top, 8)
        }
        .padding(12)
        .frame(minWidth: 320)
        .onAppear {
            portDetector.startMonitoring()
        }
        .onChange(of: showingSettings) { isPresented in
            if !isPresented {
                portDetector.refresh()
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(settings: settings)
        }
        .alert(
            "Could Not Kill Process",
            isPresented: Binding(
                get: { portDetector.lastKillError != nil },
                set: { if !$0 { portDetector.lastKillError = nil } }
            )
        ) {
            Button("OK") { portDetector.lastKillError = nil }
        } message: {
            Text(portDetector.lastKillError?.userMessage ?? "")
        }
    }

    private var emptyStateTitle: String {
        settings.activePorts.isEmpty
            ? "No ports are being monitored"
            : "No matching ports found"
    }

    private var emptyStateDescription: String {
        settings.activePorts.isEmpty
            ? "Enable at least one preset or add custom ports in Settings to start monitoring."
            : "No open LISTEN ports match your active filters. Try refreshing or updating your settings."
    }

    private var portListHeight: CGFloat {
        min(CGFloat(portDetector.ports.count) * 66, 300)
    }
}

struct PortRowView: View {
    let port: OpenPort
    let onKill: () -> Void
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
                .help("Open Activity Monitor — \"\(port.processName)\" copied, press ⌘F and paste to find it")

                Button(action: { showConfirmation = true }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .help("Kill process")
                .buttonStyle(.plain)
                .confirmationDialog(
                    "Kill Process?",
                    isPresented: $showConfirmation
                ) {
                    Button("Kill", role: .destructive) { onKill() }
                } message: {
                    Text(verbatim: "Terminate \(port.processName) (PID \(port.pid)) on port \(port.number)?")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minHeight: 64, alignment: .center)
    }

    private var scopeBadge: some View {
        let isPublic = !port.isLocalhostOnly
        return Text(isPublic ? "public" : "local")
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isPublic ? Color.orange.opacity(0.15) : Color.secondary.opacity(0.12))
            .foregroundColor(isPublic ? .orange : .secondary)
            .clipShape(Capsule())
            .help(isPublic
                ? "Bound to all interfaces (0.0.0.0) — other machines on your network can connect"
                : "Bound to localhost — accessible from this machine only"
            )
    }
}

#Preview {
    ContentView()
}

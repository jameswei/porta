import SwiftUI

struct ContentView: View {
    @StateObject var portDetector = PortDetector()
    @StateObject private var settings = PortSettings.shared
    @State private var showingSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Open Ports")
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
                List(portDetector.ports, id: \.self) { port in
                    PortRowView(port: port, onKill: {
                        portDetector.killPort(port)
                    })
                }
                .frame(maxWidth: 400, maxHeight: 300)
            }

            Divider()

            HStack(spacing: 8) {
                Button("Settings") {
                    showingSettings = true
                }
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
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
}

struct PortRowView: View {
    let port: OpenPort
    let onKill: () -> Void
    @State private var showConfirmation = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Port \(port.number)")
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
                Text("PID: \(port.pid) • \(port.processName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(port.networkProtocol) \(port.addressFamily) • \(port.listenAddress)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("Listening on \(port.listeningAddressLabel)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: { showConfirmation = true }) {
                Image(systemName: "xmark.circle.fill")
            }
            .help("Kill process")
            .confirmationDialog(
                "Kill Process?",
                isPresented: $showConfirmation
            ) {
                Button("Kill", role: .destructive) {
                    onKill()
                }
            } message: {
                Text("Terminate process \(port.pid) on port \(port.number)?")
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}

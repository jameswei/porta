import SwiftUI

struct ContentView: View {
    @StateObject var portDetector = PortDetector()

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
                Text("No open ports detected")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .padding(12)
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
                    // TODO: Open settings window
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
        .frame(minWidth: 300)
        .onAppear {
            portDetector.startMonitoring()
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

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
            
            if portDetector.ports.isEmpty {
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

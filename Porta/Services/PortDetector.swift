import Foundation
import Combine

class PortDetector: ObservableObject {
    @Published var ports: [OpenPort] = []
    
    private var monitoringTimer: Timer?
    private let refreshInterval: TimeInterval = 5.0
    
    func startMonitoring() {
        refresh()
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }
    
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    func refresh() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let detectedPorts = self?.detectOpenPorts() ?? []
            DispatchQueue.main.async {
                self?.ports = detectedPorts.sorted { $0.number < $1.number }
            }
        }
    }
    
    func killPort(_ port: OpenPort) {
        let process = Process()
        process.launchPath = "/bin/kill"
        process.arguments = ["-9", "\(port.pid)"]
        
        do {
            try process.run()
            process.waitUntilExit()
            
            // Refresh after killing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.refresh()
            }
        } catch {
            print("Error killing process \(port.pid): \(error)")
        }
    }
    
    private func detectOpenPorts() -> [OpenPort] {
        let process = Process()
        process.launchPath = "/usr/sbin/lsof"
        process.arguments = ["-i", "-P", "-n"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }
            
            return parseLsofOutput(output)
        } catch {
            print("Error running lsof: \(error)")
            return []
        }
    }
    
    private func parseLsofOutput(_ output: String) -> [OpenPort] {
        var detectedPorts: [OpenPort] = []
        let lines = output.components(separatedBy: .newlines).dropFirst() // Skip header
        
        for line in lines {
            let components = line.split(separator: " ").filter { !$0.isEmpty }
            
            guard components.count >= 9 else { continue }
            
            let processName = String(components[0])
            guard let pid = Int(components[1]) else { continue }
            
            // Look for port in format like "*:3000 (LISTEN)" or "127.0.0.1:3000"
            let addressInfo = String(components[8])
            
            if let portNumber = extractPortNumber(from: addressInfo),
               PortConfig.allPorts.contains(portNumber) {
                let port = OpenPort(number: portNumber, pid: pid, processName: processName)
                
                // Avoid duplicates
                if !detectedPorts.contains(where: { $0.number == portNumber && $0.pid == pid }) {
                    detectedPorts.append(port)
                }
            }
        }
        
        return detectedPorts
    }
    
    private func extractPortNumber(from addressInfo: String) -> Int? {
        // Handle formats like "*:3000 (LISTEN)" or "127.0.0.1:3000"
        let parts = addressInfo.split(separator: ":")
        if parts.count >= 2 {
            let portStr = String(parts.last ?? "").split(separator: " ").first ?? ""
            return Int(portStr)
        }
        return nil
    }
    
    deinit {
        stopMonitoring()
    }
}

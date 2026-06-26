import Foundation
import Combine

// MARK: - OpenPort

struct OpenPort: Hashable, Identifiable {
    let id = UUID()
    let number: Int
    let pid: Int
    let processName: String
    let listenAddress: String  // e.g. "0.0.0.0", "127.0.0.1", "*"
    let addressFamily: String  // e.g. "IPv4", "IPv6"
    let networkProtocol: String  // e.g. "TCP"

    var isLocalhostOnly: Bool {
        listenAddress == "127.0.0.1" || listenAddress == "::1"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(number)
        hasher.combine(pid)
        hasher.combine(listenAddress)
        hasher.combine(addressFamily)
        hasher.combine(networkProtocol)
    }

    static func == (lhs: OpenPort, rhs: OpenPort) -> Bool {
        lhs.number == rhs.number &&
        lhs.pid == rhs.pid &&
        lhs.listenAddress == rhs.listenAddress &&
        lhs.addressFamily == rhs.addressFamily &&
        lhs.networkProtocol == rhs.networkProtocol
    }
}

// MARK: - KillResult

enum KillResult {
    case permissionDenied
    case processNotFound
    case portNoLongerOwned
    case ownershipVerificationFailed(String)
    case signalFailed(String)
    case stillAliveAfterKill

    var userMessage: String {
        switch self {
        case .permissionDenied:
            return "Permission denied. Porta may need elevated privileges to kill this process."
        case .processNotFound:
            return "The process was already gone."
        case .portNoLongerOwned:
            return "This process no longer owns the port. It may have already exited."
        case .ownershipVerificationFailed(let detail):
            return "Could not verify that this process still owns the port. \(detail)"
        case .signalFailed(let detail):
            return "Could not signal the process. \(detail)"
        case .stillAliveAfterKill:
            return "Process survived SIGKILL and may require manual intervention."
        }
    }
}

// MARK: - DetectionError

enum DetectionError: Error {
    case launchFailed(String)
    case lsofFailed(String)
    case unreadableOutput

    var userMessage: String {
        switch self {
        case .launchFailed(let detail):
            return "Could not run lsof. \(detail)"
        case .lsofFailed(let detail):
            return "lsof failed while detecting listening ports. \(detail)"
        case .unreadableOutput:
            return "Could not read lsof output."
        }
    }
}

// MARK: - Preset Definitions

struct PortPresetGroup {
    let key: String
    let label: String
    let ports: Set<Int>
}

extension PortPresetGroup {
    static let all: [PortPresetGroup] = [
        PortPresetGroup(key: "node",     label: "Node.js / npm",  ports: Set(3000...3010).union(Set(4000...4001)).union([5173, 5174, 8080, 8081])),
        PortPresetGroup(key: "vite",     label: "Vite / Webpack", ports: Set(5173...5180).union(Set(8000...8010))),
        PortPresetGroup(key: "python",   label: "Python",         ports: Set([5000, 5001, 8000, 8001, 8888, 8889])),
        PortPresetGroup(key: "ruby",     label: "Ruby / Rails",   ports: Set([3000, 3001, 4567])),
        PortPresetGroup(key: "go",       label: "Go",             ports: Set([8080, 8081, 9090, 9091])),
        PortPresetGroup(key: "java",     label: "Java / Spring",  ports: Set([8080, 8443, 9090])),
        PortPresetGroup(key: "postgres", label: "PostgreSQL",     ports: Set([5432])),
        PortPresetGroup(key: "mysql",    label: "MySQL",          ports: Set([3306])),
        PortPresetGroup(key: "redis",    label: "Redis",          ports: Set([6379])),
        PortPresetGroup(key: "mongodb",  label: "MongoDB",        ports: Set([27017])),
        PortPresetGroup(key: "misc",     label: "Common Dev",     ports: Set([1234, 4000, 4001, 9000, 9001, 9229])),
    ]
}

// MARK: - PortSettings

class PortSettings: ObservableObject {
    static let shared = PortSettings()

    private let defaults = UserDefaults.standard

    @Published var enabledPresetKeys: Set<String> {
        didSet { save() }
    }

    // User-added custom ports as free-form input (e.g. "4200, 9000-9010")
    @Published var customPortsInput: String {
        didSet { save() }
    }

    private init() {
        if let saved = defaults.stringArray(forKey: "enabledPresetKeys") {
            enabledPresetKeys = Set(saved)
        } else {
            enabledPresetKeys = Set(PortPresetGroup.all.map(\.key))
        }
        customPortsInput = defaults.string(forKey: "customPortsInput") ?? ""
    }

    private func save() {
        defaults.set(Array(enabledPresetKeys), forKey: "enabledPresetKeys")
        defaults.set(customPortsInput, forKey: "customPortsInput")
    }

    var activePorts: Set<Int> {
        var ports = Set<Int>()
        for group in PortPresetGroup.all where enabledPresetKeys.contains(group.key) {
            ports.formUnion(group.ports)
        }
        parsedCustomPorts.forEach { ports.insert($0) }
        return ports
    }

    // Parses comma-separated port numbers and ranges (e.g. "4200, 9000-9010").
    // Invalid entries are filtered out from active port usage and surfaced in the
    // Settings UI as validation notes (without changing persistence behavior).
    var parsedCustomPorts: [Int] {
        parseCustomPorts(from: customPortsInput).validPorts
    }

    var customPortsValidationMessage: String? {
        let issues = parseCustomPorts(from: customPortsInput).invalidTokens
        guard !issues.isEmpty else { return nil }

        if issues.count == 1 {
            return "Invalid custom port entry: \(issues[0])"
        }

        return "Invalid custom port entries: \(issues.joined(separator: ", "))"
    }

    private func parseCustomPorts(from text: String) -> (validPorts: [Int], invalidTokens: [String]) {
        var validPorts: [Int] = []
        var invalidTokens: [String] = []

        for token in text.split(separator: ",") {
            let trimmed = token.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                continue
            }

            if let single = Int(trimmed), (1...65535).contains(single) {
                validPorts.append(single)
                continue
            }

            let parts = trimmed.split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2,
               let lo = Int(parts[0]),
               let hi = Int(parts[1]),
               lo <= hi,
               (1...65535).contains(lo),
               (1...65535).contains(hi),
               (hi - lo) <= 1000 {
                validPorts.append(contentsOf: lo...hi)
                continue
            }

            invalidTokens.append(String(trimmed))
        }

        return (validPorts, invalidTokens)
    }
}

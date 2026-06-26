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
    var startTime: Date? = nil

    var isLocalhostOnly: Bool {
        listenAddresses.allSatisfy { $0 == "127.0.0.1" || $0 == "::1" }
    }

    private var listenAddresses: [String] {
        listenAddress
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
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

private extension String {
    var formattedListenAddress: String {
        contains(":") ? "[\(self)]" : self
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

    var portsLabel: String {
        guard !ports.isEmpty else { return "" }
        let sorted = ports.sorted()
        var ranges: [(Int, Int)] = []
        var start = sorted[0], end = sorted[0]
        for port in sorted.dropFirst() {
            if port == end + 1 {
                end = port
            } else {
                ranges.append((start, end))
                start = port; end = port
            }
        }
        ranges.append((start, end))
        return ranges.map { lo, hi in lo == hi ? "\(lo)" : "\(lo)–\(hi)" }.joined(separator: ", ")
    }
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
    static let allowedRefreshIntervals = [1, 3, 5, 10, 30, 60]

    private let defaults = UserDefaults.standard

    @Published var enabledPresetKeys: Set<String> {
        didSet { save() }
    }

    // User-added custom ports as free-form input (e.g. "4200, 9000-9010")
    @Published var customPortsInput: String {
        didSet { save() }
    }

    @Published var refreshIntervalSeconds: Int {
        didSet { save() }
    }

    private init() {
        if let saved = defaults.stringArray(forKey: "enabledPresetKeys") {
            enabledPresetKeys = Set(saved)
        } else {
            enabledPresetKeys = Set(PortPresetGroup.all.map(\.key))
        }
        customPortsInput = defaults.string(forKey: "customPortsInput") ?? ""
        let savedInterval = defaults.object(forKey: "refreshIntervalSeconds") as? Int ?? 5
        refreshIntervalSeconds = Self.allowedRefreshIntervals.min(by: { abs($0 - savedInterval) < abs($1 - savedInterval) }) ?? 5
    }

    private func save() {
        defaults.set(Array(enabledPresetKeys), forKey: "enabledPresetKeys")
        defaults.set(customPortsInput, forKey: "customPortsInput")
        defaults.set(refreshIntervalSeconds, forKey: "refreshIntervalSeconds")
    }

    var activePorts: Set<Int> {
        var ports = Set<Int>()
        for group in PortPresetGroup.all where enabledPresetKeys.contains(group.key) {
            ports.formUnion(group.ports)
        }
        parsedCustomPorts.forEach { ports.insert($0) }
        return ports
    }

    var parsedCustomPorts: [Int] {
        parseCustomPorts(from: customPortsInput).validPorts
    }

    var customPortEntries: [String] {
        customPortsInput
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    func isValidEntry(_ text: String) -> Bool {
        let result = parseCustomPorts(from: text)
        return result.invalidTokens.isEmpty && !result.validPorts.isEmpty
    }

    func addCustomEntry(_ text: String) {
        let incoming = text
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { normalizeEntry($0) }
        var entries = customPortEntries
        for token in incoming where !entries.contains(token) {
            entries.append(token)
        }
        customPortsInput = entries.joined(separator: ", ")
    }

    func removeCustomEntry(at index: Int) {
        var entries = customPortEntries
        guard entries.indices.contains(index) else { return }
        entries.remove(at: index)
        customPortsInput = entries.joined(separator: ", ")
    }

    private func normalizeEntry(_ text: String) -> String {
        let parts = text.split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.count == 2, parts[0] == parts[1] { return String(parts[0]) }
        return text
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

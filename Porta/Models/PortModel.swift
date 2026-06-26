import Foundation

struct OpenPort: Hashable, Identifiable {
    let id = UUID()
    let number: Int
    let pid: Int
    let processName: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(number)
        hasher.combine(pid)
    }
    
    static func == (lhs: OpenPort, rhs: OpenPort) -> Bool {
        lhs.number == rhs.number && lhs.pid == rhs.pid
    }
}

struct PortConfig {
    // Default port ranges for common dev services
    static let presets: [String: [Int]] = [
        "HTTP": [80, 8080, 3000],
        "Node.js": Array(3000...3100) + Array(8000...8100),
        "Python": [5000, 8000, 8888],
        "PostgreSQL": [5432],
        "Redis": [6379],
        "MongoDB": [27017],
    ]
    
    // Flatten all port ranges into a single set for quick lookup
    static var allPorts: Set<Int> {
        Set(presets.values.flatMap { $0 })
    }
}

import Foundation
import Combine
import Darwin

class PortDetector: ObservableObject {
    @Published var ports: [OpenPort] = []
    @Published var detectionError: DetectionError?
    @Published var lastKillError: KillResult?

    private let settings: PortSettings
    private var isMonitoring = false
    private var monitoringTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []

    init(settings: PortSettings = .shared) {
        self.settings = settings
        settings.$refreshIntervalSeconds
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.restartMonitoringTimer()
            }
            .store(in: &cancellables)
    }

    func startMonitoring() {
        isMonitoring = true
        refresh()
        startMonitoringTimer()
    }

    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        isMonitoring = false
    }

    private func startMonitoringTimer() {
        monitoringTimer?.invalidate()
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(settings.refreshIntervalSeconds), repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    private func restartMonitoringTimer() {
        guard isMonitoring else { return }
        monitoringTimer?.invalidate()
        startMonitoringTimer()
    }

    func refresh() {
        let filter = settings.activePorts
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = self?.detectOpenPorts(filter: filter) ?? .success([])
            DispatchQueue.main.async {
                switch result {
                case .success(let detected):
                    self?.detectionError = nil
                    self?.ports = detected.sorted { $0.number < $1.number }
                case .failure(let error):
                    self?.detectionError = error
                    self?.ports = []
                }
            }
        }
    }

    func killPort(_ port: OpenPort) {
        lastKillError = nil
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            let ownerCheck = self.isPortStillOwned(port)
            guard case .success(let isOwned) = ownerCheck else {
                DispatchQueue.main.async {
                    if case .failure(let error) = ownerCheck {
                        self.lastKillError = .ownershipVerificationFailed(error.userMessage)
                    }
                    self.refresh()
                }
                return
            }

            // Pre-kill: verify this exact PID still owns this port to guard against PID reuse
            guard isOwned else {
                DispatchQueue.main.async {
                    self.lastKillError = .portNoLongerOwned
                    self.refresh()
                }
                return
            }

            // SIGTERM — attempt graceful shutdown
            if Darwin.kill(Int32(port.pid), SIGTERM) != 0 {
                let result = self.killResult(forErrno: errno)
                DispatchQueue.main.async {
                    self.lastKillError = result
                    self.refresh()
                }
                return
            }

            // Wait for graceful exit
            Thread.sleep(forTimeInterval: 2.0)

            // SIGKILL — escalate only if process is still alive AND still owns the port
            if Darwin.kill(Int32(port.pid), 0) == 0 {
                let postTermOwnerCheck = self.isPortStillOwned(port)
                guard case .success(let isStillOwned) = postTermOwnerCheck else {
                    DispatchQueue.main.async {
                        if case .failure(let error) = postTermOwnerCheck {
                            self.lastKillError = .ownershipVerificationFailed(error.userMessage)
                        }
                        self.refresh()
                    }
                    return
                }

                guard isStillOwned else {
                    self.scheduleRefresh()
                    return
                }

                if Darwin.kill(Int32(port.pid), SIGKILL) != 0 {
                    let result = self.killResult(forErrno: errno)
                    DispatchQueue.main.async {
                        self.lastKillError = result
                        self.refresh()
                    }
                    return
                }
                Thread.sleep(forTimeInterval: 0.5)

                if Darwin.kill(Int32(port.pid), 0) == 0 {
                    let postKillOwnerCheck = self.isPortStillOwned(port)
                    switch postKillOwnerCheck {
                    case .success(let isStillOwned):
                        if isStillOwned {
                            DispatchQueue.main.async { self.lastKillError = .stillAliveAfterKill }
                            self.scheduleRefresh()
                            return
                        }
                    case .failure(let error):
                        DispatchQueue.main.async { self.lastKillError = .ownershipVerificationFailed(error.userMessage) }
                        self.scheduleRefresh()
                        return
                    }
                }
            }

            self.scheduleRefresh()
        }
    }

    // MARK: - Private

    private struct LsofResult {
        let output: String
        let errorOutput: String
        let exitStatus: Int32
    }

    /// Re-reads lsof before signaling to verify the selected listener still exists.
    private func isPortStillOwned(_ port: OpenPort) -> Result<Bool, DetectionError> {
        let result = runLsof(arguments: ["-iTCP:\(port.number)", "-sTCP:LISTEN", "-P", "-n", "-F", "pcPtn"])
        switch result {
        case .failure(let error):
            return .failure(error)
        case .success(let lsofResult):
            if lsofResult.exitStatus != 0, !lsofResult.errorOutput.isEmpty {
                return .failure(.lsofFailed(lsofResult.errorOutput))
            }
            let listeners = parseLsofMachineOutput(lsofResult.output, filter: [port.number])
            return .success(listeners.contains { $0.number == port.number && $0.pid == port.pid })
        }
    }

    private func detectOpenPorts(filter: Set<Int>) -> Result<[OpenPort], DetectionError> {
        // -F pcPtn: machine-readable output (p=pid, c=command, P=protocol, t=type, n=name/address)
        // lsof always emits 'f<fd>' as a per-file separator in -F mode
        let result = runLsof(arguments: ["-iTCP", "-sTCP:LISTEN", "-P", "-n", "-F", "pcPtn"])
        guard case .success(let lsofResult) = result else {
            if case .failure(let error) = result {
                return .failure(error)
            }
            return .success([])
        }

        if lsofResult.exitStatus != 0, !lsofResult.errorOutput.isEmpty {
            return .failure(.lsofFailed(lsofResult.errorOutput))
        }

        let coalesced = coalesceOpenPorts(parseLsofMachineOutput(lsofResult.output, filter: filter))
        return .success(coalesced.map { port in
            var p = port
            p.startTime = processStartTime(pid: port.pid)
            return p
        })
    }

    private func runLsof(arguments: [String]) -> Result<LsofResult, DetectionError> {
        let process = Process()
        process.launchPath = "/usr/sbin/lsof"
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return .failure(.launchFailed(error.localizedDescription))
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: stdoutData, encoding: .utf8),
              let errorOutput = String(data: stderrData, encoding: .utf8) else {
            return .failure(.unreadableOutput)
        }

        return .success(LsofResult(
            output: output,
            errorOutput: errorOutput.trimmingCharacters(in: .whitespacesAndNewlines),
            exitStatus: process.terminationStatus
        ))
    }

    /// Parses lsof -F pcPtn output. Each line starts with a type character:
    ///   p<pid>        – new process block
    ///   c<cmd>        – command / process name
    ///   P<protocol>   – protocol name, e.g. TCP
    ///   t<type>       – file type, e.g. IPv4 or IPv6
    ///   f<fd>         – file-descriptor separator (always emitted, ignored here)
    ///   n<addr:port>  – network name field → emit OpenPort if port is in filter
    func parseLsofMachineOutput(_ output: String, filter: Set<Int>) -> [OpenPort] {
        var result: [OpenPort] = []
        var currentPID = 0
        var currentCommand = ""
        var currentProtocol = ""
        var currentAddressFamily = ""

        for line in output.components(separatedBy: .newlines) {
            guard let typeChar = line.first else { continue }
            let value = String(line.dropFirst())

            switch typeChar {
            case "p":
                currentPID = Int(value) ?? 0
                currentCommand = ""
                currentProtocol = ""
                currentAddressFamily = ""
            case "c":
                currentCommand = value
            case "P":
                currentProtocol = value
            case "t":
                currentAddressFamily = value
            case "n":
                guard currentPID > 0,
                      let (address, port) = parseNameField(value),
                      filter.contains(port),
                      !result.contains(where: {
                          $0.number == port &&
                          $0.pid == currentPID &&
                          $0.listenAddress == address &&
                          $0.addressFamily == currentAddressFamily &&
                          $0.networkProtocol == currentProtocol
                      })
                else { continue }
                result.append(OpenPort(
                    number: port,
                    pid: currentPID,
                    processName: currentCommand,
                    listenAddress: address,
                    addressFamily: currentAddressFamily,
                    networkProtocol: currentProtocol
                ))
            default:
                break
            }
        }

        return result
    }

    func coalesceOpenPorts(_ ports: [OpenPort]) -> [OpenPort] {
        var coalesced: [OpenPort] = []

        for port in ports {
            if let index = coalesced.firstIndex(where: {
                $0.number == port.number &&
                $0.pid == port.pid &&
                $0.processName == port.processName &&
                $0.networkProtocol == port.networkProtocol
            }) {
                let existing = coalesced[index]
                let addresses = uniqueSorted(existing.listenAddress, port.listenAddress)
                let families = uniqueSorted(existing.addressFamily, port.addressFamily, separator: "/")
                coalesced[index] = OpenPort(
                    number: existing.number,
                    pid: existing.pid,
                    processName: existing.processName,
                    listenAddress: addresses.joined(separator: ", "),
                    addressFamily: families.joined(separator: "/"),
                    networkProtocol: existing.networkProtocol
                )
            } else {
                coalesced.append(port)
            }
        }

        return coalesced
    }

    private func uniqueSorted(_ first: String, _ second: String, separator: String = ",") -> [String] {
        Array(
            Set(
                [first, second]
                    .flatMap { $0.split(separator: Character(separator)).map(String.init) }
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            )
        )
        .sorted()
    }

    /// Parses an lsof NAME field into (address, port).
    /// Handles: "*:3000"  "127.0.0.1:8000"  "[::1]:8080"
    func parseNameField(_ name: String) -> (address: String, port: Int)? {
        // IPv6: "[::1]:8080"
        if name.hasPrefix("[") {
            guard let closeBracket = name.firstIndex(of: "]") else { return nil }
            let address = String(name[name.index(after: name.startIndex)..<closeBracket])
            let remainder = name[name.index(after: closeBracket)...]
            guard remainder.hasPrefix(":"), let port = Int(remainder.dropFirst()) else { return nil }
            return (address, port)
        }
        // IPv4 / wildcard: split on the last colon
        guard let lastColon = name.lastIndex(of: ":") else { return nil }
        let address = String(name[name.startIndex..<lastColon])
        let portStr = String(name[name.index(after: lastColon)...])
        guard let port = Int(portStr) else { return nil }
        return (address, port)
    }

    private func processStartTime(pid: Int) -> Date? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, Int32(pid)]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0, size > 0 else { return nil }
        let tv = info.kp_proc.p_starttime
        return Date(timeIntervalSince1970: Double(tv.tv_sec) + Double(tv.tv_usec) / 1_000_000)
    }

    private func scheduleRefresh() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refresh()
        }
    }

    private func killResult(forErrno errnoCode: Int32) -> KillResult {
        switch errnoCode {
        case EPERM:
            return .permissionDenied
        case ESRCH:
            return .processNotFound
        default:
            return .signalFailed(String(cString: strerror(errnoCode)))
        }
    }

    deinit {
        stopMonitoring()
    }
}

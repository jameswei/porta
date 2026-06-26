import XCTest
@testable import Porta

final class PortaTests: XCTestCase {

    // MARK: - setUp / tearDown

    override func setUp() {
        super.setUp()
        // Reset custom ports before each test that touches them
        PortSettings.shared.customPortsInput = ""
    }

    // MARK: - PortSettings.isValidEntry

    func testIsValidEntry_validSinglePorts() {
        let s = PortSettings.shared
        XCTAssertTrue(s.isValidEntry("1"))
        XCTAssertTrue(s.isValidEntry("80"))
        XCTAssertTrue(s.isValidEntry("3000"))
        XCTAssertTrue(s.isValidEntry("65535"))
    }

    func testIsValidEntry_validRanges() {
        let s = PortSettings.shared
        XCTAssertTrue(s.isValidEntry("8080-8180"))   // short range
        XCTAssertTrue(s.isValidEntry("9300-9300"))   // degenerate range (lo == hi)
        XCTAssertTrue(s.isValidEntry("1000-2000"))   // exactly at 1000-port limit (hi-lo == 1000)
    }

    func testIsValidEntry_invalid() {
        let s = PortSettings.shared
        XCTAssertFalse(s.isValidEntry(""))           // empty
        XCTAssertFalse(s.isValidEntry("0"))          // below minimum
        XCTAssertFalse(s.isValidEntry("65536"))      // above maximum
        XCTAssertFalse(s.isValidEntry("abc"))        // non-numeric
        XCTAssertFalse(s.isValidEntry("80-79"))      // lo > hi
        XCTAssertFalse(s.isValidEntry("80-"))        // missing hi
        XCTAssertFalse(s.isValidEntry("-80"))        // missing lo
        XCTAssertFalse(s.isValidEntry("8080-9090"))  // hi-lo = 1010, exceeds 1000-port limit
    }

    // MARK: - PortSettings.addCustomEntry / customPortEntries

    func testAddCustomEntry_singlePort() {
        PortSettings.shared.addCustomEntry("9000")
        XCTAssertEqual(PortSettings.shared.customPortEntries, ["9000"])
    }

    func testAddCustomEntry_deduplication() {
        PortSettings.shared.addCustomEntry("9000")
        PortSettings.shared.addCustomEntry("9000")
        XCTAssertEqual(PortSettings.shared.customPortEntries, ["9000"])
    }

    func testAddCustomEntry_commaSeparated() {
        PortSettings.shared.addCustomEntry("9000, 9001")
        XCTAssertEqual(PortSettings.shared.customPortEntries, ["9000", "9001"])
    }

    func testAddCustomEntry_normalizesDegenerate() {
        PortSettings.shared.addCustomEntry("9300-9300")
        XCTAssertEqual(PortSettings.shared.customPortEntries, ["9300"])
    }

    func testAddCustomEntry_mixedRangeAndSingle() {
        PortSettings.shared.addCustomEntry("9000-9001, 9300-9300")
        XCTAssertEqual(PortSettings.shared.customPortEntries, ["9000-9001", "9300"])
    }

    // MARK: - PortSettings.removeCustomEntry

    func testRemoveCustomEntry_middleElement() {
        PortSettings.shared.addCustomEntry("9000, 9001, 9002")
        PortSettings.shared.removeCustomEntry(at: 1)
        XCTAssertEqual(PortSettings.shared.customPortEntries, ["9000", "9002"])
    }

    func testRemoveCustomEntry_outOfBoundsIsNoop() {
        PortSettings.shared.addCustomEntry("9000")
        PortSettings.shared.removeCustomEntry(at: 99)
        XCTAssertEqual(PortSettings.shared.customPortEntries, ["9000"])
    }

    // MARK: - PortPresetGroup.portsLabel

    func testPortsLabel_singlePort() {
        let g = PortPresetGroup(key: "t", label: "T", ports: [5432])
        XCTAssertEqual(g.portsLabel, "5432")
    }

    func testPortsLabel_consecutiveRange() {
        let g = PortPresetGroup(key: "t", label: "T", ports: Set(3000...3003))
        XCTAssertEqual(g.portsLabel, "3000\u{2013}3003")   // en-dash
    }

    func testPortsLabel_nonConsecutive() {
        let g = PortPresetGroup(key: "t", label: "T", ports: [3000, 5432])
        XCTAssertEqual(g.portsLabel, "3000, 5432")
    }

    func testPortsLabel_empty() {
        let g = PortPresetGroup(key: "t", label: "T", ports: [])
        XCTAssertEqual(g.portsLabel, "")
    }

    // MARK: - PortDetector.parseNameField

    func testParseNameField_wildcard() {
        let d = PortDetector()
        let r = d.parseNameField("*:3000")
        XCTAssertEqual(r?.address, "*")
        XCTAssertEqual(r?.port, 3000)
    }

    func testParseNameField_ipv4() {
        let d = PortDetector()
        let r = d.parseNameField("127.0.0.1:8080")
        XCTAssertEqual(r?.address, "127.0.0.1")
        XCTAssertEqual(r?.port, 8080)
    }

    func testParseNameField_ipv6() {
        let d = PortDetector()
        let r = d.parseNameField("[::1]:8080")
        XCTAssertEqual(r?.address, "::1")
        XCTAssertEqual(r?.port, 8080)
    }

    func testParseNameField_invalid() {
        let d = PortDetector()
        XCTAssertNil(d.parseNameField("notaport"))
        XCTAssertNil(d.parseNameField(""))
        XCTAssertNil(d.parseNameField("[noclose:8080"))
    }

    // MARK: - PortDetector.parseLsofMachineOutput

    func testParseLsofMachineOutput_basicEntry() {
        let d = PortDetector()
        let output = "p1234\ncnode\nPTCP\ntIPv4\nf3\nn*:3000\n"
        let ports = d.parseLsofMachineOutput(output, filter: [3000])
        XCTAssertEqual(ports.count, 1)
        XCTAssertEqual(ports[0].number, 3000)
        XCTAssertEqual(ports[0].pid, 1234)
        XCTAssertEqual(ports[0].processName, "node")
        XCTAssertEqual(ports[0].listenAddress, "*")
        XCTAssertEqual(ports[0].addressFamily, "IPv4")
    }

    func testParseLsofMachineOutput_portNotInFilter() {
        let d = PortDetector()
        let output = "p1234\ncnode\nPTCP\ntIPv4\nf3\nn*:9999\n"
        XCTAssertTrue(d.parseLsofMachineOutput(output, filter: [3000]).isEmpty)
    }

    func testParseLsofMachineOutput_multipleProcesses() {
        let d = PortDetector()
        let output = """
        p1234
        cnode
        PTCP
        tIPv4
        f3
        n*:3000
        p5678
        cpython
        PTCP
        tIPv4
        f4
        n127.0.0.1:8000
        """
        let ports = d.parseLsofMachineOutput(output, filter: [3000, 8000])
        XCTAssertEqual(ports.count, 2)
        XCTAssertTrue(ports.contains { $0.number == 3000 && $0.pid == 1234 })
        XCTAssertTrue(ports.contains { $0.number == 8000 && $0.pid == 5678 })
    }

    // MARK: - PortDetector.coalesceOpenPorts

    func testCoalesceOpenPorts_mergesIPv4AndIPv6() {
        let d = PortDetector()
        let ports = [
            OpenPort(number: 3000, pid: 1234, processName: "node", listenAddress: "*",  addressFamily: "IPv4", networkProtocol: "TCP"),
            OpenPort(number: 3000, pid: 1234, processName: "node", listenAddress: "*",  addressFamily: "IPv6", networkProtocol: "TCP"),
        ]
        let result = d.coalesceOpenPorts(ports)
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0].addressFamily.contains("IPv4"))
        XCTAssertTrue(result[0].addressFamily.contains("IPv6"))
    }

    func testCoalesceOpenPorts_keepsDifferentPorts() {
        let d = PortDetector()
        let ports = [
            OpenPort(number: 3000, pid: 1234, processName: "node", listenAddress: "*", addressFamily: "IPv4", networkProtocol: "TCP"),
            OpenPort(number: 4000, pid: 1234, processName: "node", listenAddress: "*", addressFamily: "IPv4", networkProtocol: "TCP"),
        ]
        XCTAssertEqual(d.coalesceOpenPorts(ports).count, 2)
    }

    // MARK: - OpenPort.isLocalhostOnly

    func testIsLocalhostOnly_localhost127() {
        let p = OpenPort(number: 3000, pid: 1, processName: "x", listenAddress: "127.0.0.1", addressFamily: "IPv4", networkProtocol: "TCP")
        XCTAssertTrue(p.isLocalhostOnly)
    }

    func testIsLocalhostOnly_localhostIPv6() {
        let p = OpenPort(number: 3000, pid: 1, processName: "x", listenAddress: "::1", addressFamily: "IPv6", networkProtocol: "TCP")
        XCTAssertTrue(p.isLocalhostOnly)
    }

    func testIsLocalhostOnly_wildcard() {
        let p = OpenPort(number: 3000, pid: 1, processName: "x", listenAddress: "*", addressFamily: "IPv4", networkProtocol: "TCP")
        XCTAssertFalse(p.isLocalhostOnly)
    }

    func testIsLocalhostOnly_allInterfaces() {
        let p = OpenPort(number: 3000, pid: 1, processName: "x", listenAddress: "0.0.0.0", addressFamily: "IPv4", networkProtocol: "TCP")
        XCTAssertFalse(p.isLocalhostOnly)
    }

    func testIsLocalhostOnly_coalescedLocalhostAddresses() {
        let d = PortDetector()
        let ports = [
            OpenPort(number: 3000, pid: 1234, processName: "node", listenAddress: "127.0.0.1", addressFamily: "IPv4", networkProtocol: "TCP"),
            OpenPort(number: 3000, pid: 1234, processName: "node", listenAddress: "::1",       addressFamily: "IPv6", networkProtocol: "TCP"),
        ]
        let result = d.coalesceOpenPorts(ports)
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0].isLocalhostOnly)
    }
}

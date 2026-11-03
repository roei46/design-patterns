import Foundation
import Testing
@testable import DesignPatterns

struct PortMetadataFactoryTests {
    let factory = PortMetadataFactory()

    @Test func sameCodeReturnsSameObject() throws {
        let first = try factory.metadata(for: "ILHFA")
        let second = try factory.metadata(for: "ILHFA")

        #expect(first === second)
    }

    @Test func codeIsCleanedUpBeforeLookup() throws {
        let plain = try factory.metadata(for: "ILHFA")
        let lowercase = try factory.metadata(for: "ilhfa")
        let padded = try factory.metadata(for: " ILHFA ")

        #expect(plain === lowercase)
        #expect(plain === padded)
    }

    @Test func differentCodesReturnDifferentObjects() throws {
        let haifa = try factory.metadata(for: "ILHFA")
        let newYork = try factory.metadata(for: "USNYC")

        #expect(haifa !== newYork)
        #expect(haifa.country == "Israel")
        #expect(newYork.country == "United States")
    }

    @Test func eachPortIsCreatedOnlyOnce() throws {
        let codes = ["ILHFA", "USNYC", "NLRTM"]

        for i in 0..<10_000 {
            _ = try factory.metadata(for: codes[i % codes.count])
        }

        #expect(factory.createdCount == 3)
    }

    // Per-rate data stays outside: changing one rate doesn't touch the shared port or other rates.
    @Test func changingRateDoesNotChangeSharedPort() throws {
        let port = try factory.metadata(for: "ILHFA")
        var first = ShippingRate(shipmentID: "S1", priceMinor: 100, timestamp: .now, port: port)
        let second = ShippingRate(shipmentID: "S2", priceMinor: 200, timestamp: .now, port: port)

        first.priceMinor = 999

        #expect(second.priceMinor == 200)
        #expect(first.port === second.port)
        #expect(port.code == "ILHFA")
        #expect(port.country == "Israel")
        #expect(port.timezone == "Asia/Jerusalem")
    }

    @Test func concurrentLookupsCreateOneObject() async throws {
        let factory = self.factory
        let ids = try await withThrowingTaskGroup(of: ObjectIdentifier.self) { group in
            for _ in 0..<100 {
                group.addTask { ObjectIdentifier(try factory.metadata(for: "NLRTM")) }
            }
            var ids = Set<ObjectIdentifier>()
            for try await id in group { ids.insert(id) }
            return ids
        }

        #expect(ids.count == 1)
        #expect(factory.createdCount == 1)
    }

    // Negative: valid format, but not a port we know.
    @Test func unknownPortIsRejected() {
        #expect(throws: PortError.unknownPort("XXXXX")) {
            try factory.metadata(for: "XXXXX")
        }
        #expect(factory.createdCount == 0)
    }

    // Failure: the code itself is invalid.
    @Test(arguments: ["", "AB", "ILHFA1", "IL-FA"])
    func invalidCodeIsRejected(code: String) {
        #expect(throws: PortError.invalidCode(code)) {
            try factory.metadata(for: code)
        }
    }
}

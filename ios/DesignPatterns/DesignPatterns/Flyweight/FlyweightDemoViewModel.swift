import Foundation
import Observation

/// Creates 100,000 rates through the real factory and reports how much is shared.
@Observable @MainActor
final class FlyweightDemoViewModel {
    private(set) var lines: [DemoLineState] = []
    private let factory: PortMetadataFactory

    init(factory: PortMetadataFactory) {
        self.factory = factory
    }

    func run() {
        let codes = ["ILHFA", "USNYC", "NLRTM", "CNSHA"]
        let memoryBefore = MemoryProbe.footprintBytes()
        var rates: [ShippingRate] = []

        do {
            for i in 0..<100_000 {
                let port = try factory.metadata(for: codes[i % codes.count])
                rates.append(ShippingRate(shipmentID: "S\(i)", priceMinor: 10_000 + i, timestamp: .now, port: port))
            }
        } catch {
            lines = [.init(text: "Failed: \(error)", passed: false)]
            return
        }

        let megabytes = Double(MemoryProbe.footprintBytes() - memoryBefore) / 1_000_000
        lines = [
            .init(text: "100,000 rates share \(factory.createdCount) port objects", passed: factory.createdCount == 4),
            .init(text: "Same code → same object", passed: rates[0].port === rates[4].port),
            .init(text: "Memory for 100,000 rates: \(megabytes.formatted(.number.precision(.fractionLength(1)))) MB (illustrative)", passed: true),
        ]
    }
}

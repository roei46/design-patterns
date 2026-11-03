import Foundation
import Synchronization

/// The flyweight: shared, immutable port info. Only the factory can create one.
final class PortMetadata: Sendable {
    let code: String
    let country: String
    let timezone: String

    fileprivate init(code: String, country: String, timezone: String) {
        self.code = code
        self.country = country
        self.timezone = timezone
    }
}

/// Per-rate data. Stays outside the flyweight and only points to the shared port.
struct ShippingRate {
    let shipmentID: String
    var priceMinor: Int
    let timestamp: Date
    let port: PortMetadata
}

enum PortError: Error, Equatable {
    case invalidCode(String)   // not 5 letters
    case unknownPort(String)   // valid format, but not a port we know
}

final class PortMetadataFactory: Sendable {
    private let cache = Mutex<[String: PortMetadata]>([:])

    private static let knownPorts: [String: (country: String, timezone: String)] = [
        "ILHFA": ("Israel", "Asia/Jerusalem"),
        "USNYC": ("United States", "America/New_York"),
        "NLRTM": ("Netherlands", "Europe/Amsterdam"),
        "CNSHA": ("China", "Asia/Shanghai"),
    ]

    /// Allocation count: each cached port was created exactly once.
    var createdCount: Int { cache.withLock { $0.count } }

    func metadata(for code: String) throws(PortError) -> PortMetadata {
        let canonical = code.trimmingCharacters(in: .whitespaces).uppercased()
        guard canonical.count == 5, canonical.allSatisfy({ $0.isASCII && $0.isLetter }) else {
            throw .invalidCode(code)
        }
        guard let info = Self.knownPorts[canonical] else { throw .unknownPort(canonical) }

        return cache.withLock { cache in
            if let existing = cache[canonical] { return existing }   // reuse
            let created = PortMetadata(code: canonical, country: info.country, timezone: info.timezone)
            cache[canonical] = created
            return created
        }
    }
}

import Foundation
import Synchronization
@testable import DesignPatterns

/// Returns chosen JSON (or throws) and records the weight it was asked for.
final class ProviderAClientSpy: ProviderAClientProtocol {
    private let result: Result<Data, any Error>
    private let weights = Mutex<[Double]>([])

    var receivedWeightsKg: [Double] { weights.withLock { $0 } }

    init(json: String) { result = .success(Data(json.utf8)) }
    init(error: any Error) { result = .failure(error) }

    func fetchRate(from origin: String, to destination: String, weightKg: Double) async throws -> Data {
        weights.withLock { $0.append(weightKg) }
        return try result.get()
    }
}

/// Returns chosen JSON (or throws) and records the weight it was asked for.
final class ProviderBClientSpy: ProviderBClientProtocol {
    private let result: Result<Data, any Error>
    private let weights = Mutex<[Int]>([])

    var receivedGrams: [Int] { weights.withLock { $0 } }

    init(json: String) { result = .success(Data(json.utf8)) }
    init(error: any Error) { result = .failure(error) }

    func getQuote(origin: String, destination: String, grams: Int) async throws -> Data {
        weights.withLock { $0.append(grams) }
        return try result.get()
    }
}

/// A provider that returns a fixed result, for testing app code without real adapters.
struct StubShippingProvider: ShippingRateProviderProtocol {
    let result: Result<RateQuote, ShippingError>

    func quote(for request: QuoteRequest) async throws(ShippingError) -> RateQuote {
        try result.get()
    }
}

extension QuoteRequest {
    static let sample = QuoteRequest(origin: "ILHFA", destination: "USNYC", weightGrams: 2_500)
}

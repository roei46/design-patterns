import Foundation
import Observation

/// App code: only knows ShippingRateProviderProtocol, never Provider A or B.
@Observable @MainActor
final class AdapterDemoViewModel {
    private(set) var lines: [DemoLineState] = []
    private let providers: [(name: String, provider: any ShippingRateProviderProtocol)]

    init(providers: [(name: String, provider: any ShippingRateProviderProtocol)]) {
        self.providers = providers
    }

    func run() async {
        let request = QuoteRequest(origin: "ILHFA", destination: "USNYC", weightGrams: 2_500)
        var result: [DemoLineState] = []
        var quotes: [RateQuote] = []

        for (name, provider) in providers {
            do {
                let quote = try await provider.quote(for: request)
                quotes.append(quote)
                result.append(.init(text: "\(name): \(quote.amountMinor) \(quote.currency.rawValue)", passed: true))
            } catch {
                result.append(.init(text: "\(name) failed: \(error)", passed: false))
            }
        }

        if quotes.count == providers.count {
            result.append(.init(text: "All normalized to the same RateQuote",
                                passed: Set(quotes).count == 1))
        }
        lines = result
    }
}

import Foundation
import Testing
@testable import DesignPatterns

struct ProviderAAdapterTests {
    @Test func convertsDollarsToCents() async throws {
        let adapter = ProviderAAdapter(client: ProviderAClientSpy(json: #"{"price":120,"currency":"USD"}"#))

        let quote = try await adapter.quote(for: .sample)

        #expect(quote == RateQuote(amountMinor: 12_000, currency: .usd))
    }

    // The floating-point trap: 19.99 as a Double is 19.989999…, as Decimal it's exact.
    @Test func decimalPriceBecomesExactCents() async throws {
        let adapter = ProviderAAdapter(client: ProviderAClientSpy(json: #"{"price":19.99,"currency":"EUR"}"#))

        let quote = try await adapter.quote(for: .sample)

        #expect(quote == RateQuote(amountMinor: 1_999, currency: .eur))
    }

    @Test func sendsWeightInKilograms() async throws {
        let client = ProviderAClientSpy(json: #"{"price":120,"currency":"USD"}"#)
        let adapter = ProviderAAdapter(client: client)

        _ = try await adapter.quote(for: .sample)   // 2500 g

        #expect(client.receivedWeightsKg == [2.5])
    }

    // Negative: a currency we don't support.
    @Test func invalidCurrencyIsRejected() async {
        let adapter = ProviderAAdapter(client: ProviderAClientSpy(json: #"{"price":120,"currency":"XYZ"}"#))

        await #expect(throws: ShippingError.invalidCurrency("XYZ")) {
            try await adapter.quote(for: .sample)
        }
    }

    // Failure: Provider A's own timeout error becomes our .timeout.
    @Test func timeoutBecomesShippingTimeout() async {
        let adapter = ProviderAAdapter(client: ProviderAClientSpy(error: URLError(.timedOut)))

        await #expect(throws: ShippingError.timeout) {
            try await adapter.quote(for: .sample)
        }
    }

    @Test func otherClientErrorBecomesProviderUnavailable() async {
        let adapter = ProviderAAdapter(client: ProviderAClientSpy(error: URLError(.notConnectedToInternet)))

        await #expect(throws: ShippingError.providerUnavailable) {
            try await adapter.quote(for: .sample)
        }
    }

    @Test(arguments: [
        "not json",
        #"{"currency":"USD"}"#,                  // missing price
        #"{"price":"120","currency":"USD"}"#,    // price is a string
        #"{"price":-5,"currency":"USD"}"#,       // negative price
    ])
    func malformedPayloadIsRejected(json: String) async {
        let adapter = ProviderAAdapter(client: ProviderAClientSpy(json: json))

        await #expect(throws: ShippingError.malformedPayload) {
            try await adapter.quote(for: .sample)
        }
    }
}

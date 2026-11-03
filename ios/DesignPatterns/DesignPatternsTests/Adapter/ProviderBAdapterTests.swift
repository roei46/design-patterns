import Foundation
import Testing
@testable import DesignPatterns

struct ProviderBAdapterTests {
    @Test func minorUnitsAreUsedAsIs() async throws {
        let adapter = ProviderBAdapter(client: ProviderBClientSpy(
            json: #"{"total_amount":12000,"currency_code":"USD","minor_units":true}"#))

        let quote = try await adapter.quote(for: .sample)

        #expect(quote == RateQuote(amountMinor: 12_000, currency: .usd))
    }

    @Test func majorUnitsAreConvertedToCents() async throws {
        let adapter = ProviderBAdapter(client: ProviderBClientSpy(
            json: #"{"total_amount":120,"currency_code":"USD","minor_units":false}"#))

        let quote = try await adapter.quote(for: .sample)

        #expect(quote == RateQuote(amountMinor: 12_000, currency: .usd))
    }

    // The core of the pattern: two different formats, one identical result.
    @Test func sameQuoteAsProviderAForSamePrice() async throws {
        let adapterA = ProviderAAdapter(client: ProviderAClientSpy(json: #"{"price":120,"currency":"USD"}"#))
        let adapterB = ProviderBAdapter(client: ProviderBClientSpy(
            json: #"{"total_amount":12000,"currency_code":"USD","minor_units":true}"#))

        let quoteA = try await adapterA.quote(for: .sample)
        let quoteB = try await adapterB.quote(for: .sample)

        #expect(quoteA == quoteB)
    }

    @Test func sendsWeightInGrams() async throws {
        let client = ProviderBClientSpy(json: #"{"total_amount":12000,"currency_code":"USD","minor_units":true}"#)
        let adapter = ProviderBAdapter(client: client)

        _ = try await adapter.quote(for: .sample)

        #expect(client.receivedGrams == [2_500])
    }

    // Negative: a currency we don't support.
    @Test func invalidCurrencyIsRejected() async {
        let adapter = ProviderBAdapter(client: ProviderBClientSpy(
            json: #"{"total_amount":12000,"currency_code":"XYZ","minor_units":true}"#))

        await #expect(throws: ShippingError.invalidCurrency("XYZ")) {
            try await adapter.quote(for: .sample)
        }
    }

    // Failure: Provider B's own timeout error becomes our .timeout.
    @Test func timeoutBecomesShippingTimeout() async {
        let adapter = ProviderBAdapter(client: ProviderBClientSpy(error: ProviderBError.requestTimedOut))

        await #expect(throws: ShippingError.timeout) {
            try await adapter.quote(for: .sample)
        }
    }

    @Test func serverErrorBecomesProviderUnavailable() async {
        let adapter = ProviderBAdapter(client: ProviderBClientSpy(error: ProviderBError.serverError(statusCode: 503)))

        await #expect(throws: ShippingError.providerUnavailable) {
            try await adapter.quote(for: .sample)
        }
    }

    @Test(arguments: [
        "not json",
        #"{"total_amount":12000,"currency_code":"USD"}"#,                       // missing minor_units
        #"{"total_amount":120.5,"currency_code":"USD","minor_units":true}"#,    // fractional cents
        #"{"total_amount":-1,"currency_code":"USD","minor_units":true}"#,       // negative amount
    ])
    func malformedPayloadIsRejected(json: String) async {
        let adapter = ProviderBAdapter(client: ProviderBClientSpy(json: json))

        await #expect(throws: ShippingError.malformedPayload) {
            try await adapter.quote(for: .sample)
        }
    }
}

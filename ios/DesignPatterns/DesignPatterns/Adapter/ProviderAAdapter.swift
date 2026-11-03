import Foundation

/// Provider A's own client (third-party, we don't change it).
/// Wants weight in kg, returns `{"price":120,"currency":"USD"}` with price in dollars.
protocol ProviderAClientProtocol: Sendable {
    func fetchRate(from origin: String, to destination: String, weightKg: Double) async throws -> Data
}

/// Adapter: translates Provider A into ShippingRateProviderProtocol.
struct ProviderAAdapter: ShippingRateProviderProtocol {
    let client: any ProviderAClientProtocol

    func quote(for request: QuoteRequest) async throws(ShippingError) -> RateQuote {
        let data: Data
        do {
            data = try await client.fetchRate(
                from: request.origin,
                to: request.destination,
                weightKg: Double(request.weightGrams) / 1_000
            )
        } catch let error as URLError where error.code == .timedOut {
            throw .timeout
        } catch {
            throw .providerUnavailable
        }

        let payload: Payload
        do {
            payload = try JSONDecoder().decode(Payload.self, from: data)
        } catch {
            throw .malformedPayload
        }

        guard let currency = Currency(rawValue: payload.currency) else {
            throw .invalidCurrency(payload.currency)
        }
        guard payload.price >= 0 else { throw .malformedPayload }

        return RateQuote(amountMinor: Money.minorUnits(fromMajor: payload.price), currency: currency)
    }

    private struct Payload: Decodable {
        let price: Decimal
        let currency: String
    }
}

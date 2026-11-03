import Foundation

/// Provider B's own client (third-party, we don't change it).
/// Wants weight in grams, returns `{"total_amount":12000,"currency_code":"USD","minor_units":true}`.
protocol ProviderBClientProtocol: Sendable {
    func getQuote(origin: String, destination: String, grams: Int) async throws -> Data
}

/// Provider B's own error type.
enum ProviderBError: Error {
    case requestTimedOut
    case serverError(statusCode: Int)
}

/// Adapter: translates Provider B into ShippingRateProviderProtocol.
struct ProviderBAdapter: ShippingRateProviderProtocol {
    let client: any ProviderBClientProtocol

    func quote(for request: QuoteRequest) async throws(ShippingError) -> RateQuote {
        let data: Data
        do {
            data = try await client.getQuote(
                origin: request.origin,
                destination: request.destination,
                grams: request.weightGrams
            )
        } catch ProviderBError.requestTimedOut {
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

        guard let currency = Currency(rawValue: payload.currencyCode) else {
            throw .invalidCurrency(payload.currencyCode)
        }
        guard payload.totalAmount >= 0 else { throw .malformedPayload }

        let amountMinor: Int
        if payload.minorUnits {
            // Already in cents: must be a whole number.
            guard Money.isWholeNumber(payload.totalAmount) else { throw .malformedPayload }
            amountMinor = NSDecimalNumber(decimal: payload.totalAmount).intValue
        } else {
            amountMinor = Money.minorUnits(fromMajor: payload.totalAmount)
        }

        return RateQuote(amountMinor: amountMinor, currency: currency)
    }

    private struct Payload: Decodable {
        let totalAmount: Decimal
        let currencyCode: String
        let minorUnits: Bool

        enum CodingKeys: String, CodingKey {
            case totalAmount = "total_amount"
            case currencyCode = "currency_code"
            case minorUnits = "minor_units"
        }
    }
}

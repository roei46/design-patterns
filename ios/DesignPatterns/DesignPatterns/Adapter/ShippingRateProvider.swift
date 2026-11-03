import Foundation

/// The only thing app code knows about shipping providers.
protocol ShippingRateProviderProtocol: Sendable {
    func quote(for request: QuoteRequest) async throws(ShippingError) -> RateQuote
}

struct QuoteRequest: Equatable, Sendable {
    let origin: String
    let destination: String
    let weightGrams: Int
}

/// Normalized price. Money is always integer minor units: 12000 = $120.00.
struct RateQuote: Hashable, Sendable {
    let amountMinor: Int
    let currency: Currency
}

enum Currency: String, Hashable, Sendable {
    case usd = "USD"
    case eur = "EUR"
    case ils = "ILS"
}

enum ShippingError: Error, Equatable {
    case invalidCurrency(String)   // currency code we don't support, e.g. "XYZ"
    case timeout
    case malformedPayload          // not JSON, missing fields, negative or fractional amounts
    case providerUnavailable       // any other provider error
}

enum Money {
    /// Major units (dollars) → minor units (cents), exact. Uses Decimal, never Double.
    static func minorUnits(fromMajor amount: Decimal) -> Int {
        NSDecimalNumber(decimal: rounded(amount * 100)).intValue
    }

    static func isWholeNumber(_ amount: Decimal) -> Bool {
        rounded(amount) == amount
    }

    private static func rounded(_ amount: Decimal) -> Decimal {
        var input = amount
        var result = Decimal()
        NSDecimalRound(&result, &input, 0, .plain)
        return result
    }
}

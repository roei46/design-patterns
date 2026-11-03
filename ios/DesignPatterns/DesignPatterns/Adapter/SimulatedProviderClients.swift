import Foundation

/// Stand-ins for the real shipping companies, used by the demo app.

struct SimulatedProviderAClient: ProviderAClientProtocol {
    func fetchRate(from origin: String, to destination: String, weightKg: Double) async throws -> Data {
        try await Task.sleep(for: .milliseconds(300))
        return Data(#"{"price":120,"currency":"USD"}"#.utf8)
    }
}

struct SimulatedProviderBClient: ProviderBClientProtocol {
    func getQuote(origin: String, destination: String, grams: Int) async throws -> Data {
        try await Task.sleep(for: .milliseconds(300))
        return Data(#"{"total_amount":12000,"currency_code":"USD","minor_units":true}"#.utf8)
    }
}

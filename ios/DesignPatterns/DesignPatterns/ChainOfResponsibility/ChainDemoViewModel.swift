import Foundation
import Observation

/// Sends 5 requests through the real chain and shows where each one stopped.
@Observable @MainActor
final class ChainDemoViewModel {
    private(set) var lines: [DemoLineState] = []
    private let chain: RequestChain
    private var runCount = 0

    init(chain: RequestChain) {
        self.chain = chain
    }

    func run() async {
        // The rate limit remembers users, so each run uses new user IDs.
        runCount += 1
        let user = "user-\(runCount)"
        let valid = APIRequest(token: "valid-token", userID: user, body: "export", isPremium: true)

        let cases: [(name: String, request: APIRequest, expected: ChainResult)] = [
            ("Valid request", valid, .accepted),
            ("No token", APIRequest(token: nil, userID: user, body: "export", isPremium: true), .rejected(.unauthorized)),
            ("Empty body", APIRequest(token: "valid-token", userID: user, body: "", isPremium: true), .rejected(.invalidRequest)),
            ("Same request again", valid, .rejected(.rateLimited)),
            ("Non-premium user", APIRequest(token: "valid-token", userID: "free-\(user)", body: "export", isPremium: false), .rejected(.notEligible)),
        ]

        var result: [DemoLineState] = []
        for (name, request, expected) in cases {
            let outcome = await chain.run(request)
            result.append(.init(text: "\(name) → \(text(for: outcome))", passed: outcome == expected))
        }
        lines = result
    }

    private func text(for outcome: ChainResult) -> String {
        switch outcome {
        case .accepted: "accepted"
        case .rejected(let rejection): "rejected: \(rejection)"
        }
    }
}

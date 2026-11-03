import Foundation
import Synchronization

struct APIRequest: Sendable {
    let token: String?
    let userID: String
    let body: String
    let isPremium: Bool
}

enum Rejection: Error, Equatable {
    case unauthorized, invalidRequest, rateLimited, notEligible
}

enum ChainResult: Equatable {
    case accepted
    case rejected(Rejection)
}

protocol RequestHandlerProtocol: Sendable {
    /// nil = pass it on to the next handler.
    func check(_ request: APIRequest) async -> Rejection?
}

/// Runs handlers in array order and stops at the first rejection.
/// Handlers never call "next" themselves, so they can't call it twice.
struct RequestChain: Sendable {
    let handlers: [any RequestHandlerProtocol]

    func run(_ request: APIRequest) async -> ChainResult {
        for handler in handlers {
            if let rejection = await handler.check(request) { return .rejected(rejection) }
        }
        return .accepted
    }
}

struct AuthHandler: RequestHandlerProtocol {
    func check(_ request: APIRequest) async -> Rejection? {
        request.token == "valid-token" ? nil : .unauthorized
    }
}

struct ValidationHandler: RequestHandlerProtocol {
    func check(_ request: APIRequest) async -> Rejection? {
        request.body.isEmpty ? .invalidRequest : nil
    }
}

/// Counts requests per user. The only handler with state (a side effect).
final class RateLimitHandler: RequestHandlerProtocol {
    private let limit: Int
    private let counts = Mutex<[String: Int]>([:])

    init(limit: Int) {
        self.limit = limit
    }

    func requestCount(for userID: String) -> Int {
        counts.withLock { $0[userID, default: 0] }
    }

    func check(_ request: APIRequest) async -> Rejection? {
        let count = counts.withLock { counts in
            counts[request.userID, default: 0] += 1
            return counts[request.userID, default: 0]
        }
        return count > limit ? .rateLimited : nil
    }
}

struct EligibilityHandler: RequestHandlerProtocol {
    func check(_ request: APIRequest) async -> Rejection? {
        request.isPremium ? nil : .notEligible
    }
}

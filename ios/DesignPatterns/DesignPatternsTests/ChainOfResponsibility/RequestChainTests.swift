import Synchronization
import Testing
@testable import DesignPatterns

struct RequestChainTests {
    let rateLimit = RateLimitHandler(limit: 2)
    var chain: RequestChain {
        RequestChain(handlers: [AuthHandler(), ValidationHandler(), rateLimit, EligibilityHandler()])
    }

    @Test func validRequestIsAccepted() async {
        #expect(await chain.run(.valid) == .accepted)
    }

    @Test func noTokenIsRejectedAtAuth() async {
        let request = APIRequest(token: nil, userID: "u1", body: "export", isPremium: true)

        #expect(await chain.run(request) == .rejected(.unauthorized))
    }

    @Test func emptyBodyIsRejectedAtValidation() async {
        let request = APIRequest(token: "valid-token", userID: "u1", body: "", isPremium: true)

        #expect(await chain.run(request) == .rejected(.invalidRequest))
    }

    @Test func tooManyRequestsAreRejectedAtRateLimit() async {
        _ = await chain.run(.valid)
        _ = await chain.run(.valid)

        #expect(await chain.run(.valid) == .rejected(.rateLimited))   // 3rd, limit is 2
    }

    @Test func nonPremiumIsRejectedAtEligibility() async {
        let request = APIRequest(token: "valid-token", userID: "u1", body: "export", isPremium: false)

        #expect(await chain.run(request) == .rejected(.notEligible))
    }

    @Test func handlersRunInArrayOrder() async {
        let log = CallLog()
        let chain = RequestChain(handlers: [
            SpyHandler(name: "first", log: log),
            SpyHandler(name: "second", log: log),
            SpyHandler(name: "third", log: log),
        ])

        _ = await chain.run(.valid)

        #expect(log.names == ["first", "second", "third"])
    }

    @Test func stopsAtFirstRejection() async {
        let log = CallLog()
        let chain = RequestChain(handlers: [
            SpyHandler(name: "first", log: log),
            SpyHandler(name: "second", log: log, rejection: .invalidRequest),
            SpyHandler(name: "third", log: log),
        ])

        let result = await chain.run(.valid)

        #expect(result == .rejected(.invalidRequest))
        #expect(log.names == ["first", "second"])   // "third" never ran
    }

    // A request rejected at Auth never reaches RateLimit, so it isn't counted.
    @Test func sideEffectsAreSkippedAfterRejection() async {
        let request = APIRequest(token: nil, userID: "u1", body: "export", isPremium: true)

        _ = await chain.run(request)

        #expect(rateLimit.requestCount(for: "u1") == 0)
    }
}

/// Records which handlers ran, in order.
final class CallLog: Sendable {
    private let storage = Mutex<[String]>([])
    var names: [String] { storage.withLock { $0 } }
    func append(_ name: String) { storage.withLock { $0.append(name) } }
}

struct SpyHandler: RequestHandlerProtocol {
    let name: String
    let log: CallLog
    var rejection: Rejection?

    func check(_ request: APIRequest) async -> Rejection? {
        log.append(name)
        return rejection
    }
}

extension APIRequest {
    static let valid = APIRequest(token: "valid-token", userID: "u1", body: "export", isPremium: true)
}

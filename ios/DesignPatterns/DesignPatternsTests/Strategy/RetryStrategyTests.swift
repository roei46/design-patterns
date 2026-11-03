import Testing
@testable import DesignPatterns

struct RetryStrategyTests {
    @Test func noRetryTriesOnceAndThrows() async {
        var calls = 0
        var delays: [Int] = []

        await #expect(throws: HTTPError(statusCode: 503)) {
            try await executeWithRetry(strategy: NoRetry(), sleep: { delays.append($0) }) {
                calls += 1
                return try fail(503)
            }
        }
        #expect(calls == 1)
        #expect(delays.isEmpty)
    }

    @Test func fixedDelaySucceedsAfterTwoFailures() async throws {
        var calls = 0
        var delays: [Int] = []

        let result = try await executeWithRetry(
            strategy: FixedDelayRetry(maxAttempts: 3, delayMs: 200),
            sleep: { delays.append($0) }
        ) {
            calls += 1
            if calls <= 2 { return try fail(503) }
            return "ok"
        }

        #expect(result == "ok")
        #expect(calls == 3)
        #expect(delays == [200, 200])
    }

    // Failure: always failing stops at maxAttempts and throws the last error.
    @Test func stopsAtMaxAttempts() async {
        var calls = 0
        var delays: [Int] = []

        await #expect(throws: HTTPError(statusCode: 503)) {
            try await executeWithRetry(
                strategy: FixedDelayRetry(maxAttempts: 3, delayMs: 200),
                sleep: { delays.append($0) }
            ) {
                calls += 1
                return try fail(503)
            }
        }
        #expect(calls == 3)
        #expect(delays == [200, 200])
    }

    @Test func exponentialDelaysDoubleUpToTheCap() async {
        var delays: [Int] = []

        await #expect(throws: HTTPError(statusCode: 503)) {
            try await executeWithRetry(
                strategy: ExponentialBackoffRetry(maxAttempts: 5, baseDelayMs: 100, maxDelayMs: 500, jitterMs: 0),
                sleep: { delays.append($0) }
            ) {
                try fail(503)
            }
        }
        #expect(delays == [100, 200, 400, 500])
    }

    @Test func jitterStaysInRange() {
        let strategy = ExponentialBackoffRetry(maxAttempts: 5, baseDelayMs: 100, maxDelayMs: 10_000, jitterMs: 50)

        for _ in 0..<100 {
            #expect((100...150).contains(strategy.nextDelayMs(attempt: 1)))
            #expect((400...450).contains(strategy.nextDelayMs(attempt: 3)))
        }
    }

    @Test func rateLimited429IsRetried() async throws {
        var calls = 0
        var delays: [Int] = []

        let result = try await executeWithRetry(
            strategy: FixedDelayRetry(maxAttempts: 3, delayMs: 10),
            sleep: { delays.append($0) }
        ) {
            calls += 1
            if calls == 1 { return try fail(429) }
            return "ok"
        }

        #expect(result == "ok")
        #expect(calls == 2)
        #expect(delays == [10])
    }

    // Negative: 400 is the caller's fault, retrying won't help.
    @Test func nonRetryableErrorIsNotRetried() async {
        var calls = 0
        var delays: [Int] = []

        await #expect(throws: HTTPError(statusCode: 400)) {
            try await executeWithRetry(
                strategy: FixedDelayRetry(maxAttempts: 3, delayMs: 200),
                sleep: { delays.append($0) }
            ) {
                calls += 1
                return try fail(400)
            }
        }
        #expect(calls == 1)
        #expect(delays.isEmpty)
    }

    @Test func nonHTTPErrorIsNotRetried() async {
        var calls = 0

        await #expect(throws: CancellationError.self) {
            try await executeWithRetry(
                strategy: ExponentialBackoffRetry(maxAttempts: 3, baseDelayMs: 100, maxDelayMs: 500, jitterMs: 0),
                sleep: { _ in }
            ) {
                calls += 1
                throw CancellationError()
            }
        }
        #expect(calls == 1)
    }

    @Test func successOnFirstTryDoesNotSleep() async throws {
        var delays: [Int] = []

        let result = try await executeWithRetry(
            strategy: ExponentialBackoffRetry(maxAttempts: 3, baseDelayMs: 100, maxDelayMs: 500, jitterMs: 0),
            sleep: { delays.append($0) }
        ) {
            "ok"
        }

        #expect(result == "ok")
        #expect(delays.isEmpty)
    }
}

private func fail(_ statusCode: Int) throws -> String {
    throw HTTPError(statusCode: statusCode)
}

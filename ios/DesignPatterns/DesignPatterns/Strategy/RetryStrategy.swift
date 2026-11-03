import Foundation

/// Retry on 429 (rate limited) and 5xx (server errors). Everything else is final.
struct HTTPError: Error, Equatable {
    let statusCode: Int
    var isRetryable: Bool { statusCode == 429 || statusCode >= 500 }
}

/// Attempt numbering is 1-based: attempt 1 = the first call.
/// After attempt N fails, the loop asks shouldRetry(error, attempt: N) and nextDelayMs(attempt: N).
protocol RetryStrategyProtocol: Sendable {
    func shouldRetry(_ error: any Error, attempt: Int) -> Bool
    func nextDelayMs(attempt: Int) -> Int
}

struct NoRetry: RetryStrategyProtocol {
    func shouldRetry(_ error: any Error, attempt: Int) -> Bool { false }
    func nextDelayMs(attempt: Int) -> Int { 0 }
}

struct FixedDelayRetry: RetryStrategyProtocol {
    let maxAttempts: Int
    let delayMs: Int

    func shouldRetry(_ error: any Error, attempt: Int) -> Bool {
        attempt < maxAttempts && (error as? HTTPError)?.isRetryable == true
    }

    func nextDelayMs(attempt: Int) -> Int { delayMs }
}

/// Delay = base × 2^(attempt-1), capped at maxDelayMs, then + random 0...jitterMs.
struct ExponentialBackoffRetry: RetryStrategyProtocol {
    let maxAttempts: Int
    let baseDelayMs: Int
    let maxDelayMs: Int
    let jitterMs: Int

    func shouldRetry(_ error: any Error, attempt: Int) -> Bool {
        attempt < maxAttempts && (error as? HTTPError)?.isRetryable == true
    }

    func nextDelayMs(attempt: Int) -> Int {
        let doublings = min(attempt - 1, 30)   // avoids overflow on huge attempt numbers
        let exponential = min(baseDelayMs * (1 << doublings), maxDelayMs)
        return exponential + Int.random(in: 0...jitterMs)
    }
}

/// Calls `operation`, retrying as the strategy says. `sleep` is injected so tests don't really wait.
func executeWithRetry<T>(
    strategy: any RetryStrategyProtocol,
    sleep: (Int) async -> Void,
    operation: () async throws -> T
) async throws -> T {
    var attempt = 1
    while true {
        do {
            return try await operation()
        } catch {
            guard strategy.shouldRetry(error, attempt: attempt) else { throw error }
            await sleep(strategy.nextDelayMs(attempt: attempt))
            attempt += 1
        }
    }
}

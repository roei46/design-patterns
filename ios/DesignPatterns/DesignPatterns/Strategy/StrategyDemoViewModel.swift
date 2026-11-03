import Foundation
import Observation

/// Runs the same failing call (503, 503, then success) with each strategy.
@Observable @MainActor
final class StrategyDemoViewModel {
    private(set) var lines: [DemoLineState] = []

    func run() async {
        let strategies: [(name: String, strategy: any RetryStrategyProtocol, expectSuccess: Bool)] = [
            ("NoRetry", NoRetry(), false),
            ("FixedDelay", FixedDelayRetry(maxAttempts: 3, delayMs: 200), true),
            ("Exponential", ExponentialBackoffRetry(maxAttempts: 3, baseDelayMs: 100, maxDelayMs: 1_000, jitterMs: 0), true),
        ]

        var result: [DemoLineState] = []
        for (name, strategy, expectSuccess) in strategies {
            var calls = 0
            var delays: [Int] = []
            do {
                _ = try await executeWithRetry(strategy: strategy, sleep: { ms in
                    delays.append(ms)
                    try? await Task.sleep(for: .milliseconds(ms))
                }) {
                    calls += 1
                    if calls <= 2 { throw HTTPError(statusCode: 503) }
                    return "ok"
                }
                let waited = delays.map(String.init).joined(separator: ", ")
                result.append(.init(text: "\(name) → succeeded after \(calls) attempts (waited \(waited) ms)",
                                    passed: expectSuccess))
            } catch {
                result.append(.init(text: "\(name) → failed after \(calls) attempt\(calls == 1 ? "" : "s")",
                                    passed: !expectSuccess))
            }
        }
        lines = result
    }
}

import Foundation
import Observation

/// Runs the real SettingsProvider.shared and reports what happened.
/// Uses the singleton directly on purpose: the singleton is what's being demoed.
@Observable @MainActor
final class SingletonDemoViewModel {
    private(set) var lines: [DemoLineState] = []

    func run() {
        let provider = SettingsProvider.shared
        var result: [DemoLineState] = []

        result.append(.init(text: "Same instance on repeated calls",
                            passed: SettingsProvider.shared === provider))

        // Loading the same settings again is a no-op, so Run can be tapped many times.
        do {
            try provider.load(.demo)
            let current = try provider.current()
            result.append(.init(text: "Settings loaded: maxRetries = \(current.maxRetries)", passed: true))
        } catch {
            result.append(.init(text: "Load failed: \(error)", passed: false))
        }

        do {
            try provider.load(.demoConflicting)
            result.append(.init(text: "Conflicting re-init was NOT rejected", passed: false))
        } catch {
            result.append(.init(text: "Conflicting re-init rejected", passed: error == .conflictingReinit))
        }

        result.append(.init(text: "Settings unchanged after rejection",
                            passed: (try? provider.current()) == .demo))
        lines = result
    }
}

private extension AppSettings {
    static let demo = AppSettings(
        apiBaseURL: URL(string: "https://api.example.com")!,
        requestTimeoutMs: 5_000,
        maxRetries: 3
    )
    static let demoConflicting = AppSettings(
        apiBaseURL: URL(string: "https://api.example.com")!,
        requestTimeoutMs: 5_000,
        maxRetries: 5
    )
}

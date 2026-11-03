import Foundation
import Testing
@testable import DesignPatterns

extension SingletonTests {
    struct SettingsProviderTests {
        let provider = SettingsProvider.shared

        init() { SettingsProvider.shared.resetForTesting() }   // test isolation

        @Test func sharedAlwaysReturnsSameInstance() {
            #expect(SettingsProvider.shared === SettingsProvider.shared)
        }

        @Test func loadThenReadReturnsSettings() throws {
            try provider.load(.sample)

            #expect(try provider.current() == .sample)
        }

        @Test func readingTwiceGivesStableSettings() throws {
            try provider.load(.sample)

            let first = try provider.current()
            let second = try provider.current()

            #expect(first == second)
        }

        @Test func loadingSameSettingsAgainIsAllowed() throws {
            try provider.load(.sample)

            try provider.load(.sample)

            #expect(try provider.current() == .sample)
        }

        // Negative: different values after the first load are rejected, original is kept.
        @Test func conflictingReinitIsRejected() throws {
            try provider.load(.sample)

            #expect(throws: SettingsError.conflictingReinit) {
                try provider.load(.other)
            }
            #expect(try provider.current() == .sample)
        }

        // Failure: reading before anything was loaded.
        @Test func readingBeforeLoadFails() {
            #expect(throws: SettingsError.notLoaded) {
                try provider.current()
            }
        }

        @Test func resetClearsSettings() throws {
            try provider.load(.sample)

            provider.resetForTesting()

            #expect(throws: SettingsError.notLoaded) {
                try provider.current()
            }
        }

        // 100 tasks race to load different settings: exactly one wins, the rest are rejected.
        @Test func concurrentLoadsHaveExactlyOneWinner() async throws {
            let winners = await withTaskGroup(of: AppSettings?.self) { group in
                for retries in 0..<100 {
                    group.addTask {
                        let settings = AppSettings.sample(maxRetries: retries)
                        do {
                            try SettingsProvider.shared.load(settings)
                            return settings
                        } catch {
                            return nil
                        }
                    }
                }
                var winners: [AppSettings] = []
                for await result in group {
                    if let result { winners.append(result) }
                }
                return winners
            }

            let winner = try #require(winners.first)
            #expect(winners.count == 1)
            #expect(try provider.current() == winner)
        }
    }
}

private extension AppSettings {
    static let sample = AppSettings.sample(maxRetries: 3)
    static let other = AppSettings.sample(maxRetries: 5)

    static func sample(maxRetries: Int) -> AppSettings {
        AppSettings(
            apiBaseURL: URL(string: "https://api.example.com")!,
            requestTimeoutMs: 5_000,
            maxRetries: maxRetries
        )
    }
}

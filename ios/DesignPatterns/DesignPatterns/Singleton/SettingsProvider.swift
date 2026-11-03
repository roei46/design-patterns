import Foundation
import Synchronization

/// Immutable settings. A struct with only `let`s is frozen once created.
struct AppSettings: Equatable, Sendable {
    let apiBaseURL: URL
    let requestTimeoutMs: Int
    let maxRetries: Int
}

enum SettingsError: Error, Equatable {
    case notLoaded          // read before load()
    case conflictingReinit  // load() again with different values
}

/// Singleton: one shared settings holder per process.
final class SettingsProvider: Sendable {
    static let shared = SettingsProvider()   // Swift's getInstance()

    // Threads share memory in Swift, so the stored value sits behind a lock.
    private let storage = Mutex<AppSettings?>(nil)

    private init() {}                        // nobody else can create one

    /// First call stores the settings. Same values again: no-op. Different values: throws.
    func load(_ settings: AppSettings) throws(SettingsError) {
        try storage.withLock { current throws(SettingsError) in
            if let existing = current {
                guard existing == settings else { throw .conflictingReinit }
                return
            }
            current = settings
        }
    }

    func current() throws(SettingsError) -> AppSettings {
        guard let settings = storage.withLock({ $0 }) else { throw .notLoaded }
        return settings
    }

    #if DEBUG
    /// Test-only. Not compiled into Release builds.
    func resetForTesting() {
        storage.withLock { $0 = nil }
    }
    #endif
}

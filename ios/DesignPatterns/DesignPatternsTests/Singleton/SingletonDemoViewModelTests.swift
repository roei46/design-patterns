import Testing
@testable import DesignPatterns

extension SingletonTests {
    @MainActor
    struct SingletonDemoViewModelTests {
        init() { SettingsProvider.shared.resetForTesting() }

        @Test func runReportsAllChecksPassed() throws {
            let viewModel = SingletonDemoViewModel()

            viewModel.run()

            #expect(viewModel.lines.count == 4)
            #expect(viewModel.lines.allSatisfy { $0.passed })
            #expect(throws: Never.self) { try SettingsProvider.shared.current() }
        }

        @Test func runningTwiceStillPasses() {
            let viewModel = SingletonDemoViewModel()

            viewModel.run()
            viewModel.run()

            #expect(viewModel.lines.count == 4)
            #expect(viewModel.lines.allSatisfy { $0.passed })
        }
    }
}

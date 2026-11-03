import Testing
@testable import DesignPatterns

@MainActor
struct BuilderDemoViewModelTests {
    @Test func runReportsAllChecksPassed() {
        let viewModel = BuilderDemoViewModel()

        viewModel.run()

        #expect(viewModel.lines.count == 4)
        #expect(viewModel.lines.allSatisfy { $0.passed })
    }

    @Test func runningTwiceStillPasses() {
        let viewModel = BuilderDemoViewModel()

        viewModel.run()
        viewModel.run()

        #expect(viewModel.lines.count == 4)
        #expect(viewModel.lines.allSatisfy { $0.passed })
    }
}

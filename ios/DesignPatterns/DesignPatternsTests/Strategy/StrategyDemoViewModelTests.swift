import Testing
@testable import DesignPatterns

@MainActor
struct StrategyDemoViewModelTests {
    @Test func runReportsAllExpectedOutcomes() async {
        let viewModel = StrategyDemoViewModel()

        await viewModel.run()

        #expect(viewModel.lines.count == 3)
        #expect(viewModel.lines.allSatisfy { $0.passed })
    }

    @Test func runningTwiceStillPasses() async {
        let viewModel = StrategyDemoViewModel()

        await viewModel.run()
        await viewModel.run()

        #expect(viewModel.lines.count == 3)
        #expect(viewModel.lines.allSatisfy { $0.passed })
    }
}

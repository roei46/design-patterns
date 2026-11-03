import Testing
@testable import DesignPatterns

@MainActor
struct ChainDemoViewModelTests {
    let chain = RequestChain(handlers: [AuthHandler(), ValidationHandler(), RateLimitHandler(limit: 1), EligibilityHandler()])

    @Test func runReportsAllExpectedOutcomes() async {
        let viewModel = ChainDemoViewModel(chain: chain)

        await viewModel.run()

        #expect(viewModel.lines.count == 5)
        #expect(viewModel.lines.allSatisfy { $0.passed })
    }

    @Test func runningTwiceStillPasses() async {
        let viewModel = ChainDemoViewModel(chain: chain)

        await viewModel.run()
        await viewModel.run()

        #expect(viewModel.lines.count == 5)
        #expect(viewModel.lines.allSatisfy { $0.passed })
    }
}

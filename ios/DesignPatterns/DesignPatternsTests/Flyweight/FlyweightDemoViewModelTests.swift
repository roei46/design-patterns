import Testing
@testable import DesignPatterns

@MainActor
struct FlyweightDemoViewModelTests {
    @Test func runReportsAllChecksPassed() {
        let viewModel = FlyweightDemoViewModel(factory: PortMetadataFactory())

        viewModel.run()

        #expect(viewModel.lines.count == 3)
        #expect(viewModel.lines.allSatisfy { $0.passed })
    }

    @Test func runningTwiceStillCreatesOnlyFourPorts() {
        let factory = PortMetadataFactory()
        let viewModel = FlyweightDemoViewModel(factory: factory)

        viewModel.run()
        viewModel.run()

        #expect(factory.createdCount == 4)
        #expect(viewModel.lines.allSatisfy { $0.passed })
    }
}

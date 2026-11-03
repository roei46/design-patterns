import Testing
@testable import DesignPatterns

@MainActor
struct AdapterDemoViewModelTests {
    @Test func allProvidersSucceedShowsAllGreen() async {
        let quote = RateQuote(amountMinor: 12_000, currency: .usd)
        let viewModel = AdapterDemoViewModel(providers: [
            ("A", StubShippingProvider(result: .success(quote))),
            ("B", StubShippingProvider(result: .success(quote))),
        ])

        await viewModel.run()

        #expect(viewModel.lines.count == 3)
        #expect(viewModel.lines.allSatisfy { $0.passed })
    }

    @Test func failingProviderShowsRedLine() async {
        let viewModel = AdapterDemoViewModel(providers: [
            ("A", StubShippingProvider(result: .success(RateQuote(amountMinor: 12_000, currency: .usd)))),
            ("B", StubShippingProvider(result: .failure(.timeout))),
        ])

        await viewModel.run()

        #expect(viewModel.lines.count == 2)
        #expect(viewModel.lines[0].passed)
        #expect(!viewModel.lines[1].passed)
    }
}

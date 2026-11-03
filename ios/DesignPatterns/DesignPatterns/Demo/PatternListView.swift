import SwiftUI

struct PatternListView: View {
    let singletonViewModel: SingletonDemoViewModel
    let builderViewModel: BuilderDemoViewModel
    let adapterViewModel: AdapterDemoViewModel
    let flyweightViewModel: FlyweightDemoViewModel
    let chainViewModel: ChainDemoViewModel
    let strategyViewModel: StrategyDemoViewModel

    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Singleton") {
                    SingletonDemoView(viewModel: singletonViewModel)
                }
                NavigationLink("Builder") {
                    BuilderDemoView(viewModel: builderViewModel)
                }
                NavigationLink("Adapter") {
                    AdapterDemoView(viewModel: adapterViewModel)
                }
                NavigationLink("Flyweight") {
                    FlyweightDemoView(viewModel: flyweightViewModel)
                }
                NavigationLink("Chain of Responsibility") {
                    ChainDemoView(viewModel: chainViewModel)
                }
                NavigationLink("Strategy") {
                    StrategyDemoView(viewModel: strategyViewModel)
                }
            }
            .navigationTitle("Design Patterns")
        }
    }
}

#Preview {
    PatternListView(
        singletonViewModel: SingletonDemoViewModel(),
        builderViewModel: BuilderDemoViewModel(),
        adapterViewModel: AdapterDemoViewModel(providers: [
            ("Provider A", ProviderAAdapter(client: SimulatedProviderAClient())),
            ("Provider B", ProviderBAdapter(client: SimulatedProviderBClient())),
        ]),
        flyweightViewModel: FlyweightDemoViewModel(factory: PortMetadataFactory()),
        chainViewModel: ChainDemoViewModel(chain: RequestChain(handlers: [
            AuthHandler(), ValidationHandler(), RateLimitHandler(limit: 1), EligibilityHandler(),
        ])),
        strategyViewModel: StrategyDemoViewModel()
    )
}

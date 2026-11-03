import SwiftUI

@main struct DesignPatternsApp: App {
    @State private var singletonViewModel = SingletonDemoViewModel()
    @State private var builderViewModel = BuilderDemoViewModel()
    @State private var adapterViewModel = AdapterDemoViewModel(providers: [
        ("Provider A", ProviderAAdapter(client: SimulatedProviderAClient())),
        ("Provider B", ProviderBAdapter(client: SimulatedProviderBClient())),
    ])
    @State private var flyweightViewModel = FlyweightDemoViewModel(factory: PortMetadataFactory())
    @State private var chainViewModel = ChainDemoViewModel(chain: RequestChain(handlers: [
        AuthHandler(), ValidationHandler(), RateLimitHandler(limit: 1), EligibilityHandler(),
    ]))
    @State private var strategyViewModel = StrategyDemoViewModel()

    var body: some Scene {
        WindowGroup {
            PatternListView(
                singletonViewModel: singletonViewModel,
                builderViewModel: builderViewModel,
                adapterViewModel: adapterViewModel,
                flyweightViewModel: flyweightViewModel,
                chainViewModel: chainViewModel,
                strategyViewModel: strategyViewModel
            )
        }
    }
}

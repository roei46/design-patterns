import SwiftUI

struct StrategyDemoView: View {
    let viewModel: StrategyDemoViewModel

    var body: some View {
        List {
            Button("Run") { Task { await viewModel.run() } }
            ForEach(viewModel.lines) { line in DemoLineRow(line: line) }
        }
        .navigationTitle("Strategy")
    }
}

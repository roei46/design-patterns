import SwiftUI

struct ChainDemoView: View {
    let viewModel: ChainDemoViewModel

    var body: some View {
        List {
            Button("Run") { Task { await viewModel.run() } }
            ForEach(viewModel.lines) { line in DemoLineRow(line: line) }
        }
        .navigationTitle("Chain of Responsibility")
    }
}

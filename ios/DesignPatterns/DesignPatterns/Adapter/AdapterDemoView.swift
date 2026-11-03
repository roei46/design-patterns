import SwiftUI

struct AdapterDemoView: View {
    let viewModel: AdapterDemoViewModel

    var body: some View {
        List {
            Button("Run") { Task { await viewModel.run() } }
            ForEach(viewModel.lines) { line in DemoLineRow(line: line) }
        }
        .navigationTitle("Adapter")
    }
}

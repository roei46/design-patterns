import SwiftUI

struct BuilderDemoView: View {
    let viewModel: BuilderDemoViewModel

    var body: some View {
        List {
            Button("Run") { viewModel.run() }
            ForEach(viewModel.lines) { line in DemoLineRow(line: line) }
        }
        .navigationTitle("Builder")
    }
}

import SwiftUI

struct SingletonDemoView: View {
    let viewModel: SingletonDemoViewModel

    var body: some View {
        List {
            Button("Run") { viewModel.run() }
            ForEach(viewModel.lines) { line in DemoLineRow(line: line) }
        }
        .navigationTitle("Singleton")
    }
}

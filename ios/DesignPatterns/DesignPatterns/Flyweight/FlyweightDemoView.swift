import SwiftUI

struct FlyweightDemoView: View {
    let viewModel: FlyweightDemoViewModel

    var body: some View {
        List {
            Button("Run") { viewModel.run() }
            ForEach(viewModel.lines) { line in DemoLineRow(line: line) }
        }
        .navigationTitle("Flyweight")
    }
}

import SwiftUI

/// One output line on a demo page: green check or red cross.
struct DemoLineRow: View {
    let line: DemoLineState

    var body: some View {
        Label(line.text, systemImage: line.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
            .foregroundStyle(line.passed ? .green : .red)
    }
}

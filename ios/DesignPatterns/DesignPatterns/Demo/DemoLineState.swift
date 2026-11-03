import Foundation

/// One line of output on a demo page.
struct DemoLineState: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let passed: Bool
}

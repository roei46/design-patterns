import Foundation
import Observation

/// Runs the real ReportRequestBuilder and reports what happened.
@Observable @MainActor
final class BuilderDemoViewModel {
    private(set) var lines: [DemoLineState] = []

    func run() {
        let jan1 = Date(timeIntervalSince1970: 1_767_225_600)
        let jan31 = Date(timeIntervalSince1970: 1_769_817_600)
        var result: [DemoLineState] = []

        let builder = ReportRequestBuilder()
            .withDateRange(from: jan1, to: jan31)
            .addFilter(field: "country", value: "IL")
            .withFormat(.json)
            .enableCompression()

        var built: ReportRequest?
        do {
            let report = try builder.build()
            built = report
            result.append(.init(text: "Built report: json, \(report.filters.count) filter, compressed", passed: true))
        } catch {
            result.append(.init(text: "Build failed: \(error)", passed: false))
        }

        do {
            _ = try ReportRequestBuilder().withDateRange(from: jan31, to: jan1).build()
            result.append(.init(text: "Inverted date range was NOT rejected", passed: false))
        } catch {
            result.append(.init(text: "Inverted date range rejected", passed: error == .invertedDateRange))
        }

        do {
            _ = try builder.withFormat(.pdf).build()
            result.append(.init(text: "PDF + compression was NOT rejected", passed: false))
        } catch {
            result.append(.init(text: "PDF + compression rejected", passed: error == .compressionNotSupportedForPDF))
        }

        _ = builder.addFilter(field: "status", value: "paid")
        result.append(.init(text: "Earlier report unchanged after builder reused",
                            passed: built?.filters.count == 1))

        lines = result
    }
}

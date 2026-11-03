import Foundation
import Testing
@testable import DesignPatterns

struct ReportRequestBuilderTests {
    @Test func chainingBuildsReportWithAllOptions() throws {
        let report = try ReportRequestBuilder()
            .withDateRange(from: .jan1, to: .jan31)
            .addFilter(field: "country", value: "IL")
            .withFormat(.json)
            .enableCompression()
            .build()

        #expect(report.dateRange == DateRange(start: .jan1, end: .jan31))
        #expect(report.filters == [ReportFilter(field: "country", value: "IL")])
        #expect(report.format == .json)
        #expect(report.isCompressed)
    }

    @Test func sameApiBuildsTwoDifferentReports() throws {
        let csv = try ReportRequestBuilder()
            .withDateRange(from: .jan1, to: .jan31)
            .withFormat(.csv)
            .build()
        let pdf = try ReportRequestBuilder()
            .withDateRange(from: .jan1, to: .jan1)
            .addFilter(field: "status", value: "paid")
            .withFormat(.pdf)
            .build()

        #expect(csv != pdf)
        #expect(csv.format == .csv)
        #expect(pdf.format == .pdf)
    }

    @Test func skippedStepsUseDefaults() throws {
        let report = try ReportRequestBuilder()
            .withDateRange(from: .jan1, to: .jan31)
            .build()

        #expect(report.format == .csv)
        #expect(report.filters.isEmpty)
        #expect(!report.isCompressed)
    }

    // Edge case: a one-day report.
    @Test func sameStartAndEndIsAllowed() throws {
        let report = try ReportRequestBuilder()
            .withDateRange(from: .jan1, to: .jan1)
            .build()

        #expect(report.dateRange.start == report.dateRange.end)
    }

    // Negative: start after end.
    @Test func invertedDateRangeIsRejected() {
        #expect(throws: ReportRequestError.invertedDateRange) {
            try ReportRequestBuilder()
                .withDateRange(from: .jan31, to: .jan1)
                .build()
        }
    }

    // Negative: incompatible combination.
    @Test func compressionWithPdfIsRejected() {
        #expect(throws: ReportRequestError.compressionNotSupportedForPDF) {
            try ReportRequestBuilder()
                .withDateRange(from: .jan1, to: .jan31)
                .withFormat(.pdf)
                .enableCompression()
                .build()
        }
    }

    // Failure: a required step was skipped.
    @Test func missingDateRangeIsRejected() {
        #expect(throws: ReportRequestError.missingDateRange) {
            try ReportRequestBuilder()
                .withFormat(.json)
                .build()
        }
    }

    // Built reports don't share arrays with the builder or with later builds.
    @Test func changingBuilderAfterBuildDoesNotChangeReport() throws {
        let builder = ReportRequestBuilder()
            .withDateRange(from: .jan1, to: .jan31)
            .addFilter(field: "country", value: "IL")

        let first = try builder.build()
        let second = try builder.addFilter(field: "status", value: "paid").build()

        #expect(first.filters == [ReportFilter(field: "country", value: "IL")])
        #expect(second.filters == [
            ReportFilter(field: "country", value: "IL"),
            ReportFilter(field: "status", value: "paid"),
        ])
    }
}

private extension Date {
    static let jan1 = Date(timeIntervalSince1970: 1_767_225_600)   // 2026-01-01 UTC
    static let jan31 = Date(timeIntervalSince1970: 1_769_817_600)  // 2026-01-31 UTC
}

import Foundation

/// The finished, immutable report request. Only the builder can create one.
struct ReportRequest: Equatable, Sendable {
    let dateRange: DateRange
    let filters: [ReportFilter]
    let format: ReportFormat
    let isCompressed: Bool

    fileprivate init(dateRange: DateRange, filters: [ReportFilter], format: ReportFormat, isCompressed: Bool) {
        self.dateRange = dateRange
        self.filters = filters
        self.format = format
        self.isCompressed = isCompressed
    }
}

struct DateRange: Equatable, Sendable {
    let start: Date
    let end: Date
}

struct ReportFilter: Equatable, Sendable {
    let field: String
    let value: String
}

enum ReportFormat: Equatable, Sendable {
    case csv, json, pdf
}

enum ReportRequestError: Error, Equatable {
    case missingDateRange               // build() without withDateRange()
    case invertedDateRange              // start is after end
    case compressionNotSupportedForPDF  // a PDF is already compressed
}

/// Builder: set options step by step, then build() checks them all together.
/// A struct, so every step and every build is its own copy: nothing is shared.
struct ReportRequestBuilder {
    private var dateRange: DateRange?
    private var filters: [ReportFilter] = []
    private var format: ReportFormat = .csv
    private var isCompressed = false

    func withDateRange(from start: Date, to end: Date) -> Self {
        var copy = self
        copy.dateRange = DateRange(start: start, end: end)
        return copy
    }

    func addFilter(field: String, value: String) -> Self {
        var copy = self
        copy.filters.append(ReportFilter(field: field, value: value))
        return copy
    }

    func withFormat(_ format: ReportFormat) -> Self {
        var copy = self
        copy.format = format
        return copy
    }

    func enableCompression() -> Self {
        var copy = self
        copy.isCompressed = true
        return copy
    }

    func build() throws(ReportRequestError) -> ReportRequest {
        guard let dateRange else { throw .missingDateRange }
        guard dateRange.start <= dateRange.end else { throw .invertedDateRange }
        if isCompressed && format == .pdf { throw .compressionNotSupportedForPDF }

        return ReportRequest(dateRange: dateRange, filters: filters, format: format, isCompressed: isCompressed)
    }
}

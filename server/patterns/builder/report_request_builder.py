from dataclasses import dataclass
from datetime import date
from typing import Literal, Self

ReportFormat = Literal["csv", "json", "pdf"]


@dataclass(frozen=True)
class ReportFilter:
    field: str
    value: str


@dataclass(frozen=True)
class ReportRequest:
    """The finished, immutable request. Create it with ReportRequestBuilder, not directly."""

    start_date: date
    end_date: date
    filters: tuple[ReportFilter, ...]  # tuple: can't be changed, so nothing is shared
    format: ReportFormat
    compressed: bool


class MissingDateRangeError(Exception):
    """build() was called without with_date_range()."""


class InvertedDateRangeError(Exception):
    """The start date is after the end date."""


class IncompatibleOptionsError(Exception):
    """Options that can't go together, e.g. compression on a PDF (already compressed)."""


class ReportRequestBuilder:
    """Builder: set options step by step, then build() checks them all together."""

    def __init__(self) -> None:
        self._start_date: date | None = None
        self._end_date: date | None = None
        self._filters: list[ReportFilter] = []
        self._format: ReportFormat = "csv"
        self._compressed = False

    def with_date_range(self, start: date, end: date) -> Self:
        self._start_date = start
        self._end_date = end
        return self

    def add_filter(self, field: str, value: str) -> Self:
        self._filters.append(ReportFilter(field, value))
        return self

    def with_format(self, fmt: ReportFormat) -> Self:
        self._format = fmt
        return self

    def enable_compression(self) -> Self:
        self._compressed = True
        return self

    def build(self) -> ReportRequest:
        if self._start_date is None or self._end_date is None:
            raise MissingDateRangeError("call with_date_range() first")
        if self._start_date > self._end_date:
            raise InvertedDateRangeError(f"start {self._start_date} is after end {self._end_date}")
        if self._compressed and self._format == "pdf":
            raise IncompatibleOptionsError("compression is not supported for PDF")

        return ReportRequest(
            start_date=self._start_date,
            end_date=self._end_date,
            filters=tuple(self._filters),  # a copy: later add_filter() calls don't change this request
            format=self._format,
            compressed=self._compressed,
        )

import dataclasses
from datetime import date

import pytest

from patterns.builder.report_request_builder import (
    IncompatibleOptionsError,
    InvertedDateRangeError,
    MissingDateRangeError,
    ReportFilter,
    ReportRequestBuilder,
)

JAN_1 = date(2026, 1, 1)
JAN_31 = date(2026, 1, 31)


def test_full_chain_builds_the_request() -> None:
    request = (
        ReportRequestBuilder()
        .with_date_range(JAN_1, JAN_31)
        .add_filter("country", "IL")
        .add_filter("status", "paid")
        .with_format("json")
        .enable_compression()
        .build()
    )

    assert request.start_date == JAN_1
    assert request.end_date == JAN_31
    assert request.filters == (ReportFilter("country", "IL"), ReportFilter("status", "paid"))
    assert request.format == "json"
    assert request.compressed is True


def test_defaults() -> None:
    request = ReportRequestBuilder().with_date_range(JAN_1, JAN_31).build()

    assert request.format == "csv"
    assert request.compressed is False
    assert request.filters == ()


def test_missing_date_range_is_rejected() -> None:
    with pytest.raises(MissingDateRangeError):
        ReportRequestBuilder().build()


def test_inverted_date_range_is_rejected() -> None:
    with pytest.raises(InvertedDateRangeError):
        ReportRequestBuilder().with_date_range(JAN_31, JAN_1).build()


def test_compressed_pdf_is_rejected() -> None:
    builder = ReportRequestBuilder().with_date_range(JAN_1, JAN_31).with_format("pdf").enable_compression()

    with pytest.raises(IncompatibleOptionsError):
        builder.build()


def test_built_requests_do_not_share_filters() -> None:
    builder = ReportRequestBuilder().with_date_range(JAN_1, JAN_31).add_filter("country", "IL")
    first = builder.build()

    builder.add_filter("status", "paid")
    second = builder.build()

    assert first.filters == (ReportFilter("country", "IL"),)
    assert len(second.filters) == 2


def test_request_cannot_be_changed() -> None:
    request = ReportRequestBuilder().with_date_range(JAN_1, JAN_31).build()

    with pytest.raises(dataclasses.FrozenInstanceError):
        request.compressed = True  # type: ignore[misc]

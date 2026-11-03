import dataclasses
import tracemalloc
from collections.abc import Callable

import pytest

from patterns.flyweight.port_metadata import (
    PortMetadata,
    PortMetadataFactory,
    ShippingRate,
    UnknownPortError,
)

CODES = ["ILHFA", "USNYC", "NLRTM"]
RATE_COUNT = 10_000


def test_same_code_returns_same_object() -> None:
    factory = PortMetadataFactory()

    assert factory.get("ILHFA") is factory.get("ILHFA")
    assert factory.get("ilhfa") is factory.get("ILHFA")


def test_different_codes_return_different_objects() -> None:
    factory = PortMetadataFactory()

    assert factory.get("ILHFA") is not factory.get("USNYC")


def test_many_rates_create_only_one_port_per_code() -> None:
    factory = PortMetadataFactory()

    rates = [ShippingRate(f"s{i}", 100, factory.get(CODES[i % 3])) for i in range(RATE_COUNT)]

    assert len(rates) == RATE_COUNT
    assert factory.created_count == 3


def measure_memory(make_rates: Callable[[], list[ShippingRate]]) -> int:
    """Bytes allocated while make_rates() runs."""
    tracemalloc.start()
    rates = make_rates()
    used, _ = tracemalloc.get_traced_memory()
    tracemalloc.stop()
    assert len(rates) == RATE_COUNT
    return used


def test_shared_ports_use_less_memory() -> None:
    factory = PortMetadataFactory()

    def shared() -> list[ShippingRate]:
        return [ShippingRate(f"s{i}", 100, factory.get(CODES[i % 3])) for i in range(RATE_COUNT)]

    def not_shared() -> list[ShippingRate]:
        return [
            ShippingRate(f"s{i}", 100, PortMetadata(CODES[i % 3], "Israel", "Asia/Jerusalem"))
            for i in range(RATE_COUNT)
        ]

    assert measure_memory(shared) < measure_memory(not_shared)


def test_unknown_port_is_rejected() -> None:
    with pytest.raises(UnknownPortError):
        PortMetadataFactory().get("XXXXX")


def test_port_cannot_be_changed() -> None:
    port = PortMetadataFactory().get("ILHFA")

    with pytest.raises(dataclasses.FrozenInstanceError):
        port.country = "Nowhere"  # type: ignore[misc]

import threading
from dataclasses import dataclass


@dataclass(frozen=True)
class PortMetadata:
    """The flyweight: shared, immutable port info. Get it from PortMetadataFactory."""

    code: str
    country: str
    timezone: str


@dataclass(frozen=True)
class ShippingRate:
    """Per-rate data. Stays outside the flyweight and only points to the shared port."""

    shipment_id: str
    price_minor: int
    port: PortMetadata


class UnknownPortError(Exception):
    """A port code we don't know."""


_KNOWN_PORTS: dict[str, tuple[str, str]] = {
    "ILHFA": ("Israel", "Asia/Jerusalem"),
    "USNYC": ("United States", "America/New_York"),
    "NLRTM": ("Netherlands", "Europe/Amsterdam"),
    "CNSHA": ("China", "Asia/Shanghai"),
}


class PortMetadataFactory:
    """Returns one shared PortMetadata per port code."""

    def __init__(self) -> None:
        self._cache: dict[str, PortMetadata] = {}
        self._lock = threading.Lock()

    @property
    def created_count(self) -> int:
        """How many PortMetadata objects were created."""
        return len(self._cache)

    def get(self, code: str) -> PortMetadata:
        code = code.upper()
        if code not in _KNOWN_PORTS:
            raise UnknownPortError(f"unknown port: {code}")

        with self._lock:
            if code not in self._cache:
                country, timezone = _KNOWN_PORTS[code]
                self._cache[code] = PortMetadata(code, country, timezone)
            return self._cache[code]

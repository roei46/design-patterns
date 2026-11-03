from collections.abc import Awaitable, Callable, Mapping
from dataclasses import dataclass
from decimal import Decimal
from enum import StrEnum
from typing import Protocol


class Currency(StrEnum):
    """Like a Swift `enum Currency: String`. Currency("XYZ") raises ValueError."""

    USD = "USD"
    EUR = "EUR"
    ILS = "ILS"


@dataclass(frozen=True)
class QuoteRequest:
    origin: str
    destination: str
    weight_grams: int


@dataclass(frozen=True)
class RateQuote:
    """Normalized price. Money is always integer minor units: 12000 = $120.00."""

    amount_minor: int
    currency: Currency


class InvalidCurrencyError(Exception):
    """The provider returned a currency we don't support, e.g. "XYZ"."""


class ProviderTimeoutError(Exception):
    """The provider didn't answer in time."""


class MalformedPayloadError(Exception):
    """Missing fields, wrong types, negative or fractional amounts."""


class ShippingRateProvider(Protocol):
    """The only thing app code knows about shipping providers."""

    async def get_quote(self, request: QuoteRequest) -> RateQuote: ...


# A provider's raw API call: takes the request, returns its JSON as a dict.
# Raises TimeoutError when the provider is too slow.
FetchRaw = Callable[[QuoteRequest], Awaitable[Mapping[str, object]]]


# --- Helpers shared by both adapters ---


async def _call(fetch: FetchRaw, request: QuoteRequest) -> Mapping[str, object]:
    try:
        return await fetch(request)
    except TimeoutError as error:
        raise ProviderTimeoutError("provider timed out") from error


def _major_to_minor(amount: object) -> int:
    """Dollars -> cents, exact. Goes through Decimal so floats like 0.1 don't lose cents."""
    if isinstance(amount, bool) or not isinstance(amount, int | float):
        raise MalformedPayloadError(f"invalid amount: {amount!r}")
    cents = Decimal(str(amount)) * 100
    if cents < 0 or cents != cents.to_integral_value():
        raise MalformedPayloadError(f"invalid amount: {amount!r}")
    return int(cents)


def _parse_currency(code: object) -> Currency:
    if not isinstance(code, str):
        raise MalformedPayloadError(f"invalid currency field: {code!r}")
    try:
        return Currency(code)
    except ValueError as error:
        raise InvalidCurrencyError(f"unsupported currency: {code}") from error


class ProviderAAdapter:
    """Provider A returns {"price": 120, "currency": "USD"}, price in dollars."""

    def __init__(self, fetch: FetchRaw) -> None:
        self._fetch = fetch

    async def get_quote(self, request: QuoteRequest) -> RateQuote:
        payload = await _call(self._fetch, request)
        return RateQuote(
            amount_minor=_major_to_minor(payload.get("price")),
            currency=_parse_currency(payload.get("currency")),
        )


class ProviderBAdapter:
    """Provider B returns {"total_amount": 12000, "currency_code": "USD", "minor_units": true}."""

    def __init__(self, fetch: FetchRaw) -> None:
        self._fetch = fetch

    async def get_quote(self, request: QuoteRequest) -> RateQuote:
        payload = await _call(self._fetch, request)
        amount = payload.get("total_amount")
        minor_units = payload.get("minor_units")
        if not isinstance(minor_units, bool):
            raise MalformedPayloadError("minor_units must be true or false")

        if minor_units:
            # Already in cents: must be a whole, non-negative number.
            if isinstance(amount, bool) or not isinstance(amount, int) or amount < 0:
                raise MalformedPayloadError(f"invalid total_amount: {amount!r}")
            amount_minor = amount
        else:
            amount_minor = _major_to_minor(amount)

        return RateQuote(
            amount_minor=amount_minor,
            currency=_parse_currency(payload.get("currency_code")),
        )

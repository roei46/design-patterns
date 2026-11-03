from collections.abc import Mapping

import pytest

from patterns.adapter.shipping import (
    Currency,
    FetchRaw,
    InvalidCurrencyError,
    MalformedPayloadError,
    ProviderAAdapter,
    ProviderBAdapter,
    ProviderTimeoutError,
    QuoteRequest,
    RateQuote,
    ShippingRateProvider,
)

REQUEST = QuoteRequest(origin="ILHFA", destination="USNYC", weight_grams=2_500)


def returning(payload: Mapping[str, object]) -> FetchRaw:
    """A fake provider call that always returns `payload`."""

    async def fetch(request: QuoteRequest) -> Mapping[str, object]:
        return payload

    return fetch


async def timing_out(request: QuoteRequest) -> Mapping[str, object]:
    """A fake provider call that always times out."""
    raise TimeoutError


@pytest.mark.asyncio
async def test_both_providers_give_the_same_quote() -> None:
    # The app only knows ShippingRateProvider, not which provider is behind it.
    provider_a: ShippingRateProvider = ProviderAAdapter(returning({"price": 120, "currency": "USD"}))
    provider_b: ShippingRateProvider = ProviderBAdapter(
        returning({"total_amount": 12000, "currency_code": "USD", "minor_units": True})
    )

    quote_a = await provider_a.get_quote(REQUEST)
    quote_b = await provider_b.get_quote(REQUEST)

    assert quote_a == quote_b == RateQuote(12000, Currency.USD)


@pytest.mark.asyncio
async def test_provider_a_converts_fractional_dollars_exactly() -> None:
    adapter = ProviderAAdapter(returning({"price": 19.99, "currency": "EUR"}))

    assert await adapter.get_quote(REQUEST) == RateQuote(1999, Currency.EUR)


@pytest.mark.asyncio
async def test_provider_b_in_major_units() -> None:
    adapter = ProviderBAdapter(returning({"total_amount": 120, "currency_code": "ILS", "minor_units": False}))

    assert await adapter.get_quote(REQUEST) == RateQuote(12000, Currency.ILS)


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "provider",
    [
        ProviderAAdapter(returning({"price": 120, "currency": "XYZ"})),
        ProviderBAdapter(returning({"total_amount": 12000, "currency_code": "XYZ", "minor_units": True})),
    ],
)
async def test_invalid_currency_is_rejected(provider: ShippingRateProvider) -> None:
    with pytest.raises(InvalidCurrencyError):
        await provider.get_quote(REQUEST)


@pytest.mark.asyncio
@pytest.mark.parametrize("provider", [ProviderAAdapter(timing_out), ProviderBAdapter(timing_out)])
async def test_timeout_becomes_provider_timeout_error(provider: ShippingRateProvider) -> None:
    with pytest.raises(ProviderTimeoutError):
        await provider.get_quote(REQUEST)


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "provider",
    [
        ProviderAAdapter(returning({"currency": "USD"})),  # missing price
        ProviderAAdapter(returning({"price": "120", "currency": "USD"})),  # price is text
        ProviderAAdapter(returning({"price": -5, "currency": "USD"})),  # negative
        ProviderAAdapter(returning({"price": 1.234, "currency": "USD"})),  # fraction of a cent
        ProviderBAdapter(returning({"total_amount": 12000, "currency_code": "USD"})),  # missing minor_units
        ProviderBAdapter(returning({"total_amount": 120.5, "currency_code": "USD", "minor_units": True})),  # half a cent
    ],
)
async def test_malformed_payload_is_rejected(provider: ShippingRateProvider) -> None:
    with pytest.raises(MalformedPayloadError):
        await provider.get_quote(REQUEST)

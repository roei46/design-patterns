import dataclasses

import pytest

from patterns.chain_of_responsibility.request_chain import (
    APIRequest,
    AuthHandler,
    EligibilityHandler,
    RateLimitHandler,
    Rejection,
    RequestChain,
    ValidationHandler,
)

VALID = APIRequest(token="valid-token", user_id="u1", body="hello", is_premium=True)


def make_chain(rate_limiter: RateLimitHandler) -> RequestChain:
    return RequestChain([AuthHandler(), ValidationHandler(), rate_limiter, EligibilityHandler()])


class SpyHandler:
    """A fake handler that writes its name to a shared list, then passes."""

    def __init__(self, name: str, calls: list[str]) -> None:
        self._name = name
        self._calls = calls

    async def check(self, request: APIRequest) -> Rejection | None:
        self._calls.append(self._name)
        return None


@pytest.mark.asyncio
async def test_valid_request_is_accepted() -> None:
    result = await make_chain(RateLimitHandler(limit=10)).run(VALID)

    assert result.accepted
    assert result.rejection is None


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("request_", "limit", "expected"),
    [
        (dataclasses.replace(VALID, token=None), 10, Rejection.UNAUTHORIZED),
        (dataclasses.replace(VALID, body=""), 10, Rejection.INVALID_REQUEST),
        (VALID, 0, Rejection.RATE_LIMITED),
        (dataclasses.replace(VALID, is_premium=False), 10, Rejection.NOT_ELIGIBLE),
    ],
)
async def test_each_stage_can_reject(request_: APIRequest, limit: int, expected: Rejection) -> None:
    result = await make_chain(RateLimitHandler(limit=limit)).run(request_)

    assert not result.accepted
    assert result.rejection == expected


@pytest.mark.asyncio
async def test_rate_limit_rejects_after_limit() -> None:
    chain = make_chain(RateLimitHandler(limit=2))

    results = [await chain.run(VALID) for _ in range(3)]

    assert [r.rejection for r in results] == [None, None, Rejection.RATE_LIMITED]


@pytest.mark.asyncio
async def test_handlers_run_in_order_once_each() -> None:
    calls: list[str] = []
    chain = RequestChain([SpyHandler(name, calls) for name in ["auth", "validation", "rate_limit", "eligibility"]])

    await chain.run(VALID)

    assert calls == ["auth", "validation", "rate_limit", "eligibility"]


@pytest.mark.asyncio
async def test_rejection_skips_later_side_effects() -> None:
    rate_limiter = RateLimitHandler(limit=10)

    result = await make_chain(rate_limiter).run(dataclasses.replace(VALID, token="wrong"))

    assert result.rejection == Rejection.UNAUTHORIZED
    assert rate_limiter.count_for("u1") == 0  # rate limiter never ran

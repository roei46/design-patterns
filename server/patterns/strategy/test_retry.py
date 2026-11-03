import pytest

from patterns.strategy.retry import (
    ExponentialBackoff,
    FixedDelay,
    HTTPError,
    NoRetry,
    execute_with_retry,
)


class FakeSleep:
    """Records each delay instead of waiting."""

    def __init__(self) -> None:
        self.delays: list[int] = []

    async def __call__(self, ms: int) -> None:
        self.delays.append(ms)


class FlakyOperation:
    """Raises the given errors one by one, then returns "ok"."""

    def __init__(self, errors: list[Exception]) -> None:
        self._errors = errors
        self.calls = 0

    async def __call__(self) -> str:
        self.calls += 1
        if self.calls <= len(self._errors):
            raise self._errors[self.calls - 1]
        return "ok"


@pytest.mark.asyncio
async def test_success_on_first_try_does_not_sleep() -> None:
    operation, sleep = FlakyOperation([]), FakeSleep()

    result = await execute_with_retry(operation, FixedDelay(max_attempts=3, delay_ms=100), sleep)

    assert result == "ok"
    assert operation.calls == 1
    assert sleep.delays == []


@pytest.mark.asyncio
async def test_no_retry_fails_immediately() -> None:
    operation, sleep = FlakyOperation([HTTPError(500)]), FakeSleep()

    with pytest.raises(HTTPError):
        await execute_with_retry(operation, NoRetry(), sleep)

    assert operation.calls == 1
    assert sleep.delays == []


@pytest.mark.asyncio
async def test_fixed_delay_retries_then_succeeds() -> None:
    operation, sleep = FlakyOperation([HTTPError(500), HTTPError(500)]), FakeSleep()

    result = await execute_with_retry(operation, FixedDelay(max_attempts=3, delay_ms=100), sleep)

    assert result == "ok"
    assert operation.calls == 3
    assert sleep.delays == [100, 100]


@pytest.mark.asyncio
async def test_exponential_backoff_doubles_and_caps() -> None:
    operation, sleep = FlakyOperation([HTTPError(503)] * 4), FakeSleep()
    strategy = ExponentialBackoff(max_attempts=5, base_delay_ms=100, max_delay_ms=500)

    result = await execute_with_retry(operation, strategy, sleep)

    assert result == "ok"
    assert operation.calls == 5
    assert sleep.delays == [100, 200, 400, 500]  # 800 capped to 500


@pytest.mark.asyncio
async def test_stops_at_max_attempts() -> None:
    operation, sleep = FlakyOperation([HTTPError(500)] * 10), FakeSleep()

    with pytest.raises(HTTPError):
        await execute_with_retry(operation, FixedDelay(max_attempts=3, delay_ms=100), sleep)

    assert operation.calls == 3
    assert sleep.delays == [100, 100]


@pytest.mark.asyncio
async def test_429_is_retried() -> None:
    operation, sleep = FlakyOperation([HTTPError(429)]), FakeSleep()

    result = await execute_with_retry(operation, FixedDelay(max_attempts=3, delay_ms=100), sleep)

    assert result == "ok"
    assert operation.calls == 2


@pytest.mark.asyncio
@pytest.mark.parametrize("error", [HTTPError(400), HTTPError(404), ValueError("bug")])
async def test_non_retryable_errors_are_not_retried(error: Exception) -> None:
    operation, sleep = FlakyOperation([error]), FakeSleep()

    with pytest.raises(type(error)):
        await execute_with_retry(operation, FixedDelay(max_attempts=3, delay_ms=100), sleep)

    assert operation.calls == 1
    assert sleep.delays == []


def test_jitter_stays_in_range() -> None:
    strategy = ExponentialBackoff(max_attempts=5, base_delay_ms=100, max_delay_ms=10_000, jitter_ms=50)

    delays = [strategy.next_delay_ms(1) for _ in range(200)]

    assert all(100 <= d <= 150 for d in delays)

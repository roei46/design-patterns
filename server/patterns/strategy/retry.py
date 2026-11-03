import asyncio
import random
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from typing import Protocol


class HTTPError(Exception):
    """An HTTP failure. 429 (rate limited) and 5xx (server errors) are worth retrying."""

    def __init__(self, status_code: int) -> None:
        super().__init__(f"HTTP {status_code}")
        self.status_code = status_code

    @property
    def is_retryable(self) -> bool:
        return self.status_code == 429 or self.status_code >= 500


class RetryStrategy(Protocol):
    """Attempt numbering is 1-based: attempt 1 = the first call.
    After attempt N fails, the loop asks should_retry(error, N) and next_delay_ms(N)."""

    def should_retry(self, error: Exception, attempt: int) -> bool: ...

    def next_delay_ms(self, attempt: int) -> int: ...


def _is_retryable(error: Exception) -> bool:
    return isinstance(error, HTTPError) and error.is_retryable


class NoRetry:
    def should_retry(self, error: Exception, attempt: int) -> bool:
        return False

    def next_delay_ms(self, attempt: int) -> int:
        return 0


@dataclass(frozen=True)
class FixedDelay:
    max_attempts: int
    delay_ms: int

    def should_retry(self, error: Exception, attempt: int) -> bool:
        return attempt < self.max_attempts and _is_retryable(error)

    def next_delay_ms(self, attempt: int) -> int:
        return self.delay_ms


@dataclass(frozen=True)
class ExponentialBackoff:
    """Delay = base_delay_ms * 2^(attempt-1), capped at max_delay_ms, plus random 0..jitter_ms."""

    max_attempts: int
    base_delay_ms: int
    max_delay_ms: int
    jitter_ms: int = 0

    def should_retry(self, error: Exception, attempt: int) -> bool:
        return attempt < self.max_attempts and _is_retryable(error)

    def next_delay_ms(self, attempt: int) -> int:
        delay = min(
            self.base_delay_ms * (1 << (attempt - 1)), self.max_delay_ms
        )  # 1 << n = 2^n
        return delay + random.randint(0, self.jitter_ms)


async def real_sleep(ms: int) -> None:
    await asyncio.sleep(ms / 1000)


async def execute_with_retry[T](
    operation: Callable[[], Awaitable[T]],
    strategy: RetryStrategy,
    sleep: Callable[[int], Awaitable[None]] = real_sleep,
) -> T:
    """Calls operation(), retrying as the strategy says. Tests pass a fake sleep so nothing really waits."""
    attempt = 1
    while True:
        try:
            return await operation()
        except Exception as error:
            if not strategy.should_retry(error, attempt):
                raise
            await sleep(strategy.next_delay_ms(attempt))
            attempt += 1

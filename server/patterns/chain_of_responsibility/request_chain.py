import threading
from dataclasses import dataclass
from enum import StrEnum
from typing import Protocol


@dataclass(frozen=True)
class APIRequest:
    token: str | None
    user_id: str
    body: str
    is_premium: bool


class Rejection(StrEnum):
    UNAUTHORIZED = "unauthorized"
    INVALID_REQUEST = "invalid_request"
    RATE_LIMITED = "rate_limited"
    NOT_ELIGIBLE = "not_eligible"


@dataclass(frozen=True)
class ChainResult:
    """rejection is None when every handler passed."""

    rejection: Rejection | None = None

    @property
    def accepted(self) -> bool:
        return self.rejection is None


class RequestHandler(Protocol):
    async def check(self, request: APIRequest) -> Rejection | None:
        """Return a Rejection to stop the chain, or None to pass to the next handler."""
        ...


class AuthHandler:
    async def check(self, request: APIRequest) -> Rejection | None:
        if request.token != "valid-token":
            return Rejection.UNAUTHORIZED
        return None


class ValidationHandler:
    async def check(self, request: APIRequest) -> Rejection | None:
        if not request.body:
            return Rejection.INVALID_REQUEST
        return None


class RateLimitHandler:
    """Counts requests per user. The only handler with state (a side effect)."""

    def __init__(self, limit: int) -> None:
        self._limit = limit
        self._counts: dict[str, int] = {}
        self._lock = threading.Lock()

    def count_for(self, user_id: str) -> int:
        return self._counts.get(user_id, 0)

    async def check(self, request: APIRequest) -> Rejection | None:
        with self._lock:
            self._counts[request.user_id] = self.count_for(request.user_id) + 1
            count = self._counts[request.user_id]
        if count > self._limit:
            return Rejection.RATE_LIMITED
        return None


class EligibilityHandler:
    async def check(self, request: APIRequest) -> Rejection | None:
        if not request.is_premium:
            return Rejection.NOT_ELIGIBLE
        return None


class RequestChain:
    """Runs handlers in order and stops at the first rejection.
    Handlers never call "next" themselves, so they can't call it twice."""

    def __init__(self, handlers: list[RequestHandler]) -> None:
        self._handlers = tuple(handlers)  # tuple: the order can't change later

    async def run(self, request: APIRequest) -> ChainResult:
        for handler in self._handlers:
            rejection = await handler.check(request)
            if rejection is not None:
                return ChainResult(rejection)
        return ChainResult()

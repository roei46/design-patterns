import threading
from dataclasses import dataclass
from typing import ClassVar


@dataclass(frozen=True)
class AppSettings:
    """Immutable settings. frozen=True: assigning a field raises an error."""

    api_base_url: str
    request_timeout_ms: int
    max_retries: int


class SettingsNotLoadedError(Exception):
    """current() was called before load()."""


class ConflictingReinitError(Exception):
    """load() was called again with different values."""


class SettingsProvider:
    """Singleton: one shared settings holder per process (not shared between processes)."""

    _instance: ClassVar["SettingsProvider | None"] = None
    _instance_lock: ClassVar[threading.Lock] = threading.Lock()

    def __init__(self) -> None:
        # Python has no private init. Use get_instance(), never SettingsProvider().
        self._settings: AppSettings | None = None
        self._lock = threading.Lock()

    @classmethod
    def get_instance(cls) -> "SettingsProvider":
        """Python's version of Swift's `static let shared`."""
        with cls._instance_lock:
            if cls._instance is None:
                cls._instance = cls()
            return cls._instance

    def load(self, settings: AppSettings) -> None:
        """First call stores the settings. Same values again: no-op. Different values: raises."""
        with self._lock:
            if self._settings is None:
                self._settings = settings
            elif self._settings != settings:
                raise ConflictingReinitError("settings are already loaded with different values")

    def current(self) -> AppSettings:
        with self._lock:
            if self._settings is None:
                raise SettingsNotLoadedError("call load() first")
            return self._settings

    def reset_for_testing(self) -> None:
        """Test-only: clears the loaded settings."""
        with self._lock:
            self._settings = None

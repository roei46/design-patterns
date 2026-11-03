import dataclasses

import pytest

from patterns.singleton.settings_provider import (
    AppSettings,
    ConflictingReinitError,
    SettingsNotLoadedError,
    SettingsProvider,
)

SETTINGS = AppSettings(api_base_url="https://api.example.com", request_timeout_ms=5_000, max_retries=3)


@pytest.fixture(autouse=True)
def provider() -> SettingsProvider:
    """Runs before every test (like setUp): each test starts with no settings loaded."""
    instance = SettingsProvider.get_instance()
    instance.reset_for_testing()
    return instance


def test_get_instance_returns_same_object() -> None:
    assert SettingsProvider.get_instance() is SettingsProvider.get_instance()


def test_load_then_read(provider: SettingsProvider) -> None:
    provider.load(SETTINGS)

    assert provider.current() == SETTINGS


def test_loading_same_values_twice_is_a_no_op(provider: SettingsProvider) -> None:
    provider.load(SETTINGS)
    provider.load(SETTINGS)

    assert provider.current() == SETTINGS


def test_reading_before_load_raises(provider: SettingsProvider) -> None:
    with pytest.raises(SettingsNotLoadedError):
        provider.current()


def test_conflicting_reinit_is_rejected_and_keeps_original(provider: SettingsProvider) -> None:
    provider.load(SETTINGS)
    conflicting = dataclasses.replace(SETTINGS, max_retries=5)

    with pytest.raises(ConflictingReinitError):
        provider.load(conflicting)

    assert provider.current() == SETTINGS


def test_settings_cannot_be_changed() -> None:
    with pytest.raises(dataclasses.FrozenInstanceError):
        SETTINGS.max_retries = 10  # type: ignore[misc]

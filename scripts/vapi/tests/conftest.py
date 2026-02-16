"""Pytest fixtures for Vapi tests."""

import pytest

from vapi.client import VapiClient


@pytest.fixture
def sample_assistant() -> dict:
    """Sample assistant object from Vapi API."""
    return {
        "id": "asst_abc123",
        "name": "Ghostwriter",
        "model": {"provider": "openai", "model": "gpt-4o-mini"},
    }


@pytest.fixture
def env_vars(monkeypatch: pytest.MonkeyPatch) -> None:
    """Set required env vars for CLI tests."""
    monkeypatch.setenv("VAPI_PRIVATE_KEY", "test-key")
    monkeypatch.setenv("BACKEND_WEBHOOK_URL", "https://webhook.example.com/")
    monkeypatch.setenv("PHONE_NUMBER_ID", "phn_test123")

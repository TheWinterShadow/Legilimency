"""Tests for config module."""

import pytest

from vapi.config import ASSISTANT_NAME, build_assistant_payload, SYSTEM_PROMPT


def test_build_assistant_payload_returns_correct_structure() -> None:
    """build_assistant_payload returns dict with required keys."""
    payload = build_assistant_payload("https://webhook.example.com/")
    assert payload["name"] == ASSISTANT_NAME
    assert payload["model"]["provider"] == "openai"
    assert payload["model"]["model"] == "gpt-4o-mini"
    assert payload["transcriber"]["provider"] == "deepgram"
    assert payload["transcriber"]["model"] == "nova-2"
    assert payload["transcriber"]["smartFormat"] is False
    assert payload["silenceTimeoutSeconds"] == 0.6
    assert payload["serverUrl"] == "https://webhook.example.com/"
    assert "end-of-call-report" in payload["serverMessages"]


def test_build_assistant_payload_includes_system_prompt() -> None:
    """build_assistant_payload includes system prompt in model messages."""
    payload = build_assistant_payload("https://x.com/")
    messages = payload["model"]["messages"]
    assert len(messages) == 1
    assert messages[0]["role"] == "system"
    assert messages[0]["content"] == SYSTEM_PROMPT


def test_build_assistant_payload_includes_voice() -> None:
    """build_assistant_payload includes voice config."""
    payload = build_assistant_payload("https://x.com/")
    assert payload["voice"]["provider"] == "openai"
    assert payload["voice"]["voice"] == "alloy"
    assert payload["voice"]["speed"] == 1.1

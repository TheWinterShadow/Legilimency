"""Tests for deploy orchestration."""

from unittest.mock import MagicMock

import pytest

from vapi.deploy import run


def test_run_creates_assistant_when_not_found() -> None:
    """run creates assistant when none exists with matching name."""
    client = MagicMock()
    client.list_assistants.return_value = []
    client.create_assistant.return_value = {"id": "asst_new"}

    result = run(
        client=client,
        server_url="https://webhook.example.com/",
        phone_number_id="phn_1",
        dry_run=False,
    )

    assert result == "asst_new"
    client.create_assistant.assert_called_once()
    client.update_assistant.assert_not_called()
    client.link_phone_number.assert_called_once_with("phn_1", "asst_new")


def test_run_updates_assistant_when_found() -> None:
    """run updates assistant when one exists with matching name."""
    client = MagicMock()
    client.list_assistants.return_value = [{"id": "asst_existing", "name": "Ghostwriter"}]

    result = run(
        client=client,
        server_url="https://webhook.example.com/",
        phone_number_id="phn_1",
        dry_run=False,
    )

    assert result == "asst_existing"
    call_args = client.update_assistant.call_args
    assert call_args[0][0] == "asst_existing"
    assert "serverUrl" in call_args[0][1]
    client.create_assistant.assert_not_called()
    client.link_phone_number.assert_called_once_with("phn_1", "asst_existing")


def test_run_dry_run_does_not_call_api() -> None:
    """run with dry_run=True does not create, update, or link."""
    client = MagicMock()

    result = run(
        client=client,
        server_url="https://webhook.example.com/",
        phone_number_id="phn_1",
        dry_run=True,
    )

    assert result == "dry-run"
    client.list_assistants.assert_not_called()
    client.create_assistant.assert_not_called()
    client.update_assistant.assert_not_called()
    client.link_phone_number.assert_not_called()

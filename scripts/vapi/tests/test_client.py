"""Tests for Vapi API client."""

import pytest
import requests_mock

from vapi.client import VapiClient
from vapi.exceptions import VapiAPIError


def test_list_assistants_success(requests_mock: requests_mock.Mocker) -> None:
    """list_assistants returns list from API."""
    requests_mock.get(
        "https://api.vapi.ai/assistant",
        json=[{"id": "asst_1", "name": "Ghostwriter"}],
    )
    client = VapiClient(api_key="test-key")
    result = client.list_assistants()
    assert len(result) == 1
    assert result[0]["name"] == "Ghostwriter"


def test_list_assistants_error(requests_mock: requests_mock.Mocker) -> None:
    """list_assistants raises VapiAPIError on 4xx."""
    requests_mock.get("https://api.vapi.ai/assistant", status_code=401)
    client = VapiClient(api_key="bad-key")
    with pytest.raises(VapiAPIError) as exc_info:
        client.list_assistants()
    assert exc_info.value.status_code == 401


def test_create_assistant_success(requests_mock: requests_mock.Mocker) -> None:
    """create_assistant returns created assistant."""
    requests_mock.post(
        "https://api.vapi.ai/assistant",
        json={"id": "asst_new", "name": "Ghostwriter"},
    )
    client = VapiClient(api_key="test-key")
    result = client.create_assistant({"name": "Ghostwriter"})
    assert result["id"] == "asst_new"


def test_update_assistant_success(requests_mock: requests_mock.Mocker) -> None:
    """update_assistant returns updated assistant."""
    requests_mock.patch(
        "https://api.vapi.ai/assistant/asst_1",
        json={"id": "asst_1", "name": "Ghostwriter"},
    )
    client = VapiClient(api_key="test-key")
    result = client.update_assistant("asst_1", {"name": "Ghostwriter"})
    assert result["id"] == "asst_1"


def test_link_phone_number_success(requests_mock: requests_mock.Mocker) -> None:
    """link_phone_number succeeds."""
    requests_mock.patch(
        "https://api.vapi.ai/phone-number/phn_1",
        json={"id": "phn_1", "assistantId": "asst_1"},
    )
    client = VapiClient(api_key="test-key")
    result = client.link_phone_number("phn_1", "asst_1")
    assert result["assistantId"] == "asst_1"
    assert requests_mock.last_request.json() == {"assistantId": "asst_1"}

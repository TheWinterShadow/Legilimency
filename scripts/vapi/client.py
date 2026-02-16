"""
Vapi API client.

Handles HTTP calls to the Vapi REST API only.
No business logic; returns raw responses.
"""

import logging
from typing import Any

import requests

from .exceptions import VapiAPIError

logger = logging.getLogger(__name__)

VAPI_BASE = "https://api.vapi.ai"


class VapiClient:
    """Client for the Vapi REST API."""

    def __init__(self, api_key: str, base_url: str = VAPI_BASE) -> None:
        self._session = requests.Session()
        self._session.headers.update(
            {
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            }
        )
        self._base_url = base_url.rstrip("/")

    def list_assistants(self) -> list[dict[str, Any]]:
        """
        List all assistants from the Vapi API.

        Returns:
            List of assistant objects from the API.

        Raises:
            VapiAPIError: If the API request fails.
        """
        url = f"{self._base_url}/assistant"
        resp = self._session.get(url)
        if not resp.ok:
            raise VapiAPIError(
                f"List assistants failed: {resp.text}",
                status_code=resp.status_code,
            )
        data = resp.json()
        return data if isinstance(data, list) else []

    def create_assistant(self, payload: dict[str, Any]) -> dict[str, Any]:
        """
        Create a new assistant.

        Args:
            payload: Assistant config dict.

        Returns:
            Created assistant object from the API.

        Raises:
            VapiAPIError: If the API request fails.
        """
        url = f"{self._base_url}/assistant"
        resp = self._session.post(url, json=payload)
        if not resp.ok:
            raise VapiAPIError(
                f"Create assistant failed: {resp.text}",
                status_code=resp.status_code,
            )
        return resp.json()

    def update_assistant(self, assistant_id: str, payload: dict[str, Any]) -> dict[str, Any]:
        """
        Update an existing assistant.

        Args:
            assistant_id: The assistant ID.
            payload: Partial assistant config dict.

        Returns:
            Updated assistant object from the API.

        Raises:
            VapiAPIError: If the API request fails.
        """
        url = f"{self._base_url}/assistant/{assistant_id}"
        resp = self._session.patch(url, json=payload)
        if not resp.ok:
            raise VapiAPIError(
                f"Update assistant failed: {resp.text}",
                status_code=resp.status_code,
            )
        return resp.json()

    def link_phone_number(self, phone_number_id: str, assistant_id: str) -> dict[str, Any]:
        """
        Link a phone number to an assistant.

        Args:
            phone_number_id: The phone number ID.
            assistant_id: The assistant ID to link.

        Returns:
            Updated phone number object from the API.

        Raises:
            VapiAPIError: If the API request fails.
        """
        url = f"{self._base_url}/phone-number/{phone_number_id}"
        resp = self._session.patch(url, json={"assistantId": assistant_id})
        if not resp.ok:
            raise VapiAPIError(
                f"Link phone number failed: {resp.text}",
                status_code=resp.status_code,
            )
        return resp.json()

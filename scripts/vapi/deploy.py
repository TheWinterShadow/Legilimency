"""
Deployment orchestration for Vapi assistant.

Resolves assistant by name, creates or updates, and links phone number.
Accepts VapiClient for dependency injection (testability).
"""

import logging
from typing import Protocol

from .config import ASSISTANT_NAME, build_assistant_payload

logger = logging.getLogger(__name__)


class VapiClientProtocol(Protocol):
    """Protocol for Vapi API client (for typing and mocking)."""

    def list_assistants(self) -> list[dict]:
        ...

    def create_assistant(self, payload: dict) -> dict:
        ...

    def update_assistant(self, assistant_id: str, payload: dict) -> dict:
        ...

    def link_phone_number(self, phone_number_id: str, assistant_id: str) -> dict:
        ...


def run(
    client: VapiClientProtocol,
    server_url: str,
    phone_number_id: str,
    dry_run: bool = False,
) -> str:
    """
    Deploy the Ghostwriter assistant to Vapi.

    Resolves assistant by name, creates if not found or updates if found,
    then links the phone number.

    Args:
        client: Vapi API client.
        server_url: Webhook URL for end-of-call-report.
        phone_number_id: Phone number ID to link to the assistant.
        dry_run: If True, validate only; do not create/update/link.

    Returns:
        The assistant ID (created or updated).

    Raises:
        VapiAPIError: If any API call fails.
    """
    payload = build_assistant_payload(server_url)

    if dry_run:
        logger.info("Dry run: would deploy assistant %s", ASSISTANT_NAME)
        return "dry-run"

    # Resolve assistant
    assistants = client.list_assistants()
    existing = next((a for a in assistants if a.get("name") == ASSISTANT_NAME), None)

    if existing:
        assistant_id = existing["id"]
        logger.info("Updating existing assistant %s", assistant_id)
        client.update_assistant(assistant_id, payload)
    else:
        logger.info("Creating new assistant %s", ASSISTANT_NAME)
        created = client.create_assistant(payload)
        assistant_id = created["id"]

    # Link phone number
    logger.info("Linking phone number %s to assistant %s", phone_number_id, assistant_id)
    client.link_phone_number(phone_number_id, assistant_id)

    return assistant_id

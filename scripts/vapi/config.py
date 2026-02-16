"""
Assistant configuration for Ghostwriter.

Builds the Vapi API payload from version-controlled config.
Secrets (serverUrl) are injected at runtime from environment.
"""

from typing import Any


SYSTEM_PROMPT = """You are a technical ghostwriter for Elijah. Ask ONE short question at a time. Probe for technical details. When Elijah says 'That's it', say 'Documentation saved' and end the call."""

ASSISTANT_NAME = "Ghostwriter"


def build_assistant_payload(server_url: str) -> dict[str, Any]:
    """
    Build the assistant creation/update payload for the Vapi API.

    Args:
        server_url: Webhook URL for end-of-call-report (from BACKEND_WEBHOOK_URL).

    Returns:
        Dict suitable for POST /assistant or PATCH /assistant/{id}.
    """
    return {
        "name": ASSISTANT_NAME,
        "model": {
            "provider": "openai",
            "model": "gpt-4o-mini",
            "messages": [
                {
                    "role": "system",
                    "content": SYSTEM_PROMPT,
                }
            ],
        },
        "transcriber": {
            "provider": "deepgram",
            "model": "nova-2",
            "smartFormat": False,
        },
        "silenceTimeoutSeconds": 0.6,
        "voice": {
            "provider": "openai",
            "voice": "alloy",
            "speed": 1.1,
        },
        "serverUrl": server_url,
        "serverMessages": ["end-of-call-report"],
    }

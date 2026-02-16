"""
Vapi.ai webhook handler for Legilimency/Ghostwriter.

Processes end-of-call-report webhooks: validates secret token, formats transcript
to Markdown, and uploads to S3.
"""

import json
import logging
import os
from datetime import datetime

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client("s3")


def lambda_handler(event: dict, context: object) -> dict:
    """
    Handle Vapi webhook POST request.

    Args:
        event: Lambda Function URL event (headers, body).
        context: Lambda context (unused).

    Returns:
        HTTP response dict with statusCode and body.
    """
    # 1. Validate secret token
    headers = event.get("headers", {}) or {}
    if isinstance(headers, str):
        headers = json.loads(headers) if headers else {}
    token = headers.get("x-vapi-secret") or headers.get("X-Vapi-Secret")
    if token != os.environ.get("SECRET_TOKEN"):
        logger.warning("Unauthorized access attempt")
        return _response(401, "Unauthorized")

    # 2. Parse Vapi payload
    try:
        body = json.loads(event.get("body", "{}"))
        message = body.get("message", {})

        if message.get("type") != "end-of-call-report":
            return _response(200, "Ignored event type")

        # 3. Extract data
        call_id = message.get("call", {}).get("id", "unknown-id")
        transcript = message.get("transcript", "No transcript provided.")
        summary = message.get("summary", "No summary provided.")
        recording_url = message.get("recordingUrl", "")

        # 4. Format Markdown
        now = datetime.now()
        date_str = now.strftime("%Y-%m-%d")
        time_str = now.strftime("%H:%M")
        filename = f"inbox/Interview-{date_str}-{call_id[:8]}.md"

        markdown_content = f"""---
id: {call_id}
date: {date_str} {time_str}
type: voice-note
tags: [interview, inbox, ghostwriter]
recording: {recording_url}
---

# Auto-Generated Interview ({date_str})

## Summary
{summary}

## Transcript
{transcript}
"""

        # 5. Upload to S3
        bucket_name = os.environ["BUCKET_NAME"]
        s3.put_object(
            Bucket=bucket_name,
            Key=filename,
            Body=markdown_content,
            ContentType="text/markdown",
        )

        logger.info("Successfully saved to %s", filename)
        return _response(200, json.dumps(f"Successfully saved to {filename}"))

    except json.JSONDecodeError as e:
        logger.exception("JSON parse error: %s", e)
        return _response(500, "Internal Server Error")
    except Exception as e:
        logger.exception("Error processing webhook: %s", e)
        return _response(500, "Internal Server Error")


def _response(status_code: int, body: str) -> dict:
    """Build HTTP response dict."""
    return {
        "statusCode": status_code,
        "body": body if isinstance(body, str) else json.dumps(body),
    }

#!/usr/bin/env python3
"""
CLI entry point for Vapi assistant deployment.

Usage:
    python cli.py           # deploy
    python cli.py --dry-run # validate only
"""

import argparse
import logging
import os
import sys

from .client import VapiClient
from .deploy import run
from .exceptions import MissingEnvError, VapiError

logging.basicConfig(
    level=logging.INFO,
    format="%(levelname)s: %(message)s",
)
logger = logging.getLogger(__name__)


def _get_env(name: str) -> str:
    """Get required env var or raise MissingEnvError."""
    value = os.environ.get(name)
    if not value:
        raise MissingEnvError(name)
    return value


def main() -> int:
    """Run the CLI. Returns 0 on success, 1 on failure."""
    parser = argparse.ArgumentParser(description="Deploy Ghostwriter assistant to Vapi")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate config and API connectivity without making changes",
    )
    args = parser.parse_args()

    try:
        api_key = _get_env("VAPI_PRIVATE_KEY")
        server_url = _get_env("BACKEND_WEBHOOK_URL")
        phone_number_id = _get_env("PHONE_NUMBER_ID")
    except MissingEnvError as e:
        logger.error("%s", e)
        return 1

    client = VapiClient(api_key)
    try:
        assistant_id = run(
            client=client,
            server_url=server_url,
            phone_number_id=phone_number_id,
            dry_run=args.dry_run,
        )
        logger.info("Done. Assistant ID: %s", assistant_id)
        return 0
    except VapiError as e:
        logger.error("%s", e)
        return 1


if __name__ == "__main__":
    sys.exit(main())

# Vapi Assistant Deployment

Manages the Ghostwriter assistant and phone number configuration on Vapi.ai via the REST API.

## Required Environment Variables

- `VAPI_PRIVATE_KEY` — Vapi API key (from [dashboard.vapi.ai](https://dashboard.vapi.ai))
- `BACKEND_WEBHOOK_URL` — AWS Lambda Function URL (from Terraform output)
- `PHONE_NUMBER_ID` — Existing Vapi phone number ID to link

## Local Usage

From the `scripts/` directory:

```bash
cd scripts
pip install -r vapi/requirements.txt
export VAPI_PRIVATE_KEY="your-key"
export BACKEND_WEBHOOK_URL="https://xxx.lambda-url.us-east-1.on.aws/"
export PHONE_NUMBER_ID="phn_xxx"
python -m vapi.cli           # deploy
python -m vapi.cli --dry-run # validate only
```

## Running Tests

```bash
cd scripts
pip install -r vapi/requirements-dev.txt
pytest vapi/tests/ -v --cov=vapi --cov-omit="vapi/tests/*"
```

## Adding New Assistant Settings

Edit `config.py` and update `build_assistant_payload()`. The payload is sent to the Vapi API on create/update.

"""Custom exceptions for Vapi deployment scripts."""


class VapiError(Exception):
    """Base exception for Vapi-related errors."""


class VapiAPIError(VapiError):
    """Raised when the Vapi API returns an error."""

    def __init__(self, message: str, status_code: int | None = None) -> None:
        self.status_code = status_code
        super().__init__(message)


class ConfigError(VapiError):
    """Raised when configuration is invalid."""


class MissingEnvError(VapiError):
    """Raised when a required environment variable is missing."""

    def __init__(self, var_name: str) -> None:
        super().__init__(f"Missing required environment variable: {var_name}")

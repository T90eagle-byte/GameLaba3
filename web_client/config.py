from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

try:
    from dotenv import load_dotenv
except ImportError:  # pragma: no cover - keeps config importable before deps install
    load_dotenv = None


PROJECT_ROOT = Path(__file__).resolve().parents[1]
ENV_PATH = PROJECT_ROOT / "python_client" / ".env"


@dataclass(frozen=True)
class OracleSettings:
    host: str
    port: int
    user: str
    password: str
    service_name: str | None
    sid: str | None


@dataclass(frozen=True)
class WebConfig:
    oracle: OracleSettings
    secret_key: str
    host: str = "127.0.0.1"
    port: int = 8000
    debug: bool = False


def _parse_env_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        return values

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def _load_env_values() -> dict[str, str]:
    if load_dotenv is not None:
        load_dotenv(ENV_PATH, override=False)

    file_values = _parse_env_file(ENV_PATH)
    merged = dict(file_values)
    for key in (
        "ORACLE_HOST",
        "ORACLE_PORT",
        "ORACLE_SERVICE",
        "ORACLE_SID",
        "ORACLE_USER",
        "ORACLE_PASSWORD",
        "FLASK_SECRET_KEY",
        "FLASK_HOST",
        "FLASK_PORT",
        "FLASK_DEBUG",
    ):
        if os.getenv(key) is not None:
            merged[key] = os.getenv(key, "")
    return merged


def load_config() -> WebConfig:
    values = _load_env_values()
    service_name = values.get("ORACLE_SERVICE") or None
    sid = values.get("ORACLE_SID") or None

    oracle = OracleSettings(
        host=values.get("ORACLE_HOST", "localhost"),
        port=int(values.get("ORACLE_PORT", "1521")),
        user=values.get("ORACLE_USER", "biosborka"),
        password=values.get("ORACLE_PASSWORD", ""),
        service_name=service_name,
        sid=sid,
    )

    secret_key = values.get("FLASK_SECRET_KEY") or "dev-only-change-me-biosborka"
    debug = values.get("FLASK_DEBUG", "0").lower() in {"1", "true", "yes", "on"}

    return WebConfig(
        oracle=oracle,
        secret_key=secret_key,
        host=values.get("FLASK_HOST", "127.0.0.1"),
        port=int(values.get("FLASK_PORT", "8000")),
        debug=debug,
    )

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv


@dataclass(frozen=True)
class OracleConfig:
    host: str
    port: int
    service: str
    user: str
    password: str


@dataclass(frozen=True)
class AppConfig:
    oracle: OracleConfig

    @classmethod
    def load(cls) -> "AppConfig":
        project_root = Path(__file__).resolve().parents[1]
        load_dotenv(project_root / ".env", override=False)

        oracle = OracleConfig(
            host=os.getenv("ORACLE_HOST", "localhost"),
            port=int(os.getenv("ORACLE_PORT", "1521")),
            service=os.getenv("ORACLE_SERVICE", "FREEPDB1"),
            user=os.getenv("ORACLE_USER", "biosborka"),
            password=os.getenv("ORACLE_PASSWORD", "Biosborka_12345"),
        )

        return cls(oracle=oracle)
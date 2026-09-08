from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
WEB_ROOT = ROOT / "web_client"
if str(WEB_ROOT) not in sys.path:
    sys.path.insert(0, str(WEB_ROOT))

from app import create_app  # noqa: E402
from config import load_config  # noqa: E402
from waitress import serve  # noqa: E402


def main() -> None:
    config = load_config()
    serve(create_app(), host=config.host, port=config.port, threads=4)


if __name__ == "__main__":
    main()

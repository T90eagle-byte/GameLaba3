from __future__ import annotations

import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
WEB_ROOT = REPO_ROOT / "web_client"
if str(WEB_ROOT) not in sys.path:
    sys.path.insert(0, str(WEB_ROOT))

from services.readiness_service import runtime_readiness  # noqa: E402


def main() -> int:
    report = runtime_readiness()
    print(json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True))
    return 0 if report["database"]["connected"] and report["schema"]["ready"] else 1


if __name__ == "__main__":
    raise SystemExit(main())

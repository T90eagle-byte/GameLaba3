from __future__ import annotations

import shutil
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
RELEASE_ROOT = REPO_ROOT / "dist" / "BioSborka"
INCLUDED_PATHS = (
    "database/ddl",
    "database/installers",
    "database/migrations",
    "database/packages",
    "database/seeds",
    "database/scripts/manage_schema.py",
    "database/scripts/run_tests.py",
    "deployment/windows",
    "web_client",
    "scripts/build_release.py",
    "README_RELEASE.md",
    ".gitattributes",
)
EXCLUDED_NAMES = {
    ".env", ".venv", "__pycache__", ".pytest_cache", ".git", ".github",
    ".idea", ".vscode", "tests", "tmp", "dist",
}
EXCLUDED_SUFFIXES = {".pyc", ".pyo", ".log", ".dmp", ".dump", ".zip"}


def should_copy(path: Path) -> bool:
    return not any(part in EXCLUDED_NAMES for part in path.parts) and path.suffix.lower() not in EXCLUDED_SUFFIXES


def copy_path(relative: str) -> None:
    source = REPO_ROOT / relative
    target = RELEASE_ROOT / relative
    if source.is_file():
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        return
    for item in source.rglob("*"):
        if item.is_file() and should_copy(item.relative_to(source)):
            destination = target / item.relative_to(source)
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(item, destination)


def validate_release() -> None:
    forbidden: list[Path] = []
    for path in RELEASE_ROOT.rglob("*"):
        relative = path.relative_to(RELEASE_ROOT)
        if not should_copy(relative):
            forbidden.append(relative)
        if path.is_file() and path.name == ".env":
            forbidden.append(relative)
        if path.is_file() and path.suffix.lower() in {".env", ".zip", ".log", ".dmp", ".dump"}:
            forbidden.append(relative)
    if forbidden:
        raise RuntimeError(f"Release содержит запрещённые файлы: {', '.join(map(str, forbidden))}")

    for path in RELEASE_ROOT.rglob("*.env.example"):
        for line in path.read_text(encoding="utf-8").splitlines():
            if line.startswith("ORACLE_PASSWORD=") and line.partition("=")[2].strip():
                raise RuntimeError(f"Release содержит непустой ORACLE_PASSWORD: {path.relative_to(RELEASE_ROOT)}")


def main() -> int:
    if RELEASE_ROOT.exists():
        shutil.rmtree(RELEASE_ROOT)
    for relative in INCLUDED_PATHS:
        copy_path(relative)
    validate_release()
    file_count = sum(1 for path in RELEASE_ROOT.rglob("*") if path.is_file())
    print(f"Release собран: {RELEASE_ROOT}")
    print(f"Файлов: {file_count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

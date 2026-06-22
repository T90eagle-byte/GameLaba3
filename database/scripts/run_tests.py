from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import oracledb

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_ENV_PATH = REPO_ROOT / "python_client" / ".env"
DEFAULT_ENV_EXAMPLE_PATH = REPO_ROOT / "python_client" / ".env.example"
PACKAGE_OBJECT_NAME = "PKG_GENETICS_GAME"

PACKAGE_FILES = [
    REPO_ROOT / "database" / "packages" / "spec" / "pkg_genetics_game.pks",
    REPO_ROOT / "database" / "packages" / "body" / "pkg_genetics_game.pkb",
]

SMOKE_TEST_FILES = [
    REPO_ROOT / "database" / "tests" / "01_auth_labs_smoke_test.sql",
    REPO_ROOT / "database" / "tests" / "02_seed_data_smoke_test.sql",
    REPO_ROOT / "database" / "tests" / "03_creature_generation_smoke_test.sql",
    REPO_ROOT / "database" / "tests" / "04_crossbreed_smoke_test.sql",
    REPO_ROOT / "database" / "tests" / "05_mutations_experiments_smoke_test.sql",
    REPO_ROOT / "database" / "tests" / "06_tasks_smoke_test.sql",
    REPO_ROOT / "database" / "tests" / "07_strict_compliance_smoke_test.sql",
    REPO_ROOT / "database" / "tests" / "08_multiuser_sessions_smoke_test.sql",
    REPO_ROOT / "database" / "tests" / "09_lr2_package_api_compat_smoke_test.sql",
]

PLSQL_START_RE = re.compile(
    r"^(declare|begin|create\s+or\s+replace\s+(package(\s+body)?|procedure|function|trigger|type(\s+body)?))\b",
    re.IGNORECASE,
)
AT_DIRECTIVE_RE = re.compile(r"^@(.+)$")


def is_sqlplus_directive(stripped_line: str) -> bool:
    normalized = stripped_line.lstrip("\ufeff").strip()
    if normalized.endswith(";"):
        normalized = normalized[:-1].strip()
    normalized = re.sub(r"\s+", " ", normalized).lower()

    if not normalized:
        return False
    if normalized == "set define off":
        return True
    if normalized in {"set verify off", "set verify on"}:
        return True
    if re.fullmatch(r"set serveroutput on( size (unlimited|\d+))?", normalized):
        return True
    if normalized.startswith("show errors"):
        return True
    if normalized.startswith("prompt"):
        return True
    if normalized.startswith("whenever "):
        return True
    return False


@dataclass(frozen=True)
class OracleSettings:
    host: str
    port: int
    user: str
    password: str
    service_name: str | None
    sid: str | None


def parse_env_file(path: Path) -> dict[str, str]:
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


def load_oracle_settings(env_path: Path) -> OracleSettings:
    values = parse_env_file(env_path)
    if not values:
        values = parse_env_file(DEFAULT_ENV_EXAMPLE_PATH)

    host = values.get("ORACLE_HOST", "localhost")
    port = int(values.get("ORACLE_PORT", "1521"))
    user = values.get("ORACLE_USER", "biosborka")
    password = values.get("ORACLE_PASSWORD", "")
    service_name = values.get("ORACLE_SERVICE") or None
    sid = values.get("ORACLE_SID") or None

    if not password:
        raise SystemExit(
            f"Oracle password is missing. Fill {env_path} or set ORACLE_PASSWORD in the selected env file."
        )

    if not service_name and not sid:
        raise SystemExit(
            f"Neither ORACLE_SERVICE nor ORACLE_SID is set in {env_path}. Add one of them before running tests."
        )

    return OracleSettings(
        host=host,
        port=port,
        user=user,
        password=password,
        service_name=service_name,
        sid=sid,
    )


def create_connection(settings: OracleSettings) -> oracledb.Connection:
    dsn_kwargs: dict[str, object] = {"host": settings.host, "port": settings.port}
    if settings.service_name:
        dsn_kwargs["service_name"] = settings.service_name
    else:
        dsn_kwargs["sid"] = settings.sid

    dsn = oracledb.makedsn(**dsn_kwargs)
    connection = oracledb.connect(user=settings.user, password=settings.password, dsn=dsn)
    connection.autocommit = True
    return connection


def drain_dbms_output(cursor: oracledb.Cursor) -> None:
    while True:
        lines_var = cursor.arrayvar(str, 200)
        count_var = cursor.var(int)
        count_var.setvalue(0, 200)
        cursor.callproc("dbms_output.get_lines", [lines_var, count_var])
        count = int(count_var.getvalue() or 0)
        if count <= 0:
            return
        for line in lines_var.getvalue()[:count]:
            if line is not None:
                print(line)


def iter_statements(path: Path) -> Iterable[tuple[str, int]]:
    current: list[str] = []
    statement_start_line = 1
    in_plsql = False

    for line_no, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        raw_line = raw_line.lstrip("\ufeff")
        stripped = raw_line.strip()

        if not stripped:
            if current:
                current.append(raw_line)
            continue

        if stripped.startswith("--") and not current:
            continue

        if not current:
            include_match = AT_DIRECTIVE_RE.match(stripped)
            if include_match:
                include_target = (path.parent / include_match.group(1).strip()).resolve()
                yield from iter_statements(include_target)
                continue

            if is_sqlplus_directive(stripped):
                continue

            statement_start_line = line_no
            if PLSQL_START_RE.match(stripped):
                in_plsql = True

        if in_plsql and stripped == "/":
            statement = "\n".join(current).strip()
            if statement:
                yield statement, statement_start_line
            current = []
            in_plsql = False
            continue

        current.append(raw_line)

        if not in_plsql and stripped.endswith(";") and not stripped.startswith("--"):
            statement = "\n".join(current).strip()
            if statement:
                yield statement, statement_start_line
            current = []

    trailing = "\n".join(current).strip()
    if trailing:
        yield trailing, statement_start_line


def execute_sql_file(connection: oracledb.Connection, path: Path) -> None:
    rel_path = path.relative_to(REPO_ROOT) if path.is_relative_to(REPO_ROOT) else path
    print(f"\n=== RUN {rel_path} ===")
    with connection.cursor() as cursor:
        cursor.callproc("dbms_output.enable", [None])
        for statement, line_no in iter_statements(path):
            try:
                cursor.execute(statement)
                drain_dbms_output(cursor)
            except Exception as exc:
                try:
                    drain_dbms_output(cursor)
                except Exception as output_exc:
                    print(f"Could not read DBMS_OUTPUT after error: {output_exc}")
                preview = statement.splitlines()[0][:120]
                raise RuntimeError(
                    f"{rel_path}:{line_no}: {exc} | statement starts with: {preview}"
                ) from exc


def print_package_status(connection: oracledb.Connection) -> None:
    print("\n=== PACKAGE STATUS ===")
    with connection.cursor() as cursor:
        cursor.execute(
            """
            select object_name, object_type, status
              from user_objects
             where object_name = :name
             order by object_type
            """,
            name=PACKAGE_OBJECT_NAME,
        )
        rows = cursor.fetchall()
        if not rows:
            print("No package objects found.")
        else:
            for object_name, object_type, status in rows:
                print(f"{object_type}: {status}")

        cursor.execute(
            """
            select name, type, line, position, text
              from user_errors
             where upper(name) = :name
             order by sequence
            """,
            name=PACKAGE_OBJECT_NAME,
        )
        errors = cursor.fetchall()
        if not errors:
            print("user_errors: clean")
        else:
            print("user_errors:")
            for name, object_type, line, position, text in errors:
                print(f"{object_type} {name} line {line}:{position} {text}")


def build_file_list(args: argparse.Namespace) -> list[Path]:
    if args.files:
        result: list[Path] = []
        for item in args.files:
            item_path = Path(item)
            if not item_path.is_absolute():
                item_path = (REPO_ROOT / item_path).resolve()
            result.append(item_path)
        return result

    files: list[Path] = []
    if args.include_package:
        files.extend(PACKAGE_FILES)
    files.extend(SMOKE_TEST_FILES)
    return files


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run Oracle package files and backend smoke-tests through python-oracledb."
    )
    parser.add_argument(
        "--env-file",
        default=str(DEFAULT_ENV_PATH),
        help="Path to .env with ORACLE_* values. Defaults to python_client/.env",
    )
    parser.add_argument(
        "--files",
        nargs="*",
        help="Explicit SQL files to run, relative to repo root or absolute paths.",
    )
    parser.add_argument(
        "--include-package",
        action="store_true",
        help="Compile package spec/body before running smoke-tests. Enabled by default when --files is not used.",
    )
    parser.add_argument(
        "--skip-package-status",
        action="store_true",
        help="Do not print package status and user_errors after execution.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the files that would run without connecting to Oracle.",
    )
    args = parser.parse_args()
    if not args.files and not args.include_package:
        args.include_package = True
    return args


def main() -> int:
    args = parse_args()
    file_list = build_file_list(args)

    print("Files to run:")
    for path in file_list:
        rel_path = path.relative_to(REPO_ROOT) if path.is_relative_to(REPO_ROOT) else path
        print(f"- {rel_path}")

    if args.dry_run:
        return 0

    env_path = Path(args.env_file)
    if not env_path.is_absolute():
        env_path = (REPO_ROOT / env_path).resolve()

    settings = load_oracle_settings(env_path)
    mode = "service_name" if settings.service_name else "sid"
    print(f"\nConnecting with {mode} mode to {settings.host}:{settings.port} as {settings.user}")

    connection = None
    try:
        connection = create_connection(settings)
        for path in file_list:
            execute_sql_file(connection, path)
        if not args.skip_package_status:
            print_package_status(connection)
        print("\nRunner finished successfully.")
        return 0
    finally:
        if connection is not None:
            connection.close()


if __name__ == "__main__":
    raise SystemExit(main())

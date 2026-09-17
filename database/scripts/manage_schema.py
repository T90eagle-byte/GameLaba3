from __future__ import annotations

import argparse
import os
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import oracledb

from run_tests import REPO_ROOT, create_connection, execute_sql_file, load_oracle_settings


DEFAULT_ENV_PATH = REPO_ROOT / "deployment" / "windows" / ".env"
FRESH_INSTALLER = REPO_ROOT / "database" / "installers" / "university_existing_schema_install.sql"
UPDATE_INSTALLER = REPO_ROOT / "database" / "installers" / "university_existing_schema_update.sql"
KNOWN_TABLES = frozenset({
    "USERS", "SESSIONS", "LABS", "GENES", "ALLELES", "MUTATIONS",
    "MUTATION_RULES", "TASKS", "TASK_MARKERS", "CREATURES", "GENOTYPES",
    "EXPERIMENTS", "LAB_MUTATIONS", "LAB_TASKS", "RATING_EVENTS",
    "REF_SPECIES_TYPES", "REF_GENE_TYPES", "REF_DOMINANCE_TYPES",
    "REF_TASK_STATUSES", "REF_EXPERIMENT_TYPES", "REF_MUTAGEN_TYPES",
    "REF_MUTATION_TYPES", "REF_TASK_DIFFICULTIES", "REF_RATING_EVENT_TYPES",
    "REF_EXPERIMENT_ECONOMICS", "REF_CREATURE_ARCHETYPES",
    "REF_ARCHETYPE_ALLELES", "REF_GENETICS_MODEL_GENES",
})
LEGACY_REQUIRED_TABLES = frozenset({
    "USERS", "SESSIONS", "LABS", "GENES", "ALLELES", "MUTATIONS",
    "MUTATION_RULES", "TASKS", "TASK_MARKERS", "CREATURES", "GENOTYPES",
    "EXPERIMENTS", "LAB_MUTATIONS", "LAB_TASKS", "RATING_EVENTS",
    "REF_SPECIES_TYPES", "REF_GENE_TYPES", "REF_DOMINANCE_TYPES",
    "REF_TASK_STATUSES", "REF_EXPERIMENT_TYPES", "REF_MUTAGEN_TYPES",
    "REF_MUTATION_TYPES", "REF_TASK_DIFFICULTIES", "REF_RATING_EVENT_TYPES",
})
PRESERVED_TABLES = ("USERS", "LABS", "CREATURES", "GENOTYPES", "EXPERIMENTS")


@dataclass(frozen=True)
class SchemaState:
    tables: frozenset[str]
    object_count: int
    install_version: int | None

    @property
    def has_biosborka_objects(self) -> bool:
        return bool(self.tables & KNOWN_TABLES)

    @property
    def is_empty(self) -> bool:
        return self.object_count == 0


def _scalar(cursor: oracledb.Cursor, sql: str, **params: object) -> int | None:
    cursor.execute(sql, params)
    row = cursor.fetchone()
    return None if row is None or row[0] is None else int(row[0])


def inspect_schema(connection: oracledb.Connection) -> SchemaState:
    with connection.cursor() as cursor:
        cursor.execute("select table_name from user_tables")
        tables = frozenset(str(row[0]).upper() for row in cursor.fetchall())
        object_count = _scalar(
            cursor,
            """
            select count(*)
              from user_objects
             where object_name not like 'BIN$%'
            """,
        ) or 0
        install_version = None
        if "APP_INSTALL_STATE" in tables:
            install_version = _scalar(
                cursor,
                "select install_version from app_install_state where install_key = 'schema'",
            )
    return SchemaState(tables=tables, object_count=object_count, install_version=install_version)


def preserved_counts(connection: oracledb.Connection) -> dict[str, int]:
    with connection.cursor() as cursor:
        return {
            table: _scalar(cursor, f"select count(*) from {table.lower()}") or 0
            for table in PRESERVED_TABLES
        }


def resolve_env_path(value: str) -> Path:
    path = Path(value).expanduser()
    if not path.is_absolute():
        path = (REPO_ROOT / path).resolve()
    if not path.exists():
        raise SystemExit(f"Файл настроек не найден: {path}. Скопируйте deployment\\windows\\.env.example в .env.")
    return path


def readiness_report(env_path: Path) -> dict[str, object]:
    web_root = REPO_ROOT / "web_client"
    if str(web_root) not in sys.path:
        sys.path.insert(0, str(web_root))
    os.environ["BIOSBORKA_ENV_FILE"] = str(env_path)
    from services.readiness_service import runtime_readiness  # noqa: PLC0415

    return runtime_readiness()


def print_validation(report: dict[str, object]) -> bool:
    database = report["database"]  # type: ignore[index]
    schema = report["schema"]  # type: ignore[index]
    if not database["connected"]:  # type: ignore[index]
        error = database.get("error") or {}  # type: ignore[union-attr]
        print(f"Connection .............. FAIL ({error.get('message', 'Oracle недоступна')})")
        return False

    package = schema["package"]  # type: ignore[index]
    contract = schema["contract"]  # type: ignore[index]
    seed = schema["seed"]  # type: ignore[index]
    integrity = seed["integrity"]  # type: ignore[index]
    print("Connection .............. OK")
    print(f"Schema version .......... {contract['actual_install_version']}")
    print(f"PACKAGE ................. {'VALID' if package['spec_valid'] else 'INVALID'}")
    print(f"PACKAGE BODY ............ {'VALID' if package['body_valid'] else 'INVALID'}")
    print(f"USER_ERRORS ............. {package['error_count']}")
    print(f"Reference data .......... {'OK' if seed['ready'] else 'FAIL'}")
    print(f"Archetypes .............. {contract['archetype_count']}")
    print(f"Templates ............... {contract['archetype_template_count']}")
    print(f"V3 model genes .......... {contract['model_membership']['v3']}")
    print(f"V3 tasks ................ {contract['v3_task_count']}")
    print(f"Hybridization ........... {'OK' if integrity['hybridization_economics'] else 'FAIL'}")
    print(f"Catalog display names ... {'OK' if integrity['catalog_display_names'] else 'FAIL'}")
    ready = bool(schema["ready"])
    print(f"Readiness ............... {'PASS' if ready else 'FAIL'}")
    return ready


def install_fresh(connection: oracledb.Connection) -> None:
    state = inspect_schema(connection)
    if state.has_biosborka_objects:
        raise SystemExit("Обнаружена существующая BioSborka. Используйте режим update.")
    if not state.is_empty:
        raise SystemExit("Схема содержит посторонние объекты. Fresh installation остановлена без изменений.")
    print("Схема пуста. Запускается безопасная fresh installation до version 15.")
    execute_sql_file(connection, FRESH_INSTALLER)


def update_existing(connection: oracledb.Connection) -> None:
    state = inspect_schema(connection)
    if not state.has_biosborka_objects:
        raise SystemExit("BioSborka в назначенной схеме не обнаружена. Для пустой schema используйте fresh.")
    if not LEGACY_REQUIRED_TABLES.issubset(state.tables):
        raise SystemExit("BioSborka schema неполная или не распознана. Update остановлен без изменений.")

    before = preserved_counts(connection)
    version = "unknown legacy" if state.install_version is None else str(state.install_version)
    print(f"Обнаружена BioSborka schema, marker: {version}. Выполняется идемпотентный update до version 15.")
    execute_sql_file(connection, UPDATE_INSTALLER)
    after = preserved_counts(connection)
    if before != after:
        raise RuntimeError(f"Update изменил защищённые игровые counts: до={before}, после={after}.")
    print("Игровые counts USERS/LABS/CREATURES/GENOTYPES/EXPERIMENTS сохранены.")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Безопасная установка, обновление и проверка схемы BioSborka.")
    parser.add_argument("command", choices=("fresh", "update", "validate"))
    parser.add_argument(
        "--env-file",
        default=str(DEFAULT_ENV_PATH),
        help="Путь к .env с ORACLE_* параметрами. По умолчанию deployment/windows/.env.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    env_path = resolve_env_path(args.env_file)
    settings = load_oracle_settings(env_path)
    mode = "service" if settings.service_name else "SID"
    print(f"Oracle connection: {settings.host}:{settings.port}, {mode}, user {settings.user}")

    with create_connection(settings) as connection:
        if args.command == "fresh":
            install_fresh(connection)
        elif args.command == "update":
            update_existing(connection)

    report = readiness_report(env_path)
    return 0 if print_validation(report) else 1


if __name__ == "__main__":
    raise SystemExit(main())

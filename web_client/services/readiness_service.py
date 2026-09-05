from __future__ import annotations

from dataclasses import dataclass
from typing import Any

import oracledb

from services.oracle import ServiceError, get_connection, map_oracle_error


PACKAGE_NAME = "PKG_GENETICS_GAME"
REQUIRED_TABLES = frozenset(
    {
        "USERS",
        "SESSIONS",
        "LABS",
        "GENES",
        "ALLELES",
        "MUTATIONS",
        "MUTATION_RULES",
        "TASKS",
        "TASK_MARKERS",
        "CREATURES",
        "GENOTYPES",
        "EXPERIMENTS",
        "LAB_MUTATIONS",
        "LAB_TASKS",
        "RATING_EVENTS",
        "REF_SPECIES_TYPES",
        "REF_GENE_TYPES",
        "REF_DOMINANCE_TYPES",
    }
)
REQUIRED_ROUTINES = frozenset(
    {
        "REGISTER_USER",
        "LOGIN_USER",
        "LOGOUT_USER",
        "RESOLVE_USER_ID_BY_TOKEN",
        "START_NEW_LAB",
        "LOAD_LAB",
        "RECOVER_LAB_ACCESS",
        "SWITCH_LAB",
        "LIST_USER_LABS",
        "DELETE_LAB",
        "RENAME_LAB",
        "EXIT_LAB",
        "GET_LAB_STATS",
        "GET_CREATURES_CURSOR",
        "GET_GENOTYPE_CURSOR",
        "PREVIEW_OFFSPRING_OPTIONS",
        "CROSSBREED",
        "SHOW_MUTATION_SHOP",
        "GET_MUTATION_TARGET_GENES_CURSOR",
        "GET_COMPATIBLE_CREATURES_FOR_MUTATION_CURSOR",
        "GET_LAB_MUTATION_QUANTITY",
        "BUY_MUTATION",
        "APPLY_MUTATION",
        "APPLY_MUTAGEN",
        "GET_EXPERIMENT_HISTORY",
        "GET_RATING_EVENTS_CURSOR",
        "GET_TASKS_CURSOR",
        "CHECK_TASK",
        "COMPLETE_TASK",
    }
)
SEED_MINIMUMS = {
    "species": ("REF_SPECIES_TYPES", 7),
    "genes": ("GENES", 12),
    "alleles": ("ALLELES", 38),
    "mutations": ("MUTATIONS", 20),
    "tasks": ("TASKS", 21),
}


@dataclass(frozen=True)
class SchemaSnapshot:
    tables: frozenset[str]
    package_statuses: dict[str, str]
    package_error_count: int
    lab_session_nullable: bool
    lab_name_not_null: bool
    task_descriptions_aligned: bool
    seed_counts: dict[str, int]
    routines: frozenset[str]


def _in_binds(prefix: str, values: list[str]) -> tuple[str, dict[str, str]]:
    params = {f"{prefix}{index}": value for index, value in enumerate(values)}
    return ", ".join(f":{key}" for key in params), params


def _fetch_names(cursor: oracledb.Cursor, sql: str, **params: object) -> frozenset[str]:
    cursor.execute(sql, params)
    return frozenset(str(row[0]).upper() for row in cursor.fetchall())


def collect_schema_snapshot(connection: oracledb.Connection) -> SchemaSnapshot:
    with connection.cursor() as cursor:
        table_values = sorted(REQUIRED_TABLES)
        table_binds, table_params = _in_binds("table", table_values)
        tables = _fetch_names(
            cursor,
            f"select table_name from user_tables where table_name in ({table_binds})",
            **table_params,
        )

        cursor.execute(
            """
            select object_type, status
              from user_objects
             where object_name = :package_name
               and object_type in ('PACKAGE', 'PACKAGE BODY')
            """,
            package_name=PACKAGE_NAME,
        )
        package_statuses = {str(kind).upper(): str(status).upper() for kind, status in cursor.fetchall()}

        cursor.execute(
            """
            select count(*)
              from user_errors
             where name = :package_name
               and type in ('PACKAGE', 'PACKAGE BODY')
            """,
            package_name=PACKAGE_NAME,
        )
        package_error_count = int(cursor.fetchone()[0] or 0)

        columns: dict[str, str] = {}
        if "LABS" in tables:
            cursor.execute(
                """
                select column_name, nullable
                  from user_tab_columns
                 where table_name = 'LABS'
                   and column_name in ('SESSION_ID', 'LAB_NAME')
                """
            )
            columns = {str(name).upper(): str(nullable).upper() for name, nullable in cursor.fetchall()}

        legacy_description_count = 1
        if "TASKS" in tables:
            cursor.execute(
                """
                select count(*)
                  from tasks
                 where description is null
                    or instr(lower(description), 'носительств') = 0
                """
            )
            legacy_description_count = int(cursor.fetchone()[0] or 0)

        seed_counts: dict[str, int] = {}
        for label, (table_name, _minimum) in SEED_MINIMUMS.items():
            if table_name in tables:
                cursor.execute(f"select count(*) from {table_name}")
                seed_counts[label] = int(cursor.fetchone()[0] or 0)
            else:
                seed_counts[label] = 0

        routines = _fetch_names(
            cursor,
            """
            select distinct procedure_name
              from user_procedures
             where object_name = :package_name
               and procedure_name is not null
            """,
            package_name=PACKAGE_NAME,
        )

    return SchemaSnapshot(
        tables=tables,
        package_statuses=package_statuses,
        package_error_count=package_error_count,
        lab_session_nullable=columns.get("SESSION_ID") == "Y",
        lab_name_not_null=columns.get("LAB_NAME") == "N",
        task_descriptions_aligned=legacy_description_count == 0,
        seed_counts=seed_counts,
        routines=routines,
    )


def schema_report(snapshot: SchemaSnapshot) -> dict[str, Any]:
    missing_tables = sorted(REQUIRED_TABLES - snapshot.tables)
    package_exists = {"PACKAGE", "PACKAGE BODY"}.issubset(snapshot.package_statuses)
    package_valid = package_exists and all(
        snapshot.package_statuses.get(kind) == "VALID" for kind in ("PACKAGE", "PACKAGE BODY")
    )
    missing_routines = sorted(REQUIRED_ROUTINES - snapshot.routines)
    seed_report = {
        label: {"count": snapshot.seed_counts.get(label, 0), "minimum": minimum}
        for label, (_table, minimum) in SEED_MINIMUMS.items()
    }
    seed_ready = all(item["count"] >= item["minimum"] for item in seed_report.values())
    migrations = {
        "session_bindings_released": snapshot.lab_session_nullable,
        "lab_names": snapshot.lab_name_not_null,
        "task_descriptions": snapshot.task_descriptions_aligned,
    }
    migrations_ready = all(migrations.values())
    api_ready = not missing_routines
    ready = all(
        (
            not missing_tables,
            package_valid,
            snapshot.package_error_count == 0,
            migrations_ready,
            seed_ready,
            api_ready,
        )
    )
    return {
        "ready": ready,
        "tables_ready": not missing_tables,
        "missing_tables": missing_tables,
        "package": {
            "exists": package_exists,
            "spec_valid": snapshot.package_statuses.get("PACKAGE") == "VALID",
            "body_valid": snapshot.package_statuses.get("PACKAGE BODY") == "VALID",
            "error_count": snapshot.package_error_count,
        },
        "migrations_ready": migrations_ready,
        "migrations": migrations,
        "seed": {"ready": seed_ready, "counts": seed_report},
        "api": {"ready": api_ready, "missing_routines": missing_routines},
    }


def classify_oracle_error_code(code: object) -> str:
    try:
        normalized_code = -abs(int(code))
    except (TypeError, ValueError):
        return "oracle"
    if normalized_code == -1017:
        return "credentials"
    if normalized_code in {-12154, -12514, -12541, -12543, -12545}:
        return "unavailable"
    return "oracle"


def _connectivity_error(exc: Exception) -> dict[str, str]:
    if isinstance(exc, ServiceError):
        return {"kind": "configuration", "message": str(exc)}
    if isinstance(exc, oracledb.DatabaseError):
        payload = exc.args[0] if exc.args else None
        code = getattr(payload, "code", None)
        kind = classify_oracle_error_code(code)
        return {"kind": kind, "message": map_oracle_error(exc)}
    return {"kind": "unavailable", "message": "Не удалось подключиться к Oracle."}


def runtime_readiness() -> dict[str, Any]:
    """Return a safe liveness, connectivity and schema-readiness report."""
    report: dict[str, Any] = {
        "app": {"ok": True},
        "database": {"connected": False, "error": None},
        "schema": {"ready": False},
    }
    try:
        with get_connection() as connection:
            report["database"] = {"connected": True, "error": None}
            report["schema"] = schema_report(collect_schema_snapshot(connection))
    except Exception as exc:  # noqa: BLE001 - health must keep the Flask process alive
        report["database"] = {"connected": False, "error": _connectivity_error(exc)}
    return report

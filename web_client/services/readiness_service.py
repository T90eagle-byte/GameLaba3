from __future__ import annotations

from dataclasses import dataclass
import re
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
        "REF_TASK_STATUSES",
        "REF_EXPERIMENT_TYPES",
        "REF_MUTAGEN_TYPES",
        "REF_MUTATION_TYPES",
        "REF_TASK_DIFFICULTIES",
        "REF_RATING_EVENT_TYPES",
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
REQUIRED_SIGNATURES: dict[str, tuple[frozenset[str], ...]] = {
    "REGISTER_USER": (frozenset({"P_USERNAME", "P_LOGIN", "P_PASSWORD", "P_USER_ID"}),),
    "LOGIN_USER": (frozenset({"P_LOGIN", "P_PASSWORD"}),),
    "START_NEW_LAB": (
        frozenset({"P_SESSION_TOKEN", "P_LAB_ID"}),
        frozenset({"P_SESSION_TOKEN", "P_LAB_NAME", "P_LAB_ID"}),
    ),
    "LOAD_LAB": (frozenset({"P_SESSION_TOKEN", "P_LAB_ID"}),),
    "GET_CREATURES_CURSOR": (frozenset({"P_LAB_ID"}),),
    "GET_GENOTYPE_CURSOR": (frozenset({"P_CREATURE_ID"}),),
    "PREVIEW_OFFSPRING_OPTIONS": (
        frozenset({"P_SESSION_TOKEN", "P_LAB_ID", "P_PARENT1_ID", "P_PARENT2_ID", "P_OPTIONS_COUNT"}),
    ),
    "CROSSBREED": (frozenset({"P_LAB_ID", "P_PARENT1_ID", "P_PARENT2_ID", "P_OFFSPRING_NAME", "P_OFFSPRING_ID"}),),
    "BUY_MUTATION": (frozenset({"P_LAB_ID", "P_MUTATION_ID"}),),
    "APPLY_MUTATION": (frozenset({"P_CREATURE_ID", "P_MUTATION_ID"}),),
    "APPLY_MUTAGEN": (frozenset({"P_CREATURE_ID", "P_MUTAGEN_TYPE", "P_NEW_CREATURE_ID"}),),
    "CHECK_TASK": (frozenset({"P_LAB_ID", "P_TASK_ID", "P_CREATURE_ID"}),),
    "COMPLETE_TASK": (
        frozenset({"P_LAB_ID", "P_TASK_ID", "P_CREATURE_ID", "P_IS_COMPLETED", "P_WALLET_AFTER", "P_RATING_AFTER"}),
    ),
}
SEED_MINIMUMS = {
    "species": ("REF_SPECIES_TYPES", 7),
    "genes": ("GENES", 12),
    "alleles": ("ALLELES", 38),
    "mutations": ("MUTATIONS", 20),
    "mutation_rules": ("MUTATION_RULES", 20),
    "tasks": ("TASKS", 21),
    "task_markers": ("TASK_MARKERS", 21),
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
    routine_signatures: dict[str, frozenset[frozenset[str]]]
    species_types: frozenset[int]
    mutations_without_rules: int
    tasks_without_markers: int


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

        signature_names = sorted(REQUIRED_SIGNATURES)
        signature_binds, signature_params = _in_binds("routine", signature_names)
        cursor.execute(
            f"""
            select object_name, subprogram_id, argument_name
              from user_arguments
             where package_name = :package_name
               and object_name in ({signature_binds})
               and argument_name is not null
               and data_level = 0
             order by object_name, subprogram_id, sequence
            """,
            package_name=PACKAGE_NAME,
            **signature_params,
        )
        signature_rows: dict[tuple[str, int], set[str]] = {}
        for name, subprogram_id, argument_name in cursor.fetchall():
            key = (str(name).upper(), int(subprogram_id))
            signature_rows.setdefault(key, set()).add(str(argument_name).upper())
        routine_signatures: dict[str, frozenset[frozenset[str]]] = {}
        for (name, _subprogram_id), arguments in signature_rows.items():
            routine_signatures[name] = routine_signatures.get(name, frozenset()) | frozenset({frozenset(arguments)})

        species_types: frozenset[int] = frozenset()
        if "REF_SPECIES_TYPES" in tables:
            cursor.execute("select species_type from ref_species_types")
            species_types = frozenset(int(row[0]) for row in cursor.fetchall())

        mutations_without_rules = 0
        if {"MUTATIONS", "MUTATION_RULES"}.issubset(tables):
            cursor.execute(
                """
                select count(*) from mutations m
                 where not exists (
                    select 1 from mutation_rules mr where mr.mutation_id = m.mutation_id
                 )
                """
            )
            mutations_without_rules = int(cursor.fetchone()[0] or 0)

        tasks_without_markers = 0
        if {"TASKS", "TASK_MARKERS"}.issubset(tables):
            cursor.execute(
                """
                select count(*) from tasks t
                 where not exists (
                    select 1 from task_markers tm where tm.task_id = t.task_id
                 )
                """
            )
            tasks_without_markers = int(cursor.fetchone()[0] or 0)

    return SchemaSnapshot(
        tables=tables,
        package_statuses=package_statuses,
        package_error_count=package_error_count,
        lab_session_nullable=columns.get("SESSION_ID") == "Y",
        lab_name_not_null=columns.get("LAB_NAME") == "N",
        task_descriptions_aligned=legacy_description_count == 0,
        seed_counts=seed_counts,
        routines=routines,
        routine_signatures=routine_signatures,
        species_types=species_types,
        mutations_without_rules=mutations_without_rules,
        tasks_without_markers=tasks_without_markers,
    )


def schema_report(snapshot: SchemaSnapshot) -> dict[str, Any]:
    missing_tables = sorted(REQUIRED_TABLES - snapshot.tables)
    package_exists = {"PACKAGE", "PACKAGE BODY"}.issubset(snapshot.package_statuses)
    package_valid = package_exists and all(
        snapshot.package_statuses.get(kind) == "VALID" for kind in ("PACKAGE", "PACKAGE BODY")
    )
    missing_routines = sorted(REQUIRED_ROUTINES - snapshot.routines)
    missing_signatures: dict[str, list[str]] = {}
    for routine, expected_signatures in REQUIRED_SIGNATURES.items():
        actual_signatures = snapshot.routine_signatures.get(routine, frozenset())
        missing = set(expected_signatures) - set(actual_signatures)
        if missing:
            missing_signatures[routine] = [", ".join(sorted(arguments)) for arguments in missing]
    seed_report = {
        label: {"count": snapshot.seed_counts.get(label, 0), "minimum": minimum}
        for label, (_table, minimum) in SEED_MINIMUMS.items()
    }
    seed_integrity = {
        "species_types": snapshot.species_types == frozenset(range(7)),
        "mutation_rules_cover_catalog": snapshot.mutations_without_rules == 0,
        "task_markers_cover_tasks": snapshot.tasks_without_markers == 0,
    }
    seed_ready = all(item["count"] >= item["minimum"] for item in seed_report.values()) and all(seed_integrity.values())
    migrations = {
        "session_bindings_released": snapshot.lab_session_nullable,
        "lab_names": snapshot.lab_name_not_null,
        "task_descriptions": snapshot.task_descriptions_aligned,
    }
    migrations_ready = all(migrations.values())
    api_ready = not missing_routines
    signatures_ready = not missing_signatures
    ready = all(
        (
            not missing_tables,
            package_valid,
            snapshot.package_error_count == 0,
            migrations_ready,
            seed_ready,
            api_ready,
            signatures_ready,
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
        "seed": {"ready": seed_ready, "counts": seed_report, "integrity": seed_integrity},
        "api": {"ready": api_ready, "missing_routines": missing_routines},
        "signatures": {"ready": signatures_ready, "missing": missing_signatures},
    }


def classify_oracle_error_code(code: object) -> str:
    if isinstance(code, str) and re.search(r"\bDPY-\d{4}\b", code, flags=re.IGNORECASE):
        return "unavailable"
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
        message = str(getattr(payload, "message", exc))
        kind = "unavailable" if re.search(r"\bDPY-\d{4}\b", message, flags=re.IGNORECASE) else classify_oracle_error_code(code)
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

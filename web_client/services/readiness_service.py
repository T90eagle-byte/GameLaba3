from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import re
from typing import Any

import oracledb

from services.oracle import ServiceError, get_connection, map_oracle_error


PACKAGE_NAME = "PKG_GENETICS_GAME"


def _load_current_schema_version() -> int:
    candidates = (
        Path(__file__).resolve().parents[2] / "database" / "installers" / "mark_current_schema_version.sql",
        Path(__file__).resolve().parents[1] / "database" / "installers" / "mark_current_schema_version.sql",
    )
    for path in candidates:
        if not path.exists():
            continue
        match = re.search(
            r"^\s*v_current_version\s+constant\s+number\s*:=\s*(\d+);\s*$",
            path.read_text(encoding="utf-8"),
            flags=re.MULTILINE | re.IGNORECASE,
        )
        if match:
            return int(match.group(1))
    raise RuntimeError("BioSborka schema version contract is missing or invalid.")


CURRENT_SCHEMA_VERSION = _load_current_schema_version()
EXPECTED_ARCHETYPE_CODES = frozenset(
    {
        "shark", "ray", "sawfish", "generic_bony_fish", "eel", "pufferfish",
        "crab", "crayfish", "shrimp", "octopus", "squid", "snail",
        "sea_turtle", "sea_snake", "whale", "dolphin", "seal", "walrus",
    }
)
EXPECTED_MORPHOLOGY_GENES = frozenset(
    {
        "body_shape", "body_proportion", "body_size", "body_cover", "body_color",
        "mouth_type", "snout_type", "eye_type", "front_appendage_count",
        "front_appendage_type", "front_appendage_size", "rear_appendage_count",
        "rear_appendage_type", "rear_appendage_size", "tail_type", "tail_size",
        "dorsal_type", "dorsal_size",
    }
)
EXPECTED_MODEL_GENES = {
    1: frozenset(
        {
            "0:color", "0:size", "0:nutrition_type", "0:has_wings",
            "1:fin_shape", "2:fin_shape", "3:claw_form", "3:shell_armor",
            "4:beak_nose_shape", "5:shell_armor", "5:speed_level", "6:fur_density",
        }
    ),
    3: frozenset({f"0:{name}" for name in EXPECTED_MORPHOLOGY_GENES} | {"0:nutrition_type"}),
}
EXPECTED_V3_TASKS = frozenset(
    {
        "task_v3_disc_saw", "task_v3_eel_yellow", "task_v3_shrimp_claws",
        "task_v3_cephalopod_shell", "task_v3_snake_shell", "task_v3_cetacean_broad",
        "task_v3_brown_cetacean", "task_v3_giant_pinniped", "task_v3_disc_fish_tail",
        "task_v3_cetacean_rear_flippers", "task_v3_white_broad_cephalopod",
        "task_v3_long_tailed_pointed",
    }
)
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
        "REF_EXPERIMENT_ECONOMICS",
        "REF_CREATURE_ARCHETYPES",
        "REF_ARCHETYPE_ALLELES",
        "REF_GENETICS_MODEL_GENES",
        "APP_INSTALL_STATE",
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
        "GET_MORPHOLOGY_CURSOR",
        "GET_LAB_MORPHOLOGY_CURSOR",
        "PREVIEW_OFFSPRING_OPTIONS",
        "CROSSBREED",
        "SHOW_MUTATION_SHOP",
        "SHOW_LAB_MUTATION_SHOP",
        "GET_MUTATION_TARGET_GENES_CURSOR",
        "GET_COMPATIBLE_CREATURES_FOR_MUTATION_CURSOR",
        "GET_LAB_MUTATION_QUANTITY",
        "BUY_MUTATION",
        "APPLY_MUTATION",
        "APPLY_MUTAGEN",
        "MAKE_EXPERIMENT",
        "HYBRIDIZE",
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
    "GET_MORPHOLOGY_CURSOR": (frozenset({"P_CREATURE_ID"}),),
    "GET_LAB_MORPHOLOGY_CURSOR": (frozenset({"P_LAB_ID"}),),
    "PREVIEW_OFFSPRING_OPTIONS": (
        frozenset({"P_SESSION_TOKEN", "P_LAB_ID", "P_PARENT1_ID", "P_PARENT2_ID", "P_OPTIONS_COUNT"}),
    ),
    "CROSSBREED": (frozenset({"P_LAB_ID", "P_PARENT1_ID", "P_PARENT2_ID", "P_OFFSPRING_NAME", "P_OFFSPRING_ID"}),),
    "BUY_MUTATION": (frozenset({"P_LAB_ID", "P_MUTATION_ID"}),),
    "SHOW_LAB_MUTATION_SHOP": (frozenset({"P_LAB_ID"}),),
    "APPLY_MUTATION": (frozenset({"P_CREATURE_ID", "P_MUTATION_ID"}),),
    "APPLY_MUTAGEN": (frozenset({"P_CREATURE_ID", "P_MUTAGEN_TYPE", "P_NEW_CREATURE_ID"}),),
    "MAKE_EXPERIMENT": (
        frozenset({"P_LAB_ID", "P_PARENT1_ID", "P_PARENT2_ID", "P_MUTATION_ID", "P_OFFSPRING_NAME", "P_OFFSPRING_ID"}),
        frozenset({"P_LAB_ID", "P_PARENT1_ID", "P_PARENT2_ID", "P_MUTAGEN_TYPE", "P_OFFSPRING_NAME", "P_OFFSPRING_ID"}),
    ),
    "HYBRIDIZE": (
        frozenset({"P_LAB_ID", "P_PARENT1_ID", "P_PARENT2_ID", "P_MUTAGEN_TYPE", "P_OFFSPRING_NAME", "P_OFFSPRING_ID"}),
    ),
    "CHECK_TASK": (frozenset({"P_LAB_ID", "P_TASK_ID", "P_CREATURE_ID"}),),
    "COMPLETE_TASK": (
        frozenset({"P_LAB_ID", "P_TASK_ID", "P_CREATURE_ID", "P_IS_COMPLETED", "P_WALLET_AFTER", "P_RATING_AFTER"}),
    ),
}
SEED_MINIMUMS = {
    "species": ("REF_SPECIES_TYPES", 8),
    "genes": ("GENES", 30),
    "alleles": ("ALLELES", 136),
    "mutations": ("MUTATIONS", 20),
    "mutation_rules": ("MUTATION_RULES", 20),
    "tasks": ("TASKS", 33),
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
    experiment_types: frozenset[str]
    rating_event_types: frozenset[str]
    hybrid_economics_ready: bool
    catalog_display_names_ready: bool
    install_version: int | None
    schema_columns: frozenset[str]
    archetype_codes: frozenset[str]
    archetype_template_count: int
    archetypes_with_invalid_template_count: int
    morphology_genes: frozenset[str]
    model_genes: dict[int, frozenset[str]]
    v3_task_names: frozenset[str]


def _in_binds(prefix: str, values: list[str]) -> tuple[str, dict[str, str]]:
    params = {f"{prefix}{index}": value for index, value in enumerate(values)}
    return ", ".join(f":{key}" for key in params), params


def _fetch_names(cursor: oracledb.Cursor, sql: str, **params: object) -> frozenset[str]:
    cursor.execute(sql, params)
    return frozenset(str(row[0]).upper() for row in cursor.fetchall())


def legacy_task_description_is_aligned(
    description: str | None,
    genetics_version: int | None = None,
    *,
    has_genetics_version: bool = False,
) -> bool:
    """Apply migration 03 wording only where the task model is legacy.

    Pre-migration schemas have no version column, so every task retains the
    original migration-03 contract.  Once the column exists, v3 tasks use
    phenotype wording and are deliberately outside that legacy contract.
    """
    if has_genetics_version and genetics_version != 1:
        return True
    return bool(description) and "носительств" in description.lower()


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
        schema_columns: frozenset[str] = frozenset()
        tracked_columns = {
            "LABS": {"SESSION_ID", "LAB_NAME", "GENETICS_VERSION"},
            "TASKS": {"GENETICS_VERSION", "DISPLAY_NAME"},
            "MUTATIONS": {"DISPLAY_NAME"},
            "EXPERIMENTS": {"MUTAGEN_TYPE"},
            "CREATURES": {"ARCHETYPE_ID"},
            "GENES": {"GAMEPLAY_ENABLED"},
            "ALLELES": {"DISPLAY_NAME"},
        }
        cursor.execute(
            """
            select table_name, column_name
              from user_tab_columns
             where table_name in ('LABS', 'TASKS', 'MUTATIONS', 'EXPERIMENTS', 'CREATURES', 'GENES', 'ALLELES')
            """
        )
        schema_columns = frozenset(
            f"{str(table_name).upper()}.{str(column_name).upper()}"
            for table_name, column_name in cursor.fetchall()
            if str(column_name).upper() in tracked_columns.get(str(table_name).upper(), set())
        )
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
                  from user_tab_columns
                 where table_name = 'TASKS'
                   and column_name = 'GENETICS_VERSION'
                """
            )
            has_task_genetics_version = bool(cursor.fetchone()[0])
            description_scope = "and genetics_version = 1" if has_task_genetics_version else ""
            cursor.execute(
                f"""
                select count(*)
                  from tasks
                 where (description is null
                    or instr(lower(description), 'носительств') = 0)
                    {description_scope}
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

        experiment_types: frozenset[str] = frozenset()
        if "REF_EXPERIMENT_TYPES" in tables:
            experiment_types = _fetch_names(cursor, "select experiment_type from ref_experiment_types")

        rating_event_types: frozenset[str] = frozenset()
        if "REF_RATING_EVENT_TYPES" in tables:
            rating_event_types = _fetch_names(cursor, "select event_type from ref_rating_event_types")

        hybrid_economics_ready = False
        if "REF_EXPERIMENT_ECONOMICS" in tables:
            cursor.execute(
                """
                select count(*)
                  from ref_experiment_economics
                 where experiment_type = 'HYBRIDIZATION'
                   and genetics_version = 3
                   and mutagen_type = 'RADIATION'
                   and wallet_cost = 0
                   and rating_effect = -50
                   and active_flag = 'Y'
                """
            )
            hybrid_economics_ready = int(cursor.fetchone()[0] or 0) == 1

        catalog_display_names_ready = False
        if {"TASKS.DISPLAY_NAME", "MUTATIONS.DISPLAY_NAME"}.issubset(schema_columns):
            cursor.execute(
                """
                select count(*)
                  from (
                      select display_name from tasks
                      union all
                      select display_name from mutations
                  )
                 where display_name is null
                    or trim(display_name) is null
                """
            )
            catalog_display_names_ready = int(cursor.fetchone()[0] or 0) == 0

        install_version: int | None = None
        if "APP_INSTALL_STATE" in tables:
            cursor.execute(
                "select install_version from app_install_state where install_key = 'schema'"
            )
            marker_row = cursor.fetchone()
            if marker_row is not None:
                install_version = int(marker_row[0])

        archetype_codes: frozenset[str] = frozenset()
        archetype_template_count = 0
        archetypes_with_invalid_template_count = len(EXPECTED_ARCHETYPE_CODES)
        if "REF_CREATURE_ARCHETYPES" in tables:
            archetype_codes = _fetch_names(
                cursor,
                "select archetype_code from ref_creature_archetypes",
            )
        if {"REF_CREATURE_ARCHETYPES", "REF_ARCHETYPE_ALLELES"}.issubset(tables):
            cursor.execute("select count(*) from ref_archetype_alleles")
            archetype_template_count = int(cursor.fetchone()[0] or 0)
            cursor.execute(
                """
                select count(*)
                  from (
                      select r.archetype_id
                        from ref_creature_archetypes r
                        left join ref_archetype_alleles a on a.archetype_id = r.archetype_id
                       group by r.archetype_id
                      having count(a.gene_id) <> 18
                  )
                """
            )
            archetypes_with_invalid_template_count = int(cursor.fetchone()[0] or 0)

        morphology_genes: frozenset[str] = frozenset()
        if "GENES" in tables and "GENES.GAMEPLAY_ENABLED" in schema_columns:
            morphology_genes = _fetch_names(
                cursor,
                """
                select gene_name
                  from genes
                 where species_type = 0
                   and gameplay_enabled = 'N'
                """,
            )

        model_genes: dict[int, frozenset[str]] = {1: frozenset(), 3: frozenset()}
        if {"REF_GENETICS_MODEL_GENES", "GENES"}.issubset(tables):
            cursor.execute(
                """
                select membership.genetics_version, g.species_type, g.gene_name
                  from ref_genetics_model_genes membership
                  join genes g on g.gene_id = membership.gene_id
                 where membership.genetics_version in (1, 3)
                """
            )
            mutable_model_genes: dict[int, set[str]] = {1: set(), 3: set()}
            for version, species_type, gene_name in cursor.fetchall():
                mutable_model_genes[int(version)].add(f"{int(species_type)}:{str(gene_name).lower()}")
            model_genes = {version: frozenset(names) for version, names in mutable_model_genes.items()}

        v3_task_names: frozenset[str] = frozenset()
        if "TASKS" in tables and "TASKS.GENETICS_VERSION" in schema_columns:
            v3_task_names = _fetch_names(
                cursor,
                "select task_name from tasks where genetics_version = 3",
            )

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
        experiment_types=experiment_types,
        rating_event_types=rating_event_types,
        hybrid_economics_ready=hybrid_economics_ready,
        catalog_display_names_ready=catalog_display_names_ready,
        install_version=install_version,
        schema_columns=schema_columns,
        archetype_codes=frozenset(code.lower() for code in archetype_codes),
        archetype_template_count=archetype_template_count,
        archetypes_with_invalid_template_count=archetypes_with_invalid_template_count,
        morphology_genes=frozenset(name.lower() for name in morphology_genes),
        model_genes=model_genes,
        v3_task_names=frozenset(name.lower() for name in v3_task_names),
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
        "species_types": snapshot.species_types == frozenset(range(8)),
        "mutation_rules_cover_catalog": snapshot.mutations_without_rules == 0,
        "task_markers_cover_tasks": snapshot.tasks_without_markers == 0,
        "hybridization_experiment_type": "HYBRIDIZATION" in snapshot.experiment_types,
        "hybridization_rating_event_type": "HYBRIDIZATION_PENALTY" in snapshot.rating_event_types,
        "hybridization_economics": snapshot.hybrid_economics_ready,
        "catalog_display_names": snapshot.catalog_display_names_ready,
    }
    seed_ready = all(item["count"] >= item["minimum"] for item in seed_report.values()) and all(seed_integrity.values())
    expected_columns = frozenset(
        {
            "LABS.SESSION_ID", "LABS.LAB_NAME", "LABS.GENETICS_VERSION",
            "TASKS.GENETICS_VERSION", "TASKS.DISPLAY_NAME", "MUTATIONS.DISPLAY_NAME", "EXPERIMENTS.MUTAGEN_TYPE",
            "CREATURES.ARCHETYPE_ID", "GENES.GAMEPLAY_ENABLED", "ALLELES.DISPLAY_NAME",
        }
    )
    schema_contract = {
        "install_version": snapshot.install_version == CURRENT_SCHEMA_VERSION,
        "columns": expected_columns.issubset(snapshot.schema_columns),
        "archetypes": snapshot.archetype_codes == EXPECTED_ARCHETYPE_CODES,
        "archetype_templates": (
            snapshot.archetype_template_count == 324
            and snapshot.archetypes_with_invalid_template_count == 0
        ),
        "morphology_genes": snapshot.morphology_genes == EXPECTED_MORPHOLOGY_GENES,
        "v1_model_membership": snapshot.model_genes.get(1, frozenset()) == EXPECTED_MODEL_GENES[1],
        "v3_model_membership": snapshot.model_genes.get(3, frozenset()) == EXPECTED_MODEL_GENES[3],
        "v3_tasks": snapshot.v3_task_names == EXPECTED_V3_TASKS,
    }
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
            all(schema_contract.values()),
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
        "contract": {
            "ready": all(schema_contract.values()),
            "checks": schema_contract,
            "expected_install_version": CURRENT_SCHEMA_VERSION,
            "actual_install_version": snapshot.install_version,
            "archetype_count": len(snapshot.archetype_codes),
            "archetype_template_count": snapshot.archetype_template_count,
            "model_membership": {
                "v1": len(snapshot.model_genes.get(1, frozenset())),
                "v3": len(snapshot.model_genes.get(3, frozenset())),
            },
            "v3_task_count": len(snapshot.v3_task_names),
        },
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

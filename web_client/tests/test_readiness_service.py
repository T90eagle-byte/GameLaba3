from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

import oracledb

WEB_ROOT = Path(__file__).resolve().parents[1]
if str(WEB_ROOT) not in sys.path:
    sys.path.insert(0, str(WEB_ROOT))

import app as app_module  # noqa: E402
from services.oracle import ServiceError  # noqa: E402
from services import readiness_service  # noqa: E402


def ready_snapshot(**changes: object) -> readiness_service.SchemaSnapshot:
    values: dict[str, object] = {
        "tables": readiness_service.REQUIRED_TABLES,
        "package_statuses": {"PACKAGE": "VALID", "PACKAGE BODY": "VALID"},
        "package_error_count": 0,
        "lab_session_nullable": True,
        "lab_name_not_null": True,
        "task_descriptions_aligned": True,
        "seed_counts": {
            label: minimum for label, (_table, minimum) in readiness_service.SEED_MINIMUMS.items()
        },
        "routines": readiness_service.REQUIRED_ROUTINES,
        "routine_signatures": {
            routine: frozenset(signatures)
            for routine, signatures in readiness_service.REQUIRED_SIGNATURES.items()
        },
        "species_types": frozenset(range(8)),
        "mutations_without_rules": 0,
        "tasks_without_markers": 0,
        "experiment_types": frozenset({"CROSS", "MUTATION", "MUTAGEN", "CROSSBREED_MUTAGEN", "HYBRIDIZATION"}),
        "rating_event_types": frozenset({"TASK_REWARD", "MUTAGEN_PENALTY", "HYBRIDIZATION_PENALTY"}),
        "hybrid_economics_ready": True,
        "install_version": readiness_service.CURRENT_SCHEMA_VERSION,
        "schema_columns": frozenset(
            {
                "LABS.SESSION_ID", "LABS.LAB_NAME", "LABS.GENETICS_VERSION",
                "TASKS.GENETICS_VERSION", "EXPERIMENTS.MUTAGEN_TYPE",
                "CREATURES.ARCHETYPE_ID", "GENES.GAMEPLAY_ENABLED", "ALLELES.DISPLAY_NAME",
            }
        ),
        "archetype_codes": readiness_service.EXPECTED_ARCHETYPE_CODES,
        "archetype_template_count": 324,
        "archetypes_with_invalid_template_count": 0,
        "morphology_genes": readiness_service.EXPECTED_MORPHOLOGY_GENES,
        "model_genes": readiness_service.EXPECTED_MODEL_GENES,
        "v3_task_names": readiness_service.EXPECTED_V3_TASKS,
    }
    values.update(changes)
    return readiness_service.SchemaSnapshot(**values)  # type: ignore[arg-type]


class SchemaReportTests(unittest.TestCase):
    def test_ready_schema(self) -> None:
        report = readiness_service.schema_report(ready_snapshot())
        self.assertTrue(report["ready"])
        self.assertTrue(report["package"]["spec_valid"])
        self.assertTrue(report["api"]["ready"])

    def test_missing_package_is_not_ready(self) -> None:
        report = readiness_service.schema_report(ready_snapshot(package_statuses={}))
        self.assertFalse(report["ready"])
        self.assertFalse(report["package"]["exists"])

    def test_invalid_package_is_not_ready(self) -> None:
        report = readiness_service.schema_report(
            ready_snapshot(package_statuses={"PACKAGE": "VALID", "PACKAGE BODY": "INVALID"})
        )
        self.assertFalse(report["ready"])
        self.assertFalse(report["package"]["body_valid"])

    def test_package_errors_are_not_ready(self) -> None:
        report = readiness_service.schema_report(ready_snapshot(package_error_count=2))
        self.assertFalse(report["ready"])
        self.assertEqual(report["package"]["error_count"], 2)

    def test_missing_table_and_migration_are_reported(self) -> None:
        report = readiness_service.schema_report(
            ready_snapshot(
                tables=frozenset(readiness_service.REQUIRED_TABLES - {"LABS"}),
                lab_name_not_null=False,
            )
        )
        self.assertFalse(report["tables_ready"])
        self.assertEqual(report["missing_tables"], ["LABS"])
        self.assertFalse(report["migrations_ready"])

    def test_missing_required_signature_is_not_ready(self) -> None:
        signatures = dict(ready_snapshot().routine_signatures)
        signatures["APPLY_MUTATION"] = frozenset()
        report = readiness_service.schema_report(ready_snapshot(routine_signatures=signatures))
        self.assertFalse(report["ready"])
        self.assertFalse(report["signatures"]["ready"])
        self.assertIn("APPLY_MUTATION", report["signatures"]["missing"])

    def test_combined_experiment_overload_is_required(self) -> None:
        signatures = dict(ready_snapshot().routine_signatures)
        signatures["MAKE_EXPERIMENT"] = frozenset({readiness_service.REQUIRED_SIGNATURES["MAKE_EXPERIMENT"][0]})

        report = readiness_service.schema_report(ready_snapshot(routine_signatures=signatures))

        self.assertFalse(report["ready"])
        self.assertIn("MAKE_EXPERIMENT", report["signatures"]["missing"])

    def test_missing_seed_relationships_are_not_ready(self) -> None:
        report = readiness_service.schema_report(
            ready_snapshot(mutations_without_rules=1, tasks_without_markers=1)
        )
        self.assertFalse(report["ready"])
        self.assertFalse(report["seed"]["ready"])
        self.assertFalse(report["seed"]["integrity"]["mutation_rules_cover_catalog"])
        self.assertFalse(report["seed"]["integrity"]["task_markers_cover_tasks"])

    def test_missing_hybridization_economics_is_not_ready(self) -> None:
        report = readiness_service.schema_report(ready_snapshot(hybrid_economics_ready=False))

        self.assertFalse(report["ready"])
        self.assertFalse(report["seed"]["integrity"]["hybridization_economics"])

    def test_old_install_marker_is_not_ready(self) -> None:
        report = readiness_service.schema_report(ready_snapshot(install_version=2))

        self.assertFalse(report["ready"])
        self.assertFalse(report["contract"]["checks"]["install_version"])

    def test_incomplete_archetype_templates_are_not_ready(self) -> None:
        report = readiness_service.schema_report(
            ready_snapshot(archetype_template_count=323, archetypes_with_invalid_template_count=1)
        )

        self.assertFalse(report["ready"])
        self.assertFalse(report["contract"]["checks"]["archetype_templates"])

    def test_missing_archetype_is_not_ready(self) -> None:
        report = readiness_service.schema_report(
            ready_snapshot(
                archetype_codes=frozenset(set(readiness_service.EXPECTED_ARCHETYPE_CODES) - {"shark"})
            )
        )

        self.assertFalse(report["ready"])
        self.assertFalse(report["contract"]["checks"]["archetypes"])

    def test_incomplete_v3_membership_is_not_ready(self) -> None:
        model_genes = dict(readiness_service.EXPECTED_MODEL_GENES)
        model_genes[3] = frozenset(set(model_genes[3]) - {"0:body_shape"})
        report = readiness_service.schema_report(ready_snapshot(model_genes=model_genes))

        self.assertFalse(report["ready"])
        self.assertFalse(report["contract"]["checks"]["v3_model_membership"])

    def test_missing_v3_task_is_not_ready(self) -> None:
        report = readiness_service.schema_report(
            ready_snapshot(v3_task_names=frozenset(set(readiness_service.EXPECTED_V3_TASKS) - {"task_v3_disc_saw"}))
        )

        self.assertFalse(report["ready"])
        self.assertFalse(report["contract"]["checks"]["v3_tasks"])

    def test_missing_hybridization_reference_is_not_ready(self) -> None:
        report = readiness_service.schema_report(
            ready_snapshot(experiment_types=frozenset({"CROSS", "MUTATION", "MUTAGEN", "CROSSBREED_MUTAGEN"}))
        )

        self.assertFalse(report["ready"])
        self.assertFalse(report["seed"]["integrity"]["hybridization_experiment_type"])

    def test_credentials_and_listener_errors_have_different_kinds(self) -> None:
        self.assertEqual(readiness_service.classify_oracle_error_code(1017), "credentials")
        self.assertEqual(readiness_service.classify_oracle_error_code(12541), "unavailable")
        self.assertEqual(readiness_service.classify_oracle_error_code("DPY-6005"), "unavailable")


class TaskDescriptionReadinessTests(unittest.TestCase):
    def test_legacy_schema_keeps_the_original_requirement_for_every_task(self) -> None:
        self.assertTrue(
            readiness_service.legacy_task_description_is_aligned(
                "Требуется носительство генетического варианта.",
                has_genetics_version=False,
            )
        )
        self.assertFalse(
            readiness_service.legacy_task_description_is_aligned(
                "Получите выраженный признак.",
                has_genetics_version=False,
            )
        )

    def test_versioned_schema_checks_only_v1_descriptions(self) -> None:
        self.assertTrue(
            readiness_service.legacy_task_description_is_aligned(
                "Требуется носительство генетического варианта.",
                genetics_version=1,
                has_genetics_version=True,
            )
        )
        self.assertTrue(
            readiness_service.legacy_task_description_is_aligned(
                "Получите выраженный фенотипический признак.",
                genetics_version=3,
                has_genetics_version=True,
            )
        )

    def test_versioned_schema_rejects_only_a_broken_v1_description(self) -> None:
        self.assertFalse(
            readiness_service.legacy_task_description_is_aligned(
                "Получите выраженный признак.",
                genetics_version=1,
                has_genetics_version=True,
            )
        )
        self.assertTrue(
            readiness_service.legacy_task_description_is_aligned(
                "Нормальное описание выраженного признака.",
                genetics_version=3,
                has_genetics_version=True,
            )
        )


class RuntimeReadinessTests(unittest.TestCase):
    @patch.object(readiness_service, "get_connection")
    def test_web_process_reports_database_unavailable_without_crashing(self, get_connection: Mock) -> None:
        get_connection.side_effect = ServiceError("Oracle configuration is missing")
        report = readiness_service.runtime_readiness()
        self.assertTrue(report["app"]["ok"])
        self.assertFalse(report["database"]["connected"])
        self.assertEqual(report["database"]["error"]["kind"], "configuration")

    @patch.object(app_module, "runtime_readiness")
    def test_health_is_safe_when_schema_is_not_ready(self, runtime_readiness: Mock) -> None:
        runtime_readiness.return_value = {
            "app": {"ok": True},
            "database": {"connected": True, "error": None},
            "schema": {"ready": False, "missing_tables": ["TASKS"]},
        }
        app = app_module.create_app()
        app.config.update(TESTING=True, SECRET_KEY="test-secret")
        response = app.test_client().get("/health")
        body = response.get_data(as_text=True)
        self.assertEqual(response.status_code, 503)
        self.assertNotIn("ORACLE_PASSWORD", body)
        self.assertNotIn("test-secret", body)

    def test_liveness_endpoint_stays_up_without_database(self) -> None:
        app = app_module.create_app()
        app.config.update(TESTING=True, SECRET_KEY="test-secret")
        response = app.test_client().get("/health/live")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json(), {"app": {"ok": True}})

    @patch.object(readiness_service, "get_connection")
    def test_dpy_connection_error_is_unavailable_and_health_stays_safe(self, get_connection: Mock) -> None:
        payload = type("OraclePayload", (), {"code": 0, "message": "DPY-6005: cannot connect to database"})()
        get_connection.side_effect = oracledb.DatabaseError(payload)

        report = readiness_service.runtime_readiness()

        self.assertFalse(report["database"]["connected"])
        self.assertEqual(report["database"]["error"]["kind"], "unavailable")
        self.assertNotIn("DPY-6005", report["database"]["error"]["message"])

    @patch.object(app_module, "runtime_readiness")
    def test_health_returns_503_for_dpy_connectivity_failure(self, runtime_readiness: Mock) -> None:
        runtime_readiness.return_value = {
            "app": {"ok": True},
            "database": {"connected": False, "error": {"kind": "unavailable", "message": "Oracle unavailable"}},
            "schema": {"ready": False},
        }
        app = app_module.create_app()
        app.config.update(TESTING=True, SECRET_KEY="test-secret")

        response = app.test_client().get("/health")

        self.assertEqual(response.status_code, 503)
        self.assertNotIn("DPY-6005", response.get_data(as_text=True))


class DeploymentSafetyTests(unittest.TestCase):
    def test_db_init_refuses_incomplete_existing_schema_without_drop_user(self) -> None:
        script = (WEB_ROOT.parent / "docker" / "db-init.sh").read_text(encoding="utf-8").lower()
        self.assertNotIn("drop user", script)
        self.assertIn("refusing to alter or delete an existing schema", script)

    def test_db_init_has_a_safe_recognized_version_upgrade(self) -> None:
        script = (WEB_ROOT.parent / "docker" / "db-init.sh").read_text(encoding="utf-8")
        self.assertIn("mark_current_schema_version.sql", script)
        self.assertIn("apply_current_schema_files", script)
        self.assertIn("@/workspace/database/installers/apply_current_schema_update.sql", script)
        self.assertIn("@/workspace/database/installers/mark_current_schema_version.sql", script)
        self.assertLess(script.index("validate_schema\n    mark_current_schema_version"), script.index("Schema upgrade to version"))

        update_script = (
            WEB_ROOT.parent / "database" / "installers" / "apply_current_schema_update.sql"
        ).read_text(encoding="utf-8")
        for number in range(1, 14):
            self.assertIn(f"../migrations/{number:02d}_", update_script)
        for number in range(1, 6):
            self.assertIn(f"../seeds/{number:02d}_", update_script)

    def test_schema_version_has_one_installer_source(self) -> None:
        version_file = WEB_ROOT.parent / "database" / "installers" / "mark_current_schema_version.sql"
        self.assertEqual(readiness_service.CURRENT_SCHEMA_VERSION, 13)
        self.assertIn("v_current_version constant number := 13", version_file.read_text(encoding="utf-8"))

    def test_university_installers_are_non_destructive(self) -> None:
        installers = WEB_ROOT.parent / "database" / "installers"
        for path in installers.glob("university_*.sql"):
            with self.subTest(path=path.name):
                script = path.read_text(encoding="utf-8").lower()
                self.assertNotIn("create user", script)
                self.assertNotIn("drop user", script)
                self.assertNotIn("truncate", script)

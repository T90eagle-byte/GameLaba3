from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest.mock import ANY, patch


REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPTS_ROOT = REPO_ROOT / "database" / "scripts"
if str(SCRIPTS_ROOT) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_ROOT))

import manage_schema  # noqa: E402


class ManageSchemaSafetyTests(unittest.TestCase):
    @staticmethod
    def state(
        tables: set[str], object_count: int = 0, version: int | None = None
    ) -> manage_schema.SchemaState:
        return manage_schema.SchemaState(frozenset(tables), object_count, version)

    @patch("manage_schema.execute_sql_file")
    @patch("manage_schema.inspect_schema")
    def test_fresh_refuses_existing_biosborka_without_sql(
        self, inspect_schema, execute_sql_file
    ) -> None:
        inspect_schema.return_value = self.state({"USERS", "LABS"}, object_count=2, version=15)

        with self.assertRaisesRegex(SystemExit, "BioSborka"):
            manage_schema.install_fresh(object())

        execute_sql_file.assert_not_called()

    @patch("manage_schema.execute_sql_file")
    @patch("manage_schema.inspect_schema")
    def test_fresh_refuses_foreign_objects_without_sql(
        self, inspect_schema, execute_sql_file
    ) -> None:
        inspect_schema.return_value = self.state({"FOREIGN_TABLE"}, object_count=1)

        with self.assertRaisesRegex(SystemExit, "посторонние объекты"):
            manage_schema.install_fresh(object())

        execute_sql_file.assert_not_called()

    @patch("manage_schema.execute_sql_file")
    @patch("manage_schema.inspect_schema")
    def test_fresh_uses_canonical_installer_for_empty_schema(
        self, inspect_schema, execute_sql_file
    ) -> None:
        inspect_schema.return_value = self.state(set())

        manage_schema.install_fresh(object())

        execute_sql_file.assert_called_once_with(ANY, manage_schema.FRESH_INSTALLER)

    @patch("manage_schema.execute_sql_file")
    @patch("manage_schema.inspect_schema")
    def test_update_refuses_partial_schema_without_sql(
        self, inspect_schema, execute_sql_file
    ) -> None:
        inspect_schema.return_value = self.state({"USERS", "LABS"}, object_count=2)

        with self.assertRaisesRegex(SystemExit, "неполная"):
            manage_schema.update_existing(object())

        execute_sql_file.assert_not_called()

    @patch(
        "manage_schema.preserved_counts",
        side_effect=[
            {"USERS": 2, "LABS": 10, "CREATURES": 30, "GENOTYPES": 100, "EXPERIMENTS": 4},
            {"USERS": 2, "LABS": 10, "CREATURES": 30, "GENOTYPES": 100, "EXPERIMENTS": 4},
        ],
    )
    @patch("manage_schema.execute_sql_file")
    @patch("manage_schema.inspect_schema")
    def test_update_uses_canonical_installer_and_preserves_counts(
        self, inspect_schema, execute_sql_file, preserved_counts
    ) -> None:
        inspect_schema.return_value = self.state(
            set(manage_schema.LEGACY_REQUIRED_TABLES), object_count=24, version=15
        )

        manage_schema.update_existing(object())

        execute_sql_file.assert_called_once_with(ANY, manage_schema.UPDATE_INSTALLER)
        self.assertEqual(preserved_counts.call_count, 2)


if __name__ == "__main__":
    unittest.main()

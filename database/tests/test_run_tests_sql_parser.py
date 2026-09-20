from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPTS_ROOT = REPO_ROOT / "database" / "scripts"
if str(SCRIPTS_ROOT) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_ROOT))

from run_tests import iter_statements  # noqa: E402


class SqlRunnerParserTests(unittest.TestCase):
    def statements(self, text: str, name: str = "script.sql") -> list[tuple[str, int]]:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / name
            path.write_text(text, encoding="utf-8")
            return list(iter_statements(path))

    def test_regular_sql_statements_drop_only_the_terminal_semicolon(self) -> None:
        statements = self.statements(
            """
update labs
   set session_id = null
 where session_id is not null;

insert into labs (lab_id) values (1);
delete from labs where lab_id = 1;
commit;
rollback;
"""
        )

        self.assertEqual(
            [statement for statement, _ in statements],
            [
                "update labs\n   set session_id = null\n where session_id is not null",
                "insert into labs (lab_id) values (1)",
                "delete from labs where lab_id = 1",
                "commit",
                "rollback",
            ],
        )

    def test_plsql_and_package_bodies_keep_internal_semicolons(self) -> None:
        statements = self.statements(
            """
begin
    null;
    dbms_output.put_line('ok;');
end;
/

create or replace package demo_package as
    procedure demo;
end demo_package;
/

create or replace package body demo_package as
    procedure demo is
    begin
        null;
    end demo;
end demo_package;
/
"""
        )

        self.assertEqual(len(statements), 3)
        self.assertTrue(statements[0][0].endswith("end;"))
        self.assertIn("put_line('ok;');", statements[0][0])
        self.assertIn("procedure demo;", statements[1][0])
        self.assertIn("null;", statements[2][0])
        self.assertTrue(statements[2][0].endswith("end demo_package;"))

    def test_include_and_release_session_migration_emit_plain_update(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            child = root / "child.sql"
            child.write_text("update labs set session_id = null;\n", encoding="utf-8")
            parent = root / "parent.sql"
            parent.write_text("@@child.sql\ncommit;\n", encoding="utf-8")

            statements = list(iter_statements(parent))

        self.assertEqual([statement for statement, _ in statements], ["update labs set session_id = null", "commit"])

        migration = REPO_ROOT / "database" / "migrations" / "01_release_lab_session_bindings.sql"
        parsed_migration = list(iter_statements(migration))
        update = next(statement for statement, _ in parsed_migration if statement.lower().startswith("update labs"))
        self.assertFalse(update.endswith(";"))
        self.assertIn("where session_id is not null", update.lower())


if __name__ == "__main__":
    unittest.main()

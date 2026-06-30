from __future__ import annotations

from typing import Any

import oracledb

from services.oracle import rows_from_refcursor, run_db


def get_experiment_history(session_token: str, lab_id: int) -> list[dict[str, Any]]:
    def action(connection: oracledb.Connection) -> list[dict[str, Any]]:
        with connection.cursor() as cursor:
            cursor.callproc("pkg_genetics_game.load_lab", [session_token, lab_id])
            ref_cursor = cursor.callfunc(
                "pkg_genetics_game.get_experiment_history",
                oracledb.DB_TYPE_CURSOR,
                [lab_id, None],
            )
            try:
                return rows_from_refcursor(ref_cursor)
            finally:
                ref_cursor.close()

    return run_db(action)
from __future__ import annotations

from typing import Any

import oracledb

from services.oracle import rows_from_refcursor, run_db


def preview_offspring_options(
    session_token: str,
    lab_id: int,
    parent1_id: int,
    parent2_id: int,
    options_count: int = 3,
) -> list[dict[str, Any]]:
    def action(connection: oracledb.Connection) -> list[dict[str, Any]]:
        with connection.cursor() as cursor:
            ref_cursor = cursor.callfunc(
                "pkg_genetics_game.preview_offspring_options",
                oracledb.DB_TYPE_CURSOR,
                [session_token, lab_id, parent1_id, parent2_id, options_count],
            )
            try:
                return rows_from_refcursor(ref_cursor)
            finally:
                ref_cursor.close()

    return run_db(action)


def crossbreed(
    session_token: str,
    lab_id: int,
    parent1_id: int,
    parent2_id: int,
    offspring_name: str,
) -> int:
    def action(connection: oracledb.Connection) -> int:
        with connection.cursor() as cursor:
            cursor.callproc("pkg_genetics_game.load_lab", [session_token, lab_id])
            out_offspring_id = cursor.var(oracledb.DB_TYPE_NUMBER)
            cursor.callproc(
                "pkg_genetics_game.crossbreed",
                [lab_id, parent1_id, parent2_id, offspring_name, out_offspring_id],
            )
            value = out_offspring_id.getvalue()
            return 0 if value is None else int(value)

    return run_db(action)
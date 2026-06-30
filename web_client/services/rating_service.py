from __future__ import annotations

from typing import Any

import oracledb

from services.oracle import rows_from_refcursor, run_db


def get_rating_events(session_token: str, lab_id: int) -> list[dict[str, Any]]:
    def action(connection: oracledb.Connection) -> list[dict[str, Any]]:
        with connection.cursor() as cursor:
            ref_cursor = cursor.callfunc(
                "pkg_genetics_game.get_rating_events_cursor",
                oracledb.DB_TYPE_CURSOR,
                [session_token, lab_id],
            )
            try:
                return rows_from_refcursor(ref_cursor)
            finally:
                ref_cursor.close()

    return run_db(action)
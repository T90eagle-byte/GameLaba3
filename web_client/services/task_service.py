from __future__ import annotations

from typing import Any

import oracledb

from services.oracle import rows_from_refcursor, run_db


def _as_int(value: Any) -> int:
    if value is None:
        return 0
    return int(value)


def _as_float(value: Any) -> float:
    if value is None:
        return 0.0
    return float(value)


def get_tasks(session_token: str, lab_id: int) -> list[dict[str, Any]]:
    def action(connection: oracledb.Connection) -> list[dict[str, Any]]:
        with connection.cursor() as cursor:
            cursor.callproc("pkg_genetics_game.load_lab", [session_token, lab_id])
            ref_cursor = cursor.callfunc(
                "pkg_genetics_game.get_tasks_cursor",
                oracledb.DB_TYPE_CURSOR,
                [lab_id],
            )
            try:
                return rows_from_refcursor(ref_cursor)
            finally:
                ref_cursor.close()

    return run_db(action)


def check_task(session_token: str, lab_id: int, task_id: int, creature_id: int) -> int:
    def action(connection: oracledb.Connection) -> int:
        with connection.cursor() as cursor:
            cursor.callproc("pkg_genetics_game.load_lab", [session_token, lab_id])
            result = cursor.callfunc(
                "pkg_genetics_game.check_task",
                oracledb.DB_TYPE_NUMBER,
                [lab_id, task_id, creature_id],
            )
            return _as_int(result)

    return run_db(action)


def complete_task(
    session_token: str,
    lab_id: int,
    task_id: int,
    creature_id: int,
) -> dict[str, Any]:
    def action(connection: oracledb.Connection) -> dict[str, Any]:
        with connection.cursor() as cursor:
            cursor.callproc("pkg_genetics_game.load_lab", [session_token, lab_id])
            out_is_completed = cursor.var(oracledb.DB_TYPE_NUMBER)
            out_wallet_after = cursor.var(oracledb.DB_TYPE_NUMBER)
            out_rating_after = cursor.var(oracledb.DB_TYPE_NUMBER)

            cursor.callproc(
                "pkg_genetics_game.complete_task",
                [
                    lab_id,
                    task_id,
                    creature_id,
                    out_is_completed,
                    out_wallet_after,
                    out_rating_after,
                ],
            )

            return {
                "is_completed": _as_int(out_is_completed.getvalue()),
                "wallet_after": _as_float(out_wallet_after.getvalue()),
                "rating_after": _as_float(out_rating_after.getvalue()),
            }

    return run_db(action)
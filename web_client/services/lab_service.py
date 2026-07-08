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


def resolve_user_id(session_token: str) -> int | None:
    def action(connection: oracledb.Connection) -> int | None:
        with connection.cursor() as cursor:
            user_id = cursor.callfunc(
                "pkg_genetics_game.resolve_user_id_by_token",
                oracledb.DB_TYPE_NUMBER,
                [session_token],
            )
            return None if user_id is None else int(user_id)

    return run_db(action)


def list_user_labs(session_token: str) -> list[dict[str, Any]]:
    def action(connection: oracledb.Connection) -> list[dict[str, Any]]:
        with connection.cursor() as cursor:
            user_id = cursor.callfunc(
                "pkg_genetics_game.resolve_user_id_by_token",
                oracledb.DB_TYPE_NUMBER,
                [session_token],
            )
            ref_cursor = cursor.callfunc(
                "pkg_genetics_game.list_user_labs",
                oracledb.DB_TYPE_CURSOR,
                [user_id],
            )
            try:
                return rows_from_refcursor(ref_cursor)
            finally:
                ref_cursor.close()

    return run_db(action)


def start_new_lab(session_token: str) -> int:
    def action(connection: oracledb.Connection) -> int:
        with connection.cursor() as cursor:
            out_lab_id = cursor.var(oracledb.DB_TYPE_NUMBER)
            cursor.callproc("pkg_genetics_game.start_new_lab", [session_token, out_lab_id])
            return int(out_lab_id.getvalue())

    return run_db(action)


def load_lab(session_token: str, lab_id: int) -> None:
    def action(connection: oracledb.Connection) -> None:
        with connection.cursor() as cursor:
            cursor.callproc("pkg_genetics_game.load_lab", [session_token, lab_id])

    run_db(action)


def switch_lab(session_token: str, lab_id: int) -> None:
    def action(connection: oracledb.Connection) -> None:
        with connection.cursor() as cursor:
            cursor.callproc("pkg_genetics_game.switch_lab", [session_token, lab_id])

    run_db(action)


def delete_lab(session_token: str, lab_id: int) -> None:
    def action(connection: oracledb.Connection) -> None:
        with connection.cursor() as cursor:
            cursor.callproc("pkg_genetics_game.delete_lab", [session_token, lab_id])

    run_db(action)


def get_lab_stats(session_token: str, lab_id: int) -> dict[str, Any]:
    def action(connection: oracledb.Connection) -> dict[str, Any]:
        with connection.cursor() as cursor:
            cursor.callproc("pkg_genetics_game.load_lab", [session_token, lab_id])

            out_wallet = cursor.var(oracledb.DB_TYPE_NUMBER)
            out_rating = cursor.var(oracledb.DB_TYPE_NUMBER)
            out_creature_count = cursor.var(oracledb.DB_TYPE_NUMBER)
            out_active_task_count = cursor.var(oracledb.DB_TYPE_NUMBER)
            out_completed_task_count = cursor.var(oracledb.DB_TYPE_NUMBER)
            out_experiment_count = cursor.var(oracledb.DB_TYPE_NUMBER)

            cursor.callproc(
                "pkg_genetics_game.get_lab_stats",
                [
                    lab_id,
                    out_wallet,
                    out_rating,
                    out_creature_count,
                    out_active_task_count,
                    out_completed_task_count,
                    out_experiment_count,
                ],
            )

            return {
                "wallet": _as_float(out_wallet.getvalue()),
                "rating": _as_float(out_rating.getvalue()),
                "creature_count": _as_int(out_creature_count.getvalue()),
                "active_task_count": _as_int(out_active_task_count.getvalue()),
                "completed_task_count": _as_int(out_completed_task_count.getvalue()),
                "experiment_count": _as_int(out_experiment_count.getvalue()),
            }

    return run_db(action)

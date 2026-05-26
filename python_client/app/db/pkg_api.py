from __future__ import annotations

from typing import Any

import oracledb


class PkgApi:
    def __init__(self, connection: oracledb.Connection) -> None:
        self._connection = connection

    @staticmethod
    def _rows_from_refcursor(ref_cursor: oracledb.Cursor) -> list[dict[str, Any]]:
        columns = [desc[0].lower() for desc in ref_cursor.description]
        rows = ref_cursor.fetchall()
        return [dict(zip(columns, row)) for row in rows]

    @staticmethod
    def _as_int(value: Any) -> int:
        if value is None:
            return 0
        return int(value)

    @staticmethod
    def _as_float(value: Any) -> float:
        if value is None:
            return 0.0
        return float(value)

    def register_user(self, username: str, login: str, password: str) -> int:
        with self._connection.cursor() as cursor:
            out_user_id = cursor.var(oracledb.DB_TYPE_NUMBER)
            cursor.callproc(
                "pkg_genetics_game.register_user",
                [username, login, password, out_user_id],
            )
            return self._as_int(out_user_id.getvalue())

    def login_user(self, login: str, password: str) -> str | None:
        with self._connection.cursor() as cursor:
            token = cursor.callfunc(
                "pkg_genetics_game.login_user",
                str,
                [login, password],
            )
            if token is None:
                return None
            return str(token)

    def logout_user(self, session_token: str) -> None:
        with self._connection.cursor() as cursor:
            cursor.callproc("pkg_genetics_game.logout_user", [session_token])

    def resolve_user_id_by_token(self, session_token: str) -> int | None:
        with self._connection.cursor() as cursor:
            cursor.execute(
                """
                select s.user_id
                  from sessions s
                 where s.session_token = :session_token
                   and s.status = 'ACTIVE'
                """,
                {"session_token": session_token},
            )
            row = cursor.fetchone()
            if row is None:
                return None
            return self._as_int(row[0])

    def list_user_labs(self, user_id: int) -> list[dict[str, Any]]:
        with self._connection.cursor() as cursor:
            ref_cursor = cursor.callfunc(
                "pkg_genetics_game.list_user_labs",
                oracledb.DB_TYPE_CURSOR,
                [user_id],
            )
            try:
                return self._rows_from_refcursor(ref_cursor)
            finally:
                ref_cursor.close()

    def start_new_lab(self, session_token: str) -> int:
        with self._connection.cursor() as cursor:
            out_lab_id = cursor.var(oracledb.DB_TYPE_NUMBER)
            cursor.callproc(
                "pkg_genetics_game.start_new_lab",
                [session_token, out_lab_id],
            )
            return self._as_int(out_lab_id.getvalue())

    def load_lab(self, session_token: str, lab_id: int) -> None:
        with self._connection.cursor() as cursor:
            cursor.callproc("pkg_genetics_game.load_lab", [session_token, lab_id])

    def switch_lab(self, session_token: str, lab_id: int) -> None:
        with self._connection.cursor() as cursor:
            cursor.callproc("pkg_genetics_game.switch_lab", [session_token, lab_id])

    def get_lab_stats(self, lab_id: int) -> dict[str, Any]:
        with self._connection.cursor() as cursor:
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
                "wallet": self._as_float(out_wallet.getvalue()),
                "rating": self._as_float(out_rating.getvalue()),
                "creature_count": self._as_int(out_creature_count.getvalue()),
                "active_task_count": self._as_int(out_active_task_count.getvalue()),
                "completed_task_count": self._as_int(out_completed_task_count.getvalue()),
                "experiment_count": self._as_int(out_experiment_count.getvalue()),
            }

    def get_creatures(self, lab_id: int) -> list[dict[str, Any]]:
        with self._connection.cursor() as cursor:
            ref_cursor = cursor.callfunc(
                "pkg_genetics_game.get_creatures_cursor",
                oracledb.DB_TYPE_CURSOR,
                [lab_id],
            )
            try:
                return self._rows_from_refcursor(ref_cursor)
            finally:
                ref_cursor.close()

    def get_genotype(self, creature_id: int) -> list[dict[str, Any]]:
        with self._connection.cursor() as cursor:
            ref_cursor = cursor.callfunc(
                "pkg_genetics_game.get_genotype_cursor",
                oracledb.DB_TYPE_CURSOR,
                [creature_id],
            )
            try:
                return self._rows_from_refcursor(ref_cursor)
            finally:
                ref_cursor.close()

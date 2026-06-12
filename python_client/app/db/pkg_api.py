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
            user_id = cursor.callfunc(
                "pkg_genetics_game.resolve_user_id_by_token",
                oracledb.DB_TYPE_NUMBER,
                [session_token],
            )
            if user_id is None:
                return None
            return self._as_int(user_id)

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

    def delete_lab(self, session_token: str, lab_id: int) -> None:
        with self._connection.cursor() as cursor:
            cursor.callproc("pkg_genetics_game.delete_lab", [session_token, lab_id])

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

    def get_tasks(self, lab_id: int) -> list[dict[str, Any]]:
        with self._connection.cursor() as cursor:
            ref_cursor = cursor.callfunc(
                "pkg_genetics_game.get_tasks_cursor",
                oracledb.DB_TYPE_CURSOR,
                [lab_id],
            )
            try:
                return self._rows_from_refcursor(ref_cursor)
            finally:
                ref_cursor.close()

    def check_task(self, lab_id: int, task_id: int, creature_id: int) -> int:
        with self._connection.cursor() as cursor:
            result = cursor.callfunc(
                "pkg_genetics_game.check_task",
                oracledb.DB_TYPE_NUMBER,
                [lab_id, task_id, creature_id],
            )
            return self._as_int(result)

    def complete_task(self, lab_id: int, task_id: int, creature_id: int) -> dict[str, Any]:
        with self._connection.cursor() as cursor:
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
                "is_completed": self._as_int(out_is_completed.getvalue()),
                "wallet_after": self._as_float(out_wallet_after.getvalue()),
                "rating_after": self._as_float(out_rating_after.getvalue()),
            }

    def calculate_punnett_probabilities(
        self,
        entity_a_id: int,
        entity_b_id: int,
        gene_id: int,
    ) -> list[dict[str, Any]]:
        with self._connection.cursor() as cursor:
            ref_cursor = cursor.callfunc(
                "pkg_genetics_game.calculate_punnett_probabilities",
                oracledb.DB_TYPE_CURSOR,
                [entity_a_id, entity_b_id, gene_id],
            )
            try:
                return self._rows_from_refcursor(ref_cursor)
            finally:
                ref_cursor.close()

    def crossbreed(
        self,
        lab_id: int,
        entity_a_id: int,
        entity_b_id: int,
        result_name: str,
    ) -> int:
        with self._connection.cursor() as cursor:
            out_offspring_id = cursor.var(oracledb.DB_TYPE_NUMBER)
            cursor.callproc(
                "pkg_genetics_game.crossbreed",
                [lab_id, entity_a_id, entity_b_id, result_name, out_offspring_id],
            )
            return self._as_int(out_offspring_id.getvalue())

    def show_mutation_shop(self) -> list[dict[str, Any]]:
        with self._connection.cursor() as cursor:
            ref_cursor = cursor.callfunc(
                "pkg_genetics_game.show_mutation_shop",
                oracledb.DB_TYPE_CURSOR,
                [],
            )
            try:
                return self._rows_from_refcursor(ref_cursor)
            finally:
                ref_cursor.close()

    def buy_mutation(self, lab_id: int, mutation_id: int) -> int:
        with self._connection.cursor() as cursor:
            result = cursor.callfunc(
                "pkg_genetics_game.buy_mutation",
                oracledb.DB_TYPE_NUMBER,
                [lab_id, mutation_id],
            )
            return self._as_int(result)

    def apply_mutation(self, creature_id: int, mutation_id: int) -> None:
        with self._connection.cursor() as cursor:
            cursor.callproc(
                "pkg_genetics_game.apply_mutation",
                [creature_id, mutation_id],
            )

    def apply_mutagen(self, creature_id: int, mutagen_type: str) -> int:
        with self._connection.cursor() as cursor:
            out_new_creature_id = cursor.var(oracledb.DB_TYPE_NUMBER)
            cursor.callproc(
                "pkg_genetics_game.apply_mutagen",
                [creature_id, mutagen_type, out_new_creature_id],
            )
            return self._as_int(out_new_creature_id.getvalue())

    def get_mutation_target_genes(self, mutation_id: int) -> list[dict[str, Any]]:
        with self._connection.cursor() as cursor:
            ref_cursor = cursor.callfunc(
                "pkg_genetics_game.get_mutation_target_genes_cursor",
                oracledb.DB_TYPE_CURSOR,
                [mutation_id],
            )
            try:
                return self._rows_from_refcursor(ref_cursor)
            finally:
                ref_cursor.close()

    def get_compatible_creature_ids_for_mutation(self, lab_id: int, mutation_id: int) -> list[int]:
        with self._connection.cursor() as cursor:
            ref_cursor = cursor.callfunc(
                "pkg_genetics_game.get_compatible_creatures_for_mutation_cursor",
                oracledb.DB_TYPE_CURSOR,
                [lab_id, mutation_id],
            )
            try:
                rows = self._rows_from_refcursor(ref_cursor)
            finally:
                ref_cursor.close()
            return [self._as_int(row.get("creature_id")) for row in rows]

    def get_lab_mutation_quantity(self, lab_id: int, mutation_id: int) -> int:
        with self._connection.cursor() as cursor:
            quantity = cursor.callfunc(
                "pkg_genetics_game.get_lab_mutation_quantity",
                oracledb.DB_TYPE_NUMBER,
                [lab_id, mutation_id],
            )
            return self._as_int(quantity)

    def get_experiment_history(
        self,
        lab_id: int,
        experiment_type: str | None = None,
    ) -> list[dict[str, Any]]:
        with self._connection.cursor() as cursor:
            ref_cursor = cursor.callfunc(
                "pkg_genetics_game.get_experiment_history",
                oracledb.DB_TYPE_CURSOR,
                [lab_id, experiment_type],
            )
            try:
                return self._rows_from_refcursor(ref_cursor)
            finally:
                ref_cursor.close()




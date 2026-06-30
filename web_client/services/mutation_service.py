from __future__ import annotations

from typing import Any

import oracledb

from services.oracle import rows_from_refcursor, run_db


def get_mutation_shop(session_token: str, lab_id: int) -> list[dict[str, Any]]:
    def action(connection: oracledb.Connection) -> list[dict[str, Any]]:
        with connection.cursor() as cursor:
            cursor.callproc("pkg_genetics_game.load_lab", [session_token, lab_id])
            ref_cursor = cursor.callfunc(
                "pkg_genetics_game.show_mutation_shop",
                oracledb.DB_TYPE_CURSOR,
                [],
            )
            try:
                return rows_from_refcursor(ref_cursor)
            finally:
                ref_cursor.close()

    return run_db(action)


def buy_mutation(session_token: str, lab_id: int, mutation_id: int) -> int:
    def action(connection: oracledb.Connection) -> int:
        with connection.cursor() as cursor:
            cursor.callproc("pkg_genetics_game.load_lab", [session_token, lab_id])
            result = cursor.callfunc(
                "pkg_genetics_game.buy_mutation",
                oracledb.DB_TYPE_NUMBER,
                [lab_id, mutation_id],
            )
            return 0 if result is None else int(result)

    return run_db(action)


def apply_mutation(
    session_token: str,
    lab_id: int,
    creature_id: int,
    mutation_id: int,
) -> None:
    def action(connection: oracledb.Connection) -> None:
        with connection.cursor() as cursor:
            cursor.callproc("pkg_genetics_game.load_lab", [session_token, lab_id])
            cursor.callproc("pkg_genetics_game.apply_mutation", [creature_id, mutation_id])

    run_db(action)


def apply_mutagen(
    session_token: str,
    lab_id: int,
    creature_id: int,
    mutagen_type: str,
) -> int:
    def action(connection: oracledb.Connection) -> int:
        with connection.cursor() as cursor:
            cursor.callproc("pkg_genetics_game.load_lab", [session_token, lab_id])
            out_new_creature_id = cursor.var(oracledb.DB_TYPE_NUMBER)
            cursor.callproc(
                "pkg_genetics_game.apply_mutagen",
                [creature_id, mutagen_type, out_new_creature_id],
            )
            value = out_new_creature_id.getvalue()
            return 0 if value is None else int(value)

    return run_db(action)

def get_compatible_creatures_for_mutation(
    session_token: str,
    lab_id: int,
    mutation_id: int,
) -> list[dict[str, Any]]:
    def action(connection: oracledb.Connection) -> list[dict[str, Any]]:
        with connection.cursor() as cursor:
            cursor.callproc("pkg_genetics_game.load_lab", [session_token, lab_id])
            ref_cursor = cursor.callfunc(
                "pkg_genetics_game.get_compatible_creatures_for_mutation_cursor",
                oracledb.DB_TYPE_CURSOR,
                [lab_id, mutation_id],
            )
            try:
                return rows_from_refcursor(ref_cursor)
            finally:
                ref_cursor.close()

    return run_db(action)
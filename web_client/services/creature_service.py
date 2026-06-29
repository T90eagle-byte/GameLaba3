from __future__ import annotations

from typing import Any

import oracledb

from services.oracle import rows_from_refcursor, run_db


def get_creatures(session_token: str, lab_id: int) -> list[dict[str, Any]]:
    def action(connection: oracledb.Connection) -> list[dict[str, Any]]:
        with connection.cursor() as cursor:
            cursor.callproc("pkg_genetics_game.load_lab", [session_token, lab_id])
            ref_cursor = cursor.callfunc(
                "pkg_genetics_game.get_creatures_cursor",
                oracledb.DB_TYPE_CURSOR,
                [lab_id],
            )
            try:
                return rows_from_refcursor(ref_cursor)
            finally:
                ref_cursor.close()

    return run_db(action)


def get_genotype(
    session_token: str,
    creature_id: int,
    lab_id: int | None = None,
) -> list[dict[str, Any]]:
    if not session_token:
        return []

    def action(connection: oracledb.Connection) -> list[dict[str, Any]]:
        with connection.cursor() as cursor:
            if lab_id is not None:
                cursor.callproc("pkg_genetics_game.load_lab", [session_token, lab_id])
            ref_cursor = cursor.callfunc(
                "pkg_genetics_game.get_genotype_cursor",
                oracledb.DB_TYPE_CURSOR,
                [creature_id],
            )
            try:
                return rows_from_refcursor(ref_cursor)
            finally:
                ref_cursor.close()

    return run_db(action)


def get_creature_detail(
    session_token: str,
    lab_id: int,
    creature_id: int,
) -> dict[str, Any] | None:
    creatures = get_creatures(session_token, lab_id)
    for creature in creatures:
        if int(creature.get("creature_id", 0)) == creature_id:
            return creature
    return None
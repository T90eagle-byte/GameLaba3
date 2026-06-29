from __future__ import annotations

import oracledb

from services.oracle import run_db


def register_user(username: str, login: str, password: str) -> int:
    def action(connection: oracledb.Connection) -> int:
        with connection.cursor() as cursor:
            out_user_id = cursor.var(oracledb.DB_TYPE_NUMBER)
            cursor.callproc(
                "pkg_genetics_game.register_user",
                [username, login, password, out_user_id],
            )
            return int(out_user_id.getvalue())

    return run_db(action)


def login_user(login: str, password: str) -> str | None:
    def action(connection: oracledb.Connection) -> str | None:
        with connection.cursor() as cursor:
            token = cursor.callfunc(
                "pkg_genetics_game.login_user",
                str,
                [login, password],
            )
            return None if token is None else str(token)

    return run_db(action)


def logout_user(session_token: str) -> None:
    def action(connection: oracledb.Connection) -> None:
        with connection.cursor() as cursor:
            cursor.callproc("pkg_genetics_game.logout_user", [session_token])

    run_db(action)

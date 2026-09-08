from __future__ import annotations

import sys
import uuid
from pathlib import Path

import oracledb


REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from database.scripts.run_tests import DEFAULT_ENV_PATH, create_connection, load_oracle_settings  # noqa: E402


PASSWORD = "Profile_security_123"


def oracle_code(exc: oracledb.DatabaseError) -> int:
    return -abs(int(getattr(exc.args[0], "code", 0)))


def expect_code(action: object, expected: int, label: str) -> None:
    try:
        action()  # type: ignore[operator]
    except oracledb.DatabaseError as exc:
        actual = oracle_code(exc)
        if actual != expected:
            raise AssertionError(f"{label}: expected {expected}, got {actual}: {exc}") from exc
    else:
        raise AssertionError(f"{label}: expected Oracle error {expected}")


def main() -> int:
    connection = create_connection(load_oracle_settings(DEFAULT_ENV_PATH))
    suffix = uuid.uuid4().hex[:12]
    owner_login = f"p{suffix}"
    foreign_login = f"q{suffix}"
    user_ids: list[int] = []
    try:
        with connection.cursor() as cursor:
            for login in (owner_login, foreign_login):
                out_user_id = cursor.var(oracledb.NUMBER)
                cursor.callproc("pkg_genetics_game.register_user", [f"Profile {login}", login, PASSWORD, out_user_id])
                user_ids.append(int(out_user_id.getvalue()))

            owner_token = str(cursor.callfunc("pkg_genetics_game.login_user", str, [owner_login, PASSWORD]))
            cursor.callproc("pkg_genetics_game.update_user_profile", [owner_token, "Owner by token", None])
            cursor.execute("select username from users where user_id = :id", id=user_ids[0])
            assert cursor.fetchone()[0] == "Owner by token"

            # Legacy signature remains safe when an authenticated package context exists.
            cursor.callproc("pkg_genetics_game.update_user_profile", [user_ids[0], "Owner legacy", None])
            cursor.execute("select username from users where user_id = :id", id=user_ids[0])
            assert cursor.fetchone()[0] == "Owner legacy"

            expect_code(
                lambda: cursor.callproc("pkg_genetics_game.update_user_profile", [user_ids[1], "Forbidden", None]),
                -20079,
                "authenticated owner cannot update another account",
            )
            expect_code(
                lambda: cursor.callproc("pkg_genetics_game.update_user_profile", [-999999999, "Missing", None]),
                -20079,
                "nonexistent user id",
            )
            expect_code(
                lambda: cursor.callproc("pkg_genetics_game.update_user_profile", ["missing-session-token", "Missing", None]),
                -20020,
                "unknown token",
            )

            cursor.callproc("pkg_genetics_game.logout_user", [owner_token])
            expect_code(
                lambda: cursor.callproc("pkg_genetics_game.update_user_profile", [owner_token, "Closed", None]),
                -20020,
                "closed token",
            )
            expect_code(
                lambda: cursor.callproc("pkg_genetics_game.update_user_profile", [user_ids[0], "No context", None]),
                -20066,
                "legacy call without active context",
            )

        print("PASS: token-authenticated owner updates own profile")
        print("PASS: legacy signature is restricted to the active owner")
        print("PASS: foreign account, unknown token, and closed session are rejected")
        return 0
    finally:
        with connection.cursor() as cursor:
            if user_ids:
                binds = {f"u{i}": value for i, value in enumerate(user_ids)}
                slots = ", ".join(f":u{i}" for i in range(len(user_ids)))
                cursor.execute(f"delete from sessions where user_id in ({slots})", binds)
                cursor.execute(f"delete from users where user_id in ({slots})", binds)
        connection.close()


if __name__ == "__main__":
    raise SystemExit(main())

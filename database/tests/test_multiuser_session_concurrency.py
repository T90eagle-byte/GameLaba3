from __future__ import annotations

import sys
import threading
import time
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import oracledb


REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from database.scripts.run_tests import (  # noqa: E402
    DEFAULT_ENV_PATH,
    create_connection,
    load_oracle_settings,
)


PASSWORD = "Multi_user_123"


def oracle_code(exc: oracledb.DatabaseError) -> int:
    return -abs(int(getattr(exc.args[0], "code", 0)))


@dataclass
class Client:
    connection: oracledb.Connection
    token: str
    session_id: int

    def call(self, name: str, args: list[Any]) -> None:
        with self.connection.cursor() as cursor:
            cursor.callproc(f"pkg_genetics_game.{name}", args)

    def start_lab(self, name: str) -> int:
        with self.connection.cursor() as cursor:
            out_lab_id = cursor.var(oracledb.DB_TYPE_NUMBER)
            cursor.callproc(
                "pkg_genetics_game.start_new_lab",
                [self.token, name, out_lab_id],
            )
            return int(out_lab_id.getvalue())

    def load_lab(self, lab_id: int) -> None:
        self.call("load_lab", [self.token, lab_id])

    def recover_lab(self, lab_id: int) -> None:
        self.call("recover_lab_access", [self.token, lab_id])

    def stats(self, lab_id: int) -> None:
        with self.connection.cursor() as cursor:
            outputs = [cursor.var(oracledb.DB_TYPE_NUMBER) for _ in range(6)]
            cursor.callproc("pkg_genetics_game.get_lab_stats", [lab_id, *outputs])

    def rename_creature(self, creature_id: int, name: str) -> None:
        self.call("rename_creature", [creature_id, name])


def scalar(connection: oracledb.Connection, sql: str, binds: dict[str, Any]) -> Any:
    with connection.cursor() as cursor:
        cursor.execute(sql, binds)
        return cursor.fetchone()[0]


def first_creature(connection: oracledb.Connection, lab_id: int) -> int:
    return int(scalar(connection, "select min(creature_id) from creatures where lab_id = :id", {"id": lab_id}))


def wait_for_lab_lock(connection: oracledb.Connection, lab_id: int, timeout: float = 10.0) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            with connection.cursor() as cursor:
                cursor.execute(
                    "select lab_id from labs where lab_id = :id for update nowait",
                    {"id": lab_id},
                )
            connection.rollback()
        except oracledb.DatabaseError as exc:
            connection.rollback()
            if oracle_code(exc) == -54:
                return
            raise
        time.sleep(0.05)
    raise AssertionError(f"lab {lab_id} was not locked by the in-flight operation")


def register(connection: oracledb.Connection, login: str) -> int:
    with connection.cursor() as cursor:
        out_user_id = cursor.var(oracledb.DB_TYPE_NUMBER)
        cursor.callproc(
            "pkg_genetics_game.register_user",
            [f"Concurrency {login}", login, PASSWORD, out_user_id],
        )
        return int(out_user_id.getvalue())


def login(settings: Any, login_name: str) -> Client:
    connection = create_connection(settings)
    with connection.cursor() as cursor:
        token = cursor.callfunc(
            "pkg_genetics_game.login_user",
            oracledb.DB_TYPE_VARCHAR,
            [login_name, PASSWORD],
        )
        cursor.execute(
            "select session_id from sessions where session_token = :token",
            {"token": token},
        )
        session_id = int(cursor.fetchone()[0])
    return Client(connection=connection, token=str(token), session_id=session_id)


def expect_code(action: Any, expected: int, label: str) -> None:
    try:
        action()
    except oracledb.DatabaseError as exc:
        actual = oracle_code(exc)
        if actual != expected:
            raise AssertionError(f"{label}: expected {expected}, got {actual}: {exc}") from exc
    else:
        raise AssertionError(f"{label}: expected Oracle error {expected}")


def cleanup(connection: oracledb.Connection, user_ids: list[int]) -> None:
    binds = {f"u{index}": user_id for index, user_id in enumerate(user_ids)}
    placeholders = ", ".join(f":u{index}" for index in range(len(user_ids)))
    lab_query = f"select lab_id from labs where user_id in ({placeholders})"
    statements = [
        f"delete from rating_events where lab_id in ({lab_query})",
        f"delete from lab_tasks where lab_id in ({lab_query})",
        f"delete from lab_mutations where lab_id in ({lab_query})",
        f"delete from experiments where lab_id in ({lab_query})",
        f"delete from genotypes where creature_id in (select creature_id from creatures where lab_id in ({lab_query}))",
        f"delete from creatures where lab_id in ({lab_query})",
        f"delete from labs where user_id in ({placeholders})",
        f"delete from sessions where user_id in ({placeholders})",
        f"delete from users where user_id in ({placeholders})",
    ]
    with connection.cursor() as cursor:
        for statement in statements:
            cursor.execute(statement, binds)


def main() -> int:
    settings = load_oracle_settings(DEFAULT_ENV_PATH)
    admin = create_connection(settings)
    suffix = uuid.uuid4().hex[:12]
    owner_login = f"m{suffix}"
    foreign_login = f"n{suffix}"
    clients: list[Client] = []
    user_ids: list[int] = []
    blocker: oracledb.Connection | None = None

    try:
        owner_id = register(admin, owner_login)
        foreign_id = register(admin, foreign_login)
        user_ids.extend([owner_id, foreign_id])

        first = login(settings, owner_login)
        second = login(settings, owner_login)
        observer = login(settings, owner_login)
        abandoned = login(settings, owner_login)
        foreign = login(settings, foreign_login)
        clients.extend([first, second, observer, abandoned, foreign])

        first_lab = first.start_lab("First session lab")
        second_lab = second.start_lab("Second session lab")
        observer_lab = observer.start_lab("Observer lab")
        replacement_observer_lab = observer.start_lab("Observer replacement lab")
        assert scalar(admin, "select session_id from labs where lab_id = :id", {"id": observer_lab}) is None
        observer_lab = replacement_observer_lab
        race_lab = abandoned.start_lab("Concurrent target")
        abandoned.call("exit_lab", [race_lab])
        foreign_lab = foreign.start_lab("Foreign lab")

        expect_code(
            lambda: second.load_lab(first_lab),
            -20072,
            "ordinary conflict",
        )
        second.connection.rollback()
        assert scalar(admin, "select session_id from labs where lab_id = :id", {"id": second_lab}) == second.session_id
        assert scalar(admin, "select status from sessions where session_id = :id", {"id": first.session_id}) == "ACTIVE"

        barrier = threading.Barrier(2)
        race_results: dict[str, int | str] = {}

        def compete(label: str, client: Client) -> None:
            try:
                barrier.wait(timeout=10)
                client.load_lab(race_lab)
                race_results[label] = "ok"
            except oracledb.DatabaseError as exc:
                race_results[label] = oracle_code(exc)
                client.connection.rollback()

        threads = [
            threading.Thread(target=compete, args=("first", first), daemon=True),
            threading.Thread(target=compete, args=("second", second), daemon=True),
        ]
        for thread in threads:
            thread.start()
        for thread in threads:
            thread.join(timeout=30)
        assert all(not thread.is_alive() for thread in threads), "concurrent load timed out"
        assert sorted(race_results.values(), key=str) == [-20072, "ok"], race_results

        winner = first if race_results["first"] == "ok" else second
        loser = second if winner is first else first
        loser_original_lab = second_lab if loser is second else first_lab
        winner_original_lab = first_lab if winner is first else second_lab
        assert scalar(admin, "select session_id from labs where lab_id = :id", {"id": race_lab}) == winner.session_id
        assert scalar(admin, "select session_id from labs where lab_id = :id", {"id": loser_original_lab}) == loser.session_id
        assert scalar(admin, "select session_id from labs where lab_id = :id", {"id": winner_original_lab}) is None

        loser.recover_lab(race_lab)
        assert scalar(admin, "select session_id from labs where lab_id = :id", {"id": race_lab}) == loser.session_id
        assert scalar(admin, "select status from sessions where session_id = :id", {"id": winner.session_id}) == "ACTIVE"
        assert scalar(admin, "select session_id from labs where lab_id = :id", {"id": observer_lab}) == observer.session_id
        assert scalar(admin, "select session_id from labs where lab_id = :id", {"id": foreign_lab}) == foreign.session_id
        expect_code(lambda: winner.stats(race_lab), -20073, "previous holder loses selected lab")
        winner.connection.rollback()

        crash_lab = abandoned.start_lab("Abandoned browser lab")
        replacement = login(settings, owner_login)
        clients.append(replacement)
        expect_code(lambda: replacement.load_lab(crash_lab), -20072, "abandoned browser conflict")
        replacement.connection.rollback()
        replacement.recover_lab(crash_lab)
        assert scalar(admin, "select session_id from labs where lab_id = :id", {"id": crash_lab}) == replacement.session_id
        assert scalar(admin, "select status from sessions where session_id = :id", {"id": abandoned.session_id}) == "ACTIVE"
        expect_code(lambda: abandoned.stats(crash_lab), -20073, "abandoned session loses recovered lab")
        abandoned.connection.rollback()
        assert scalar(admin, "select session_id from labs where lab_id = :id", {"id": observer_lab}) == observer.session_id
        assert scalar(admin, "select status from sessions where session_id = :id", {"id": foreign.session_id}) == "ACTIVE"

        # Hold a creature row so the old holder reaches the gameplay update while
        # retaining the lab lock acquired by assert_lab_access.
        protected_creature = first_creature(admin, race_lab)
        foreign_creature = first_creature(admin, foreign_lab)
        current_holder = loser
        new_holder = winner
        blocker = create_connection(settings)
        blocker.autocommit = False
        with blocker.cursor() as cursor:
            cursor.execute(
                "select creature_id from creatures where creature_id = :id for update",
                {"id": protected_creature},
            )

        operation_done = threading.Event()
        takeover_done = threading.Event()
        operation_error: list[Exception] = []
        takeover_error: list[Exception] = []

        def delayed_operation() -> None:
            try:
                current_holder.rename_creature(protected_creature, "Committed before takeover")
            except Exception as exc:  # noqa: BLE001 - asserted below
                operation_error.append(exc)
            finally:
                operation_done.set()

        def delayed_takeover() -> None:
            try:
                new_holder.recover_lab(race_lab)
            except Exception as exc:  # noqa: BLE001 - asserted below
                takeover_error.append(exc)
            finally:
                takeover_done.set()

        operation_thread = threading.Thread(target=delayed_operation, daemon=True)
        operation_thread.start()
        wait_for_lab_lock(admin, race_lab)

        takeover_thread = threading.Thread(target=delayed_takeover, daemon=True)
        takeover_thread.start()
        time.sleep(0.2)
        assert not takeover_done.is_set(), "takeover bypassed an in-flight protected operation"

        # Unrelated owner/lab remains writable while the target lab is serialized.
        foreign.rename_creature(foreign_creature, "Independent operation")

        blocker.rollback()
        blocker.close()
        blocker = None
        operation_thread.join(timeout=15)
        takeover_thread.join(timeout=15)
        assert not operation_thread.is_alive() and not takeover_thread.is_alive(), "takeover race timed out"
        assert not operation_error, operation_error
        assert not takeover_error, takeover_error
        assert operation_done.is_set() and takeover_done.is_set()
        assert scalar(
            admin,
            "select creature_name from creatures where creature_id = :id",
            {"id": protected_creature},
        ) == "Committed before takeover"
        assert scalar(admin, "select session_id from labs where lab_id = :id", {"id": race_lab}) == new_holder.session_id
        new_holder.rename_creature(protected_creature, "New holder operation")
        expect_code(
            lambda: current_holder.rename_creature(protected_creature, "Stale holder operation"),
            -20073,
            "old holder cannot write after takeover",
        )
        current_holder.connection.rollback()

        print("PASS: create/switch releases only the current session's previous lab")
        print("PASS: independent sessions keep different labs")
        print("PASS: concurrent open has exactly one winner")
        print("PASS: selected recovery transfers one lab without closing sessions")
        print("PASS: abandoned-browser recovery leaves other labs and users untouched")
        print("PASS: in-flight gameplay finishes before takeover; stale holder is rejected afterwards")
        print("PASS: unrelated users and labs remain independent during takeover")
        return 0
    finally:
        if blocker is not None:
            blocker.rollback()
            blocker.close()
        for client in clients:
            client.connection.close()
        if user_ids:
            cleanup(admin, user_ids)
        admin.close()


if __name__ == "__main__":
    raise SystemExit(main())

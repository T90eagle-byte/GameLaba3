from __future__ import annotations

"""Create a repeatable, package-driven data set for the LR3 demonstration."""

import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

import oracledb

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from database.scripts.run_tests import create_connection, load_oracle_settings  # noqa: E402


DEMO_PASSWORD = "DemoLR3Pass2026"


@dataclass(frozen=True)
class DemoUser:
    login: str
    username: str


@dataclass(frozen=True)
class DemoLab:
    login: str
    name: str
    activity: str


DEMO_USERS = (
    DemoUser("lr3demoalpha", "Демо-исследователь Альфа"),
    DemoUser("lr3demobeta", "Демо-исследователь Бета"),
)

DEMO_LABS = (
    DemoLab("lr3demoalpha", "Альфа: стартовая популяция", "start"),
    DemoLab("lr3demoalpha", "Альфа: селекционная линия", "cross"),
    DemoLab("lr3demoalpha", "Альфа: заказы клиентов", "task"),
    DemoLab("lr3demoalpha", "Альфа: направленная мутация", "mutation"),
    DemoLab("lr3demoalpha", "Альфа: радиационный опыт", "radiation"),
    DemoLab("lr3demobeta", "Бета: стартовая популяция", "start"),
    DemoLab("lr3demobeta", "Бета: селекционная линия", "cross"),
    DemoLab("lr3demobeta", "Бета: заказы клиентов", "task"),
    DemoLab("lr3demobeta", "Бета: направленная мутация", "mutation"),
    DemoLab("lr3demobeta", "Бета: химический опыт", "chemical"),
)


class DemoSetupError(RuntimeError):
    pass


def scalar(cursor: oracledb.Cursor, sql: str, **params: object) -> object:
    cursor.execute(sql, params)
    row = cursor.fetchone()
    return row[0] if row else None


def ensure_user(cursor: oracledb.Cursor, user: DemoUser) -> int:
    user_id = scalar(cursor, "select user_id from users where login = :login", login=user.login)
    if user_id is not None:
        return int(user_id)

    out_user_id = cursor.var(oracledb.NUMBER)
    cursor.callproc(
        "pkg_genetics_game.register_user",
        [user.username, user.login, DEMO_PASSWORD, out_user_id],
    )
    return int(out_user_id.getvalue())


def login(cursor: oracledb.Cursor, user: DemoUser) -> str:
    token = cursor.callfunc(
        "pkg_genetics_game.login_user", str, [user.login, DEMO_PASSWORD]
    )
    if not token:
        raise DemoSetupError(f"Не удалось войти демонстрационным пользователем {user.login}.")
    return str(token)


def ensure_session_records(cursor: oracledb.Cursor, user: DemoUser, minimum: int = 5) -> str:
    token = login(cursor, user)
    count = int(
        scalar(cursor, "select count(*) from sessions s join users u on u.user_id = s.user_id where u.login = :login", login=user.login)
        or 0
    )
    while count < minimum:
        token = login(cursor, user)
        count += 1
    return token


def find_lab(cursor: oracledb.Cursor, user_id: int, name: str) -> int | None:
    lab_id = scalar(
        cursor,
        "select lab_id from labs where user_id = :user_id and lab_name = :name",
        user_id=user_id,
        name=name,
    )
    return int(lab_id) if lab_id is not None else None


def ensure_lab(cursor: oracledb.Cursor, token: str, user_id: int, spec: DemoLab) -> int:
    existing_lab_id = find_lab(cursor, user_id, spec.name)
    if existing_lab_id is not None:
        return existing_lab_id

    out_lab_id = cursor.var(oracledb.NUMBER)
    cursor.callproc("pkg_genetics_game.start_new_lab", [token, spec.name, out_lab_id])
    return int(out_lab_id.getvalue())


def activate_demo_lab(cursor: oracledb.Cursor, token: str, lab_id: int) -> None:
    # Recovery is intentionally scoped to one known lab of the same demo user.
    cursor.callproc("pkg_genetics_game.recover_lab_access", [token, lab_id])


def has_experiment(cursor: oracledb.Cursor, lab_id: int, experiment_type: str) -> bool:
    return bool(
        scalar(
            cursor,
            "select count(*) from experiments where lab_id = :lab_id and experiment_type = :experiment_type",
            lab_id=lab_id,
            experiment_type=experiment_type,
        )
    )


def ensure_crossbreed(cursor: oracledb.Cursor, token: str, lab_id: int) -> None:
    if has_experiment(cursor, lab_id, "CROSS"):
        return
    activate_demo_lab(cursor, token, lab_id)
    cursor.execute(
        """
        select species_type, creature_id
          from creatures
         where lab_id = :lab_id
         order by species_type, creature_id
        """,
        lab_id=lab_id,
    )
    parents: dict[int, list[int]] = {}
    for species_type, creature_id in cursor.fetchall():
        parents.setdefault(int(species_type), []).append(int(creature_id))
    pair = next((rows[:2] for rows in parents.values() if len(rows) >= 2), None)
    if pair is None:
        raise DemoSetupError(f"В лаборатории #{lab_id} не найдена пара родителей.")
    offspring_id = cursor.var(oracledb.NUMBER)
    cursor.callproc(
        "pkg_genetics_game.crossbreed",
        [lab_id, pair[0], pair[1], "Демо-потомок", offspring_id],
    )


def ensure_completed_task(cursor: oracledb.Cursor, token: str, lab_id: int) -> None:
    if scalar(cursor, "select count(*) from lab_tasks where lab_id = :lab_id and task_status = 'COMPLETED'", lab_id=lab_id):
        return
    activate_demo_lab(cursor, token, lab_id)
    cursor.execute("select task_id from lab_tasks where lab_id = :lab_id and task_status = 'ACTIVE' order by task_id", lab_id=lab_id)
    task_ids = [int(row[0]) for row in cursor.fetchall()]
    cursor.execute("select creature_id from creatures where lab_id = :lab_id order by creature_id", lab_id=lab_id)
    creature_ids = [int(row[0]) for row in cursor.fetchall()]
    for task_id in task_ids:
        for creature_id in creature_ids:
            matches = cursor.callfunc(
                "pkg_genetics_game.check_task", oracledb.NUMBER, [lab_id, task_id, creature_id]
            )
            if int(matches or 0) != 1:
                continue
            completed = cursor.var(oracledb.NUMBER)
            wallet = cursor.var(oracledb.NUMBER)
            rating = cursor.var(oracledb.NUMBER)
            cursor.callproc(
                "pkg_genetics_game.complete_task",
                [lab_id, task_id, creature_id, completed, wallet, rating],
            )
            return
    raise DemoSetupError(f"В лаборатории #{lab_id} не найдено существо для активного заказа.")


def compatible_creature(cursor: oracledb.Cursor, lab_id: int, mutation_id: int) -> int | None:
    ref_cursor = cursor.callfunc(
        "pkg_genetics_game.get_compatible_creatures_for_mutation_cursor",
        oracledb.CURSOR,
        [lab_id, mutation_id],
    )
    try:
        row = ref_cursor.fetchone()
        return int(row[0]) if row else None
    finally:
        ref_cursor.close()


def ensure_mutation(cursor: oracledb.Cursor, token: str, lab_id: int) -> None:
    if has_experiment(cursor, lab_id, "MUTATION"):
        return
    activate_demo_lab(cursor, token, lab_id)
    cursor.execute("select mutation_id from mutations order by cost, mutation_id")
    for (mutation_id_raw,) in cursor.fetchall():
        mutation_id = int(mutation_id_raw)
        creature_id = compatible_creature(cursor, lab_id, mutation_id)
        if creature_id is None:
            continue
        bought = cursor.callfunc("pkg_genetics_game.buy_mutation", oracledb.NUMBER, [lab_id, mutation_id])
        if int(bought or 0) != 1:
            continue
        cursor.callproc("pkg_genetics_game.apply_mutation", [creature_id, mutation_id])
        return
    raise DemoSetupError(f"Для лаборатории #{lab_id} не найдена доступная совместимая мутация.")


def ensure_mutagen(cursor: oracledb.Cursor, token: str, lab_id: int, mutagen_type: str) -> None:
    if has_experiment(cursor, lab_id, "MUTAGEN"):
        return
    activate_demo_lab(cursor, token, lab_id)
    creature_id = scalar(
        cursor,
        "select min(creature_id) from creatures where lab_id = :lab_id",
        lab_id=lab_id,
    )
    if creature_id is None:
        raise DemoSetupError(f"В лаборатории #{lab_id} нет существа для мутагена.")
    offspring_id = cursor.var(oracledb.NUMBER)
    cursor.callproc(
        "pkg_genetics_game.apply_mutagen",
        [int(creature_id), mutagen_type, offspring_id],
    )


def lab_needs_activity(cursor: oracledb.Cursor, lab_id: int, activity: str) -> bool:
    if activity == "start":
        return False
    experiment_type = "MUTAGEN" if activity in {"radiation", "chemical"} else activity.upper()
    if activity == "task":
        return not bool(
            scalar(
                cursor,
                "select count(*) from lab_tasks where lab_id = :lab_id and task_status = 'COMPLETED'",
                lab_id=lab_id,
            )
        )
    return not has_experiment(cursor, lab_id, experiment_type)


def user_needs_setup(cursor: oracledb.Cursor, user: DemoUser, user_id: int) -> bool:
    session_count = int(
        scalar(
            cursor,
            "select count(*) from sessions s where s.user_id = :user_id",
            user_id=user_id,
        )
        or 0
    )
    if session_count < 5:
        return True
    for spec in DEMO_LABS:
        if spec.login != user.login:
            continue
        lab_id = find_lab(cursor, user_id, spec.name)
        if lab_id is None or lab_needs_activity(cursor, lab_id, spec.activity):
            return True
    return False


def main() -> int:
    settings = load_oracle_settings(REPO_ROOT / "python_client" / ".env")
    connection = create_connection(settings)
    try:
        with connection.cursor() as cursor:
            user_ids = {user.login: ensure_user(cursor, user) for user in DEMO_USERS}
            users_to_prepare = [
                user for user in DEMO_USERS if user_needs_setup(cursor, user, user_ids[user.login])
            ]
            if not users_to_prepare:
                print("Демонстрационный набор ЛР3 уже подготовлен; данные не изменялись.")
                return 0

            tokens = {user.login: ensure_session_records(cursor, user) for user in users_to_prepare}
            lab_ids: dict[str, int] = {}
            for spec in DEMO_LABS:
                if spec.login not in tokens:
                    existing_lab_id = find_lab(cursor, user_ids[spec.login], spec.name)
                    if existing_lab_id is None:
                        raise DemoSetupError(f"Не найдена лаборатория {spec.name}.")
                    lab_ids[spec.name] = existing_lab_id
                else:
                    lab_ids[spec.name] = ensure_lab(
                        cursor, tokens[spec.login], user_ids[spec.login], spec
                    )

            actions: dict[str, Callable[[oracledb.Cursor, str, int], None]] = {
                "cross": ensure_crossbreed,
                "task": ensure_completed_task,
                "mutation": ensure_mutation,
            }
            for spec in DEMO_LABS:
                if spec.login not in tokens:
                    continue
                lab_id = lab_ids[spec.name]
                token = tokens[spec.login]
                if spec.activity in actions:
                    actions[spec.activity](cursor, token, lab_id)
                elif spec.activity == "radiation":
                    ensure_mutagen(cursor, token, lab_id, "RADIATION")
                elif spec.activity == "chemical":
                    ensure_mutagen(cursor, token, lab_id, "CHEMICAL")

            for token in tokens.values():
                cursor.callproc("pkg_genetics_game.logout_user", [token])
        print("Демонстрационный набор ЛР3 подготовлен. Запустите check_lr3_demo_data.py для проверки.")
        return 0
    finally:
        connection.close()


if __name__ == "__main__":
    raise SystemExit(main())

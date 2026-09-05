from __future__ import annotations

"""Validate that the separately created LR3 demonstration data is ready."""

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from database.scripts.create_lr3_demo_data import DEMO_LABS, DEMO_USERS  # noqa: E402
from database.scripts.run_tests import create_connection, load_oracle_settings  # noqa: E402


def scalar(cursor, sql: str, **params: object) -> int:
    cursor.execute(sql, params)
    return int(cursor.fetchone()[0] or 0)


def require(condition: bool, message: str, errors: list[str]) -> None:
    print(f"[{'OK' if condition else 'FAIL'}] {message}")
    if not condition:
        errors.append(message)


def main() -> int:
    settings = load_oracle_settings(REPO_ROOT / "python_client" / ".env")
    connection = create_connection(settings)
    errors: list[str] = []
    logins = tuple(user.login for user in DEMO_USERS)
    placeholders = ", ".join(f":login{index}" for index in range(len(logins)))
    params = {f"login{index}": login for index, login in enumerate(logins)}
    try:
        with connection.cursor() as cursor:
            users = scalar(cursor, f"select count(*) from users where login in ({placeholders})", **params)
            labs = scalar(
                cursor,
                f"select count(*) from labs l join users u on u.user_id = l.user_id where u.login in ({placeholders})",
                **params,
            )
            sessions = scalar(
                cursor,
                f"select count(*) from sessions s join users u on u.user_id = s.user_id where u.login in ({placeholders})",
                **params,
            )
            creatures = scalar(
                cursor,
                f"select count(*) from creatures c join labs l on l.lab_id = c.lab_id join users u on u.user_id = l.user_id where u.login in ({placeholders})",
                **params,
            )
            experiments = scalar(
                cursor,
                f"select count(*) from experiments e join labs l on l.lab_id = e.lab_id join users u on u.user_id = l.user_id where u.login in ({placeholders})",
                **params,
            )
            completed_tasks = scalar(
                cursor,
                f"select count(*) from lab_tasks lt join labs l on l.lab_id = lt.lab_id join users u on u.user_id = l.user_id where u.login in ({placeholders}) and lt.task_status = 'COMPLETED'",
                **params,
            )
            species = scalar(
                cursor,
                f"select count(distinct c.species_type) from creatures c join labs l on l.lab_id = c.lab_id join users u on u.user_id = l.user_id where u.login in ({placeholders})",
                **params,
            )
            expected_names = {spec.name for spec in DEMO_LABS}
            cursor.execute(
                f"select l.lab_name from labs l join users u on u.user_id = l.user_id where u.login in ({placeholders})",
                params,
            )
            actual_names = {str(row[0]) for row in cursor.fetchall()}

        require(users >= 2, f"демонстрационных пользователей: {users} (минимум 2)", errors)
        require(labs >= 10, f"демонстрационных лабораторий: {labs} (минимум 10)", errors)
        require(expected_names.issubset(actual_names), "все 10 именованных лабораторий созданы", errors)
        require(sessions >= 10, f"записей пользовательских сессий: {sessions} (минимум 10)", errors)
        require(creatures > 0, f"сохранённых существ: {creatures}", errors)
        require(experiments >= 6, f"сохранённых экспериментов: {experiments} (минимум 6)", errors)
        require(completed_tasks >= 2, f"выполненных заказов: {completed_tasks} (минимум 2)", errors)
        require(species == 6, f"представлено видов: {species} из 6", errors)
    finally:
        connection.close()

    if errors:
        print("\nНабор не готов к демонстрации ЛР3.")
        return 1
    print("\nНабор готов к демонстрации ЛР3.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

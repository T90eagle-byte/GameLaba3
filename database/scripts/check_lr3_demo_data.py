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
                f"select count(distinct c.species_type) from creatures c join labs l on l.lab_id = c.lab_id join users u on u.user_id = l.user_id where u.login in ({placeholders}) and c.species_type between 1 and 6",
                **params,
            )
            v1_labs = scalar(
                cursor,
                f"select count(*) from labs l join users u on u.user_id = l.user_id where u.login in ({placeholders}) and l.genetics_version = 1",
                **params,
            )
            v3_labs = scalar(
                cursor,
                f"select count(*) from labs l join users u on u.user_id = l.user_id where u.login in ({placeholders}) and l.genetics_version = 3",
                **params,
            )
            v3_starter_archetype_mismatches = scalar(
                cursor,
                f"""
                select count(*)
                  from (
                        select l.lab_id
                          from labs l
                          join users u on u.user_id = l.user_id
                          left join creatures c
                            on c.lab_id = l.lab_id
                           and c.species_type between 1 and 6
                           and c.archetype_id is not null
                         where u.login in ({placeholders})
                           and l.genetics_version = 3
                         group by l.lab_id
                        having count(c.creature_id) < 30
                  )
                """,
                **params,
            )
            v3_morphology_mismatches = scalar(
                cursor,
                f"""
                select count(*)
                  from (
                        select c.creature_id
                          from creatures c
                          join labs l on l.lab_id = c.lab_id
                          join users u on u.user_id = l.user_id
                          left join genotypes gt on gt.creature_id = c.creature_id
                          left join genes g on g.gene_id = gt.gene_id
                         where u.login in ({placeholders})
                           and l.genetics_version = 3
                         group by c.creature_id
                        having count(case when g.species_type = 0 and g.gene_type = 'morphology' then 1 end) <> 18
                  )
                """,
                **params,
            )
            v3_experiment_types = scalar(
                cursor,
                f"select count(distinct e.experiment_type) from experiments e join labs l on l.lab_id = e.lab_id join users u on u.user_id = l.user_id where u.login in ({placeholders}) and l.genetics_version = 3 and e.experiment_type in ('CROSS', 'MUTAGEN', 'CROSSBREED_MUTAGEN', 'HYBRIDIZATION')",
                **params,
            )
            hybrids = scalar(
                cursor,
                f"select count(*) from creatures c join labs l on l.lab_id = c.lab_id join users u on u.user_id = l.user_id where u.login in ({placeholders}) and l.genetics_version = 3 and c.species_type = 7 and c.archetype_id is null",
                **params,
            )
            hybrid_genotype_mismatches = scalar(
                cursor,
                f"""
                select count(*)
                  from (
                        select c.creature_id
                          from creatures c
                          join labs l on l.lab_id = c.lab_id
                          join users u on u.user_id = l.user_id
                          left join genotypes gt on gt.creature_id = c.creature_id
                          left join ref_genetics_model_genes rmg
                            on rmg.genetics_version = 3
                           and rmg.gene_id = gt.gene_id
                         where u.login in ({placeholders})
                           and l.genetics_version = 3
                           and c.species_type = 7
                         group by c.creature_id
                        having count(gt.gene_id) <> 19
                            or count(rmg.gene_id) <> 19
                  )
                """,
                **params,
            )
            active_v3_tasks = scalar(
                cursor,
                f"select count(*) from lab_tasks lt join labs l on l.lab_id = lt.lab_id join users u on u.user_id = l.user_id join tasks t on t.task_id = lt.task_id where u.login in ({placeholders}) and l.genetics_version = 3 and lt.task_status = 'ACTIVE' and t.genetics_version = 3",
                **params,
            )
            expected_names = {spec.name for spec in DEMO_LABS}
            cursor.execute(
                f"select l.lab_name from labs l join users u on u.user_id = l.user_id where u.login in ({placeholders})",
                params,
            )
            actual_names = {str(row[0]) for row in cursor.fetchall()}

        require(users >= 2, f"демонстрационных пользователей: {users} (минимум 2)", errors)
        require(labs >= 12, f"демонстрационных лабораторий: {labs} (10 v1 + 2 v3)", errors)
        require(expected_names.issubset(actual_names), "все именованные лаборатории созданы", errors)
        require(sessions >= 10, f"записей пользовательских сессий: {sessions} (минимум 10)", errors)
        require(creatures > 0, f"сохранённых существ: {creatures}", errors)
        require(experiments >= 6, f"сохранённых экспериментов: {experiments} (минимум 6)", errors)
        require(completed_tasks >= 2, f"выполненных заказов: {completed_tasks} (минимум 2)", errors)
        require(species == 6, f"представлено видов: {species} из 6", errors)
        require(v1_labs >= 10, f"исторических v1 лабораторий сохранено: {v1_labs}", errors)
        require(v3_labs >= 2, f"v3 витринных лабораторий: {v3_labs}", errors)
        require(v3_starter_archetype_mismatches == 0, "30 v3 стартовых существ каждой витрины имеют архетипы", errors)
        require(v3_morphology_mismatches == 0, "v3 существа имеют по 18 морфологических признаков", errors)
        require(v3_experiment_types == 4, "v3 витрины содержат CROSS, MUTAGEN, CROSSBREED_MUTAGEN и HYBRIDIZATION", errors)
        require(hybrids >= 1 and hybrid_genotype_mismatches == 0, "v3 гибриды имеют species=7, NULL archetype и 19 генов", errors)
        require(active_v3_tasks >= 2, f"активных v3 заданий: {active_v3_tasks}", errors)
    finally:
        connection.close()

    if errors:
        print("\nНабор не готов к демонстрации ЛР3.")
        return 1
    print("\nНабор готов к демонстрации ЛР3.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

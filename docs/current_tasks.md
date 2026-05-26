# Current Tasks

## 1) Текущий статус проекта

- Backend остается полностью в Oracle PL/SQL (`pkg_genetics_game`).
- Добавлен backend-механизм пополнения заданий: после успешного `complete_task` пакет пытается восстановить до `3` ACTIVE-заданий, если в `tasks` есть неназначенные задачи.
- Дубликаты `task_id` для одной лаборатории не создаются.
- Если пул `tasks` исчерпан, backend корректно оставляет меньше 3 ACTIVE-заданий и не падает.
- Python GUI не назначает задания сам и не содержит task-бизнес-логики.

## 2) Что изменено в strict pass (tasks refill)

- В `pkg_genetics_game.pkb` добавлен private helper `refill_active_tasks(p_lab_id, p_target_active default 3)`.
- `complete_task` после успешного завершения и начисления наград вызывает `refill_active_tasks` перед финальным `get_lab_stats`.
- За счет того, что auto-flow (`crossbreed` / `apply_mutation` / `apply_mutagen`) завершает задачи через `complete_task`, пополнение ACTIVE-заданий применяется и в auto-сценариях.

## 3) Обновленные smoke-tests

- `database/tests/06_tasks_smoke_test.sql`:
  - проверяет refill после `complete_task`;
  - проверяет отсутствие дубликатов `task_id` в `lab_tasks`;
  - корректно обрабатывает сценарий исчерпания пула `tasks`.
- `database/tests/07_strict_compliance_smoke_test.sql`:
  - проверяет refill после auto-complete (`apply_mutation`);
  - проверяет отсутствие дубликатов и ограничение по активным задачам.

## 4) Что прогнать на Oracle

1. `@database/packages/body/pkg_genetics_game.pkb`
2. `show errors package body pkg_genetics_game`
3. `@database/tests/06_tasks_smoke_test.sql`
4. `@database/tests/07_strict_compliance_smoke_test.sql`
5. При необходимости полный прогон `01..07`.

## 5) Ближайший GUI-check

- Открыть вкладку «Задания».
- Завершить подходящее задание.
- Нажать «Обновить задания».
- Убедиться, что появилось новое ACTIVE-задание, если в пуле `tasks` еще есть неназначенные.

## Content Compliance Pass (LR2)

Status: completed (no DDL or package API changes).

Completed work:
- Expanded `database/seeds/01_seed_core_game_data.sql`.
- Added mutation and mutation-rule coverage for weak traits:
  `nutrition_type`, `has_wings`, `fin_shape` (types 1 and 2), `claw_form`,
  `beak_nose_shape`, `shell_armor` (type 5), `fur_density`.
- Expanded task and marker pool to cover all `species_type 1..6` and
  universal traits (`color`, `size`, `nutrition_type`, `has_wings`).
- Updated smoke-tests:
  - `database/tests/02_seed_data_smoke_test.sql`;
  - `database/tests/07_strict_compliance_smoke_test.sql`.

Current content targets:
- genes: 12
- alleles: 24
- mutations: 8
- mutation_rules: 12
- tasks: 12
- task_markers: 21

Next step:
1. Run seed + checks on Oracle:
   - `@database/seeds/01_seed_core_game_data.sql`
   - `@database/tests/02_seed_data_smoke_test.sql`
   - `@database/tests/07_strict_compliance_smoke_test.sql`
2. If green, run full regression `01..07`.

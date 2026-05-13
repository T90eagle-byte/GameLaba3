# Gameplay Rules

## 1) Общая модель

Игрок управляет лабораторией, создает и модифицирует существ, проводит эксперименты и выполняет задания.

Критично:
- вся игровая логика на Oracle PL/SQL;
- Python только клиент GUI;
- backend API централизован в `pkg_genetics_game`.

## 2) Типы существ (MVP)

Используются 6 типов:
1. хрящевые рыбы
2. костные рыбы
3. ракообразные
4. моллюски
5. черепахи
6. млекопитающие

## 3) Реализованные игровые блоки в PL/SQL

### Auth/session
- `register_user`
- `login_user`
- `logout_user`
- `update_user_profile`

### Labs
- `start_new_lab`
- `load_lab`
- `switch_lab`
- `list_user_labs`
- `get_lab_stats`
- `delete_lab`

`start_new_lab` назначает стартовые `ACTIVE` задания в `lab_tasks`.

### Creatures/genetics
- `create_creature_of_type`
- `generate_starting_creatures`
- `get_phenotype`
- `get_creatures_cursor`
- `get_genotype_cursor`

`generate_starting_creatures` формирует 30 существ (6x5).

### Crossbreed
- `calculate_punnett_probabilities`
- `crossbreed`
- `rename_creature`

### Mutations/experiments
- `show_mutation_shop`
- `buy_mutation`
- `apply_mutation`
- `apply_mutagen`
- `make_experiment`
- `get_experiment_history`

### Tasks
- `get_tasks_cursor`
- `check_task`
- `complete_task`

## 4) Правила задач

- Задание считается выполненным, если для выбранного существа найдены все `task_markers.allele_id`.
- Проверка выполняется в `check_task` без изменения состояния БД.
- `complete_task`:
  - завершает `lab_tasks.task_status = 'COMPLETED'`
  - фиксирует `completed_at`
  - начисляет награды (`money_reward`, `rating_reward`) в `labs`
  - повторное завершение того же задания запрещено (ошибка `-20064`)

## 5) Данные для GUI

GUI получает данные только через:
- `SYS_REFCURSOR`
- OUT-параметры
- простые RETURN-типы

`dbms_output` не используется в runtime-интеграции GUI.

## 6) Текущее состояние реализации

- PL/SQL backend MVP реализован полностью.
- В `pkg_genetics_game.pkb` stubs отсутствуют.
- Проверки покрыты smoke-тестами `01..06`.


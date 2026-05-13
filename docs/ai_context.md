# AI context: "БиоСборка"

## Назначение проекта

`БиоСборка` — игра-симулятор генетического конструктора.  
Главный принцип: бизнес-логика в Oracle PL/SQL, Python 3.12 — GUI-клиент и слой вызова API БД.

Основные источники требований:
- `docs/ПСБД_ЛР1.pdf`
- `docs/ПСБД_ЛР2.pdf`

## Текущий статус проекта (зафиксировано)

- DDL создан и исправлен: `database/ddl/01_create_tables.sql`.
- Seed data создан: `database/seeds/01_seed_core_game_data.sql`.
- Package specification создан: `database/packages/spec/pkg_genetics_game.pks`.
- Package body создан: `database/packages/body/pkg_genetics_game.pkb`.
- Реализован vertical slice `auth/session/labs`.
- Реализован блок стартовых существ:
  - `create_creature_of_type`
  - `generate_starting_creatures`
  - `get_phenotype`
  - `get_creatures_cursor`
  - `get_genotype_cursor`
- Созданы smoke-tests:
  - `database/tests/01_auth_labs_smoke_test.sql`
  - `database/tests/02_seed_data_smoke_test.sql`
  - `database/tests/03_creature_generation_smoke_test.sql`

## Архитектурные решения MVP

1. Используются 6 типов существ из ЛР2:
   - хрящевые рыбы;
   - костные рыбы;
   - ракообразные;
   - моллюски;
   - черепахи;
   - млекопитающие.
2. Игровая авторизация реализуется через таблицу `users`.
3. Oracle roles/grants — для доступа приложения к схеме, не для отдельного Oracle-пользователя на каждого игрока.
4. В `genes` обязательны поля `species_type`, `dominance_type`, `linkage_group`.
5. В `creatures` хранятся кэш-поля часто отображаемого фенотипа + `phenotype_summary`.
6. Python-клиент не использует `dbms_output`; GUI получает данные через OUT-параметры, `sys_refcursor`, простые return-типы.

## Что уже работает логически

- регистрация пользователя;
- вход и выдача `session_token`;
- logout;
- создание/загрузка/переключение/удаление лаборатории;
- пересчет статистики лаборатории;
- загрузка стартовых справочников (`genes`, `alleles`, `mutations`, `tasks`, `mutation_rules`, `task_markers`);
- генерация существ по `species_type`;
- создание `genotypes`-записей;
- вычисление и кеширование `phenotype_summary`;
- GUI-friendly cursor API для существ и генотипов.

## Что пока не реализовано (stubs в package body)

- `calculate_punnett_probabilities`
- `crossbreed`
- `rename_creature`
- `show_mutation_shop`
- `buy_mutation`
- `apply_mutation`
- `apply_mutagen`
- `make_experiment`
- `get_experiment_history`
- `get_tasks_cursor`
- `check_task`
- `complete_task`

## Правило распределения ответственности

- Oracle PL/SQL принимает игровые решения и изменяет состояние игры.
- Python отображает данные, вызывает API пакета, обрабатывает ответы и ошибки.
- Перенос игровой логики из PL/SQL в Python запрещен.

## Следующая сессия: точка входа

1. Прогон в Oracle полной цепочки:
   `DDL -> seed -> package spec -> package body -> tests`.
2. При успешной проверке перейти к блоку скрещивания:
   `calculate_punnett_probabilities`, `crossbreed`, `rename_creature`.
3. Затем — к блоку мутаций и заданий.


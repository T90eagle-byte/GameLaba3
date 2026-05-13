# AI Context: БиоСборка

## 1) Назначение проекта

`БиоСборка` — игра-симулятор генетического конструктора.

Технологический принцип проекта:
- backend полностью в Oracle PL/SQL;
- Python 3.12 только как GUI-клиент и слой вызова API;
- центральная точка бизнес-логики: `pkg_genetics_game`.

Ключевые источники требований:
- `docs/ПСБД_ЛР1.pdf`
- `docs/ПСБД_ЛР2.pdf`

Оперативный контекст разработки:
- markdown-документация в `docs/`
- SQL/PLSQL-код в `database/`

## 2) Текущий статус (зафиксирован)

PL/SQL backend MVP реализован полностью.

Состояние артефактов:
- DDL готов: `database/ddl/01_create_tables.sql`
- seed data готов: `database/seeds/01_seed_core_game_data.sql`
- package spec готов: `database/packages/spec/pkg_genetics_game.pks`
- package body готов: `database/packages/body/pkg_genetics_game.pkb`
- stubs / `Not implemented yet` в package body больше нет

Реализованы группы API:
- auth/session
- labs
- creatures/genetics
- crossbreed
- mutations/experiments
- tasks

Smoke-tests созданы:
- `database/tests/01_auth_labs_smoke_test.sql`
- `database/tests/02_seed_data_smoke_test.sql`
- `database/tests/03_creature_generation_smoke_test.sql`
- `database/tests/04_crossbreed_smoke_test.sql`
- `database/tests/05_mutations_experiments_smoke_test.sql`
- `database/tests/06_tasks_smoke_test.sql`

Порядок запуска и проверки уже зафиксирован в:
- `database/README_RUN.md`

## 3) Архитектурные правила (обязательные)

1. Весь backend реализуется на Oracle PL/SQL.
2. Центральная точка backend-логики — `pkg_genetics_game`.
3. Python не является backend-слоем.
4. Python используется только как:
   - GUI
   - слой подключения к Oracle
   - слой вызова процедур/функций `pkg_genetics_game`
   - слой отображения данных пользователю
5. Python не считает:
   - генетику
   - скрещивание
   - мутации
   - экономику
   - задания
   - статистику лаборатории
6. Python не использует `dbms_output` как источник данных.
7. Все GUI-данные приходят только через:
   - `SYS_REFCURSOR`
   - OUT-параметры
   - простые RETURN-типы

## 4) Реализованные API в pkg_genetics_game.pkb

- `register_user`
- `login_user`
- `logout_user`
- `update_user_profile`
- `start_new_lab`
- `load_lab`
- `switch_lab`
- `list_user_labs`
- `get_lab_stats`
- `delete_lab`
- `create_creature_of_type`
- `generate_starting_creatures`
- `get_phenotype`
- `get_creatures_cursor`
- `get_genotype_cursor`
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

## 5) Что важно перед следующим этапом

Следующая практическая цель — реальный прогон в Oracle всей цепочки:

1. `database/ddl/01_create_tables.sql`
2. `database/seeds/01_seed_core_game_data.sql`
3. `database/packages/spec/pkg_genetics_game.pks`
4. `database/packages/body/pkg_genetics_game.pkb`
5. `database/tests/01_auth_labs_smoke_test.sql`
6. `database/tests/02_seed_data_smoke_test.sql`
7. `database/tests/03_creature_generation_smoke_test.sql`
8. `database/tests/04_crossbreed_smoke_test.sql`
9. `database/tests/05_mutations_experiments_smoke_test.sql`
10. `database/tests/06_tasks_smoke_test.sql`

Проверка компиляции:
- `show errors package pkg_genetics_game`
- `show errors package body pkg_genetics_game`
- `select * from user_errors where upper(name) = 'PKG_GENETICS_GAME'`


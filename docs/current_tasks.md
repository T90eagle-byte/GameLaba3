# Current Tasks

## 1) Текущий статус (checkpoint)

PL/SQL backend MVP реализован полностью.

Подтверждено по репозиторию:
- DDL готов: `database/ddl/01_create_tables.sql`
- seed data готов: `database/seeds/01_seed_core_game_data.sql`
- package spec готов: `database/packages/spec/pkg_genetics_game.pks`
- package body готов: `database/packages/body/pkg_genetics_game.pkb`
- stubs / `Not implemented yet` отсутствуют
- smoke-tests `01..06` созданы

Реализованы все группы API:
- auth/session
- labs
- creatures/genetics
- crossbreed
- mutations/experiments
- tasks

## 2) Последний реализованный блок

`Tasks`:
- `get_tasks_cursor`
- `check_task`
- `complete_task`

Дополнительно в `start_new_lab`:
- назначение стартовых `ACTIVE` заданий в `lab_tasks`.

## 3) Следующий конкретный шаг (с чего начинать следующую сессию)

Сначала выполнить реальный прогон в Oracle:

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

## 4) План после успешного прогона PL/SQL

1. Провести короткое архитектурное ревью backend.
2. Перейти к Python GUI:
   - подключение к Oracle
   - auth window
   - lab selection/creation
   - creatures view
   - genotype/phenotype view
   - crossbreed screen
   - mutations screen
   - tasks screen
   - experiment history screen

## 5) Файлы старта следующей сессии

- `database/README_RUN.md`
- `database/ddl/01_create_tables.sql`
- `database/seeds/01_seed_core_game_data.sql`
- `database/packages/spec/pkg_genetics_game.pks`
- `database/packages/body/pkg_genetics_game.pkb`
- `database/tests/01_auth_labs_smoke_test.sql`
- `database/tests/02_seed_data_smoke_test.sql`
- `database/tests/03_creature_generation_smoke_test.sql`
- `database/tests/04_crossbreed_smoke_test.sql`
- `database/tests/05_mutations_experiments_smoke_test.sql`
- `database/tests/06_tasks_smoke_test.sql`

## 6) Риски для следующей сессии

- package body еще не прогонялся в реальной Oracle-схеме;
- возможны компиляционные/ runtime-ошибки, не видимые статически;
- необходимы права `EXECUTE` на `DBMS_CRYPTO`;
- могут потребоваться права на `UTL_I18N` и `DBMS_RANDOM`;
- smoke-tests `01..06` еще нужно прогнать в реальной схеме;
- возможны расхождения фактических `sqlcode` после запуска;
- возможны проблемы `SYS_REFCURSOR` fetch в SQL Developer/SQLcl;
- Python GUI начинать только после подтверждения стабильного прогона backend.


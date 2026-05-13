# Project Roadmap

## 1) Текущий checkpoint

Backend MVP на Oracle PL/SQL завершен:
- DDL готов и стабилизирован
- seed data готов
- package spec готов
- package body реализован полностью (без stubs)
- smoke-tests `01..06` подготовлены

Реализованы все группы API:
- auth/session
- labs
- creatures/genetics
- crossbreed
- mutations/experiments
- tasks

## 2) Что уже закрыто

### Data layer
- `database/ddl/01_create_tables.sql`
- `database/seeds/01_seed_core_game_data.sql`

### PL/SQL API
- `database/packages/spec/pkg_genetics_game.pks`
- `database/packages/body/pkg_genetics_game.pkb`

### Smoke coverage
- `database/tests/01_auth_labs_smoke_test.sql`
- `database/tests/02_seed_data_smoke_test.sql`
- `database/tests/03_creature_generation_smoke_test.sql`
- `database/tests/04_crossbreed_smoke_test.sql`
- `database/tests/05_mutations_experiments_smoke_test.sql`
- `database/tests/06_tasks_smoke_test.sql`

### Run guide
- `database/README_RUN.md` содержит порядок запуска:
  - DDL
  - seed
  - package spec/body
  - smoke-tests `01..06`
  - `user_errors`

## 3) Ближайший следующий этап

### Этап A: реальный прогон на Oracle (обязательный)

Запустить:
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

Проверить компиляцию:
- `show errors package pkg_genetics_game`
- `show errors package body pkg_genetics_game`
- `select * from user_errors where upper(name) = 'PKG_GENETICS_GAME'`

### Этап B: архитектурное ревью PL/SQL backend

До GUI-этапа провести ревью:
- согласованность кодов ошибок
- стабильность cursor-контрактов для клиента
- повторяемость smoke-тестов

### Этап C: Python GUI

Стартовать только после успешного Этапа A:
- подключение к Oracle
- auth window
- lab selection/creation
- creatures view
- genotype/phenotype view
- crossbreed screen
- mutations screen
- tasks screen
- experiment history screen

## 4) Риски

- package body еще не подтвержден реальным запуском в Oracle;
- возможны runtime/компиляционные ошибки, не видимые при статическом ревью;
- нужны права `EXECUTE` на `DBMS_CRYPTO`;
- возможно нужны права на `UTL_I18N` и `DBMS_RANDOM`;
- возможны расхождения фактических `sqlcode` после запуска;
- возможны особенности `SYS_REFCURSOR` fetch в SQL Developer/SQLcl.


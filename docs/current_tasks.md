# Current tasks

## Текущий статус проекта (checkpoint)

Зафиксировано на текущем состоянии репозитория:

- DDL готов и исправлен: `database/ddl/01_create_tables.sql`.
- Seed data готов: `database/seeds/01_seed_core_game_data.sql`.
- Package specification готов: `database/packages/spec/pkg_genetics_game.pks`.
- Package body создан: `database/packages/body/pkg_genetics_game.pkb`.
- Реализован vertical slice `auth/session/labs`.
- Реализован блок стартовых существ:
  - `create_creature_of_type`
  - `generate_starting_creatures`
  - `get_phenotype`
  - `get_creatures_cursor`
  - `get_genotype_cursor`
- Smoke-tests:
  - `database/tests/01_auth_labs_smoke_test.sql` (auth/labs)
  - `database/tests/02_seed_data_smoke_test.sql` (seed data)
  - `database/tests/03_creature_generation_smoke_test.sql` (стартовые существа)
- Run guide обновлен: `database/README_RUN.md` включает запуск `03` smoke-test.

## Что уже работает логически

- регистрация пользователя;
- вход с выдачей `session_token`;
- logout;
- создание/загрузка/переключение/удаление лаборатории;
- пересчет статистики лаборатории;
- загрузка стартовых справочников (`genes/alleles/mutations/tasks`);
- генерация существ по `species_type`;
- создание `genotypes`-записей;
- вычисление и кеширование `phenotype_summary`;
- cursor API для GUI (`get_creatures_cursor`, `get_genotype_cursor`).

## Что пока stub (не реализовано)

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

## Последний реализованный блок

`Creature generation vertical slice`:
- создание стартовых существ;
- генерация генотипа;
- расчет и кэш фенотипа;
- выдача данных для GUI курсорами.

## Следующий конкретный шаг

1. Выполнить полный прогон в Oracle и зафиксировать фактический результат компиляции/выполнения:
   - `@database/ddl/01_create_tables.sql`
   - `@database/seeds/01_seed_core_game_data.sql`
   - `@database/packages/spec/pkg_genetics_game.pks`
   - `@database/packages/body/pkg_genetics_game.pkb`
   - `@database/tests/01_auth_labs_smoke_test.sql`
   - `@database/tests/02_seed_data_smoke_test.sql`
   - `@database/tests/03_creature_generation_smoke_test.sql`
2. Если все green — перейти к блоку скрещивания:
   - `calculate_punnett_probabilities`
   - `crossbreed`
   - `rename_creature`
3. После этого перейти к блоку мутаций и заданий.

## С чего начинать следующую сессию

### Файлы

- `database/packages/spec/pkg_genetics_game.pks`
- `database/packages/body/pkg_genetics_game.pkb`
- `database/tests/03_creature_generation_smoke_test.sql`
- `database/README_RUN.md`
- `docs/gameplay_rules.md`

### Команды проверки

```sql
show errors package pkg_genetics_game
show errors package body pkg_genetics_game

select name, type, line, position, text
from user_errors
where upper(name) = 'PKG_GENETICS_GAME'
order by sequence;
```

## Важные риски

1. Права в схеме:
   - нужен `EXECUTE` на `DBMS_CRYPTO`;
   - нужен `EXECUTE` на `UTL_I18N`;
   - для генерации аллелей используется `DBMS_RANDOM`.
2. Нужна проверка компиляции именно в Oracle (статическая проверка не эквивалентна runtime).
3. Возможны ошибки, не видимые без запуска:
   - данные seed/ограничения DDL;
   - runtime-ветки package body;
   - поведение курсоров и обработка исключений.

## Примечание по задачам из предыдущего плана

- Задача "создать `03_creature_generation_smoke_test.sql`" — выполнена.
- Задача "обновить `database/README_RUN.md` под `03` smoke-test" — выполнена.


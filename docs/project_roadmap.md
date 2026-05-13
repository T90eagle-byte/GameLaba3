# Project roadmap

## Сводный статус этапов

1. **Аналитика и архитектура** — выполнено.
2. **Oracle DDL** — выполнено (включая ревизии целостности).
3. **Seed data** — выполнено.
4. **Package specification** — выполнено.
5. **Package body (частично)** — в работе:
   - готов `auth/session/labs`;
   - готов блок стартовых существ и фенотипа;
   - мутации/скрещивание/задания пока stubs.
6. **Smoke-tests backend** — выполнены базовые сценарии:
   - `01_auth_labs_smoke_test.sql`
   - `02_seed_data_smoke_test.sql`
   - `03_creature_generation_smoke_test.sql`

## Что уже закрыто в backend MVP

- схема БД (`01_create_tables.sql`);
- справочники и стартовые данные (`01_seed_core_game_data.sql`);
- API-контракт (`pkg_genetics_game.pks`);
- рабочая часть `pkg_genetics_game.pkb`:
  - регистрация/логин/логаут/профиль;
  - создание и управление лабораторией;
  - статистика лаборатории;
  - генерация стартовых существ;
  - получение фенотипа;
  - курсоры для списка существ и генотипа.

## Что осталось до следующего функционального рубежа

### Этап A: проверка на реальной Oracle (обязательный)

Прогонить полный pipeline:
`DDL -> seed -> package spec -> package body -> tests`.

Цель: подтвердить компиляцию и runtime-поведение не только статически.

### Этап B: блок скрещивания

Реализовать:
- `calculate_punnett_probabilities`
- `crossbreed`
- `rename_creature`

Добавить smoke-test для crossbreed-сценария.

### Этап C: блок мутаций

Реализовать:
- `show_mutation_shop`
- `buy_mutation`
- `apply_mutation`
- `apply_mutagen`
- `make_experiment`
- `get_experiment_history`

Добавить smoke-test на покупку/применение мутаций.

### Этап D: блок заданий

Реализовать:
- `get_tasks_cursor`
- `check_task`
- `complete_task`

Добавить smoke-test на закрытие задания и начисление наград.

## Критерий готовности backend MVP

- package spec/body компилируются без ошибок;
- все smoke-tests проходят стабильно при повторном запуске;
- скрещивание, мутации и задания работают через PL/SQL API;
- Python-клиенту достаточно cursor/OUT-интерфейсов без чтения `dbms_output`.


# Database Map

## 1) Источники и приоритет

Карта основана на:
- `docs/ПСБД_ЛР1.pdf`
- `docs/ПСБД_ЛР2.pdf`
- фактическом DDL: `database/ddl/01_create_tables.sql`

При расхождении деталей оперативный приоритет у актуального DDL и текущего package API.

## 2) Физическая схема (актуальная)

Таблицы:
- `users`
- `sessions`
- `labs`
- `genes`
- `alleles`
- `creatures`
- `genotypes`
- `experiments`
- `mutations`
- `mutation_rules`
- `tasks`
- `lab_tasks`
- `lab_mutations`
- `task_markers`

Все PK поддерживаются отдельными sequence (`*_seq`).

## 3) Ключевые связи и ограничения

### Авторизация и лаборатории
- `users.login` уникален.
- `sessions.session_token` уникален.
- В `sessions` есть `status in ('ACTIVE', 'CLOSED')`.
- В `sessions` есть `unique (session_id, user_id)`.
- `labs` связана с пользователем и сессией:
  - FK `labs.user_id -> users.user_id`
  - FK `labs.session_id -> sessions.session_id`
  - составной FK `(session_id, user_id) -> sessions(session_id, user_id)`

### Генетика
- В `genes` обязательны поля:
  - `species_type` (0..6)
  - `dominance_type` (`FULL`, `INCOMPLETE`, `CODOMINANT`)
  - `linkage_group` (nullable)
- В `alleles` есть `unique (allele_id, gene_id)` для усиления целостности.
- В `genotypes` составные FK:
  - `(allele1_id, gene_id) -> alleles(allele_id, gene_id)`
  - `(allele2_id, gene_id) -> alleles(allele_id, gene_id)`
- В `creatures` есть кеш фенотипа:
  - `phenotype_color`
  - `phenotype_size`
  - `phenotype_has_wings`
  - `phenotype_nutrition_type`
  - `phenotype_summary`

### Мутации и эксперименты
- `mutation_rules`:
  - FK `mutation_id -> mutations`
  - FK `gene_id -> genes`
  - составной FK `(target_allele_id, gene_id) -> alleles(allele_id, gene_id)`
  - `target_slot in ('1', '2', 'ANY')`
- `experiments`:
  - `experiment_type in ('CROSS', 'MUTATION', 'MUTAGEN')`
  - `CROSS` требует `parent2_id is not null`
  - `MUTATION`/`MUTAGEN` требуют `parent2_id is null`

### Задания
- `lab_tasks` использует `task_status` (`ACTIVE`, `COMPLETED`), не `status`.
- `task_markers` задают требуемые `allele_id` для проверки выполнения.

## 4) Seed coverage (MVP)

`database/seeds/01_seed_core_game_data.sql` заполняет:
- 6 типов существ
- 12 генов
- 24 аллеля
- 4 мутации
- `mutation_rules`
- 6 заданий
- `task_markers`

## 5) Соответствие package API

Схема согласована с:
- `database/packages/spec/pkg_genetics_game.pks`
- `database/packages/body/pkg_genetics_game.pkb`

В package body реализованы все группы API, stubs отсутствуют.

## 6) Принцип интеграции с Python GUI

Python получает данные только через:
- `SYS_REFCURSOR`
- OUT-параметры
- простые RETURN-типы

`dbms_output` — только для smoke-tests и ручной диагностики, не для GUI.


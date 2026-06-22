# Project Roadmap: GameLR3 / «БиоСборка»

## Завершённые этапы

### 1. Backend stabilization
- `pkg_genetics_game` является центральным backend API.
- Package spec/body компилируются.
- `STANDARD_HASH` заменил `DBMS_CRYPTO`.
- Smoke-tests `01..09` подготовлены и проходят.

### 2. Domain reference tables
- Доменные enum-значения вынесены в `ref_*` таблицы.
- Package cursors возвращают display labels из БД.
- Python не является источником истины для игровых enum-справочников.

### 3. LR2 package compatibility
- В package добавлены LR2-compatible wrappers.
- Прямые SQL-запросы к игровым таблицам убраны из `pkg_api.py`.
- Python остаётся клиентом/display-layer.

### 4. Desktop GUI delivery
- PySide6 GUI реализован как desktop-версия.
- GUI не удалять: он остаётся локальным клиентом.
- Из-за Windows Server 2012 R2 будущий переносимый клиент планируется как browser-based web-client.

### 5. Backend audit and test runner
- Подготовлен `docs/backend_compliance_audit.md`.
- Подготовлен `docs/backend_expansion_plan.md`.
- Добавлен `database/scripts/run_tests.py`.
- Runner исправлен для seed/package/tests: BOM, SQL*Plus directives, одиночный `/`, `DBMS_OUTPUT` при ошибке.

### 6. First backend content expansion
- Выполнен первый seed-only content expansion.
- DDL не менялся.
- Package spec/body не менялись.
- `pkg_api.py` не менялся.
- PySide6 GUI/layout не менялся.
- Полный Oracle smoke suite `01..09` прошёл с `Failed: 0`.

## Текущая стадия: checkpoint after backend content expansion
Цель текущей стадии — сохранить зелёную контрольную точку перед следующим крупным backend треком.

Текущий стабильный статус:
- content expansion подтверждён tests;
- package `VALID`;
- `user_errors` clean;
- runner пригоден для локального Docker и учебного стенда;
- web-клиент ещё не начинался.

## Следующий крупный этап
### Rating foundation / `rating_events`
- спроектировать DDL для истории рейтинга;
- добавить package-запись rating events рядом с текущими изменениями рейтинга;
- покрыть smoke-tests;
- подготовить backend contract для будущего web dashboard.

## Отложено
- Web-клиент как отдельный этап после rating foundation или после отдельного решения.
- Strict provenance tasks для BREED/MUTATE.
- Новая большая волна genes/alleles/mutations/tasks.
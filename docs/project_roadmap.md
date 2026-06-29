# Project Roadmap: GameLR3 / «БиоСборка»

## Completed Stages

### 1. Backend stabilization
- `pkg_genetics_game` стал центральным backend API.
- Package spec/body компилируются.
- `STANDARD_HASH` заменил `DBMS_CRYPTO`.
- Python-клиент вызывает package через `callproc`/`callfunc`.

### 2. Domain reference tables
- Доменные enum-значения вынесены в `ref_*` tables.
- Package cursors возвращают display labels из БД.
- `tasks.difficulty_code` хранит сложность заданий в БД.
- Python больше не является source of truth для gameplay enums.

### 3. LR2 package compatibility
- LR2-compatible wrappers добавлены в package API.
- Все методы из ЛР2 присутствуют в package spec/body.
- Часть сигнатур адаптирована под session-token модель и Python/Oracle interoperability.

### 4. Desktop GUI delivery
- PySide6 GUI остается desktop-версией.
- На Windows Server 2012 R2 Qt6 ненадежен, поэтому переносимый клиент планируется как browser web-client.
- Desktop GUI не удалять.

### 5. Backend audit, runner, content expansion
- Создан предварительный `docs/backend_compliance_audit.md`.
- Создан `docs/backend_expansion_plan.md`.
- Добавлен `database/scripts/run_tests.py` для воспроизводимого запуска package/tests.
- Первый seed-only backend content expansion выполнен и проверен.

### 6. Rating foundation / `rating_events`
- Добавлены `ref_rating_event_types`, `rating_events`, `rating_events_seq`.
- Package пишет события для task rewards, mutation purchases, mutagen penalties и rating adjustments.
- `get_rating_events_cursor` возвращает историю изменений для будущего dashboard.
- Добавлен smoke-test `10_rating_events_smoke_test.sql`.
- Runner расширен до `01..10`.

### 7. Final backend and grade reviews
- Создан `docs/backend_final_requirements_review.md`.
- Создан `docs/grade_requirements_audit.md`.
- Уровень 3 закрыт уверенно.
- Уровень 4 закрыт в основном, с адаптацией “эволюционных линий” под задания/многовидовую “БиоСборку”.
- Уровень 5 не заявляется как реализованный.
- Полный Oracle runner `01..10` прошел с `Failed: 0`.
- `PKG_GENETICS_GAME`: `PACKAGE VALID`, `PACKAGE BODY VALID`.
- `user_errors`: clean.

## Current Stage: Level 4 Hardening
Текущий этап — не web-клиент, а укрепление демонстрации уровня “хорошо”.

Scope:
- явно описать задания как “заказы клиента”;
- описать “эволюционную линию” как путь через скрещивания/мутации к нужному фенотипу;
- подготовить defense demo script;
- подготовить requirements cheatsheet;
- проверить демонстрацию 3 вариантов потомства;
- не менять стабильный backend без отдельной причины.

## Next Stage: Web Client Planning
После hardening:
1. Создать `docs/web_client_plan.md`.
2. Спроектировать server-side слой поверх `pkg_genetics_game`.
3. Зафиксировать, что frontend/browser не подключается к Oracle напрямую.
4. Затем сделать минимальный Flask/Jinja web-каркас.

## Web Strategy
- Flask/Jinja предпочтительнее React/Vue для слабого учебного стенда.
- Интерфейс должен быть простой, быстрый и переносимый.
- Web server вызывает только package API.
- Frontend отображает данные и не считает генетику, экономику, рейтинг или задания.
- `rating_events` используется для объяснимой истории рейтинга/кошелька.
- PySide6 GUI остается в проекте как desktop-версия.

## Postponed
- Требования на 5: экосистема, смертность, совет по этике, закрытие лаборатории.
- Автоматические rare trait bonuses поверх зарезервированного `RARE_TRAIT_BONUS`.
- Строгие provenance tasks для BREED/MUTATE.
- Новая волна content expansion.
- Большие DDL-треки без отдельного плана и тестов.

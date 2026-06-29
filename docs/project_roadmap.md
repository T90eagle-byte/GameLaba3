# Project Roadmap: GameLR3 / «БиоСборка»

## Completed Stages

### 1. Backend Stabilization
- `pkg_genetics_game` стал центральным backend API.
- Package spec/body компилируются.
- `STANDARD_HASH` заменил `DBMS_CRYPTO`.
- Python-клиент вызывает package через `callproc`/`callfunc`.

### 2. Domain Reference Tables
- Доменные enum-значения вынесены в `ref_*` tables.
- Package cursors возвращают display labels из БД.
- `tasks.difficulty_code` хранит сложность заданий в БД.
- Python больше не является source of truth для gameplay enums.

### 3. LR2 Package Compatibility
- LR2-compatible wrappers добавлены в package API.
- Все методы из ЛР2 присутствуют в package spec/body.
- Часть сигнатур адаптирована под session-token модель и Python/Oracle interoperability.

### 4. Desktop GUI Delivery
- PySide6 GUI остается desktop-версией.
- На Windows Server 2012 R2 Qt6 ненадежен, поэтому переносимый клиент планируется как browser web-client.
- Desktop GUI не удалять.

### 5. Backend Audit, Runner, Content Expansion
- Создан предварительный `docs/backend_compliance_audit.md`.
- Создан `docs/backend_expansion_plan.md`.
- Добавлен `database/scripts/run_tests.py` для воспроизводимого запуска package/tests.
- Первый seed-only backend content expansion выполнен и проверен.

### 6. Rating Foundation / `rating_events`
- Добавлены `ref_rating_event_types`, `rating_events`, `rating_events_seq`.
- Package пишет события для task rewards, mutation purchases, mutagen penalties и rating adjustments.
- `get_rating_events_cursor` возвращает историю изменений для будущего dashboard.
- Добавлен smoke-test `10_rating_events_smoke_test.sql`.

### 7. Final Backend and Grade Reviews
- Создан `docs/backend_final_requirements_review.md`.
- Создан `docs/grade_requirements_audit.md`.
- Уровень 3 закрыт уверенно.
- Уровень 4 закрыт в адаптированной форме под многовидовую “БиоСборку”.
- Уровень 5 не заявляется как реализованный.

### 8. Offspring Preview Hardening
- Добавлен stateless backend API `preview_offspring_options`.
- По умолчанию API возвращает 3 preview-варианта потомства.
- Preview не создает creatures, genotypes, experiments и не меняет wallet/rating.
- Добавлен smoke-test `11_offspring_preview_smoke_test.sql`.
- Runner расширен до `01..11`.
- Ветка `backend-offspring-preview` влита в `main` merge-коммитом `81d8293`.
- Полный Oracle runner `01..11` прошел с `Failed: 0`.
- `PKG_GENETICS_GAME`: `PACKAGE VALID`, `PACKAGE BODY VALID`.
- `user_errors`: clean.

## Current Stage: Web Client Planning
Текущий этап — планирование легкого web-клиента без реализации кода.

Цель этапа:
- создать и поддерживать `docs/web_client_plan.md`;
- зафиксировать Flask/Jinja как простой server-side web поверх `pkg_genetics_game`;
- описать страницы, маршруты, service-layer и демонстрационный flow;
- сохранить бизнес-логику в Oracle PL/SQL.

## Next Stage: Minimal Flask/Jinja Skeleton
После утверждения плана:
1. Создать `web_client/` skeleton.
2. Реализовать config и Oracle connection helper через `.env`.
3. Добавить login/register/logout.
4. Добавить labs/dashboard.
5. Постепенно подключить creatures, tasks, crossbreed preview, mutations, experiments и rating events.

## Web Strategy
- Flask/Jinja предпочтительнее React/Vue для слабого учебного стенда.
- Интерфейс должен быть простым, быстрым и переносимым.
- Web server вызывает только package API.
- Frontend отображает данные и не считает генетику, экономику, рейтинг или задания.
- `rating_events` используется для объяснимой истории рейтинга/кошелька.
- `preview_offspring_options` используется для показа 3 вариантов потомства перед реальным `crossbreed`.
- PySide6 GUI остается в проекте как desktop-версия.

## Postponed
- Требования на 5: экосистема, смертность, совет по этике, закрытие лаборатории.
- Автоматические rare trait bonuses поверх зарезервированного `RARE_TRAIT_BONUS`.
- Строгие provenance tasks для BREED/MUTATE.
- Новая волна content expansion.
- Большие DDL-треки без отдельного плана и тестов.

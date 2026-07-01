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

### 9. Web Client Skeleton
- Создан `web_client/` на Flask/Jinja.
- Добавлены config, Oracle connection layer и thin services.
- Реализованы routes `/health`, `/register`, `/login`, `/logout`, `/labs`, `/dashboard`.
- Web использует package API и не содержит gameplay logic.

## Current Stage: Web Creatures / Tasks
Следующий этап — расширить web-клиент страницами существ и заказов клиента.

Scope:
- creatures list;
- creature detail genotype/phenotype;
- tasks page как “Заказы клиента”;
- без изменения backend.

## Next Stage: Crossbreed Preview UI
После creatures/tasks подключить страницу скрещивания:
- выбрать родителей;
- показать 3 варианта через `preview_offspring_options`;
- создать потомка через `crossbreed`.

## Web Strategy
- Flask/Jinja предпочтительнее React/Vue для слабого учебного стенда.
- Интерфейс должен быть простым, быстрым и переносимым.
- Web server вызывает только package API.
- Frontend отображает данные и не считает генетику, экономику, рейтинг или задания.
- PySide6 GUI остается в проекте как desktop-версия.

## Postponed
- Требования на 5: экосистема, смертность, совет по этике, закрытие лаборатории.
- Автоматические rare trait bonuses поверх зарезервированного `RARE_TRAIT_BONUS`.
- Строгие provenance tasks для BREED/MUTATE.
- Новая волна content expansion.
- Большие DDL-треки без отдельного плана и тестов.

## Checkpoint: web creatures/orders

Web-клиент перешёл от skeleton к первому демонстрационному игровому слою: список существ, карточка существа, генотип/фенотип и “Заказы клиента”. Backend при этом не менялся: Flask остаётся display-layer и вызывает только `pkg_genetics_game`.

Ближайшие шаги:
1. Web crossbreed: выбор родителей, preview 3 вариантов потомства, затем создание потомка.
2. Web mutations: магазин, покупка, применение, мутагены RADIATION/CHEMICAL.
3. Web history: experiments и `rating_events`.
4. Polish: страница защиты, аккуратные тексты, README для стенда.

## Checkpoint: web crossbreed preview

Web-клиент теперь закрывает ключевой демонстрационный сценарий уровня 3/4 в браузере: пользователь выбирает двух родителей, получает 3 preview-варианта потомства через backend API и отдельно создаёт реального потомка через `crossbreed`. Python не генерирует потомков и не считает генетику.

Дальше по web: mutations UI, mutagens RADIATION/CHEMICAL, experiments history, rating events page, затем polish для защиты.

## Checkpoint: web mutations

Web-клиент теперь показывает требования уровня 4 через UI: мутации, RADIATION, CHEMICAL и риск изменения wallet/rating. Все действия идут через `pkg_genetics_game`; backend не менялся.

Следующие шаги: `/experiments`, `/rating-events`, затем polish и страница защиты.

## Checkpoint: web history

Web-клиент теперь показывает цельную цепочку уровня 4: заказы клиента, подбор существ, preview 3 вариантов, скрещивание, мутации, мутагены, риск и историю последствий. Эволюционная линия доступна через `/experiments`, а изменения wallet/rating — через `/rating-events`.

Следующий шаг: polish, страница `/about-requirements`, финальная демонстрационная инструкция и smoke checklist.

## Roadmap checkpoint: web client ready for grade 3/4 defense

- Backend phase is complete and covered by smoke-tests `01..11`.
- Web demo route is complete for grade 3/4:
  - auth/labs/dashboard;
  - creatures/detail/genotype;
  - client orders;
  - crossbreed + 3-option preview;
  - mutations/mutagens;
  - experiments history;
  - rating events;
  - `/about-requirements`.
- Grade 5 remains roadmap and is not claimed as implemented.
- Practical next step: final clean launch and defense preparation.

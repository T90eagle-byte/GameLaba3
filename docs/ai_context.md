# AI Context: GameLR3 / «БиоСборка»

## Workspace
- Актуальный workspace: `C:\GameLR3`.
- Основная ветка: `main`.
- Текущая web-ветка: `web-client-skeleton`.
- Коммиты писать на русском языке.
- Не коммитить `.env`, `.venv`, `__pycache__`, временные файлы и backup-файлы.

## Архитектура
- Backend реализован на Oracle PL/SQL.
- Центральный backend API: `pkg_genetics_game`.
- Python/PySide6 и Flask/Jinja web остаются client/display-layer.
- Бизнес-логика остается в Oracle PL/SQL package.

## Backend Checkpoint
- Backend-фаза завершена и зафиксирована.
- `STANDARD_HASH` используется вместо `DBMS_CRYPTO`.
- `ref_*` справочники и FK реализованы.
- `rating_events` реализован.
- `preview_offspring_options` возвращает 3 preview-варианта по умолчанию.
- Runner `01..11` ранее прошел с `Failed: 0`.
- `PKG_GENETICS_GAME`: `PACKAGE VALID`, `PACKAGE BODY VALID`.
- `user_errors`: clean.

## Web Checkpoint
Создан первый минимальный web skeleton:
- Flask/Jinja;
- обычный CSS без CDN/frameworks;
- config из `python_client/.env`;
- Oracle connection layer с `ORACLE_SERVICE` / `ORACLE_SID`;
- `auth_service` и `lab_service` как thin wrappers над package;
- routes `/health`, `/register`, `/login`, `/logout`, `/labs`, `/dashboard`.

Web не считает генетику, задания, рейтинг или кошелек. Единственный прямой SQL — health-check `select 1 from dual`.

## Следующие web-этапы
1. Creatures list и creature detail.
2. Tasks page как “Заказы клиента”.
3. Crossbreed page с preview 3 вариантов.
4. Mutations, experiments, rating events.
5. Polish под слабый учебный стенд.

## Важные ограничения
- Не реализовывать требования на 5 сейчас.
- Не добавлять экосистему, смертность, совет по этике или закрытие лаборатории.
- Не переносить бизнес-логику в Python/web/frontend.
- Не менять DDL/package/seed/tests/PySide6 GUI без отдельной задачи.

## Context checkpoint: web-client-creatures-orders

Ветка `web-client-creatures-orders` добавляет второй практический слой web-клиента без изменения backend:
- сервисы `creature_service` и `task_service` являются тонкими wrappers над package API;
- routes `/creatures`, `/creatures/<id>`, `/tasks` работают поверх текущей лаборатории из Flask session;
- “Заказы клиента” проверяются и завершаются только в Oracle PL/SQL package;
- Flask не считает генетику, рейтинг, кошелёк и не проверяет task markers.

Следующий web-этап должен быть `crossbreed + preview_offspring_options`; mutation/history/rating pages идут после него.

## Context checkpoint: web-client-crossbreed-preview

Ветка `web-client-crossbreed-preview` добавляет route `/crossbreed` и service `crossbreed_service`:
- `preview_offspring_options` вызывается напрямую из package и возвращает 3 preview-варианта;
- preview показывается в браузере как stateless результат `PREVIEW_ONLY`;
- `crossbreed` создаёт реального потомка через package и возвращает `offspring_id`;
- Flask не проверяет совместимость родителей как источник истины и не считает генетику.

Следующий web-трек: mutations/experiments/rating events.

## Context checkpoint: web-client-mutations

Ветка `web-client-mutations` добавляет route `/mutations` и service `mutation_service`:
- магазин мутаций вызывает `show_mutation_shop`;
- покупка вызывает `buy_mutation`;
- directed mutation вызывает `apply_mutation`;
- RADIATION/CHEMICAL вызывают `apply_mutagen` и могут открыть карточку созданного существа.

Flask не считает стоимость, штраф, применимость или генетический эффект. Следующий web-трек: experiments/rating events.

## Context checkpoint: web-client-history

Ветка `web-client-history` добавляет:
- `history_service.get_experiment_history` поверх `pkg_genetics_game.get_experiment_history`;
- `rating_service.get_rating_events` поверх `pkg_genetics_game.get_rating_events_cursor`;
- routes `/experiments` и `/rating-events`;
- templates для эволюционной линии и истории рейтинга.

Flask не строит последствия и не считает deltas; он показывает cursor rows из backend.

## Checkpoint 2026-07-01: web polish for defense

- `web-client-history` was merged into `main` as `c4642f5`.
- `web-client-polish-defense` adds the final defense UI layer without backend changes.
- Web now covers the complete grade 3/4 demo route: labs, dashboard, creatures, genotype/phenotype, client orders, crossbreed, 3-option preview, real offspring, mutations, mutagens, experiments history and rating events.
- Added `/about-requirements` as a compact requirements coverage page.
- Backend remains the source of truth: Flask only calls `pkg_genetics_game` and renders returned data. Direct SQL remains limited to health-check `select 1 from dual`.
- Next step: final clean run, browser smoke on the defense machine, and only small UX fixes if needed.

## Checkpoint 2026-07-10: persistent lab release

- `labs.session_id` is nullable and represents only an active session lock.
- `exit_lab` and `logout_user` persistently release held laboratories.
- `reset_other_user_sessions` safely closes only other active sessions of the same user; the current and foreign-user sessions remain active.
- Existing local schemas use `database/migrations/01_release_lab_session_bindings.sql` with the application stopped.

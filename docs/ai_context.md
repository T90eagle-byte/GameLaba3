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

# Current Tasks

## Current Stage
Backend hardening уровня “хорошо” завершен. Ветка `backend-offspring-preview` влита в `main`, P0-риск по буквальному требованию “показывает 3 случайных варианта потомства” закрыт через `preview_offspring_options`.

Текущая ближайшая задача — не писать web-код, а сохранить архитектурный план легкого Flask/Jinja web-клиента в `docs/web_client_plan.md`.

## Backend Checkpoint
- `backend-rating-events` влит в `main`.
- `backend-offspring-preview` влит в `main` merge-коммитом `81d8293`.
- `rating_events` реализован как backend-журнал объяснения изменений экономики и рейтинга.
- `labs.wallet` и `labs.rating` остаются aggregate state.
- `preview_offspring_options` возвращает 3 preview-варианта потомства по умолчанию.
- Preview stateless: не создает creature/genotype/experiment, не меняет wallet/rating и состояние лаборатории.
- Полный Oracle runner `01..11` прошел с `Failed: 0`.
- `PKG_GENETICS_GAME`: `PACKAGE VALID`, `PACKAGE BODY VALID`.
- `user_errors`: clean.

## Что теперь закрыто для уровня 4
- Задания можно защищаемо показывать как “заказы клиента”: backend хранит описание, rewards, difficulty и `task_markers`.
- Эволюционная линия показывается как путь лаборатории через `experiments`, `get_experiment_history`, мутации, мутагены и завершение заказа.
- Три варианта потомства закрыты буквально: `preview_offspring_options(... default 3)`.
- Риски экспериментов закрыты через RADIATION/CHEMICAL, штрафы wallet/rating и `rating_events`.

## Актуальные документы
- Главный документ по соответствию backend требованиям: `docs/backend_final_requirements_review.md`.
- Аудит уровней оценки: `docs/grade_requirements_audit.md`.
- Технический аудит hardening уровня 4: `docs/level4_backend_hardening_review.md`.
- Материалы защиты: `docs/defense_requirements_cheatsheet.md`, `docs/defense_demo_script.md`.
- План web-клиента: `docs/web_client_plan.md`.
- `docs/backend_compliance_audit.md` является предварительным/историческим аудитом.

## Следующая фаза
1. Использовать `docs/web_client_plan.md` как контракт перед реализацией.
2. Отдельной задачей создать минимальный Flask/Jinja skeleton.
3. Сначала реализовать auth/labs/dashboard.
4. Затем creatures/tasks/crossbreed с backend preview трёх вариантов.
5. После этого добавить mutations/experiments/rating events.

## Не делать сейчас
- Не менять DDL/seed/package/tests/runner без отдельной причины.
- Не добавлять требования на 5: экосистему, смертность, совет по этике, закрытие лаборатории.
- Не начинать Flask/Jinja реализацию в docs-checkpoint.
- Не переносить генетику, экономику, рейтинг или задания в Python/web/frontend.
- Не удалять PySide6 GUI: он остается desktop-версией.

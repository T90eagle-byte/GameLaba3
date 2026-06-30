# Current Tasks

## Current Stage
Web-этап 1–2 начат: создан минимальный Flask/Jinja skeleton поверх `pkg_genetics_game`.

Готово в текущем web skeleton:
- `web_client/` структура;
- config и Oracle connection layer;
- auth/register/login/logout;
- labs page;
- dashboard page;
- `/health`;
- простой CSS без внешних CDN и frontend build.

## Backend Checkpoint
- Backend не менялся на web-этапе.
- `backend-rating-events` и `backend-offspring-preview` влиты в `main`.
- `preview_offspring_options` возвращает 3 preview-варианта потомства по умолчанию.
- Полный Oracle runner `01..11` ранее прошел с `Failed: 0`.
- `PKG_GENETICS_GAME`: `PACKAGE VALID`, `PACKAGE BODY VALID`.
- `user_errors`: clean.

## Web Architecture Rule
- Web-клиент является только client/display-layer.
- Flask не считает генетику, рейтинг, кошелек или задания.
- Игровые операции идут через `pkg_genetics_game`.
- Единственный прямой SQL в web skeleton — технический health-check `select 1 from dual`.

## Актуальные документы
- План web-клиента: `docs/web_client_plan.md`.
- Главный документ по соответствию backend требованиям: `docs/backend_final_requirements_review.md`.
- Аудит уровней оценки: `docs/grade_requirements_audit.md`.
- Материалы защиты: `docs/defense_requirements_cheatsheet.md`, `docs/defense_demo_script.md`.

## Следующие web-этапы
1. Creatures list и creature detail.
2. Tasks page как “Заказы клиента”.
3. Crossbreed page с `preview_offspring_options`.
4. Mutations, experiments, rating events.
5. Polish и стендовый README.

## Не делать сейчас
- Не менять DDL/seed/package/tests/runner без отдельной причины.
- Не добавлять требования на 5: экосистему, смертность, совет по этике, закрытие лаборатории.
- Не переносить генетику, экономику, рейтинг или задания в Python/web/frontend.
- Не удалять PySide6 GUI: он остается desktop-версией.

## Web-этап 3: существа и заказы клиента

Реализован следующий слой Flask/Jinja поверх `pkg_genetics_game`:
- `/creatures` показывает существ текущей лаборатории через `get_creatures_cursor`;
- `/creatures/<id>` показывает карточку существа и генотип через `get_genotype_cursor`;
- `/tasks` показывает задания как “Заказы клиента”;
- проверка и выполнение заказа идут только через `check_task` и `complete_task`;
- dashboard получил быстрые действия и блок защиты.

Следующий web-этап: скрещивание, `preview_offspring_options`, затем реальное `crossbreed`.

## Web-этап 4: скрещивание и preview потомства

Реализован web-интерфейс `/crossbreed`:
- выбор двух родителей из текущей лаборатории;
- preview ровно 3 вариантов потомства через `preview_offspring_options`;
- отображение phenotype/genotype preview, probability и `PREVIEW_ONLY`;
- реальное создание потомка через `crossbreed` отдельной кнопкой;
- preview не меняет состояние лаборатории.

Следующий web-этап: мутации, мутагены RADIATION/CHEMICAL, история экспериментов и `rating_events`.

## Web-этап 5: мутации и мутагены

Реализован web-интерфейс `/mutations`:
- магазин мутаций через `show_mutation_shop`;
- покупка через `buy_mutation`;
- применение directed mutation через `apply_mutation`;
- мутагены `RADIATION` и `CHEMICAL` через `apply_mutagen`;
- риск показывается через обновлённые wallet/rating из backend stats.

Backend не менялся. Flask остаётся display-layer и не рассчитывает эффекты мутаций.

Следующий web-этап: история экспериментов и `rating_events`, затем polish.

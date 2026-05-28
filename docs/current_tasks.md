# Current Tasks

## Статус проекта (обновлено: 2026-05-27)

### 1) Backend strict-pass — завершён
- Backend полностью реализован на Oracle PL/SQL.
- Центральная backend-точка: `pkg_genetics_game`.
- `pkg_genetics_game` (spec/body) компилируются без ошибок.
- `user_errors` пустой.
- Smoke-tests `01..08` прошли с `Failed: 0`.
- Python остаётся только GUI-клиентом.

### 2) Content compliance pass — завершён
Актуальные объёмы seed-данных:
- `genes`: 12
- `alleles`: 24
- `mutations`: 8
- `mutation_rules`: 12
- `tasks`: 12
- `task_markers`: 21

Покрытие:
- `mutation_rules` покрывают универсальные признаки и `species_type 1..6`.
- `task_markers` покрывают `species_type 1..6` и универсальные признаки.

### 3) Economy pass — завершён
- `buy_mutation`:
  - списывает `wallet`;
  - увеличивает `lab_mutations.quantity`;
  - `rating` не меняет.
- `apply_mutation`:
  - применяет `mutation_rules`;
  - уменьшает запас купленной мутации;
  - создаёт `MUTATION` experiment;
  - применяет `mutations.rating_effect` к `labs.rating` через `greatest(0, ...)`;
  - затем запускает `auto_complete_matching_tasks`.
- `apply_mutagen`:
  - создаёт новое изменённое существо;
  - создаёт `MUTAGEN` experiment;
  - запускает `auto_complete_matching_tasks`;
  - `RADIATION`: `cost=50`, `rating_delta=-5`;
  - `CHEMICAL`: `cost=100`, `rating_delta=-2`.
- Рейтинг не уходит ниже 0.
- Рост рейтинга после мутагена допустим за счёт auto-complete задач и `task rewards`.
- Tests `05`/`07` обновлены и проходят.

### 4) Multiuser strict-pass — завершён
- Добавлен `g_current_lab_id`.
- `start_new_lab` фиксирует текущую лабораторию в package context.
- `load_lab`/`switch_lab`:
  - работают с блокировкой lab row через `FOR UPDATE`;
  - проверяют владельца;
  - запрещают открыть одну лабораторию в другой ACTIVE session.
- Новые backend-ошибки:
  - `-20072`: `Lab is already opened in another active session`.
  - `-20073`: `Selected lab is not active in current session`.
- `assert_lab_access`/`assert_creature_access` усилены session-bound проверками.
- `refill_active_tasks` защищён от `dup_val_on_index`.
- Добавлен `database/tests/08_multiuser_sessions_smoke_test.sql`.
- Tests `06`/`07` адаптированы под session-bound модель.
- Полный прогон `01..08` — зелёный.

### 5) GUI статус
Реализованы:
- Auth
- Lab Selection
- Main Shell
- Существа
- Генетический эксперимент
- Мутации
- Задания
- История экспериментов

### 6) Локализация display-layer — выполнена
- Используется `python_client/app/services/display_names.py`.
- В GUI русифицировано отображение:
  - видов существ;
  - генов;
  - аллелей;
  - типов доминирования;
  - статусов заданий;
  - типов экспериментов;
  - типов мутагенов;
  - названий задач;
  - названий мутаций;
  - `phenotype_summary`.
- Это только display-localization, без переноса бизнес-логики в Python.

### 7) Инцидент с кодировкой — закрыт
Было:
- `tasks_tab.py`: mojibake (`Р—...`, `СЂ...` и т.п.).
- `display_names.py`: испорченные значения в `TASK_NAME_LABELS` (`????...`).

Исправлено:
- изменены только:
  - `python_client/app/services/display_names.py`
  - `python_client/app/gui/tasks_tab.py`
- восстановлены корректные UTF-8 строки;
- восстановлен `TASK_NAME_LABELS`;
- `display_task_name()` используется в таблице и карточке вкладки «Задания»;
- технический `task_name` оставлен только в tooltip.

Проверки:
- `python -m compileall -f python_client` — успешно;
- sanity-check:
  - `task_green_specimen -> Зелёный образец`
  - `task_fast_turtle -> Быстрая черепаха`
  - `task_armored_crustacean -> Панцирное ракообразное`

## Важные правила
- UI/подсказки/игровые формулировки — на русском.
- Английский — только для технических имён, API, enum, полей БД.
- Python не считает генетику/мутации/экономику/задания/рейтинг/статистику.
- Python вызывает `pkg_genetics_game` и отображает результат.
- GUI не читает `dbms_output`.
- Все Python-файлы с кириллицей сохранять в UTF-8.

## CloseEvent/logout fix — завершён
- Закрытие GUI через `X` вызывает безопасный logout flow.
- GUI вызывает `logout_user(session_token)`, очищает `SessionState` и закрывает Oracle connection.
- Добавлены понятные русские сообщения для `ORA-20072` и `ORA-20073`.
- Dev-only recovery script для старых зависших sessions: `database/scripts/dev_unlock_stale_sessions.sql`.

## Аудит расширения признаков/контента по ЛР1/ЛР2 и KB — выполнен
Вывод: базовое соответствие ЛР1/ЛР2 достаточное, расширение контента желательно точечно для лучшего учебного впечатления и более явной демонстрации KB.

Текущие объёмы seed:
- `genes`: 12
- `alleles`: 24
- `mutations`: 8
- `mutation_rules`: 12
- `tasks`: 12
- `task_markers`: 21

Что уже закрыто:
- 6 видов существ вместо минимальных 5: хрящевые рыбы, костные рыбы, ракообразные, моллюски, черепахи, млекопитающие.
- Универсальные признаки: `color`, `size`, `nutrition_type`, `has_wings`.
- Видоспецифичные признаки покрывают `species_type 1..6`.
- По каждому гену есть 2 аллеля.
- Реализованы `FULL`, `INCOMPLETE`, `CODOMINANT`.
- `mutation_rules` покрывают универсальные признаки и все `species_type 1..6`.
- `task_markers` покрывают все `species_type 1..6` и универсальные признаки.
- `calculate_punnett_probabilities`, `crossbreed`, `get_phenotype`, `apply_mutation`, `apply_mutagen` остаются в PL/SQL backend.

Рекомендации для будущего content-pass:
- Обязательных seed-изменений для текущего strict baseline нет.
- Желательно усилить демонстрацию `linkage_group`: сейчас осмысленная связанная пара явно есть у черепах (`shell_armor` + `speed_level`), а у рыб linkage-группы содержат по одному гену и почти не демонстрируют связанное наследование.
- Желательно расширять признаки только по подтверждённой KB-таблице/требованиям преподавателя, не добавляя случайные гены.
- Если потребуется показывать в истории точный тип мутагена и изменённый ген, это отдельный backend/DDL-трек, потому что текущая таблица `experiments` не хранит такие детали.
- `creatures.generation` остаётся отдельным DDL-треком, если нужно строго показывать поколение в коллекции.

Потенциальные файлы будущей реализации:
- `database/seeds/01_seed_core_game_data.sql`
- `database/tests/02_seed_data_smoke_test.sql`
- `database/tests/07_strict_compliance_smoke_test.sql`
- `python_client/app/services/display_names.py`
- `docs/current_tasks.md`, `docs/project_roadmap.md`, `docs/gameplay_rules.md`, `docs/ai_context.md`

Код, SQL, backend package, DDL, seed, tests и Python в ходе аудита не менялись.

## Следующий шаг
Если требуется расширение KB-контента, сначала согласовать конкретные признаки из ЛР2/KB, затем делать отдельный seed/test/display pass. Без подтверждения не менять backend/DDL/Python.

## 11) Content/GUI pass по формулировкам заданий (выполнен)
- В database/seeds/01_seed_core_game_data.sql обновлены tasks.description для текущих 12 задач.
- Для tutorial/find-задач формулировки переведены в нейтральный стиль: Найдите / Отберите / предъявите вместо двусмысленного Получите там, где это не требует происхождения существа.
- Backend-логика не менялась: check_task проверяет признаки выбранного существа по task_markers, а не историю происхождения.
- Проверена согласованность marker-логики: конфликтов взаимно исключающих аллелей в рамках одного (task, gene) нет.

## 12) Примечание по типам задач
- В текущей модели БД нет отдельного типа задачи (FIND / BREED / MUTATE).
- Если в будущем потребуется строгое различение таких типов, это отдельный DDL/backend-трек.



## 13) Финальный user-friendly polish — Этап 1 (onboarding и empty states)
Выполнено безопасно, без изменения backend/DDL/package/seed/tests:
- Auth: добавлен блок «Как начать», уточнены placeholder-подсказки по логину/паролю.
- Lab Selection: добавлено пояснение роли лаборатории и empty-state при пустом списке лабораторий.
- Main Shell: добавлена компактная панель «Что делать дальше?».
- Существа: добавлен empty-state при пустой коллекции.
- Генетический эксперимент: добавлены сценарные подсказки, если недостаточно существ/нет общих генов.
- Мутации: уточнена подсказка, когда для выбранной мутации нет совместимых существ.
- Задания: empty-state для отсутствия активных задач оставлен в понятной игровой формулировке.
- История экспериментов: empty-state при отсутствии записей.

Проверка: python -m compileall -f python_client — успешно.

## 15) Mutation-rules coherence pass
- Устранён контентный источник ORA-20045: смешанные мутации разделены на видоспецифичные.
- Актуальные объёмы seed: genes=12, alleles=24, mutations=12, mutation_rules=12, tasks=12, task_markers=21.
- Backend package/DDL/spec не менялись; правка сделана через seed + smoke-tests + display mapping.


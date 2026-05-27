# AI Context: БиоСборка

## Базовая архитектура
- Backend полностью реализован в Oracle PL/SQL.
- Центральный backend API: `pkg_genetics_game`.
- Python — только GUI-клиент (подключение к Oracle, вызов package API, отображение данных).
- Python не переносит и не дублирует backend-бизнес-логику.
- GUI не использует `dbms_output`.

## Текущий подтверждённый статус (2026-05-27)

### Backend strict-pass
- `pkg_genetics_game` spec/body компилируются.
- `user_errors` пустой.
- Smoke-tests `01..08` прошли зелёным (`Failed: 0`).

### Content compliance pass
Итоговые объёмы seed:
- genes: 12
- alleles: 24
- mutations: 8
- mutation_rules: 12
- tasks: 12
- task_markers: 21

Покрытие:
- универсальные признаки;
- `species_type 1..6` по mutation_rules и task_markers.

### Economy pass
- `buy_mutation`: списывает wallet, увеличивает stock, rating не меняет.
- `apply_mutation`: применяет mutation_rules, уменьшает stock, создаёт MUTATION experiment, применяет `rating_effect` через `greatest(0, ...)`, затем auto-complete tasks.
- `apply_mutagen`: создаёт мутанта + MUTAGEN experiment + auto-complete tasks.
  - RADIATION: cost 50, rating_delta -5.
  - CHEMICAL: cost 100, rating_delta -2.
- Рейтинг не уходит ниже 0.
- Рост рейтинга после мутагена возможен за счёт task rewards.

### Multiuser strict-pass
- Session-bound модель доступа к лаборатории.
- Добавлен `g_current_lab_id`.
- `load_lab/switch_lab` используют `FOR UPDATE`, проверяют owner и занятость lab.
- Ошибки:
  - `-20072` lab already opened in another active session;
  - `-20073` selected lab is not active in current session.
- `assert_lab_access`/`assert_creature_access` проверяют owner + активную lab в текущей session.
- Добавлен `08_multiuser_sessions_smoke_test.sql`.

### GUI реализован
- Auth
- Lab Selection
- Main Shell
- Существа
- Генетический эксперимент
- Мутации
- Задания
- История экспериментов

### Display localization
- Используется `python_client/app/services/display_names.py`.
- Русифицировано отображение видов, генов, аллелей, dominance/status/experiment/mutagen типов, названий задач/мутаций, phenotype summary.
- Это display-layer, не бизнес-логика.

### Закрытый инцидент
- Была сломана кодировка во вкладке «Задания» (mojibake/`????`).
- Исправлено без backend-изменений:
  - `python_client/app/services/display_names.py`
  - `python_client/app/gui/tasks_tab.py`
- Проверки:
  - `python -m compileall -f python_client` успешно;
  - `display_task_name` возвращает корректные русские значения.

## Важные правила для следующих сессий
- UI/подсказки/игровые формулировки — на русском.
- Английский оставлять только для технических имён/API/enum/полей БД.
- Python не считает генетику, мутации, экономику, задания, рейтинг, статистику.
- Все такие расчёты выполняет только PL/SQL backend.
- Python-файлы с кириллицей хранить в UTF-8.

## Pending next (не закрыто)
Нужно добавить корректный logout flow при закрытии GUI через `X`:
- вызвать `logout_user(session_token)`;
- очистить `SessionState`;
- закрыть Oracle connection;
- не делать повторный logout после нажатия «Выход».

Также в `oracle_errors.py` нужно держать понятные русские сообщения для:
- `ORA-20072` (лаборатория уже открыта в другой активной сессии);
- `ORA-20073` (лаборатория не активна в текущей сессии).

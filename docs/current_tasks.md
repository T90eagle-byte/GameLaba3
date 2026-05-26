# Current Tasks

## 1) Текущий статус проекта

- PL/SQL backend strict-pass завершен.
- `pkg_genetics_game` (spec/body) компилируется на Oracle.
- `USER_ERRORS` для `PKG_GENETICS_GAME` пустой.
- Smoke-tests `01..07` проходят с `Failed: 0`.
- Backend полностью остается в Oracle PL/SQL.

## 2) Последний завершенный этап

Реализован первый Python GUI vertical slice: **Auth + Lab Selection + Main Window Shell**.

Создано:
- `python_client/main.py`
- `python_client/requirements.txt`
- `python_client/.env.example`
- `python_client/app/__init__.py`
- `python_client/app/config.py`
- `python_client/app/db/__init__.py`
- `python_client/app/db/connection.py`
- `python_client/app/db/pkg_api.py`
- `python_client/app/services/__init__.py`
- `python_client/app/services/session_state.py`
- `python_client/app/services/oracle_errors.py`
- `python_client/app/gui/__init__.py`
- `python_client/app/gui/app.py`
- `python_client/app/gui/styles.py`
- `python_client/app/gui/auth_window.py`
- `python_client/app/gui/lab_window.py`
- `python_client/app/gui/main_window.py`

Реализовано в GUI:
- PySide6-клиент;
- Oracle thin connection через `python-oracledb`;
- один стабильный Oracle connection на GUI-сессию (без pool);
- auth flow: `register_user` / `login_user` / `logout_user`;
- lab flow: `list_user_labs` / `start_new_lab` / `load_lab` / `switch_lab`;
- main shell со статистикой лаборатории и вкладками-заглушками;
- `python -m compileall python_client` проходит успешно.

## 3) Ближайший следующий этап

Ручная проверка GUI на реальной Oracle БД:
1. Создать `venv`.
2. Установить `python_client/requirements.txt`.
3. Создать `python_client/.env` из `.env.example`.
4. Запустить `python_client/main.py`.
5. Проверить сценарии:
   - register
   - login
   - create lab
   - list labs
   - open lab
   - main shell
   - logout

## 4) Следующий coding-этап после ручной проверки

Вкладка **Creatures**:
- интеграция `get_creatures_cursor`;
- интеграция `get_genotype_cursor`;
- отображение `phenotype_summary`;
- показ генотипа выбранного существа.

## 5) Архитектурные ограничения (не менять)

- Python не переносит backend-логику из PL/SQL.
- Python не использует `dbms_output`.
- Все игровые операции идут через `pkg_genetics_game`.
- Один connection должен жить от `login_user` до `logout_user` (package session context).

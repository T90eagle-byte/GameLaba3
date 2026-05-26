# AI Context: БиоСборка

## 1) Проект

БиоСборка — игра-симулятор генетического конструктора.

Архитектура:
- backend полностью на Oracle PL/SQL;
- центральный backend-пакет: `pkg_genetics_game`;
- Python — только GUI-клиент (подключение к Oracle, вызовы API, отображение данных).

## 2) Текущий статус

- Backend strict-pass завершен.
- `pkg_genetics_game` (spec/body) компилируется на Oracle.
- `USER_ERRORS` для `PKG_GENETICS_GAME` пустой.
- Smoke-tests `01..07` проходят с `Failed: 0`.

## 3) Новый завершенный этап

Реализован первый Python GUI vertical slice:
- Auth;
- Lab Selection;
- Main Window Shell.

Технологии GUI:
- Python 3.12;
- PySide6;
- `python-oracledb` thin.

Создан единый стабильный Oracle connection на GUI-сессию (без pool), чтобы корректно работал package session context.

## 4) Ключевые ограничения

- Python не переносит бизнес-логику из PL/SQL.
- Python не считает генетику, скрещивание, мутации, экономику, задания и статистику.
- Python не использует `dbms_output`.
- Все игровые операции идут через API `pkg_genetics_game`.

## 5) Следующий шаг

Ручной прогон GUI на реальной Oracle БД:
1. создать `venv`;
2. установить `python_client/requirements.txt`;
3. создать `python_client/.env` из `.env.example`;
4. запустить `python_client/main.py`;
5. проверить сценарии register/login/create lab/open lab/main shell/logout.

После успешной ручной проверки — этап реализации вкладки Creatures (`get_creatures_cursor`, `get_genotype_cursor`, phenotype/genotype view).

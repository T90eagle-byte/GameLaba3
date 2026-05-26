# Project Roadmap

## 1) Backend strict-pass

Статус: **завершен и подтвержден на реальном Oracle**.

- `pkg_genetics_game` package spec/body компилируются успешно.
- `USER_ERRORS` для `PKG_GENETICS_GAME` пустой.
- Smoke-tests `01..07` проходят с `Failed: 0`.
- Backend полностью остается в Oracle PL/SQL и соответствует strict-pass целям.

## 2) Python GUI Stage — Vertical Slice #1

Статус: **реализован**.

Собран первый desktop-срез на PySide6 + python-oracledb thin:
- Auth window;
- Lab Selection window;
- Main Window Shell со статистикой лаборатории и вкладками-заглушками.

Принципы сохранены:
- Python только GUI-клиент;
- бизнес-логика не переносится из PL/SQL;
- один стабильный Oracle connection на сессию GUI.

## 3) Ближайший этап — ручная проверка GUI

Порядок:
1. Создать `venv`.
2. Установить зависимости из `python_client/requirements.txt`.
3. Создать `python_client/.env` из `.env.example`.
4. Запустить `python_client/main.py`.
5. Проверить сценарии: register, login, create lab, list labs, open lab, main shell, logout.

## 4) Следующий coding-этап

После успешной ручной проверки перейти к вкладке **Creatures**:
- вызов `get_creatures_cursor`;
- вызов `get_genotype_cursor`;
- показ `phenotype_summary`;
- показ генотипа выбранного существа.

## 5) Дальнейшие GUI-этапы

- Crossbreed screen
- Mutations screen
- Tasks screen
- Experiment history screen

## 6) Отдельный DDL-трек (по решению)

Поле `generation` в `creatures` остается отдельным DDL-этапом и не входит в текущий GUI-срез.

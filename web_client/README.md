# Web-клиент “БиоСборки”

Минимальный Flask/Jinja клиент поверх Oracle PL/SQL package `pkg_genetics_game`.

## Назначение

Web-клиент нужен как переносимый интерфейс для учебного стенда. PySide6 GUI остается desktop-версией, но web проще запустить на старой Windows-машине через браузер.

## Архитектурное правило

Бизнес-логика остается в Oracle PL/SQL:

- генетика считается в `pkg_genetics_game`;
- задания проверяются в `pkg_genetics_game`;
- рейтинг и кошелек меняются в `pkg_genetics_game`;
- Flask только вызывает package API и отображает результат.

Прямой SQL разрешен только для технического health-check `select 1 from dual`.

## Зависимости

```powershell
.\.venv\Scripts\python.exe -m pip install -r web_client\requirements.txt
```

## Перед запуском

- Oracle должен быть доступен.
- `python_client/.env` должен содержать `ORACLE_HOST`, `ORACLE_PORT`, `ORACLE_USER`, `ORACLE_PASSWORD` и один из параметров `ORACLE_SERVICE` / `ORACLE_SID`.
- Желательно проверить backend:

```powershell
.\.venv\Scripts\python.exe database\scripts\run_tests.py --dry-run
```

## Запуск

```powershell
.\.venv\Scripts\python.exe web_client\app.py
```

Адрес:

```text
http://127.0.0.1:8000
```

## Реализовано в первом web-этапе

- `/health`;
- регистрация;
- вход;
- выход;
- список лабораторий;
- создание лаборатории через package API;
- открытие лаборатории;
- dashboard со статистикой лаборатории.

Следующие этапы: существа, заказы клиента, скрещивание с preview 3 вариантов, мутации, история экспериментов и `rating_events`.

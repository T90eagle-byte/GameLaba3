# Web-клиент “БиоСборка”

Минимальный Flask/Jinja клиент поверх Oracle PL/SQL package `pkg_genetics_game`.

## Назначение

Web-клиент нужен как переносимый интерфейс для учебного стенда. PySide6 GUI остаётся desktop-версией, но web проще запустить на старой Windows-машине через браузер.

## Архитектурное правило

Бизнес-логика остаётся в Oracle PL/SQL:

- генетика считается в `pkg_genetics_game`;
- заказы клиента проверяются в `pkg_genetics_game`;
- рейтинг и кошелёк меняются в `pkg_genetics_game`;
- Flask только вызывает package API и отображает результат.

Прямой SQL разрешён только для технического health-check `select 1 from dual`.

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

## Реализовано

- `/health`;
- регистрация;
- вход;
- выход;
- список лабораторий;
- создание лаборатории через package API;
- открытие лаборатории;
- dashboard со статистикой лаборатории;
- `/creatures` — список существ лаборатории;
- `/creatures/<id>` — карточка существа, фенотип и генотип;
- `/tasks` — заказы клиента, проверка и выполнение заказа через backend package.

## Smoke checklist

1. Открыть `/health`.
2. Зарегистрировать пользователя.
3. Войти.
4. Создать лабораторию.
5. Открыть dashboard.
6. Открыть список существ.
7. Открыть карточку существа.
8. Открыть “Заказы клиента”.
9. Проверить заказ на выбранном существе.
10. Выполнить подходящий заказ.
11. Выйти.

## Ещё не реализовано в web

- скрещивание и preview 3 вариантов потомства;
- мутации и мутагены;
- история экспериментов;
- история рейтинга `rating_events`;
- страница требований для защиты.
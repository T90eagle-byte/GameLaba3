# Windows deployment БиоСборки

Этот каталог содержит canonical runtime path для Windows: Flask запускается
через Waitress и подключается к внешней Oracle в Thin mode. Docker, SQL
Developer и DBeaver для установки не нужны.

## Быстрый запуск

1. Скопируйте `.env.example` в `.env` и заполните параметры назначенной Oracle schema.
2. Выполните `powershell -ExecutionPolicy Bypass -File deployment\windows\setup.ps1`.
3. Для пустой schema выполните `install_fresh.ps1`; для существующей BioSborka — `update_game.ps1`.
4. Выполните `start_game.ps1`.
5. Откройте адрес, заданный `FLASK_HOST` и `FLASK_PORT` в `.env`.

Пример для университетского стенда: `FLASK_HOST=127.0.0.1`, `FLASK_PORT=14550`, адрес `http://127.0.0.1:14550/`.

Все команды используют `.venv\Scripts\python.exe` напрямую и не требуют
`Activate.ps1`. Полная ПИМ находится в корневом `README_RELEASE.md`.

## Файлы

| Файл | Назначение |
| --- | --- |
| `.env.example` | Шаблон параметров Oracle без паролей. |
| `requirements-windows.txt` | Единственный runtime requirements path: Flask, Waitress, python-oracledb, python-dotenv. |
| `setup.ps1` | Создаёт `.venv` и устанавливает runtime dependencies. |
| `install_fresh.ps1` | Безопасно устанавливает игру в пустую выделенную schema. |
| `update_game.ps1` | Идемпотентно обновляет существующую BioSborka до schema version 15. |
| `validate_game.ps1` | Выполняет read-only readiness check. |
| `start_game.ps1` | Запускает Waitress только на `127.0.0.1` по умолчанию. |

Заполните ровно один способ подключения:

```text
ORACLE_SID=ORCL
ORACLE_SERVICE=
```

или:

```text
ORACLE_SID=
ORACLE_SERVICE=service_name
```

Если оба значения заполнены или оба пусты, запуск и schema CLI остановятся с
понятной диагностикой. `.env` содержит секреты и исключён из Git и release.

`python_client` остаётся в репозитории как исторический PySide клиент, но не
входит в web runtime release: Flask и Oracle installers от него не зависят.

# БиоСборка: запуск на Windows

Этот комплект запускает web-версию игры через Waitress и внешнюю Oracle. Docker,
SQL Developer и DBeaver для работы не требуются.

## Что нужно

- Windows с Python 3.12 x64;
- доступ к назначенной Oracle schema: host, port, SID **или** service, user и password;
- права этого пользователя на установку объектов в выделенной schema.

## Первая установка

1. Распакуйте архив в короткий путь без кириллицы в имени папки.
2. Скопируйте `deployment\windows\.env.example` в `deployment\windows\.env` и заполните только `ORACLE_*` и `FLASK_SECRET_KEY`.
3. Выполните `powershell -ExecutionPolicy Bypass -File deployment\windows\setup.ps1`.
4. Выполните `powershell -ExecutionPolicy Bypass -File deployment\windows\install_fresh.ps1`.
5. Выполните `powershell -ExecutionPolicy Bypass -File deployment\windows\start_game.ps1` и откройте `http://127.0.0.1:8000`.

`install_fresh.ps1` работает только с пустой выделенной schema. Он не удаляет
объекты: при найденной BioSborka или посторонних объектах установка остановится.

## Обновление существующей BioSborka

Остановите web-приложение и выполните:

```powershell
powershell -ExecutionPolicy Bypass -File deployment\windows\update_game.ps1
```

Update применяет только canonical идемпотентные SQL-файлы, проверяет readiness и
сохраняет пользователей, лаборатории, существ, генотипы и историю. Повторный
update version 15 безопасен.

## Проверка

```powershell
powershell -ExecutionPolicy Bypass -File deployment\windows\validate_game.ps1
```

Ожидается `Readiness ............... PASS`. Ошибка SID/SERVICE означает, что
нужно заполнить ровно один из `ORACLE_SID` и `ORACLE_SERVICE`. При занятом порте
измените `FLASK_PORT` в `.env`; при ошибке package выполните `update_game.ps1`.

## Типичные ошибки

- Нет `.env`: скопируйте `.env.example` и заполните параметры, не добавляя файл в Git.
- Oracle недоступна: проверьте host, port, сеть и учётные данные у администратора.
- Неверный SID/service: оставьте заполненным ровно один параметр подключения.
- Схема не пуста: `install_fresh.ps1` намеренно остановится; для существующей игры используйте `update_game.ps1`.
- Package invalid: остановите web-приложение, выполните `update_game.ps1`, затем `validate_game.ps1`.
- Порт занят: задайте свободный `FLASK_PORT` в `.env` и повторите `start_game.ps1`.

Файл `.env` содержит секреты и не должен попадать в архив или Git.

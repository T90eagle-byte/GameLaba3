# План лёгкого web-клиента для “БиоСборки”

## 1. Цель web-клиента

Web-клиент нужен как переносимый интерфейс для учебного стенда, где PySide6/Qt6 может не запускаться на Windows Server 2012 R2. Он должен открываться через браузер, запускаться на слабой машине и не требовать тяжелой frontend-сборки.

Ключевое правило: бизнес-логика остается в Oracle PL/SQL package `pkg_genetics_game`. Flask/Jinja только вызывает package API и отображает данные.

## 2. Технологический выбор

Рекомендуемый стек:
- Flask;
- Jinja templates;
- обычный CSS;
- без React/Vue;
- без Node.js и frontend build;
- минимум зависимостей: `Flask`, `oracledb`, `python-dotenv`, возможно `waitress` для Windows-запуска.

Почему так:
- проще запустить на Windows Server 2012 R2;
- меньше внешних точек отказа;
- не нужен Node.js;
- templates достаточно для учебной демонстрации;
- backend уже содержит всю игровую логику.

## 3. Архитектура папок

```text
web_client/
  app.py
  config.py
  requirements.txt
  services/
    oracle.py
    auth_service.py
    lab_service.py
    creature_service.py
    task_service.py
    mutation_service.py
    experiment_service.py
    rating_service.py
  templates/
    base.html
    login.html
    register.html
    labs.html
    dashboard.html
    creatures.html
    creature_detail.html
    crossbreed.html
    tasks.html
    mutations.html
    experiments.html
    rating_events.html
    about_requirements.html
  static/
    css/
      app.css
```

Структуру можно слегка адаптировать при реализации, но она должна оставаться простой: один Flask app, server-side routes, сервисы-обертки над package API.

## 4. Правило client/display-layer

Web не должен:
- считать генетику;
- считать рейтинг;
- считать кошелек;
- проверять задания;
- генерировать потомков;
- выбирать мутации;
- определять access control вместо backend.

Web должен:
- читать `.env`;
- открывать Oracle connection;
- вызывать `pkg_genetics_game`;
- показывать returned rows/errors пользователю.

Разрешенный direct SQL:
- health check `select 1 from dual`;
- техническая диагностика подключения.

Все игровые данные должны идти через package cursors/procedures/functions.

## 5. Session Model

- После `login_user` Flask хранит `session_token` в server-side session cookie.
- Текущая лаборатория хранится как `current_lab_id`.
- Logout вызывает `pkg_genetics_game.logout_user` и очищает Flask session.
- Route guards проверяют наличие `session_token`.
- Чужая лаборатория блокируется backend package, а не только Flask-логикой.
- Ошибка устаревшей/невалидной session ведет на `/login` с понятным сообщением.

## 6. Карта страниц и маршрутов

| Страница | Route | Backend API | Что показывает | Требование |
| --- | --- | --- | --- | --- |
| Главная | `/` | - | Redirect на `/dashboard` или `/login` | UX |
| Регистрация | `/register` | `register_user` | Форма создания пользователя | Auth |
| Вход | `/login` | `login_user` | Форма входа | Auth |
| Выход | `/logout` | `logout_user` | Завершение session | Auth |
| Лаборатории | `/labs` | `list_user_labs`, `start_new_lab`, `load_lab`, `switch_lab`, `delete_lab` | Список лабораторий, создание, открытие, удаление | Labs |
| Dashboard | `/dashboard` | `get_lab_stats`, `get_tasks_cursor`, `get_rating_events_cursor` | Статистика, активные заказы, последние события | Demo |
| Существа | `/creatures` | `get_creatures_cursor` | Коллекция существ | Уровень 3 |
| Карточка существа | `/creatures/<creature_id>` | `get_genotype_cursor`, phenotype fields | Генотип, фенотип, признаки | Уровень 3/4 |
| Скрещивание | `/crossbreed` | `preview_offspring_options`, `calculate_punnett_probabilities`, `crossbreed` | Выбор родителей, 3 preview-варианта, создание потомка | Уровень 3 |
| Заказы клиента | `/tasks` | `get_tasks_cursor`, `check_task`, `complete_task` | Задания как клиентские заказы | Уровень 3/4 |
| Мутации | `/mutations` | `show_mutation_shop`, `buy_mutation`, `apply_mutation`, `apply_mutagen` | Магазин, покупка, применение, мутагены | Уровень 4 |
| История экспериментов | `/experiments` | `get_experiment_history`, `show_mutation_history` | Эволюционная линия лаборатории | Уровень 4 |
| История рейтинга | `/rating-events` | `get_rating_events_cursor` | Пояснение изменений wallet/rating | Уровень 4+ |
| Требования | `/about-requirements` | - | Статическая страница защиты: 3/4/не 5 | Defense |

## 7. Главный демонстрационный flow

1. Регистрация.
2. Вход.
3. Создание лаборатории.
4. Dashboard со stats.
5. Существа: список стартовой популяции.
6. Карточка существа: genotype/phenotype.
7. Заказы клиента: показать требуемые признаки и награды.
8. Crossbreed:
   - выбрать родителей;
   - показать 3 preview-варианта через `preview_offspring_options`;
   - создать реального потомка через `crossbreed`.
9. Мутации:
   - купить directed mutation;
   - применить mutation.
10. Мутагены:
   - применить RADIATION;
   - применить CHEMICAL;
   - показать риск через wallet/rating.
11. Rating events: показать покупки, штрафы и награды.
12. Experiments: показать эволюционную линию лаборатории.

## 8. UI-принципы

- Чистый, простой дизайн.
- Карточки для существ и заказов.
- Таблицы для истории, мутаций и событий рейтинга.
- Badges для видов, признаков, сложности и статусов.
- Минимум JS; все основные действия через обычные POST forms.
- Без тяжелых анимаций.
- Работает на маленьком экране.
- Русские пользовательские тексты.
- Ошибки package показываются понятным языком.

## 9. Ошибки и UX

- Raw traceback пользователю не показывать.
- `ORA-20023` / access denied: “Нет доступа к лаборатории”.
- Недостаточно денег: “Недостаточно средств в лаборатории”.
- Несовместимые родители: “Эти существа несовместимы для скрещивания”.
- Неверная или истекшая session: redirect на `/login`.
- Ошибки Oracle логировать на серверной стороне, пользователю давать короткое сообщение.

## 10. Минимальные этапы реализации

### Web-этап 1: Skeleton
- `web_client/app.py`;
- config;
- DB connection helper;
- base template;
- login/register/logout.

### Web-этап 2: Labs / Dashboard
- labs list;
- start/load/switch/delete lab;
- dashboard stats.

### Web-этап 3: Creatures / Tasks
- creatures list;
- creature detail genotype/phenotype;
- tasks как “Заказы клиента”.

### Web-этап 4: Crossbreed
- parent selection;
- preview 3 offspring options;
- probabilities block;
- real crossbreed action.

### Web-этап 5: Mutations / Experiments / Rating
- mutation shop;
- apply mutation;
- apply mutagen;
- experiment history;
- rating events.

### Web-этап 6: Polish
- CSS;
- `/about-requirements` для защиты;
- README;
- запуск на стенде.

## 11. Acceptance Criteria

Web считается готовым для минимальной защиты, если:
- запускается одной командой;
- login/register работают;
- lab create/load работает;
- dashboard показывает stats;
- creatures видны;
- genotype/phenotype видны;
- tasks отображаются как “Заказы клиента”;
- preview показывает 3 варианта потомства;
- crossbreed создает потомка;
- mutation/mutagen работают;
- rating_events показывают последствия;
- нет бизнес-логики в web;
- запуск без Node.js.

## 12. Команды запуска

Черновик будущих команд:

```powershell
.\.venv\Scripts\python.exe database\scripts\run_tests.py
.\.venv\Scripts\python.exe web_client\app.py
```

Адрес:

```text
http://127.0.0.1:8000
```

Если для Windows-запуска будет добавлен `waitress`, production-like команда может быть отдельной, но это не требуется для первого skeleton.

## 13. Что НЕ делать в web

- Не React.
- Не Vue.
- Не Node build.
- Не Electron.
- Не переносить PL/SQL logic.
- Не добавлять требования уровня 5.
- Не делать realtime ecosystem.
- Не подключать браузер напрямую к Oracle.
## 14. Реализация Web-этапа 1–2

Создан минимальный skeleton `web_client/`:
- config и Oracle connection layer;
- thin wrappers `auth_service` и `lab_service`;
- routes `/health`, `/register`, `/login`, `/logout`, `/labs`, `/dashboard`;
- Jinja templates и простой CSS без внешних CDN;
- README с запуском.

Следующие этапы остаются без изменений: creatures/tasks, crossbreed preview, mutations, experiments/rating events и polish.

## 15. Реализация Web-этапа 3: Creatures / Client Orders

Сделан слой “creatures/tasks”:
- `web_client/services/creature_service.py` вызывает `load_lab`, `get_creatures_cursor`, `get_genotype_cursor`;
- `web_client/services/task_service.py` вызывает `load_lab`, `get_tasks_cursor`, `check_task`, `complete_task`;
- `/creatures` показывает список существ текущей лаборатории;
- `/creatures/<id>` показывает фенотип и таблицу генотипа;
- `/tasks` оформляет задания как “Заказы клиента” и отправляет проверку/выполнение в package API;
- dashboard получил быстрые переходы и защитный блок.

Осталось по плану: crossbreed UI с preview 3 вариантов, затем mutations/experiments/rating events.

## 16. Реализация Web-этапа 4: Crossbreed Preview

Сделан слой скрещивания:
- `web_client/services/crossbreed_service.py` вызывает `preview_offspring_options` и `crossbreed`;
- `/crossbreed` показывает форму выбора родителей и имени потомка;
- preview выводит 3 карточки с phenotype/genotype summary, probability и source note;
- реальное создание потомка выполняется отдельной POST-кнопкой через backend package;
- после создания web переходит на карточку потомка.

Этот этап закрывает браузерную демонстрацию требования “показывает 3 случайных варианта потомства”.

## 17. Реализация Web-этапа 5: Mutations / Mutagens

Сделан слой мутаций:
- `web_client/services/mutation_service.py` вызывает `show_mutation_shop`, `buy_mutation`, `apply_mutation`, `apply_mutagen`;
- `/mutations` показывает wallet/rating, магазин, форму применения купленной мутации и блок мутагенов;
- RADIATION/CHEMICAL отображаются как рискованные backend-операции;
- после действий пользователь видит обновлённые stats или карточку изменённого/нового существа.

Осталось: experiments history и `rating_events` page.

## 18. Реализация Web-этапа 6: Experiments / Rating Events

Сделан слой истории:
- `/experiments` показывает историю экспериментов как эволюционную линию лаборатории;
- `/rating-events` показывает журнал причин изменения wallet/rating;
- dashboard и navigation получили ссылки на эти страницы.

Осталось: polish, `/about-requirements`, финальный smoke script/checklist.

## Implementation status on 2026-07-01

Implemented stages: skeleton, labs/dashboard, creatures/tasks, crossbreed preview, mutations/mutagens, experiments/rating events and polish for defense.

Actual pages:

- `/health`;
- `/register`, `/login`, `/logout`;
- `/labs`, `/dashboard`;
- `/creatures`, `/creatures/<id>`;
- `/tasks` as client orders;
- `/crossbreed` with 3-option preview and real offspring creation;
- `/mutations` with mutation shop, mutation application and mutagens;
- `/experiments` as evolution line;
- `/rating-events` as wallet/rating consequences;
- `/about-requirements` as requirements coverage for defense.

Architecture rule is preserved: web does not calculate genetics, tasks, rating, wallet or consequences. Gameplay actions go through `pkg_genetics_game`; direct SQL remains health-check only.

Remaining work before defense: clean launch on the stand, manual smoke checklist, small visual fixes only if needed.

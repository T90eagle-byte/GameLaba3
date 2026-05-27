# Project Roadmap

## Текущий этап (2026-05-27)

### Завершённые backend-pass этапы
1. **Backend strict-pass**
- PL/SQL backend завершён.
- Центральный API: `pkg_genetics_game`.
- spec/body компилируются, `user_errors` пустой.
- smoke-tests `01..08` прошли (`Failed: 0`).

2. **Content compliance pass (ЛР2/KB)**
- Расширен seed-контент по признакам, мутациям и заданиям.
- Текущие объёмы: `genes=12`, `alleles=24`, `mutations=8`, `mutation_rules=12`, `tasks=12`, `task_markers=21`.
- Покрытие: универсальные признаки + `species_type 1..6`.

3. **Economy pass**
- `apply_mutation` применяет `mutations.rating_effect` к рейтингу лаборатории.
- `apply_mutagen` получил экономику:
  - `RADIATION`: `cost=50`, `rating_delta=-5`.
  - `CHEMICAL`: `cost=100`, `rating_delta=-2`.
- Рейтинг ограничен снизу через `greatest(0, ...)`.
- Auto-complete задач может компенсировать штрафы.

4. **Multiuser strict-pass**
- Session-bound доступ к лаборатории усилен.
- Одна лаборатория не может быть открыта в двух ACTIVE sessions одновременно.
- Ошибки:
  - `-20072` lab already opened in another active session;
  - `-20073` selected lab is not active in current session.
- Добавлен `08_multiuser_sessions_smoke_test.sql`.

### GUI готовность
Реализованы экраны:
- Auth
- Lab Selection
- Main Shell
- Существа
- Генетический эксперимент
- Мутации
- Задания
- История экспериментов

### Локализация и display-layer
- Используется единый mapping в `python_client/app/services/display_names.py`.
- Пользовательское отображение русифицировано.
- Бизнес-логика остаётся в PL/SQL.

### Закрытый инцидент
- Исправлена сломанная кодировка во вкладке «Задания» (`tasks_tab.py`, `display_names.py`).
- Восстановлены корректные UTF-8 строки и mapping task names.

## Ближайший обязательный шаг
**GUI closeEvent/logout fix после multiuser pass**:
- при закрытии через `X` вызывать `logout_user(session_token)`;
- очищать `SessionState`;
- закрывать Oracle connection;
- не выполнять повторный logout после «Выход»;
- добавить/уточнить русские сообщения для `ORA-20072` и `ORA-20073`.

## Следующие этапы
1. Проверка сценариев после closeEvent fix:
- открыть лабораторию;
- закрыть GUI через `X`;
- повторно войти и открыть ту же лабораторию;
- проверить блокировку второй активной сессии.

2. Дополнительное развитие UX (после стабилизации):
- улучшение dashboard;
- больше карточного/визуального представления;
- сценарий «быстрого старта» для преподавателя.

3. Возможные отдельные backend/DDL-треки (по решению):
- `experiments.created_at` для полной даты/времени в истории;
- `creatures.generation` при необходимости строгого соответствия расширенным требованиям ЛР.

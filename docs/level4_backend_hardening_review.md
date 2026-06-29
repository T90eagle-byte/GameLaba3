# Технический аудит backend hardening для уровня “хорошо”

Дата актуализации: 2026-06-29
Актуальная ветка: `main`
Итог hardening: P0 закрыт, `backend-offspring-preview` влит merge-коммитом `81d8293`.

## 1. Краткий вывод

Требования уровня 4 теперь закрыты защищаемо. До hardening главным P0-риском было буквальное требование “показывает 3 случайных варианта потомства”: раньше backend возвращал вероятности и создавал реального потомка, но отдельного stateless preview API не было.

После hardening добавлен `preview_offspring_options`, который:
- по умолчанию возвращает ровно 3 preview-варианта;
- не создает creature/genotype/experiment;
- не меняет wallet/rating и lab state;
- проверяет session/lab/parents через backend;
- покрыт smoke-test `11_offspring_preview_smoke_test.sql`.

Полный Oracle runner `01..11` после merge прошел с `Failed: 0`; package `VALID`, `user_errors` clean.

## 2. Заказы клиента

| Проверка | Итог | Комментарий |
| --- | --- | --- |
| Есть ли описание задания | Да | `tasks.description` хранит пользовательский смысл задания. |
| Есть ли reward | Да | `money_reward`, `rating_reward`, `difficulty_code`. |
| Есть ли task markers | Да | `task_markers` задают проверяемые признаки. |
| Можно ли трактовать task как “заказ клиента” | Да | Это корректный display/demo label без DDL. |
| Нужно ли менять seed-тексты | Не обязательно | Можно оставить backend стабильным и назвать блок “Заказы клиента” в web/docs. |
| Нужно ли поле `client_order_title` | Нет | DDL не нужен; это был бы лишний риск перед web. |

Рекомендация: в web-клиенте и на защите показывать `tasks` как “Заказы клиента”. Backend уже хранит смысл заказа, сложность, награды и проверяемые markers.

## 3. Эволюционная линия

В проекте уже есть достаточная backend-база:
- `experiments` хранит CROSS/MUTATION/MUTAGEN operations;
- `get_experiment_history` возвращает историю экспериментов;
- `show_mutation_history` есть как LR2-compatible wrapper;
- `rating_events` объясняет экономические последствия.

Новая backend API для “линии” сейчас не нужна. Для web/demo достаточно показать timeline: стартовые существа → скрещивания/мутации/мутагены → финальный организм → выполнение заказа клиента.

Это не буквальная “волко-собака”, а адаптация под многовидовую “БиоСборку”. Такая формулировка честная и защищаемая.

## 4. Три варианта потомства

### До hardening
- `calculate_punnett_probabilities` возвращал вероятности.
- `crossbreed` создавал реального потомка.
- Буквального stateless API “вернуть 3 варианта” не было.

### После hardening
Добавлен package API:

```sql
function preview_offspring_options(
    p_session_token in varchar2,
    p_lab_id        in number,
    p_parent1_id    in number,
    p_parent2_id    in number,
    p_options_count in number default 3
) return sys_refcursor;
```

Cursor возвращает preview-варианты без side effects. Default `3` буквально закрывает требование “показывает 3 случайных варианта потомства”.

Покрытие:
- `11_offspring_preview_smoke_test.sql` проверяет default count, custom count, access control, invalid count, отсутствие side effects и работоспособность `crossbreed` после preview.
- Runner теперь `01..11`.

## 5. Риски мутагенов и последствия

`apply_mutagen` уже достаточно закрывает “эксперименты с риском”:
- `RADIATION` и `CHEMICAL` имеют стоимость;
- есть rating penalty;
- результат меняет genotype случайно или полууправляемо;
- операции пишутся в `experiments`;
- штрафы пишутся в `rating_events`.

Изменения не нужны. Требования уровня 5 вроде смерти существ или ethics council не добавлять.

## 6. Минимальный список backend-доработок

| Приоритет | Доработка | Зачем | Риск | Нужен ли DDL | Нужны ли tests | Статус |
| --- | --- | --- | --- | --- | --- | --- |
| P0 | `preview_offspring_options(... default 3)` | Буквально закрыть 3 preview-варианта потомства | Средний | Нет | Да | Готово, test `11` зеленый |
| P1 | Называть `tasks` как “Заказы клиента” в web/docs | Четче закрыть формулировку уровня 4 | Низкий | Нет | Нет | Готово в docs, web впереди |
| P1 | Показывать experiment history как “эволюционную линию” | Защитить адаптацию “волко-собаки” | Низкий | Нет | Нет | Готово в docs, web впереди |
| P2 | Web display wrappers/pages | Удобная демонстрация на стенде | Низкий | Нет | Web smoke позже | Следующий этап |

## 7. Предлагаемый следующий технический трек

Ветка hardening уже завершена. Следующий трек — web-client planning и затем минимальная реализация:

1. `docs/web_client_plan.md`.
2. Flask/Jinja skeleton.
3. Auth/labs/dashboard.
4. Creatures/tasks.
5. Crossbreed page с `preview_offspring_options`.
6. Mutations/experiments/rating events.

Backend менять на этом этапе не требуется.

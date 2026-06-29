# Технический аудит backend hardening для уровня "хорошо"

Дата аудита: 2026-06-29
Ветка: `main`
Исходная точка: `e75aee1 Подготовить материалы для защиты уровня хорошо`, `git status --short` был чистым.

Этот документ начинался как анализ. После hardening P0 закрывается отдельной backend-доработкой: `preview_offspring_options` + smoke-test `11`. DDL, seed и GUI при этом не меняются.

## 1. Краткий вывод

Большая часть требований уровня 4 уже закрыта без изменений backend:

- сложная генетика: `FULL`, `INCOMPLETE`, `CODOMINANT`, `genes.linkage_group`;
- скрещивание и наследование: `calculate_punnett_probabilities`, `crossbreed`, `make_experiment`;
- мутации и мутагены: `buy_mutation`, `apply_mutation`, `apply_mutagen`;
- риск экспериментов: списания `wallet`, штрафы `rating`, история `rating_events`;
- история действий лаборатории: `experiments`, `get_experiment_history`, `show_mutation_history`;
- задания как marker-based цели на нужный фенотип: `tasks`, `task_markers`, `check_task`, `complete_task`.

Требования, которые закрыты, но требуют лучшей демонстрации:

- “заказы клиента”: фактически это текущие `tasks`, но в UI/docs их нужно называть заказами клиента;
- “эволюционная линия”: фактически это последовательность `CROSS`/`MUTATION`/`MUTAGEN` операций в `experiments`, ведущая к выполнению task;
- “3 случайных варианта потомства”: P0 закрывается через stateless cursor `preview_offspring_options`, который по умолчанию возвращает 3 preview-варианта без создания существа.

Минимальные backend/API-доработки, которые стоит сделать перед web-клиентом и защитой уровня 4:

- P0: backend API для preview трёх вариантов потомства без создания существа добавлен как `preview_offspring_options`;
- P1: усилить формулировку “заказ клиента” в seed/docs/UI label без DDL;
- P1: явно показывать `get_experiment_history` как “эволюционную линию”;
- P2: добавить Python wrapper для нового preview API только после появления package API.

Что не нужно делать сейчас:

- не добавлять уровень 5: экосистему, смертность, совет по этике, закрытие лаборатории;
- не добавлять `client_order_title` или новые таблицы для заказов клиента;
- не переписывать `tasks` в provenance-based задания, пока backend не хранит происхождение “получено именно скрещиванием/мутацией”;
- не переносить расчёт preview в Python.

## 2. Заказы клиента

Текущая система `tasks` уже подходит для трактовки “заказ клиента” без изменения схемы.

| Вопрос | Фактическое состояние | Вывод |
| --- | --- | --- |
| Есть ли описание задания | Да. `tasks.description` заполняется в seed. | Достаточно для клиентского текста заказа. |
| Есть ли reward | Да. `money_reward`, `rating_reward`, `difficulty_code`. | Награда выглядит как оплата/репутация за заказ. |
| Есть ли task markers | Да. `task_markers` связывает task с требуемыми allele markers. | Backend проверяет заказ по признакам. |
| Можно ли трактовать task как заказ клиента | Да. Текущие формулировки “найдите”, “отберите”, “предъявите” честно описывают marker-based проверку. | DDL не нужен. |
| Нужно ли менять seed-тексты | Не обязательно. Можно точечно добавить “Заказ клиента:” в UI/docs или в будущий web heading. | Seed менять только если хочется сильнее стилистически оформить защиту. |
| Нужно ли поле `client_order_title` | Нет. Это лишний DDL-риск перед защитой. | Лучше оставить `tasks.description` как source of truth. |

Практичная рекомендация:

- DDL не нужен.
- Backend package менять не нужно.
- Для защиты и будущего web достаточно называть блок `tasks` как “Заказы клиента”.
- Если всё же усиливать seed, безопасный вариант: заменить часть описаний на формат “Заказ клиента: найдите/отберите ...”, не меняя task names, markers, rewards и tests. Это P1, не P0.
- Не писать “выведите через скрещивание”, пока backend проверяет итоговые признаки, а не provenance.

## 3. Эволюционная линия

В проекте уже есть данные, из которых можно показать эволюционную линию лаборатории:

| Элемент | Что даёт | Статус |
| --- | --- | --- |
| `experiments` | Хранит `CROSS`, `MUTATION`, `MUTAGEN`, родителей, mutation_id, offspring_id, timestamp. | OK |
| `get_experiment_history` | Возвращает историю операций лаборатории с display label типа эксперимента. | OK |
| `show_mutation_history` | LR2-compatible wrapper над историей экспериментов. | OK |
| `rating_events` | Объясняет экономические последствия: покупка мутации, штраф мутагена, reward task. | OK, дополняет историю |
| `complete_task` | Финальная точка линии: существо предъявлено и заказ закрыт. | OK |

Сохраняются операции:

- `CROSS`: через `crossbreed` и ветку `make_experiment` с двумя родителями;
- `MUTATION`: через `apply_mutation` / `make_experiment` с mutation_id;
- `MUTAGEN`: через `apply_mutagen`.

Вывод:

- Новая таблица для “эволюционной линии” не нужна.
- Новая backend API не обязательна: текущий `get_experiment_history` уже достаточен для web/GUI-представления “линии”.
- Для будущего web можно сделать display-level view: “заказ клиента” + timeline `experiments` + финальное `complete_task`/`rating_events`.
- Если преподаватель ждёт буквальную “волко-собаку”, это нужно объяснять как адаптацию: в “БиоСборке” линия многовидовая, а не одна собачья порода.

## 4. Три варианта потомства

Это главный технический зазор между текущей реализацией и буквальной формулировкой требований уровня 3.

Текущая реализация:

| Элемент | Что делает сейчас |
| --- | --- |
| `calculate_punnett_probabilities(p_parent1_id, p_parent2_id, p_gene_id)` | Возвращает вероятности allele-pair вариантов для одного выбранного гена. |
| `crossbreed(p_lab_id, p_parent1_id, p_parent2_id, p_offspring_name, p_offspring_id out)` | Создаёт реального потомка, наследует полный генотип, учитывает linkage groups, пишет `experiments`. |
| `04_crossbreed_smoke_test.sql` | Проверяет, что Punnett cursor возвращает rows, сумма вероятностей около 1, а `crossbreed` создаёт offspring. |
| `pkg_api.py` | Имеет wrappers для `calculate_punnett_probabilities`, `preview_offspring_options` и `crossbreed`. |

Честный ответ:

- Backend теперь возвращает ровно 3 случайных preview-варианта потомства по умолчанию через `preview_offspring_options`.
- Вероятностная таблица по отдельному гену остаётся в `calculate_punnett_probabilities`.
- Реальное создание потомка остаётся отдельной state-changing операцией `crossbreed`.

Реализованная минимальная доработка P0:

```sql
function preview_offspring_options(
    p_session_token in varchar2,
    p_lab_id        in number,
    p_parent1_id    in number,
    p_parent2_id    in number,
    p_options_count in number default 3
) return sys_refcursor;
```

Требования к реализации:

- API должен быть stateless: не создавать creature, не писать `genotypes`, не писать `experiments`, не менять `wallet/rating`.
- Логика должна переиспользовать те же правила наследования, что `crossbreed`: species check, common genes, random allele side, linkage group consistency внутри одного preview-варианта.
- Cursor должен возвращать ровно `least(greatest(p_options_count, 1), 10)` вариантов, по умолчанию 3.
- Для каждого варианта желательно вернуть:
  - `option_no`;
  - `species_type`, `species_display_name`;
  - `phenotype_color`, `phenotype_size`, `phenotype_has_wings`, `phenotype_nutrition_type`;
  - `phenotype_summary`;
  - возможно compact genotype summary для debug/demo.
- Чтобы не создавать постоянные существа, можно считать phenotype через локальную временную структуру сложно; проще и безопаснее сделать helper, который строит summary по выбранным allele descriptions. Если это слишком рискованно, на первом шаге вернуть allele-pair summary и display labels, а полноценный phenotype оставить для следующего этапа.

Тесты для новой API:

- добавить `database/tests/11_offspring_preview_smoke_test.sql` или расширить `04_crossbreed_smoke_test.sql`;
- проверить, что cursor возвращает 3 строки по default;
- проверить, что preview не увеличивает count в `creatures`, `genotypes`, `experiments`;
- проверить, что чужая лаборатория/родители из разных labs блокируются;
- проверить, что parents same species, иначе ожидаемая ошибка;
- обновить runner до `01..11`, если будет отдельный test 11.

Итог: буквальное требование по трём вариантам закрывается новым package cursor и test `11_offspring_preview_smoke_test.sql`.

## 5. Риски мутагенов и последствия

Текущая реализация закрывает “эксперименты с риском” достаточно хорошо для уровня 4.

| Элемент | Фактическое поведение | Покрытие |
| --- | --- | --- |
| `apply_mutagen(..., 'RADIATION', ...)` | Стоимость 50, rating penalty до -5, возможно больше одного random mutation round. | `05`, `07`, `10` |
| `apply_mutagen(..., 'CHEMICAL', ...)` | Стоимость 100, rating penalty до -2, более контролируемый выбор target gene. | `07`, `08` |
| `experiments` | Пишет событие `MUTAGEN` с исходным и новым существом. | `05` |
| `rating_events` | Пишет `MUTAGEN_PENALTY`, объясняет wallet/rating delta. | `10` |
| auto-complete tasks | Если мутаген создал подходящее существо, reward пишется отдельно как `TASK_REWARD`. | `05`, `06`, `10` |

Вывод:

- Изменения backend не нужны.
- На защите нужно показывать “риск” как комбинацию стоимости, штрафа рейтинга и случайности результата.
- Не нужно добавлять смерть существ или ethics penalties: это уже уровень 5.

## 6. Минимальный список backend-доработок

| Приоритет | Доработка | Зачем | Риск | Нужен ли DDL | Нужны ли tests |
| --- | --- | --- | --- | --- | --- |
| P0 | `preview_offspring_options(... default 3)` в package | Буквально закрыть “показывает 3 случайных варианта потомства” | Средний: важно подтвердить отсутствие side effects | Нет | Да, `11_offspring_preview_smoke_test.sql` |
| P1 | Переименовать UI/docs блок `Задания` в “Заказы клиента” для web/demo | Чётче закрыть формулировку уровня 4 | Низкий | Нет | Нет, если только docs/UI |
| P1 | Точечно усилить seed descriptions префиксом “Заказ клиента:” | Чтобы даже в БД формулировка выглядела как заказ | Низкий, но потребует rerun seed/tests | Нет | Да, минимум `02`, `06`, `07` |
| P1 | Показывать `get_experiment_history` как “эволюционную линию” | Защитить адаптацию “волко-собаки” | Низкий | Нет | Нет, уже покрыто `05`, `09` |
| P2 | Добавить Python wrapper для preview API | Подготовить будущий web/PySide display-layer | Низкий после package API | Нет | compileall + будущий web smoke |
| Не делать | `client_order_title` / новая таблица client orders | Это красиво, но не нужно для защиты | Лишний DDL-риск | Да | Да |
| Не делать | Ecosystem/death/ethics/lab closure | Это уровень 5, не текущая цель | Высокий | Да | Да |

## 7. Предлагаемый следующий технический трек

Рекомендуемая ветка:

```powershell
git checkout -b backend-level4-hardening
```

Минимальный состав трека:

1. Package API для preview трёх вариантов потомства:
   - добавить spec/body `preview_offspring_options`;
   - сохранить существующие `calculate_punnett_probabilities` и `crossbreed` без изменения сигнатур;
   - не менять состояние БД при preview.
2. Test:
   - добавить `database/tests/11_offspring_preview_smoke_test.sql` или расширить `04`;
   - если добавлен `11`, обновить runner/README с `01..11`.
3. Заказы клиента:
   - без DDL;
   - либо только docs/web label “Заказы клиента”, либо небольшой seed text hardening отдельным коммитом.
4. Эволюционная линия:
   - без новой таблицы;
   - в web/demo показывать `get_experiment_history` как timeline.

После успешного runner `01..11` можно переходить к `docs/web_client_plan.md`: риск по буквальной фразе “3 случайных варианта” закрыт backend API.

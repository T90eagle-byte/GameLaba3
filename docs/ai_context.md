# Технический snapshot: «БиоСборка» v3

## Рабочее состояние

- Репозиторий: `C:\GameLR3`.
- Основная ветка: `main`.
- Текущий schema/install marker: **14**.
- Backend truth: Oracle package `pkg_genetics_game`.
- Клиенты: PySide6 и Flask/Jinja — только display/API clients.

Новые SQL/PLSQL изменения статически проверены на совместимость с Oracle 12.2.
Runtime validation на Oracle 12.2 должна быть выполнена на университетском
стенде.

## Модели лабораторий

- Исторические лаборатории остаются `genetics_version=1` и не конвертируются.
- Новые лаборатории создаются как `genetics_version=3`.
- v3 содержит 19 canonical genes: `nutrition_type` и 18 universal morphology
  genes из `ref_genetics_model_genes`.
- `ref_creature_archetypes` содержит 18 стартовых архетипов;
  `ref_archetype_alleles` задаёт их генотипы.
- Стартовые v3-существа имеют `archetype_id`; потомки и мутагенные клоны могут
  его не иметь, поскольку renderer читает materialized morphology.

## Скрещивание, мутации и эксперименты

- Обычное `crossbreed` — два существа одного обычного вида.
- Preview stateless и не создаёт игровых данных.
- Unified experiment modes: `CROSS`, `MUTATION`, `MUTAGEN`,
  `CROSSBREED_MUTAGEN`, `HYBRIDIZATION`.
- v3 directed mutation возможна только для совместимого production rule;
  текущий production v3-каталог направленного morphology content намеренно
  пуст.
- `RADIATION` и `CHEMICAL` работают через package.
- Гибрид имеет `species_type=7`, `archetype_id=NULL` и **ровно 19 canonical
  genes**. Он не может размножаться, но может мутировать.
- Гибридизация применяет рейтинг `-50` с ограничением до нуля.

## Задания

- v1: marker alleles, присутствие в allele1 или allele2.
- v3: package проверяет выраженный phenotype.
- Task rewards и Монеты/рейтинг не рассчитываются в Flask.

## Установка и обновление

- Fresh assigned schema: `database/installers/university_existing_schema_install.sql`.
- Existing BioSborka schema: `database/installers/university_existing_schema_update.sql`.
- Оба entry points приводят recognised schema к marker 14, применяют
  migrations `01..14`, seeds `01..05`, package и validation. Update сохраняет
  пользователей и игровой прогресс.
- Docker `db-init` использует тот же versioned contract; не заменять его
  destructive fallback.
- Runtime CLI: `database/scripts/check_runtime_readiness.py`.

## Тесты и demo

- `database/scripts/run_tests.py` numeric-discoveries backend tests `01..30`;
  полный runner компилирует package и печатает status/user_errors.
- Test 30 — connected v3 end-to-end acceptance с exact temporary fixture
  cleanup.
- `database/scripts/create_lr3_demo_data.py` создаёт два demo users, десять
  historical v1 labs и две v3 showcase labs.
- `database/scripts/check_lr3_demo_data.py` проверяет formal demo minimum и
  v3 showcase data.
- Web tests находятся в `web_client/tests`; Oracle web smoke —
  `web_client/smoke_test.py`.

## Непереговорные инварианты

1. Historical labs остаются v1.
2. New labs создаются v3.
3. v3 renderer, tasks и mutations используют canonical morphology.
4. Hybrid genotype содержит ровно 19 canonical genes.
5. Hybrid не может размножаться.
6. В web нет прямого gameplay SQL.
7. Oracle package — единственный source of gameplay truth.
8. Existing DB обновляется миграциями, а не reinstall.
9. Обычный конфликт lab session не закрывает другие сессии; recovery передаёт
   только выбранную собственную лабораторию.

## Целевой стенд

Windows Server 2012 R2 x64, Python 3.12, Waitress, external Oracle 12.2 и
assigned existing schema. Используется `python-oracledb` Thin mode без Instant
Client. Реальная runtime validation ещё требуется на университетском стенде.

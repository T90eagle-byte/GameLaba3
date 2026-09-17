# Текущее состояние проекта

## READY

- versioned Oracle schema с marker `15` и migrations `01..15`;
- v1 compatibility для исторических лабораторий;
- v3 canonical genetics: 19 genes, 18 archetypes и materialized morphology;
- phenotype-aware v3 Задания;
- SVG renderer и package-backed read model;
- version-aware directed mutations и мутагены;
- unified `/experiments`: скрещивание, мутация, мутаген, «Скрещивание +
  мутаген», «Гибридизация»;
- controlled hybridization с canonical 19-gene hybrid;
- безопасный install/update для существующей схемы;
- v3 demo dataset и connected acceptance smoke-test `30`;
- web, readiness и deployment helpers.

## PENDING RELEASE GATE

1. Выполнить один полный RC regression на целевом актуальном состоянии.
2. Выполнить runtime validation на университетской Oracle 12.2.
3. Развернуть Waitress на вузовском стенде и проверить `/health/live`,
   `/health`, readiness и v3 demo-витрину.

## DEFERRED, НЕ BLOCKER ДЛЯ ЗАЩИТЫ

- production content направленных morphology-мутаций для v3;
- mutation/tasks для `nutrition_type`;
- размножение гибридов;
- дополнительные виды мутагенов;
- hybrid-specific Задания;
- более сложная графика renderer;
- удаление legacy compatibility routes.

Не переносить gameplay logic из Oracle в web-клиент и не обновлять
существующую базу переустановкой.

# Roadmap «БиоСборки»

## Завершено

- Oracle schema, reference data и `pkg_genetics_game`;
- многопользовательские сессии и scoped recovery лаборатории;
- v1 compatibility и versioned v3 model;
- архетипы, universal morphology, phenotype-aware Задания;
- version-aware mutations, unified experiments и гибридизация;
- web read model, renderer, history и runtime readiness;
- безопасные fresh/install/update entry points;
- v3 demo dataset и acceptance test `30`.

## Следующий этап: Release Candidate

1. Полный RC regression на актуальном `main`.
2. Runtime validation на университетской Oracle 12.2.
3. Развёртывание Python 3.12 + Waitress на Windows Server 2012 R2.
4. Проверка v3 demo-витрины и подготовка к защите.

## После появления стенда

Подтвердить фактическую совместимость соединения Thin mode, SQL Developer
installer, readiness и browser access на вузовском окружении. До такого
запуска это не следует объявлять завершённым.

## Осознанно отложено

Расширение v3 mutation content, nutrition content, гибридные Задания,
размножение гибридов и художественное усложнение renderer. Это не условия
release candidate и не требует изменения существующей v1 совместимости.

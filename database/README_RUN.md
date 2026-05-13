# Oracle backend slice: run guide

This guide is for Oracle SQL Developer, SQLcl, or SQL*Plus.

## Prerequisites

- The schema must have `EXECUTE` on `DBMS_CRYPTO`.
- If `UTL_I18N` is used (for password hashing input encoding), the schema must also have `EXECUTE` on `UTL_I18N`.
- Without these grants, package body compilation can fail.

## 1) Run DDL

From repository root:

```sql
@database/ddl/01_create_tables.sql
```

## 2) Run package specification

```sql
@database/packages/spec/pkg_genetics_game.pks
```

Check compile output:

```sql
show errors package pkg_genetics_game
```

## 3) Run package body

```sql
@database/packages/body/pkg_genetics_game.pkb
```

Check compile output:

```sql
show errors package body pkg_genetics_game
```

## 4) Run smoke-test

```sql
@database/tests/01_auth_labs_smoke_test.sql
```

The script uses anonymous PL/SQL blocks and `dbms_output` only for test reporting.

## 5) Inspect compile errors via USER_ERRORS

```sql
select
    name,
    type,
    line,
    position,
    text
from user_errors
where upper(name) = 'PKG_GENETICS_GAME'
order by sequence;
```

## Useful verification queries

### Verify tables

```sql
select table_name
from user_tables
where table_name in (
    'USERS',
    'SESSIONS',
    'LABS',
    'GENES',
    'ALLELES',
    'MUTATIONS',
    'MUTATION_RULES',
    'TASKS',
    'CREATURES',
    'GENOTYPES',
    'EXPERIMENTS',
    'LAB_MUTATIONS',
    'LAB_TASKS',
    'TASK_MARKERS'
)
order by table_name;
```

### Verify sequences

```sql
select sequence_name
from user_sequences
where sequence_name in (
    'USERS_SEQ',
    'SESSIONS_SEQ',
    'LABS_SEQ',
    'GENES_SEQ',
    'ALLELES_SEQ',
    'MUTATIONS_SEQ',
    'MUTATION_RULES_SEQ',
    'TASKS_SEQ',
    'CREATURES_SEQ',
    'GENOTYPES_SEQ',
    'EXPERIMENTS_SEQ',
    'LAB_MUTATIONS_SEQ',
    'LAB_TASKS_SEQ',
    'TASK_MARKERS_SEQ'
)
order by sequence_name;
```

### Quick package status check

```sql
select object_name, object_type, status
from user_objects
where object_name = 'PKG_GENETICS_GAME'
order by object_type;
```

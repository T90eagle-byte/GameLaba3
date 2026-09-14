-- Run this migration with the application stopped.
-- Existing tasks are historical v1 entries. This migration does not touch LAB_TASKS.

set define off;
set serveroutput on size unlimited;

declare
    v_table_count      number;
    v_column_count     number;
    v_invalid_count    number;
    v_nullable         user_tab_columns.nullable%type;
    v_constraint_count number;
begin
    select count(*)
      into v_table_count
      from user_tables
     where table_name = 'TASKS';

    if v_table_count = 0 then
        raise_application_error(-20930, 'Task genetics-version migration requires TASKS.');
    end if;

    select count(*)
      into v_column_count
      from user_tab_columns
     where table_name = 'TASKS'
       and column_name = 'GENETICS_VERSION';

    if v_column_count = 0 then
        execute immediate 'alter table tasks add (genetics_version number(2) null)';
    end if;

    execute immediate q'[
        update tasks
           set genetics_version = 1
         where genetics_version is null
    ]';

    execute immediate q'[
        select count(*)
          from tasks
         where genetics_version not in (1, 3)
    ]'
    into v_invalid_count;

    if v_invalid_count <> 0 then
        raise_application_error(
            -20931,
            'TASKS.GENETICS_VERSION contains unsupported values; expected only 1 or 3.'
        );
    end if;

    select nullable
      into v_nullable
      from user_tab_columns
     where table_name = 'TASKS'
       and column_name = 'GENETICS_VERSION';

    if v_nullable = 'Y' then
        execute immediate 'alter table tasks modify (genetics_version default 1 not null)';
    else
        execute immediate 'alter table tasks modify (genetics_version default 1)';
    end if;

    select count(*)
      into v_constraint_count
      from user_constraints
     where table_name = 'TASKS'
       and constraint_name = 'CK_TASKS_GENETICS_VERSION';

    if v_constraint_count = 0 then
        execute immediate q'[
            alter table tasks
            add constraint ck_tasks_genetics_version
            check (genetics_version in (1, 3))
        ]';
    else
        select count(*)
          into v_constraint_count
          from user_constraints
         where table_name = 'TASKS'
           and constraint_name = 'CK_TASKS_GENETICS_VERSION'
           and status = 'ENABLED';

        if v_constraint_count = 0 then
            raise_application_error(-20932, 'CK_TASKS_GENETICS_VERSION exists but is not enabled.');
        end if;
    end if;

    commit;
end;
/

@@../seeds/05_seed_v3_tasks.sql
@@../packages/body/pkg_genetics_game.pkb

begin
    dbms_output.put_line('Task genetics-version migration complete: historical tasks are v1 and the v3 morphology catalogue is ready.');
end;
/

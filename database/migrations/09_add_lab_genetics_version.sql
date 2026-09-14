-- Run this migration with the application stopped.
-- Existing laboratories are historical legacy laboratories and stay untouched
-- except for their explicit genetics_version marker.

set define off;
set serveroutput on size unlimited;

declare
    v_column_count     number;
    v_invalid_count    number;
    v_constraint_count number;
    v_nullable         user_tab_columns.nullable%type;
begin
    select count(*)
      into v_column_count
      from user_tab_columns
     where table_name = 'LABS'
       and column_name = 'GENETICS_VERSION';

    if v_column_count = 0 then
        execute immediate 'alter table labs add (genetics_version number(2) null)';
    end if;

    execute immediate q'[
        update labs
           set genetics_version = 1
         where genetics_version is null
    ]';

    execute immediate q'[
        select count(*)
          from labs
         where genetics_version not in (1, 3)
    ]'
    into v_invalid_count;

    if v_invalid_count <> 0 then
        raise_application_error(
            -20890,
            'LABS.GENETICS_VERSION contains unsupported values; expected only 1 or 3.'
        );
    end if;

    select nullable
      into v_nullable
      from user_tab_columns
     where table_name = 'LABS'
       and column_name = 'GENETICS_VERSION';

    if v_nullable = 'Y' then
        execute immediate 'alter table labs modify (genetics_version default 3 not null)';
    else
        execute immediate 'alter table labs modify (genetics_version default 3)';
    end if;

    select count(*)
      into v_constraint_count
      from user_constraints
     where table_name = 'LABS'
       and constraint_name = 'CK_LABS_GENETICS_VERSION';

    if v_constraint_count = 0 then
        execute immediate q'[
            alter table labs
            add constraint ck_labs_genetics_version
            check (genetics_version in (1, 3))
        ]';
    else
        select count(*)
          into v_constraint_count
          from user_constraints
         where table_name = 'LABS'
           and constraint_name = 'CK_LABS_GENETICS_VERSION'
           and status = 'ENABLED';

        if v_constraint_count = 0 then
            raise_application_error(-20891, 'CK_LABS_GENETICS_VERSION exists but is not enabled.');
        end if;
    end if;

    commit;
end;
/

@@../packages/body/pkg_genetics_game.pkb

begin
    dbms_output.put_line('Lab genetics-version migration complete: existing labs remain legacy v1; new labs default to v3.');
end;
/

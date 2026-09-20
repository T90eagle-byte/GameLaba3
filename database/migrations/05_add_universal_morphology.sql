-- Запускайте миграцию при остановленном приложении.
-- Она добавляет признак включения для справочных генов морфологии и сохраняет
-- активными и неизменными все существующие игровые гены и строки генотипов.

set define off;
set serveroutput on size unlimited;

declare
    v_column_count number;
begin
    select count(*)
      into v_column_count
      from user_tab_columns
     where table_name = 'GENES'
       and column_name = 'GAMEPLAY_ENABLED';

    if v_column_count = 0 then
        execute immediate 'alter table genes add (gameplay_enabled char(1 char) default ''Y'')';
    end if;
end;
/

declare
    v_constraint_count number;
    v_nullable         user_tab_columns.nullable%type;
begin
    update genes
       set gameplay_enabled = 'Y'
     where gameplay_enabled is null;

    select nullable
      into v_nullable
      from user_tab_columns
     where table_name = 'GENES'
       and column_name = 'GAMEPLAY_ENABLED';

    if v_nullable = 'Y' then
        execute immediate 'alter table genes modify (gameplay_enabled default ''Y'' not null)';
    end if;

    select count(*)
      into v_constraint_count
      from user_constraints
     where table_name = 'GENES'
       and constraint_name = 'CK_GENES_GAMEPLAY_ENABLED';

    if v_constraint_count = 0 then
        execute immediate q'[alter table genes add constraint ck_genes_gameplay_enabled check (gameplay_enabled in ('Y', 'N'))]';
    end if;
end;
/

@@../seeds/02_seed_universal_morphology.sql
@@../packages/body/pkg_genetics_game.pkb

begin
    dbms_output.put_line('Universal morphology migration complete: active gameplay genes are Y; reference morphology genes are N.');
end;
/

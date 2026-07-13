-- Run this migration with the application stopped.
-- It adds player-facing names without changing existing laboratory ownership.

set serveroutput on size unlimited;

begin
    dbms_output.put_line('=== MIGRATION: add laboratory names ===');
end;
/

declare
    v_column_count number;
begin
    select count(*)
      into v_column_count
      from user_tab_columns utc
     where utc.table_name = 'LABS'
       and utc.column_name = 'LAB_NAME';

    if v_column_count = 0 then
        execute immediate 'alter table labs add (lab_name varchar2(60 char))';
    end if;
end;
/

update labs
   set lab_name = 'Био-мастерская #' || to_char(lab_id)
 where lab_name is null;

declare
    v_nullable user_tab_columns.nullable%type;
begin
    select utc.nullable
      into v_nullable
      from user_tab_columns utc
     where utc.table_name = 'LABS'
       and utc.column_name = 'LAB_NAME';

    if v_nullable = 'Y' then
        execute immediate 'alter table labs modify (lab_name not null)';
    end if;
end;
/

commit;

begin
    dbms_output.put_line('Migration complete: labs.lab_name is populated and NOT NULL.');
end;
/

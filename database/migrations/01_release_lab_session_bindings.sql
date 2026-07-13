-- Run this migration with the application stopped.
-- It converts labs.session_id from a permanent binding into an active lock
-- and releases bindings left by earlier application versions.

set serveroutput on size unlimited;

begin
    dbms_output.put_line('=== MIGRATION: release lab session bindings ===');
end;
/

declare
    v_nullable user_tab_columns.nullable%type;
begin
    select utc.nullable
      into v_nullable
      from user_tab_columns utc
     where utc.table_name = 'LABS'
       and utc.column_name = 'SESSION_ID';

    if v_nullable = 'N' then
        execute immediate 'alter table labs modify (session_id null)';
    end if;
end;
/

update labs
   set session_id = null
 where session_id is not null;

commit;

begin
    dbms_output.put_line('Migration complete: labs.session_id is nullable and existing labs are released.');
end;
/

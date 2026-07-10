-- Run this migration with the application stopped.
-- It converts labs.session_id from a permanent binding into an active lock
-- and releases bindings left by earlier application versions.

set serveroutput on size unlimited;

begin
    dbms_output.put_line('=== MIGRATION: release lab session bindings ===');
end;
/

alter table labs modify (session_id null);

update labs
   set session_id = null
 where session_id is not null;

commit;

begin
    dbms_output.put_line('Migration complete: labs.session_id is nullable and existing labs are released.');
end;
/

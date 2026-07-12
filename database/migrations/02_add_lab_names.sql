-- Run this migration with the application stopped.
-- It adds player-facing names without changing existing laboratory ownership.

set serveroutput on size unlimited;

begin
    dbms_output.put_line('=== MIGRATION: add laboratory names ===');
end;
/

alter table labs add (lab_name varchar2(60 char));

update labs
   set lab_name = 'Био-мастерская #' || to_char(lab_id)
 where lab_name is null;

alter table labs modify (lab_name not null);

commit;

begin
    dbms_output.put_line('Migration complete: labs.lab_name is populated and NOT NULL.');
end;
/

-- Запускайте миграцию при остановленном приложении.
-- Она добавляет необязательные пользовательские названия, не меняя стабильные коды аллелей.

set define off;
set serveroutput on size unlimited;

declare
    v_column_count number;
begin
    select count(*)
      into v_column_count
      from user_tab_columns
     where table_name = 'ALLELES'
       and column_name = 'DISPLAY_NAME';

    if v_column_count = 0 then
        execute immediate 'alter table alleles add (display_name varchar2(128 char) null)';
    end if;
end;
/

@@../seeds/02_seed_universal_morphology.sql
@@../packages/body/pkg_genetics_game.pkb

begin
    dbms_output.put_line('Allele display-name migration complete: universal morphology display names are ready.');
end;
/

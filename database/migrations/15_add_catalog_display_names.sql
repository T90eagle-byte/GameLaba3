-- Пользовательские названия каталогов являются справочными данными.
-- TASK_NAME и MUTATION_NAME остаются техническими идентификаторами пакета.
-- Миграция аддитивна и безопасна для распознанных существующих схем.
set define off;
set serveroutput on size unlimited;
set verify off;

declare
    v_count number;
begin
    select count(*)
      into v_count
      from user_tab_columns
     where table_name = 'TASKS'
       and column_name = 'DISPLAY_NAME';

    if v_count = 0 then
        execute immediate 'alter table tasks add (display_name varchar2(160 char))';
    end if;

    select count(*)
      into v_count
      from user_tab_columns
     where table_name = 'MUTATIONS'
       and column_name = 'DISPLAY_NAME';

    if v_count = 0 then
        execute immediate 'alter table mutations add (display_name varchar2(120 char))';
    end if;
end;
/

comment on column tasks.display_name is
    'Пользовательское название задания; TASK_NAME остаётся стабильным техническим кодом.';
comment on column mutations.display_name is
    'Пользовательское название мутации; MUTATION_NAME остаётся стабильным техническим кодом.';

-- Для имеющихся строк первоначально используются пользовательские описания.
-- Канонические идемпотентные seed-данные задают краткие названия при установке.
update tasks
   set display_name = description
 where display_name is null
   and description is not null;

update mutations
   set display_name = description
 where display_name is null
   and description is not null;

commit;

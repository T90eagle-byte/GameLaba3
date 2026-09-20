-- Запускайте миграцию при остановленном приложении.
-- Она заполняет только справочные шаблоны архетипов, не меняя игровое состояние.

set define off;
set serveroutput on size unlimited;

declare
    v_count number;
begin
    select count(*)
      into v_count
      from user_tables
     where table_name in (
        'REF_CREATURE_ARCHETYPES', 'REF_ARCHETYPE_ALLELES', 'GENES', 'ALLELES'
     );

    if v_count <> 4 then
        raise_application_error(
            -20861,
            'Archetype template migration requires migrations 04 and 05 plus the base genes and alleles.'
        );
    end if;

    select count(*)
      into v_count
      from user_tab_columns
     where table_name = 'GENES'
       and column_name = 'GAMEPLAY_ENABLED';

    if v_count <> 1 then
        raise_application_error(-20862, 'Archetype template migration requires migration 05.');
    end if;
end;
/

@@../seeds/03_seed_archetype_templates.sql

begin
    dbms_output.put_line('Archetype template migration complete: 18 reference templates contain 18 homozygous morphology genes each.');
end;
/

-- Run this migration with the application stopped.
-- It records the reference archetype only for future starter creatures.
-- Historical and crossbred creatures intentionally remain without an archetype.

set define off;
set serveroutput on size unlimited;

declare
    v_count    number;
    v_nullable user_tab_columns.nullable%type;
begin
    select count(*)
      into v_count
      from user_tables
     where table_name in ('CREATURES', 'REF_CREATURE_ARCHETYPES');

    if v_count <> 2 then
        raise_application_error(
            -20870,
            'Creature archetype link migration requires CREATURES and REF_CREATURE_ARCHETYPES.'
        );
    end if;

    select count(*)
      into v_count
      from user_tab_columns
     where table_name = 'CREATURES'
       and column_name = 'ARCHETYPE_ID';

    if v_count = 0 then
        execute immediate 'alter table creatures add (archetype_id number null)';
    end if;

    select nullable
      into v_nullable
      from user_tab_columns
     where table_name = 'CREATURES'
       and column_name = 'ARCHETYPE_ID';

    if v_nullable <> 'Y' then
        raise_application_error(-20871, 'CREATURES.ARCHETYPE_ID must remain nullable for historical and hybrid creatures.');
    end if;

    select count(*)
      into v_count
      from user_constraints
     where table_name = 'CREATURES'
       and constraint_name = 'FK_CREATURES_ARCHETYPE_ID'
       and status = 'ENABLED';

    if v_count = 0 then
        select count(*)
          into v_count
          from user_constraints
         where table_name = 'CREATURES'
           and constraint_name = 'FK_CREATURES_ARCHETYPE_ID';

        if v_count <> 0 then
            raise_application_error(-20872, 'FK_CREATURES_ARCHETYPE_ID exists but is not enabled.');
        end if;

        execute immediate q'[
            alter table creatures
            add constraint fk_creatures_archetype_id
            foreign key (archetype_id)
            references ref_creature_archetypes (archetype_id)
        ]';
    end if;
end;
/

@@../packages/body/pkg_genetics_game.pkb

begin
    dbms_output.put_line('Creature archetype link migration complete: existing creatures remain unchanged; future starter creatures receive deterministic reference archetypes.');
end;
/

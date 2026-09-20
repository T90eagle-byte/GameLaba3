-- Smoke-test намеренно дважды запускает идемпотентную миграцию.
-- Он проверяет уникальность справочных seed-данных архетипов.

@../migrations/04_add_creature_archetypes.sql
@../migrations/04_add_creature_archetypes.sql

set serveroutput on size unlimited;
set verify off;

declare
    v_failed_tests number := 0;
    v_passed_tests number := 0;
    v_value        number;

    procedure pass_test(p_test_name in varchar2) is
    begin
        v_passed_tests := v_passed_tests + 1;
        dbms_output.put_line('[PASS] ' || p_test_name);
    end pass_test;

    procedure fail_test(p_test_name in varchar2, p_detail in varchar2 default null) is
    begin
        v_failed_tests := v_failed_tests + 1;
        dbms_output.put_line('[FAIL] ' || p_test_name || case when p_detail is null then '' else ' -> ' || p_detail end);
    end fail_test;

    procedure assert_true(p_condition in boolean, p_test_name in varchar2, p_detail in varchar2 default null) is
    begin
        if p_condition then
            pass_test(p_test_name);
        else
            fail_test(p_test_name, p_detail);
        end if;
    end assert_true;
begin
    select count(*)
      into v_value
      from user_tables
     where table_name in ('REF_CREATURE_ARCHETYPES', 'REF_ARCHETYPE_ALLELES');
    assert_true(v_value = 2, 'Archetype reference tables exist', 'actual=' || v_value);

    select count(*)
      into v_value
      from user_sequences
     where sequence_name = 'REF_CREATURE_ARCHETYPES_SEQ';
    assert_true(v_value = 1, 'Archetype sequence exists', 'actual=' || v_value);

    select count(*)
      into v_value
      from user_constraints
     where constraint_name in (
        'PK_REF_CREATURE_ARCHETYPES', 'UQ_REF_CREATURE_ARCHETYPE_CODE',
        'FK_REF_ARCHETYPE_SPECIES', 'CK_REF_ARCHETYPE_ACTIVE',
        'PK_REF_ARCHETYPE_ALLELES', 'FK_REF_ARCH_ALLELES_ARCHETYPE',
        'FK_REF_ARCH_ALLELES_GENE', 'FK_REF_ARCH_ALLELES_A1', 'FK_REF_ARCH_ALLELES_A2'
     )
       and status = 'ENABLED';
    assert_true(v_value = 9, 'Archetype PK and FK constraints exist', 'actual=' || v_value);

    select count(*)
      into v_value
      from ref_creature_archetypes;
    assert_true(v_value = 18, 'Minimum archetype seed count', 'actual=' || v_value);

    select count(*)
      into v_value
      from (
          select archetype_code
            from ref_creature_archetypes
           group by archetype_code
          having count(*) > 1
      );
    assert_true(v_value = 0, 'Archetype codes remain unique after repeated migration', 'duplicates=' || v_value);

    select count(*)
      into v_value
      from ref_creature_archetypes
     where archetype_code in (
        'shark', 'ray', 'sawfish', 'generic_bony_fish', 'eel', 'pufferfish',
        'crab', 'crayfish', 'shrimp', 'octopus', 'squid', 'snail',
        'sea_turtle', 'sea_snake', 'whale', 'dolphin', 'seal', 'walrus'
     );
    assert_true(v_value = 18, 'All required archetype codes exist', 'actual=' || v_value);

    dbms_output.put_line('Passed: ' || v_passed_tests || ', Failed: ' || v_failed_tests);
    if v_failed_tests > 0 then
        raise_application_error(-20990, 'Creature archetype smoke test failed: ' || v_failed_tests);
    end if;
end;
/

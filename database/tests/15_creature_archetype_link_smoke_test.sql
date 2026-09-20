-- Проверяет необязательные метаданные архетипа только для будущих стартовых существ.
-- Необязательные миграции намеренно запускаются повторно для проверки идемпотентности.

@@../migrations/04_add_creature_archetypes.sql
@@../migrations/05_add_universal_morphology.sql
@@../migrations/06_add_archetype_templates.sql
@@../migrations/07_add_creature_archetype.sql
@@../migrations/07_add_creature_archetype.sql

set serveroutput on size unlimited;
set verify off;

declare
    v_failed_tests             number := 0;
    v_passed_tests             number := 0;
    v_value                    number;
    v_user1_id                 number;
    v_user2_id                 number;
    v_lab1_id                  number;
    v_lab2_id                  number;
    v_session1_token           varchar2(128);
    v_session2_token           varchar2(128);
    v_login1                   varchar2(20) := 'a' || lower(substr(rawtohex(sys_guid()), 1, 19));
    v_login2                   varchar2(20) := 'b' || lower(substr(rawtohex(sys_guid()), 1, 19));
    v_password                 varchar2(100) := 'archetype_link_123';
    v_sequence1                varchar2(4000);
    v_sequence2                varchar2(4000);
    v_parent1_id               number;
    v_parent2_id               number;
    v_offspring_id             number;
    v_runtime_gene_count       number;
    v_creature_gene_count      number;

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

    procedure cleanup_test_data is
    begin
        if v_session1_token is not null and v_lab1_id is not null then
            begin
                pkg_genetics_game.delete_lab(v_session1_token, v_lab1_id);
            exception when others then
                dbms_output.put_line('[WARN] cleanup first lab: ' || sqlcode || ' / ' || sqlerrm);
            end;
        end if;

        if v_session2_token is not null and v_lab2_id is not null then
            begin
                pkg_genetics_game.delete_lab(v_session2_token, v_lab2_id);
            exception when others then
                dbms_output.put_line('[WARN] cleanup second lab: ' || sqlcode || ' / ' || sqlerrm);
            end;
        end if;

        begin
            delete from sessions
             where user_id in (v_user1_id, v_user2_id)
                or user_id in (select user_id from users where login in (v_login1, v_login2));
            delete from users
             where user_id in (v_user1_id, v_user2_id)
                or login in (v_login1, v_login2);
        exception when others then
            dbms_output.put_line('[WARN] cleanup users: ' || sqlcode || ' / ' || sqlerrm);
        end;
    end cleanup_test_data;
begin
    dbms_output.put_line('--- CREATURE ARCHETYPE LINK SMOKE TEST ---');

    select count(*)
      into v_value
      from user_tab_columns
     where table_name = 'CREATURES'
       and column_name = 'ARCHETYPE_ID'
       and nullable = 'Y';
    assert_true(v_value = 1, 'CREATURES.ARCHETYPE_ID exists and is nullable', 'actual=' || v_value);

    select count(*)
      into v_value
      from user_constraints
     where table_name = 'CREATURES'
       and constraint_name = 'FK_CREATURES_ARCHETYPE_ID'
       and constraint_type = 'R'
       and status = 'ENABLED';
    assert_true(v_value = 1, 'Archetype foreign key exists and is enabled', 'actual=' || v_value);

    begin
        pkg_genetics_game.register_user('Archetype smoke one', v_login1, v_password, v_user1_id);
        v_session1_token := pkg_genetics_game.login_user(v_login1, v_password);
        pkg_genetics_game.start_new_lab(v_session1_token, v_lab1_id);

        pkg_genetics_game.register_user('Archetype smoke two', v_login2, v_password, v_user2_id);
        v_session2_token := pkg_genetics_game.login_user(v_login2, v_password);
        pkg_genetics_game.start_new_lab(v_session2_token, v_lab2_id);
        pass_test('Two independent starter laboratories were created');
    exception when others then
        fail_test('Starter laboratory creation', sqlerrm);
    end;

    if v_lab1_id is not null then
        select count(*)
          into v_value
          from creatures
         where lab_id = v_lab1_id;
        assert_true(v_value = 30, 'New laboratory has 30 starter creatures', 'actual=' || v_value);

        select count(*)
          into v_value
          from creatures
         where lab_id = v_lab1_id
           and archetype_id is not null;
        assert_true(v_value = 30, 'Every starter creature has an archetype', 'actual=' || v_value);

        select count(*)
          into v_value
          from creatures c
          join ref_creature_archetypes r
            on r.archetype_id = c.archetype_id
         where c.lab_id = v_lab1_id
           and (c.species_type <> r.species_type or r.active_flag <> 'Y');
        assert_true(v_value = 0, 'Starter archetype species and active flag are consistent', 'mismatches=' || v_value);

        select count(*)
          into v_value
          from (
              select species_type
                from creatures
               where lab_id = v_lab1_id
               group by species_type
              having count(*) <> 5
          );
        assert_true(v_value = 0, 'Each of six species has five starters', 'invalid_species=' || v_value);

        select count(*)
          into v_value
          from (
              select c.species_type
                from creatures c
                join ref_creature_archetypes r
                  on r.archetype_id = c.archetype_id
               where c.lab_id = v_lab1_id
               group by c.species_type
              having count(distinct r.archetype_code) <= 1
          );
        assert_true(v_value = 0, 'Species with multiple references use more than one archetype', 'single_archetype_species=' || v_value);

        for rec in (
            select c.species_type, r.archetype_code, count(*) as creature_count
              from creatures c
              join ref_creature_archetypes r
                on r.archetype_id = c.archetype_id
             where c.lab_id = v_lab1_id
             group by c.species_type, r.archetype_code
             order by c.species_type, r.archetype_code
        ) loop
            dbms_output.put_line('[INFO] species=' || rec.species_type || ', archetype=' || rec.archetype_code || ', starters=' || rec.creature_count);
        end loop;

        select listagg(r.archetype_code, ',') within group (order by c.creature_id)
          into v_sequence1
          from creatures c
          join ref_creature_archetypes r
            on r.archetype_id = c.archetype_id
         where c.lab_id = v_lab1_id
           and c.species_type = 1;

        select min(creature_id), max(creature_id)
          into v_parent1_id, v_parent2_id
          from creatures
         where lab_id = v_lab1_id
           and species_type = 1;

        pkg_genetics_game.load_lab(v_session1_token, v_lab1_id);
        pkg_genetics_game.crossbreed(
            p_lab_id         => v_lab1_id,
            p_parent1_id     => v_parent1_id,
            p_parent2_id     => v_parent2_id,
            p_offspring_name => 'archetype_link_offspring',
            p_offspring_id   => v_offspring_id
        );

        select count(*)
          into v_value
          from creatures
         where creature_id = v_offspring_id
           and archetype_id is null;
        assert_true(v_value = 1, 'Crossbred offspring keeps nullable archetype metadata', 'actual=' || v_value);

        select count(*)
          into v_value
          from genotypes gt
          join genes g
            on g.gene_id = gt.gene_id
         where gt.creature_id = v_parent1_id
           and g.gameplay_enabled = 'N';
        assert_true(v_value = 18, 'Starter genotype materializes all reference morphology genes', 'actual=' || v_value);

        select count(*)
          into v_runtime_gene_count
          from genes
         where species_type in (0, 1)
           and gameplay_enabled = 'Y';
        select count(*)
          into v_creature_gene_count
          from genotypes
         where creature_id = v_parent1_id;
        assert_true(
            v_creature_gene_count = v_runtime_gene_count + 18,
            'Starter genotype combines runtime genes with its morphology template',
            'actual=' || v_creature_gene_count || ', expected=' || (v_runtime_gene_count + 18)
        );
    end if;

    if v_lab2_id is not null then
        select listagg(r.archetype_code, ',') within group (order by c.creature_id)
          into v_sequence2
          from creatures c
          join ref_creature_archetypes r
            on r.archetype_id = c.archetype_id
         where c.lab_id = v_lab2_id
           and c.species_type = 1;
        assert_true(v_sequence1 = v_sequence2, 'Clean starter labs receive the same deterministic archetype cycle', 'first=' || v_sequence1 || ', second=' || v_sequence2);
    end if;

    select count(*)
      into v_value
      from user_objects
     where object_name = 'PKG_GENETICS_GAME'
       and object_type in ('PACKAGE', 'PACKAGE BODY')
       and status = 'VALID';
    assert_true(v_value = 2, 'Package specification and body remain valid', 'actual=' || v_value);

    select count(*)
      into v_value
      from user_errors
     where name = 'PKG_GENETICS_GAME'
       and type in ('PACKAGE', 'PACKAGE BODY');
    assert_true(v_value = 0, 'Package user_errors remain clean', 'actual=' || v_value);

    cleanup_test_data;
    dbms_output.put_line('Passed: ' || v_passed_tests || ', Failed: ' || v_failed_tests);
    if v_failed_tests > 0 then
        raise_application_error(-20990, 'Creature archetype link smoke test failed: ' || v_failed_tests);
    end if;
exception
    when others then
        cleanup_test_data;
        raise;
end;
/

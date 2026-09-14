-- Validates dual-schema materialization for new starter creatures.
-- The test creates one isolated laboratory and removes it at the end.

@@../migrations/04_add_creature_archetypes.sql
@@../migrations/05_add_universal_morphology.sql
@@../migrations/06_add_archetype_templates.sql
@@../migrations/07_add_creature_archetype.sql

set serveroutput on size unlimited;
set verify off;

declare
    v_failed_tests          number := 0;
    v_passed_tests          number := 0;
    v_value                 number;
    v_user_id               number;
    v_lab_id                number;
    v_session_token         varchar2(128);
    v_login                 varchar2(20) := 's' || lower(substr(rawtohex(sys_guid()), 1, 19));
    v_password              varchar2(100) := 'starter_morphology_123';
    v_parent1_id            number;
    v_parent2_id            number;
    v_offspring_id          number;
    v_mutagen_child_id      number;
    v_task_id               number;
    v_task_result           number;
    v_summary               varchar2(1000);
    v_before_signature      varchar2(4000);
    v_after_signature       varchar2(4000);
    v_cursor                sys_refcursor;
    v_cursor_open           boolean := false;
    v_option_no             number;
    v_species_type          number;
    v_species_label         varchar2(4000);
    v_probability           number;
    v_phenotype_summary     varchar2(4000);
    v_genotype_summary      varchar2(4000);
    v_source_note           varchar2(4000);
    v_preview_rows          number := 0;
    v_preview_morph_rows    number := 0;
    v_preview_probability_rows number := 0;
    v_creatures_before      number;
    v_genotypes_before      number;
    v_experiments_before    number;
    v_failure_archetype_id  number;
    v_failure_gene_id       number;
    v_failure_allele1_id    number;
    v_failure_allele2_id    number;
    v_failure_error_code    number;
    v_failure_position      number;
    v_failure_archetype_count number;
    v_template_removed      boolean := false;
    v_unused_creature_id    number;

    procedure pass_test(p_test_name in varchar2, p_detail in varchar2 default null) is
    begin
        v_passed_tests := v_passed_tests + 1;
        dbms_output.put_line('[PASS] ' || p_test_name || case when p_detail is null then '' else ' -> ' || p_detail end);
    end pass_test;

    procedure fail_test(p_test_name in varchar2, p_detail in varchar2 default null) is
    begin
        v_failed_tests := v_failed_tests + 1;
        dbms_output.put_line('[FAIL] ' || p_test_name || case when p_detail is null then '' else ' -> ' || p_detail end);
    end fail_test;

    procedure assert_true(p_condition in boolean, p_test_name in varchar2, p_detail in varchar2 default null) is
    begin
        if p_condition then
            pass_test(p_test_name, p_detail);
        else
            fail_test(p_test_name, p_detail);
        end if;
    end assert_true;

    function morphology_signature(p_creature_id in number) return varchar2 is
        v_signature varchar2(4000);
    begin
        select listagg(g.gene_name || '=' || gt.allele1_id || '/' || gt.allele2_id, '; ')
                   within group (order by g.gene_name)
          into v_signature
          from genotypes gt
          join genes g
            on g.gene_id = gt.gene_id
         where gt.creature_id = p_creature_id
           and g.gameplay_enabled = 'N';
        return v_signature;
    end morphology_signature;

    procedure close_cursor is
    begin
        if v_cursor_open then
            close v_cursor;
            v_cursor_open := false;
        end if;
    end close_cursor;

    procedure restore_failure_template is
    begin
        if v_template_removed then
            merge into ref_archetype_alleles target
            using (
                select v_failure_archetype_id as archetype_id,
                       v_failure_gene_id as gene_id,
                       v_failure_allele1_id as allele1_id,
                       v_failure_allele2_id as allele2_id
                  from dual
            ) source
               on (target.archetype_id = source.archetype_id and target.gene_id = source.gene_id)
            when not matched then
                insert (archetype_id, gene_id, allele1_id, allele2_id)
                values (source.archetype_id, source.gene_id, source.allele1_id, source.allele2_id);
            v_template_removed := false;
        end if;
    end restore_failure_template;

    procedure cleanup_test_data is
    begin
        close_cursor;
        restore_failure_template;

        if v_session_token is not null and v_lab_id is not null then
            begin
                pkg_genetics_game.delete_lab(v_session_token, v_lab_id);
            exception
                when others then
                    dbms_output.put_line('[WARN] cleanup lab: ' || sqlcode || ' / ' || sqlerrm);
            end;
        end if;

        begin
            delete from sessions
             where user_id = v_user_id
                or user_id in (select user_id from users where login = v_login);
            delete from users
             where user_id = v_user_id
                or login = v_login;
        exception
            when others then
                dbms_output.put_line('[WARN] cleanup user: ' || sqlcode || ' / ' || sqlerrm);
        end;
    end cleanup_test_data;
begin
    dbms_output.put_line('--- STARTER MORPHOLOGY MATERIALIZATION SMOKE TEST ---');

    pkg_genetics_game.register_user('Starter morphology smoke', v_login, v_password, v_user_id);
    v_session_token := pkg_genetics_game.login_user(v_login, v_password);
    pkg_genetics_game.start_new_lab(v_session_token, v_lab_id);

    select count(*) into v_value from creatures where lab_id = v_lab_id;
    assert_true(v_value = 30, 'New laboratory creates 30 starters', 'actual=' || v_value);

    select count(*) into v_value from creatures where lab_id = v_lab_id and archetype_id is not null;
    assert_true(v_value = 30, 'Every starter has an archetype', 'actual=' || v_value);

    select count(*)
      into v_value
      from genotypes gt
      join creatures c on c.creature_id = gt.creature_id
      join genes g on g.gene_id = gt.gene_id
     where c.lab_id = v_lab_id
       and g.gameplay_enabled = 'N';
    assert_true(v_value = 540, 'All starters materialize 540 morphology rows', 'actual=' || v_value);

    select count(*)
      into v_value
      from (
            select c.creature_id
              from creatures c
              join genotypes gt on gt.creature_id = c.creature_id
              join genes g on g.gene_id = gt.gene_id
             where c.lab_id = v_lab_id
               and g.gameplay_enabled = 'N'
             group by c.creature_id
            having count(*) <> 18
      );
    assert_true(v_value = 0, 'Each starter has exactly 18 morphology rows', 'mismatches=' || v_value);

    select count(*)
      into v_value
      from (
            select c.creature_id, taa.gene_id, taa.allele1_id, taa.allele2_id
              from creatures c
              join ref_archetype_alleles taa on taa.archetype_id = c.archetype_id
             where c.lab_id = v_lab_id
            minus
            select c.creature_id, gt.gene_id, gt.allele1_id, gt.allele2_id
              from creatures c
              join genotypes gt on gt.creature_id = c.creature_id
              join genes g on g.gene_id = gt.gene_id
             where c.lab_id = v_lab_id
               and g.gameplay_enabled = 'N'
      );
    assert_true(v_value = 0, 'Morphology rows match every archetype template', 'missing_or_changed=' || v_value);

    select count(*)
      into v_value
      from (
            select c.creature_id, gt.gene_id, gt.allele1_id, gt.allele2_id
              from creatures c
              join genotypes gt on gt.creature_id = c.creature_id
              join genes g on g.gene_id = gt.gene_id
             where c.lab_id = v_lab_id
               and g.gameplay_enabled = 'N'
            minus
            select c.creature_id, taa.gene_id, taa.allele1_id, taa.allele2_id
              from creatures c
              join ref_archetype_alleles taa on taa.archetype_id = c.archetype_id
             where c.lab_id = v_lab_id
      );
    assert_true(v_value = 0, 'No extra morphology rows are materialized', 'extra_or_changed=' || v_value);

    select count(*)
      into v_value
      from (
            select c.creature_id
              from creatures c
             where c.lab_id = v_lab_id
               and (
                    select count(*)
                      from genotypes gt
                      join genes g on g.gene_id = gt.gene_id
                     where gt.creature_id = c.creature_id
                       and g.gameplay_enabled = 'Y'
               ) <> (
                    select count(*)
                      from genes g
                     where g.species_type in (0, c.species_type)
                       and g.gameplay_enabled = 'Y'
               )
      );
    assert_true(v_value = 0, 'Starter legacy gameplay rows remain complete', 'mismatches=' || v_value);

    select count(*)
      into v_value
      from (
            select gt.creature_id, gt.gene_id
              from genotypes gt
              join creatures c on c.creature_id = gt.creature_id
             where c.lab_id = v_lab_id
             group by gt.creature_id, gt.gene_id
            having count(*) > 1
      );
    assert_true(v_value = 0, 'Materialization creates no duplicate genotype genes', 'duplicates=' || v_value);

    select min(creature_id), max(creature_id)
      into v_parent1_id, v_parent2_id
      from creatures
     where lab_id = v_lab_id
       and species_type = 1;

    v_summary := pkg_genetics_game.get_phenotype(v_parent1_id);
    assert_true(instr(v_summary, 'body_shape=') = 0, 'Phenotype ignores disabled morphology rows');

    select min(task_id) into v_task_id from lab_tasks where lab_id = v_lab_id and task_status = 'ACTIVE';
    v_task_result := pkg_genetics_game.check_task(v_lab_id, v_task_id, v_parent1_id);
    assert_true(v_task_result in (0, 1), 'Task check remains defined for a dual-schema starter', 'result=' || v_task_result);

    select count(*)
      into v_value
      from task_markers tm
      join tasks t on t.task_id = tm.task_id
      join alleles a on a.allele_id = tm.allele_id
      join genes g on g.gene_id = a.gene_id
     where substr(t.task_name, 1, 8) <> 'task_v3_'
       and g.gameplay_enabled = 'N';
    assert_true(v_value = 0, 'Historical task markers exclude disabled morphology genes', 'actual=' || v_value);

    select count(*) into v_creatures_before from creatures where lab_id = v_lab_id;
    select count(*) into v_experiments_before from experiments where lab_id = v_lab_id;
    v_cursor := pkg_genetics_game.preview_offspring_options(v_session_token, v_lab_id, v_parent1_id, v_parent2_id, 3);
    v_cursor_open := true;
    loop
        fetch v_cursor into v_option_no, v_species_type, v_species_label, v_probability,
                            v_phenotype_summary, v_genotype_summary, v_source_note;
        exit when v_cursor%notfound;
        v_preview_rows := v_preview_rows + 1;
        if instr(v_genotype_summary, 'body_shape:') > 0 then
            v_preview_morph_rows := v_preview_morph_rows + 1;
        end if;
        if v_probability is not null then
            v_preview_probability_rows := v_preview_probability_rows + 1;
        end if;
    end loop;
    close_cursor;
    assert_true(v_preview_rows = 3, 'Dual parents preview returns three examples', 'actual=' || v_preview_rows);
    assert_true(v_preview_morph_rows = v_preview_rows, 'Dual parents preview includes morphology rows', 'actual=' || v_preview_morph_rows);
    assert_true(v_preview_probability_rows = 0, 'Preview probability remains NULL for full offspring examples', 'non_null=' || v_preview_probability_rows);
    select count(*) into v_value from creatures where lab_id = v_lab_id;
    assert_true(v_value = v_creatures_before, 'Preview creates no creatures');
    select count(*) into v_value from experiments where lab_id = v_lab_id;
    assert_true(v_value = v_experiments_before, 'Preview creates no experiments');

    pkg_genetics_game.crossbreed(v_lab_id, v_parent1_id, v_parent2_id, 'dual_starter_offspring', v_offspring_id);
    select count(*)
      into v_value
      from genotypes gt join genes g on g.gene_id = gt.gene_id
     where gt.creature_id = v_offspring_id and g.gameplay_enabled = 'N';
    assert_true(v_value = 18, 'Dual-starter crossbreed inherits 18 morphology rows', 'actual=' || v_value);
    select count(*) into v_value from creatures where creature_id = v_offspring_id and archetype_id is null;
    assert_true(v_value = 1, 'Crossbred creature has no single archetype');
    v_summary := pkg_genetics_game.get_phenotype(v_offspring_id);
    assert_true(instr(v_summary, 'body_shape=') = 0, 'Crossbred phenotype remains legacy-compatible');

    select count(*)
      into v_value
      from mutation_rules mr join genes g on g.gene_id = mr.gene_id
     where g.gameplay_enabled = 'N';
    assert_true(v_value = 0, 'Mutation rules exclude disabled morphology genes', 'actual=' || v_value);
    v_before_signature := morphology_signature(v_parent1_id);
    pkg_genetics_game.apply_mutagen(v_parent1_id, 'CHEMICAL', v_mutagen_child_id);
    v_after_signature := morphology_signature(v_mutagen_child_id);
    assert_true(v_before_signature <> v_after_signature, 'V3 chemical mutagen changes canonical morphology rows');

    select count(*) into v_creatures_before from creatures where lab_id = v_lab_id;
    select count(*) into v_genotypes_before from genotypes gt join creatures c on c.creature_id = gt.creature_id where c.lab_id = v_lab_id;

    select count(*)
      into v_failure_archetype_count
      from ref_creature_archetypes r
     where r.species_type = 1
       and r.active_flag = 'Y';

    select mod(count(*), v_failure_archetype_count) + 1
      into v_failure_position
      from creatures c
     where c.lab_id = v_lab_id
       and c.species_type = 1
       and c.archetype_id is not null;

    select archetype_id
      into v_failure_archetype_id
      from (
            select r.archetype_id, row_number() over (order by r.archetype_code) as archetype_position
              from ref_creature_archetypes r
             where r.species_type = 1
               and r.active_flag = 'Y'
      )
     where archetype_position = v_failure_position;

    select gene_id, allele1_id, allele2_id
      into v_failure_gene_id, v_failure_allele1_id, v_failure_allele2_id
      from (
            select taa.gene_id, taa.allele1_id, taa.allele2_id
              from ref_archetype_alleles taa
             where taa.archetype_id = v_failure_archetype_id
             order by taa.gene_id
      )
     where rownum = 1;

    delete from ref_archetype_alleles
     where archetype_id = v_failure_archetype_id
       and gene_id = v_failure_gene_id;
    v_template_removed := true;

    begin
        pkg_genetics_game.create_creature_of_type(v_lab_id, 1, 99, v_unused_creature_id);
        fail_test('Incomplete morphology template rejects creature creation', 'no error was raised');
    exception
        when others then
            v_failure_error_code := sqlcode;
    end;
    restore_failure_template;
    assert_true(v_failure_error_code = -20082, 'Incomplete morphology template rejects creature creation', 'sqlcode=' || v_failure_error_code);
    select count(*) into v_value from creatures where lab_id = v_lab_id;
    assert_true(v_value = v_creatures_before, 'Failed materialization leaves no partial creature', 'actual=' || v_value);
    select count(*) into v_value from genotypes gt join creatures c on c.creature_id = gt.creature_id where c.lab_id = v_lab_id;
    assert_true(v_value = v_genotypes_before, 'Failed materialization leaves no partial genotype rows', 'actual=' || v_value);

    select count(*) into v_value from ref_archetype_alleles;
    assert_true(v_value = 324, 'Reference templates are restored after atomicity check', 'actual=' || v_value);

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
        raise_application_error(-20991, 'Starter morphology materialization smoke test had ' || v_failed_tests || ' failure(s).');
    end if;
exception
    when others then
        cleanup_test_data;
        raise;
end;
/

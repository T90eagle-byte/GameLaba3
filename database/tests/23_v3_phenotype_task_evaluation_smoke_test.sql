-- Validates version-aware task evaluation without changing assignment runtime.
-- It creates isolated users and laboratories and removes every fixture row.

@@../packages/spec/pkg_genetics_game.pks
@@../migrations/04_add_creature_archetypes.sql
@@../migrations/05_add_universal_morphology.sql
@@../migrations/06_add_archetype_templates.sql
@@../migrations/07_add_creature_archetype.sql
@@../migrations/08_add_allele_display_names.sql
@@../migrations/09_add_lab_genetics_version.sql
@@../migrations/10_add_genetics_model_membership.sql
@@../migrations/11_add_task_genetics_version.sql
@@../packages/body/pkg_genetics_game.pkb

set serveroutput on size unlimited;
set verify off;

declare
    v_failed_tests       number := 0;
    v_passed_tests       number := 0;
    v_value              number;
    v_error_code         number;
    v_user1_id           number;
    v_user2_id           number;
    v_lab1_id            number;
    v_lab2_id            number;
    v_creature1_id       number;
    v_creature2_id       number;
    v_token1             varchar2(128);
    v_token2             varchar2(128);
    v_login1             varchar2(20) := 'p' || lower(substr(rawtohex(sys_guid()), 1, 19));
    v_login2             varchar2(20) := 'q' || lower(substr(rawtohex(sys_guid()), 1, 19));
    v_password           varchar2(100) := 'phenotype_tasks_123';
    v_v1_task_id         number;
    v_v3_task_id         number;
    v_mutation_id        number;
    v_fixture_mutation_id number;
    v_body_color_gene_id  number;
    v_red_allele_id       number;
    v_snout_gene_id      number;
    v_pointed_allele_id  number;
    v_lab_wallet_before  number;
    v_lab_wallet_after   number;
    v_rating_event_count number;
    v_baseline_labs      number;
    v_baseline_creatures number;
    v_baseline_genotypes number;
    v_baseline_lab_tasks number;

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

    function gene_id(p_gene_name in varchar2) return number is
        v_gene_id number;
    begin
        select gene_id
          into v_gene_id
          from genes
         where gene_name = p_gene_name
           and species_type = 0;
        return v_gene_id;
    end gene_id;

    function allele_id(p_gene_name in varchar2, p_allele_code in varchar2) return number is
        v_allele_id number;
    begin
        select a.allele_id
          into v_allele_id
          from alleles a
          join genes g on g.gene_id = a.gene_id
         where g.gene_name = p_gene_name
           and g.species_type = 0
           and a.description = p_allele_code;
        return v_allele_id;
    end allele_id;

    procedure set_genotype(
        p_gene_name    in varchar2,
        p_allele1_code in varchar2,
        p_allele2_code in varchar2
    ) is
        v_gene_id    number := gene_id(p_gene_name);
        v_allele1_id number := allele_id(p_gene_name, p_allele1_code);
        v_allele2_id number := allele_id(p_gene_name, p_allele2_code);
    begin
        update genotypes
           set allele1_id = v_allele1_id,
               allele2_id = v_allele2_id
         where creature_id = v_creature1_id
           and gene_id = v_gene_id;
        assert_true(sql%rowcount = 1, 'Controlled genotype row exists: ' || p_gene_name, 'rows=' || sql%rowcount);
    end set_genotype;

    procedure add_active_task(p_task_id in number) is
    begin
        insert into lab_tasks (lab_task_id, lab_id, task_id, task_status, assigned_at, completed_at)
        values (lab_tasks_seq.nextval, v_lab1_id, p_task_id, 'ACTIVE', systimestamp, null);
    end add_active_task;

    procedure cleanup is
    begin
        if v_lab1_id is not null then
            delete from rating_events where lab_id = v_lab1_id;
            delete from experiments where lab_id = v_lab1_id;
            delete from lab_mutations where lab_id = v_lab1_id;
            delete from lab_tasks where lab_id = v_lab1_id;
            delete from genotypes where creature_id in (select creature_id from creatures where lab_id = v_lab1_id);
            delete from creatures where lab_id = v_lab1_id;
            delete from labs where lab_id = v_lab1_id;
        end if;
        if v_lab2_id is not null then
            delete from rating_events where lab_id = v_lab2_id;
            delete from experiments where lab_id = v_lab2_id;
            delete from lab_mutations where lab_id = v_lab2_id;
            delete from lab_tasks where lab_id = v_lab2_id;
            delete from genotypes where creature_id in (select creature_id from creatures where lab_id = v_lab2_id);
            delete from creatures where lab_id = v_lab2_id;
            delete from labs where lab_id = v_lab2_id;
        end if;
        if v_fixture_mutation_id is not null then
            delete from mutation_rules where mutation_id = v_fixture_mutation_id;
            delete from mutations where mutation_id = v_fixture_mutation_id;
        end if;
        if v_user1_id is not null then
            delete from sessions where user_id = v_user1_id;
            delete from users where user_id = v_user1_id;
        end if;
        if v_user2_id is not null then
            delete from sessions where user_id = v_user2_id;
            delete from users where user_id = v_user2_id;
        end if;
        commit;
    end cleanup;

begin
    select count(*) into v_baseline_labs from labs;
    select count(*) into v_baseline_creatures from creatures;
    select count(*) into v_baseline_genotypes from genotypes;
    select count(*) into v_baseline_lab_tasks from lab_tasks;

    select task_id into v_v1_task_id from tasks where task_name = 'task_winged_specimen' and genetics_version = 1;
    select task_id into v_v3_task_id from tasks where task_name = 'task_v3_long_tailed_pointed' and genetics_version = 3;
    v_body_color_gene_id := gene_id('body_color');
    v_red_allele_id := allele_id('body_color', 'red');
    select mutations_seq.nextval into v_fixture_mutation_id from dual;
    insert into mutations (mutation_id, mutation_name, mutation_type, description, cost, rating_effect, created_at)
    values (v_fixture_mutation_id, 'task23_v3_color_fixture', null, 'Тестовая мутация цвета тела.', 0, 0, systimestamp);
    insert into mutation_rules (mutation_rule_id, mutation_id, gene_id, target_allele_id, target_slot, created_at)
    values (mutation_rules_seq.nextval, v_fixture_mutation_id, v_body_color_gene_id, v_red_allele_id, '1', systimestamp);
    v_mutation_id := v_fixture_mutation_id;
    v_snout_gene_id := gene_id('snout_type');
    v_pointed_allele_id := allele_id('snout_type', 'pointed');

    pkg_genetics_game.register_user('Phenotype task v3 owner', v_login1, v_password, v_user1_id);
    v_token1 := pkg_genetics_game.login_user(v_login1, v_password);
    pkg_genetics_game.start_new_lab(v_token1, v_lab1_id);
    select min(creature_id) into v_creature1_id from creatures where lab_id = v_lab1_id;
    delete from lab_tasks where lab_id = v_lab1_id;

    select genetics_version into v_value from labs where lab_id = v_lab1_id;
    assert_true(v_value = 3, 'Fixture laboratory uses genetics_version=3', 'actual=' || v_value);

    -- The v1 marker is physically present but hidden by no_wings dominance.
    set_genotype('has_wings', 'wings', 'no_wings');
    assert_true(pkg_genetics_game.get_dominant_allele(v_creature1_id, gene_id('has_wings')) = 'no_wings', 'V1 control marker is not expressed');
    add_active_task(v_v1_task_id);
    assert_true(pkg_genetics_game.check_task(v_lab1_id, v_v1_task_id, v_creature1_id) = 1, 'V3 lab plus v1 task keeps allele-presence semantics');

    select wallet into v_lab_wallet_before from labs where lab_id = v_lab1_id;
    pkg_genetics_game.complete_task(v_lab1_id, v_v1_task_id, v_creature1_id, v_value, v_lab_wallet_after, v_rating_event_count);
    assert_true(v_value = 1 and v_lab_wallet_after = v_lab_wallet_before + 120, 'V1 reward flow remains unchanged');

    begin
        pkg_genetics_game.complete_task(v_lab1_id, v_v1_task_id, v_creature1_id, v_value, v_lab_wallet_after, v_rating_event_count);
        fail_test('Completed v1 task cannot pay twice', 'completion unexpectedly succeeded');
    exception
        when others then
            v_error_code := sqlcode;
            assert_true(v_error_code = -20064, 'Completed v1 task cannot pay twice', 'actual=' || v_error_code);
    end;

    -- complete_task refills active legacy tasks; isolate the v3 evaluator fixture.
    delete from lab_tasks where lab_id = v_lab1_id;

    -- Multi-marker v3 task: tail marker is present but hidden; size and snout are expressed.
    set_genotype('tail_type', 'elongated', 'fish');
    set_genotype('body_size', 'large', 'large');
    set_genotype('snout_type', 'pointed', 'pointed');
    assert_true(pkg_genetics_game.get_dominant_allele(v_creature1_id, gene_id('tail_type')) = 'fish', 'V3 hidden tail marker is not expressed');
    add_active_task(v_v3_task_id);
    assert_true(pkg_genetics_game.check_task(v_lab1_id, v_v3_task_id, v_creature1_id) = 0, 'V3 hidden-but-present marker does not satisfy task');

    delete from genotypes where creature_id = v_creature1_id and gene_id = v_snout_gene_id;
    assert_true(pkg_genetics_game.check_task(v_lab1_id, v_v3_task_id, v_creature1_id) = 0, 'V3 missing required gene returns not matched');
    insert into genotypes (genotype_id, creature_id, gene_id, allele1_id, allele2_id)
    values (genotypes_seq.nextval, v_creature1_id, v_snout_gene_id, v_pointed_allele_id, v_pointed_allele_id);

    set_genotype('tail_type', 'elongated', 'elongated');
    assert_true(pkg_genetics_game.check_task(v_lab1_id, v_v3_task_id, v_creature1_id) = 1, 'V3 multi-marker task matches only when every marker is expressed');

    -- Return to the hidden state and use a normal mutation path to prove auto-complete shares the evaluator.
    set_genotype('tail_type', 'elongated', 'fish');
    set_genotype('body_color', 'blue', 'blue');
    assert_true(pkg_genetics_game.buy_mutation(v_lab1_id, v_mutation_id) = 1, 'Buy mutation for hidden-marker auto-complete check');
    pkg_genetics_game.apply_mutation(v_creature1_id, v_mutation_id);
    select count(*) into v_value from lab_tasks where lab_id = v_lab1_id and task_id = v_v3_task_id and task_status = 'ACTIVE';
    assert_true(v_value = 1, 'Hidden v3 marker does not auto-complete task', 'active=' || v_value);

    set_genotype('tail_type', 'elongated', 'elongated');
    set_genotype('body_color', 'blue', 'blue');
    assert_true(pkg_genetics_game.buy_mutation(v_lab1_id, v_mutation_id) = 1, 'Buy mutation for matching auto-complete check');
    select wallet into v_lab_wallet_before from labs where lab_id = v_lab1_id;
    pkg_genetics_game.apply_mutation(v_creature1_id, v_mutation_id);
    select wallet into v_lab_wallet_after from labs where lab_id = v_lab1_id;
    select count(*) into v_value from lab_tasks where lab_id = v_lab1_id and task_id = v_v3_task_id and task_status = 'COMPLETED';
    assert_true(v_value = 1, 'Matching v3 phenotype auto-completes task', 'completed=' || v_value);
    assert_true(v_lab_wallet_after = v_lab_wallet_before + 2000, 'V3 auto-complete pays reward once');

    select count(*) into v_rating_event_count from rating_events where lab_id = v_lab1_id and task_id = v_v3_task_id and event_type = 'TASK_REWARD';
    assert_true(v_rating_event_count = 1, 'V3 task reward history has one entry', 'actual=' || v_rating_event_count);

    begin
        pkg_genetics_game.complete_task(v_lab1_id, v_v3_task_id, v_creature1_id, v_value, v_lab_wallet_after, v_rating_event_count);
        fail_test('Completed v3 task cannot pay twice', 'completion unexpectedly succeeded');
    exception
        when others then
            v_error_code := sqlcode;
            assert_true(v_error_code = -20064, 'Completed v3 task cannot pay twice', 'actual=' || v_error_code);
    end;

    delete from lab_tasks where lab_id = v_lab1_id and task_id <> v_v3_task_id;
    set_genotype('body_color', 'blue', 'blue');
    assert_true(pkg_genetics_game.buy_mutation(v_lab1_id, v_mutation_id) = 1, 'Buy mutation after completed v3 task');
    select wallet into v_lab_wallet_before from labs where lab_id = v_lab1_id;
    pkg_genetics_game.apply_mutation(v_creature1_id, v_mutation_id);
    select wallet into v_lab_wallet_after from labs where lab_id = v_lab1_id;
    select count(*) into v_value from rating_events where lab_id = v_lab1_id and task_id = v_v3_task_id and event_type = 'TASK_REWARD';
    assert_true(v_value = 1 and v_lab_wallet_after = v_lab_wallet_before, 'Repeated auto-complete does not pay v3 reward twice');

    pkg_genetics_game.register_user('Phenotype task foreign user', v_login2, v_password, v_user2_id);
    v_token2 := pkg_genetics_game.login_user(v_login2, v_password);
    pkg_genetics_game.start_new_lab(v_token2, v_lab2_id);
    select min(creature_id) into v_creature2_id from creatures where lab_id = v_lab2_id;
    pkg_genetics_game.load_lab(v_token1, v_lab1_id);
    begin
        v_value := pkg_genetics_game.check_task(v_lab1_id, v_v3_task_id, v_creature2_id);
        fail_test('Foreign creature cannot check v3 task', 'check unexpectedly returned ' || v_value);
    exception
        when others then
            v_error_code := sqlcode;
            assert_true(v_error_code = -20069, 'Foreign creature cannot check v3 task', 'actual=' || v_error_code);
    end;

    select count(*)
      into v_value
      from task_markers tm
      join tasks t on t.task_id = tm.task_id
      join alleles a on a.allele_id = tm.allele_id
      left join ref_genetics_model_genes membership on membership.genetics_version = 3 and membership.gene_id = a.gene_id
     where t.genetics_version = 3
       and membership.gene_id is null;
    assert_true(v_value = 0, 'All v3 marker genes belong to v3 membership', 'actual=' || v_value);

    select count(*)
      into v_value
      from task_markers tm
      join tasks t on t.task_id = tm.task_id
      join alleles a on a.allele_id = tm.allele_id
      join genes g on g.gene_id = a.gene_id
     where t.genetics_version = 3
       and g.dominance_type <> 'FULL';
    assert_true(v_value = 0, 'All v3 marker genes use FULL dominance', 'actual=' || v_value);

    cleanup;
    select count(*) into v_value from labs;
    assert_true(v_value = v_baseline_labs, 'Cleanup restores LABS baseline', 'actual=' || v_value);
    select count(*) into v_value from creatures;
    assert_true(v_value = v_baseline_creatures, 'Cleanup restores CREATURES baseline', 'actual=' || v_value);
    select count(*) into v_value from genotypes;
    assert_true(v_value = v_baseline_genotypes, 'Cleanup restores GENOTYPES baseline', 'actual=' || v_value);
    select count(*) into v_value from lab_tasks;
    assert_true(v_value = v_baseline_lab_tasks, 'Cleanup restores LAB_TASKS baseline', 'actual=' || v_value);

    dbms_output.put_line('--- SUMMARY ---');
    dbms_output.put_line('Passed: ' || v_passed_tests);
    dbms_output.put_line('Failed: ' || v_failed_tests);
    if v_failed_tests > 0 then
        raise_application_error(-20000, 'V3 phenotype task evaluation smoke test failed.');
    end if;
exception
    when others then
        cleanup;
        raise;
end;
/

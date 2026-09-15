-- Unified experiment runtime smoke test.
-- Fixtures are isolated and removed before completion.

set serveroutput on size unlimited;
set verify off;

declare
    v_failed_tests              number := 0;
    v_passed_tests              number := 0;
    v_value                     number;
    v_error_code                number;
    v_user_v3_id                number;
    v_user_v1_id                number;
    v_lab_v3_id                 number;
    v_lab_v1_id                 number;
    v_token_v3                  varchar2(128);
    v_token_v1                  varchar2(128);
    v_login_v3                  varchar2(20) := 'u' || lower(substr(rawtohex(sys_guid()), 1, 19));
    v_login_v1                  varchar2(20) := 'v' || lower(substr(rawtohex(sys_guid()), 1, 19));
    v_password                  varchar2(100) := 'unified_experiment_123';
    v_species_type              number;
    v_parent1_id                number;
    v_parent2_id                number;
    v_other_species_id          number;
    v_cross_child_id            number;
    v_mutagen_child_id          number;
    v_combined_child_id         number;
    v_trial_child_id            number;
    v_v1_parent1_id             number;
    v_v1_parent2_id             number;
    v_v1_child_id               number;
    v_mutation_id               number;
    v_body_cover_gene_id        number;
    v_smooth_skin_allele_id     number;
    v_hard_shell_allele_id      number;
    v_body_color_gene_id        number;
    v_white_allele_id           number;
    v_final_color_allele_id     number;
    v_final_color_code          varchar2(100);
    v_task_before_id            number;
    v_task_after_id             number;
    v_wallet_before             number;
    v_wallet_after              number;
    v_before_creatures          number;
    v_before_genotypes          number;
    v_before_experiments        number;
    v_before_lab_tasks          number;
    v_before_rating_events      number;
    v_baseline_labs             number;
    v_baseline_creatures        number;
    v_baseline_genotypes        number;
    v_baseline_lab_tasks        number;
    v_baseline_tasks            number;
    v_baseline_experiments      number;
    v_baseline_lab_mutations    number;
    v_baseline_rating_events    number;

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

    procedure cleanup is
    begin
        if v_lab_v3_id is not null then
            delete from rating_events where lab_id = v_lab_v3_id;
            delete from experiments where lab_id = v_lab_v3_id;
            delete from lab_mutations where lab_id = v_lab_v3_id;
            delete from lab_tasks where lab_id = v_lab_v3_id;
            delete from genotypes where creature_id in (select creature_id from creatures where lab_id = v_lab_v3_id);
            delete from creatures where lab_id = v_lab_v3_id;
            delete from labs where lab_id = v_lab_v3_id;
        end if;

        if v_lab_v1_id is not null then
            delete from rating_events where lab_id = v_lab_v1_id;
            delete from experiments where lab_id = v_lab_v1_id;
            delete from lab_mutations where lab_id = v_lab_v1_id;
            delete from lab_tasks where lab_id = v_lab_v1_id;
            delete from genotypes where creature_id in (select creature_id from creatures where lab_id = v_lab_v1_id);
            delete from creatures where lab_id = v_lab_v1_id;
            delete from labs where lab_id = v_lab_v1_id;
        end if;

        if v_task_before_id is not null then
            delete from task_markers where task_id = v_task_before_id;
            delete from tasks where task_id = v_task_before_id;
        end if;
        if v_task_after_id is not null then
            delete from task_markers where task_id = v_task_after_id;
            delete from tasks where task_id = v_task_after_id;
        end if;
        if v_mutation_id is not null then
            delete from mutation_rules where mutation_id = v_mutation_id;
            delete from mutations where mutation_id = v_mutation_id;
        end if;
        if v_user_v3_id is not null then
            delete from sessions where user_id = v_user_v3_id;
            delete from users where user_id = v_user_v3_id;
        end if;
        if v_user_v1_id is not null then
            delete from sessions where user_id = v_user_v1_id;
            delete from users where user_id = v_user_v1_id;
        end if;
        commit;
    end cleanup;

    procedure snapshot_lab_counts is
    begin
        select count(*) into v_before_creatures from creatures where lab_id = v_lab_v3_id;
        select count(*)
          into v_before_genotypes
          from genotypes
         where creature_id in (select creature_id from creatures where lab_id = v_lab_v3_id);
        select count(*) into v_before_experiments from experiments where lab_id = v_lab_v3_id;
        select count(*) into v_before_lab_tasks from lab_tasks where lab_id = v_lab_v3_id;
        select count(*) into v_before_rating_events from rating_events where lab_id = v_lab_v3_id;
    end snapshot_lab_counts;

begin
    select count(*) into v_baseline_labs from labs;
    select count(*) into v_baseline_creatures from creatures;
    select count(*) into v_baseline_genotypes from genotypes;
    select count(*) into v_baseline_lab_tasks from lab_tasks;
    select count(*) into v_baseline_tasks from tasks;
    select count(*) into v_baseline_experiments from experiments;
    select count(*) into v_baseline_lab_mutations from lab_mutations;
    select count(*) into v_baseline_rating_events from rating_events;

    select g.gene_id into v_body_cover_gene_id
      from genes g where g.gene_name = 'body_cover' and g.species_type = 0;
    select a.allele_id into v_smooth_skin_allele_id
      from alleles a where a.gene_id = v_body_cover_gene_id and a.description = 'smooth_skin';
    select a.allele_id into v_hard_shell_allele_id
      from alleles a where a.gene_id = v_body_cover_gene_id and a.description = 'hard_shell';
    select g.gene_id into v_body_color_gene_id
      from genes g where g.gene_name = 'body_color' and g.species_type = 0;
    select a.allele_id into v_white_allele_id
      from alleles a where a.gene_id = v_body_color_gene_id and a.description = 'white';

    pkg_genetics_game.register_user('Unified experiment v3', v_login_v3, v_password, v_user_v3_id);
    v_token_v3 := pkg_genetics_game.login_user(v_login_v3, v_password);
    pkg_genetics_game.start_new_lab(v_token_v3, v_lab_v3_id);
    update labs set wallet = 50000, rating = 100 where lab_id = v_lab_v3_id;
    delete from lab_tasks where lab_id = v_lab_v3_id;

    select min(species_type)
      into v_species_type
      from (
            select species_type
              from creatures
             where lab_id = v_lab_v3_id
             group by species_type
            having count(*) >= 2
           );
    select min(creature_id), max(creature_id)
      into v_parent1_id, v_parent2_id
      from creatures
     where lab_id = v_lab_v3_id
       and species_type = v_species_type;
    select min(creature_id)
      into v_other_species_id
      from creatures
     where lab_id = v_lab_v3_id
       and species_type <> v_species_type;

    -- Standalone public operations keep their established orchestration.
    insert into mutations (mutation_id, mutation_name, mutation_type, description, cost, rating_effect, created_at)
    values (mutations_seq.nextval, 'task20_cover_' || lower(substr(rawtohex(sys_guid()), 1, 12)), null, 'Task 20 fixture.', 0, 0, systimestamp)
    returning mutation_id into v_mutation_id;
    insert into mutation_rules (mutation_rule_id, mutation_id, gene_id, target_allele_id, target_slot, created_at)
    values (mutation_rules_seq.nextval, v_mutation_id, v_body_cover_gene_id, v_hard_shell_allele_id, '1', systimestamp);
    update genotypes
       set allele1_id = v_smooth_skin_allele_id,
           allele2_id = v_smooth_skin_allele_id
     where creature_id = v_parent1_id
       and gene_id = v_body_cover_gene_id;

    select count(*) into v_before_experiments from experiments where lab_id = v_lab_v3_id;
    pkg_genetics_game.crossbreed(v_lab_v3_id, v_parent1_id, v_parent2_id, 'Task 20 cross', v_cross_child_id);
    select count(*) into v_value from experiments where lab_id = v_lab_v3_id and experiment_type = 'CROSS' and offspring_id = v_cross_child_id;
    assert_true(v_value = 1, 'Standalone CROSS keeps one CROSS history row');
    select count(*) into v_value from experiments where lab_id = v_lab_v3_id;
    assert_true(v_value = v_before_experiments + 1, 'Standalone CROSS history delta is one');

    assert_true(pkg_genetics_game.buy_mutation(v_lab_v3_id, v_mutation_id) = 1, 'Standalone mutation fixture is purchased');
    select count(*) into v_before_experiments from experiments where lab_id = v_lab_v3_id;
    pkg_genetics_game.apply_mutation(v_parent1_id, v_mutation_id);
    select count(*) into v_value from experiments where lab_id = v_lab_v3_id and experiment_type = 'MUTATION' and parent1_id = v_parent1_id and mutation_id = v_mutation_id;
    assert_true(v_value = 1, 'Standalone MUTATION keeps its history row');
    select count(*) into v_value from experiments where lab_id = v_lab_v3_id;
    assert_true(v_value = v_before_experiments + 1, 'Standalone MUTATION history delta is one');

    select count(*) into v_before_creatures from creatures where lab_id = v_lab_v3_id;
    select count(*) into v_before_experiments from experiments where lab_id = v_lab_v3_id;
    pkg_genetics_game.apply_mutagen(v_parent1_id, 'CHEMICAL', v_mutagen_child_id);
    select count(*) into v_value from creatures where lab_id = v_lab_v3_id;
    assert_true(v_value = v_before_creatures + 1 and v_mutagen_child_id <> v_parent1_id, 'Standalone MUTAGEN still clones source creature');
    select count(*) into v_value from experiments where lab_id = v_lab_v3_id and experiment_type = 'MUTAGEN' and offspring_id = v_mutagen_child_id and mutagen_type = 'CHEMICAL';
    assert_true(v_value = 1, 'Standalone MUTAGEN records its mutagen type');
    select count(*) into v_value from experiments where lab_id = v_lab_v3_id;
    assert_true(v_value = v_before_experiments + 1, 'Standalone MUTAGEN history delta is one');

    -- Combined operation mutates the crossbred creature itself and records one logical experiment.
    update genotypes
       set allele1_id = v_white_allele_id,
           allele2_id = v_white_allele_id
     where creature_id in (v_parent1_id, v_parent2_id)
       and gene_id = v_body_color_gene_id;
    delete from lab_tasks where lab_id = v_lab_v3_id;

    -- Predict the deterministic post-mutagen color inside a rollback-only trial.
    savepoint final_state_prediction;
    dbms_random.seed(202003);
    pkg_genetics_game.make_experiment(
        p_lab_id         => v_lab_v3_id,
        p_parent1_id     => v_parent1_id,
        p_parent2_id     => v_parent2_id,
        p_mutagen_type   => 'CHEMICAL',
        p_offspring_name => 'Task 20 prediction',
        p_offspring_id   => v_trial_child_id
    );
    v_final_color_code := pkg_genetics_game.get_dominant_allele(v_trial_child_id, v_body_color_gene_id);
    select a.allele_id
      into v_final_color_allele_id
      from alleles a
     where a.gene_id = v_body_color_gene_id
       and a.description = v_final_color_code;
    assert_true(v_final_color_code <> 'white', 'Controlled mutagen changes the intermediate white phenotype', v_final_color_code);
    rollback to final_state_prediction;

    select tasks_seq.nextval into v_task_before_id from dual;
    insert into tasks (task_id, task_name, description, rating_reward, money_reward, difficulty_code, genetics_version, created_at)
    values (v_task_before_id, 'task20_before_' || lower(substr(rawtohex(sys_guid()), 1, 12)), 'Matches only the intermediate color.', 11, 111, 'MEDIUM', 3, systimestamp);
    insert into task_markers (task_marker_id, task_id, allele_id)
    values (task_markers_seq.nextval, v_task_before_id, v_white_allele_id);
    insert into lab_tasks (lab_task_id, lab_id, task_id, task_status, assigned_at, completed_at)
    values (lab_tasks_seq.nextval, v_lab_v3_id, v_task_before_id, 'ACTIVE', systimestamp, null);

    select tasks_seq.nextval into v_task_after_id from dual;
    insert into tasks (task_id, task_name, description, rating_reward, money_reward, difficulty_code, genetics_version, created_at)
    values (v_task_after_id, 'task20_after_' || lower(substr(rawtohex(sys_guid()), 1, 12)), 'Matches only the final color.', 22, 222, 'MEDIUM', 3, systimestamp);
    insert into task_markers (task_marker_id, task_id, allele_id)
    values (task_markers_seq.nextval, v_task_after_id, v_final_color_allele_id);
    insert into lab_tasks (lab_task_id, lab_id, task_id, task_status, assigned_at, completed_at)
    values (lab_tasks_seq.nextval, v_lab_v3_id, v_task_after_id, 'ACTIVE', systimestamp, null);

    select wallet into v_wallet_before from labs where lab_id = v_lab_v3_id;
    select count(*) into v_before_creatures from creatures where lab_id = v_lab_v3_id;
    select count(*) into v_before_experiments from experiments where lab_id = v_lab_v3_id;
    dbms_random.seed(202003);
    pkg_genetics_game.make_experiment(
        p_lab_id         => v_lab_v3_id,
        p_parent1_id     => v_parent1_id,
        p_parent2_id     => v_parent2_id,
        p_mutagen_type   => 'CHEMICAL',
        p_offspring_name => 'Task 20 combined',
        p_offspring_id   => v_combined_child_id
    );

    select count(*) into v_value from creatures where lab_id = v_lab_v3_id;
    assert_true(v_value = v_before_creatures + 1, 'Combined flow creates no second clone', 'delta=' || (v_value - v_before_creatures));
    assert_true(pkg_genetics_game.get_dominant_allele(v_combined_child_id, v_body_color_gene_id) = v_final_color_code, 'Combined flow mutates the same offspring in place');
    select count(*) into v_value from experiments where lab_id = v_lab_v3_id;
    assert_true(v_value = v_before_experiments + 1, 'Combined flow creates exactly one experiment row');
    select count(*) into v_value
      from experiments
     where lab_id = v_lab_v3_id
       and experiment_type = 'CROSSBREED_MUTAGEN'
       and parent1_id = v_parent1_id
       and parent2_id = v_parent2_id
       and offspring_id = v_combined_child_id
       and mutagen_type = 'CHEMICAL'
       and mutation_id is null;
    assert_true(v_value = 1, 'Combined history stores parents, offspring, and mutagen');
    select count(*) into v_value
      from experiments
     where lab_id = v_lab_v3_id
       and offspring_id = v_combined_child_id
       and experiment_type in ('CROSS', 'MUTAGEN');
    assert_true(v_value = 0, 'Combined flow has no intermediate CROSS or MUTAGEN history');
    select count(*) into v_value
      from genotypes gt
      join ref_genetics_model_genes rmg
        on rmg.genetics_version = 3
       and rmg.gene_id = gt.gene_id
      join genes g
        on g.gene_id = gt.gene_id
     where gt.creature_id = v_combined_child_id
       and g.species_type = 0
       and g.gene_type = 'morphology';
    assert_true(v_value = 18, 'Combined V3 offspring keeps complete morphology', 'rows=' || v_value);
    select count(*) into v_value
      from genotypes child
      join genes g on g.gene_id = child.gene_id
      join genotypes parent1 on parent1.creature_id = v_parent1_id and parent1.gene_id = child.gene_id
      join genotypes parent2 on parent2.creature_id = v_parent2_id and parent2.gene_id = child.gene_id
     where child.creature_id = v_combined_child_id
       and g.gameplay_enabled = 'Y'
       and (
            child.allele1_id not in (parent1.allele1_id, parent1.allele2_id)
            or child.allele2_id not in (parent2.allele1_id, parent2.allele2_id)
       );
    assert_true(v_value = 0, 'Combined V3 mutagen leaves inherited legacy genes unchanged', 'violations=' || v_value);

    select count(*) into v_value from lab_tasks where lab_id = v_lab_v3_id and task_id = v_task_before_id and task_status = 'ACTIVE';
    assert_true(v_value = 1, 'Final-state task A: intermediate-only match receives no reward');
    select count(*) into v_value from rating_events where lab_id = v_lab_v3_id and task_id = v_task_before_id and event_type = 'TASK_REWARD';
    assert_true(v_value = 0, 'Final-state task A: no reward event is recorded');
    select count(*) into v_value from lab_tasks where lab_id = v_lab_v3_id and task_id = v_task_after_id and task_status = 'COMPLETED';
    assert_true(v_value = 1, 'Final-state task B: post-mutagen match completes once');
    select count(*) into v_value from rating_events where lab_id = v_lab_v3_id and task_id = v_task_after_id and event_type = 'TASK_REWARD';
    assert_true(v_value = 1, 'Final-state task B: exactly one reward event is recorded');
    select wallet into v_wallet_after from labs where lab_id = v_lab_v3_id;
    assert_true(v_wallet_after = v_wallet_before - 100 + 222, 'Combined wallet applies mutagen cost and final reward once');

    -- A failure after offspring creation rolls back every partial gameplay effect.
    delete from lab_tasks where lab_id = v_lab_v3_id;
    update labs set wallet = 0 where lab_id = v_lab_v3_id;
    snapshot_lab_counts;
    begin
        pkg_genetics_game.make_experiment(
            p_lab_id         => v_lab_v3_id,
            p_parent1_id     => v_parent1_id,
            p_parent2_id     => v_parent2_id,
            p_mutagen_type   => 'CHEMICAL',
            p_offspring_name => 'Task 20 rollback',
            p_offspring_id   => v_trial_child_id
        );
        fail_test('Combined failure after crossbreed is atomic', 'call unexpectedly succeeded');
    exception
        when others then
            v_error_code := sqlcode;
            assert_true(v_error_code = -20071, 'Combined failure after crossbreed is controlled', 'actual=' || v_error_code);
    end;
    select count(*) into v_value from creatures where lab_id = v_lab_v3_id;
    assert_true(v_value = v_before_creatures, 'Atomic rollback restores creature count');
    select count(*) into v_value from genotypes where creature_id in (select creature_id from creatures where lab_id = v_lab_v3_id);
    assert_true(v_value = v_before_genotypes, 'Atomic rollback restores genotype count');
    select count(*) into v_value from experiments where lab_id = v_lab_v3_id;
    assert_true(v_value = v_before_experiments, 'Atomic rollback restores experiment count');
    select count(*) into v_value from lab_tasks where lab_id = v_lab_v3_id;
    assert_true(v_value = v_before_lab_tasks, 'Atomic rollback leaves tasks unchanged');
    select count(*) into v_value from rating_events where lab_id = v_lab_v3_id;
    assert_true(v_value = v_before_rating_events, 'Atomic rollback leaves rewards and penalties unchanged');
    update labs set wallet = 50000 where lab_id = v_lab_v3_id;

    snapshot_lab_counts;
    begin
        pkg_genetics_game.make_experiment(
            p_lab_id         => v_lab_v3_id,
            p_parent1_id     => v_parent1_id,
            p_parent2_id     => v_other_species_id,
            p_mutagen_type   => 'RADIATION',
            p_offspring_name => 'Task 20 mixed species',
            p_offspring_id   => v_trial_child_id
        );
        fail_test('Cross-species combined experiment is rejected', 'call unexpectedly succeeded');
    exception
        when others then
            v_error_code := sqlcode;
            assert_true(v_error_code = -20036, 'Cross-species combined experiment is rejected', 'actual=' || v_error_code);
    end;
    select count(*) into v_value from creatures where lab_id = v_lab_v3_id;
    assert_true(v_value = v_before_creatures, 'Cross-species rejection leaves no offspring');
    select count(*) into v_value from experiments where lab_id = v_lab_v3_id;
    assert_true(v_value = v_before_experiments, 'Cross-species rejection leaves no history');

    -- Existing rows may keep NULL mutagen_type, while new combined constraints stay strict.
    savepoint constraint_compatibility;
    insert into experiments (experiment_id, lab_id, parent1_id, parent2_id, mutation_id, mutagen_type, offspring_id, experiment_type)
    values (experiments_seq.nextval, v_lab_v3_id, v_parent1_id, null, null, null, v_mutagen_child_id, 'MUTAGEN');
    assert_true(sql%rowcount = 1, 'Historical MUTAGEN rows may keep NULL mutagen_type');
    rollback to constraint_compatibility;

    begin
        insert into experiments (experiment_id, lab_id, parent1_id, parent2_id, mutation_id, mutagen_type, offspring_id, experiment_type)
        values (experiments_seq.nextval, v_lab_v3_id, v_parent1_id, v_parent2_id, null, 'UNKNOWN', v_combined_child_id, 'CROSSBREED_MUTAGEN');
        fail_test('Combined mutagen FK rejects unknown code', 'insert unexpectedly succeeded');
    exception
        when others then
            assert_true(sqlcode = -2291, 'Combined mutagen FK rejects unknown code', 'actual=' || sqlcode);
    end;
    begin
        insert into experiments (experiment_id, lab_id, parent1_id, parent2_id, mutation_id, mutagen_type, offspring_id, experiment_type)
        values (experiments_seq.nextval, v_lab_v3_id, v_parent1_id, v_parent2_id, v_mutation_id, null, v_parent1_id, 'MUTATION');
        fail_test('MUTATION still rejects parent2_id', 'insert unexpectedly succeeded');
    exception
        when others then
            assert_true(sqlcode = -2290, 'MUTATION still rejects parent2_id', 'actual=' || sqlcode);
    end;

    -- V1 uses the same combined orchestration with its established mutagen targets.
    pkg_genetics_game.register_user('Unified experiment v1', v_login_v1, v_password, v_user_v1_id);
    v_token_v1 := pkg_genetics_game.login_user(v_login_v1, v_password);
    pkg_genetics_game.start_new_lab(v_token_v1, v_lab_v1_id);
    update labs set genetics_version = 1, wallet = 50000 where lab_id = v_lab_v1_id;
    pkg_genetics_game.load_lab(v_token_v1, v_lab_v1_id);
    select min(species_type)
      into v_species_type
      from (
            select species_type
              from creatures
             where lab_id = v_lab_v1_id
             group by species_type
            having count(*) >= 2
           );
    select min(creature_id), max(creature_id)
      into v_v1_parent1_id, v_v1_parent2_id
      from creatures
     where lab_id = v_lab_v1_id
       and species_type = v_species_type;
    pkg_genetics_game.make_experiment(
        p_lab_id         => v_lab_v1_id,
        p_parent1_id     => v_v1_parent1_id,
        p_parent2_id     => v_v1_parent2_id,
        p_mutagen_type   => 'CHEMICAL',
        p_offspring_name => 'Task 20 legacy combined',
        p_offspring_id   => v_v1_child_id
    );
    select count(*) into v_value from experiments where lab_id = v_lab_v1_id and offspring_id = v_v1_child_id and experiment_type = 'CROSSBREED_MUTAGEN' and mutagen_type = 'CHEMICAL';
    assert_true(v_value = 1, 'V1 combined experiment remains supported');
    select count(*) into v_value
      from genotypes child
      join genes g on g.gene_id = child.gene_id
     where child.creature_id = v_v1_child_id
       and g.gameplay_enabled = 'Y';
    assert_true(v_value > 0, 'V1 combined offspring keeps legacy gameplay genes', 'rows=' || v_value);

    select count(*) into v_value from user_objects where object_name = 'PKG_GENETICS_GAME' and object_type in ('PACKAGE', 'PACKAGE BODY') and status = 'VALID';
    assert_true(v_value = 2, 'Package specification and body remain valid', 'actual=' || v_value);
    select count(*) into v_value from user_errors where name = 'PKG_GENETICS_GAME';
    assert_true(v_value = 0, 'Package user_errors remain clean', 'actual=' || v_value);

    cleanup;
    select count(*) into v_value from labs;
    assert_true(v_value = v_baseline_labs, 'Cleanup restores LABS baseline', 'actual=' || v_value);
    select count(*) into v_value from creatures;
    assert_true(v_value = v_baseline_creatures, 'Cleanup restores CREATURES baseline', 'actual=' || v_value);
    select count(*) into v_value from genotypes;
    assert_true(v_value = v_baseline_genotypes, 'Cleanup restores GENOTYPES baseline', 'actual=' || v_value);
    select count(*) into v_value from lab_tasks;
    assert_true(v_value = v_baseline_lab_tasks, 'Cleanup restores LAB_TASKS baseline', 'actual=' || v_value);
    select count(*) into v_value from tasks;
    assert_true(v_value = v_baseline_tasks, 'Cleanup restores TASKS baseline', 'actual=' || v_value);
    select count(*) into v_value from experiments;
    assert_true(v_value = v_baseline_experiments, 'Cleanup restores EXPERIMENTS baseline', 'actual=' || v_value);
    select count(*) into v_value from lab_mutations;
    assert_true(v_value = v_baseline_lab_mutations, 'Cleanup restores LAB_MUTATIONS baseline', 'actual=' || v_value);
    select count(*) into v_value from rating_events;
    assert_true(v_value = v_baseline_rating_events, 'Cleanup restores RATING_EVENTS baseline', 'actual=' || v_value);

    dbms_output.put_line('--- SUMMARY ---');
    dbms_output.put_line('Passed: ' || v_passed_tests);
    dbms_output.put_line('Failed: ' || v_failed_tests);
    if v_failed_tests > 0 then
        raise_application_error(-20999, 'Unified experiment runtime smoke test failed.');
    end if;
exception
    when others then
        cleanup;
        raise;
end;
/

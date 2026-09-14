-- Validates version-aware runtime assignment without changing existing data.
-- Private assignment helpers are exercised through their public callers:
-- start_new_lab for v3 and complete_task/refill for a controlled v1 fixture.

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
    v_user_id            number;
    v_v3_lab_id          number;
    v_v1_lab_id          number;
    v_transition_lab_id  number;
    v_v3_creature_id     number;
    v_v1_creature_id     number;
    v_transition_creature_id number;
    v_token              varchar2(128);
    v_login              varchar2(20) := 'a' || lower(substr(rawtohex(sys_guid()), 1, 19));
    v_password           varchar2(100) := 'assignment_v3_123';
    v_v1_task_id         number;
    v_v3_task_id         number;
    v_wallet             number;
    v_rating             number;
    v_baseline_labs      number;
    v_baseline_creatures number;
    v_baseline_genotypes number;
    v_baseline_lab_tasks number;
    v_baseline_tasks     number;

    procedure pass_test(p_name in varchar2, p_detail in varchar2 default null) is
    begin
        v_passed_tests := v_passed_tests + 1;
        dbms_output.put_line('[PASS] ' || p_name || case when p_detail is null then '' else ' -> ' || p_detail end);
    end pass_test;

    procedure fail_test(p_name in varchar2, p_detail in varchar2 default null) is
    begin
        v_failed_tests := v_failed_tests + 1;
        dbms_output.put_line('[FAIL] ' || p_name || case when p_detail is null then '' else ' -> ' || p_detail end);
    end fail_test;

    procedure assert_true(p_condition in boolean, p_name in varchar2, p_detail in varchar2 default null) is
    begin
        if p_condition then
            pass_test(p_name, p_detail);
        else
            fail_test(p_name, p_detail);
        end if;
    end assert_true;

    procedure cleanup is
        procedure remove_lab(p_lab_id in number) is
        begin
            if p_lab_id is null then
                return;
            end if;
            delete from rating_events where lab_id = p_lab_id;
            delete from experiments where lab_id = p_lab_id;
            delete from lab_mutations where lab_id = p_lab_id;
            delete from lab_tasks where lab_id = p_lab_id;
            delete from genotypes where creature_id in (select creature_id from creatures where lab_id = p_lab_id);
            delete from creatures where lab_id = p_lab_id;
            delete from labs where lab_id = p_lab_id;
        end remove_lab;
    begin
        remove_lab(v_v3_lab_id);
        remove_lab(v_v1_lab_id);
        remove_lab(v_transition_lab_id);
        if v_user_id is not null then
            delete from sessions where user_id = v_user_id;
            delete from users where user_id = v_user_id;
        end if;
        commit;
    end cleanup;

    procedure make_task_match(p_creature_id in number, p_task_id in number) is
    begin
        for marker_rec in (
            select a.gene_id, tm.allele_id
              from task_markers tm
              join alleles a on a.allele_id = tm.allele_id
             where tm.task_id = p_task_id
             order by a.gene_id
        ) loop
            update genotypes
               set allele1_id = marker_rec.allele_id,
                   allele2_id = marker_rec.allele_id
             where creature_id = p_creature_id
               and gene_id = marker_rec.gene_id;
            assert_true(sql%rowcount = 1, 'Fixture has marker genotype', 'gene_id=' || marker_rec.gene_id);
        end loop;
    end make_task_match;

    procedure add_active_task(p_lab_id in number, p_task_id in number) is
    begin
        insert into lab_tasks (lab_task_id, lab_id, task_id, task_status, assigned_at, completed_at)
        values (lab_tasks_seq.nextval, p_lab_id, p_task_id, 'ACTIVE', systimestamp, null);
    end add_active_task;

    procedure complete_matching_task(p_lab_id in number, p_creature_id in number, p_task_id in number) is
    begin
        make_task_match(p_creature_id, p_task_id);
        pkg_genetics_game.complete_task(
            p_lab_id       => p_lab_id,
            p_task_id      => p_task_id,
            p_creature_id  => p_creature_id,
            p_is_completed => v_value,
            p_wallet_after => v_wallet,
            p_rating_after => v_rating
        );
        assert_true(v_value = 1, 'Controlled task completion succeeds', 'task_id=' || p_task_id);
    end complete_matching_task;

    procedure assert_lab_task_versions(p_lab_id in number, p_version in number, p_name in varchar2) is
    begin
        select count(*)
          into v_value
          from lab_tasks lt
          join tasks t on t.task_id = lt.task_id
         where lt.lab_id = p_lab_id
           and t.genetics_version <> p_version;
        assert_true(v_value = 0, p_name, 'mismatches=' || v_value);
    end assert_lab_task_versions;

begin
    select count(*) into v_baseline_labs from labs;
    select count(*) into v_baseline_creatures from creatures;
    select count(*) into v_baseline_genotypes from genotypes;
    select count(*) into v_baseline_lab_tasks from lab_tasks;
    select count(*) into v_baseline_tasks from tasks;

    select task_id into v_v1_task_id from tasks where task_name = 'task_winged_specimen' and genetics_version = 1;
    select task_id into v_v3_task_id from tasks where task_name = 'task_v3_long_tailed_pointed' and genetics_version = 3;

    pkg_genetics_game.register_user('Version aware assignment owner', v_login, v_password, v_user_id);
    v_token := pkg_genetics_game.login_user(v_login, v_password);

    -- start_new_lab is the normal assignment entry point and must select v3 only.
    pkg_genetics_game.start_new_lab(v_token, v_v3_lab_id);
    select min(creature_id) into v_v3_creature_id from creatures where lab_id = v_v3_lab_id;
    select count(*) into v_value from lab_tasks where lab_id = v_v3_lab_id and task_status = 'ACTIVE';
    assert_true(v_value = 3, 'V3 start creates three active tasks', 'actual=' || v_value);
    assert_lab_task_versions(v_v3_lab_id, 3, 'V3 start assigns only v3 tasks');

    v_value := 0;
    for task_rec in (
        select task_id
          from lab_tasks
         where lab_id = v_v3_lab_id
           and task_status = 'ACTIVE'
    ) loop
        for creature_rec in (
            select creature_id
              from creatures
             where lab_id = v_v3_lab_id
        ) loop
            if pkg_genetics_game.check_task(v_v3_lab_id, task_rec.task_id, creature_rec.creature_id) = 1 then
                v_value := v_value + 1;
            end if;
        end loop;
    end loop;
    assert_true(v_value = 0, 'V3 starters do not auto-satisfy assigned tasks', 'matches=' || v_value);

    -- Completing an assigned v3 task refills from the v3 catalogue only.
    select min(task_id) into v_v3_task_id from lab_tasks where lab_id = v_v3_lab_id and task_status = 'ACTIVE';
    complete_matching_task(v_v3_lab_id, v_v3_creature_id, v_v3_task_id);
    select count(*) into v_value from lab_tasks where lab_id = v_v3_lab_id and task_status = 'ACTIVE';
    assert_true(v_value = 3, 'V3 completion refills to three active tasks', 'actual=' || v_value);
    assert_lab_task_versions(v_v3_lab_id, 3, 'V3 refill assigns only v3 tasks');
    select count(*) into v_value from (select task_id from lab_tasks where lab_id = v_v3_lab_id group by task_id having count(*) > 1);
    assert_true(v_value = 0, 'V3 assignment never duplicates a task', 'duplicates=' || v_value);
    select count(*) into v_value from lab_tasks where lab_id = v_v3_lab_id and task_id = v_v3_task_id and task_status = 'COMPLETED';
    assert_true(v_value = 1, 'Completed v3 task is retained and not reassigned', 'completed=' || v_value);

    -- A controlled v1 fixture reaches the same private selector through complete_task/refill.
    pkg_genetics_game.start_new_lab(v_token, v_v1_lab_id);
    select min(creature_id) into v_v1_creature_id from creatures where lab_id = v_v1_lab_id;
    delete from lab_tasks where lab_id = v_v1_lab_id;
    update labs set genetics_version = 1 where lab_id = v_v1_lab_id;
    add_active_task(v_v1_lab_id, v_v1_task_id);
    complete_matching_task(v_v1_lab_id, v_v1_creature_id, v_v1_task_id);
    select count(*) into v_value from lab_tasks where lab_id = v_v1_lab_id and task_status = 'ACTIVE';
    assert_true(v_value = 3, 'V1 refill preserves the three-task active target', 'actual=' || v_value);
    assert_lab_task_versions(v_v1_lab_id, 1, 'V1 refill assigns only v1 tasks');
    select count(*) into v_value from (select task_id from lab_tasks where lab_id = v_v1_lab_id group by task_id having count(*) > 1);
    assert_true(v_value = 0, 'V1 assignment never duplicates a task', 'duplicates=' || v_value);
    select count(*) into v_value from lab_tasks where lab_id = v_v1_lab_id and task_id = v_v1_task_id and task_status = 'COMPLETED';
    assert_true(v_value = 1, 'Completed v1 task is not reassigned', 'completed=' || v_value);

    -- Exhaust the v3 catalogue in an isolated fixture. Refill must be a no-op.
    pkg_genetics_game.start_new_lab(v_token, v_transition_lab_id);
    select min(creature_id) into v_transition_creature_id from creatures where lab_id = v_transition_lab_id;
    delete from lab_tasks where lab_id = v_transition_lab_id;
    for task_rec in (select task_id from tasks where genetics_version = 3) loop
        insert into lab_tasks (lab_task_id, lab_id, task_id, task_status, assigned_at, completed_at)
        values (
            lab_tasks_seq.nextval,
            v_transition_lab_id,
            task_rec.task_id,
            case when task_rec.task_id = v_v3_task_id then 'ACTIVE' else 'COMPLETED' end,
            systimestamp,
            case when task_rec.task_id = v_v3_task_id then null else systimestamp end
        );
    end loop;
    complete_matching_task(v_transition_lab_id, v_transition_creature_id, v_v3_task_id);
    select count(*) into v_value from lab_tasks where lab_id = v_transition_lab_id and task_status = 'ACTIVE';
    assert_true(v_value = 0, 'Exhausted v3 catalogue leaves no active fallback task', 'active=' || v_value);
    assert_lab_task_versions(v_transition_lab_id, 3, 'Exhaustion never falls back to v1 tasks');

    -- The evaluator remains task-version-aware for a deliberately manual transition row.
    delete from lab_tasks where lab_id = v_transition_lab_id;
    add_active_task(v_transition_lab_id, v_v1_task_id);
    make_task_match(v_transition_creature_id, v_v1_task_id);
    assert_true(
        pkg_genetics_game.check_task(v_transition_lab_id, v_v1_task_id, v_transition_creature_id) = 1,
        'Manual v1 task in v3 lab still uses v1 evaluator'
    );
    assert_lab_task_versions(v_transition_lab_id, 1, 'Manual transition fixture is explicitly isolated');

    select count(*) into v_value from tasks;
    assert_true(v_value = v_baseline_tasks, 'Assignment flow does not change task catalogue', 'actual=' || v_value);

    cleanup;
    select count(*) into v_value from labs;
    assert_true(v_value = v_baseline_labs, 'Cleanup restores LABS baseline', 'actual=' || v_value);
    select count(*) into v_value from creatures;
    assert_true(v_value = v_baseline_creatures, 'Cleanup restores CREATURES baseline', 'actual=' || v_value);
    select count(*) into v_value from genotypes;
    assert_true(v_value = v_baseline_genotypes, 'Cleanup restores GENOTYPES baseline', 'actual=' || v_value);
    select count(*) into v_value from lab_tasks;
    assert_true(v_value = v_baseline_lab_tasks, 'Cleanup restores LAB_TASKS baseline', 'actual=' || v_value);

    select count(*) into v_value from user_objects where object_name = 'PKG_GENETICS_GAME' and object_type in ('PACKAGE', 'PACKAGE BODY') and status = 'VALID';
    assert_true(v_value = 2, 'Package and body are VALID', 'actual=' || v_value);
    select count(*) into v_value from user_errors where name = 'PKG_GENETICS_GAME';
    assert_true(v_value = 0, 'PKG_GENETICS_GAME has no USER_ERRORS', 'actual=' || v_value);

    dbms_output.put_line('--- SUMMARY ---');
    dbms_output.put_line('Passed: ' || v_passed_tests);
    dbms_output.put_line('Failed: ' || v_failed_tests);
    if v_failed_tests > 0 then
        raise_application_error(-20000, 'Version-aware task assignment smoke test failed.');
    end if;
exception
    when others then
        cleanup;
        raise;
end;
/

-- Validates the reference-only v3 morphology task catalogue.
-- It never assigns tasks to laboratories or changes gameplay runtime.

@@../packages/spec/pkg_genetics_game.pks
@@../migrations/04_add_creature_archetypes.sql
@@../migrations/05_add_universal_morphology.sql
@@../migrations/06_add_archetype_templates.sql
@@../migrations/07_add_creature_archetype.sql
@@../migrations/08_add_allele_display_names.sql
@@../migrations/09_add_lab_genetics_version.sql
@@../migrations/10_add_genetics_model_membership.sql

declare
    v_v1_task_count       number;
    v_v1_marker_count     number;
    v_v1_task_id_sum      number;
    v_v1_money_sum        number;
    v_v1_rating_sum       number;
    v_lab_task_count      number;
    v_lab_count           number;
    v_creature_count      number;
    v_genotype_count      number;
begin
    select count(*), nvl(sum(t.task_id), 0), nvl(sum(t.money_reward * 100), 0), nvl(sum(t.rating_reward * 100), 0)
      into v_v1_task_count, v_v1_task_id_sum, v_v1_money_sum, v_v1_rating_sum
      from tasks t
     where substr(t.task_name, 1, 8) <> 'task_v3_';

    select count(*)
      into v_v1_marker_count
      from task_markers tm
      join tasks t
        on t.task_id = tm.task_id
     where substr(t.task_name, 1, 8) <> 'task_v3_';

    select count(*) into v_lab_task_count from lab_tasks;
    select count(*) into v_lab_count from labs;
    select count(*) into v_creature_count from creatures;
    select count(*) into v_genotype_count from genotypes;

    dbms_application_info.set_client_info(
        'm22:' || v_v1_task_count || ':' || v_v1_marker_count || ':' || v_v1_task_id_sum || ':' ||
        v_v1_money_sum || ':' || v_v1_rating_sum || ':' || v_lab_task_count || ':' ||
        v_lab_count || ':' || v_creature_count || ':' || v_genotype_count
    );
end;
/

@@../migrations/11_add_task_genetics_version.sql

declare
    v_v3_task_count   number;
    v_v3_marker_count number;
begin
    select count(*) into v_v3_task_count from tasks where genetics_version = 3;
    select count(*) into v_v3_marker_count from task_markers tm join tasks t on t.task_id = tm.task_id where t.genetics_version = 3;
    dbms_application_info.set_client_info(
        sys_context('USERENV', 'CLIENT_INFO') || ':' || v_v3_task_count || ':' || v_v3_marker_count
    );
end;
/

@@../seeds/05_seed_v3_tasks.sql

set serveroutput on size unlimited;
set verify off;

declare
    v_failed_tests        number := 0;
    v_passed_tests        number := 0;
    v_value               number;
    v_snapshot            varchar2(64);
    v_v3_task_count       number;
    v_v3_marker_count     number;
    v_error_code          number;

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

    function snapshot_value(p_position in number) return number is
    begin
        return to_number(regexp_substr(v_snapshot, '[^:]+', 1, p_position));
    end snapshot_value;

    procedure assert_v3_task(
        p_task_name    in varchar2,
        p_marker_count in number
    ) is
    begin
        select count(*)
          into v_value
          from tasks t
         where t.task_name = p_task_name
           and t.genetics_version = 3;
        assert_true(v_value = 1, 'v3 task exists: ' || p_task_name, 'actual=' || v_value);

        select count(*)
          into v_value
          from task_markers tm
          join tasks t on t.task_id = tm.task_id
         where t.task_name = p_task_name;
        assert_true(v_value = p_marker_count, p_task_name || ' marker count', 'actual=' || v_value);
    end assert_v3_task;
begin
    v_snapshot := sys_context('USERENV', 'CLIENT_INFO');

    select count(*)
      into v_value
      from user_tab_columns
     where table_name = 'TASKS'
       and column_name = 'GENETICS_VERSION'
       and nullable = 'N';
    assert_true(v_value = 1, 'TASKS.GENETICS_VERSION is NOT NULL', 'actual=' || v_value);

    select count(*)
      into v_value
      from user_constraints
     where table_name = 'TASKS'
       and constraint_name = 'CK_TASKS_GENETICS_VERSION'
       and status = 'ENABLED';
    assert_true(v_value = 1, 'TASKS.GENETICS_VERSION check is enabled', 'actual=' || v_value);

    select count(*) into v_value from tasks where genetics_version = 1;
    assert_true(v_value = snapshot_value(2), 'Historical task count is preserved as v1', 'actual=' || v_value);

    select count(*) into v_value from tasks where substr(task_name, 1, 8) <> 'task_v3_' and genetics_version <> 1;
    assert_true(v_value = 0, 'Every historical task belongs to v1', 'actual=' || v_value);

    select count(*) into v_value from task_markers tm join tasks t on t.task_id = tm.task_id where t.genetics_version = 1;
    assert_true(v_value = snapshot_value(3), 'Historical task markers are preserved', 'actual=' || v_value);

    select nvl(sum(task_id), 0), nvl(sum(money_reward * 100), 0), nvl(sum(rating_reward * 100), 0)
      into v_value, v_v3_task_count, v_v3_marker_count
      from tasks
     where genetics_version = 1;
    assert_true(v_value = snapshot_value(4), 'Historical task IDs are preserved', 'actual=' || v_value);
    assert_true(v_v3_task_count = snapshot_value(5), 'Historical money rewards are preserved', 'actual=' || v_v3_task_count);
    assert_true(v_v3_marker_count = snapshot_value(6), 'Historical rating rewards are preserved', 'actual=' || v_v3_marker_count);

    select count(*) into v_value from lab_tasks;
    assert_true(v_value = snapshot_value(7), 'Existing LAB_TASKS are preserved', 'actual=' || v_value);
    select count(*) into v_value from labs;
    assert_true(v_value = snapshot_value(8), 'LABS count is preserved', 'actual=' || v_value);
    select count(*) into v_value from creatures;
    assert_true(v_value = snapshot_value(9), 'CREATURES count is preserved', 'actual=' || v_value);
    select count(*) into v_value from genotypes;
    assert_true(v_value = snapshot_value(10), 'GENOTYPES count is preserved', 'actual=' || v_value);

    select count(*) into v_v3_task_count from tasks where genetics_version = 3;
    assert_true(v_v3_task_count = 12, 'Exactly 12 v3 catalogue tasks exist', 'actual=' || v_v3_task_count);

    assert_v3_task('task_v3_disc_saw', 2);
    assert_v3_task('task_v3_eel_yellow', 2);
    assert_v3_task('task_v3_shrimp_claws', 2);
    assert_v3_task('task_v3_cephalopod_shell', 2);
    assert_v3_task('task_v3_snake_shell', 2);
    assert_v3_task('task_v3_cetacean_broad', 2);
    assert_v3_task('task_v3_brown_cetacean', 2);
    assert_v3_task('task_v3_giant_pinniped', 2);
    assert_v3_task('task_v3_disc_fish_tail', 2);
    assert_v3_task('task_v3_cetacean_rear_flippers', 2);
    assert_v3_task('task_v3_white_broad_cephalopod', 3);
    assert_v3_task('task_v3_long_tailed_predator', 3);

    select count(*)
      into v_value
      from task_markers tm
      join tasks t on t.task_id = tm.task_id
      left join alleles a on a.allele_id = tm.allele_id
      left join ref_genetics_model_genes membership on membership.gene_id = a.gene_id and membership.genetics_version = 3
     where t.genetics_version = 3
       and membership.gene_id is null;
    assert_true(v_value = 0, 'Every v3 marker belongs to the v3 model', 'actual=' || v_value);

    select count(*)
      into v_value
      from task_markers tm
      join tasks t on t.task_id = tm.task_id
      join alleles a on a.allele_id = tm.allele_id
      join genes g on g.gene_id = a.gene_id
     where t.genetics_version = 3
       and g.gene_name in ('color', 'size', 'has_wings', 'fin_shape', 'shell_armor', 'claw_form', 'beak_nose_shape', 'speed_level', 'fur_density');
    assert_true(v_value = 0, 'v3 markers exclude legacy genes', 'actual=' || v_value);

    select count(*)
      into v_value
      from tasks t
     where t.genetics_version = 3
       and (t.money_reward <= 0 or t.rating_reward <= 0);
    assert_true(v_value = 0, 'All v3 rewards are positive', 'actual=' || v_value);

    begin
        insert into tasks (task_id, task_name, description, rating_reward, money_reward, difficulty_code, genetics_version)
        values (tasks_seq.nextval, 'task_v2_rejected_smoke', 'Controlled invalid version row.', 1, 1, 'EASY', 2);
        fail_test('TASKS.GENETICS_VERSION rejects 2', 'insert unexpectedly succeeded');
        rollback;
    exception
        when others then
            v_error_code := sqlcode;
            rollback;
            assert_true(v_error_code = -2290, 'TASKS.GENETICS_VERSION rejects 2', 'actual=' || v_error_code);
    end;

    select count(*) into v_v3_task_count from tasks where genetics_version = 3;
    select count(*) into v_v3_marker_count from task_markers tm join tasks t on t.task_id = tm.task_id where t.genetics_version = 3;
    assert_true(v_v3_task_count = snapshot_value(11), 'Repeated v3 seed preserves task count', 'actual=' || v_v3_task_count);
    assert_true(v_v3_marker_count = snapshot_value(12), 'Repeated v3 seed preserves marker count', 'actual=' || v_v3_marker_count);

    select count(*) into v_value from user_objects where object_name = 'PKG_GENETICS_GAME' and object_type in ('PACKAGE', 'PACKAGE BODY') and status = 'VALID';
    assert_true(v_value = 2, 'PKG_GENETICS_GAME package and body remain VALID', 'actual=' || v_value);
    select count(*) into v_value from user_errors where name = 'PKG_GENETICS_GAME';
    assert_true(v_value = 0, 'PKG_GENETICS_GAME has no USER_ERRORS', 'actual=' || v_value);

    dbms_output.put_line('--- SUMMARY ---');
    dbms_output.put_line('Passed: ' || v_passed_tests);
    dbms_output.put_line('Failed: ' || v_failed_tests);
    if v_failed_tests > 0 then
        raise_application_error(-20000, 'Versioned v3 task catalogue smoke test failed.');
    end if;
end;
/

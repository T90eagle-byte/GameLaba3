set serveroutput on size unlimited;
set verify off;

declare
    v_user_id                     number;
    v_lab_id                      number;
    v_secondary_lab_id            number;
    v_login                       varchar2(20);
    v_username                    varchar2(255);
    v_password                    varchar2(100) := 'tasks_smoke_123';
    v_session_token               varchar2(128);

    v_active_task_count_db        number := 0;
    v_total_task_count_db         number := 0;

    v_tasks_cursor                sys_refcursor;
    v_t_lab_task_id               number;
    v_t_task_id                   number;
    v_t_task_name                 varchar2(4000);
    v_t_task_display_name         varchar2(4000);
    v_t_description               varchar2(4000);
    v_t_reward_money              number;
    v_t_reward_rating             number;
    v_t_difficulty_code           varchar2(4000);
    v_t_difficulty_display_name   varchar2(4000);
    v_t_task_status               varchar2(4000);
    v_t_task_status_display_name  varchar2(4000);
    v_t_created_at                timestamp;
    v_t_completed_at              timestamp;
    v_tasks_cursor_row_count      number := 0;
    v_any_task_id                 number;

    v_creature_count_before       number := 0;
    v_creature_count_after        number := 0;
    v_probe_creature_id           number;

    v_candidate_task_id           number;
    v_candidate_creature_id       number;
    v_fallback_task_id            number;
    v_fallback_creature_id        number;
    v_check_result                number;

    v_wallet_before               number;
    v_rating_before               number;
    v_is_completed                number;
    v_wallet_after                number;
    v_rating_after                number;
    v_completed_task_status       varchar2(4000);
    v_completed_at_after          timestamp;

    v_stats_wallet                number;
    v_stats_rating                number;
    v_stats_creature_count        number;
    v_stats_active_task_count     number;
    v_stats_completed_task_count  number;
    v_stats_experiment_count      number;

    v_secondary_task_id           number;
    v_completion_done             number := 0;

    v_marker_task_id               number;
    v_multi_marker_task_id         number;
    v_marker_lab_task_id           number;
    v_multi_marker_lab_task_id     number;
    v_wings_gene_id                number;
    v_wings_allele_id              number;
    v_no_wings_allele_id           number;
    v_color_gene_id                number;
    v_green_allele_id              number;
    v_red_allele_id                number;
    v_wings_genotype_id            number;
    v_color_genotype_id            number;
    v_wings_original_allele1_id    number;
    v_wings_original_allele2_id    number;
    v_color_original_allele1_id    number;
    v_color_original_allele2_id    number;
    v_marker_phenotype             varchar2(4000);
    v_wallet_after_marker_complete number;
    v_wallet_after_marker_repeat   number;

    v_active_task_count_before    number := 0;
    v_active_task_count_after     number := 0;
    v_total_task_count_before     number := 0;
    v_total_task_count_after      number := 0;
    v_total_available_tasks       number := 0;
    v_distinct_task_count_after   number := 0;

    v_failed_tests                number := 0;
    v_passed_tests                number := 0;

    procedure pass_test(p_test_name in varchar2) is
    begin
        v_passed_tests := v_passed_tests + 1;
        dbms_output.put_line('[PASS] ' || p_test_name);
    end pass_test;

    procedure fail_test(
        p_test_name in varchar2,
        p_detail    in varchar2 default null
    ) is
    begin
        v_failed_tests := v_failed_tests + 1;
        dbms_output.put_line('[FAIL] ' || p_test_name || case when p_detail is null then '' else ' -> ' || p_detail end);
    end fail_test;

    procedure assert_true(
        p_condition in boolean,
        p_test_name in varchar2,
        p_detail    in varchar2 default null
    ) is
    begin
        if p_condition then
            pass_test(p_test_name);
        else
            fail_test(p_test_name, p_detail);
        end if;
    end assert_true;

    procedure cleanup_test_data is
    begin
        begin
            if v_wings_genotype_id is not null then
                update genotypes
                   set allele1_id = v_wings_original_allele1_id,
                       allele2_id = v_wings_original_allele2_id
                 where genotype_id = v_wings_genotype_id;
            end if;

            if v_color_genotype_id is not null then
                update genotypes
                   set allele1_id = v_color_original_allele1_id,
                       allele2_id = v_color_original_allele2_id
                 where genotype_id = v_color_genotype_id;
            end if;

            delete from rating_events
             where task_id in (v_marker_task_id, v_multi_marker_task_id);
            delete from lab_tasks
             where task_id in (v_marker_task_id, v_multi_marker_task_id);
            delete from task_markers
             where task_id in (v_marker_task_id, v_multi_marker_task_id);
            delete from tasks
             where task_id in (v_marker_task_id, v_multi_marker_task_id);
        exception
            when others then
                dbms_output.put_line('[WARN] cleanup marker semantics: ' || sqlcode || ' / ' || sqlerrm);
        end;

        if v_session_token is not null and v_secondary_lab_id is not null then
            begin
                pkg_genetics_game.delete_lab(
                    p_session_token => v_session_token,
                    p_lab_id        => v_secondary_lab_id
                );
                dbms_output.put_line('[INFO] cleanup: delete secondary lab done');
            exception
                when others then
                    dbms_output.put_line('[WARN] cleanup delete secondary lab: ' || sqlcode || ' / ' || sqlerrm);
            end;
        end if;

        if v_session_token is not null and v_lab_id is not null then
            begin
                pkg_genetics_game.delete_lab(
                    p_session_token => v_session_token,
                    p_lab_id        => v_lab_id
                );
                dbms_output.put_line('[INFO] cleanup: delete primary lab done');
            exception
                when others then
                    dbms_output.put_line('[WARN] cleanup delete primary lab: ' || sqlcode || ' / ' || sqlerrm);
            end;
        end if;

        if v_session_token is not null then
            begin
                pkg_genetics_game.logout_user(
                    p_session_token => v_session_token
                );
                dbms_output.put_line('[INFO] cleanup: logout_user done');
            exception
                when others then
                    if sqlcode != -20021 then
                        dbms_output.put_line('[WARN] cleanup logout_user: ' || sqlcode || ' / ' || sqlerrm);
                    end if;
            end;
        end if;

        begin
            delete from sessions s
             where s.user_id = v_user_id
                or s.user_id in (
                    select u.user_id
                      from users u
                     where u.login = v_login
                );

            delete from users u
             where (u.user_id = v_user_id or u.login = v_login)
               and u.login = v_login;

            dbms_output.put_line('[INFO] cleanup: direct sessions/users cleanup done');
        exception
            when others then
                dbms_output.put_line('[WARN] cleanup direct delete: ' || sqlcode || ' / ' || sqlerrm);
        end;
    end cleanup_test_data;
begin
    v_login := 'u' || lower(substr(rawtohex(sys_guid()), 1, 19));
    v_username := 'tasks_smoke_' || substr(v_login, 2, 6);

    dbms_output.put_line('Smoke-test login: ' || v_login);
    dbms_output.put_line('--- TASKS SMOKE TEST ---');

    begin
        pkg_genetics_game.register_user(
            p_username => v_username,
            p_login    => v_login,
            p_password => v_password,
            p_user_id  => v_user_id
        );
        assert_true(v_user_id is not null and v_user_id > 0, 'register_user');
    exception
        when others then
            fail_test('register_user', sqlerrm);
    end;

    if v_user_id is not null then
        begin
            v_session_token := pkg_genetics_game.login_user(
                p_login    => v_login,
                p_password => v_password
            );
            assert_true(v_session_token is not null, 'login_user');
        exception
            when others then
                fail_test('login_user', sqlerrm);
        end;
    end if;

    if v_session_token is not null then
        begin
            pkg_genetics_game.start_new_lab(
                p_session_token => v_session_token,
                p_lab_id        => v_lab_id
            );
            assert_true(v_lab_id is not null and v_lab_id > 0, 'start_new_lab');
        exception
            when others then
                fail_test('start_new_lab', sqlerrm);
        end;
    end if;

    if v_lab_id is not null then
        begin
            select count(*)
              into v_active_task_count_db
              from lab_tasks lt
             where lt.lab_id = v_lab_id
               and lt.task_status = 'ACTIVE';

            select count(*)
              into v_total_task_count_db
              from lab_tasks lt
             where lt.lab_id = v_lab_id;

            assert_true(v_active_task_count_db = 3, 'start_new_lab assigns 3 ACTIVE tasks', 'actual=' || v_active_task_count_db);
            assert_true(v_total_task_count_db = 3, 'start_new_lab assigns 3 tasks total', 'actual=' || v_total_task_count_db);
        exception
            when others then
                fail_test('start_new_lab tasks assignment', sqlerrm);
        end;
    end if;

    if v_lab_id is not null then
        begin
            v_tasks_cursor_row_count := 0;
            v_any_task_id := null;
            v_tasks_cursor := pkg_genetics_game.get_tasks_cursor(
                p_lab_id => v_lab_id
            );

            loop
                fetch v_tasks_cursor into
                    v_t_lab_task_id,
                    v_t_task_id,
                    v_t_task_name,
                    v_t_task_display_name,
                    v_t_description,
                    v_t_reward_money,
                    v_t_reward_rating,
                    v_t_difficulty_code,
                    v_t_difficulty_display_name,
                    v_t_task_status,
                    v_t_task_status_display_name,
                    v_t_created_at,
                    v_t_completed_at;
                exit when v_tasks_cursor%notfound;

                v_tasks_cursor_row_count := v_tasks_cursor_row_count + 1;
                if v_any_task_id is null then
                    v_any_task_id := v_t_task_id;
                end if;
            end loop;

            close v_tasks_cursor;
            assert_true(v_tasks_cursor_row_count > 0, 'get_tasks_cursor returns rows', 'rowcount=' || v_tasks_cursor_row_count);
        exception
            when others then
                if v_tasks_cursor%isopen then
                    close v_tasks_cursor;
                end if;
                fail_test('get_tasks_cursor', sqlerrm);
        end;
    end if;

    if v_lab_id is not null then
        begin
            select count(*)
              into v_creature_count_before
              from creatures c
             where c.lab_id = v_lab_id;

            assert_true(v_creature_count_before = 30, 'start_new_lab generated 30 creatures', 'count=' || v_creature_count_before);

            select count(*)
              into v_creature_count_after
              from creatures c
             where c.lab_id = v_lab_id;

            assert_true(v_creature_count_after = 30, 'lab has 30 creatures for task checks', 'count=' || v_creature_count_after);

            select min(c.creature_id)
              into v_probe_creature_id
              from creatures c
             where c.lab_id = v_lab_id;
        exception
            when others then
                fail_test('creature preparation for tasks', sqlerrm);
        end;
    end if;

    -- Find one ACTIVE task + creature that fully matches all task markers
    if v_lab_id is not null then
        begin
            select z.task_id, z.creature_id
              into v_candidate_task_id, v_candidate_creature_id
              from (
                    select
                        lt.task_id,
                        c.creature_id
                      from lab_tasks lt
                      join creatures c
                        on c.lab_id = lt.lab_id
                     where lt.lab_id = v_lab_id
                       and lt.task_status = 'ACTIVE'
                       and not exists (
                            select 1
                              from task_markers tm
                             where tm.task_id = lt.task_id
                               and not exists (
                                    select 1
                                      from genotypes g
                                     where g.creature_id = c.creature_id
                                       and (
                                            g.allele1_id = tm.allele_id
                                            or g.allele2_id = tm.allele_id
                                       )
                               )
                       )
                     order by lt.task_id, c.creature_id
              ) z
             where rownum = 1;

            pass_test('found completable task/creature pair');
        exception
            when no_data_found then
                v_candidate_task_id := null;
                v_candidate_creature_id := null;
                dbms_output.put_line('[WARN] no completable pair found (random generation). Will run negative check_task flow.');
            when others then
                fail_test('search completable task/creature pair', sqlerrm);
        end;
    end if;

    -- Positive flow if completable pair exists
    if v_candidate_task_id is not null and v_candidate_creature_id is not null then
        begin
            v_check_result := pkg_genetics_game.check_task(
                p_lab_id      => v_lab_id,
                p_task_id     => v_candidate_task_id,
                p_creature_id => v_candidate_creature_id
            );
            assert_true(v_check_result = 1, 'check_task positive returns 1', 'actual=' || nvl(to_char(v_check_result), 'NULL'));
        exception
            when others then
                fail_test('check_task positive', sqlerrm);
        end;

        begin
            select l.wallet, l.rating
              into v_wallet_before, v_rating_before
              from labs l
             where l.lab_id = v_lab_id;

            select count(*)
              into v_active_task_count_before
              from lab_tasks lt
             where lt.lab_id = v_lab_id
               and lt.task_status = 'ACTIVE';

            select count(*)
              into v_total_task_count_before
              from lab_tasks lt
             where lt.lab_id = v_lab_id;

            select count(*)
              into v_total_available_tasks
              from tasks t;

            pkg_genetics_game.complete_task(
                p_lab_id       => v_lab_id,
                p_task_id      => v_candidate_task_id,
                p_creature_id  => v_candidate_creature_id,
                p_is_completed => v_is_completed,
                p_wallet_after => v_wallet_after,
                p_rating_after => v_rating_after
            );

            select lt.task_status, lt.completed_at
              into v_completed_task_status, v_completed_at_after
              from lab_tasks lt
             where lt.lab_id = v_lab_id
               and lt.task_id = v_candidate_task_id;

            select count(*)
              into v_active_task_count_after
              from lab_tasks lt
             where lt.lab_id = v_lab_id
               and lt.task_status = 'ACTIVE';

            select count(*)
              into v_total_task_count_after
              from lab_tasks lt
             where lt.lab_id = v_lab_id;

            select count(distinct lt.task_id)
              into v_distinct_task_count_after
              from lab_tasks lt
             where lt.lab_id = v_lab_id;

            assert_true(v_is_completed = 1, 'complete_task returns completed=1', 'actual=' || nvl(to_char(v_is_completed), 'NULL'));
            assert_true(v_completed_task_status = 'COMPLETED', 'task status changed to COMPLETED', 'actual=' || v_completed_task_status);
            assert_true(v_completed_at_after is not null, 'task completed_at is filled');
            assert_true(v_wallet_after > v_wallet_before, 'wallet increased after complete_task', 'before=' || v_wallet_before || ', after=' || v_wallet_after);
            assert_true(v_rating_after > v_rating_before, 'rating increased after complete_task', 'before=' || v_rating_before || ', after=' || v_rating_after);

            assert_true(
                v_total_task_count_after = v_distinct_task_count_after,
                'no duplicate task_id assignments for lab',
                'total=' || v_total_task_count_after || ', distinct=' || v_distinct_task_count_after
            );
            assert_true(
                v_total_task_count_after <= v_total_available_tasks,
                'assigned tasks do not exceed tasks pool',
                'assigned=' || v_total_task_count_after || ', pool=' || v_total_available_tasks
            );

            if v_total_task_count_before < v_total_available_tasks then
                assert_true(
                    v_total_task_count_after > v_total_task_count_before,
                    'task refill assigns a new task when pool is available',
                    'before=' || v_total_task_count_before || ', after=' || v_total_task_count_after || ', pool=' || v_total_available_tasks
                );
                assert_true(
                    v_active_task_count_after = 3,
                    'active tasks are refilled to 3 when pool is available',
                    'before_active=' || v_active_task_count_before || ', after_active=' || v_active_task_count_after
                );
            else
                assert_true(
                    v_active_task_count_after <= 3,
                    'active tasks stay bounded when task pool is exhausted',
                    'after_active=' || v_active_task_count_after || ', pool=' || v_total_available_tasks
                );
            end if;

            pkg_genetics_game.get_lab_stats(
                p_lab_id               => v_lab_id,
                p_wallet               => v_stats_wallet,
                p_rating               => v_stats_rating,
                p_creature_count       => v_stats_creature_count,
                p_active_task_count    => v_stats_active_task_count,
                p_completed_task_count => v_stats_completed_task_count,
                p_experiment_count     => v_stats_experiment_count
            );
            assert_true(v_stats_completed_task_count >= 1, 'get_lab_stats completed_task_count increased', 'actual=' || v_stats_completed_task_count);
            assert_true(
                v_stats_active_task_count = v_active_task_count_after,
                'get_lab_stats active_task_count matches lab_tasks',
                'stats=' || v_stats_active_task_count || ', table=' || v_active_task_count_after
            );

            v_completion_done := 1;
        exception
            when others then
                fail_test('complete_task positive flow', sqlerrm);
        end;
    end if;

    -- If no completable pair found, verify negative check_task = 0
    if v_candidate_task_id is null or v_candidate_creature_id is null then
        begin
            select y.task_id, y.creature_id
              into v_fallback_task_id, v_fallback_creature_id
              from (
                    select
                        lt.task_id,
                        c.creature_id
                      from lab_tasks lt
                      join creatures c
                        on c.lab_id = lt.lab_id
                     where lt.lab_id = v_lab_id
                       and lt.task_status = 'ACTIVE'
                       and exists (
                            select 1
                              from task_markers tm
                             where tm.task_id = lt.task_id
                               and not exists (
                                    select 1
                                      from genotypes g
                                     where g.creature_id = c.creature_id
                                       and (
                                            g.allele1_id = tm.allele_id
                                            or g.allele2_id = tm.allele_id
                                       )
                               )
                       )
                     order by lt.task_id, c.creature_id
              ) y
             where rownum = 1;

            v_check_result := pkg_genetics_game.check_task(
                p_lab_id      => v_lab_id,
                p_task_id     => v_fallback_task_id,
                p_creature_id => v_fallback_creature_id
            );

            assert_true(v_check_result = 0, 'check_task negative returns 0', 'actual=' || nvl(to_char(v_check_result), 'NULL'));
        exception
            when no_data_found then
                dbms_output.put_line('[WARN] no fallback pair for negative check_task found.');
            when others then
                fail_test('check_task negative flow', sqlerrm);
        end;
    end if;

    -- Repeated completion of already COMPLETED task should raise -20064
    if v_completion_done = 1 then
        begin
            pkg_genetics_game.complete_task(
                p_lab_id       => v_lab_id,
                p_task_id      => v_candidate_task_id,
                p_creature_id  => v_candidate_creature_id,
                p_is_completed => v_is_completed,
                p_wallet_after => v_wallet_after,
                p_rating_after => v_rating_after
            );
            fail_test('repeat complete_task should fail', 'expected -20064');
        exception
            when others then
                if sqlcode = -20064 then
                    pass_test('repeat complete_task returns -20064');
                else
                    fail_test(
                        'repeat complete_task returns -20064',
                        'unexpected sqlcode=' || to_char(sqlcode) || ' message=' || sqlerrm
                    );
                end if;
        end;
    else
        dbms_output.put_line('[WARN] skip repeat complete_task check: no completed task in this run.');
    end if;

    -- Negative case: non-existing lab_id -> -20057
    if v_any_task_id is null and v_lab_id is not null then
        begin
            select min(lt.task_id)
              into v_any_task_id
              from lab_tasks lt
             where lt.lab_id = v_lab_id;
        exception
            when others then
                null;
        end;
    end if;

    if v_any_task_id is not null and v_probe_creature_id is not null then
        begin
            v_check_result := pkg_genetics_game.check_task(
                p_lab_id      => -999999,
                p_task_id     => v_any_task_id,
                p_creature_id => v_probe_creature_id
            );
            fail_test('negative check_task non-existing lab', 'expected -20057, got result=' || nvl(to_char(v_check_result), 'NULL'));
        exception
            when others then
                if sqlcode = -20057 then
                    pass_test('negative check_task non-existing lab');
                else
                    fail_test(
                        'negative check_task non-existing lab',
                        'unexpected sqlcode=' || to_char(sqlcode) || ' message=' || sqlerrm
                    );
                end if;
        end;
    end if;

    -- Negative case: non-existing task_id -> -20058
    if v_lab_id is not null and v_probe_creature_id is not null then
        begin
            v_check_result := pkg_genetics_game.check_task(
                p_lab_id      => v_lab_id,
                p_task_id     => -999999,
                p_creature_id => v_probe_creature_id
            );
            fail_test('negative check_task non-existing task', 'expected -20058, got result=' || nvl(to_char(v_check_result), 'NULL'));
        exception
            when others then
                if sqlcode = -20058 then
                    pass_test('negative check_task non-existing task');
                else
                    fail_test(
                        'negative check_task non-existing task',
                        'unexpected sqlcode=' || to_char(sqlcode) || ' message=' || sqlerrm
                    );
                end if;
        end;
    end if;

    -- Controlled LR2 marker semantics: each required allele may be in either genotype slot.
    if v_lab_id is not null and v_probe_creature_id is not null then
        begin
            select
                g.gene_id,
                max(case when a.description = 'wings' then a.allele_id end),
                max(case when a.description = 'no_wings' then a.allele_id end)
              into v_wings_gene_id, v_wings_allele_id, v_no_wings_allele_id
              from genes g
              join alleles a
                on a.gene_id = g.gene_id
             where g.gene_name = 'has_wings'
               and g.species_type = 0
             group by g.gene_id;

            select
                g.gene_id,
                max(case when a.description = 'green_color' then a.allele_id end),
                max(case when a.description = 'red_color' then a.allele_id end)
              into v_color_gene_id, v_green_allele_id, v_red_allele_id
              from genes g
              join alleles a
                on a.gene_id = g.gene_id
             where g.gene_name = 'color'
               and g.species_type = 0
             group by g.gene_id;

            select genotype_id, allele1_id, allele2_id
              into v_wings_genotype_id, v_wings_original_allele1_id, v_wings_original_allele2_id
              from genotypes
             where creature_id = v_probe_creature_id
               and gene_id = v_wings_gene_id;

            select genotype_id, allele1_id, allele2_id
              into v_color_genotype_id, v_color_original_allele1_id, v_color_original_allele2_id
              from genotypes
             where creature_id = v_probe_creature_id
               and gene_id = v_color_gene_id;

            v_marker_task_id := tasks_seq.nextval;
            insert into tasks (
                task_id, task_name, description, money_reward, rating_reward, difficulty_code, created_at
            ) values (
                v_marker_task_id,
                'task_marker_slot_' || substr(v_login, 2, 12),
                'Controlled task-marker semantics test',
                7, 3, 'EASY', systimestamp
            );
            insert into task_markers (task_marker_id, task_id, allele_id)
            values (task_markers_seq.nextval, v_marker_task_id, v_wings_allele_id);
            v_marker_lab_task_id := lab_tasks_seq.nextval;
            insert into lab_tasks (lab_task_id, lab_id, task_id, task_status, assigned_at, completed_at)
            values (v_marker_lab_task_id, v_lab_id, v_marker_task_id, 'ACTIVE', systimestamp, null);

            update genotypes
               set allele1_id = v_wings_allele_id,
                   allele2_id = v_wings_allele_id
             where genotype_id = v_wings_genotype_id;
            v_check_result := pkg_genetics_game.check_task(v_lab_id, v_marker_task_id, v_probe_creature_id);
            assert_true(v_check_result = 1, 'marker allele in both slots completes task', 'actual=' || v_check_result);

            update genotypes
               set allele1_id = v_wings_allele_id,
                   allele2_id = v_no_wings_allele_id
             where genotype_id = v_wings_genotype_id;
            v_check_result := pkg_genetics_game.check_task(v_lab_id, v_marker_task_id, v_probe_creature_id);
            v_marker_phenotype := pkg_genetics_game.get_phenotype(v_probe_creature_id);
            assert_true(v_check_result = 1, 'marker allele in one slot completes task', 'actual=' || v_check_result);
            assert_true(instr(v_marker_phenotype, 'has_wings=no_wings') > 0,
                'recessive wings carrier keeps non-winged phenotype', v_marker_phenotype);

            update genotypes
               set allele1_id = v_no_wings_allele_id,
                   allele2_id = v_no_wings_allele_id
             where genotype_id = v_wings_genotype_id;
            v_check_result := pkg_genetics_game.check_task(v_lab_id, v_marker_task_id, v_probe_creature_id);
            assert_true(v_check_result = 0, 'missing marker allele does not complete task', 'actual=' || v_check_result);

            v_multi_marker_task_id := tasks_seq.nextval;
            insert into tasks (
                task_id, task_name, description, money_reward, rating_reward, difficulty_code, created_at
            ) values (
                v_multi_marker_task_id,
                'task_marker_multi_' || substr(v_login, 2, 12),
                'Controlled multi-marker semantics test',
                9, 4, 'MEDIUM', systimestamp
            );
            insert into task_markers (task_marker_id, task_id, allele_id)
            values (task_markers_seq.nextval, v_multi_marker_task_id, v_wings_allele_id);
            insert into task_markers (task_marker_id, task_id, allele_id)
            values (task_markers_seq.nextval, v_multi_marker_task_id, v_green_allele_id);
            v_multi_marker_lab_task_id := lab_tasks_seq.nextval;
            insert into lab_tasks (lab_task_id, lab_id, task_id, task_status, assigned_at, completed_at)
            values (v_multi_marker_lab_task_id, v_lab_id, v_multi_marker_task_id, 'ACTIVE', systimestamp, null);

            update genotypes
               set allele1_id = v_wings_allele_id,
                   allele2_id = v_no_wings_allele_id
             where genotype_id = v_wings_genotype_id;
            update genotypes
               set allele1_id = v_green_allele_id,
                   allele2_id = v_green_allele_id
             where genotype_id = v_color_genotype_id;
            v_check_result := pkg_genetics_game.check_task(v_lab_id, v_multi_marker_task_id, v_probe_creature_id);
            assert_true(v_check_result = 1, 'all task markers must match together', 'actual=' || v_check_result);

            update genotypes
               set allele1_id = v_red_allele_id,
                   allele2_id = v_red_allele_id
             where genotype_id = v_color_genotype_id;
            v_check_result := pkg_genetics_game.check_task(v_lab_id, v_multi_marker_task_id, v_probe_creature_id);
            assert_true(v_check_result = 0, 'one missing marker blocks multi-marker task', 'actual=' || v_check_result);

            update genotypes
               set allele1_id = v_wings_allele_id,
                   allele2_id = v_wings_allele_id
             where genotype_id = v_wings_genotype_id;
            select wallet into v_wallet_before from labs where lab_id = v_lab_id;
            pkg_genetics_game.complete_task(
                v_lab_id, v_marker_task_id, v_probe_creature_id,
                v_is_completed, v_wallet_after, v_rating_after
            );
            select wallet into v_wallet_after_marker_complete from labs where lab_id = v_lab_id;
            assert_true(v_is_completed = 1 and v_wallet_after_marker_complete > v_wallet_before,
                'marker task reward is issued once');

            begin
                pkg_genetics_game.complete_task(
                    v_lab_id, v_marker_task_id, v_probe_creature_id,
                    v_is_completed, v_wallet_after, v_rating_after
                );
                fail_test('marker task repeat completion is blocked', 'expected -20064');
            exception
                when others then
                    if sqlcode = -20064 then
                        pass_test('marker task repeat completion is blocked');
                    else
                        fail_test('marker task repeat completion is blocked', sqlcode || ' / ' || sqlerrm);
                    end if;
            end;
            select wallet into v_wallet_after_marker_repeat from labs where lab_id = v_lab_id;
            assert_true(v_wallet_after_marker_repeat = v_wallet_after_marker_complete,
                'repeat completion does not duplicate marker task reward');
        exception
            when others then
                fail_test('controlled task-marker semantics', sqlcode || ' / ' || sqlerrm);
        end;
    end if;

    -- Negative case: creature_id from another lab under session-bound access model
    if v_session_token is not null and v_lab_id is not null and v_probe_creature_id is not null then
        begin
            pkg_genetics_game.start_new_lab(
                p_session_token => v_session_token,
                p_lab_id        => v_secondary_lab_id
            );

            select min(lt.task_id)
              into v_secondary_task_id
              from lab_tasks lt
             where lt.lab_id = v_secondary_lab_id;

            v_check_result := pkg_genetics_game.check_task(
                p_lab_id      => v_secondary_lab_id,
                p_task_id     => v_secondary_task_id,
                p_creature_id => v_probe_creature_id
            );

            fail_test(
                'negative check_task creature from another lab (session-bound)',
                'expected -20073 (or -20060 for legacy order), got result=' || nvl(to_char(v_check_result), 'NULL')
            );
        exception
            when others then
                if sqlcode in (-20073, -20060) then
                    pass_test('negative check_task creature from another lab (session-bound)');
                else
                    fail_test(
                        'negative check_task creature from another lab (session-bound)',
                        'unexpected sqlcode=' || to_char(sqlcode) || ' message=' || sqlerrm
                    );
                end if;
        end;
    end if;

    cleanup_test_data;
    commit;

    dbms_output.put_line('--- SUMMARY ---');
    dbms_output.put_line('Passed: ' || v_passed_tests);
    dbms_output.put_line('Failed: ' || v_failed_tests);

    if v_failed_tests > 0 then
        raise_application_error(-20600, 'Tasks smoke-test failed. See DBMS_OUTPUT for details.');
    end if;
exception
    when others then
        declare
            v_unhandled_sqlcode number := sqlcode;
            v_unhandled_sqlerrm varchar2(4000) := sqlerrm;
        begin
            dbms_output.put_line('[ERROR] Unhandled exception in 06_tasks_smoke_test: ' || v_unhandled_sqlcode || ' / ' || v_unhandled_sqlerrm);
            begin
                cleanup_test_data;
                commit;
            exception
                when others then
                    dbms_output.put_line('[WARN] Cleanup after error failed: ' || sqlcode || ' / ' || sqlerrm);
            end;

            raise_application_error(
                -20600,
                'Tasks smoke-test failed. Root error: ' || to_char(v_unhandled_sqlcode) || ' / ' || substr(v_unhandled_sqlerrm, 1, 1400)
            );
        end;
end;
/

set serveroutput on size unlimited;
set verify off;

declare
    v_user_id                     number;
    v_lab_id                      number;
    v_login                       varchar2(20);
    v_username                    varchar2(255);
    v_password                    varchar2(100) := 'creature_smoke_123';
    v_session_token               varchar2(128);

    v_initial_creature_count      number := 0;
    v_creature_count_db           number := 0;
    v_species_distinct_count      number := 0;
    v_missing_species_count       number := 0;
    v_creatures_without_genotype  number := 0;
    v_creatures_without_summary   number := 0;

    v_wallet                      number;
    v_rating                      number;
    v_creature_count_stats        number;
    v_active_task_count           number;
    v_completed_task_count        number;
    v_experiment_count            number;

    v_creatures_cursor            sys_refcursor;
    v_c_creature_id               number;
    v_c_lab_id                    number;
    v_c_species_type              number;
    v_c_name                      varchar2(255);
    v_c_color                     varchar2(100);
    v_c_size                      varchar2(100);
    v_c_has_wings                 char(1);
    v_c_nutrition                 varchar2(100);
    v_c_summary                   varchar2(1000);
    v_c_created_at                timestamp;
    v_c_updated_at                timestamp;
    v_creatures_cursor_count      number := 0;

    v_probe_creature_id           number;
    v_genotype_cursor             sys_refcursor;
    v_g_genotype_id               number;
    v_g_creature_id               number;
    v_g_gene_id                   number;
    v_g_gene_name                 varchar2(50);
    v_g_gene_type                 varchar2(50);
    v_g_dominance_type            varchar2(20);
    v_g_allele1_id                number;
    v_g_allele1_desc              varchar2(255);
    v_g_allele1_dominance         number;
    v_g_allele1_trait_value       number;
    v_g_allele2_id                number;
    v_g_allele2_desc              varchar2(255);
    v_g_allele2_dominance         number;
    v_g_allele2_trait_value       number;
    v_genotype_cursor_count       number := 0;

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
        if v_session_token is not null and v_lab_id is not null then
            begin
                pkg_genetics_game.delete_lab(
                    p_session_token => v_session_token,
                    p_lab_id        => v_lab_id
                );
                dbms_output.put_line('[INFO] cleanup: delete_lab done');
            exception
                when others then
                    dbms_output.put_line('[WARN] cleanup delete_lab: ' || sqlcode || ' / ' || sqlerrm);
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
    v_username := 'creature_smoke_' || substr(v_login, 2, 6);

    dbms_output.put_line('Smoke-test login: ' || v_login);
    dbms_output.put_line('--- CREATURE GENERATION SMOKE TEST ---');

    begin
        pkg_genetics_game.register_user(
            p_username => v_username,
            p_login    => v_login,
            p_password => v_password,
            p_user_id  => v_user_id
        );
        assert_true(v_user_id is not null and v_user_id > 0, 'register_user', 'user_id is null or <= 0');
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
            assert_true(v_session_token is not null, 'login_user', 'session_token is null');
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
            assert_true(v_lab_id is not null and v_lab_id > 0, 'start_new_lab', 'lab_id is null or <= 0');
        exception
            when others then
                fail_test('start_new_lab', sqlerrm);
        end;
    end if;

    if v_lab_id is not null then
        begin
            select count(*)
              into v_initial_creature_count
              from creatures c
             where c.lab_id = v_lab_id;

            assert_true(
                v_initial_creature_count = 30,
                'start_new_lab generated 30 creatures',
                'actual=' || v_initial_creature_count
            );
        exception
            when others then
                fail_test('start_new_lab generated 30 creatures', sqlerrm);
        end;

        begin
            select count(*)
              into v_creature_count_db
              from creatures c
             where c.lab_id = v_lab_id;
            assert_true(v_creature_count_db = 30, '30 creatures created', 'actual=' || v_creature_count_db);
        exception
            when others then
                fail_test('30 creatures created', sqlerrm);
        end;

        begin
            select count(distinct c.species_type)
              into v_species_distinct_count
              from creatures c
             where c.lab_id = v_lab_id
               and c.species_type between 1 and 6;

            select count(*)
              into v_missing_species_count
              from (
                    select level as species_type
                      from dual
                   connect by level <= 6
                   ) s
             where not exists (
                    select 1
                      from creatures c
                     where c.lab_id = v_lab_id
                       and c.species_type = s.species_type
                   );

            assert_true(v_species_distinct_count = 6, 'all species_type 1..6 present', 'distinct count=' || v_species_distinct_count);
            assert_true(v_missing_species_count = 0, 'no missing species_type', 'missing count=' || v_missing_species_count);
        exception
            when others then
                fail_test('species_type coverage', sqlerrm);
        end;

        begin
            select count(*)
              into v_creatures_without_genotype
              from creatures c
             where c.lab_id = v_lab_id
               and not exists (
                    select 1
                      from genotypes g
                     where g.creature_id = c.creature_id
               );
            assert_true(v_creatures_without_genotype = 0, 'each creature has genotypes', 'creatures without genotypes=' || v_creatures_without_genotype);
        exception
            when others then
                fail_test('genotype presence', sqlerrm);
        end;

        begin
            select count(*)
              into v_creatures_without_summary
              from creatures c
             where c.lab_id = v_lab_id
               and (c.phenotype_summary is null or length(trim(c.phenotype_summary)) = 0);
            assert_true(v_creatures_without_summary = 0, 'each creature has phenotype_summary', 'creatures without summary=' || v_creatures_without_summary);
        exception
            when others then
                fail_test('phenotype_summary presence', sqlerrm);
        end;

        begin
            v_creatures_cursor_count := 0;
            v_probe_creature_id := null;

            v_creatures_cursor := pkg_genetics_game.get_creatures_cursor(
                p_lab_id => v_lab_id
            );

            loop
                fetch v_creatures_cursor into
                    v_c_creature_id,
                    v_c_lab_id,
                    v_c_species_type,
                    v_c_name,
                    v_c_color,
                    v_c_size,
                    v_c_has_wings,
                    v_c_nutrition,
                    v_c_summary,
                    v_c_created_at,
                    v_c_updated_at;
                exit when v_creatures_cursor%notfound;

                v_creatures_cursor_count := v_creatures_cursor_count + 1;
                if v_probe_creature_id is null then
                    v_probe_creature_id := v_c_creature_id;
                end if;
            end loop;

            close v_creatures_cursor;

            assert_true(v_creatures_cursor_count > 0, 'get_creatures_cursor returns data', 'rowcount=' || v_creatures_cursor_count);
        exception
            when others then
                if v_creatures_cursor%isopen then
                    close v_creatures_cursor;
                end if;
                fail_test('get_creatures_cursor', sqlerrm);
        end;

        if v_probe_creature_id is null then
            begin
                select min(c.creature_id)
                  into v_probe_creature_id
                  from creatures c
                 where c.lab_id = v_lab_id;
            exception
                when others then
                    fail_test('probe creature selection', sqlerrm);
            end;
        end if;

        if v_probe_creature_id is not null then
            begin
                v_genotype_cursor_count := 0;
                v_genotype_cursor := pkg_genetics_game.get_genotype_cursor(
                    p_creature_id => v_probe_creature_id
                );

                loop
                    fetch v_genotype_cursor into
                        v_g_genotype_id,
                        v_g_creature_id,
                        v_g_gene_id,
                        v_g_gene_name,
                        v_g_gene_type,
                        v_g_dominance_type,
                        v_g_allele1_id,
                        v_g_allele1_desc,
                        v_g_allele1_dominance,
                        v_g_allele1_trait_value,
                        v_g_allele2_id,
                        v_g_allele2_desc,
                        v_g_allele2_dominance,
                        v_g_allele2_trait_value;
                    exit when v_genotype_cursor%notfound;

                    v_genotype_cursor_count := v_genotype_cursor_count + 1;
                end loop;

                close v_genotype_cursor;

                assert_true(v_genotype_cursor_count > 0, 'get_genotype_cursor returns data', 'rowcount=' || v_genotype_cursor_count);
            exception
                when others then
                    if v_genotype_cursor%isopen then
                        close v_genotype_cursor;
                    end if;
                    fail_test('get_genotype_cursor', sqlerrm);
            end;
        else
            fail_test('get_genotype_cursor returns data', 'no creature found for probe');
        end if;

        begin
            pkg_genetics_game.get_lab_stats(
                p_lab_id               => v_lab_id,
                p_wallet               => v_wallet,
                p_rating               => v_rating,
                p_creature_count       => v_creature_count_stats,
                p_active_task_count    => v_active_task_count,
                p_completed_task_count => v_completed_task_count,
                p_experiment_count     => v_experiment_count
            );
            assert_true(v_creature_count_stats = 30, 'get_lab_stats creature_count = 30', 'actual=' || v_creature_count_stats);
        exception
            when others then
                fail_test('get_lab_stats creature_count', sqlerrm);
        end;
    end if;

    cleanup_test_data;
    commit;

    dbms_output.put_line('--- SUMMARY ---');
    dbms_output.put_line('Passed: ' || v_passed_tests);
    dbms_output.put_line('Failed: ' || v_failed_tests);

    if v_failed_tests > 0 then
        raise_application_error(-20300, 'Creature generation smoke-test failed. See DBMS_OUTPUT for details.');
    end if;
exception
    when others then
        dbms_output.put_line('[ERROR] Unhandled exception in 03_creature_generation_smoke_test: ' || sqlcode || ' / ' || sqlerrm);
        begin
            cleanup_test_data;
            commit;
        exception
            when others then
                dbms_output.put_line('[WARN] Cleanup after error failed: ' || sqlcode || ' / ' || sqlerrm);
        end;
        raise;
end;
/


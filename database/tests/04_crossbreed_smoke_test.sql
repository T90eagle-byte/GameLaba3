set serveroutput on size unlimited;
set verify off;

declare
    v_user_id                 number;
    v_lab_id                  number;
    v_login                   varchar2(20);
    v_username                varchar2(255);
    v_password                varchar2(100) := 'cross_smoke_123';
    v_session_token           varchar2(128);

    v_initial_creature_count  number := 0;
    v_creature_count_before   number := 0;
    v_species_type            number;
    v_parent1_id              number;
    v_parent2_id              number;
    v_gene_id                 number;

    v_punnett_cursor          sys_refcursor;
    v_prob_allele1_id         number;
    v_prob_allele2_id         number;
    v_probability             number;
    v_prob_allele1_desc       varchar2(255);
    v_prob_allele2_desc       varchar2(255);
    v_punnett_row_count       number := 0;
    v_probability_sum         number := 0;

    v_offspring_id            number;
    v_offspring_name          varchar2(255);
    v_offspring_species       number;
    v_offspring_lab_id        number;
    v_offspring_stored_name   varchar2(255);
    v_offspring_summary       varchar2(1000);
    v_offspring_genotype_cnt  number := 0;

    v_experiment_count_match  number := 0;

    v_wallet                  number;
    v_rating                  number;
    v_creature_count_stats    number;
    v_active_task_count       number;
    v_completed_task_count    number;
    v_experiment_count_stats  number;

    v_new_name                varchar2(255);
    v_renamed_name            varchar2(255);
    v_negative_offspring_id   number;

    v_failed_tests            number := 0;
    v_passed_tests            number := 0;

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
    v_username := 'cross_smoke_' || substr(v_login, 2, 6);

    dbms_output.put_line('Smoke-test login: ' || v_login);
    dbms_output.put_line('--- CROSSBREED SMOKE TEST ---');

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
                fail_test('starting creatures preparation', sqlerrm);
        end;

        begin
            select count(*)
              into v_creature_count_before
              from creatures c
             where c.lab_id = v_lab_id;
            assert_true(v_creature_count_before = 30, 'starting creature count = 30', 'actual=' || v_creature_count_before);
        exception
            when others then
                fail_test('starting creature count', sqlerrm);
        end;

        begin
            select species_type
              into v_species_type
              from (
                    select c.species_type
                      from creatures c
                     where c.lab_id = v_lab_id
                     group by c.species_type
                    having count(*) >= 2
                     order by c.species_type
              )
             where rownum = 1;
            pass_test('species_type with two parents found');
        exception
            when no_data_found then
                fail_test('species_type with two parents found', 'no species has at least two creatures');
            when others then
                fail_test('species_type with two parents found', sqlerrm);
        end;

        if v_species_type is not null then
            begin
                select creature_id
                  into v_parent1_id
                  from (
                        select
                            c.creature_id,
                            row_number() over (order by c.creature_id) as rn
                          from creatures c
                         where c.lab_id = v_lab_id
                           and c.species_type = v_species_type
                  )
                 where rn = 1;

                select creature_id
                  into v_parent2_id
                  from (
                        select
                            c.creature_id,
                            row_number() over (order by c.creature_id) as rn
                          from creatures c
                         where c.lab_id = v_lab_id
                           and c.species_type = v_species_type
                  )
                 where rn = 2;

                assert_true(v_parent1_id is not null and v_parent2_id is not null and v_parent1_id <> v_parent2_id, 'two different parents selected');
            exception
                when others then
                    fail_test('two different parents selected', sqlerrm);
            end;
        end if;

        if v_parent1_id is not null and v_parent2_id is not null then
            begin
                select min(gp1.gene_id)
                  into v_gene_id
                  from genotypes gp1
                  join genotypes gp2
                    on gp2.gene_id = gp1.gene_id
                   and gp2.creature_id = v_parent2_id
                 where gp1.creature_id = v_parent1_id;

                assert_true(v_gene_id is not null, 'common gene selected');
            exception
                when others then
                    fail_test('common gene selected', sqlerrm);
            end;
        end if;

        if v_parent1_id is not null and v_parent2_id is not null and v_gene_id is not null then
            begin
                v_punnett_row_count := 0;
                v_probability_sum := 0;

                v_punnett_cursor := pkg_genetics_game.calculate_punnett_probabilities(
                    p_parent1_id => v_parent1_id,
                    p_parent2_id => v_parent2_id,
                    p_gene_id    => v_gene_id
                );

                loop
                    fetch v_punnett_cursor into
                        v_prob_allele1_id,
                        v_prob_allele2_id,
                        v_probability,
                        v_prob_allele1_desc,
                        v_prob_allele2_desc;
                    exit when v_punnett_cursor%notfound;

                    v_punnett_row_count := v_punnett_row_count + 1;
                    v_probability_sum := v_probability_sum + nvl(v_probability, 0);
                end loop;

                close v_punnett_cursor;

                assert_true(v_punnett_row_count > 0, 'calculate_punnett_probabilities returned rows', 'rowcount=' || v_punnett_row_count);
                assert_true(abs(v_probability_sum - 1) <= 0.0001, 'probability sum ~= 1', 'actual sum=' || to_char(v_probability_sum));
            exception
                when others then
                    if v_punnett_cursor%isopen then
                        close v_punnett_cursor;
                    end if;
                    fail_test('calculate_punnett_probabilities', sqlerrm);
            end;
        end if;

        if v_parent1_id is not null and v_parent2_id is not null then
            begin
                v_offspring_name := 'offspring_' || substr(v_login, 2, 8);

                pkg_genetics_game.crossbreed(
                    p_lab_id         => v_lab_id,
                    p_parent1_id     => v_parent1_id,
                    p_parent2_id     => v_parent2_id,
                    p_offspring_name => v_offspring_name,
                    p_offspring_id   => v_offspring_id
                );

                assert_true(v_offspring_id is not null and v_offspring_id > 0, 'crossbreed offspring_id');
            exception
                when others then
                    fail_test('crossbreed', sqlerrm);
            end;
        end if;

        if v_offspring_id is not null then
            begin
                select
                    c.lab_id,
                    c.species_type,
                    c.creature_name,
                    c.phenotype_summary
                  into
                    v_offspring_lab_id,
                    v_offspring_species,
                    v_offspring_stored_name,
                    v_offspring_summary
                  from creatures c
                 where c.creature_id = v_offspring_id;

                assert_true(v_offspring_lab_id = v_lab_id, 'offspring exists in creatures and lab matches');
                assert_true(v_offspring_species = v_species_type, 'offspring species matches parents', 'expected=' || v_species_type || ', actual=' || v_offspring_species);
                assert_true(v_offspring_summary is not null and length(trim(v_offspring_summary)) > 0, 'offspring phenotype_summary filled');
            exception
                when no_data_found then
                    fail_test('offspring exists in creatures', 'no row for offspring_id=' || v_offspring_id);
                when others then
                    fail_test('offspring exists in creatures', sqlerrm);
            end;

            begin
                select count(*)
                  into v_offspring_genotype_cnt
                  from genotypes g
                 where g.creature_id = v_offspring_id;
                assert_true(v_offspring_genotype_cnt > 0, 'offspring has genotypes', 'rowcount=' || v_offspring_genotype_cnt);
            exception
                when others then
                    fail_test('offspring has genotypes', sqlerrm);
            end;

            begin
                select count(*)
                  into v_experiment_count_match
                  from experiments e
                 where e.lab_id = v_lab_id
                   and e.experiment_type = 'CROSS'
                   and e.parent1_id = v_parent1_id
                   and e.parent2_id = v_parent2_id
                   and e.offspring_id = v_offspring_id
                   and e.mutation_id is null;
                assert_true(v_experiment_count_match >= 1, 'cross experiment row exists', 'rowcount=' || v_experiment_count_match);
            exception
                when others then
                    fail_test('cross experiment row exists', sqlerrm);
            end;

            begin
                pkg_genetics_game.get_lab_stats(
                    p_lab_id               => v_lab_id,
                    p_wallet               => v_wallet,
                    p_rating               => v_rating,
                    p_creature_count       => v_creature_count_stats,
                    p_active_task_count    => v_active_task_count,
                    p_completed_task_count => v_completed_task_count,
                    p_experiment_count     => v_experiment_count_stats
                );
                assert_true(v_creature_count_stats = 31, 'get_lab_stats creature_count = 31', 'actual=' || v_creature_count_stats);
                assert_true(v_experiment_count_stats >= 1, 'get_lab_stats experiment_count >= 1', 'actual=' || v_experiment_count_stats);
            exception
                when others then
                    fail_test('get_lab_stats after crossbreed', sqlerrm);
            end;

            begin
                v_new_name := 'renamed_' || substr(v_login, 2, 8);

                pkg_genetics_game.rename_creature(
                    p_creature_id => v_offspring_id,
                    p_new_name    => v_new_name
                );

                select c.creature_name
                  into v_renamed_name
                  from creatures c
                 where c.creature_id = v_offspring_id;

                assert_true(v_renamed_name = trim(v_new_name), 'rename_creature updated creature_name');
            exception
                when others then
                    fail_test('rename_creature', sqlerrm);
            end;
        end if;

        if v_parent1_id is not null then
            begin
                pkg_genetics_game.crossbreed(
                    p_lab_id         => v_lab_id,
                    p_parent1_id     => v_parent1_id,
                    p_parent2_id     => v_parent1_id,
                    p_offspring_name => 'invalid_same_parent',
                    p_offspring_id   => v_negative_offspring_id
                );

                fail_test('crossbreed same parent negative case', 'expected error was not raised');
            exception
                when others then
                    if sqlcode = -20032 then
                        pass_test('crossbreed same parent negative case');
                    else
                        fail_test(
                            'crossbreed same parent negative case',
                            'unexpected error code=' || to_char(sqlcode) || ' message=' || sqlerrm
                        );
                    end if;
            end;
        end if;
    end if;

    cleanup_test_data;
    commit;

    dbms_output.put_line('--- SUMMARY ---');
    dbms_output.put_line('Passed: ' || v_passed_tests);
    dbms_output.put_line('Failed: ' || v_failed_tests);

    if v_failed_tests > 0 then
        raise_application_error(-20400, 'Crossbreed smoke-test failed. See DBMS_OUTPUT for details.');
    end if;
exception
    when others then
        dbms_output.put_line('[ERROR] Unhandled exception in 04_crossbreed_smoke_test: ' || sqlcode || ' / ' || sqlerrm);
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


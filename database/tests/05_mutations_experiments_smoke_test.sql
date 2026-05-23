set serveroutput on size unlimited;
set verify off;

declare
    v_user_id                         number;
    v_lab_id                          number;
    v_login                           varchar2(20);
    v_username                        varchar2(255);
    v_password                        varchar2(100) := 'mutexp_smoke_123';
    v_session_token                   varchar2(128);

    v_initial_creature_count          number := 0;

    v_shop_cursor                     sys_refcursor;
    v_shop_mutation_id                number;
    v_shop_mutation_name              varchar2(50);
    v_shop_mutation_type              number;
    v_shop_description                varchar2(255);
    v_shop_price                      number;
    v_shop_rating_effect              number;
    v_shop_row_count                  number := 0;

    v_mutation_id                     number;
    v_mutation_gene_id                number;
    v_target_creature_id              number;

    v_wallet_before_buy               number;
    v_wallet_after_buy                number;
    v_buy_result                      number;
    v_stock_before                    number := 0;
    v_stock_after                     number := 0;
    v_stock_after_apply               number := 0;

    v_mutation_experiment_count       number := 0;
    v_source_species_type             number;
    v_mutagen_new_creature_id         number;
    v_mutagen_new_species_type        number;
    v_mutagen_genotype_count          number := 0;
    v_mutagen_phenotype_summary       varchar2(1000);
    v_mutagen_experiment_count        number := 0;

    v_cross_species_type              number;
    v_cross_parent1_id                number;
    v_cross_parent2_id                number;
    v_make_cross_offspring_id         number;
    v_cross_experiment_count          number := 0;

    v_buy_result_for_make_mut         number;
    v_make_mut_parent_id              number;
    v_make_mut_offspring_id           number;
    v_mutation_count_before_make      number := 0;
    v_mutation_count_after_make       number := 0;

    v_history_cursor                  sys_refcursor;
    v_h_experiment_id                 number;
    v_h_experiment_type               varchar2(20);
    v_h_parent1_id                    number;
    v_h_parent1_name                  varchar2(255);
    v_h_parent2_id                    number;
    v_h_parent2_name                  varchar2(255);
    v_h_offspring_id                  number;
    v_h_offspring_name                varchar2(255);
    v_h_mutation_id                   number;
    v_h_mutation_name                 varchar2(50);
    v_h_created_at                    timestamp;
    v_history_row_count               number := 0;
    v_history_has_cross               number := 0;
    v_history_has_mutation            number := 0;
    v_history_has_mutagen             number := 0;

    v_wallet_stats                    number;
    v_rating_stats                    number;
    v_creature_count_stats            number;
    v_active_task_count_stats         number;
    v_completed_task_count_stats      number;
    v_experiment_count_stats          number;

    v_invalid_buy_result              number;
    v_unavailable_mutation_id         number;
    v_unavailable_creature_id         number;
    v_dummy_offspring_id              number;

    v_failed_tests                    number := 0;
    v_passed_tests                    number := 0;

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
    v_username := 'mutexp_smoke_' || substr(v_login, 2, 6);

    dbms_output.put_line('Smoke-test login: ' || v_login);
    dbms_output.put_line('--- MUTATIONS / EXPERIMENTS SMOKE TEST ---');

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
                fail_test('prepare starting creatures', sqlerrm);
        end;
    end if;

    -- 5) show_mutation_shop
    begin
        v_shop_row_count := 0;
        v_shop_cursor := pkg_genetics_game.show_mutation_shop();

        loop
            fetch v_shop_cursor into
                v_shop_mutation_id,
                v_shop_mutation_name,
                v_shop_mutation_type,
                v_shop_description,
                v_shop_price,
                v_shop_rating_effect;
            exit when v_shop_cursor%notfound;

            v_shop_row_count := v_shop_row_count + 1;
        end loop;

        close v_shop_cursor;
        assert_true(v_shop_row_count > 0, 'show_mutation_shop returns rows', 'rowcount=' || v_shop_row_count);
    exception
        when others then
            if v_shop_cursor%isopen then
                close v_shop_cursor;
            end if;
            fail_test('show_mutation_shop', sqlerrm);
    end;

    -- 6/8) select mutation with rules and compatible creature in lab
    if v_lab_id is not null then
        begin
            select
                t.mutation_id,
                t.gene_id,
                t.creature_id
              into
                v_mutation_id,
                v_mutation_gene_id,
                v_target_creature_id
              from (
                    select
                        mr.mutation_id,
                        mr.gene_id,
                        c.creature_id
                      from mutation_rules mr
                      join genotypes g
                        on g.gene_id = mr.gene_id
                      join creatures c
                        on c.creature_id = g.creature_id
                       and c.lab_id = v_lab_id
                     order by mr.mutation_id, c.creature_id
              ) t
             where rownum = 1;

            assert_true(v_mutation_id is not null and v_target_creature_id is not null, 'mutation with rules and compatible creature selected');
        exception
            when no_data_found then
                fail_test('mutation with rules and compatible creature selected', 'no matching mutation_rules for creatures in lab');
            when others then
                fail_test('mutation with rules and compatible creature selected', sqlerrm);
        end;
    end if;

    -- 7) buy_mutation success path
    if v_lab_id is not null and v_mutation_id is not null then
        begin
            select l.wallet
              into v_wallet_before_buy
              from labs l
             where l.lab_id = v_lab_id;

            select nvl(max(lm.quantity), 0)
              into v_stock_before
              from lab_mutations lm
             where lm.lab_id = v_lab_id
               and lm.mutation_id = v_mutation_id;

            v_buy_result := pkg_genetics_game.buy_mutation(
                p_lab_id      => v_lab_id,
                p_mutation_id => v_mutation_id
            );

            select l.wallet
              into v_wallet_after_buy
              from labs l
             where l.lab_id = v_lab_id;

            select nvl(max(lm.quantity), 0)
              into v_stock_after
              from lab_mutations lm
             where lm.lab_id = v_lab_id
               and lm.mutation_id = v_mutation_id;

            assert_true(v_buy_result = 1, 'buy_mutation success result');
            assert_true(v_wallet_after_buy < v_wallet_before_buy, 'wallet decreased after buy_mutation');
            assert_true(v_stock_after = v_stock_before + 1, 'lab_mutations quantity increased', 'before=' || v_stock_before || ', after=' || v_stock_after);
        exception
            when others then
                fail_test('buy_mutation success path', sqlerrm);
        end;
    end if;

    -- 9) apply_mutation success path
    if v_target_creature_id is not null and v_mutation_id is not null then
        begin
            pkg_genetics_game.apply_mutation(
                p_creature_id => v_target_creature_id,
                p_mutation_id => v_mutation_id
            );

            select nvl(max(lm.quantity), 0)
              into v_stock_after_apply
              from lab_mutations lm
             where lm.lab_id = v_lab_id
               and lm.mutation_id = v_mutation_id;

            assert_true(v_stock_after_apply = v_stock_after - 1, 'apply_mutation decreases stock', 'before apply=' || v_stock_after || ', after=' || v_stock_after_apply);

            select c.phenotype_summary
              into v_mutagen_phenotype_summary
              from creatures c
             where c.creature_id = v_target_creature_id;
            assert_true(v_mutagen_phenotype_summary is not null and length(trim(v_mutagen_phenotype_summary)) > 0, 'apply_mutation keeps phenotype_summary filled');

            select count(*)
              into v_mutation_experiment_count
              from experiments e
             where e.lab_id = v_lab_id
               and e.experiment_type = 'MUTATION'
               and e.parent1_id = v_target_creature_id
               and e.parent2_id is null
               and e.mutation_id = v_mutation_id
               and e.offspring_id = v_target_creature_id;

            assert_true(v_mutation_experiment_count >= 1, 'MUTATION experiment row created');
        exception
            when others then
                fail_test('apply_mutation success path', sqlerrm);
        end;
    end if;

    -- 10) apply_mutagen path
    if v_target_creature_id is not null then
        begin
            select c.species_type
              into v_source_species_type
              from creatures c
             where c.creature_id = v_target_creature_id;

            pkg_genetics_game.apply_mutagen(
                p_creature_id     => v_target_creature_id,
                p_mutagen_type    => 'RADIATION',
                p_new_creature_id => v_mutagen_new_creature_id
            );

            assert_true(v_mutagen_new_creature_id is not null and v_mutagen_new_creature_id > 0, 'apply_mutagen returns new creature id');

            select
                c.species_type,
                c.phenotype_summary
              into
                v_mutagen_new_species_type,
                v_mutagen_phenotype_summary
              from creatures c
             where c.creature_id = v_mutagen_new_creature_id;

            assert_true(v_mutagen_new_species_type = v_source_species_type, 'mutagen offspring species_type matches source');
            assert_true(v_mutagen_phenotype_summary is not null and length(trim(v_mutagen_phenotype_summary)) > 0, 'mutagen offspring phenotype_summary filled');

            select count(*)
              into v_mutagen_genotype_count
              from genotypes g
             where g.creature_id = v_mutagen_new_creature_id;
            assert_true(v_mutagen_genotype_count > 0, 'mutagen offspring has genotypes');

            select count(*)
              into v_mutagen_experiment_count
              from experiments e
             where e.lab_id = v_lab_id
               and e.experiment_type = 'MUTAGEN'
               and e.parent1_id = v_target_creature_id
               and e.parent2_id is null
               and e.mutation_id is null
               and e.offspring_id = v_mutagen_new_creature_id;

            assert_true(v_mutagen_experiment_count >= 1, 'MUTAGEN experiment row created');
        exception
            when others then
                fail_test('apply_mutagen path', sqlerrm);
        end;
    end if;

    -- 11) make_experiment CROSS branch
    if v_lab_id is not null then
        begin
            select species_type
              into v_cross_species_type
              from (
                    select c.species_type
                      from creatures c
                     where c.lab_id = v_lab_id
                     group by c.species_type
                    having count(*) >= 2
                     order by c.species_type
              )
             where rownum = 1;

            select creature_id
              into v_cross_parent1_id
              from (
                    select
                        c.creature_id,
                        row_number() over (order by c.creature_id) as rn
                      from creatures c
                     where c.lab_id = v_lab_id
                       and c.species_type = v_cross_species_type
              )
             where rn = 1;

            select creature_id
              into v_cross_parent2_id
              from (
                    select
                        c.creature_id,
                        row_number() over (order by c.creature_id) as rn
                      from creatures c
                     where c.lab_id = v_lab_id
                       and c.species_type = v_cross_species_type
              )
             where rn = 2;

            pkg_genetics_game.make_experiment(
                p_lab_id         => v_lab_id,
                p_parent1_id     => v_cross_parent1_id,
                p_parent2_id     => v_cross_parent2_id,
                p_mutation_id    => null,
                p_offspring_name => 'mk_cross_' || substr(v_login, 2, 8),
                p_offspring_id   => v_make_cross_offspring_id
            );

            assert_true(v_make_cross_offspring_id is not null and v_make_cross_offspring_id > 0, 'make_experiment CROSS created offspring');

            select count(*)
              into v_cross_experiment_count
              from experiments e
             where e.lab_id = v_lab_id
               and e.experiment_type = 'CROSS'
               and e.parent1_id = v_cross_parent1_id
               and e.parent2_id = v_cross_parent2_id
               and e.offspring_id = v_make_cross_offspring_id;

            assert_true(v_cross_experiment_count >= 1, 'make_experiment CROSS experiment row created');
        exception
            when others then
                fail_test('make_experiment CROSS branch', sqlerrm);
        end;
    end if;

    -- 12) make_experiment MUTATION branch
    if v_lab_id is not null and v_mutation_id is not null then
        begin
            v_buy_result_for_make_mut := pkg_genetics_game.buy_mutation(
                p_lab_id      => v_lab_id,
                p_mutation_id => v_mutation_id
            );
            assert_true(v_buy_result_for_make_mut = 1, 'buy_mutation for make_experiment MUTATION branch');
        exception
            when others then
                fail_test('buy_mutation for make_experiment MUTATION branch', sqlerrm);
        end;

        begin
            select t.creature_id
              into v_make_mut_parent_id
              from (
                    select distinct c.creature_id
                      from creatures c
                      join genotypes g
                        on g.creature_id = c.creature_id
                      join mutation_rules mr
                        on mr.gene_id = g.gene_id
                     where c.lab_id = v_lab_id
                       and mr.mutation_id = v_mutation_id
                     order by c.creature_id
              ) t
             where rownum = 1;
        exception
            when others then
                fail_test('select parent for make_experiment MUTATION branch', sqlerrm);
        end;

        if v_make_mut_parent_id is not null then
            begin
                select count(*)
                  into v_mutation_count_before_make
                  from experiments e
                 where e.lab_id = v_lab_id
                   and e.experiment_type = 'MUTATION'
                   and e.parent1_id = v_make_mut_parent_id
                   and e.parent2_id is null
                   and e.mutation_id = v_mutation_id
                   and e.offspring_id = v_make_mut_parent_id;

                pkg_genetics_game.make_experiment(
                    p_lab_id         => v_lab_id,
                    p_parent1_id     => v_make_mut_parent_id,
                    p_parent2_id     => null,
                    p_mutation_id    => v_mutation_id,
                    p_offspring_name => 'ignored_for_mutation_branch',
                    p_offspring_id   => v_make_mut_offspring_id
                );

                assert_true(v_make_mut_offspring_id = v_make_mut_parent_id, 'make_experiment MUTATION branch returns parent as offspring');

                select count(*)
                  into v_mutation_count_after_make
                  from experiments e
                 where e.lab_id = v_lab_id
                   and e.experiment_type = 'MUTATION'
                   and e.parent1_id = v_make_mut_parent_id
                   and e.parent2_id is null
                   and e.mutation_id = v_mutation_id
                   and e.offspring_id = v_make_mut_parent_id;

                assert_true(v_mutation_count_after_make = v_mutation_count_before_make + 1, 'make_experiment MUTATION experiment row created');
            exception
                when others then
                    fail_test('make_experiment MUTATION branch', sqlerrm);
            end;
        end if;
    end if;

    -- 13) get_experiment_history
    if v_lab_id is not null then
        begin
            v_history_row_count := 0;
            v_history_has_cross := 0;
            v_history_has_mutation := 0;
            v_history_has_mutagen := 0;

            v_history_cursor := pkg_genetics_game.get_experiment_history(
                p_lab_id => v_lab_id
            );

            loop
                fetch v_history_cursor into
                    v_h_experiment_id,
                    v_h_experiment_type,
                    v_h_parent1_id,
                    v_h_parent1_name,
                    v_h_parent2_id,
                    v_h_parent2_name,
                    v_h_offspring_id,
                    v_h_offspring_name,
                    v_h_mutation_id,
                    v_h_mutation_name,
                    v_h_created_at;
                exit when v_history_cursor%notfound;

                v_history_row_count := v_history_row_count + 1;
                if v_h_experiment_type = 'CROSS' then
                    v_history_has_cross := 1;
                elsif v_h_experiment_type = 'MUTATION' then
                    v_history_has_mutation := 1;
                elsif v_h_experiment_type = 'MUTAGEN' then
                    v_history_has_mutagen := 1;
                end if;
            end loop;

            close v_history_cursor;

            assert_true(v_history_row_count > 0, 'get_experiment_history returns rows', 'rowcount=' || v_history_row_count);
            assert_true(v_history_has_cross = 1, 'history contains CROSS');
            assert_true(v_history_has_mutation = 1, 'history contains MUTATION');
            assert_true(v_history_has_mutagen = 1, 'history contains MUTAGEN');
        exception
            when others then
                if v_history_cursor%isopen then
                    close v_history_cursor;
                end if;
                fail_test('get_experiment_history', sqlerrm);
        end;
    end if;

    -- 14) get_lab_stats
    if v_lab_id is not null then
        begin
            pkg_genetics_game.get_lab_stats(
                p_lab_id               => v_lab_id,
                p_wallet               => v_wallet_stats,
                p_rating               => v_rating_stats,
                p_creature_count       => v_creature_count_stats,
                p_active_task_count    => v_active_task_count_stats,
                p_completed_task_count => v_completed_task_count_stats,
                p_experiment_count     => v_experiment_count_stats
            );

            assert_true(v_experiment_count_stats >= 3, 'get_lab_stats experiment_count >= 3', 'actual=' || v_experiment_count_stats);
            assert_true(v_creature_count_stats >= 32, 'get_lab_stats creature_count increased', 'actual=' || v_creature_count_stats);
        exception
            when others then
                fail_test('get_lab_stats after mutations/experiments', sqlerrm);
        end;
    end if;

    -- 15a) negative: buy_mutation with non-existing mutation id
    if v_lab_id is not null then
        begin
            v_invalid_buy_result := pkg_genetics_game.buy_mutation(
                p_lab_id      => v_lab_id,
                p_mutation_id => -999999
            );
            fail_test('negative buy_mutation non-existing mutation', 'expected -20041, got return=' || nvl(to_char(v_invalid_buy_result), 'NULL'));
        exception
            when others then
                if sqlcode = -20041 then
                    pass_test('negative buy_mutation non-existing mutation');
                else
                    fail_test(
                        'negative buy_mutation non-existing mutation',
                        'unexpected sqlcode=' || to_char(sqlcode) || ' message=' || sqlerrm
                    );
                end if;
        end;
    end if;

    -- 15b) negative: apply_mutation without inventory -> expect -20043
    if v_lab_id is not null then
        begin
            select t.mutation_id, t.creature_id
              into v_unavailable_mutation_id, v_unavailable_creature_id
              from (
                    select
                        mr.mutation_id,
                        c.creature_id
                      from mutation_rules mr
                      join genotypes g
                        on g.gene_id = mr.gene_id
                      join creatures c
                        on c.creature_id = g.creature_id
                       and c.lab_id = v_lab_id
                     where not exists (
                            select 1
                              from lab_mutations lm
                             where lm.lab_id = v_lab_id
                               and lm.mutation_id = mr.mutation_id
                       )
                     order by mr.mutation_id, c.creature_id
              ) t
             where rownum = 1;
        exception
            when no_data_found then
                v_unavailable_mutation_id := null;
                v_unavailable_creature_id := null;
                dbms_output.put_line('[WARN] skip negative -20043: no mutation without inventory found');
            when others then
                fail_test('prepare negative apply_mutation -20043', sqlerrm);
        end;

        if v_unavailable_mutation_id is not null and v_unavailable_creature_id is not null then
            begin
                pkg_genetics_game.apply_mutation(
                    p_creature_id => v_unavailable_creature_id,
                    p_mutation_id => v_unavailable_mutation_id
                );
                fail_test('negative apply_mutation without inventory', 'expected -20043');
            exception
                when others then
                    if sqlcode = -20043 then
                        pass_test('negative apply_mutation without inventory');
                    else
                        fail_test(
                            'negative apply_mutation without inventory',
                            'unexpected sqlcode=' || to_char(sqlcode) || ' message=' || sqlerrm
                        );
                    end if;
            end;
        end if;
    end if;

    -- 15c) negative: apply_mutation with exhausted quantity -> expect -20044
    if v_make_mut_parent_id is not null and v_mutation_id is not null then
        begin
            pkg_genetics_game.apply_mutation(
                p_creature_id => v_make_mut_parent_id,
                p_mutation_id => v_mutation_id
            );
            fail_test('negative apply_mutation exhausted quantity', 'expected -20044');
        exception
            when others then
                if sqlcode = -20044 then
                    pass_test('negative apply_mutation exhausted quantity');
                else
                    fail_test(
                        'negative apply_mutation exhausted quantity',
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
        raise_application_error(-20500, 'Mutations/experiments smoke-test failed. See DBMS_OUTPUT for details.');
    end if;
exception
    when others then
        dbms_output.put_line('[ERROR] Unhandled exception in 05_mutations_experiments_smoke_test: ' || sqlcode || ' / ' || sqlerrm);
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


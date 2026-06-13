create or replace package body pkg_genetics_game as
    c_err_not_implemented constant number := -20999;
    g_current_user_id       number;
    g_current_session_id    number;
    g_current_session_token varchar2(128);
    g_current_lab_id        number;

    procedure clear_current_session_context is
    begin
        g_current_user_id := null;
        g_current_session_id := null;
        g_current_session_token := null;
        g_current_lab_id := null;
    end clear_current_session_context;

    procedure set_current_session_context(
        p_user_id       in number,
        p_session_id    in number,
        p_session_token in varchar2
    ) is
    begin
        g_current_user_id := p_user_id;
        g_current_session_id := p_session_id;
        g_current_session_token := p_session_token;
        g_current_lab_id := null;
    end set_current_session_context;
    procedure require_current_session is
        v_active_session_count number;
    begin
        if g_current_user_id is null
           or g_current_session_id is null
           or g_current_session_token is null then
            raise_application_error(-20066, 'Session context is not initialized. Call login_user first.');
        end if;

        select count(*)
          into v_active_session_count
          from sessions s
         where s.session_id = g_current_session_id
           and s.user_id = g_current_user_id
           and s.session_token = g_current_session_token
           and s.status = 'ACTIVE';

        if v_active_session_count = 0 then
            clear_current_session_context();
            raise_application_error(-20067, 'Session context is not active. Please login again.');
        end if;
    end require_current_session;

    procedure assert_lab_access(
        p_lab_id in number
    ) is
        v_lab_user_id    number;
        v_lab_session_id number;
    begin
        require_current_session();

        begin
            select l.user_id, l.session_id
              into v_lab_user_id, v_lab_session_id
              from labs l
             where l.lab_id = p_lab_id;
        exception
            when no_data_found then
                raise_application_error(-20057, 'Lab not found.');
        end;

        if v_lab_user_id <> g_current_user_id then
            raise_application_error(-20068, 'Access denied for selected lab.');
        end if;

        if g_current_lab_id is null or p_lab_id <> g_current_lab_id then
            raise_application_error(-20073, 'Selected lab is not active in current session.');
        end if;

        if v_lab_session_id is null or v_lab_session_id <> g_current_session_id then
            raise_application_error(-20073, 'Selected lab is not active in current session.');
        end if;
    end assert_lab_access;

    function assert_creature_access(
        p_creature_id     in number,
        p_expected_lab_id in number default null
    ) return number is
        v_lab_id      number;
        v_lab_user_id number;
    begin
        require_current_session();

        begin
            select c.lab_id, l.user_id
              into v_lab_id, v_lab_user_id
              from creatures c
              join labs l
                on l.lab_id = c.lab_id
             where c.creature_id = p_creature_id;
        exception
            when no_data_found then
                raise_application_error(-20059, 'Creature not found.');
        end;

        if v_lab_user_id <> g_current_user_id then
            raise_application_error(-20069, 'Access denied for selected creature.');
        end if;

        assert_lab_access(
            p_lab_id => v_lab_id
        );

        if p_expected_lab_id is not null and v_lab_id <> p_expected_lab_id then
            raise_application_error(-20060, 'Creature does not belong to the selected lab.');
        end if;

        return v_lab_id;
    end assert_creature_access;
    function hash_password_sha256(
        p_password in varchar2
    ) return varchar2 is
    begin
        if p_password is null then
            raise_application_error(-20010, 'Password cannot be null.');
        end if;

        return lower(
            rawtohex(
                dbms_crypto.hash(
                    utl_i18n.string_to_raw(p_password, 'AL32UTF8'),
                    dbms_crypto.hash_sh256
                )
            )
        );
    end hash_password_sha256;

    function generate_session_token
    return varchar2 is
    begin
        return lower(rawtohex(sys_guid()) || rawtohex(sys_guid()));
    end generate_session_token;

    procedure get_active_session(
        p_session_token in varchar2,
        p_session_id    out number,
        p_user_id       out number
    ) is
    begin
        select s.session_id, s.user_id
          into p_session_id, p_user_id
          from sessions s
         where s.session_token = p_session_token
           and s.status = 'ACTIVE';
    exception
        when no_data_found then
            raise_application_error(-20020, 'Active session not found.');
    end get_active_session;

    function resolve_user_id_by_token(
        p_session_token in varchar2
    ) return number is
        v_user_id number;
    begin
        select s.user_id
          into v_user_id
          from sessions s
         where s.session_token = p_session_token
           and s.status = 'ACTIVE';

        return v_user_id;
    exception
        when no_data_found then
            return null;
    end resolve_user_id_by_token;

    procedure assign_starting_tasks(
        p_lab_id in number
    ) is
    begin
        insert into lab_tasks (
            lab_task_id,
            lab_id,
            task_id,
            task_status,
            assigned_at,
            completed_at
        )
        select
            lab_tasks_seq.nextval,
            p_lab_id,
            seeded_tasks.task_id,
            'ACTIVE',
            systimestamp,
            null
          from (
                select t.task_id
                  from tasks t
                 order by t.task_id
          ) seeded_tasks
         where rownum <= 3
           and not exists (
                select 1
                  from lab_tasks lt
                 where lt.lab_id = p_lab_id
                   and lt.task_id = seeded_tasks.task_id
           );
    end assign_starting_tasks;

    procedure refill_active_tasks(
        p_lab_id         in number,
        p_target_active  in number default 3
    ) is
        v_lab_exists_count  number;
        v_target_active     number := nvl(p_target_active, 3);
        v_active_count      number;
        v_missing_count     number;
    begin
        if v_target_active <= 0 then
            return;
        end if;

        select count(*)
          into v_lab_exists_count
          from labs l
         where l.lab_id = p_lab_id;

        if v_lab_exists_count = 0 then
            raise_application_error(-20057, 'Lab not found.');
        end if;

        select count(*)
          into v_active_count
          from lab_tasks lt
         where lt.lab_id = p_lab_id
           and lt.task_status = 'ACTIVE';

        if v_active_count >= v_target_active then
            return;
        end if;

        v_missing_count := v_target_active - v_active_count;
        if v_missing_count <= 0 then
            return;
        end if;

        begin
            insert into lab_tasks (
                lab_task_id,
                lab_id,
                task_id,
                task_status,
                assigned_at,
                completed_at
            )
            select
                lab_tasks_seq.nextval,
                p_lab_id,
                candidate_tasks.task_id,
                'ACTIVE',
                systimestamp,
                null
              from (
                    select t.task_id
                      from tasks t
                     where not exists (
                            select 1
                              from lab_tasks lt
                             where lt.lab_id = p_lab_id
                               and lt.task_id = t.task_id
                     )
                     order by t.task_id
              ) candidate_tasks
             where rownum <= v_missing_count;
        exception
            when dup_val_on_index then
                null;
        end;
    end refill_active_tasks;

    function pick_random_allele_side
    return pls_integer is
    begin
        if dbms_random.value(0, 1) < 0.5 then
            return 1;
        end if;

        return 2;
    end pick_random_allele_side;

    procedure register_user(
        p_username      in varchar2,
        p_login         in varchar2,
        p_password      in varchar2,
        p_user_id       out number
    ) is
        v_login_count    number;
        v_password_hash  varchar2(64);
    begin
        if p_username is null then
            raise_application_error(-20001, 'Username cannot be null.');
        end if;

        if p_login is null then
            raise_application_error(-20002, 'Login cannot be null.');
        end if;

        if not regexp_like(p_login, '^[a-z][a-z0-9_]{0,19}$') then
            raise_application_error(-20003, 'Invalid login format.');
        end if;

        if p_password is null then
            raise_application_error(-20004, 'Password cannot be null.');
        end if;

        select count(*)
          into v_login_count
          from users u
         where u.login = p_login;

        if v_login_count > 0 then
            raise_application_error(-20005, 'Login already exists.');
        end if;

        v_password_hash := hash_password_sha256(p_password);
        p_user_id := users_seq.nextval;

        insert into users (
            user_id,
            username,
            login,
            password_hash
        ) values (
            p_user_id,
            p_username,
            p_login,
            v_password_hash
        );
    exception
        when dup_val_on_index then
            raise_application_error(-20005, 'Login already exists.');
    end register_user;

    function login_user(
        p_login         in varchar2,
        p_password      in varchar2
    ) return varchar2 is
        v_user_id         number;
        v_password_hash   varchar2(64);
        v_session_id      number;
        v_session_token   varchar2(128);
    begin
        select u.user_id, u.password_hash
          into v_user_id, v_password_hash
          from users u
         where u.login = p_login;

        if v_password_hash <> hash_password_sha256(p_password) then
            return null;
        end if;

        v_session_id := sessions_seq.nextval;
        v_session_token := generate_session_token();

        insert into sessions (
            session_id,
            user_id,
            session_token,
            status,
            started_at,
            ended_at
        ) values (
            v_session_id,
            v_user_id,
            v_session_token,
            'ACTIVE',
            systimestamp,
            null
        );

        set_current_session_context(
            p_user_id       => v_user_id,
            p_session_id    => v_session_id,
            p_session_token => v_session_token
        );

        return v_session_token;
    exception
        when no_data_found then
            return null;
        when others then
            return null;
    end login_user;

    procedure logout_user(
        p_session_token in varchar2
    ) is
    begin
        update sessions s
           set s.status = 'CLOSED',
               s.ended_at = systimestamp
         where s.session_token = p_session_token
           and s.status = 'ACTIVE';

        if sql%rowcount = 0 then
            raise_application_error(-20021, 'Active session not found.');
        end if;

        if g_current_session_token = p_session_token then
            clear_current_session_context();
        end if;
    end logout_user;

    procedure update_user_profile(
        p_user_id       in number,
        p_username      in varchar2 default null,
        p_password      in varchar2 default null
    ) is
        v_password_hash  varchar2(64);
    begin
        if p_username is null and p_password is null then
            return;
        end if;

        if p_password is not null then
            v_password_hash := hash_password_sha256(p_password);
        end if;

        if p_username is not null and p_password is not null then
            update users u
               set u.username = p_username,
                   u.password_hash = v_password_hash
             where u.user_id = p_user_id;
        elsif p_username is not null then
            update users u
               set u.username = p_username
             where u.user_id = p_user_id;
        else
            update users u
               set u.password_hash = v_password_hash
             where u.user_id = p_user_id;
        end if;

        if sql%rowcount = 0 then
            raise_application_error(-20022, 'User not found.');
        end if;
    end update_user_profile;

    function hash_password(
        p_password in varchar2
    ) return varchar2 is
    begin
        return hash_password_sha256(p_password);
    end hash_password;

    procedure start_new_lab(
        p_session_token in varchar2,
        p_lab_id        out number
    ) is
        v_session_id           number;
        v_user_id              number;
        v_wallet               number;
        v_rating               number;
        v_creature_count       number;
        v_active_task_count    number;
        v_completed_task_count number;
        v_experiment_count     number;
    begin
        get_active_session(
            p_session_token => p_session_token,
            p_session_id    => v_session_id,
            p_user_id       => v_user_id
        );

        set_current_session_context(
            p_user_id       => v_user_id,
            p_session_id    => v_session_id,
            p_session_token => p_session_token
        );

        p_lab_id := labs_seq.nextval;

        insert into labs (
            lab_id,
            user_id,
            session_id,
            wallet,
            rating,
            creature_count,
            active_task_count,
            completed_task_count,
            experiment_count
        ) values (
            p_lab_id,
            v_user_id,
            v_session_id,
            1000,
            0,
            0,
            0,
            0,
            0
        );

        assign_starting_tasks(
            p_lab_id => p_lab_id
        );

        g_current_lab_id := p_lab_id;

        generate_starting_creatures(
            p_lab_id => p_lab_id
        );

        get_lab_stats(
            p_lab_id               => p_lab_id,
            p_wallet               => v_wallet,
            p_rating               => v_rating,
            p_creature_count       => v_creature_count,
            p_active_task_count    => v_active_task_count,
            p_completed_task_count => v_completed_task_count,
            p_experiment_count     => v_experiment_count
        );
    end start_new_lab;

    procedure load_lab(
        p_session_token in varchar2,
        p_lab_id        in number
    ) is
        v_session_id     number;
        v_user_id        number;
        v_lab_user_id    number;
        v_lab_session_id number;
        v_holder_status  sessions.status%type;
    begin
        get_active_session(
            p_session_token => p_session_token,
            p_session_id    => v_session_id,
            p_user_id       => v_user_id
        );

        set_current_session_context(
            p_user_id       => v_user_id,
            p_session_id    => v_session_id,
            p_session_token => p_session_token
        );

        begin
            select l.user_id, l.session_id
              into v_lab_user_id, v_lab_session_id
              from labs l
             where l.lab_id = p_lab_id
             for update;
        exception
            when no_data_found then
                raise_application_error(-20023, 'Lab not found or access denied.');
        end;

        if v_lab_user_id <> v_user_id then
            raise_application_error(-20023, 'Lab not found or access denied.');
        end if;

        if v_lab_session_id is not null and v_lab_session_id <> v_session_id then
            begin
                select s.status
                  into v_holder_status
                  from sessions s
                 where s.session_id = v_lab_session_id;
            exception
                when no_data_found then
                    v_holder_status := 'CLOSED';
            end;

            if v_holder_status = 'ACTIVE' then
                raise_application_error(-20072, 'Lab is already opened in another active session.');
            end if;
        end if;

        update labs l
           set l.session_id = v_session_id
         where l.lab_id = p_lab_id;

        g_current_lab_id := p_lab_id;
    end load_lab;

    procedure switch_lab(
        p_session_token in varchar2,
        p_new_lab_id    in number
    ) is
    begin
        load_lab(
            p_session_token => p_session_token,
            p_lab_id        => p_new_lab_id
        );
    end switch_lab;

    function list_user_labs(
        p_user_id       in number
    ) return sys_refcursor is
        v_cursor sys_refcursor;
    begin
        open v_cursor for
            select
                l.lab_id,
                l.user_id,
                l.session_id,
                l.wallet,
                l.rating,
                l.creature_count,
                l.active_task_count,
                l.completed_task_count,
                l.experiment_count,
                cast(null as timestamp) as created_at,
                cast(null as timestamp) as updated_at
              from labs l
             where l.user_id = p_user_id
             order by l.lab_id;

        return v_cursor;
    end list_user_labs;

    procedure get_lab_stats(
        p_lab_id                in number,
        p_wallet                out number,
        p_rating                out number,
        p_creature_count        out number,
        p_active_task_count     out number,
        p_completed_task_count  out number,
        p_experiment_count      out number
    ) is
    begin
        assert_lab_access(p_lab_id => p_lab_id);

        select l.wallet, l.rating
          into p_wallet, p_rating
          from labs l
         where l.lab_id = p_lab_id;

        select count(*)
          into p_creature_count
          from creatures c
         where c.lab_id = p_lab_id;

        select count(*)
          into p_active_task_count
          from lab_tasks lt
         where lt.lab_id = p_lab_id
           and lt.task_status = 'ACTIVE';

        select count(*)
          into p_completed_task_count
          from lab_tasks lt
         where lt.lab_id = p_lab_id
           and lt.task_status = 'COMPLETED';

        select count(*)
          into p_experiment_count
          from experiments e
         where e.lab_id = p_lab_id;

        update labs l
           set l.creature_count = p_creature_count,
               l.active_task_count = p_active_task_count,
               l.completed_task_count = p_completed_task_count,
               l.experiment_count = p_experiment_count
         where l.lab_id = p_lab_id;
    exception
        when no_data_found then
            raise_application_error(-20024, 'Lab not found.');
    end get_lab_stats;

    procedure delete_lab(
        p_session_token in varchar2,
        p_lab_id        in number
    ) is
    begin
        load_lab(
            p_session_token => p_session_token,
            p_lab_id        => p_lab_id
        );

        delete from genotypes g
         where g.creature_id in (
             select c.creature_id
               from creatures c
              where c.lab_id = p_lab_id
         );

        delete from experiments e
         where e.lab_id = p_lab_id;

        delete from lab_tasks lt
         where lt.lab_id = p_lab_id;

        delete from lab_mutations lm
         where lm.lab_id = p_lab_id;

        delete from creatures c
         where c.lab_id = p_lab_id;

        delete from labs l
         where l.lab_id = p_lab_id
           and l.user_id = g_current_user_id;

        if sql%rowcount = 0 then
            raise_application_error(-20025, 'Lab not found or access denied.');
        end if;

        if g_current_lab_id = p_lab_id then
            g_current_lab_id := null;
        end if;
    end delete_lab;

    procedure exit_lab(
        p_lab_id in number
    ) is
    begin
        assert_lab_access(p_lab_id => p_lab_id);

        if g_current_lab_id = p_lab_id then
            g_current_lab_id := null;
        end if;
    end exit_lab;

    procedure show_lab_stats(
        p_lab_id in number
    ) is
        v_wallet               number;
        v_rating               number;
        v_creature_count       number;
        v_active_task_count    number;
        v_completed_task_count number;
        v_experiment_count     number;
    begin
        get_lab_stats(
            p_lab_id               => p_lab_id,
            p_wallet               => v_wallet,
            p_rating               => v_rating,
            p_creature_count       => v_creature_count,
            p_active_task_count    => v_active_task_count,
            p_completed_task_count => v_completed_task_count,
            p_experiment_count     => v_experiment_count
        );

        dbms_output.put_line('Лаборатория #' || p_lab_id);
        dbms_output.put_line('  Монеты: ' || to_char(v_wallet));
        dbms_output.put_line('  Рейтинг: ' || to_char(v_rating));
        dbms_output.put_line('  Существа: ' || to_char(v_creature_count));
        dbms_output.put_line('  Активные задания: ' || to_char(v_active_task_count));
        dbms_output.put_line('  Выполненные задания: ' || to_char(v_completed_task_count));
        dbms_output.put_line('  Эксперименты: ' || to_char(v_experiment_count));
    end show_lab_stats;

    function get_reference_cursor(
        p_ref_name      in varchar2
    ) return sys_refcursor is
        v_cursor sys_refcursor;
        v_ref_name varchar2(100) := upper(trim(p_ref_name));
    begin
        case v_ref_name
            when 'SPECIES_TYPES' then
                open v_cursor for
                    select to_char(species_type) as code, display_name, species_type as numeric_code
                      from ref_species_types
                     order by species_type;
            when 'GENE_TYPES' then
                open v_cursor for
                    select gene_type as code, display_name, cast(null as number) as numeric_code
                      from ref_gene_types
                     order by gene_type;
            when 'DOMINANCE_TYPES' then
                open v_cursor for
                    select dominance_type as code, display_name, cast(null as number) as numeric_code
                      from ref_dominance_types
                     order by dominance_type;
            when 'TASK_STATUSES' then
                open v_cursor for
                    select task_status as code, display_name, cast(null as number) as numeric_code
                      from ref_task_statuses
                     order by task_status;
            when 'EXPERIMENT_TYPES' then
                open v_cursor for
                    select experiment_type as code, display_name, cast(null as number) as numeric_code
                      from ref_experiment_types
                     order by experiment_type;
            when 'MUTAGEN_TYPES' then
                open v_cursor for
                    select mutagen_type as code, display_name, cast(null as number) as numeric_code
                      from ref_mutagen_types
                     order by mutagen_type;
            when 'MUTATION_TYPES' then
                open v_cursor for
                    select to_char(mutation_type) as code, display_name, mutation_type as numeric_code
                      from ref_mutation_types
                     order by mutation_type;
            when 'TASK_DIFFICULTIES' then
                open v_cursor for
                    select difficulty_code as code, display_name, cast(null as number) as numeric_code
                      from ref_task_difficulties
                     order by case difficulty_code when 'EASY' then 1 when 'MEDIUM' then 2 when 'HARD' then 3 else 4 end;
            else
                raise_application_error(-20074, 'Unknown reference name.');
        end case;

        return v_cursor;
    end get_reference_cursor;

    function get_creatures_cursor(
        p_lab_id         in number
    ) return sys_refcursor is
        v_cursor sys_refcursor;
    begin
        assert_lab_access(p_lab_id => p_lab_id);

        open v_cursor for
            select
                c.creature_id,
                c.lab_id,
                c.species_type,
                rst.display_name as species_display_name,
                c.creature_name,
                c.phenotype_color,
                c.phenotype_size,
                c.phenotype_has_wings,
                c.phenotype_nutrition_type,
                c.phenotype_summary,
                cast(null as timestamp) as created_at,
                cast(null as timestamp) as updated_at
              from creatures c
              join ref_species_types rst
                on rst.species_type = c.species_type
             where c.lab_id = p_lab_id
             order by c.creature_id;

        return v_cursor;
    end get_creatures_cursor;

    function get_genotype_cursor(
        p_creature_id    in number
    ) return sys_refcursor is
        v_cursor sys_refcursor;
        v_lab_id number;
    begin
        v_lab_id := assert_creature_access(
            p_creature_id => p_creature_id
        );

        open v_cursor for
            select
                gt.genotype_id,
                gt.creature_id,
                g.gene_id,
                g.gene_name,
                g.description as gene_display_name,
                g.gene_type,
                rgt.display_name as gene_type_display_name,
                g.dominance_type,
                rdt.display_name as dominance_display_name,
                a1.allele_id as allele1_id,
                a1.description as allele1_description,
                a1.description as allele1_display_name,
                a1.dominance as allele1_dominance,
                a1.trait_value as allele1_trait_value,
                a2.allele_id as allele2_id,
                a2.description as allele2_description,
                a2.description as allele2_display_name,
                a2.dominance as allele2_dominance,
                a2.trait_value as allele2_trait_value
              from genotypes gt
              join genes g
                on g.gene_id = gt.gene_id
              join ref_gene_types rgt
                on rgt.gene_type = g.gene_type
              join ref_dominance_types rdt
                on rdt.dominance_type = g.dominance_type
              join alleles a1
                on a1.allele_id = gt.allele1_id
              join alleles a2
                on a2.allele_id = gt.allele2_id
             where gt.creature_id = p_creature_id
             order by g.species_type, g.gene_name, g.gene_id;

        return v_cursor;
    end get_genotype_cursor;

    function get_phenotype(
        p_creature_id    in number
    ) return varchar2 is
        v_lab_id                 number;
        v_summary                varchar2(1000);
        v_trait_text              varchar2(400);
        v_effective_desc          varchar2(255);
        v_mid_desc                varchar2(255);
        v_mid_value               number;

        v_color                   varchar2(100);
        v_size                    varchar2(100);
        v_has_wings               char(1);
        v_nutrition_type          varchar2(100);
    begin
        v_lab_id := assert_creature_access(
            p_creature_id => p_creature_id
        );

        for rec in (
            select
                gt.gene_id,
                gt.allele1_id,
                gt.allele2_id,
                lower(g.gene_name) as gene_name,
                g.dominance_type,
                a1.description as allele1_desc,
                a1.dominance as allele1_dom,
                a1.trait_value as allele1_val,
                a2.description as allele2_desc,
                a2.dominance as allele2_dom,
                a2.trait_value as allele2_val
              from genotypes gt
              join genes g
                on g.gene_id = gt.gene_id
              join alleles a1
                on a1.allele_id = gt.allele1_id
              join alleles a2
                on a2.allele_id = gt.allele2_id
             where gt.creature_id = p_creature_id
             order by g.species_type, g.gene_name, g.gene_id
        ) loop
            if rec.allele1_id = rec.allele2_id then
                v_effective_desc := rec.allele1_desc;
            elsif rec.dominance_type = 'INCOMPLETE' then
                v_mid_value := (rec.allele1_val + rec.allele2_val) / 2;
                begin
                    select a.description
                      into v_mid_desc
                      from alleles a
                     where a.gene_id = rec.gene_id
                       and a.trait_value = v_mid_value
                       and rownum = 1;
                    v_effective_desc := v_mid_desc;
                exception
                    when no_data_found then
                        v_effective_desc := 'intermediate(' || rec.allele1_desc || '/' || rec.allele2_desc || ')';
                end;
            elsif rec.dominance_type = 'CODOMINANT' then
                v_effective_desc := rec.allele1_desc || '/' || rec.allele2_desc;
            elsif rec.allele1_dom > rec.allele2_dom then
                v_effective_desc := rec.allele1_desc;
            elsif rec.allele2_dom > rec.allele1_dom then
                v_effective_desc := rec.allele2_desc;
            else
                v_effective_desc := rec.allele1_desc;
            end if;

            if rec.gene_name = 'color' then
                v_color := v_effective_desc;
            elsif rec.gene_name = 'size' then
                v_size := v_effective_desc;
            elsif rec.gene_name = 'nutrition_type' then
                v_nutrition_type := v_effective_desc;
            elsif rec.gene_name = 'has_wings' then
                if instr(lower(v_effective_desc), 'no_wings') > 0 or rec.allele1_val = 0 and rec.allele2_val = 0 then
                    v_has_wings := 'N';
                else
                    v_has_wings := 'Y';
                end if;
            end if;

            v_trait_text := rec.gene_name || '=' || v_effective_desc;
            if v_summary is null then
                v_summary := v_trait_text;
            elsif length(v_summary) + length(v_trait_text) + 2 <= 1000 then
                v_summary := v_summary || '; ' || v_trait_text;
            else
                v_summary := substr(v_summary, 1, 997) || '...';
                exit;
            end if;
        end loop;

        update creatures c
           set c.phenotype_color = v_color,
               c.phenotype_size = v_size,
               c.phenotype_has_wings = v_has_wings,
               c.phenotype_nutrition_type = v_nutrition_type,
               c.phenotype_summary = v_summary
         where c.creature_id = p_creature_id;

        if sql%rowcount = 0 then
            raise_application_error(-20026, 'Creature not found.');
        end if;

        return v_summary;
    exception
        when others then
            raise;
    end get_phenotype;

    procedure show_creatures(
        p_lab_id in number
    ) is
        v_cursor                 sys_refcursor;
        v_creature_id            number;
        v_lab_id                 number;
        v_species_type           number;
        v_species_display_name   varchar2(4000);
        v_creature_name          varchar2(4000);
        v_color                  varchar2(4000);
        v_size                   varchar2(4000);
        v_has_wings              varchar2(10);
        v_nutrition_type         varchar2(4000);
        v_summary                varchar2(4000);
        v_created_at             timestamp;
        v_updated_at             timestamp;
    begin
        v_cursor := get_creatures_cursor(
            p_lab_id => p_lab_id
        );

        loop
            fetch v_cursor into
                v_creature_id,
                v_lab_id,
                v_species_type,
                v_species_display_name,
                v_creature_name,
                v_color,
                v_size,
                v_has_wings,
                v_nutrition_type,
                v_summary,
                v_created_at,
                v_updated_at;
            exit when v_cursor%notfound;

            dbms_output.put_line(
                '#' || v_creature_id || ' ' || nvl(v_creature_name, 'без имени') ||
                ' [' || nvl(v_species_display_name, to_char(v_species_type)) || '] ' ||
                nvl(v_summary, 'Фенотип не рассчитан')
            );
        end loop;

        close v_cursor;
    exception
        when others then
            if v_cursor%isopen then
                close v_cursor;
            end if;
            raise;
    end show_creatures;

    function get_dominant_allele(
        p_creature_id in number,
        p_gene_id     in number
    ) return varchar2 is
        v_lab_id          number;
        v_allele1_id      number;
        v_allele2_id      number;
        v_dominance_type  genes.dominance_type%type;
        v_allele1_desc    alleles.description%type;
        v_allele1_dom     alleles.dominance%type;
        v_allele1_val     alleles.trait_value%type;
        v_allele2_desc    alleles.description%type;
        v_allele2_dom     alleles.dominance%type;
        v_allele2_val     alleles.trait_value%type;
        v_effective_desc  varchar2(4000);
        v_mid_desc        varchar2(4000);
        v_mid_value       number;
    begin
        v_lab_id := assert_creature_access(
            p_creature_id => p_creature_id
        );

        select
            gt.allele1_id,
            gt.allele2_id,
            g.dominance_type,
            a1.description,
            a1.dominance,
            a1.trait_value,
            a2.description,
            a2.dominance,
            a2.trait_value
          into
            v_allele1_id,
            v_allele2_id,
            v_dominance_type,
            v_allele1_desc,
            v_allele1_dom,
            v_allele1_val,
            v_allele2_desc,
            v_allele2_dom,
            v_allele2_val
          from genotypes gt
          join genes g
            on g.gene_id = gt.gene_id
          join alleles a1
            on a1.allele_id = gt.allele1_id
          join alleles a2
            on a2.allele_id = gt.allele2_id
         where gt.creature_id = p_creature_id
           and gt.gene_id = p_gene_id;

        if v_allele1_id = v_allele2_id then
            v_effective_desc := v_allele1_desc;
        elsif v_dominance_type = 'INCOMPLETE' then
            v_mid_value := (v_allele1_val + v_allele2_val) / 2;
            begin
                select a.description
                  into v_mid_desc
                  from alleles a
                 where a.gene_id = p_gene_id
                   and a.trait_value = v_mid_value
                   and rownum = 1;
                v_effective_desc := v_mid_desc;
            exception
                when no_data_found then
                    v_effective_desc := 'intermediate(' || v_allele1_desc || '/' || v_allele2_desc || ')';
            end;
        elsif v_dominance_type = 'CODOMINANT' then
            v_effective_desc := v_allele1_desc || '/' || v_allele2_desc;
        elsif v_allele1_dom > v_allele2_dom then
            v_effective_desc := v_allele1_desc;
        elsif v_allele2_dom > v_allele1_dom then
            v_effective_desc := v_allele2_desc;
        else
            v_effective_desc := v_allele1_desc;
        end if;

        return v_effective_desc;
    exception
        when no_data_found then
            raise_application_error(-20075, 'Selected creature has no genotype for the requested gene.');
    end get_dominant_allele;

    function get_inherited_allele(
        p_parent_id in number,
        p_gene_id   in number
    ) return number is
        v_lab_id     number;
        v_allele1_id number;
        v_allele2_id number;
    begin
        v_lab_id := assert_creature_access(
            p_creature_id => p_parent_id
        );

        select gt.allele1_id, gt.allele2_id
          into v_allele1_id, v_allele2_id
          from genotypes gt
         where gt.creature_id = p_parent_id
           and gt.gene_id = p_gene_id;

        if pick_random_allele_side() = 1 then
            return v_allele1_id;
        end if;

        return v_allele2_id;
    exception
        when no_data_found then
            raise_application_error(-20076, 'Selected parent has no genotype for the requested gene.');
    end get_inherited_allele;

    function get_linked_allele_set(
        p_creature_id   in number,
        p_linkage_group in number
    ) return varchar2 is
        v_lab_id  number;
        v_result  varchar2(4000);
    begin
        v_lab_id := assert_creature_access(
            p_creature_id => p_creature_id
        );

        if p_linkage_group is null then
            return null;
        end if;

        select listagg(g.gene_name || '=' || a1.description || '/' || a2.description, '; ')
                   within group (order by g.gene_id)
          into v_result
          from genotypes gt
          join genes g
            on g.gene_id = gt.gene_id
          join alleles a1
            on a1.allele_id = gt.allele1_id
          join alleles a2
            on a2.allele_id = gt.allele2_id
         where gt.creature_id = p_creature_id
           and g.linkage_group = p_linkage_group;

        return v_result;
    end get_linked_allele_set;

    function calculate_punnett_probabilities(
        p_parent1_id     in number,
        p_parent2_id     in number,
        p_gene_id        in number
    ) return sys_refcursor is
        v_cursor                sys_refcursor;
        v_parent1_allele1_id    number;
        v_parent1_allele2_id    number;
        v_parent2_allele1_id    number;
        v_parent2_allele2_id    number;
        v_parent1_lab_id        number;
        v_parent2_lab_id        number;
    begin
        v_parent1_lab_id := assert_creature_access(
            p_creature_id => p_parent1_id
        );

        v_parent2_lab_id := assert_creature_access(
            p_creature_id => p_parent2_id
        );

        if v_parent1_lab_id <> v_parent2_lab_id then
            raise_application_error(-20060, 'Parents must belong to the same lab.');
        end if;

        select gt.allele1_id, gt.allele2_id
          into v_parent1_allele1_id, v_parent1_allele2_id
          from genotypes gt
         where gt.creature_id = p_parent1_id
           and gt.gene_id = p_gene_id;

        select gt.allele1_id, gt.allele2_id
          into v_parent2_allele1_id, v_parent2_allele2_id
          from genotypes gt
         where gt.creature_id = p_parent2_id
           and gt.gene_id = p_gene_id;

        open v_cursor for
            with combinations as (
                select
                    least(v_parent1_allele1_id, v_parent2_allele1_id) as allele1_id,
                    greatest(v_parent1_allele1_id, v_parent2_allele1_id) as allele2_id
                  from dual
                union all
                select
                    least(v_parent1_allele1_id, v_parent2_allele2_id) as allele1_id,
                    greatest(v_parent1_allele1_id, v_parent2_allele2_id) as allele2_id
                  from dual
                union all
                select
                    least(v_parent1_allele2_id, v_parent2_allele1_id) as allele1_id,
                    greatest(v_parent1_allele2_id, v_parent2_allele1_id) as allele2_id
                  from dual
                union all
                select
                    least(v_parent1_allele2_id, v_parent2_allele2_id) as allele1_id,
                    greatest(v_parent1_allele2_id, v_parent2_allele2_id) as allele2_id
                  from dual
            ),
            grouped_combinations as (
                select
                    c.allele1_id,
                    c.allele2_id,
                    count(*) / 4 as probability
                  from combinations c
                 group by c.allele1_id, c.allele2_id
            )
            select
                gc.allele1_id,
                gc.allele2_id,
                gc.probability,
                a1.description as allele1_description,
                a2.description as allele2_description
              from grouped_combinations gc
              join alleles a1
                on a1.allele_id = gc.allele1_id
              join alleles a2
                on a2.allele_id = gc.allele2_id
             order by gc.probability desc, gc.allele1_id, gc.allele2_id;

        return v_cursor;
    exception
        when no_data_found then
            raise_application_error(-20030, 'Genotype for selected gene is missing in one or both parents.');
    end calculate_punnett_probabilities;

    procedure auto_complete_matching_tasks(
        p_lab_id      in number,
        p_creature_id in number
    ) is
        v_is_completed number;
        v_wallet_after number;
        v_rating_after number;
    begin
        for task_rec in (
            select lt.task_id
              from lab_tasks lt
             where lt.lab_id = p_lab_id
               and lt.task_status = 'ACTIVE'
             order by lt.lab_task_id
        ) loop
            begin
                if check_task(
                    p_lab_id      => p_lab_id,
                    p_task_id     => task_rec.task_id,
                    p_creature_id => p_creature_id
                ) = 1 then
                    complete_task(
                        p_lab_id       => p_lab_id,
                        p_task_id      => task_rec.task_id,
                        p_creature_id  => p_creature_id,
                        p_is_completed => v_is_completed,
                        p_wallet_after => v_wallet_after,
                        p_rating_after => v_rating_after
                    );
                end if;
            exception
                when others then
                    if sqlcode in (-20063, -20064) then
                        null;
                    else
                        raise;
                    end if;
            end;
        end loop;
    end auto_complete_matching_tasks;

    procedure crossbreed(
        p_lab_id          in number,
        p_parent1_id      in number,
        p_parent2_id      in number,
        p_offspring_name  in varchar2,
        p_offspring_id    out number
    ) is
        type t_link_side_map is table of pls_integer index by varchar2(40);

        v_parent1_link_side_map   t_link_side_map;
        v_parent2_link_side_map   t_link_side_map;

        v_parent1_species_type    number;
        v_parent2_species_type    number;
        v_link_key                varchar2(40);
        v_parent1_side            pls_integer;
        v_parent2_side            pls_integer;
        v_selected_allele1_id     number;
        v_selected_allele2_id     number;
        v_gene_count              number;
        v_experiment_id           number;
        v_summary                 varchar2(1000);

        v_wallet                  number;
        v_rating                  number;
        v_creature_count          number;
        v_active_task_count       number;
        v_completed_task_count    number;
        v_experiment_count        number;
    begin
        if p_parent1_id is null or p_parent2_id is null then
            raise_application_error(-20031, 'Both parent ids are required.');
        end if;

        if p_parent1_id = p_parent2_id then
            raise_application_error(-20032, 'Parent ids must be different.');
        end if;

        if p_offspring_name is null or trim(p_offspring_name) is null then
            raise_application_error(-20033, 'Offspring name cannot be empty.');
        end if;

        assert_lab_access(p_lab_id => p_lab_id);

        if assert_creature_access(
            p_creature_id     => p_parent1_id,
            p_expected_lab_id => p_lab_id
        ) is null then
            null;
        end if;

        if assert_creature_access(
            p_creature_id     => p_parent2_id,
            p_expected_lab_id => p_lab_id
        ) is null then
            null;
        end if;

        begin
            select c.species_type
              into v_parent1_species_type
              from creatures c
             where c.creature_id = p_parent1_id
               and c.lab_id = p_lab_id;
        exception
            when no_data_found then
                raise_application_error(-20034, 'Parent1 does not exist in the selected lab.');
        end;

        begin
            select c.species_type
              into v_parent2_species_type
              from creatures c
             where c.creature_id = p_parent2_id
               and c.lab_id = p_lab_id;
        exception
            when no_data_found then
                raise_application_error(-20035, 'Parent2 does not exist in the selected lab.');
        end;

        if v_parent1_species_type <> v_parent2_species_type then
            raise_application_error(-20036, 'Crossbreeding is allowed only for parents of the same species_type in MVP.');
        end if;

        select count(*)
          into v_gene_count
          from genotypes gp1
          join genotypes gp2
            on gp2.gene_id = gp1.gene_id
           and gp2.creature_id = p_parent2_id
         where gp1.creature_id = p_parent1_id;

        if v_gene_count = 0 then
            raise_application_error(-20037, 'Parents have no common genes for crossbreeding.');
        end if;

        p_offspring_id := creatures_seq.nextval;

        insert into creatures (
            creature_id,
            lab_id,
            species_type,
            creature_name,
            phenotype_color,
            phenotype_size,
            phenotype_has_wings,
            phenotype_nutrition_type,
            phenotype_summary
        ) values (
            p_offspring_id,
            p_lab_id,
            v_parent1_species_type,
            trim(p_offspring_name),
            null,
            null,
            null,
            null,
            null
        );

        for rec in (
            select
                gp1.gene_id,
                g.linkage_group,
                gp1.allele1_id as parent1_allele1_id,
                gp1.allele2_id as parent1_allele2_id,
                gp2.allele1_id as parent2_allele1_id,
                gp2.allele2_id as parent2_allele2_id
              from genotypes gp1
              join genotypes gp2
                on gp2.gene_id = gp1.gene_id
               and gp2.creature_id = p_parent2_id
              join genes g
                on g.gene_id = gp1.gene_id
             where gp1.creature_id = p_parent1_id
             order by
                case when g.linkage_group is null then 0 else 1 end,
                g.linkage_group,
                gp1.gene_id
        ) loop
            if rec.linkage_group is null then
                v_parent1_side := pick_random_allele_side();
                v_parent2_side := pick_random_allele_side();
            else
                v_link_key := to_char(rec.linkage_group);

                if not v_parent1_link_side_map.exists(v_link_key) then
                    v_parent1_link_side_map(v_link_key) := pick_random_allele_side();
                end if;

                if not v_parent2_link_side_map.exists(v_link_key) then
                    v_parent2_link_side_map(v_link_key) := pick_random_allele_side();
                end if;

                v_parent1_side := v_parent1_link_side_map(v_link_key);
                v_parent2_side := v_parent2_link_side_map(v_link_key);
            end if;

            if v_parent1_side = 1 then
                v_selected_allele1_id := rec.parent1_allele1_id;
            else
                v_selected_allele1_id := rec.parent1_allele2_id;
            end if;

            if v_parent2_side = 1 then
                v_selected_allele2_id := rec.parent2_allele1_id;
            else
                v_selected_allele2_id := rec.parent2_allele2_id;
            end if;

            insert into genotypes (
                genotype_id,
                creature_id,
                gene_id,
                allele1_id,
                allele2_id
            ) values (
                genotypes_seq.nextval,
                p_offspring_id,
                rec.gene_id,
                v_selected_allele1_id,
                v_selected_allele2_id
            );
        end loop;

        v_summary := get_phenotype(
            p_creature_id => p_offspring_id
        );

        v_experiment_id := experiments_seq.nextval;

        insert into experiments (
            experiment_id,
            lab_id,
            parent1_id,
            parent2_id,
            mutation_id,
            offspring_id,
            experiment_type
        ) values (
            v_experiment_id,
            p_lab_id,
            p_parent1_id,
            p_parent2_id,
            null,
            p_offspring_id,
            'CROSS'
        );

        auto_complete_matching_tasks(
            p_lab_id      => p_lab_id,
            p_creature_id => p_offspring_id
        );

        get_lab_stats(
            p_lab_id               => p_lab_id,
            p_wallet               => v_wallet,
            p_rating               => v_rating,
            p_creature_count       => v_creature_count,
            p_active_task_count    => v_active_task_count,
            p_completed_task_count => v_completed_task_count,
            p_experiment_count     => v_experiment_count
        );
    end crossbreed;

    procedure rename_creature(
        p_creature_id     in number,
        p_new_name        in varchar2
    ) is
        v_lab_id number;
    begin
        if p_new_name is null or trim(p_new_name) is null then
            raise_application_error(-20038, 'New creature name cannot be empty.');
        end if;

        v_lab_id := assert_creature_access(
            p_creature_id => p_creature_id
        );

        update creatures c
           set c.creature_name = trim(p_new_name)
         where c.creature_id = p_creature_id;

        if sql%rowcount = 0 then
            raise_application_error(-20039, 'Creature not found.');
        end if;
    end rename_creature;

    function show_mutation_shop
    return sys_refcursor is
        v_cursor sys_refcursor;
    begin
        open v_cursor for
            select
                m.mutation_id,
                m.mutation_name,
                m.mutation_type,
                rmt.display_name as mutation_type_display_name,
                m.description,
                m.cost as price,
                m.rating_effect
              from mutations m
              left join ref_mutation_types rmt
                on rmt.mutation_type = m.mutation_type
             order by m.cost, m.mutation_id;

        return v_cursor;
    end show_mutation_shop;

    function get_mutation_target_genes_cursor(
        p_mutation_id     in number
    ) return sys_refcursor is
        v_cursor sys_refcursor;
    begin
        open v_cursor for
            select
                mr.gene_id,
                g.gene_name,
                g.description as gene_display_name,
                g.gene_type,
                rgt.display_name as gene_type_display_name,
                g.species_type,
                rst.display_name as species_display_name,
                mr.target_slot,
                a.trait_value,
                a.description as target_allele_description,
                a.description as target_allele_display_name
              from mutation_rules mr
              join genes g
                on g.gene_id = mr.gene_id
              join ref_gene_types rgt
                on rgt.gene_type = g.gene_type
              join ref_species_types rst
                on rst.species_type = g.species_type
              join alleles a
                on a.allele_id = mr.target_allele_id
             where mr.mutation_id = p_mutation_id
             order by mr.gene_id;

        return v_cursor;
    end get_mutation_target_genes_cursor;

    function get_compatible_creatures_for_mutation_cursor(
        p_lab_id          in number,
        p_mutation_id     in number
    ) return sys_refcursor is
        v_cursor sys_refcursor;
    begin
        assert_lab_access(p_lab_id => p_lab_id);

        open v_cursor for
            select c.creature_id
              from creatures c
             where c.lab_id = p_lab_id
               and not exists (
                    select 1
                      from (
                            select distinct mr.gene_id
                              from mutation_rules mr
                             where mr.mutation_id = p_mutation_id
                      ) req
                     where not exists (
                            select 1
                              from genotypes g
                             where g.creature_id = c.creature_id
                               and g.gene_id = req.gene_id
                     )
               )
             order by c.creature_id;

        return v_cursor;
    end get_compatible_creatures_for_mutation_cursor;

    function get_lab_mutation_quantity(
        p_lab_id          in number,
        p_mutation_id     in number
    ) return number is
        v_quantity number;
    begin
        assert_lab_access(p_lab_id => p_lab_id);

        select lm.quantity
          into v_quantity
          from lab_mutations lm
         where lm.lab_id = p_lab_id
           and lm.mutation_id = p_mutation_id;

        return nvl(v_quantity, 0);
    exception
        when no_data_found then
            return 0;
    end get_lab_mutation_quantity;

    function buy_mutation(
        p_lab_id          in number,
        p_mutation_id     in number
    ) return number is
        v_lab_wallet      number(12, 2);
        v_mutation_cost   number(12, 2);
        v_exists_count    number;
    begin
        assert_lab_access(p_lab_id => p_lab_id);

        begin
            select m.cost
              into v_mutation_cost
              from mutations m
             where m.mutation_id = p_mutation_id;
        exception
            when no_data_found then
                raise_application_error(-20041, 'Mutation not found.');
        end;

        select l.wallet
          into v_lab_wallet
          from labs l
         where l.lab_id = p_lab_id
         for update;

        if v_lab_wallet < v_mutation_cost then
            return 0;
        end if;

        update labs l
           set l.wallet = l.wallet - v_mutation_cost
         where l.lab_id = p_lab_id;

        update lab_mutations lm
           set lm.quantity = lm.quantity + 1
         where lm.lab_id = p_lab_id
           and lm.mutation_id = p_mutation_id;

        if sql%rowcount = 0 then
            insert into lab_mutations (
                lab_mutation_id,
                lab_id,
                mutation_id,
                quantity
            ) values (
                lab_mutations_seq.nextval,
                p_lab_id,
                p_mutation_id,
                1
            );
        end if;

        return 1;
    end buy_mutation;

    procedure apply_mutation(
        p_creature_id     in number,
        p_mutation_id     in number
    ) is
        v_lab_id                 number;
        v_mutation_rating_effect number(12, 2) := 0;
        v_mutation_stock         number;
        v_rule_count            number := 0;
        v_selected_slot         pls_integer;
        v_summary               varchar2(1000);
        v_experiment_id         number;

        v_wallet                number;
        v_rating                number;
        v_creature_count        number;
        v_active_task_count     number;
        v_completed_task_count  number;
        v_experiment_count      number;
    begin
        v_lab_id := assert_creature_access(
            p_creature_id => p_creature_id
        );
        begin
            select nvl(m.rating_effect, 0)
              into v_mutation_rating_effect
              from mutations m
             where m.mutation_id = p_mutation_id;
        exception
            when no_data_found then
                raise_application_error(-20056, 'Mutation not found.');
        end;

        begin
            select lm.quantity
              into v_mutation_stock
              from lab_mutations lm
             where lm.lab_id = v_lab_id
               and lm.mutation_id = p_mutation_id
             for update;
        exception
            when no_data_found then
                raise_application_error(-20043, 'Mutation is not available in lab inventory.');
        end;

        if v_mutation_stock <= 0 then
            raise_application_error(-20044, 'Mutation quantity is zero.');
        end if;

        for rule_rec in (
            select
                mr.gene_id,
                mr.target_allele_id,
                mr.target_slot
              from mutation_rules mr
             where mr.mutation_id = p_mutation_id
             order by mr.mutation_rule_id
        ) loop
            v_rule_count := v_rule_count + 1;

            if rule_rec.target_slot = '1' then
                update genotypes g
                   set g.allele1_id = rule_rec.target_allele_id
                 where g.creature_id = p_creature_id
                   and g.gene_id = rule_rec.gene_id;
            elsif rule_rec.target_slot = '2' then
                update genotypes g
                   set g.allele2_id = rule_rec.target_allele_id
                 where g.creature_id = p_creature_id
                   and g.gene_id = rule_rec.gene_id;
            else
                v_selected_slot := pick_random_allele_side();
                if v_selected_slot = 1 then
                    update genotypes g
                       set g.allele1_id = rule_rec.target_allele_id
                     where g.creature_id = p_creature_id
                       and g.gene_id = rule_rec.gene_id;
                else
                    update genotypes g
                       set g.allele2_id = rule_rec.target_allele_id
                     where g.creature_id = p_creature_id
                       and g.gene_id = rule_rec.gene_id;
                end if;
            end if;

            if sql%rowcount = 0 then
                raise_application_error(-20045, 'Creature has no genotype row for mutation rule gene_id=' || rule_rec.gene_id);
            end if;
        end loop;

        if v_rule_count = 0 then
            raise_application_error(-20046, 'No mutation rules found for mutation_id=' || p_mutation_id);
        end if;

        v_summary := get_phenotype(
            p_creature_id => p_creature_id
        );

        update lab_mutations lm
           set lm.quantity = lm.quantity - 1
         where lm.lab_id = v_lab_id
           and lm.mutation_id = p_mutation_id
           and lm.quantity > 0;

        if sql%rowcount = 0 then
            raise_application_error(-20047, 'Failed to decrease mutation quantity.');
        end if;

        update labs l
           set l.rating = greatest(0, l.rating + nvl(v_mutation_rating_effect, 0))
         where l.lab_id = v_lab_id;

        if sql%rowcount = 0 then
            raise_application_error(-20057, 'Lab not found.');
        end if;

        v_experiment_id := experiments_seq.nextval;

        insert into experiments (
            experiment_id,
            lab_id,
            parent1_id,
            parent2_id,
            mutation_id,
            offspring_id,
            experiment_type
        ) values (
            v_experiment_id,
            v_lab_id,
            p_creature_id,
            null,
            p_mutation_id,
            p_creature_id,
            'MUTATION'
        );

        auto_complete_matching_tasks(
            p_lab_id      => v_lab_id,
            p_creature_id => p_creature_id
        );

        get_lab_stats(
            p_lab_id               => v_lab_id,
            p_wallet               => v_wallet,
            p_rating               => v_rating,
            p_creature_count       => v_creature_count,
            p_active_task_count    => v_active_task_count,
            p_completed_task_count => v_completed_task_count,
            p_experiment_count     => v_experiment_count
        );
    end apply_mutation;

    procedure apply_mutagen(
        p_creature_id      in number,
        p_mutagen_type     in varchar2,
        p_new_creature_id  out number
    ) is
        v_lab_id                number;
        v_species_type          number;
        v_source_name           varchar2(255);
        v_new_name              varchar2(255);
        v_mutagen_mode          varchar2(20);
        v_target_gene_id        number;
        v_current_allele1_id    number;
        v_current_allele2_id    number;
        v_new_allele_id         number;
        v_selected_slot         pls_integer;
        v_mutation_rounds       pls_integer := 1;
        v_wallet_cost           number(12, 2);
        v_rating_delta          number(12, 2);
        v_lab_wallet            number(12, 2);
        v_summary               varchar2(1000);
        v_experiment_id         number;

        v_wallet                number;
        v_rating                number;
        v_creature_count        number;
        v_active_task_count     number;
        v_completed_task_count  number;
        v_experiment_count      number;
    begin
        if p_mutagen_type is null or trim(p_mutagen_type) is null then
            raise_application_error(-20048, 'Mutagen type cannot be empty.');
        end if;

        v_mutagen_mode := upper(trim(p_mutagen_type));

        if v_mutagen_mode not in ('RADIATION', 'CHEMICAL') then
            raise_application_error(-20070, 'Unsupported mutagen type. Use RADIATION or CHEMICAL.');
        end if;

        if v_mutagen_mode = 'RADIATION' then
            v_wallet_cost := 50;
            v_rating_delta := -5;
        else
            v_wallet_cost := 100;
            v_rating_delta := -2;
        end if;

        v_lab_id := assert_creature_access(
            p_creature_id => p_creature_id
        );

        begin
            select c.species_type, c.creature_name
              into v_species_type, v_source_name
              from creatures c
             where c.creature_id = p_creature_id;
        exception
            when no_data_found then
                raise_application_error(-20049, 'Source creature not found.');
        end;

        select l.wallet
          into v_lab_wallet
          from labs l
         where l.lab_id = v_lab_id
         for update;

        if v_lab_wallet < v_wallet_cost then
            raise_application_error(-20071, 'Not enough wallet balance for selected mutagen.');
        end if;

        update labs l
           set l.wallet = l.wallet - v_wallet_cost,
               l.rating = greatest(0, l.rating + v_rating_delta)
         where l.lab_id = v_lab_id;

        if sql%rowcount = 0 then
            raise_application_error(-20057, 'Lab not found.');
        end if;

        v_new_name := substr(v_source_name || '_mutagen_' || lower(substr(rawtohex(sys_guid()), 1, 8)), 1, 255);
        p_new_creature_id := creatures_seq.nextval;

        insert into creatures (
            creature_id,
            lab_id,
            species_type,
            creature_name,
            phenotype_color,
            phenotype_size,
            phenotype_has_wings,
            phenotype_nutrition_type,
            phenotype_summary
        ) values (
            p_new_creature_id,
            v_lab_id,
            v_species_type,
            v_new_name,
            null,
            null,
            null,
            null,
            null
        );

        insert into genotypes (
            genotype_id,
            creature_id,
            gene_id,
            allele1_id,
            allele2_id
        )
        select
            genotypes_seq.nextval,
            p_new_creature_id,
            g.gene_id,
            g.allele1_id,
            g.allele2_id
          from genotypes g
         where g.creature_id = p_creature_id;

        if sql%rowcount = 0 then
            raise_application_error(-20050, 'Source creature has no genotype rows.');
        end if;

        if v_mutagen_mode = 'RADIATION' and dbms_random.value(0, 1) < 0.45 then
            v_mutation_rounds := 2;
        end if;

        for mutation_round in 1 .. v_mutation_rounds loop
            if v_mutagen_mode = 'CHEMICAL' then
                begin
                    select
                        gt.gene_id,
                        gt.allele1_id,
                        gt.allele2_id
                      into
                        v_target_gene_id,
                        v_current_allele1_id,
                        v_current_allele2_id
                      from (
                            select
                                g.gene_id,
                                g.allele1_id,
                                g.allele2_id
                              from genotypes g
                              join genes ge
                                on ge.gene_id = g.gene_id
                             where g.creature_id = p_new_creature_id
                             order by
                                 case
                                     when ge.species_type = v_species_type then 0
                                     else 1
                                 end,
                                 ge.gene_id
                      ) gt
                     where rownum = 1;
                exception
                    when no_data_found then
                        raise_application_error(-20051, 'Unable to select genotype row for chemical mutagen.');
                end;

                v_selected_slot := 1;
            else
                begin
                    select
                        gt.gene_id,
                        gt.allele1_id,
                        gt.allele2_id
                      into
                        v_target_gene_id,
                        v_current_allele1_id,
                        v_current_allele2_id
                      from (
                            select
                                g.gene_id,
                                g.allele1_id,
                                g.allele2_id
                              from genotypes g
                             where g.creature_id = p_new_creature_id
                             order by dbms_random.value
                      ) gt
                     where rownum = 1;
                exception
                    when no_data_found then
                        raise_application_error(-20051, 'Unable to select genotype row for radiation mutagen.');
                end;

                v_selected_slot := pick_random_allele_side();
            end if;

            if v_selected_slot = 1 then
                begin
                    select a.allele_id
                      into v_new_allele_id
                      from (
                            select a.allele_id
                              from alleles a
                             where a.gene_id = v_target_gene_id
                               and a.allele_id <> v_current_allele1_id
                             order by dbms_random.value
                      ) a
                     where rownum = 1;
                exception
                    when no_data_found then
                        select a.allele_id
                          into v_new_allele_id
                          from (
                                select a.allele_id
                                  from alleles a
                                 where a.gene_id = v_target_gene_id
                                 order by dbms_random.value
                          ) a
                         where rownum = 1;
                end;

                update genotypes g
                   set g.allele1_id = v_new_allele_id
                 where g.creature_id = p_new_creature_id
                   and g.gene_id = v_target_gene_id;
            else
                begin
                    select a.allele_id
                      into v_new_allele_id
                      from (
                            select a.allele_id
                              from alleles a
                             where a.gene_id = v_target_gene_id
                               and a.allele_id <> v_current_allele2_id
                             order by dbms_random.value
                      ) a
                     where rownum = 1;
                exception
                    when no_data_found then
                        select a.allele_id
                          into v_new_allele_id
                          from (
                                select a.allele_id
                                  from alleles a
                                 where a.gene_id = v_target_gene_id
                                 order by dbms_random.value
                          ) a
                         where rownum = 1;
                end;

                update genotypes g
                   set g.allele2_id = v_new_allele_id
                 where g.creature_id = p_new_creature_id
                   and g.gene_id = v_target_gene_id;
            end if;
        end loop;

        v_summary := get_phenotype(
            p_creature_id => p_new_creature_id
        );

        v_experiment_id := experiments_seq.nextval;

        insert into experiments (
            experiment_id,
            lab_id,
            parent1_id,
            parent2_id,
            mutation_id,
            offspring_id,
            experiment_type
        ) values (
            v_experiment_id,
            v_lab_id,
            p_creature_id,
            null,
            null,
            p_new_creature_id,
            'MUTAGEN'
        );

        auto_complete_matching_tasks(
            p_lab_id      => v_lab_id,
            p_creature_id => p_new_creature_id
        );

        get_lab_stats(
            p_lab_id               => v_lab_id,
            p_wallet               => v_wallet,
            p_rating               => v_rating,
            p_creature_count       => v_creature_count,
            p_active_task_count    => v_active_task_count,
            p_completed_task_count => v_completed_task_count,
            p_experiment_count     => v_experiment_count
        );
    end apply_mutagen;

    procedure make_experiment(
        p_lab_id          in number,
        p_parent1_id      in number,
        p_parent2_id      in number,
        p_mutation_id     in number default null,
        p_offspring_name  in varchar2,
        p_offspring_id    out number
    ) is
    begin
        assert_lab_access(p_lab_id => p_lab_id);

        if p_parent1_id is null then
            raise_application_error(-20052, 'Parent1 id is required.');
        end if;

        if assert_creature_access(
            p_creature_id     => p_parent1_id,
            p_expected_lab_id => p_lab_id
        ) is null then
            null;
        end if;

        if p_parent2_id is not null then
            if assert_creature_access(
                p_creature_id     => p_parent2_id,
                p_expected_lab_id => p_lab_id
            ) is null then
                null;
            end if;

            crossbreed(
                p_lab_id         => p_lab_id,
                p_parent1_id     => p_parent1_id,
                p_parent2_id     => p_parent2_id,
                p_offspring_name => p_offspring_name,
                p_offspring_id   => p_offspring_id
            );

            if p_mutation_id is not null then
                apply_mutation(
                    p_creature_id => p_offspring_id,
                    p_mutation_id => p_mutation_id
                );
            end if;
        elsif p_mutation_id is not null then
            apply_mutation(
                p_creature_id => p_parent1_id,
                p_mutation_id => p_mutation_id
            );
            p_offspring_id := p_parent1_id;
        else
            raise_application_error(-20054, 'Invalid experiment input. Provide parent2_id for CROSS or mutation_id for MUTATION.');
        end if;
    end make_experiment;

    function get_experiment_history(
        p_lab_id           in number,
        p_experiment_type  in varchar2 default null
    ) return sys_refcursor is
        v_cursor       sys_refcursor;
    begin
        assert_lab_access(p_lab_id => p_lab_id);

        open v_cursor for
            select
                e.experiment_id,
                e.experiment_type,
                ret.display_name as experiment_type_display_name,
                e.parent1_id,
                p1.creature_name as parent1_name,
                e.parent2_id,
                p2.creature_name as parent2_name,
                e.offspring_id,
                o.creature_name as offspring_name,
                e.mutation_id,
                m.mutation_name,
                e.created_at as created_at
              from experiments e
              join ref_experiment_types ret
                on ret.experiment_type = e.experiment_type
              left join creatures p1
                on p1.creature_id = e.parent1_id
              left join creatures p2
                on p2.creature_id = e.parent2_id
              left join creatures o
                on o.creature_id = e.offspring_id
              left join mutations m
                on m.mutation_id = e.mutation_id
             where e.lab_id = p_lab_id
               and (
                    p_experiment_type is null
                    or upper(e.experiment_type) = upper(p_experiment_type)
               )
             order by e.experiment_id desc;

        return v_cursor;
    end get_experiment_history;

    function get_tasks_cursor(
        p_lab_id          in number
    ) return sys_refcursor is
        v_cursor       sys_refcursor;
    begin
        assert_lab_access(p_lab_id => p_lab_id);

        open v_cursor for
            select
                lt.lab_task_id,
                lt.task_id,
                t.task_name,
                t.task_name as task_display_name,
                t.description,
                t.money_reward as reward_money,
                t.rating_reward as reward_rating,
                t.difficulty_code,
                rtd.display_name as difficulty_display_name,
                lt.task_status,
                rts.display_name as task_status_display_name,
                lt.assigned_at as created_at,
                lt.completed_at
              from lab_tasks lt
              join tasks t
                on t.task_id = lt.task_id
              join ref_task_statuses rts
                on rts.task_status = lt.task_status
              join ref_task_difficulties rtd
                on rtd.difficulty_code = t.difficulty_code
             where lt.lab_id = p_lab_id
             order by
                case lt.task_status
                    when 'ACTIVE' then 0
                    else 1
                end,
                lt.assigned_at,
                lt.lab_task_id;

        return v_cursor;
    end get_tasks_cursor;

    procedure show_tasks(
        p_lab_id in number
    ) is
        v_cursor                   sys_refcursor;
        v_lab_task_id              number;
        v_task_id                  number;
        v_task_name                varchar2(4000);
        v_task_display_name        varchar2(4000);
        v_description              varchar2(4000);
        v_reward_money             number;
        v_reward_rating            number;
        v_difficulty_code          varchar2(100);
        v_difficulty_display_name  varchar2(4000);
        v_task_status              varchar2(100);
        v_task_status_display_name varchar2(4000);
        v_created_at               timestamp;
        v_completed_at             timestamp;
    begin
        v_cursor := get_tasks_cursor(
            p_lab_id => p_lab_id
        );

        loop
            fetch v_cursor into
                v_lab_task_id,
                v_task_id,
                v_task_name,
                v_task_display_name,
                v_description,
                v_reward_money,
                v_reward_rating,
                v_difficulty_code,
                v_difficulty_display_name,
                v_task_status,
                v_task_status_display_name,
                v_created_at,
                v_completed_at;
            exit when v_cursor%notfound;

            dbms_output.put_line(
                '#' || v_task_id || ' ' || nvl(v_task_display_name, v_task_name) ||
                ' [' || nvl(v_task_status_display_name, v_task_status) || '] ' ||
                'сложность=' || nvl(v_difficulty_display_name, v_difficulty_code)
            );
        end loop;

        close v_cursor;
    exception
        when others then
            if v_cursor%isopen then
                close v_cursor;
            end if;
            raise;
    end show_tasks;

    function check_task(
        p_lab_id          in number,
        p_task_id         in number,
        p_creature_id     in number
    ) return number is
        v_exists_count    number;
        v_marker_total    number;
        v_marker_matched  number;
    begin
        assert_lab_access(p_lab_id => p_lab_id);

        select count(*)
          into v_exists_count
          from tasks t
         where t.task_id = p_task_id;

        if v_exists_count = 0 then
            raise_application_error(-20058, 'Task not found.');
        end if;

        if assert_creature_access(
            p_creature_id     => p_creature_id,
            p_expected_lab_id => p_lab_id
        ) is null then
            null;
        end if;

        select count(*)
          into v_exists_count
          from lab_tasks lt
         where lt.lab_id = p_lab_id
           and lt.task_id = p_task_id;

        if v_exists_count = 0 then
            raise_application_error(-20061, 'Task is not assigned to the selected lab.');
        end if;

        select count(*)
          into v_marker_total
          from task_markers tm
         where tm.task_id = p_task_id;

        if v_marker_total = 0 then
            raise_application_error(-20062, 'Task has no markers defined.');
        end if;

        select count(*)
          into v_marker_matched
          from task_markers tm
         where tm.task_id = p_task_id
           and exists (
                select 1
                  from genotypes g
                 where g.creature_id = p_creature_id
                   and (
                        g.allele1_id = tm.allele_id
                        or g.allele2_id = tm.allele_id
                   )
           );

        if v_marker_matched = v_marker_total then
            return 1;
        end if;

        return 0;
    end check_task;

    procedure complete_task(
        p_lab_id          in number,
        p_task_id         in number,
        p_creature_id     in number,
        p_is_completed    out number,
        p_wallet_after    out number,
        p_rating_after    out number
    ) is
        v_check_result         number;
        v_task_status          lab_tasks.task_status%type;
        v_money_reward         tasks.money_reward%type;
        v_rating_reward        tasks.rating_reward%type;
        v_creature_count       number;
        v_active_task_count    number;
        v_completed_task_count number;
        v_experiment_count     number;
    begin
        p_is_completed := 0;
        p_wallet_after := null;
        p_rating_after := null;

        assert_lab_access(p_lab_id => p_lab_id);

        v_check_result := check_task(
            p_lab_id      => p_lab_id,
            p_task_id     => p_task_id,
            p_creature_id => p_creature_id
        );

        if v_check_result = 0 then
            raise_application_error(-20063, 'Task requirements are not met for the selected creature.');
        end if;

        begin
            select lt.task_status
              into v_task_status
              from lab_tasks lt
             where lt.lab_id = p_lab_id
               and lt.task_id = p_task_id
             for update;
        exception
            when no_data_found then
                raise_application_error(-20061, 'Task is not assigned to the selected lab.');
        end;

        if v_task_status = 'COMPLETED' then
            raise_application_error(-20064, 'Task is already completed for this lab.');
        end if;

        select t.money_reward, t.rating_reward
          into v_money_reward, v_rating_reward
          from tasks t
         where t.task_id = p_task_id;

        update lab_tasks lt
           set lt.task_status = 'COMPLETED',
               lt.completed_at = systimestamp
         where lt.lab_id = p_lab_id
           and lt.task_id = p_task_id
           and lt.task_status = 'ACTIVE';

        if sql%rowcount = 0 then
            raise_application_error(-20065, 'Failed to complete task.');
        end if;

        update labs l
           set l.wallet = l.wallet + nvl(v_money_reward, 0),
               l.rating = l.rating + nvl(v_rating_reward, 0)
         where l.lab_id = p_lab_id;

        if sql%rowcount = 0 then
            raise_application_error(-20057, 'Lab not found.');
        end if;

        refill_active_tasks(
            p_lab_id        => p_lab_id,
            p_target_active => 3
        );

        get_lab_stats(
            p_lab_id               => p_lab_id,
            p_wallet               => p_wallet_after,
            p_rating               => p_rating_after,
            p_creature_count       => v_creature_count,
            p_active_task_count    => v_active_task_count,
            p_completed_task_count => v_completed_task_count,
            p_experiment_count     => v_experiment_count
        );

        p_is_completed := 1;
    end complete_task;

    procedure generate_starting_creatures(
        p_lab_id          in number
    ) is
        v_species_type          number;
        v_variant               number;
        v_creature_id           number;
        v_existing_creatures    number;
        v_wallet                number;
        v_rating                number;
        v_creature_count        number;
        v_active_task_count     number;
        v_completed_task_count  number;
        v_experiment_count      number;
    begin
        assert_lab_access(p_lab_id => p_lab_id);

        select count(*)
          into v_existing_creatures
          from creatures c
         where c.lab_id = p_lab_id;

        if v_existing_creatures > 0 then
            get_lab_stats(
                p_lab_id               => p_lab_id,
                p_wallet               => v_wallet,
                p_rating               => v_rating,
                p_creature_count       => v_creature_count,
                p_active_task_count    => v_active_task_count,
                p_completed_task_count => v_completed_task_count,
                p_experiment_count     => v_experiment_count
            );
            return;
        end if;

        for v_species_type in 1 .. 6 loop
            for v_variant in 1 .. 5 loop
                create_creature_of_type(
                    p_lab_id       => p_lab_id,
                    p_species_type => v_species_type,
                    p_variant      => v_variant,
                    p_creature_id  => v_creature_id
                );
            end loop;
        end loop;

        get_lab_stats(
            p_lab_id               => p_lab_id,
            p_wallet               => v_wallet,
            p_rating               => v_rating,
            p_creature_count       => v_creature_count,
            p_active_task_count    => v_active_task_count,
            p_completed_task_count => v_completed_task_count,
            p_experiment_count     => v_experiment_count
        );
    end generate_starting_creatures;

    procedure create_creature_of_type(
        p_lab_id          in number,
        p_species_type    in number,
        p_variant         in number,
        p_creature_id     out number
    ) is
        v_creature_name    varchar2(255);
        v_allele1_id       number;
        v_allele2_id       number;
        v_summary          varchar2(1000);
    begin
        if p_species_type < 1 or p_species_type > 6 then
            raise_application_error(-20027, 'Invalid species_type. Expected value from 1 to 6.');
        end if;

        assert_lab_access(p_lab_id => p_lab_id);

        v_creature_name :=
            case p_species_type
                when 1 then 'cartilaginous_fish'
                when 2 then 'bony_fish'
                when 3 then 'crustacean'
                when 4 then 'mollusk'
                when 5 then 'turtle'
                when 6 then 'mammal'
            end
            || ' #' || to_char(nvl(p_variant, 1));

        p_creature_id := creatures_seq.nextval;

        insert into creatures (
            creature_id,
            lab_id,
            species_type,
            creature_name,
            phenotype_color,
            phenotype_size,
            phenotype_has_wings,
            phenotype_nutrition_type,
            phenotype_summary
        ) values (
            p_creature_id,
            p_lab_id,
            p_species_type,
            v_creature_name,
            null,
            null,
            null,
            null,
            null
        );

        for g in (
            select gene_id
              from genes
             where species_type in (0, p_species_type)
             order by gene_id
        ) loop
            begin
                select allele_id
                  into v_allele1_id
                  from (
                        select a.allele_id
                          from alleles a
                         where a.gene_id = g.gene_id
                         order by dbms_random.value
                       )
                 where rownum = 1;

                select allele_id
                  into v_allele2_id
                  from (
                        select a.allele_id
                          from alleles a
                         where a.gene_id = g.gene_id
                         order by dbms_random.value
                       )
                 where rownum = 1;
            exception
                when no_data_found then
                    raise_application_error(-20029, 'No alleles found for gene_id=' || g.gene_id);
            end;

            insert into genotypes (
                genotype_id,
                creature_id,
                gene_id,
                allele1_id,
                allele2_id
            ) values (
                genotypes_seq.nextval,
                p_creature_id,
                g.gene_id,
                v_allele1_id,
                v_allele2_id
            );
        end loop;

        v_summary := get_phenotype(p_creature_id => p_creature_id);
    end create_creature_of_type;

    procedure show_mutation_history(
        p_lab_id in number
    ) is
        v_cursor                     sys_refcursor;
        v_experiment_id              number;
        v_experiment_type            varchar2(100);
        v_experiment_type_display    varchar2(4000);
        v_parent1_id                 number;
        v_parent1_name               varchar2(4000);
        v_parent2_id                 number;
        v_parent2_name               varchar2(4000);
        v_offspring_id               number;
        v_offspring_name             varchar2(4000);
        v_mutation_id                number;
        v_mutation_name              varchar2(4000);
        v_created_at                 timestamp;
    begin
        v_cursor := get_experiment_history(
            p_lab_id => p_lab_id
        );

        loop
            fetch v_cursor into
                v_experiment_id,
                v_experiment_type,
                v_experiment_type_display,
                v_parent1_id,
                v_parent1_name,
                v_parent2_id,
                v_parent2_name,
                v_offspring_id,
                v_offspring_name,
                v_mutation_id,
                v_mutation_name,
                v_created_at;
            exit when v_cursor%notfound;

            dbms_output.put_line(
                '#' || v_experiment_id || ' ' || nvl(v_experiment_type_display, v_experiment_type) ||
                ': ' || nvl(v_parent1_name, '?') ||
                case when v_parent2_name is null then '' else ' + ' || v_parent2_name end ||
                case when v_offspring_name is null then '' else ' -> ' || v_offspring_name end ||
                case when v_mutation_name is null then '' else ' [' || v_mutation_name || ']' end
            );
        end loop;

        close v_cursor;
    exception
        when others then
            if v_cursor%isopen then
                close v_cursor;
            end if;
            raise;
    end show_mutation_history;
end pkg_genetics_game;
/

create or replace package body pkg_genetics_game as
    c_err_not_implemented constant number := -20999;

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

    procedure register_user(
        p_username      in varchar2,
        p_login         in varchar2,
        p_password      in varchar2,
        p_user_id       out number
    ) is
        v_login_count number;
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

        p_user_id := users_seq.nextval;

        insert into users (
            user_id,
            username,
            login,
            password_hash,
            created_at,
            updated_at
        ) values (
            p_user_id,
            p_username,
            p_login,
            hash_password_sha256(p_password),
            systimestamp,
            systimestamp
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
    end logout_user;

    procedure update_user_profile(
        p_user_id       in number,
        p_username      in varchar2 default null,
        p_password      in varchar2 default null
    ) is
    begin
        if p_username is null and p_password is null then
            return;
        end if;

        if p_username is not null and p_password is not null then
            update users u
               set u.username = p_username,
                   u.password_hash = hash_password_sha256(p_password),
                   u.updated_at = systimestamp
             where u.user_id = p_user_id;
        elsif p_username is not null then
            update users u
               set u.username = p_username,
                   u.updated_at = systimestamp
             where u.user_id = p_user_id;
        else
            update users u
               set u.password_hash = hash_password_sha256(p_password),
                   u.updated_at = systimestamp
             where u.user_id = p_user_id;
        end if;

        if sql%rowcount = 0 then
            raise_application_error(-20022, 'User not found.');
        end if;
    end update_user_profile;

    procedure start_new_lab(
        p_session_token in varchar2,
        p_lab_id        out number
    ) is
        v_session_id number;
        v_user_id    number;
    begin
        get_active_session(
            p_session_token => p_session_token,
            p_session_id    => v_session_id,
            p_user_id       => v_user_id
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
            experiment_count,
            created_at,
            updated_at
        ) values (
            p_lab_id,
            v_user_id,
            v_session_id,
            1000,
            0,
            0,
            0,
            0,
            0,
            systimestamp,
            systimestamp
        );
    end start_new_lab;

    procedure load_lab(
        p_session_token in varchar2,
        p_lab_id        in number
    ) is
        v_session_id number;
        v_user_id    number;
    begin
        get_active_session(
            p_session_token => p_session_token,
            p_session_id    => v_session_id,
            p_user_id       => v_user_id
        );

        update labs l
           set l.session_id = v_session_id,
               l.updated_at = systimestamp
         where l.lab_id = p_lab_id
           and l.user_id = v_user_id;

        if sql%rowcount = 0 then
            raise_application_error(-20023, 'Lab not found or access denied.');
        end if;
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
                l.created_at,
                l.updated_at
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
               l.experiment_count = p_experiment_count,
               l.updated_at = systimestamp
         where l.lab_id = p_lab_id;
    exception
        when no_data_found then
            raise_application_error(-20024, 'Lab not found.');
    end get_lab_stats;

    procedure delete_lab(
        p_session_token in varchar2,
        p_lab_id        in number
    ) is
        v_session_id number;
        v_user_id    number;
    begin
        get_active_session(
            p_session_token => p_session_token,
            p_session_id    => v_session_id,
            p_user_id       => v_user_id
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
           and l.user_id = v_user_id;

        if sql%rowcount = 0 then
            raise_application_error(-20025, 'Lab not found or access denied.');
        end if;
    end delete_lab;

    function get_creatures_cursor(
        p_lab_id         in number
    ) return sys_refcursor is
    begin
        raise_application_error(c_err_not_implemented, 'Not implemented yet');
        return null;
    end get_creatures_cursor;

    function get_genotype_cursor(
        p_creature_id    in number
    ) return sys_refcursor is
    begin
        raise_application_error(c_err_not_implemented, 'Not implemented yet');
        return null;
    end get_genotype_cursor;

    function get_phenotype(
        p_creature_id    in number
    ) return varchar2 is
    begin
        raise_application_error(c_err_not_implemented, 'Not implemented yet');
        return null;
    end get_phenotype;

    function calculate_punnett_probabilities(
        p_parent1_id     in number,
        p_parent2_id     in number,
        p_gene_id        in number
    ) return sys_refcursor is
    begin
        raise_application_error(c_err_not_implemented, 'Not implemented yet');
        return null;
    end calculate_punnett_probabilities;

    procedure crossbreed(
        p_lab_id          in number,
        p_parent1_id      in number,
        p_parent2_id      in number,
        p_offspring_name  in varchar2,
        p_offspring_id    out number
    ) is
    begin
        raise_application_error(c_err_not_implemented, 'Not implemented yet');
    end crossbreed;

    procedure rename_creature(
        p_creature_id     in number,
        p_new_name        in varchar2
    ) is
    begin
        raise_application_error(c_err_not_implemented, 'Not implemented yet');
    end rename_creature;

    function show_mutation_shop
    return sys_refcursor is
    begin
        raise_application_error(c_err_not_implemented, 'Not implemented yet');
        return null;
    end show_mutation_shop;

    function buy_mutation(
        p_lab_id          in number,
        p_mutation_id     in number
    ) return number is
    begin
        raise_application_error(c_err_not_implemented, 'Not implemented yet');
        return null;
    end buy_mutation;

    procedure apply_mutation(
        p_creature_id     in number,
        p_mutation_id     in number
    ) is
    begin
        raise_application_error(c_err_not_implemented, 'Not implemented yet');
    end apply_mutation;

    procedure apply_mutagen(
        p_creature_id      in number,
        p_mutagen_type     in varchar2,
        p_new_creature_id  out number
    ) is
    begin
        raise_application_error(c_err_not_implemented, 'Not implemented yet');
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
        raise_application_error(c_err_not_implemented, 'Not implemented yet');
    end make_experiment;

    function get_experiment_history(
        p_lab_id           in number,
        p_experiment_type  in varchar2 default null
    ) return sys_refcursor is
    begin
        raise_application_error(c_err_not_implemented, 'Not implemented yet');
        return null;
    end get_experiment_history;

    function get_tasks_cursor(
        p_lab_id          in number
    ) return sys_refcursor is
    begin
        raise_application_error(c_err_not_implemented, 'Not implemented yet');
        return null;
    end get_tasks_cursor;

    function check_task(
        p_lab_id          in number,
        p_task_id         in number,
        p_creature_id     in number
    ) return number is
    begin
        raise_application_error(c_err_not_implemented, 'Not implemented yet');
        return null;
    end check_task;

    procedure complete_task(
        p_lab_id          in number,
        p_task_id         in number,
        p_creature_id     in number,
        p_is_completed    out number,
        p_wallet_after    out number,
        p_rating_after    out number
    ) is
    begin
        raise_application_error(c_err_not_implemented, 'Not implemented yet');
    end complete_task;

    procedure generate_starting_creatures(
        p_lab_id          in number
    ) is
    begin
        raise_application_error(c_err_not_implemented, 'Not implemented yet');
    end generate_starting_creatures;

    procedure create_creature_of_type(
        p_lab_id          in number,
        p_species_type    in number,
        p_variant         in number,
        p_creature_id     out number
    ) is
    begin
        raise_application_error(c_err_not_implemented, 'Not implemented yet');
    end create_creature_of_type;
end pkg_genetics_game;
/

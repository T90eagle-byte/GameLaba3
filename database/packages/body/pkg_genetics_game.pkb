create or replace package body pkg_genetics_game as
    c_err_not_implemented constant number := -20999;
    g_current_user_id       number;
    g_current_session_id    number;
    g_current_session_token varchar2(128);
    g_current_lab_id        number;
    g_gameplay_gate_present  number := null;
    g_lab_genetics_version_present number := null;

    function gameplay_gate_is_present
    return boolean is
    begin
        if g_gameplay_gate_present is null then
            select count(*)
              into g_gameplay_gate_present
              from user_tab_columns
             where table_name = 'GENES'
               and column_name = 'GAMEPLAY_ENABLED';
        end if;

        return g_gameplay_gate_present = 1;
    end gameplay_gate_is_present;

    function lab_genetics_version_is_present
    return boolean is
    begin
        if g_lab_genetics_version_present is null then
            select count(*)
              into g_lab_genetics_version_present
              from user_tab_columns
             where table_name = 'LABS'
               and column_name = 'GENETICS_VERSION';
        end if;

        return g_lab_genetics_version_present = 1;
    end lab_genetics_version_is_present;

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

        -- Keep the ownership check and the protected call in one lab-row lock.
        -- Lock transitions take user/session first and never reverse that order.
        begin
            select l.user_id, l.session_id
              into v_lab_user_id, v_lab_session_id
              from labs l
             where l.lab_id = p_lab_id
             for update;
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


    procedure record_rating_event(
        p_lab_id         in number,
        p_event_type     in varchar2,
        p_rating_delta   in number default 0,
        p_wallet_delta   in number default 0,
        p_description    in varchar2 default null,
        p_creature_id    in number default null,
        p_task_id        in number default null,
        p_experiment_id  in number default null
    ) is
    begin
        insert into rating_events (
            rating_event_id,
            lab_id,
            creature_id,
            task_id,
            experiment_id,
            event_type,
            rating_delta,
            wallet_delta,
            description,
            created_at
        ) values (
            rating_events_seq.nextval,
            p_lab_id,
            p_creature_id,
            p_task_id,
            p_experiment_id,
            upper(trim(p_event_type)),
            nvl(p_rating_delta, 0),
            nvl(p_wallet_delta, 0),
            substr(p_description, 1, 1000),
            systimestamp
        );
    end record_rating_event;

    function hash_password_sha256(
    p_password in varchar2
) return varchar2
is
    v_hash varchar2(64);
begin
    select lower(rawtohex(standard_hash(p_password, 'SHA256')))
      into v_hash
      from dual;

    return v_hash;
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

    procedure lock_active_session(
        p_session_token in varchar2,
        p_session_id    out number,
        p_user_id       out number,
        p_error_code    in number default -20020
    ) is
        v_locked_user_id users.user_id%type;
    begin
        begin
            select s.session_id, s.user_id
              into p_session_id, p_user_id
              from sessions s
             where s.session_token = p_session_token;
        exception
            when no_data_found then
                raise_application_error(p_error_code, 'Active session not found.');
        end;

        -- Serialize lab lock transitions for one owner while leaving other users independent.
        select u.user_id
          into v_locked_user_id
          from users u
         where u.user_id = p_user_id
         for update;

        begin
            select s.session_id, s.user_id
              into p_session_id, p_user_id
              from sessions s
             where s.session_token = p_session_token
               and s.status = 'ACTIVE'
             for update;
        exception
            when no_data_found then
                raise_application_error(p_error_code, 'Active session not found.');
        end;
    end lock_active_session;

    procedure activate_lab(
        p_session_token  in varchar2,
        p_lab_id         in number,
        p_allow_takeover in boolean
    ) is
        v_session_id     sessions.session_id%type;
        v_user_id        users.user_id%type;
        v_lab_user_id    labs.user_id%type;
        v_lab_session_id labs.session_id%type;
        v_holder_status  sessions.status%type;
    begin
        lock_active_session(
            p_session_token => p_session_token,
            p_session_id    => v_session_id,
            p_user_id       => v_user_id
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

            if v_holder_status = 'ACTIVE' and not p_allow_takeover then
                raise_application_error(-20072, 'Lab is already opened in another active session.');
            end if;
        end if;

        update labs l
           set l.session_id = null
         where l.session_id = v_session_id
           and l.lab_id <> p_lab_id;

        update labs l
           set l.session_id = v_session_id
         where l.lab_id = p_lab_id;

        set_current_session_context(
            p_user_id       => v_user_id,
            p_session_id    => v_session_id,
            p_session_token => p_session_token
        );
        g_current_lab_id := p_lab_id;
    end activate_lab;

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
        v_lab_genetics_version labs.genetics_version%type;
    begin
        begin
            select l.genetics_version
              into v_lab_genetics_version
              from labs l
             where l.lab_id = p_lab_id;
        exception
            when no_data_found then
                raise_application_error(-20057, 'Lab not found.');
        end;

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
                 where t.genetics_version = v_lab_genetics_version
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
        v_lab_genetics_version labs.genetics_version%type;
        v_target_active     number := nvl(p_target_active, 3);
        v_active_count      number;
        v_missing_count     number;
    begin
        if v_target_active <= 0 then
            return;
        end if;

        begin
            select l.genetics_version
              into v_lab_genetics_version
              from labs l
             where l.lab_id = p_lab_id;
        exception
            when no_data_found then
                raise_application_error(-20057, 'Lab not found.');
        end;

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
                     where t.genetics_version = v_lab_genetics_version
                       and not exists (
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

    function get_lab_genetics_version(
        p_lab_id in number
    ) return number is
        v_genetics_version labs.genetics_version%type;
    begin
        select l.genetics_version
          into v_genetics_version
          from labs l
         where l.lab_id = p_lab_id;

        return v_genetics_version;
    end get_lab_genetics_version;

    function mutation_rules_match_genetics_version(
        p_mutation_id      in number,
        p_genetics_version in number
    ) return number is
        v_rule_count    number;
        v_allowed_count number;
    begin
        if p_genetics_version = 1 then
            return 1;
        end if;

        if p_genetics_version <> 3 then
            return 0;
        end if;

        select
            count(*),
            nvl(sum(
                case
                    when rmg.gene_id is not null
                     and g.species_type = 0
                     and g.gene_type = 'morphology'
                     and g.gene_name <> 'nutrition_type'
                    then 1
                    else 0
                end
            ), 0)
          into v_rule_count, v_allowed_count
          from mutation_rules mr
          join genes g
            on g.gene_id = mr.gene_id
          left join ref_genetics_model_genes rmg
            on rmg.genetics_version = 3
           and rmg.gene_id = mr.gene_id
         where mr.mutation_id = p_mutation_id;

        return case when v_rule_count > 0 and v_rule_count = v_allowed_count then 1 else 0 end;
    end mutation_rules_match_genetics_version;

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
        v_session_id sessions.session_id%type;
        v_user_id    users.user_id%type;
    begin
        lock_active_session(
            p_session_token => p_session_token,
            p_session_id    => v_session_id,
            p_user_id       => v_user_id,
            p_error_code    => -20021
        );

        update labs l
           set l.session_id = null
         where l.session_id = v_session_id;

        update sessions s
           set s.status = 'CLOSED',
               s.ended_at = systimestamp
         where s.session_id = v_session_id;

        if g_current_session_token = p_session_token then
            clear_current_session_context();
        end if;
    end logout_user;

    procedure reset_other_user_sessions(
        p_session_token in varchar2
    ) is
        v_current_session_id sessions.session_id%type;
        v_user_id            users.user_id%type;
    begin
        lock_active_session(
            p_session_token => p_session_token,
            p_session_id    => v_current_session_id,
            p_user_id       => v_user_id
        );

        update labs l
           set l.session_id = null
         where l.session_id in (
             select s.session_id
               from sessions s
              where s.user_id = v_user_id
                and s.status = 'ACTIVE'
                and s.session_id <> v_current_session_id
         );

        update sessions s
           set s.status = 'CLOSED',
               s.ended_at = systimestamp
         where s.user_id = v_user_id
           and s.status = 'ACTIVE'
           and s.session_id <> v_current_session_id;

        set_current_session_context(
            p_user_id       => v_user_id,
            p_session_id    => v_current_session_id,
            p_session_token => p_session_token
        );
    end reset_other_user_sessions;

    procedure update_profile_values(
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
    end update_profile_values;

    procedure update_user_profile(
        p_user_id       in number,
        p_username      in varchar2 default null,
        p_password      in varchar2 default null
    ) is
    begin
        require_current_session();

        if p_user_id is null or p_user_id <> g_current_user_id then
            raise_application_error(-20079, 'Access denied for selected user profile.');
        end if;

        update_profile_values(
            p_user_id  => g_current_user_id,
            p_username => p_username,
            p_password => p_password
        );
    end update_user_profile;

    procedure update_user_profile(
        p_session_token in varchar2,
        p_username      in varchar2 default null,
        p_password      in varchar2 default null
    ) is
        v_session_id sessions.session_id%type;
        v_user_id    users.user_id%type;
    begin
        lock_active_session(
            p_session_token => p_session_token,
            p_session_id    => v_session_id,
            p_user_id       => v_user_id,
            p_error_code    => -20020
        );

        update_profile_values(
            p_user_id  => v_user_id,
            p_username => p_username,
            p_password => p_password
        );
    end update_user_profile;

    function hash_password(
        p_password in varchar2
    ) return varchar2 is
    begin
        return hash_password_sha256(p_password);
    end hash_password;

    procedure start_new_lab(
        p_session_token in varchar2,
        p_lab_name      in varchar2,
        p_lab_id        out number
    ) is
        v_session_id           number;
        v_user_id              number;
        v_lab_name             varchar2(32767);
        v_wallet               number;
        v_rating               number;
        v_creature_count       number;
        v_active_task_count    number;
        v_completed_task_count number;
        v_experiment_count     number;
    begin
        lock_active_session(
            p_session_token => p_session_token,
            p_session_id    => v_session_id,
            p_user_id       => v_user_id
        );

        p_lab_id := labs_seq.nextval;
        v_lab_name := trim(p_lab_name);

        if v_lab_name is null then
            v_lab_name := 'Био-мастерская #' || to_char(p_lab_id);
        elsif length(v_lab_name) > 60 then
            raise_application_error(-20078, 'Lab name is too long.');
        end if;

        update labs l
           set l.session_id = null
         where l.session_id = v_session_id;

        insert into labs (
            lab_id,
            user_id,
            lab_name,
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
            v_lab_name,
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

        set_current_session_context(
            p_user_id       => v_user_id,
            p_session_id    => v_session_id,
            p_session_token => p_session_token
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

    procedure start_new_lab(
        p_session_token in varchar2,
        p_lab_id        out number
    ) is
    begin
        start_new_lab(
            p_session_token => p_session_token,
            p_lab_name      => null,
            p_lab_id        => p_lab_id
        );
    end start_new_lab;

    procedure load_lab(
        p_session_token in varchar2,
        p_lab_id        in number
    ) is
    begin
        activate_lab(
            p_session_token  => p_session_token,
            p_lab_id         => p_lab_id,
            p_allow_takeover => false
        );
    end load_lab;

    procedure recover_lab_access(
        p_session_token in varchar2,
        p_lab_id        in number
    ) is
    begin
        activate_lab(
            p_session_token  => p_session_token,
            p_lab_id         => p_lab_id,
            p_allow_takeover => true
        );
    end recover_lab_access;

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
                l.lab_name,
                l.session_id,
                l.wallet,
                l.rating,
                l.creature_count,
                l.active_task_count,
                l.completed_task_count,
                l.experiment_count,
                l.genetics_version,
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

        delete from rating_events re
         where re.lab_id = p_lab_id;

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

    procedure rename_lab(
        p_session_token in varchar2,
        p_lab_id        in number,
        p_lab_name      in varchar2
    ) is
        v_lab_name varchar2(32767);
    begin
        load_lab(
            p_session_token => p_session_token,
            p_lab_id        => p_lab_id
        );

        v_lab_name := trim(p_lab_name);
        if v_lab_name is null then
            raise_application_error(-20077, 'Lab name cannot be empty.');
        end if;
        if length(v_lab_name) > 60 then
            raise_application_error(-20078, 'Lab name is too long.');
        end if;

        update labs l
           set l.lab_name = v_lab_name,
               l.updated_at = systimestamp
         where l.lab_id = p_lab_id
           and l.user_id = g_current_user_id;

        if sql%rowcount = 0 then
            raise_application_error(-20025, 'Lab not found or access denied.');
        end if;
    end rename_lab;

    procedure exit_lab(
        p_lab_id in number
    ) is
        v_locked_user_id users.user_id%type;
    begin
        require_current_session();

        select u.user_id
          into v_locked_user_id
          from users u
         where u.user_id = g_current_user_id
         for update;

        assert_lab_access(p_lab_id => p_lab_id);

        update labs l
           set l.session_id = null
         where l.lab_id = p_lab_id
           and l.user_id = g_current_user_id
           and l.session_id = g_current_session_id;

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
            when 'RATING_EVENT_TYPES' then
                open v_cursor for
                    select event_type as code, display_name, cast(null as number) as numeric_code
                      from ref_rating_event_types
                     order by event_type;
            else
                raise_application_error(-20074, 'Unknown reference name.');
        end case;

        return v_cursor;
    end get_reference_cursor;



    function get_rating_events_cursor(
        p_session_token in varchar2,
        p_lab_id        in number
    ) return sys_refcursor is
        v_cursor sys_refcursor;
    begin
        load_lab(
            p_session_token => p_session_token,
            p_lab_id        => p_lab_id
        );

        assert_lab_access(p_lab_id => p_lab_id);

        open v_cursor for
            select
                re.rating_event_id,
                re.lab_id,
                re.creature_id,
                c.creature_name,
                re.task_id,
                t.task_name,
                re.experiment_id,
                re.event_type,
                ret.display_name as event_type_display_name,
                re.rating_delta,
                re.wallet_delta,
                re.description,
                re.created_at
              from rating_events re
              join ref_rating_event_types ret
                on ret.event_type = re.event_type
              left join creatures c
                on c.creature_id = re.creature_id
              left join tasks t
                on t.task_id = re.task_id
             where re.lab_id = p_lab_id
             order by re.created_at desc, re.rating_event_id desc;

        return v_cursor;
    end get_rating_events_cursor;

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
                l.genetics_version,
                c.species_type,
                rst.display_name as species_display_name,
                c.creature_name,
                c.archetype_id,
                rca.archetype_code,
                rca.display_name as archetype_display_name,
                c.phenotype_color,
                c.phenotype_size,
                c.phenotype_has_wings,
                c.phenotype_nutrition_type,
                c.phenotype_summary,
                cast(null as timestamp) as created_at,
                cast(null as timestamp) as updated_at
              from creatures c
              join labs l
                on l.lab_id = c.lab_id
              join ref_species_types rst
                on rst.species_type = c.species_type
              left join ref_creature_archetypes rca
                on rca.archetype_id = c.archetype_id
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
                coalesce(a1.display_name, a1.description) as allele1_display_name,
                a1.dominance as allele1_dominance,
                a1.trait_value as allele1_trait_value,
                a2.allele_id as allele2_id,
                a2.description as allele2_description,
                coalesce(a2.display_name, a2.description) as allele2_display_name,
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

    function get_morphology_cursor(
        p_creature_id in number
    ) return sys_refcursor is
        v_cursor                   sys_refcursor;
        v_lab_id                   number;
        v_morphology_row_count     number;
        v_required_morphology_rows number;
    begin
        v_lab_id := assert_creature_access(
            p_creature_id => p_creature_id
        );

        select
            count(*),
            count(
                case
                    when g.gene_name in (
                        'body_shape', 'body_proportion', 'body_size', 'body_cover', 'body_color',
                        'mouth_type', 'snout_type', 'eye_type',
                        'front_appendage_count', 'front_appendage_type', 'front_appendage_size',
                        'rear_appendage_count', 'rear_appendage_type', 'rear_appendage_size',
                        'tail_type', 'tail_size', 'dorsal_type', 'dorsal_size'
                    ) then 1
                end
            )
          into v_morphology_row_count, v_required_morphology_rows
          from genotypes gt
          join genes g
            on g.gene_id = gt.gene_id
         where gt.creature_id = p_creature_id
           and g.species_type = 0
           and g.gene_type = 'morphology';

        if v_morphology_row_count = 0 then
            open v_cursor for
                select
                    cast(null as varchar2(50 char)) as gene_code,
                    cast(null as varchar2(255 char)) as gene_display_name,
                    cast(null as varchar2(255 char)) as allele1_code,
                    cast(null as varchar2(255 char)) as allele2_code,
                    cast(null as varchar2(4000 char)) as expressed_allele_code,
                    cast(null as varchar2(255 char)) as allele1_display_name,
                    cast(null as varchar2(255 char)) as allele2_display_name,
                    cast(null as varchar2(4000 char)) as expressed_display_name
                  from dual
                 where 1 = 0;
            return v_cursor;
        end if;

        if v_morphology_row_count <> 18 or v_required_morphology_rows <> 18 then
            raise_application_error(
                -20083,
                'Creature morphology genotype is incomplete or inconsistent. Expected exactly 18 universal morphology genes.'
            );
        end if;

        open v_cursor for
            select
                g.gene_name as gene_code,
                g.description as gene_display_name,
                a1.description as allele1_code,
                a2.description as allele2_code,
                case
                    when gt.allele1_id = gt.allele2_id then a1.description
                    when g.dominance_type = 'INCOMPLETE' then
                        nvl(
                            (
                                select max(am.description)
                                  from alleles am
                                 where am.gene_id = g.gene_id
                                   and am.trait_value = (a1.trait_value + a2.trait_value) / 2
                            ),
                            'intermediate(' || a1.description || '/' || a2.description || ')'
                        )
                    when g.dominance_type = 'CODOMINANT' then a1.description || '/' || a2.description
                    when a1.dominance > a2.dominance then a1.description
                    when a2.dominance > a1.dominance then a2.description
                    else a1.description
                end as expressed_allele_code,
                coalesce(a1.display_name, a1.description) as allele1_display_name,
                coalesce(a2.display_name, a2.description) as allele2_display_name,
                case
                    when gt.allele1_id = gt.allele2_id then coalesce(a1.display_name, a1.description)
                    when g.dominance_type = 'INCOMPLETE' then
                        nvl(
                            (
                                select max(coalesce(am.display_name, am.description))
                                  from alleles am
                                 where am.gene_id = g.gene_id
                                   and am.trait_value = (a1.trait_value + a2.trait_value) / 2
                            ),
                            'intermediate(' || coalesce(a1.display_name, a1.description) || '/' || coalesce(a2.display_name, a2.description) || ')'
                        )
                    when g.dominance_type = 'CODOMINANT' then coalesce(a1.display_name, a1.description) || '/' || coalesce(a2.display_name, a2.description)
                    when a1.dominance > a2.dominance then coalesce(a1.display_name, a1.description)
                    when a2.dominance > a1.dominance then coalesce(a2.display_name, a2.description)
                    else coalesce(a1.display_name, a1.description)
                end as expressed_display_name
              from genotypes gt
              join genes g
                on g.gene_id = gt.gene_id
              join alleles a1
                on a1.allele_id = gt.allele1_id
              join alleles a2
                on a2.allele_id = gt.allele2_id
             where gt.creature_id = p_creature_id
               and g.species_type = 0
               and g.gene_type = 'morphology'
             order by g.gene_name, g.gene_id;

        return v_cursor;
    end get_morphology_cursor;

    function get_lab_morphology_cursor(
        p_lab_id in number
    ) return sys_refcursor is
        v_cursor sys_refcursor;
    begin
        assert_lab_access(p_lab_id => p_lab_id);

        open v_cursor for
            select
                gt.creature_id,
                g.gene_name as gene_code,
                g.description as gene_display_name,
                a1.description as allele1_code,
                a2.description as allele2_code,
                case
                    when gt.allele1_id = gt.allele2_id then a1.description
                    when g.dominance_type = 'INCOMPLETE' then
                        nvl(
                            (
                                select max(am.description)
                                  from alleles am
                                 where am.gene_id = g.gene_id
                                   and am.trait_value = (a1.trait_value + a2.trait_value) / 2
                            ),
                            'intermediate(' || a1.description || '/' || a2.description || ')'
                        )
                    when g.dominance_type = 'CODOMINANT' then a1.description || '/' || a2.description
                    when a1.dominance > a2.dominance then a1.description
                    when a2.dominance > a1.dominance then a2.description
                    else a1.description
                end as expressed_allele_code,
                coalesce(a1.display_name, a1.description) as allele1_display_name,
                coalesce(a2.display_name, a2.description) as allele2_display_name,
                case
                    when gt.allele1_id = gt.allele2_id then coalesce(a1.display_name, a1.description)
                    when g.dominance_type = 'INCOMPLETE' then
                        nvl(
                            (
                                select max(coalesce(am.display_name, am.description))
                                  from alleles am
                                 where am.gene_id = g.gene_id
                                   and am.trait_value = (a1.trait_value + a2.trait_value) / 2
                            ),
                            'intermediate(' || coalesce(a1.display_name, a1.description) || '/' || coalesce(a2.display_name, a2.description) || ')'
                        )
                    when g.dominance_type = 'CODOMINANT' then coalesce(a1.display_name, a1.description) || '/' || coalesce(a2.display_name, a2.description)
                    when a1.dominance > a2.dominance then coalesce(a1.display_name, a1.description)
                    when a2.dominance > a1.dominance then coalesce(a2.display_name, a2.description)
                    else coalesce(a1.display_name, a1.description)
                end as expressed_display_name
              from genotypes gt
              join creatures c
                on c.creature_id = gt.creature_id
              join genes g
                on g.gene_id = gt.gene_id
              join alleles a1
                on a1.allele_id = gt.allele1_id
              join alleles a2
                on a2.allele_id = gt.allele2_id
             where c.lab_id = p_lab_id
               and g.species_type = 0
               and g.gene_type = 'morphology'
             order by gt.creature_id, g.gene_name, g.gene_id;

        return v_cursor;
    end get_lab_morphology_cursor;

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
               and g.gameplay_enabled = 'Y'
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
        v_genetics_version       number;
        v_species_type           number;
        v_species_display_name   varchar2(4000);
        v_creature_name          varchar2(4000);
        v_archetype_id           number;
        v_archetype_code         varchar2(4000);
        v_archetype_display_name varchar2(4000);
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
                v_genetics_version,
                v_species_type,
                v_species_display_name,
                v_creature_name,
                v_archetype_id,
                v_archetype_code,
                v_archetype_display_name,
                v_color,
                v_size,
                v_has_wings,
                v_nutrition_type,
                v_summary,
                v_created_at,
                v_updated_at;
            exit when v_cursor%notfound;

            dbms_output.put_line(
                '#' || v_creature_id || ' ' || nvl(v_creature_name, 'Р±РµР· РёРјРµРЅРё') ||
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


    function preview_offspring_options(
        p_session_token  in varchar2,
        p_lab_id         in number,
        p_parent1_id     in number,
        p_parent2_id     in number,
        p_options_count  in number default 3
    ) return sys_refcursor is
        v_cursor               sys_refcursor;
        v_session_id           number;
        v_user_id              number;
        v_lab_user_id          number;
        v_lab_session_id       number;
        v_parent1_species_type number;
        v_parent2_species_type number;
        v_gene_count           number;
        v_options_count        pls_integer;
        v_preview_seed         varchar2(64);
    begin
        if p_parent1_id is null or p_parent2_id is null then
            raise_application_error(-20031, 'Both parent ids are required.');
        end if;

        if p_parent1_id = p_parent2_id then
            raise_application_error(-20032, 'Parent ids must be different.');
        end if;

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
             where l.lab_id = p_lab_id;
        exception
            when no_data_found then
                raise_application_error(-20023, 'Lab not found or access denied.');
        end;

        if v_lab_user_id <> v_user_id then
            raise_application_error(-20023, 'Lab not found or access denied.');
        end if;

        if v_lab_session_id is null or v_lab_session_id <> v_session_id then
            raise_application_error(-20073, 'Selected lab is not active in current session.');
        end if;

        g_current_lab_id := p_lab_id;

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

        if v_parent1_species_type not between 1 and 6
           or v_parent2_species_type not between 1 and 6 then
            raise_application_error(-20091, 'Гибрид нельзя использовать в качестве родителя.');
        end if;

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

        v_options_count := least(greatest(nvl(trunc(p_options_count), 3), 1), 10);
        -- A stable seed makes each logical option/group/parent choice invariant
        -- even if Oracle merges or reevaluates the CTE during query execution.
        v_preview_seed := rawtohex(sys_guid()) || rawtohex(sys_guid());

        open v_cursor for
            with options as (
                select level as option_no
                  from dual
                connect by level <= v_options_count
            ),
            common_genes as (
                select
                    gp1.gene_id,
                    lower(g.gene_name) as gene_name,
                    g.species_type,
                    g.linkage_group,
                    g.dominance_type,
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
            ),
            inheritance_sides as (
                select
                    side_seed.option_no,
                    side_seed.link_key,
                    mod(
                        ora_hash(v_preview_seed || ':P1:' || to_char(side_seed.option_no) || ':' || side_seed.link_key),
                        2
                    ) + 1 as parent1_side,
                    mod(
                        ora_hash(v_preview_seed || ':P2:' || to_char(side_seed.option_no) || ':' || side_seed.link_key),
                        2
                    ) + 1 as parent2_side
                  from (
                        select distinct
                            o.option_no,
                            case
                                when cg.linkage_group is null then 'G' || to_char(cg.gene_id)
                                else 'L' || to_char(cg.linkage_group)
                            end as link_key
                          from options o
                          cross join common_genes cg
                  ) side_seed
            ),
            selected_genes as (
                select
                    o.option_no,
                    cg.gene_id,
                    cg.gene_name,
                    cg.species_type,
                    cg.linkage_group,
                    cg.dominance_type,
                    case
                        when s.parent1_side = 1 then cg.parent1_allele1_id
                        else cg.parent1_allele2_id
                    end as allele1_id,
                    case
                        when s.parent2_side = 1 then cg.parent2_allele1_id
                        else cg.parent2_allele2_id
                    end as allele2_id
                  from options o
                  join common_genes cg
                    on 1 = 1
                  join inheritance_sides s
                    on s.option_no = o.option_no
                   and s.link_key = case
                                        when cg.linkage_group is null then 'G' || to_char(cg.gene_id)
                                        else 'L' || to_char(cg.linkage_group)
                                    end
            ),
            effective_genes as (
                select
                    sg.option_no,
                    sg.gene_id,
                    sg.gene_name,
                    sg.species_type,
                    sg.linkage_group,
                    sg.allele1_id,
                    sg.allele2_id,
                    a1.description as allele1_description,
                    a2.description as allele2_description,
                    case
                        when sg.allele1_id = sg.allele2_id then a1.description
                        when sg.dominance_type = 'INCOMPLETE' then
                            nvl(
                                (
                                    select max(am.description)
                                      from alleles am
                                     where am.gene_id = sg.gene_id
                                       and am.trait_value = (a1.trait_value + a2.trait_value) / 2
                                ),
                                'intermediate(' || a1.description || '/' || a2.description || ')'
                            )
                        when sg.dominance_type = 'CODOMINANT' then a1.description || '/' || a2.description
                        when a1.dominance > a2.dominance then a1.description
                        when a2.dominance > a1.dominance then a2.description
                        else a1.description
                    end as effective_description
                  from selected_genes sg
                  join alleles a1
                    on a1.allele_id = sg.allele1_id
                  join alleles a2
                    on a2.allele_id = sg.allele2_id
            )
            select
                o.option_no,
                v_parent1_species_type as species_type,
                rst.display_name as species_label,
                cast(null as number) as probability,
                substr(
                    listagg(eg.gene_name || '=' || eg.effective_description, '; ')
                        within group (order by eg.species_type, eg.gene_name, eg.gene_id),
                    1,
                    1000
                ) as phenotype_summary,
                substr(
                    listagg(eg.gene_name || ':' || eg.allele1_description || '/' || eg.allele2_description, '; ')
                        within group (order by eg.species_type, eg.gene_name, eg.gene_id),
                    1,
                    4000
                ) as genotype_summary,
                'PREVIEW_SAMPLE' as source_note
              from options o
              join ref_species_types rst
                on rst.species_type = v_parent1_species_type
              left join effective_genes eg
                on eg.option_no = o.option_no
             group by
                o.option_no,
                rst.display_name
             order by o.option_no;

        return v_cursor;
    end preview_offspring_options;
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

    procedure crossbreed_core(
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
        v_summary                 varchar2(1000);
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

        if v_parent1_species_type not between 1 and 6
           or v_parent2_species_type not between 1 and 6 then
            raise_application_error(-20091, 'Гибрид нельзя использовать в качестве родителя.');
        end if;

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
    end crossbreed_core;

    procedure crossbreed(
        p_lab_id          in number,
        p_parent1_id      in number,
        p_parent2_id      in number,
        p_offspring_name  in varchar2,
        p_offspring_id    out number
    ) is
        v_experiment_id           number;
        v_wallet                  number;
        v_rating                  number;
        v_creature_count          number;
        v_active_task_count       number;
        v_completed_task_count    number;
        v_experiment_count        number;
    begin
        crossbreed_core(
            p_lab_id         => p_lab_id,
            p_parent1_id     => p_parent1_id,
            p_parent2_id     => p_parent2_id,
            p_offspring_name => p_offspring_name,
            p_offspring_id   => p_offspring_id
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
                m.rating_effect,
                m.display_name as mutation_display_name
              from mutations m
              left join ref_mutation_types rmt
                on rmt.mutation_type = m.mutation_type
             order by m.cost, m.mutation_id;

        return v_cursor;
    end show_mutation_shop;

    function show_lab_mutation_shop(
        p_lab_id          in number
    ) return sys_refcursor is
        v_cursor           sys_refcursor;
        v_genetics_version labs.genetics_version%type;
    begin
        assert_lab_access(p_lab_id => p_lab_id);
        v_genetics_version := get_lab_genetics_version(p_lab_id => p_lab_id);

        open v_cursor for
            select
                m.mutation_id,
                m.mutation_name,
                m.mutation_type,
                rmt.display_name as mutation_type_display_name,
                m.description,
                m.cost as price,
                m.rating_effect,
                m.display_name as mutation_display_name
              from mutations m
              left join ref_mutation_types rmt
                on rmt.mutation_type = m.mutation_type
             where mutation_rules_match_genetics_version(
                       p_mutation_id      => m.mutation_id,
                       p_genetics_version => v_genetics_version
                   ) = 1
             order by m.cost, m.mutation_id;

        return v_cursor;
    end show_lab_mutation_shop;

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
                coalesce(a.display_name, a.description) as target_allele_display_name
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
        v_cursor           sys_refcursor;
        v_genetics_version labs.genetics_version%type;
    begin
        assert_lab_access(p_lab_id => p_lab_id);

        v_genetics_version := get_lab_genetics_version(p_lab_id => p_lab_id);

        if mutation_rules_match_genetics_version(
            p_mutation_id      => p_mutation_id,
            p_genetics_version => v_genetics_version
        ) <> 1 then
            open v_cursor for
                select cast(null as number) as creature_id
                  from dual
                 where 1 = 0;
            return v_cursor;
        end if;

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
        v_mutation_name   mutations.mutation_name%type;
        v_mutation_display_name mutations.display_name%type;
        v_genetics_version labs.genetics_version%type;
        v_exists_count    number;
    begin
        assert_lab_access(p_lab_id => p_lab_id);

        begin
            select m.cost, m.mutation_name, m.display_name
              into v_mutation_cost, v_mutation_name, v_mutation_display_name
              from mutations m
             where m.mutation_id = p_mutation_id;
        exception
            when no_data_found then
                raise_application_error(-20041, 'Mutation not found.');
        end;

        v_genetics_version := get_lab_genetics_version(p_lab_id => p_lab_id);
        if mutation_rules_match_genetics_version(
            p_mutation_id      => p_mutation_id,
            p_genetics_version => v_genetics_version
        ) <> 1 then
            raise_application_error(-20088, 'Эта мутация недоступна для генетической модели данной лаборатории.');
        end if;

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

        if nvl(v_mutation_cost, 0) <> 0 then
            record_rating_event(
                p_lab_id       => p_lab_id,
                p_event_type   => 'MUTATION_PURCHASE',
                p_rating_delta => 0,
                p_wallet_delta => -v_mutation_cost,
                p_description  => 'Покупка мутации: ' || coalesce(v_mutation_display_name, v_mutation_name)
            );
        end if;

        return 1;
    end buy_mutation;

    procedure apply_mutation(
        p_creature_id     in number,
        p_mutation_id     in number
    ) is
        v_lab_id                 number;
        v_genetics_version       labs.genetics_version%type;
        v_mutation_rating_effect number(12, 2) := 0;
        v_mutation_stock         number;
        v_rule_count            number := 0;
        v_selected_slot         pls_integer;
        v_current_allele1_id    number;
        v_current_allele2_id    number;
        v_summary               varchar2(1000);
        v_experiment_id         number;
        v_rating_before         number(12, 2);
        v_rating_after_update   number(12, 2);
        v_rating_actual_delta   number(12, 2);

        v_wallet                number;
        v_rating                number;
        v_creature_count        number;
        v_active_task_count     number;
        v_completed_task_count  number;
        v_experiment_count      number;
    begin
        savepoint apply_mutation_savepoint;

        v_lab_id := assert_creature_access(
            p_creature_id => p_creature_id
        );
        v_genetics_version := get_lab_genetics_version(p_lab_id => v_lab_id);

        begin
            select nvl(m.rating_effect, 0)
              into v_mutation_rating_effect
              from mutations m
             where m.mutation_id = p_mutation_id;
        exception
            when no_data_found then
                raise_application_error(-20056, 'Mutation not found.');
        end;

        if mutation_rules_match_genetics_version(
            p_mutation_id      => p_mutation_id,
            p_genetics_version => v_genetics_version
        ) <> 1 then
            raise_application_error(-20088, 'Эта мутация недоступна для генетической модели данной лаборатории.');
        end if;

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

            if v_genetics_version = 3 then
                select g.allele1_id, g.allele2_id
                  into v_current_allele1_id, v_current_allele2_id
                  from genotypes g
                 where g.creature_id = p_creature_id
                   and g.gene_id = rule_rec.gene_id
                 for update;

                if rule_rec.target_slot = '1'
                   and rule_rec.target_allele_id = v_current_allele1_id then
                    raise_application_error(-20089, 'Мутация не может заменить аллель тем же значением.');
                elsif rule_rec.target_slot = '2'
                   and rule_rec.target_allele_id = v_current_allele2_id then
                    raise_application_error(-20089, 'Мутация не может заменить аллель тем же значением.');
                elsif rule_rec.target_slot = 'ANY' then
                    if rule_rec.target_allele_id = v_current_allele1_id
                       and rule_rec.target_allele_id = v_current_allele2_id then
                        raise_application_error(-20089, 'Мутация не может заменить аллель тем же значением.');
                    elsif rule_rec.target_allele_id = v_current_allele1_id then
                        v_selected_slot := 2;
                    elsif rule_rec.target_allele_id = v_current_allele2_id then
                        v_selected_slot := 1;
                    else
                        v_selected_slot := pick_random_allele_side();
                    end if;
                end if;
            end if;

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
                if v_genetics_version <> 3 then
                    v_selected_slot := pick_random_allele_side();
                end if;
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

        select l.rating
          into v_rating_before
          from labs l
         where l.lab_id = v_lab_id
         for update;

        update labs l
           set l.rating = greatest(0, l.rating + nvl(v_mutation_rating_effect, 0))
         where l.lab_id = v_lab_id;

        if sql%rowcount = 0 then
            raise_application_error(-20057, 'Lab not found.');
        end if;

        select l.rating
          into v_rating_after_update
          from labs l
         where l.lab_id = v_lab_id;

        v_rating_actual_delta := v_rating_after_update - v_rating_before;

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

        if nvl(v_rating_actual_delta, 0) <> 0 then
            record_rating_event(
                p_lab_id        => v_lab_id,
                p_event_type    => 'SYSTEM_ADJUSTMENT',
                p_rating_delta  => v_rating_actual_delta,
                p_wallet_delta  => 0,
                p_description   => 'Эффект применённой мутации',
                p_creature_id   => p_creature_id,
                p_experiment_id => v_experiment_id
            );
        end if;

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
    exception
        when others then
            rollback to apply_mutation_savepoint;
            raise;
    end apply_mutation;

    procedure apply_mutagen_genetics_core(
        p_creature_id      in number,
        p_mutagen_type     in varchar2,
        p_genetics_version in number,
        p_species_type     in number
    ) is
        v_target_gene_id        number;
        v_current_allele1_id    number;
        v_current_allele2_id    number;
        v_new_allele_id         number;
        v_selected_slot         pls_integer;
        v_mutation_rounds       pls_integer := 1;
        v_summary               varchar2(1000);
    begin
        if p_mutagen_type not in ('RADIATION', 'CHEMICAL') then
            raise_application_error(-20070, 'Unsupported mutagen type. Use RADIATION or CHEMICAL.');
        end if;

        if p_mutagen_type = 'RADIATION' and dbms_random.value(0, 1) < 0.45 then
            v_mutation_rounds := 2;
        end if;

        for mutation_round in 1 .. v_mutation_rounds loop
            if p_mutagen_type = 'CHEMICAL' then
                begin
                    select gt.gene_id, gt.allele1_id, gt.allele2_id
                      into v_target_gene_id, v_current_allele1_id, v_current_allele2_id
                      from (
                            select g.gene_id, g.allele1_id, g.allele2_id
                              from genotypes g
                              join genes ge
                                on ge.gene_id = g.gene_id
                             where g.creature_id = p_creature_id
                               and (
                                    (p_genetics_version = 1 and ge.gameplay_enabled = 'Y')
                                    or (
                                        p_genetics_version = 3
                                        and ge.species_type = 0
                                        and ge.gene_type = 'morphology'
                                        and ge.gene_name <> 'nutrition_type'
                                        and exists (
                                            select 1
                                              from ref_genetics_model_genes rmg
                                             where rmg.genetics_version = 3
                                               and rmg.gene_id = ge.gene_id
                                        )
                                    )
                               )
                             order by
                                 case
                                     when p_genetics_version = 1 and ge.species_type = p_species_type then 0
                                     else 1
                                 end,
                                 case when p_genetics_version = 3 then ge.gene_name end,
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
                    select gt.gene_id, gt.allele1_id, gt.allele2_id
                      into v_target_gene_id, v_current_allele1_id, v_current_allele2_id
                      from (
                            select g.gene_id, g.allele1_id, g.allele2_id
                              from genotypes g
                              join genes ge
                                on ge.gene_id = g.gene_id
                             where g.creature_id = p_creature_id
                               and (
                                    (p_genetics_version = 1 and ge.gameplay_enabled = 'Y')
                                    or (
                                        p_genetics_version = 3
                                        and ge.species_type = 0
                                        and ge.gene_type = 'morphology'
                                        and ge.gene_name <> 'nutrition_type'
                                        and exists (
                                            select 1
                                              from ref_genetics_model_genes rmg
                                             where rmg.genetics_version = 3
                                               and rmg.gene_id = ge.gene_id
                                        )
                                    )
                               )
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
                        if p_genetics_version = 3 then
                            raise_application_error(-20089, 'Мутация не может заменить аллель тем же значением.');
                        end if;

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
                 where g.creature_id = p_creature_id
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
                        if p_genetics_version = 3 then
                            raise_application_error(-20089, 'Мутация не может заменить аллель тем же значением.');
                        end if;

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
                 where g.creature_id = p_creature_id
                   and g.gene_id = v_target_gene_id;
            end if;
        end loop;

        v_summary := get_phenotype(p_creature_id => p_creature_id);
    end apply_mutagen_genetics_core;

    procedure hybridize_core(
        p_lab_id          in number,
        p_parent1_id      in number,
        p_parent2_id      in number,
        p_offspring_name  in varchar2,
        p_offspring_id    out number
    ) is
        type t_link_side_map is table of pls_integer index by varchar2(40);
        v_parent1_link_side_map t_link_side_map;
        v_parent2_link_side_map t_link_side_map;
        v_link_key              varchar2(40);
        v_parent1_side          pls_integer;
        v_parent2_side          pls_integer;
        v_selected_allele1_id   number;
        v_selected_allele2_id   number;
        v_membership_count      number;
        v_parent1_gene_count    number;
        v_parent2_gene_count    number;
        v_summary               varchar2(1000);
    begin
        select count(*)
          into v_membership_count
          from ref_genetics_model_genes
         where genetics_version = 3;

        if v_membership_count <> 19 then
            raise_application_error(-20096, 'Каноническая генетическая модель гибрида должна содержать ровно 19 генов.');
        end if;

        select count(*)
          into v_parent1_gene_count
          from ref_genetics_model_genes rmg
          join genotypes gt
            on gt.gene_id = rmg.gene_id
           and gt.creature_id = p_parent1_id
         where rmg.genetics_version = 3;

        select count(*)
          into v_parent2_gene_count
          from ref_genetics_model_genes rmg
          join genotypes gt
            on gt.gene_id = rmg.gene_id
           and gt.creature_id = p_parent2_id
         where rmg.genetics_version = 3;

        if v_parent1_gene_count <> v_membership_count
           or v_parent2_gene_count <> v_membership_count then
            raise_application_error(-20097, 'У одного из родителей отсутствует полный набор генов версии 3.');
        end if;

        p_offspring_id := creatures_seq.nextval;
        insert into creatures (
            creature_id, lab_id, species_type, archetype_id, creature_name,
            phenotype_color, phenotype_size, phenotype_has_wings,
            phenotype_nutrition_type, phenotype_summary
        ) values (
            p_offspring_id, p_lab_id, 7, null, trim(p_offspring_name),
            null, null, null, null, null
        );

        for rec in (
            select
                rmg.gene_id,
                g.linkage_group,
                gp1.allele1_id as parent1_allele1_id,
                gp1.allele2_id as parent1_allele2_id,
                gp2.allele1_id as parent2_allele1_id,
                gp2.allele2_id as parent2_allele2_id
              from ref_genetics_model_genes rmg
              join genes g
                on g.gene_id = rmg.gene_id
              join genotypes gp1
                on gp1.gene_id = rmg.gene_id
               and gp1.creature_id = p_parent1_id
              join genotypes gp2
                on gp2.gene_id = rmg.gene_id
               and gp2.creature_id = p_parent2_id
             where rmg.genetics_version = 3
             order by
                case when g.linkage_group is null then 0 else 1 end,
                g.linkage_group,
                rmg.gene_id
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

            v_selected_allele1_id := case
                when v_parent1_side = 1 then rec.parent1_allele1_id
                else rec.parent1_allele2_id
            end;
            v_selected_allele2_id := case
                when v_parent2_side = 1 then rec.parent2_allele1_id
                else rec.parent2_allele2_id
            end;

            insert into genotypes (
                genotype_id, creature_id, gene_id, allele1_id, allele2_id
            ) values (
                genotypes_seq.nextval, p_offspring_id, rec.gene_id,
                v_selected_allele1_id, v_selected_allele2_id
            );
        end loop;

        v_summary := get_phenotype(p_creature_id => p_offspring_id);
    end hybridize_core;

    procedure mutagen_core(
        p_creature_id      in number,
        p_mutagen_type     in varchar2,
        p_clone_source     in boolean,
        p_record_side_effects in boolean,
        p_new_creature_id  out number,
        p_normalized_type  out varchar2,
        p_wallet_cost      out number,
        p_rating_delta     out number,
        p_display_name     out varchar2
    ) is
        v_lab_id                number;
        v_genetics_version      labs.genetics_version%type;
        v_species_type          number;
        v_source_name           varchar2(255);
        v_new_name              varchar2(255);
        v_mutagen_mode          varchar2(20);
        v_wallet_cost           number(12, 2);
        v_rating_delta          number(12, 2);
        v_lab_wallet            number(12, 2);
        v_lab_rating_before     number(12, 2);
        v_lab_rating_after      number(12, 2);
        v_rating_actual_delta   number(12, 2);
        v_experiment_id         number;
        v_mutagen_display_name  varchar2(100);

        v_wallet                number;
        v_rating                number;
        v_creature_count        number;
        v_active_task_count     number;
        v_completed_task_count  number;
        v_experiment_count      number;
    begin
        savepoint mutagen_core_savepoint;

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
            v_mutagen_display_name := 'Облучение';
        else
            v_wallet_cost := 100;
            v_rating_delta := -2;
            v_mutagen_display_name := 'Химический мутаген';
        end if;

        p_normalized_type := v_mutagen_mode;
        p_wallet_cost := v_wallet_cost;
        p_display_name := v_mutagen_display_name;

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

        select l.wallet, l.rating, l.genetics_version
          into v_lab_wallet, v_lab_rating_before, v_genetics_version
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

        select l.rating
          into v_lab_rating_after
          from labs l
         where l.lab_id = v_lab_id;

        v_rating_actual_delta := v_lab_rating_after - v_lab_rating_before;
        p_rating_delta := v_rating_actual_delta;

        if p_clone_source then
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
        else
            p_new_creature_id := p_creature_id;
        end if;

        apply_mutagen_genetics_core(
            p_creature_id      => p_new_creature_id,
            p_mutagen_type     => v_mutagen_mode,
            p_genetics_version => v_genetics_version,
            p_species_type     => v_species_type
        );

        if p_record_side_effects then
            v_experiment_id := experiments_seq.nextval;

            insert into experiments (
                experiment_id,
                lab_id,
                parent1_id,
                parent2_id,
                mutation_id,
                mutagen_type,
                offspring_id,
                experiment_type
            ) values (
                v_experiment_id,
                v_lab_id,
                p_creature_id,
                null,
                null,
                v_mutagen_mode,
                p_new_creature_id,
                'MUTAGEN'
            );

            record_rating_event(
            p_lab_id        => v_lab_id,
            p_event_type    => 'MUTAGEN_PENALTY',
            p_rating_delta  => v_rating_actual_delta,
            p_wallet_delta  => -v_wallet_cost,
            p_description   => 'Воздействие мутагена: ' || v_mutagen_display_name,
            p_creature_id   => p_new_creature_id,
            p_experiment_id => v_experiment_id
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
        end if;
    exception
        when others then
            rollback to mutagen_core_savepoint;
            p_new_creature_id := null;
            raise;
    end mutagen_core;

    procedure apply_mutagen(
        p_creature_id      in number,
        p_mutagen_type     in varchar2,
        p_new_creature_id  out number
    ) is
        v_normalized_type varchar2(30);
        v_wallet_cost     number(12, 2);
        v_rating_delta    number(12, 2);
        v_display_name    varchar2(100);
    begin
        mutagen_core(
            p_creature_id        => p_creature_id,
            p_mutagen_type       => p_mutagen_type,
            p_clone_source       => true,
            p_record_side_effects => true,
            p_new_creature_id    => p_new_creature_id,
            p_normalized_type    => v_normalized_type,
            p_wallet_cost        => v_wallet_cost,
            p_rating_delta       => v_rating_delta,
            p_display_name       => v_display_name
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

    procedure make_experiment(
        p_lab_id          in number,
        p_parent1_id      in number,
        p_parent2_id      in number,
        p_mutagen_type    in varchar2,
        p_offspring_name  in varchar2,
        p_offspring_id    out number
    ) is
        v_mutated_creature_id number;
        v_normalized_type     varchar2(30);
        v_wallet_cost         number(12, 2);
        v_rating_delta        number(12, 2);
        v_display_name        varchar2(100);
        v_experiment_id       number;
    begin
        savepoint combined_experiment_savepoint;

        if p_mutagen_type is null or trim(p_mutagen_type) is null then
            raise_application_error(-20048, 'Mutagen type cannot be empty.');
        end if;

        crossbreed_core(
            p_lab_id         => p_lab_id,
            p_parent1_id     => p_parent1_id,
            p_parent2_id     => p_parent2_id,
            p_offspring_name => p_offspring_name,
            p_offspring_id   => p_offspring_id
        );

        mutagen_core(
            p_creature_id         => p_offspring_id,
            p_mutagen_type        => p_mutagen_type,
            p_clone_source        => false,
            p_record_side_effects => false,
            p_new_creature_id     => v_mutated_creature_id,
            p_normalized_type     => v_normalized_type,
            p_wallet_cost         => v_wallet_cost,
            p_rating_delta        => v_rating_delta,
            p_display_name        => v_display_name
        );

        if v_mutated_creature_id <> p_offspring_id then
            raise_application_error(-20090, 'Combined experiment must mutate its offspring in place.');
        end if;

        v_experiment_id := experiments_seq.nextval;

        insert into experiments (
            experiment_id,
            lab_id,
            parent1_id,
            parent2_id,
            mutation_id,
            mutagen_type,
            offspring_id,
            experiment_type
        ) values (
            v_experiment_id,
            p_lab_id,
            p_parent1_id,
            p_parent2_id,
            null,
            v_normalized_type,
            p_offspring_id,
            'CROSSBREED_MUTAGEN'
        );

        record_rating_event(
            p_lab_id        => p_lab_id,
            p_event_type    => 'MUTAGEN_PENALTY',
            p_rating_delta  => v_rating_delta,
            p_wallet_delta  => -v_wallet_cost,
            p_description   => 'Скрещивание + мутаген: ' || v_display_name,
            p_creature_id   => p_offspring_id,
            p_experiment_id => v_experiment_id
        );

        auto_complete_matching_tasks(
            p_lab_id      => p_lab_id,
            p_creature_id => p_offspring_id
        );
    exception
        when others then
            rollback to combined_experiment_savepoint;
            p_offspring_id := null;
            raise;
    end make_experiment;

    procedure hybridize(
        p_lab_id          in number,
        p_parent1_id      in number,
        p_parent2_id      in number,
        p_mutagen_type    in varchar2,
        p_offspring_name  in varchar2,
        p_offspring_id    out number
    ) is
        v_parent1_species_type number;
        v_parent2_species_type number;
        v_genetics_version     labs.genetics_version%type;
        v_wallet_before        labs.wallet%type;
        v_rating_before        labs.rating%type;
        v_rating_after         labs.rating%type;
        v_wallet_cost          ref_experiment_economics.wallet_cost%type;
        v_rating_effect        ref_experiment_economics.rating_effect%type;
        v_rating_actual_delta  rating_events.rating_delta%type;
        v_experiment_id        experiments.experiment_id%type;
        v_genotype_count       number;
        v_membership_count     number;
        v_morphology_count     number;
        v_nutrition_count      number;
        v_normalized_mutagen   varchar2(30);
    begin
        savepoint hybridization_savepoint;
        p_offspring_id := null;

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
        if assert_creature_access(p_parent1_id, p_lab_id) is null then
            null;
        end if;
        if assert_creature_access(p_parent2_id, p_lab_id) is null then
            null;
        end if;

        select l.genetics_version, l.wallet
          into v_genetics_version, v_wallet_before
          from labs l
         where l.lab_id = p_lab_id;

        if v_genetics_version <> 3 then
            raise_application_error(-20092, 'Гибридизация доступна только в лаборатории генетической модели 3.');
        end if;

        select c.species_type
          into v_parent1_species_type
          from creatures c
         where c.creature_id = p_parent1_id
           and c.lab_id = p_lab_id;
        select c.species_type
          into v_parent2_species_type
          from creatures c
         where c.creature_id = p_parent2_id
           and c.lab_id = p_lab_id;

        if v_parent1_species_type not between 1 and 6
           or v_parent2_species_type not between 1 and 6 then
            raise_application_error(-20091, 'Гибрид нельзя использовать в качестве родителя.');
        end if;
        if v_parent1_species_type = v_parent2_species_type then
            raise_application_error(-20093, 'Для гибридизации выберите существ двух разных видов.');
        end if;

        v_normalized_mutagen := upper(trim(p_mutagen_type));
        if v_normalized_mutagen <> 'RADIATION' then
            raise_application_error(-20094, 'Для контролируемой гибридизации доступно только облучение.');
        end if;

        begin
            select ree.wallet_cost, ree.rating_effect
              into v_wallet_cost, v_rating_effect
              from ref_experiment_economics ree
             where ree.experiment_type = 'HYBRIDIZATION'
               and ree.genetics_version = 3
               and ree.mutagen_type = v_normalized_mutagen
               and ree.active_flag = 'Y';
        exception
            when no_data_found then
                raise_application_error(-20095, 'Настройки контролируемой гибридизации недоступны.');
            when too_many_rows then
                raise_application_error(-20095, 'Настройки контролируемой гибридизации противоречивы.');
        end;

        if v_wallet_before < v_wallet_cost then
            raise_application_error(-20071, 'Not enough wallet balance for selected experiment.');
        end if;

        hybridize_core(
            p_lab_id         => p_lab_id,
            p_parent1_id     => p_parent1_id,
            p_parent2_id     => p_parent2_id,
            p_offspring_name => p_offspring_name,
            p_offspring_id   => p_offspring_id
        );

        apply_mutagen_genetics_core(
            p_creature_id      => p_offspring_id,
            p_mutagen_type     => v_normalized_mutagen,
            p_genetics_version => 3,
            p_species_type     => 7
        );

        select
            count(*),
            count(case when rmg.gene_id is not null then 1 end),
            count(case when g.species_type = 0 and g.gene_type = 'morphology' then 1 end),
            count(case when g.species_type = 0 and g.gene_name = 'nutrition_type' then 1 end)
          into
            v_genotype_count,
            v_membership_count,
            v_morphology_count,
            v_nutrition_count
          from genotypes gt
          join genes g
            on g.gene_id = gt.gene_id
          left join ref_genetics_model_genes rmg
            on rmg.genetics_version = 3
           and rmg.gene_id = gt.gene_id
         where gt.creature_id = p_offspring_id;

        if v_genotype_count <> 19
           or v_membership_count <> 19
           or v_morphology_count <> 18
           or v_nutrition_count <> 1 then
            raise_application_error(-20098, 'Итоговый генотип гибрида не соответствует канонической модели версии 3.');
        end if;

        v_experiment_id := experiments_seq.nextval;
        insert into experiments (
            experiment_id, lab_id, parent1_id, parent2_id,
            mutation_id, mutagen_type, offspring_id, experiment_type
        ) values (
            v_experiment_id, p_lab_id, p_parent1_id, p_parent2_id,
            null, v_normalized_mutagen, p_offspring_id, 'HYBRIDIZATION'
        );

        auto_complete_matching_tasks(
            p_lab_id      => p_lab_id,
            p_creature_id => p_offspring_id
        );

        select l.rating
          into v_rating_before
          from labs l
         where l.lab_id = p_lab_id;

        update labs l
           set l.wallet = l.wallet - v_wallet_cost,
               l.rating = greatest(0, l.rating + v_rating_effect)
         where l.lab_id = p_lab_id;

        select l.rating
          into v_rating_after
          from labs l
         where l.lab_id = p_lab_id;

        v_rating_actual_delta := v_rating_after - v_rating_before;
        record_rating_event(
            p_lab_id        => p_lab_id,
            p_event_type    => 'HYBRIDIZATION_PENALTY',
            p_rating_delta  => v_rating_actual_delta,
            p_wallet_delta  => -v_wallet_cost,
            p_description   => 'Штраф за гибридизацию',
            p_creature_id   => p_offspring_id,
            p_experiment_id => v_experiment_id
        );
    exception
        when others then
            rollback to hybridization_savepoint;
            p_offspring_id := null;
            raise;
    end hybridize;

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
                e.created_at as created_at,
                e.mutagen_type,
                m.display_name as mutation_display_name
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
                coalesce(t.display_name, t.description, t.task_name) as task_display_name,
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
        v_difficulty_display_name varchar2(4000);
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

    function creature_matches_task(
        p_creature_id in number,
        p_task_id     in number
    ) return number is
        v_task_version    tasks.genetics_version%type;
        v_marker_total    number;
        v_marker_matched  number := 0;
        v_membership_count number;
        v_genotype_count  number;
        v_expressed_code  alleles.description%type;
    begin
        select t.genetics_version
          into v_task_version
          from tasks t
         where t.task_id = p_task_id;

        select count(*)
          into v_marker_total
          from task_markers tm
         where tm.task_id = p_task_id;

        if v_marker_total = 0 then
            raise_application_error(-20062, 'Task has no markers defined.');
        end if;

        if v_task_version = 1 then
            -- Preserve the approved legacy rule: a marker only has to be present.
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
        elsif v_task_version = 3 then
            for marker_rec in (
                select
                    tm.allele_id,
                    a.gene_id,
                    a.description as marker_code,
                    g.dominance_type
                  from task_markers tm
                  join alleles a
                    on a.allele_id = tm.allele_id
                  join genes g
                    on g.gene_id = a.gene_id
                 where tm.task_id = p_task_id
                 order by tm.task_marker_id
            ) loop
                select count(*)
                  into v_membership_count
                  from ref_genetics_model_genes membership
                 where membership.genetics_version = 3
                   and membership.gene_id = marker_rec.gene_id;

                if v_membership_count <> 1 then
                    raise_application_error(
                        -20085,
                        'V3 task marker gene is outside the canonical v3 genetics model.'
                    );
                end if;

                if marker_rec.dominance_type <> 'FULL' then
                    raise_application_error(
                        -20086,
                        'V3 task marker requires a FULL-dominance gene with one expressed allele.'
                    );
                end if;

                select count(*)
                  into v_genotype_count
                  from genotypes gt
                 where gt.creature_id = p_creature_id
                   and gt.gene_id = marker_rec.gene_id;

                if v_genotype_count = 0 then
                    return 0;
                end if;

                v_expressed_code := get_dominant_allele(
                    p_creature_id => p_creature_id,
                    p_gene_id     => marker_rec.gene_id
                );

                if v_expressed_code = marker_rec.marker_code then
                    v_marker_matched := v_marker_matched + 1;
                end if;
            end loop;
        else
            raise_application_error(-20087, 'Task has an unsupported genetics_version.');
        end if;

        if v_marker_matched = v_marker_total then
            return 1;
        end if;

        return 0;
    end creature_matches_task;

    function check_task(
        p_lab_id          in number,
        p_task_id         in number,
        p_creature_id     in number
    ) return number is
        v_exists_count    number;
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

        return creature_matches_task(
            p_creature_id => p_creature_id,
            p_task_id     => p_task_id
        );
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

        record_rating_event(
            p_lab_id       => p_lab_id,
            p_event_type   => 'TASK_REWARD',
            p_rating_delta => nvl(v_rating_reward, 0),
            p_wallet_delta => nvl(v_money_reward, 0),
            p_description   => 'Награда за выполненный заказ',
            p_creature_id  => p_creature_id,
            p_task_id      => p_task_id
        );

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

    procedure materialize_archetype_morphology(
        p_creature_id  in number,
        p_archetype_id in number
    ) is
        v_creature_species_type creatures.species_type%type;
        v_archetype_species_type ref_creature_archetypes.species_type%type;
        v_template_row_count number;
        v_morphology_row_count number;
    begin
        begin
            select c.species_type, r.species_type
              into v_creature_species_type, v_archetype_species_type
              from creatures c
              join ref_creature_archetypes r
                on r.archetype_id = p_archetype_id
             where c.creature_id = p_creature_id;
        exception
            when no_data_found then
                raise_application_error(-20080, 'Creature or reference archetype was not found for morphology materialization.');
        end;

        if v_creature_species_type <> v_archetype_species_type then
            raise_application_error(-20081, 'Creature species_type does not match its reference archetype.');
        end if;

        select
            count(*),
            count(case
                      when g.species_type = 0
                       and g.gene_type = 'morphology'
                       and g.gameplay_enabled = 'N'
                      then 1
                  end)
          into v_template_row_count, v_morphology_row_count
          from ref_archetype_alleles taa
          join genes g
            on g.gene_id = taa.gene_id
         where taa.archetype_id = p_archetype_id;

        if v_template_row_count <> 18 or v_morphology_row_count <> 18 then
            raise_application_error(-20082, 'Reference archetype must contain exactly 18 universal morphology genes.');
        end if;

        merge into genotypes target
        using (
            select
                p_creature_id as creature_id,
                taa.gene_id,
                taa.allele1_id,
                taa.allele2_id
              from ref_archetype_alleles taa
             where taa.archetype_id = p_archetype_id
        ) source
           on (target.creature_id = source.creature_id and target.gene_id = source.gene_id)
        when not matched then
            insert (genotype_id, creature_id, gene_id, allele1_id, allele2_id)
            values (genotypes_seq.nextval, source.creature_id, source.gene_id, source.allele1_id, source.allele2_id);
    end materialize_archetype_morphology;

    procedure generate_starting_creatures(
        p_lab_id          in number
    ) is
        v_genetics_version      number := 3;
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

        if lab_genetics_version_is_present then
            begin
                execute immediate q'[
                    select l.genetics_version,
                           count(c.creature_id)
                      from labs l
                      left join creatures c
                        on c.lab_id = l.lab_id
                     where l.lab_id = :lab_id
                     group by l.genetics_version
                ]'
                into v_genetics_version, v_existing_creatures
                using p_lab_id;
            exception
                when no_data_found then
                    raise_application_error(-20057, 'Lab not found.');
            end;
        else
            select count(*)
              into v_existing_creatures
              from creatures c
             where c.lab_id = p_lab_id;
        end if;

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

        if v_genetics_version <> 3 then
            raise_application_error(
                -20084,
                'Legacy laboratory cannot create universal-morphology starters.'
            );
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
        v_gene_cursor      sys_refcursor;
        v_gene_id          number;
        v_archetype_id     number;
        v_archetype_display_name ref_creature_archetypes.display_name%type;
        v_archetype_count  number;
        v_existing_count   number;
        v_gene_cursor_open boolean := false;
    begin
        savepoint creature_build;

        if p_species_type < 1 or p_species_type > 6 then
            raise_application_error(-20027, 'Invalid species_type. Expected value from 1 to 6.');
        end if;

        assert_lab_access(p_lab_id => p_lab_id);

        select count(*)
          into v_archetype_count
          from ref_creature_archetypes
         where species_type = p_species_type
           and active_flag = 'Y';

        if v_archetype_count = 0 then
            raise_application_error(-20079, 'No active reference archetype exists for species_type=' || p_species_type || '.');
        end if;

        select count(*)
          into v_existing_count
          from creatures
         where lab_id = p_lab_id
           and species_type = p_species_type
           and archetype_id is not null;

        select archetype_id, display_name
          into v_archetype_id, v_archetype_display_name
          from (
                select archetype_id,
                       display_name,
                       row_number() over (order by archetype_code) as archetype_position
                  from ref_creature_archetypes
                 where species_type = p_species_type
                   and active_flag = 'Y'
               )
         where archetype_position = mod(v_existing_count, v_archetype_count) + 1;

        v_creature_name := trim(v_archetype_display_name)
            || ' #' || to_char(nvl(p_variant, 1));

        p_creature_id := creatures_seq.nextval;

        insert into creatures (
            creature_id,
            lab_id,
            species_type,
            archetype_id,
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
            v_archetype_id,
            v_creature_name,
            null,
            null,
            null,
            null,
            null
        );

        if gameplay_gate_is_present then
            open v_gene_cursor for
                'select gene_id
                   from genes
                  where species_type in (0, :species_type)
                    and gameplay_enabled = ''Y''
                  order by gene_id'
                using p_species_type;
            v_gene_cursor_open := true;
        else
            open v_gene_cursor for
                'select gene_id
                   from genes
                  where species_type in (0, :species_type)
                  order by gene_id'
                using p_species_type;
            v_gene_cursor_open := true;
        end if;

        loop
            fetch v_gene_cursor into v_gene_id;
            exit when v_gene_cursor%notfound;
            begin
                select allele_id
                  into v_allele1_id
                  from (
                        select a.allele_id
                          from alleles a
                         where a.gene_id = v_gene_id
                         order by dbms_random.value
                       )
                 where rownum = 1;

                select allele_id
                  into v_allele2_id
                  from (
                        select a.allele_id
                          from alleles a
                         where a.gene_id = v_gene_id
                         order by dbms_random.value
                       )
                 where rownum = 1;
            exception
                when no_data_found then
                    raise_application_error(-20029, 'No alleles found for gene_id=' || v_gene_id);
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
                v_gene_id,
                v_allele1_id,
                v_allele2_id
            );
        end loop;

        close v_gene_cursor;
        v_gene_cursor_open := false;

        materialize_archetype_morphology(
            p_creature_id  => p_creature_id,
            p_archetype_id => v_archetype_id
        );

        v_summary := get_phenotype(p_creature_id => p_creature_id);
    exception
        when others then
            if v_gene_cursor_open then
                close v_gene_cursor;
            end if;
            rollback to creature_build;
            raise;
    end create_creature_of_type;



    procedure show_rating_history(
        p_lab_id in number
    ) is
        v_event_id      number;
        v_event_type    varchar2(4000);
        v_event_label   varchar2(4000);
        v_rating_delta  number;
        v_wallet_delta  number;
        v_description   varchar2(4000);
        v_created_at    timestamp;
        v_cursor        sys_refcursor;
    begin
        assert_lab_access(p_lab_id => p_lab_id);

        open v_cursor for
            select
                re.rating_event_id,
                re.event_type,
                ret.display_name,
                re.rating_delta,
                re.wallet_delta,
                re.description,
                re.created_at
              from rating_events re
              join ref_rating_event_types ret
                on ret.event_type = re.event_type
             where re.lab_id = p_lab_id
             order by re.created_at, re.rating_event_id;

        loop
            fetch v_cursor
             into v_event_id,
                  v_event_type,
                  v_event_label,
                  v_rating_delta,
                  v_wallet_delta,
                  v_description,
                  v_created_at;
            exit when v_cursor%notfound;

            dbms_output.put_line(
                '[' || v_event_type || '] '
                || v_event_label
                || ': rating ' || to_char(v_rating_delta)
                || ', wallet ' || to_char(v_wallet_delta)
                || case when v_description is null then '' else ' - ' || v_description end
            );
        end loop;
        close v_cursor;
    end show_rating_history;

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
        v_mutation_display_name      varchar2(4000);
        v_created_at                 timestamp;
        v_mutagen_type               varchar2(30);
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
                v_created_at,
                v_mutagen_type,
                v_mutation_display_name;
            exit when v_cursor%notfound;

            dbms_output.put_line(
                '#' || v_experiment_id || ' ' || nvl(v_experiment_type_display, v_experiment_type) ||
                ': ' || nvl(v_parent1_name, '?') ||
                case when v_parent2_name is null then '' else ' + ' || v_parent2_name end ||
                case when v_offspring_name is null then '' else ' -> ' || v_offspring_name end ||
                case when v_mutation_name is null then '' else ' [' || coalesce(v_mutation_display_name, v_mutation_name) || ']' end
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

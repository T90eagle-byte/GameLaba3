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
        v_cursor sys_refcursor;
    begin
        open v_cursor for
            select
                c.creature_id,
                c.lab_id,
                c.species_type,
                c.creature_name,
                c.phenotype_color,
                c.phenotype_size,
                c.phenotype_has_wings,
                c.phenotype_nutrition_type,
                c.phenotype_summary,
                c.created_at,
                c.updated_at
              from creatures c
             where c.lab_id = p_lab_id
             order by c.creature_id;

        return v_cursor;
    end get_creatures_cursor;

    function get_genotype_cursor(
        p_creature_id    in number
    ) return sys_refcursor is
        v_cursor sys_refcursor;
    begin
        open v_cursor for
            select
                gt.genotype_id,
                gt.creature_id,
                g.gene_id,
                g.gene_name,
                g.gene_type,
                g.dominance_type,
                a1.allele_id as allele1_id,
                a1.description as allele1_description,
                a1.dominance as allele1_dominance,
                a1.trait_value as allele1_trait_value,
                a2.allele_id as allele2_id,
                a2.description as allele2_description,
                a2.dominance as allele2_dominance,
                a2.trait_value as allele2_trait_value
              from genotypes gt
              join genes g
                on g.gene_id = gt.gene_id
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
        v_summary                 varchar2(1000);
        v_trait_text              varchar2(400);
        v_effective_desc          varchar2(255);
        v_mid_desc                varchar2(255);
        v_mid_value               number;

        v_color                   varchar2(100);
        v_size                    varchar2(100);
        v_has_wings               char(1);
        v_nutrition_type          varchar2(100);
    begin
        for rec in (
            select
                gt.gene_id,
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
            if rec.allele1_dom > rec.allele2_dom then
                v_effective_desc := rec.allele1_desc;
            elsif rec.allele2_dom > rec.allele1_dom then
                v_effective_desc := rec.allele2_desc;
            else
                if rec.dominance_type = 'INCOMPLETE' then
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
                else
                    v_effective_desc := rec.allele1_desc;
                end if;
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
               c.phenotype_summary = v_summary,
               c.updated_at = systimestamp
         where c.creature_id = p_creature_id;

        if sql%rowcount = 0 then
            raise_application_error(-20026, 'Creature not found.');
        end if;

        return v_summary;
    exception
        when others then
            raise;
    end get_phenotype;

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
    begin
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
            phenotype_summary,
            created_at,
            updated_at
        ) values (
            p_offspring_id,
            p_lab_id,
            v_parent1_species_type,
            trim(p_offspring_name),
            null,
            null,
            null,
            null,
            null,
            systimestamp,
            systimestamp
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
                allele2_id,
                created_at
            ) values (
                genotypes_seq.nextval,
                p_offspring_id,
                rec.gene_id,
                v_selected_allele1_id,
                v_selected_allele2_id,
                systimestamp
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
            experiment_type,
            created_at
        ) values (
            v_experiment_id,
            p_lab_id,
            p_parent1_id,
            p_parent2_id,
            null,
            p_offspring_id,
            'CROSS',
            systimestamp
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
    begin
        if p_new_name is null or trim(p_new_name) is null then
            raise_application_error(-20038, 'New creature name cannot be empty.');
        end if;

        update creatures c
           set c.creature_name = trim(p_new_name),
               c.updated_at = systimestamp
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
                m.description,
                m.cost as price,
                m.rating_effect
              from mutations m
             order by m.cost, m.mutation_id;

        return v_cursor;
    end show_mutation_shop;

    function buy_mutation(
        p_lab_id          in number,
        p_mutation_id     in number
    ) return number is
        v_lab_wallet      number(12, 2);
        v_mutation_cost   number(12, 2);
        v_exists_count    number;
    begin
        select count(*)
          into v_exists_count
          from labs l
         where l.lab_id = p_lab_id;

        if v_exists_count = 0 then
            raise_application_error(-20040, 'Lab not found.');
        end if;

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
           set l.wallet = l.wallet - v_mutation_cost,
               l.updated_at = systimestamp
         where l.lab_id = p_lab_id;

        update lab_mutations lm
           set lm.quantity = lm.quantity + 1,
               lm.updated_at = systimestamp
         where lm.lab_id = p_lab_id
           and lm.mutation_id = p_mutation_id;

        if sql%rowcount = 0 then
            insert into lab_mutations (
                lab_mutation_id,
                lab_id,
                mutation_id,
                quantity,
                created_at,
                updated_at
            ) values (
                lab_mutations_seq.nextval,
                p_lab_id,
                p_mutation_id,
                1,
                systimestamp,
                systimestamp
            );
        end if;

        return 1;
    end buy_mutation;

    procedure apply_mutation(
        p_creature_id     in number,
        p_mutation_id     in number
    ) is
        v_lab_id                number;
        v_mutation_exists       number;
        v_mutation_stock        number;
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
        begin
            select c.lab_id
              into v_lab_id
              from creatures c
             where c.creature_id = p_creature_id;
        exception
            when no_data_found then
                raise_application_error(-20042, 'Creature not found.');
        end;

        select count(*)
          into v_mutation_exists
          from mutations m
         where m.mutation_id = p_mutation_id;

        if v_mutation_exists = 0 then
            raise_application_error(-20056, 'Mutation not found.');
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
           set lm.quantity = lm.quantity - 1,
               lm.updated_at = systimestamp
         where lm.lab_id = v_lab_id
           and lm.mutation_id = p_mutation_id
           and lm.quantity > 0;

        if sql%rowcount = 0 then
            raise_application_error(-20047, 'Failed to decrease mutation quantity.');
        end if;

        v_experiment_id := experiments_seq.nextval;

        insert into experiments (
            experiment_id,
            lab_id,
            parent1_id,
            parent2_id,
            mutation_id,
            offspring_id,
            experiment_type,
            created_at
        ) values (
            v_experiment_id,
            v_lab_id,
            p_creature_id,
            null,
            p_mutation_id,
            p_creature_id,
            'MUTATION',
            systimestamp
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
        v_target_gene_id        number;
        v_current_allele1_id    number;
        v_current_allele2_id    number;
        v_new_allele_id         number;
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
        if p_mutagen_type is null or trim(p_mutagen_type) is null then
            raise_application_error(-20048, 'Mutagen type cannot be empty.');
        end if;

        begin
            select
                c.lab_id,
                c.species_type,
                c.creature_name
              into
                v_lab_id,
                v_species_type,
                v_source_name
              from creatures c
             where c.creature_id = p_creature_id;
        exception
            when no_data_found then
                raise_application_error(-20049, 'Source creature not found.');
        end;

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
            phenotype_summary,
            created_at,
            updated_at
        ) values (
            p_new_creature_id,
            v_lab_id,
            v_species_type,
            v_new_name,
            null,
            null,
            null,
            null,
            null,
            systimestamp,
            systimestamp
        );

        insert into genotypes (
            genotype_id,
            creature_id,
            gene_id,
            allele1_id,
            allele2_id,
            created_at
        )
        select
            genotypes_seq.nextval,
            p_new_creature_id,
            g.gene_id,
            g.allele1_id,
            g.allele2_id,
            systimestamp
          from genotypes g
         where g.creature_id = p_creature_id;

        if sql%rowcount = 0 then
            raise_application_error(-20050, 'Source creature has no genotype rows.');
        end if;

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
                raise_application_error(-20051, 'Unable to select genotype row for mutagen.');
        end;

        v_selected_slot := pick_random_allele_side();
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
            experiment_type,
            created_at
        ) values (
            v_experiment_id,
            v_lab_id,
            p_creature_id,
            null,
            null,
            p_new_creature_id,
            'MUTAGEN',
            systimestamp
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
        v_parent1_lab_match number;
    begin
        if p_parent1_id is null then
            raise_application_error(-20052, 'Parent1 id is required.');
        end if;

        if p_parent2_id is not null then
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
            select count(*)
              into v_parent1_lab_match
              from creatures c
             where c.creature_id = p_parent1_id
               and c.lab_id = p_lab_id;

            if v_parent1_lab_match = 0 then
                raise_application_error(-20053, 'Parent1 creature does not belong to the selected lab.');
            end if;

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
        v_exists_count number;
    begin
        select count(*)
          into v_exists_count
          from labs l
         where l.lab_id = p_lab_id;

        if v_exists_count = 0 then
            raise_application_error(-20055, 'Lab not found.');
        end if;

        open v_cursor for
            select
                e.experiment_id,
                e.experiment_type,
                e.parent1_id,
                p1.creature_name as parent1_name,
                e.parent2_id,
                p2.creature_name as parent2_name,
                e.offspring_id,
                o.creature_name as offspring_name,
                e.mutation_id,
                m.mutation_name,
                e.created_at
              from experiments e
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
             order by e.created_at desc, e.experiment_id desc;

        return v_cursor;
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
        v_species_type          number;
        v_variant               number;
        v_creature_id           number;
        v_wallet                number;
        v_rating                number;
        v_creature_count        number;
        v_active_task_count     number;
        v_completed_task_count  number;
        v_experiment_count      number;
    begin
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
        v_lab_count        number;
        v_creature_name    varchar2(255);
        v_allele1_id       number;
        v_allele2_id       number;
        v_summary          varchar2(1000);
    begin
        if p_species_type < 1 or p_species_type > 6 then
            raise_application_error(-20027, 'Invalid species_type. Expected value from 1 to 6.');
        end if;

        select count(*)
          into v_lab_count
          from labs l
         where l.lab_id = p_lab_id;

        if v_lab_count = 0 then
            raise_application_error(-20028, 'Lab not found.');
        end if;

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
            phenotype_summary,
            created_at,
            updated_at
        ) values (
            p_creature_id,
            p_lab_id,
            p_species_type,
            v_creature_name,
            null,
            null,
            null,
            null,
            null,
            systimestamp,
            systimestamp
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
                allele2_id,
                created_at
            ) values (
                genotypes_seq.nextval,
                p_creature_id,
                g.gene_id,
                v_allele1_id,
                v_allele2_id,
                systimestamp
            );
        end loop;

        v_summary := get_phenotype(p_creature_id => p_creature_id);
    end create_creature_of_type;
end pkg_genetics_game;
/

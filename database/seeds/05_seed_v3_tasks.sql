-- Version 3 morphology task catalogue.
-- Reference data only: this script never inserts into LAB_TASKS and does not change task runtime.

set define off;

declare
    v_task_id      number;
    v_allele_id    number;
    v_match_count  number;

    procedure upsert_task(
        p_task_name       in varchar2,
        p_description     in varchar2,
        p_rating_reward   in number,
        p_money_reward    in number,
        p_difficulty_code in varchar2
    ) is
    begin
        merge into tasks target
        using (select p_task_name as task_name from dual) source
           on (target.task_name = source.task_name)
        when matched then
            update set
                target.description = p_description,
                target.rating_reward = p_rating_reward,
                target.money_reward = p_money_reward,
                target.difficulty_code = p_difficulty_code,
                target.genetics_version = 3
        when not matched then
            insert (
                task_id,
                task_name,
                description,
                rating_reward,
                money_reward,
                difficulty_code,
                genetics_version,
                created_at
            )
            values (
                tasks_seq.nextval,
                p_task_name,
                p_description,
                p_rating_reward,
                p_money_reward,
                p_difficulty_code,
                3,
                systimestamp
            );
    end upsert_task;

    procedure upsert_marker(
        p_task_name    in varchar2,
        p_gene_name    in varchar2,
        p_allele_code  in varchar2
    ) is
    begin
        select count(*)
          into v_match_count
          from tasks t
         where t.task_name = p_task_name
           and t.genetics_version = 3;

        if v_match_count <> 1 then
            raise_application_error(-20933, 'V3 task was not resolved exactly once: ' || p_task_name || '.');
        end if;

        select t.task_id
          into v_task_id
          from tasks t
         where t.task_name = p_task_name;

        select count(*)
          into v_match_count
          from ref_genetics_model_genes membership
          join genes g
            on g.gene_id = membership.gene_id
         where membership.genetics_version = 3
           and g.species_type = 0
           and g.gene_name = p_gene_name;

        if v_match_count <> 1 then
            raise_application_error(-20934, 'V3 model does not resolve exactly one gene: ' || p_gene_name || '.');
        end if;

        select count(*)
          into v_match_count
          from alleles a
          join genes g
            on g.gene_id = a.gene_id
          join ref_genetics_model_genes membership
            on membership.gene_id = g.gene_id
           and membership.genetics_version = 3
         where g.species_type = 0
           and g.gene_name = p_gene_name
           and a.description = p_allele_code;

        if v_match_count <> 1 then
            raise_application_error(
                -20935,
                'V3 task marker was not resolved exactly once: ' || p_gene_name || '=' || p_allele_code || '.'
            );
        end if;

        select a.allele_id
          into v_allele_id
          from alleles a
          join genes g
            on g.gene_id = a.gene_id
          join ref_genetics_model_genes membership
            on membership.gene_id = g.gene_id
           and membership.genetics_version = 3
         where g.species_type = 0
           and g.gene_name = p_gene_name
           and a.description = p_allele_code;

        merge into task_markers target
        using (select v_task_id as task_id, v_allele_id as allele_id from dual) source
           on (target.task_id = source.task_id and target.allele_id = source.allele_id)
        when not matched then
            insert (task_marker_id, task_id, allele_id)
            values (task_markers_seq.nextval, source.task_id, source.allele_id);
    end upsert_marker;
begin
    upsert_task('task_v3_disc_saw', 'Требуется дискообразная форма тела и пилообразное рыло.', 30, 900, 'MEDIUM');
    upsert_task('task_v3_eel_yellow', 'Требуется угреобразная форма тела и жёлтый окрас.', 30, 900, 'MEDIUM');
    upsert_task('task_v3_shrimp_claws', 'Требуется креветкообразная форма тела и клешни.', 35, 1100, 'HARD');
    upsert_task('task_v3_cephalopod_shell', 'Требуется головоногая форма тела и раковина на спине.', 40, 1300, 'HARD');
    upsert_task('task_v3_snake_shell', 'Требуется змеевидная форма тела и панцирь на спине.', 40, 1200, 'HARD');
    upsert_task('task_v3_cetacean_broad', 'Требуется китообразная форма тела и широкие пропорции.', 35, 1000, 'HARD');
    upsert_task('task_v3_brown_cetacean', 'Требуется китообразная форма тела и коричневый окрас.', 45, 1400, 'HARD');
    upsert_task('task_v3_giant_pinniped', 'Требуется ластоногая форма тела и гигантский размер.', 50, 1600, 'HARD');
    upsert_task('task_v3_disc_fish_tail', 'Требуется дискообразная форма тела и рыбный хвост.', 55, 1800, 'HARD');
    upsert_task('task_v3_cetacean_rear_flippers', 'Требуется китообразная форма тела и задние ласты.', 50, 1500, 'HARD');
    upsert_task('task_v3_white_broad_cephalopod', 'Требуется белая головоногая форма тела с широкими пропорциями.', 55, 1700, 'HARD');
    upsert_task('task_v3_long_tailed_predator', 'Требуется вытянутый хвост, крупный размер и хищное питание.', 60, 2000, 'HARD');

    upsert_marker('task_v3_disc_saw', 'body_shape', 'disc');
    upsert_marker('task_v3_disc_saw', 'snout_type', 'saw');

    upsert_marker('task_v3_eel_yellow', 'body_shape', 'eel_like');
    upsert_marker('task_v3_eel_yellow', 'body_color', 'yellow');

    upsert_marker('task_v3_shrimp_claws', 'body_shape', 'shrimp_like');
    upsert_marker('task_v3_shrimp_claws', 'front_appendage_type', 'claw');

    upsert_marker('task_v3_cephalopod_shell', 'body_shape', 'cephalopod');
    upsert_marker('task_v3_cephalopod_shell', 'dorsal_type', 'shell');

    upsert_marker('task_v3_snake_shell', 'body_shape', 'eel_like');
    upsert_marker('task_v3_snake_shell', 'dorsal_type', 'shell');

    upsert_marker('task_v3_cetacean_broad', 'body_shape', 'cetacean');
    upsert_marker('task_v3_cetacean_broad', 'body_proportion', 'broad');

    upsert_marker('task_v3_brown_cetacean', 'body_shape', 'cetacean');
    upsert_marker('task_v3_brown_cetacean', 'body_color', 'brown');

    upsert_marker('task_v3_giant_pinniped', 'body_shape', 'pinniped');
    upsert_marker('task_v3_giant_pinniped', 'body_size', 'giant');

    upsert_marker('task_v3_disc_fish_tail', 'body_shape', 'disc');
    upsert_marker('task_v3_disc_fish_tail', 'tail_type', 'fish');

    upsert_marker('task_v3_cetacean_rear_flippers', 'body_shape', 'cetacean');
    upsert_marker('task_v3_cetacean_rear_flippers', 'rear_appendage_type', 'flipper');

    upsert_marker('task_v3_white_broad_cephalopod', 'body_shape', 'cephalopod');
    upsert_marker('task_v3_white_broad_cephalopod', 'body_color', 'white');
    upsert_marker('task_v3_white_broad_cephalopod', 'body_proportion', 'broad');

    upsert_marker('task_v3_long_tailed_predator', 'tail_type', 'elongated');
    upsert_marker('task_v3_long_tailed_predator', 'body_size', 'large');
    upsert_marker('task_v3_long_tailed_predator', 'nutrition_type', 'carnivore');

    commit;
end;
/

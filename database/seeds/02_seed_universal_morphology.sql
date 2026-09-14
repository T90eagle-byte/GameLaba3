-- Shared seed for the lr3-v3 universal morphology dictionary.
-- It is invoked from the core seed for fresh schemas and from migration 05
-- for existing schemas after GENES.GAMEPLAY_ENABLED is available.

set define off;

declare
    v_gate_column_count number;

    procedure upsert_gene(
        p_gene_name    in varchar2,
        p_description  in varchar2
    ) is
    begin
        merge into genes target
        using (
            select p_gene_name as gene_name from dual
        ) source
        on (target.gene_name = source.gene_name and target.species_type = 0)
        when matched then
            update set
                target.gene_type = 'morphology',
                target.dominance_type = 'FULL',
                target.linkage_group = null,
                target.description = p_description,
                target.gameplay_enabled = 'N'
        when not matched then
            insert (
                gene_id,
                gene_type,
                species_type,
                dominance_type,
                linkage_group,
                gameplay_enabled,
                gene_name,
                description,
                created_at
            )
            values (
                genes_seq.nextval,
                'morphology',
                0,
                'FULL',
                null,
                'N',
                p_gene_name,
                p_description,
                systimestamp
            );
    end upsert_gene;

    procedure upsert_allele(
        p_gene_name    in varchar2,
        p_code         in varchar2,
        p_description  in varchar2,
        p_position     in number
    ) is
        v_gene_id number;
    begin
        select gene_id
          into v_gene_id
          from genes
         where gene_name = p_gene_name
           and species_type = 0;

        merge into alleles target
        using (
            select v_gene_id as gene_id, p_code as description from dual
        ) source
        on (target.gene_id = source.gene_id and target.description = source.description)
        when matched then
            update set
                target.dominance = 100 - p_position,
                target.trait_value = p_position * 10
        when not matched then
            insert (allele_id, gene_id, dominance, description, trait_value, created_at)
            values (alleles_seq.nextval, v_gene_id, 100 - p_position, p_code, p_position * 10, systimestamp);
    end upsert_allele;

    procedure seed_gene(
        p_gene_name    in varchar2,
        p_description  in varchar2
    ) is
    begin
        upsert_gene(p_gene_name, p_description);
    end seed_gene;
begin
    select count(*)
      into v_gate_column_count
      from user_tab_columns
     where table_name = 'GENES'
       and column_name = 'GAMEPLAY_ENABLED';

    if v_gate_column_count = 0 then
        dbms_output.put_line('Universal morphology seed skipped: GENES.GAMEPLAY_ENABLED is not installed yet.');
    else

    seed_gene('body_shape', 'Форма тела');
    seed_gene('body_proportion', 'Пропорции тела');
    seed_gene('body_size', 'Размер тела');
    seed_gene('body_cover', 'Покров тела');
    seed_gene('body_color', 'Окрас тела');
    seed_gene('mouth_type', 'Тип рта');
    seed_gene('snout_type', 'Тип рыла');
    seed_gene('eye_type', 'Тип глаз');
    seed_gene('front_appendage_count', 'Количество передних конечностей');
    seed_gene('front_appendage_type', 'Тип передних конечностей');
    seed_gene('front_appendage_size', 'Размер передних конечностей');
    seed_gene('rear_appendage_count', 'Количество задних конечностей');
    seed_gene('rear_appendage_type', 'Тип задних конечностей');
    seed_gene('rear_appendage_size', 'Размер задних конечностей');
    seed_gene('tail_type', 'Тип хвоста');
    seed_gene('tail_size', 'Размер хвоста');
    seed_gene('dorsal_type', 'Тип спинного покрова');
    seed_gene('dorsal_size', 'Размер спинного покрова');

    upsert_allele('body_shape', 'streamlined', 'Обтекаемая форма', 1);
    upsert_allele('body_shape', 'shark_like', 'Акулоподобная форма', 2);
    upsert_allele('body_shape', 'disc', 'Дисковидная форма', 3);
    upsert_allele('body_shape', 'eel_like', 'Угреобразная форма', 4);
    upsert_allele('body_shape', 'cetacean', 'Китообразная форма', 5);
    upsert_allele('body_shape', 'pinniped', 'Ластоногая форма', 6);
    upsert_allele('body_shape', 'crustacean', 'Ракообразная форма', 7);
    upsert_allele('body_shape', 'shrimp_like', 'Креветкообразная форма', 8);
    upsert_allele('body_shape', 'cephalopod', 'Головоногая форма', 9);
    upsert_allele('body_shape', 'snail_like', 'Улиткообразная форма', 10);

    upsert_allele('body_proportion', 'elongated', 'Вытянутые пропорции', 1);
    upsert_allele('body_proportion', 'compact', 'Компактные пропорции', 2);
    upsert_allele('body_proportion', 'broad', 'Широкие пропорции', 3);
    upsert_allele('body_proportion', 'flattened', 'Уплощённые пропорции', 4);
    upsert_allele('body_proportion', 'fusiform', 'Веретенообразные пропорции', 5);

    upsert_allele('body_size', 'small', 'Маленький размер', 1);
    upsert_allele('body_size', 'medium', 'Средний размер', 2);
    upsert_allele('body_size', 'large', 'Крупный размер', 3);
    upsert_allele('body_size', 'giant', 'Гигантский размер', 4);

    upsert_allele('body_cover', 'smooth_skin', 'Гладкая кожа', 1);
    upsert_allele('body_cover', 'scales', 'Чешуя', 2);
    upsert_allele('body_cover', 'rough_skin', 'Шероховатая кожа', 3);
    upsert_allele('body_cover', 'chitin', 'Хитиновый покров', 4);
    upsert_allele('body_cover', 'hard_shell', 'Твёрдый панцирь', 5);
    upsert_allele('body_cover', 'leathery_skin', 'Кожистый покров', 6);
    upsert_allele('body_cover', 'soft_body', 'Мягкое тело', 7);

    upsert_allele('body_color', 'gray', 'Серый окрас', 1);
    upsert_allele('body_color', 'blue', 'Синий окрас', 2);
    upsert_allele('body_color', 'green', 'Зелёный окрас', 3);
    upsert_allele('body_color', 'brown', 'Коричневый окрас', 4);
    upsert_allele('body_color', 'red', 'Красный окрас', 5);
    upsert_allele('body_color', 'orange', 'Оранжевый окрас', 6);
    upsert_allele('body_color', 'yellow', 'Жёлтый окрас', 7);
    upsert_allele('body_color', 'black', 'Чёрный окрас', 8);
    upsert_allele('body_color', 'white', 'Белый окрас', 9);

    upsert_allele('mouth_type', 'standard', 'Обычный рот', 1);
    upsert_allele('mouth_type', 'beak', 'Клюв', 2);
    upsert_allele('mouth_type', 'suction', 'Присосочный рот', 3);
    upsert_allele('mouth_type', 'filter_feeding', 'Фильтрующий рот', 4);
    upsert_allele('mouth_type', 'jawed', 'Челюстной рот', 5);

    upsert_allele('snout_type', 'standard', 'Обычное рыло', 1);
    upsert_allele('snout_type', 'pointed', 'Заострённое рыло', 2);
    upsert_allele('snout_type', 'blunt', 'Тупое рыло', 3);
    upsert_allele('snout_type', 'saw', 'Пилообразное рыло', 4);
    upsert_allele('snout_type', 'hammer', 'Молоткообразное рыло', 5);
    upsert_allele('snout_type', 'elongated', 'Вытянутое рыло', 6);

    upsert_allele('eye_type', 'standard', 'Обычные глаза', 1);
    upsert_allele('eye_type', 'large', 'Крупные глаза', 2);
    upsert_allele('eye_type', 'lateral', 'Боковые глаза', 3);
    upsert_allele('eye_type', 'stalked', 'Глаза на стебельках', 4);

    upsert_allele('front_appendage_count', 'zero', 'Нет передних конечностей', 1);
    upsert_allele('front_appendage_count', 'two', 'Две передние конечности', 2);
    upsert_allele('front_appendage_count', 'four', 'Четыре передние конечности', 3);
    upsert_allele('front_appendage_count', 'six', 'Шесть передних конечностей', 4);
    upsert_allele('front_appendage_count', 'eight', 'Восемь передних конечностей', 5);

    upsert_allele('front_appendage_type', 'none', 'Нет передних конечностей', 1);
    upsert_allele('front_appendage_type', 'fin', 'Передние плавники', 2);
    upsert_allele('front_appendage_type', 'flipper', 'Передние ласты', 3);
    upsert_allele('front_appendage_type', 'walking_leg', 'Передние ходильные ноги', 4);
    upsert_allele('front_appendage_type', 'claw', 'Передние клешни', 5);
    upsert_allele('front_appendage_type', 'tentacle', 'Передние щупальца', 6);

    upsert_allele('front_appendage_size', 'none', 'Нет передних конечностей', 1);
    upsert_allele('front_appendage_size', 'small', 'Малый размер передних конечностей', 2);
    upsert_allele('front_appendage_size', 'medium', 'Средний размер передних конечностей', 3);
    upsert_allele('front_appendage_size', 'large', 'Крупный размер передних конечностей', 4);

    upsert_allele('rear_appendage_count', 'zero', 'Нет задних конечностей', 1);
    upsert_allele('rear_appendage_count', 'two', 'Две задние конечности', 2);
    upsert_allele('rear_appendage_count', 'four', 'Четыре задние конечности', 3);
    upsert_allele('rear_appendage_count', 'six', 'Шесть задних конечностей', 4);
    upsert_allele('rear_appendage_count', 'eight', 'Восемь задних конечностей', 5);

    upsert_allele('rear_appendage_type', 'none', 'Нет задних конечностей', 1);
    upsert_allele('rear_appendage_type', 'fin', 'Задние плавники', 2);
    upsert_allele('rear_appendage_type', 'flipper', 'Задние ласты', 3);
    upsert_allele('rear_appendage_type', 'walking_leg', 'Задние ходильные ноги', 4);
    upsert_allele('rear_appendage_type', 'tentacle', 'Задние щупальца', 5);

    upsert_allele('rear_appendage_size', 'none', 'Нет задних конечностей', 1);
    upsert_allele('rear_appendage_size', 'small', 'Малый размер задних конечностей', 2);
    upsert_allele('rear_appendage_size', 'medium', 'Средний размер задних конечностей', 3);
    upsert_allele('rear_appendage_size', 'large', 'Крупный размер задних конечностей', 4);

    upsert_allele('tail_type', 'none', 'Нет хвоста', 1);
    upsert_allele('tail_type', 'fish', 'Рыбий хвост', 2);
    upsert_allele('tail_type', 'cetacean', 'Китообразный хвост', 3);
    upsert_allele('tail_type', 'crustacean', 'Ракообразный хвост', 4);
    upsert_allele('tail_type', 'elongated', 'Вытянутый хвост', 5);
    upsert_allele('tail_type', 'paddle', 'Веслообразный хвост', 6);

    upsert_allele('tail_size', 'none', 'Нет хвоста', 1);
    upsert_allele('tail_size', 'small', 'Малый размер хвоста', 2);
    upsert_allele('tail_size', 'medium', 'Средний размер хвоста', 3);
    upsert_allele('tail_size', 'large', 'Крупный размер хвоста', 4);

    upsert_allele('dorsal_type', 'none', 'Нет спинного покрова', 1);
    upsert_allele('dorsal_type', 'dorsal_fin', 'Спинной плавник', 2);
    upsert_allele('dorsal_type', 'shell', 'Раковина', 3);
    upsert_allele('dorsal_type', 'carapace', 'Панцирь', 4);
    upsert_allele('dorsal_type', 'ridge', 'Спинной гребень', 5);

    upsert_allele('dorsal_size', 'none', 'Нет спинного покрова', 1);
    upsert_allele('dorsal_size', 'small', 'Малый размер спинного покрова', 2);
    upsert_allele('dorsal_size', 'medium', 'Средний размер спинного покрова', 3);
    upsert_allele('dorsal_size', 'large', 'Крупный размер спинного покрова', 4);

    end if;

    commit;
end;
/

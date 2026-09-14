-- Shared seed for the lr3-v3 universal morphology dictionary.
-- It is invoked from the core seed for fresh schemas and from migration 05
-- for existing schemas after GENES.GAMEPLAY_ENABLED is available.

set define off;

declare
    v_gate_column_count number;
    v_display_name_column_count number;

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

        if v_display_name_column_count = 1 then
            execute immediate
                'update alleles set display_name = :display_name where gene_id = :gene_id and description = :code'
                using p_description, v_gene_id, p_code;
        end if;
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

    select count(*)
      into v_display_name_column_count
      from user_tab_columns
     where table_name = 'ALLELES'
       and column_name = 'DISPLAY_NAME';

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

    upsert_allele('body_shape', 'streamlined', 'Обтекаемая', 1);
    upsert_allele('body_shape', 'shark_like', 'Акулообразная', 2);
    upsert_allele('body_shape', 'disc', 'Дискообразная', 3);
    upsert_allele('body_shape', 'eel_like', 'Угреобразная', 4);
    upsert_allele('body_shape', 'cetacean', 'Китообразная', 5);
    upsert_allele('body_shape', 'pinniped', 'Ластоногая', 6);
    upsert_allele('body_shape', 'crustacean', 'Ракообразная', 7);
    upsert_allele('body_shape', 'shrimp_like', 'Креветкообразная', 8);
    upsert_allele('body_shape', 'cephalopod', 'Головоногая', 9);
    upsert_allele('body_shape', 'snail_like', 'Улиткообразная', 10);

    upsert_allele('body_proportion', 'elongated', 'Вытянутая', 1);
    upsert_allele('body_proportion', 'compact', 'Компактная', 2);
    upsert_allele('body_proportion', 'broad', 'Широкая', 3);
    upsert_allele('body_proportion', 'flattened', 'Сплющенная', 4);
    upsert_allele('body_proportion', 'fusiform', 'Веретенообразная', 5);

    upsert_allele('body_size', 'small', 'Маленький', 1);
    upsert_allele('body_size', 'medium', 'Средний', 2);
    upsert_allele('body_size', 'large', 'Крупный', 3);
    upsert_allele('body_size', 'giant', 'Гигантский', 4);

    upsert_allele('body_cover', 'smooth_skin', 'Гладкая кожа', 1);
    upsert_allele('body_cover', 'scales', 'Чешуя', 2);
    upsert_allele('body_cover', 'rough_skin', 'Шероховатая кожа', 3);
    upsert_allele('body_cover', 'chitin', 'Хитиновый покров', 4);
    upsert_allele('body_cover', 'hard_shell', 'Твёрдый панцирь', 5);
    upsert_allele('body_cover', 'leathery_skin', 'Кожистый покров', 6);
    upsert_allele('body_cover', 'soft_body', 'Мягкое тело', 7);

    upsert_allele('body_color', 'gray', 'Серый', 1);
    upsert_allele('body_color', 'blue', 'Синий', 2);
    upsert_allele('body_color', 'green', 'Зелёный', 3);
    upsert_allele('body_color', 'brown', 'Коричневый', 4);
    upsert_allele('body_color', 'red', 'Красный', 5);
    upsert_allele('body_color', 'orange', 'Оранжевый', 6);
    upsert_allele('body_color', 'yellow', 'Жёлтый', 7);
    upsert_allele('body_color', 'black', 'Чёрный', 8);
    upsert_allele('body_color', 'white', 'Белый', 9);

    upsert_allele('mouth_type', 'standard', 'Обычный', 1);
    upsert_allele('mouth_type', 'beak', 'Клюв', 2);
    upsert_allele('mouth_type', 'suction', 'Присасывающий', 3);
    upsert_allele('mouth_type', 'filter_feeding', 'Фильтрующий', 4);
    upsert_allele('mouth_type', 'jawed', 'Челюстной', 5);

    upsert_allele('snout_type', 'standard', 'Обычная', 1);
    upsert_allele('snout_type', 'pointed', 'Заострённая', 2);
    upsert_allele('snout_type', 'blunt', 'Тупая', 3);
    upsert_allele('snout_type', 'saw', 'Пилообразная', 4);
    upsert_allele('snout_type', 'hammer', 'Молотообразная', 5);
    upsert_allele('snout_type', 'elongated', 'Вытянутая', 6);

    upsert_allele('eye_type', 'standard', 'Обычные', 1);
    upsert_allele('eye_type', 'large', 'Крупные', 2);
    upsert_allele('eye_type', 'lateral', 'Боковые', 3);
    upsert_allele('eye_type', 'stalked', 'На стебельках', 4);

    upsert_allele('front_appendage_count', 'zero', '0', 1);
    upsert_allele('front_appendage_count', 'two', '2', 2);
    upsert_allele('front_appendage_count', 'four', '4', 3);
    upsert_allele('front_appendage_count', 'six', '6', 4);
    upsert_allele('front_appendage_count', 'eight', '8', 5);

    upsert_allele('front_appendage_type', 'none', 'Отсутствуют', 1);
    upsert_allele('front_appendage_type', 'fin', 'Плавники', 2);
    upsert_allele('front_appendage_type', 'flipper', 'Ласты', 3);
    upsert_allele('front_appendage_type', 'walking_leg', 'Ходильные конечности', 4);
    upsert_allele('front_appendage_type', 'claw', 'Клешни', 5);
    upsert_allele('front_appendage_type', 'tentacle', 'Щупальца', 6);

    upsert_allele('front_appendage_size', 'none', 'Отсутствуют', 1);
    upsert_allele('front_appendage_size', 'small', 'Маленькие', 2);
    upsert_allele('front_appendage_size', 'medium', 'Средние', 3);
    upsert_allele('front_appendage_size', 'large', 'Крупные', 4);

    upsert_allele('rear_appendage_count', 'zero', '0', 1);
    upsert_allele('rear_appendage_count', 'two', '2', 2);
    upsert_allele('rear_appendage_count', 'four', '4', 3);
    upsert_allele('rear_appendage_count', 'six', '6', 4);
    upsert_allele('rear_appendage_count', 'eight', '8', 5);

    upsert_allele('rear_appendage_type', 'none', 'Отсутствуют', 1);
    upsert_allele('rear_appendage_type', 'fin', 'Плавники', 2);
    upsert_allele('rear_appendage_type', 'flipper', 'Ласты', 3);
    upsert_allele('rear_appendage_type', 'walking_leg', 'Ходильные конечности', 4);
    upsert_allele('rear_appendage_type', 'tentacle', 'Щупальца', 5);

    upsert_allele('rear_appendage_size', 'none', 'Отсутствуют', 1);
    upsert_allele('rear_appendage_size', 'small', 'Маленькие', 2);
    upsert_allele('rear_appendage_size', 'medium', 'Средние', 3);
    upsert_allele('rear_appendage_size', 'large', 'Крупные', 4);

    upsert_allele('tail_type', 'none', 'Отсутствует', 1);
    upsert_allele('tail_type', 'fish', 'Рыбий хвост', 2);
    upsert_allele('tail_type', 'cetacean', 'Китовый хвост', 3);
    upsert_allele('tail_type', 'crustacean', 'Хвост ракообразного', 4);
    upsert_allele('tail_type', 'elongated', 'Вытянутый хвост', 5);
    upsert_allele('tail_type', 'paddle', 'Веслообразный хвост', 6);

    upsert_allele('tail_size', 'none', 'Отсутствует', 1);
    upsert_allele('tail_size', 'small', 'Маленький', 2);
    upsert_allele('tail_size', 'medium', 'Средний', 3);
    upsert_allele('tail_size', 'large', 'Крупный', 4);

    upsert_allele('dorsal_type', 'none', 'Отсутствует', 1);
    upsert_allele('dorsal_type', 'dorsal_fin', 'Спинной плавник', 2);
    upsert_allele('dorsal_type', 'shell', 'Раковина', 3);
    upsert_allele('dorsal_type', 'carapace', 'Панцирь', 4);
    upsert_allele('dorsal_type', 'ridge', 'Спинной гребень', 5);

    upsert_allele('dorsal_size', 'none', 'Отсутствует', 1);
    upsert_allele('dorsal_size', 'small', 'Маленький', 2);
    upsert_allele('dorsal_size', 'medium', 'Средний', 3);
    upsert_allele('dorsal_size', 'large', 'Крупный', 4);

    end if;

    commit;
end;
/

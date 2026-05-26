set define off;

declare
    -- Species type mapping used in seed:
    -- 1 = cartilaginous_fish
    -- 2 = bony_fish
    -- 3 = crustaceans
    -- 4 = mollusks
    -- 5 = turtles
    -- 6 = mammals

    function get_gene_id(
        p_gene_name    in varchar2,
        p_species_type in number
    ) return number is
        v_gene_id number;
    begin
        select g.gene_id
          into v_gene_id
          from genes g
         where g.gene_name = p_gene_name
           and g.species_type = p_species_type;
        return v_gene_id;
    exception
        when no_data_found then
            raise_application_error(-21001, 'Gene not found: ' || p_gene_name || ' species=' || p_species_type);
    end get_gene_id;

    function get_allele_id(
        p_gene_name      in varchar2,
        p_species_type   in number,
        p_allele_desc    in varchar2
    ) return number is
        v_allele_id number;
    begin
        select a.allele_id
          into v_allele_id
          from alleles a
          join genes g
            on g.gene_id = a.gene_id
         where g.gene_name = p_gene_name
           and g.species_type = p_species_type
           and a.description = p_allele_desc;
        return v_allele_id;
    exception
        when no_data_found then
            raise_application_error(
                -21002,
                'Allele not found: gene=' || p_gene_name || ' species=' || p_species_type || ' desc=' || p_allele_desc
            );
    end get_allele_id;

    function get_mutation_id(
        p_mutation_name in varchar2
    ) return number is
        v_mutation_id number;
    begin
        select m.mutation_id
          into v_mutation_id
          from mutations m
         where m.mutation_name = p_mutation_name;
        return v_mutation_id;
    exception
        when no_data_found then
            raise_application_error(-21003, 'Mutation not found: ' || p_mutation_name);
    end get_mutation_id;

    function get_task_id(
        p_task_name in varchar2
    ) return number is
        v_task_id number;
    begin
        select t.task_id
          into v_task_id
          from tasks t
         where t.task_name = p_task_name;
        return v_task_id;
    exception
        when no_data_found then
            raise_application_error(-21004, 'Task not found: ' || p_task_name);
    end get_task_id;

    procedure upsert_gene(
        p_gene_type       in varchar2,
        p_species_type    in number,
        p_dominance_type  in varchar2,
        p_linkage_group   in number,
        p_gene_name       in varchar2,
        p_description     in varchar2
    ) is
    begin
        merge into genes tgt
        using (
            select
                p_gene_name as gene_name,
                p_species_type as species_type
            from dual
        ) src
        on (
            tgt.gene_name = src.gene_name
            and tgt.species_type = src.species_type
        )
        when matched then
            update set
                tgt.gene_type = p_gene_type,
                tgt.dominance_type = p_dominance_type,
                tgt.linkage_group = p_linkage_group,
                tgt.description = p_description
        when not matched then
            insert (
                gene_id,
                gene_type,
                species_type,
                dominance_type,
                linkage_group,
                gene_name,
                description,
                created_at
            )
            values (
                genes_seq.nextval,
                p_gene_type,
                p_species_type,
                p_dominance_type,
                p_linkage_group,
                p_gene_name,
                p_description,
                systimestamp
            );
    end upsert_gene;

    procedure upsert_allele(
        p_gene_name      in varchar2,
        p_species_type   in number,
        p_dominance      in number,
        p_allele_desc    in varchar2,
        p_trait_value    in number
    ) is
        v_gene_id number;
    begin
        v_gene_id := get_gene_id(p_gene_name, p_species_type);

        merge into alleles tgt
        using (
            select
                v_gene_id as gene_id,
                p_allele_desc as description
            from dual
        ) src
        on (
            tgt.gene_id = src.gene_id
            and tgt.description = src.description
        )
        when matched then
            update set
                tgt.dominance = p_dominance,
                tgt.trait_value = p_trait_value
        when not matched then
            insert (
                allele_id,
                gene_id,
                dominance,
                description,
                trait_value,
                created_at
            )
            values (
                alleles_seq.nextval,
                v_gene_id,
                p_dominance,
                p_allele_desc,
                p_trait_value,
                systimestamp
            );
    end upsert_allele;

    procedure upsert_mutation(
        p_mutation_name  in varchar2,
        p_mutation_type  in number,
        p_description    in varchar2,
        p_cost           in number,
        p_rating_effect  in number
    ) is
    begin
        merge into mutations tgt
        using (
            select p_mutation_name as mutation_name from dual
        ) src
        on (tgt.mutation_name = src.mutation_name)
        when matched then
            update set
                tgt.mutation_type = p_mutation_type,
                tgt.description = p_description,
                tgt.cost = p_cost,
                tgt.rating_effect = p_rating_effect
        when not matched then
            insert (
                mutation_id,
                mutation_name,
                mutation_type,
                description,
                cost,
                rating_effect,
                created_at
            )
            values (
                mutations_seq.nextval,
                p_mutation_name,
                p_mutation_type,
                p_description,
                p_cost,
                p_rating_effect,
                systimestamp
            );
    end upsert_mutation;

    procedure upsert_mutation_rule(
        p_mutation_name   in varchar2,
        p_gene_name       in varchar2,
        p_species_type    in number,
        p_allele_desc     in varchar2,
        p_target_slot     in varchar2
    ) is
        v_mutation_id      number;
        v_gene_id          number;
        v_target_allele_id number;
    begin
        v_mutation_id := get_mutation_id(p_mutation_name);
        v_gene_id := get_gene_id(p_gene_name, p_species_type);
        v_target_allele_id := get_allele_id(p_gene_name, p_species_type, p_allele_desc);

        merge into mutation_rules tgt
        using (
            select
                v_mutation_id as mutation_id,
                v_gene_id as gene_id,
                v_target_allele_id as target_allele_id,
                p_target_slot as target_slot
            from dual
        ) src
        on (
            tgt.mutation_id = src.mutation_id
            and tgt.gene_id = src.gene_id
            and tgt.target_allele_id = src.target_allele_id
            and tgt.target_slot = src.target_slot
        )
        when not matched then
            insert (
                mutation_rule_id,
                mutation_id,
                gene_id,
                target_allele_id,
                target_slot,
                created_at
            )
            values (
                mutation_rules_seq.nextval,
                v_mutation_id,
                v_gene_id,
                v_target_allele_id,
                p_target_slot,
                systimestamp
            );
    end upsert_mutation_rule;

    procedure upsert_task(
        p_task_name       in varchar2,
        p_description     in varchar2,
        p_rating_reward   in number,
        p_money_reward    in number
    ) is
    begin
        merge into tasks tgt
        using (
            select p_task_name as task_name from dual
        ) src
        on (tgt.task_name = src.task_name)
        when matched then
            update set
                tgt.description = p_description,
                tgt.rating_reward = p_rating_reward,
                tgt.money_reward = p_money_reward
        when not matched then
            insert (
                task_id,
                task_name,
                description,
                rating_reward,
                money_reward,
                created_at
            )
            values (
                tasks_seq.nextval,
                p_task_name,
                p_description,
                p_rating_reward,
                p_money_reward,
                systimestamp
            );
    end upsert_task;

    procedure upsert_task_marker(
        p_task_name       in varchar2,
        p_gene_name       in varchar2,
        p_species_type    in number,
        p_allele_desc     in varchar2
    ) is
        v_task_id    number;
        v_allele_id  number;
    begin
        v_task_id := get_task_id(p_task_name);
        v_allele_id := get_allele_id(p_gene_name, p_species_type, p_allele_desc);

        merge into task_markers tgt
        using (
            select
                v_task_id as task_id,
                v_allele_id as allele_id
            from dual
        ) src
        on (
            tgt.task_id = src.task_id
            and tgt.allele_id = src.allele_id
        )
        when not matched then
            insert (
                task_marker_id,
                task_id,
                allele_id
            )
            values (
                task_markers_seq.nextval,
                v_task_id,
                v_allele_id
            );
    end upsert_task_marker;
begin
    -- -------------------------------------------------------------------------
    -- 1) Genes (4 universal + species-specific genes)
    -- -------------------------------------------------------------------------
    upsert_gene('trait', 0, 'FULL', null, 'color', 'Body color trait');
    upsert_gene('trait', 0, 'INCOMPLETE', null, 'size', 'Overall body size');
    upsert_gene('trait', 0, 'CODOMINANT', null, 'nutrition_type', 'Feeding behavior');
    upsert_gene('trait', 0, 'FULL', null, 'has_wings', 'Wing availability');

    upsert_gene('morphology', 1, 'FULL', 101, 'fin_shape', 'Fin shape for cartilaginous fish');
    upsert_gene('morphology', 2, 'FULL', 201, 'fin_shape', 'Fin shape for bony fish');
    upsert_gene('morphology', 3, 'FULL', null, 'shell_armor', 'Shell armor for crustaceans');
    upsert_gene('morphology', 3, 'FULL', null, 'claw_form', 'Claw form for crustaceans');
    upsert_gene('morphology', 4, 'FULL', null, 'beak_nose_shape', 'Beak or nose form for mollusks');
    upsert_gene('morphology', 5, 'FULL', 501, 'shell_armor', 'Shell armor for turtles');
    upsert_gene('performance', 5, 'FULL', 501, 'speed_level', 'Movement speed for turtles');
    upsert_gene('morphology', 6, 'FULL', null, 'fur_density', 'Fur density for mammals');

    -- -------------------------------------------------------------------------
    -- 2) Alleles (minimum 2 per gene)
    -- -------------------------------------------------------------------------
    upsert_allele('color', 0, 2, 'green_color', 10);
    upsert_allele('color', 0, 1, 'blue_color', 20);

    upsert_allele('size', 0, 2, 'compact_size', 10);
    upsert_allele('size', 0, 1, 'large_size', 20);

    upsert_allele('nutrition_type', 0, 2, 'herbivore', 10);
    upsert_allele('nutrition_type', 0, 1, 'carnivore', 20);

    upsert_allele('has_wings', 0, 2, 'no_wings', 0);
    upsert_allele('has_wings', 0, 1, 'wings', 1);

    upsert_allele('fin_shape', 1, 2, 'pointed_fin', 10);
    upsert_allele('fin_shape', 1, 1, 'broad_fin', 20);

    upsert_allele('fin_shape', 2, 2, 'rounded_fin', 10);
    upsert_allele('fin_shape', 2, 1, 'forked_fin', 20);

    upsert_allele('shell_armor', 3, 2, 'thick_armor', 10);
    upsert_allele('shell_armor', 3, 1, 'light_armor', 20);

    upsert_allele('claw_form', 3, 2, 'short_claws', 10);
    upsert_allele('claw_form', 3, 1, 'long_claws', 20);

    upsert_allele('beak_nose_shape', 4, 2, 'rounded_nose', 10);
    upsert_allele('beak_nose_shape', 4, 1, 'sharp_beak', 20);

    upsert_allele('shell_armor', 5, 2, 'smooth_shell', 10);
    upsert_allele('shell_armor', 5, 1, 'spiked_shell', 20);

    upsert_allele('speed_level', 5, 2, 'slow_speed', 10);
    upsert_allele('speed_level', 5, 1, 'fast_speed', 20);

    upsert_allele('fur_density', 6, 2, 'short_fur', 10);
    upsert_allele('fur_density', 6, 1, 'dense_fur', 20);

    -- -------------------------------------------------------------------------
    -- 3) Mutations
    -- -------------------------------------------------------------------------
    upsert_mutation('radiation_mutation', 1, 'Radiation-driven randomization pressure', 150, -5);
    upsert_mutation('chemical_mutation', 2, 'Chemical transformation with controlled target', 130, -3);
    upsert_mutation('enhanced_color_mutation', 3, 'Boost color expression toward green', 200, 2);
    upsert_mutation('size_shift_mutation', 4, 'Shift body size toward large phenotype', 180, 1);
    upsert_mutation('nutrition_shift_mutation', 5, 'Shift feeding strategy toward carnivore pattern', 160, 1);
    upsert_mutation('wing_activation_mutation', 6, 'Activate wing trait expression where gene is present', 170, 1);
    upsert_mutation('aquatic_form_mutation', 7, 'Aquatic morphology shift for fins and turtle shell profile', 190, 2);
    upsert_mutation('morphology_refine_mutation', 8, 'Refine claws, beak/nose, and fur morphology', 210, 2);

    -- -------------------------------------------------------------------------
    -- 4) Mutation rules
    -- -------------------------------------------------------------------------
    upsert_mutation_rule('radiation_mutation', 'speed_level', 5, 'fast_speed', 'ANY');
    upsert_mutation_rule('chemical_mutation', 'shell_armor', 3, 'thick_armor', '1');
    upsert_mutation_rule('enhanced_color_mutation', 'color', 0, 'green_color', 'ANY');
    upsert_mutation_rule('size_shift_mutation', 'size', 0, 'large_size', 'ANY');

    upsert_mutation_rule('nutrition_shift_mutation', 'nutrition_type', 0, 'carnivore', 'ANY');
    upsert_mutation_rule('wing_activation_mutation', 'has_wings', 0, 'wings', 'ANY');

    upsert_mutation_rule('aquatic_form_mutation', 'fin_shape', 1, 'broad_fin', 'ANY');
    upsert_mutation_rule('aquatic_form_mutation', 'fin_shape', 2, 'forked_fin', 'ANY');
    upsert_mutation_rule('aquatic_form_mutation', 'shell_armor', 5, 'spiked_shell', 'ANY');

    upsert_mutation_rule('morphology_refine_mutation', 'claw_form', 3, 'long_claws', 'ANY');
    upsert_mutation_rule('morphology_refine_mutation', 'beak_nose_shape', 4, 'sharp_beak', 'ANY');
    upsert_mutation_rule('morphology_refine_mutation', 'fur_density', 6, 'dense_fur', 'ANY');

    -- -------------------------------------------------------------------------
    -- 5) Tasks
    -- -------------------------------------------------------------------------
    upsert_task(
        'task_green_specimen',
        'Create a specimen with green body color.',
        10,
        100
    );

    upsert_task(
        'task_winged_specimen',
        'Create a winged specimen for visual study.',
        12,
        120
    );

    upsert_task(
        'task_fast_turtle',
        'Create a turtle with fast movement.',
        15,
        150
    );

    upsert_task(
        'task_predator_fish_line',
        'Create a bony fish predator with forked fin morphology.',
        30,
        260
    );

    upsert_task(
        'task_armored_crustacean',
        'Create a large armored crustacean with long claws.',
        35,
        300
    );

    upsert_task(
        'task_dense_fur_mammal',
        'Create a mammal line with dense fur and green color.',
        40,
        340
    );

    upsert_task(
        'task_cartilaginous_fin_line',
        'Create a cartilaginous fish with broad_fin and carnivore nutrition.',
        28,
        250
    );

    upsert_task(
        'task_mollusk_sharp_profile',
        'Create a mollusk with sharp_beak and green color.',
        26,
        230
    );

    upsert_task(
        'task_large_specimen',
        'Get a large specimen with the large_size trait.',
        14,
        140
    );

    upsert_task(
        'task_herbivore_line',
        'Build a herbivore creature line.',
        16,
        160
    );

    upsert_task(
        'task_spiked_turtle',
        'Create a turtle with spiked_shell and fast_speed.',
        24,
        220
    );

    upsert_task(
        'task_mammal_short_fur',
        'Create a mammal with short_fur and compact_size.',
        22,
        210
    );

    -- -------------------------------------------------------------------------
    -- 6) Task markers
    -- -------------------------------------------------------------------------
    upsert_task_marker('task_green_specimen', 'color', 0, 'green_color');

    upsert_task_marker('task_winged_specimen', 'has_wings', 0, 'wings');

    upsert_task_marker('task_fast_turtle', 'speed_level', 5, 'fast_speed');
    upsert_task_marker('task_fast_turtle', 'shell_armor', 5, 'smooth_shell');

    upsert_task_marker('task_predator_fish_line', 'nutrition_type', 0, 'carnivore');
    upsert_task_marker('task_predator_fish_line', 'fin_shape', 2, 'forked_fin');

    upsert_task_marker('task_armored_crustacean', 'shell_armor', 3, 'thick_armor');
    upsert_task_marker('task_armored_crustacean', 'claw_form', 3, 'long_claws');
    upsert_task_marker('task_armored_crustacean', 'size', 0, 'large_size');

    upsert_task_marker('task_dense_fur_mammal', 'fur_density', 6, 'dense_fur');
    upsert_task_marker('task_dense_fur_mammal', 'color', 0, 'green_color');

    upsert_task_marker('task_cartilaginous_fin_line', 'fin_shape', 1, 'broad_fin');
    upsert_task_marker('task_cartilaginous_fin_line', 'nutrition_type', 0, 'carnivore');

    upsert_task_marker('task_mollusk_sharp_profile', 'beak_nose_shape', 4, 'sharp_beak');
    upsert_task_marker('task_mollusk_sharp_profile', 'color', 0, 'green_color');

    upsert_task_marker('task_large_specimen', 'size', 0, 'large_size');

    upsert_task_marker('task_herbivore_line', 'nutrition_type', 0, 'herbivore');

    upsert_task_marker('task_spiked_turtle', 'shell_armor', 5, 'spiked_shell');
    upsert_task_marker('task_spiked_turtle', 'speed_level', 5, 'fast_speed');

    upsert_task_marker('task_mammal_short_fur', 'fur_density', 6, 'short_fur');
    upsert_task_marker('task_mammal_short_fur', 'size', 0, 'compact_size');
end;
/

commit;

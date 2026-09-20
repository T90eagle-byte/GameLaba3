-- Общие справочные шаблоны морфологии lr3-v3.
-- Seed намеренно заполняет только REF_ARCHETYPE_ALLELES; исполняемый код пока его не использует.

set define off;

declare
    v_expected_rows number;
    v_resolved_rows number;

    procedure validate_template_source is
    begin
        with template_rows (
            archetype_code, body_shape, body_proportion, body_size, body_cover, body_color,
            mouth_type, snout_type, eye_type, front_appendage_count, front_appendage_type,
            front_appendage_size, rear_appendage_count, rear_appendage_type, rear_appendage_size,
            tail_type, tail_size, dorsal_type, dorsal_size
        ) as (
            select 'shark', 'shark_like', 'fusiform', 'large', 'rough_skin', 'gray', 'jawed', 'pointed', 'lateral', 'two', 'fin', 'medium', 'two', 'fin', 'small', 'fish', 'large', 'dorsal_fin', 'large' from dual union all
            select 'ray', 'disc', 'flattened', 'large', 'rough_skin', 'gray', 'standard', 'blunt', 'lateral', 'two', 'fin', 'large', 'zero', 'none', 'none', 'elongated', 'large', 'none', 'none' from dual union all
            select 'sawfish', 'shark_like', 'elongated', 'large', 'rough_skin', 'gray', 'jawed', 'saw', 'lateral', 'two', 'fin', 'medium', 'two', 'fin', 'small', 'fish', 'large', 'dorsal_fin', 'medium' from dual union all
            select 'generic_bony_fish', 'streamlined', 'fusiform', 'medium', 'scales', 'blue', 'standard', 'standard', 'lateral', 'two', 'fin', 'medium', 'two', 'fin', 'small', 'fish', 'medium', 'dorsal_fin', 'medium' from dual union all
            select 'eel', 'eel_like', 'elongated', 'medium', 'smooth_skin', 'green', 'jawed', 'pointed', 'lateral', 'zero', 'none', 'none', 'zero', 'none', 'none', 'elongated', 'large', 'ridge', 'medium' from dual union all
            select 'pufferfish', 'streamlined', 'compact', 'small', 'scales', 'yellow', 'beak', 'blunt', 'large', 'two', 'fin', 'small', 'two', 'fin', 'small', 'fish', 'small', 'dorsal_fin', 'small' from dual union all
            select 'crab', 'crustacean', 'broad', 'medium', 'chitin', 'red', 'standard', 'blunt', 'stalked', 'two', 'claw', 'large', 'eight', 'walking_leg', 'medium', 'none', 'none', 'carapace', 'large' from dual union all
            select 'crayfish', 'crustacean', 'elongated', 'medium', 'chitin', 'brown', 'standard', 'pointed', 'stalked', 'two', 'claw', 'large', 'eight', 'walking_leg', 'medium', 'crustacean', 'medium', 'carapace', 'medium' from dual union all
            select 'shrimp', 'shrimp_like', 'elongated', 'small', 'chitin', 'orange', 'standard', 'pointed', 'stalked', 'six', 'walking_leg', 'small', 'six', 'walking_leg', 'small', 'crustacean', 'medium', 'carapace', 'small' from dual union all
            select 'octopus', 'cephalopod', 'broad', 'medium', 'soft_body', 'red', 'beak', 'standard', 'large', 'eight', 'tentacle', 'large', 'zero', 'none', 'none', 'none', 'none', 'none', 'none' from dual union all
            select 'squid', 'cephalopod', 'elongated', 'medium', 'soft_body', 'white', 'beak', 'pointed', 'large', 'eight', 'tentacle', 'medium', 'two', 'tentacle', 'large', 'none', 'none', 'none', 'none' from dual union all
            select 'snail', 'snail_like', 'compact', 'small', 'soft_body', 'brown', 'standard', 'standard', 'stalked', 'zero', 'none', 'none', 'zero', 'none', 'none', 'none', 'none', 'shell', 'large' from dual union all
            select 'sea_turtle', 'streamlined', 'broad', 'large', 'leathery_skin', 'green', 'beak', 'blunt', 'lateral', 'two', 'flipper', 'large', 'two', 'flipper', 'medium', 'none', 'none', 'shell', 'large' from dual union all
            select 'sea_snake', 'eel_like', 'elongated', 'medium', 'scales', 'black', 'jawed', 'pointed', 'lateral', 'zero', 'none', 'none', 'zero', 'none', 'none', 'paddle', 'medium', 'none', 'none' from dual union all
            select 'whale', 'cetacean', 'fusiform', 'giant', 'smooth_skin', 'gray', 'filter_feeding', 'blunt', 'lateral', 'two', 'flipper', 'large', 'zero', 'none', 'none', 'cetacean', 'large', 'dorsal_fin', 'small' from dual union all
            select 'dolphin', 'cetacean', 'fusiform', 'medium', 'smooth_skin', 'gray', 'standard', 'elongated', 'lateral', 'two', 'flipper', 'medium', 'zero', 'none', 'none', 'cetacean', 'medium', 'dorsal_fin', 'medium' from dual union all
            select 'seal', 'pinniped', 'fusiform', 'medium', 'smooth_skin', 'gray', 'jawed', 'blunt', 'large', 'two', 'flipper', 'medium', 'two', 'flipper', 'medium', 'none', 'none', 'none', 'none' from dual union all
            select 'walrus', 'pinniped', 'broad', 'large', 'rough_skin', 'brown', 'jawed', 'elongated', 'standard', 'two', 'flipper', 'large', 'two', 'flipper', 'large', 'none', 'none', 'none', 'none' from dual
        ), expected_templates as (
            select archetype_code, lower(gene_name) as gene_name, allele_code
              from template_rows
              unpivot include nulls (allele_code for gene_name in (
                body_shape, body_proportion, body_size, body_cover, body_color,
                mouth_type, snout_type, eye_type, front_appendage_count, front_appendage_type,
                front_appendage_size, rear_appendage_count, rear_appendage_type, rear_appendage_size,
                tail_type, tail_size, dorsal_type, dorsal_size
              ))
        )
        select count(*),
               count(case
                   when r.archetype_id is not null
                    and a.allele_id is not null then 1
               end)
          into v_expected_rows, v_resolved_rows
          from expected_templates t
          left join ref_creature_archetypes r
            on r.archetype_code = t.archetype_code
          left join genes g
            on g.gene_name = t.gene_name
           and g.species_type = 0
           and g.gameplay_enabled = 'N'
          left join alleles a
            on a.gene_id = g.gene_id
           and a.description = t.allele_code;

        if v_expected_rows <> 324 or v_resolved_rows <> v_expected_rows then
            raise_application_error(
                -20860,
                'Archetype template seed requires all 18 archetypes and 18 disabled morphology genes with their declared alleles.'
            );
        end if;
    end validate_template_source;
begin
    validate_template_source;

    merge into ref_archetype_alleles target
    using (
        with template_rows (
            archetype_code, body_shape, body_proportion, body_size, body_cover, body_color,
            mouth_type, snout_type, eye_type, front_appendage_count, front_appendage_type,
            front_appendage_size, rear_appendage_count, rear_appendage_type, rear_appendage_size,
            tail_type, tail_size, dorsal_type, dorsal_size
        ) as (
            select 'shark', 'shark_like', 'fusiform', 'large', 'rough_skin', 'gray', 'jawed', 'pointed', 'lateral', 'two', 'fin', 'medium', 'two', 'fin', 'small', 'fish', 'large', 'dorsal_fin', 'large' from dual union all
            select 'ray', 'disc', 'flattened', 'large', 'rough_skin', 'gray', 'standard', 'blunt', 'lateral', 'two', 'fin', 'large', 'zero', 'none', 'none', 'elongated', 'large', 'none', 'none' from dual union all
            select 'sawfish', 'shark_like', 'elongated', 'large', 'rough_skin', 'gray', 'jawed', 'saw', 'lateral', 'two', 'fin', 'medium', 'two', 'fin', 'small', 'fish', 'large', 'dorsal_fin', 'medium' from dual union all
            select 'generic_bony_fish', 'streamlined', 'fusiform', 'medium', 'scales', 'blue', 'standard', 'standard', 'lateral', 'two', 'fin', 'medium', 'two', 'fin', 'small', 'fish', 'medium', 'dorsal_fin', 'medium' from dual union all
            select 'eel', 'eel_like', 'elongated', 'medium', 'smooth_skin', 'green', 'jawed', 'pointed', 'lateral', 'zero', 'none', 'none', 'zero', 'none', 'none', 'elongated', 'large', 'ridge', 'medium' from dual union all
            select 'pufferfish', 'streamlined', 'compact', 'small', 'scales', 'yellow', 'beak', 'blunt', 'large', 'two', 'fin', 'small', 'two', 'fin', 'small', 'fish', 'small', 'dorsal_fin', 'small' from dual union all
            select 'crab', 'crustacean', 'broad', 'medium', 'chitin', 'red', 'standard', 'blunt', 'stalked', 'two', 'claw', 'large', 'eight', 'walking_leg', 'medium', 'none', 'none', 'carapace', 'large' from dual union all
            select 'crayfish', 'crustacean', 'elongated', 'medium', 'chitin', 'brown', 'standard', 'pointed', 'stalked', 'two', 'claw', 'large', 'eight', 'walking_leg', 'medium', 'crustacean', 'medium', 'carapace', 'medium' from dual union all
            select 'shrimp', 'shrimp_like', 'elongated', 'small', 'chitin', 'orange', 'standard', 'pointed', 'stalked', 'six', 'walking_leg', 'small', 'six', 'walking_leg', 'small', 'crustacean', 'medium', 'carapace', 'small' from dual union all
            select 'octopus', 'cephalopod', 'broad', 'medium', 'soft_body', 'red', 'beak', 'standard', 'large', 'eight', 'tentacle', 'large', 'zero', 'none', 'none', 'none', 'none', 'none', 'none' from dual union all
            select 'squid', 'cephalopod', 'elongated', 'medium', 'soft_body', 'white', 'beak', 'pointed', 'large', 'eight', 'tentacle', 'medium', 'two', 'tentacle', 'large', 'none', 'none', 'none', 'none' from dual union all
            select 'snail', 'snail_like', 'compact', 'small', 'soft_body', 'brown', 'standard', 'standard', 'stalked', 'zero', 'none', 'none', 'zero', 'none', 'none', 'none', 'none', 'shell', 'large' from dual union all
            select 'sea_turtle', 'streamlined', 'broad', 'large', 'leathery_skin', 'green', 'beak', 'blunt', 'lateral', 'two', 'flipper', 'large', 'two', 'flipper', 'medium', 'none', 'none', 'shell', 'large' from dual union all
            select 'sea_snake', 'eel_like', 'elongated', 'medium', 'scales', 'black', 'jawed', 'pointed', 'lateral', 'zero', 'none', 'none', 'zero', 'none', 'none', 'paddle', 'medium', 'none', 'none' from dual union all
            select 'whale', 'cetacean', 'fusiform', 'giant', 'smooth_skin', 'gray', 'filter_feeding', 'blunt', 'lateral', 'two', 'flipper', 'large', 'zero', 'none', 'none', 'cetacean', 'large', 'dorsal_fin', 'small' from dual union all
            select 'dolphin', 'cetacean', 'fusiform', 'medium', 'smooth_skin', 'gray', 'standard', 'elongated', 'lateral', 'two', 'flipper', 'medium', 'zero', 'none', 'none', 'cetacean', 'medium', 'dorsal_fin', 'medium' from dual union all
            select 'seal', 'pinniped', 'fusiform', 'medium', 'smooth_skin', 'gray', 'jawed', 'blunt', 'large', 'two', 'flipper', 'medium', 'two', 'flipper', 'medium', 'none', 'none', 'none', 'none' from dual union all
            select 'walrus', 'pinniped', 'broad', 'large', 'rough_skin', 'brown', 'jawed', 'elongated', 'standard', 'two', 'flipper', 'large', 'two', 'flipper', 'large', 'none', 'none', 'none', 'none' from dual
        ), expected_templates as (
            select archetype_code, lower(gene_name) as gene_name, allele_code
              from template_rows
              unpivot include nulls (allele_code for gene_name in (
                body_shape, body_proportion, body_size, body_cover, body_color,
                mouth_type, snout_type, eye_type, front_appendage_count, front_appendage_type,
                front_appendage_size, rear_appendage_count, rear_appendage_type, rear_appendage_size,
                tail_type, tail_size, dorsal_type, dorsal_size
              ))
        )
        select r.archetype_id, g.gene_id, a.allele_id
          from expected_templates t
          join ref_creature_archetypes r
            on r.archetype_code = t.archetype_code
          join genes g
            on g.gene_name = t.gene_name
           and g.species_type = 0
           and g.gameplay_enabled = 'N'
          join alleles a
            on a.gene_id = g.gene_id
           and a.description = t.allele_code
    ) source
       on (target.archetype_id = source.archetype_id and target.gene_id = source.gene_id)
    when matched then
        update set target.allele1_id = source.allele_id,
                   target.allele2_id = source.allele_id
    when not matched then
        insert (archetype_id, gene_id, allele1_id, allele2_id)
        values (source.archetype_id, source.gene_id, source.allele_id, source.allele_id);

    commit;
end;
/

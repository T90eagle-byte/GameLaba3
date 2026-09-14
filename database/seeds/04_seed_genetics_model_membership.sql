-- Explicit canonical gene membership for laboratory genetics versions.
-- This is reference data only: it does not alter GENES, GENOTYPES, or LABS.

set define off;

declare
    type number_list is table of number index by pls_integer;
    type varchar2_list is table of varchar2(50 char) index by pls_integer;

    v_versions       number_list;
    v_species_types  number_list;
    v_gene_names     varchar2_list;
    v_gene_ids       number_list;
    v_gene_count     number;
    v_row_count      number;

    procedure expect_gene(
        p_genetics_version in number,
        p_species_type     in number,
        p_gene_name        in varchar2
    ) is
        v_index pls_integer;
    begin
        v_index := v_gene_names.count + 1;
        v_versions(v_index) := p_genetics_version;
        v_species_types(v_index) := p_species_type;
        v_gene_names(v_index) := p_gene_name;
    end expect_gene;

    procedure resolve_expected_genes is
    begin
        for i in 1 .. v_gene_names.count loop
            select count(*)
              into v_gene_count
              from genes g
             where g.gene_name = v_gene_names(i)
               and g.species_type = v_species_types(i);

            if v_gene_count <> 1 then
                raise_application_error(
                    -20910,
                    'Genetics model membership requires exactly one gene for version=' ||
                    v_versions(i) || ', species_type=' || v_species_types(i) ||
                    ', gene_name=' || v_gene_names(i) || '.'
                );
            end if;

            select g.gene_id
              into v_gene_ids(i)
              from genes g
             where g.gene_name = v_gene_names(i)
               and g.species_type = v_species_types(i);
        end loop;
    end resolve_expected_genes;
begin
    -- v1: exact legacy runtime model as it existed before universal morphology.
    expect_gene(1, 0, 'color');
    expect_gene(1, 0, 'size');
    expect_gene(1, 0, 'nutrition_type');
    expect_gene(1, 0, 'has_wings');
    expect_gene(1, 1, 'fin_shape');
    expect_gene(1, 2, 'fin_shape');
    expect_gene(1, 3, 'claw_form');
    expect_gene(1, 3, 'shell_armor');
    expect_gene(1, 4, 'beak_nose_shape');
    expect_gene(1, 5, 'shell_armor');
    expect_gene(1, 5, 'speed_level');
    expect_gene(1, 6, 'fur_density');

    -- v3: universal morphology core plus the retained nutrition gameplay trait.
    expect_gene(3, 0, 'body_shape');
    expect_gene(3, 0, 'body_proportion');
    expect_gene(3, 0, 'body_size');
    expect_gene(3, 0, 'body_cover');
    expect_gene(3, 0, 'body_color');
    expect_gene(3, 0, 'mouth_type');
    expect_gene(3, 0, 'snout_type');
    expect_gene(3, 0, 'eye_type');
    expect_gene(3, 0, 'front_appendage_count');
    expect_gene(3, 0, 'front_appendage_type');
    expect_gene(3, 0, 'front_appendage_size');
    expect_gene(3, 0, 'rear_appendage_count');
    expect_gene(3, 0, 'rear_appendage_type');
    expect_gene(3, 0, 'rear_appendage_size');
    expect_gene(3, 0, 'tail_type');
    expect_gene(3, 0, 'tail_size');
    expect_gene(3, 0, 'dorsal_type');
    expect_gene(3, 0, 'dorsal_size');
    expect_gene(3, 0, 'nutrition_type');

    resolve_expected_genes;

    delete from ref_genetics_model_genes
     where genetics_version in (1, 3);

    for i in 1 .. v_gene_names.count loop
        insert into ref_genetics_model_genes (genetics_version, gene_id)
        values (v_versions(i), v_gene_ids(i));
    end loop;

    select count(*)
      into v_row_count
      from ref_genetics_model_genes
     where genetics_version = 1;
    if v_row_count <> 12 then
        raise_application_error(-20911, 'Legacy genetics model membership must contain exactly 12 genes.');
    end if;

    select count(*)
      into v_row_count
      from ref_genetics_model_genes
     where genetics_version = 3;
    if v_row_count <> 19 then
        raise_application_error(-20912, 'V3 genetics model membership must contain exactly 19 genes.');
    end if;

    commit;
end;
/

-- Run this migration with the application stopped.
-- It adds data-only morphology archetypes and leaves all existing game state unchanged.
-- The migration is safe to rerun: existing archetypes are matched by archetype_code.

set define off;
set serveroutput on size unlimited;

declare
    v_count number;

    procedure require_base_schema is
    begin
        select count(*)
          into v_count
          from user_tables
         where table_name in ('REF_SPECIES_TYPES', 'GENES', 'ALLELES');

        if v_count <> 3 then
            raise_application_error(
                -20840,
                'Creature archetype migration requires REF_SPECIES_TYPES, GENES, and ALLELES.'
            );
        end if;
    end require_base_schema;

    procedure require_constraints(
        p_table_name in varchar2,
        p_expected    in number,
        p_names       in sys.odcivarchar2list
    ) is
    begin
        select count(*)
          into v_count
          from user_constraints
         where table_name = p_table_name
           and constraint_name in (select column_value from table(p_names))
           and status = 'ENABLED';

        if v_count <> p_expected then
            raise_application_error(
                -20841,
                'Creature archetype migration found an incomplete existing ' || lower(p_table_name) || ' definition.'
            );
        end if;
    end require_constraints;
begin
    require_base_schema;

    select count(*)
      into v_count
      from user_tables
     where table_name = 'REF_CREATURE_ARCHETYPES';

    if v_count = 0 then
        execute immediate q'[
            create table ref_creature_archetypes (
                archetype_id       number not null,
                species_type       number(1) not null,
                archetype_code     varchar2(60 char) not null,
                display_name       varchar2(100 char) not null,
                active_flag        char(1 char) default 'Y' not null,
                constraint pk_ref_creature_archetypes primary key (archetype_id),
                constraint uq_ref_creature_archetype_code unique (archetype_code),
                constraint fk_ref_archetype_species foreign key (species_type) references ref_species_types (species_type),
                constraint ck_ref_archetype_active check (active_flag in ('Y', 'N'))
            )]';
    end if;

    require_constraints(
        'REF_CREATURE_ARCHETYPES',
        4,
        sys.odcivarchar2list(
            'PK_REF_CREATURE_ARCHETYPES',
            'UQ_REF_CREATURE_ARCHETYPE_CODE',
            'FK_REF_ARCHETYPE_SPECIES',
            'CK_REF_ARCHETYPE_ACTIVE'
        )
    );

    select count(*)
      into v_count
      from user_tables
     where table_name = 'REF_ARCHETYPE_ALLELES';

    if v_count = 0 then
        execute immediate q'[
            create table ref_archetype_alleles (
                archetype_id       number not null,
                gene_id            number not null,
                allele1_id         number not null,
                allele2_id         number not null,
                constraint pk_ref_archetype_alleles primary key (archetype_id, gene_id),
                constraint fk_ref_arch_alleles_archetype foreign key (archetype_id) references ref_creature_archetypes (archetype_id),
                constraint fk_ref_arch_alleles_gene foreign key (gene_id) references genes (gene_id),
                constraint fk_ref_arch_alleles_a1 foreign key (allele1_id, gene_id) references alleles (allele_id, gene_id),
                constraint fk_ref_arch_alleles_a2 foreign key (allele2_id, gene_id) references alleles (allele_id, gene_id)
            )]';
    end if;

    require_constraints(
        'REF_ARCHETYPE_ALLELES',
        5,
        sys.odcivarchar2list(
            'PK_REF_ARCHETYPE_ALLELES',
            'FK_REF_ARCH_ALLELES_ARCHETYPE',
            'FK_REF_ARCH_ALLELES_GENE',
            'FK_REF_ARCH_ALLELES_A1',
            'FK_REF_ARCH_ALLELES_A2'
        )
    );

    select count(*)
      into v_count
      from user_sequences
     where sequence_name = 'REF_CREATURE_ARCHETYPES_SEQ';

    if v_count = 0 then
        execute immediate 'create sequence ref_creature_archetypes_seq start with 1 increment by 1 nocache nocycle';
    end if;
end;
/

declare
    procedure seed_archetype(
        p_species_type   in number,
        p_archetype_code in varchar2,
        p_display_name   in varchar2
    ) is
    begin
        merge into ref_creature_archetypes target
        using (
            select
                p_species_type as species_type,
                p_archetype_code as archetype_code,
                p_display_name as display_name
            from dual
        ) source
        on (target.archetype_code = source.archetype_code)
        when not matched then
            insert (archetype_id, species_type, archetype_code, display_name, active_flag)
            values (ref_creature_archetypes_seq.nextval, source.species_type, source.archetype_code, source.display_name, 'Y');
    end seed_archetype;
begin
    seed_archetype(1, 'shark', 'Акула');
    seed_archetype(1, 'ray', 'Скат');
    seed_archetype(1, 'sawfish', 'Рыба-пила');

    seed_archetype(2, 'generic_bony_fish', 'Костная рыба');
    seed_archetype(2, 'eel', 'Угорь');
    seed_archetype(2, 'pufferfish', 'Рыба-фугу');

    seed_archetype(3, 'crab', 'Краб');
    seed_archetype(3, 'crayfish', 'Речной рак');
    seed_archetype(3, 'shrimp', 'Креветка');

    seed_archetype(4, 'octopus', 'Осьминог');
    seed_archetype(4, 'squid', 'Кальмар');
    seed_archetype(4, 'snail', 'Улитка');

    seed_archetype(5, 'sea_turtle', 'Морская черепаха');
    seed_archetype(5, 'sea_snake', 'Морская змея');

    seed_archetype(6, 'whale', 'Кит');
    seed_archetype(6, 'dolphin', 'Дельфин');
    seed_archetype(6, 'seal', 'Тюлень');
    seed_archetype(6, 'walrus', 'Морж');

    commit;
end;
/

begin
    dbms_output.put_line('Creature archetype migration complete: reference tables and empty genotype templates are ready.');
end;
/

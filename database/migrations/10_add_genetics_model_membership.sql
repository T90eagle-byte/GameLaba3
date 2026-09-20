-- Запускайте миграцию при остановленном приложении.
-- Она добавляет справочный состав канонических генов для моделей лабораторий.

set define off;
set serveroutput on size unlimited;

declare
    v_table_count      number;
    v_constraint_count number;
begin
    select count(*)
      into v_table_count
      from user_tables
     where table_name = 'GENES';

    if v_table_count = 0 then
        raise_application_error(-20920, 'Genetics model membership migration requires GENES.');
    end if;

    select count(*)
      into v_table_count
      from user_tables
     where table_name = 'REF_GENETICS_MODEL_GENES';

    if v_table_count = 0 then
        execute immediate q'[
            create table ref_genetics_model_genes (
                genetics_version   number(2) not null,
                gene_id            number not null,
                constraint pk_ref_genetics_model_genes primary key (genetics_version, gene_id),
                constraint fk_ref_genetics_model_genes_gene foreign key (gene_id) references genes (gene_id),
                constraint ck_ref_genetics_model_genes_version check (genetics_version in (1, 3))
            )
        ]';
    end if;

    select count(*)
      into v_constraint_count
      from user_constraints
     where table_name = 'REF_GENETICS_MODEL_GENES'
       and constraint_name in (
           'PK_REF_GENETICS_MODEL_GENES',
           'FK_REF_GENETICS_MODEL_GENES_GENE',
           'CK_REF_GENETICS_MODEL_GENES_VERSION'
       )
       and status = 'ENABLED';

    if v_constraint_count <> 3 then
        raise_application_error(
            -20921,
            'REF_GENETICS_MODEL_GENES has an incomplete or disabled constraint definition.'
        );
    end if;
end;
/

@@../seeds/04_seed_genetics_model_membership.sql

begin
    dbms_output.put_line('Genetics model membership migration complete: v1 legacy and v3 core memberships are ready.');
end;
/

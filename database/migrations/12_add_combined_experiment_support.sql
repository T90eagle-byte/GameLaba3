prompt Adding combined crossbreed and mutagen experiment support...

declare
    v_count number;
begin
    select count(*)
      into v_count
      from user_tab_columns
     where table_name = 'EXPERIMENTS'
       and column_name = 'MUTAGEN_TYPE';

    if v_count = 0 then
        execute immediate 'alter table experiments add (mutagen_type varchar2(30 char) null)';
    end if;
end;
/

merge into ref_experiment_types target
using (
    select 'CROSSBREED_MUTAGEN' as experiment_type,
           'Скрещивание + мутаген' as display_name
      from dual
) source
on (target.experiment_type = source.experiment_type)
when matched then
    update set target.display_name = source.display_name
when not matched then
    insert (experiment_type, display_name)
    values (source.experiment_type, source.display_name);

declare
    v_count number;
begin
    select count(*)
      into v_count
      from user_constraints
     where table_name = 'EXPERIMENTS'
       and constraint_name = 'FK_EXPERIMENTS_MUTAGEN_TYPE';

    if v_count = 0 then
        execute immediate q'[
            alter table experiments add constraint fk_experiments_mutagen_type
            foreign key (mutagen_type) references ref_mutagen_types (mutagen_type)
        ]';
    end if;
end;
/

declare
    v_count number;
begin
    select count(*)
      into v_count
      from user_constraints
     where table_name = 'EXPERIMENTS'
       and constraint_name = 'CK_EXPERIMENTS_CROSS_REQUIRES_PARENT2';

    if v_count > 0 then
        execute immediate 'alter table experiments drop constraint ck_experiments_cross_requires_parent2';
    end if;

    execute immediate q'[
        alter table experiments add constraint ck_experiments_cross_requires_parent2 check (
            (
                experiment_type in ('CROSS', 'CROSSBREED_MUTAGEN')
                and parent2_id is not null
            )
            or (
                experiment_type in ('MUTATION', 'MUTAGEN')
                and parent2_id is null
            )
        )
    ]';
end;
/

declare
    v_count number;
begin
    select count(*)
      into v_count
      from user_constraints
     where table_name = 'EXPERIMENTS'
       and constraint_name = 'CK_EXPERIMENTS_COMBINED_FIELDS';

    if v_count = 0 then
        execute immediate q'[
            alter table experiments add constraint ck_experiments_combined_fields check (
                experiment_type <> 'CROSSBREED_MUTAGEN'
                or (mutagen_type is not null and mutation_id is null)
            )
        ]';
    end if;
end;
/

comment on column experiments.mutagen_type is
    'Mutagen code for combined experiments; historical MUTAGEN rows may remain null.';

commit;

prompt Combined experiment support is ready.

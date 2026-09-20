-- Запускайте при остановленном приложении. Миграция аддитивна и сохраняет
-- существующих существ, эксперименты и игровой прогресс.

set define off;
set serveroutput on size unlimited;

declare
    v_count number;
begin
    select count(*)
      into v_count
      from user_tables
     where table_name = 'REF_EXPERIMENT_ECONOMICS';

    if v_count = 0 then
        execute immediate q'[
            create table ref_experiment_economics (
                experiment_type    varchar2(30 char) not null,
                genetics_version   number(2) not null,
                mutagen_type       varchar2(30 char) not null,
                wallet_cost        number(12, 2) default 0 not null,
                rating_effect      number(12, 2) default 0 not null,
                active_flag        char(1 char) default 'Y' not null,
                constraint pk_ref_experiment_economics primary key (experiment_type, genetics_version, mutagen_type),
                constraint fk_ref_exp_econ_experiment foreign key (experiment_type) references ref_experiment_types (experiment_type),
                constraint fk_ref_exp_econ_mutagen foreign key (mutagen_type) references ref_mutagen_types (mutagen_type),
                constraint ck_ref_exp_econ_version check (genetics_version in (1, 3)),
                constraint ck_ref_exp_econ_wallet check (wallet_cost >= 0),
                constraint ck_ref_exp_econ_active check (active_flag in ('Y', 'N'))
            )
        ]';
    end if;

    select count(*)
      into v_count
      from user_tab_columns
     where table_name = 'REF_EXPERIMENT_ECONOMICS'
       and column_name in (
           'EXPERIMENT_TYPE', 'GENETICS_VERSION', 'MUTAGEN_TYPE',
           'WALLET_COST', 'RATING_EFFECT', 'ACTIVE_FLAG'
       );

    if v_count <> 6 then
        raise_application_error(-20960, 'REF_EXPERIMENT_ECONOMICS has an incompatible definition.');
    end if;
end;
/

comment on table ref_experiment_economics is
    'Version-aware economics for configured compound experiments.';
comment on column ref_experiment_economics.rating_effect is
    'Configured rating delta; the recorded event stores the actual delta after clamping.';

merge into ref_species_types target
using (select 7 as species_type, 'Гибрид' as display_name from dual) source
on (target.species_type = source.species_type)
when matched then update set target.display_name = source.display_name
when not matched then insert (species_type, display_name)
values (source.species_type, source.display_name);

merge into ref_experiment_types target
using (select 'HYBRIDIZATION' as experiment_type, 'Гибридизация' as display_name from dual) source
on (target.experiment_type = source.experiment_type)
when matched then update set target.display_name = source.display_name
when not matched then insert (experiment_type, display_name)
values (source.experiment_type, source.display_name);

merge into ref_rating_event_types target
using (select 'HYBRIDIZATION_PENALTY' as event_type, 'Штраф за гибридизацию' as display_name from dual) source
on (target.event_type = source.event_type)
when matched then update set target.display_name = source.display_name
when not matched then insert (event_type, display_name)
values (source.event_type, source.display_name);

merge into ref_mutagen_types target
using (
    select 'RADIATION' as mutagen_type, 'Облучение' as display_name from dual
    union all
    select 'CHEMICAL', 'Химический мутаген' from dual
) source
on (target.mutagen_type = source.mutagen_type)
when matched then update set target.display_name = source.display_name
when not matched then insert (mutagen_type, display_name)
values (source.mutagen_type, source.display_name);

merge into ref_experiment_economics target
using (
    select 'HYBRIDIZATION' as experiment_type, 3 as genetics_version,
           'RADIATION' as mutagen_type, 0 as wallet_cost,
           -50 as rating_effect, 'Y' as active_flag
      from dual
) source
on (
    target.experiment_type = source.experiment_type
    and target.genetics_version = source.genetics_version
    and target.mutagen_type = source.mutagen_type
)
when matched then update set
    target.wallet_cost = source.wallet_cost,
    target.rating_effect = source.rating_effect,
    target.active_flag = source.active_flag
when not matched then insert (
    experiment_type, genetics_version, mutagen_type,
    wallet_cost, rating_effect, active_flag
) values (
    source.experiment_type, source.genetics_version, source.mutagen_type,
    source.wallet_cost, source.rating_effect, source.active_flag
);

declare
    v_count number;
begin
    select count(*)
      into v_count
      from creatures
     where species_type not between 1 and 7;

    if v_count <> 0 then
        raise_application_error(-20961, 'CREATURES contains species outside the supported 1..7 range.');
    end if;

    select count(*)
      into v_count
      from user_constraints
     where table_name = 'CREATURES'
       and constraint_name = 'CK_CREATURES_SPECIES_TYPE';

    if v_count > 0 then
        execute immediate 'alter table creatures drop constraint ck_creatures_species_type';
    end if;

    execute immediate q'[
        alter table creatures add constraint ck_creatures_species_type
        check (species_type between 1 and 7) enable validate
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
       and constraint_name = 'CK_EXPERIMENTS_CROSS_REQUIRES_PARENT2';

    if v_count > 0 then
        execute immediate 'alter table experiments drop constraint ck_experiments_cross_requires_parent2';
    end if;

    execute immediate q'[
        alter table experiments add constraint ck_experiments_cross_requires_parent2 check (
            (experiment_type in ('CROSS', 'CROSSBREED_MUTAGEN', 'HYBRIDIZATION') and parent2_id is not null)
            or (experiment_type in ('MUTATION', 'MUTAGEN') and parent2_id is null)
        ) enable validate
    ]';

    select count(*)
      into v_count
      from user_constraints
     where table_name = 'EXPERIMENTS'
       and constraint_name = 'CK_EXPERIMENTS_COMBINED_FIELDS';

    if v_count > 0 then
        execute immediate 'alter table experiments drop constraint ck_experiments_combined_fields';
    end if;

    execute immediate q'[
        alter table experiments add constraint ck_experiments_combined_fields check (
            (experiment_type = 'CROSSBREED_MUTAGEN' and mutagen_type is not null and mutation_id is null)
            or (experiment_type = 'HYBRIDIZATION' and mutagen_type = 'RADIATION' and mutation_id is null)
            or experiment_type not in ('CROSSBREED_MUTAGEN', 'HYBRIDIZATION')
        ) enable validate
    ]';
end;
/

comment on column creatures.species_type is
    'Persisted species type code from 1 to 7; type 7 is created only by controlled hybridization.';
comment on table experiments is
    'History of crossbreeding, mutation, mutagen, and controlled hybridization actions.';
comment on column experiments.experiment_type is
    'CROSS, MUTATION, MUTAGEN, CROSSBREED_MUTAGEN, or HYBRIDIZATION.';
comment on column experiments.mutagen_type is
    'Mutagen code for compound experiments; historical MUTAGEN rows may remain null.';

commit;

@@../packages/spec/pkg_genetics_game.pks
@@../packages/body/pkg_genetics_game.pkb

begin
    dbms_output.put_line('Controlled hybridization migration complete.');
end;
/

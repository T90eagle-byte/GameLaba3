-- ============================================================================
-- BioAssembly / Oracle DDL
-- File: 01_create_tables.sql
-- Purpose: create base schema objects for MVP (tables, constraints, sequences)
-- ============================================================================

-- ============================================================================
-- SECTION 1. SEQUENCES FOR PRIMARY KEYS
-- ============================================================================

create sequence users_seq start with 1 increment by 1 nocache nocycle;
create sequence sessions_seq start with 1 increment by 1 nocache nocycle;
create sequence labs_seq start with 1 increment by 1 nocache nocycle;
create sequence genes_seq start with 1 increment by 1 nocache nocycle;
create sequence alleles_seq start with 1 increment by 1 nocache nocycle;
create sequence mutations_seq start with 1 increment by 1 nocache nocycle;
create sequence mutation_rules_seq start with 1 increment by 1 nocache nocycle;
create sequence tasks_seq start with 1 increment by 1 nocache nocycle;
create sequence creatures_seq start with 1 increment by 1 nocache nocycle;
create sequence genotypes_seq start with 1 increment by 1 nocache nocycle;
create sequence experiments_seq start with 1 increment by 1 nocache nocycle;
create sequence lab_mutations_seq start with 1 increment by 1 nocache nocycle;
create sequence lab_tasks_seq start with 1 increment by 1 nocache nocycle;
create sequence task_markers_seq start with 1 increment by 1 nocache nocycle;
create sequence rating_events_seq start with 1 increment by 1 nocache nocycle;

-- ============================================================================
-- SECTION 2. AUTHORIZATION AND SESSION TABLES
-- ============================================================================

create table users (
    user_id          number not null,
    username         varchar2(255 char) not null,
    login            varchar2(20 char) not null,
    password_hash    varchar2(64 char) not null,
    created_at       timestamp default systimestamp not null,
    updated_at       timestamp default systimestamp not null,
    constraint pk_users primary key (user_id),
    constraint uq_users_login unique (login),
    constraint ck_users_login_format check (regexp_like(login, '^[a-z][a-z0-9_]{0,19}$')),
    constraint ck_users_password_hash check (regexp_like(password_hash, '^[A-Fa-f0-9]{64}$'))
);

comment on table users is 'Game users for MVP authentication.';
comment on column users.user_id is 'Primary key.';
comment on column users.login is 'Unique login, lowercase latin letters, digits, underscore; first symbol is a letter.';
comment on column users.password_hash is 'SHA-256 hash in hex string format.';

create table sessions (
    session_id       number not null,
    user_id          number not null,
    session_token    varchar2(128 char) not null,
    status           varchar2(10 char) not null,
    started_at       timestamp default systimestamp not null,
    ended_at         timestamp null,
    constraint pk_sessions primary key (session_id),
    constraint uq_sessions_token unique (session_token),
    constraint uq_sessions_session_user unique (session_id, user_id),
    constraint fk_sessions_user_id foreign key (user_id) references users (user_id),
    constraint ck_sessions_status check (status in ('ACTIVE', 'CLOSED')),
    constraint ck_sessions_ended_after_start check (ended_at is null or ended_at >= started_at),
    constraint ck_sessions_status_dates check (
        (status = 'ACTIVE' and ended_at is null) or
        (status = 'CLOSED' and ended_at is not null)
    )
);

comment on table sessions is 'User authentication sessions.';
comment on column sessions.session_id is 'Primary key.';
comment on column sessions.session_token is 'Opaque token used by client for session context.';
comment on column sessions.status is 'Session status: ACTIVE or CLOSED.';


-- ============================================================================
-- SECTION 3. DOMAIN REFERENCE TABLES
-- ============================================================================

create table ref_species_types (
    species_type       number not null,
    display_name       varchar2(100 char) not null,
    constraint pk_ref_species_types primary key (species_type)
);

create table ref_gene_types (
    gene_type          varchar2(30 char) not null,
    display_name       varchar2(100 char) not null,
    constraint pk_ref_gene_types primary key (gene_type)
);

create table ref_dominance_types (
    dominance_type     varchar2(30 char) not null,
    display_name       varchar2(100 char) not null,
    constraint pk_ref_dominance_types primary key (dominance_type)
);

create table ref_task_statuses (
    task_status        varchar2(30 char) not null,
    display_name       varchar2(100 char) not null,
    constraint pk_ref_task_statuses primary key (task_status)
);

create table ref_experiment_types (
    experiment_type    varchar2(30 char) not null,
    display_name       varchar2(100 char) not null,
    constraint pk_ref_experiment_types primary key (experiment_type)
);

create table ref_mutagen_types (
    mutagen_type       varchar2(30 char) not null,
    display_name       varchar2(100 char) not null,
    constraint pk_ref_mutagen_types primary key (mutagen_type)
);

create table ref_mutation_types (
    mutation_type      number not null,
    display_name       varchar2(100 char) not null,
    constraint pk_ref_mutation_types primary key (mutation_type)
);

create table ref_task_difficulties (
    difficulty_code    varchar2(30 char) not null,
    display_name       varchar2(100 char) not null,
    constraint pk_ref_task_difficulties primary key (difficulty_code)
);

create table ref_rating_event_types (
    event_type         varchar2(30 char) not null,
    display_name       varchar2(100 char) not null,
    constraint pk_ref_rating_event_types primary key (event_type)
);

comment on table ref_species_types is 'Species type domain reference.';
comment on table ref_gene_types is 'Gene type domain reference.';
comment on table ref_dominance_types is 'Dominance type domain reference.';
comment on table ref_task_statuses is 'Task status domain reference.';
comment on table ref_experiment_types is 'Experiment type domain reference.';
comment on table ref_mutagen_types is 'Mutagen type domain reference.';
comment on table ref_mutation_types is 'Mutation type domain reference.';
comment on table ref_task_difficulties is 'Task difficulty domain reference.';
comment on table ref_rating_event_types is 'Rating/economy event type domain reference.';

-- ============================================================================
-- SECTION 4. CORE GAME STATE TABLES
-- ============================================================================

create table labs (
    lab_id                number not null,
    user_id               number not null,
    session_id            number null,
    wallet                number(12, 2) default 1000 not null,
    rating                number(12, 2) default 0 not null,
    creature_count        number default 0 not null,
    active_task_count     number default 0 not null,
    completed_task_count  number default 0 not null,
    experiment_count      number default 0 not null,
    created_at            timestamp default systimestamp not null,
    updated_at            timestamp default systimestamp not null,
    constraint pk_labs primary key (lab_id),
    constraint fk_labs_user_id foreign key (user_id) references users (user_id),
    constraint fk_labs_session_id foreign key (session_id) references sessions (session_id),
    constraint fk_labs_session_user foreign key (session_id, user_id) references sessions (session_id, user_id),
    constraint ck_labs_wallet_nonnegative check (wallet >= 0),
    constraint ck_labs_creature_count check (creature_count >= 0),
    constraint ck_labs_active_task_count check (active_task_count >= 0),
    constraint ck_labs_completed_task_count check (completed_task_count >= 0),
    constraint ck_labs_experiment_count check (experiment_count >= 0)
);

comment on table labs is 'Player laboratory state and aggregated counters.';
comment on column labs.lab_id is 'Primary key.';
comment on column labs.session_id is 'Current active session holding the lab; NULL when the lab is released.';

create table genes (
    gene_id            number not null,
    gene_type          varchar2(50 char) not null,
    species_type       number(1) default 0 not null,
    dominance_type     varchar2(20 char) default 'FULL' not null,
    linkage_group      number null,
    gene_name          varchar2(50 char) not null,
    description        varchar2(255 char) null,
    created_at         timestamp default systimestamp not null,
    constraint pk_genes primary key (gene_id),
    constraint fk_genes_gene_type foreign key (gene_type) references ref_gene_types (gene_type),
    constraint fk_genes_species_type foreign key (species_type) references ref_species_types (species_type),
    constraint fk_genes_dominance_type foreign key (dominance_type) references ref_dominance_types (dominance_type),
    constraint ck_genes_species_type check (species_type between 0 and 6),
    constraint ck_genes_linkage_group check (linkage_group is null or linkage_group > 0)
);

comment on table genes is 'Genes with species scope, dominance type, and linkage group.';
comment on column genes.gene_id is 'Primary key.';
comment on column genes.species_type is '0 for universal genes; 1..6 for specific species types.';
comment on column genes.dominance_type is 'Dominance model: FULL, INCOMPLETE, CODOMINANT.';
comment on column genes.linkage_group is 'Linked inheritance group identifier; NULL for independent genes.';

create table alleles (
    allele_id           number not null,
    gene_id             number not null,
    dominance           number(5, 2) default 0 not null,
    description         varchar2(255 char) not null,
    trait_value         number(10, 2) not null,
    created_at          timestamp default systimestamp not null,
    constraint pk_alleles primary key (allele_id),
    constraint uq_alleles_allele_gene unique (allele_id, gene_id),
    constraint fk_alleles_gene_id foreign key (gene_id) references genes (gene_id),
    constraint ck_alleles_dominance_nonnegative check (dominance >= 0)
);

comment on table alleles is 'Alleles for each gene.';
comment on column alleles.allele_id is 'Primary key.';
comment on column alleles.gene_id is 'References the gene this allele belongs to.';

create table mutations (
    mutation_id         number not null,
    mutation_name       varchar2(50 char) not null,
    mutation_type       number null,
    description         varchar2(255 char) null,
    cost                number(12, 2) default 0 not null,
    rating_effect       number(12, 2) default 0 not null,
    created_at          timestamp default systimestamp not null,
    constraint pk_mutations primary key (mutation_id),
    constraint uq_mutations_name unique (mutation_name),
    constraint fk_mutations_mutation_type foreign key (mutation_type) references ref_mutation_types (mutation_type),
    constraint ck_mutations_cost_nonnegative check (cost >= 0)
);

comment on table mutations is 'Mutation catalog for lab shop and experiments.';
comment on column mutations.mutation_id is 'Primary key.';

create table mutation_rules (
    mutation_rule_id    number not null,
    mutation_id         number not null,
    gene_id             number not null,
    target_allele_id    number not null,
    target_slot         varchar2(3 char) not null,
    created_at          timestamp default systimestamp not null,
    constraint pk_mutation_rules primary key (mutation_rule_id),
    constraint fk_mutation_rules_mutation_id foreign key (mutation_id) references mutations (mutation_id),
    constraint fk_mutation_rules_gene_id foreign key (gene_id) references genes (gene_id),
    constraint fk_mutation_rules_target_allele foreign key (target_allele_id, gene_id) references alleles (allele_id, gene_id),
    constraint ck_mutation_rules_target_slot check (target_slot in ('1', '2', 'ANY'))
);

comment on table mutation_rules is 'Rules describing how mutations affect genotype alleles.';
comment on column mutation_rules.mutation_rule_id is 'Primary key.';
comment on column mutation_rules.target_allele_id is 'Target allele that should be applied for the gene.';
comment on column mutation_rules.target_slot is 'Genotype slot: 1, 2, or ANY.';

create table tasks (
    task_id             number not null,
    task_name           varchar2(100 char) not null,
    description         varchar2(255 char) null,
    rating_reward       number(12, 2) default 0 not null,
    money_reward        number(12, 2) default 0 not null,
    difficulty_code     varchar2(30 char) default 'MEDIUM' not null,
    created_at          timestamp default systimestamp not null,
    constraint pk_tasks primary key (task_id),
    constraint uq_tasks_name unique (task_name),
    constraint fk_tasks_difficulty_code foreign key (difficulty_code) references ref_task_difficulties (difficulty_code),
    constraint ck_tasks_money_reward_nonnegative check (money_reward >= 0)
);

comment on table tasks is 'Client orders with rewards.';
comment on column tasks.task_id is 'Primary key.';
comment on column tasks.difficulty_code is 'Task difficulty code from ref_task_difficulties.';

create table creatures (
    creature_id                  number not null,
    lab_id                       number not null,
    species_type                 number(1) not null,
    creature_name                varchar2(255 char) not null,
    phenotype_color              varchar2(100 char) null,
    phenotype_size               varchar2(100 char) null,
    phenotype_has_wings          char(1 char) null,
    phenotype_nutrition_type     varchar2(100 char) null,
    phenotype_summary            varchar2(1000 char) null,
    created_at                   timestamp default systimestamp not null,
    updated_at                   timestamp default systimestamp not null,
    constraint pk_creatures primary key (creature_id),
    constraint fk_creatures_lab_id foreign key (lab_id) references labs (lab_id),
    constraint fk_creatures_species_type foreign key (species_type) references ref_species_types (species_type),
    constraint ck_creatures_species_type check (species_type between 1 and 6),
    constraint ck_creatures_has_wings check (phenotype_has_wings in ('Y', 'N') or phenotype_has_wings is null)
);

comment on table creatures is 'Creatures owned by a lab, with cached phenotype fields for UI.';
comment on column creatures.creature_id is 'Primary key.';
comment on column creatures.species_type is 'Species type code from 1 to 6.';
comment on column creatures.phenotype_summary is 'Compact phenotype text for collection screens.';

-- ============================================================================
-- SECTION 5. RELATIONAL GAMEPLAY TABLES
-- ============================================================================

create table genotypes (
    genotype_id         number not null,
    creature_id         number not null,
    gene_id             number not null,
    allele1_id          number not null,
    allele2_id          number not null,
    created_at          timestamp default systimestamp not null,
    constraint pk_genotypes primary key (genotype_id),
    constraint fk_genotypes_creature_id foreign key (creature_id) references creatures (creature_id),
    constraint fk_genotypes_gene_id foreign key (gene_id) references genes (gene_id),
    constraint fk_genotypes_allele1_gene foreign key (allele1_id, gene_id) references alleles (allele_id, gene_id),
    constraint fk_genotypes_allele2_gene foreign key (allele2_id, gene_id) references alleles (allele_id, gene_id),
    constraint uq_genotypes_creature_gene unique (creature_id, gene_id)
);

comment on table genotypes is 'Creature genotype rows: one row per creature and gene.';
comment on column genotypes.genotype_id is 'Primary key.';
comment on column genotypes.allele1_id is 'First inherited allele.';
comment on column genotypes.allele2_id is 'Second inherited allele.';

create table experiments (
    experiment_id       number not null,
    lab_id              number not null,
    parent1_id          number not null,
    parent2_id          number null,
    mutation_id         number null,
    offspring_id        number not null,
    experiment_type     varchar2(20 char) not null,
    created_at          timestamp default systimestamp not null,
    constraint pk_experiments primary key (experiment_id),
    constraint fk_experiments_lab_id foreign key (lab_id) references labs (lab_id),
    constraint fk_experiments_parent1_id foreign key (parent1_id) references creatures (creature_id),
    constraint fk_experiments_parent2_id foreign key (parent2_id) references creatures (creature_id),
    constraint fk_experiments_mutation_id foreign key (mutation_id) references mutations (mutation_id),
    constraint fk_experiments_offspring_id foreign key (offspring_id) references creatures (creature_id),
    constraint fk_experiments_type foreign key (experiment_type) references ref_experiment_types (experiment_type),
    constraint ck_experiments_parents_different check (parent2_id is null or parent1_id <> parent2_id),
    constraint ck_experiments_cross_requires_parent2 check (
        (experiment_type = 'CROSS' and parent2_id is not null) or
        (experiment_type in ('MUTATION', 'MUTAGEN') and parent2_id is null)
    )
);

comment on table experiments is 'History of crossbreeding, mutation, and mutagen actions.';
comment on column experiments.experiment_id is 'Primary key.';
comment on column experiments.experiment_type is 'CROSS, MUTATION, or MUTAGEN.';

create table lab_mutations (
    lab_mutation_id     number not null,
    lab_id              number not null,
    mutation_id         number not null,
    quantity            number default 0 not null,
    created_at          timestamp default systimestamp not null,
    updated_at          timestamp default systimestamp not null,
    constraint pk_lab_mutations primary key (lab_mutation_id),
    constraint fk_lab_mutations_lab_id foreign key (lab_id) references labs (lab_id),
    constraint fk_lab_mutations_mutation_id foreign key (mutation_id) references mutations (mutation_id),
    constraint uq_lab_mutations_lab_mutation unique (lab_id, mutation_id),
    constraint ck_lab_mutations_quantity_nonnegative check (quantity >= 0)
);

comment on table lab_mutations is 'Purchased mutation stock per lab.';
comment on column lab_mutations.lab_mutation_id is 'Primary key.';

create table lab_tasks (
    lab_task_id         number not null,
    lab_id              number not null,
    task_id             number not null,
    task_status         varchar2(20 char) default 'ACTIVE' not null,
    assigned_at         timestamp default systimestamp not null,
    completed_at        timestamp null,
    constraint pk_lab_tasks primary key (lab_task_id),
    constraint fk_lab_tasks_lab_id foreign key (lab_id) references labs (lab_id),
    constraint fk_lab_tasks_task_id foreign key (task_id) references tasks (task_id),
    constraint fk_lab_tasks_status foreign key (task_status) references ref_task_statuses (task_status),
    constraint uq_lab_tasks_lab_task unique (lab_id, task_id),
    constraint ck_lab_tasks_dates check (
        (task_status = 'ACTIVE' and completed_at is null) or
        (task_status = 'COMPLETED' and completed_at is not null)
    )
);

comment on table lab_tasks is 'Task status for each lab.';
comment on column lab_tasks.lab_task_id is 'Primary key.';
comment on column lab_tasks.task_status is 'ACTIVE or COMPLETED.';

create table task_markers (
    task_marker_id      number not null,
    task_id             number not null,
    allele_id           number not null,
    constraint pk_task_markers primary key (task_marker_id),
    constraint fk_task_markers_task_id foreign key (task_id) references tasks (task_id),
    constraint fk_task_markers_allele_id foreign key (allele_id) references alleles (allele_id),
    constraint uq_task_markers_task_allele unique (task_id, allele_id)
);

comment on table task_markers is 'Required alleles for task completion checks.';
comment on column task_markers.task_marker_id is 'Primary key.';

create table rating_events (
    rating_event_id    number not null,
    lab_id             number not null,
    creature_id        number null,
    task_id            number null,
    experiment_id      number null,
    event_type         varchar2(30 char) not null,
    rating_delta       number(12, 2) default 0 not null,
    wallet_delta       number(12, 2) default 0 not null,
    description        varchar2(1000 char) null,
    created_at         timestamp default systimestamp not null,
    constraint pk_rating_events primary key (rating_event_id),
    constraint fk_rating_events_lab_id foreign key (lab_id) references labs (lab_id),
    constraint fk_rating_events_creature_id foreign key (creature_id) references creatures (creature_id),
    constraint fk_rating_events_task_id foreign key (task_id) references tasks (task_id),
    constraint fk_rating_events_experiment_id foreign key (experiment_id) references experiments (experiment_id),
    constraint fk_rating_events_type foreign key (event_type) references ref_rating_event_types (event_type)
);

comment on table rating_events is 'Append-only explanation log for lab wallet and rating changes.';
comment on column rating_events.rating_event_id is 'Primary key.';
comment on column rating_events.event_type is 'Domain event type from ref_rating_event_types.';
comment on column rating_events.rating_delta is 'Actual rating delta recorded after aggregate update, including zero when clipping applies.';
comment on column rating_events.wallet_delta is 'Actual wallet delta recorded after aggregate update.';

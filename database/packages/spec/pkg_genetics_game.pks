create or replace package pkg_genetics_game as
    ----------------------------------------------------------------------------
    -- A. Auth/session
    ----------------------------------------------------------------------------
    procedure register_user(
        p_username      in varchar2,
        p_login         in varchar2,
        p_password      in varchar2,
        p_user_id       out number
    );

    function login_user(
        p_login         in varchar2,
        p_password      in varchar2
    ) return varchar2;

    procedure logout_user(
        p_session_token in varchar2
    );

    function resolve_user_id_by_token(
        p_session_token in varchar2
    ) return number;

    procedure update_user_profile(
        p_user_id       in number,
        p_username      in varchar2 default null,
        p_password      in varchar2 default null
    );

    function hash_password(
        p_password      in varchar2
    ) return varchar2;

    ----------------------------------------------------------------------------
    -- B. Labs
    ----------------------------------------------------------------------------
    procedure start_new_lab(
        p_session_token in varchar2,
        p_lab_id        out number
    );

    procedure load_lab(
        p_session_token in varchar2,
        p_lab_id        in number
    );

    procedure switch_lab(
        p_session_token in varchar2,
        p_new_lab_id    in number
    );

    function list_user_labs(
        p_user_id       in number
    ) return sys_refcursor;

    procedure get_lab_stats(
        p_lab_id                in number,
        p_wallet                out number,
        p_rating                out number,
        p_creature_count        out number,
        p_active_task_count     out number,
        p_completed_task_count  out number,
        p_experiment_count      out number
    );

    procedure delete_lab(
        p_session_token in varchar2,
        p_lab_id        in number
    );

    procedure exit_lab(
        p_lab_id        in number
    );

    procedure show_lab_stats(
        p_lab_id        in number
    );

    function get_rating_events_cursor(
        p_session_token in varchar2,
        p_lab_id        in number
    ) return sys_refcursor;

    procedure show_rating_history(
        p_lab_id        in number
    );

    function get_reference_cursor(
        p_ref_name      in varchar2
    ) return sys_refcursor;

    ----------------------------------------------------------------------------
    -- C. Creatures/genetics
    ----------------------------------------------------------------------------
    function get_creatures_cursor(
        p_lab_id         in number
    ) return sys_refcursor;

    function get_genotype_cursor(
        p_creature_id    in number
    ) return sys_refcursor;

    function get_phenotype(
        p_creature_id    in number
    ) return varchar2;

    procedure show_creatures(
        p_lab_id         in number
    );

    function get_dominant_allele(
        p_creature_id    in number,
        p_gene_id        in number
    ) return varchar2;

    function get_inherited_allele(
        p_parent_id      in number,
        p_gene_id        in number
    ) return number;

    function get_linked_allele_set(
        p_creature_id    in number,
        p_linkage_group  in number
    ) return varchar2;

    function calculate_punnett_probabilities(
        p_parent1_id     in number,
        p_parent2_id     in number,
        p_gene_id        in number
    ) return sys_refcursor;

    function preview_offspring_options(
        p_session_token  in varchar2,
        p_lab_id         in number,
        p_parent1_id     in number,
        p_parent2_id     in number,
        p_options_count  in number default 3
    ) return sys_refcursor;

    procedure crossbreed(
        p_lab_id          in number,
        p_parent1_id      in number,
        p_parent2_id      in number,
        p_offspring_name  in varchar2,
        p_offspring_id    out number
    );

    procedure rename_creature(
        p_creature_id     in number,
        p_new_name        in varchar2
    );

    ----------------------------------------------------------------------------
    -- D. Mutations/experiments
    ----------------------------------------------------------------------------
    function show_mutation_shop
    return sys_refcursor;

    function get_mutation_target_genes_cursor(
        p_mutation_id     in number
    ) return sys_refcursor;

    function get_compatible_creatures_for_mutation_cursor(
        p_lab_id          in number,
        p_mutation_id     in number
    ) return sys_refcursor;

    function get_lab_mutation_quantity(
        p_lab_id          in number,
        p_mutation_id     in number
    ) return number;

    function buy_mutation(
        p_lab_id          in number,
        p_mutation_id     in number
    ) return number;

    procedure apply_mutation(
        p_creature_id     in number,
        p_mutation_id     in number
    );

    procedure apply_mutagen(
        p_creature_id      in number,
        p_mutagen_type     in varchar2,
        p_new_creature_id  out number
    );

    procedure make_experiment(
        p_lab_id          in number,
        p_parent1_id      in number,
        p_parent2_id      in number,
        p_mutation_id     in number default null,
        p_offspring_name  in varchar2,
        p_offspring_id    out number
    );

    function get_experiment_history(
        p_lab_id           in number,
        p_experiment_type  in varchar2 default null
    ) return sys_refcursor;

    ----------------------------------------------------------------------------
    -- E. Tasks
    ----------------------------------------------------------------------------
    function get_tasks_cursor(
        p_lab_id          in number
    ) return sys_refcursor;

    procedure show_tasks(
        p_lab_id          in number
    );

    function check_task(
        p_lab_id          in number,
        p_task_id         in number,
        p_creature_id     in number
    ) return number;

    procedure complete_task(
        p_lab_id          in number,
        p_task_id         in number,
        p_creature_id     in number,
        p_is_completed    out number,
        p_wallet_after    out number,
        p_rating_after    out number
    );

    ----------------------------------------------------------------------------
    -- F. Seed/bootstrap helpers
    ----------------------------------------------------------------------------
    procedure generate_starting_creatures(
        p_lab_id          in number
    );

    procedure create_creature_of_type(
        p_lab_id          in number,
        p_species_type    in number,
        p_variant         in number,
        p_creature_id     out number
    );

    procedure show_mutation_history(
        p_lab_id          in number
    );
end pkg_genetics_game;
/

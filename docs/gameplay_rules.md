# Gameplay Rules

## 1) Core model

The player operates a lab, creates/modifies creatures, runs experiments, and completes tasks.

Critical architecture rules:
- backend logic is Oracle PL/SQL only;
- Python is GUI client only;
- central backend API is `pkg_genetics_game`.

## 2) Species model

The game uses 6 species types (`species_type`):
1. cartilaginous fish
2. bony fish
3. crustaceans
4. mollusks
5. turtles
6. mammals

## 3) Lab startup

`start_new_lab` must immediately prepare a playable lab:
- create lab record;
- assign 3 starter `ACTIVE` tasks;
- generate 30 starter creatures (`6 x 5`).

Expected right after `start_new_lab`:
- `creature_count = 30`;
- `active_task_count = 3`.

## 4) Genetics and phenotype

- Genotype is stored in `genotypes` (two alleles per gene).
- Full phenotype is computed in `get_phenotype`.
- Cached phenotype fields and `phenotype_summary` are stored in `creatures`.

`dominance_type` semantics:
- `FULL`: dominance by numeric `dominance` value.
- `INCOMPLETE`: for different alleles, return intermediate phenotype.
- `CODOMINANT`: for different alleles, return both traits as `trait1/trait2`.
- Same-allele pairs always return the regular allele description.

## 5) Access control

Gameplay API is session-aware:
- active session context is stored after `login_user`;
- operations by `lab_id`/`creature_id` verify ownership by current user;
- foreign lab/creature access is denied.

## 6) Mutations and mutagens

- `show_mutation_shop` provides available mutations.
- `buy_mutation` spends wallet and increases `lab_mutations` stock.
- `apply_mutation` applies `mutation_rules` to creature genotype.
- `apply_mutagen` creates a new mutated creature.

Mutagen modes:
- `CHEMICAL`: more controlled mutation path.
- `RADIATION`: more random mutation path, with extra-risk behavior.

## 7) Tasks

- Tasks are assigned per lab in `lab_tasks`.
- Marker check is done by `check_task` against `task_markers`.
- `complete_task`:
  - sets `task_status = COMPLETED`;
  - applies money/rating rewards;
  - blocks duplicate reward payout.

Automatic task checks run after experiment flow:
- `crossbreed`;
- `apply_mutation`;
- `apply_mutagen`.

Startup flow (`start_new_lab` and initial generation) does not auto-complete tasks.

## 8) GUI contract

GUI must consume data only through:
- `SYS_REFCURSOR`;
- OUT parameters;
- simple return types.

`dbms_output` is not a runtime data channel for GUI.
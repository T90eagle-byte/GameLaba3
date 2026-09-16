-- Version-aware terminology update for existing v13 schemas.
-- Only reference display names change; species IDs and gameplay rows remain intact.
set define off;
set serveroutput on size unlimited;
set verify off;

merge into ref_species_types target
using (select 5 as species_type, 'Морские рептилии' as display_name from dual) source
on (target.species_type = source.species_type)
when matched then update set target.display_name = source.display_name
when not matched then insert (species_type, display_name)
values (source.species_type, source.display_name);

merge into ref_species_types target
using (select 6 as species_type, 'Морские млекопитающие' as display_name from dual) source
on (target.species_type = source.species_type)
when matched then update set target.display_name = source.display_name
when not matched then insert (species_type, display_name)
values (source.species_type, source.display_name);

commit;

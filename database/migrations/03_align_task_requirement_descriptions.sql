-- Run on an existing schema after stopping the application.
-- This data migration is idempotent and keeps task markers unchanged.
set define off;

update tasks
   set description = case task_name
       when 'task_green_specimen' then 'Требуется носительство генетического варианта «зелёный окрас».'
       when 'task_winged_specimen' then 'Требуется носительство генетического варианта «крылья». Внешние крылья могут не проявиться.'
       when 'task_fast_turtle' then 'Требуется носительство обоих генетических вариантов: «быстрая скорость» и «гладкий панцирь».'
       when 'task_predator_fish_line' then 'Требуется носительство обоих генетических вариантов: «хищное питание» и «раздвоенный плавник».'
       when 'task_armored_crustacean' then 'Требуется носительство генетических вариантов: «толстый панцирь», «длинные клешни» и «крупный размер».'
       when 'task_dense_fur_mammal' then 'Требуется носительство генетических вариантов: «густая шерсть» и «зелёный окрас».'
       when 'task_cartilaginous_fin_line' then 'Требуется носительство генетических вариантов: «широкий плавник» и «хищное питание».'
       when 'task_mollusk_sharp_profile' then 'Требуется носительство генетических вариантов: «острый клюв» и «зелёный окрас».'
       when 'task_large_specimen' then 'Требуется носительство генетического варианта «крупный размер».'
       when 'task_herbivore_line' then 'Требуется носительство генетического варианта «травоядное питание».'
       when 'task_spiked_turtle' then 'Требуется носительство генетических вариантов: «шипастый панцирь» и «быстрая скорость».'
       when 'task_mammal_short_fur' then 'Требуется носительство генетических вариантов: «короткая шерсть» и «компактный размер».'
       when 'task_red_specimen' then 'Требуется носительство генетического варианта «красный окрас».'
       when 'task_medium_specimen' then 'Требуется носительство генетического варианта «средний размер».'
       when 'task_winged_red_specimen' then 'Требуется носительство обоих генетических вариантов: «крылья» и «красный окрас». Внешние крылья могут не проявиться.'
       when 'task_crescent_fin_cartilaginous' then 'Требуется носительство генетических вариантов: «серповидный плавник» и «хищное питание».'
       when 'task_ribbon_fin_bony' then 'Требуется носительство генетических вариантов: «ленточный плавник» и «крупный размер».'
       when 'task_hooked_crustacean' then 'Требуется носительство генетических вариантов: «крючковатые клешни» и «ребристый панцирь».'
       when 'task_spiral_mollusk' then 'Требуется носительство генетических вариантов: «спиральный профиль» и «фиолетовый окрас».'
       when 'task_plated_turtle' then 'Требуется носительство генетических вариантов: «пластинчатый панцирь» и «быстрая скорость».'
       when 'task_soft_fur_mammal' then 'Требуется носительство генетических вариантов: «мягкая шерсть» и «белый окрас».'
   end
 where task_name in (
    'task_green_specimen', 'task_winged_specimen', 'task_fast_turtle',
    'task_predator_fish_line', 'task_armored_crustacean', 'task_dense_fur_mammal',
    'task_cartilaginous_fin_line', 'task_mollusk_sharp_profile', 'task_large_specimen',
    'task_herbivore_line', 'task_spiked_turtle', 'task_mammal_short_fur',
    'task_red_specimen', 'task_medium_specimen', 'task_winged_red_specimen',
    'task_crescent_fin_cartilaginous', 'task_ribbon_fin_bony', 'task_hooked_crustacean',
    'task_spiral_mollusk', 'task_plated_turtle', 'task_soft_fur_mammal'
 );

commit;

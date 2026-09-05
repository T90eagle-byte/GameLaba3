# Аудит генетических условий заказов

## Правило ЛР2

`pkg_genetics_game.check_task` проверяет каждый marker задания по
генотипу существа. Требуемый аллель должен находиться хотя бы в одном из
двух слотов соответствующего гена. Для задания с несколькими markers должны
совпасть все условия. Внешний фенотип не является заменой этой проверки.

Поэтому тексты заказов говорят о носительстве генетических вариантов, а не
гарантируют проявившийся признак. Например, `wings` рецессивен относительно
`no_wings`: существо с генотипом `wings/no_wings` выполняет заказ на этот
аллель, хотя его фенотип остаётся `no_wings`.

## Seed-заказы

| Заказ | Marker alleles | Генотипическое условие | Пользовательская формулировка |
|---|---|---|---|
| `task_green_specimen` | `color: green_color` | В одном или обоих слотах `color` есть `green_color` | Носительство варианта «зелёный окрас» |
| `task_winged_specimen` | `has_wings: wings` | В одном или обоих слотах `has_wings` есть `wings` | Носительство варианта «крылья»; внешние крылья могут не проявиться |
| `task_fast_turtle` | `speed_level: fast_speed`; `shell_armor: smooth_shell` | Оба marker должны быть в соответствующих генах | Носительство вариантов «быстрая скорость» и «гладкий панцирь» |
| `task_predator_fish_line` | `nutrition_type: carnivore`; `fin_shape: forked_fin` | Оба marker должны быть в соответствующих генах | Носительство вариантов «хищное питание» и «раздвоенный плавник» |
| `task_armored_crustacean` | `shell_armor: thick_armor`; `claw_form: long_claws`; `size: large_size` | Все три marker должны совпасть | Носительство вариантов толстого панциря, длинных клешней и крупного размера |
| `task_dense_fur_mammal` | `fur_density: dense_fur`; `color: green_color` | Оба marker должны совпасть | Носительство густой шерсти и зелёного окраса |
| `task_cartilaginous_fin_line` | `fin_shape: broad_fin`; `nutrition_type: carnivore` | Оба marker должны совпасть | Носительство широкого плавника и хищного питания |
| `task_mollusk_sharp_profile` | `beak_nose_shape: sharp_beak`; `color: green_color` | Оба marker должны совпасть | Носительство острого клюва и зелёного окраса |
| `task_large_specimen` | `size: large_size` | В одном или обоих слотах `size` есть `large_size` | Носительство варианта «крупный размер» |
| `task_herbivore_line` | `nutrition_type: herbivore` | В одном или обоих слотах `nutrition_type` есть `herbivore` | Носительство варианта «травоядное питание» |
| `task_spiked_turtle` | `shell_armor: spiked_shell`; `speed_level: fast_speed` | Оба marker должны совпасть | Носительство шипастого панциря и быстрой скорости |
| `task_mammal_short_fur` | `fur_density: short_fur`; `size: compact_size` | Оба marker должны совпасть | Носительство короткой шерсти и компактного размера |
| `task_red_specimen` | `color: red_color` | В одном или обоих слотах `color` есть `red_color` | Носительство варианта «красный окрас» |
| `task_medium_specimen` | `size: medium_size` | В одном или обоих слотах `size` есть `medium_size` | Носительство варианта «средний размер» |
| `task_winged_red_specimen` | `has_wings: wings`; `color: red_color` | Оба marker должны совпасть | Носительство вариантов «крылья» и «красный окрас»; крылья могут не проявиться |
| `task_crescent_fin_cartilaginous` | `fin_shape: crescent_fin`; `nutrition_type: carnivore` | Оба marker должны совпасть | Носительство серповидного плавника и хищного питания |
| `task_ribbon_fin_bony` | `fin_shape: ribbon_fin`; `size: large_size` | Оба marker должны совпасть | Носительство ленточного плавника и крупного размера |
| `task_hooked_crustacean` | `claw_form: hooked_claws`; `shell_armor: ridged_armor` | Оба marker должны совпасть | Носительство крючковатых клешней и ребристого панциря |
| `task_spiral_mollusk` | `beak_nose_shape: spiral_profile`; `color: purple_color` | Оба marker должны совпасть | Носительство спирального профиля и фиолетового окраса |
| `task_plated_turtle` | `shell_armor: plated_shell`; `speed_level: fast_speed` | Оба marker должны совпасть | Носительство пластинчатого панциря и быстрой скорости |
| `task_soft_fur_mammal` | `fur_density: soft_fur`; `color: white_color` | Оба marker должны совпасть | Носительство мягкой шерсти и белого окраса |

## Границы изменения

Изменение касается seed-описаний и display-layer. `check_task`,
`complete_task`, автоматическое закрытие заказов и генетические правила не
переписываются: они уже реализуют принятое правило ЛР2.

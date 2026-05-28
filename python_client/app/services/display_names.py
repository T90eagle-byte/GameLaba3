from __future__ import annotations

import re
from typing import Any

SPECIES_LABELS = {
    0: "Универсальный признак",
    1: "Хрящевые рыбы",
    2: "Костные рыбы",
    3: "Ракообразные",
    4: "Моллюски",
    5: "Черепахи",
    6: "Млекопитающие",
}

GENE_LABELS = {
    "color": "Цвет",
    "size": "Размер",
    "nutrition_type": "Тип питания",
    "has_wings": "Крылья",
    "fin_shape": "Форма плавника",
    "shell_armor": "Панцирь",
    "claw_form": "Клешни",
    "beak_nose_shape": "Форма клюва/носа",
    "speed_level": "Скорость",
    "fur_density": "Шерсть",
}

GENE_TYPE_LABELS = {
    "trait": "Базовый признак",
    "morphology": "Морфология",
    "performance": "Производительность",
    "physiology": "Физиология",
}

TRAIT_LABELS = {
    "green_color": "зелёная окраска",
    "blue_color": "синяя окраска",
    "compact_size": "компактный размер",
    "large_size": "крупный размер",
    "herbivore": "травоядный тип питания",
    "carnivore": "хищный тип питания",
    "no_wings": "без крыльев",
    "wings": "есть крылья",
    "pointed_fin": "заострённый плавник",
    "broad_fin": "широкий плавник",
    "rounded_fin": "округлый плавник",
    "forked_fin": "раздвоенный плавник",
    "thick_armor": "прочный панцирь",
    "light_armor": "лёгкий панцирь",
    "short_claws": "короткие клешни",
    "long_claws": "длинные клешни",
    "rounded_nose": "округлая форма",
    "sharp_beak": "острый клюв",
    "smooth_shell": "гладкий панцирь",
    "spiked_shell": "шипастый панцирь",
    "slow_speed": "низкая скорость",
    "fast_speed": "высокая скорость",
    "short_fur": "короткая шерсть",
    "dense_fur": "густая шерсть",
}

DOMINANCE_LABELS = {
    "FULL": "Полное доминирование",
    "INCOMPLETE": "Неполное доминирование",
    "CODOMINANT": "Кодоминирование",
}

TASK_STATUS_LABELS = {
    "ACTIVE": "Активно",
    "COMPLETED": "Выполнено",
}

EXPERIMENT_TYPE_LABELS = {
    "CROSS": "Генетический эксперимент",
    "MUTATION": "Мутация",
    "MUTAGEN": "Мутаген",
}

MUTAGEN_TYPE_LABELS = {
    "RADIATION": "Радиационный",
    "CHEMICAL": "Химический",
}

MUTATION_NAME_LABELS = {
    "radiation_mutation": "Радиационная мутация",
    "chemical_mutation": "Химическая мутация",
    "enhanced_color_mutation": "Усиленная мутация окраски",
    "size_shift_mutation": "Мутация размера",
    "nutrition_shift_mutation": "Мутация типа питания",
    "wing_activation_mutation": "Мутация активации крыльев",
    "aquatic_form_mutation": "Мутация формы плавника (хрящевые рыбы)",
    "aquatic_form_bony_mutation": "Мутация формы плавника (костные рыбы)",
    "aquatic_form_turtle_shell_mutation": "Мутация панциря (черепахи)",
    "morphology_refine_mutation": "Мутация клешней (ракообразные)",
    "morphology_refine_mollusk_mutation": "Мутация профиля (моллюски)",
    "morphology_refine_mammal_mutation": "Мутация шерсти (млекопитающие)",
}

TASK_NAME_LABELS = {
    "task_green_specimen": "Зелёный образец",
    "task_winged_specimen": "Крылатый образец",
    "task_fast_turtle": "Быстрая черепаха",
    "task_predator_fish_line": "Хищная рыбная линия",
    "task_armored_crustacean": "Панцирное ракообразное",
    "task_dense_fur_mammal": "Млекопитающее с густой шерстью",
    "task_cartilaginous_fin_line": "Линия хрящевых рыб с развитым плавником",
    "task_mollusk_sharp_profile": "Моллюск с острым профилем",
    "task_large_specimen": "Крупный образец",
    "task_herbivore_line": "Травоядная линия",
    "task_spiked_turtle": "Шипастая черепаха",
    "task_mammal_short_fur": "Млекопитающее с короткой шерстью",
}

TASK_DIFFICULTY_LABELS = {
    "task_green_specimen": "Лёгкое",
    "task_winged_specimen": "Лёгкое",
    "task_large_specimen": "Лёгкое",
    "task_herbivore_line": "Лёгкое",
    "task_fast_turtle": "Среднее",
    "task_predator_fish_line": "Среднее",
    "task_cartilaginous_fin_line": "Среднее",
    "task_mollusk_sharp_profile": "Среднее",
    "task_mammal_short_fur": "Среднее",
    "task_spiked_turtle": "Среднее",
    "task_armored_crustacean": "Сложное",
    "task_dense_fur_mammal": "Сложное",
}


CREATURE_PREFIX_LABELS = {
    "cartilaginous_fish": "Хрящевая рыба",
    "bony_fish": "Костная рыба",
    "crustacean": "Ракообразное",
    "mollusk": "Моллюск",
    "turtle": "Черепаха",
    "mammal": "Млекопитающее",
}

MUTATION_TYPE_LABELS = {
    1: "Радиационная",
    2: "Химическая",
    3: "Окраска",
    4: "Размер",
    5: "Питание",
    6: "Крылья",
    7: "Водная морфология",
    8: "Морфология",
}


def display_value(value: Any, *, empty_label: str = "Не указано") -> str:
    if value is None:
        return empty_label
    text = str(value).strip()
    return text if text else empty_label


def species_label(value: Any) -> str:
    try:
        species_id = int(value)
    except (TypeError, ValueError):
        return "Не указано"
    return SPECIES_LABELS.get(species_id, f"Тип {species_id}")


def gene_label(value: Any, *, with_code: bool = False) -> str:
    code = display_value(value)
    label = GENE_LABELS.get(code.lower(), code.replace("_", " "))
    return f"{label} ({code})" if with_code and code != "Не указано" else label


def gene_type_label(value: Any, *, with_code: bool = False) -> str:
    code = display_value(value)
    label = GENE_TYPE_LABELS.get(code.lower(), code)
    return f"{label} ({code})" if with_code and code != "Не указано" else label


def trait_label(value: Any, *, with_code: bool = False) -> str:
    code = display_value(value)
    label = TRAIT_LABELS.get(code.lower(), code)
    return f"{label} ({code})" if with_code and code != "Не указано" else label


def display_trait_value(value: Any) -> str:
    return _trait_expression_label(display_value(value))


def display_gene_name(value: Any) -> str:
    return gene_label(value, with_code=False)


def display_gene_type(value: Any) -> str:
    return gene_type_label(value, with_code=False)


def display_creature_name(value: Any) -> str:
    return creature_name_label(value)


def display_mutation_name(value: Any) -> str:
    return mutation_name_label(value, with_code=False)


def display_task_name(value: Any) -> str:
    return task_name_label(value, with_code=False)


def display_task_difficulty(value: Any) -> str:
    return task_difficulty_label(value)


def format_phenotype_summary(summary: Any) -> str:
    return phenotype_summary_label(summary)


def dominance_label(value: Any, *, with_code: bool = False) -> str:
    code = display_value(value).upper()
    label = DOMINANCE_LABELS.get(code, display_value(value))
    return f"{label} ({code})" if with_code and code != "НЕ УКАЗАНО" else label


def task_status_label(value: Any, *, with_code: bool = True) -> str:
    code = display_value(value).upper()
    label = TASK_STATUS_LABELS.get(code, display_value(value))
    return f"{label} ({code})" if with_code and code != "НЕ УКАЗАНО" else label


def experiment_type_label(value: Any, *, with_code: bool = True) -> str:
    code = display_value(value).upper()
    label = EXPERIMENT_TYPE_LABELS.get(code, display_value(value))
    return f"{label} ({code})" if with_code and code != "НЕ УКАЗАНО" else label


def mutagen_type_label(value: Any, *, with_code: bool = True) -> str:
    code = display_value(value).upper()
    label = MUTAGEN_TYPE_LABELS.get(code, display_value(value))
    return f"{label} ({code})" if with_code and code != "НЕ УКАЗАНО" else label


def mutation_type_label(value: Any) -> str:
    try:
        mutation_type = int(value)
    except (TypeError, ValueError):
        return display_value(value)
    label = MUTATION_TYPE_LABELS.get(mutation_type, f"Тип {mutation_type}")
    return f"{label} (тип {mutation_type})"


def mutation_name_label(value: Any, *, with_code: bool = False) -> str:
    code = display_value(value)
    label = MUTATION_NAME_LABELS.get(code.lower(), code.replace("_", " "))
    return f"{label} ({code})" if with_code and code != "Не указано" else label


def task_name_label(value: Any, *, with_code: bool = False) -> str:
    code = display_value(value)
    label = TASK_NAME_LABELS.get(code.lower(), code.replace("_", " "))
    return f"{label} ({code})" if with_code and code != "Не указано" else label


def task_difficulty_label(value: Any) -> str:
    code = display_value(value)
    if code == "Не указано":
        return code
    return TASK_DIFFICULTY_LABELS.get(code.lower(), "Среднее")

def creature_name_label(value: Any) -> str:
    text = display_value(value)
    if text == "Не указано":
        return text
    return _creature_name_label_inner(text)


def phenotype_summary_label(value: Any) -> str:
    raw = display_value(value)
    if raw == "Не указано":
        return raw
    parts = [part.strip() for part in raw.split(";") if part.strip()]
    if not parts:
        return raw

    lines: list[str] = []
    for part in parts:
        if "=" not in part:
            lines.append(display_trait_value(part))
            continue
        gene_code, trait_code = part.split("=", 1)
        lines.append(f"{display_gene_name(gene_code.strip())}: {display_trait_value(trait_code.strip())}")
    return "\n".join(lines)


def _trait_expression_label(value: str) -> str:
    text = value.strip()
    lower_text = text.lower()

    if lower_text.startswith("intermediate(") and text.endswith(")"):
        inside = text[len("intermediate(") : -1]
        left, right = _split_pair(inside)
        if left is not None and right is not None:
            if {left.lower(), right.lower()} == {"large_size", "compact_size"}:
                return "средний размер"
            return f"промежуточное значение: {_format_pair_label(left, right)}"
        return f"промежуточное значение: {inside}"

    if lower_text == "carnivore/herbivore":
        return "смешанный тип питания: хищный + травоядный"
    if lower_text == "herbivore/carnivore":
        return "смешанный тип питания: травоядный + хищный"

    left, right = _split_pair(text)
    if left is not None and right is not None:
        return _format_pair_label(left, right)

    return trait_label(text)


def _split_pair(value: str) -> tuple[str, str] | tuple[None, None]:
    if "/" not in value:
        return None, None
    left, right = value.split("/", 1)
    left = left.strip()
    right = right.strip()
    if not left or not right:
        return None, None
    return left, right


def _format_pair_label(left: str, right: str) -> str:
    left_label = trait_label(left)
    right_label = trait_label(right)
    suffix = " тип питания"
    if left_label.endswith(suffix) and right_label.endswith(suffix):
        left_base = left_label[: -len(suffix)].strip()
        right_base = right_label[: -len(suffix)].strip()
        return f"{left_base} / {right_base}{suffix}"
    return f"{left_label} / {right_label}"


def _creature_name_label_inner(text: str) -> str:
    lower = text.lower()
    if "_mutagen_" in lower:
        split_index = lower.index("_mutagen_")
        base_name = text[:split_index].rstrip(" _-")
        if base_name:
            return f"Мутант: {_creature_name_label_inner(base_name)}"
        return "Мутант"

    match = re.fullmatch(r"([a-z_]+)\s*#\s*(\d+)", text)
    if match:
        prefix = match.group(1).lower()
        idx = match.group(2)
        prefix_label = CREATURE_PREFIX_LABELS.get(prefix)
        if prefix_label:
            return f"{prefix_label} №{idx}"

    return text


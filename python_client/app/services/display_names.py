from __future__ import annotations

import re
from typing import Any

SPECIES_LABELS = {
    1: "\u0425\u0440\u044f\u0449\u0435\u0432\u044b\u0435 \u0440\u044b\u0431\u044b",
    2: "\u041a\u043e\u0441\u0442\u043d\u044b\u0435 \u0440\u044b\u0431\u044b",
    3: "\u0420\u0430\u043a\u043e\u043e\u0431\u0440\u0430\u0437\u043d\u044b\u0435",
    4: "\u041c\u043e\u043b\u043b\u044e\u0441\u043a\u0438",
    5: "\u0427\u0435\u0440\u0435\u043f\u0430\u0445\u0438",
    6: "\u041c\u043b\u0435\u043a\u043e\u043f\u0438\u0442\u0430\u044e\u0449\u0438\u0435",
}

GENE_LABELS = {
    "color": "\u0426\u0432\u0435\u0442",
    "size": "\u0420\u0430\u0437\u043c\u0435\u0440",
    "nutrition_type": "\u0422\u0438\u043f \u043f\u0438\u0442\u0430\u043d\u0438\u044f",
    "has_wings": "\u041a\u0440\u044b\u043b\u044c\u044f",
    "fin_shape": "\u0424\u043e\u0440\u043c\u0430 \u043f\u043b\u0430\u0432\u043d\u0438\u043a\u0430",
    "shell_armor": "\u041f\u0430\u043d\u0446\u0438\u0440\u044c",
    "claw_form": "\u041a\u043b\u0435\u0448\u043d\u0438",
    "beak_nose_shape": "\u0424\u043e\u0440\u043c\u0430 \u043a\u043b\u044e\u0432\u0430/\u043d\u043e\u0441\u0430",
    "speed_level": "\u0421\u043a\u043e\u0440\u043e\u0441\u0442\u044c",
    "fur_density": "\u0428\u0435\u0440\u0441\u0442\u044c",
}

GENE_TYPE_LABELS = {
    "trait": "\u0411\u0430\u0437\u043e\u0432\u044b\u0439 \u043f\u0440\u0438\u0437\u043d\u0430\u043a",
    "morphology": "\u041c\u043e\u0440\u0444\u043e\u043b\u043e\u0433\u0438\u044f",
    "performance": "\u041f\u0440\u043e\u0438\u0437\u0432\u043e\u0434\u0438\u0442\u0435\u043b\u044c\u043d\u043e\u0441\u0442\u044c",
    "physiology": "\u0424\u0438\u0437\u0438\u043e\u043b\u043e\u0433\u0438\u044f",
}

TRAIT_LABELS = {
    "green_color": "\u0437\u0435\u043b\u0451\u043d\u0430\u044f \u043e\u043a\u0440\u0430\u0441\u043a\u0430",
    "blue_color": "\u0441\u0438\u043d\u044f\u044f \u043e\u043a\u0440\u0430\u0441\u043a\u0430",
    "compact_size": "\u043a\u043e\u043c\u043f\u0430\u043a\u0442\u043d\u044b\u0439 \u0440\u0430\u0437\u043c\u0435\u0440",
    "large_size": "\u043a\u0440\u0443\u043f\u043d\u044b\u0439 \u0440\u0430\u0437\u043c\u0435\u0440",
    "herbivore": "\u0442\u0440\u0430\u0432\u043e\u044f\u0434\u043d\u044b\u0439 \u0442\u0438\u043f \u043f\u0438\u0442\u0430\u043d\u0438\u044f",
    "carnivore": "\u0445\u0438\u0449\u043d\u044b\u0439 \u0442\u0438\u043f \u043f\u0438\u0442\u0430\u043d\u0438\u044f",
    "no_wings": "\u0431\u0435\u0437 \u043a\u0440\u044b\u043b\u044c\u0435\u0432",
    "wings": "\u0435\u0441\u0442\u044c \u043a\u0440\u044b\u043b\u044c\u044f",
    "pointed_fin": "\u0437\u0430\u043e\u0441\u0442\u0440\u0451\u043d\u043d\u044b\u0439 \u043f\u043b\u0430\u0432\u043d\u0438\u043a",
    "broad_fin": "\u0448\u0438\u0440\u043e\u043a\u0438\u0439 \u043f\u043b\u0430\u0432\u043d\u0438\u043a",
    "rounded_fin": "\u043e\u043a\u0440\u0443\u0433\u043b\u044b\u0439 \u043f\u043b\u0430\u0432\u043d\u0438\u043a",
    "forked_fin": "\u0440\u0430\u0437\u0434\u0432\u043e\u0435\u043d\u043d\u044b\u0439 \u043f\u043b\u0430\u0432\u043d\u0438\u043a",
    "thick_armor": "\u043f\u0440\u043e\u0447\u043d\u044b\u0439 \u043f\u0430\u043d\u0446\u0438\u0440\u044c",
    "light_armor": "\u043b\u0451\u0433\u043a\u0438\u0439 \u043f\u0430\u043d\u0446\u0438\u0440\u044c",
    "short_claws": "\u043a\u043e\u0440\u043e\u0442\u043a\u0438\u0435 \u043a\u043b\u0435\u0448\u043d\u0438",
    "long_claws": "\u0434\u043b\u0438\u043d\u043d\u044b\u0435 \u043a\u043b\u0435\u0448\u043d\u0438",
    "rounded_nose": "\u043e\u043a\u0440\u0443\u0433\u043b\u0430\u044f \u0444\u043e\u0440\u043c\u0430",
    "sharp_beak": "\u043e\u0441\u0442\u0440\u044b\u0439 \u043a\u043b\u044e\u0432",
    "smooth_shell": "\u0433\u043b\u0430\u0434\u043a\u0438\u0439 \u043f\u0430\u043d\u0446\u0438\u0440\u044c",
    "spiked_shell": "\u0448\u0438\u043f\u0430\u0441\u0442\u044b\u0439 \u043f\u0430\u043d\u0446\u0438\u0440\u044c",
    "slow_speed": "\u043d\u0438\u0437\u043a\u0430\u044f \u0441\u043a\u043e\u0440\u043e\u0441\u0442\u044c",
    "fast_speed": "\u0432\u044b\u0441\u043e\u043a\u0430\u044f \u0441\u043a\u043e\u0440\u043e\u0441\u0442\u044c",
    "short_fur": "\u043a\u043e\u0440\u043e\u0442\u043a\u0430\u044f \u0448\u0435\u0440\u0441\u0442\u044c",
    "dense_fur": "\u0433\u0443\u0441\u0442\u0430\u044f \u0448\u0435\u0440\u0441\u0442\u044c",
}

DOMINANCE_LABELS = {
    "FULL": "\u041f\u043e\u043b\u043d\u043e\u0435 \u0434\u043e\u043c\u0438\u043d\u0438\u0440\u043e\u0432\u0430\u043d\u0438\u0435",
    "INCOMPLETE": "\u041d\u0435\u043f\u043e\u043b\u043d\u043e\u0435 \u0434\u043e\u043c\u0438\u043d\u0438\u0440\u043e\u0432\u0430\u043d\u0438\u0435",
    "CODOMINANT": "\u041a\u043e\u0434\u043e\u043c\u0438\u043d\u0438\u0440\u043e\u0432\u0430\u043d\u0438\u0435",
}

TASK_STATUS_LABELS = {"ACTIVE": "\u0410\u043a\u0442\u0438\u0432\u043d\u043e", "COMPLETED": "\u0412\u044b\u043f\u043e\u043b\u043d\u0435\u043d\u043e"}
EXPERIMENT_TYPE_LABELS = {"CROSS": "\u0413\u0435\u043d\u0435\u0442\u0438\u0447\u0435\u0441\u043a\u0438\u0439 \u044d\u043a\u0441\u043f\u0435\u0440\u0438\u043c\u0435\u043d\u0442", "MUTATION": "\u041c\u0443\u0442\u0430\u0446\u0438\u044f", "MUTAGEN": "\u041c\u0443\u0442\u0430\u0433\u0435\u043d"}
MUTAGEN_TYPE_LABELS = {"RADIATION": "\u0420\u0430\u0434\u0438\u0430\u0446\u0438\u043e\u043d\u043d\u044b\u0439", "CHEMICAL": "\u0425\u0438\u043c\u0438\u0447\u0435\u0441\u043a\u0438\u0439"}

MUTATION_NAME_LABELS = {
    "radiation_mutation": "\u0420\u0430\u0434\u0438\u0430\u0446\u0438\u043e\u043d\u043d\u0430\u044f \u043c\u0443\u0442\u0430\u0446\u0438\u044f",
    "chemical_mutation": "\u0425\u0438\u043c\u0438\u0447\u0435\u0441\u043a\u0430\u044f \u043c\u0443\u0442\u0430\u0446\u0438\u044f",
    "enhanced_color_mutation": "\u0423\u0441\u0438\u043b\u0435\u043d\u043d\u0430\u044f \u043c\u0443\u0442\u0430\u0446\u0438\u044f \u043e\u043a\u0440\u0430\u0441\u043a\u0438",
    "size_shift_mutation": "\u041c\u0443\u0442\u0430\u0446\u0438\u044f \u0440\u0430\u0437\u043c\u0435\u0440\u0430",
    "nutrition_shift_mutation": "\u041c\u0443\u0442\u0430\u0446\u0438\u044f \u0442\u0438\u043f\u0430 \u043f\u0438\u0442\u0430\u043d\u0438\u044f",
    "wing_activation_mutation": "\u041c\u0443\u0442\u0430\u0446\u0438\u044f \u0430\u043a\u0442\u0438\u0432\u0430\u0446\u0438\u0438 \u043a\u0440\u044b\u043b\u044c\u0435\u0432",
    "aquatic_form_mutation": "\u041c\u0443\u0442\u0430\u0446\u0438\u044f \u0432\u043e\u0434\u043d\u043e\u0439 \u0444\u043e\u0440\u043c\u044b",
    "morphology_refine_mutation": "\u041c\u0443\u0442\u0430\u0446\u0438\u044f \u043c\u043e\u0440\u0444\u043e\u043b\u043e\u0433\u0438\u0447\u0435\u0441\u043a\u043e\u0439 \u043a\u043e\u0440\u0440\u0435\u043a\u0442\u0438\u0440\u043e\u0432\u043a\u0438",
}

TASK_NAME_LABELS = {}

CREATURE_PREFIX_LABELS = {
    "cartilaginous_fish": "\u0425\u0440\u044f\u0449\u0435\u0432\u0430\u044f \u0440\u044b\u0431\u0430",
    "bony_fish": "\u041a\u043e\u0441\u0442\u043d\u0430\u044f \u0440\u044b\u0431\u0430",
    "crustacean": "\u0420\u0430\u043a\u043e\u043e\u0431\u0440\u0430\u0437\u043d\u043e\u0435",
    "mollusk": "\u041c\u043e\u043b\u043b\u044e\u0441\u043a",
    "turtle": "\u0427\u0435\u0440\u0435\u043f\u0430\u0445\u0430",
    "mammal": "\u041c\u043b\u0435\u043a\u043e\u043f\u0438\u0442\u0430\u044e\u0449\u0435\u0435",
}

MUTATION_TYPE_LABELS = {1: "\u0420\u0430\u0434\u0438\u0430\u0446\u0438\u043e\u043d\u043d\u0430\u044f", 2: "\u0425\u0438\u043c\u0438\u0447\u0435\u0441\u043a\u0430\u044f", 3: "\u041e\u043a\u0440\u0430\u0441\u043a\u0430", 4: "\u0420\u0430\u0437\u043c\u0435\u0440", 5: "\u041f\u0438\u0442\u0430\u043d\u0438\u0435", 6: "\u041a\u0440\u044b\u043b\u044c\u044f", 7: "\u0412\u043e\u0434\u043d\u0430\u044f \u043c\u043e\u0440\u0444\u043e\u043b\u043e\u0433\u0438\u044f", 8: "\u041c\u043e\u0440\u0444\u043e\u043b\u043e\u0433\u0438\u044f"}


def display_value(value: Any, *, empty_label: str = "\u041d\u0435 \u0443\u043a\u0430\u0437\u0430\u043d\u043e") -> str:
    if value is None:
        return empty_label
    text = str(value).strip()
    return text if text else empty_label


def species_label(value: Any) -> str:
    try:
        species_id = int(value)
    except (TypeError, ValueError):
        return "\u041d\u0435 \u0443\u043a\u0430\u0437\u0430\u043d\u043e"
    return SPECIES_LABELS.get(species_id, f"\u0422\u0438\u043f {species_id}")


def gene_label(value: Any, *, with_code: bool = False) -> str:
    code = display_value(value)
    label = GENE_LABELS.get(code.lower(), code.replace("_", " "))
    return f"{label} ({code})" if with_code and code != "\u041d\u0435 \u0443\u043a\u0430\u0437\u0430\u043d\u043e" else label


def gene_type_label(value: Any, *, with_code: bool = False) -> str:
    code = display_value(value)
    label = GENE_TYPE_LABELS.get(code.lower(), code)
    return f"{label} ({code})" if with_code and code != "\u041d\u0435 \u0443\u043a\u0430\u0437\u0430\u043d\u043e" else label


def trait_label(value: Any, *, with_code: bool = False) -> str:
    code = display_value(value)
    label = TRAIT_LABELS.get(code.lower(), code)
    return f"{label} ({code})" if with_code and code != "\u041d\u0435 \u0443\u043a\u0430\u0437\u0430\u043d\u043e" else label


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


def format_phenotype_summary(summary: Any) -> str:
    return phenotype_summary_label(summary)


def dominance_label(value: Any, *, with_code: bool = False) -> str:
    code = display_value(value).upper()
    label = DOMINANCE_LABELS.get(code, display_value(value))
    return f"{label} ({code})" if with_code and code != "\u041d\u0415 \u0423\u041a\u0410\u0417\u0410\u041d\u041e" else label


def task_status_label(value: Any, *, with_code: bool = True) -> str:
    code = display_value(value).upper()
    label = TASK_STATUS_LABELS.get(code, display_value(value))
    return f"{label} ({code})" if with_code and code != "\u041d\u0415 \u0423\u041a\u0410\u0417\u0410\u041d\u041e" else label


def experiment_type_label(value: Any, *, with_code: bool = True) -> str:
    code = display_value(value).upper()
    label = EXPERIMENT_TYPE_LABELS.get(code, display_value(value))
    return f"{label} ({code})" if with_code and code != "\u041d\u0415 \u0423\u041a\u0410\u0417\u0410\u041d\u041e" else label


def mutagen_type_label(value: Any, *, with_code: bool = True) -> str:
    code = display_value(value).upper()
    label = MUTAGEN_TYPE_LABELS.get(code, display_value(value))
    return f"{label} ({code})" if with_code and code != "\u041d\u0415 \u0423\u041a\u0410\u0417\u0410\u041d\u041e" else label


def mutation_type_label(value: Any) -> str:
    try:
        mutation_type = int(value)
    except (TypeError, ValueError):
        return display_value(value)
    label = MUTATION_TYPE_LABELS.get(mutation_type, f"\u0422\u0438\u043f {mutation_type}")
    return f"{label} (\u0442\u0438\u043f {mutation_type})"


def mutation_name_label(value: Any, *, with_code: bool = False) -> str:
    code = display_value(value)
    label = MUTATION_NAME_LABELS.get(code.lower(), code.replace("_", " "))
    return f"{label} ({code})" if with_code and code != "\u041d\u0435 \u0443\u043a\u0430\u0437\u0430\u043d\u043e" else label


def task_name_label(value: Any, *, with_code: bool = False) -> str:
    code = display_value(value)
    label = TASK_NAME_LABELS.get(code.lower(), code.replace("_", " "))
    return f"{label} ({code})" if with_code and code != "\u041d\u0435 \u0443\u043a\u0430\u0437\u0430\u043d\u043e" else label


def creature_name_label(value: Any) -> str:
    text = display_value(value)
    if text == "\u041d\u0435 \u0443\u043a\u0430\u0437\u0430\u043d\u043e":
        return text
    return _creature_name_label_inner(text)


def phenotype_summary_label(value: Any) -> str:
    raw = display_value(value)
    if raw == "\u041d\u0435 \u0443\u043a\u0430\u0437\u0430\u043d\u043e":
        return raw
    parts = [part.strip() for part in raw.split(";") if part.strip()]
    if not parts:
        return raw
    lines = []
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
                return "\u0441\u0440\u0435\u0434\u043d\u0438\u0439 \u0440\u0430\u0437\u043c\u0435\u0440"
            return f"\u043f\u0440\u043e\u043c\u0435\u0436\u0443\u0442\u043e\u0447\u043d\u043e\u0435 \u0437\u043d\u0430\u0447\u0435\u043d\u0438\u0435: {_format_pair_label(left, right)}"
        return f"\u043f\u0440\u043e\u043c\u0435\u0436\u0443\u0442\u043e\u0447\u043d\u043e\u0435 \u0437\u043d\u0430\u0447\u0435\u043d\u0438\u0435: {inside}"
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
    suffix = " \u0442\u0438\u043f \u043f\u0438\u0442\u0430\u043d\u0438\u044f"
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
            return f"\u041c\u0443\u0442\u0430\u043d\u0442: {_creature_name_label_inner(base_name)}"
        return "\u041c\u0443\u0442\u0430\u043d\u0442"
    match = re.fullmatch(r"([a-z_]+)\s*#\s*(\d+)", text)
    if match:
        prefix = match.group(1).lower()
        idx = match.group(2)
        prefix_label = CREATURE_PREFIX_LABELS.get(prefix)
        if prefix_label:
            return f"{prefix_label} \u2116{idx}"
    return text

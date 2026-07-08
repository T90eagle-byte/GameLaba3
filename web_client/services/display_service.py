from __future__ import annotations

import re
from typing import Any


SPECIES_LABELS = {
    "1": "Хрящевая рыба",
    "2": "Костная рыба",
    "3": "Ракообразное",
    "4": "Моллюск",
    "5": "Черепаха",
    "6": "Млекопитающее",
    "cartilaginous_fish": "Хрящевая рыба",
    "bony_fish": "Костная рыба",
    "crustacean": "Ракообразное",
    "mollusk": "Моллюск",
    "turtle": "Черепаха",
    "mammal": "Млекопитающее",
    "canis_lupus": "Волко-собака",
    "felis_catus": "Кошачий вид",
    "avis_aurora": "Аврора-птица",
    "reptilia_solaris": "Солнечная рептилия",
    "amphibia_lumen": "Световая амфибия",
    "insecta_chroma": "Хрома-насекомое",
}

GENE_LABELS = {
    "color": "Окрас",
    "size": "Размер",
    "has_wings": "Крылья",
    "nutrition_type": "Питание",
    "fin_shape": "Плавники",
    "shell_armor": "Панцирь",
    "claw_form": "Клешни",
    "beak_nose_shape": "Профиль",
    "speed_level": "Скорость",
    "fur_density": "Покров",
    "trait": "Признак",
}

TRAIT_LABELS = {
    "red_color": "красный",
    "blue_color": "синий",
    "green_color": "зелёный",
    "yellow_color": "жёлтый",
    "purple_color": "фиолетовый",
    "white_color": "белый",
    "orange_color": "оранжевый",
    "black_color": "чёрный",
    "brown_color": "бурый",
    "silver_color": "серебристый",
    "compact_size": "компактный",
    "small_size": "малый",
    "medium_size": "средний",
    "large_size": "крупный",
    "giant_size": "гигантский",
    "compact": "компактный",
    "medium": "средний",
    "large": "крупный",
    "small": "малый",
    "has_wings": "есть крылья",
    "wings": "есть крылья",
    "no_wings": "без крыльев",
    "herbivore": "травоядное",
    "carnivore": "хищное",
    "omnivore": "всеядное",
    "filter_feeder": "фильтратор",
    "predator": "хищное",
    "crescent_fin": "серповидный плавник",
    "broad_fin": "широкий плавник",
    "pointed_fin": "заострённый плавник",
    "ribbon_fin": "ленточный плавник",
    "forked_fin": "раздвоенный плавник",
    "rounded_fin": "округлый плавник",
    "long_claws": "длинные клешни",
    "hooked_claws": "крючковатые клешни",
    "short_claws": "короткие клешни",
    "thick_armor": "толстый панцирь",
    "ridged_armor": "ребристый панцирь",
    "smooth_shell": "гладкий панцирь",
    "plated_shell": "пластинчатый панцирь",
    "rounded_nose": "округлый профиль",
    "spiral_profile": "спиральный профиль",
    "fast_speed": "быстрый",
    "slow_speed": "медленный",
    "short_fur": "короткая шерсть",
    "soft_fur": "мягкая шерсть",
    "dense_fur": "густая шерсть",
}

DOMINANCE_LABELS = {
    "complete": "полное доминирование",
    "incomplete": "неполное доминирование",
    "codominance": "кодоминирование",
    "codominant": "кодоминирование",
    "linked": "сцепленное наследование",
}

TASK_LABELS = {
    "task_green_specimen": "Зелёное существо",
    "task_winged_specimen": "Крылатое существо",
    "task_fast_turtle": "Быстрая черепаха",
}

TASK_DESCRIPTIONS = {
    "task_green_specimen": "Клиент просит вывести существо с зелёным окрасом.",
    "task_winged_specimen": "Клиенту нужен организм с крыльями.",
    "task_fast_turtle": "Нужно получить быструю черепаху для специального заказа.",
}

MUTATION_LABELS = {
    "chemical mutation": "Химическая мутация",
    "radiation mutation": "Радиационная мутация",
    "nutrition shift mutation": "Сдвиг типа питания",
    "wing activation mutation": "Активация крыльев",
    "size shift mutation": "Изменение размера",
    "red mutation": "Красная окраска",
    "blue mutation": "Синяя окраска",
    "green mutation": "Зелёная окраска",
    "yellow mutation": "Жёлтая окраска",
    "purple mutation": "Фиолетовая окраска",
    "orange mutation": "Оранжевая окраска",
    "white mutation": "Белая окраска",
    "black mutation": "Чёрная окраска",
}

EVENT_LABELS = {
    "TASK_REWARD": "Награда за заказ",
    "MUTATION_PURCHASE": "Покупка мутации",
    "MUTAGEN_PENALTY": "Риск мутагена",
    "MUTATION_EFFECT": "Эффект мутации",
    "RARE_TRAIT_BONUS": "Бонус редкого признака",
}

EXPERIMENT_LABELS = {
    "CROSS": "Скрещивание",
    "MUTATION": "Мутация",
    "MUTAGEN": "Мутагент",
}

COLOR_CLASSES = {
    "green": "tone-green",
    "blue": "tone-blue",
    "red": "tone-red",
    "yellow": "tone-yellow",
    "purple": "tone-purple",
    "orange": "tone-orange",
    "white": "tone-white",
    "black": "tone-black",
    "brown": "tone-brown",
    "silver": "tone-silver",
}

TECH_SPECIES_PREFIXES = tuple(SPECIES_LABELS.keys())


def _text(value: Any) -> str:
    return "" if value is None else str(value).strip()


def _clean_code(value: Any) -> str:
    return _text(value).strip().strip("`").lower()


def _strip_mojibake(value: str) -> str:
    markers = (chr(0x0420), chr(0x0421) + chr(0x0453), chr(0x00D0), chr(0x00D1))
    return "" if any(marker in value for marker in markers) else value


def _title_fallback(code: str) -> str:
    clean = code.replace("_color", "").replace("_size", "").replace("_", " ").strip()
    return clean[:1].upper() + clean[1:] if clean else "не указано"


def humanize_code(value: Any) -> str:
    raw = _text(value)
    code = _clean_code(raw)
    if not code:
        return "не указано"
    if code.startswith("intermediate(") and code.endswith(")"):
        inner = raw[raw.find("(") + 1 : raw.rfind(")")]
        return "промежуточный: " + " / ".join(trait_label(part) for part in inner.split("/"))
    if "/" in code:
        parts = [trait_label(part) for part in raw.split("/") if part.strip()]
        return "смешанное: " + " / ".join(parts)
    if code in TRAIT_LABELS:
        return TRAIT_LABELS[code]
    if code in GENE_LABELS:
        return GENE_LABELS[code]
    if code in SPECIES_LABELS:
        return SPECIES_LABELS[code]
    if code in DOMINANCE_LABELS:
        return DOMINANCE_LABELS[code]
    return _title_fallback(code)


def species_label(row: dict[str, Any]) -> str:
    code = _clean_code(row.get("species_type") or row.get("species_code"))
    if code in SPECIES_LABELS:
        return SPECIES_LABELS[code]
    display = _strip_mojibake(_text(row.get("species_display_name") or row.get("species_label")))
    if display:
        return display
    return humanize_code(code)


def _creature_number(row: dict[str, Any]) -> str:
    name = _text(row.get("creature_name"))
    match = re.search(r"#\s*(\d+)", name)
    if match:
        return match.group(1)
    creature_id = _text(row.get("creature_id"))
    return creature_id or "?"


def creature_name(row: dict[str, Any]) -> str:
    name = _text(row.get("creature_name"))
    lower = name.lower()
    if name and not any(lower.startswith(prefix) for prefix in TECH_SPECIES_PREFIXES):
        return name
    return f"{species_label(row)} #{_creature_number(row)}"


def trait_label(value: Any) -> str:
    return humanize_code(value)


def gene_label(value: Any) -> str:
    code = _clean_code(value)
    return GENE_LABELS.get(code, humanize_code(code))


def dominance_label(value: Any) -> str:
    return DOMINANCE_LABELS.get(_clean_code(value), humanize_code(value))


def _color_key(value: Any) -> str:
    code = _clean_code(value)
    for key in COLOR_CLASSES:
        if key in code:
            return key
    return "green"


def color_class(value: Any) -> str:
    return COLOR_CLASSES.get(_color_key(value), "tone-green")


def parse_phenotype(summary: Any) -> list[dict[str, str]]:
    text = _text(summary)
    items: list[dict[str, str]] = []
    if not text:
        return items
    for raw_part in text.replace("|", ";").split(";"):
        part = raw_part.strip()
        if not part:
            continue
        if "=" in part:
            key, value = part.split("=", 1)
        elif ":" in part:
            key, value = part.split(":", 1)
        else:
            key, value = "trait", part
        key = key.strip()
        value = value.strip()
        items.append({"key": key, "label": gene_label(key), "value": trait_label(value), "raw": value, "class": color_class(value) if "color" in key.lower() else "tone-neutral"})
    return items


def phenotype_items(row: dict[str, Any]) -> list[dict[str, str]]:
    items = parse_phenotype(row.get("phenotype_summary"))
    seen = {_clean_code(item["key"]) for item in items}
    explicit = [("color", row.get("phenotype_color")), ("size", row.get("phenotype_size")), ("has_wings", row.get("phenotype_has_wings")), ("nutrition_type", row.get("phenotype_nutrition_type"))]
    for key, value in explicit:
        if value and key not in seen:
            items.append({"key": key, "label": gene_label(key), "value": trait_label(value), "raw": _text(value), "class": color_class(value) if key == "color" else "tone-neutral"})
    return items


def phenotype_sentence(row: dict[str, Any]) -> str:
    items = phenotype_items(row)
    if not items:
        return "Фенотип пока не описан."
    return " · ".join(f"{item['label']}: {item['value']}" for item in items[:5])


def creature_visual(row: dict[str, Any]) -> dict[str, str]:
    species = _clean_code(row.get("species_type") or row.get("species_label"))
    species_class = "species-" + (species.replace("_", "-") if species else "default")
    color = row.get("phenotype_color") or row.get("phenotype_summary")
    wings_raw = _clean_code(row.get("phenotype_has_wings") or row.get("phenotype_summary"))
    wings = "has-wings" if "wing" in wings_raw and "no_wings" not in wings_raw else "no-wings"
    return {"species_class": species_class, "tone_class": color_class(color), "wings_class": wings}


def creature_view(row: dict[str, Any]) -> dict[str, Any]:
    view = dict(row)
    view["display_name"] = creature_name(row)
    view["species_label"] = species_label(row)
    view["phenotype_items"] = phenotype_items(row)
    view["phenotype_text"] = phenotype_sentence(row)
    view["visual"] = creature_visual(row)
    return view


def creature_views(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [creature_view(row) for row in rows]


def genotype_view(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    formatted = []
    for row in rows:
        allele1 = row.get("allele1_trait_value") or row.get("allele1_display_name")
        allele2 = row.get("allele2_trait_value") or row.get("allele2_display_name")
        gene = row.get("gene_name") or row.get("gene_type") or row.get("gene_display_name")
        dominance = row.get("dominance_type") or row.get("dominance_display_name")
        formatted.append({**row, "gene_label": gene_label(gene), "gene_code": _text(gene), "dominance_label": dominance_label(dominance), "allele1_label": trait_label(allele1), "allele2_label": trait_label(allele2), "pair_label": f"{trait_label(allele1)} / {trait_label(allele2)}"})
    return formatted


def _probability_label(value: Any) -> str:
    try:
        number = float(value or 0)
    except (TypeError, ValueError):
        return "не указана"
    if number <= 1:
        number *= 100
    return f"{number:.1f}%"


def preview_view(row: dict[str, Any]) -> dict[str, Any]:
    view = creature_view(row)
    view["option_no"] = row.get("option_no")
    view["probability"] = row.get("probability")
    view["probability_label"] = _probability_label(row.get("probability"))
    view["genotype_summary"] = _text(row.get("genotype_summary"))
    view["source_note"] = "Предпросмотр"
    view["display_name"] = f"Вариант {row.get('option_no')}"
    return view


def preview_views(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [preview_view(row) for row in rows]


def task_view(row: dict[str, Any]) -> dict[str, Any]:
    status = _text(row.get("task_status")).upper()
    code = _clean_code(row.get("task_name") or row.get("task_code") or row.get("title"))
    difficulty = row.get("difficulty_display_name") or row.get("difficulty_code") or row.get("difficulty")
    name = TASK_LABELS.get(code) or _strip_mojibake(_text(row.get("task_display_name"))) or humanize_code(code.replace("task_", ""))
    description = _text(row.get("description") or row.get("task_description") or row.get("goal_description"))
    if not description or code in TASK_DESCRIPTIONS:
        description = TASK_DESCRIPTIONS.get(code, f"Клиент просит организм: {name.lower()}.")
    return {**row, "display_name": name, "description_text": description, "status_label": "Выполнен" if status == "COMPLETED" else "Активен" if status == "ACTIVE" else humanize_code(status), "status_class": "status-completed" if status == "COMPLETED" else "status-active" if status == "ACTIVE" else "status-neutral", "difficulty_label": humanize_code(difficulty)}


def task_views(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [task_view(row) for row in rows]


def _mutation_label(value: Any) -> str:
    text = _text(value)
    code = _clean_code(text)
    if code in MUTATION_LABELS:
        return MUTATION_LABELS[code]
    spaced = code.replace("_", " ")
    if spaced in MUTATION_LABELS:
        return MUTATION_LABELS[spaced]
    return humanize_code(code)


def mutation_view(row: dict[str, Any]) -> dict[str, Any]:
    name = row.get("mutation_name") or row.get("display_name") or row.get("mutation_code") or f"mutation {row.get('mutation_id')}"
    target = row.get("target_trait") or row.get("trait_value") or row.get("gene_type") or row.get("gene_name")
    return {**row, "display_name": _mutation_label(name), "target_label": trait_label(target), "description_text": _text(row.get("description")) or "Точечное изменение выбранного признака."}


def mutation_views(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [mutation_view(row) for row in rows]


def experiment_view(row: dict[str, Any]) -> dict[str, Any]:
    kind = _text(row.get("experiment_type") or row.get("experiment_type_code")).upper()
    return {**row, "type_label": EXPERIMENT_LABELS.get(kind, humanize_code(kind)), "type_class": f"event-{kind.lower()}" if kind else "event-neutral", "description_text": _text(row.get("description") or row.get("result_description")) or "Шаг лабораторной линии."}


def experiment_views(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [experiment_view(row) for row in rows]


def rating_event_view(row: dict[str, Any]) -> dict[str, Any]:
    kind = _text(row.get("event_type") or row.get("event_code")).upper()
    rating_delta = row.get("rating_delta")
    wallet_delta = row.get("wallet_delta")
    return {**row, "type_label": EVENT_LABELS.get(kind, humanize_code(kind)), "event_class": f"event-{kind.lower()}" if kind else "event-neutral", "rating_class": _delta_class(rating_delta), "wallet_class": _delta_class(wallet_delta), "description_text": _text(row.get("description")) or "Записанное последствие действия."}


def rating_event_views(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [rating_event_view(row) for row in rows]


def _delta_class(value: Any) -> str:
    try:
        number = float(value or 0)
    except (TypeError, ValueError):
        number = 0
    if number > 0:
        return "delta-positive"
    if number < 0:
        return "delta-negative"
    return "delta-neutral"

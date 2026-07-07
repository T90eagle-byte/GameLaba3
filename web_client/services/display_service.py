from __future__ import annotations

from typing import Any


SPECIES_LABELS = {
    "CANIS_LUPUS": "Волко-собака",
    "FELIS_CATUS": "Кошачий вид",
    "AVIS_AURORA": "Аврора-птица",
    "REPTILIA_SOLARIS": "Солнечная рептилия",
    "AMPHIBIA_LUMEN": "Световая амфибия",
    "INSECTA_CHROMA": "Хрома-насекомое",
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
}

TRAIT_LABELS = {
    "green_color": "зелёный",
    "blue_color": "синий",
    "red_color": "красный",
    "yellow_color": "жёлтый",
    "purple_color": "фиолетовый",
    "orange_color": "оранжевый",
    "white_color": "белый",
    "black_color": "чёрный",
    "brown_color": "бурый",
    "silver_color": "серебристый",
    "compact_size": "компактный",
    "small_size": "малый",
    "medium_size": "средний",
    "large_size": "крупный",
    "giant_size": "гигантский",
    "has_wings": "есть крылья",
    "wings": "есть крылья",
    "no_wings": "без крыльев",
    "herbivore": "травоядное",
    "carnivore": "хищное",
    "omnivore": "всеядное",
    "filter_feeder": "фильтратор",
    "predator": "хищник",
    "rounded": "округлый",
    "sharp": "острый",
    "striped": "полосатый",
    "dense": "густой",
    "light": "лёгкий",
    "fast": "быстрый",
    "slow": "медленный",
}

DOMINANCE_LABELS = {
    "COMPLETE": "полное доминирование",
    "INCOMPLETE": "неполное доминирование",
    "CODOMINANCE": "кодоминирование",
    "LINKED": "сцепленное наследование",
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

MUTAGEN_LABELS = {
    "RADIATION": "Облучение",
    "CHEMICAL": "Химикаты",
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


def _text(value: Any) -> str:
    return "" if value is None else str(value).strip()


def _clean_code(value: Any) -> str:
    return _text(value).strip().strip("`").lower()


def humanize_code(value: Any) -> str:
    code = _clean_code(value)
    if not code:
        return "не указано"
    if code in TRAIT_LABELS:
        return TRAIT_LABELS[code]
    if code in GENE_LABELS:
        return GENE_LABELS[code]
    if code.upper() in SPECIES_LABELS:
        return SPECIES_LABELS[code.upper()]
    if code.upper() in DOMINANCE_LABELS:
        return DOMINANCE_LABELS[code.upper()]
    label = code.replace("_color", "").replace("_size", "").replace("_", " ")
    return label[:1].upper() + label[1:]


def species_label(row: dict[str, Any]) -> str:
    display = _text(row.get("species_display_name") or row.get("species_label"))
    if display and "Р" not in display:
        return display
    code = _text(row.get("species_type")).upper()
    return SPECIES_LABELS.get(code, humanize_code(code))


def trait_label(value: Any) -> str:
    return humanize_code(value)


def gene_label(value: Any) -> str:
    code = _clean_code(value)
    return GENE_LABELS.get(code, humanize_code(code))


def dominance_label(value: Any) -> str:
    code = _text(value).upper()
    return DOMINANCE_LABELS.get(code, humanize_code(code))


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
        items.append(
            {
                "key": key.strip(),
                "label": gene_label(key),
                "value": trait_label(value),
                "raw": value.strip(),
                "class": color_class(value) if "color" in key.lower() else "tone-neutral",
            }
        )
    return items


def phenotype_items(row: dict[str, Any]) -> list[dict[str, str]]:
    items = parse_phenotype(row.get("phenotype_summary"))
    seen = {_clean_code(item["key"]) for item in items}
    explicit = [
        ("color", row.get("phenotype_color")),
        ("size", row.get("phenotype_size")),
        ("has_wings", row.get("phenotype_has_wings")),
        ("nutrition_type", row.get("phenotype_nutrition_type")),
    ]
    for key, value in explicit:
        if value and key not in seen:
            items.append(
                {
                    "key": key,
                    "label": gene_label(key),
                    "value": trait_label(value),
                    "raw": _text(value),
                    "class": color_class(value) if key == "color" else "tone-neutral",
                }
            )
    return items


def phenotype_sentence(row: dict[str, Any]) -> str:
    items = phenotype_items(row)
    if not items:
        return "Фенотип пока не описан."
    pairs = [f"{item['label']}: {item['value']}" for item in items[:5]]
    return "; ".join(pairs)


def creature_visual(row: dict[str, Any]) -> dict[str, str]:
    species = _clean_code(row.get("species_type") or row.get("species_label"))
    species_class = "species-" + (species.replace("_", "-") if species else "default")
    color = row.get("phenotype_color") or row.get("phenotype_summary")
    wings_raw = _clean_code(row.get("phenotype_has_wings") or row.get("phenotype_summary"))
    wings = "has-wings" if "wing" in wings_raw and "no_wings" not in wings_raw else "no-wings"
    return {
        "species_class": species_class,
        "tone_class": color_class(color),
        "wings_class": wings,
    }


def creature_view(row: dict[str, Any]) -> dict[str, Any]:
    view = dict(row)
    view["display_name"] = _text(row.get("creature_name")) or f"Существо #{row.get('creature_id')}"
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
        allele1 = row.get("allele1_display_name") or row.get("allele1_trait_value")
        allele2 = row.get("allele2_display_name") or row.get("allele2_trait_value")
        gene = row.get("gene_display_name") or row.get("gene_name") or row.get("gene_type")
        dominance = row.get("dominance_display_name") or row.get("dominance_type")
        formatted.append(
            {
                **row,
                "gene_label": gene_label(gene),
                "gene_code": _text(row.get("gene_name") or row.get("gene_type")),
                "dominance_label": dominance_label(dominance),
                "allele1_label": trait_label(allele1),
                "allele2_label": trait_label(allele2),
                "pair_label": f"{trait_label(allele1)} / {trait_label(allele2)}",
            }
        )
    return formatted


def preview_view(row: dict[str, Any]) -> dict[str, Any]:
    view = creature_view(row)
    view["option_no"] = row.get("option_no")
    view["probability"] = row.get("probability")
    view["genotype_summary"] = _text(row.get("genotype_summary"))
    view["source_note"] = _text(row.get("source_note")) or "PREVIEW_ONLY"
    view["display_name"] = f"Вариант {row.get('option_no')}"
    return view


def preview_views(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [preview_view(row) for row in rows]


def task_view(row: dict[str, Any]) -> dict[str, Any]:
    status = _text(row.get("task_status")).upper()
    difficulty = row.get("difficulty_display_name") or row.get("difficulty_code") or row.get("difficulty")
    name = row.get("task_name") or row.get("task_display_name") or row.get("title") or f"Заказ #{row.get('task_id')}"
    description = row.get("description") or row.get("task_description") or row.get("goal_description") or ""
    return {
        **row,
        "display_name": _text(name),
        "description_text": _text(description),
        "status_label": "Выполнен" if status == "COMPLETED" else "Активен" if status == "ACTIVE" else humanize_code(status),
        "status_class": "status-completed" if status == "COMPLETED" else "status-active" if status == "ACTIVE" else "status-neutral",
        "difficulty_label": humanize_code(difficulty),
    }


def task_views(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [task_view(row) for row in rows]


def mutation_view(row: dict[str, Any]) -> dict[str, Any]:
    name = row.get("mutation_name") or row.get("display_name") or row.get("mutation_code") or f"Мутация #{row.get('mutation_id')}"
    target = row.get("target_trait") or row.get("trait_value") or row.get("gene_type") or row.get("gene_name")
    return {
        **row,
        "display_name": humanize_code(name) if "_" in _text(name) else _text(name),
        "target_label": trait_label(target),
        "description_text": _text(row.get("description")) or "Точечное изменение признака по правилам лаборатории.",
    }


def mutation_views(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [mutation_view(row) for row in rows]


def experiment_view(row: dict[str, Any]) -> dict[str, Any]:
    kind = _text(row.get("experiment_type") or row.get("experiment_type_code")).upper()
    return {
        **row,
        "type_label": EXPERIMENT_LABELS.get(kind, humanize_code(kind)),
        "type_class": f"event-{kind.lower()}" if kind else "event-neutral",
        "description_text": _text(row.get("description") or row.get("result_description")) or "Шаг лабораторной линии.",
    }


def experiment_views(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [experiment_view(row) for row in rows]


def rating_event_view(row: dict[str, Any]) -> dict[str, Any]:
    kind = _text(row.get("event_type") or row.get("event_code")).upper()
    rating_delta = row.get("rating_delta")
    wallet_delta = row.get("wallet_delta")
    return {
        **row,
        "type_label": EVENT_LABELS.get(kind, humanize_code(kind)),
        "event_class": f"event-{kind.lower()}" if kind else "event-neutral",
        "rating_class": _delta_class(rating_delta),
        "wallet_class": _delta_class(wallet_delta),
        "description_text": _text(row.get("description")) or "Записанное последствие действия.",
    }


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

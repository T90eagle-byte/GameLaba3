from __future__ import annotations

import re
from datetime import date, datetime
from typing import Any


SPECIES_LABELS = {
    "1": "Хрящевая рыба",
    "2": "Костная рыба",
    "3": "Ракообразное",
    "4": "Моллюск",
    "5": "Морские рептилии",
    "6": "Морские млекопитающие",
    "7": "Гибрид",
    "cartilaginous_fish": "Хрящевая рыба",
    "bony_fish": "Костная рыба",
    "crustacean": "Ракообразное",
    "mollusk": "Моллюск",
    "turtle": "Морские рептилии",
    "mammal": "Морские млекопитающие",
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
    "body_shape": "Форма тела",
    "body_proportion": "Пропорции тела",
    "body_size": "Размер тела",
    "body_cover": "Покров тела",
    "body_color": "Окрас тела",
    "mouth_type": "Тип рта",
    "snout_type": "Форма морды",
    "eye_type": "Тип глаз",
    "front_appendage_count": "Передние конечности",
    "front_appendage_type": "Тип передних конечностей",
    "front_appendage_size": "Размер передних конечностей",
    "rear_appendage_count": "Задние конечности",
    "rear_appendage_type": "Тип задних конечностей",
    "rear_appendage_size": "Размер задних конечностей",
    "tail_type": "Тип хвоста",
    "tail_size": "Размер хвоста",
    "dorsal_type": "Спинной покров",
    "dorsal_size": "Размер спинного покрова",
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
    "spiked_shell": "шипастый панцирь",
    "light_armor": "лёгкий панцирь",
    "rounded_nose": "округлый профиль",
    "spiral_profile": "спиральный профиль",
    "sharp_beak": "острый профиль",
    "fast_speed": "быстрый",
    "slow_speed": "медленный",
    "short_fur": "короткая шерсть",
    "soft_fur": "мягкая шерсть",
    "dense_fur": "густая шерсть",
    "streamlined": "обтекаемая форма",
    "shark_like": "акулообразная форма",
    "disc": "дискообразная форма",
    "eel_like": "угреобразная форма",
    "cetacean": "китообразная форма",
    "pinniped": "ластоногая форма",
    "crustacean": "ракообразная форма",
    "shrimp_like": "креветкообразная форма",
    "cephalopod": "головоногая форма",
    "snail_like": "улиткообразная форма",
    "elongated": "вытянутые пропорции",
    "broad": "широкие пропорции",
    "flattened": "уплощённые пропорции",
    "fusiform": "веретенообразные пропорции",
    "gray": "серый",
    "blue": "синий",
    "green": "зелёный",
    "brown": "бурый",
    "red": "красный",
    "orange": "оранжевый",
    "yellow": "жёлтый",
    "black": "чёрный",
    "white": "белый",
    "smooth_skin": "гладкая кожа",
    "scales": "чешуя",
    "rough_skin": "шероховатая кожа",
    "chitin": "хитиновый покров",
    "hard_shell": "твёрдая раковина",
    "leathery_skin": "кожистый покров",
    "soft_body": "мягкое тело",
    "standard": "обычный",
    "beak": "клюв",
    "suction": "присоска",
    "jawed": "челюстной рот",
    "pointed": "заострённая",
    "blunt": "тупая",
    "saw": "пилообразная",
    "hammer": "молоткообразная",
    "large": "крупный",
    "lateral": "боковые глаза",
    "stalked": "глаза на стебельках",
    "zero": "нет",
    "two": "две",
    "four": "четыре",
    "six": "шесть",
    "eight": "восемь",
    "none": "нет",
    "fin": "плавники",
    "flipper": "ласты",
    "walking_leg": "ходильные ноги",
    "claw": "клешни",
    "tentacle": "щупальца",
    "fish": "рыбный хвост",
    "crustacean": "ракообразная форма",
    "paddle": "лопатообразный хвост",
    "dorsal_fin": "спинной плавник",
    "shell": "раковина",
    "carapace": "панцирь",
    "ridge": "гребень",
}

DOMINANCE_LABELS = {
    "complete": "полное доминирование",
    "full": "полное доминирование",
    "dominant": "полное доминирование",
    "complete_dominance": "полное доминирование",
    "incomplete": "неполное доминирование",
    "incomplete_dominance": "неполное доминирование",
    "codominance": "кодоминирование",
    "codominant": "кодоминирование",
    "linked": "сцепленное наследование",
}

EVENT_LABELS = {
    "TASK_REWARD": "Награда за задание",
    "MUTATION_PURCHASE": "Покупка мутации",
    "MUTAGEN_PENALTY": "Риск мутагена",
    "MUTATION_EFFECT": "Эффект мутации",
    "RARE_TRAIT_BONUS": "Бонус редкого признака",
    "SYSTEM_ADJUSTMENT": "Корректировка результата",
    "HYBRIDIZATION_PENALTY": "Штраф за гибридизацию",
}

USER_TEXT_REPLACEMENTS = {
    "system adjustment": "Корректировка результата",
    "spiked shell": "шипастый панцирь",
    "light armor": "лёгкий панцирь",
    "sharp beak": "острый профиль",
}

EXPERIMENT_LABELS = {
    "CROSS": "Скрещивание",
    "MUTATION": "Мутация",
    "MUTAGEN": "Мутагент",
    "CROSSBREED_MUTAGEN": "Скрещивание + мутаген",
    "HYBRIDIZATION": "Гибридизация",
}

MUTAGEN_LABELS = {
    "RADIATION": "Облучение",
    "CHEMICAL": "Химический мутаген",
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

COLOR_VALUES = {
    "green": ("#83ad69", "#477a59"),
    "blue": ("#76a9bd", "#42768e"),
    "red": ("#cf7567", "#9e4c45"),
    "yellow": ("#e7c76b", "#b88735"),
    "purple": ("#aa82ae", "#7e5684"),
    "orange": ("#df9a5e", "#ae6639"),
    "white": ("#f4f1df", "#aaa78f"),
    "black": ("#48524a", "#222b26"),
    "brown": ("#a77b56", "#6f4f36"),
    "silver": ("#c7d0c9", "#77877f"),
}

SPECIES_CLASS_CODES = {
    "1": "cartilaginous-fish",
    "2": "bony-fish",
    "3": "crustacean",
    "4": "mollusk",
    "5": "turtle",
    "6": "mammal",
    "7": "hybrid",
    "cartilaginous_fish": "cartilaginous-fish",
    "bony_fish": "bony-fish",
    "crustacean": "crustacean",
    "mollusk": "mollusk",
    "turtle": "turtle",
    "mammal": "mammal",
}

TECH_SPECIES_PREFIXES = tuple(SPECIES_LABELS.keys())

MORPHOLOGY_GENE_CODES = (
    "body_shape",
    "body_proportion",
    "body_size",
    "body_cover",
    "body_color",
    "mouth_type",
    "snout_type",
    "eye_type",
    "front_appendage_count",
    "front_appendage_type",
    "front_appendage_size",
    "rear_appendage_count",
    "rear_appendage_type",
    "rear_appendage_size",
    "tail_type",
    "tail_size",
    "dorsal_type",
    "dorsal_size",
)


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




def number_label(value: Any) -> str:
    if value is None or value == "":
        return "0"
    try:
        number = float(value)
    except (TypeError, ValueError):
        return _text(value)
    if number.is_integer():
        return str(int(number))
    return f"{number:.2f}".rstrip("0").rstrip(".")


def signed_number_label(value: Any) -> str:
    if value is None or value == "":
        return "0"
    try:
        number = float(value)
    except (TypeError, ValueError):
        return _text(value)
    sign = "+" if number > 0 else ""
    return sign + number_label(number)


def date_label(value: Any) -> str:
    if not value:
        return ""
    if isinstance(value, datetime):
        return value.strftime("%d.%m.%Y %H:%M")
    if isinstance(value, date):
        return value.strftime("%d.%m.%Y")
    text = _text(value)
    for fmt in ("%Y-%m-%d %H:%M:%S.%f", "%Y-%m-%d %H:%M:%S", "%Y-%m-%dT%H:%M:%S.%f", "%Y-%m-%dT%H:%M:%S"):
        try:
            return datetime.strptime(text[:26], fmt).strftime("%d.%m.%Y %H:%M")
        except ValueError:
            continue
    return re.sub(r"\.\d{3,6}", "", text)


def translate_free_text(value: Any) -> str:
    text = _text(value)
    if not text:
        return ""
    replacements: dict[str, str] = {}
    # Для числовых идентификаторов вида нужна граница поля: замена голых цифр
    # исказит обычные значения вроде 123.45 или 60 в свободном тексте истории.
    replacements.update({code: label for code, label in SPECIES_LABELS.items() if not code.isdigit()})
    replacements.update(TRAIT_LABELS)
    replacements.update(EVENT_LABELS)
    replacements.update(USER_TEXT_REPLACEMENTS)
    for raw, label in sorted(replacements.items(), key=lambda item: len(item[0]), reverse=True):
        if raw:
            text = re.sub(re.escape(raw), label, text, flags=re.IGNORECASE)

    def replace_numeric_species(match: re.Match[str]) -> str:
        return f"{match.group(1)}{SPECIES_LABELS[match.group(2)]}"

    text = re.sub(
        r"\b(species(?:_type)?\s*[=:]\s*)([1-7])\b",
        replace_numeric_species,
        text,
        flags=re.IGNORECASE,
    )
    return text.replace("_", " ")


def stats_view(row: dict[str, Any]) -> dict[str, Any]:
    return {
        **row,
        "wallet_label": number_label(row.get("wallet")),
        "rating_label": number_label(row.get("rating")),
    }


def count_mutation_purchases(rows: list[dict[str, Any]]) -> int:
    return sum(1 for row in rows if _text(row.get("event_type") or row.get("event_code")).upper() == "MUTATION_PURCHASE")


def _base_trait_label(value: Any) -> str:
    code = _clean_code(value)
    return TRAIT_LABELS.get(code) or GENE_LABELS.get(code) or SPECIES_LABELS.get(code) or DOMINANCE_LABELS.get(code) or _title_fallback(code)


def _size_blend_label(codes: list[str], detailed: bool = False) -> str | None:
    normalized = tuple(sorted(code.replace("_size", "") for code in codes))
    short_labels = {
        ("compact", "medium"): "компактно-средний",
        ("large", "medium"): "средне-крупный",
        ("compact", "large"): "переменный",
    }
    detailed_labels = {
        ("compact", "medium"): "промежуточный между компактным и средним",
        ("large", "medium"): "промежуточный между средним и крупным",
        ("compact", "large"): "промежуточный между компактным и крупным",
    }
    return (detailed_labels if detailed else short_labels).get(normalized)


def _color_blend_label(codes: list[str]) -> str | None:
    roots = [code.replace("_color", "") for code in codes]
    if len(roots) != 2:
        return None
    prefixes = {
        "red": "красно",
        "blue": "сине",
        "green": "зелёно",
        "yellow": "жёлто",
        "purple": "фиолетово",
        "white": "бело",
        "orange": "оранжево",
        "black": "чёрно",
    }
    finals = {
        "red": "красный",
        "blue": "синий",
        "green": "зелёный",
        "yellow": "жёлтый",
        "purple": "фиолетовый",
        "white": "белый",
        "orange": "оранжевый",
        "black": "чёрный",
    }
    if roots[0] in prefixes and roots[1] in finals:
        return f"{prefixes[roots[0]]}-{finals[roots[1]]}"
    return None


def _blend_label(raw: Any, fallback: str) -> str:
    parts = [_clean_code(part) for part in _text(raw).split("/") if part.strip()]
    if not parts:
        return fallback
    if {"herbivore", "carnivore"}.issubset(set(parts)):
        return "смешанное"
    if all("color" in part for part in parts):
        return _color_blend_label(parts) or "двухцветный"
    if all(part in {"compact", "medium", "large", "compact_size", "medium_size", "large_size"} for part in parts):
        return _size_blend_label(parts) or "промежуточный"
    return fallback


def _intermediate_label(raw: Any, detailed: bool = False) -> str:
    inner = _text(raw)
    inner = inner[inner.find("(") + 1 : inner.rfind(")")]
    parts = [_clean_code(part) for part in inner.split("/") if part.strip()]
    if not parts:
        return "промежуточный"
    if all(part in {"compact", "medium", "large", "compact_size", "medium_size", "large_size"} for part in parts):
        return _size_blend_label(parts, detailed=detailed) or "промежуточный размер"
    if all("color" in part for part in parts):
        return _color_blend_label(parts) or "двухцветный"
    return "промежуточный признак"


def allele_label(value: Any) -> str:
    raw = _text(value)
    try:
        return number_label(float(raw))
    except (TypeError, ValueError):
        return trait_label(value)


def trait_detail_label(value: Any) -> str:
    raw = _text(value)
    code = _clean_code(raw)
    if code.startswith("intermediate(") and code.endswith(")"):
        return _intermediate_label(raw, detailed=True)
    return humanize_code(value)


def humanize_code(value: Any) -> str:
    raw = _text(value)
    code = _clean_code(raw)
    if not code:
        return "не указано"
    if code.startswith("intermediate(") and code.endswith(")"):
        return _intermediate_label(raw)
    if "/" in code:
        return _blend_label(raw, "смешанный признак")
    if code in TRAIT_LABELS:
        return TRAIT_LABELS[code]
    if code in GENE_LABELS:
        return GENE_LABELS[code]
    if code in SPECIES_LABELS and not code.isdigit():
        return SPECIES_LABELS[code]
    if code in DOMINANCE_LABELS:
        return DOMINANCE_LABELS[code]
    if code.upper() in EVENT_LABELS:
        return EVENT_LABELS[code.upper()]
    return _title_fallback(code)


def species_label(row: dict[str, Any]) -> str:
    code = _clean_code(row.get("species_type") or row.get("species_code"))
    display = _strip_mojibake(_text(row.get("species_display_name") or row.get("species_label")))
    if display:
        return display
    if code in SPECIES_LABELS:
        return SPECIES_LABELS[code]
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
    mutagen_name = re.match(r"^(.+?)_mutagen_[0-9a-f]+$", name, flags=re.IGNORECASE)
    if mutagen_name:
        base_name = mutagen_name.group(1).rstrip(" _-")
        return f"{base_name} — мутант" if base_name else "Мутант"
    lower = name.lower()
    if name and not any(lower.startswith(prefix) for prefix in TECH_SPECIES_PREFIXES):
        return name
    return f"{species_label(row)} #{_creature_number(row)}"


def default_mutagen_result_name(row: dict[str, Any]) -> str:
    """Use a player-facing source name; the package keeps the internal identifier."""
    name = _text(row.get("display_name")) or creature_name(row)
    return f"{name} — мутант"


def trait_label(value: Any) -> str:
    return humanize_code(value)


def morphology_trait_label(gene_code: Any, value: Any) -> str:
    """Make absence grammatical without altering Oracle's technical allele values."""
    gene = _clean_code(gene_code)
    code = _clean_code(value)
    if gene in {"front_appendage_count", "rear_appendage_count"} and code == "zero":
        return "отсутствуют"
    if gene in {"front_appendage_type", "rear_appendage_type"} and code == "none":
        return "отсутствуют"
    if gene in {"front_appendage_size", "rear_appendage_size", "tail_size", "dorsal_size"} and code == "none":
        return "не применимо"
    if gene in {"tail_type", "dorsal_type"} and code == "none":
        return "отсутствует"
    return trait_label(value)


def gene_label(value: Any) -> str:
    code = _clean_code(value)
    return GENE_LABELS.get(code, humanize_code(code))


def dominance_label(value: Any) -> str:
    code = _clean_code(value).replace(" ", "_").replace("-", "_")
    if not code:
        return "тип наследования не указан"
    return DOMINANCE_LABELS.get(code, "особый тип наследования")


def _color_key(value: Any) -> str:
    code = _clean_code(value)
    for key in COLOR_CLASSES:
        if key in code:
            return key
    return "green"


def color_class(value: Any) -> str:
    return COLOR_CLASSES.get(_color_key(value), "tone-green")


def _color_visual(raw: Any) -> dict[str, str]:
    code = _clean_code(raw)
    keys = [key for key in COLOR_CLASSES if key in code]
    if not keys:
        keys = ["green"]
    primary = keys[0]
    result = {
        "tone_class": COLOR_CLASSES[primary],
        "tone_mode_class": "tone-solid",
        "tone_style": "",
    }
    if len(keys) > 1:
        secondary = keys[1]
        primary_tone, primary_accent = COLOR_VALUES[primary]
        secondary_tone, secondary_accent = COLOR_VALUES[secondary]
        result["tone_mode_class"] = "tone-mixed"
        result["tone_style"] = (
            f"--creature-tone:{primary_tone};--creature-accent:{primary_accent};"
            f"--creature-tone-secondary:{secondary_tone};--creature-accent-secondary:{secondary_accent};"
        )
    return result


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
        items.append({"key": key, "label": gene_label(key), "value": trait_label(value), "detail_value": trait_detail_label(value), "raw": value, "class": color_class(value) if "color" in key.lower() else "tone-neutral"})
    return items


def phenotype_items(row: dict[str, Any]) -> list[dict[str, str]]:
    items = parse_phenotype(row.get("phenotype_summary"))
    seen = {_clean_code(item["key"]) for item in items}
    explicit = [("color", row.get("phenotype_color")), ("size", row.get("phenotype_size")), ("has_wings", row.get("phenotype_has_wings")), ("nutrition_type", row.get("phenotype_nutrition_type"))]
    for key, value in explicit:
        if value and key not in seen:
            items.append({"key": key, "label": gene_label(key), "value": trait_label(value), "detail_value": trait_detail_label(value), "raw": _text(value), "class": color_class(value) if key == "color" else "tone-neutral"})
    return items


def _item_by_key(items: list[dict[str, str]], key: str) -> dict[str, str] | None:
    clean_key = _clean_code(key)
    for item in items:
        if _clean_code(item.get("key")) == clean_key:
            return item
    return None


def _item_with_keys(items: list[dict[str, str]], keys: tuple[str, ...]) -> dict[str, str] | None:
    clean_keys = {_clean_code(key) for key in keys}
    for item in items:
        if _clean_code(item.get("key")) in clean_keys:
            return item
    return None


def phenotype_sentence(row: dict[str, Any]) -> str:
    items = phenotype_items(row)
    if not items:
        return "Фенотип пока не описан."
    preferred = ["color", "has_wings", "nutrition_type", "size"]
    selected: list[dict[str, str]] = []
    seen: set[str] = set()
    for key in preferred:
        item = _item_by_key(items, key)
        if item:
            selected.append(item)
            seen.add(_clean_code(item.get("key")))
    for item in items:
        key = _clean_code(item.get("key"))
        if key not in seen:
            selected.append(item)
            break
    parts: list[str] = []
    for item in selected[:5]:
        key = _clean_code(item.get("key"))
        value = item.get("value", "")
        if key == "color":
            parts.append(f"{value.capitalize()} окрас")
        elif key == "has_wings":
            parts.append(value)
        elif key == "nutrition_type":
            parts.append(f"{value} питание")
        elif key == "size":
            parts.append(f"{value} размер")
        else:
            parts.append(value)
    return " · ".join(parts)


def _class_from_raw(raw: Any, prefix: str, variants: tuple[str, ...], default: str) -> str:
    code = _clean_code(raw)
    for variant in variants:
        if variant in code:
            return f"{prefix}-{variant.replace('_', '-')}"
    return f"{prefix}-{default}"


def _nutrition_class(raw: Any) -> str:
    code = _clean_code(raw)
    has_herbivore = "herbivore" in code
    has_carnivore = "carnivore" in code or "predator" in code
    if has_herbivore and has_carnivore:
        return "nutrition-mixed"
    if has_carnivore:
        return "nutrition-carnivore"
    if has_herbivore:
        return "nutrition-herbivore"
    return "nutrition-neutral"


def _size_class(raw: Any) -> str:
    code = _clean_code(raw)
    if "intermediate" in code or "/" in code:
        has_compact = "compact" in code or "small" in code
        has_medium = "medium" in code
        has_large = "large" in code or "giant" in code
        if has_compact and has_medium and not has_large:
            return "size-intermediate-compact-medium"
        if has_medium and has_large and not has_compact:
            return "size-intermediate-medium-large"
        if has_compact and has_large:
            return "size-intermediate-wide"
        return "size-intermediate"
    return _class_from_raw(code, "size", ("compact", "small", "medium", "large", "giant"), "medium")


def _feature_classes(items: list[dict[str, str]]) -> str:
    variants = (
        "crescent_fin", "broad_fin", "pointed_fin", "ribbon_fin", "forked_fin", "rounded_fin",
        "long_claws", "hooked_claws", "short_claws",
        "thick_armor", "light_armor", "ridged_armor", "smooth_shell", "plated_shell", "spiked_shell",
        "spiral_profile", "rounded_nose", "sharp_beak",
        "fast_speed", "slow_speed", "short_fur", "soft_fur", "dense_fur",
    )
    classes: list[str] = []
    feature_keys = {"fin_shape", "claw_form", "shell_armor", "beak_nose_shape", "speed_level", "fur_density"}
    for item in items:
        if _clean_code(item.get("key")) not in feature_keys:
            continue
        raw = _clean_code(item.get("raw"))
        for variant in variants:
            class_name = "feature-" + variant.replace("_", "-")
            if variant in raw and class_name not in classes:
                classes.append(class_name)
    return " ".join(classes) if classes else "feature-neutral"


def creature_visual(row: dict[str, Any]) -> dict[str, str]:
    species = _clean_code(row.get("species_type") or row.get("species_code") or row.get("species_label"))
    species_code = SPECIES_CLASS_CODES.get(species, species.replace("_", "-") if species else "default")
    items = phenotype_items(row)
    color_item = _item_by_key(items, "color")
    size_item = _item_by_key(items, "size")
    wings_item = _item_by_key(items, "has_wings")
    nutrition_item = _item_by_key(items, "nutrition_type")
    color = color_item.get("raw") if color_item else row.get("phenotype_color") or row.get("phenotype_summary")
    color_visual = _color_visual(color)
    wings_raw = _clean_code((wings_item or {}).get("raw") or row.get("phenotype_has_wings") or row.get("phenotype_summary"))
    wings = "has-wings" if "wing" in wings_raw and "no_wings" not in wings_raw else "no-wings"
    size_class = _size_class((size_item or {}).get("raw") or row.get("phenotype_size") or row.get("phenotype_summary"))
    nutrition_class = _nutrition_class((nutrition_item or {}).get("raw") or row.get("phenotype_nutrition_type") or row.get("phenotype_summary"))
    return {
        "species_class": "species-" + species_code,
        "tone_class": color_visual["tone_class"],
        "tone_mode_class": color_visual["tone_mode_class"],
        "tone_style": color_visual["tone_style"],
        "wings_class": wings,
        "size_class": size_class,
        "nutrition_class": nutrition_class,
        "feature_classes": _feature_classes(items),
    }


def creature_genetics_version(row: dict[str, Any]) -> int:
    """Return the package-provided laboratory model version; old cursors stay v1."""
    try:
        return 3 if int(row.get("genetics_version")) == 3 else 1
    except (TypeError, ValueError):
        return 1


def morphology_traits(rows: list[dict[str, Any]]) -> list[dict[str, str]]:
    """Keep Oracle's expressed morphology values keyed by stable gene_code."""
    by_code = {
        _clean_code(row.get("gene_code")): row
        for row in rows
        if _clean_code(row.get("gene_code")) in MORPHOLOGY_GENE_CODES
    }
    traits: list[dict[str, str]] = []
    for gene_code in MORPHOLOGY_GENE_CODES:
        row = by_code.get(gene_code)
        if row is None:
            continue
        technical_value = _text(row.get("expressed_allele_code"))
        display_value = _text(row.get("expressed_display_name")) or technical_value
        if _clean_code(technical_value) in {"zero", "none"}:
            display_value = morphology_trait_label(gene_code, technical_value)
        label = _text(row.get("gene_display_name")) or gene_label(gene_code)
        traits.append({
            "key": gene_code,
            "label": label,
            "value": display_value,
            "detail_value": display_value,
            "raw": technical_value,
            "technical_value": technical_value,
            "class": color_class(technical_value) if gene_code == "body_color" else "tone-neutral",
        })
    return traits


def normalize_morphology_visual_state(traits: list[dict[str, str]]) -> dict[str, str]:
    """Prepare renderer-friendly states without changing the Oracle morphology rows."""
    visual_state = {
        _clean_code(trait.get("key")): _clean_code(trait.get("technical_value"))
        for trait in traits
    }
    for count_code, dependent_codes in (
        ("front_appendage_count", ("front_appendage_type", "front_appendage_size")),
        ("rear_appendage_count", ("rear_appendage_type", "rear_appendage_size")),
    ):
        if visual_state.get(count_code) == "zero":
            for dependent_code in dependent_codes:
                visual_state[dependent_code] = "none"
    if visual_state.get("tail_type") == "none":
        visual_state["tail_size"] = "none"
    if visual_state.get("dorsal_type") == "none":
        visual_state["dorsal_size"] = "none"
    return visual_state


def _archetype_view(row: dict[str, Any]) -> dict[str, Any] | None:
    archetype_id = row.get("archetype_id")
    if archetype_id is None:
        return None
    return {
        "archetype_id": archetype_id,
        "code": _text(row.get("archetype_code")),
        "display_name": _text(row.get("archetype_display_name")) or _text(row.get("archetype_code")),
    }


def build_creature_view(
    row: dict[str, Any],
    morphology_rows: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    """Build one display model selected exclusively by LABS.GENETICS_VERSION."""
    view = dict(row)
    view["display_name"] = creature_name(row)
    view["species_label"] = species_label(row)
    view["can_crossbreed"] = _clean_code(row.get("species_type")) not in {"7", "hybrid"}
    genetics_version = creature_genetics_version(row)
    view["genetics_version"] = genetics_version
    view["archetype"] = _archetype_view(row)
    if genetics_version == 3:
        traits = morphology_traits(morphology_rows or [])
        phenotype_results = list(traits)
        nutrition_value = row.get("phenotype_nutrition_type")
        if nutrition_value:
            nutrition_parts = {
                _clean_code(part)
                for part in _text(nutrition_value).split("/")
                if part.strip()
            }
            nutrition_detail = (
                "смешанное питание: хищное и травоядное"
                if {"herbivore", "carnivore"}.issubset(nutrition_parts)
                else trait_detail_label(nutrition_value)
            )
            nutrition_trait = {
                "key": "nutrition_type",
                "label": gene_label("nutrition_type"),
                "value": trait_label(nutrition_value),
                "detail_value": nutrition_detail,
                "raw": _text(nutrition_value),
                "class": "tone-neutral",
            }
            phenotype_results.append(nutrition_trait)
            display_traits = [*traits, nutrition_trait]
        else:
            display_traits = traits
        view["display_model"] = "morphology"
        view["morphology_traits"] = display_traits
        view["morphology"] = {trait["key"]: trait for trait in traits}
        view["morphology_visual_state"] = normalize_morphology_visual_state(traits)
        view["phenotype_items"] = phenotype_results
        summary_traits = [
            view["morphology"].get(code)
            for code in ("body_shape", "body_color", "body_size")
            if view["morphology"].get(code)
        ]
        view["phenotype_text"] = " · ".join(item["value"] for item in summary_traits) or "Морфология доступна в карточке существа."
    else:
        view["display_model"] = "legacy"
        view["morphology_traits"] = []
        view["morphology"] = {}
        view["morphology_visual_state"] = {}
        view["phenotype_items"] = phenotype_items(row)
        view["phenotype_text"] = phenotype_sentence(row)
    view["visual"] = creature_visual(row)
    return view


def creature_view(
    row: dict[str, Any],
    morphology_rows: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    return build_creature_view(row, morphology_rows)


def morphology_rows_by_creature(rows: list[dict[str, Any]]) -> dict[int, list[dict[str, Any]]]:
    grouped: dict[int, list[dict[str, Any]]] = {}
    for row in rows:
        try:
            creature_id = int(row.get("creature_id"))
        except (TypeError, ValueError):
            continue
        grouped.setdefault(creature_id, []).append(row)
    return grouped


def creature_views(
    rows: list[dict[str, Any]],
    morphology_by_creature: dict[int, list[dict[str, Any]]] | None = None,
) -> list[dict[str, Any]]:
    morphology_by_creature = morphology_by_creature or {}
    return [
        creature_view(row, morphology_by_creature.get(int(row["creature_id"]), []))
        for row in rows
    ]


def parent_creature_view(
    row: dict[str, Any],
    morphology_rows: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    """Compact, display-only card data for the parent comparison on crossbreed."""
    view = creature_view(row, morphology_rows)
    if view["display_model"] == "morphology":
        traits = [
            view["morphology"].get(key)
            for key in (
                "body_shape", "body_color", "body_size", "body_cover",
                "tail_type", "dorsal_type", "nutrition_type",
            )
            if view["morphology"].get(key)
        ]
        view["parent_traits"] = [
            {
                **trait,
                "label": gene_label(trait["key"]),
                "value": morphology_trait_label(
                    trait["key"],
                    trait.get("technical_value") or trait.get("raw") or trait["value"],
                ),
            }
            for trait in traits
        ]
        return view
    core_keys = ("color", "has_wings", "nutrition_type", "size")
    special_keys = ("fin_shape", "claw_form", "shell_armor", "beak_nose_shape", "speed_level", "fur_density")
    items = view["phenotype_items"]
    traits = [item for key in core_keys if (item := _item_by_key(items, key))]
    special = _item_with_keys(items, special_keys)
    if special:
        traits.append(special)
    view["parent_traits"] = traits[:5]
    return view


def parent_creature_views(
    rows: list[dict[str, Any]],
    morphology_by_creature: dict[int, list[dict[str, Any]]] | None = None,
) -> list[dict[str, Any]]:
    morphology_by_creature = morphology_by_creature or {}
    return [
        parent_creature_view(row, morphology_by_creature.get(int(row["creature_id"]), []))
        for row in rows
    ]


def _genotype_gene_key(row: dict[str, Any]) -> str:
    gene_id = row.get("gene_id")
    if gene_id is not None:
        return f"id:{gene_id}"
    return _clean_code(row.get("gene_name") or row.get("gene_type"))


def _allele_identity(row: dict[str, Any], slot: int) -> tuple[str, str]:
    for suffix in ("id", "trait_value", "display_name", "description"):
        value = row.get(f"allele{slot}_{suffix}")
        if value is not None:
            return suffix, _text(value)
    return "missing", ""


def genotype_change_slots(
    before_rows: list[dict[str, Any]],
    after_rows: list[dict[str, Any]],
) -> dict[str, list[str]]:
    """Compare package cursor rows and return only actually changed allele slots."""
    before = {_genotype_gene_key(row): row for row in before_rows}
    changes: dict[str, list[str]] = {}
    for after_row in after_rows:
        previous = before.get(_genotype_gene_key(after_row))
        if previous is None:
            continue
        slots = [
            f"allele{slot}"
            for slot in (1, 2)
            if _allele_identity(previous, slot) != _allele_identity(after_row, slot)
        ]
        gene_code = _clean_code(after_row.get("gene_name") or after_row.get("gene_type"))
        if slots and gene_code:
            changes[gene_code] = slots
    return changes


def genotype_change_details(
    before_rows: list[dict[str, Any]],
    after_rows: list[dict[str, Any]],
) -> list[dict[str, str]]:
    """Describe package-observed allele changes without inferring inheritance."""
    before = {_genotype_gene_key(row): row for row in before_rows}
    details: list[dict[str, str]] = []
    for after_row in after_rows:
        previous = before.get(_genotype_gene_key(after_row))
        if previous is None:
            continue
        gene = after_row.get("gene_display_name") or after_row.get("gene_name") or after_row.get("gene_type")
        for slot in (1, 2):
            if _allele_identity(previous, slot) == _allele_identity(after_row, slot):
                continue
            before_value = previous.get(f"allele{slot}_display_name") or previous.get(f"allele{slot}_description")
            after_value = after_row.get(f"allele{slot}_display_name") or after_row.get(f"allele{slot}_description")
            details.append({
                "gene_label": gene_label(gene),
                "slot_label": f"Аллель {slot}",
                "before": trait_label(before_value) if before_value else "не указан",
                "after": trait_label(after_value) if after_value else "не указан",
            })
    return details


def genotype_view(
    rows: list[dict[str, Any]],
    phenotype: list[dict[str, str]] | None = None,
    changed_slots: dict[str, list[str]] | None = None,
) -> list[dict[str, Any]]:
    phenotype_by_gene = {
        _clean_code(item.get("key")): item
        for item in (phenotype or [])
    }
    formatted = []
    changed_slots = changed_slots or {}
    for row in rows:
        gene = row.get("gene_name") or row.get("gene_type") or row.get("gene_display_name")
        dominance = row.get("dominance_type") or row.get("dominance_display_name")
        gene_code = _clean_code(gene)
        allele1_name = row.get("allele1_display_name") or row.get("allele1_description")
        allele2_name = row.get("allele2_display_name") or row.get("allele2_description")
        allele1_semantic = morphology_trait_label(gene_code, allele1_name) if allele1_name else "не указана"
        allele2_semantic = morphology_trait_label(gene_code, allele2_name) if allele2_name else "не указана"
        result_item = phenotype_by_gene.get(gene_code)
        result_label = result_item.get("detail_value") if result_item else "не указан"
        inheritance = dominance_label(dominance)
        row_changed_slots = changed_slots.get(gene_code, [])
        formatted.append({
            **row,
            "gene_label": _text(row.get("gene_display_name")) or gene_label(gene),
            "gene_code": gene_code,
            "allele1_label": allele1_semantic,
            "allele2_label": allele2_semantic,
            "allele1_semantic_label": allele1_semantic,
            "allele2_semantic_label": allele2_semantic,
            "dominance_label": inheritance,
            "inheritance_label": inheritance,
            "result_label": result_label,
            "pair_label": f"Аллели: {allele1_semantic} / {allele2_semantic}",
            "allele1_changed": "allele1" in row_changed_slots,
            "allele2_changed": "allele2" in row_changed_slots,
            "gene_changed": bool(row_changed_slots),
        })
    return formatted


def preview_morphology_rows(row: dict[str, Any]) -> list[dict[str, str]]:
    """Adapt package preview fields to the existing v3 morphology read model."""
    result: list[dict[str, str]] = []
    for item in parse_phenotype(row.get("phenotype_summary")):
        gene_code = _clean_code(item.get("key"))
        if gene_code not in MORPHOLOGY_GENE_CODES:
            continue
        raw_value = _text(item.get("raw"))
        result.append({
            "gene_code": gene_code,
            "gene_display_name": gene_label(gene_code),
            "expressed_allele_code": raw_value,
            "expressed_display_name": trait_label(raw_value),
        })
    return result


def preview_view(row: dict[str, Any], genetics_version: int = 1) -> dict[str, Any]:
    preview_row = dict(row)
    morphology_rows: list[dict[str, str]] = []
    if genetics_version == 3:
        preview_row["genetics_version"] = 3
        morphology_rows = preview_morphology_rows(row)
        nutrition = _item_by_key(parse_phenotype(row.get("phenotype_summary")), "nutrition_type")
        if nutrition:
            preview_row["phenotype_nutrition_type"] = nutrition.get("raw")
    view = creature_view(preview_row, morphology_rows)
    view.pop("probability", None)
    view["option_no"] = row.get("option_no")
    view["genotype_summary"] = _text(row.get("genotype_summary"))
    view["source_note"] = "Пример возможного потомства"
    view["display_name"] = f"Вариант {row.get('option_no')}"
    return view


def preview_views(rows: list[dict[str, Any]], genetics_version: int = 1) -> list[dict[str, Any]]:
    return [preview_view(row, genetics_version) for row in rows]


def task_view(row: dict[str, Any]) -> dict[str, Any]:
    status = _text(row.get("task_status")).upper()
    code = _clean_code(row.get("task_name") or row.get("task_code") or row.get("title"))
    genetics_version = creature_genetics_version(row)
    difficulty = row.get("difficulty_display_name") or row.get("difficulty_code") or row.get("difficulty")
    supplied_name = _strip_mojibake(_text(row.get("task_display_name")))
    supplied_code = _clean_code(supplied_name)
    is_internal_name = supplied_code.startswith("task_")
    name = supplied_name if supplied_name and not is_internal_name else "Специальное задание"
    unknown_task_code = code if code.startswith("task_") and is_internal_name else None
    description = _text(row.get("description") or row.get("task_description") or row.get("goal_description"))
    if not description:
        description = f"Цель задания: получить организм «{name.lower()}»."
    money_reward = row.get("money_reward") or row.get("reward_money") or 0
    rating_reward = row.get("rating_reward") or row.get("reward_rating") or 0
    requirement_label = "Проявляющийся признак" if genetics_version == 3 else "Условие задания" if unknown_task_code else "Генетическое условие"
    return {**row, "display_name": name, "unknown_task_code": unknown_task_code, "description_text": description, "requirement_label": requirement_label, "status_label": "Выполнен" if status == "COMPLETED" else "Активен" if status == "ACTIVE" else humanize_code(status), "status_class": "status-completed" if status == "COMPLETED" else "status-active" if status == "ACTIVE" else "status-neutral", "difficulty_label": humanize_code(difficulty), "money_reward_label": number_label(money_reward), "rating_reward_label": number_label(rating_reward), "genetics_version": genetics_version}


def task_views(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [task_view(row) for row in rows]


def _mutation_label(value: Any) -> str:
    text = _text(value)
    code = _clean_code(text)
    if not text or code.startswith("mutation_") or code.endswith("_mutation"):
        return "Мутация"
    return text


def mutation_view(row: dict[str, Any]) -> dict[str, Any]:
    name = row.get("mutation_display_name") or row.get("display_name") or row.get("mutation_name") or row.get("mutation_code")
    target = row.get("target_trait") or row.get("trait_value") or row.get("gene_type") or row.get("gene_name")
    rating_effect = None
    for key in ("rating_effect", "rating_delta", "rating_change", "rating_reward"):
        if row.get(key) is not None:
            rating_effect = row.get(key)
            break
    return {
        **row,
        "display_name": _mutation_label(name),
        "target_label": trait_label(target),
        "description_text": translate_free_text(row.get("description")) or "Точечное изменение выбранного признака.",
        "cost_label": number_label(row.get("cost") or row.get("price") or 0),
        "rating_effect_label": signed_number_label(rating_effect) if rating_effect is not None else "не указано",
    }


def mutation_views(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [mutation_view(row) for row in rows]


def mutation_target_view(row: dict[str, Any]) -> dict[str, Any]:
    gene = row.get("gene_type_display_name") or row.get("gene_type") or row.get("gene_name")
    allele = row.get("target_allele_display_name") or row.get("target_allele_description") or row.get("trait_value")
    species = species_label(row)
    return {
        **row,
        "gene_label": gene_label(gene),
        "allele_label": trait_label(allele),
        "species_label": species,
    }


def mutation_target_views(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [mutation_target_view(row) for row in rows]


def purchased_mutation_views(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    purchases = []
    for event in events:
        kind = _text(event.get("event_type") or event.get("event_code")).upper()
        if kind != "MUTATION_PURCHASE":
            continue
        view = rating_event_view(event)
        purchases.append({
            **view,
            "display_name": translate_free_text(view.get("description_text")).replace("Покупка мутации:", "").strip() or "Покупка мутации",
        })
    return purchases


def experiment_view(row: dict[str, Any]) -> dict[str, Any]:
    kind = _text(row.get("experiment_type") or row.get("experiment_type_code")).upper()
    mutagen_type = _text(row.get("mutagen_type")).upper()
    mutagen_label = MUTAGEN_LABELS.get(mutagen_type, "")
    description = translate_free_text(row.get("description") or row.get("result_description"))
    if not description:
        descriptions = {
            "CROSS": "Получен новый потомок в результате скрещивания.",
            "MUTATION": "К существу применена направленная мутация.",
            "MUTAGEN": f"Копия существа изменена воздействием: {mutagen_label or 'мутаген'}.",
            "CROSSBREED_MUTAGEN": f"Получен потомок после скрещивания и воздействия: {mutagen_label or 'мутаген'}.",
            "HYBRIDIZATION": "Проведена контролируемая гибридизация с облучением. Рейтинг не может стать ниже нуля.",
        }
        description = descriptions.get(kind, "Событие лабораторной линии.")
    result_creature_id = row.get("result_creature_id")
    if result_creature_id is None:
        result_creature_id = row.get("offspring_id")
    return {
        **row,
        "result_creature_id": result_creature_id,
        "type_label": _text(row.get("experiment_type_display_name")) or EXPERIMENT_LABELS.get(kind, humanize_code(kind)),
        "type_class": f"event-{kind.lower()}" if kind else "event-neutral",
        "mutagen_label": mutagen_label,
        "description_text": description,
        "created_at_label": date_label(row.get("created_at") or row.get("experiment_date")),
    }


def experiment_views(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [experiment_view(row) for row in rows]


def rating_event_view(row: dict[str, Any]) -> dict[str, Any]:
    kind = _text(row.get("event_type") or row.get("event_code")).upper()
    rating_delta = row.get("rating_delta")
    wallet_delta = row.get("wallet_delta")
    return {
        **row,
        "type_label": _text(row.get("event_type_display_name")) or EVENT_LABELS.get(kind, humanize_code(kind)),
        "event_class": f"event-{kind.lower()}" if kind else "event-neutral",
        "rating_class": _delta_class(rating_delta),
        "wallet_class": _delta_class(wallet_delta),
        "rating_delta_label": signed_number_label(rating_delta),
        "wallet_delta_label": signed_number_label(wallet_delta),
        "created_at_label": date_label(row.get("created_at") or row.get("event_time")),
        "description_text": translate_free_text(row.get("description")) or "Записанное событие лаборатории.",
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

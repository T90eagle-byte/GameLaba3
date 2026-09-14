"""Deterministic SVG portrait renderer for the universal morphology model.

The renderer deliberately consumes only ``morphology_visual_state`` produced
from Oracle's canonical morphology cursor.  It does not infer traits from an
archetype, legacy phenotype fields, nutrition, or wings.
"""
from __future__ import annotations

from html import escape
import re
from typing import Any

from markupsafe import Markup


VIEW_BOX = "0 0 300 180"
_UID_RE = re.compile(r"[^A-Za-z0-9_-]+")
_SIZES = {"", "mini", "large"}

_PALETTES = {
    "gray": ("#87949a", "#53646b"), "blue": ("#5d93b5", "#346d8d"),
    "green": ("#6d9c78", "#3f7353"), "brown": ("#9a785d", "#674a37"),
    "red": ("#c96862", "#93413f"), "orange": ("#d99055", "#a95f35"),
    "yellow": ("#d7ba58", "#9b7c2d"), "black": ("#566068", "#252d32"),
    "white": ("#f3f0e4", "#a8aaa0"),
}
_BODY_PATHS = {
    "streamlined": "M65 91 C95 51 194 52 232 87 C199 119 104 128 65 91Z",
    "shark_like": "M55 94 C93 50 194 46 239 83 L222 101 C177 124 96 126 55 94Z",
    "disc": "M67 91 C89 48 204 45 234 89 C204 134 91 134 67 91Z",
    "eel_like": "M48 94 C86 63 174 63 247 90 C187 120 89 123 48 94Z",
    "cetacean": "M66 91 C97 54 195 55 231 88 C203 124 98 126 66 91Z",
    "pinniped": "M69 97 C100 64 191 63 226 91 C195 123 103 129 69 97Z",
    "crustacean": "M80 91 C98 52 194 53 219 91 C196 126 101 126 80 91Z",
    "shrimp_like": "M57 97 C100 57 191 60 238 87 C199 128 101 132 57 97Z",
    "cephalopod": "M88 77 C119 42 190 52 210 84 C193 117 110 121 88 77Z",
    "snail_like": "M75 95 C91 53 177 49 216 90 C186 128 105 130 75 95Z",
}
_PROPORTIONS = {
    "elongated": "translate(-10 0) scale(1.14 .88)",
    "compact": "translate(16 4) scale(.82 1.12)",
    "broad": "translate(-8 0) scale(1.10 1.03)",
    "flattened": "translate(0 10) scale(1.04 .72)",
    "fusiform": "translate(0 0) scale(1 .98)",
}
_SCALE = {"small": ".72", "medium": ".9", "large": "1.06", "giant": "1.19"}
_APPENDAGE_SCALES = {"none": "0", "small": ".72", "medium": "1", "large": "1.28"}
_COUNT = {"zero": 0, "two": 2, "four": 4, "six": 6, "eight": 8}


def _code(value: Any, fallback: str = "unknown") -> str:
    text = str(value or "").strip().lower()
    return text if re.fullmatch(r"[a-z0-9_]+", text or "") else fallback


def _uid(value: Any) -> str:
    cleaned = _UID_RE.sub("-", str(value or "portrait")).strip("-")
    return cleaned or "portrait"


def _attrs(**values: str) -> str:
    return " ".join(
        f'data-{key.replace("_", "-")}="{escape(value, quote=True)}"'
        for key, value in values.items()
    )


def _part_group(part: str, count: str, kind: str, size: str, front: bool) -> str:
    amount = _COUNT.get(count, 0)
    if not amount or kind == "none":
        return f'<g class="morph-appendages morph-{part}-appendages" {_attrs(part=part, count=count, appendage_type="none", appendage_size="none")}/>'
    direction = 1 if front else -1
    x = 195 if front else 104
    y_values = [62, 78, 104, 120, 70, 112, 88, 96][:amount]
    elements: list[str] = []
    for index, y in enumerate(y_values, 1):
        offset = (index % 2) * 6
        if kind == "fin":
            shape = f'<path d="M{x} {y} l{direction * 29} {-17 + offset} l{direction * 12} 27 Z"/>'
        elif kind == "flipper":
            shape = f'<ellipse cx="{x + direction * 20}" cy="{y}" rx="23" ry="10" transform="rotate({direction * 25} {x + direction * 20} {y})"/>'
        elif kind == "walking_leg":
            shape = f'<path d="M{x} {y} q{direction * 20} 14 {direction * 33} 31"/>'
        elif kind == "claw":
            shape = f'<path d="M{x} {y} q{direction * 23} -20 {direction * 38} 1 q{direction * -16} 16 {direction * -30} 7"/>'
        elif kind == "tentacle":
            shape = f'<path d="M{x} {y} q{direction * 20} 17 {direction * 30} 1 q{direction * 11} -17 {direction * 25} -2"/>'
        else:
            shape = f'<path d="M{x} {y} q{direction * 16} 10 {direction * 28} 3"/>'
        elements.append(f'<g class="morph-appendage appendage-{kind}" data-index="{index}">{shape}</g>')
    return (
        f'<g class="morph-appendages morph-{part}-appendages" '
        f'{_attrs(part=part, count=count, appendage_type=kind, appendage_size=size)} '
        f'style="--appendage-scale:{_APPENDAGE_SCALES.get(size, "1")}">{"".join(elements)}</g>'
    )


def _tail(kind: str, size: str) -> str:
    if kind == "none":
        return f'<g class="morph-tail" {_attrs(tail_type="none", tail_size="none")}/>'
    paths = {
        "fish": "M73 91 L31 60 L42 91 L31 122 Z",
        "cetacean": "M70 91 C39 67 34 112 59 99 C42 123 66 129 78 105 Z",
        "crustacean": "M73 91 C43 77 37 106 61 111 L38 122 L74 105 Z",
        "elongated": "M75 91 C44 69 31 83 38 99 C47 111 57 108 75 101 Z",
        "paddle": "M74 91 C44 66 30 91 44 109 C55 122 69 111 79 101 Z",
    }
    return f'<g class="morph-tail tail-{kind}" {_attrs(tail_type=kind, tail_size=size)} style="--tail-scale:{_APPENDAGE_SCALES.get(size, "1")}"><path d="{paths.get(kind, paths["fish"])}"/></g>'


def _dorsal(kind: str, size: str) -> str:
    if kind == "none":
        return f'<g class="morph-dorsal" {_attrs(dorsal_type="none", dorsal_size="none")}/>'
    if kind == "dorsal_fin":
        markup = '<path d="M136 65 L159 24 L177 68 Z"/>'
    elif kind == "shell":
        markup = '<path d="M102 86 C117 35 190 35 206 87"/><path class="morph-detail" d="M119 74 Q154 43 191 74"/>'
    elif kind == "carapace":
        markup = '<path d="M99 87 C115 40 194 40 211 87 C184 106 124 106 99 87Z"/><path class="morph-detail" d="M125 54 L125 94 M154 45 L154 102 M183 55 L183 94"/>'
    else:
        markup = '<path d="M112 75 L129 45 L145 72 L161 38 L178 72 L195 49 L208 82 Z"/>'
    return f'<g class="morph-dorsal dorsal-{kind}" {_attrs(dorsal_type=kind, dorsal_size=size)} style="--dorsal-scale:{_APPENDAGE_SCALES.get(size, "1")}">{markup}</g>'


def _cover(kind: str) -> str:
    overlays = {
        "smooth_skin": "",
        "scales": '<g class="cover-scales"><circle cx="125" cy="78" r="5"/><circle cx="145" cy="70" r="5"/><circle cx="165" cy="80" r="5"/><circle cx="137" cy="97" r="5"/><circle cx="159" cy="101" r="5"/></g>',
        "rough_skin": '<g class="cover-rough"><circle cx="119" cy="78" r="2"/><circle cx="138" cy="67" r="2"/><circle cx="160" cy="77" r="2"/><circle cx="180" cy="93" r="2"/><circle cx="143" cy="105" r="2"/></g>',
        "chitin": '<path class="cover-chitin" d="M104 84 Q150 56 204 84 M104 96 Q150 121 204 96 M129 65 L129 112 M154 59 L154 117 M179 67 L179 111"/>',
        "hard_shell": '<path class="cover-shell" d="M104 89 C118 50 191 49 207 89 C185 113 125 113 104 89Z"/>',
        "leathery_skin": '<path class="cover-leathery" d="M98 92 C117 54 193 54 212 91 C191 123 118 124 98 92Z"/>',
        "soft_body": '<path class="cover-soft" d="M108 83 Q132 66 154 82 T198 81 M112 102 Q138 86 162 103 T197 101"/>',
    }
    return f'<g class="morph-cover cover-{kind}" {_attrs(cover=kind)}>{overlays.get(kind, "")}</g>'


def _head(snout: str, mouth: str, eye: str) -> str:
    snouts = {
        "standard": '<path class="morph-snout" d="M214 83 Q238 91 214 100Z"/>',
        "pointed": '<path class="morph-snout" d="M210 84 L250 91 L210 100Z"/>',
        "blunt": '<path class="morph-snout" d="M211 79 Q237 80 240 91 Q237 102 211 104Z"/>',
        "saw": '<path class="morph-snout" d="M211 86 L251 89 L251 94 L211 100Z"/><path class="morph-saw" d="M226 87 l4 -8 m4 9 l4 -8 m4 9 l4 -7"/>',
        "hammer": '<path class="morph-snout" d="M211 87 L237 87 L247 77 L258 87 L247 97 L237 97 L211 98Z"/>',
        "elongated": '<path class="morph-snout" d="M211 85 Q258 86 263 92 Q258 99 211 101Z"/>',
    }
    mouths = {
        "standard": '<path class="morph-mouth" d="M219 101 Q230 106 240 101"/>',
        "beak": '<path class="morph-mouth" d="M218 98 L239 106 L229 97 Z"/>',
        "suction": '<circle class="morph-mouth" cx="237" cy="96" r="7"/>',
        "filter_feeding": '<path class="morph-mouth" d="M217 101 Q232 113 245 100 M224 102 v7 m7 -7 v8 m7 -8 v7"/>',
        "jawed": '<path class="morph-mouth" d="M218 101 L240 104 L229 111 Z"/>',
    }
    eyes = {
        "standard": '<circle class="morph-eye" cx="211" cy="81" r="5"/>',
        "large": '<circle class="morph-eye" cx="211" cy="80" r="8"/>',
        "lateral": '<circle class="morph-eye" cx="218" cy="74" r="5"/>',
        "stalked": '<path class="morph-eye-stalk" d="M211 81 L218 61"/><circle class="morph-eye" cx="219" cy="59" r="5"/>',
    }
    return f'<g class="morph-head" {_attrs(snout=snout, mouth=mouth, eye=eye)}>{snouts.get(snout, snouts["standard"])}{mouths.get(mouth, mouths["standard"])}{eyes.get(eye, eyes["standard"] )}</g>'


def render_creature_portrait(view: dict[str, Any], uid: str = "portrait", size: str = "") -> Markup | None:
    """Render a v3 portrait, or return None so the legacy macro can render v1."""
    if view.get("display_model") != "morphology":
        return None
    state = view.get("morphology_visual_state")
    if not isinstance(state, dict):
        return None
    shape = _code(state.get("body_shape"))
    proportion = _code(state.get("body_proportion"))
    body_size = _code(state.get("body_size"))
    color = _code(state.get("body_color"))
    cover = _code(state.get("body_cover"))
    front_count, front_type, front_size = (_code(state.get(key)) for key in ("front_appendage_count", "front_appendage_type", "front_appendage_size"))
    rear_count, rear_type, rear_size = (_code(state.get(key)) for key in ("rear_appendage_count", "rear_appendage_type", "rear_appendage_size"))
    tail_type, tail_size = (_code(state.get(key)) for key in ("tail_type", "tail_size"))
    dorsal_type, dorsal_size = (_code(state.get(key)) for key in ("dorsal_type", "dorsal_size"))
    snout, mouth, eye = (_code(state.get(key)) for key in ("snout_type", "mouth_type", "eye_type"))
    safe_uid = _uid(uid)
    safe_size = size if size in _SIZES else ""
    base, accent = _PALETTES.get(color, ("#829196", "#52676b"))
    attributes = _attrs(shape=shape, proportion=proportion, body_size=body_size, color=color, cover=cover)
    body_path = _BODY_PATHS.get(shape, _BODY_PATHS["streamlined"])
    svg = f'''<div class="creature-portrait morphology-portrait {safe_size}" {attributes}>
<svg class="creature-svg morphology-svg" viewBox="{VIEW_BOX}" role="img" aria-label="Морфологический портрет существа" {attributes}>
<defs><linearGradient id="morph-tone-{safe_uid}" x1="0" y1="0" x2="1" y2="1"><stop stop-color="{base}"/><stop offset="1" stop-color="{accent}"/></linearGradient><filter id="morph-shadow-{safe_uid}" x="-20%" y="-25%" width="140%" height="150%"><feDropShadow dx="0" dy="7" stdDeviation="5" flood-opacity=".18"/></filter></defs>
<ellipse class="morph-ground" cx="151" cy="138" rx="104" ry="18"/>
<g class="morph-creature" style="--morph-scale:{_SCALE.get(body_size, '.9')};--morph-proportion:{_PROPORTIONS.get(proportion, _PROPORTIONS['fusiform'])}" filter="url(#morph-shadow-{safe_uid})">
{_tail(tail_type, tail_size)}{_part_group('rear', rear_count, rear_type, rear_size, False)}
<g class="morph-body" data-body-shape="{shape}"><path d="{body_path}" fill="url(#morph-tone-{safe_uid})"/></g>
{_cover(cover)}{_dorsal(dorsal_type, dorsal_size)}{_part_group('front', front_count, front_type, front_size, True)}{_head(snout, mouth, eye)}
</g></svg></div>'''
    return Markup(svg)

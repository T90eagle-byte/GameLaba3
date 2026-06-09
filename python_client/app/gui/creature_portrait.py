from __future__ import annotations

import re
from typing import Any

from PySide6.QtCore import QPointF, QRectF, QSize, Qt
from PySide6.QtGui import QColor, QFont, QPainter, QPainterPath, QPen
from PySide6.QtWidgets import QWidget


class CreaturePortraitWidget(QWidget):
    MODES = {"large", "compact", "mini"}

    def __init__(self, parent: QWidget | None = None, mode: str = "large") -> None:
        super().__init__(parent)
        self.setObjectName("creaturePortrait")
        self.setAttribute(Qt.WA_TranslucentBackground, True)

        self._species_label = ""
        self._phenotype_color = ""
        self._phenotype_size = ""
        self._phenotype_wings = ""
        self._phenotype_nutrition = ""
        self._phenotype_summary = ""
        self._variant_seed = 0
        self._compact_max_width = 460
        self._compact_max_height = 230

        self._mode = "large"
        self.set_mode(mode)

    def set_mode(self, mode: str) -> None:
        normalized = (mode or "large").strip().lower()
        if normalized not in self.MODES:
            normalized = "large"
        self._mode = normalized

        if normalized == "large":
            self.setMinimumSize(252, 214)
            self.setMaximumWidth(16777215)
            self.setMaximumHeight(245)
        elif normalized == "compact":
            self.setMinimumSize(220, 178)
            self.setMaximumWidth(self._compact_max_width)
            self.setMaximumHeight(self._compact_max_height)
        else:
            self.setMinimumSize(152, 132)
            self.setMaximumWidth(190)
            self.setMaximumHeight(150)

        self.updateGeometry()
        self.update()

    def sizeHint(self) -> QSize:  # noqa: N802
        if self._mode == "large":
            return QSize(264, 224)
        if self._mode == "compact":
            return QSize(440, 220)
        return QSize(164, 140)

    def minimumSizeHint(self) -> QSize:  # noqa: N802
        if self._mode == "large":
            return QSize(242, 206)
        if self._mode == "compact":
            return QSize(220, 178)
        return QSize(146, 126)

    def set_compact_canvas_limit(self, width: int, height: int) -> None:
        self._compact_max_width = max(220, int(width))
        self._compact_max_height = max(178, int(height))
        if self._mode == "compact":
            self.setMaximumWidth(self._compact_max_width)
            self.setMaximumHeight(self._compact_max_height)
            self.updateGeometry()
            self.update()

    def _card_rect(self) -> QRectF:
        raw = QRectF(self.rect()).adjusted(6, 6, -6, -6)
        if self._mode != "compact":
            return raw

        max_width = min(raw.width(), float(self._compact_max_width))
        max_height = min(raw.height(), float(self._compact_max_height))
        target_ratio = 16.0 / 9.0
        if max_width / max_height > target_ratio:
            max_width = max_height * target_ratio
        else:
            max_height = max_width / target_ratio

        return QRectF(
            raw.center().x() - max_width / 2,
            raw.center().y() - max_height / 2,
            max_width,
            max_height,
        )

    def set_creature(
        self,
        species_label: str | None = None,
        phenotype_color: str | None = None,
        phenotype_size: str | None = None,
        phenotype_wings: str | None = None,
        phenotype_nutrition: str | None = None,
        phenotype_summary: str | None = None,
        creature_key: object | None = None,
    ) -> None:
        self._species_label = (species_label or "").strip()
        self._phenotype_color = (phenotype_color or "").strip()
        self._phenotype_size = (phenotype_size or "").strip()
        self._phenotype_wings = (phenotype_wings or "").strip()
        self._phenotype_nutrition = (phenotype_nutrition or "").strip()
        self._phenotype_summary = (phenotype_summary or "").strip()

        self._variant_seed = self._build_variant_seed(creature_key)

        self.update()

    def clear(self) -> None:
        self.set_creature()

    def paintEvent(self, event: Any) -> None:  # noqa: N802
        super().paintEvent(event)

        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing, True)
        painter.setRenderHint(QPainter.TextAntialiasing, True)

        card = self._card_rect()
        self._draw_paper_card(painter, card)

        if not self._species_label:
            self._draw_empty_state(painter, card)
            return

        badges_space = 76 if self._mode == "large" else (48 if self._mode == "compact" else 32)
        margin = 18 if self._mode == "large" else (14 if self._mode == "compact" else 10)
        draw_zone = card.adjusted(margin, margin, -margin, -badges_space)
        body = self._scaled_body_rect(draw_zone, self._resolve_scale())

        self._draw_sketch_shadow(painter, body)

        if self._has_wings():
            self._draw_wings(painter, body)

        kind = self._species_kind()
        if kind == "cartilaginous_fish":
            self._draw_cartilaginous_fish(painter, body)
        elif kind == "bony_fish":
            self._draw_bony_fish(painter, body)
        elif kind == "crustacean":
            self._draw_crustacean(painter, body)
        elif kind == "mollusk":
            self._draw_mollusk(painter, body)
        elif kind == "turtle":
            self._draw_turtle(painter, body)
        elif kind == "mammal":
            self._draw_mammal(painter, body)
        else:
            self._draw_unknown(painter, body)

        self._draw_surface_glaze(painter, body, kind)
        self._draw_texture_overlay(painter, body, kind)
        self._draw_nutrition_marker(painter, card)
        self._draw_badges(painter, card)

    def _draw_paper_card(self, painter: QPainter, rect: QRectF) -> None:
        painter.setPen(QPen(QColor("#d6ccb8"), 1.2))
        painter.setBrush(QColor("#fffdf7"))
        painter.drawRoundedRect(rect, 10, 10)

        painter.setPen(Qt.NoPen)
        painter.setBrush(QColor("#f8ecd4"))
        painter.drawEllipse(QPointF(rect.left() + 18, rect.top() + 16), 3.2, 3.2)
        painter.drawEllipse(QPointF(rect.right() - 18, rect.top() + 16), 3.2, 3.2)

        line_pen = QPen(QColor("#ece4d3"), 1)
        painter.setPen(line_pen)
        step = 14 if self._mode == "large" else 16
        y = rect.top() + 18
        while y < rect.bottom() - (52 if self._mode != "mini" else 34):
            painter.drawLine(QPointF(rect.left() + 10, y), QPointF(rect.right() - 10, y))
            y += step

        if self._mode != "mini":
            painter.setPen(QPen(QColor("#e7dcc7"), 1))
            painter.drawLine(
                QPointF(rect.left() + 24, rect.top() + 10),
                QPointF(rect.left() + 24, rect.bottom() - (52 if self._mode == "large" else 38)),
            )

    def _draw_empty_state(self, painter: QPainter, rect: QRectF) -> None:
        center = rect.center()
        icon_w = 64 if self._mode != "mini" else 52
        icon_h = 48 if self._mode != "mini" else 38
        icon = QRectF(center.x() - icon_w / 2, center.y() - icon_h / 2 - 8, icon_w, icon_h)

        painter.setPen(QPen(QColor("#9ca3af"), 1.4, Qt.DashLine))
        painter.setBrush(QColor("#f5f3ec"))
        painter.drawRoundedRect(icon, 10, 10)

        painter.setPen(QPen(QColor("#9ca3af"), 1.5))
        painter.drawEllipse(QRectF(icon.left() + 13, icon.top() + 12, icon.width() - 26, icon.height() - 22))

        painter.setPen(QColor("#6b7280"))
        painter.drawText(
            QRectF(rect.left() + 12, rect.center().y() + 16, rect.width() - 24, 24),
            Qt.AlignCenter,
            "Выберите существо",
        )

    def _base_fill_color(self) -> QColor:
        palette = {
            "green": QColor("#7ebf8b"),
            "blue": QColor("#7fa8cf"),
            "red": QColor("#c98275"),
            "yellow": QColor("#d9c86f"),
            "purple": QColor("#a78ac2"),
            "orange": QColor("#d79a5f"),
            "white": QColor("#ece5d6"),
            "black": QColor("#545454"),
        }
        base = palette.get(self._color_token(), QColor("#9dafaa"))

        variant = self._variant_seed % 5
        if variant == 0:
            return base.lighter(106)
        if variant == 1:
            return base.darker(106)
        if variant == 2:
            return base.lighter(112)
        if variant == 3:
            return base.darker(112)
        return base

    def _color_token(self) -> str | None:
        direct = self._normalize_color_token(self._phenotype_color)
        if direct:
            return direct

        summary_color = self._extract_color_segment(self._phenotype_summary)
        if summary_color:
            return self._normalize_color_token(summary_color)
        return None

    @staticmethod
    def _extract_color_segment(value: str | None) -> str | None:
        text = (value or "").strip()
        if not text:
            return None

        for part in re.split(r"[;\n]+", text):
            if re.search(r"(?i)(^|[^a-zA-Zа-яА-Я])color\s*[:=]", part) or re.search(r"(?i)(^|[^a-zA-Zа-яА-Я])цвет\s*[:=]", part):
                return re.split(r"[:=]", part, maxsplit=1)[-1].strip()
        return None

    @staticmethod
    def _normalize_color_token(value: str | None) -> str | None:
        text = (value or "").casefold().replace("ё", "е")
        if not text:
            return None

        raw_patterns = {
            "green": r"(?<![a-zA-Z])green(?:_color)?(?![a-zA-Z])",
            "blue": r"(?<![a-zA-Z])blue(?:_color)?(?![a-zA-Z])",
            "red": r"(?<![a-zA-Z])red(?:_color)?(?![a-zA-Z])",
            "yellow": r"(?<![a-zA-Z])yellow(?:_color)?(?![a-zA-Z])",
            "purple": r"(?<![a-zA-Z])purple(?:_color)?(?![a-zA-Z])",
            "orange": r"(?<![a-zA-Z])orange(?:_color)?(?![a-zA-Z])",
            "white": r"(?<![a-zA-Z])white(?:_color)?(?![a-zA-Z])",
            "black": r"(?<![a-zA-Z])black(?:_color)?(?![a-zA-Z])",
        }
        for color, pattern in raw_patterns.items():
            if re.search(pattern, text):
                return color

        russian_markers = (
            ("green", ("зел",)),
            ("blue", ("син",)),
            ("red", ("красн",)),
            ("yellow", ("желт",)),
            ("purple", ("фиолет",)),
            ("orange", ("оранж",)),
            ("white", ("бел",)),
            ("black", ("черн",)),
        )
        for color, markers in russian_markers:
            if any(marker in text for marker in markers):
                return color
        return None

    def _outline_pen(self, width: float = 1.8) -> QPen:
        token = self._color_token()
        if token == "black":
            return QPen(QColor("#1f2937"), width)
        if token == "white":
            return QPen(QColor("#52606d"), width)
        return QPen(QColor("#334155"), width)

    def _highlight_color(self, alpha: int = 72) -> QColor:
        token = self._color_token()
        if token == "black":
            color = QColor("#a1a1aa")
        elif token == "white":
            color = QColor("#ffffff")
        else:
            color = self._base_fill_color().lighter(145)
        color.setAlpha(alpha)
        return color

    def _shadow_color(self, alpha: int = 64) -> QColor:
        token = self._color_token()
        if token == "black":
            color = QColor("#111827")
        elif token == "white":
            color = QColor("#b9aa91")
        else:
            color = self._base_fill_color().darker(145)
        color.setAlpha(alpha)
        return color

    def _detail_color(self, alpha: int = 92) -> QColor:
        token = self._color_token()
        if token == "black":
            color = QColor("#e5e7eb")
        elif token == "white":
            color = QColor("#64748b")
        else:
            color = self._base_fill_color().darker(155)
        color.setAlpha(alpha)
        return color

    def _resolve_scale(self) -> float:
        size = self._phenotype_size.casefold()
        if "компакт" in size:
            return 0.86
        if "круп" in size:
            return 1.12
        return 1.0

    def _has_wings(self) -> bool:
        wings = self._phenotype_wings.casefold()
        return "есть" in wings and "крыл" in wings

    def _species_kind(self) -> str:
        text = self._species_label.casefold()
        if "хрящ" in text:
            return "cartilaginous_fish"
        if "кост" in text and "рыб" in text:
            return "bony_fish"
        if "ракообраз" in text:
            return "crustacean"
        if "моллюск" in text:
            return "mollusk"
        if "черепах" in text:
            return "turtle"
        if "млекопита" in text:
            return "mammal"
        if "рыб" in text:
            return "bony_fish"
        return "unknown"

    def _scaled_body_rect(self, area: QRectF, scale: float) -> QRectF:
        kind = self._species_kind()
        if kind == "cartilaginous_fish":
            width_factor, height_factor = 0.66, 0.34
        elif kind == "bony_fish":
            width_factor, height_factor = 0.58, 0.44
        elif kind == "crustacean":
            width_factor, height_factor = 0.60, 0.48
        elif kind == "mollusk":
            width_factor, height_factor = 0.60, 0.46
        elif kind == "turtle":
            width_factor, height_factor = 0.58, 0.48
        elif kind == "mammal":
            width_factor, height_factor = 0.60, 0.46
        else:
            width_factor, height_factor = 0.56, 0.42

        w = area.width() * width_factor * scale
        h = area.height() * height_factor * scale
        w = min(w, area.width() * 0.82)
        h = min(h, area.height() * 0.72)
        return QRectF(area.center().x() - w / 2, area.center().y() - h / 2, w, h)


    def _detail_level(self) -> int:
        if self._mode == "large":
            return 3
        if self._mode == "compact":
            return 2
        return 1

    @staticmethod
    def _organic_oval_path(rect: QRectF, nose: float = 0.0, back: float = 0.0) -> QPainterPath:
        path = QPainterPath()
        cy = rect.center().y()
        path.moveTo(rect.left() + rect.width() * back, cy)
        path.cubicTo(rect.left() + rect.width() * 0.10, rect.top() - rect.height() * 0.06, rect.right() - rect.width() * 0.16, rect.top() - rect.height() * 0.10, rect.right() + rect.width() * nose, cy)
        path.cubicTo(rect.right() - rect.width() * 0.12, rect.bottom() + rect.height() * 0.10, rect.left() + rect.width() * 0.10, rect.bottom() + rect.height() * 0.05, rect.left() + rect.width() * back, cy)
        path.closeSubpath()
        return path

    @staticmethod
    def _limb_path(start: QPointF, mid: QPointF, end: QPointF, width: float) -> QPainterPath:
        path = QPainterPath()
        path.moveTo(start.x() - width, start.y())
        path.quadTo(mid.x() - width * 0.8, mid.y(), end.x() - width * 0.4, end.y())
        path.quadTo(end.x() + width * 0.6, end.y() + width * 0.45, mid.x() + width * 0.8, mid.y() + width * 0.25)
        path.quadTo(start.x() + width, start.y() + width * 0.15, start.x() - width, start.y())
        path.closeSubpath()
        return path

    @staticmethod
    def _segment_path(rect: QRectF, pinch: float = 0.08) -> QPainterPath:
        path = QPainterPath()
        cy = rect.center().y()
        path.moveTo(rect.left(), cy)
        path.cubicTo(rect.left() + rect.width() * (0.12 + pinch), rect.top(), rect.right() - rect.width() * 0.12, rect.top() + rect.height() * 0.04, rect.right(), cy)
        path.cubicTo(rect.right() - rect.width() * 0.12, rect.bottom() - rect.height() * 0.02, rect.left() + rect.width() * (0.10 + pinch), rect.bottom(), rect.left(), cy)
        path.closeSubpath()
        return path

    def _draw_sketch_shadow(self, painter: QPainter, body: QRectF) -> None:
        painter.save()
        painter.setPen(Qt.NoPen)
        shadow = QColor("#d8c7ad")
        shadow.setAlpha(92 if self._mode != "mini" else 58)
        painter.setBrush(shadow)
        painter.drawEllipse(
            QRectF(
                body.left() + body.width() * 0.06,
                body.bottom() - body.height() * 0.035,
                body.width() * 0.88,
                body.height() * 0.20,
            )
        )
        soft = QColor("#bca582")
        soft.setAlpha(34 if self._mode != "mini" else 18)
        painter.setBrush(soft)
        painter.drawEllipse(
            QRectF(
                body.left() + body.width() * 0.18,
                body.bottom() + body.height() * 0.02,
                body.width() * 0.58,
                body.height() * 0.10,
            )
        )
        painter.restore()

    def _draw_surface_glaze(self, painter: QPainter, body: QRectF, kind: str) -> None:
        detail = self._detail_level()
        painter.save()
        painter.setPen(Qt.NoPen)

        highlight = self._highlight_color(56 if detail >= 2 else 34)
        shadow = self._shadow_color(48 if detail >= 2 else 30)

        if kind in {"cartilaginous_fish", "bony_fish"}:
            painter.setBrush(highlight)
            painter.drawEllipse(
                QRectF(
                    body.left() + body.width() * 0.26,
                    body.top() + body.height() * 0.08,
                    body.width() * 0.40,
                    body.height() * 0.18,
                )
            )
            painter.setBrush(shadow)
            painter.drawEllipse(
                QRectF(
                    body.left() + body.width() * 0.20,
                    body.center().y() + body.height() * 0.16,
                    body.width() * 0.50,
                    body.height() * 0.15,
                )
            )
        elif kind == "turtle":
            painter.setBrush(highlight)
            painter.drawEllipse(body.adjusted(body.width() * 0.22, body.height() * 0.18, -body.width() * 0.34, -body.height() * 0.46))
            painter.setBrush(shadow)
            painter.drawEllipse(body.adjusted(body.width() * 0.20, body.height() * 0.58, -body.width() * 0.28, -body.height() * 0.16))
        elif kind == "mollusk":
            painter.setBrush(highlight)
            painter.drawEllipse(body.adjusted(body.width() * 0.12, body.height() * 0.10, -body.width() * 0.56, -body.height() * 0.52))
            painter.setBrush(shadow)
            painter.drawEllipse(body.adjusted(body.width() * 0.44, body.height() * 0.54, -body.width() * 0.08, -body.height() * 0.12))
        else:
            painter.setBrush(highlight)
            painter.drawEllipse(body.adjusted(body.width() * 0.22, body.height() * 0.08, -body.width() * 0.34, -body.height() * 0.54))
            painter.setBrush(shadow)
            painter.drawEllipse(body.adjusted(body.width() * 0.18, body.height() * 0.56, -body.width() * 0.24, -body.height() * 0.14))

        if detail >= 2:
            painter.setPen(QPen(self._highlight_color(72), 1.0))
            painter.drawLine(
                QPointF(body.left() + body.width() * 0.26, body.top() + body.height() * 0.20),
                QPointF(body.left() + body.width() * 0.62, body.top() + body.height() * 0.14),
            )
        painter.restore()

    def _draw_cartilaginous_fish(self, painter: QPainter, body: QRectF) -> None:
        painter.save()
        detail = self._detail_level()
        fill = self._base_fill_color()
        painter.setPen(self._outline_pen(1.75 if detail > 1 else 1.4))
        painter.setBrush(fill)

        head_nose = body.width() * 0.10
        core = QPainterPath()
        core.moveTo(body.left() + body.width() * 0.03, body.center().y() + body.height() * 0.02)
        core.cubicTo(
            body.left() + body.width() * 0.18,
            body.top() + body.height() * 0.02,
            body.left() + body.width() * 0.62,
            body.top() - body.height() * 0.12,
            body.right() + head_nose,
            body.center().y() - body.height() * 0.03,
        )
        core.cubicTo(
            body.left() + body.width() * 0.78,
            body.center().y() + body.height() * 0.32,
            body.left() + body.width() * 0.26,
            body.bottom() + body.height() * 0.03,
            body.left() + body.width() * 0.03,
            body.center().y() + body.height() * 0.02,
        )
        core.closeSubpath()
        painter.drawPath(core)

        painter.setBrush(fill.lighter(107))
        fork = 0.28 if self._summary_has("\u0440\u0430\u0437\u0434\u0432\u043e") else 0.20
        tail = QPainterPath()
        tail.moveTo(body.left() + body.width() * 0.08, body.center().y())
        tail.cubicTo(
            body.left() - body.width() * 0.15,
            body.top() - body.height() * 0.12,
            body.left() - body.width() * fork,
            body.top() + body.height() * 0.04,
            body.left() - body.width() * 0.12,
            body.center().y() - body.height() * 0.03,
        )
        tail.cubicTo(
            body.left() - body.width() * fork,
            body.bottom() - body.height() * 0.04,
            body.left() - body.width() * 0.15,
            body.bottom() + body.height() * 0.12,
            body.left() + body.width() * 0.08,
            body.center().y(),
        )
        painter.drawPath(tail)

        fin_height = 0.58 if self._summary_has("\u0437\u0430\u043e\u0441\u0442\u0440") else 0.42
        if self._summary_has("\u0448\u0438\u0440\u043e\u043a"):
            fin_height = 0.34
        dorsal = QPainterPath()
        dorsal.moveTo(body.left() + body.width() * 0.39, body.top() + body.height() * 0.10)
        dorsal.cubicTo(
            body.left() + body.width() * 0.48,
            body.top() - body.height() * fin_height,
            body.left() + body.width() * 0.59,
            body.top() - body.height() * fin_height * 0.42,
            body.left() + body.width() * 0.67,
            body.top() + body.height() * 0.12,
        )
        dorsal.closeSubpath()
        painter.drawPath(dorsal)

        if detail >= 2:
            painter.setBrush(fill.lighter(112))
            for x_mul, y_mul, side in ((0.44, 0.72, -1), (0.66, 0.70, 1)):
                fin = QPainterPath()
                x = body.left() + body.width() * x_mul
                y = body.top() + body.height() * y_mul
                fin.moveTo(x, y)
                fin.cubicTo(
                    x + side * body.width() * 0.03,
                    y + body.height() * 0.18,
                    x + side * body.width() * 0.18,
                    y + body.height() * 0.30,
                    x + side * body.width() * 0.22,
                    y + body.height() * 0.06,
                )
                fin.cubicTo(
                    x + side * body.width() * 0.12,
                    y + body.height() * 0.03,
                    x + side * body.width() * 0.06,
                    y - body.height() * 0.01,
                    x,
                    y,
                )
                painter.drawPath(fin)

            painter.setPen(QPen(self._detail_color(120), 1.0))
            gill_count = 3 if detail == 3 else 2
            for idx in range(gill_count):
                offset = 0.10 + idx * 0.055
                painter.drawLine(
                    QPointF(body.right() - body.width() * 0.25, body.center().y() - body.height() * offset),
                    QPointF(body.right() - body.width() * 0.20, body.center().y() + body.height() * (offset - 0.05)),
                )
            painter.drawLine(
                QPointF(body.right() - body.width() * 0.06, body.center().y() + body.height() * 0.12),
                QPointF(body.right() + body.width() * 0.02, body.center().y() + body.height() * 0.09),
            )
            painter.setPen(QPen(self._highlight_color(115), 1.05))
            painter.drawLine(
                QPointF(body.left() + body.width() * 0.26, body.top() + body.height() * 0.20),
                QPointF(body.right() - body.width() * 0.22, body.top() + body.height() * 0.10),
            )
            painter.setPen(QPen(self._shadow_color(92), 1.0))
            painter.drawLine(
                QPointF(body.left() + body.width() * 0.28, body.bottom() - body.height() * 0.16),
                QPointF(body.right() - body.width() * 0.30, body.bottom() - body.height() * 0.12),
            )

        painter.setPen(self._outline_pen())
        self._draw_eye(painter, QPointF(body.right() - body.width() * 0.14, body.center().y() - body.height() * 0.13))
        painter.restore()


    def _draw_bony_fish(self, painter: QPainter, body: QRectF) -> None:
        painter.save()
        detail = self._detail_level()
        fill = self._base_fill_color()
        painter.setPen(self._outline_pen(1.7 if detail > 1 else 1.4))
        painter.setBrush(fill)

        fish_body = QRectF(body.left() + body.width() * 0.10, body.top() - body.height() * 0.02, body.width() * 0.72, body.height() * 1.04)
        shape = QPainterPath()
        shape.moveTo(fish_body.left(), fish_body.center().y())
        shape.cubicTo(
            fish_body.left() + fish_body.width() * 0.17,
            fish_body.top() - fish_body.height() * 0.08,
            fish_body.right() - fish_body.width() * 0.15,
            fish_body.top() - fish_body.height() * 0.12,
            fish_body.right() + fish_body.width() * 0.06,
            fish_body.center().y() - fish_body.height() * 0.01,
        )
        shape.cubicTo(
            fish_body.right() - fish_body.width() * 0.10,
            fish_body.bottom() + fish_body.height() * 0.14,
            fish_body.left() + fish_body.width() * 0.18,
            fish_body.bottom() + fish_body.height() * 0.08,
            fish_body.left(),
            fish_body.center().y(),
        )
        shape.closeSubpath()
        painter.drawPath(shape)

        painter.setBrush(fill.lighter(110))
        fan = 0.28 if self._summary_has("\u0448\u0438\u0440\u043e\u043a") else 0.20
        if self._summary_has("\u0440\u0430\u0437\u0434\u0432\u043e"):
            fan = 0.32
        tail = QPainterPath()
        tail.moveTo(fish_body.left() + fish_body.width() * 0.03, fish_body.center().y())
        tail.cubicTo(
            body.left() - body.width() * fan,
            fish_body.top() - fish_body.height() * 0.03,
            body.left() - body.width() * 0.19,
            fish_body.top() + fish_body.height() * 0.24,
            fish_body.left() - body.width() * 0.02,
            fish_body.center().y(),
        )
        tail.cubicTo(
            body.left() - body.width() * 0.19,
            fish_body.bottom() - fish_body.height() * 0.24,
            body.left() - body.width() * fan,
            fish_body.bottom() + fish_body.height() * 0.03,
            fish_body.left() + fish_body.width() * 0.03,
            fish_body.center().y(),
        )
        painter.drawPath(tail)

        if detail >= 2:
            top_fin = QPainterPath()
            top_fin.moveTo(fish_body.left() + fish_body.width() * 0.38, fish_body.top() + fish_body.height() * 0.10)
            top_fin.cubicTo(
                fish_body.center().x(),
                fish_body.top() - fish_body.height() * 0.28,
                fish_body.center().x() + fish_body.width() * 0.18,
                fish_body.top() - fish_body.height() * 0.12,
                fish_body.center().x() + fish_body.width() * 0.25,
                fish_body.top() + fish_body.height() * 0.12,
            )
            top_fin.closeSubpath()
            painter.drawPath(top_fin)

            bottom_fin = QPainterPath()
            bottom_fin.moveTo(fish_body.center().x() - fish_body.width() * 0.02, fish_body.bottom() - fish_body.height() * 0.10)
            bottom_fin.cubicTo(
                fish_body.center().x() + fish_body.width() * 0.04,
                fish_body.bottom() + fish_body.height() * 0.25,
                fish_body.center().x() + fish_body.width() * 0.18,
                fish_body.bottom() + fish_body.height() * 0.12,
                fish_body.center().x() + fish_body.width() * 0.22,
                fish_body.bottom() - fish_body.height() * 0.12,
            )
            bottom_fin.closeSubpath()
            painter.drawPath(bottom_fin)

            painter.setPen(QPen(self._detail_color(92), 0.95))
            scale_count = 5 if detail == 3 else 3
            for idx in range(scale_count):
                shift = 0.20 + idx * 0.12
                arc = QRectF(
                    fish_body.left() + fish_body.width() * shift,
                    fish_body.top() + fish_body.height() * 0.17,
                    fish_body.width() * 0.20,
                    fish_body.height() * 0.64,
                )
                painter.drawArc(arc, 72 * 16, 215 * 16)
            painter.setPen(QPen(self._highlight_color(100), 1.0))
            painter.drawLine(
                QPointF(fish_body.left() + fish_body.width() * 0.24, fish_body.top() + fish_body.height() * 0.22),
                QPointF(fish_body.right() - fish_body.width() * 0.20, fish_body.top() + fish_body.height() * 0.16),
            )

        painter.setPen(self._outline_pen())
        self._draw_eye(painter, QPointF(fish_body.right() - fish_body.width() * 0.14, fish_body.center().y() - fish_body.height() * 0.12))
        painter.restore()


    def _draw_crustacean(self, painter: QPainter, body: QRectF) -> None:
        painter.save()
        detail = self._detail_level()
        fill = self._base_fill_color()
        painter.setPen(self._outline_pen(1.6 if detail > 1 else 1.35))
        painter.setBrush(fill)

        segment_total = 5 if detail == 3 else (4 if detail == 2 else 3)
        segments = []
        for idx in range(segment_total):
            t = idx / max(1, segment_total - 1)
            scale = 0.74 + 0.20 * (1.0 - abs(t - 0.55) * 1.7)
            x = body.left() + body.width() * (0.12 + idx * (0.58 / max(1, segment_total - 1)))
            seg = QRectF(x, body.top() + body.height() * (0.5 - scale * 0.30), body.width() * 0.22, body.height() * scale * 0.60)
            segments.append(seg)
            painter.drawPath(self._segment_path(seg, 0.04 + idx * 0.01))
            if detail >= 2:
                painter.save()
                painter.setPen(QPen(self._detail_color(85), 0.85))
                painter.drawLine(
                    QPointF(seg.left() + seg.width() * 0.18, seg.top() + seg.height() * 0.22),
                    QPointF(seg.right() - seg.width() * 0.14, seg.bottom() - seg.height() * 0.24),
                )
                painter.restore()

        tail = QPainterPath()
        tail.moveTo(body.left() + body.width() * 0.1, body.center().y())
        tail.lineTo(body.left() - body.width() * 0.1, body.top() + body.height() * 0.26)
        tail.lineTo(body.left() + body.width() * 0.04, body.center().y())
        tail.lineTo(body.left() - body.width() * 0.1, body.bottom() - body.height() * 0.26)
        tail.closeSubpath()
        painter.drawPath(tail)

        claw_len = 0.28 if self._summary_has("длин") else 0.22
        head = segments[-1]
        for side in (-1, 1):
            arm_base = QPointF(head.center().x() + side * head.width() * 0.28, head.center().y() - head.height() * 0.18)
            arm_tip = QPointF(arm_base.x() + side * body.width() * claw_len, arm_base.y() - body.height() * 0.18)
            painter.drawLine(arm_base, arm_tip)
            claw = QPainterPath()
            claw.moveTo(arm_tip)
            claw.quadTo(arm_tip.x() + side * body.width() * 0.08, arm_tip.y() - body.height() * 0.16, arm_tip.x() + side * body.width() * 0.16, arm_tip.y() - body.height() * 0.04)
            claw.lineTo(arm_tip.x() + side * body.width() * 0.06, arm_tip.y() + body.height() * 0.04)
            claw.quadTo(arm_tip.x() + side * body.width() * 0.14, arm_tip.y() + body.height() * 0.13, arm_tip.x() + side * body.width() * 0.02, arm_tip.y() + body.height() * 0.12)
            claw.closeSubpath()
            painter.drawPath(claw)
            if detail >= 2:
                painter.save()
                painter.setPen(QPen(self._highlight_color(90), 0.9))
                painter.drawLine(arm_tip, QPointF(arm_tip.x() + side * body.width() * 0.10, arm_tip.y() - body.height() * 0.02))
                painter.restore()

        if detail >= 2:
            painter.setPen(QPen(QColor("#334155"), 1.2))
            leg_count = 4 if detail == 3 else 3
            for idx in range(leg_count):
                seg = segments[min(idx, len(segments) - 1)]
                for side in (-1, 1):
                    start = QPointF(seg.center().x(), seg.bottom() - seg.height() * 0.16)
                    mid = QPointF(start.x() + side * body.width() * 0.12, start.y() + body.height() * 0.16)
                    end = QPointF(mid.x() + side * body.width() * 0.08, mid.y() + body.height() * 0.06)
                    painter.drawPath(self._limb_path(start, mid, end, body.width() * 0.008))

        if detail >= 2:
            painter.drawLine(QPointF(head.right() - head.width() * 0.18, head.top() + head.height() * 0.18), QPointF(head.right() + body.width() * 0.12, head.top() - body.height() * 0.12))
            painter.drawLine(QPointF(head.right() - head.width() * 0.08, head.top() + head.height() * 0.24), QPointF(head.right() + body.width() * 0.16, head.top() + body.height() * 0.02))
        self._draw_eye(painter, QPointF(head.right() - head.width() * 0.24, head.center().y() - head.height() * 0.16))
        painter.restore()

    def _draw_mollusk(self, painter: QPainter, body: QRectF) -> None:
        painter.save()
        detail = self._detail_level()
        fill = self._base_fill_color()
        shell_fill = fill.darker(106)
        painter.setPen(self._outline_pen(1.6 if detail > 1 else 1.35))
        painter.setBrush(shell_fill)

        shell = QRectF(body.left() + body.width() * 0.03, body.top() + body.height() * 0.04, body.width() * 0.52, body.height() * 0.76)
        shell_path = QPainterPath()
        shell_path.moveTo(shell.left() + shell.width() * 0.18, shell.center().y())
        shell_path.cubicTo(shell.left() + shell.width() * 0.1, shell.top() + shell.height() * 0.1, shell.right() - shell.width() * 0.1, shell.top() - shell.height() * 0.02, shell.right(), shell.center().y())
        shell_path.cubicTo(shell.right() - shell.width() * 0.04, shell.bottom() + shell.height() * 0.06, shell.left() + shell.width() * 0.16, shell.bottom() - shell.height() * 0.02, shell.left() + shell.width() * 0.18, shell.center().y())
        painter.drawPath(shell_path)

        painter.setPen(QPen(QColor("#64748b"), 1.2))
        center = shell.center()
        spiral = QPainterPath()
        spiral.moveTo(center)
        spiral.cubicTo(center.x() + shell.width() * 0.22, center.y() - shell.height() * 0.12, center.x() + shell.width() * 0.12, shell.top() + shell.height() * 0.12, shell.left() + shell.width() * 0.34, shell.top() + shell.height() * 0.18)
        spiral.cubicTo(shell.left() + shell.width() * 0.02, shell.top() + shell.height() * 0.34, shell.left() + shell.width() * 0.16, shell.bottom() - shell.height() * 0.18, center.x() + shell.width() * 0.08, shell.bottom() - shell.height() * 0.12)
        painter.drawPath(spiral)
        if detail >= 2:
            painter.save()
            painter.setPen(QPen(self._highlight_color(120), 1.0))
            painter.drawArc(shell.adjusted(shell.width() * 0.18, shell.height() * 0.14, -shell.width() * 0.30, -shell.height() * 0.52), 20 * 16, 130 * 16)
            painter.restore()
            for shift in (0.28, 0.46, 0.64):
                painter.drawArc(shell.adjusted(shell.width() * shift * 0.25, shell.height() * 0.08, -shell.width() * 0.08, -shell.height() * 0.1), 110 * 16, 105 * 16)

        painter.setPen(self._outline_pen(1.5))
        painter.setBrush(fill.lighter(112))
        soft = QPainterPath()
        soft.moveTo(body.left() + body.width() * 0.42, body.center().y() + body.height() * 0.08)
        soft.cubicTo(body.left() + body.width() * 0.55, body.top() + body.height() * 0.42, body.right() - body.width() * 0.1, body.top() + body.height() * 0.42, body.right(), body.center().y() + body.height() * 0.03)
        soft.cubicTo(body.right() - body.width() * 0.04, body.bottom() - body.height() * 0.06, body.left() + body.width() * 0.54, body.bottom() - body.height() * 0.12, body.left() + body.width() * 0.42, body.center().y() + body.height() * 0.08)
        painter.drawPath(soft)

        head = QRectF(body.right() - body.width() * 0.16, body.center().y() - body.height() * 0.08, body.width() * 0.16, body.height() * 0.16)
        painter.drawPath(self._organic_oval_path(head, nose=0.04))
        if detail >= 2:
            painter.drawLine(QPointF(head.center().x(), head.top()), QPointF(head.center().x() + body.width() * 0.08, head.top() - body.height() * 0.16))
            painter.drawLine(QPointF(head.center().x() - head.width() * 0.15, head.top() + head.height() * 0.12), QPointF(head.center().x() - body.width() * 0.02, head.top() - body.height() * 0.12))
        self._draw_eye(painter, QPointF(head.right() - head.width() * 0.28, head.center().y() - head.height() * 0.12))
        painter.restore()

    def _draw_turtle(self, painter: QPainter, body: QRectF) -> None:
        painter.save()
        detail = self._detail_level()
        fill = self._base_fill_color()
        painter.setPen(self._outline_pen(1.7 if detail > 1 else 1.4))
        painter.setBrush(fill)

        shell = QRectF(body.left() + body.width() * 0.12, body.top() + body.height() * 0.08, body.width() * 0.64, body.height() * 0.72)
        shell_path = QPainterPath()
        shell_path.moveTo(shell.left(), shell.center().y())
        shell_path.cubicTo(shell.left() + shell.width() * 0.12, shell.top() - shell.height() * 0.08, shell.right() - shell.width() * 0.1, shell.top() - shell.height() * 0.08, shell.right(), shell.center().y())
        shell_path.cubicTo(shell.right() - shell.width() * 0.08, shell.bottom() + shell.height() * 0.08, shell.left() + shell.width() * 0.12, shell.bottom() + shell.height() * 0.05, shell.left(), shell.center().y())
        painter.drawPath(shell_path)

        if detail >= 2:
            painter.setPen(QPen(QColor("#5f7288"), 1.1))
            inner = shell.adjusted(shell.width() * 0.15, shell.height() * 0.18, -shell.width() * 0.15, -shell.height() * 0.18)
            painter.drawPath(self._organic_oval_path(inner))
            painter.drawLine(QPointF(shell.left() + shell.width() * 0.18, shell.center().y()), QPointF(shell.right() - shell.width() * 0.18, shell.center().y()))
            painter.drawLine(QPointF(shell.center().x(), shell.top() + shell.height() * 0.16), QPointF(shell.center().x(), shell.bottom() - shell.height() * 0.14))
            painter.setPen(QPen(self._highlight_color(105), 1.0))
            painter.drawArc(shell.adjusted(shell.width() * 0.18, shell.height() * 0.12, -shell.width() * 0.35, -shell.height() * 0.44), 25 * 16, 110 * 16)
            painter.setPen(QPen(QColor("#5f7288"), 1.1))
            if detail == 3:
                painter.drawLine(QPointF(shell.left() + shell.width() * 0.33, shell.top() + shell.height() * 0.22), QPointF(shell.left() + shell.width() * 0.26, shell.bottom() - shell.height() * 0.2))
                painter.drawLine(QPointF(shell.left() + shell.width() * 0.67, shell.top() + shell.height() * 0.22), QPointF(shell.left() + shell.width() * 0.74, shell.bottom() - shell.height() * 0.2))

        if self._summary_has("шип"):
            painter.setPen(self._outline_pen(1.2))
            for shift in (0.18, 0.34, 0.5, 0.66):
                x = shell.left() + shell.width() * shift
                spike = QPainterPath()
                spike.moveTo(x, shell.top() + shell.height() * 0.08)
                spike.lineTo(x + shell.width() * 0.04, shell.top() - shell.height() * 0.07)
                spike.lineTo(x + shell.width() * 0.08, shell.top() + shell.height() * 0.09)
                spike.closeSubpath()
                painter.drawPath(spike)

        painter.setPen(self._outline_pen(1.5))
        painter.setBrush(fill.lighter(112))
        head = QRectF(shell.right() - shell.width() * 0.02, shell.center().y() - shell.height() * 0.15, shell.width() * 0.23, shell.height() * 0.30)
        painter.drawPath(self._organic_oval_path(head, nose=0.02))
        self._draw_eye(painter, QPointF(head.center().x() + head.width() * 0.14, head.center().y() - head.height() * 0.12))

        foot_points = [
            (QPointF(shell.left() + shell.width() * 0.18, shell.top() + shell.height() * 0.22), QPointF(shell.left() + shell.width() * 0.06, shell.top() - shell.height() * 0.02), QPointF(shell.left() + shell.width() * 0.18, shell.top() - shell.height() * 0.08)),
            (QPointF(shell.right() - shell.width() * 0.16, shell.top() + shell.height() * 0.22), QPointF(shell.right() + shell.width() * 0.03, shell.top()), QPointF(shell.right() + shell.width() * 0.09, shell.top() + shell.height() * 0.08)),
            (QPointF(shell.left() + shell.width() * 0.18, shell.bottom() - shell.height() * 0.20), QPointF(shell.left() + shell.width() * 0.04, shell.bottom() + shell.height() * 0.08), QPointF(shell.left() + shell.width() * 0.18, shell.bottom() + shell.height() * 0.10)),
            (QPointF(shell.right() - shell.width() * 0.18, shell.bottom() - shell.height() * 0.20), QPointF(shell.right() + shell.width() * 0.04, shell.bottom() + shell.height() * 0.08), QPointF(shell.right() + shell.width() * 0.10, shell.bottom() + shell.height() * 0.04)),
        ]
        for start_point, mid_point, end_point in foot_points:
            painter.drawPath(self._limb_path(start_point, mid_point, end_point, shell.width() * 0.035))

        tail = QPainterPath()
        tail.moveTo(shell.left() - shell.width() * 0.01, shell.center().y())
        tail.lineTo(shell.left() - shell.width() * 0.13, shell.center().y() - shell.height() * 0.07)
        tail.lineTo(shell.left() - shell.width() * 0.12, shell.center().y() + shell.height() * 0.08)
        tail.closeSubpath()
        painter.drawPath(tail)
        painter.restore()

    def _draw_mammal(self, painter: QPainter, body: QRectF) -> None:
        painter.save()
        detail = self._detail_level()
        fill = self._base_fill_color()
        painter.setPen(self._outline_pen(1.7 if detail > 1 else 1.4))
        painter.setBrush(fill)

        trunk = QRectF(body.left() + body.width() * 0.08, body.top() + body.height() * 0.20, body.width() * 0.58, body.height() * 0.50)
        trunk_path = QPainterPath()
        trunk_path.moveTo(trunk.left(), trunk.center().y())
        trunk_path.cubicTo(trunk.left() + trunk.width() * 0.10, trunk.top() - trunk.height() * 0.04, trunk.right() - trunk.width() * 0.12, trunk.top() - trunk.height() * 0.08, trunk.right(), trunk.center().y() - trunk.height() * 0.05)
        trunk_path.cubicTo(trunk.right() + trunk.width() * 0.06, trunk.bottom() + trunk.height() * 0.06, trunk.left() + trunk.width() * 0.13, trunk.bottom() + trunk.height() * 0.08, trunk.left(), trunk.center().y())
        trunk_path.closeSubpath()
        painter.drawPath(trunk_path)

        head = QRectF(trunk.right() - trunk.width() * 0.02, trunk.top() - trunk.height() * 0.04, trunk.width() * 0.42, trunk.height() * 0.58)
        painter.drawPath(self._organic_oval_path(head, nose=0.04))

        for x_mul in (0.24, 0.72):
            ear = QPainterPath()
            x = head.left() + head.width() * x_mul
            direction = 1 if x_mul > 0.5 else -1
            ear.moveTo(x, head.top() + head.height() * 0.18)
            ear.cubicTo(x + direction * head.width() * 0.02, head.top() - head.height() * 0.18, x + direction * head.width() * 0.20, head.top() - head.height() * 0.26, x + direction * head.width() * 0.20, head.top() + head.height() * 0.02)
            ear.cubicTo(x + direction * head.width() * 0.12, head.top() + head.height() * 0.05, x + direction * head.width() * 0.05, head.top() + head.height() * 0.10, x, head.top() + head.height() * 0.18)
            painter.drawPath(ear)

        tail = QPainterPath()
        tail.moveTo(trunk.left() + trunk.width() * 0.04, trunk.center().y() - trunk.height() * 0.04)
        tail.cubicTo(trunk.left() - trunk.width() * 0.22, trunk.top() + trunk.height() * 0.12, trunk.left() - trunk.width() * 0.28, trunk.bottom() - trunk.height() * 0.22, trunk.left() - trunk.width() * 0.1, trunk.bottom() - trunk.height() * 0.18)
        painter.drawPath(tail)

        self._draw_eye(painter, QPointF(head.center().x() + head.width() * 0.16, head.center().y() - head.height() * 0.12))
        painter.setPen(QPen(QColor("#334155"), 1.0))
        nose = QPointF(head.right() - head.width() * 0.05, head.center().y() + head.height() * 0.07)
        painter.drawEllipse(nose, 1.7, 1.2)
        painter.drawLine(QPointF(head.right() - head.width() * 0.14, head.center().y() + head.height() * 0.08), QPointF(head.right() - head.width() * 0.03, head.center().y() + head.height() * 0.1))

        painter.setPen(self._outline_pen(1.5))
        leg_positions = (0.14, 0.44, 0.66, 0.86) if detail >= 2 else (0.22, 0.76)
        for shift in leg_positions:
            start = QPointF(trunk.left() + trunk.width() * shift, trunk.bottom() - trunk.height() * 0.06)
            mid = QPointF(start.x() + trunk.width() * 0.02, trunk.bottom() + trunk.height() * 0.18)
            end = QPointF(start.x() + trunk.width() * 0.08, trunk.bottom() + trunk.height() * 0.25)
            painter.drawPath(self._limb_path(start, mid, end, trunk.width() * 0.025))

        painter.setPen(QPen(QColor("#516274"), 1.0))
        fur_shifts = (0.12, 0.22, 0.32, 0.46, 0.58, 0.7)
        if self._summary_has("шерст"):
            fur_shifts = (0.08, 0.16, 0.24, 0.32, 0.44, 0.56, 0.68, 0.8)
        if detail >= 2:
            for shift in fur_shifts:
                x = trunk.left() + trunk.width() * shift
                painter.drawLine(QPointF(x, trunk.top() + trunk.height() * 0.03), QPointF(x + trunk.width() * 0.04, trunk.top() - trunk.height() * 0.08))

        if self._summary_has("скорость", "высок") or self._summary_has("быстр"):
            painter.setPen(QPen(QColor("#94a3b8"), 1.3))
            for offset in (0.18, 0.32, 0.46):
                painter.drawLine(QPointF(trunk.left() - trunk.width() * offset, trunk.center().y()), QPointF(trunk.left() - trunk.width() * (offset - 0.08), trunk.center().y()))
        painter.restore()

    def _draw_unknown(self, painter: QPainter, body: QRectF) -> None:
        painter.setPen(self._outline_pen())
        painter.setBrush(self._base_fill_color())

        shape = QPainterPath()
        shape.moveTo(body.center().x(), body.top())
        shape.lineTo(body.right(), body.center().y())
        shape.lineTo(body.center().x(), body.bottom())
        shape.lineTo(body.left(), body.center().y())
        shape.closeSubpath()
        painter.drawPath(shape)

        painter.setPen(QPen(QColor("#475569"), 1.1))
        painter.drawText(body, Qt.AlignCenter, "?")

    def _draw_wings(self, painter: QPainter, body: QRectF) -> None:
        painter.save()
        wing_fill = QColor("#e7eefb")
        wing_fill.setAlpha(205)
        painter.setBrush(wing_fill)
        painter.setPen(QPen(QColor("#7b8da8"), 1.2))

        for side in (-1, 1):
            wing = QPainterPath()
            anchor_x = body.center().x() + side * body.width() * 0.18
            wing.moveTo(anchor_x, body.top() + body.height() * 0.24)
            wing.cubicTo(
                anchor_x + side * body.width() * 0.34,
                body.top() - body.height() * 0.18,
                anchor_x + side * body.width() * 0.44,
                body.center().y() + body.height() * 0.05,
                anchor_x + side * body.width() * 0.1,
                body.center().y() + body.height() * 0.2,
            )
            wing.cubicTo(
                anchor_x + side * body.width() * 0.24,
                body.center().y(),
                anchor_x + side * body.width() * 0.12,
                body.top() + body.height() * 0.36,
                anchor_x,
                body.top() + body.height() * 0.24,
            )
            painter.drawPath(wing)
            painter.drawLine(QPointF(anchor_x + side * body.width() * 0.1, body.center().y() + body.height() * 0.02), QPointF(anchor_x + side * body.width() * 0.32, body.top() + body.height() * 0.04))
        painter.restore()

    @staticmethod
    def _draw_eye(painter: QPainter, center: QPointF) -> None:
        painter.setBrush(QColor("#f8fafc"))
        painter.setPen(QPen(QColor("#334155"), 1.2))
        painter.drawEllipse(center, 3.6, 3.2)
        painter.setBrush(QColor("#111827"))
        painter.drawEllipse(center, 1.2, 1.2)

    def _build_variant_seed(self, creature_key: Any | None) -> int:
        text = ""
        if creature_key is not None:
            text = str(creature_key)
        if not text:
            text = f"{self._species_label}|{self._phenotype_summary}"
        return sum(ord(ch) for ch in text) % 97

    def _draw_texture_overlay(self, painter: QPainter, body: QRectF, kind: str) -> None:
        detail = self._detail_level()
        if detail == 1:
            if self._summary_has("\u0441\u043a\u043e\u0440\u043e\u0441\u0442\u044c", "\u0432\u044b\u0441\u043e\u043a") or self._summary_has("\u0431\u044b\u0441\u0442\u0440"):
                painter.setPen(QPen(QColor("#8aa2b8"), 1.0))
                painter.drawLine(QPointF(body.left() - body.width() * 0.22, body.center().y()), QPointF(body.left() - body.width() * 0.12, body.center().y()))
            return

        seed = self._variant_seed
        accent = self._detail_color(44 if detail == 2 else 58)
        painter.setPen(QPen(accent, 0.9))

        pattern = seed % 3
        if pattern == 0:
            for idx in range(3):
                y = body.top() + body.height() * (0.28 + idx * 0.18)
                painter.drawLine(
                    QPointF(body.left() + body.width() * 0.18, y),
                    QPointF(body.right() - body.width() * 0.14, y),
                )
        elif pattern == 1:
            for idx in range(4):
                x = body.left() + body.width() * (0.22 + idx * 0.16)
                painter.drawEllipse(QPointF(x, body.center().y()), 2.0, 1.6)
        else:
            for idx in range(3):
                shift = 0.2 + idx * 0.22
                painter.drawLine(
                    QPointF(body.left() + body.width() * shift, body.top() + body.height() * 0.2),
                    QPointF(body.left() + body.width() * (shift + 0.08), body.bottom() - body.height() * 0.18),
                )

        if self._summary_has("скорость", "высок") or self._summary_has("быстр"):
            painter.setPen(QPen(QColor("#8aa2b8"), 1.1))
            for offset in (0.18, 0.32, 0.46):
                painter.drawLine(
                    QPointF(body.left() - body.width() * offset, body.center().y() - body.height() * 0.12),
                    QPointF(body.left() - body.width() * (offset - 0.08), body.center().y() - body.height() * 0.12),
                )

        if kind == "turtle":
            painter.setPen(QPen(QColor("#64748b"), 1.1))
            painter.drawEllipse(body.adjusted(body.width() * 0.18, body.height() * 0.2, -body.width() * 0.22, -body.height() * 0.24))

    def _draw_nutrition_marker(self, painter: QPainter, card: QRectF) -> None:
        if self._mode == "mini":
            return

        label = self._nutrition_label()
        if label == "не указано":
            return

        marker = QRectF(card.right() - 54, card.top() + 12, 38, 22)
        painter.save()
        painter.setPen(QPen(QColor("#d4c5ad"), 1))
        painter.setBrush(QColor("#fffaf0"))
        painter.drawRoundedRect(marker, 7, 7)
        painter.setPen(QColor("#4b5563"))
        font = QFont(painter.font())
        font.setPointSize(8 if self._mode == "compact" else 9)
        font.setBold(True)
        painter.setFont(font)
        painter.drawText(marker, Qt.AlignCenter, self._nutrition_short_label(label))
        painter.restore()

    def _draw_badges(self, painter: QPainter, card: QRectF) -> None:
        if self._mode == "mini":
            text = f"{self._short_species()} | {self._color_label()} | {self._size_label()}"
            badge = QRectF(card.left() + 10, card.bottom() - 24, card.width() - 20, 16)
            painter.setPen(QPen(QColor("#d4c5ad"), 1))
            painter.setBrush(QColor("#fffaf0"))
            painter.drawRoundedRect(badge, 5, 5)
            painter.setPen(QColor("#4b5563"))
            painter.drawText(badge.adjusted(6, 0, -6, 0), Qt.AlignVCenter | Qt.AlignLeft, text)
            return

        color = self._color_label()
        size = self._size_label()
        wings = "есть" if self._has_wings() else "нет"

        badges = [
            f"Вид: {self._short_species()}",
            f"Цвет: {color}",
            f"Размер: {size}",
            f"Крылья: {wings}",
        ]

        chip_w = (card.width() - 32) / 2
        chip_h = 20 if self._mode == "large" else 18
        start_x = card.left() + 10
        start_y = card.bottom() - (48 if self._mode == "large" else 40)

        for idx, text in enumerate(badges):
            col = idx % 2
            row = idx // 2
            chip = QRectF(
                start_x + col * (chip_w + 8),
                start_y + row * (chip_h + 4),
                chip_w,
                chip_h,
            )

            painter.setPen(QPen(QColor("#d4c5ad"), 1))
            painter.setBrush(QColor("#fffaf0"))
            painter.drawRoundedRect(chip, 6, 6)

            painter.setPen(QColor("#4b5563"))
            painter.drawText(chip.adjusted(6, 0, -6, 0), Qt.AlignVCenter | Qt.AlignLeft, text)

    def _nutrition_label(self) -> str:
        text = self._phenotype_nutrition.casefold()
        if "смеш" in text or ("хищ" in text and "трав" in text):
            return "смешанный"
        if "хищ" in text:
            return "хищный"
        if "трав" in text:
            return "травоядный"
        return "не указано"

    @staticmethod
    def _nutrition_short_label(label: str) -> str:
        if label == "хищный":
            return "Х"
        if label == "травоядный":
            return "Т"
        if label == "смешанный":
            return "С"
        return "?"

    def _detail_label(self) -> str:
        summary = self._phenotype_summary.casefold()
        details = [
            ("плавник", ("плавник",)),
            ("панцирь", ("панцир",)),
            ("клешни", ("клеш",)),
            ("раковина", ("раков", "моллюск")),
            ("шерсть", ("шерст",)),
            ("скорость", ("скор", "быстр")),
            ("шипы", ("шип",)),
        ]
        for label, tokens in details:
            if any(token in summary for token in tokens):
                return label
        return "см. фенотип"

    def _summary_has(self, *tokens: str) -> bool:
        summary = self._phenotype_summary.casefold()
        return all(token.casefold() in summary for token in tokens)

    def _short_species(self) -> str:
        limit = 18 if self._mode == "large" else 14
        text = self._species_label.strip()
        if len(text) <= limit:
            return text
        return text[: limit - 1] + "…"

    def _color_label(self) -> str:
        labels = {
            "green": "зелёный",
            "blue": "синий",
            "red": "красный",
            "yellow": "жёлтый",
            "purple": "фиолетовый",
            "orange": "оранжевый",
            "white": "белый",
            "black": "чёрный",
        }
        return labels.get(self._color_token(), "нейтральный")

    def _size_label(self) -> str:
        text = self._phenotype_size.casefold()
        if "компакт" in text:
            return "компактный"
        if "круп" in text:
            return "крупный"
        if "сред" in text or "промеж" in text:
            return "средний"
        return "не указан"


from __future__ import annotations

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

        self._mode = "large"
        self.set_mode(mode)

    def set_mode(self, mode: str) -> None:
        normalized = (mode or "large").strip().lower()
        if normalized not in self.MODES:
            normalized = "large"
        self._mode = normalized

        if normalized == "large":
            self.setMinimumSize(252, 214)
            self.setMaximumHeight(245)
        elif normalized == "compact":
            self.setMinimumSize(196, 166)
            self.setMaximumHeight(188)
        else:
            self.setMinimumSize(152, 132)
            self.setMaximumHeight(150)

        self.updateGeometry()
        self.update()

    def sizeHint(self) -> QSize:  # noqa: N802
        if self._mode == "large":
            return QSize(264, 224)
        if self._mode == "compact":
            return QSize(208, 178)
        return QSize(164, 140)

    def minimumSizeHint(self) -> QSize:  # noqa: N802
        if self._mode == "large":
            return QSize(242, 206)
        if self._mode == "compact":
            return QSize(190, 160)
        return QSize(146, 126)

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

        card = QRectF(self.rect()).adjusted(6, 6, -6, -6)
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
        color = self._phenotype_color.casefold()
        if "зел" in color:
            base = QColor("#7ebf8b")
        elif "син" in color:
            base = QColor("#7fa8cf")
        else:
            base = QColor("#9dafaa")

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

    def _outline_pen(self, width: float = 1.8) -> QPen:
        return QPen(QColor("#334155"), width)

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

    def _draw_sketch_shadow(self, painter: QPainter, body: QRectF) -> None:
        painter.save()
        shadow = QColor("#d8c7ad")
        shadow.setAlpha(80)
        painter.setPen(Qt.NoPen)
        painter.setBrush(shadow)
        painter.drawEllipse(
            QRectF(
                body.left() + body.width() * 0.08,
                body.bottom() - body.height() * 0.04,
                body.width() * 0.84,
                body.height() * 0.18,
            )
        )
        painter.restore()

    def _draw_cartilaginous_fish(self, painter: QPainter, body: QRectF) -> None:
        painter.save()
        fill = self._base_fill_color()
        painter.setPen(self._outline_pen(1.7))
        painter.setBrush(fill)

        core = QPainterPath()
        core.moveTo(body.left() + body.width() * 0.02, body.center().y())
        core.cubicTo(
            body.left() + body.width() * 0.18,
            body.top() + body.height() * 0.03,
            body.right() - body.width() * 0.22,
            body.top() - body.height() * 0.08,
            body.right(),
            body.center().y() - body.height() * 0.02,
        )
        core.cubicTo(
            body.right() - body.width() * 0.2,
            body.bottom() + body.height() * 0.06,
            body.left() + body.width() * 0.18,
            body.bottom() - body.height() * 0.02,
            body.left() + body.width() * 0.02,
            body.center().y(),
        )
        painter.drawPath(core)

        tail = QPainterPath()
        tail.moveTo(body.left() + body.width() * 0.04, body.center().y())
        tail.lineTo(body.left() - body.width() * 0.22, body.top() + body.height() * 0.04)
        tail.lineTo(body.left() - body.width() * 0.15, body.center().y())
        tail.lineTo(body.left() - body.width() * 0.22, body.bottom() - body.height() * 0.04)
        tail.closeSubpath()
        painter.drawPath(tail)

        fin_height = 0.55 if self._summary_has("заостр") else 0.38
        dorsal = QPainterPath()
        dorsal.moveTo(body.left() + body.width() * 0.42, body.top() + body.height() * 0.08)
        dorsal.lineTo(body.left() + body.width() * 0.52, body.top() - body.height() * fin_height)
        dorsal.lineTo(body.left() + body.width() * 0.64, body.top() + body.height() * 0.12)
        dorsal.closeSubpath()
        painter.drawPath(dorsal)

        painter.setBrush(fill.lighter(110))
        for x_mul, y_mul, sign in ((0.44, 0.72, -1), (0.66, 0.70, 1)):
            fin = QPainterPath()
            x = body.left() + body.width() * x_mul
            y = body.top() + body.height() * y_mul
            fin.moveTo(x, y)
            fin.lineTo(x + body.width() * 0.12 * sign, y + body.height() * 0.34)
            fin.lineTo(x + body.width() * 0.19 * sign, y + body.height() * 0.05)
            fin.closeSubpath()
            painter.drawPath(fin)

        painter.setPen(QPen(QColor("#4b6475"), 1.0))
        for offset in (0.11, 0.16, 0.21):
            painter.drawLine(
                QPointF(body.right() - body.width() * 0.25, body.center().y() - body.height() * offset),
                QPointF(body.right() - body.width() * 0.2, body.center().y() + body.height() * (offset - 0.04)),
            )
        painter.drawLine(
            QPointF(body.right() - body.width() * 0.08, body.center().y() + body.height() * 0.12),
            QPointF(body.right() - body.width() * 0.01, body.center().y() + body.height() * 0.09),
        )
        painter.setPen(self._outline_pen())
        self._draw_eye(painter, QPointF(body.right() - body.width() * 0.16, body.center().y() - body.height() * 0.13))
        painter.restore()

    def _draw_bony_fish(self, painter: QPainter, body: QRectF) -> None:
        painter.save()
        fill = self._base_fill_color()
        painter.setPen(self._outline_pen(1.7))
        painter.setBrush(fill)

        fish_body = QRectF(body.left() + body.width() * 0.08, body.top(), body.width() * 0.78, body.height())
        shape = QPainterPath()
        shape.moveTo(fish_body.left(), fish_body.center().y())
        shape.cubicTo(
            fish_body.left() + fish_body.width() * 0.18,
            fish_body.top() - fish_body.height() * 0.05,
            fish_body.right() - fish_body.width() * 0.18,
            fish_body.top() - fish_body.height() * 0.08,
            fish_body.right(),
            fish_body.center().y(),
        )
        shape.cubicTo(
            fish_body.right() - fish_body.width() * 0.18,
            fish_body.bottom() + fish_body.height() * 0.08,
            fish_body.left() + fish_body.width() * 0.18,
            fish_body.bottom() + fish_body.height() * 0.05,
            fish_body.left(),
            fish_body.center().y(),
        )
        painter.drawPath(shape)

        painter.setBrush(fill.lighter(108))
        tail = QPainterPath()
        tail.moveTo(fish_body.left(), fish_body.center().y())
        tail.cubicTo(body.left() - body.width() * 0.12, fish_body.top(), body.left() - body.width() * 0.18, fish_body.top() + fish_body.height() * 0.18, fish_body.left() - body.width() * 0.02, fish_body.center().y())
        tail.cubicTo(body.left() - body.width() * 0.18, fish_body.bottom() - fish_body.height() * 0.18, body.left() - body.width() * 0.12, fish_body.bottom(), fish_body.left(), fish_body.center().y())
        painter.drawPath(tail)

        top_fin = QPainterPath()
        top_fin.moveTo(fish_body.center().x() - fish_body.width() * 0.14, fish_body.top() + fish_body.height() * 0.08)
        top_fin.quadTo(fish_body.center().x(), fish_body.top() - fish_body.height() * 0.24, fish_body.center().x() + fish_body.width() * 0.18, fish_body.top() + fish_body.height() * 0.11)
        painter.drawPath(top_fin)

        bottom_fin = QPainterPath()
        bottom_fin.moveTo(fish_body.center().x() - fish_body.width() * 0.02, fish_body.bottom() - fish_body.height() * 0.1)
        bottom_fin.quadTo(fish_body.center().x() + fish_body.width() * 0.08, fish_body.bottom() + fish_body.height() * 0.24, fish_body.center().x() + fish_body.width() * 0.18, fish_body.bottom() - fish_body.height() * 0.12)
        painter.drawPath(bottom_fin)

        painter.setPen(QPen(QColor("#5b7088"), 1.0))
        for shift in (0.20, 0.34, 0.48, 0.62):
            arc = QRectF(fish_body.left() + fish_body.width() * shift, fish_body.top() + fish_body.height() * 0.17, fish_body.width() * 0.23, fish_body.height() * 0.66)
            painter.drawArc(arc, 70 * 16, 220 * 16)
        painter.setPen(self._outline_pen())
        self._draw_eye(painter, QPointF(fish_body.right() - fish_body.width() * 0.17, fish_body.center().y() - fish_body.height() * 0.12))
        painter.restore()

    def _draw_crustacean(self, painter: QPainter, body: QRectF) -> None:
        painter.save()
        fill = self._base_fill_color()
        painter.setPen(self._outline_pen(1.6))
        painter.setBrush(fill)

        segments = []
        for idx, scale in enumerate((0.74, 0.86, 0.98, 0.84)):
            x = body.left() + body.width() * (0.14 + idx * 0.17)
            seg = QRectF(x, body.top() + body.height() * (0.5 - scale * 0.28), body.width() * 0.22, body.height() * scale * 0.56)
            segments.append(seg)
            painter.drawEllipse(seg)

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

        painter.setPen(QPen(QColor("#334155"), 1.2))
        for idx in range(4):
            seg = segments[min(idx, len(segments) - 1)]
            for side in (-1, 1):
                start = QPointF(seg.center().x(), seg.bottom() - seg.height() * 0.16)
                mid = QPointF(start.x() + side * body.width() * 0.12, start.y() + body.height() * 0.16)
                end = QPointF(mid.x() + side * body.width() * 0.08, mid.y() + body.height() * 0.06)
                painter.drawLine(start, mid)
                painter.drawLine(mid, end)

        painter.drawLine(QPointF(head.right() - head.width() * 0.18, head.top() + head.height() * 0.18), QPointF(head.right() + body.width() * 0.12, head.top() - body.height() * 0.12))
        painter.drawLine(QPointF(head.right() - head.width() * 0.08, head.top() + head.height() * 0.24), QPointF(head.right() + body.width() * 0.16, head.top() + body.height() * 0.02))
        self._draw_eye(painter, QPointF(head.right() - head.width() * 0.24, head.center().y() - head.height() * 0.16))
        painter.restore()

    def _draw_mollusk(self, painter: QPainter, body: QRectF) -> None:
        painter.save()
        fill = self._base_fill_color()
        shell_fill = fill.darker(106)
        painter.setPen(self._outline_pen(1.6))
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
        painter.drawEllipse(head)
        painter.drawLine(QPointF(head.center().x(), head.top()), QPointF(head.center().x() + body.width() * 0.08, head.top() - body.height() * 0.16))
        painter.drawLine(QPointF(head.center().x() - head.width() * 0.15, head.top() + head.height() * 0.12), QPointF(head.center().x() - body.width() * 0.02, head.top() - body.height() * 0.12))
        self._draw_eye(painter, QPointF(head.right() - head.width() * 0.28, head.center().y() - head.height() * 0.12))
        painter.restore()

    def _draw_turtle(self, painter: QPainter, body: QRectF) -> None:
        painter.save()
        fill = self._base_fill_color()
        painter.setPen(self._outline_pen(1.7))
        painter.setBrush(fill)

        shell = QRectF(body.left() + body.width() * 0.12, body.top() + body.height() * 0.08, body.width() * 0.64, body.height() * 0.72)
        shell_path = QPainterPath()
        shell_path.moveTo(shell.left(), shell.center().y())
        shell_path.cubicTo(shell.left() + shell.width() * 0.12, shell.top() - shell.height() * 0.08, shell.right() - shell.width() * 0.1, shell.top() - shell.height() * 0.08, shell.right(), shell.center().y())
        shell_path.cubicTo(shell.right() - shell.width() * 0.08, shell.bottom() + shell.height() * 0.08, shell.left() + shell.width() * 0.12, shell.bottom() + shell.height() * 0.05, shell.left(), shell.center().y())
        painter.drawPath(shell_path)

        painter.setPen(QPen(QColor("#5f7288"), 1.1))
        inner = shell.adjusted(shell.width() * 0.15, shell.height() * 0.18, -shell.width() * 0.15, -shell.height() * 0.18)
        painter.drawEllipse(inner)
        painter.drawLine(QPointF(shell.left() + shell.width() * 0.18, shell.center().y()), QPointF(shell.right() - shell.width() * 0.18, shell.center().y()))
        painter.drawLine(QPointF(shell.center().x(), shell.top() + shell.height() * 0.16), QPointF(shell.center().x(), shell.bottom() - shell.height() * 0.14))
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
        painter.drawEllipse(head)
        self._draw_eye(painter, QPointF(head.center().x() + head.width() * 0.14, head.center().y() - head.height() * 0.12))

        foot_w = shell.width() * 0.18
        foot_h = shell.height() * 0.22
        feet = [
            QRectF(shell.left() + shell.width() * 0.02, shell.top() + shell.height() * 0.08, foot_w, foot_h),
            QRectF(shell.right() - shell.width() * 0.18, shell.top() + shell.height() * 0.08, foot_w, foot_h),
            QRectF(shell.left() + shell.width() * 0.04, shell.bottom() - shell.height() * 0.22, foot_w, foot_h),
            QRectF(shell.right() - shell.width() * 0.2, shell.bottom() - shell.height() * 0.22, foot_w, foot_h),
        ]
        for foot in feet:
            painter.drawRoundedRect(foot, 7, 7)

        tail = QPainterPath()
        tail.moveTo(shell.left() - shell.width() * 0.01, shell.center().y())
        tail.lineTo(shell.left() - shell.width() * 0.13, shell.center().y() - shell.height() * 0.07)
        tail.lineTo(shell.left() - shell.width() * 0.12, shell.center().y() + shell.height() * 0.08)
        tail.closeSubpath()
        painter.drawPath(tail)
        painter.restore()

    def _draw_mammal(self, painter: QPainter, body: QRectF) -> None:
        painter.save()
        fill = self._base_fill_color()
        painter.setPen(self._outline_pen(1.7))
        painter.setBrush(fill)

        trunk = QRectF(body.left() + body.width() * 0.08, body.top() + body.height() * 0.18, body.width() * 0.58, body.height() * 0.54)
        painter.drawRoundedRect(trunk, 18, 18)

        head = QRectF(trunk.right() - trunk.width() * 0.02, trunk.top() - trunk.height() * 0.02, trunk.width() * 0.42, trunk.height() * 0.55)
        painter.drawEllipse(head)

        for x_mul in (0.24, 0.72):
            ear = QPainterPath()
            x = head.left() + head.width() * x_mul
            ear.moveTo(x, head.top() + head.height() * 0.16)
            ear.lineTo(x + head.width() * (0.14 if x_mul > 0.5 else -0.14), head.top() - head.height() * 0.24)
            ear.lineTo(x + head.width() * (0.22 if x_mul < 0.5 else -0.22), head.top() + head.height() * 0.02)
            ear.closeSubpath()
            painter.drawPath(ear)

        tail = QPainterPath()
        tail.moveTo(trunk.left() + trunk.width() * 0.04, trunk.center().y() - trunk.height() * 0.04)
        tail.cubicTo(trunk.left() - trunk.width() * 0.22, trunk.top() + trunk.height() * 0.12, trunk.left() - trunk.width() * 0.28, trunk.bottom() - trunk.height() * 0.22, trunk.left() - trunk.width() * 0.1, trunk.bottom() - trunk.height() * 0.18)
        painter.drawPath(tail)

        self._draw_eye(painter, QPointF(head.center().x() + head.width() * 0.16, head.center().y() - head.height() * 0.12))
        painter.setPen(QPen(QColor("#334155"), 1.0))
        painter.drawLine(QPointF(head.right() - head.width() * 0.14, head.center().y() + head.height() * 0.08), QPointF(head.right() - head.width() * 0.03, head.center().y() + head.height() * 0.1))

        painter.setPen(self._outline_pen(1.5))
        for shift in (0.14, 0.44, 0.66, 0.86):
            leg = QRectF(trunk.left() + trunk.width() * shift, trunk.bottom() - trunk.height() * 0.08, trunk.width() * 0.11, trunk.height() * 0.34)
            painter.drawRoundedRect(leg, 5, 5)

        painter.setPen(QPen(QColor("#516274"), 1.0))
        fur_shifts = (0.12, 0.22, 0.32, 0.46, 0.58, 0.7)
        if self._summary_has("шерст"):
            fur_shifts = (0.08, 0.16, 0.24, 0.32, 0.44, 0.56, 0.68, 0.8)
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
        seed = self._variant_seed
        accent = QColor("#4b5563")
        accent.setAlpha(60)
        painter.setPen(QPen(accent, 1.0))

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
        text = self._phenotype_color.casefold()
        if "зел" in text:
            return "зелёный"
        if "син" in text:
            return "синий"
        return "нейтральный"

    def _size_label(self) -> str:
        text = self._phenotype_size.casefold()
        if "компакт" in text:
            return "компактный"
        if "круп" in text:
            return "крупный"
        if "сред" in text or "промеж" in text:
            return "средний"
        return "не указан"


from __future__ import annotations

from typing import Any

from PySide6.QtCore import QPointF, QRectF, QSize, Qt
from PySide6.QtGui import QColor, QPainter, QPainterPath, QPen
from PySide6.QtWidgets import QWidget


class CreaturePortraitWidget(QWidget):
    MODES = {"large", "compact", "mini"}

    def __init__(self, parent: QWidget | None = None, mode: str = "large") -> None:
        super().__init__(parent)
        self.setObjectName("creaturePortrait")

        self._species_label = ""
        self._phenotype_color = ""
        self._phenotype_size = ""
        self._phenotype_wings = ""
        self._phenotype_nutrition = ""
        self._phenotype_summary = ""

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
        species_label: str,
        phenotype_color: str | None,
        phenotype_size: str | None,
        phenotype_wings: str | None,
        phenotype_nutrition: str | None,
        phenotype_summary: str | None,
    ) -> None:
        self._species_label = (species_label or "").strip()
        self._phenotype_color = (phenotype_color or "").strip()
        self._phenotype_size = (phenotype_size or "").strip()
        self._phenotype_wings = (phenotype_wings or "").strip()
        self._phenotype_nutrition = (phenotype_nutrition or "").strip()
        self._phenotype_summary = (phenotype_summary or "").strip()
        self.update()

    def clear(self) -> None:
        self.set_creature("", None, None, None, None, None)

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

        badges_space = 58 if self._mode == "large" else (42 if self._mode == "compact" else 32)
        draw_zone = card.adjusted(14, 14, -14, -badges_space)
        body = self._scaled_body_rect(draw_zone, self._resolve_scale())

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

        self._draw_badges(painter, card)

    def _draw_paper_card(self, painter: QPainter, rect: QRectF) -> None:
        painter.setPen(QPen(QColor("#d6ccb8"), 1.2))
        painter.setBrush(QColor("#fffdf7"))
        painter.drawRoundedRect(rect, 10, 10)

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
            return QColor("#7ebf8b")
        if "син" in color:
            return QColor("#7fa8cf")
        return QColor("#9dafaa")

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

    @staticmethod
    def _scaled_body_rect(area: QRectF, scale: float) -> QRectF:
        w = area.width() * 0.55 * scale
        h = area.height() * 0.40 * scale
        w = min(w, area.width() * 0.86)
        h = min(h, area.height() * 0.75)
        return QRectF(area.center().x() - w / 2, area.center().y() - h / 2, w, h)

    def _draw_cartilaginous_fish(self, painter: QPainter, body: QRectF) -> None:
        painter.setPen(self._outline_pen())
        painter.setBrush(self._base_fill_color())

        path = QPainterPath()
        path.moveTo(body.left() + body.width() * 0.06, body.center().y())
        path.cubicTo(
            body.left() + body.width() * 0.22,
            body.top() - body.height() * 0.18,
            body.right() - body.width() * 0.28,
            body.top() + body.height() * 0.05,
            body.right(),
            body.center().y(),
        )
        path.cubicTo(
            body.right() - body.width() * 0.28,
            body.bottom() - body.height() * 0.05,
            body.left() + body.width() * 0.22,
            body.bottom() + body.height() * 0.18,
            body.left() + body.width() * 0.06,
            body.center().y(),
        )
        painter.drawPath(path)

        tail = QPainterPath()
        tail.moveTo(body.left() + body.width() * 0.05, body.center().y())
        tail.lineTo(body.left() - body.width() * 0.22, body.top() + body.height() * 0.12)
        tail.lineTo(body.left() - body.width() * 0.2, body.bottom() - body.height() * 0.12)
        tail.closeSubpath()
        painter.drawPath(tail)

        fin_height = 0.45 if self._summary_has("заостр") else 0.32
        fin = QPainterPath()
        fin.moveTo(body.center().x() - body.width() * 0.04, body.top() + body.height() * 0.08)
        fin.lineTo(body.center().x() + body.width() * 0.08, body.top() - body.height() * fin_height)
        fin.lineTo(body.center().x() + body.width() * 0.18, body.top() + body.height() * 0.1)
        fin.closeSubpath()
        painter.drawPath(fin)

        self._draw_eye(painter, QPointF(body.right() - body.width() * 0.18, body.center().y() - body.height() * 0.12))
        painter.drawArc(
            QRectF(body.right() - body.width() * 0.26, body.center().y() - body.height() * 0.2, body.width() * 0.12, body.height() * 0.4),
            70 * 16,
            220 * 16,
        )

    def _draw_bony_fish(self, painter: QPainter, body: QRectF) -> None:
        painter.setPen(self._outline_pen())
        painter.setBrush(self._base_fill_color())

        painter.drawEllipse(body)

        tail = QPainterPath()
        tail.moveTo(body.left(), body.center().y())
        tail.lineTo(body.left() - body.width() * 0.24, body.top() + body.height() * 0.07)
        tail.lineTo(body.left() - body.width() * 0.24, body.bottom() - body.height() * 0.07)
        tail.closeSubpath()
        painter.drawPath(tail)

        top_fin = QPainterPath()
        top_fin.moveTo(body.center().x() - body.width() * 0.1, body.top() + body.height() * 0.06)
        top_fin.quadTo(
            body.center().x(),
            body.top() - body.height() * 0.26,
            body.center().x() + body.width() * 0.16,
            body.top() + body.height() * 0.12,
        )
        painter.drawPath(top_fin)

        painter.setPen(QPen(QColor("#5b7088"), 1))
        for shift in (0.18, 0.34, 0.5):
            arc = QRectF(
                body.left() + body.width() * shift,
                body.top() + body.height() * 0.2,
                body.width() * 0.3,
                body.height() * 0.6,
            )
            painter.drawArc(arc, 65 * 16, 230 * 16)

        painter.setPen(self._outline_pen())
        self._draw_eye(painter, QPointF(body.right() - body.width() * 0.2, body.center().y() - body.height() * 0.1))

    def _draw_crustacean(self, painter: QPainter, body: QRectF) -> None:
        painter.setPen(self._outline_pen())
        painter.setBrush(self._base_fill_color())

        left_seg = QRectF(body.left(), body.top() + body.height() * 0.2, body.width() * 0.3, body.height() * 0.6)
        mid_seg = QRectF(body.left() + body.width() * 0.24, body.top() + body.height() * 0.15, body.width() * 0.34, body.height() * 0.7)
        right_seg = QRectF(body.left() + body.width() * 0.54, body.top() + body.height() * 0.2, body.width() * 0.3, body.height() * 0.6)
        painter.drawEllipse(left_seg)
        painter.drawEllipse(mid_seg)
        painter.drawEllipse(right_seg)

        claw_len = 0.26 if self._summary_has("длин") else 0.2
        for direction in (-1, 1):
            base_x = mid_seg.center().x() + direction * mid_seg.width() * 0.48
            base_y = mid_seg.top() + mid_seg.height() * 0.35
            painter.drawLine(
                QPointF(base_x, base_y),
                QPointF(base_x + direction * body.width() * claw_len, base_y - body.height() * 0.25),
            )

            claw = QPainterPath()
            claw.moveTo(base_x + direction * body.width() * claw_len, base_y - body.height() * 0.25)
            claw.lineTo(base_x + direction * body.width() * (claw_len + 0.1), base_y - body.height() * 0.35)
            claw.lineTo(base_x + direction * body.width() * (claw_len + 0.02), base_y - body.height() * 0.12)
            claw.closeSubpath()
            painter.drawPath(claw)

        painter.setPen(QPen(QColor("#334155"), 1.3))
        for idx in range(4):
            y = body.top() + body.height() * (0.22 + idx * 0.18)
            painter.drawLine(
                QPointF(mid_seg.left() - body.width() * 0.02, y),
                QPointF(body.left() - body.width() * 0.2, y + 5),
            )
            painter.drawLine(
                QPointF(mid_seg.right() + body.width() * 0.02, y),
                QPointF(body.right() + body.width() * 0.2, y + 5),
            )

    def _draw_mollusk(self, painter: QPainter, body: QRectF) -> None:
        painter.setPen(self._outline_pen())
        painter.setBrush(self._base_fill_color())

        shell = QRectF(body.left() + body.width() * 0.08, body.top() + body.height() * 0.08, body.width() * 0.54, body.height() * 0.82)
        painter.drawEllipse(shell)

        painter.setPen(QPen(QColor("#64748b"), 1.2))
        spiral = QPainterPath()
        spiral.moveTo(shell.center())
        spiral.cubicTo(
            shell.center().x() + shell.width() * 0.22,
            shell.center().y() - shell.height() * 0.12,
            shell.center().x() + shell.width() * 0.1,
            shell.top() + shell.height() * 0.05,
            shell.left() + shell.width() * 0.22,
            shell.top() + shell.height() * 0.2,
        )
        spiral.cubicTo(
            shell.left() + shell.width() * 0.02,
            shell.top() + shell.height() * 0.34,
            shell.left() + shell.width() * 0.14,
            shell.bottom() - shell.height() * 0.14,
            shell.center().x() + shell.width() * 0.06,
            shell.bottom() - shell.height() * 0.12,
        )
        painter.drawPath(spiral)

        painter.setPen(self._outline_pen())
        soft = QRectF(body.left() + body.width() * 0.46, body.top() + body.height() * 0.46, body.width() * 0.5, body.height() * 0.32)
        painter.setBrush(self._base_fill_color().lighter(108))
        painter.drawRoundedRect(soft, 9, 9)
        self._draw_eye(painter, QPointF(soft.right() - soft.width() * 0.14, soft.center().y() - soft.height() * 0.18))

    def _draw_turtle(self, painter: QPainter, body: QRectF) -> None:
        painter.setPen(self._outline_pen())
        painter.setBrush(self._base_fill_color())

        shell = QRectF(body.left() + body.width() * 0.08, body.top() + body.height() * 0.14, body.width() * 0.72, body.height() * 0.68)
        painter.drawEllipse(shell)

        painter.setPen(QPen(QColor("#5f7288"), 1.1))
        painter.drawArc(shell.adjusted(shell.width() * 0.14, shell.height() * 0.2, -shell.width() * 0.14, -shell.height() * 0.2), 0, 360 * 16)
        painter.drawLine(
            QPointF(shell.left() + shell.width() * 0.25, shell.center().y()),
            QPointF(shell.right() - shell.width() * 0.25, shell.center().y()),
        )
        painter.drawLine(
            QPointF(shell.center().x(), shell.top() + shell.height() * 0.18),
            QPointF(shell.center().x(), shell.bottom() - shell.height() * 0.18),
        )

        if self._summary_has("шип"):
            painter.setPen(self._outline_pen(1.4))
            for shift in (0.2, 0.35, 0.5, 0.65):
                x = shell.left() + shell.width() * shift
                spike = QPainterPath()
                spike.moveTo(x, shell.top() + shell.height() * 0.08)
                spike.lineTo(x + shell.width() * 0.04, shell.top() - shell.height() * 0.08)
                spike.lineTo(x + shell.width() * 0.08, shell.top() + shell.height() * 0.1)
                spike.closeSubpath()
                painter.drawPath(spike)

        painter.setPen(self._outline_pen())
        head = QRectF(shell.right() - shell.width() * 0.02, shell.center().y() - shell.height() * 0.14, shell.width() * 0.24, shell.height() * 0.28)
        painter.drawEllipse(head)
        self._draw_eye(painter, QPointF(head.center().x() + head.width() * 0.14, head.center().y() - head.height() * 0.12))

        foot_w = shell.width() * 0.2
        foot_h = shell.height() * 0.2
        feet = [
            QRectF(shell.left() + shell.width() * 0.08, shell.top() - foot_h * 0.22, foot_w, foot_h),
            QRectF(shell.right() - shell.width() * 0.28, shell.top() - foot_h * 0.22, foot_w, foot_h),
            QRectF(shell.left() + shell.width() * 0.08, shell.bottom() - foot_h * 0.76, foot_w, foot_h),
            QRectF(shell.right() - shell.width() * 0.28, shell.bottom() - foot_h * 0.76, foot_w, foot_h),
        ]
        for foot in feet:
            painter.drawRoundedRect(foot, 7, 7)

        tail = QPainterPath()
        tail.moveTo(shell.left() - shell.width() * 0.02, shell.center().y())
        tail.lineTo(shell.left() - shell.width() * 0.14, shell.center().y() - shell.height() * 0.08)
        tail.lineTo(shell.left() - shell.width() * 0.14, shell.center().y() + shell.height() * 0.08)
        tail.closeSubpath()
        painter.drawPath(tail)

    def _draw_mammal(self, painter: QPainter, body: QRectF) -> None:
        painter.setPen(self._outline_pen())
        painter.setBrush(self._base_fill_color())

        trunk = QRectF(body.left() + body.width() * 0.04, body.top() + body.height() * 0.12, body.width() * 0.66, body.height() * 0.62)
        head = QRectF(trunk.right() - trunk.width() * 0.02, trunk.top() + trunk.height() * 0.08, trunk.width() * 0.38, trunk.height() * 0.5)

        painter.drawRoundedRect(trunk, 18, 18)
        painter.drawEllipse(head)

        ear_l = QPainterPath()
        ear_l.moveTo(head.left() + head.width() * 0.22, head.top() + head.height() * 0.12)
        ear_l.lineTo(head.left() + head.width() * 0.1, head.top() - head.height() * 0.26)
        ear_l.lineTo(head.left() + head.width() * 0.35, head.top() - head.height() * 0.04)
        ear_l.closeSubpath()
        painter.drawPath(ear_l)

        ear_r = QPainterPath()
        ear_r.moveTo(head.right() - head.width() * 0.2, head.top() + head.height() * 0.12)
        ear_r.lineTo(head.right() - head.width() * 0.05, head.top() - head.height() * 0.24)
        ear_r.lineTo(head.right() - head.width() * 0.3, head.top() - head.height() * 0.04)
        ear_r.closeSubpath()
        painter.drawPath(ear_r)

        self._draw_eye(painter, QPointF(head.center().x() + head.width() * 0.16, head.center().y() - head.height() * 0.12))

        for shift in (0.12, 0.36, 0.58, 0.8):
            leg = QRectF(
                trunk.left() + trunk.width() * shift,
                trunk.bottom() - trunk.height() * 0.12,
                trunk.width() * 0.12,
                trunk.height() * 0.3,
            )
            painter.drawRoundedRect(leg, 4, 4)

        if self._summary_has("шерсть"):
            painter.setPen(QPen(QColor("#516274"), 1))
            for shift in (0.15, 0.25, 0.35, 0.45, 0.55):
                x = trunk.left() + trunk.width() * shift
                painter.drawLine(
                    QPointF(x, trunk.top() + trunk.height() * 0.03),
                    QPointF(x + trunk.width() * 0.05, trunk.top() - trunk.height() * 0.1),
                )

        if self._summary_has("скорость", "высок") or self._summary_has("быстр"):
            painter.setPen(QPen(QColor("#94a3b8"), 1.3))
            for offset in (0.18, 0.32, 0.46):
                painter.drawLine(
                    QPointF(trunk.left() - trunk.width() * offset, trunk.center().y()),
                    QPointF(trunk.left() - trunk.width() * (offset - 0.08), trunk.center().y()),
                )

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
        wing_fill = QColor("#e7eefb")
        wing_fill.setAlpha(230)
        painter.setBrush(wing_fill)
        painter.setPen(QPen(QColor("#7b8da8"), 1.4))

        left = QPainterPath()
        left.moveTo(body.left() + body.width() * 0.2, body.top() + body.height() * 0.18)
        left.cubicTo(
            body.left() - body.width() * 0.32,
            body.top() - body.height() * 0.25,
            body.left() - body.width() * 0.24,
            body.bottom() - body.height() * 0.14,
            body.left() + body.width() * 0.24,
            body.center().y(),
        )
        painter.drawPath(left)

        right = QPainterPath()
        right.moveTo(body.right() - body.width() * 0.2, body.top() + body.height() * 0.18)
        right.cubicTo(
            body.right() + body.width() * 0.32,
            body.top() - body.height() * 0.25,
            body.right() + body.width() * 0.24,
            body.bottom() - body.height() * 0.14,
            body.right() - body.width() * 0.24,
            body.center().y(),
        )
        painter.drawPath(right)

    @staticmethod
    def _draw_eye(painter: QPainter, center: QPointF) -> None:
        painter.setBrush(QColor("#f8fafc"))
        painter.setPen(QPen(QColor("#334155"), 1.2))
        painter.drawEllipse(center, 3.6, 3.2)
        painter.setBrush(QColor("#111827"))
        painter.drawEllipse(center, 1.2, 1.2)

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

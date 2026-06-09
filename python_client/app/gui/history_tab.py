from __future__ import annotations

from datetime import date, datetime
from typing import Any

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QAbstractItemView,
    QComboBox,
    QFormLayout,
    QFrame,
    QHeaderView,
    QHBoxLayout,
    QLabel,
    QMessageBox,
    QPushButton,
    QTableWidget,
    QTableWidgetItem,
    QVBoxLayout,
    QWidget,
)

from app.db.pkg_api import PkgApi
from app.services.display_names import (
    display_creature_name,
    display_mutation_name,
    display_value,
    experiment_type_label,
)
from app.services.oracle_errors import map_oracle_error
from app.services.session_state import SessionState


class HistoryTab(QWidget):
    def __init__(self, pkg_api: PkgApi, state: SessionState) -> None:
        super().__init__()
        self.pkg_api = pkg_api
        self.state = state

        self._rows: list[dict[str, Any]] = []
        self._build_ui()

    def _build_ui(self) -> None:
        root = QVBoxLayout(self)
        root.setContentsMargins(8, 8, 8, 8)
        root.setSpacing(10)

        heading_row = QHBoxLayout()
        heading = QVBoxLayout()

        title = QLabel("История экспериментов")
        title.setObjectName("title")
        subtitle = QLabel("Лабораторный журнал скрещиваний, мутаций и мутагенных воздействий")
        subtitle.setObjectName("subtitle")
        heading.addWidget(title)
        heading.addWidget(subtitle)

        self.history_help_label = QLabel(
            "\u0416\u0443\u0440\u043d\u0430\u043b \u0445\u0440\u0430\u043d\u0438\u0442 \u0441\u043a\u0440\u0435\u0449\u0438\u0432\u0430\u043d\u0438\u044f, \u043c\u0443\u0442\u0430\u0446\u0438\u0438 \u0438 \u043c\u0443\u0442\u0430\u0433\u0435\u043d\u043d\u044b\u0435 \u0432\u043e\u0437\u0434\u0435\u0439\u0441\u0442\u0432\u0438\u044f. "
            "\u041f\u043e \u043d\u0435\u043c\u0443 \u0443\u0434\u043e\u0431\u043d\u043e \u0432\u043e\u0441\u0441\u0442\u0430\u043d\u043e\u0432\u0438\u0442\u044c, \u043a\u0430\u043a \u043f\u043e\u044f\u0432\u0438\u043b\u0438\u0441\u044c \u0441\u0443\u0449\u0435\u0441\u0442\u0432\u0430 \u0438 \u043f\u0440\u0438\u0437\u043d\u0430\u043a\u0438."
        )
        self.history_help_label.setProperty("helpCard", True)
        self.history_help_label.setWordWrap(True)
        heading.addWidget(self.history_help_label)

        heading_row.addLayout(heading)
        heading_row.addStretch()

        filter_label = QLabel("Фильтр:")
        self.type_filter_combo = QComboBox()
        self.type_filter_combo.setToolTip("\u041e\u0441\u0442\u0430\u0432\u044c\u0442\u0435 \u0432\u0441\u0435 \u0437\u0430\u043f\u0438\u0441\u0438 \u0438\u043b\u0438 \u0432\u044b\u0431\u0435\u0440\u0438\u0442\u0435 \u043e\u0434\u0438\u043d \u0442\u0438\u043f \u0441\u043e\u0431\u044b\u0442\u0438\u044f \u0436\u0443\u0440\u043d\u0430\u043b\u0430.")
        self.type_filter_combo.addItem("Все", None)
        self.type_filter_combo.addItem("Генетические эксперименты", "CROSS")
        self.type_filter_combo.addItem("Мутации", "MUTATION")
        self.type_filter_combo.addItem("Мутагены", "MUTAGEN")
        self.type_filter_combo.currentIndexChanged.connect(self.refresh_data)

        self.refresh_btn = QPushButton("Обновить историю")
        self.refresh_btn.setProperty("role", "secondary")
        self.refresh_btn.clicked.connect(self.refresh_data)

        heading_row.addWidget(filter_label)
        heading_row.addWidget(self.type_filter_combo)
        heading_row.addWidget(self.refresh_btn)

        root.addLayout(heading_row)

        table_card = QFrame()
        table_card.setProperty("card", "true")
        table_card.setObjectName("journalListCard")
        table_layout = QVBoxLayout(table_card)
        table_layout.setContentsMargins(12, 12, 12, 12)
        table_layout.setSpacing(8)

        self.history_table = QTableWidget(0, 6)
        self.history_table.setHorizontalHeaderLabels(
            [
                "Дата/время",
                "Тип",
                "Исходное существо A",
                "Исходное существо B",
                "Результат",
                "Мутация/воздействие",
            ]
        )
        self.history_table.verticalHeader().setVisible(False)
        self.history_table.verticalHeader().setDefaultSectionSize(38)
        self.history_table.setEditTriggers(QAbstractItemView.NoEditTriggers)
        self.history_table.setSelectionBehavior(QAbstractItemView.SelectRows)
        self.history_table.setSelectionMode(QAbstractItemView.SingleSelection)
        self.history_table.horizontalHeader().setStretchLastSection(False)
        h_header = self.history_table.horizontalHeader()
        h_header.setSectionResizeMode(0, QHeaderView.ResizeMode.ResizeToContents)
        h_header.setSectionResizeMode(1, QHeaderView.ResizeMode.ResizeToContents)
        h_header.setSectionResizeMode(2, QHeaderView.ResizeMode.Stretch)
        h_header.setSectionResizeMode(3, QHeaderView.ResizeMode.Stretch)
        h_header.setSectionResizeMode(4, QHeaderView.ResizeMode.Stretch)
        h_header.setSectionResizeMode(5, QHeaderView.ResizeMode.Stretch)
        self.history_table.setAlternatingRowColors(True)
        self.history_table.itemSelectionChanged.connect(self._on_history_selected)

        table_layout.addWidget(self.history_table)

        self.empty_history_hint = QLabel("")
        self.empty_history_hint.setObjectName("subtitle")
        self.empty_history_hint.setProperty("emptyState", True)
        self.empty_history_hint.setWordWrap(True)
        table_layout.addWidget(self.empty_history_hint)

        root.addWidget(table_card)

        detail_card = QFrame()
        detail_card.setProperty("card", "true")
        detail_card.setObjectName("journalCard")
        detail_layout = QFormLayout(detail_card)
        detail_layout.setContentsMargins(12, 12, 12, 12)
        detail_layout.setLabelAlignment(Qt.AlignRight)

        detail_title = QLabel("Запись лабораторного журнала")
        detail_title.setObjectName("journalTitle")
        detail_layout.addRow("", detail_title)

        self.lbl_type = QLabel("-")
        self.lbl_parent1 = QLabel("-")
        self.lbl_parent2 = QLabel("-")
        self.lbl_offspring = QLabel("-")
        self.lbl_mutation = QLabel("-")
        self.lbl_created_at = QLabel("-")
        self.lbl_rating_note = QLabel("-")

        self.lbl_parent1.setWordWrap(True)
        self.lbl_parent2.setWordWrap(True)
        self.lbl_offspring.setWordWrap(True)
        self.lbl_mutation.setWordWrap(True)
        self.lbl_rating_note.setWordWrap(True)

        detail_layout.addRow("Тип эксперимента:", self.lbl_type)
        detail_layout.addRow("Исходное существо A:", self.lbl_parent1)
        detail_layout.addRow("Исходное существо B:", self.lbl_parent2)
        detail_layout.addRow("Результат:", self.lbl_offspring)
        detail_layout.addRow("Мутация:", self.lbl_mutation)
        detail_layout.addRow("Дата/время:", self.lbl_created_at)
        detail_layout.addRow("Справка по рейтингу:", self.lbl_rating_note)

        root.addWidget(detail_card)

    def refresh_data(self) -> None:
        lab_id = self.state.selected_lab_id
        if lab_id is None:
            QMessageBox.warning(self, "История экспериментов", "Сначала выберите лабораторию.")
            return

        selected_experiment_id = self._selected_experiment_id()
        experiment_type = self.type_filter_combo.currentData()

        try:
            self._rows = self.pkg_api.get_experiment_history(lab_id, experiment_type)
        except Exception as exc:
            QMessageBox.critical(self, "Ошибка истории", map_oracle_error(exc))
            return

        self._fill_table(selected_experiment_id)

    def _fill_table(self, selected_experiment_id: int | None = None) -> None:
        self.history_table.blockSignals(True)
        self.history_table.setRowCount(0)

        selected_row_idx = 0

        for row_idx, row in enumerate(self._rows):
            self.history_table.insertRow(row_idx)

            experiment_id = self._to_int(row.get("experiment_id"))
            type_code = self._display(row.get("experiment_type"))
            type_label = experiment_type_label(type_code, with_code=False)
            type_display = self._type_marker_text(type_code, type_label)

            parent1_name = self._entity_name(row.get("parent1_name"))
            parent2_name = self._entity_name(row.get("parent2_name"))
            offspring_name = self._entity_name(row.get("offspring_name"))
            mutation_text = self._mutation_brief_text(row)

            self._set_table_item(row_idx, 0, self._display_datetime(row.get("created_at")), center=True)
            self._set_table_item(row_idx, 1, type_display, center=True)
            self._set_table_item(row_idx, 2, parent1_name, tooltip=self._entity_text(row.get("parent1_id"), row.get("parent1_name")))
            self._set_table_item(row_idx, 3, parent2_name, tooltip=self._entity_text(row.get("parent2_id"), row.get("parent2_name")))
            self._set_table_item(row_idx, 4, offspring_name, tooltip=self._entity_text(row.get("offspring_id"), row.get("offspring_name")))
            self._set_table_item(row_idx, 5, mutation_text, tooltip=self._mutation_detail_text(row))

            if selected_experiment_id is not None and experiment_id == selected_experiment_id:
                selected_row_idx = row_idx

        if self.history_table.rowCount() > 0:
            self.history_table.selectRow(selected_row_idx)
            self.empty_history_hint.setText("")
        else:
            self._clear_detail_card()
            self.empty_history_hint.setText(
                "История пока пуста. Проведите эксперимент, мутацию или мутагенное воздействие."
            )

        self.history_table.blockSignals(False)
        self._on_history_selected()

    def _on_history_selected(self) -> None:
        row = self._selected_row()
        if row is None:
            self._clear_detail_card()
            return

        type_code = self._display(row.get("experiment_type"))
        type_ru = experiment_type_label(type_code, with_code=False)
        self.lbl_type.setText(self._type_marker_text(type_code, type_ru))
        self._apply_type_chip(type_code)

        self.lbl_parent1.setText(self._entity_text(row.get("parent1_id"), row.get("parent1_name")))
        self.lbl_parent2.setText(self._entity_text(row.get("parent2_id"), row.get("parent2_name")))
        self.lbl_offspring.setText(self._entity_text(row.get("offspring_id"), row.get("offspring_name")))

        mutation_id = self._to_int(row.get("mutation_id"))
        mutation_name = display_mutation_name(row.get("mutation_name"))
        if mutation_id is None:
            self.lbl_mutation.setText("Без мутации")
        else:
            self.lbl_mutation.setText(f"{mutation_id} | {mutation_name}")

        created_at_text = self._display_datetime(row.get("created_at"))
        self.lbl_created_at.setText(created_at_text)

        self.lbl_rating_note.setText(self._rating_reference_text(row))

    def _rating_reference_text(self, row: dict[str, Any]) -> str:
        exp_type = self._display(row.get("experiment_type")).upper()

        if exp_type == "MUTATION":
            raw_effect = row.get("rating_effect")
            if raw_effect is not None:
                return (
                    f"Справка: для этой мутации базовый эффект рейтинга {raw_effect}. "
                    "Итог может измениться из-за автозавершения заданий."
                )
            return "Итоговое изменение рейтинга может включать награды за задания."

        if exp_type == "MUTAGEN":
            mutagen_hint = self._detect_mutagen_subtype(row)
            if mutagen_hint == "RADIATION":
                return "Справка: RADIATION обычно даёт cost 50 и базовый штраф рейтинга -5."
            if mutagen_hint == "CHEMICAL":
                return "Справка: CHEMICAL обычно даёт cost 100 и базовый штраф рейтинга -2."
            return (
                "Справка: для мутагенов действуют базовые правила RADIATION (50 / -5) "
                "и CHEMICAL (100 / -2). Итоговое изменение рейтинга может включать награды за задания."
            )

        return "Итоговое изменение рейтинга может включать награды за задания."

    def _detect_mutagen_subtype(self, row: dict[str, Any]) -> str | None:
        # Mutagen subtype can be absent as a separate field.
        for key in ("mutagen_type", "mutation_name", "offspring_name"):
            value = self._display(row.get(key)).lower()
            if "radiation" in value:
                return "RADIATION"
            if "chemical" in value:
                return "CHEMICAL"
        return None

    def _entity_name(self, entity_name: Any) -> str:
        name = display_creature_name(entity_name)
        return "Нет данных" if name == "Не указано" else name

    def _mutation_brief_text(self, row: dict[str, Any]) -> str:
        mutation_name = display_mutation_name(row.get("mutation_name"))
        if mutation_name != "Не указано":
            return mutation_name

        exp_type = self._display(row.get("experiment_type")).upper()
        if exp_type == "MUTAGEN":
            hint = self._detect_mutagen_subtype(row)
            if hint == "RADIATION":
                return "Радиационный мутаген"
            if hint == "CHEMICAL":
                return "Химический мутаген"
            return "Мутагенное воздействие"

        return "Без мутации"

    def _mutation_detail_text(self, row: dict[str, Any]) -> str:
        mutation_id = self._display(row.get("mutation_id"))
        mutation_name = display_mutation_name(row.get("mutation_name"))
        if mutation_name == "Не указано":
            mutation_name = self._mutation_brief_text(row)
        return f"ID мутации: {mutation_id}\nОписание: {mutation_name}"

    def _selected_row(self) -> dict[str, Any] | None:
        row_idx = self.history_table.currentRow()
        if row_idx < 0 or row_idx >= len(self._rows):
            return None
        return self._rows[row_idx]

    def _selected_experiment_id(self) -> int | None:
        row = self._selected_row()
        if row is None:
            return None
        return self._to_int(row.get("experiment_id"))

    def _clear_detail_card(self) -> None:
        self.lbl_type.setText("-")
        self.lbl_type.setProperty("typechip", "")
        self.lbl_type.style().unpolish(self.lbl_type)
        self.lbl_type.style().polish(self.lbl_type)
        self.lbl_parent1.setText("-")
        self.lbl_parent2.setText("-")
        self.lbl_offspring.setText("-")
        self.lbl_mutation.setText("-")
        self.lbl_created_at.setText("-")
        self.lbl_rating_note.setText("-")

    def _type_marker_text(self, type_code: str, type_ru: str) -> str:
        code = (type_code or "").upper()
        if code == "CROSS":
            return f"[СКР] {type_ru}"
        if code == "MUTATION":
            return f"[МУТ] {type_ru}"
        if code == "MUTAGEN":
            return f"[МГН] {type_ru}"
        return type_ru

    def _apply_type_chip(self, type_code: str) -> None:
        code = (type_code or "").upper()
        chip = ""
        if code == "CROSS":
            chip = "cross"
        elif code == "MUTATION":
            chip = "mutation"
        elif code == "MUTAGEN":
            chip = "mutagen"

        self.lbl_type.setProperty("typechip", chip)
        self.lbl_type.style().unpolish(self.lbl_type)
        self.lbl_type.style().polish(self.lbl_type)

    def _set_table_item(
        self,
        row: int,
        col: int,
        value: Any,
        center: bool = False,
        tooltip: str | None = None,
    ) -> None:
        text = self._display(value)
        item = QTableWidgetItem(text)
        if center:
            item.setTextAlignment(Qt.AlignCenter)
        item.setToolTip(tooltip if tooltip else text)
        self.history_table.setItem(row, col, item)

    @staticmethod
    def _display(value: Any) -> str:
        return display_value(value)

    @staticmethod
    def _to_int(value: Any) -> int | None:
        if value is None:
            return None
        try:
            return int(value)
        except (TypeError, ValueError):
            return None

    @staticmethod
    def _display_datetime(value: Any) -> str:
        if value is None:
            return "Нет данных"
        if isinstance(value, datetime):
            return value.strftime("%d.%m.%Y %H:%M:%S")
        if isinstance(value, date):
            return value.strftime("%d.%m.%Y")
        text = str(value).strip()
        return text if text else "Нет данных"

    def _entity_text(self, entity_id: Any, entity_name: Any) -> str:
        value_id = self._to_int(entity_id)
        value_name = display_creature_name(entity_name)

        if value_id is None and value_name == "Не указано":
            return "Нет данных"
        if value_id is None:
            return value_name
        if value_name == "Не указано":
            return str(value_id)
        return f"{value_id} | {value_name}"

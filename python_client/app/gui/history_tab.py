from __future__ import annotations

from datetime import date, datetime
from typing import Any

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QAbstractItemView,
    QComboBox,
    QFormLayout,
    QFrame,
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
from app.services.oracle_errors import map_oracle_error
from app.services.session_state import SessionState


_EXPERIMENT_TYPE_LABELS = {
    "CROSS": "Генетический эксперимент",
    "MUTATION": "Мутация",
    "MUTAGEN": "Мутаген",
}


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
        subtitle = QLabel("Журнал генетических экспериментов, мутаций и мутагенных воздействий")
        subtitle.setObjectName("subtitle")

        heading.addWidget(title)
        heading.addWidget(subtitle)

        heading_row.addLayout(heading)
        heading_row.addStretch()

        filter_label = QLabel("Фильтр:")
        self.type_filter_combo = QComboBox()
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
        table_layout = QVBoxLayout(table_card)
        table_layout.setContentsMargins(12, 12, 12, 12)
        table_layout.setSpacing(8)

        self.history_table = QTableWidget(0, 11)
        self.history_table.setHorizontalHeaderLabels(
            [
                "ID",
                "Тип",
                "ID существа A",
                "Имя существа A",
                "ID существа B",
                "Имя существа B",
                "ID результата",
                "Имя результата",
                "ID мутации",
                "Название мутации",
                "Дата/время",
            ]
        )
        self.history_table.verticalHeader().setVisible(False)
        self.history_table.setEditTriggers(QAbstractItemView.NoEditTriggers)
        self.history_table.setSelectionBehavior(QAbstractItemView.SelectRows)
        self.history_table.setSelectionMode(QAbstractItemView.SingleSelection)
        self.history_table.horizontalHeader().setStretchLastSection(True)
        self.history_table.setAlternatingRowColors(True)
        self.history_table.itemSelectionChanged.connect(self._on_history_selected)

        table_layout.addWidget(self.history_table)
        root.addWidget(table_card)

        detail_card = QFrame()
        detail_card.setProperty("card", "true")
        detail_layout = QFormLayout(detail_card)
        detail_layout.setContentsMargins(12, 12, 12, 12)
        detail_layout.setLabelAlignment(Qt.AlignRight)

        detail_title = QLabel("Карточка записи")
        detail_title.setObjectName("subtitle")
        detail_layout.addRow("", detail_title)

        self.lbl_type = QLabel("-")
        self.lbl_parent1 = QLabel("-")
        self.lbl_parent2 = QLabel("-")
        self.lbl_offspring = QLabel("-")
        self.lbl_mutation = QLabel("-")
        self.lbl_created_at = QLabel("-")

        self.lbl_parent1.setWordWrap(True)
        self.lbl_parent2.setWordWrap(True)
        self.lbl_offspring.setWordWrap(True)
        self.lbl_mutation.setWordWrap(True)

        detail_layout.addRow("Тип эксперимента:", self.lbl_type)
        detail_layout.addRow("Исходное существо A:", self.lbl_parent1)
        detail_layout.addRow("Исходное существо B:", self.lbl_parent2)
        detail_layout.addRow("Результат:", self.lbl_offspring)
        detail_layout.addRow("Мутация:", self.lbl_mutation)
        detail_layout.addRow("Дата/время:", self.lbl_created_at)

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
            type_label = self._experiment_type_ru(type_code)
            if type_code == "Не указано":
                type_display = type_label
            else:
                type_display = f"{type_label} ({type_code})"

            self._set_table_item(row_idx, 0, experiment_id, center=True)
            self._set_table_item(row_idx, 1, type_display, center=True)
            self._set_table_item(row_idx, 2, row.get("parent1_id"), center=True)
            self._set_table_item(row_idx, 3, row.get("parent1_name"))
            self._set_table_item(row_idx, 4, row.get("parent2_id"), center=True)
            self._set_table_item(row_idx, 5, row.get("parent2_name"))
            self._set_table_item(row_idx, 6, row.get("offspring_id"), center=True)
            self._set_table_item(row_idx, 7, row.get("offspring_name"))
            self._set_table_item(row_idx, 8, row.get("mutation_id"), center=True)
            self._set_table_item(row_idx, 9, row.get("mutation_name"))
            self._set_table_item(row_idx, 10, self._display_datetime(row.get("created_at")), center=True)

            if selected_experiment_id is not None and experiment_id == selected_experiment_id:
                selected_row_idx = row_idx

        if self.history_table.rowCount() > 0:
            self.history_table.selectRow(selected_row_idx)
        else:
            self._clear_detail_card()

        self.history_table.blockSignals(False)
        self._on_history_selected()

    def _on_history_selected(self) -> None:
        row = self._selected_row()
        if row is None:
            self._clear_detail_card()
            return

        type_code = self._display(row.get("experiment_type"))
        type_ru = self._experiment_type_ru(type_code)
        if type_code == "Не указано":
            self.lbl_type.setText(type_ru)
        else:
            self.lbl_type.setText(f"{type_ru} ({type_code})")

        self.lbl_parent1.setText(self._entity_text(row.get("parent1_id"), row.get("parent1_name")))
        self.lbl_parent2.setText(self._entity_text(row.get("parent2_id"), row.get("parent2_name")))
        self.lbl_offspring.setText(self._entity_text(row.get("offspring_id"), row.get("offspring_name")))

        mutation_id = self._to_int(row.get("mutation_id"))
        mutation_name = self._display(row.get("mutation_name"))
        if mutation_id is None:
            self.lbl_mutation.setText("Без мутации")
        else:
            self.lbl_mutation.setText(f"{mutation_id} | {mutation_name}")

        created_at_text = self._display_datetime(row.get("created_at"))
        if created_at_text == "Нет данных":
            self.lbl_created_at.setText("Нет данных")
        else:
            self.lbl_created_at.setText(created_at_text)

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
        self.lbl_parent1.setText("-")
        self.lbl_parent2.setText("-")
        self.lbl_offspring.setText("-")
        self.lbl_mutation.setText("-")
        self.lbl_created_at.setText("-")

    def _set_table_item(self, row: int, col: int, value: Any, center: bool = False) -> None:
        item = QTableWidgetItem(self._display(value))
        if center:
            item.setTextAlignment(Qt.AlignCenter)
        self.history_table.setItem(row, col, item)

    @staticmethod
    def _display(value: Any) -> str:
        if value is None:
            return "Не указано"
        text = str(value).strip()
        return text if text else "Не указано"

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

    @staticmethod
    def _experiment_type_ru(type_code: str) -> str:
        upper_code = (type_code or "").upper()
        return _EXPERIMENT_TYPE_LABELS.get(upper_code, "Неизвестный тип")

    def _entity_text(self, entity_id: Any, entity_name: Any) -> str:
        value_id = self._to_int(entity_id)
        value_name = self._display(entity_name)

        if value_id is None and value_name == "Не указано":
            return "Нет данных"
        if value_id is None:
            return value_name
        if value_name == "Не указано":
            return str(value_id)
        return f"{value_id} | {value_name}"

from __future__ import annotations

from typing import Any, Callable

import oracledb
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
    QSplitter,
    QTableWidget,
    QTableWidgetItem,
    QVBoxLayout,
    QWidget,
)

from app.db.pkg_api import PkgApi
from app.services.oracle_errors import map_oracle_error
from app.services.session_state import SessionState


_SPECIES_LABELS = {
    1: "Хрящевые рыбы",
    2: "Костные рыбы",
    3: "Ракообразные",
    4: "Моллюски",
    5: "Черепахи",
    6: "Млекопитающие",
}

_STATUS_LABELS = {
    "ACTIVE": "Активно",
    "COMPLETED": "Выполнено",
}


class TasksTab(QWidget):
    def __init__(
        self,
        pkg_api: PkgApi,
        state: SessionState,
        on_lab_data_changed: Callable[[], None] | None = None,
    ) -> None:
        super().__init__()
        self.pkg_api = pkg_api
        self.state = state
        self.on_lab_data_changed = on_lab_data_changed

        self._tasks: list[dict[str, Any]] = []
        self._visible_tasks: list[dict[str, Any]] = []
        self._creatures: list[dict[str, Any]] = []
        self._creature_by_id: dict[int, dict[str, Any]] = {}

        self._last_check_result: int | None = None

        self._build_ui()

    def _build_ui(self) -> None:
        root = QVBoxLayout(self)
        root.setContentsMargins(8, 8, 8, 8)
        root.setSpacing(10)

        heading_row = QHBoxLayout()
        heading_col = QVBoxLayout()

        title = QLabel("Задания")
        title.setObjectName("title")
        subtitle = QLabel("Лабораторные задачи: проверка существа и завершение с наградой")
        subtitle.setObjectName("subtitle")
        heading_col.addWidget(title)
        heading_col.addWidget(subtitle)

        self.refresh_tasks_btn = QPushButton("Обновить задания")
        self.refresh_tasks_btn.setProperty("role", "secondary")
        self.refresh_tasks_btn.clicked.connect(self.refresh_data)

        heading_row.addLayout(heading_col)
        heading_row.addStretch()
        heading_row.addWidget(self.refresh_tasks_btn)

        root.addLayout(heading_row)

        splitter = QSplitter(Qt.Horizontal)

        left_card = QFrame()
        left_card.setProperty("card", "true")
        left_layout = QVBoxLayout(left_card)
        left_layout.setContentsMargins(12, 12, 12, 12)
        left_layout.setSpacing(8)

        filter_row = QHBoxLayout()
        filter_title = QLabel("Список заданий")
        filter_title.setObjectName("subtitle")
        filter_row.addWidget(filter_title)
        filter_row.addStretch()

        filter_label = QLabel("Показать:")
        self.status_filter_combo = QComboBox()
        self.status_filter_combo.addItem("Все", "ALL")
        self.status_filter_combo.addItem("Активные", "ACTIVE")
        self.status_filter_combo.addItem("Выполненные", "COMPLETED")
        self.status_filter_combo.currentIndexChanged.connect(self._on_filter_changed)

        filter_row.addWidget(filter_label)
        filter_row.addWidget(self.status_filter_combo)

        left_layout.addLayout(filter_row)

        self.tasks_table = QTableWidget(0, 9)
        self.tasks_table.setHorizontalHeaderLabels(
            [
                "ID записи",
                "ID задания",
                "Название",
                "Описание",
                "Награда (монеты)",
                "Награда (рейтинг)",
                "Статус",
                "Назначено",
                "Завершено",
            ]
        )
        self.tasks_table.verticalHeader().setVisible(False)
        self.tasks_table.setEditTriggers(QAbstractItemView.NoEditTriggers)
        self.tasks_table.setSelectionBehavior(QAbstractItemView.SelectRows)
        self.tasks_table.setSelectionMode(QAbstractItemView.SingleSelection)
        self.tasks_table.horizontalHeader().setStretchLastSection(True)
        self.tasks_table.setAlternatingRowColors(True)
        self.tasks_table.itemSelectionChanged.connect(self._on_task_selected)

        left_layout.addWidget(self.tasks_table)

        self.empty_tasks_hint = QLabel("")
        self.empty_tasks_hint.setObjectName("subtitle")
        self.empty_tasks_hint.setWordWrap(True)
        left_layout.addWidget(self.empty_tasks_hint)

        splitter.addWidget(left_card)

        right_panel = QWidget()
        right_layout = QVBoxLayout(right_panel)
        right_layout.setContentsMargins(0, 0, 0, 0)
        right_layout.setSpacing(10)

        task_info_card = QFrame()
        task_info_card.setProperty("card", "true")
        task_info_layout = QFormLayout(task_info_card)
        task_info_layout.setContentsMargins(12, 12, 12, 12)
        task_info_layout.setLabelAlignment(Qt.AlignRight)

        task_title = QLabel("Описание задания")
        task_title.setObjectName("subtitle")
        task_info_layout.addRow("", task_title)

        self.task_name_label = QLabel("-")
        self.task_desc_label = QLabel("-")
        self.task_desc_label.setWordWrap(True)
        self.task_desc_label.setMinimumHeight(54)
        self.task_reward_money_label = QLabel("-")
        self.task_reward_rating_label = QLabel("-")
        self.task_status_label = QLabel("-")

        task_info_layout.addRow("Название:", self.task_name_label)
        task_info_layout.addRow("Описание:", self.task_desc_label)
        task_info_layout.addRow("Награда (монеты):", self.task_reward_money_label)
        task_info_layout.addRow("Награда (рейтинг):", self.task_reward_rating_label)
        task_info_layout.addRow("Статус:", self.task_status_label)

        right_layout.addWidget(task_info_card)

        creature_card = QFrame()
        creature_card.setProperty("card", "true")
        creature_layout = QFormLayout(creature_card)
        creature_layout.setContentsMargins(12, 12, 12, 12)
        creature_layout.setLabelAlignment(Qt.AlignRight)

        creature_title = QLabel("Проверка существа")
        creature_title.setObjectName("subtitle")
        creature_layout.addRow("", creature_title)

        self.creature_combo = QComboBox()
        self.creature_combo.currentIndexChanged.connect(self._on_creature_changed)

        self.creature_id_label = QLabel("-")
        self.creature_name_label = QLabel("-")
        self.creature_species_label = QLabel("-")
        self.creature_phenotype_label = QLabel("-")
        self.creature_phenotype_label.setWordWrap(True)
        self.creature_phenotype_label.setMinimumHeight(48)

        creature_layout.addRow("Существо:", self.creature_combo)
        creature_layout.addRow("ID:", self.creature_id_label)
        creature_layout.addRow("Имя:", self.creature_name_label)
        creature_layout.addRow("Вид:", self.creature_species_label)
        creature_layout.addRow("Фенотип:", self.creature_phenotype_label)

        right_layout.addWidget(creature_card)

        action_card = QFrame()
        action_card.setProperty("card", "true")
        action_layout = QVBoxLayout(action_card)
        action_layout.setContentsMargins(12, 12, 12, 12)
        action_layout.setSpacing(8)

        action_title = QLabel("Результат проверки")
        action_title.setObjectName("subtitle")
        action_layout.addWidget(action_title)

        buttons_row = QHBoxLayout()
        self.check_btn = QPushButton("Проверить выполнение")
        self.check_btn.setProperty("role", "secondary")
        self.check_btn.clicked.connect(self.check_selected_task)

        self.complete_btn = QPushButton("Завершить задание")
        self.complete_btn.clicked.connect(self.complete_selected_task)

        buttons_row.addWidget(self.check_btn)
        buttons_row.addWidget(self.complete_btn)
        action_layout.addLayout(buttons_row)

        self.status_hint_label = QLabel("Выберите активное задание и существо.")
        self.status_hint_label.setObjectName("subtitle")
        self.status_hint_label.setWordWrap(True)
        action_layout.addWidget(self.status_hint_label)

        right_layout.addWidget(action_card)

        right_layout.addStretch()

        splitter.addWidget(right_panel)
        splitter.setStretchFactor(0, 3)
        splitter.setStretchFactor(1, 2)

        root.addWidget(splitter)

    def refresh_data(self) -> None:
        selected_task_id = self._selected_task_id()
        selected_creature_id = self._to_int(self.creature_combo.currentData())

        self._load_tasks(selected_task_id)
        self._load_creatures(selected_creature_id)

    def _load_tasks(self, selected_task_id: int | None = None) -> None:
        lab_id = self.state.selected_lab_id
        if lab_id is None:
            QMessageBox.warning(self, "Задания", "Сначала выберите лабораторию.")
            return

        try:
            self._tasks = self.pkg_api.get_tasks(lab_id)
        except Exception as exc:
            QMessageBox.critical(self, "Ошибка загрузки заданий", map_oracle_error(exc))
            return

        self._fill_tasks_table(selected_task_id)

    def _load_creatures(self, selected_creature_id: int | None = None) -> None:
        lab_id = self.state.selected_lab_id
        if lab_id is None:
            return

        try:
            self._creatures = self.pkg_api.get_creatures(lab_id)
        except Exception as exc:
            QMessageBox.critical(self, "Ошибка загрузки существ", map_oracle_error(exc))
            return

        self._creature_by_id = {}
        for creature in self._creatures:
            creature_id = self._to_int(creature.get("creature_id"))
            if creature_id is not None:
                self._creature_by_id[creature_id] = creature

        self._fill_creature_combo(selected_creature_id)

    def _fill_tasks_table(self, selected_task_id: int | None = None) -> None:
        filter_value = self.status_filter_combo.currentData()
        self._visible_tasks = []

        for task in self._tasks:
            task_status = str(task.get("task_status") or "").upper()
            if filter_value == "ACTIVE" and task_status != "ACTIVE":
                continue
            if filter_value == "COMPLETED" and task_status != "COMPLETED":
                continue
            self._visible_tasks.append(task)

        self.tasks_table.blockSignals(True)
        self.tasks_table.setRowCount(0)

        selected_row_idx = 0

        for row_idx, task in enumerate(self._visible_tasks):
            self.tasks_table.insertRow(row_idx)
            self._set_table_item(self.tasks_table, row_idx, 0, task.get("lab_task_id"), center=True)
            self._set_table_item(self.tasks_table, row_idx, 1, task.get("task_id"), center=True)
            self._set_table_item(self.tasks_table, row_idx, 2, task.get("task_name"))
            self._set_table_item(self.tasks_table, row_idx, 3, task.get("description"))
            self._set_table_item(self.tasks_table, row_idx, 4, task.get("reward_money"), center=True)
            self._set_table_item(self.tasks_table, row_idx, 5, task.get("reward_rating"), center=True)
            self._set_table_item(
                self.tasks_table,
                row_idx,
                6,
                self._status_display(task.get("task_status")),
                center=True,
            )
            self._set_table_item(self.tasks_table, row_idx, 7, task.get("created_at"), center=True)
            self._set_table_item(self.tasks_table, row_idx, 8, task.get("completed_at"), center=True)

            if selected_task_id is not None and self._to_int(task.get("task_id")) == selected_task_id:
                selected_row_idx = row_idx

        if self.tasks_table.rowCount() > 0:
            self.tasks_table.selectRow(selected_row_idx)
            self.empty_tasks_hint.setText("")
        else:
            self._clear_task_card()
            self._update_empty_tasks_hint(filter_value)

        self.tasks_table.blockSignals(False)
        self._on_task_selected()

    def _fill_creature_combo(self, selected_creature_id: int | None = None) -> None:
        self.creature_combo.blockSignals(True)
        self.creature_combo.clear()
        self.creature_combo.addItem("Выберите существо...", None)

        selected_index = 0

        for creature in self._creatures:
            creature_id = self._to_int(creature.get("creature_id"))
            if creature_id is None:
                continue

            name = self._display(creature.get("creature_name"))
            species = self._species_text(creature.get("species_type"))
            self.creature_combo.addItem(f"{creature_id} | {name} | {species}", creature_id)

            if selected_creature_id is not None and creature_id == selected_creature_id:
                selected_index = self.creature_combo.count() - 1

        self.creature_combo.setCurrentIndex(selected_index)
        self.creature_combo.blockSignals(False)
        self._on_creature_changed()

    def _on_filter_changed(self) -> None:
        selected_task_id = self._selected_task_id()
        self._fill_tasks_table(selected_task_id)

    def _on_task_selected(self) -> None:
        self._last_check_result = None

        task = self._selected_task()
        if task is None:
            self._clear_task_card()
            self._update_status_hint()
            return

        self.task_name_label.setText(self._display(task.get("task_name")))
        self.task_desc_label.setText(self._display(task.get("description")))
        self.task_reward_money_label.setText(self._display(task.get("reward_money")))
        self.task_reward_rating_label.setText(self._display(task.get("reward_rating")))
        self.task_status_label.setText(self._status_display(task.get("task_status")))

        self._update_status_hint()

    def _on_creature_changed(self) -> None:
        self._last_check_result = None

        creature_id = self._to_int(self.creature_combo.currentData())
        creature = self._creature_by_id.get(creature_id) if creature_id is not None else None

        if creature is None:
            self.creature_id_label.setText("-")
            self.creature_name_label.setText("-")
            self.creature_species_label.setText("-")
            self.creature_phenotype_label.setText("-")
            self._update_status_hint()
            return

        self.creature_id_label.setText(self._display(creature.get("creature_id")))
        self.creature_name_label.setText(self._display(creature.get("creature_name")))
        self.creature_species_label.setText(self._species_text(creature.get("species_type")))
        self.creature_phenotype_label.setText(self._display(creature.get("phenotype_summary")))

        self._update_status_hint()

    def check_selected_task(self) -> None:
        task = self._selected_task()
        if task is None:
            QMessageBox.warning(self, "Задания", "Выберите задание из списка.")
            return

        task_status = str(task.get("task_status") or "").upper()
        if task_status == "COMPLETED":
            self._last_check_result = 1
            self._update_status_hint()
            QMessageBox.information(self, "Задания", "Это задание уже выполнено.")
            return

        lab_id = self.state.selected_lab_id
        task_id = self._to_int(task.get("task_id"))
        creature_id = self._to_int(self.creature_combo.currentData())

        if lab_id is None or task_id is None:
            QMessageBox.warning(self, "Задания", "Некорректный контекст лаборатории или задания.")
            return

        if creature_id is None:
            QMessageBox.warning(self, "Задания", "Выберите существо для проверки задания.")
            return

        try:
            self._last_check_result = self.pkg_api.check_task(lab_id, task_id, creature_id)
        except Exception as exc:
            QMessageBox.critical(self, "Ошибка проверки", map_oracle_error(exc))
            return

        self._update_status_hint()

        if self._last_check_result == 1:
            QMessageBox.information(self, "Задания", "Существо подходит для выполнения задания.")
        else:
            QMessageBox.information(self, "Задания", "Выбранное существо не соответствует условиям задания.")

    def complete_selected_task(self) -> None:
        task = self._selected_task()
        if task is None:
            QMessageBox.warning(self, "Задания", "Выберите задание из списка.")
            return

        lab_id = self.state.selected_lab_id
        task_id = self._to_int(task.get("task_id"))
        creature_id = self._to_int(self.creature_combo.currentData())

        if lab_id is None or task_id is None:
            QMessageBox.warning(self, "Задания", "Некорректный контекст лаборатории или задания.")
            return

        if creature_id is None:
            QMessageBox.warning(self, "Задания", "Выберите существо для завершения задания.")
            return

        try:
            result = self.pkg_api.complete_task(lab_id, task_id, creature_id)
        except Exception as exc:
            code = self._oracle_error_code(exc)
            text = map_oracle_error(exc)

            if code in (-20063, -20064):
                QMessageBox.information(self, "Задания", text)
            else:
                QMessageBox.critical(self, "Ошибка завершения", text)
            return

        if self._to_int(result.get("is_completed")) == 1:
            QMessageBox.information(
                self,
                "Задания",
                (
                    "Задание успешно завершено. "
                    f"Текущий баланс: {self._display(result.get('wallet_after'))}, "
                    f"рейтинг: {self._display(result.get('rating_after'))}."
                ),
            )

        if self.on_lab_data_changed is not None:
            self.on_lab_data_changed()
        else:
            self.refresh_data()

    def _update_status_hint(self) -> None:
        task = self._selected_task()
        creature_id = self._to_int(self.creature_combo.currentData())

        if task is None or creature_id is None:
            self.status_hint_label.setText("Выберите активное задание и существо.")
            self.complete_btn.setEnabled(False)
            return

        task_status = str(task.get("task_status") or "").upper()
        if task_status == "COMPLETED":
            self.status_hint_label.setText("Задание уже выполнено.")
            self.complete_btn.setEnabled(False)
            return

        if self._last_check_result == 1:
            self.status_hint_label.setText("Существо подходит для выполнения задания.")
            self.complete_btn.setEnabled(True)
            return

        if self._last_check_result == 0:
            self.status_hint_label.setText("Существо не подходит для выполнения задания.")
            self.complete_btn.setEnabled(False)
            return

        self.status_hint_label.setText("Выберите активное задание и существо.")
        self.complete_btn.setEnabled(True)

    def _update_empty_tasks_hint(self, filter_value: str) -> None:
        if filter_value == "ACTIVE":
            completed_count = sum(1 for task in self._tasks if str(task.get("task_status") or "").upper() == "COMPLETED")
            if completed_count > 0:
                self.empty_tasks_hint.setText(
                    "Сейчас нет активных заданий. Возможно, все доступные задания выполнены. "
                    "Нажмите «Обновить задания» для актуализации списка."
                )
                return
        self.empty_tasks_hint.setText("По выбранному фильтру нет записей.")

    def _selected_task(self) -> dict[str, Any] | None:
        row_idx = self.tasks_table.currentRow()
        if row_idx < 0 or row_idx >= len(self._visible_tasks):
            return None
        return self._visible_tasks[row_idx]

    def _selected_task_id(self) -> int | None:
        task = self._selected_task()
        if task is None:
            return None
        return self._to_int(task.get("task_id"))

    def _clear_task_card(self) -> None:
        self.task_name_label.setText("-")
        self.task_desc_label.setText("-")
        self.task_reward_money_label.setText("-")
        self.task_reward_rating_label.setText("-")
        self.task_status_label.setText("-")

    @staticmethod
    def _set_table_item(table: QTableWidget, row: int, col: int, value: Any, center: bool = False) -> None:
        item = QTableWidgetItem(TasksTab._display(value))
        if center:
            item.setTextAlignment(Qt.AlignCenter)
        table.setItem(row, col, item)

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
    def _species_text(species_value: Any) -> str:
        species_id = TasksTab._to_int(species_value)
        if species_id is None:
            return "Не указано"
        return _SPECIES_LABELS.get(species_id, f"Тип {species_id}")

    @staticmethod
    def _status_display(status_value: Any) -> str:
        code = str(status_value).strip().upper() if status_value is not None else ""
        if code == "":
            return "Не указано"
        label = _STATUS_LABELS.get(code)
        if label is None:
            return code
        return f"{label} ({code})"

    @staticmethod
    def _oracle_error_code(exc: Exception) -> int | None:
        if not isinstance(exc, oracledb.DatabaseError):
            return None

        payload = exc.args[0]
        code = getattr(payload, "code", None)
        if code is None:
            return None

        try:
            return int(code)
        except (TypeError, ValueError):
            return None

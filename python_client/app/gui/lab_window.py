from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
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


class LabWindow(QWidget):
    def __init__(self, pkg_api: PkgApi, state: SessionState, on_open_lab, on_logout) -> None:
        super().__init__()
        self.pkg_api = pkg_api
        self.state = state
        self.on_open_lab = on_open_lab
        self.on_logout = on_logout

        self._labs: list[dict] = []

        self.setWindowTitle("БиоСборка - Лаборатории")
        self.setMinimumSize(860, 520)
        self._build_ui()

    def _build_ui(self) -> None:
        root = QVBoxLayout(self)
        root.setContentsMargins(20, 18, 20, 18)
        root.setSpacing(12)

        title = QLabel("Выбор лаборатории")
        title.setObjectName("title")
        subtitle = QLabel("Создайте новую лабораторию или откройте существующую")
        subtitle.setObjectName("subtitle")
        root.addWidget(title)
        root.addWidget(subtitle)

        card = QFrame()
        card.setProperty("card", "true")
        card_layout = QVBoxLayout(card)
        card_layout.setContentsMargins(12, 12, 12, 12)

        self.table = QTableWidget(0, 7)
        self.table.setHorizontalHeaderLabels([
            "Lab ID",
            "Wallet",
            "Rating",
            "Creatures",
            "Active Tasks",
            "Completed Tasks",
            "Experiments",
        ])
        self.table.setSelectionBehavior(QTableWidget.SelectRows)
        self.table.setSelectionMode(QTableWidget.SingleSelection)
        self.table.verticalHeader().setVisible(False)
        self.table.setEditTriggers(QTableWidget.NoEditTriggers)
        self.table.horizontalHeader().setStretchLastSection(True)
        card_layout.addWidget(self.table)

        root.addWidget(card)

        actions = QHBoxLayout()
        self.refresh_btn = QPushButton("Refresh")
        self.refresh_btn.setProperty("role", "secondary")
        self.refresh_btn.clicked.connect(self.refresh_labs)

        self.create_btn = QPushButton("Create Lab")
        self.create_btn.clicked.connect(self._create_lab)

        self.open_btn = QPushButton("Open Lab")
        self.open_btn.clicked.connect(self._open_selected_lab)

        self.logout_btn = QPushButton("Logout")
        self.logout_btn.setProperty("role", "secondary")
        self.logout_btn.clicked.connect(self.on_logout)

        actions.addWidget(self.refresh_btn)
        actions.addStretch()
        actions.addWidget(self.create_btn)
        actions.addWidget(self.open_btn)
        actions.addWidget(self.logout_btn)

        root.addLayout(actions)

    def refresh_labs(self) -> None:
        if self.state.user_id is None:
            QMessageBox.warning(self, "Session", "User context is not initialized.")
            return

        try:
            self._labs = self.pkg_api.list_user_labs(self.state.user_id)
        except Exception as exc:
            QMessageBox.critical(self, "Labs Error", map_oracle_error(exc))
            return

        self.table.setRowCount(0)

        for row_idx, lab in enumerate(self._labs):
            self.table.insertRow(row_idx)
            self._set_cell(row_idx, 0, lab.get("lab_id"))
            self._set_cell(row_idx, 1, lab.get("wallet"))
            self._set_cell(row_idx, 2, lab.get("rating"))
            self._set_cell(row_idx, 3, lab.get("creature_count"))
            self._set_cell(row_idx, 4, lab.get("active_task_count"))
            self._set_cell(row_idx, 5, lab.get("completed_task_count"))
            self._set_cell(row_idx, 6, lab.get("experiment_count"))

        if self.table.rowCount() > 0:
            self.table.selectRow(0)

    def _set_cell(self, row: int, col: int, value) -> None:
        text = "" if value is None else str(value)
        item = QTableWidgetItem(text)
        item.setTextAlignment(Qt.AlignCenter)
        self.table.setItem(row, col, item)

    def _create_lab(self) -> None:
        token = self.state.session_token
        if not token:
            QMessageBox.warning(self, "Session", "Session token is missing.")
            return

        try:
            new_lab_id = self.pkg_api.start_new_lab(token)
            self.refresh_labs()
            self._select_lab_by_id(new_lab_id)
            QMessageBox.information(self, "Create Lab", f"Lab {new_lab_id} created.")
        except Exception as exc:
            QMessageBox.critical(self, "Create Lab Error", map_oracle_error(exc))

    def _select_lab_by_id(self, lab_id: int) -> None:
        for row in range(self.table.rowCount()):
            item = self.table.item(row, 0)
            if item and item.text() == str(lab_id):
                self.table.selectRow(row)
                return

    def _open_selected_lab(self) -> None:
        token = self.state.session_token
        if not token:
            QMessageBox.warning(self, "Session", "Session token is missing.")
            return

        row = self.table.currentRow()
        if row < 0:
            QMessageBox.information(self, "Open Lab", "Select a lab first.")
            return

        lab_id_item = self.table.item(row, 0)
        if lab_id_item is None:
            QMessageBox.warning(self, "Open Lab", "Could not read lab ID.")
            return

        lab_id = int(lab_id_item.text())

        try:
            self.pkg_api.switch_lab(token, lab_id)
            self.state.set_selected_lab(lab_id)
            self.on_open_lab(lab_id)
        except Exception as exc:
            QMessageBox.critical(self, "Open Lab Error", map_oracle_error(exc))
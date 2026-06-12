from __future__ import annotations

from collections.abc import Callable

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QApplication,
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
    def __init__(
        self,
        pkg_api: PkgApi,
        state: SessionState,
        on_open_lab,
        on_logout,
        on_window_close: Callable[[], None],
        is_programmatic_close: Callable[[], bool],
    ) -> None:
        super().__init__()
        self.pkg_api = pkg_api
        self.state = state
        self.on_open_lab = on_open_lab
        self.on_logout = on_logout
        self.on_window_close = on_window_close
        self.is_programmatic_close = is_programmatic_close

        self._labs: list[dict] = []
        self._delete_in_progress = False

        self.setWindowTitle("БиоСборка — Лаборатории")
        self.setMinimumSize(900, 560)
        self._build_ui()

    def _build_ui(self) -> None:
        root = QVBoxLayout(self)
        root.setContentsMargins(20, 18, 20, 18)
        root.setSpacing(12)

        title = QLabel("Выбор лаборатории")
        title.setObjectName("title")
        subtitle = QLabel("Создайте новую лабораторию или откройте существующую")
        subtitle.setObjectName("subtitle")
        context_hint = QLabel("Лаборатория хранит ваших существ, задания, мутации и историю экспериментов.")
        context_hint.setObjectName("subtitle")
        context_hint.setWordWrap(True)

        root.addWidget(title)
        root.addWidget(subtitle)
        root.addWidget(context_hint)

        card = QFrame()
        card.setProperty("card", "true")
        card_layout = QVBoxLayout(card)
        card_layout.setContentsMargins(12, 12, 12, 12)

        self.table = QTableWidget(0, 7)
        self.table.setHorizontalHeaderLabels(
            [
                "ID лаборатории",
                "Монеты",
                "Рейтинг",
                "Существа",
                "Активные задания",
                "Выполненные",
                "Эксперименты",
            ]
        )
        self.table.setSelectionBehavior(QTableWidget.SelectRows)
        self.table.setSelectionMode(QTableWidget.SingleSelection)
        self.table.verticalHeader().setVisible(False)
        self.table.setEditTriggers(QTableWidget.NoEditTriggers)
        self.table.horizontalHeader().setStretchLastSection(True)
        self.table.setAlternatingRowColors(True)
        card_layout.addWidget(self.table)

        self.empty_labs_hint = QLabel("")
        self.empty_labs_hint.setObjectName("subtitle")
        self.empty_labs_hint.setWordWrap(True)
        card_layout.addWidget(self.empty_labs_hint)

        root.addWidget(card)

        actions = QHBoxLayout()
        self.refresh_btn = QPushButton("Обновить список")
        self.refresh_btn.setProperty("role", "secondary")
        self.refresh_btn.clicked.connect(self.refresh_labs)

        self.create_btn = QPushButton("Создать лабораторию")
        self.create_btn.setToolTip("Создает новую лабораторию и стартовую коллекцию существ.")
        self.create_btn.clicked.connect(self._create_lab)

        self.open_btn = QPushButton("Открыть")
        self.open_btn.setToolTip("Открывает выбранную лабораторию для текущей сессии.")
        self.open_btn.clicked.connect(self._open_selected_lab)

        self.delete_btn = QPushButton("Удалить лабораторию")
        self.delete_btn.setProperty("role", "secondary")
        self.delete_btn.setToolTip("Удаляет выбранную лабораторию вместе с её данными.")
        self.delete_btn.clicked.connect(self._delete_selected_lab)

        self.logout_btn = QPushButton("Выйти из аккаунта")
        self.logout_btn.setProperty("role", "secondary")
        self.logout_btn.setToolTip("Завершает текущую сессию и возвращает на экран входа.")
        self.logout_btn.clicked.connect(self.on_logout)

        actions.addWidget(self.refresh_btn)
        actions.addStretch()
        actions.addWidget(self.create_btn)
        actions.addWidget(self.open_btn)
        actions.addWidget(self.delete_btn)
        actions.addWidget(self.logout_btn)

        root.addLayout(actions)

    def closeEvent(self, event) -> None:
        if self.is_programmatic_close():
            event.accept()
            return

        self.on_window_close()
        event.accept()

    def refresh_labs(self) -> None:
        if self.state.user_id is None:
            QMessageBox.warning(self, "Лаборатории", "Контекст пользователя не инициализирован. Выполните вход заново.")
            return

        try:
            self._labs = self.pkg_api.list_user_labs(self.state.user_id)
        except Exception as exc:
            QMessageBox.critical(self, "Ошибка лабораторий", map_oracle_error(exc))
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
            self.empty_labs_hint.setText("")
        else:
            self.empty_labs_hint.setText("У вас пока нет лабораторий. Создайте первую лабораторию, чтобы начать игру.")

    def _set_cell(self, row: int, col: int, value) -> None:
        text = "Не указано" if value is None else str(value)
        item = QTableWidgetItem(text)
        item.setTextAlignment(Qt.AlignCenter)
        self.table.setItem(row, col, item)

    def _set_delete_flow_enabled(self, enabled: bool) -> None:
        self.refresh_btn.setEnabled(enabled)
        self.create_btn.setEnabled(enabled)
        self.open_btn.setEnabled(enabled)
        self.delete_btn.setEnabled(enabled)
        self.logout_btn.setEnabled(enabled)
        self.table.setEnabled(enabled)

    def _delete_error_message(self, exc: Exception) -> str:
        message = map_oracle_error(exc)
        raw_text = str(exc).casefold()
        lock_tokens = (
            "timeout",
            "timed out",
            "call timeout",
            "dpy-4011",
            "ora-00054",
            "ora-30006",
            "resource busy",
            "lock wait",
        )
        if any(token in raw_text for token in lock_tokens):
            hint = (
                "Удаление заняло слишком много времени. "
                "Возможно, лаборатория занята другой сессией. "
                "Закройте другие окна приложения или выполните "
                "очистку зависших DEV-сессий."
            )
            return f"{hint}\n\n{message}" if message else hint
        return message

    def _create_lab(self) -> None:
        token = self.state.session_token
        if not token:
            QMessageBox.warning(self, "Лаборатории", "Токен сессии отсутствует. Выполните вход заново.")
            return

        try:
            new_lab_id = self.pkg_api.start_new_lab(token)
            self.refresh_labs()
            self._select_lab_by_id(new_lab_id)
            QMessageBox.information(self, "Лаборатории", f"Лаборатория {new_lab_id} успешно создана.")
        except Exception as exc:
            QMessageBox.critical(self, "Ошибка создания", map_oracle_error(exc))

    def _select_lab_by_id(self, lab_id: int) -> None:
        for row in range(self.table.rowCount()):
            item = self.table.item(row, 0)
            if item and item.text() == str(lab_id):
                self.table.selectRow(row)
                return

    def _open_selected_lab(self) -> None:
        token = self.state.session_token
        if not token:
            QMessageBox.warning(self, "Лаборатории", "Токен сессии отсутствует. Выполните вход заново.")
            return

        row = self.table.currentRow()
        if row < 0:
            QMessageBox.information(self, "Лаборатории", "Сначала выберите лабораторию в таблице.")
            return

        lab_id_item = self.table.item(row, 0)
        if lab_id_item is None:
            QMessageBox.warning(self, "Лаборатории", "Не удалось прочитать идентификатор лаборатории.")
            return

        lab_id = int(lab_id_item.text())

        try:
            self.pkg_api.switch_lab(token, lab_id)
            self.state.set_selected_lab(lab_id)
            self.on_open_lab(lab_id)
        except Exception as exc:
            QMessageBox.critical(self, "Ошибка открытия", map_oracle_error(exc))

    def _delete_selected_lab(self) -> None:
        if self._delete_in_progress:
            return

        token = self.state.session_token
        if not token:
            QMessageBox.warning(self, "Лаборатории", "Токен сессии отсутствует. Выполните вход заново.")
            return

        row = self.table.currentRow()
        if row < 0:
            QMessageBox.information(self, "Лаборатории", "Сначала выберите лабораторию в таблице.")
            return

        lab_id_item = self.table.item(row, 0)
        if lab_id_item is None:
            QMessageBox.warning(self, "Лаборатории", "Не удалось прочитать идентификатор лаборатории.")
            return

        lab_id = int(lab_id_item.text())

        if self.state.selected_lab_id == lab_id:
            QMessageBox.information(
                self,
                "Удаление лаборатории",
                "Нельзя удалить лабораторию, которая сейчас открыта. "
                "Сначала выйдите из неё или выберите другую.",
            )
            return

        answer = QMessageBox.question(
            self,
            "Удаление лаборатории",
            (
                f"Вы действительно хотите удалить лабораторию {lab_id}?\n"
                "Это действие необратимо."
            ),
            QMessageBox.Yes | QMessageBox.No,
            QMessageBox.No,
        )
        if answer != QMessageBox.Yes:
            return

        self._delete_in_progress = True
        self._set_delete_flow_enabled(False)
        QApplication.setOverrideCursor(Qt.WaitCursor)
        QApplication.processEvents()

        connection = self.state.connection
        previous_call_timeout = getattr(connection, "call_timeout", None)
        deleted = False
        error_message = ""

        try:
            connection.call_timeout = 15000
            self.pkg_api.delete_lab(token, lab_id)
            deleted = True
        except Exception as exc:
            error_message = self._delete_error_message(exc)
        finally:
            try:
                connection.call_timeout = previous_call_timeout
            except Exception:
                pass
            QApplication.restoreOverrideCursor()
            self._set_delete_flow_enabled(True)
            self._delete_in_progress = False
            QApplication.processEvents()

        if error_message:
            QMessageBox.critical(self, "Ошибка удаления", error_message)
            return

        if deleted:
            self.refresh_labs()
            QMessageBox.information(self, "Лаборатории", f"Лаборатория {lab_id} удалена.")

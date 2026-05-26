from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QFormLayout,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QMessageBox,
    QPushButton,
    QTabWidget,
    QVBoxLayout,
    QWidget,
)

from app.db.pkg_api import PkgApi
from app.services.oracle_errors import map_oracle_error
from app.services.session_state import SessionState


class AuthWindow(QWidget):
    def __init__(self, pkg_api: PkgApi, state: SessionState, on_login_success) -> None:
        super().__init__()
        self.pkg_api = pkg_api
        self.state = state
        self.on_login_success = on_login_success

        self.setWindowTitle("БиоСборка - Авторизация")
        self.setMinimumSize(520, 420)

        self._build_ui()

    def _build_ui(self) -> None:
        root_layout = QVBoxLayout(self)
        root_layout.setContentsMargins(24, 20, 24, 20)
        root_layout.setSpacing(14)

        title = QLabel("БиоСборка")
        title.setObjectName("title")
        subtitle = QLabel("Вход в лабораторную систему")
        subtitle.setObjectName("subtitle")

        root_layout.addWidget(title)
        root_layout.addWidget(subtitle)

        self.tabs = QTabWidget()
        self.tabs.addTab(self._build_login_tab(), "Login")
        self.tabs.addTab(self._build_register_tab(), "Register")
        root_layout.addWidget(self.tabs)

    def _build_login_tab(self) -> QWidget:
        tab = QWidget()
        layout = QVBoxLayout(tab)

        box = QGroupBox("Вход")
        form = QFormLayout(box)
        form.setLabelAlignment(Qt.AlignRight)

        self.login_input = QLineEdit()
        self.login_input.setPlaceholderText("login")

        self.password_input = QLineEdit()
        self.password_input.setEchoMode(QLineEdit.Password)
        self.password_input.setPlaceholderText("password")

        form.addRow("Login:", self.login_input)
        form.addRow("Password:", self.password_input)

        login_btn = QPushButton("Login")
        login_btn.clicked.connect(self._handle_login)

        buttons = QHBoxLayout()
        buttons.addStretch()
        buttons.addWidget(login_btn)

        layout.addWidget(box)
        layout.addLayout(buttons)
        layout.addStretch()
        return tab

    def _build_register_tab(self) -> QWidget:
        tab = QWidget()
        layout = QVBoxLayout(tab)

        box = QGroupBox("Регистрация")
        form = QFormLayout(box)
        form.setLabelAlignment(Qt.AlignRight)

        self.reg_username_input = QLineEdit()
        self.reg_username_input.setPlaceholderText("display name")

        self.reg_login_input = QLineEdit()
        self.reg_login_input.setPlaceholderText("login")

        self.reg_password_input = QLineEdit()
        self.reg_password_input.setEchoMode(QLineEdit.Password)
        self.reg_password_input.setPlaceholderText("password")

        self.reg_password_repeat_input = QLineEdit()
        self.reg_password_repeat_input.setEchoMode(QLineEdit.Password)
        self.reg_password_repeat_input.setPlaceholderText("repeat password")

        form.addRow("Username:", self.reg_username_input)
        form.addRow("Login:", self.reg_login_input)
        form.addRow("Password:", self.reg_password_input)
        form.addRow("Repeat:", self.reg_password_repeat_input)

        register_btn = QPushButton("Register")
        register_btn.clicked.connect(self._handle_register)

        buttons = QHBoxLayout()
        buttons.addStretch()
        buttons.addWidget(register_btn)

        layout.addWidget(box)
        layout.addLayout(buttons)
        layout.addStretch()
        return tab

    def _handle_login(self) -> None:
        login = self.login_input.text().strip()
        password = self.password_input.text()

        if not login or not password:
            QMessageBox.warning(self, "Validation", "Login and password are required.")
            return

        try:
            token = self.pkg_api.login_user(login, password)
            if not token:
                QMessageBox.warning(self, "Login", "Invalid login or password.")
                return

            user_id = self.pkg_api.resolve_user_id_by_token(token)
            if user_id is None:
                QMessageBox.critical(self, "Login", "Could not resolve user context by session token.")
                return

            self.state.session_token = token
            self.state.user_id = user_id
            self.state.clear_lab_context()
            self.on_login_success()
        except Exception as exc:
            QMessageBox.critical(self, "Login Error", map_oracle_error(exc))

    def _handle_register(self) -> None:
        username = self.reg_username_input.text().strip()
        login = self.reg_login_input.text().strip()
        password = self.reg_password_input.text()
        password_repeat = self.reg_password_repeat_input.text()

        if not username or not login or not password:
            QMessageBox.warning(self, "Validation", "Username, login and password are required.")
            return

        if password != password_repeat:
            QMessageBox.warning(self, "Validation", "Passwords do not match.")
            return

        try:
            self.pkg_api.register_user(username, login, password)
            QMessageBox.information(self, "Register", "User created successfully. Please login.")
            self.login_input.setText(login)
            self.password_input.setFocus()
            self.tabs.setCurrentIndex(0)
        except Exception as exc:
            QMessageBox.critical(self, "Register Error", map_oracle_error(exc))
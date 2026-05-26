from __future__ import annotations

from app.db.pkg_api import PkgApi
from app.gui.auth_window import AuthWindow
from app.gui.lab_window import LabWindow
from app.gui.main_window import MainWindow
from app.services.session_state import SessionState


class GuiController:
    def __init__(self, state: SessionState, pkg_api: PkgApi) -> None:
        self.state = state
        self.pkg_api = pkg_api

        self.auth_window: AuthWindow | None = None
        self.lab_window: LabWindow | None = None
        self.main_window: MainWindow | None = None

    def start(self) -> None:
        self.show_auth_window()

    def _close_windows(self) -> None:
        for window in (self.auth_window, self.lab_window, self.main_window):
            if window is not None:
                window.close()

    def show_auth_window(self) -> None:
        self._close_windows()
        self.auth_window = AuthWindow(
            pkg_api=self.pkg_api,
            state=self.state,
            on_login_success=self.show_lab_window,
        )
        self.auth_window.show()

    def show_lab_window(self) -> None:
        if self.state.session_token is None or self.state.user_id is None:
            self.show_auth_window()
            return

        self._close_windows()
        self.lab_window = LabWindow(
            pkg_api=self.pkg_api,
            state=self.state,
            on_open_lab=self.show_main_window,
            on_logout=self.logout_to_auth,
        )
        self.lab_window.refresh_labs()
        self.lab_window.show()

    def show_main_window(self, lab_id: int) -> None:
        self.state.set_selected_lab(lab_id)

        self._close_windows()
        self.main_window = MainWindow(
            pkg_api=self.pkg_api,
            state=self.state,
            on_logout=self.logout_to_auth,
        )
        self.main_window.refresh_main_shell()
        self.main_window.show()

    def logout_to_auth(self) -> None:
        token = self.state.session_token
        if token:
            try:
                self.pkg_api.logout_user(token)
            except Exception:
                pass

        self.state.clear_session_context()
        self.show_auth_window()

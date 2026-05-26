from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

import oracledb


@dataclass
class SessionState:
    connection: oracledb.Connection
    session_token: str | None = None
    user_id: int | None = None
    selected_lab_id: int | None = None
    lab_stats: dict[str, Any] = field(default_factory=dict)

    def clear_lab_context(self) -> None:
        self.selected_lab_id = None
        self.lab_stats = {}

    def clear_session_context(self) -> None:
        self.session_token = None
        self.user_id = None
        self.clear_lab_context()

    def set_selected_lab(self, lab_id: int) -> None:
        self.selected_lab_id = lab_id

    def set_lab_stats(self, stats: dict[str, Any]) -> None:
        self.lab_stats = dict(stats)
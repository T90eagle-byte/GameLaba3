APP_STYLE = """
QWidget {
    background-color: #eef2f7;
    color: #1f2937;
    font-family: Segoe UI, Arial, sans-serif;
    font-size: 13px;
}

QMainWindow, QDialog {
    background-color: #eef2f7;
}

QLabel#title {
    font-size: 20px;
    font-weight: 700;
    color: #0f172a;
}

QLabel#subtitle {
    color: #475569;
}

QGroupBox {
    border: 1px solid #d3d9e3;
    border-radius: 8px;
    margin-top: 10px;
    padding-top: 10px;
    background: #ffffff;
}

QGroupBox::title {
    subcontrol-origin: margin;
    left: 10px;
    padding: 0 4px;
    color: #1f2937;
    font-weight: 600;
}

QLineEdit, QComboBox, QTableWidget, QTabWidget::pane {
    background: #ffffff;
    border: 1px solid #ccd5e1;
    border-radius: 6px;
    padding: 6px;
}

QLineEdit:focus, QComboBox:focus {
    border: 1px solid #3b82f6;
}

QPushButton {
    background-color: #2563eb;
    color: #ffffff;
    border: 0;
    border-radius: 6px;
    padding: 8px 14px;
    font-weight: 600;
    min-height: 18px;
}

QPushButton:hover {
    background-color: #1d4ed8;
}

QPushButton:pressed {
    background-color: #1e40af;
}

QPushButton:disabled {
    background-color: #cbd5e1;
    color: #6b7280;
}

QPushButton[role='secondary'] {
    background-color: #e8edf5;
    color: #0f172a;
    border: 1px solid #d2dceb;
}

QPushButton[role='secondary']:hover {
    background-color: #dde6f3;
}

QTableWidget {
    gridline-color: #e2e8f0;
    selection-background-color: #dbeafe;
    selection-color: #0f172a;
    alternate-background-color: #f8fafc;
}

QHeaderView::section {
    background-color: #edf2fb;
    border: 0;
    border-right: 1px solid #d1d9e6;
    border-bottom: 1px solid #d1d9e6;
    padding: 6px;
    font-weight: 600;
    color: #1e293b;
}

QTabBar::tab {
    background: #e6ebf3;
    border: 1px solid #cfd7e4;
    border-bottom: none;
    border-top-left-radius: 6px;
    border-top-right-radius: 6px;
    padding: 8px 12px;
    margin-right: 2px;
}

QTabBar::tab:selected {
    background: #ffffff;
    color: #0f172a;
}

QFrame#infoPanel {
    background-color: #eef6ff;
    border: 1px solid #bfd8fb;
    border-radius: 8px;
}

QFrame#geneCard {
    background-color: #f8fafc;
    border: 1px solid #e3e8f1;
    border-radius: 6px;
}

QLabel#geneCardTitle {
    font-weight: 700;
    color: #111827;
}

QLabel#muted {
    color: #64748b;
}

QFrame[card='true'] {
    background-color: #ffffff;
    border: 1px solid #d6deea;
    border-radius: 8px;
}

QFrame#creaturePortrait {
    background-color: #fffdf7;
    border: 1px solid #e2d6c2;
    border-radius: 10px;
}

QLabel[badge='true'] {
    background-color: #fff8ea;
    border: 1px solid #e9dcc3;
    border-radius: 6px;
    padding: 2px 8px;
    color: #374151;
    font-size: 12px;
}

QLabel[typechip='cross'] {
    background-color: #e8f1ff;
    border: 1px solid #c7dafc;
    border-radius: 6px;
    padding: 2px 8px;
}

QLabel[typechip='mutation'] {
    background-color: #f3ecff;
    border: 1px solid #dccfff;
    border-radius: 6px;
    padding: 2px 8px;
}

QLabel[typechip='mutagen'] {
    background-color: #eafaf2;
    border: 1px solid #c7eed8;
    border-radius: 6px;
    padding: 2px 8px;
}

QScrollBar:vertical {
    background: #eaf0fa;
    width: 12px;
    margin: 0;
    border-radius: 6px;
}

QScrollBar::handle:vertical {
    background: #c9d7ee;
    min-height: 24px;
    border-radius: 6px;
}

QScrollBar:horizontal {
    background: #eaf0fa;
    height: 12px;
    margin: 0;
    border-radius: 6px;
}

QScrollBar::handle:horizontal {
    background: #c9d7ee;
    min-width: 24px;
    border-radius: 6px;
}

QMessageBox {
    background-color: #f8fafc;
}
"""

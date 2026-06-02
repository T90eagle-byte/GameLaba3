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

QPushButton[role='quick'] {
    background-color: #fff8ea;
    color: #334155;
    border: 1px solid #e6d6b8;
    border-radius: 8px;
    padding: 7px 10px;
    font-weight: 600;
}

QPushButton[role='quick']:hover {
    background-color: #fff0d3;
    border-color: #d9bd88;
}

QTableWidget {
    gridline-color: #eadfce;
    selection-background-color: #fff0d3;
    selection-color: #1f2937;
    alternate-background-color: #fffaf2;
}

QTableWidget::item {
    padding: 4px;
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
    background-color: #fffdf7;
    border: 1px solid #e2d6c2;
    border-radius: 8px;
}

QFrame#statCard {
    background-color: #fffaf0;
    border: 1px solid #e6d6b8;
    border-radius: 8px;
}

QLabel[statLabel='true'] {
    color: #64748b;
    font-size: 12px;
}

QLabel[statValue='true'] {
    color: #1f2937;
    font-size: 18px;
    font-weight: 700;
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

QScrollBar::handle:vertical:hover {
    background: #b8c9e5;
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

QScrollBar::handle:horizontal:hover {
    background: #b8c9e5;
}


QFrame#missionListCard, QFrame#journalListCard {
    background-color: #fffdf7;
    border: 1px solid #e4d3b7;
    border-radius: 8px;
}

QFrame#missionCard, QFrame#journalCard {
    background-color: #fffaf0;
    border: 1px solid #dec9a4;
    border-radius: 8px;
}

QFrame#missionCreatureCard {
    background-color: #fbfff7;
    border: 1px solid #d7e5c5;
    border-radius: 8px;
}

QFrame#resultStatusCard {
    background-color: #f8fbff;
    border: 1px solid #d4dfef;
    border-radius: 8px;
}

QLabel#missionSectionTitle, QLabel#journalTitle {
    color: #1f2937;
    font-weight: 700;
    font-size: 14px;
}

QLabel#missionTitle {
    color: #0f172a;
    font-weight: 700;
    font-size: 16px;
}

QLabel#missionDescription {
    background-color: #fffdf7;
    border: 1px solid #eadfce;
    border-radius: 6px;
    padding: 8px;
    color: #334155;
}

QLabel[badgeType='difficulty'] {
    background-color: #fef3c7;
    border-color: #e7c66b;
    color: #4b3b12;
}

QLabel[badgeType='status'] {
    background-color: #e8f1ff;
    border-color: #bdd4fb;
    color: #1e3a8a;
}

QLabel[badgeType='reward'] {
    background-color: #eafaf2;
    border-color: #c5e8d2;
    color: #14532d;
}

QLabel[resultStatus='neutral'] {
    background-color: #fffdf7;
    border: 1px solid #e2d6c2;
    border-radius: 6px;
    padding: 8px;
    color: #475569;
}

QLabel[resultStatus='success'] {
    background-color: #ecfdf3;
    border: 1px solid #bbebcd;
    border-radius: 6px;
    padding: 8px;
    color: #166534;
    font-weight: 600;
}

QLabel[resultStatus='error'] {
    background-color: #fff1f2;
    border: 1px solid #fecdd3;
    border-radius: 6px;
    padding: 8px;
    color: #9f1239;
    font-weight: 600;
}

QLabel[resultStatus='done'] {
    background-color: #f5f0ff;
    border: 1px solid #d8c9ff;
    border-radius: 6px;
    padding: 8px;
    color: #5b21b6;
    font-weight: 600;
}

QLabel[emptyState='true'] {
    background-color: #fffaf0;
    border: 1px dashed #dec9a4;
    border-radius: 8px;
    padding: 8px;
    color: #64748b;
}


QFrame#experimentFlowCard,
QFrame#mutationStandInfo {
    background-color: #fff7e8;
    border: 1px solid #e8d4ad;
    border-radius: 8px;
}

QFrame#experimentSelectorCard,
QFrame#parentCard,
QFrame#probabilityCard,
QFrame#experimentResultCard,
QFrame#mutationShopCard,
QFrame#mutationCreatureCard,
QFrame#mutationApplyCard,
QFrame#mutagenCard {
    background-color: #fffdf7;
    border: 1px solid #e4d7c3;
    border-radius: 8px;
}

QLabel#flowSteps {
    background-color: #f5ead7;
    border: 1px solid #d7bd92;
    color: #4b3b25;
    font-weight: 700;
    padding: 7px 10px;
    border-radius: 6px;
}

QLabel#mutationTitle {
    color: #293241;
    font-size: 15px;
    font-weight: 700;
}

QLabel[badgeType='stock'] {
    background-color: #eef7ff;
    border-color: #bedaf7;
    color: #1d4f7a;
}

QLabel[badgeType='radiation'] {
    background-color: #fff3d8;
    border-color: #e8bd62;
    color: #7a4b00;
}

QLabel[badgeType='chemical'] {
    background-color: #eafaf2;
    border-color: #b8e4cd;
    color: #14532d;
}

QLabel[resultStatus='warning'] {
    background-color: #fff7ed;
    border: 1px solid #fed7aa;
    border-radius: 6px;
    padding: 8px;
    color: #9a3412;
    font-weight: 600;
}

QLabel[compatibilityStatus='neutral'] {
    background-color: #fffdf7;
    border: 1px solid #e2d6c2;
    border-radius: 6px;
    padding: 7px;
    color: #64748b;
}

QLabel[compatibilityStatus='ready'] {
    background-color: #ecfdf3;
    border: 1px solid #bbebcd;
    border-radius: 6px;
    padding: 7px;
    color: #166534;
    font-weight: 600;
}

QLabel[compatibilityStatus='warning'] {
    background-color: #fff7ed;
    border: 1px solid #fed7aa;
    border-radius: 6px;
    padding: 7px;
    color: #9a3412;
    font-weight: 600;
}

QLabel[compatibilityStatus='blocked'] {
    background-color: #fff1f2;
    border: 1px solid #fecdd3;
    border-radius: 6px;
    padding: 7px;
    color: #9f1239;
    font-weight: 600;
}

QToolTip {
    background-color: #fffdf7;
    color: #1f2937;
    border: 1px solid #d9cdb8;
    padding: 5px 8px;
}

QMessageBox {
    background-color: #f8fafc;
}
"""



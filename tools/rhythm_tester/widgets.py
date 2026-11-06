"""Painted timing displays; the transport, not these widgets, owns music time."""
from __future__ import annotations

import math
import numpy as np
from PySide6.QtCore import QPointF, QRectF, Qt
from PySide6.QtGui import QColor, QFont, QPainter, QPen
from PySide6.QtWidgets import QApplication, QPushButton, QWidget
from .strings_zh import t

BG = "#111e19"
SURFACE = "#1d3229"
INK = "#eee5ce"
MUTED = "#bcbba7"
GOLD = "#dfc187"
RED = "#9c4d3e"
BORDER = "#405448"


def beat_flash(times, position: float, duration: float = .075) -> float:
    """A beat starts the flash; the early input window never starts it.

    The lane rectangles show input tolerance separately. Using those rectangles
    for the metronome would make its visual onset precede the click by90ms at the
    default setting, encouraging users to tap ahead of the reference time.
    """
    index = int(np.searchsorted(times, position, side="right")) - 1
    if index < 0:
        return 0.0
    elapsed = position - float(times[index])
    return max(0.0, 1.0 - elapsed / duration) if 0 <= elapsed < duration else 0.0


def apply_theme(app: QApplication) -> None:
    app.setStyle("Fusion")
    app.setStyleSheet(f"""
        QWidget {{ background: {BG}; color: {INK}; font-size: 14px; }}
        QMainWindow, QScrollArea, QScrollArea > QWidget > QWidget {{ background: {BG}; }}
        QLabel {{ background: transparent; }}
        QLabel[role='muted'] {{ color: {MUTED}; }}
        QLabel[role='title'] {{ font-size: 24px; font-weight: 650; }}
        QLabel[role='feedback'] {{ font-size: 21px; font-weight: 600; }}
        QLabel[role='error'] {{ color: #efb5a1; }}
        QPushButton, QComboBox, QSpinBox, QDoubleSpinBox, QLineEdit {{
            background: {SURFACE}; border: 1px solid {BORDER}; border-radius: 4px;
            padding: 7px 10px; min-height: 19px;
        }}
        QPushButton:hover, QComboBox:hover {{ border-color: {GOLD}; background: #294135; }}
        QPushButton:pressed, QPushButton[active='true'] {{ background: {GOLD}; color: {BG}; }}
        QPushButton:focus, QComboBox:focus, QSpinBox:focus, QLineEdit:focus {{ border: 2px solid {GOLD}; }}
        QPushButton:disabled, QComboBox:disabled, QSpinBox:disabled, QCheckBox:disabled {{ color: #7b897b; border-color: #2c3c31; }}
        QPushButton[primary='true'] {{ background: {GOLD}; color: {BG}; border-color: {GOLD}; font-weight: 650; }}
        QPushButton[primary='true']:disabled {{ background: #666747; color: #c2c1aa; }}
        QComboBox QAbstractItemView {{ background: {SURFACE}; color: {INK}; selection-background-color: #476045; selection-color: {INK}; }}
        QCheckBox {{ spacing: 7px; background: transparent; }}
        QCheckBox::indicator {{ width: 16px; height: 16px; border: 1px solid #809078; background: {SURFACE}; border-radius: 2px; }}
        QCheckBox::indicator:checked {{ background: {GOLD}; border: 1px solid {GOLD}; }}
        QSlider::groove:horizontal {{ height: 4px; background: #34483c; border-radius: 2px; }}
        QSlider::sub-page:horizontal {{ background: {GOLD}; }}
        QSlider::handle:horizontal {{ width: 13px; margin: -5px 0; background: {GOLD}; border-radius: 6px; }}
        QSlider:disabled::handle:horizontal {{ background: #68735f; }}
        QToolTip {{ color: {INK}; background: {SURFACE}; border: 1px solid {BORDER}; padding: 6px; }}
        QFrame[role='separator'] {{ background: {BORDER}; max-height: 1px; border: none; }}
    """)


class BeatCanvas(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setMinimumHeight(174)
        self.setAccessibleName(t("mode_pulse"))
        self.times = np.empty(0)
        self.strengths = np.empty(0)
        self.starts = np.empty(0)
        self.ends = np.empty(0)
        self.position = 0.0
        self.window_ms = 90
        self.reduced_motion = False
        self.playing = False

    def set_plan(self, times, strengths):
        self.times = np.asarray(times, dtype=float)
        self.strengths = np.asarray(strengths, dtype=float)
        half = np.full(len(self.times), self.window_ms/1000)
        if len(self.times)>1:
            gaps=np.diff(self.times)*.45
            half[:-1]=np.minimum(half[:-1],gaps);half[1:]=np.minimum(half[1:],gaps)
        self.starts=np.maximum(0,self.times-half);self.ends=self.times+half
        self.update()

    def set_window_bounds(self, starts, ends):
        self.starts=np.asarray(starts,dtype=float);self.ends=np.asarray(ends,dtype=float)
        self.update()

    def set_position(self, position: float, playing: bool):
        self.position, self.playing = position, playing
        self.update()

    def paintEvent(self, event):
        p = QPainter(self); p.setRenderHint(QPainter.RenderHint.Antialiasing)
        rect = QRectF(self.rect()).adjusted(.5, .5, -.5, -.5)
        p.setPen(QPen(QColor(BORDER), 1)); p.setBrush(QColor(SURFACE)); p.drawRoundedRect(rect, 5, 5)
        index = int(np.searchsorted(self.times, self.position))
        flash = beat_flash(self.times, self.position) if self.playing else 0.0
        pulse = flash > 0
        p.setPen(Qt.PenStyle.NoPen); p.setBrush(QColor(GOLD if pulse else "#405448"))
        p.drawEllipse(QPointF(self.width()/2, 27), 8+2*flash, 8+2*flash)
        line_y = 115
        left, right = 24.0, self.width()-24.0
        anchor = left+(right-left)*.23
        p.setPen(QPen(QColor("#476052"),1)); p.drawLine(QPointF(left,line_y),QPointF(right,line_y))
        if self.reduced_motion:
            for j in range(-2,7):
                x = anchor+j*(right-left)/10
                if x < left: continue
                p.setPen(QPen(QColor(GOLD if j == 0 and pulse else MUTED),2 if j == 0 else 1))
                p.drawLine(QPointF(x,line_y-20),QPointF(x,line_y+20))
        else:
            scale = (right-left)/3.5
            begin = int(np.searchsorted(self.times,self.position-.82))
            end = int(np.searchsorted(self.times,self.position+2.7))
            for i in range(begin,end):
                x = anchor+(float(self.times[i])-self.position)*scale
                if not left <= x <= right: continue
                start_x=max(left,anchor+(float(self.starts[i])-self.position)*scale)
                end_x=min(right,anchor+(float(self.ends[i])-self.position)*scale)
                if end_x>start_x:
                    fill=QColor(GOLD);fill.setAlpha(25)
                    p.fillRect(QRectF(start_x,64,end_x-start_x,80),fill)
                strength = float(self.strengths[i]) if i < len(self.strengths) else .5
                height = 13+min(1,max(0,strength))*35
                color = QColor(GOLD if i >= index else MUTED)
                color.setAlpha(245 if i >= index else 100)
                p.setPen(QPen(color,3));p.drawLine(QPointF(x,line_y-height),QPointF(x,line_y+15))
        p.setPen(QPen(QColor(GOLD),2));p.drawLine(QPointF(anchor,61),QPointF(anchor,150))
        p.setPen(QColor(MUTED));p.setFont(QFont(self.font().family(),9))
        p.drawText(QRectF(20,145,self.width()-40,22),Qt.AlignmentFlag.AlignLeft,t("keys_hint"))
        p.end()


class DeviationPlot(QWidget):
    def __init__(self,parent=None):
        super().__init__(parent)
        self.errors: list[float] = []
        self.window_ms = 90
        self.setMinimumHeight(68)
        self.setAccessibleName(t("recent_errors"))

    def set_errors(self, errors):
        self.errors = [float(e) for e in errors[-40:] if e is not None and math.isfinite(float(e))]
        self.update()

    def paintEvent(self,event):
        p=QPainter(self);p.setRenderHint(QPainter.RenderHint.Antialiasing)
        center=self.height()/2
        p.setPen(QPen(QColor(BORDER),1));p.drawLine(62,int(center),self.width()-10,int(center))
        p.setPen(QColor(MUTED));p.drawText(1,18,f"+{self.window_ms} {t('unit_ms')}")
        p.drawText(1,self.height()-6,f"−{self.window_ms}")
        n=max(20,len(self.errors))
        for i,error in enumerate(self.errors):
            x=72+i*(self.width()-88)/max(1,n-1)
            y=center-max(-1.0,min(1.0,error/max(1,self.window_ms)))*(center-8)
            p.setPen(Qt.PenStyle.NoPen);p.setBrush(QColor(GOLD if abs(error)<=self.window_ms else "#df9a85"))
            p.drawEllipse(QPointF(x,y),3,3)
        p.end()


class KeyButton(QPushButton):
    def __init__(self,key,parent=None):
        super().__init__(t("key_"+key),parent)
        self.key=key
        self.setMinimumSize(94,62)
        self.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        self.setStyleSheet("font-size: 22px; font-weight: 600;")
        self._flash_id=0

    def flash(self):
        from PySide6.QtCore import QTimer
        self._flash_id+=1
        stamp=self._flash_id
        self.setProperty("active",True);self.style().unpolish(self);self.style().polish(self)
        def finish():
            if self._flash_id==stamp:
                self.setProperty("active",False);self.style().unpolish(self);self.style().polish(self)
        QTimer.singleShot(130,self,finish)

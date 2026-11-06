"""Standalone Qt listening/tapping workbench. It never loads Godot player data."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import sys
from typing import Any

import numpy as np
from PySide6.QtCore import QEvent, QObject, QRunnable, QThreadPool, QTimer, Qt, QUrl, Signal
from PySide6.QtGui import QCloseEvent, QDesktopServices, QFont, QFontDatabase
from PySide6.QtWidgets import (
    QAbstractSpinBox, QApplication, QCheckBox, QComboBox, QDialog, QFileDialog,
    QFrame, QGridLayout, QHBoxLayout, QLabel, QLineEdit, QMainWindow, QMessageBox,
    QPlainTextEdit, QPushButton, QScrollArea, QSlider, QSpinBox, QTextEdit,
    QVBoxLayout, QWidget,
)
from .analysis import BeatPlan, build_plan, parse_midi
from .audio import AudioTransport, decode_audio
from .session import SessionLog, TapJudge
from .strings_zh import t
from .widgets import BeatCanvas, DeviationPlot, KeyButton, apply_theme

ROOT=Path(__file__).resolve().parents[2]
RESULTS_DIR=Path(__file__).resolve().parent/"results"


class _LoadSignals(QObject):
    loaded=Signal(int,object,object)
    failed=Signal(int,str)


class _LoadTask(QRunnable):
    def __init__(self,token,midi,audio):
        super().__init__();self.token=token;self.midi=midi;self.audio=audio
        self.signals=_LoadSignals()

    def run(self):
        try:
            data=parse_midi(self.midi)
            audio=decode_audio(self.audio)
            self.signals.loaded.emit(self.token,data,audio)
        except Exception as exc:
            self.signals.failed.emit(self.token,str(exc))


def _label(text,role=None):
    label=QLabel(text)
    if role:label.setProperty("role",role)
    return label


def _clock(seconds):
    seconds=max(0,float(seconds));return f"{int(seconds)//60:02d}:{int(seconds)%60:02d}.{int(seconds*10)%10}"


class MainWindow(QMainWindow):
    def __init__(self, *, midi_path=None,audio_path=None,results_dir=None,no_autoplay=True,initial_track=2,presentation_offset_ms=0):
        super().__init__()
        self.setWindowTitle(t("app_title"));self.resize(1140,800);self.setMinimumSize(940,660)
        self.transport=AudioTransport(self)
        self.transport.set_volume(.6)
        self.transport.stateChanged.connect(self._state_changed)
        self.transport.error.connect(self._audio_error)
        self.transport.finished.connect(self._finished)
        self.results_dir=Path(results_dir) if results_dir else RESULTS_DIR
        self.log=SessionLog(self.results_dir)
        self.judge=TapJudge(np.empty(0),window_ms=90)
        self.data=None;self.audio=None;self.plan=None
        self._loading=False;self._closing=False;self._dirty=False;self._load_token=0;self._applied_click=False
        self._tasks={};self._seek_was_playing=False;self._ready_once=False
        self._pool=QThreadPool(self);self._pool.setMaxThreadCount(2)
        self._build_ui();self._populate_tracks(initial_track)
        self.presentation_spin.setValue(presentation_offset_ms)
        QApplication.instance().installEventFilter(self)
        self._timer=QTimer(self);self._timer.timeout.connect(self._tick);self._timer.start(16)
        if midi_path and audio_path:
            self._add_external(Path(midi_path),Path(audio_path))
        else:QTimer.singleShot(0,self._load_selected)

    def _build_ui(self):
        scroll=QScrollArea();scroll.setWidgetResizable(True);scroll.setFrameShape(QFrame.Shape.NoFrame)
        self.setCentralWidget(scroll)
        body=QWidget();scroll.setWidget(body)
        main=QVBoxLayout(body);main.setContentsMargins(22,16,22,16);main.setSpacing(8)
        head=QHBoxLayout();titles=QVBoxLayout();titles.setSpacing(3)
        titles.addWidget(_label(t("app_title"),"title"));titles.addWidget(_label(t("app_subtitle"),"muted"))
        head.addLayout(titles);head.addStretch()
        help_button=QPushButton(t("help_title"));help_button.clicked.connect(self._help);head.addWidget(help_button)
        main.addLayout(head)
        select=QHBoxLayout();select.addWidget(_label(t("track")))
        self.track_combo=QComboBox();self.track_combo.setMinimumContentsLength(24);select.addWidget(self.track_combo,1)
        self.track_combo.currentIndexChanged.connect(self._load_selected)
        self.open_button=QPushButton(t("open_pair"));self.open_button.clicked.connect(self._open_pair);select.addWidget(self.open_button)
        main.addLayout(select)
        modes=QHBoxLayout();modes.addWidget(_label(t("mode")))
        self.mode_combo=QComboBox()
        for mode in ("pulse","quarter","onsets","blind"):self.mode_combo.addItem(t("mode_"+mode),mode)
        self.mode_combo.currentIndexChanged.connect(self._parameters_changed);modes.addWidget(self.mode_combo)
        modes.addSpacing(16);self.layer_label=_label(t("layer"));modes.addWidget(self.layer_label)
        self.layer_combo=QComboBox()
        for key,value in (("layer_half",.5),("layer_normal",1.0),("layer_double",2.0)):self.layer_combo.addItem(t(key),value)
        self.layer_combo.setCurrentIndex(1);self.layer_combo.currentIndexChanged.connect(self._parameters_changed);modes.addWidget(self.layer_combo)
        self.phase_label=_label(t("phase"));modes.addWidget(self.phase_label)
        self.phase_combo=QComboBox();self.phase_combo.addItem(t("phase_normal"),0.0);self.phase_combo.addItem(t("phase_half"),.5)
        self.phase_combo.currentIndexChanged.connect(self._parameters_changed);modes.addWidget(self.phase_combo);modes.addStretch()
        main.addLayout(modes)
        self.mode_description=_label(t("mode_desc_pulse"),"muted");self.mode_description.setWordWrap(True);self.mode_description.hide();self.mode_combo.setToolTip(t("mode_desc_pulse"));main.addWidget(self.mode_description)
        parameters=QHBoxLayout()
        parameters.addWidget(_label(t("window_limit")))
        self.window_spin=QSpinBox();self.window_spin.setRange(20,180);self.window_spin.setValue(90);self.window_spin.setSuffix(" ms");self.window_spin.setToolTip(t("window_tip"))
        self.window_spin.valueChanged.connect(self._timing_changed);parameters.addWidget(self.window_spin)
        parameters.addSpacing(14);parameters.addWidget(_label(t("compensation")))
        self.compensation_spin=QSpinBox();self.compensation_spin.setRange(-300,300);self.compensation_spin.setSuffix(" ms")
        self.compensation_spin.setToolTip(t("compensation_semantics"));self.compensation_spin.valueChanged.connect(self._timing_changed);parameters.addWidget(self.compensation_spin)
        parameters.addStretch();self.click_check=QCheckBox(t("click_sound"));self.click_check.toggled.connect(self._click_changed);parameters.addWidget(self.click_check)
        self.motion_check=QCheckBox(t("reduced_motion"));self.motion_check.toggled.connect(self._motion_changed);parameters.addWidget(self.motion_check)
        main.addLayout(parameters)
        sync=QHBoxLayout();sync.addWidget(_label(t("presentation_offset")))
        self.presentation_spin=QSpinBox();self.presentation_spin.setRange(-500,1000);self.presentation_spin.setSuffix(" ms")
        self.presentation_spin.setToolTip(t("presentation_offset_tip"));self.presentation_spin.valueChanged.connect(self._timing_changed);sync.addWidget(self.presentation_spin)
        sync_notice=_label(t("presentation_offset_notice"),"muted");sync_notice.setWordWrap(True);sync.addWidget(sync_notice,1);main.addLayout(sync)
        transport=QHBoxLayout()
        self.play_button=QPushButton(t("play"));self.play_button.setProperty("primary",True);self.play_button.setMinimumWidth(112)
        self.play_button.clicked.connect(self._toggle_play);transport.addWidget(self.play_button)
        self.retry_button=QPushButton(t("retry"));self.retry_button.clicked.connect(self._retry);transport.addWidget(self.retry_button)
        self.status_label=_label(t("loading"),"muted");transport.addWidget(self.status_label,1)
        transport.addWidget(_label(t("volume")))
        self.volume_slider=QSlider(Qt.Orientation.Horizontal);self.volume_slider.setRange(0,100);self.volume_slider.setValue(60);self.volume_slider.setMaximumWidth(110)
        self.volume_slider.valueChanged.connect(lambda v:self.transport.set_volume(v/100));transport.addWidget(self.volume_slider)
        self.clock_label=_label("00:00.0 / 00:00.0","muted");self.clock_label.setMinimumWidth(157);self.clock_label.setAlignment(Qt.AlignmentFlag.AlignRight|Qt.AlignmentFlag.AlignVCenter)
        transport.addWidget(self.clock_label);main.addLayout(transport)
        self.seek_slider=QSlider(Qt.Orientation.Horizontal);self.seek_slider.setRange(0,0)
        self.seek_slider.sliderPressed.connect(self._seek_pressed);self.seek_slider.sliderReleased.connect(self._seek_released);self.seek_slider.actionTriggered.connect(self._seek_action);main.addWidget(self.seek_slider)
        self.canvas=BeatCanvas();main.addWidget(self.canvas)
        self.blind_panel=_label(t("blind_hint"),"muted");self.blind_panel.setWordWrap(True);self.blind_panel.setAlignment(Qt.AlignmentFlag.AlignCenter);self.blind_panel.setMinimumHeight(115);self.blind_panel.hide();main.addWidget(self.blind_panel)
        feedback=QHBoxLayout();feedback.setSpacing(10);self.key_buttons={}
        for key in ("J","K","SPACE"):
            button=KeyButton(key);button.clicked.connect(lambda checked=False,k=key:self._tap(k,"mouse"));feedback.addWidget(button);self.key_buttons[key]=button
        feedback.addSpacing(18);last=QVBoxLayout();last.setSpacing(4)
        self.last_label=_label(t("waiting_hit"),"feedback");self.last_detail=_label(t("keys_hint"),"muted")
        last.addWidget(self.last_label);last.addWidget(self.last_detail);feedback.addLayout(last,1);main.addLayout(feedback)
        self.statistics=QWidget();stats=QGridLayout(self.statistics);stats.setContentsMargins(0,0,0,0)
        self.stats_labels=[]
        for i,key in enumerate(("tap_count","match_rate","mean_error","median_abs_error")):
            label=_label(t(key)+"  —","muted");self.stats_labels.append(label);stats.addWidget(label,i//2,i%2)
        main.addWidget(self.statistics)
        self.errors_label=_label(t("recent_errors"),"muted");main.addWidget(self.errors_label)
        self.error_plot=DeviationPlot();main.addWidget(self.error_plot)
        self.notice=_label(t("candidate_notice"),"muted");self.notice.setWordWrap(True);main.addWidget(self.notice)
        self.analysis_label=_label("","muted");self.analysis_label.setWordWrap(True);main.addWidget(self.analysis_label)
        line=QFrame();line.setProperty("role","separator");line.setFixedHeight(1);main.addWidget(line)
        footer=QHBoxLayout();self.trial_label=_label(t("trial_count")+"  0","muted");footer.addWidget(self.trial_label);self.save_label=_label(t("status_hint"),"muted");self.save_label.setWordWrap(True);footer.addWidget(self.save_label,1)
        export=QPushButton(t("export_results"));export.clicked.connect(self._export);footer.addWidget(export)
        folder=QPushButton(t("open_results"));folder.clicked.connect(self._open_results);footer.addWidget(folder)
        main.addLayout(footer);main.addStretch(1)
        self._set_enabled(False)

    def _populate_tracks(self,initial_track=2):
        self.track_combo.blockSignals(True)
        catalog=json.loads((ROOT/"assets/data/audio/music_catalog.json").read_text())
        for cue in catalog["cues"]:
            if not cue["id"].startswith("midi_test_"):continue
            entry={"cue_id":cue["id"],"title":cue["title"],"midi":ROOT/"design/music-20261104-chinese-12/arrangements"/cue["id"]/"D2.mid","audio":ROOT/cue["path"].removeprefix("res://")}
            self.track_combo.addItem(f"{cue['id'][-2:]}  {cue['title']}",entry)
        target=next((i for i in range(self.track_combo.count()) if self.track_combo.itemData(i)["cue_id"]==f"midi_test_{initial_track:02d}"),0)
        self.track_combo.setCurrentIndex(target);self.track_combo.blockSignals(False)

    def _mode(self):return self.mode_combo.currentData()

    def _presentation_position(self):
        return self.transport.position_seconds()-self.presentation_spin.value()/1000

    def _set_enabled(self,ready):
        for control in (self.play_button,self.retry_button,self.seek_slider):control.setEnabled(ready)
        for button in self.key_buttons.values():button.setEnabled(ready and self.transport.state=="playing")

    def _load_selected(self,*args):
        if not hasattr(self,"track_combo"):return
        entry=self.track_combo.currentData()
        if not entry:return
        self._export_if_dirty();self.transport.close();self._load_token+=1
        self._pool.clear()
        token=self._load_token;self._loading=True;self.data=None;self.audio=None;self.plan=None
        self._set_enabled(False);self.status_label.setText(t("loading"));self.analysis_label.clear()
        self.canvas.set_plan([],[]);self.error_plot.set_errors([]);self.last_label.setText(t("waiting_hit"))
        task=_LoadTask(token,entry["midi"],entry["audio"]);self._tasks[token]=task
        task.signals.loaded.connect(self._loaded);task.signals.failed.connect(self._load_failed);self._pool.start(task)

    def _loaded(self,token,data,audio):
        self._tasks.pop(token,None)
        if token!=self._load_token or self._closing:return
        self._loading=False;self.data=data;self.audio=audio
        try:
            self._build_plan();self._applied_click=self.click_check.isChecked() and self._mode()!="blind"
            self.transport.load(audio,self.plan.times,self._applied_click)
            self.transport.set_volume(self.volume_slider.value()/100)
            self.seek_slider.setRange(0,round(audio.duration_sec*1000));self._begin_trial("load")
            self.status_label.setText(t("ready"));self._ready_once=True;self._set_enabled(True)
        except Exception as exc:self._load_failed(token,str(exc))

    def _load_failed(self,token,message):
        self._tasks.pop(token,None)
        if token!=self._load_token or self._closing:return
        self._loading=False;self.status_label.setText(t("load_failed"));self.save_label.setText(message);self.analysis_label.setText(message);self.analysis_label.setProperty("role","error")
        self._set_enabled(False)

    def _build_plan(self):
        mode=self._mode();blind=mode=="blind"
        self.mode_description.setText(t("mode_desc_"+mode));self.mode_combo.setToolTip(t("mode_desc_"+mode))
        self.layer_combo.setEnabled(mode in ("pulse","quarter"));self.phase_combo.setEnabled(mode in ("pulse","quarter"))
        self.window_spin.setEnabled(not blind);self.click_check.setEnabled(not blind)
        self.canvas.setVisible(not blind);self.blind_panel.setVisible(blind)
        for widget in (self.statistics,self.error_plot,self.errors_label,self.notice,self.analysis_label):widget.setVisible(not blind)
        if not self.data:return
        if blind:self.plan=BeatPlan(np.empty(0),np.empty(0),"blind",{"blind":True,"reference_hidden":True})
        else:self.plan=build_plan(self.data,mode,self.layer_combo.currentData(),self.phase_combo.currentData())
        self.canvas.window_ms=self.window_spin.value();self.canvas.set_plan(self.plan.times,self.plan.strengths);self.error_plot.window_ms=self.window_spin.value()
        self.analysis_label.setProperty("role","muted")
        if mode=="pulse":
            # Scores are intentionally not presented as probabilities or accuracy.
            interval=float(np.median(np.diff(self.plan.times))) if len(self.plan.times)>1 else 0.0
            self.analysis_label.setText(t("reference_summary",count=len(self.plan.times),interval_ms=interval*1000,rate=60/interval if interval>0 else 0))
        else:self.analysis_label.setText(t("source_details"))
        self.last_label.setText(t("waiting_hit"));self.last_detail.setText(t("blind_hint") if blind else t("keys_hint"))

    def _parameters_changed(self,*args):
        self._build_plan()
        if not self.data or not self.audio or self._loading:return
        self._export_if_dirty()
        enabled=self.click_check.isChecked() and self._mode()!="blind"
        # A visual/reference change does not restart music when clicks are off.
        if enabled or self._applied_click:self.transport.set_clicks(self.plan.times,enabled)
        self._applied_click=enabled
        self._begin_trial("parameters")

    def _timing_changed(self,*args):
        # Judgement/display settings never rebuild the PCM stream.
        self._build_plan()
        if not self.data or not self.audio or self._loading:return
        self._export_if_dirty();self._begin_trial("timing")

    def _click_changed(self,checked):
        if not self.audio:return
        self._export_if_dirty();self._applied_click=checked and self._mode()!="blind"
        self.transport.set_clicks(self.plan.times,self._applied_click);self._begin_trial("click")

    def _motion_changed(self,checked):
        self.canvas.reduced_motion=checked;self.canvas.update()
        if self.data:self._export_if_dirty();self._begin_trial("motion")

    def _metadata(self,reason):
        entry=self.track_combo.currentData() or {}
        return {"reason":reason,"utc":datetime.now(timezone.utc).isoformat(),"cue_id":entry.get("cue_id"),"title":entry.get("title"),
                "midi_path":str(self.data.path),"midi_sha256":self.data.sha256,"audio_path":str(self.audio.path),"audio_sha256":self.audio.sha256,
                "mode":self._mode(),"layer":self.layer_combo.currentData(),"phase":self.phase_combo.currentData(),"window_ms":self.window_spin.value(),
                "compensation_ms":self.compensation_spin.value(),"compensation_semantics":"corrected=presented-compensation_ms/1000; positive advances tap",
                "presentation_offset_ms":self.presentation_spin.value(),"presentation_semantics":"presented=raw-presentation_offset_ms/1000; corrected=presented-compensation_ms/1000",
                "click_enabled":self.click_check.isChecked() and self._mode()!="blind","reduced_motion":self.motion_check.isChecked(),
                "start_audio_sec":self.transport.position_seconds(),"start_presentation_sec":self._presentation_position(),"trim_sec":self.data.trim_sec,"midi_metadata":self.data.metadata,"algorithm_metadata":self.plan.metadata,
                "reference_times_sec":self.plan.times.tolist(),"reference_strengths":self.plan.strengths.tolist()}

    def _begin_trial(self,reason):
        if not self.data or not self.audio or self.plan is None:return
        self.judge=TapJudge(self.plan.times,window_ms=self.window_spin.value());self.canvas.set_window_bounds(self.judge.starts,self.judge.ends);self.log.start_trial(self._metadata(reason))
        self.error_plot.set_errors([]);self.last_label.setText(t("waiting_hit"));self.trial_label.setText(f"{t('trial_count')}  {self.log.trial_count}");self._update_stats()

    def _tap(self,key,source="keyboard"):
        if self._loading or self.transport.state!="playing" or self.plan is None:return
        result=self.judge.tap(self.transport.position_seconds(),key,compensation_ms=self.compensation_spin.value(),blind=self._mode()=="blind",source=source,presentation_offset_ms=self.presentation_spin.value())
        self.log.append(result);self._dirty=True;self.key_buttons[key].flash()
        judgement=result["judgement"]
        self.last_label.setText(t(judgement))
        error=result.get("error_ms")
        self.last_detail.setText(t("blind_hint") if self._mode()=="blind" else (f"{error:+.1f} ms" if error is not None else t("keys_hint")))
        self.error_plot.set_errors([e.get("error_ms") for e in self.judge.events if e.get("error_ms") is not None]);self._update_stats()

    def _update_stats(self):
        stats=self.judge.stats()
        values=[str(stats.get("tap_count",0)),f"{stats['match_rate']:.1f}%" if stats.get("match_rate") is not None else "—",
                f"{stats['mean_error']:+.1f} ms" if stats.get("mean_error") is not None else "—",
                f"{stats['median_abs_error']:.1f} ms" if stats.get("median_abs_error") is not None else "—"]
        for label,key,value in zip(self.stats_labels,("tap_count","match_rate","mean_error","median_abs_error"),values):label.setText(f"{t(key)}  {value}")

    def _toggle_play(self):
        if self._loading or self.audio is None:return
        if self.transport.state=="playing":self.transport.pause()
        else:
            if self.transport.position_seconds()>=self.audio.duration_sec-1e-4:
                self._export_if_dirty();self.transport.seek(0);self._begin_trial("replay")
            self.transport.play()

    def _retry(self):
        if self.audio is None or self._loading:return
        playing=self.transport.state=="playing";self._export_if_dirty();self.transport.pause();self.transport.seek(0);self._begin_trial("retry")
        if playing:self.transport.play()

    def _seek_pressed(self):
        self._seek_was_playing=self.transport.state=="playing";self.transport.pause()

    def _seek_action(self,action):
        # Qt updates sliderPosition before actionTriggered, and value afterwards.
        # This covers keyboard Home/End/arrows and clicks on the groove.
        if self.audio is None or self.seek_slider.isSliderDown() or not action:return
        self._export_if_dirty();self.transport.seek(self.seek_slider.sliderPosition()/1000);self._begin_trial("seek")

    def _seek_released(self):
        if self.audio is None:return
        self._export_if_dirty();self.transport.seek(self.seek_slider.value()/1000);self._begin_trial("seek")
        if self._seek_was_playing:self.transport.play()

    def _state_changed(self,state):
        self.play_button.setText(t("pause") if state=="playing" else t("resume") if state=="paused" else t("play"))
        if not self._loading:self.status_label.setText(t({"ready":"ready","playing":"playing","paused":"paused","stopped":"stopped","empty":"loading"}.get(state,"stopped")))
        for button in self.key_buttons.values():button.setEnabled(state=="playing" and not self._loading)

    def _audio_error(self,message):
        self.status_label.setText(t("load_failed"));self.save_label.setText(message)

    def _finished(self):
        self.status_label.setText(t("finished"));self._export_if_dirty()

    def _tick(self):
        if not self.audio:return
        position=self._presentation_position()
        self.clock_label.setText(f"{_clock(position)} / {_clock(self.audio.duration_sec)}")
        if not self.seek_slider.isSliderDown():
            self.seek_slider.blockSignals(True);self.seek_slider.setValue(max(0,round(position*1000)));self.seek_slider.blockSignals(False)
        if self._mode()!="blind":self.canvas.set_position(position,self.transport.state=="playing")

    def _export_if_dirty(self):
        if self._dirty:self._export(automatic=True)

    def _export(self,automatic=False):
        if not self.log.total_taps:
            if not automatic:self.save_label.setText(t("results_empty"))
            return
        try:
            paths=self.log.export();self._dirty=False
            self.save_label.setText(t("results_saved")+"  "+str(paths[0].name))
        except Exception as exc:self.save_label.setText(t("export_failed")+": "+str(exc))

    def _open_results(self):
        path=self.results_dir
        try:
            path.mkdir(parents=True,exist_ok=True);QDesktopServices.openUrl(QUrl.fromLocalFile(str(path)))
        except OSError as exc:self.save_label.setText(t("export_failed")+": "+str(exc))

    def _open_pair(self):
        self.transport.pause()
        midi,_=QFileDialog.getOpenFileName(self,t("external_midi_title"),str(ROOT),"MIDI (*.mid *.midi)")
        if not midi:return
        audio,_=QFileDialog.getOpenFileName(self,t("external_audio_title"),str(Path(midi).parent),"Audio (*.ogg *.wav *.flac *.mp3 *.m4a)")
        if audio:self._add_external(Path(midi),Path(audio))

    def _add_external(self,midi,audio):
        entry={"cue_id":None,"title":midi.stem,"midi":midi,"audio":audio}
        self.track_combo.addItem(midi.stem,entry);self.track_combo.setCurrentIndex(self.track_combo.count()-1)

    def _help(self):
        self.transport.pause();QMessageBox.information(self,t("help_title"),t("help_body"))

    def eventFilter(self,obj,event):
        if event.type()==QEvent.Type.ApplicationDeactivate or (obj is self and event.type()==QEvent.Type.WindowDeactivate):
            if self.transport.state=="playing":self.transport.pause();self.status_label.setText(t("focus_paused"))
        if event.type()!=QEvent.Type.KeyPress:return super().eventFilter(obj,event)
        app=QApplication.instance()
        if app.activeWindow() is not self or app.activeModalWidget() or app.activePopupWidget():return super().eventFilter(obj,event)
        focus=app.focusWidget()
        if isinstance(focus,(QAbstractSpinBox,QLineEdit,QTextEdit,QPlainTextEdit)):return super().eventFilter(obj,event)
        if event.modifiers() & (Qt.KeyboardModifier.ControlModifier|Qt.KeyboardModifier.AltModifier|Qt.KeyboardModifier.MetaModifier):return super().eventFilter(obj,event)
        if event.isAutoRepeat():
            if event.key() in (Qt.Key.Key_J,Qt.Key.Key_K,Qt.Key.Key_Space,Qt.Key.Key_P,Qt.Key.Key_R):return True
            return super().eventFilter(obj,event)
        key=event.key()
        if key in (Qt.Key.Key_J,Qt.Key.Key_K,Qt.Key.Key_Space):
            self._tap({Qt.Key.Key_J:"J",Qt.Key.Key_K:"K",Qt.Key.Key_Space:"SPACE"}[key]);return True
        if key==Qt.Key.Key_P:self._toggle_play();return True
        if key==Qt.Key.Key_R:self._retry();return True
        if key in (Qt.Key.Key_Return,Qt.Key.Key_Enter):
            if self.transport.state!="playing":self._toggle_play()
            return True
        return super().eventFilter(obj,event)

    def closeEvent(self,event:QCloseEvent):
        self._closing=True;self._load_token+=1;self._timer.stop();self._pool.clear();self._export_if_dirty();self.transport.close()
        QApplication.instance().removeEventFilter(self);event.accept()


def main(argv=None)->int:
    parser=argparse.ArgumentParser(description="Local MIDI rhythm tester")
    parser.add_argument("--smoke",action="store_true");parser.add_argument("--smoke-seconds",type=float,default=3.0)
    parser.add_argument("--screenshot",type=Path);parser.add_argument("--no-autoplay",action="store_true")
    parser.add_argument("--midi",type=Path);parser.add_argument("--audio",type=Path);parser.add_argument("--results-dir",type=Path)
    parser.add_argument("--track",type=int,choices=range(1,13),default=2)
    parser.add_argument("--presentation-offset-ms",type=int,default=0)
    args=parser.parse_args(argv)
    if bool(args.midi)!=bool(args.audio):parser.error("--midi and --audio must be supplied together")
    if not -500<=args.presentation_offset_ms<=1000:parser.error("--presentation-offset-ms must be between -500 and1000")
    app=QApplication.instance() or QApplication([sys.argv[0]])
    families=QFontDatabase.families()
    chosen=next((name for name in ("Noto Sans CJK SC","Source Han Sans SC","WenQuanYi Micro Hei","Microsoft YaHei","PingFang SC") if name in families),app.font().family())
    app.setFont(QFont(chosen,11));apply_theme(app)
    window=MainWindow(midi_path=args.midi,audio_path=args.audio,results_dir=args.results_dir,no_autoplay=True,initial_track=args.track,presentation_offset_ms=args.presentation_offset_ms);window.show()
    attempts=[0]
    def finish_smoke():
        attempts[0]+=1
        if window._loading and attempts[0]<75:QTimer.singleShot(200,finish_smoke);return
        ok=window.audio is not None and not window._loading
        if args.screenshot:
            args.screenshot.parent.mkdir(parents=True,exist_ok=True)
            ok=window.grab().save(str(args.screenshot)) and ok
        if args.smoke:
            print(f"RHYTHM_TESTER_SMOKE_{'OK' if ok else 'FAILED'} ready={window.audio is not None} mode={window._mode()}",flush=True)
            window.close();app.exit(0 if ok else 1)
    if args.smoke or args.screenshot:QTimer.singleShot(max(300,round(args.smoke_seconds*1000)),finish_smoke)
    return app.exec()


if __name__=="__main__":raise SystemExit(main())

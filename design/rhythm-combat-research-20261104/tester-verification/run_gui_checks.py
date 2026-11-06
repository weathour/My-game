"""Qt integration evidence for the local tester, not a perceptual-beat benchmark.

Run with tools/rhythm_tester/.venv/bin/python from the repository; Qt's normal
platform is used (QT_QPA_PLATFORM=offscreen also works). The audio probe uses the
real transport at zero volume. Subsequent input routing fixtures explicitly set
its sampled position/state, so their results do not prove audio device timing.
All exported trial fixtures use a temporary directory, never player data.
"""
from pathlib import Path
import json,sys,time,tempfile
import numpy as np
from PySide6.QtCore import QEvent,Qt,QEventLoop,QTimer
from PySide6.QtGui import QKeyEvent,QFont,QFontDatabase
from PySide6.QtTest import QTest
from PySide6.QtWidgets import QApplication,QWidget,QAbstractSlider
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT))
from tools.rhythm_tester.app import MainWindow
from tools.rhythm_tester.widgets import apply_theme

def run_native_end_to_end(out):
 """Real backend and native event-filter branch; no state/clock monkeypatches."""
 app=QApplication.instance()
 checks=[]
 readings=[]
 temp=tempfile.TemporaryDirectory(prefix="rhythm-native-e2e-")
 w=MainWindow(results_dir=Path(temp.name));w.show()
 def pump(ms=70):
  loop=QEventLoop();QTimer.singleShot(ms,loop.quit);loop.exec();app.processEvents()
 def check(ok,label):
  checks.append({"check":label,"pass":bool(ok)})
  print(("PASS " if ok else "FAIL ")+label,flush=True)
  if not ok:raise AssertionError(label)
 def focus():
  w.raise_();w.activateWindow();w.play_button.setFocus();pump(90)
  check(app.activeWindow() is w,"native main window owns focus")
 def press(key,name):
  print("INPUT_STATE",name,w.transport.state,app.activeWindow() is w,type(app.focusWidget()).__name__,w.status_label.text(),flush=True)
  before=w.transport.position_seconds()
  prior=len(w.judge.events)
  QTest.keyClick(w,key)
  after=w.transport.position_seconds()
  check(len(w.judge.events)==prior+1,"real native "+name+" input recorded")
  event=w.judge.events[-1]
  check(before-1/w.transport.sample_rate<=event["raw_audio_sec"]<=after+1/w.transport.sample_rate,"raw "+name+" is bracketed by actual transport samples")
  check(event["source"]=="keyboard","native "+name+" keeps keyboard source")
  readings.append({"mode":w._mode(),"trial_id":w.log.trials[-1]["trial_id"],"before_audio_sec":before,"after_audio_sec":after,"event":dict(event)})
  return event
 for _ in range(600):
  pump(20)
  if w.audio is not None:break
 check(w.audio is not None and w.track_combo.currentData()["cue_id"]=="midi_test_02","actual default02 OGG and D2 MIDI decoded")
 check(w.transport.state=="ready","initial state is ready without autoplay")
 check("position_seconds" not in w.transport.__dict__ and "play" not in w.transport.__dict__,"transport uses original class clock and playback methods")
 w.volume_slider.setValue(2);focus()
 QTest.keyClick(w,Qt.Key.Key_Return);pump(250)
 p0=w.transport.position_seconds()
 check(w.transport.state=="playing" and p0>0,"actual default audio backend starts at0.02 volume and advances")
 a=press(Qt.Key.Key_J,"J");pump(170)
 b=press(Qt.Key.Key_K,"K");pump(190)
 c=press(Qt.Key.Key_Space,"SPACE")
 check(a["raw_audio_sec"]<b["raw_audio_sec"]<c["raw_audio_sec"],"J K SPACE timestamps progress with real music")
 w.grab().save(str(out/"native-live-pulse.png"))
 QTest.keyClick(w,Qt.Key.Key_P)
 check(w.transport.state=="paused","native P pauses real playback")
 paused=w.transport.position_seconds();pump(240)
 check(abs(w.transport.position_seconds()-paused)<=1/w.transport.sample_rate,"paused real transport position freezes")
 before_taps=w.log.total_taps;QTest.keyClick(w,Qt.Key.Key_J)
 check(w.log.total_taps==before_taps,"paused native key is not captured")
 old_trial=w.log.trial_count;w.seek_slider.setFocus()
 QTest.keyClick(w.seek_slider,Qt.Key.Key_Home);pump(80)
 check(w.transport.position_seconds()<.002 and w.log.trial_count>old_trial,"native Home seeks real transport and creates a new trial")
 focus();QTest.keyClick(w,Qt.Key.Key_Return);pump(180)
 check(w.transport.state=="playing" and w.transport.position_seconds()>0,"real backend resumes after seek")
 press(Qt.Key.Key_J,"J-after-seek")
 old_trial=w.log.trial_count;w.mode_combo.setCurrentIndex(3);pump(60)
 check(w.log.trial_count>old_trial and len(w.plan.times)==0,"blind change creates a reference-free trial")
 if w.transport.state!="playing":focus();QTest.keyClick(w,Qt.Key.Key_Return);pump(120)
 focus();pump(100)
 blind_a=press(Qt.Key.Key_J,"blind-J");pump(170)
 blind_b=press(Qt.Key.Key_K,"blind-K");pump(190)
 blind_c=press(Qt.Key.Key_Space,"blind-SPACE")
 check(all(e["judgement"]=="recorded" and e["target_sec"] is None and e["error_ms"] is None for e in (blind_a,blind_b,blind_c)),"real blind taps have no target assignment or score")
 check(blind_a["raw_audio_sec"]<blind_b["raw_audio_sec"]<blind_c["raw_audio_sec"],"blind raw timestamps progress naturally")
 check(not w.canvas.isVisible() and not w.statistics.isVisible() and not w.analysis_label.isVisible(),"live blind interface hides timing and scoring")
 w.grab().save(str(out/"native-live-blind.png"))
 w.transport.pause();w._export()
 session_file=Path(temp.name)/f"session_{w.log.session_id}.json"
 exported=json.loads(session_file.read_text())
 exported_events=[e for trial in exported["trials"] for e in trial["events"]]
 check(len(exported_events)==len(readings),"all real keyboard events survive multi-trial export")
 check(all(e["raw_audio_sec"]==r["event"]["raw_audio_sec"] for e,r in zip(exported_events,readings)),"export preserves measured real transport timestamps exactly")
 check(all(trial["metadata"]["midi_sha256"]==w.data.sha256 and trial["metadata"]["audio_sha256"]==w.audio.sha256 for trial in exported["trials"]),"real trial exports retain exact MIDI and OGG resource hashes")
 csv_file=session_file.with_suffix(".csv")
 import csv
 with csv_file.open(newline="") as stream:csv_rows=list(csv.DictReader(stream))
 check(len(csv_rows)==len(readings) and all(float(e["raw_audio_sec"])==r["event"]["raw_audio_sec"] for e,r in zip(csv_rows,readings)),"CSV preserves every measured raw audio timestamp")
 (out/"native-session.json").write_bytes(session_file.read_bytes())
 (out/"native-session.csv").write_bytes(csv_file.read_bytes())
 w.transport.stop();check(w.transport.state=="stopped" and w.transport.position_seconds()==0,"real stop tears down playback and resets position")
 w.close();pump(150);check(w.transport.state=="empty","real close releases transport audio")
 report={"kind":"native real-audio end-to-end","platform":app.platformName(),"checks":checks,"count":len(checks),"volume_linear":.02,"clock_state_patched":False,"sampling":"QAudioSink-backed AudioTransport.position_seconds before/inside/after native QTest input","readings":readings,"trial_count":exported["trial_count"],"total_taps":exported["total_taps"],"subjective_listening_claim":False}
 (out/"native-end-to-end.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
 prior=out/"qt-event-checks.json"
 if prior.exists():
  prior_data=json.loads(prior.read_text());prior_data["native_end_to_end"]={"artifact":"native-end-to-end.json","checks":len(checks),"passed":all(c["pass"] for c in checks),"clock_state_patched":False};prior.write_text(json.dumps(prior_data,ensure_ascii=False,indent=2)+"\n")
 temp.cleanup()
 print("NATIVE_END_TO_END_OK",len(checks),"taps=",len(readings),flush=True)


import argparse
parser=argparse.ArgumentParser()
parser.add_argument("--native-e2e",action="store_true")
parser.add_argument("--output-dir",type=Path,default=Path(__file__).resolve().parent)
options=parser.parse_args()
app=QApplication([])
families=QFontDatabase.families()
chosen=next((n for n in ("Noto Sans CJK SC","Source Han Sans SC","WenQuanYi Micro Hei") if n in families),app.font().family())
app.setFont(QFont(chosen,11));apply_theme(app)
out=options.output_dir.resolve();out.mkdir(parents=True,exist_ok=True)
if options.native_e2e:
 run_native_end_to_end(out)
 raise SystemExit(0)
session_temp=tempfile.TemporaryDirectory(prefix="rhythm-gui-fixture-")
w=MainWindow(results_dir=Path(session_temp.name));w.show();w.activateWindow()
checks=[]
def expect(ok,label):
 checks.append({'check':label,'pass':bool(ok)})
 print(('PASS ' if ok else 'FAIL ')+label,flush=True)
 if not ok:raise AssertionError(label)
def pump(ms=50):
 loop=QEventLoop();QTimer.singleShot(ms,loop.quit);loop.exec();app.processEvents()
def focus_main():
 w.raise_();w.activateWindow();w.play_button.setFocus();pump(60)
for _ in range(300):
 pump(10)
 if w.audio is not None or (not w._loading and w.status_label.text()=='加载失败'):break
print("LOAD_STATE",w._loading,w.status_label.text(),w.save_label.text(),flush=True)
expect(w.audio is not None,'default catalog load completes asynchronously')
expect(w.track_combo.currentData()['cue_id']=='midi_test_02','default is mOBSCENE')
expect(w.transport.state=='ready','initial audio does not autoplay')
expect(len(w.plan.times)>100,'pulse plan has inferred time grid')
expect(np.array_equal(w.canvas.starts,w.judge.starts) and np.array_equal(w.canvas.ends,w.judge.ends),'visual and judge window boundaries agree')
w.grab().save(str(out/'pulse-1140x800.png'))
# Actual transport check is independent of the mocked event-time fixtures below.
w.volume_slider.setValue(0);w.transport.play();pump(180)
state=w.transport.state;position=w.transport.position_seconds()
print('LIVE_TRANSPORT',state,position,flush=True)
transport_probe={'check':'actual audio backend playback position advances','pass':state=='playing' and position>0,'state':state,'position':position,'volume':0,'separate_from_clock_fixtures':True}
w.transport.pause()
# UI event routing uses an explicit controlled audio position; backend timing is
# assessed separately above, not inferred from these deterministic fixtures.
raw=[float(w.plan.times[2])]
w.transport.position_seconds=lambda:raw[0]
w.transport.set_clicks=lambda *args,**kwargs:None
w.transport.seek=lambda sec:raw.__setitem__(0,float(sec))
def pause():w.transport._state='paused';w._state_changed('paused')
def play(*args):w.transport._state='playing';w._state_changed('playing')
w.transport.pause=pause;w.transport.play=play
focus_main();play()
QTest.keyClick(w,Qt.Key.Key_J);QTest.keyClick(w,Qt.Key.Key_K)
expect(len(w.judge.events)==2 and w.judge.events[0]['judgement']=='hit' and w.judge.events[1]['judgement']=='duplicate','fresh keys captured, shared reference duplicate classified')
n=len(w.judge.events)
auto=QKeyEvent(QEvent.Type.KeyPress,Qt.Key.Key_J,Qt.KeyboardModifier.NoModifier,'j',True,1)
QApplication.sendEvent(w,auto)
expect(len(w.judge.events)==n,'keyboard auto-repeat does not record')
w.window_spin.setFocus();pump();QTest.keyClick(w.window_spin,Qt.Key.Key_J)
expect(len(w.judge.events)==n,'spin editor does not leak a tap')
w.setFocus();other=QWidget();other.show();other.activateWindow();pump()
QTest.keyClick(other,Qt.Key.Key_J)
expect(len(w.judge.events)==n,'another active window does not record a tap')
other.close();focus_main();play()
QTest.mouseClick(w.key_buttons['SPACE'],Qt.MouseButton.LeftButton)
expect(w.judge.events[-1]['source']=='mouse','mouse key records separate input source')
# Keyboard slider action reads sliderPosition before value propagation.
before=w.log.trial_count
w.seek_slider.setFocus();QTest.keyClick(w.seek_slider,Qt.Key.Key_End);pump()
expect(abs(raw[0]-w.audio.duration_sec)<.002 and w.log.trial_count>before,'keyboard End actually seeks and starts a new trial')
before=w.log.trial_count
QTest.keyClick(w.seek_slider,Qt.Key.Key_Home);pump()
expect(raw[0]==0 and w.log.trial_count>before,'keyboard Home actually seeks and starts a new trial')
# Every mode creates a separate segment and preserves old recorded events.
w.mode_combo.setCurrentIndex(2);pump()
expect(not w.layer_combo.isEnabled() and not w.phase_combo.isEnabled(),'onset comparison disables layer and phase')
expect(np.array_equal(w.canvas.starts,w.judge.starts),'dense onset display uses judge windows')
w.mode_combo.setCurrentIndex(3);pump()
expect(not w.canvas.isVisible() and not w.statistics.isVisible() and not w.error_plot.isVisible() and not w.analysis_label.isVisible(),'blind mode hides pulse, scores, errors and analysis')
expect(not w.click_check.isEnabled() and not w.window_spin.isEnabled() and len(w.plan.times)==0,'blind mode has no reference or click controls')
raw[0]=1.234;focus_main();play();QTest.keyClick(w,Qt.Key.Key_J)
e=w.judge.events[-1]
expect(e['judgement']=='recorded' and e['target_sec'] is None and e['error_ms'] is None,'blind tap contains no target or score')
w.grab().save(str(out/'blind-1140x800.png'))
w.mode_combo.setCurrentIndex(0);pump();w.resize(940,660);pump()
w.grab().save(str(out/'pulse-940x660.png'))
expect(w.size().width()==940 and w.size().height()==660,'small window accepts intended minimum size')
w.compensation_spin.setValue(100);pump()
raw[0]=float(w.plan.times[3])+.1;focus_main();play();QTest.keyClick(w,Qt.Key.Key_J)
expect(abs(w.judge.events[-1]['error_ms'])<1e-7,'positive compensation advances raw tap by100ms')
QApplication.sendEvent(w,QEvent(QEvent.Type.ApplicationDeactivate))
expect(w.transport.state=='paused','application focus loss automatically pauses')
w._export();files=list(Path(session_temp.name).glob('*.json'))
expect(len(files)==1,'all trials export to one session JSON')
payload=json.loads(files[0].read_text())
expect(payload['total_taps']>=5 and payload['trial_count']>=7,'trial changes retain prior taps')
expect(all('midi_sha256' in x['metadata'] and 'audio_sha256' in x['metadata'] and 'reference_times_sec' in x['metadata'] for x in payload['trials']),'trial provenance includes resource hashes and exact reference grid')
w.close();pump(150)
session_temp.cleanup()
(out/'qt-event-checks.json').write_text(json.dumps({'ui_checks':checks,'ui_count':len(checks),'transport_probe':transport_probe,'fixture_semantics':'UI routing checks use explicitly controlled AudioTransport sampled time/state; not an audio-clock accuracy or perceptual-beat evaluation'},ensure_ascii=False,indent=2)+'\n')
print('QT_EVENT_CHECKS_OK',len(checks),flush=True)

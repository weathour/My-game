"""Native Qt checks for the feedback fixes; no fake playback clock or state.

This verifies compensation/recording and uninterrupted playback. It cannot
measure acoustic arrival at the ear or infer the listener's preferred beat.
"""
from pathlib import Path
import csv
import json
import sys
import tempfile
import time
import functools
import traceback

from PySide6.QtCore import QEventLoop, QTimer, Qt
from PySide6.QtGui import QFont, QFontDatabase
from PySide6.QtTest import QTest
from PySide6.QtWidgets import QApplication

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT))
from tools.rhythm_tester.app import MainWindow
from tools.rhythm_tester.widgets import apply_theme

app=QApplication([])
font=next((n for n in ('Noto Sans CJK SC','WenQuanYi Micro Hei') if n in QFontDatabase.families()),app.font().family())
app.setFont(QFont(font,11));apply_theme(app)
out=Path(__file__).resolve().parent
checks=[]
trace=[]
def check(ok,label):
    checks.append({'check':label,'pass':bool(ok)})
    print(('PASS ' if ok else 'FAIL ')+label,flush=True)
    if not ok:raise AssertionError(label)
def pump(ms=80):
    loop=QEventLoop();QTimer.singleShot(ms,loop.quit);loop.exec();app.processEvents()

with tempfile.TemporaryDirectory(prefix='rhythm-feedback-') as directory:
    w=MainWindow(results_dir=Path(directory));w.show();w.raise_();w.activateWindow()
    deadline=time.monotonic()+25
    while w.audio is None and time.monotonic()<deadline:pump(40)
    def trace_point(label,**extra):
        sink=w.transport._sink
        row={'label':label,'monotonic_sec':time.monotonic(),'state':w.transport.state,'sink_id':id(sink) if sink is not None else None,
             'generation':w.transport._sink_generation,'position':w.transport.position_seconds(),
             'duration_sec':w.transport.duration_seconds,'buffer_at_end':w.transport._buffer.atEnd() if w.transport._buffer is not None else None,
             'buffer_pos':w.transport._buffer.pos() if w.transport._buffer is not None else None,
             'buffer_size':w.transport._buffer.size() if w.transport._buffer is not None else None,
             'active_window':app.activeWindow() is w,'focus':type(app.focusWidget()).__name__,
             'mode':w._mode(),'click_checked':w.click_check.isChecked(),'applied_click':w._applied_click,
             'slider_down':w.seek_slider.isSliderDown(),'slider_value':w.seek_slider.value(),
             'slider_position':w.seek_slider.sliderPosition(),**extra}
        if sink is not None:
            try:row.update(sink_state=str(sink.state()),sink_error=str(sink.error()),processed_sec=sink.processedUSecs()/1e6,buffer_remaining=w.transport._buffer.bytesAvailable() if w.transport._buffer is not None else None)
            except RuntimeError as exc:row['qt_wrapper_error']=str(exc)
        trace.append(row);print('TRACE '+json.dumps(row),flush=True)
        (out/'feedback-gui-trace.json').write_text(json.dumps({'trace':trace,'observation_wrappers_only':True,'patched_clock_or_state':False},indent=2)+'\n')
    for method_name in ('play','pause','resume','seek','set_clicks','_start_backend','_discard_backend','_fail_output','_handle_sink_state'):
        original=getattr(w.transport,method_name)
        def wrap(original=original,name=method_name):
            @functools.wraps(original)
            def observed(*args,**kwargs):
                stack=[f'{Path(frame.filename).name}:{frame.lineno}:{frame.name}' for frame in traceback.extract_stack(limit=7)[:-1]]
                trace_point(name+':enter',stack=stack,args=[repr(a)[:80] for a in args],kwargs={k:repr(v) for k,v in kwargs.items()})
                result=original(*args,**kwargs)
                trace_point(name+':exit')
                return result
            return observed
        setattr(w.transport,method_name,wrap())
    w.transport.stateChanged.connect(lambda state:trace_point('transport.stateChanged',emitted=state))
    w.transport.error.connect(lambda error:trace_point('transport.error',error=error))
    w.seek_slider.actionTriggered.connect(lambda action:trace_point('slider.actionTriggered',action=int(action)))
    w.seek_slider.sliderPressed.connect(lambda:trace_point('slider.pressed'))
    w.seek_slider.sliderReleased.connect(lambda:trace_point('slider.released'))
    trace_point('loaded')
    check(w.audio is not None,'actual default D2 audio and MIDI load')
    check(w.presentation_spin.value()==0,'output presentation correction defaults to zero, no guessed acoustic latency')
    w.volume_slider.setValue(2);w.play_button.setFocus();pump(100)
    QTest.keyClick(w,Qt.Key.Key_Return);pump(350)
    check(w.transport.state=='playing' and w.transport.position_seconds()>.1,'real audio clock advances')
    sink=w.transport._sink;generation=w.transport._sink_generation
    before=w.transport.position_seconds()
    w.presentation_spin.setValue(150);w.compensation_spin.setValue(30);w.window_spin.setValue(100)
    pump(100)
    check(w.transport._sink is sink and w.transport._sink_generation==generation,'timing and window changes keep the exact audio stream')
    check(w.transport.state=='playing' and w.transport.position_seconds()>=before,'timing change does not reset playback position')
    w._tick()
    check(abs(w.canvas.position-w._presentation_position())<.025,'visual timeline uses output correction once')
    check(app.activeWindow() is w,'native tester owns focus')
    w.play_button.setFocus();QTest.keyClick(w,Qt.Key.Key_J)
    check(len(w.judge.events)==1,'real key is captured after compensation changes')
    event=w.judge.events[-1]
    check(abs(event['presentation_audio_sec']-(event['raw_audio_sec']-.15))<1e-9,'raw input remains unchanged and presentation subtracts150ms')
    check(abs(event['corrected_audio_sec']-(event['raw_audio_sec']-.18))<1e-9,'input correction subtracts30ms independently')
    w.mode_combo.setCurrentIndex(1);pump(90)
    check(w.transport._sink is sink and w.transport._sink_generation==generation,'reference mode change without clicks does not rebuild music')
    trace_point("before_K")
    QTest.keyClick(w,Qt.Key.Key_K)
    trace_point("after_K")
    trace_point('before_first_grab');w.grab().save(str(out/'feedback-live-pulse.png'));trace_point('after_first_grab')
    trace_point('before_small_resize');w.resize(940,660);pump(80);trace_point('after_small_resize');w.grab().save(str(out/'feedback-small-window.png'));trace_point('after_small_grab')
    trace_point("before_large_resize");w.resize(1140,800);trace_point("before_blind_mode");w.mode_combo.setCurrentIndex(3);trace_point("after_blind_mode_sync");pump(90);trace_point("after_blind_mode_pump")
    check(w.transport._sink is sink,'blind mode without clicks keeps playback continuous')
    check(not w.canvas.isVisible() and not w.statistics.isVisible(),'blind mode still hides reference and scores')
    w.play_button.setFocus();QTest.keyClick(w,Qt.Key.Key_Space)
    blind=w.judge.events[-1]
    check(blind['judgement']=='recorded' and blind['error_ms'] is None and blind['target_sec'] is None,'blind corrected input has no target or score')
    check(blind['presentation_offset_ms']==150,'blind capture retains presentation correction provenance')
    w.grab().save(str(out/'feedback-live-blind.png'))
    w.transport.pause();w._export()
    paths=list(Path(directory).glob('*.json'));payload=json.loads(paths[0].read_text())
    check(payload['schema_version']==2,'new exports explicitly version changed timeline semantics')
    all_events=[e for trial in payload['trials'] for e in trial['events']]
    check(payload['total_taps']==3,'all real taps survive multiple settings segments')
    check(all(e['presentation_offset_ms']==150 and e['compensation_ms']==30 for e in all_events),'JSON retains both independent corrections')
    with paths[0].with_suffix('.csv').open(newline='') as stream:rows=list(csv.DictReader(stream))
    check(len(rows)==3 and all(float(row['presentation_offset_ms'])==150 for row in rows),'CSV retains correction and exact raw timestamps')
    (out/'feedback-session.json').write_text(json.dumps(payload,indent=2,ensure_ascii=False)+'\n')
    (out/'feedback-session.csv').write_bytes(paths[0].with_suffix('.csv').read_bytes())
    w.close();pump(100)
    check(w.transport.state=='empty','close releases audio and saves user-style records')
(out/'feedback-gui-checks.json').write_text(json.dumps({'checks':checks,'count':len(checks),'real_audio':True,'patched_clock_or_state':False,'subjective_accuracy_claim':False},indent=2)+'\n')
print('FEEDBACK_GUI_OK',len(checks),flush=True)

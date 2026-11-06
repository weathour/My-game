"""Inspect nominal MIDI/audio onset alignment, not perceptual beat accuracy.

Uses only existing rendered game audio. No microphone or system audio capture.
Spectral flux has32ms analysis support and instrument-dependent attack delay;
its strongest correlation lag is not a hardware latency calibration.
"""
from pathlib import Path
import json
import subprocess
import sys

import numpy as np

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))
from tools.rhythm_tester.analysis import parse_midi


def check(cue):
    midi_path = ROOT / 'design/music-20261104-chinese-12/arrangements' / cue / 'D2.mid'
    audio_path = ROOT / 'assets/music/midi_test' / (cue+'.ogg')
    data = parse_midi(midi_path)
    rate, hop, frame = 16000, 80, 512
    payload = subprocess.run(['ffmpeg','-nostdin','-v','error','-i',str(audio_path),
                              '-ac','1','-ar',str(rate),'-f','f32le','-'],
                             capture_output=True,check=True).stdout
    audio = np.frombuffer(payload,dtype='<f4')
    windows = np.lib.stride_tricks.sliding_window_view(audio, frame)[::hop]
    spectrum = np.abs(np.fft.rfft(windows*np.hanning(frame),axis=1)).astype(np.float32)
    frequency = np.fft.rfftfreq(frame,1/rate)
    times = (np.arange(len(windows))*hop+frame/2)/rate
    features={}
    for name, mask in [('full',frequency>=30), ('low',(frequency>=30)&(frequency<=180)),
                       ('high',frequency>=800)]:
        magnitude = np.log1p(spectrum[:,mask]*10)
        flux = np.maximum(0,np.diff(magnitude,axis=0,prepend=magnitude[:1])).sum(axis=1)
        scale = np.quantile(flux,.95) or 1
        features[name]=np.minimum(3,flux/scale)
    lags=np.arange(-.3,.3001,.005)
    results=[]
    for start in np.arange(0,min(data.duration_sec,180),30):
        end=min(start+30,data.duration_sec)
        for family, feature in [('all','full'),('kick','low'),('snare','high'),('bass','low')]:
            notes=[n for n in data.notes if start+.5<n.time_sec<end-.5
                   and (family=='all' or n.family==family)]
            q=np.unique([round(n.time_sec,3) for n in notes])
            if len(q)<8:continue
            scores=np.array([np.mean(np.interp(q+lag,times,features[feature])) for lag in lags])
            top=np.argsort(scores)[::-1][:5]
            zero=int(np.argmin(abs(lags)))
            results.append({'start_sec':float(start),'end_sec':float(end),
                            'family':family,'onset_count':len(q),
                            'best_lag_ms':round(float(lags[top[0]]*1000),2),
                            'top_lags_ms':[round(float(lags[i]*1000),2) for i in top],
                            'score_at_zero_over_best':float(scores[zero]/scores[top[0]]) if scores[top[0]] else None})
    return {'cue_id':cue,'midi_sha256':data.sha256,'declared_trim_sec':data.trim_sec,
            'audio_file':str(audio_path.relative_to(ROOT)),'results':results}


if __name__=='__main__':
    output={'method':'positive spectral flux at5ms hop/32ms support, compare nominal MIDI onset families',
            'limitations':'dense periodic attacks cause aliases; instrument attacks differ; not tactus truth or device latency',
            'songs':[check(cue) for cue in ('midi_test_02','midi_test_10')]}
    path=Path(__file__).with_name('audio-file-alignment.json')
    path.write_text(json.dumps(output,indent=2)+'\n')
    for song in output['songs']:
        print(song['cue_id'],[(r['start_sec'],r['family'],r['best_lag_ms']) for r in song['results'] if r['family']=='kick'])

#!/usr/bin/env python3
"""Independent static/runtime checks for master.py using existing render evidence."""
import json, tempfile, sys, subprocess, shutil
from pathlib import Path
import numpy as np
from scipy.signal import fftconvolve
from scipy.io import wavfile
HERE=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(HERE))
import master
scores={c['id']:c for c in json.loads((HERE/'score.json').read_text())}
report={'scope':'existing renders only; no publication, no listening review','checks':[]}
# Compare implemented circular convolution against the middle steady-state period
# obtained by explicit multi-period linear convolution.
room=master.room_impulse(); rng=np.random.default_rng(7); x=rng.normal(0,.01,(48000,2)).astype(np.float32)
y=master.room(x,True)
errs=[]
for ch in range(2):
    repeated=np.tile(x[:,ch],3)
    conv=fftconvolve(repeated,room[:,ch])
    expected=conv[len(x):2*len(x)]
    actual=y[:,ch]-x[:,ch]
    errs.append(float(np.max(np.abs(actual-.09*expected))))
report['checks'].append({'name':'circular_room_equals_steady_period','max_abs_error':max(errs),'pass':max(errs)<2e-6})
# Process existing short cues from renders in a temp directory; check tail cap,
# frame count, levels, and encoded decode.
render_root=HERE/'renders-world-p0'
with tempfile.TemporaryDirectory(prefix='music-master-independent-') as td:
    out=Path(td)
    for folder in ('prepared','masters','music'): (out/folder).mkdir()
    cue_results=[]
    for id in ('stinger_victory','stinger_transform','stinger_reward_rare'):
        pre=master.prepare(scores[id],render_root/id,out)
        result=master.encode(scores[id],pre,pre['suggested_gain'],out)
        max_frames=round((scores[id]['beats']*60/scores[id]['bpm']+2)*master.RATE)
        cue_results.append({'id':id,'frames':result['frames'],'seconds':result['seconds'],'nominal_seconds':scores[id]['beats']*60/scores[id]['bpm'],'tail_limited':pre['tail_limited'],'within_nominal_plus_2s':result['frames']<=max_frames,'lufs':result['integrated_lufs'],'true_peak_dbtp':result['true_peak_dbtp'],'tail_quiet':result['frames']<480 or float(np.max(np.abs(wavfile.read(out/'prepared'/f'{id}.wav')[1][-480:])))<=.001,'pass':result['frames']==pre['frames'] and result['frames']<=max_frames and (result['frames']<480 or float(np.max(np.abs(wavfile.read(out/'prepared'/f'{id}.wav')[1][-480:])))<=.001)})
    report['checks'].append({'name':'existing_short_cue_prepare_encode','results':cue_results,'pass':all(x['pass'] for x in cue_results)})
# Confirm malformed/old score input is rejected before producing prepared PCM.
old=dict(scores['stinger_victory']); old['bpm']+=1
with tempfile.TemporaryDirectory(prefix='music-master-stale-score-') as td:
    try: master.prepare(old,render_root/'stinger_victory',Path(td)); rejected=False; why='accepted'
    except ValueError as exc: rejected=True; why=str(exc)
report['checks'].append({'name':'old_or_stale_score_rejected','pass':rejected,'evidence':why})
# Exercise CLI publish refusal, same-job resume, changed score, and changed render
# source using only temporary paths and the existing P0 render.
def cli(score_path, render_path, output_path, *extra):
    return subprocess.run([sys.executable,str(HERE/'master.py'),'--score',str(score_path),
        '--renders',str(render_path),'--output',str(output_path),*extra],
        stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
with tempfile.TemporaryDirectory(prefix='music-master-cli-review-') as td:
    base=Path(td); score_path=HERE/'score.json'; render_path=render_root
    out=base/'publish-partial'
    refused=cli(score_path,render_path,out,'--publish','stinger_victory')
    report['checks'].append({'name':'publish_partial_cli_refusal','exit_code':refused.returncode,'output_dir_created':out.exists(),'diagnostic':refused.stderr[-250:],'pass':refused.returncode!=0 and not out.exists()})
    # A valid one-cue job can be resumed unchanged. A modified score is refused
    # as a different job before it can reuse its prior masters.
    resume_out=base/'resume'
    first=cli(score_path,render_path,resume_out,'stinger_victory')
    again=cli(score_path,render_path,resume_out,'stinger_victory') if first.returncode==0 else first
    changed_data=json.loads(score_path.read_text()); changed_data[0]['bpm']+=1
    changed_score=base/'score-changed.json'; changed_score.write_text(json.dumps(changed_data))
    changed=cli(changed_score,render_path,resume_out,'stinger_victory') if again.returncode==0 else again
    report['checks'].append({'name':'same_job_resume_and_changed_score_rejection','first_exit':first.returncode,'resume_exit':again.returncode,'changed_score_exit':changed.returncode,'diagnostic':changed.stderr[-250:],'pass':first.returncode==0 and again.returncode==0 and changed.returncode!=0 and 'different master job' in changed.stderr})
    # Copy one existing render so its root stays fixed, then mutate only mix.wav.
    copied=base/'renders'; shutil.copytree(render_root/'stinger_victory',copied/'stinger_victory')
    source_out=base/'source-change'
    source_first=cli(score_path,copied,source_out,'stinger_victory')
    if source_first.returncode==0:
        wav=copied/'stinger_victory'/'mix.wav'; data=bytearray(wav.read_bytes()); data[-16]^=1; wav.write_bytes(data)
        source_changed=cli(score_path,copied,source_out,'stinger_victory')
    else: source_changed=source_first
    report['checks'].append({'name':'changed_render_source_rejected_on_resume','first_exit':source_first.returncode,'changed_exit':source_changed.returncode,'diagnostic':source_changed.stderr[-250:],'pass':source_first.returncode==0 and source_changed.returncode!=0 and 'Changed input' in source_changed.stderr})
(HERE/'checks/master_review.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))

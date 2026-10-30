#!/usr/bin/env python3
"""Master verified dry renders, check actual Vorbis, then publish one complete roster."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import shutil
import subprocess
import tempfile

import numpy as np
from scipy.io import wavfile
from scipy.signal import fftconvolve, butter, sosfilt

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
RATE=48000
VERSION='chronicle-master-3'

def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def dump(path,data): Path(path).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
def run(*args):
    return subprocess.run(['ffmpeg','-hide_banner','-nostdin','-y',*map(str,args)],check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
def loudness(path):
    data=run('-i',path,'-af','loudnorm=I=-23:TP=-3:LRA=14:print_format=json','-f','null','-').stderr.decode()
    return json.loads(data[data.rindex('{'):data.rindex('}')+1])


def room_impulse():
    """Small deterministic diffuse room, with a 17 ms direct-path gap.

    This is a generated effect, not a sampled room or an instrument source.
    Energy-normalized response keeps the 0.09 send genuinely small.
    """
    n=round(.82*RATE)
    rng=np.random.default_rng(20261030)
    response=rng.standard_normal((n,2)).astype(np.float32)
    response=sosfilt(butter(2,[220,6500],btype='bandpass',fs=RATE,output='sos'),response,axis=0)
    t=np.arange(n)/RATE
    response*=np.exp(-t[:,None]*9.5)
    response[:round(.017*RATE)]=0
    response[-480:]*=np.linspace(1,0,480)[:,None]
    for ch in range(2): response[:,ch]/=np.sqrt(np.sum(response[:,ch]**2))
    return response.astype(np.float32)


def room(data,loop,send=.09):
    impulse=room_impulse()
    result=np.empty_like(data) if loop else np.zeros((len(data)+len(impulse)-1,2),np.float32)
    for ch in range(2):
        wet=fftconvolve(data[:,ch],impulse[:,ch])
        if loop:
            # Circular convolution is the steady-state room of consecutive periods.
            wet[:len(wet)-len(data)]+=wet[len(data):]
            result[:,ch]=data[:,ch]+send*wet[:len(data)]
        else:
            result[:len(data),ch]=data[:,ch]
            result[:,ch]+=send*wet
    return result


def prepare(cue,render,output):
    source=render/'mix.wav'
    score=json.loads((render/'score.json').read_text())
    # Only musical inputs affect the audio; copy text/labels separately in catalog.
    keys=('bpm','meter','beats','loop','tracks')
    if any(score[k]!=cue[k] for k in keys): raise ValueError(cue['id']+': stale render')
    report=json.loads((render/'render-report.json').read_text())
    if sha(source)!=report['mix']['sha256']: raise ValueError('Modified render '+str(source))
    bad=[a for t in report['tracks'] for a in t['audit'] if a['type'] in
         ('range_extension','velocity_region_repair','round_robin_region_repair','recorded_sustain_exhausted')]
    if bad: raise ValueError(f'{cue["id"]}: unresolved render audits {bad[:3]}')
    rate,data=wavfile.read(source)
    if rate!=RATE or data.ndim!=2 or data.shape[1]!=2 or not np.isfinite(data).all(): raise ValueError('Invalid PCM')
    if cue['loop'] and len(data)!=round(cue['beats']*60/cue['bpm']*RATE): raise ValueError(cue['id']+': period frame mismatch')
    if np.max(np.abs(data))>=1: raise ValueError(cue['id']+': clipped source')
    if np.sqrt(np.mean(data.astype(float)**2))<1e-6: raise ValueError(cue['id']+': silent source')
    data=room(data,cue['loop'])
    tail_limited=False
    if not cue['loop']:
        # Retain a quiet release, trimming only an already near-silent remainder.
        audible=np.flatnonzero(np.max(np.abs(data),axis=1)>1e-6)
        data=data[:min(len(data),int(audible[-1])+4801)]
        # Notification beds must return promptly; two seconds beyond the written
        # phrase retain a musical release without ten-second bell ducking.
        cap=round((cue['beats']*60/cue['bpm']+2.0)*RATE)
        tail_limited=len(data)>cap
        data=data[:cap]
        fade=round(.75*RATE) if tail_limited else 2400
        data[-fade:]*=np.linspace(1,0,fade,dtype=np.float32)[:,None]
    destination=output/'prepared'/f'{cue["id"]}.wav'
    wavfile.write(destination,RATE,data)
    measured=loudness(destination)
    return {'render':str(render.resolve()),'source_sha256':sha(source),'prepared':str(destination),
            'prepared_sha256':sha(destination),'frames':len(data),'tail_limited':tail_limited,'pre_loudness':measured,
            'suggested_gain':min(cue['target_lufs']-float(measured['input_i']),-3.5-float(measured['input_tp']))}


def encode(cue,pre,gain,output):
    pcm=Path(pre['prepared'])
    flac=output/'masters'/f'{cue["id"]}.flac'
    ogg=output/'music'/f'{cue["id"]}.ogg'
    run('-i',pcm,'-af',f'volume={gain:.8f}dB','-c:a','flac','-sample_fmt','s32',
        '-bits_per_raw_sample','24','-compression_level','8','-metadata','title='+cue['title'],
        '-metadata','artist=My-game original score',flac)
    loop_tags=['-metadata','LOOPSTART=0','-metadata',f'LOOPEND={pre["frames"]}'] if cue['loop'] else []
    run('-i',flac,'-c:a','libvorbis','-q:a','6',*loop_tags,ogg)
    final=loudness(ogg)
    with tempfile.TemporaryDirectory(prefix='mygame-encoded-qa-') as temp:
        decoded=Path(temp)/'decode.wav'
        run('-i',ogg,'-c:a','pcm_f32le',decoded)
        rate,data=wavfile.read(decoded)
    if rate!=RATE or len(data)!=pre['frames'] or not np.isfinite(data).all(): raise ValueError('Vorbis duration/data mismatch '+cue['id'])
    if float(final['input_tp'])>-2.8 or float(final['input_i'])>cue['target_lufs']+.5: raise ValueError('Encoded level '+cue['id'])
    rms=float(np.sqrt(np.mean(data.astype(float)**2)))
    mono=float(np.sqrt(np.mean(data.mean(axis=1,dtype=float)**2)))
    mono_db=20*math.log10(max(mono,1e-12)/rms)
    if mono_db < -3.1: raise ValueError('Mono cancellation '+cue['id'])
    step=float(np.max(np.abs(data[0]-data[-1])))
    typical=float(np.quantile(np.abs(np.diff(data,axis=0)),.999))
    if cue['loop'] and step>max(.004,1.5*typical): raise ValueError(f'Loop boundary {cue["id"]} {step} / {typical}')
    if not cue['loop'] and np.max(np.abs(data[-480:]))>.001: raise ValueError('Nonquiet one-shot tail '+cue['id'])
    return {'id':cue['id'],'seconds':len(data)/RATE,'frames':len(data),'sample_rate':RATE,'channels':2,
            'loop':cue['loop'],'integrated_lufs':float(final['input_i']),'true_peak_dbtp':float(final['input_tp']),
            'loudness_range_lu':float(final['input_lra']),'mono_loss_db':round(mono_db,4),
            'vorbis_boundary_step':step,'typical_large_step':typical,'linear_gain_db':gain,
            'phase_family':cue.get('phase_family'),'source_sha256':pre['source_sha256'],
            'release_limited_to_two_seconds_after_score':pre['tail_limited'],
            'flac_sha256':sha(flac),'ogg_sha256':sha(ogg),'listening_review':False}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--score',type=Path,default=HERE/'score.json')
    p.add_argument('--renders',type=Path,nargs='+',required=True)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--publish',action='store_true',help='Install only a complete 70-cue verified roster')
    p.add_argument('cues',nargs='*')
    a=p.parse_args()
    all_cues=json.loads(a.score.read_text())
    if set(a.cues)-{c['id'] for c in all_cues}: p.error('Unknown cue')
    cues=[c for c in all_cues if not a.cues or c['id'] in a.cues]
    if a.publish and len(cues)!=70: p.error('Partial roster cannot be published')
    output=a.output.resolve()
    output.mkdir(parents=True,exist_ok=True)
    config={'version':VERSION,'script_sha256':sha(__file__),'score_sha256':sha(a.score),
            'renders':[str(r.resolve()) for r in a.renders],'cues':[c['id'] for c in cues]}
    config_path=output/'job.json'
    if config_path.exists() and json.loads(config_path.read_text())!=config: p.error('Output belongs to a different master job')
    dump(config_path,config)
    for folder in ('prepared','masters','music'): (output/folder).mkdir(exist_ok=True)
    prepath=output/'preparation.json'
    pre=json.loads(prepath.read_text()) if prepath.exists() else {}
    for cue in cues:
        id=cue['id']
        found=[r/id for r in a.renders if (r/id/'mix.wav').exists()]
        if not found: raise ValueError('Missing render '+id)
        render=found[-1] # Explicit later roots take precedence for repaired versions.
        if id in pre:
            if sha(render/'mix.wav')!=pre[id]['source_sha256'] or sha(pre[id]['prepared'])!=pre[id]['prepared_sha256']: raise ValueError('Changed input '+id)
        else:
            pre[id]=prepare(cue,render,output)
            dump(prepath,pre)
            print('PREPARED',id,pre[id]['pre_loudness']['input_i'],flush=True)
    gains={id:row['suggested_gain'] for id,row in pre.items()}
    # Match the perceived level of each complete arrangement independently.
    # A shared scalar would make a quiet orchestration follow an unrelated
    # transient in its partner. The game uses complementary linear gains when
    # crossfading synchronous phases, so level-matched shared material stays safe.
    qapath=output/'audio-qa.json'
    qa=json.loads(qapath.read_text()) if qapath.exists() else {}
    for cue in cues:
        id=cue['id']
        if id in qa:
            if sha(output/'music'/f'{id}.ogg')!=qa[id]['ogg_sha256']: raise ValueError('Changed master '+id)
            continue
        qa[id]=encode(cue,pre[id],gains[id],output)
        dump(qapath,qa)
        print('VERIFIED',id,qa[id]['integrated_lufs'],qa[id]['true_peak_dbtp'],flush=True)
    if a.publish:
        catalog=json.loads((a.score.parent/'catalog.staged.json').read_text())
        if {c['id'] for c in catalog['cues']}!=set(qa) or len(qa)!=70: raise ValueError('Incomplete catalog')
        game=ROOT/'assets/music/chronicle'
        game.mkdir(parents=True,exist_ok=True)
        for id in qa:
            final=game/f'{id}.ogg'
            if final.exists() and sha(final)==qa[id]['ogg_sha256']: continue
            staging=final.with_suffix('.ogg.tmp')
            shutil.copy2(output/'music'/f'{id}.ogg',staging)
            staging.replace(final)
        path=ROOT/'assets/data/audio/music_catalog.json'
        path.parent.mkdir(parents=True,exist_ok=True)
        dump(path.with_suffix('.json.tmp'),catalog)
        path.with_suffix('.json.tmp').replace(path)
        dump(HERE/'audio-qa.json',qa)
        dump(HERE/'production-lock.json',config|{'master_output':str(output),'catalog_sha256':sha(path),'listening_review':False})
        print('PUBLISHED 70 VERIFIED CUES',flush=True)

if __name__=='__main__': main()

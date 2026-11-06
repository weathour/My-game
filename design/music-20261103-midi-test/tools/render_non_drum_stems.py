#!/usr/bin/env python3
"""Render frozen MIDI pitched events with the pinned local multisample engine.

This is the non-drum stage of the MIDI test renderer. It preserves absolute MIDI
ticks, tempo-map seconds, pitches, velocities, note durations, and all source
MIDI events; drum stems are handled by a separately licensed complete-kit stage.
"""
from __future__ import annotations
import argparse, collections, hashlib, importlib.util, json, math, re, sys
from pathlib import Path

import mido
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt

ROOT = Path(__file__).resolve().parents[3]
DESIGN = ROOT / 'design/music-20261103-midi-test'
OLD = ROOT / 'design/music-20261030/audio_engine.py'
sys.path.insert(0, str(OLD.parent))
spec = importlib.util.spec_from_file_location('audio_engine', OLD)
engine = importlib.util.module_from_spec(spec); sys.modules[spec.name] = engine; spec.loader.exec_module(engine)
RATE = 48000
CACHE = Path.home() / '.cache/my-game/music-instruments'
MANIFEST = DESIGN / 'instrument-source-lock.json'

def sha(path):
    h=hashlib.sha256()
    with open(path,'rb') as f:
        for b in iter(lambda:f.read(1<<20),b''): h.update(b)
    return h.hexdigest()

def parse_midi(path):
    mf=mido.MidiFile(path)
    merged=mido.merge_tracks(mf.tracks)
    # Build a stable tick->seconds tempo map using all tempo events.
    events=[]; tick=0; tempo=500000; sec=0.0; prev=0
    for msg in merged:
        tick += msg.time
        sec += mido.tick2second(tick-prev,mf.ticks_per_beat,tempo)
        prev=tick
        if msg.type=='set_tempo': tempo=msg.tempo
        events.append((tick,sec,msg))
    # Each track is independently decoded with the exact shared global tempo map.
    tempo_rows=[(0,0.0,500000)]
    tempo=500000; last_tick=0; now=0.0
    for t,s,m in events:
        if m.type=='set_tempo':
            tempo_rows.append((t,s,m.tempo)); tempo=m.tempo
    def tosec(t):
        row=tempo_rows[0]
        for cand in tempo_rows[1:]:
            if cand[0]>t: break
            row=cand
        return row[1]+mido.tick2second(t-row[0],mf.ticks_per_beat,row[2])
    tracks=[]; all_notes=0; max_end=0.0; midi_end_tick=0
    for ti,tr in enumerate(mf.tracks):
        name=next((m.name for m in tr if m.type=='track_name'),f'track_{ti+1}')
        inst=next((m.program for m in tr if m.type=='program_change'),0)
        abs_tick=0; active=collections.defaultdict(collections.deque); notes=[]; channel_program={}
        for m in tr:
            abs_tick += m.time; t=tosec(abs_tick)
            midi_end_tick=max(midi_end_tick,abs_tick)
            if m.type=='program_change': channel_program[m.channel]=m.program
            if m.type=='note_on' and m.velocity>0:
                active[(m.channel,m.note)].append((abs_tick,t,m.velocity,channel_program.get(m.channel,inst)))
            elif m.type=='note_off' or (m.type=='note_on' and m.velocity==0):
                q=active[(m.channel,m.note)]
                if q:
                    st,ts,v,pr=q.popleft(); dur=max(0.001,t-ts)
                    notes.append({'channel':m.channel,'pitch':m.note,'velocity':v,'start_tick':st,'end_tick':abs_tick,'start_s':ts,'end_s':t,'duration_s':dur,'program':pr})
        for (ch,p),q in active.items():
            while q:
                st,ts,v,pr=q.popleft(); end_tick=max(st,abs_tick); end_s=tosec(end_tick)
                notes.append({'channel':ch,'pitch':p,'velocity':v,'start_tick':st,'end_tick':end_tick,'start_s':ts,'end_s':end_s,'duration_s':max(.001,end_s-ts),'program':pr,'unterminated':True})
        all_notes+=len(notes)
        if notes: max_end=max(max_end,max(n['end_s'] for n in notes))
        tracks.append({'index':ti,'name':name,'program':inst,'notes':notes})
    return mf,tracks,max(max_end,tosec(midi_end_tick)),midi_end_tick

def role(track):
    n=track['name'].lower(); p=track['program']
    if any(x in n for x in ('drum','percussion')) or any(x['channel']==9 for x in track['notes']): return 'drums'
    if 'bass' in n or p in range(32,40): return 'bass'
    if any(x in n for x in ('guitar','gtr')) or p in range(24,32): return 'guitar'
    if 'piano' in n or p in (0,1,2,3): return 'piano'
    return 'aux'

def process(data, kind):
    """Deterministic amp/cab shaping; no time-domain lookahead/latency."""
    x=data.astype(np.float32,copy=True)
    if kind=='guitar':
        # Mild nonlinear amp stage followed by a cab-style 5.2 kHz low-pass.
        x=np.tanh(x*3.2).astype(np.float32)*0.86
        x=sosfilt(butter(2,5200,fs=RATE,output='sos'),x,axis=0).astype(np.float32)
        x=sosfilt(butter(1,95,fs=RATE,btype='highpass',output='sos'),x,axis=0).astype(np.float32)
    elif kind=='bass':
        x=np.tanh(x*1.75).astype(np.float32)*0.88
        x=sosfilt(butter(2,4800,fs=RATE,output='sos'),x,axis=0).astype(np.float32)
    elif kind=='piano':
        x=sosfilt(butter(2,7600,fs=RATE,output='sos'),x,axis=0).astype(np.float32)
    else:
        x*=0.45
    return x

def render_track(track,sampler,frames,audit):
    kind=role(track); y=np.zeros((frames,2),dtype=np.float32)
    if kind=='drums': return y,kind
    if kind=='guitar': instrument='electric_guitar'; patch='emilyguitar'; trim='guitar'
    elif kind=='bass': instrument='bass'; patch='fashionbass'; trim='bass'
    elif kind=='piano': instrument='piano'; patch='VSUpright1'; trim='piano'
    else: instrument='pad'; patch=None; trim='aux'
    inst=sampler.manifest['instruments'][instrument]
    for ei,n in enumerate(track['notes']):
        start=round(n['start_s']*RATE); hold=n['duration_s']; pitch=n['pitch']; vel=n['velocity']
        if patch is None:
            voice=engine.synth_voice(inst,pitch,vel,hold)
        else:
            voice_parts=[]
            for region in sampler.select(patch,pitch,vel,ei,'attack',audit):
                voice_parts.append(sampler.voice(region,pitch,vel,hold,inst,audit))
            if not voice_parts:
                audit.append({'type':'missing_region','pitch':pitch,'role':kind}); continue
            voice=sum(voice_parts)
        stop=min(frames,start+len(voice))
        if stop>start: y[start:stop]+=voice[:stop-start]
    y=process(y,trim)
    # Fixed stem headroom/gain; not velocity editing.
    gain={'guitar':0.36,'bass':0.48,'piano':0.34,'aux':0.24}[kind]
    return y*gain,kind

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--midi',type=Path,required=True); ap.add_argument('--out',type=Path,required=True); ap.add_argument('--title',default='')
    a=ap.parse_args(); a.out.mkdir(parents=True,exist_ok=True)
    mf,tracks,midi_end,midi_end_tick=parse_midi(a.midi); frames=round((midi_end+2.0)*RATE)
    manifest=engine.load_manifest(MANIFEST); sampler=engine.Sampler(manifest,CACHE)
    abs_tick=0; tempo_map_by_tick={}; meter_map_by_tick={}; cc_count=0
    for msg in mido.merge_tracks(mf.tracks):
        abs_tick+=msg.time
        if msg.type=='set_tempo': tempo_map_by_tick[abs_tick]=msg.tempo
        elif msg.type=='time_signature': meter_map_by_tick[abs_tick]=(msg.numerator,msg.denominator)
        elif msg.type=='control_change': cc_count+=1
    tempo_map=[{'tick':t,'microseconds_per_beat':v} for t,v in sorted(tempo_map_by_tick.items())]
    meter_map=[{'tick':t,'numerator':v[0],'denominator':v[1]} for t,v in sorted(meter_map_by_tick.items())]
    report={'title':a.title,'source_midi':str(a.midi),'source_midi_sha256':sha(a.midi),'ticks_per_beat':mf.ticks_per_beat,
            'midi_end_tick':midi_end_tick,'midi_end_seconds':midi_end,'render_seconds':frames/RATE,'sample_rate':RATE,'full_note_count':sum(len(t['notes']) for t in tracks),
            'source_tempo_map':tempo_map,'source_meter_map':meter_map,'source_control_change_count':cc_count,
            'non_drum_stage_only':True,'tracks':[],'listening_review':False}
    for tr in tracks:
        if not tr['notes']: continue
        audit=[]; data,kind=render_track(tr,sampler,frames,audit)
        if kind=='drums':
            report['tracks'].append({'track_index':tr['index'],'name':tr['name'],'program':tr['program'],'role':kind,'note_count':len(tr['notes']),
                                     'stem':None,'stem_sha256':None,'mapping_audit':audit,'events':tr['notes'],
                                     'rendered_by':'render_gm_drum_oneshots.py'})
            continue
        name=re.sub(r'[^A-Za-z0-9_-]+','_',tr['name']).strip('_') or f'track_{tr["index"]+1}'
        path=a.out/f'{tr["index"]+1:02d}_{name}.wav'; wavfile.write(path,RATE,data)
        report['tracks'].append({'track_index':tr['index'],'name':tr['name'],'program':tr['program'],'role':kind,'note_count':len(tr['notes']),
                                 'stem':path.name,'stem_sha256':sha(path),'mapping_audit':audit,'events':tr['notes']})
    (a.out/'non-drum-render-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'title':a.title,'note_count':report['full_note_count'],'duration':midi_end,'stems':len(report['tracks']),'out':str(a.out)},ensure_ascii=False))
if __name__=='__main__': main()

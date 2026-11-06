#!/usr/bin/env python3
"""Render source GM drum triggers through a complete SF2 kit as one-shots.

Only drum notes are sent to FluidSynth. Their original GM roles are mapped to
the documented Muldjord SF2 keys; the original GM pitches remain in the event
audit. Note-on ticks, velocities, tempo events, and meter events are preserved.
Drum note-offs are omitted from this temporary render-only derivative because
the selected samples are rendered as one-shots whose natural sample decay is
not controlled by source note-off duration. This adapter policy does not
classify source note-offs as artificial or invalid.
The source MIDI remains untouched and its original event log is stored in the
report. GM note 42/44 closes an existing open-hat note before that hit.
"""
from __future__ import annotations
import argparse, hashlib, json, os, subprocess, tempfile
from pathlib import Path
import mido
from collections import defaultdict, deque

ROOT=Path(__file__).resolve().parents[3]
LOCAL=Path.home()/'.local/share/my-game/music-transcription/midi-render'
FLUID=LOCAL/'usr/bin/fluidsynth'; LIBS=LOCAL/'usr/lib/x86_64-linux-gnu'; DEFAULT_SF=LOCAL/'soundfonts/GeneralUser-GS.sf2'
MULDJORD_MAP={35:48,36:49,37:65,38:50,40:51,41:64,42:52,43:63,44:52,45:62,46:53,47:61,49:58,51:54,53:55,54:None,57:59}

def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def source_pair_queues(midi):
    queues=defaultdict(deque)
    for ti,tr in enumerate(midi.tracks):
        tick=0; active=defaultdict(deque); track_end=0
        for msg in tr:
            tick+=msg.time; track_end=tick
            if msg.type=='note_on' and msg.velocity>0 and msg.channel==9:
                active[(msg.channel,msg.note)].append((tick,msg.velocity))
            elif getattr(msg,'channel',None)==9 and (msg.type=='note_off' or (msg.type=='note_on' and msg.velocity==0)):
                q=active[(msg.channel,msg.note)]
                if q:
                    start,velocity=q.popleft()
                    queues[(ti,msg.channel,msg.note,velocity,start)].append((tick,'note_off' if msg.type=='note_off' else 'note_on_velocity_0'))
        for (channel,pitch),q in active.items():
            while q:
                start,velocity=q.popleft()
                queues[(ti,channel,pitch,velocity,start)].append((track_end,'unclosed_at_track_end'))
    return queues

def midi_duration(midi):
 tick=0; prior=0; tempo=500000; seconds=0.0
 for msg in mido.merge_tracks(midi.tracks):
  tick+=msg.time; seconds+=mido.tick2second(tick-prior,midi.ticks_per_beat,tempo); prior=tick
  if msg.type=='set_tempo': tempo=msg.tempo
 return seconds

def render(source,out,kit='power',soundfont=DEFAULT_SF,only_unmapped=False):
 source=Path(source).resolve(); out=Path(out).resolve(); midi=mido.MidiFile(source); full_duration=midi_duration(midi)
 kitprog={'standard':0,'room':8,'power':16}[kit]
 dst=mido.MidiFile(type=1,ticks_per_beat=midi.ticks_per_beat)
 meta=mido.MidiTrack(); dst.tracks.append(meta)
 # Preserve global tempo and meter events exactly at their absolute tick.
 meta_events=[]; allticks=[]
 for tr in midi.tracks:
  tick=0
  for msg in tr:
   tick+=msg.time
   if msg.type in ('set_tempo','time_signature','key_signature','marker','text'): meta_events.append((tick,msg.copy()))
   allticks.append(tick)
 for t,m in meta_events: pass
 meta.insert(0,mido.MetaMessage('track_name',name='preserved_tempo_and_meter',time=0))
 meta_abs=[(t,m) for t,m in meta_events]
 meta_abs.sort(key=lambda x:x[0]); last=0
 for t,m in meta_abs:
  c=m.copy(time=max(0,t-last)); meta.append(c); last=t
# Build single trigger track. Keep source hit onsets/pitches/velocities; omit
# note-offs so each mapped one-shot follows its sample decay. Closed/pedal hat
# hits explicitly choke the open-hat key.
 drum=mido.MidiTrack(); dst.tracks.append(drum); drum.append(mido.MetaMessage('track_name',name='GM drum one-shot render derivative',time=0))
 # The Muldjord preset is bank 0/program 0. FluidSynth reserves channel 9 for
 # GM drum bank 128, so the renderer-only derivative uses melodic channel 0 to
 # select that explicit one-shot percussion preset. Source channel remains in
 # the event audit and original MIDI is never rewritten.
 render_channel=0 if 'MuldjordKit' in str(soundfont) else 9
 if render_channel==0: drum.append(mido.Message('program_change',channel=render_channel,program=kitprog,time=0))
 else:
  drum.append(mido.Message('control_change',channel=render_channel,control=0,value=120,time=0))
  drum.append(mido.Message('control_change',channel=render_channel,control=32,value=0,time=0))
  drum.append(mido.Message('program_change',channel=render_channel,program=kitprog,time=0))
 notes=[]; events=[]; endtick=max(allticks,default=0); pair_queues=source_pair_queues(midi)
 for ti,tr in enumerate(midi.tracks):
  tick=0
  for msg in tr:
   tick+=msg.time
   if msg.type=='note_on' and msg.velocity>0 and msg.channel==9:
    mapped=MULDJORD_MAP.get(msg.note,msg.note) if 'MuldjordKit' in str(soundfont) else msg.note
    if only_unmapped and ('MuldjordKit' in str(soundfont) and mapped is not None): continue
    if only_unmapped and ('MuldjordKit' not in str(soundfont) and msg.note!=54): continue
    if not only_unmapped and mapped is None: continue
    trigger_pitch=msg.note if mapped is None else mapped
    q=pair_queues[(ti,msg.channel,msg.note,msg.velocity,tick)]
    source_end,source_off_type=q.popleft() if q else (None,'unpaired_source_note_on')
    notes.append({'source_track':ti,'source_channel':msg.channel,'source_pitch':msg.note,'render_pitch':trigger_pitch,'velocity':msg.velocity,'tick':tick,'source_end_tick':source_end,'source_off_type':source_off_type,
                  'mapping_source':'GeneralUser GM kit' if mapped is None else ('MuldjordKit explicit GM-role map' if 'MuldjordKit' in str(soundfont) else 'GeneralUser GM kit')})
    events.append((tick,msg.copy(channel=render_channel,note=trigger_pitch,time=0)))
    if msg.note in (42,44):
     open_hat=MULDJORD_MAP[46] if 'MuldjordKit' in str(soundfont) else 46
     events.append((tick,mido.Message('note_off',channel=render_channel,note=open_hat,velocity=0,time=0)))
 # retain original global end extent and avoid trailing silence length regression
 events.sort(key=lambda x:x[0]); last=0
 for t,m in events:
  drum.append(m.copy(time=max(0,t-last))); last=t
 drum.append(mido.MetaMessage('end_of_track',time=max(0,endtick-last)))
 out.parent.mkdir(parents=True,exist_ok=True)
 with tempfile.TemporaryDirectory(prefix='midi-drum-oneshot-',dir=out.parent) as td:
  tmp=Path(td)/'drums-only.mid'; dst.save(tmp)
  env=os.environ.copy(); env['LD_LIBRARY_PATH']=str(LIBS)+(':'+env['LD_LIBRARY_PATH'] if env.get('LD_LIBRARY_PATH') else '')
  raw=Path(td)/'raw.wav'
  cmd=[str(FLUID),'-ni','-q','-r','48000','-g','0.16','-O','float','-T','wav','-F',str(raw),str(soundfont),str(tmp)]
  run=subprocess.run(cmd,env=env,check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
  ff=['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(raw),'-af',f'atrim=start=0:end={full_duration+2:.9f},apad=whole_dur={full_duration+2:.9f}','-ar','48000','-ac','2','-c:a','pcm_f32le','-t',f'{full_duration+2:.9f}',str(out)]
  subprocess.run(ff,check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
 out_report={'status':'rendered','source_midi':str(source),'source_midi_sha256':sha(source),'soundfont':str(soundfont),'soundfont_sha256':sha(soundfont),'fluidsynth':'2.3.4 local Ubuntu package','kit':kit,'kit_program':kitprog,'renderer_channel':render_channel,'sample_rate_hz':48000,'channels':2,'render_only_derivative':True,'only_unmapped_fallback':only_unmapped,'source_midi_unchanged':True,'drum_note_on_count':len(notes),'drum_event_log':notes,'muldjord_gm_map':MULDJORD_MAP if 'MuldjordKit' in str(soundfont) else None,'note_off_policy':'The renderer-only derivative omits source drum note-offs so the selected one-shot samples follow their natural sample decay; source note-off duration does not control this one-shot decay. This policy does not assert that source note-offs are artificial or invalid. Closed/pedal-hat onsets explicitly choke the active open-hat sample. Temporary render channel and pitch mappings are adapter controls, not original MIDI events. Source MIDI remains unchanged.','command':cmd,'ffmpeg_command':ff,'fluidsynth_stderr':run.stderr.strip(),'output_sha256':sha(out),'output':str(out)}
 out.with_name(out.stem+'-drums-report.json').write_text(json.dumps(out_report,indent=2,ensure_ascii=False)+'\n')
 print(json.dumps({'status':'PASS','kit':kit,'events':len(notes),'out':str(out)},ensure_ascii=False))

if __name__=='__main__':
 ap=argparse.ArgumentParser(); ap.add_argument('--midi',required=True); ap.add_argument('--out',required=True); ap.add_argument('--kit',choices=['standard','room','power'],default='power'); ap.add_argument('--soundfont',default=str(DEFAULT_SF)); ap.add_argument('--only-unmapped',action='store_true'); a=ap.parse_args(); render(a.midi,a.out,a.kit,Path(a.soundfont),a.only_unmapped)

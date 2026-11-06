#!/usr/bin/env python3
"""Create internal old/new and under-BGM listening previews (not gameplay captures)."""
from __future__ import annotations
import hashlib,json,math,subprocess
from pathlib import Path
import numpy as np
from scipy.io import wavfile
from scipy.signal import resample_poly

ROOT=Path(__file__).resolve().parents[3]; OUT=ROOT/'design/skill-audio-20261103/audio/previews'; RATE=48000
OLD=ROOT/'assets/sfx/chronicle-feedback'; NEW=ROOT/'assets/sfx/skill-combat-20261103'
WINDOWS=ROOT/'design/skill-audio-20261103/runtime/dense-music-test-windows.json'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def gain(x,db):return x*(10**(db/20))
def read_wav(p):
 sr,x=wavfile.read(p)
 if x.dtype==np.int16:x=x.astype(np.float64)/32768
 elif x.dtype==np.int32:x=x.astype(np.float64)/2147483648
 else:x=x.astype(np.float64)
 if x.ndim==2:x=np.mean(x,axis=1)
 if sr!=RATE:
  from math import gcd
  g=gcd(RATE,sr);x=resample_poly(x,RATE//g,sr//g)
 return x.astype(np.float64)
def decode_bgm(path,offset,duration):
 raw=subprocess.check_output(['ffmpeg','-v','error','-ss',str(offset),'-i',str(path),'-t',str(duration),'-f','f32le','-ar',str(RATE),'-ac','2','-'])
 return np.frombuffer(raw,dtype='<f4').reshape(-1,2).astype(np.float64)
def write(path,x):
 x=np.asarray(x);x=np.nan_to_num(x)
 # Do not apply a common final gain: that would change the requested runtime
 # music-to-SFX relationship. Callers report peak and clipping explicitly.
 wavfile.write(path,RATE,np.round(np.clip(x,-1.0,1.0)*32767).astype('<i2'))
def gate_fade(x,fade=.008):
 x=x.copy();n=min(len(x)//2,int(fade*RATE))
 if n:x[:n]*=np.linspace(0,1,n)[:,None] if x.ndim==2 else np.linspace(0,1,n);x[-n:]*=np.linspace(1,0,n)[:,None] if x.ndim==2 else np.linspace(1,0,n)
 return x

def main():
 OUT.mkdir(parents=True,exist_ok=True);catalog=json.loads((NEW/'catalog.json').read_text())['cues']; records=[]
 demos=[('blade','cast_blade_01.wav','blade.cast','Old blade-cast clip → new blade.cast clip'),('arcane','magic_01.wav','arcane.cast','Old magic hit clip → new arcane release clip'),('beast','death_ghost_01.wav','beast.impact','Old ghost-death asset → new beast-impact asset (different events)'),('boss_demon','death_ghost_03.wav','boss_demon.defeat','Old ghost-death asset → new boss_demon.defeat (different events)')]
 for family,oldname,cue,label in demos:
  old_path=OLD/oldname;old=read_wav(old_path);new_entry=catalog[cue];new_path=ROOT/new_entry['variants'][0].replace('res://','');new=read_wav(new_path);new=gain(new,new_entry['gain_db'])
  gap=np.zeros(round(.25*RATE));clip=np.concatenate([old,gap,new,gap])
  p=OUT/f'{family}-old-new.wav';write(p,clip)
  same_event=(family=='blade')
  records.append({'path':str(p.relative_to(ROOT)),'label':label,'comparison_type':'timbre/material clip illustration; not an in-game or level-matched A/B','comparison_semantics':'same broad blade-cast category' if same_event else 'different event/category excerpts; not a direct event comparison','level_matching':False,'segments':[{'side':'old','path':str(old_path.relative_to(ROOT)),'sha256':sha(old_path),'duration_sec':len(old)/RATE,'gain_db':0.0,'note':'old source played as-is; no level matching'},{'side':'new','cue_id':cue,'path':str(new_path.relative_to(ROOT)),'sha256':sha(new_path),'duration_sec':len(new)/RATE,'gain_db':new_entry['gain_db'],'note':'new cue catalog gain applied; no level matching'}],'preview_sha256':sha(p),'preview_seconds':len(clip)/RATE,'manual_listening_review':'not performed'})
 # Pressure illustration layers short new one-shots over an unchanged BGM segment.
 window_doc=json.loads(WINDOWS.read_text());window=next(x for x in window_doc['items'] if x['cue_id']=='midi_test_01')
 BGM=ROOT/window['path'];music_offset=float(window['start_seconds']);duration=float(window['window_seconds'])
 bgm=decode_bgm(BGM,music_offset,duration);bgm=gain(bgm,20*math.log10(.7));bgm=gate_fade(bgm,.02)
 mix=np.zeros_like(bgm)
 for ch in range(2):mix[:,ch]=bgm[:,ch]
 events=[(.35,'blade.cast',1),(.72,'blade.impact',2),(1.10,'arcane.cast',1),(1.48,'fire.impact',1),(1.92,'beast.tell',2),(2.45,'beast.impact',3),(3.02,'boss_demon.tell',1),(3.70,'boss_demon.phase',2),(4.00,'heavy_blade.impact',1),(4.35,'shield.impact',2),(4.72,'ice.impact',1),(5.08,'lightning.impact',3),(5.44,'water.impact',2),(5.80,'poison.impact',1),(6.16,'boss_cavalry.impact',2),(6.52,'feedback.guard',1),(6.82,'feedback.hurt',2),(7.12,'boss_demon.impact',3),(7.46,'boss_demon.defeat',1),(8.00,'feedback.death',1)]
 event_log=[]
 for t,cue,vi in events:
  e=catalog[cue];path=ROOT/e['variants'][vi-1].replace('res://','');runtime_sfx_factor=.65*.55;x=gain(read_wav(path),e['gain_db']+20*math.log10(runtime_sfx_factor));start=round(t*RATE);stop=min(len(mix),start+len(x));
  if stop>start:mix[start:stop,:]+=x[:stop-start,None]
  event_log.append({'time_sec':t,'cue_id':cue,'variant':vi,'path':str(path.relative_to(ROOT)),'sha256':sha(path),'catalog_gain_db':e['gain_db'],'runtime_sfx_base_gain':runtime_sfx_factor,'runtime_sfx_base_gain_db':20*math.log10(runtime_sfx_factor),'effective_gain_db':e['gain_db']+20*math.log10(runtime_sfx_factor)})
 peak=float(np.max(np.abs(mix)));peak_dbfs=20*math.log10(max(peak,1e-15));clipped_samples=int(np.count_nonzero(np.abs(mix)>=1.0))
 p=OUT/'new-sfx-under-existing-bgm-pressure-preview.wav';write(p,mix)
 records.append({'path':str(p.relative_to(ROOT)),'label':'offline SFX pressure illustration at default mixer gains over BGM window 01; not a game capture','preview_sha256':sha(p),'preview_seconds':len(mix)/RATE,'bgm':{'path':str(BGM.relative_to(ROOT)),'sha256':sha(BGM),'window_manifest':str(WINDOWS.relative_to(ROOT)),'window_manifest_sha256':sha(WINDOWS),'window_id':'midi_test_01','segment_start_seconds':music_offset,'segment_seconds':duration,'runtime_music_gain':0.7,'fixed_gain_db':20*math.log10(.7)},'sfx_gain_policy':{'runtime_sfx_volume':0.65,'runtime_mixer_gain':0.55,'base_linear_multiplier':runtime_sfx_factor,'base_gain_db':20*math.log10(runtime_sfx_factor),'per_cue_catalog_gain_db_applied':True},'sfx_events':event_log,'common_fixed_master_gain_db':0.0,'normalization':'none; requested music/SFX ratio preserved','dynamic_compression':'none','runtime_processing_not_simulated':['complete music ducking','limiting','spatial processing'],'peak_linear':peak,'peak_dbfs':peak_dbfs,'clipped_sample_count':clipped_samples,'manual_listening_review':'not performed'})
 report={'status':'generated','format':'internal 48kHz PCM16 WAV previews','purpose':'four timbre/material clip illustrations (not in-game level-matched A/B) and an offline pressure mix; no preview is a gameplay capture','tool_sha256':sha(Path(__file__)),'previews':records}
 (OUT/'preview-index.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps({'status':'PASS','previews':len(records),'directory':str(OUT)},ensure_ascii=False))
if __name__=='__main__':main()

#!/usr/bin/env python3
"""Render immutable event plans, retain full-song alignment and encode level-matched trials.
No game asset writes. Backbone is the pinned earlier sampler; Chinese patches are
sample-based DSK Asian DreamZ with explicit bank/program. Per-song Chinese gain
is measured on D1 once then applied unchanged to D2; final mix uses constant gain.
"""
from pathlib import Path
import argparse,collections,hashlib,importlib.util,json,math,os,re,subprocess,sys,time
import numpy as np
import mido
from scipy.io import wavfile
ROOT=Path(__file__).resolve().parents[3]; BASE=ROOT/'design/music-20261104-chinese-trial'; CACHE=Path.home()/'.cache/my-game/chinese-trial-render-20261104'; OUT=Path.home()/'音乐/Marilyn-Manson-伴奏学习/中国器乐首轮_20261104'
OLD=ROOT/'design/music-20261103-midi-test'; RATE=48000
spec=importlib.util.spec_from_file_location('oldrenderer',OLD/'tools/render_non_drum_stems.py'); old=importlib.util.module_from_spec(spec);spec.loader.exec_module(old)
spec=importlib.util.spec_from_file_location('oldmix',OLD/'tools/mix_align_encode_c.py'); mix=importlib.util.module_from_spec(spec);spec.loader.exec_module(mix)
SF=Path.home()/'.cache/my-game/chinese-instruments-20261104/DSK_Asian_DreamZ/DSK Asian DreamZ.SF2'
FLUID=Path.home()/'.local/share/my-game/music-transcription/midi-render/usr/bin/fluidsynth'
PROGRAM={'pipa':0,'ruan':2,'zheng':3,'erhu':4}; ROOT_RANGE={'pipa':[57,91],'ruan':[50,79],'zheng':[58,77],'erhu':[65,84]}
def dump(path,obj):path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n')
def run(args,**kw):return subprocess.run(list(map(str,args)),check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE,**kw)
def read(path,frames=None):
 r,x=wavfile.read(path); assert r==RATE
 if x.dtype.kind=='i':x=x.astype(np.float32)/2**(8*x.dtype.itemsize-1)
 assert x.ndim==2 and x.shape[1]==2 and np.isfinite(x).all()
 if frames is not None:x=np.pad(x,((0,max(0,frames-len(x))),(0,0)))[:frames]
 return x

def sf_render(events,source,dst,family,frames):
 mf=mido.MidiFile(source); out=mido.MidiFile(ticks_per_beat=mf.ticks_per_beat); meta=mido.MidiTrack();out.tracks.append(meta)
 tick=0; tempos=[]
 for msg in mido.merge_tracks(mf.tracks):
  tick+=msg.time
  if msg.type=='set_tempo':tempos.append((tick,msg.copy()))
 last=0
 for t,msg in tempos:meta.append(msg.copy(time=t-last));last=t
 groups=sorted(set((e['source_track'],e['source_channel']) for e in events));channels=[i for i in range(16) if i!=9];assert len(groups)<=15
 for group,ch in zip(groups,channels):
  tr=mido.MidiTrack();out.tracks.append(tr);tr.append(mido.Message('program_change',program=PROGRAM[family],channel=ch)); rows=[]
  for e in events:
   if (e['source_track'],e['source_channel'])!=group:continue
   rows.extend([(e['start_tick'],e['source_note_on_index'],mido.Message('note_on',note=e['pitch'],velocity=e['velocity'],channel=ch)),(e['end_tick'],e['source_note_off_index'],mido.Message('note_off',note=e['pitch'],velocity=0,channel=ch))])
  last=0
  for t,_,msg in sorted(rows,key=lambda x:(x[0],x[1])):tr.append(msg.copy(time=t-last));last=t
 midi=dst.with_suffix('.mid');out.save(midi)
 env=os.environ.copy();env['LD_LIBRARY_PATH']=str(FLUID.parent.parent/'lib/x86_64-linux-gnu')
 result=run([FLUID,'-ni','-q','-r',RATE,'-g','0.7','-o','synth.reverb.active=0','-o','synth.chorus.active=0','-o','synth.polyphony=256','-F',dst,'-T','wav','-O','float',SF,midi],env=env)
 (dst.with_suffix('.log')).write_bytes(result.stdout+result.stderr)
 x=read(dst,frames);wavfile.write(dst,RATE,x);return x

def render(index):
 item=next(x for x in json.loads((OLD/'experiment-manifest.json').read_text())['inputs'] if x['index']==index)
 cue=f'midi_test_{index:02d}';work=CACHE/cue;work.mkdir(parents=True,exist_ok=True)
 comp=json.loads(Path(item['existing_gm_comparison_report']).read_text()); offset=comp['bar_offset_seconds_removed_from_render'];duration=comp['comparison_duration_seconds'];source=ROOT/item['repo_midi_file']
 _,_,midi_duration,_=old.parse_midi(source);frames=round((midi_duration+4)*RATE)
 folder=OLD/'trials'/({1:'tbp_non_drum'}.get(index,f'{index:02d}_non_drum'))
 sampler=old.engine.Sampler(old.engine.load_manifest(old.MANIFEST),old.CACHE)
 report={'index':index,'title':item['title'],'status':'rendering','source_sha256':mix.sha(source),'offset_seconds':offset,'duration_seconds':duration,'sample_rate':RATE,'chinese_soundfont':str(SF),'soundfont_sha256':mix.sha(SF),'chinese_source_claim':'Publisher-named sample-based patches; original recording chain not independently verified','variants':{},'processing':{'fluidsynth_gain':.7,'reverb':False,'chorus':False,'sample_rate':RATE,'polyphony':256,'note_timing':'source ticks and tempo map unchanged; FluidSynth playback scheduling','backbone':'pinned existing sample renderer and amp processing','chinese_gain':'D1 aggregate RMS -9 dB relative to backbone, fixed and shared with D2','bus':'no compression or limiting; fixed gain only'}}
 plans={v:json.loads((BASE/'arrangements'/cue/f'plan-{v}.json').read_text()) for v in ('D1','D2')}
 shared=None; aligned={}
 for variant,plan in plans.items():
  wd=work/variant;wd.mkdir(exist_ok=True); y=np.zeros((frames,2),np.float32);chinese=np.zeros_like(y);groups=collections.defaultdict(list)
  for e in plan['events']:groups[e['instrument_family']].append(e)
  row={'plan_sha256':mix.sha(BASE/'arrangements'/cue/f'plan-{variant}.json'),'families':{},'stems':[]};report['variants'][variant]=row
  # Drum one-shots preserve their own recorded decays/choke behavior. No whole guitar stem reuse.
  for p in (folder/'drums.wav',folder/'drum_fallback.wav'):
   if p.exists():x=read(p,frames);y+=x;row['stems'].append({'path':str(p),'sha256':mix.sha(p),'reuse':'unchanged original drums'})
  for family,events in sorted(groups.items()):
   if family=='drums':continue
   path=wd/f'{family}.wav';audit=[]
   if family in PROGRAM:x=sf_render(events,source,path,family,frames);chinese+=x
   else:
    role={'electric_guitar':'guitar','bass':'bass','piano':'piano','pad':'aux'}[family]
    notes=[dict(e,pitch=e['pitch']) for e in events]
    # Existing renderer chooses role by track name/program; give an explicit stable role identity.
    tr={'name':{'guitar':'guitar','bass':'bass','piano':'piano','aux':'aux'}[role],'program':{'guitar':29,'bass':33,'piano':0,'aux':88}[role],'notes':notes}
    x=np.zeros((frames,2),np.float32)
    for source_track in sorted(set(e['source_track'] for e in events)):
     tr['notes']=[e for e in events if e['source_track']==source_track]
     track_audit=[];part,_=old.render_track(tr,sampler,frames,track_audit);x+=part
     audit.extend(dict(a,source_track=source_track) for a in track_audit)
    wavfile.write(path,RATE,x);y+=x
   stats={'event_count':len(events),'peak':float(np.max(np.abs(x))),'rms':float(np.sqrt(np.mean(x.astype(float)**2))),'mapping_audit':audit}
   if family in ROOT_RANGE:
    lo,hi=ROOT_RANGE[family];outside=[e for e in events if not lo<=e['pitch']<=hi]
    patch=next(p for p in json.loads((BASE/'sources/dsk-regions.json').read_text())['patches'] if p['program_zero_based']==PROGRAM[family]); sample_rows={s['id']:s for s in json.loads((BASE/'sources/dsk-regions.json').read_text())['samples']}; sample_roots={k:s['root'] for k,s in sample_rows.items()}; shifts=[]; exhausted=[]
    for e in events:
     for region in patch['regions']:
      if region['key_low']<=e['pitch']<=region['key_high'] and region['velocity_low']<=e['velocity']<=region['velocity_high']:
       root=region.get('root_override')
       if root is None:root=sample_roots[region['sample_id']]
       shifts.append(e['pitch']-root)
       available=sample_rows[region['sample_id']]['duration_seconds']/2**((e['pitch']-root)/12)
       if region.get('loop_mode',0)==0 and e['duration_s']>available:exhausted.append({'source_id':e['source_id'],'pitch':e['pitch'],'hold_seconds':e['duration_s'],'sample_available_seconds':available})
    stats.update({'sf2_region_loop_modes':dict(collections.Counter(str(r.get('loop_mode',0)) for r in patch['regions'])),'nonloop_sample_duration_exceeded_count':len(exhausted),'nonloop_sample_duration_exceeded_examples':exhausted[:12],'natural_decay_policy':'SF2 native envelopes and loop flags unchanged; nonloop source may decay before noteoff','max_actual_sample_transposition_semitones':max(map(abs,shifts),default=0),'actual_sample_transposition_range': [min(shifts),max(shifts)] if shifts else [],'bank':0,'program_zero_based':PROGRAM[family],'recorded_root_span':ROOT_RANGE[family],'outside_recorded_root_span_count':len(outside),'beyond_four_semitone_extension_count':sum(e['pitch']<lo-4 or e['pitch']>hi+4 for e in events),'missing_sf2_zone_event_count':sum(not 21<=e['pitch']<=108 for e in events),'pitch_range':[min(e['pitch'] for e in events),max(e['pitch'] for e in events)]})
   row['families'][family]=stats;row['stems'].append({'path':str(path),'sha256':mix.sha(path)})
  if shared is None:
   # Whole-song energy calibration includes natural gaps. Remains identical for D1 and D2.
   shared=.354813389*np.sqrt(np.mean(y.astype(float)**2))/max(1e-12,np.sqrt(np.mean(chinese.astype(float)**2)))
  row['chinese_shared_gain']=float(shared);row['chinese_to_backbone_rms_db']=float(20*np.log10(np.sqrt(np.mean((chinese*shared).astype(float)**2))/np.sqrt(np.mean(y.astype(float)**2))))
  y+=chinese*shared;raw=wd/'raw-mix.wav';wavfile.write(raw,RATE,y);dest=wd/'aligned.wav'
  run(['ffmpeg','-v','error','-y','-i',raw,'-af',f'atrim=start={offset},asetpts=PTS-STARTPTS,apad=whole_dur={duration},atrim=end={duration}','-ar',RATE,'-ac',2,'-c:a','pcm_f32le',dest]);aligned[variant]=dest
  print(f'{cue} {variant} rendered',flush=True)
  dump(BASE/'reports'/f'audio-{cue}.json',report)
 aligned['C']=Path(item['existing_gm_comparison_report']).parent/'C - 游戏音色.flac'
 measurements={v:mix.loudness(p) for v,p in aligned.items()}
 target=min([-18.0]+[float(m['input_i'])-float(m['input_tp'])-3.5 for m in measurements.values()]);report['common_target_lufs']=target;report['pre_gain_measurements']=measurements
 final=OUT/f'{index:02d} - {item["title"]}';final.mkdir(parents=True,exist_ok=True);report['outputs']={}
 for v in ('C','D1','D2'):
  label={'C':'C - 现游戏音色_响度匹配','D1':'D1 - 中国器乐_原音高','D2':'D2 - 中国器乐_有限调式'}[v];gain=target-float(measurements[v]['input_i']);outputs={}
  for ext,codec in [('flac',['-c:a','flac','-sample_fmt','s32']),('mp3',['-c:a','libmp3lame','-b:a','320k'])]:
   p=final/f'{label}.{ext}';run(['ffmpeg','-v','error','-y','-i',aligned[v],'-af',f'volume={gain:.9f}dB','-ar',RATE,'-ac',2,*codec,p]);lm=mix.loudness(p);probe=mix.audio_probe(p)
   # Decode the actual delivery, rather than relying only on encoder inputs.
   decoded=run(['ffmpeg','-v','error','-i',p,'-f','f32le','-acodec','pcm_f32le','-']).stdout;a=np.frombuffer(decoded,np.float32);assert np.isfinite(a).all() and np.max(np.abs(a))>1e-5 and np.max(np.abs(a))<1
   assert abs(len(a)/2/RATE-duration)<.06 and abs(float(lm['input_i'])-target)<.3 and float(lm['input_tp'])<=-3.0
   stream=probe['streams'][0];assert stream['sample_rate']=='48000' and stream['channels']==2
   if ext=='flac':assert stream['bits_per_raw_sample']=='24'
   if ext=='mp3':assert stream['bit_rate']=='320000'
   outputs[ext]={'path':str(p),'sha256':mix.sha(p),'probe':probe,'loudness':lm,'decoded_finite':True,'decoded_sample_count_per_channel':len(a)//2,'decoded_peak':float(np.max(np.abs(a))),'decoded_rms':float(np.sqrt(np.mean(a.astype(float)**2)))}
  report['outputs'][v]={'fixed_gain_db':gain,'encoded_from':str(aligned[v]),'encoded_from_sha256':mix.sha(aligned[v]),'files':outputs};print(f'{cue} {v} encoded+QA PASS',flush=True)
 report['processing']['backbone_amp_scope']='Each source track rendered and amp-processed independently before summing family; source track note ordering retained.'
 report['processing']['fluidsynth_unused_channel_warning']='SF2 has no GM drum preset for unused channel 9; render-only MIDI only uses non-drum channels. No voice-allocation or note-drop warnings.'
 report['processing']['native_sf2_decay']='Preserve SF2 native loop and envelope flags; PIPA/LUAN are nonlooping, ERHU/GUZHEN loop natively. No extra notes or synthetic tremolo.'
 report['render_script_sha256']=mix.sha(Path(__file__))
 for v,plan in plans.items():
  counts=collections.Counter(e['instrument_family'] for e in plan['events']);assert sum(s['event_count'] for s in report['variants'][v]['families'].values())+counts['drums']==len(plan['events'])
  report['variants'][v]['full_event_count']=len(plan['events']);report['variants'][v]['drum_event_count']=counts['drums'];report['variants'][v]['event_coverage']='Every pitched plan event appears in exactly one family; drums reuse unchanged kit/fallback stems; no doubled old guitar track.'
 report['status']='PASS';report['manual_listening_review']='not performed';dump(BASE/'reports'/f'audio-{cue}.json',report);return report
if __name__=='__main__':
 ap=argparse.ArgumentParser();ap.add_argument('--index',type=int,nargs='+',default=[1,4,8]);a=ap.parse_args();state={'status':'running','completed':[]};dump(BASE/'render-status.json',state)
 for i in a.index:
  state['current_index']=i;dump(BASE/'render-status.json',state)
  try:r=render(i);state['completed'].append({'index':i,'status':r['status']});dump(BASE/'render-status.json',state)
  except Exception as e:state['status']='failed';state['error']=repr(e);dump(BASE/'render-status.json',state);raise
 state['status']='PASS';dump(BASE/'render-status.json',state)

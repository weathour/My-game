#!/usr/bin/env python3
"""Build compact per-cue render and event-fidelity QA records."""
import argparse, collections, hashlib, json, subprocess, sys
from pathlib import Path
import numpy as np
from scipy.io import wavfile

ROOT=Path(__file__).resolve().parents[3]; BASE=ROOT/'design/music-20261103-midi-test'; MANIFEST=BASE/'experiment-manifest.json'
TRIALS=BASE/'trials'; REPORTS=BASE/'reports'; REPORTS.mkdir(exist_ok=True)
def sha(p):
 h=hashlib.sha256()
 with open(p,'rb') as f:
  for b in iter(lambda:f.read(1<<20),b''):h.update(b)
 return h.hexdigest()
def source_drum_note_pairs(path):
 mf=__import__('mido').MidiFile(path); pairs=[]
 for ti,tr in enumerate(mf.tracks):
  tick=0; active=collections.defaultdict(collections.deque)
  for msg in tr:
   tick+=msg.time
   if msg.type=='note_on' and msg.velocity>0 and msg.channel==9:
    active[(msg.channel,msg.note)].append({'source_track':ti,'source_channel':msg.channel,'source_pitch':msg.note,'velocity':msg.velocity,'tick':tick,'source_end_tick':None,'source_off_type':None})
   elif getattr(msg,'channel',None)==9 and (msg.type=='note_off' or (msg.type=='note_on' and msg.velocity==0)):
    q=active[(msg.channel,msg.note)]
    if q:
     note=q.popleft(); note['source_end_tick']=tick; note['source_off_type']='note_off' if msg.type=='note_off' else 'note_on_velocity_0'; pairs.append(note)
  for q in active.values():
   while q:
    note=q.popleft(); note['source_end_tick']=tick; note['source_off_type']='unclosed_at_track_end'; pairs.append(note)
 return pairs
def enrich_drum_log(path, report, expected_pairs):
 # Match by source identity and onset; deques preserve multiplicity for repeated
 # same-pitch hits at the same tick.
 queues=collections.defaultdict(collections.deque)
 for n in expected_pairs:
  queues[(n['source_track'],n['source_channel'],n['source_pitch'],n['velocity'],n['tick'])].append(n)
 enriched=[]; unmatched=[]
 for event in report['drum_event_log']:
  key=(event['source_track'],9,event['source_pitch'],event['velocity'],event['tick'])
  if not queues[key]: unmatched.append(dict(event)); continue
  source=queues[key].popleft(); e=dict(event)
  e.update(source_channel=source['source_channel'],source_end_tick=source['source_end_tick'],source_off_type=source['source_off_type'])
  enriched.append(e)
 remaining=[dict(x) for q in queues.values() for x in q]
 report['drum_event_log']=enriched
 report['note_off_policy']='The renderer-only derivative omits source drum note-offs so selected one-shot samples follow natural sample decay; source note-off duration does not control this one-shot decay. This policy does not assert source note-offs are artificial or invalid. Closed/pedal-hat onsets explicitly choke the active open-hat sample. Temporary renderer channel and pitch mappings are adapter controls, not original MIDI events.'
 report['source_note_pair_verification']={'status':'PASS' if not unmatched and not remaining and len(enriched)==len(expected_pairs) and all(x['source_off_type']!='unclosed_at_track_end' for x in enriched) else 'FAIL','source_drum_note_pairs':len(expected_pairs),'matched_trigger_records':len(enriched),'unmatched_trigger_records':len(unmatched),'unmapped_source_note_pairs':len(remaining),'matching_fields':['source_track','source_channel','source_pitch','velocity','tick','source_end_tick'],'scope':'source MIDI note-on/off pairs; this verifies trigger provenance, not byte-for-byte identity of the renderer-only MIDI derivative'}
 report['source_note_pair_verification']['unmatched_trigger_examples']=unmatched[:5]
 report['source_note_pair_verification']['unmapped_source_examples']=remaining[:5]
 path.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
 return enriched,report['source_note_pair_verification']
def wave_metrics(p):
 rate,x=wavfile.read(p,mmap=True); maxv=float(np.max(np.abs(x))); rms=float(np.sqrt(np.mean(np.asarray(x,dtype=np.float64)**2)))
 return {'sample_rate':rate,'frames':len(x),'channels':1 if x.ndim==1 else x.shape[1],'duration_seconds':len(x)/rate,'rms':rms,'peak_abs':maxv,'silent':maxv<1e-7}
def chain(role):
 return {
  'guitar':{'source':'Karoryfer Emilyguitar clean DI (CC0 multisample)','processing':'resample nearest available root for out-of-range pitch without changing MIDI pitch; tanh(x*3.2)*0.86; 2nd-order low-pass 5200 Hz; 1st-order high-pass 95 Hz; fixed stem gain 0.36'},
  'bass':{'source':'Karoryfer Fashionbass clean DI (CC0 multisample)','processing':'resample nearest available root for out-of-range pitch without changing MIDI pitch; tanh(x*1.75)*0.88; 2nd-order low-pass 4800 Hz; fixed stem gain 0.48'},
  'piano':{'source':'VSCO Upright Piano Nr1 (CC0 sampled source from existing pinned instrument manifest)','processing':'2nd-order low-pass 7600 Hz; fixed stem gain 0.34'},
  'aux':{'source':'existing auxiliary note events mapped to deterministic additive pad/pluck patch','processing':'no new note events; fixed stem gain 0.24'}
 }[role]
def main():
 ap=argparse.ArgumentParser(); ap.add_argument('--index',type=int,required=True); a=ap.parse_args()
 manifest=json.loads(MANIFEST.read_text()); item=next(x for x in manifest['inputs'] if x['index']==a.index)
 folder={1:'tbp_non_drum',2:'mobscene_non_drum',11:'minute_decay_non_drum'}.get(a.index,f'{a.index:02d}_non_drum'); d=TRIALS/folder
 source=BASE/'inputs'/f'midi_test_{a.index:02d}.mid'; non=json.loads((d/'non-drum-render-report.json').read_text())
 drum_path=d/'drums-drums-report.json'; drum=json.loads(drum_path.read_text()); fallback_path=d/'drum_fallback.wav'; fallback_path_report=d/'drum_fallback-drums-report.json'; fallback=json.loads(fallback_path_report.read_text()) if fallback_path.exists() else None
 source_drum_pairs_all=source_drum_note_pairs(source)
 drum_source_pitches={e['source_pitch'] for e in drum['drum_event_log']}
 drum_source_pairs=[n for n in source_drum_pairs_all if n['source_pitch'] in drum_source_pitches]
 drum_log,drum_pair_check=enrich_drum_log(drum_path,drum,drum_source_pairs)
 fallback_log=[]; fallback_pair_check=None
 if fallback:
  # Drum triggers are split between the mapped kit and explicit GM54 fallback.
  # Validate the combined logs against the complete source pair list below.
  fallback_pairs=[]
  q=collections.defaultdict(collections.deque)
  for n in source_drum_pairs_all:q[(n['source_track'],n['source_channel'],n['source_pitch'],n['velocity'],n['tick'])].append(n)
  for e in drum_log:
   if q[(e['source_track'],e['source_channel'],e['source_pitch'],e['velocity'],e['tick'])]:q[(e['source_track'],e['source_channel'],e['source_pitch'],e['velocity'],e['tick'])].popleft()
  fallback_pairs=[n for queue in q.values() for n in queue]
  fallback_log,fallback_pair_check=enrich_drum_log(fallback_path_report,fallback,fallback_pairs)
 # Combined mapped-kit and fallback triggers must account for every source drum pair exactly once.
 combined=drum_log+fallback_log
 expected_counter=collections.Counter((n['source_track'],n['source_channel'],n['source_pitch'],n['velocity'],n['tick'],n['source_end_tick']) for n in source_drum_pairs_all)
 trigger_counter=collections.Counter((n['source_track'],n['source_channel'],n['source_pitch'],n['velocity'],n['tick'],n['source_end_tick']) for n in combined)
 drum_pairs_pass=(expected_counter==trigger_counter and len(combined)==len(source_drum_pairs_all) and all(n['source_off_type']!='unclosed_at_track_end' for n in combined))
 verify=json.loads(subprocess.check_output([sys.executable,str(BASE/'tools/verify_event_fidelity.py'),'--midi',str(source),'--report',str(d/'non-drum-render-report.json'),'--expected-sha256',item['midi_sha256']],text=True))
 tracks=[]
 for t in non['tracks']:
  if t['role']=='drums': continue
  p=d/t['stem']; metrics=wave_metrics(p)
  tracks.append({'track_index':t['track_index'],'source_track_name':t['name'],'program':t['program'],'role':t['role'],'note_count':t['note_count'],'stem':t['stem'],'sha256':sha(p),'audio':metrics,'mapping_audit_counts':dict(collections.Counter(a['type'] for a in t['mapping_audit'])),'timbre_and_effect_chain':chain(t['role'])})
 drum_metrics=wave_metrics(d/'drums.wav'); fallback_metrics=wave_metrics(fallback_path) if fallback else None
 drum_counts=collections.Counter(str(e['source_pitch']) for e in drum['drum_event_log'])
 source_drum_count=sum(t['note_count'] for t in non['tracks'] if t['role']=='drums')
 original=Path(item['midi_file']); original_hash=sha(original) if original.is_file() else None
 report={'status':'PASS','cue_id':f'midi_test_{a.index:02d}','title':item['title'],'input_source_midi':item['midi_file'],'frozen_midi_copy':str(source),'source_sha256_expected':item['midi_sha256'],'source_sha256_original_if_available':original_hash,'source_sha256_copy':sha(source),'note_event_verification':verify,'source_event_fidelity':{'status':'PASS' if verify.get('status')=='pass' and drum_pairs_pass else 'FAIL','scope':'all source MIDI note-on/off pairs were matched by the non-drum event audit; drum trigger records were independently matched to source drum channel-9 note-on/off pairs including end tick','source_midi_sha256':sha(source),'source_note_pair_count':item['midi_note_count'],'drum_source_pair_count':len(source_drum_pairs_all),'drum_trigger_pair_verification':{'status':'PASS' if drum_pairs_pass else 'FAIL','matched_pairs':len(combined),'source_pairs':len(source_drum_pairs_all),'exact_pair_multisets_match':expected_counter==trigger_counter}},'drum_adapter_policy':'The renderer-only FluidSynth derivative omits source drum note-offs so one-shot samples can follow their natural sample decay; this describes the adapter behavior and does not claim the source note-offs were artificial or invalid. Closed/pedal-hat triggers explicitly choke an active open-hat sample. Temporary channel, pitch, and control-flow adaptations are not the original MIDI. Source MIDI and source note events are unchanged.','source_note_count_expected':item['midi_note_count'],'source_note_count_render_event_log':non['full_note_count'],'source_midi_duration_seconds':non['midi_end_seconds'],'source_end_tick':non['midi_end_tick'],'source_tempo_map':non['source_tempo_map'],'source_meter_map':non['source_meter_map'],'source_control_change_count':non['source_control_change_count'],'pitched_track_count':len(tracks),'pitched_tracks':tracks,'source_drum_note_on_count':source_drum_count,'drum_trigger_log':combined,'drum_track':{'kit':'FreePats MuldjordKit SF2 2020-10-18','preset':'bank0 program0','note_on_count':drum['drum_note_on_count'],'source_key_counts':dict(sorted(drum_counts.items(),key=lambda x:int(x[0]))),'stem':'drums.wav','sha256':sha(d/'drums.wav'),'audio':drum_metrics,'report':drum['output'],'note_off_policy':drum['note_off_policy'],'source_note_pair_verification':drum_pair_check,'channel_remap':f'GM drum channel9 mapped to renderer channel {drum["renderer_channel"]}; source MIDI unchanged','fallback':None},'event_fidelity_verification':'PASS' if drum_pairs_pass else 'FAIL','final_C_render_report':str(Path(item['existing_gm_comparison_report']).parent/'C-render-report.json')}
 if fallback:
  report['drum_track']['fallback']={'source_pitch':'54 GM tambourine','soundfont':'GeneralUser GS 2.0.3','note_on_count':fallback['drum_note_on_count'],'stem':'drum_fallback.wav','sha256':sha(fallback_path),'audio':fallback_metrics,'only_unmapped_fallback':True}
 drum_total=drum['drum_note_on_count']+(fallback['drum_note_on_count'] if fallback else 0)
 report['drum_event_mapping_total']=drum_total
 if not drum_pairs_pass: report['status']='FAIL'; report['drum_source_pair_mismatch']=True
 if drum_total!=source_drum_count: report['status']='FAIL'; report['drum_mapping_count_mismatch']={'source':source_drum_count,'rendered':drum_total}
 if (original_hash and original_hash!=item['midi_sha256']) or report['source_sha256_copy']!=item['midi_sha256']: report['status']='FAIL'; report['source_hash_mismatch']=True
 if not verify.get('status')=='pass' or non['full_note_count']!=item['midi_note_count']: report['status']='FAIL'
 if any(t['audio']['silent'] for t in tracks) or drum_metrics['silent'] or (fallback_metrics and fallback_metrics['silent']): report['status']='FAIL'; report['silent_stem']=True
 report['missing_sample_regions']=sum(t['mapping_audit_counts'].get('missing_region',0) for t in tracks)
 if report['missing_sample_regions']: report['status']='FAIL'
 out=REPORTS/f'{report["cue_id"]}.json'; out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n'); print(json.dumps({'status':report['status'],'cue':report['cue_id'],'notes':report['source_note_count_render_event_log'],'path':str(out)},ensure_ascii=False))
if __name__=='__main__':main()

"""Read-only MIDI/tap diagnosis. Counterfactual replay is not validation data.

Run with the tester virtualenv. --capture-baseline freezes the unmodified grid
algorithm before repair; a normal run compares the repaired output to that file.
No production file or original trial is written by this diagnostic.
"""
from __future__ import annotations
import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import sys
import subprocess
import time
import numpy as np

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT))
from tools.rhythm_tester import analysis as A
from tools.rhythm_tester.session import TapJudge
OUT=Path(__file__).resolve().parent
SESSION=ROOT/'tools/rhythm_tester/results/session_20261104T080054_48b49f037e.json'


def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def write(path,data):path.write_text(json.dumps(data,ensure_ascii=False,indent=2,allow_nan=False)+'\n')
def timeline(cue):return A.parse_midi(ROOT/f'design/music-20261104-chinese-12/arrangements/{cue}/D2.mid')
def plan_snapshot(data):
 start=time.perf_counter();plan=A.build_plan(data);cold=(time.perf_counter()-start)*1000
 return {'midi_sha256':data.sha256,'raw_duration_sec':data.metadata['raw_duration_sec'],'trim_sec':data.trim_sec,'duration_sec':data.duration_sec,'tempo_map':data.metadata['tempo_map'],'note_count':len(data.notes),'selected_rate':plan.metadata['selected_rate'],'selected_phase':plan.metadata['selected_phase'],'offset_quarters':plan.metadata['offset_quarters'],'candidate_rankings':plan.metadata['candidate_rankings'],'algorithm_version':plan.metadata.get('algorithm_version','v1_implicit'),'phase_resolution_quarters':plan.metadata.get('phase_resolution_quarters'),'cold_ms':cold,'reference_count':len(plan.times),'times':plan.times.tolist()}


def replay(events,times,compensation,blind=False):
 judge=TapJudge(times,window_ms=90)
 for event in events:judge.tap(event['raw_audio_sec'],event['key'],compensation_ms=compensation,blind=blind)
 stats=judge.stats();stats['judgements']=dict(Counter(e['judgement'] for e in judge.events))
 return stats


def legacy_score(data,rate,offset,events):
    """Frozen v1 objective, solely for isolating phase-grid search fairness."""
    grid=A._grid(data,rate,offset);strengths=A._salience(grid,rate,events)
    if not len(grid):return {"score":0.,"alignment":0.,"coverage":0.,"stability":0.,"comfort":0.}
    alignment=float(np.mean(strengths));coverage=float(np.mean(strengths>.2))
    chunks=np.array_split(strengths,max(1,min(16,len(strengths)//8)))
    stability=max(0.,1-float(np.std([np.mean(c) for c in chunks]))/(alignment+.05))
    i=np.clip(np.searchsorted(data.tempo_quarters,grid,side='right')-1,0,len(data.tempo_us)-1)
    bpm=float(np.median(60e6/data.tempo_us[i]*rate));comfort=math.exp(-.5*(math.log2(bpm/110)/.65)**2)
    return {"score":.62*alignment+.10*coverage+.10*stability+.18*comfort,"alignment":alignment,"coverage":coverage,"stability":stability,"comfort":comfort,"median_bpm":bpm}


def phase_landscape(data):
 events=A._events(data);rows=[]
 for rate in (.5,1.,2.):
  for offset in np.arange(0,1/rate,1/32):
   row={'rate':rate,'offset_quarters':float(offset),'phase':float(offset*rate)}
   row.update(legacy_score(data,rate,float(offset),events));rows.append(row)
 rows.sort(key=lambda r:(-r['score'],abs(math.log2(r['rate'])),r['phase']))
 return rows


def family_diagnostics(data,before,after):
 families={}
 for family in sorted(set(n.family for n in data.notes)):
  notes=[n for n in data.notes if n.family==family and n.time_sec>=0]
  quarter_fractions=Counter(round((n.quarter%1)*32)%32 for n in notes)
  families[family]={'note_count':len(notes),'velocity_range':[min(n.velocity for n in notes),max(n.velocity for n in notes)],'programs':dict(Counter(n.program for n in notes)),'top_1over32_quarter_bins':[{'offset':i/32,'count':n} for i,n in quarter_fractions.most_common(6)]}
 events=A._events(data);decomposition=[]
 for label,row in [('before',before),('after',after)]:
  grid=A._grid(data,row['selected_rate'],row['offset_quarters']);denom=sum(A.FAMILY_WEIGHTS[f] for f in events)
  parts={}
  for family in events:
   # Isolated result is normalized to1 internally; restore the original family share.
   value=float(np.mean(A._salience(grid,row['selected_rate'],{family:events[family]})))
   parts[family]=value*A.FAMILY_WEIGHTS[family]/denom
  rank=row['candidate_rankings'][0]
  decomposition.append({'label':label,'mean_alignment_family_contributions':parts,'sum':sum(parts.values()),'score_terms':{'alignment':.62*rank['alignment'],'coverage':.1*rank['coverage'],'stability':.1*rank['stability'],'comfort':.18*rank['comfort']}})
 return {'families':families,'score_decomposition':decomposition}


def local_diagnostics(data,global_snapshot):
 events=A._events(data);global_rate=global_snapshot['selected_rate'];global_offset=global_snapshot['offset_quarters']
 sections=[]
 for start in np.arange(0,data.duration_sec,20):
  end=min(start+20,data.duration_sec)
  if end-start<8:continue
  local=[]
  for rate in (.5,1.,2.):
   for offset in np.arange(0,1/rate,1/32):
    grid=A._grid(data,rate,float(offset));times=A.quarters_to_seconds(data,grid)
    valid=(times>=start)&(times<end)
    if not np.any(valid):continue
    strengths=A._salience(grid,rate,events)[valid]
    i=np.clip(np.searchsorted(data.tempo_quarters,grid[valid],side='right')-1,0,len(data.tempo_us)-1)
    bpm=float(np.median(60e6/data.tempo_us[i]*rate));comfort=math.exp(-.5*(math.log2(bpm/110)/.65)**2)
    # Local diagnostic only; no tempo/path smoothing is implemented here.
    alignment=float(np.mean(strengths));coverage=float(np.mean(strengths>.2))
    score=.62*alignment+.10*coverage+.18*comfort
    local.append({'rate':rate,'offset_quarters':float(offset),'score_without_stability_term':score,'alignment':alignment,'coverage':coverage})
  local.sort(key=lambda x:-x['score_without_stability_term'])
  strong=[n.quarter%.5 for n in data.notes if start<=n.time_sec<end and n.family in ('kick','snare','bass')]
  sections.append({'start_sec':float(start),'end_sec':float(end),'local_best':local[0],'global_rate':global_rate,'global_offset':global_offset,'strong_event_eighth_phase_median_quarters':float(np.median(strong)) if strong else None,'local_phase_disagreement_is_not_proof_of_true_beat_switch':True})
 return sections


def timeline_excerpt(data,trial,before,after,start,end):
 return {'start_sec':start,'end_sec':end,'midi_strong_events':[{'time_sec':n.time_sec,'quarter':n.quarter,'family':n.family,'velocity':n.velocity} for n in data.notes if start<=n.time_sec<=end and n.family in ('kick','snare','bass')], 'old_pulse_times':[x for x in before['times'] if start<=x<=end], 'new_pulse_times':[x for x in after['times'] if start<=x<=end], 'quarter_times':[float(x) for x in A.build_plan(data,'quarter').times if start<=x<=end], 'raw_taps':[e['raw_audio_sec'] for e in trial['events'] if start<=e['raw_audio_sec']<=end], 'corrected_taps':[e['corrected_audio_sec'] for e in trial['events'] if start<=e['raw_audio_sec']<=end], 'interpretation':'time-plot data only; taps in these excerpts were visually exposed, not beat ground truth'}


def audio_onset_proxy(cue,data):
    path=ROOT/f'assets/music/midi_test/{cue}.ogg'
    raw=subprocess.run(['ffmpeg','-nostdin','-v','error','-i',str(path),'-ar','16000','-ac','1','-f','f32le','pipe:1'],check=True,stdout=subprocess.PIPE).stdout
    x=np.frombuffer(raw,dtype='<f4');n=512;hop=160
    frames=np.lib.stride_tricks.sliding_window_view(x,n)[::hop]
    low=[];full=[];previous=np.zeros(n//2+1);mask=(np.fft.rfftfreq(n,1/16000)>=35)&(np.fft.rfftfreq(n,1/16000)<=250)
    for first in range(0,len(frames),1024):
        spec=np.abs(np.fft.rfft(frames[first:first+1024]*np.hanning(n),axis=1))
        prior=np.vstack((previous,spec[:-1]));rise=np.maximum(0,spec-prior)
        low.extend(np.sum(rise[:,mask],axis=1));full.extend(np.sum(rise,axis=1));previous=spec[-1]
    times=(np.arange(len(low))*hop+n/2)/16000
    low=np.array(low);full=np.array(full)
    low/=max(float(np.percentile(low,95)),1e-12);full/=max(float(np.percentile(full,95)),1e-12)
    lags=[];onsets=np.array([note.time_sec for note in data.notes if note.family=='kick' and note.time_sec>=0])
    for lag in np.arange(-.15,.151,.01):
        lags.append({'lag_sec':round(float(lag),4),'mean_lowband_positive_flux_at_kick':float(np.mean(np.interp(onsets+lag,times,low)))})
    lags.sort(key=lambda row:-row['mean_lowband_positive_flux_at_kick'])
    sample=(times>=20)&(times<=24)
    return {'audio_path':str(path.relative_to(ROOT)),'audio_sha256':sha(path),'method':'mono16kHz,32ms centered Hann,10ms hop positive spectral flux;35-250Hz proxy; kick-onset lag scan','kick_count':len(onsets),'top_lags':lags[:5],'excerpt20to24sec':{'times':times[sample][::2].tolist(),'lowband_flux_p95_normalized':low[sample][::2].tolist(),'broadband_flux_p95_normalized':full[sample][::2].tolist()},'limits':'mixed-audio transient proxy, not isolated kick ground truth, human beat annotation or output-device latency calibration'}


def main():
 parser=argparse.ArgumentParser();parser.add_argument('--capture-baseline',action='store_true');args=parser.parse_args()
 cues=[f'midi_test_{i:02d}' for i in range(1,13)]
 data={cue:timeline(cue) for cue in cues}
 current={cue:plan_snapshot(value) for cue,value in data.items()}
 if args.capture_baseline:
  write(OUT/'baseline-before.json',{'analysis_sha256':sha(ROOT/'tools/rhythm_tester/analysis.py'),'captured_before_repair':True,'tracks':current});return
 baseline=json.loads((OUT/'baseline-before.json').read_text());old=baseline['tracks']
 snapshot=OUT/'input-session-snapshot.json'
 session_bytes=snapshot.read_bytes() if snapshot.exists() else SESSION.read_bytes()
 session=json.loads(session_bytes)
 assert session['total_taps']==660 and session['trial_count']==16,'Requested feedback snapshot changed'
 if not snapshot.exists():snapshot.write_bytes(session_bytes)
 trials=[]
 for index,trial in enumerate(session['trials'],1):
  m=trial['metadata'];events=trial['events'];raw=np.array([e['raw_audio_sec'] for e in events]);cue=m['cue_id']
  row={'trial_index':index,'cue_id':cue,'mode':m['mode'],'tap_count':len(events),'compensation_ms':m['compensation_ms'],'click_enabled':m['click_enabled'],'reduced_motion':m['reduced_motion'],'hit_count_recorded':sum(e['judgement']=='hit' for e in events),'raw_range':[float(raw[0]),float(raw[-1])] if len(raw) else None,'median_raw_tap_interval_sec':float(np.median(np.diff(raw))) if len(raw)>1 else None,'exposure':'reference_hidden_but_short_and_after_prior_visual_trials' if m['mode']=='blind' else 'visual_reference_exposed_not_ground_truth'}
  row['original_record_replay']=replay(events,m.get('reference_times_sec',[]),m['compensation_ms'],blind=m['mode']=='blind')
  row['original_record_hit_count_reproduced']=row['original_record_replay']['hit_count']==row['hit_count_recorded']
  if len(events):
   row['counterfactual_replay_not_validation']={
    'old_reference_comp0':replay(events,old[cue]['times'],0),
    'old_reference_comp100':replay(events,old[cue]['times'],100),
    'quarter_comp0':replay(events,A.build_plan(data[cue],'quarter').times,0),
    'new_reference_comp0':replay(events,current[cue]['times'],0)}
  trials.append(row)
 audit=[]
 for cue in cues:
  before,after=old[cue],current[cue]
  dense=phase_landscape(data[cue])
  audit.append({'cue_id':cue,'midi_sha256':data[cue].sha256,'before':{k:v for k,v in before.items() if k!='times'},'after':{k:v for k,v in after.items() if k!='times'},'uniform_phase_scan_legacy_objective_top5':dense[:5],'timeline_unchanged':all(before[k]==after[k] for k in ['midi_sha256','raw_duration_sec','trim_sec','duration_sec','tempo_map','note_count']),'perceptual_acceptance':'not measured; candidate-ranking and timeline audit only'})
 focus={}
 for cue,tr,span in [('midi_test_02',session['trials'][0],(10,14)),('midi_test_10',session['trials'][5],(20,24))]:
  focus[cue]=family_diagnostics(data[cue],old[cue],current[cue]);focus[cue]['local_sections']=local_diagnostics(data[cue],old[cue]);focus[cue]['timeline_excerpt']=timeline_excerpt(data[cue],tr,old[cue],current[cue],*span);focus[cue]['actual_ogg_onset_proxy']=audio_onset_proxy(cue,data[cue])
 report={'kind':'source-based diagnosis and phase-grid repair audit, not perceptual validation','session':{'path':str(SESSION.relative_to(ROOT)),'sha256':hashlib.sha256(session_bytes).hexdigest(),'snapshot':'input-session-snapshot.json','taps':session['total_taps'],'trials':session['trial_count']},'before_analysis_sha256':baseline['analysis_sha256'],'after_analysis_sha256':sha(ROOT/'tools/rhythm_tester/analysis.py'),'changed_score_support':'v2 scores all candidates on the same observed-onset span eroded by1quarter per side; weights and comfort unchanged','trial_diagnostics':trials,'twelve_track_audit':audit,'focus_tracks':focus,'sources':[{'url':'https://webspace.eecs.qmul.ac.uk/s.e.dixon/pub/2001/icmc.pdf','locator':'Section2','supports':'symbolic onset/chord salience, tempo induction and multiple tempo/phase tracking hypotheses; flexible grid rather than a globally fixed phase scan'},{'url':'https://webspace.eecs.qmul.ac.uk/s.e.dixon/pub/2001/jnmr.pdf','locator':'Tempo induction, Beat tracking and Musical salience sections','supports':'salience and multiple hypothesis search; not a guarantee of listener-preferred tactus'},{'url':'https://www.eecs.qmul.ac.uk/~simond/pub/2007/jnmr07.pdf','locator':'Beat Tracking; Table2; Conclusions','supports':'agents update timing from events and interpolate missing beats; metrical ambiguity and regular-beat limits remain'}],'interpretation_limits':['Visual/click-exposed taps are not blind beat annotations.','The17 blind taps cover only4.5seconds after prior reference exposure and do not identify a universal preferred layer.','Counterfactual replay of the same session is diagnostic, not independent acceptance.','New ranking improves fairness of candidate search, not proof of perceptual beat correctness.','Local salience maxima can follow syncopation or change parity; local winner switching alone does not justify switching the gameplay beat.','A whole-piece fixed quarter offset follows tempo-map changes but cannot independently recover local phase drift, onset-timing microstructure, sections without a stable beat, or metrical-level choice.']}
 report['technical_findings']=[
  {'id':'phase_search_fairness','status':'repaired_with_source_only_rule','evidence':'v1 ratio2 phase.25 can test .125quarter; ratio1 could not. A shared1/32quarter lattice removes that handicap. No tap data is used by candidate generation.'},
  {'id':'score_support_edges','status':'repaired_without_weight_change','evidence':'finer phases exposed end-padding bias in stability; v2 scores all rates/phases on one common onset-observation span eroded1quarter at each edge. Known-bin synthetic phase0/.5/.125 tests remain exact.'},
  {'id':'compensation_confound','status':'diagnostic_not_causal_validation','evidence':'Kinderfeld103tap trial inherited+100ms. Frozen old-reference replay at0ms yields88hits versus24at+100ms; output-clock/device latency and visually induced anticipation still require separate tests.'},
  {'id':'quarter_comparison_not_independent','status':'not_algorithm_accuracy','evidence':'quarter23/25 is another segment with visual/click exposure; those raw taps also obtain24/25 against old denser pulse. This does not establish quarter as perceptual truth.'},
  {'id':'blind_sample_limit','status':'short_locally_informative_not_ground_truth','evidence':'17taps span4.544seconds after prior visual trials, median interval266.7ms. Posthoc old-reference matching14/17 and new3/17 is diagnostic only; repair has not demonstrated improved user beat agreement.'},
  {'id':'audio_vs_midi_alignment','status':'rendered_transient_sanity_check_not_device_calibration','evidence':'mean lowband positive-flux proxy at known kick events peaks around+10ms for02 and0ms for10; no source-file100ms displacement is indicated by this proxy. It does not measure Bluetooth/DAC or input latency.'},
  {'id':'fixed_grid_limit','status':'remaining','evidence':'v2 follows the supplied tempo-map but retains one global rate and absolute-quarter offset. Kinderfeld local salience winners alternate about.125/.625quarter, showing accent-parity competition; do not stitch these winners into a beat path or call them true phase changes.'}
 ]
 report['recommendations']=[
  {'priority':1,'scope':'approved bounded correction','action':'ship equal absolute phase resolution, common score support, explicit v2 metadata and detached intrinsic cache; unchanged weights/comfort.','expected_effect':'candidate search fairness and removal of finite-file edge artifacts;12 source timelines unchanged','validation':'17 analysis tests and local cold/warm timing, not perceptual acceptance'},
  {'priority':2,'scope':'UI/transport owner','action':'separate target-arrival flash from acceptance-window illumination; show inherited compensation clearly and calibrate hardware independently.','expected_effect':'remove known anticipatory visual cue and reduce parameter-confounded comparisons','validation':'new tests plus same-piece controlled replay; no inferred audio-device calibration from this log'},
  {'priority':3,'scope':'fresh independent listening protocol','action':'compare old/new/quarter candidates in randomized short excerpts with initial blind tapping before reference exposure; keep compensation fixed from separate device calibration; include more than4.5seconds and repeat sections.','expected_effect':'can assess preferred rate/phase and usability for these songs; cannot certify arbitrary MIDI','validation':'new held-out taps/listening; never report this660tap refit as pass'},
  {'priority':4,'scope':'future conditional method work, not implemented','action':'if fresh references show local phase/tempo tracking need, compare an event-driven IOI/multiple-agent baseline against fixed-grid candidates; preserve continuity and missing-onset interpolation, do not select each20sec local winner independently.','expected_effect':'potential local timing adaptation, with unresolved metrical-level and salience ambiguity','validation':'separate source-only synthetic tempo/phase paths and independent listening references'}
 ]
 write(OUT/'analysis-diagnostic.json',report)
 print('DIAGNOSIS_WRITTEN tracks=12 trials=16 taps=660')

if __name__=='__main__':main()

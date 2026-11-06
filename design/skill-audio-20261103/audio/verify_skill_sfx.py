#!/usr/bin/env python3
"""Verify the generated bank, source locks, file formats, coverage, and variants."""
from __future__ import annotations
import hashlib,json,math,platform,subprocess
from pathlib import Path
import numpy as np
from scipy.io import wavfile

ROOT=Path(__file__).resolve().parents[3]
BASE=ROOT/'design/skill-audio-20261103/audio'
ASSET=ROOT/'assets/sfx/skill-combat-20261103'
INTERFACE=ROOT/'design/skill-audio-20261103/interface.json'
QA=BASE/'qa/sfx-all.json'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def db(v):return 20*math.log10(max(float(v),1e-15))

def main():
 interface=json.loads(INTERFACE.read_text()); gen=json.loads(QA.read_text()); catalog=json.loads((ASSET/'catalog.json').read_text()); errors=[]; metrics=[]
 families=interface['families']; bosses=set(families[-4:]); expected={f'{f}.{p}' for f in families for p in interface['common_phases']}
 expected|={f'{f}.{p}' for f in bosses for p in interface['boss_only_phases']}; expected|=set(interface['global_new_cues'])
 retained=set(interface['retained_utility_cues'])
 if set(k for k in catalog['cues'] if k not in retained)!=expected:errors.append('cue coverage mismatch')
 if set(catalog['cues'])!=expected|retained:errors.append('catalog contains missing or unexpected cue IDs')
 if len(gen['files'])!=303:errors.append(f'generated variant count {len(gen["files"])} != 303')
 records={}
 for x in gen['files']:
  p=ROOT/x['path'].replace('res://','')
  if not p.is_file():errors.append(f'missing file {x["path"]}');continue
  if sha(p)!=x['sha256']:errors.append(f'hash mismatch {x["path"]}')
  sr,pcm=wavfile.read(p)
  if sr!=48000 or pcm.ndim!=1 or pcm.dtype!=np.int16:errors.append(f'format mismatch {x["path"]}')
  peak=float(np.max(np.abs(pcm.astype(np.int32)))/32768); peakdb=db(peak)
  rms=float(np.sqrt(np.mean(pcm.astype(np.float64)**2))/32768)
  if not -4.15<=peakdb<=-3.85:errors.append(f'peak out of target {x["path"]}: {peakdb:.3f}')
  if peakdb>-3:errors.append(f'peak ceiling exceeded {x["path"]}')
  if peak>=1:errors.append(f'clipped PCM {x["path"]}')
  if rms<1e-4 or not math.isfinite(rms):errors.append(f'silent or invalid RMS {x["path"]}')
  if abs(len(pcm)/sr-x['duration_sec'])>1e-6:errors.append(f'duration mismatch {x["path"]}')
  if not x.get('source_layer_contributions'):errors.append(f'no source audio layer {x["path"]}')
  for layer in x.get('source_layer_contributions',[]):
   source=BASE/'sources'
   matches=list(source.glob('oga-*/'+layer['file']))
   if len(matches)!=1:errors.append(f'source file missing/ambiguous: {layer["file"]}')
   elif sha(matches[0])!=layer['sha256']:errors.append(f'source layer hash mismatch: {layer["file"]}')
   if layer.get('post_final_envelope_rms',0)<0.03:errors.append(f'source contribution too quiet: {x["path"]} {layer["file"]}')
  cue=x['cue_id']; phase=cue.rsplit('.',1)[-1]; dur=len(pcm)/sr
  if cue.endswith('.defeat') and cue.startswith('boss_') and dur>.43:errors.append(f'boss defeat exceeds 0.43s: {cue} {dur:.3f}')
  if cue=='feedback.death' and dur>.35:errors.append(f'feedback death exceeds 0.35s: {dur:.3f}')
  if phase in ('cast','impact','tell') and dur>.60:errors.append(f'ordinary cue too long: {cue} {dur:.3f}')
  rec={'path':x['path'],'sha256':sha(p),'duration_sec':dur,'sample_peak_dbfs':peakdb,'rms_dbfs':db(rms),'source_layers':len(x.get('source_layer_contributions',[])),'source_layer_mix_rms':x.get('design_metrics',{}).get('source_layer_mix_rms'),'pre_gain_mix_rms':x.get('design_metrics',{}).get('pre_gain_mix_rms')}
  records.setdefault(cue,[]).append((pcm.astype(np.float64)/32768,rec))
  metrics.append(rec)
 if len(list(ASSET.glob('*.wav')))!=303:errors.append(f'asset directory WAV count is {len(list(ASSET.glob("*.wav")))} instead of 303')
 if len({sha(ROOT/x['path'].replace('res://','')) for x in gen['files'] if (ROOT/x['path'].replace('res://','')).exists()})!=303:errors.append('generated variant hashes are not all unique')
 for cue in expected:
  variants=records.get(cue,[])
  if len(variants)!=3:errors.append(f'{cue} has {len(variants)} verified variants');continue
  paths=[x[1]['path'] for x in variants]
  if len(set(paths))!=3:errors.append(f'{cue} variant path collision')
  for i in range(3):
   for j in range(i+1,3):
    a,b=variants[i][0],variants[j][0];n=min(len(a),len(b));corr=float(np.corrcoef(a[:n],b[:n])[0,1])
    if not math.isfinite(corr) or abs(corr)>.995:errors.append(f'{cue} variants {i+1}/{j+1} too similar (r={corr:.4f})')
 catalog_variant_count=sum(len(entry['variants']) for entry in catalog['cues'].values())
 if catalog_variant_count!=309:errors.append(f'catalog variant references {catalog_variant_count} != 309')
 for cue,entry in catalog['cues'].items():
  for path in entry['variants']:
   p=ROOT/path.replace('res://','')
   if not p.is_file():errors.append(f'catalog reference missing {cue}: {path}')
 for lock in gen.get('source_manifests',[]):
  p=ROOT/lock['path']
  if not p.is_file() or sha(p)!=lock['sha256']:errors.append(f'source manifest hash mismatch: {lock["path"]}');continue
  data=json.loads(p.read_text()); folder=BASE/'sources'
  for item in data['selected_files']:
   q=next(iter(folder.glob('oga-*/'+item['file'])),None)
   if q is None or sha(q)!=item['sha256']:errors.append(f'source lock mismatch: {item["file"]}')
  lic=next(iter(folder.glob('oga-*/'+data['license_text'])),None)
  if lic is None or sha(lic)!=data['license_text_sha256']:errors.append(f'license text hash mismatch: {data["source_name"]}')
 tools={name:sha(BASE/name) for name in ('build_skill_sfx.py','verify_skill_sfx.py','make_previews.py','sources/fetch-oga-samples.sh') if (BASE/name).is_file()}
 scipy_version=__import__('scipy').__version__; numpy_version=np.__version__
 ffmpeg=subprocess.check_output(['ffmpeg','-version'],text=True).splitlines()[0]
 report={'status':'PASS' if not errors else 'FAIL','cue_count':len(expected),'variant_count':len(metrics),'asset_wav_count':len(list(ASSET.glob('*.wav'))),'catalog_entry_count':len(catalog['cues']),'catalog_variant_reference_count':catalog_variant_count,'new_variant_path_count':len({p for e in catalog['cues'].values() if not e.get('retained_utility') for p in e['variants']}),'retained_utility_variant_reference_count':sum(len(e['variants']) for e in catalog['cues'].values() if e.get('retained_utility')),'sample_rate_hz':48000,'channels':1,'encoding':'PCM16 WAV','peak_target_dbfs':-4.0,'peak_ceiling_dbfs':-3.0,'boss_defeat_max_seconds':max((x['duration_sec'] for x in metrics if Path(x['path']).name.startswith(('boss_hunter_defeat','boss_cavalry_defeat','boss_general_defeat','boss_demon_defeat'))),default=0),'feedback_death_max_seconds':max((x['duration_sec'] for x in metrics if Path(x['path']).name.startswith('feedback_death_')),default=0),'source_layers_verified':'all source texture file hashes and non-silent post-envelope contributions checked per variant','variant_uniqueness':'all 303 file hashes unique; within-cue waveform correlation checked','manual_listening_review':'not performed; user/runtime team can use the five indexed offline previews','toolchain':{'python':platform.python_version(),'numpy':numpy_version,'scipy':scipy_version,'ffmpeg':ffmpeg},'tools_sha256':tools,'errors':errors,'files':metrics}
 out=BASE/'qa/sfx-bank-verification.json';out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps({'status':report['status'],'cues':report['cue_count'],'variants':report['variant_count'],'errors':len(errors),'report':str(out)},ensure_ascii=False))
 if errors:raise SystemExit(1)
if __name__=='__main__':main()

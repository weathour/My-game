#!/usr/bin/env python3
"""Mix preserved MIDI stems, align to the existing A/B comparison, and encode C."""
from __future__ import annotations
import argparse, hashlib, json, math, re, subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[3]
MANIFEST=ROOT/'design/music-20261103-midi-test/experiment-manifest.json'
RATE=48000

def sha(p):
 h=hashlib.sha256()
 with open(p,'rb') as f:
  for b in iter(lambda:f.read(1<<20),b''): h.update(b)
 return h.hexdigest()

def run(cmd): return subprocess.run(cmd,check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)

def loudness(path):
 p=run(['ffmpeg','-hide_banner','-nostats','-i',str(path),'-af','loudnorm=I=-18:LRA=11:TP=-2:print_format=json','-f','null','-'])
 matches=re.findall(r'\{[^{}]*"input_i"[^{}]*\}',p.stderr,re.S)
 if not matches: raise RuntimeError('loudnorm measurement unavailable: '+p.stderr[-1500:])
 return json.loads(matches[-1])

def audio_probe(path):
 return json.loads(run(['ffprobe','-v','error','-show_entries','format=duration,size','-show_entries','stream=codec_name,sample_rate,channels,sample_fmt,bits_per_sample,bits_per_raw_sample,bit_rate','-of','json',str(path)]).stdout)

def encode(index,raw_dir,output_dir,asset_path):
 m=json.loads(MANIFEST.read_text()); item=next(x for x in m['inputs'] if x['index']==index)
 base=Path(item['existing_gm_comparison_report']).parent
 comp=json.loads(Path(item['existing_gm_comparison_report']).read_text())
 offset=float(comp['bar_offset_seconds_removed_from_render']); duration=float(comp['comparison_duration_seconds'])
 target=float(comp.get('target_integrated_lufs',comp.get('target_integrated_lufs_initial',comp.get('target_lufs'))))
 raw_dir=Path(raw_dir); output_dir=Path(output_dir); output_dir.mkdir(parents=True,exist_ok=True)
 stems=sorted(raw_dir.glob('*.wav'))
 if not stems: raise RuntimeError(f'No rendered stems in {raw_dir}')
 raw=output_dir/'C_raw_mix.wav'; aligned=output_dir/'C_aligned.wav'
 inputs=[]
 for p in stems: inputs+=['-i',str(p)]
 labels=''.join(f'[{i}:a]' for i in range(len(stems)))
 fc=f'{labels}amix=inputs={len(stems)}:duration=longest:dropout_transition=0:normalize=0[m]'
 run(['ffmpeg','-hide_banner','-loglevel','error','-y',*inputs,'-filter_complex',fc,'-map','[m]','-ar',str(RATE),'-ac','2','-c:a','pcm_f32le',str(raw)])
 # Match B's measured bar-offset alignment, retain all later musical content, pad only at the end.
 af=f'atrim=start={offset:.9f},asetpts=PTS-STARTPTS,apad=whole_dur={duration:.9f},atrim=start=0:end={duration:.9f}'
 run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(raw),'-af',af,'-ar',str(RATE),'-ac','2','-c:a','pcm_f32le','-t',f'{duration:.9f}',str(aligned)])
 measured=loudness(aligned); encode_input=aligned; compressor=None
 input_i=float(measured['input_i']); input_tp=float(measured['input_tp'])
 # Fair A/B/C comparison audio uses a shared constant gain. The game OGG gets
 # additional fixed attenuation for SFX and battle-mix headroom.
 gain=min(target-input_i, -.2-input_tp)
 if target-(input_i+gain)>.3:
  candidate_compressor={'filter':'acompressor=threshold=0.05:ratio=4:attack=20:release=120:detection=peak','reason':'used only when it improves peak-to-loudness ratio enough to preserve A/B/C loudness'}
  compressed=output_dir/'C_compressed.wav'
  run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(aligned),'-af',candidate_compressor['filter'],'-ar',str(RATE),'-ac','2','-c:a','pcm_f32le',str(compressed)])
  candidate_measure=loudness(compressed); candidate_i=float(candidate_measure['input_i']); candidate_tp=float(candidate_measure['input_tp'])
  if candidate_tp-candidate_i < input_tp-input_i:
   compressor=candidate_compressor; encode_input=compressed; measured=candidate_measure; input_i=candidate_i; input_tp=candidate_tp
   gain=min(target-input_i,-.2-input_tp)
 if target-(input_i+gain)>.3: raise RuntimeError(f'crest-factor headroom cannot satisfy level match: target={target}, achieved={input_i+gain}')
 game_target=-21.0; game_tp_target=-3.5
 comparison_i=input_i+gain; comparison_tp=input_tp+gain
 game_extra=min(game_target-comparison_i,game_tp_target-comparison_tp)
 game_gain=gain+game_extra
 finals={'flac':output_dir/'C - 游戏音色.flac','mp3':output_dir/'C - 游戏音色.mp3','ogg':Path(asset_path)}
 for suffix,path in finals.items():
  path.parent.mkdir(parents=True,exist_ok=True)
  if suffix=='flac': codec=['-c:a','flac','-sample_fmt','s32']
  elif suffix=='mp3': codec=['-c:a','libmp3lame','-b:a','320k']
  else: codec=['-c:a','libvorbis','-q:a','7']
  applied_gain=game_gain if suffix=='ogg' else gain
  run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(encode_input),'-af',f'volume={applied_gain:.6f}dB','-ar',str(RATE),'-ac','2',*codec,str(path)])
 # Verify decoded outputs for length, sample rate, channels, finite and audio metrics.
 checks={}
 for suffix,path in finals.items():
  probe=audio_probe(path); dur=float(probe['format']['duration']); lm=loudness(path)
  if abs(dur-duration)>.06: raise RuntimeError(f'{suffix} duration mismatch {dur} vs {duration}')
  stream=probe['streams'][0]
  if stream.get('sample_rate')!='48000' or stream.get('channels')!=2: raise RuntimeError(f'{suffix} format mismatch: {stream}')
  if suffix=='flac' and stream.get('bits_per_raw_sample')!='24': raise RuntimeError(f'FLAC is not 24-bit: {stream}')
  if suffix=='mp3' and stream.get('bit_rate')!='320000': raise RuntimeError(f'MP3 is not 320 kbps: {stream}')
  if lm.get('input_tp') in ('inf','-inf'): raise RuntimeError(f'{suffix} bad true peak {lm}')
  if float(lm['input_tp'])>=0: raise RuntimeError(f'{suffix} true-peak clipping/overshoot: {lm["input_tp"]} dBTP')
  if suffix=='ogg':
   if float(lm['input_i'])>game_target+.2: raise RuntimeError(f'game OGG too loud: {lm["input_i"]} LUFS')
   if float(lm['input_tp'])>-3.0: raise RuntimeError(f'game OGG headroom failure: {lm["input_tp"]} dBTP')
  elif abs(float(lm['input_i'])-target)>.3: raise RuntimeError(f'{suffix} loudness mismatch {lm["input_i"]} vs target {target}')
  checks[suffix]={'path':str(path),'sha256':sha(path),'probe':probe,'loudness_measurement':lm}
 report={'status':'PASS','index':index,'title':item['title'],'source_midi':item['midi_file'],'source_midi_sha256':sha(item['midi_file']),
         'midi_sha256_expected':item['midi_sha256'],'stems':[{'path':str(p),'sha256':sha(p)} for p in stems],
         'raw_mix':str(raw),'raw_mix_sha256':sha(raw),'aligned_render':str(aligned),'aligned_sha256':sha(aligned),
         'bar_offset_removed_seconds':offset,'alignment_method':'existing A/B bar_offset value; no tempo change or note edits',
         'duration_seconds':duration,'sample_rate_hz':RATE,'channels':2,'comparison_target_lufs':target,'pre_compression_loudness':loudness(aligned),'compression':compressor,'encoded_from':str(encode_input),'pre_gain_loudness':measured,
         'comparison_constant_gain_db':gain,'comparison_estimated_lufs':comparison_i,'comparison_estimated_true_peak_dbtp':comparison_tp,
         'game_mix_target_lufs_max':game_target,'game_mix_true_peak_target_dbtp':game_tp_target,'game_extra_fixed_attenuation_db':game_extra,'game_total_gain_db':game_gain,
         'dynamics_processing':'none' if compressor is None else 'gentle bus compression as recorded, then shared fixed gain','encoded_from_sha256':sha(encode_input),'outputs':checks,'manual_listening_review':'not performed'}
 (output_dir/'C-render-report.json').write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n')
 print(json.dumps({'status':'PASS','index':index,'title':item['title'],'gain_db':gain,'lufs':input_i+gain,'outputs':{k:v['path'] for k,v in checks.items()}},ensure_ascii=False))

if __name__=='__main__':
 ap=argparse.ArgumentParser(); ap.add_argument('--index',type=int,required=True); ap.add_argument('--stems',required=True); ap.add_argument('--out',required=True); ap.add_argument('--asset',required=True); a=ap.parse_args(); encode(a.index,a.stems,a.out,a.asset)

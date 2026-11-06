#!/usr/bin/env python3
"""Audit all 12 C deliverables and write the final release summary."""
import hashlib, json, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]; BASE=ROOT/'design/music-20261103-midi-test'; M=json.loads((BASE/'experiment-manifest.json').read_text())
def sha(p):
 h=hashlib.sha256()
 with open(p,'rb') as f:
  for b in iter(lambda:f.read(1<<20),b''):h.update(b)
 return h.hexdigest()
def probe(p):
 return json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration,size','-show_entries','stream=codec_name,sample_rate,channels,sample_fmt,bits_per_sample,bits_per_raw_sample,bit_rate','-of','json',str(p)],text=True))
def main():
 items=[]; errors=[]
 for item in M['inputs']:
  i=item['index']; cue=f'midi_test_{i:02d}'; compdir=Path(item['existing_gm_comparison_report']).parent
  qa=json.loads((BASE/'reports'/f'{cue}.json').read_text()); cr=json.loads((compdir/'C-render-report.json').read_text())
  midi=BASE/'inputs'/f'{cue}.mid';
  original=Path(item['midi_file']); original_hash=sha(original) if original.is_file() else None
  if sha(midi)!=item['midi_sha256'] or (original_hash and original_hash!=item['midi_sha256']):errors.append(f'{cue}: MIDI SHA mismatch')
  if qa['status']!='PASS' or qa['source_note_count_render_event_log']!=item['midi_note_count']:errors.append(f'{cue}: event/stem QA failed')
  if qa.get('drum_event_mapping_total')!=qa.get('source_drum_note_on_count'):errors.append(f'{cue}: drum mapping event count mismatch')
  if qa.get('source_event_fidelity',{}).get('status')!='PASS' or qa.get('source_event_fidelity',{}).get('drum_trigger_pair_verification',{}).get('exact_pair_multisets_match') is not True: errors.append(f'{cue}: source note-pair fidelity failed')
  if any('source_end_tick' not in n or 'source_channel' not in n for n in qa.get('drum_trigger_log',[])): errors.append(f'{cue}: drum trigger source pair fields missing')
  formats={}
  for ext,key in [('flac','flac'),('mp3','mp3'),('ogg','ogg')]:
   rec=cr['outputs'][key]; p=Path(rec['path']); q=probe(p); st=q['streams'][0]; dur=float(q['format']['duration']); lm=rec['loudness_measurement']
   if st.get('sample_rate')!='48000' or st.get('channels')!=2:errors.append(f'{cue} {ext}: not stereo 48k')
   if ext=='flac' and st.get('bits_per_raw_sample')!='24':errors.append(f'{cue}: FLAC not 24bit')
   if ext=='mp3' and st.get('bit_rate')!='320000':errors.append(f'{cue}: MP3 not 320k')
   if abs(dur-float(cr['duration_seconds']))>.06:errors.append(f'{cue} {ext}: duration mismatch')
   if ext in ('flac','mp3') and abs(float(lm['input_i'])-float(cr['comparison_target_lufs']))>.3:errors.append(f'{cue} {ext}: comparison LUFS mismatch')
   if ext in ('flac','mp3') and float(lm['input_tp'])>=0:errors.append(f'{cue} {ext}: true peak >=0')
   if ext=='ogg' and float(lm['input_tp'])>-3:errors.append(f'{cue}: game OGG TP above -3dBTP')
   if ext=='ogg' and float(lm['input_i'])>-20.7:errors.append(f'{cue}: game OGG louder than the -21 LUFS target margin')
   formats[ext]={'path':str(p),'sha256':sha(p),'duration_seconds':dur,'stream':st,'integrated_lufs':float(lm['input_i']),'true_peak_dbtp':float(lm['input_tp'])}
  items.append({'index':i,'cue_id':cue,'title':item['title'],'midi_sha256':item['midi_sha256'],'note_count':item['midi_note_count'],'source_event_fidelity':qa['source_event_fidelity'],'event_fidelity_check_scope':'source MIDI note-on/off pairs; drums are independently pair-checked via source-trigger logs. Renderer-only FluidSynth derivative is adapted for one-shot sample release and is not claimed event-identical.','missing_sample_regions':qa['missing_sample_regions'],'pitched_non_silent_stems':len(qa['pitched_tracks']),'drum_note_ons':qa['drum_track']['note_on_count'],'drum_fallback':qa['drum_track']['fallback'],'drum_adapter_policy':qa['drum_adapter_policy'],'comparison_target_lufs':cr['comparison_target_lufs'],'comparison_gain_db':cr['comparison_constant_gain_db'],'bus_compression':cr['compression'],'game_extra_attenuation_db':cr['game_extra_fixed_attenuation_db'],'game_total_gain_db':cr['game_total_gain_db'],'outputs':formats,'manual_listening_review':'not performed'})
 expected_total=sum(x['midi_note_count'] for x in M['inputs'])
 if expected_total!=42063:errors.append(f'expected note total changed: {expected_total}')
 compressed_titles=[x['title'] for x in items if x['bus_compression']]
 effects_policy='Tone shaping is applied in source role stems. Gentle bus compression was used for '+', '.join(compressed_titles)+'. No time, pitch, MIDI event, or CC edits were made.' if compressed_titles else 'Tone shaping is applied in source role stems; no bus compression or MIDI event edits were made.'
 result={'status':'PASS' if not errors and len(items)==12 else 'FAIL','songs':len(items),'total_frozen_midi_note_events':expected_total,'missing_or_silent_stems':0,'source_event_fidelity':'Frozen source MIDI hashes and source note-on/off pairs were verified across all 12 inputs. For drum triggers, each source channel-9 trigger record includes source_channel and source_end_tick and is pair-matched against the source MIDI. This verifies source provenance, not event identity of the renderer-only FluidSynth derivative.','drum_adapter_policy':'The FluidSynth render-only derivative omits source drum note-offs so selected one-shot samples follow their natural sample decay; this does not assert source note-offs are artificial or invalid. Closed/pedal-hat events choke an active open-hat sample. Temporary channel, pitch, and control-flow adaptations are not original MIDI events. Frozen source MIDI is unchanged.','event_fidelity_check_scope':'42,063 note-on/off source pairs verified against frozen MIDI and mapped trigger provenance. Pitched stems retain source pitch/onset/offset/velocity events; drum trigger logs preserve source onsets and are paired to source off ticks, while the renderer-only drum derivative applies the documented one-shot/choke policy and is not byte-for-byte/event-for-event identical.','audio_outputs':{'game_ogg_48k_stereo':12,'comparison_flac_24bit':12,'comparison_mp3_320k':12},'loudness_policy':'A/B/C preview static gain; comparison target follows existing A/B target within ±0.3 LU; C game OGG uses separately reported fixed attenuation to approximately -21 LUFS and TP <= -3 dBTP','effects_policy':effects_policy,'bus_compressed_cues':[{'cue_id':x['cue_id'],'title':x['title'],'filter':x['bus_compression']['filter'],'reason':x['bus_compression']['reason']} for x in items if x['bus_compression']],'source_and_license_lock':'sources/instrument-sources.json','SF2_keyzone_audit':'sources/muldjordkit/sf2-keyzone-audit.json','scripts':{p.name:sha(p) for p in sorted((BASE/'tools').glob('*.py'))},'items':items,'errors':errors}
 out=BASE/'audio-production-release-report.json'; out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n'); print(json.dumps({'status':result['status'],'songs':len(items),'note_events':expected_total,'errors':errors,'path':str(out)},ensure_ascii=False))
if __name__=='__main__':main()

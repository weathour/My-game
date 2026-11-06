#!/usr/bin/env python3
"""Reproducibly render all frozen MIDI cues through non-drum, kit, and C stages."""
import collections, json, subprocess, sys, time
from pathlib import Path
import mido

ROOT=Path(__file__).resolve().parents[3]; BASE=ROOT/'design/music-20261103-midi-test'; M=json.loads((BASE/'experiment-manifest.json').read_text())
PY=Path(sys.executable)
TOOLS=BASE/'tools'; TRIALS=BASE/'trials'; REPORT=BASE/'audio-production-batch-status.json'
MULDJORD=Path.home()/'.cache/my-game/music-instruments/muldjordkit/MuldjordKit-SF2-20201018/MuldjordKit 20201018.sf2'

def run(cmd): subprocess.run([str(x) for x in cmd],check=True)
def main():
 state={'status':'running','started_epoch':time.time(),'items':[]}; REPORT.write_text(json.dumps(state,indent=2)+'\n')
 root_comp=Path(M['inputs'][0]['existing_gm_comparison_report']).parent.parent
 for item in M['inputs']:
  i=item['index']; title=item['title']; cue=f'midi_test_{i:02d}'; src=BASE/'inputs'/f'{cue}.mid'
  folder={1:'tbp_non_drum',2:'mobscene_non_drum',11:'minute_decay_non_drum'}.get(i,f'{i:02d}_non_drum'); out=TRIALS/folder
  row={'index':i,'cue_id':cue,'title':title,'status':'running','input_sha256':item['midi_sha256']}; state['items'].append(row); REPORT.write_text(json.dumps(state,indent=2)+'\n')
  try:
   if item.get('repo_midi_file'):
    rp=ROOT/item['repo_midi_file']; src=rp if rp.exists() else src
   # Remove only the old zero placeholder drum stem from our earlier development run.
   placeholder=out/'01_drums.wav'
   if placeholder.exists(): placeholder.unlink()
   run([PY,TOOLS/'render_non_drum_stems.py','--midi',src,'--out',out,'--title',title])
   keys=collections.Counter(msg.note for tr in mido.MidiFile(src).tracks for msg in tr if msg.type=='note_on' and msg.velocity>0 and msg.channel==9)
   run([PY,TOOLS/'render_gm_drum_oneshots.py','--midi',src,'--out',out/'drums.wav','--kit','standard','--soundfont',MULDJORD])
   if 54 in keys:
    run([PY,TOOLS/'render_gm_drum_oneshots.py','--midi',src,'--out',out/'drum_fallback.wav','--kit','standard','--only-unmapped'])
   else:
    fallback=out/'drum_fallback.wav'; report=fallback.with_name(fallback.stem+'-drums-report.json')
    if fallback.exists(): fallback.unlink()
    if report.exists(): report.unlink()
   comp=Path(item['existing_gm_comparison_report']); songdir=comp.parent; asset=ROOT/'assets/music/midi_test'/f'{cue}.ogg'
   run([PY,TOOLS/'mix_align_encode_c.py','--index',i,'--stems',out,'--out',songdir,'--asset',asset])
   run([PY,TOOLS/'build_production_qa.py','--index',i])
   row['status']='completed'; row['drum_source_key_54_count']=keys[54]; row['midi_sha256']=item['midi_sha256']
  except Exception as e:
   row['status']='failed'; row['error']=str(e)
  REPORT.write_text(json.dumps(state,indent=2,ensure_ascii=False)+'\n')
 state['status']='completed' if all(x['status']=='completed' for x in state['items']) else 'completed_with_errors'
 state['completed_epoch']=time.time(); REPORT.write_text(json.dumps(state,indent=2,ensure_ascii=False)+'\n')
 print(json.dumps({'status':state['status'],'completed':sum(x['status']=='completed' for x in state['items']),'failed':sum(x['status']=='failed' for x in state['items'])},ensure_ascii=False))
if __name__=='__main__':main()

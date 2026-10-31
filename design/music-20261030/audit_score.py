#!/usr/bin/env python3
"""Check every authored event against the exact selected sample regions."""
import argparse,json
from pathlib import Path
from collections import Counter
from audio_engine import Sampler,DEFAULT_MANIFEST,DEFAULT_CACHE,validate_cue


def audit(cues,manifest):
    sampler=Sampler(manifest,DEFAULT_CACHE)
    result=[]
    for cue in cues:
        validate_cue(cue,manifest)
        for part in cue['tracks']:
            inst=manifest['instruments'][part['instrument']]
            if inst['status']=='synthesized': continue
            events=sorted(part['notes'],key=lambda n:(n[0],n[2],n[1],n[3]))
            for index,event in enumerate(events):
                start,duration,pitch,velocity=event
                mode=part.get('articulation','auto')
                if mode=='auto': mode='short' if duration*60/cue['bpm']<.24 else 'sustain'
                if mode not in inst.get('patches',{}): mode='sustain'
                patch=inst['patches'][mode]
                if isinstance(patch,list): patch=patch[min(len(patch)-1,sum(pitch>=k for k in inst.get('split_keys',[56,67])))]
                key=inst.get('fixed_key',pitch)
                if 'unpitched_key' in inst and pitch not in inst.get('unpitched_keys',[60,61,62]): key=inst['unpitched_key']
                key=inst.get('note_map',{}).get(str(pitch),key)
                issues=[]
                selected=sampler.select(patch,key,velocity,index,'attack',issues)
                if not selected: issues.append({'type':'no_attack_sample'})
                for issue in issues:
                    result.append({'cue':cue['id'],'track':part['name'],'instrument':part['instrument'],'event':event,**issue})
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--score',type=Path,default=Path(__file__).with_name('score.json'))
    p.add_argument('--output',type=Path)
    a=p.parse_args()
    report=audit(json.loads(a.score.read_text()),json.loads(DEFAULT_MANIFEST.read_text()))
    if a.output:
        a.output.parent.mkdir(parents=True,exist_ok=True)
        a.output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'issues':len(report),'by_cue':dict(Counter(x['cue'] for x in report))},ensure_ascii=False))
    for key,count in Counter((x['cue'],x['track'],x['type'],x.get('pitch')) for x in report).items(): print(count,key)

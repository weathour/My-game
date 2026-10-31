#!/usr/bin/env python3
"""Compile the authored cue roster and its staged game catalog."""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
from compositions import world, military, characters, signals
from scorelib import validate

HERE = Path(__file__).resolve().parent
VARIANTS = {
    'hero_daily': 'hero_main',
    'army_caoxiu_warform': 'army_cao',
    'army_caochun_human': 'army_cao',
    'army_caochun_warform': 'army_caochun_human',
    'character_liao_warform': 'character_liao',
    'boss_lubu_warform': 'boss_lubu',
    'character_emma_wary': 'character_emma',
    'character_lingqi_aftermath': 'character_lingqi',
}
CHAPTER = {'region_baimen_road','region_ghost_market','region_old_city',
           'baimen_epilogue','hero_main','army_cao','character_liao',
           'boss_lubu','character_emma','character_lingqi'}


def build():
    titles = json.loads((HERE / 'title-overrides.json').read_text())
    cues = [c for module in (world, military, characters, signals) for c in module.build_cues()]
    ids = [c['id'] for c in cues]
    if len(ids) != len(set(ids)) or set(ids) != set(titles):
        raise ValueError('Cue roster/title mismatch')
    groups = defaultdict(list)
    for c in cues:
        c['musical_role'] = c['category']
        c['category'] = 'stinger' if not c['loop'] else 'phase_variant' if c['id'] in VARIANTS else 'bed'
        c['scope'] = 'baimen' if c['id'] in CHAPTER or c['id'] in VARIANTS else 'shared'
        c.update(titles[c['id']])
        c['listening_review'] = False
        if c['id'] in VARIANTS:
            c['variant_of'] = VARIANTS[c['id']]
        if c.get('sync_group'):
            groups[c['sync_group']].append(c)
        validate(c)
    for name, members in groups.items():
        if len(members) > 1:
            if len({(c['bpm'],c['beats'],c['loop']) for c in members}) != 1:
                raise ValueError('Incompatible synchronous family: '+name)
            for c in members:
                c['phase_family'] = name
    assert Counter(c['category'] for c in cues) == {'bed':38,'phase_variant':8,'stinger':24}
    assert len([c for c in cues if c['category']=='bed' and c['scope']=='baimen']) == 10
    catalog = {'version':1, 'cues':[]}
    for c in cues:
        row = {k:c[k] for k in ('id','title','scene','category','scope','loop','bpm','beats')}
        row['kind'] = {'bed':'场景配乐','phase_variant':'主题变奏','stinger':'音乐短提示'}[c['category']]
        row['path'] = 'res://assets/music/chronicle/'+c['id']+'.ogg'
        if c.get('phase_family'):
            row['phase_family'] = c['phase_family']
        if c.get('variant_of'):
            row['variant_of'] = c['variant_of']
        catalog['cues'].append(row)
    return cues,catalog


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output',type=Path,default=HERE)
    args=p.parse_args()
    cues,catalog=build()
    args.output.mkdir(parents=True,exist_ok=True)
    for name,data in [('score.json',cues),('catalog.staged.json',catalog)]:
        (args.output/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    files=[HERE/'scorelib.py',HERE/'title-overrides.json',Path(__file__).resolve(),*sorted((HERE/'compositions').glob('*.py'))]
    report={'cue_count':len(cues),'categories':dict(Counter(c['category'] for c in cues)),
            'musical_seconds':round(sum(c['beats']*60/c['bpm'] for c in cues),3),
            'notes':sum(len(t['notes']) for c in cues for t in c['tracks']),
            'source_sha256':{str(f.relative_to(HERE)):hashlib.sha256(f.read_bytes()).hexdigest() for f in files},
            'listening_review':False}
    (args.output/'build-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='source_sha256'},ensure_ascii=False))

if __name__=='__main__': main()

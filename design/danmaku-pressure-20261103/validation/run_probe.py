#!/usr/bin/env python3
"""Isolated production-logic probe. No project assets or player data imported."""
import argparse, hashlib, json, os, pathlib, re, shutil, subprocess, tempfile, platform
ROOT=pathlib.Path(__file__).resolve().parents[3]
HERE=pathlib.Path(__file__).resolve().parent
p=argparse.ArgumentParser(); p.add_argument('version',choices=['before','after']); p.add_argument('--suite',default='mobs',choices=['mobs','boss','exposure','growth','duel','cadence']); p.add_argument('--seeds',default='1701,2219,3191'); p.add_argument('--label',default=''); p.add_argument('--stages',default=''); p.add_argument('--godot',default='/home/weathour/.local/bin/godot'); a=p.parse_args()
target=pathlib.Path(tempfile.mkdtemp(prefix='danmaku-'+a.version+'-'))
(target/'project.godot').write_text('config_version=5\n[application]\nconfig/name="IsolatedDanmakuProbe"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
pending=['scripts/battle/battle_session.gd','scripts/content/stage_catalog.gd']; copied={}
while pending:
    rel=pending.pop()
    if rel in copied: continue
    source=ROOT/rel
    if a.version=='before' and (ROOT/'design/danmaku-pressure-20261103/runtime/before-source'/rel).is_file(): source=ROOT/'design/danmaku-pressure-20261103/runtime/before-source'/rel
    text=source.read_text(); copied[rel]=hashlib.sha256(text.encode()).hexdigest()
    dest=target/rel; dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text(text)
    pending+=re.findall(r'(?:preload|load)\("res://([^\"]+\.gd)"\)',text)
if a.version=='before':
    baseline=json.loads((ROOT/'design/danmaku-pressure-20261103/encounters/before.json').read_text())
    for rel,key,const in [('scripts/content/enemy_catalog.gd','enemies','DEFINITIONS'),('scripts/content/stage_catalog.gd','stages','STAGES'),('scripts/content/boss_forms.gd','forms','FORM_DEFINITIONS')]:
        dest=target/rel;text=dest.read_text();start=text.index('const '+const+' := ');begin=text.index('{',start);depth=0;quoted=False;escaped=False;end=None
        for i in range(begin,len(text)):
            c=text[i]
            if quoted:
                if escaped: escaped=False
                elif c=='\\': escaped=True
                elif c=='"': quoted=False
                continue
            if c=='"': quoted=True
            elif c=='{': depth+=1
            elif c=='}':
                depth-=1
                if depth==0: end=i+1;break
        assert end
        dest.write_text(text[:begin]+json.dumps(baseline[key],ensure_ascii=False,indent='\t')+text[end:])
shutil.copy2(HERE/'pressure_probe.gd',target/'pressure_probe.gd')
manifest={rel:hashlib.sha256((target/rel).read_bytes()).hexdigest() for rel in copied}
metadata={'version':a.version,'suite':a.suite,'seeds':a.seeds,'machine':platform.uname()._asdict(),'cpu':next((x.split(':',1)[1].strip() for x in pathlib.Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name')),''),'source_sha256':manifest,'baseline_reconstruction':'frozen seven core files + all frozen enemies/stages/forms; other reachable script dependencies unchanged from current workspace' if a.version=='before' else 'consistent copied current workspace dependency closure; caller must arrange freeze','tmp_project':str(target),'godot':a.godot,'runner_sha256':hashlib.sha256((HERE/'pressure_probe.gd').read_bytes()).hexdigest()}
stem=(a.label+'-' if a.label else '')+a.version+'-'+a.suite
out=HERE/(stem+'.json');log=HERE/(stem+'.log');meta=HERE/(stem+'-manifest.json')
env=os.environ.copy();env['XDG_DATA_HOME']=str(target/'xdg');env['XDG_CONFIG_HOME']=str(target/'config');env['XDG_CACHE_HOME']=str(target/'cache')
cmd=[a.godot,'--headless','--path',str(target),'--script',str(target/'pressure_probe.gd'),'--','--suite='+a.suite,'--seeds='+a.seeds,'--output='+str(out)]
cmd+=['--stages='+a.stages] if a.stages else []
metadata['label']=a.label;metadata['stages']=a.stages;metadata['command']=cmd;meta.write_text(json.dumps(metadata,ensure_ascii=False,indent=2))
with log.open('w') as f: result=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,env=env,timeout=600)
print(log.read_text());print('exit',result.returncode,'report',out);raise SystemExit(result.returncode)

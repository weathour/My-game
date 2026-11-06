#!/usr/bin/env python3
from pathlib import Path
import json,os,shutil,subprocess,hashlib
p=Path(__file__).resolve().parent
manifest=json.loads((p/'after-exposure-manifest.json').read_text())
tmp=Path(manifest['tmp_project'])
freeze_record=json.loads((p.parent/'runtime/core-freeze.json').read_text())
freeze=freeze_record['sha256']
if 'previous_sha256' in freeze_record and all(manifest['source_sha256'].get(k)==v for k,v in freeze_record['previous_sha256'].items()): freeze=freeze_record['previous_sha256']
checks={name:hashlib.sha256((tmp/name).read_bytes()).hexdigest()==expected for name,expected in freeze.items()}
assert all(checks.values()),checks
(p/'freeze-verification.json').write_text(json.dumps({'checks':checks,'all_match':True,'manifest':'after-exposure-manifest.json','reference_sha256':freeze,'reference_epoch':'initial_candidate' if freeze==freeze_record.get('previous_sha256') else 'current_candidate'},indent=2))
env=os.environ.copy()
for kind in ['DATA','CONFIG','CACHE']:env['XDG_'+kind+'_HOME']=str(tmp/('checks-'+kind.lower()))
with (p/'frozen-checks.log').open('w') as log:
 for script,extra in [('geometry_probe.gd',[]),('marker_timing_review.gd',['--source='+str(p/'after-boss.json')])]:
  shutil.copy2(p/script,tmp/script)
  target=p/(script.removesuffix('.gd')+'.json')
  subprocess.run([manifest['godot'],'--headless','--path',str(tmp),'--script',str(tmp/script),'--','--output='+str(target)]+extra,stdout=log,stderr=subprocess.STDOUT,env=env,check=True,timeout=90)
print((p/'frozen-checks.log').read_text())

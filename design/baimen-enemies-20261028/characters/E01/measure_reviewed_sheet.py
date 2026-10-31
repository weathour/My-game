"""Select actual connected silhouettes after visual review; never slices a grid or changes pixels.

Input JSON gives measured body calibration and per-pose grounding after inspecting source.
This helper is local to the ordinary-enemy producer; common exporter remains W3-owned.
"""
import importlib.util
import json
import sys
from pathlib import Path

spec = importlib.util.spec_from_file_location('audit', 'design/baimen-enemies-20261028/audit_exports.py')
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)
cfg = json.loads(Path(sys.argv[1]).read_text())
folder = Path('design/baimen-enemies-20261028/characters') / cfg['id']
record = audit.components(folder / cfg['sheet'])
(folder / (cfg['sheet'].replace('.png', '-components.json'))).write_text(json.dumps(record, indent=2)+'\n')
major = [part for part in record['components'] if part['area'] > cfg.get('main_min_area',1000)]
assert len(major) == 20, (cfg['id'], 'review composite parts manually', len(major))
major.sort(key=lambda p:(p['bbox'][1]+p['bbox'][3])/2)
ordered = []
for row in range(5):
    ordered.extend(sorted(major[row*4:row*4+4], key=lambda p:p['bbox'][0]))
poses = []
for index, main in enumerate(ordered):
    x0,y0,x1,y1 = main['bbox']
    parts = [p for p in record['components'] if p == main or (p['area']<1000 and x0-3<=p['bbox'][0]<=p['bbox'][2]<=x1+3 and y0-3<=p['bbox'][1]<=p['bbox'][3]<=y1+3)]
    anchor = cfg['anchors'][index] if 'anchors' in cfg else [cfg['hip_x'][index%4], y1]
    poses.append({'id':f'p{index:02d}','source':'actions','anchor_source':anchor,'components':parts})
portrait = audit.components(folder/cfg['master'])
clips = {key:{'poses':[f'p{i:02d}' for i in range(row*4,row*4+4)],'fps':fps,'windup_frame':0,'contact_frame':2} for row,(key,fps) in enumerate([('idle',6),('move',8),('attack',10),('special',10),('hit',10)])}
canvas = cfg.get('canvas',{'size':[192,192],'anchor':[96,176],'body_height_px':80})
measurements = {'version':1,'id':cfg['id'],'review_status':'accepted_for_export','review_notes':cfg['review_notes'],'prompts':sorted(str(p.relative_to(folder)) for p in (folder/'prompts').glob('*.txt')),'canvas':canvas,'sources':{'actions':{'path':cfg['sheet'],'size':record['size'],'sha256':record['sha256'],'standing_body_height':cfg['standing_body_height']}},'portrait':{'path':cfg['master'],'size':portrait['size'],'sha256':portrait['sha256']},'poses':poses,'clips':clips,'action_clips':cfg['action_clips'],'faces_left':False}
(folder/'measurements.json').write_text(json.dumps(measurements,ensure_ascii=False,indent=2)+'\n')
print(cfg['id'], 'reviewed regions', [p['components'][0]['bbox'] for p in poses])

"""Read-only raster measurement after producer visually reviews all complete poses.

Input is per-character reviewed-extraction.json with manual ground anchors and
source body calibration. This script never edits raster pixels or grid-crops.
"""
from pathlib import Path
from PIL import Image
import importlib.util
import hashlib
import json
import sys

root = Path('design/baimen-enemies-20261028')
spec = importlib.util.spec_from_file_location('baimen_audit', root/'audit_exports.py')
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)
for identity in sys.argv[1:]:
    folder = root/'characters'/identity
    cfg = json.loads((folder/'reviewed-extraction.json').read_text())
    source_path = folder/'source'/cfg.get('source', 'actions-v1.png')
    record = audit.components(source_path)
    (source_path.with_suffix('.components.json')).write_text(json.dumps(record, indent=2)+'\n')
    bodies = [part for part in record['components'] if part['area'] > cfg.get('minimum_body_area', 5000)]
    assert len(bodies) == 20, (identity, 'review found wrong body count', len(bodies))
    # Order true connected bodies by their reviewed row-centres; no cell clipping.
    bodies.sort(key=lambda p:(p['bbox'][1]+p['bbox'][3])/2)
    ordered = []
    for row in range(5):
        ordered.extend(sorted(bodies[row*4:row*4+4], key=lambda p:p['bbox'][0]))
    poses = []
    assert len(cfg['anchors']) == 20
    for index, (body, anchor) in enumerate(zip(ordered, cfg['anchors'])):
        parts = [body]
        for part in record['components']:
            if part in bodies:
                continue
            x0,y0,x1,y1 = part['bbox']; cx,cy=(x0+x1)/2,(y0+y1)/2
            def distance(candidate):
                u,v,w,h = candidate['bbox']
                return max(u-cx,0,cx-w)**2 + max(v-cy,0,cy-h)**2
            if min(bodies, key=distance) == body and distance(body) <= cfg.get('outline_join_distance_sq',100):
                parts.append(part)
        poses.append({'id':f'p{index+1:02}', 'source':'actions', 'anchor_source':anchor, 'components':parts})
    def info(path):
        with Image.open(path) as image:
            return {'path':str(path.relative_to(folder)), 'size':list(image.size), 'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    source = info(source_path)
    source['standing_body_height'] = cfg['standing_body_height']
    measurements = {'version':1,'id':identity,'review_status':'accepted_for_export','review_notes':cfg['review_notes'],
        'prompts':[str(path.relative_to(folder)) for path in sorted((folder/'source').glob('*prompt.txt'))],
        'canvas':cfg['canvas'],'sources':{'actions':source},'portrait':info(folder/'source'/cfg.get('master','master-v1.png')),
        'poses':poses,'clips':{},'action_clips':cfg['action_clips']}
    for row,name in enumerate(('idle','move','attack','special','hit')):
        measurements['clips'][name]={'poses':[f'p{index+1:02}' for index in range(row*4,row*4+4)],
            'fps':[6,9,8,8,10][row],'windup_frame':1 if row in (2,3) else 0,'contact_frame':2}
    (folder/'measurements.json').write_text(json.dumps(measurements, ensure_ascii=False, indent=2)+'\n')
    print('MEASURED_REVIEWED_COMPONENTS',identity,len(poses))

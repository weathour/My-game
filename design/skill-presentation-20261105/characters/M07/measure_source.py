# Read-only PNG analysis. Coordinates are individually reviewed source hips/feet.
from pathlib import Path
from hashlib import sha256
import json
root=Path(__file__).resolve().parent
analysis=json.loads((root/'source/component-analysis.json').read_text())
main=sorted([p for p in analysis['components'] if p['area']>=300],key=lambda p:(round((p['bbox'][1]+p['bbox'][3])/2/245),p['bbox'][0]))
# Manual source figure grouping from reviewed actual alpha components, not crop cells.
boxes=[[63,12,250,253],[367,12,563,253],[688,12,877,253],[1001,15,1192,253],[48,269,264,478],[365,267,570,481],[682,268,884,481],[998,267,1230,479],[38,483,255,726],[350,508,619,726],[655,517,949,726],[991,508,1192,724],[41,762,272,964],[345,758,578,974],[669,737,899,974],[977,755,1217,974]]
hips=[160,469,789,1101,171,493,808,1138,156,464,784,1095,151,466,783,1091]
parts={tuple(p['bbox']):p for p in analysis['components']}
poses=[]
for i,(bbox,hip) in enumerate(zip(boxes,hips),1):
 poses.append({'id':f'p{i:02d}','source':'combat','anchor_source':[hip,bbox[3]],'hip_source':[hip,bbox[3]-91], 'components':[parts[tuple(bbox)]], 'body_bbox':bbox})
source=root/'source/combat-bundle-v1.png'
m={'version':1,'id':'M07','review_status':'accepted_for_export','review_notes':'Agent source review: black topknot/beard/fur mantle/iron lamellar/rope belt preserved; one intact right-directed dao, two limbs per side, 16 distinct source poses and independent portrait. Tiny isolated alpha specks omitted. Fixed source standing body 241 pixels (hair12..feet253), manual hip/feet anchors. User aesthetic acceptance remains pending.','canvas':{'size':[192,192],'anchor':[96,176],'body_height_px':80},'faces_left':False,'sources':{'combat':{'path':'source/combat-bundle-v1.png','size':analysis['size'],'sha256':sha256(source.read_bytes()).hexdigest(),'standing_body_height':241}},'portrait':{'path':'source/combat-bundle-v1.png','size':analysis['size'],'sha256':sha256(source.read_bytes()).hexdigest(),'bbox':[31,993,283,1246]},'poses':poses,'clips':{}}
for name,start,fps in [('idle',1,6),('move',5,10),('attack',9,10),('special',13,10)]:m['clips'][name]={'poses':[f'p{i:02d}' for i in range(start,start+4)],'fps':fps,'windup_frame':0,'contact_frame':1}
m['clips']['hit']={'poses':['p13','p01'],'fps':10,'windup_frame':0,'contact_frame':0,'source_note':'Reuses reviewed braced and ready poses; not newly drawn hit frames.'}
(root/'measurements.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n')

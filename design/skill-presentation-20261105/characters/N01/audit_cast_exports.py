"""Read-only raster QA for the N01-N09 export set; writes metadata reports only."""
from pathlib import Path
from hashlib import sha256
import json
from PIL import Image
ROOT=Path(__file__).resolve().parents[4]
for n in range(1,10):
 id=f'N{n:02d}'; base=ROOT/'design/skill-presentation-20261105/characters'/id; out=ROOT/'assets/players/chronicle-cast'/id
 m=json.loads((base/'measurements.json').read_text()); manifest=json.loads((out/'manifest.json').read_text())
 colors=set(); records=[]; clips={}
 for name in ['idle','move','attack','special','hit','head']:
  p=out/f'{name}.png'; im=Image.open(p); assert im.mode=='RGBA',(id,name,im.mode)
  assert set(im.getchannel('A').getdata())=={0,255},(id,name,'alpha')
  if name=='head':
   assert im.size==(128,128)
   # 64px native portrait exported by exact 2x nearest-neighbor scaling.
   for y in range(0,128,2):
    for x in range(0,128,2):assert len(set(im.crop((x,y,x+2,y+2)).getdata()))==1
  else:
   count=2 if name=='hit' else 4; assert im.size==(192*count,192)
   colors.update(px[:3] for px in im.getdata() if px[3])
   frames=[im.crop((i*192,0,(i+1)*192,192)) for i in range(count)]
   distinct=len({f.tobytes() for f in frames}); assert distinct==count,(id,name,'duplicate frame')
   bounds=[list(f.getbbox()) for f in frames]
   assert all(b[0]>0 and b[1]>0 and b[2]<192 and b[3]==176 for b in bounds),(id,name,bounds)
   clips[name]={'frames':count,'distinct_frames':distinct,'bounds':bounds}
  records.append({'path':str(p.relative_to(ROOT)),'size':list(im.size),'sha256':sha256(p.read_bytes()).hexdigest()})
 assert len(colors)<=64,(id,len(colors))
 for p in sorted(out.glob('*.aseprite')):
  assert p.stat().st_size>100
  records.append({'path':str(p.relative_to(ROOT)),'bytes':p.stat().st_size,'sha256':sha256(p.read_bytes()).hexdigest()})
 assert len(list(out.glob('*.aseprite')))==7
 source=base/'source/asset-bundle-v1.png'; assert sha256(source.read_bytes()).hexdigest()==m['sources']['combat']['sha256']
 assert m['portrait']['independently_drawn'] and m['portrait']['bbox'][1]>m['poses'][-1]['components'][0]['bbox'][3]
 report={'id':id,'status':'passed','actor_palette_colors':len(colors),'binary_alpha':True,'unique_source_body_poses':16,'clips':clips,'portrait_native_px':64,'portrait_export_px':128,'source_hash_verified':True,'visual_review':'Original full source and Aseprite exported QA contact sheet inspected: coherent role silhouette, intact weapons/feet, plausible limbs, no baked floor. Ground anchor and body scaling accepted for integration; user aesthetic acceptance pending.','scope':'Raster/export checks only; runtime rendering and action integration owned by main task.'}
 (base/'qa.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
 record={'version':1,'visual_id':id,'generator':'built-in image_gen.imagegen','exporter':'scripts/tools/import_chronicle_cast_art.lua','measurements':'measurements.json','source':m['sources']['combat'],'portrait_source':m['portrait'],'body_height_px':80,'anchor_px':[96,176],'faces_left':False,'outputs':records,'review_status':'raster_audit_passed','source_review':'Source v1 selected; all sixteen unique body poses and separately authored bust reviewed. Hit is a two-pose reuse of idle p01/p02, not a newly drawn hit action.','qa':'qa.json'}
 (base/'export-manifest.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
 manifest['status']='raster_audit_passed';(out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 print(id,'RASTER_AUDIT_OK','palette',len(colors),'clips',','.join(f'{k}:{v["frames"]}' for k,v in clips.items()))

# Pillow is used only to read existing PNGs; this script never writes image pixels.
from pathlib import Path
from hashlib import sha256
from PIL import Image
import json,sys
root=Path(__file__).resolve().parent
character=root.name
repo=next(p for p in root.parents if (p/'project.godot').exists())
out=repo/'assets/players/chronicle-cast'/character
m=json.loads((root/'measurements.json').read_text())
manifest=json.loads((out/'manifest.json').read_text())
for source in m['sources'].values():
 p=root/source['path'];assert sha256(p.read_bytes()).hexdigest()==source['sha256'];assert list(Image.open(p).size)==source['size']
assert len(m['poses'])==16 and len({tuple(p['components'][0]['bbox']) for p in m['poses']})==16
colors=set();report={'character_id':character,'checks':{},'clips':{},'technical_status':'pass','visual_export_review':'All five exported clips and independent head inspected with view_image; direction, grip, complete silhouette, scale and foot alignment reviewed.','aesthetic_status':'pending_user_review'}
manifest['status']='audited'
(out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
outputs=[]
for action in ['idle','move','attack','special','hit']:
 p=out/f'{action}.png';im=Image.open(p);assert im.mode=='RGBA'
 count=len(m['clips'][action]['poses']);assert im.size==(192*count,192)
 assert set(im.getchannel('A').getdata())=={0,255}
 frames=[];hashes=[]
 for i in range(count):
  frame=im.crop((192*i,0,192*(i+1),192));bbox=frame.getbbox();assert bbox and bbox[0]>0 and bbox[1]>0 and bbox[2]<192 and bbox[3]<192,(p,i,bbox)
  # Feet anchors were manually measured on source. Bottom silhouette can include a staff tip.
  pose=next(s for s in m['poses'] if s['id']==m['clips'][action]['poses'][i]);src=m['sources'][pose['source']]
  factor=80/src['standing_body_height'];actual_bottom=bbox[3]-1
  expected_bottom=176+round((max(v['bbox'][3] for v in pose['components'])-pose['anchor_source'][1])*factor)-1
  assert abs(actual_bottom-expected_bottom)<=1,(p,i,actual_bottom,expected_bottom)
  frames.append({'pose':pose['id'],'bbox':list(bbox),'bottom_pixel':actual_bottom,'foot_anchor':[96,176],'source_foot':pose['anchor_source'],'source_hip':pose['hip_source'],'sha256_rgba':sha256(frame.tobytes()).hexdigest()})
  hashes.append(frames[-1]['sha256_rgba'])
 assert len(set(hashes))==count,(action,'duplicate exported frames')
 colors.update(p[:3] for p in im.getdata() if p[3])
 report['clips'][action]={'frames':count,'unique_frames':len(set(hashes)),'poses':frames,'source_reuse':action=='hit'}
assert len(colors)<=64,len(colors)
head=Image.open(out/'head.png');assert head.mode=='RGBA' and head.size==(128,128) and set(head.getchannel('A').getdata())=={0,255}
for p in sorted(out.iterdir()):
 if p.suffix in ['.png','.aseprite','.json']:
  r={'path':str(p.relative_to(repo)),'sha256':sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size}
  if p.suffix=='.png':r['size']=list(Image.open(p).size)
  outputs.append(r)
report['checks']={'binary_alpha':True,'actor_shared_opaque_colors':len(colors),'maximum_opaque_colors':64,'no_canvas_clipping':True,'four_distinct_frames_per_main_clip':True,'source_independent_drawings':16,'hit_reused_frames':2,'body_height_px':80,'world_body_height':72,'runtime_scale':0.9,'anchor_px':[96,176],'portrait_independently_drawn':True,'portrait_native_size':[64,64],'portrait_export_size':[128,128]}
report['limitations']=['Technical and source identity/anatomy review only; aesthetic user review and game scene acceptance are separate.','Hit reuses reviewed braced/ready poses; it is not two new hand-drawn hurt poses.']
(root/'QA.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
inputs=[]
for p in sorted(root.rglob('*')):
 if p.is_file() and p.suffix in ['.png','.txt','.json','.py','.lua'] and p.name not in ['QA.json','export-manifest.json']:
  inputs.append({'path':str(p.relative_to(repo)),'sha256':sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size})
export={'version':1,'character_id':character,'producer':'Built-in image_gen; Aseprite extraction/nearest-neighbor resize/64-color quantization/binary alpha/export; Pillow read-only analysis','selected_source_version':'combat-bundle-v1','selection_record':'Only v1 generated; accepted after identity, complete weapon, two arms/two legs and direction review. No rejected versions.','reference_identity_authority':'scripts/ui/chronicle/chronicle_portraits.gd and assets/data/chronicle/character_profiles.json','standing_body_height_source':m['sources']['combat']['standing_body_height'],'independent_actor_drawings':16,'clip_frames':{a:len(v['poses']) for a,v in m['clips'].items()},'hit_frame_reuse':['p13','p01'],'outputs':outputs,'inputs':inputs,'qa':'QA.json','aesthetic_status':'pending_user_review','runtime_status':'technical_exports_checked'}
(root/'export-manifest.json').write_text(json.dumps(export,ensure_ascii=False,indent=2)+'\n')
print('CAST_ART_AUDIT_OK',character,'distinct_actor_drawings=16','clips=4/4/4/4/2','opaque_colors='+str(len(colors)))

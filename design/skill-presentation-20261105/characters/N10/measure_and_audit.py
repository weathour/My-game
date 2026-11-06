"""Read-only pixel QA and measured component registration. Never draws raster pixels."""
from pathlib import Path
from hashlib import sha256
import argparse,json,struct
import numpy as np
from PIL import Image
from scipy.ndimage import label,find_objects
ROOT=Path('design/skill-presentation-20261105/characters')
def digest(p): return sha256(p.read_bytes()).hexdigest()
def analyze(p):
 im=Image.open(p); assert im.mode=='RGBA'
 labs,_=label(np.asarray(im.getchannel('A'))>=128); sizes=np.bincount(labs.ravel());parts=[]
 for i,s in enumerate(find_objects(labs),1):
  if s is None: continue
  y,x=s;parts.append({'bbox':[x.start,y.start,x.stop,y.stop],'area':int(sizes[i])})
 return {'path':str(p),'sha256':digest(p),'size':list(im.size),'alpha_threshold':128,'connectivity':4,'components':parts}
def measure(id,cal):
 root=ROOT/id;p=root/'source/combat-bundle-v1.png'; a=analyze(p); (root/'source/component-analysis.json').write_text(json.dumps(a,indent=2)+'\n')
 cfg=json.loads(Path(cal).read_text());groups=cfg['groups'];poses=[]
 for i,g in enumerate(groups):
  bounds=g['selection'];selected=[q for q in a['components'] if q['area']>=g.get('min_area',3) and q['bbox'][0]>=bounds[0] and q['bbox'][1]>=bounds[1] and q['bbox'][2]<=bounds[2] and q['bbox'][3]<=bounds[3]]
  assert selected,(id,i,bounds)
  bbox=[min(q['bbox'][0] for q in selected),min(q['bbox'][1] for q in selected),max(q['bbox'][2] for q in selected),max(q['bbox'][3] for q in selected)]
  poses.append({'id':f'p{i+1:02d}','source':'combat','anchor_source':g['feet'],'hip_source':g['hip'],'components':selected,'body_bbox':g.get('body_bbox',bbox)})
 assert len(poses)==16
 source={'path':'source/combat-bundle-v1.png','size':a['size'],'sha256':a['sha256'],'standing_body_height':cfg['standing_body_height']}
 m={'version':1,'id':id,'review_status':'accepted_for_export','review_notes':cfg['review_notes']+' All 16 actual distinct source poses measured with alpha-connected component extraction. Source scaling is fixed from standing human body calibration; hunched/galloping frames are not stretched. Tiny disconnected alpha specks below 3 pixels omitted. User aesthetic acceptance remains pending.','prompts':['prompt-v1.txt'],'canvas':{'size':cfg.get('canvas',[192,192]),'anchor':cfg.get('anchor',[96,176]),'body_height_px':80},'faces_left':False,'sources':{'combat':source},'portrait':{'path':source['path'],'size':a['size'],'sha256':a['sha256'],'bbox':cfg['portrait']},'poses':poses,'clips':{}}
 for name,start,fps in [('idle',1,6),('move',5,10),('attack',9,10),('special',13,10)]:m['clips'][name]={'poses':[f'p{i:02d}' for i in range(start,start+4)],'fps':fps,'windup_frame':0,'contact_frame':1}
 m['clips']['hit']={'poses':['p04','p01'],'fps':10,'windup_frame':0,'contact_frame':0,'source_note':'Reviewed braced and ready frames reused; no separately drawn hit frames.'}
 (root/'measurements.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n')
 print('MEASURE_OK',id,len(poses))
def audit(id):
 root=ROOT/id;out=Path('assets/players/chronicle-cast')/id;m=json.loads((root/'measurements.json').read_text());meta=json.loads((out/'manifest.json').read_text());w,h=m['canvas']['size'];colors=set();outputs=[]
 assert digest(root/m['sources']['combat']['path'])==m['sources']['combat']['sha256']
 for name,c in m['clips'].items():
  p=out/(name+'.png');im=Image.open(p);n=len(c['poses']);assert im.mode=='RGBA' and im.size==(w*n,h);assert set(im.getchannel('A').getdata())=={0,255};colors.update(px[:3] for px in im.getdata() if px[3]);hashes=[];boxes=[]
  for i in range(n):
   f=im.crop((i*w,0,(i+1)*w,h));b=f.getchannel('A').getbbox();assert b;assert b[0]>0 and b[1]>0 and b[2]<w and b[3]<h,(id,name,i,b,'touching canvas');boxes.append(b);hashes.append(sha256(f.tobytes()).hexdigest())
  assert len(set(hashes))==n,(id,name,'repeated frames')
  outputs.append({'path':str(p),'size':list(im.size),'sha256':digest(p),'frames':n,'frame_alpha_bounds':boxes,'frame_pixel_sha256':hashes})
  ap=out/(name+'.aseprite');data=ap.read_bytes();magic,frames,aw,ah=struct.unpack_from('<4H',data,4);assert (magic,frames,aw,ah)==(0xA5E0,n,w,h);outputs.append({'path':str(ap),'sha256':digest(ap),'frames':n,'size':[w,h]})
 assert len(colors)<=64,(id,len(colors))
 for name,n,size in [('actor',16,(w,h)),('head',1,(64,64))]:
  p=out/(name+'.aseprite');data=p.read_bytes();magic,frames,aw,ah=struct.unpack_from('<4H',data,4);assert (magic,frames,aw,ah)==(0xA5E0,n,*size);outputs.append({'path':str(p),'sha256':digest(p),'frames':n,'size':list(size)})
 p=out/'head.png';im=Image.open(p);assert im.mode=='RGBA' and im.size==(128,128);assert set(im.getchannel('A').getdata())=={0,255};outputs.append({'path':str(p),'sha256':digest(p),'size':list(im.size)})
 report={'version':1,'character_id':id,'generator':'Built-in ImageGen','pixel_processing':'Aseprite only; Pillow/scipy used read-only QA','source':m['sources']['combat'],'measurements_sha256':digest(root/'measurements.json'),'export_script':'scripts/tools/import_chronicle_cast_art.lua','export_script_sha256':digest(Path('scripts/tools/import_chronicle_cast_art.lua')),'actor_shared_opaque_colors':len(colors),'unique_body_poses':16,'clips':{k:len(v['poses']) for k,v in m['clips'].items()},'portrait':'Separately drawn bust in source bundle; 64px native head exported at nearest-neighbor 128px','outputs':outputs,'checks':{'binary_alpha':True,'frame_sizes':True,'distinct_frames_within_clips':True,'canvas_no_clipping':True,'editable_files':True,'source_hash':True}}
 (root/'export-manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');(root/'qa.json').write_text(json.dumps({'id':id,'status':'passed','read_only_raster_checks':report['checks'],'visual_review':m['review_notes'],'actor_shared_opaque_colors':len(colors)},ensure_ascii=False,indent=2)+'\n');meta['status']='final';(out/'manifest.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n');print('CAST_QA_OK',id,'poses=16 colors='+str(len(colors)))
a=argparse.ArgumentParser();a.add_argument('id');a.add_argument('--calibration');a.add_argument('--audit',action='store_true');args=a.parse_args();audit(args.id) if args.audit else measure(args.id,args.calibration)

"""Read-only Pillow/source/ASE audit. Aseprite performs all image changes."""
from pathlib import Path
from PIL import Image
from hashlib import sha256
import json,struct,sys
base=Path(__file__).resolve().parent;repo=base.parents[2]
out=repo/'assets/enemies/baimen/zhang_liao_summons'
partial='--partial' in sys.argv
manifest_path=(base/'partial-manifest.json') if partial else (out/'manifest.json')
m=json.loads((base/'measurements.json').read_text());manifest=json.loads(manifest_path.read_text());contract=json.loads((base/'contract.json').read_text());old=json.loads((base/'legacy-palettes.json').read_text())
poses={p['id']:p for p in m['poses']};source_tokens=set();source_hashes=[]
for name,s in m['sources'].items():
 path=Path(s['path']);path=path if path.is_absolute() else base/path
 assert sha256(path.read_bytes()).hexdigest()==s['sha256'];assert list(Image.open(path).size)==s['size']
 source_hashes.append({'source':name,'path':str(path.relative_to(repo)),'sha256':s['sha256'],'body_calibration':s.get('body_calibration'),'fixed_scale':s.get('fixed_scale')})
def ase_record(path,frames,size):
 data=path.read_bytes();length,magic,count,w,h,depth=struct.unpack_from('<IHHHHH',data)
 assert length==len(data) and magic==0xA5E0 and count==frames and [w,h]==size,(path,count,w,h)
 return {'path':str(path.relative_to(repo)),'frames':count,'size':[w,h],'depth':depth,'sha256':sha256(data).hexdigest()}
actor_count=effect_count=0;hashes=[];actor_colors={};records=[];outputs=[]
for name,clip in manifest['clips'].items():
 expected=contract['clips'][name];assert clip['frames']==expected['frames']
 assert clip['faces_left'] is False
 assert clip['frame_size']==([768,640] if clip['kind']=='actor' else [512,512])
 assert clip['kind'] in ['actor','effect'] and clip['type']==clip['kind']
 if clip['kind']=='actor':
  assert clip['anchor_px']==[384,608] and clip['body_height_px']==224
  assert clip['release_frame']==expected['release_frame'] and clip['contact_frame']==expected['contact_frame']
  assert 0<=clip['windup_frame']<=clip['release_frame']<=clip['contact_frame']<clip['frames']
  actor_count+=clip['frames']
 else:
  assert clip['anchor_px']==expected['anchor_px'] and clip['world_size']==expected['world_size']
  effect_count+=clip['frames']
 path=out/clip['file'];image=Image.open(path);fw,fh=clip['frame_size']
 assert image.mode=='RGBA' and image.size==(fw*clip['frames'],fh)
 assert set(image.getchannel('A').getdata())=={0,255}
 colors={p[:3] for p in image.getdata() if p[3]};assert len(colors)<=63
 if clip['kind']=='actor':
  palette={tuple(c) for c in old[clip['visual_id']]['rgb']};assert colors<=palette
  actor_colors.setdefault(clip['visual_id'],set()).update(colors)
 frame_records=[]
 for index,pose_id in enumerate(m['clips'][name]['poses']):
  frame=image.crop((index*fw,0,(index+1)*fw,fh));bbox=frame.getbbox();assert bbox and bbox[0]>0 and bbox[1]>0 and bbox[2]<fw and bbox[3]<fh
  p=poses[pose_id];token=(p['source'],tuple(tuple(c['bbox']) for c in p['components']));assert token not in source_tokens;source_tokens.add(token)
  digest=sha256(frame.tobytes()).hexdigest();hashes.append(digest)
  source=m['sources'][p['source']]
  factor=source['fixed_scale'] if clip['kind']=='effect' else 224/source['standing_body_height']
  expected_bottom=clip['anchor_px'][1]+int((max(c['bbox'][3] for c in p['components'])-p['anchor_source'][1])*factor+.5)
  assert abs(bbox[3]-expected_bottom)<=2,(name,index,bbox,expected_bottom)
  frame_records.append({'frame':index,'source_pose':pose_id,'bbox':list(bbox),'rgba_sha256':digest,'anchor_px':clip['anchor_px'],'source_anchor':p['anchor_source'],'body_height_px':clip.get('body_height_px',0),'source_fixed_scale':factor,'component_count':len(p['components'])})
 records.append({'key':name,'visual_id':clip['visual_id'],'role':clip['role'],'kind':clip['kind'],'frames':clip['frames'],'fps':clip['fps'],'contact_frame':clip.get('contact_frame',0),'release_frame':clip.get('release_frame',0),'opaque_colors':len(colors),'frames_read':frame_records})
 outputs.extend([{'path':str(path.relative_to(repo)),'sha256':sha256(path.read_bytes()).hexdigest(),'size':list(image.size)},ase_record(path.with_suffix('.aseprite'),clip['frames'],clip['frame_size'])])
assert len(hashes)==len(set(hashes)),'duplicate exported frame pixels'
assert all(len(colors)<=63 for colors in actor_colors.values())
if not partial:
 assert actor_count==60 and effect_count==16 and len(records)==10 and set(manifest['clips'])==set(contract['clips'])
report={'version':1,'status':'partial_not_runtime_accepted' if partial else 'pass','agent_visual_status':'All10 original sources and all10 quantized runtime montage previews inspected by art owner and root. No further runtime art changes required at static review.','actor_frames':actor_count,'effect_frames':effect_count,'independent_source_poses':len(source_tokens),'unique_runtime_frames':len(set(hashes)),
 'actor_shared_opaque_color_counts':{k:len(v) for k,v in actor_colors.items()},'actor_palette_is_subset_of_approved_legacy':True,'actor_frame_size':[768,640],'effect_frame_size':[512,512],'actor_body_height_px':224,'actor_ground_anchor':[384,608],
 'clips':records,'sources':source_hashes,'outputs':outputs,'visual_review':'Art owner inspects each original source and quantized/static output; physical new poses are source drawings, not affine transforms of legacy sprites. Pose-specific calibration/selection stays in measurements.json.',
 'limits':['Runtime timing, effect usage, world scaling and actual native performance validated by separate owners.','Technical/source review does not imply user aesthetic approval.','Legacy identity/palette sources remain untouched.']}
report_path=base/'qa'/('partial-art-qa.json' if partial else 'art-qa.json');report_path.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('SUMMON_ART_PIXEL_QA',report['status'],'actors',actor_count,'effects',effect_count,'unique',len(set(hashes)))
if not partial:
 manifest['status']='audited';manifest['qa']='res://design/zhang-liao-summons-20261106/art/qa/art-qa.json';manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 inputs=[]
 for p in sorted(base.rglob('*')):
  if p.is_file() and p.name not in ['export-manifest.json','partial-manifest.json'] and p.suffix in ['.png','.json','.lua','.py','.txt']:
   inputs.append({'path':str(p.relative_to(repo)),'sha256':sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size})
 runtime_files=[]
 for p in sorted(out.iterdir()):
  if p.suffix in ['.png','.aseprite','.json']:runtime_files.append({'path':str(p.relative_to(repo)),'sha256':sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size})
 export={'version':1,'status':'art_ready_for_runtime_validation','actor_frames':60,'effect_frames':16,'actor_clips':8,'effect_clips':2,'inputs':inputs,'outputs':runtime_files,'actor_frame_size':[768,640],'effect_frame_size':[512,512],'body_height_px':224,'actor_anchor_px':[384,608],'palette_policy':'Actor colors mapped by Aseprite indexed conversion to full corresponding legacy runtime palette; FX individually <=64 entries.','qa':str(report_path.relative_to(repo)),'legacy_assets_unchanged':True,'aesthetic_status':'not_inferred_from_technical_pass'}
 (base/'export-manifest.json').write_text(json.dumps(export,ensure_ascii=False,indent=2)+'\n')

"""Read-only validation of the production PNG/ASE pixels and approved inputs.
Only JSON status/manifest records are written; image pixels are never edited.
"""
from pathlib import Path
from hashlib import sha256
from PIL import Image
import json,struct
repo=Path(__file__).resolve().parents[3]
base=repo/'design/jia-lord-combat-20261105'
out=repo/'assets/players/jia-campaign'
measurements=json.loads((base/'source/measurements.json').read_text())
manifest=json.loads((out/'manifest.json').read_text())
assert manifest['body_height_px']==80 and manifest['frame_size']==[256,256] and manifest['anchor_px']==manifest['foot_anchor']==[128,236]
assert manifest['portrait']=='campaign-head.png' and manifest['faces_left'] is False
assert len(measurements['poses'])==48 and len({(p['source'],tuple(p['components'][0]['bbox'])) for p in measurements['poses']})==48
for source in measurements['sources'].values():
 p=base/'source'/source['path'];assert sha256(p.read_bytes()).hexdigest()==source['sha256'];assert list(Image.open(p).size)==source['size']
assert measurements['sources']['dao']['standing_body_height']==210 and measurements['sources']['spear']['standing_body_height']==211
colors=set();unique=[];records=[]
def ase_header(path,frames,size):
 data=path.read_bytes();size_bytes,magic,count,w,h,depth=struct.unpack_from('<IHHHHH',data)
 assert size_bytes==len(data) and magic==0xA5E0 and count==frames and (w,h)==size,(path,count,w,h)
 return {'path':str(path.relative_to(repo)),'frames':count,'size':[w,h],'color_depth':depth,'sha256':sha256(data).hexdigest()}
asedata=[ase_header(out/'actor.aseprite',48,(256,256))]
for weapon in ['dao','spear']:
 for action,count in [('idle',4),('run',8),('attack',4),('sweep',4),('break',4)]:
  name=weapon+'-'+action;clip=manifest['clips'][name];path=out/(name+'.png');image=Image.open(path)
  assert image.mode=='RGBA' and image.size==(count*256,256)
  assert clip['frames']==count and clip['frame_size']==[256,256]
  assert clip['contact_frame']==(0 if action in ['idle','run'] else 1)
  assert set(image.getchannel('A').getdata())=={0,255}
  colors.update(pixel[:3] for pixel in image.getdata() if pixel[3])
  frame_records=[]
  for index,pose_id in enumerate(measurements['clips'][name]['poses']):
   frame=image.crop((index*256,0,(index+1)*256,256));bbox=frame.getbbox();assert bbox and 0<bbox[0]<bbox[2]<256 and 0<bbox[1]<bbox[3]<256
   digest=sha256(frame.tobytes()).hexdigest();unique.append(digest)
   pose=next(p for p in measurements['poses'] if p['id']==pose_id)
   assert bbox[3]<=236,(name,index,bbox)
   foot_lift=236-bbox[3]
   if action!='run':assert foot_lift<=1,(name,index,foot_lift)
   frame_records.append({'frame':index,'source_pose':pose_id,'bbox':list(bbox),'rgba_sha256':digest,'foot_anchor':[128,236],'visible_foot_lift_px':foot_lift,'source_hip_x':pose['hip_x_source'],'source_ground_y':pose['ground_source_y'],'source_visible_foot_y':pose['visible_foot_y']})
  records.append({'clip':name,'size':list(image.size),'frames':count,'fps':clip['fps'],'contact_frame':clip['contact_frame'],'sha256':sha256(path.read_bytes()).hexdigest(),'frame_records':frame_records})
  asedata.append(ase_header(out/(name+'.aseprite'),count,(256,256)))
assert len(unique)==len(set(unique))==48
assert len(colors)<=64
head=Image.open(out/'campaign-head.png');assert head.mode=='RGBA' and head.size==(128,128) and set(head.getchannel('A').getdata())=={0,255}
head_colors={p[:3] for p in head.getdata() if p[3]};assert len(head_colors)<=64
asedata.append(ase_header(out/'campaign-head.aseprite',1,(128,128)))
report={'status':'pass','generator':'built-in ImageGen; extraction/registration/nearest-neighbor/quantization by Aseprite; Pillow read-only checks',
 'independent_source_poses':48,'unique_runtime_frames':48,'actor_shared_opaque_colors':len(colors),'portrait_opaque_colors':len(head_colors),
 'frame_size':[256,256],'foot_anchor':[128,236],'standing_body_height_px':80,'world_scale':.9,'world_body_height':72,
 'source_body_calibration':{'dao':210,'spear':211},'clip_count':10,'clips':records,'editable_files':asedata,
 'agent_visual_review':'Both original24-pose sources, binary-alpha source review sheets, enlarged standing calibration crops, all48 quantized runtime contact poses and the independently generated portrait inspected. Approved campaign-v2 grand armor, double plumes, Jia grin/red tie/reed knot, complete cape and forward weapon grip retained. Active clip contact frame1 reviewed. Sweep torso turn and break lunge are separately drawn actions.',
 'registration_notes':'Fixed scale per weapon source from actual helmet-crown-to-boot reference, excluding plume/cape/weapon. Manual hip x and source row ground planes; natural running flight leaves visible boots0..7px above stable foot origin. No per-frame height stretching.',
 'limitations':['Technical and source/identity review only; runtime full playback, stage fit and user aesthetic review remain separate owner checks.','Small low-alpha background RGB in raw generated sheets is retained in original source and discarded only by Aseprite binary-alpha export.','Portrait has a separate <=64 color palette and native128px editable working size.']}
(base/'qa/art-qa.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
manifest['status']='audited';manifest['qa']='res://design/jia-lord-combat-20261105/qa/art-qa.json';manifest['independent_actor_poses']=48
(out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
inputs=[]
for path in sorted((base/'source').rglob('*'))+sorted((base/'prompts').rglob('*')):
 if path.is_file() and path.suffix in ['.png','.json','.txt','.py','.lua']:
  inputs.append({'path':str(path.relative_to(repo)),'sha256':sha256(path.read_bytes()).hexdigest(),'bytes':path.stat().st_size})
for path in [base/'jia-lord-campaign-v2.png',repo/'scripts/tools/import_jia_campaign_art.lua',base/'qa/audit_campaign_art.py',base/'qa/export_contact_sheet.lua']:
 inputs.append({'path':str(path.relative_to(repo)),'sha256':sha256(path.read_bytes()).hexdigest(),'bytes':path.stat().st_size})
outputs=[]
for path in sorted(out.iterdir()):
 if path.suffix in ['.png','.aseprite'] or path.name=='manifest.json':
  r={'path':str(path.relative_to(repo)),'sha256':sha256(path.read_bytes()).hexdigest(),'bytes':path.stat().st_size}
  if path.suffix=='.png':r['size']=list(Image.open(path).size)
  outputs.append(r)
exports={'version':1,'identity':'JIA approved campaign-v2 only','status':'art_export_audited_ready_for_runtime','user_animation_aesthetic_status':'not_claimed','runtime_acceptance':'separate runtime/validation owners',
 'approved_identity_master':'design/jia-lord-combat-20261105/jia-lord-campaign-v2.png','unapproved_ready_v1_used':False,'rejected_campaign_v1_used':False,
 'process':'Built-in ImageGen pixel model, two independent24-pose action sheets, independently generated128 portrait. Aseprite source-component extraction/fixed source scale/shared48-pose <=64 color palette/binary alpha/nearest neighbor and editable exports.',
 'actor_poses':48,'clip_frames':{n:v['frames'] for n,v in manifest['clips'].items()},'actor_shared_opaque_colors':len(colors),'portrait_opaque_colors':len(head_colors),
 'source_versions':{'pixel-model-v1':'selected, art owner and root reviewed','dao-actions-v1':'selected24 independent poses','spear-actions-v1':'selected24 independent poses','campaign-head-v1':'selected independent bust'},
 'rejected_generated_action_versions':[],'vfx':'Existing Jia slash/thrust/sweep VFX reused by runtime, no new persistent effects.',
 'body_scale':'80px helmet-crown to boot reference; excludes feathers/weapons/cape. World .9=72. Run source ground planes retain natural airborne phases.',
 'inputs':inputs,'outputs':outputs,'qa_outputs':[{'path':str(path.relative_to(repo)),'sha256':sha256(path.read_bytes()).hexdigest(),'bytes':path.stat().st_size} for path in sorted((base/'qa').iterdir()) if path.is_file()],'qa':'design/jia-lord-combat-20261105/qa/art-qa.json','static_contact_previews':['design/jia-lord-combat-20261105/qa/dao-runtime-contact-sheet.png','design/jia-lord-combat-20261105/qa/spear-runtime-contact-sheet.png']}
(base/'art-export-manifest.json').write_text(json.dumps(exports,ensure_ascii=False,indent=2)+'\n')
print('JIA_CAMPAIGN_ART_QA_PASS actor_frames=48 unique=48 shared_opaque_colors='+str(len(colors))+' portrait_colors='+str(len(head_colors))+' clips=10 editable=12')

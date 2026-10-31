"""Persist reviewed pose/component choices. Never changes image pixels."""
from pathlib import Path
import json
from hashlib import sha256
from PIL import Image
from source_components import inventory

ROOT = Path('design/boss-forms-20261029/characters')
# Reviewed head/cap-to-boot standing heights; weapons/plumes are excluded.
# Per-pose foot/horizontal pelvis anchors were measured against each actual body.
REVIEW = {
 'B18_human': (230, [(165,276),(530,279),(895,278),(1245,277),(215,548),(522,549),(914,544),(1281,552),(185,820),(520,815),(904,833),(1246,832),(157,1083),(540,1088),(890,1102),(1225,1101)], [480,220,300,350]),
 'B17_human': (236, [(235,281),(585,281),(935,281),(1289,281),(258,501),(592,504),(950,509),(1330,510),(207,758),(532,755),(937,755),(1320,758),(202,995),(566,993),(914,991),(1272,997)], [360,180,300,360]),
 'B15_human': (264, [(190,308),(516,308),(843,307),(1168,307),(180,592),(512,593),(852,595),(1160,593),(170,895),(478,896),(810,897),(1183,900),(172,1165),(518,1156),(812,1154),(1120,1164)], [380,150,310,360]),
 'B16_human': (224, [(147,265),(516,265),(903,265),(1309,265),(214,506),(594,502),(975,503),(1375,502),(166,756),(574,752),(960,765),(1339,764),(173,1006),(556,1004),(963,1005),(1350,1001)], [270,240,320,380]),
 'M03_human': (255, [(201,277),(576,276),(960,277),(1343,277),(213,508),(595,511),(978,512),(1361,515),(176,753),(559,748),(984,753),(1355,760),(190,1002),(559,1002),(940,1001),(1320,1005)], [440,50,330,360]),
 'M04_human': (338, [(169,349),(449,349),(735,349),(1028,349),(155,641),(450,648),(744,647),(1048,653),(157,1002),(451,1002),(743,1002),(1060,1002),(177,1304),(446,1308),(742,1308),(1005,1288)], [430,50,330,360]),
}
ROUTES = {
 'B18_human': {'halberd_sweep':'attack','halberd_charge':'special','halberd_fall':'special','halberd_finish':'attack','slam':'attack','charge':'special','marker':'special'},
 'B17_human': {'general_lunge':'attack','general_cut':'attack','human_formation':'special','charge':'attack','slam':'attack','collaboration':'special'},
 'B16_human': {'rider_lance':'attack','rider_cleave':'special','rider_return':'attack','charge':'attack','slam':'special'},
 'B15_human': {'hunter_aim':'attack','hunter_volley':'attack','hunter_reposition':'special','shot':'attack','fan':'attack','charge':'special'},
 'M03_human': {'swipe':'attack','slam':'attack','charge':'special','command':'special'},
 'M04_human': {'pulse':'attack','shot':'attack','command':'special','collaboration':'special'},
}

for identity,(body_height,anchors,head_rect) in REVIEW.items():
 folder=ROOT/identity
 data=inventory(folder/'source/actions-v1.png')
 groups=data['large_bodies_with_nearest_components']
 assert len(groups)==16, (identity,len(groups))
 # Components are matched by actual bbox centers to reviewed pose rows, then x.
 # No source region is cropped: selected 4-connected pixels are copied by Aseprite.
 row_height=data['size'][1]/4
 groups.sort(key=lambda g:(min(3,int(((g['body']['bbox'][1]+g['body']['bbox'][3])/2)/row_height)),g['body']['bbox'][0]))
 poses=[]
 for index,group in enumerate(groups):
  parts=[group['body']]+[p for p in group['components'] if p['area']>=3]
  # The flying arrow is a projectile, not a part of the archer's recovery body.
  if identity=='B15_human': parts=[p for p in parts if p['bbox']!=[963,687,1075,701]]
  poses.append({'id':f'p{index+1:02}','source':'combat','anchor_source':list(anchors[index]),'components':parts,'body_bbox':group['body']['bbox']})
 master='master-v2.png' if identity=='B18_human' else 'master-v1.png'
 def record(name):
  path=folder/'source'/name
  with Image.open(path) as im: size=list(im.size)
  return {'path':'source/'+name,'size':size,'sha256':sha256(path.read_bytes()).hexdigest()}
 combat=record('actions-v1.png'); combat['standing_body_height']=body_height
 clip=lambda ids,fps=10,contact=1:{'poses':[f'p{i:02}' for i in ids],'fps':fps,'contact_frame':contact,'windup_frame':0}
 # Row2 pose4 touches a source edge in Lu Bu/Cao Chun: exclude it, do not hide a cut by padding.
 move=[5,6,7] if identity in ['B18_human','B16_human'] else [5,6,7,8]
 clips={'idle':clip([1,2,3,4],6),'move':clip(move,10),'attack':clip([9,10,11,12],10),'special':clip([9,11,12],9),'hit':clip([13,14],10,0),'death':clip([15,16],7,0)}
 m={'version':1,'id':identity,'review_status':'accepted_for_export','review_notes':'Agent source/identity/anatomy review and component/foot calibration completed; user aesthetic acceptance remains pending. Parts copied by alpha connectivity; small isolated alpha specks <3px omitted. Body scale fixed across poses, no posture height stretching.','canvas':{'size':[640,512],'anchor':[288,480],'body_height_px':224},'faces_left':False,'sources':{'combat':combat},'portrait':record(master),'poses':poses,'clips':clips,'action_clips':ROUTES[identity],'head_rect_px':head_rect}
 (folder/'measurements.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n')
 print(identity,'reviewed',[(p['id'],p['body_bbox']) for p in poses])

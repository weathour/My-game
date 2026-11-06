"""Build reviewed Aseprite measurements from actual 4-connected alpha parts.
No image mutation. Manual hip x/ground planes are distinct from feathers/weapon bounds.
"""
from pathlib import Path
from hashlib import sha256
import json
root=Path(__file__).resolve().parent
specs={
'dao':{'boxes':[[24,16,218,251],[283,16,472,251],[534,16,729,251],[794,16,983,251],[20,270,225,499],[275,270,474,499],[521,269,730,499],[781,275,988,499],[14,529,217,755],[263,532,471,755],[518,530,736,751],[780,533,997,741],[14,782,216,1010],[262,787,491,1010],[512,790,768,1010],[787,786,989,1010],[12,1053,217,1265],[257,1043,511,1266],[517,1043,762,1265],[781,1039,989,1265],[13,1298,193,1523],[254,1299,509,1523],[506,1311,791,1523],[788,1296,996,1523]],'hips':[134,392,648,906,137,395,652,910,135,391,652,910,130,393,646,903,126,389,646,903,124,384,639,905],'ground':[251]*4+[500]*4+[755]*4+[1010]*4+[1266]*4+[1523]*4,'body_height':210,'standing_helmet_to_boot_y':[41,251]},
'spear':{'boxes':[[9,18,248,255],[267,18,503,255],[521,17,760,255],[777,19,1017,255],[9,285,249,500],[262,288,504,501],[519,285,762,498],[770,290,1018,491],[9,530,250,743],[268,530,506,745],[522,530,764,746],[773,533,1019,727],[13,789,226,994],[263,792,501,994],[513,794,779,994],[785,788,1005,994],[14,1045,237,1246],[261,1045,499,1246],[514,1041,765,1246],[776,1040,1015,1246],[9,1311,230,1515],[245,1313,495,1514],[484,1324,769,1513],[774,1308,1010,1515]],'hips':[125,382,638,894,130,388,647,903,131,390,650,906,122,382,638,891,118,379,636,891,118,372,627,891],'ground':[255]*4+[501]*4+[746]*4+[994]*4+[1246]*4+[1515]*4,'body_height':211,'standing_helmet_to_boot_y':[44,255]}}
m={'version':1,'id':'JIA_CAMPAIGN','review_status':'accepted_for_export','review_notes':'Approved campaign-v2 only. Root and art owner inspected pixel model and both24-pose action sheets. Warlord double crimson plumes, beast-head golden shoulder/chest armor, layered scales/tassets, gold-bordered crimson cape, adult Jia grin/stubble, red ribbon and reed knot retained. All48 separately generated poses use actual alpha-connected regions, not grid slices; detached tiny alpha specks omitted. Straight spearheads point right at contact. All active clips have contact frame1. Uniform source body calibration excludes plumes, cape and weapons. Run row ground planes retain small natural airborne phases; no per-frame body stretching. Technical export review is separate from user animation-aesthetic acceptance.','canvas':{'size':[256,256],'anchor':[128,236],'body_height_px':80},'faces_left':False,'sources':{},'poses':[],'clips':{}}
for weapon,spec in specs.items():
 a=json.loads((root/f'{weapon}-actions-v1-components.json').read_text());parts={tuple(p['bbox']):p for p in a['components']}
 path=root/f'{weapon}-actions-v1.png'
 m['sources'][weapon]={'path':path.name,'sha256':sha256(path.read_bytes()).hexdigest(),'size':a['size'],'standing_body_height':spec['body_height'],'standing_body_reference':{'pose':weapon+'-p01','helmet_crown_y':spec['standing_helmet_to_boot_y'][0],'boot_ground_y':spec['standing_helmet_to_boot_y'][1],'excludes':['long red feathers','cape extent','weapon extent']}}
 for i,(box,hip,ground) in enumerate(zip(spec['boxes'],spec['hips'],spec['ground']),1):
  m['poses'].append({'id':f'{weapon}-p{i:02}','source':weapon,'components':[parts[tuple(box)]],'anchor_source':[hip,ground],'hip_x_source':hip,'visible_foot_y':box[3],'ground_source_y':ground,'registration_note':'Manual belt/hip x; source boot row ground plane. Airborne run boot pixels may sit above ground.'})
 for clip,start,count,fps,contact in [('idle',1,4,5,0),('run',5,8,11,0),('attack',13,4,16,1),('sweep',17,4,12,1),('break',21,4,14,1)]:
  m['clips'][weapon+'-'+clip]={'poses':[f'{weapon}-p{i:02}' for i in range(start,start+count)],'fps':fps,'windup_frame':0,'contact_frame':contact}
(root/'measurements.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n')
(root/'pose-selection.json').write_text(json.dumps(specs,ensure_ascii=False,indent=2)+'\n')
print('CAMPAIGN_MEASUREMENTS_READY48 source_body_dao210 spear211')

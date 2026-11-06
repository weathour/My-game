"""Reviewed source-component registration; never edits image pixels.
Actor pose order follows original sequences, not inferred grid crops.
FX whole connected parts are assigned to the eight reviewed effect clusters.
"""
from pathlib import Path
import json
base=Path(__file__).resolve().parent
specs={
'B17-order_gaoshun':{'boxes':[[108,126,432,495],[574,157,965,496],[1061,12,1455,495],[22,628,542,974],[554,637,1085,977],[1143,597,1476,975]],'hips':[270,774,1268,266,756,1308],'grounds':[495,496,495,974,977,975],'body_top':142,'body_bottom':495,'body':353},
'B17-order_chengong':{'boxes':[[73,56,402,462],[583,12,925,461],[1086,9,1511,462],[6,601,480,976],[508,568,1013,976],[1117,496,1482,975]],'hips':[249,754,1269,242,758,1295],'grounds':[462,461,462,976,976,975],'body_top':84,'body_bottom':462,'body':378},
'B17_human-order_gaoshun':{'boxes':[[35,50,415,497],[572,124,948,497],[1087,13,1483,497],[12,636,538,977],[524,679,1049,977],[1077,540,1493,977]],'hips':[248,783,1288,251,758,1293],'grounds':[497,497,497,977,977,977],'body_top':132,'body_bottom':497,'body':365},
'B17_human-order_chengong':{'boxes':[[22,40,422,463],[557,14,918,463],[1074,13,1494,463],[20,514,463,976],[500,516,988,976],[1072,514,1455,976]],'hips':[217,748,1265,221,749,1272],'grounds':[463,463,463,976,976,976],'body_top':103,'body_bottom':463,'body':360},
'M03_WAR-gaoshun':{'boxes':[[70,9,309,399],[511,51,800,398],[901,66,1247,398],[1353,150,1755,398],[19,564,467,836],[451,580,908,835],[920,561,1312,838],[1380,452,1706,840]],'hips':[195,651,1093,1518,248,695,1129,1536],'grounds':[399,398,398,398,836,835,838,840],'body_top':87,'body_bottom':399,'body':312},
'M03_human-gaoshun':{'boxes':[[59,12,357,427],[498,11,803,427],[898,50,1258,427],[1346,129,1762,427],[16,553,451,849],[450,567,946,842],[932,538,1313,844],[1352,493,1679,849]],'hips':[210,658,1094,1515,239,700,1137,1548],'grounds':[427,427,427,427,849,842,844,849],'body_top':76,'body_bottom':427,'body':351},
'M04_WAR-chengong':{'boxes':[[57,20,307,344],[386,21,662,348],[745,10,1063,347],[9,386,342,709],[366,364,666,714],[680,382,1079,712],[10,747,341,1061],[359,746,690,1070],[715,741,1069,1066],[20,1101,325,1435]],'hips':[190,531,895,181,528,883,177,532,894,178],'grounds':[344,348,347,709,714,712,1061,1070,1066,1435],'body_top':20,'body_bottom':326,'body':306,'core_window':[130,20,252,326],'note':'Floating war form: crown y20 to main body robe hem y326 defines306px core, excluding outer scroll rollers/ribbons. Lowest orbiting scroll y344 in pose0 is virtual ground; giant scroll is not the body ruler.'},
'M04_human-chengong':{'boxes':[[78,13,236,338],[438,13,620,339],[788,13,1011,339],[21,376,323,710],[380,354,648,710],[735,388,1058,712],[28,766,325,1067],[380,755,698,1068],[747,743,1012,1068],[75,1103,239,1434]],'hips':[162,520,882,174,527,882,176,533,884,163],'grounds':[338,339,339,710,710,712,1067,1068,1068,1434],'body_top':13,'body_bottom':338,'body':325}}
contract=json.loads((base/'contract.json').read_text())
contract['clips']['FX:gaoshun_entry'].update({'frame_size':[512,512],'anchor_px':[256,480],'world_size':[260,260],'release_frame':4,'contact_frame':4})
contract['clips']['FX:chengong_seal'].update({'frame_size':[512,512],'anchor_px':[256,256],'world_size':[260,260],'release_frame':4,'contact_frame':5})
(base/'contract.json').write_text(json.dumps(contract,ensure_ascii=False,indent=2)+'\n')
m={'version':1,'review_status':'accepted_for_export','review_notes':'All10 root ImageGen sources viewed by root and art owner.60 genuinely new actor poses plus16 independently drawn FX states. Whole source alpha components selected with exact bbox/area, never blind grid crops. Tiny detached sub3px alpha specks omitted. Colors at alpha<128 are preserved only in raw source and cleared by Aseprite export. Fixed body ruler for every source, manual hip x/ground registration; war Chen uses crown-to-own-robe core and virtual scroll ground explicitly.','sources':{},'poses':[],'clips':{}}
for key,spec in specs.items():
 stem=key+'-v1';a=json.loads((base/'qa'/(stem+'-components.json')).read_text());parts={tuple(p['bbox']):p for p in a['components']}
 visual,role=key.split('-',1);count=contract['clips'][key]['frames'];assert len(spec['boxes'])==count
 reference={'reference_pose':0,'body_top_y':spec['body_top'],'body_bottom_y':spec['body_bottom'],'core_height_source':spec['body'],'virtual_ground_y':spec['grounds'][0],'hip_x':spec['hips'][0],'excludes':['weapon','flowing banners/cape','external orbiting scrolls'],'ruler_note':spec.get('note','Neutral cap/hair/fixed armor top to boot/claw sole; weapon and flowing cloth excluded.')}
 reference['measurement_window_xyxy']=spec.get('core_window',[spec['hips'][0]-110,spec['body_top'],spec['hips'][0]+110,spec['body_bottom']])
 m['sources'][stem]={'path':'source/'+stem+'.png','sha256':a['sha256'],'size':a['size'],'standing_body_height':spec['body'],'body_calibration':reference}
 ids=[]
 for index,(box,hip,ground) in enumerate(zip(spec['boxes'],spec['hips'],spec['grounds'])):
  pid=key+':'+str(index);ids.append(pid)
  m['poses'].append({'id':pid,'source':stem,'components':[parts[tuple(box)]],'anchor_source':[hip,ground],'hip_x_source':hip,'ground_source_y':ground,'registration_note':'Manual pelvis x and visible boot/claw ground; floating Chen uses lowest scroll virtual ground.'})
 m['clips'][key]={'file':key+'.png','frame_size':[768,640],'frames':count,'fps':12,'anchor_px':[384,608],'body_height_px':224,'faces_left':False,'windup_frame':0,'release_frame':contract['clips'][key]['release_frame'],'contact_frame':contract['clips'][key]['contact_frame'],'visual_id':visual,'role':role,'kind':'actor','type':'actor','poses':ids}
for role in ['gaoshun_entry','chengong_seal']:
 stem='fx-'+role+'-v1';a=json.loads((base/'qa'/(stem+'-components.json')).read_text());key='FX:'+role;groups=[[] for _ in range(8)]
 # These are whole-component ownership regions of the reviewed source clusters.
 # No component image is sliced at a nominal grid boundary, including all decay debris.
 for part in a['components']:
  b=part['bbox'];cx=(b[0]+b[2])/2;cy=(b[1]+b[3])/2;col=min(3,int(cx/(a['size'][0]/4)));row=0 if cy<a['size'][1]/2 else 1
  groups[row*4+col].append(part)
 assert all(groups)
 m['sources'][stem]={'path':'source/'+stem+'.png','sha256':a['sha256'],'size':a['size'],'fixed_scale':1.05,'effect_calibration':'One fixed1.05 scale for all8 states; release dimensions do not normalize each smaller precursor/decay state. Entire reviewed connected fragments retained; alpha<128 fringes and sub3px noise are excluded.'}
 ids=[]
 for index,parts in enumerate(groups):
  pid=key+':'+str(index);ids.append(pid);col=index%4;row=index//4
  if role=='gaoshun_entry':pivot=[[230,665,1110,1550][col],420 if row==0 else 853]
  else:pivot=[[222,665,1110,1552][col],222 if row==0 else 665]
  m['poses'].append({'id':pid,'source':stem,'components':parts,'anchor_source':pivot,'registration_note':'Whole components grouped by reviewed effect cluster; all real fracture/decay fragments retained, not just largest part.'})
 c=contract['clips'][key]
 m['clips'][key]={'file':'fx-'+role+'.png','frame_size':[512,512],'frames':8,'fps':12,'anchor_px':c['anchor_px'],'world_size':c['world_size'],'body_height_px':0,'faces_left':False,'windup_frame':0,'release_frame':c['release_frame'],'contact_frame':c['contact_frame'],'visual_id':'FX','role':role,'kind':'effect','type':'effect','poses':ids}
(base/'measurements.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n')
(base/'qa/manual-actor-selection.json').write_text(json.dumps(specs,ensure_ascii=False,indent=2)+'\n')
print('FULL_MEASUREMENTS_READY actor60 effect16 source10')

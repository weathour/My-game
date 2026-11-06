"""Read-only pixel inspection of actual Godot viewport PNGs; never draws images."""
from pathlib import Path
from hashlib import sha256
from PIL import Image
import json,re
root=Path(__file__).resolve().parent
qa=json.loads((root/'runtime-art-qa.json').read_text())
ids=list(qa['characters'])
# SceneTree JSON dictionary order is creation order, matching authoritative C.IDS.
expected_ids=['JIA']+[f'M{i:02}' for i in range(1,9)]+[f'F{i:02}' for i in range(1,12)]+[f'N{i:02}' for i in range(1,19)]
assert set(ids)==set(expected_ids) and len(ids)==38
captures=[];samples=0
for name in qa['captures']:
 p=root/name;image=Image.open(p).convert('RGBA')
 match=re.fullmatch(r'roster-(960|1280|1920)-(left|right)-page(\d+)\.png',name);assert match
 width=int(match[1]);page=int(match[3])-1;scale=width/960
 assert image.size==(width,width*9//16)
 points=[]
 for row in range(3):
  index=page*3+row
  if index>=38:break
  for col in range(4):
   x=int((223+col*194)*scale);y=int((184+row*150-36)*scale)
   rgba=image.getpixel((x,y));assert rgba[:3]==(255,41,74),(name,expected_ids[index],col,(x,y),rgba)
   points.append({'id':expected_ids[index],'action':['idle','move','basic','manual'][col],'center_pixel':[x,y],'rgba':list(rgba)})
   samples+=1
 captures.append({'file':name,'size':list(image.size),'sha256':sha256(p.read_bytes()).hexdigest(),'hurtbox_center_samples':points})
assert len(captures)==78 and samples==912
result={'status':'pass','captures':captures,'capture_count':78,'hurtbox_center_samples':samples,'all_actual_center_pixels':[255,41,74,255],
 'reference_center_world':[0,-36],'reference_radius_world':4,'sizes':[[960,540],[1280,720],[1920,1080]],'directions':['left','right'],
 'source':'Actual native Godot SubViewport PNGs. Marker directly calls battle_canvas._draw_controlled_hurtbox with shared player_hurtbox.center.',
 'runtime_qa_sha256':sha256((root/'runtime-art-qa.json').read_bytes()).hexdigest()}
(root/'capture-pixel-qa.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print('ROSTER_CAPTURE_PIXEL_QA_PASS captures=78 actual_red_center_pixels=912')

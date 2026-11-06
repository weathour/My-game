from pathlib import Path
from PIL import Image
import numpy as np,json,sys
from scipy.ndimage import label,find_objects
for character in [Path(__file__).resolve().parent.name]:
 root=Path('design/skill-presentation-20261105/characters')/character
 im=Image.open(root/'source/combat-bundle-v1.png').convert('RGBA')
 a=np.asarray(im)[:,:,3]>=128
 labels,n=label(a)
 objs=find_objects(labels)
 parts=[]
 for i,s in enumerate(objs,1):
  if s is None:continue
  count=int(np.count_nonzero(labels[s]==i))
  if count>=3:
   y,x=s;parts.append({'bbox':[x.start,y.start,x.stop,y.stop],'area':count})
 print(character,im.size,'total',n,'parts',len(parts))
 print(json.dumps(sorted([p for p in parts if p['area']>=300],key=lambda p:(p['bbox'][1],p['bbox'][0])),indent=1))
 (root/'source/component-analysis.json').write_text(json.dumps({'threshold':128,'connectivity':4,'size':list(im.size),'components':parts},indent=2)+'\n')

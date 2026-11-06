"""Read-only alpha component measurements; never writes image pixels."""
from pathlib import Path
from PIL import Image
from hashlib import sha256
import numpy as np,json
from scipy.ndimage import label,find_objects
root=Path(__file__).resolve().parent
for name in ['dao-actions-v1','spear-actions-v1']:
 path=root/(name+'.png');image=Image.open(path).convert('RGBA');labels,n=label(np.asarray(image)[:,:,3]>=128);parts=[]
 for index,region in enumerate(find_objects(labels),1):
  if region is None:continue
  area=int(np.count_nonzero(labels[region]==index))
  if area>=3:
   y,x=region;parts.append({'bbox':[x.start,y.start,x.stop,y.stop],'area':area})
 record={'file':path.name,'sha256':sha256(path.read_bytes()).hexdigest(),'size':list(image.size),'threshold':128,'connectivity':4,'components':parts}
 (root/(name+'-components.json')).write_text(json.dumps(record,indent=2)+'\n')
 print(name,'major',json.dumps([p for p in parts if p['area']>1000]))

"""Read-only RGBA connectivity analysis; writes only JSON measurements."""
from pathlib import Path
from PIL import Image
from scipy.ndimage import label,find_objects
from hashlib import sha256
import numpy as np,json,sys
base=Path(__file__).resolve().parent
for argument in sys.argv[1:]:
 path=Path(argument);im=Image.open(path).convert('RGBA');labels,n=label(np.asarray(im)[:,:,3]>=128);parts=[]
 for index,region in enumerate(find_objects(labels),1):
  if region is None:continue
  area=int(np.count_nonzero(labels[region]==index))
  if area>=3:
   y,x=region;parts.append({'bbox':[x.start,y.start,x.stop,y.stop],'area':area})
 record={'path':str(path),'sha256':sha256(path.read_bytes()).hexdigest(),'size':list(im.size),'threshold':128,'connectivity':4,'components':parts}
 target=base/'qa'/(path.stem+'-components.json');target.write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
 print(path.name,'components',len(parts),'major',json.dumps([p for p in parts if p['area']>300]))

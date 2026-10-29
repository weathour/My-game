"""Read-only FX raster audit; writes only provenance/status JSON, never images."""
from pathlib import Path
from hashlib import sha256
import json
import struct
from PIL import Image
import numpy as np
from scipy.ndimage import label, find_objects

ROOT = Path('design/baimen-enemies-20261028/effects')

def digest(path): return sha256(path.read_bytes()).hexdigest()

def run():
    results=[]
    for folder in sorted(ROOT.iterdir()):
        if not (folder/'measurements.json').is_file(): continue
        m=json.loads((folder/'measurements.json').read_text())
        assert m['review_status']=='accepted_for_export'
        source=folder/m['source']['path']
        assert digest(source)==m['source']['sha256']
        assert (folder/'prompt.txt').is_file()
        with Image.open(source) as image:
            assert image.mode=='RGBA' and list(image.size)==m['source']['size']
            labels,_=label(np.asarray(image.getchannel('A'))>=128)
            sizes=np.bincount(labels.ravel()); actual={}
            for index,part in enumerate(find_objects(labels),1):
                if part is not None:
                    y,x=part;actual[(x.start,y.start,x.stop,y.stop)]=int(sizes[index])
            selected={}
            for frame in m['frames']:
                for component in frame['components']:
                    bounds=tuple(component['bbox'])
                    assert bounds not in selected, (m['id'],'component counted twice')
                    selected[bounds]=component['area']
            assert selected==actual, (m['id'],'component changed/lost/split')
        runtime=Path('assets/enemies/baimen/fx')/m['id']
        width,height=m['frame_size'];count=len(m['frames'])
        outputs=[]
        with Image.open(runtime/'effect.png') as image:
            assert image.mode=='RGBA' and image.size==(width*count,height)
            assert set(image.getchannel('A').getdata())=={0,255}
            colors={pixel[:3] for pixel in image.getdata() if pixel[3]}
            assert len(colors)<=64
            bounds=[];hashes=[]
            for index in range(count):
                frame=image.crop((index*width,0,(index+1)*width,height))
                used=frame.getchannel('A').getbbox();assert used
                assert used[0]>0 and used[1]>0 and used[2]<width and used[3]<height, (m['id'],'effect touches crop')
                bounds.append(used);hashes.append(sha256(frame.tobytes()).hexdigest())
            assert len(set(hashes))==count
            outputs.append({'path':str(runtime/'effect.png'),'sha256':digest(runtime/'effect.png'),'size':list(image.size),'frames':count,'colors':len(colors),'frame_alpha_bounds':bounds,'frame_pixel_sha256':hashes})
        data=(runtime/'effect.aseprite').read_bytes()
        magic,n,w,h=struct.unpack_from('<4H',data,4)
        assert magic==0xA5E0 and (n,w,h)==(count,width,height)
        outputs.append({'path':str(runtime/'effect.aseprite'),'sha256':digest(runtime/'effect.aseprite'),'frames':n,'size':[w,h]})
        record={'id':m['id'],'generator':'built-in ImageGen; Aseprite measured-region extraction/registration and shared64-color quantization','source':str(source),'source_sha256':digest(source),'prompt':str(folder/'prompt.txt'),'prompt_sha256':digest(folder/'prompt.txt'),'measurements':str(folder/'measurements.json'),'measurements_sha256':digest(folder/'measurements.json'),'outputs':outputs}
        (folder/'export-manifest.json').write_text(json.dumps(record,indent=2)+'\n')
        metadata_path=runtime/'manifest.json';metadata=json.loads(metadata_path.read_text());metadata['status']='final';metadata_path.write_text(json.dumps(metadata,indent=2)+'\n')
        results.append(record)
        print(f"BAIMEN_FX_AUDIT_OK {m['id']} frames={count} colors={len(colors)}")
    assert len(results)==8
    (ROOT/'manifest.json').write_text(json.dumps({'version':1,'source_count':8,'frame_count':sum(len(r['outputs'][0]['frame_pixel_sha256']) for r in results),'effects':results,'reuse':{'slash':'assets/players/jia/vfx-slash.png','thrust':'assets/players/jia/vfx-thrust.png','sweep':'assets/players/jia/vfx-sweep.png','provenance':'design/jia-combat-20261027/manifest.json'},'mechanic_explosion':'audited candidate, not required by current ghost visual grammar; not instantiated'},indent=2)+'\n')

if __name__=='__main__': run()

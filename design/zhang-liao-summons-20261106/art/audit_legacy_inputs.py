"""Read-only audit of existing identity, geometry and palettes. No image edits."""
from pathlib import Path
from PIL import Image
from hashlib import sha256
from collections import Counter
import json
repo=Path(__file__).resolve().parents[3];base=Path(__file__).resolve().parent
identities=['B17_human','B17','M03_human','M03_WAR','M04_human','M04_WAR'];records=[];palettes={}
for visual in identities:
 folder=repo/'assets/enemies/baimen'/visual
 m=json.loads((folder/'manifest.json').read_text());counts=Counter();files=[]
 for clip in m['clips'].values():
  path=folder/clip['file'];im=Image.open(path).convert('RGBA');counts.update(p[:3] for p in im.getdata() if p[3]>=128)
  files.append({'file':str(path.relative_to(repo)),'sha256':sha256(path.read_bytes()).hexdigest(),'size':list(im.size),'frames':clip['frames']})
 old=(repo/'design/boss-forms-20261029/characters'/visual) if visual.endswith('_human') else (repo/'design/baimen-enemies-20261028/characters'/visual)
 measure=json.loads((old/'measurements.json').read_text())
 parent=old;portrait=parent/measure['portrait']['path']
 records.append({'visual_id':visual,'legacy_geometry':{'body_height_px':m['body_height_px'],'anchor_px':m['anchor_px'],'idle_frame_size':m['clips']['idle']['frame_size'],'faces_left':m.get('faces_left',False)},'identity_master':{'path':str(portrait.relative_to(repo)),'sha256':sha256(portrait.read_bytes()).hexdigest()},'source_measurements':str((old/'measurements.json').relative_to(repo)),'existing_actor_opaque_colors':len(counts),'runtime_files':files,'preservation':'Read-only reference; no old source, manifest, clip or friendly counterpart overwritten.'})
 # Reserve transparent index0 and retain up to63 most-used approved runtime colors.
 selected=[list(color) for color,_ in counts.most_common(63)]
 palettes[visual]={'origin':'Approved existing runtime actor clips, most-used opaque RGB colors; transparent index0 added by Aseprite.','source_opaque_colors':len(counts),'selected_opaque_colors':len(selected),'rgb':selected,'dropped_rare_colors':max(0,len(counts)-63)}
(base/'legacy-input-audit.json').write_text(json.dumps({'version':1,'identities':records,'friendly_links':{'M02':'B17_human','M03':'M03_human','M04':'M04_human'},'aseprite_binary':'/home/weathour/programs/aseprite-src/build/bin/aseprite','method':'RGBA read-only palette counting and original manifest/source identity lookup.'},ensure_ascii=False,indent=2)+'\n')
(base/'legacy-palettes.json').write_text(json.dumps(palettes,ensure_ascii=False,indent=2)+'\n')
for r in records:print(r['visual_id'],r['legacy_geometry'],'old_colors',r['existing_actor_opaque_colors'])

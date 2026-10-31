"""Connect source provenance metadata before read-only pixel audit."""
import json
from pathlib import Path
from hashlib import sha256
ROOT=Path('design/boss-forms-20261029/characters')
ORIGINS=json.loads((ROOT.parent/'generation-origins.json').read_text())
REFERENCES={'B18_human':'B18','B17_human':'B17','B16_human':'B16','B15_human':'B15','M03_human':'M03_WAR','M04_human':'M04_WAR'}
for folder in sorted(ROOT.iterdir()):
 if not (folder/'measurements.json').exists(): continue
 m=json.loads((folder/'measurements.json').read_text())
 path=Path('assets/enemies/baimen')/folder.name/'manifest.json'
 data=json.loads(path.read_text())
 data['head_rect_px']=m['head_rect_px']
 sources={}
 for name,spec in {**m['sources'],'master':m['portrait']}.items():
  item=dict(spec); item['path']=str(folder/item['path']); sources[name]=item
 data['sources']=sources
 path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
 records=[]
 for source in sorted((folder/'source').glob('*.png')):
  records.append({'path':str(source),'sha256':sha256(source.read_bytes()).hexdigest(),'selection':'selected' if str(source) in [x['path'] for x in sources.values()] else 'retained_unselected','generated_origin':ORIGINS[folder.name].get(source.name,'same bytes as original master-v1')})
 references=[]
 for suffix in ['references/current-identity.png','source/master-v1.png']:
  reference=Path('design/baimen-enemies-20261028/characters')/REFERENCES[folder.name]/suffix
  references.append({'path':str(reference),'sha256':sha256(reference.read_bytes()).hexdigest(),'role':'identity_face' if 'identity' in suffix else 'war_form_continuity'})
 prompts=[{'path':str(x),'sha256':sha256(x.read_bytes()).hexdigest()} for x in sorted(folder.glob('*prompt.txt'))]
 notes={'master-v1':'Identity and anatomy reviewed; subsequent user aesthetic feedback remains possible','actions-v1':'16 separate alpha-connected bodies; fixed scale; reviewed foot/pelvis anchors; no grid crop'}
 if folder.name in ['B18_human','B16_human']: notes['actions-v1']+='; source move pose4 touches image edge and is excluded from runtime clips'
 if folder.name=='B18_human': notes.update({'master-v1':'Retained; crown plume tips needed completion','master-v2':'Selected; ImageGen redraw completes crown tips and uncrops full pose','actions-v2':'Retained, rejected: pose overlap/edge contact worse than v1'})
 (folder/'generation-record.json').write_text(json.dumps({'tool':'built-in image_gen.imagegen','reference_root':'design/baimen-enemies-20261028/characters','human_aesthetic_acceptance':'pending user review','sources':records,'references':references,'prompts':prompts,'selection_notes':notes},ensure_ascii=False,indent=2)+'\n')

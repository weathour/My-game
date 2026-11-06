"""Read-only Pillow QA; deterministic art processing belongs to Aseprite only."""
from pathlib import Path
from hashlib import sha256
from PIL import Image
import json,numpy as np
repo=Path(__file__).resolve().parents[4]
base=repo/'design/jia-lord-epilogue-20261106/backgrounds'
source_paths={'lord-hall':'exec-89c2dfd4-74fd-4236-9850-986cffb94942.png','lord-chamber':'exec-fa40500f-f4d8-4810-a952-d93c1d4260ec.png'}
layouts={
'lord-hall':{'time':'day, soft late-morning sunshine with two warm lamps','architecture':'Three-bay high-beamed hall, red-black weathered wood columns, patched pale plaster, stone raised platform and central command seat/desk, orderly side seats and low tables, blank crimson banners, closed tied scrolls/books, courtyard and tiled eaves through right doorway.','dialogue_area':'Lower quarter is a broad subdued stone floor. Portrait faces overlay the left/right midground; principal command desk remains deeper in the center.','story_use':'New regional lord formal council/rebuilding/governance.'},
'lord-chamber':{'time':'night, blue moonlit lattice windows and two warm oil lamps','architecture':'Same red-black timber and patched plaster, rear-central writing desk with scrolls, left low couch/cushions and mountain-painted folding screen, wrapped medicine/travel bags, right low shelf with horizontally laid armor pieces and folded crimson cloak.','dialogue_area':'Lower quarter is dark wooden floor. Pale casual portraits remain distinct against darker timber/screen sides; central night window and desk remain behind them.','story_use':'Private rest, practical daily conversation and light joking; no sexual staging.'}}
def file_record(path):
 im=Image.open(path)
 return {'path':str(path.relative_to(repo)),'bytes':path.stat().st_size,'sha256':sha256(path.read_bytes()).hexdigest(),'size':list(im.size),'mode':im.mode}
assets=[];checks=[]
for name,generated in source_paths.items():
 source=base/'source'/(name+'-v1.png');output=repo/'assets/story/chronicle'/(name+'.png');prompt=base/'prompts'/(name+'-v1.txt')
 raw=Image.open(source);image=Image.open(output)
 assert raw.mode in ['RGB','RGBA'] and raw.size==(1672,941)
 assert image.mode in ['RGB','RGBA'] and image.size==(1536,864) and image.width*9==image.height*16
 if image.mode=='RGBA':assert set(image.getchannel('A').getdata())=={255}
 pixels=np.asarray(image.convert('RGB'),dtype=float);luma=pixels@np.array([.2126,.7152,.0722]);bottom=luma[648:]
 visual={'people_absent':True,'dialogue_ui_absent':True,'watermarks_absent':True,'required_readable_text_absent':True,'no_human_shaped_armor_rack':True,'material_style_continues_camp':True,'independent_character_overlays_supported':True,'low_contrast_dialogue_floor_reviewed':True,'original_and_final_view_image_review_completed':True}
 checks.append({'id':name,**file_record(output),'opaque':True,'exact_16_9':True,'bottom_quarter_luma_mean':float(bottom.mean()),'bottom_quarter_luma_stddev':float(bottom.std()),'whole_luma_stddev':float(luma.std()),'visual_review':visual,'actual_layout':layouts[name]})
 assets.append({'id':name,'selected_version':'v1','generator':'built-in image_gen.imagegen','generated_original':'/home/weathour/.codex/generated_images/01a1a9ec-261f-71e1-83ea-ff043bd6c5e7/'+generated,'raw_source':file_record(source),'exact_prompt':{'path':str(prompt.relative_to(repo)),'sha256':sha256(prompt.read_bytes()).hexdigest()},'actual_imagegen_references':[{'role':'style and same outer-command-compound architecture reference','file':file_record(repo/'assets/story/chronicle/camp.png')}],'processing':{'tool':'Aseprite','script':'design/jia-lord-epilogue-20261106/backgrounds/qa/export_backgrounds.lua','operation':'Whole-image bilinear resize from1672x941 to1536x864; no cropping, no generated contents added, no transparency processing.','source_pixel_size':[1672,941],'runtime_pixel_size':[1536,864],'source_aspect_error_percent':abs((1672/941)/(16/9)-1)*100,'retained_composition':'Entire source canvas retained; tiny generator aspect rounding normalized to exact16:9.'},'output':file_record(output),'actual_layout':layouts[name],'selection':'v1 selected after local source and final-runtime view_image review; no rejected background generations.'})
qa={'version':1,'status':'pass','artifacts':checks,'scope':'Two new opaque hand-painted backgrounds only. No existing camp, character image, script, dialogue copy, gameplay or save changed by this art owner.','runtime_verification':'Deferred to coordinated runtime/verification owners; no Godot run by this art owner.','aesthetic_acceptance':'Agent source/composition review completed; user aesthetic approval is not inferred from technical checks.'}
(base/'qa/background-qa.json').write_text(json.dumps(qa,ensure_ascii=False,indent=2)+'\n')
inspected=[]
for name in ['jia-lord-smirk-v1.png','jia-lord-laugh-v1.png','jia-casual-laugh-v1.png','jia-casual-approach-v1.png']:
 inspected.append({'role':'Viewed for formal/crimson and casual/ivory portrait overlay contrast only; NOT passed to ImageGen and NOT modified.','file':file_record(repo/'design/jia-weisuo-20261027'/name)})
manifest={'version':1,'date':'2026-11-06','status':'background_art_ready_for_runtime','owner_scope':'assets/story/chronicle/lord-hall.png, lord-chamber.png and this backgrounds production directory only','generated_asset_count':2,'source_versions_selected':2,'unselected_versions':[],'assets':assets,'additional_context_images_inspected':inspected,'reproduction':{'export_command':'/home/weathour/programs/aseprite-src/build/bin/aseprite --batch --script design/jia-lord-epilogue-20261106/backgrounds/qa/export_backgrounds.lua','audit_command':'python3 design/jia-lord-epilogue-20261106/backgrounds/qa/audit_backgrounds.py'},'qa':'design/jia-lord-epilogue-20261106/backgrounds/qa/background-qa.json','production_files':[{'path':str(p.relative_to(repo)),'bytes':p.stat().st_size,'sha256':sha256(p.read_bytes()).hexdigest()} for p in sorted(base.rglob('*')) if p.is_file() and p.name!='manifest.json' and not p.name.endswith('.import')]}
(base/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print('LORD_EPILOGUE_BACKGROUND_ART_QA_PASS twoRGB backgrounds1536x864; raw sources/prompts/refs/exports hashed; no crop')

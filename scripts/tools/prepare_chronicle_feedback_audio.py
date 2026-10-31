#!/usr/bin/env python3
"""Prepare and audit the sourced Chronicle feedback SFX set.

Requires ffmpeg, ffprobe, Python 3. The manifest stores each exact ffmpeg invocation.
"""
from __future__ import annotations
import hashlib, json, math, os, shutil, struct, subprocess, tempfile, wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/sfx/chronicle-feedback'
SRC = Path('/tmp/my-game-sfx-research')
EVIDENCE = ROOT / 'design/combat-feedback-20261030/audio-license-evidence'
INDEX = ROOT / 'docs/design-reviews/evidence/2026-10-30/combat-feedback/audio-source-index.json'

# category, filename, source folder, relative source, pack metadata id, material caveat
ITEMS = [
 ('cast_blade','cast_blade_01.wav','swishes-sound-pack','swishes/swish-1.wav','artisticdude_swishes','Swish recording; exact source material not stated.'),
 ('cast_blade','cast_blade_02.wav','swishes-sound-pack','swishes/swish-2.wav','artisticdude_swishes','Swish recording; exact source material not stated.'),
 ('cast_blade','cast_blade_03.wav','swishes-sound-pack','swishes/swish-8.wav','artisticdude_swishes','Swish recording; exact source material not stated.'),
 ('hit_light','hit_light_01.wav','10-impactshield-blocks','impact.1.ogg','starninjas_impacts10','Recorded cardboard strike; not flesh or metal.'),
 ('hit_light','hit_light_02.wav','10-impactshield-blocks','impact.2.ogg','starninjas_impacts10','Recorded cardboard strike; not flesh or metal.'),
 ('hit_light','hit_light_03.wav','10-impactshield-blocks','impact.3.ogg','starninjas_impacts10','Recorded cardboard strike; not flesh or metal.'),
 ('hit_heavy','hit_heavy_01.wav','10-impactshield-blocks','impact.4.ogg','starninjas_impacts10','Cardboard strike; quieter peak target for heavy feedback mix, not flesh or metal.'),
 ('hit_heavy','hit_heavy_02.wav','10-impactshield-blocks','impact.5.ogg','starninjas_impacts10','Cardboard strike; quieter peak target for heavy feedback mix, not flesh or metal.'),
 ('guard','guard_01.wav','80-cc0-rpg-sfx','chain_01.ogg','rubberduck_rpg80','Chain/metal-like source as categorized by pack; exact recording material not independently confirmed.'),
 ('guard','guard_02.wav','80-cc0-rpg-sfx','metal_01.ogg','rubberduck_rpg80','Metal-labeled source; exact recording material not independently confirmed.'),
 ('death_ghost','death_ghost_01.wav','rpg-sound-pack','RPG Sound Pack/NPC/shade/shade1.wav','artisticdude_rpg95','Shade/ghost effect by source path; recording method/material not stated.'),
 ('death_ghost','death_ghost_02.wav','rpg-sound-pack','RPG Sound Pack/NPC/shade/shade4.wav','artisticdude_rpg95','Shade/ghost effect by source path; recording method/material not stated.'),
 ('death_ghost','death_ghost_03.wav','80-cc0-rpg-sfx','creature_die_01.ogg','rubberduck_rpg80','Creature death effect by file name; not asserted as a real ghost recording.'),
 ('magic','magic_01.wav','80-cc0-rpg-sfx','spell_01.ogg','rubberduck_rpg80','Spell effect by file name; recording method/material not stated.'),
 ('magic','magic_02.wav','80-cc0-rpg-sfx','spell_fire_02.ogg','rubberduck_rpg80','Fire spell effect by file name; recording method/material not stated.'),
 ('magic','magic_03.wav','80-cc0-rpg-sfx','spell_02.ogg','rubberduck_rpg80','Spell effect by file name; recording method/material not stated.'),
 ('pickup','pickup_01.wav','80-cc0-rpg-sfx','item_gem_01.ogg','rubberduck_rpg80','Gem pickup effect by file name; recording method/material not stated.'),
 ('pickup','pickup_02.wav','80-cc0-rpg-sfx','item_gem_02.ogg','rubberduck_rpg80','Gem pickup effect by file name; recording method/material not stated.'),
 ('level','level_01.wav','interface-sounds','Audio/confirmation_001.ogg','kenney_interface','Interface confirmation tone; recording method/material not stated.'),
 ('level','level_02.wav','interface-sounds','Audio/pluck_001.ogg','kenney_interface','Interface pluck tone; recording method/material not stated.'),
 ('elite','elite_01.wav','interface-sounds','Audio/confirmation_002.ogg','kenney_interface','Interface confirmation tone; recording method/material not stated.'),
 ('elite','elite_02.wav','interface-sounds','Audio/confirmation_003.ogg','kenney_interface','Interface confirmation tone; recording method/material not stated.'),
]

def run(cmd):
    return subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

def sha(path):
    h=hashlib.sha256()
    with open(path,'rb') as f:
        for b in iter(lambda:f.read(1<<20),b''): h.update(b)
    return h.hexdigest()

def probe(path):
    d=json.loads(run(['ffprobe','-v','error','-show_entries','format=duration:stream=codec_name,sample_rate,channels,bits_per_sample','-of','json',str(path)]).stdout)
    return float(d['format']['duration']),d.get('streams',[{}])[0]

def pcm_metrics(path):
    with wave.open(str(path),'rb') as w:
        ch,sw,rate,n=w.getnchannels(),w.getsampwidth(),w.getframerate(),w.getnframes()
        raw=w.readframes(n)
    if sw != 2: raise ValueError(f'expected PCM16, got sample width {sw}')
    vals=struct.unpack('<'+'h'*(len(raw)//2),raw)
    peak=max((abs(v) for v in vals),default=0)
    clip=sum(1 for v in vals if abs(v)>=32767)
    threshold=round(32768*10**(-55/20))
    first=next((i for i,v in enumerate(vals) if abs(v)>threshold),n)
    last=next((i for i in range(n-1,-1,-1) if abs(vals[i])>threshold),-1)
    half_peak_first=next((i for i,v in enumerate(vals) if abs(v)>=peak*.5),n)
    return {'half_peak_onset_ms':half_peak_first/rate*1000,'sample_rate':rate,'channels':ch,'pcm_bits':sw*8,'frames':n,'duration_seconds':n/rate,'peak_linear':peak/32768,'peak_dbfs':20*math.log10(peak/32768) if peak else None,'clipped_sample_count':clip,'leading_silence_ms':first/rate*1000,'trailing_silence_ms':(n-1-last)/rate*1000 if last>=0 else n/rate*1000,'silence_threshold_dbfs':-55}

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    EVIDENCE.mkdir(parents=True,exist_ok=True)
    index=json.loads(INDEX.read_text())
    packs={p['id']:p for p in index['packs']}
    packs.update(index['bounded_impact_supplement'])
    # Preserve snapshots for every used source pack and the CC0 legal code.
    snapmap={
      'artisticdude_swishes':'swishes-sound-pack-oga.html',
      'starninjas_impacts10':'10-impactshield-blocks-oga.html',
      'rubberduck_rpg80':'80-cc0-rpg-sfx-oga.html',
      'artisticdude_rpg95':'rpg-sound-pack-oga.html',
      'kenney_interface':'interface-sounds-oga.html',
    }
    for pid,fn in snapmap.items(): shutil.copy2(SRC/fn,EVIDENCE/fn)
    shutil.copy2(SRC/'CC0-1.0-legalcode.en.html',EVIDENCE/'CC0-1.0-legalcode.en.html')
    shutil.copy2(EVIDENCE/'CC0-LICENSE.txt',OUT/'CC0-LICENSE.txt')
    shutil.copy2(SRC/'interface-sounds/License.txt',OUT/'KENNEY-INTERFACE-LICENSE.txt')
    outputs=[]
    tmpdir=Path(tempfile.mkdtemp(prefix='chronicle-sfx-'))
    try:
      for cat,name,folder,rel,pid,caveat in ITEMS:
        source=SRC/folder/rel
        dest=OUT/name
        temp=tmpdir/(name+'.trim.wav')
        # Trim silence and cap source length to 1.2 sec. Intermediate remains float PCM.
        trim_cmd=['ffmpeg','-y','-i',str(source),'-af','silenceremove=start_periods=1:start_duration=0.01:start_threshold=-45dB:stop_periods=-1:stop_duration=0.005:stop_threshold=-45dB,atrim=duration=1.2,asetpts=PTS-STARTPTS','-ar','48000','-ac','1','-c:a','pcm_f32le',str(temp)]
        run(trim_cmd)
        duration,_=probe(temp)
        # Read the intermediate IEEE float samples to measure true sample peak.
        raw=subprocess.run(['ffmpeg','-v','error','-i',str(temp),'-f','f32le','-acodec','pcm_f32le','-'],check=True,stdout=subprocess.PIPE).stdout
        floats=struct.unpack('<'+'f'*(len(raw)//4),raw)
        true_peak=max((abs(v) for v in floats),default=0.0)
        src_peak_db=20*math.log10(true_peak) if true_peak>0 else -120.0
        target_db=-11.0 if cat=='hit_heavy' else -8.0
        gain=max(-60.0,min(12.0,target_db-src_peak_db))
        # 5 ms fade in, 20 ms fade out. Exact gain and fade placement recorded.
        contact_category=cat in {'hit_light','hit_heavy','guard','magic'}
        half_peak_first=next((i for i,v in enumerate(floats) if abs(v)>=true_peak*.5),0)
        transient_start=max(0.0,half_peak_first/48000.0-0.003) if contact_category else 0.0
        fade_in=0.0015 if contact_category else 0.005
        fade_out=max(0.0,duration-transient_start-0.02)
        af=f'atrim=start={transient_start:.6f},asetpts=PTS-STARTPTS,volume={gain:.6f}dB,afade=t=in:st=0:d={fade_in:.6f},afade=t=out:st={fade_out:.6f}:d=0.020'
        final_cmd=['ffmpeg','-y','-i',str(temp),'-af',af,'-ar','48000','-ac','1','-c:a','pcm_s16le',str(dest)]
        run(final_cmd)
        import_path=Path(str(dest)+'.import')
        if import_path.exists():
            import_path.write_text(import_path.read_text().replace('compress/mode=2','compress/mode=0'))
        else:
            import_path.write_text('[remap]\nimporter="wav"\ntype="AudioStreamWAV"\n\n[params]\ncompress/mode=0\n')
        metrics=pcm_metrics(dest)
        pack=packs[pid]
        outputs.append({'category':cat,'filename':name,'source':{'file':rel,'original_file_name':Path(rel).name,'source_path':str(source),'source_sha256':sha(source),'pack_id':pid,'pack_name':pack['name'],'author':pack['author'],'license':pack['license']['name'],'spdx':pack['license'].get('spdx','CC0-1.0'),'license_url':pack['license']['url'],'source_page_url':pack['page_url'],'material_caveat':caveat,'listening_status':'not_listened'},'processing':{'trim_command':trim_cmd,'normalization_command':final_cmd,'decoded_intermediate_peak_dbfs':src_peak_db,'applied_gain_db':gain,'target_peak_dbfs':target_db,'gain_cap_db':12.0,'trim_silence_threshold_dbfs':-45,'duration_cap_seconds':1.2,'transient_trim_start_seconds':transient_start,'half_peak_onset_before_ms':half_peak_first/48.0,'contact_transient_policy':'contact categories start 3 ms before first half-peak crossing; 1.5 ms edge fade; no change to gameplay timing','fade_in_seconds':fade_in,'fade_out_seconds':0.020,'intermediate_duration_seconds':duration},'qa':{**metrics,'output_sha256':sha(dest),'ffprobe':probe(dest)[1]}})
    finally:
      shutil.rmtree(tmpdir,ignore_errors=True)
    catalog={'schema_version':1,'description':'Short CC0 source-derived combat feedback clips. Selections have not been auditioned; names/categories are organizational roles, not claims about perceived sound.','audio_format':{'container':'WAV','codec':'PCM signed 16-bit little-endian','sample_rate_hz':48000,'channels':1,'maximum_duration_seconds':1.2},'categories':{},'clips':[{'category':o['category'],'filename':o['filename']} for o in outputs]}
    for o in outputs: catalog['categories'].setdefault(o['category'],[]).append(o['filename'])
    (OUT/'catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
    manifest={'schema_version':1,'license_basis':index['open_license_basis'],'license_file':'CC0-LICENSE.txt','source_page_snapshot_directory':str(EVIDENCE.relative_to(ROOT)),'source_page_snapshots':snapmap,'processing_policy':'FFmpeg silence trimming at -45 dBFS, 1.2 s maximum, 48 kHz mono PCM16, peak target -8 dBFS, gain limited to +12 dB, Contact categories additionally trim to 3 ms before the first half-peak crossing and use a 1.5 ms edge fade; other clips retain 5 ms fade-in; 20 ms fade-out. No auditory review was performed.','qa_summary':{'clip_count':len(outputs),'all_48k_mono_pcm16':all(o['qa']['sample_rate']==48000 and o['qa']['channels']==1 and o['qa']['pcm_bits']==16 for o in outputs),'duration_violations':[o['filename'] for o in outputs if o['qa']['duration_seconds']>1.2],'clipping':[o['filename'] for o in outputs if o['qa']['clipped_sample_count']>0],'leading_or_trailing_silence_over_50ms':[o['filename'] for o in outputs if o['qa']['leading_silence_ms']>50 or o['qa']['trailing_silence_ms']>50],'peak_over_minus5_dbfs':[o['filename'] for o in outputs if o['qa']['peak_dbfs'] is not None and o['qa']['peak_dbfs']>-5],'gain_over_12_db':[o['filename'] for o in outputs if o['processing']['applied_gain_db']>12]},'clips':outputs}
    manifest['qa_summary']['contact_half_peak_onset_over_8ms'] = [o['filename'] for o in outputs if o['category'] in {'hit_light','hit_heavy','guard','magic'} and o['qa']['half_peak_onset_ms'] > 8]
    manifest['runtime_import'] = {'godot_wav_compress_mode':0,'format':'PCM16; source WAV samples preserved on Godot import'}
    manifest['license_basis']['local_snapshot'] = str((EVIDENCE/'CC0-1.0-legalcode.en.html').relative_to(ROOT))
    (OUT/'source-license-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(manifest['qa_summary'],indent=2))
if __name__=='__main__': main()

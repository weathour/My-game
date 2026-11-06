#!/usr/bin/env python3
"""Build the frozen skill SFX bank from CC0 source textures plus procedural layers."""
from __future__ import annotations
import argparse, hashlib, json, math, subprocess
from pathlib import Path
import numpy as np
from scipy.signal import butter, sosfilt, resample_poly
from scipy.io import wavfile

ROOT=Path(__file__).resolve().parents[3]
BASE=ROOT/'design/skill-audio-20261103/audio'
ASSETS=ROOT/'assets/sfx/skill-combat-20261103'
SOURCES=BASE/'sources/oga-80-cc0-rpg-sfx'
WET_SOURCES=BASE/'sources/oga-40-water-splash-slime'
RECORDED_SOURCES=BASE/'sources/oga-100-cc0-sfx'
RATE=48000

FAMILIES=['blade','heavy_blade','thrust','blunt','bow','dash','earth','fire','ice','lightning','wind','water','poison','arcane','curse','heal','shield','mana','cleanse','summon','buff','beast','bone','armor','command','flesh','boss_hunter','boss_cavalry','boss_general','boss_demon']
BOSS_FAMILIES=['boss_hunter','boss_cavalry','boss_general','boss_demon']
BOSSES=set(BOSS_FAMILIES)
PHASES=['cast','impact','tell']
MATERIAL={
 'blade':('steel',680,0.76,['blade_01','metal_03']), 'heavy_blade':('steel_low',230,0.92,['blade_02','metal_05','chain_01']),
 'thrust':('steel_point',1040,0.62,['blade_03','metal_03']), 'blunt':('wood_stone',155,0.93,['hit_01','wooden_01','stones_01']),
 'bow':('wood_string',520,0.60,['wood_02','chain_01']), 'dash':('air',320,0.55,['spell_01']),
 'earth':('stone',105,0.95,['stones_02','slam_04']), 'fire':('fire',180,0.70,['explosion','spell_fire_05']),
 'ice':('ice_glass',1250,0.50,['glass_02','splash_13']), 'lightning':('electric',1450,0.50,['spell_02','metal_03']),
 'wind':('air',440,0.48,['spell_01','blade_03']), 'water':('liquid',360,0.66,['splash_03','bubble_03']),
 'poison':('wet',245,0.72,['slime_01','creature_misc_03']), 'arcane':('crystal',860,0.46,['spell_01','spell_02']),
 'curse':('dark',95,0.92,['creature_monster_02','spell_02']), 'heal':('bell',990,0.42,['spell_01','item_gem_01']),
 'shield':('metal_guard',390,0.83,['metal_05','chain_02']), 'mana':('crystal_low',540,0.52,['item_gem_02','spell_01']),
 'cleanse':('air_glass',1120,0.44,['spell_02','metal_01']), 'summon':('portal',165,0.86,['creature_monster_02','spell_01']),
 'buff':('bright',740,0.50,['item_gem_03','spell_01']), 'beast':('beast',120,0.91,['creature_hurt_01','creature_roar_01']),
 'bone':('bone',310,0.77,['stones_01','creature_die_01']), 'armor':('armor',460,0.84,['metal_01','chain_01']),
 'command':('horn',260,0.73,['creature_roar_01','metal_05']), 'flesh':('flesh',155,0.88,['hit_02','creature_hurt_02']),
 'boss_hunter':('hunter',420,0.87,['creature_monster_02','metal_01']), 'boss_cavalry':('cavalry',230,0.93,['creature_roar_01','chain_02','stones_02']),
 'boss_general':('general',295,0.90,['metal_05','creature_roar_01']), 'boss_demon':('demon',82,0.98,['creature_roar_01','creature_monster_02','spell_fire_05'])}
PHASE_GAIN={'cast':-4.0,'impact':-5.0,'tell':-3.0,'phase':-3.0,'defeat':-3.0}
PHASE_PRIORITY={'cast':2,'impact':1,'tell':4,'phase':6,'defeat':6}
PHASE_COOLDOWN={'cast':0.08,'impact':0.055,'tell':0.08,'phase':0.25,'defeat':0.25}
PHASE_INSTANCES={'cast':2,'impact':3,'tell':2,'phase':1,'defeat':1}
PHYSICAL_MATERIALS={'steel','steel_low','steel_point','wood_stone','wood_string','stone','bone','armor','metal_guard','cavalry','general','hunter','beast','flesh','demon'}
TONAL_MATERIALS={'electric','crystal','ice_glass','bell','air_glass','bright','portal'}

def sha(path):
 h=hashlib.sha256()
 with open(path,'rb') as f:
  for b in iter(lambda:f.read(1<<20),b''): h.update(b)
 return h.hexdigest()

def stable_seed(*s): return int(hashlib.sha256('|'.join(s).encode()).hexdigest()[:16],16)%(2**32)

_SOURCE_CACHE={}
def source_path(name):
 for d in (SOURCES,WET_SOURCES,RECORDED_SOURCES):
  p=d/(name+'.ogg')
  if p.is_file():return p
 return SOURCES/(name+'.ogg')
def read_source(name):
 if name in _SOURCE_CACHE:return _SOURCE_CACHE[name]
 p=source_path(name)
 raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(p),'-f','f32le','-ar',str(RATE),'-ac','1','-'])
 _SOURCE_CACHE[name]=np.frombuffer(raw,dtype='<f4').astype(np.float64)
 return _SOURCE_CACHE[name]

def filt(x,kind,lo,hi=None):
 ny=RATE/2
 if kind=='low': sos=butter(3,min(hi or lo,ny-1),btype='lowpass',fs=RATE,output='sos')
 elif kind=='high': sos=butter(2,max(15,lo),btype='highpass',fs=RATE,output='sos')
 else: sos=butter(3,[max(20,lo),min(hi,ny-10)],btype='bandpass',fs=RATE,output='sos')
 return sosfilt(sos,x)

def env(n,attack=0.01,decay=0.1,release=0.08,shape=1.3):
 t=np.arange(n)/RATE; dur=n/RATE
 a=min(attack,dur*.4); r=min(release,dur*.7); hold=max(0,dur-a-r)
 e=np.ones(n)
 na=max(1,int(a*RATE)); nr=max(1,int(r*RATE))
 e[:na]=np.sin(np.linspace(0,np.pi/2,na))**shape
 e[-nr:]=np.cos(np.linspace(0,np.pi/2,nr))**shape
 if hold==0: pass
 return e

def modal(n,rng,base,weight=1.0,bright=1.0,fall=1.0):
 t=np.arange(n)/RATE; y=np.zeros(n); modes=[1.0,1.43,1.91,2.65,3.17,4.03]
 for j,m in enumerate(modes):
  f=base*m*rng.uniform(.985,1.015)
  if f>=RATE*.46: continue
  tau=(.07+(.38 if j<2 else .12)*fall)*rng.uniform(.76,1.22)
  y+=np.sin(2*np.pi*f*t+rng.uniform(-math.pi,math.pi))*np.exp(-t/tau)*weight*bright/(1+j*.95)
 return y

def chirp(n,rng,f0,f1,amp=1,phase=0):
 t=np.arange(n)/RATE; dur=max(n/RATE,1/RATE)
 ratio=max(0.03,f1/f0)
 f=f0*np.power(ratio,t/dur)
 ph=2*np.pi*np.cumsum(f)/RATE+phase
 return amp*np.sin(ph)

def noise(n,rng,lo=100,hi=10000):
 return filt(rng.standard_normal(n),'band',lo,hi)

def sample_layer(name,n,rng,phase,material):
 x=read_source(name)
 if len(x)<32:raise RuntimeError(f'empty or invalid source sample: {name}')
 # Select an active material event, not a random silent lead or tail.
 threshold=max(1e-7,float(np.max(np.abs(x)))*.06)
 active=np.flatnonzero(np.abs(x)>threshold)
 if len(active)==0:raise RuntimeError(f'source sample has no active audio: {name}')
 span=min(len(x),n); latest=max(0,len(x)-span)
 candidates=active[active<=latest]
 if phase=='impact': start=max(0,int(active[0])-int(.006*RATE))
 elif len(candidates): start=int(candidates[int(rng.integers(0,len(candidates)))])
 else:start=max(0,int(active[0])-int(rng.uniform(0,.025)*RATE))
 start=min(start,latest)
 x=x[start:min(len(x),start+span)]
 if len(x)<n:x=np.pad(x,(0,n-len(x)))
 if material in ('steel','steel_low','steel_point','metal_guard','armor','ice_glass','crystal','air_glass','bell'):
  x=filt(x,'band',220,9000 if material not in ('steel_low','metal_guard') else 4200)
 elif material in ('beast','demon','hunter','cavalry','general','flesh','dark','portal'):
  x=filt(x,'low',1400)
 elif material in ('wood_stone','stone','bone','liquid','wet'):
  x=filt(x,'band',75,6200)
 else:x=filt(x,'band',100,7500)
 if phase=='tell': x=x[::-1].copy()
 x=x*env(n,.018,.1,.12,1.5)
 processed_rms=float(np.sqrt(np.mean(x*x)))
 if processed_rms<1e-5:raise RuntimeError(f'source layer has negligible processed energy: {name}')
 # Match the processed texture to a controlled layer level before mixing; the
 # final cue is still a composite of this source and new synthesis, not a gain-
 # only or pitch-only source copy.
 return x/processed_rms,{'post_filter_envelope_rms_before_layer_match':processed_rms,'layer_match_gain':1.0/processed_rms}

def make_cue(family,phase,variant,cue_id=None):
 material,root,body,srcs=MATERIAL[family]; seed=stable_seed(family,phase,str(variant),cue_id or ''); rng=np.random.default_rng(seed)
 physical=material in PHYSICAL_MATERIALS
 dur={'cast':.29,'impact':.25,'tell':.43,'phase':.98,'defeat':1.08}[phase]
 if phase=='impact' and family in BOSSES:dur=.34
 if phase=='phase': dur=1.0+rng.uniform(0,.18)
 elif phase=='defeat': dur=(.39+rng.uniform(0,.04)) if family in BOSSES else (.30+rng.uniform(0,.04))
 elif family in BOSSES: dur+=.06
 n=round(dur*RATE); t=np.arange(n)/RATE; e=env(n,.008 if phase=='impact' else .025,.10,.09 if phase in ('impact','cast') else .20,1.2)
 y=np.zeros(n)
 # Main phase grammar: preparation rises, cast releases, impact lands and rings.
 if phase=='impact':
  trans=noise(n,rng,max(30,root*.22),min(11000,root*8+9000))*np.exp(-t/rng.uniform(.012,.036))
  if physical:
   low=np.sin(2*np.pi*max(34,root*.42)*t+rng.uniform(0,6.28))*np.exp(-t/rng.uniform(.045,.105))
   y+=trans*.28+low*(.16+body*.18)+modal(n,rng,root,.12+body*.15,.85,.75)
  else:
   low=chirp(n,rng,max(36,root*.45),max(55,root*.26),amp=1)*np.exp(-t/rng.uniform(.055,.13))
   y+=trans*.42+low*(.22+body*.28)+modal(n,rng,root,.2+body*.3,1.0,1.0)
 elif phase=='cast':
  if physical:
   # Material-led swing, draw, or lunge: source motion is foreground, with a
   # low-mid air push and a restrained object resonance, no common pitch rise.
   air=noise(n,rng,max(100,root*.14),min(6800,root*5+2200))*np.linspace(.08,.62,n)
   y+=air*.17+modal(n,rng,root,.10,.62,.72)
  else:
   fstart=max(55,root*rng.uniform(.45,.76)); fend=min(9500,root*rng.uniform(1.45,2.9))
   sweep=chirp(n,rng,fstart,fend,amp=.45)
   air=noise(n,rng,root*.2,min(13000,root*8+6500))*np.linspace(.05,.8,n)
   y+=sweep*.32+air*.24+modal(n,rng,root,.22,.8,1.0)
 else:
  if physical:
   # Tell is a growing material scrape/rattle/rumble, not an electronic alarm chirp.
   swell=noise(n,rng,max(45,root*.14),min(6500,root*5+1800))*np.linspace(.02,.78,n)
   y+=swell*.30+modal(n,rng,root,.10,.70,1.25)
  else:
   fstart=max(40,root*rng.uniform(.42,.85)); fend=min(9000,root*rng.uniform(1.5,3.5))
   rise=np.sin(2*np.pi*np.cumsum(np.linspace(fstart,fend,n))/RATE)
   swell=noise(n,rng,root*.17,min(9000,root*7+6500))*np.linspace(.02,.68,n)
   y+=rise*.24+swell*.30+modal(n,rng,root,.18,.95,1.2)
 if phase in ('phase','defeat'):
  direction=-1 if phase=='defeat' else 1
  if physical:
   y+=np.sin(2*np.pi*max(28,root*.42)*t)*np.exp(-t/(.62 if direction>0 else .84))*.22
  else:y+=chirp(n,rng,root*.45,root*(.28 if direction<0 else 2.1),amp=.30)*np.exp(-t/(.62 if direction>0 else .84))
  y+=noise(n,rng,45,4200)*(.3 if phase=='phase' else .22)*np.exp(-t/.48)
 # Family signature material layer: distinctly tuned texture and transient.
 mat_imp=modal(n,rng,root*(1.0 if phase=='impact' else .82),weight=.18+body*.21,bright=.9 if material in ('beast','demon','dark','flesh') else 1.35,fall=.7 if phase=='impact' else 1.25)
 y+=mat_imp
 if material in ('electric','crystal','ice_glass','bell','air_glass','bright'):
  y+=chirp(n,rng,root*1.4,min(RATE*.44,root*2.8),amp=.19)*np.exp(-t/.23)
 if material in ('beast','demon','hunter','cavalry','general','flesh','dark','portal'):
  y+=noise(n,rng,45,750)*(.34 if phase!='impact' else .2)*np.exp(-t/(.24 if phase!='tell' else .55))
 # Adds original recorded foley/spell/creature texture into the newly synthesized design.
 used_sources=[]; source_contributions=[]
 for ix,name in enumerate(srcs[:2] if phase not in ('phase','defeat') else srcs[:3]):
  layer,layer_stats=sample_layer(name,n,rng,phase,material)
  weight=(.62 if physical else .44)*(1.0 if ix==0 else .70)*(1.0 if ix<2 else .75)
  contribution=layer*weight
  layer_rms=float(np.sqrt(np.mean(contribution*contribution)))
  if not math.isfinite(layer_rms) or layer_rms<1e-5:raise RuntimeError(f'{cue_id or family}.{phase}: missing audible source contribution from {name}')
  y+=contribution
  source_contributions.append(contribution)
  used_sources.append({'file':name+'.ogg','sha256':sha(source_path(name)),**layer_stats,'post_layer_match_weighted_rms':layer_rms,'weight':weight,'layer_index':ix})
 # Add controlled physical grit or airy pre-motion based on family class.
 if material in ('steel','steel_low','steel_point','metal_guard','armor','wood_stone','wood_string','stone','bone','cavalry','general'):
  y+=noise(n,rng,280,9500)*(.12 if phase=='impact' else .055)*np.exp(-t/.085)
 elif material in ('fire','wet','liquid','beast','demon','flesh','dark'):
  y+=noise(n,rng,60,3700)*(.16 if phase=='impact' else .08)*np.exp(-t/.21)
 elif material in ('air','electric','portal','crystal','ice_glass','bright','bell','air_glass'):
  y+=noise(n,rng,600,14000)*(.075 if phase=='impact' else .12)*e
 # A clear, restrained phase envelope and short tail; boss phase/defeat are authored longer.
 y*=e
 source_mix=np.zeros(n)
 for i,contribution in enumerate(source_contributions):
  shaped=contribution*e
  source_mix+=shaped
  used_sources[i]['post_final_envelope_rms']=float(np.sqrt(np.mean(shaped*shaped)))
 mix_rms=float(np.sqrt(np.mean(y*y)))
 source_mix_rms=float(np.sqrt(np.mean(source_mix*source_mix)))
 if phase=='impact':
  y[:max(1,int(.005*RATE))]*=np.linspace(.35,1,min(len(y),int(.005*RATE)))
 y=np.nan_to_num(y)
 peak=np.max(np.abs(y))
 if peak<1e-8: raise RuntimeError(f'silent synthesis: {family}.{phase}.{variant}')
 y=y*(10**(-4/20)/peak)
 contribution_ratio=(source_mix_rms*source_mix_rms)/max(mix_rms*mix_rms,1e-20)
 return np.clip(y,-.9999,.9999).astype(np.float32),used_sources,{'pre_gain_mix_rms':mix_rms,'source_layer_mix_rms':source_mix_rms,'source_to_mix_power_ratio':contribution_ratio}

def cue_entries():
 for family in FAMILIES:
  for phase in PHASES: yield f'{family}.{phase}',family,phase
 for family in BOSS_FAMILIES:
  for phase in ('phase','defeat'): yield f'{family}.{phase}',family,phase
 for cue,family,phase in [('feedback.hurt','flesh','impact'),('feedback.guard','shield','impact'),('feedback.death','beast','defeat')]: yield cue,family,phase

def main():
 ap=argparse.ArgumentParser(); ap.add_argument('--families',nargs='*',default=None); ap.add_argument('--all',action='store_true'); a=ap.parse_args()
 selected=set(a.families or [])
 ASSETS.mkdir(parents=True,exist_ok=True); outentries={}; qa=[]
 if a.all:
  for stale in ASSETS.glob('*.wav'):stale.unlink()
 for cue,family,phase in cue_entries():
  if selected and family not in selected and not cue.startswith('feedback.'): continue
  if not a.all and not selected: raise SystemExit('choose --families or --all')
  variants=[]
  for variant in range(1,4):
   stem=f'{cue.replace(".","_")}' if cue.startswith('feedback.') else f'{family}_{phase}'
   name=f'{stem}_{variant:02d}.wav'; path=ASSETS/name
   y,used_sources,design_metrics=make_cue(family,phase,variant,cue_id=cue); pcm=np.round(y*32767).astype('<i2')
   wavfile.write(path,RATE,pcm)
   peak=int(np.max(np.abs(pcm))); rms=float(np.sqrt(np.mean(pcm.astype(np.float64)**2)))
   rec={'path':f'res://assets/sfx/skill-combat-20261103/{name}','sha256':sha(path),'size_bytes':path.stat().st_size,'duration_sec':len(pcm)/RATE,'sample_peak_dbfs':20*math.log10(max(peak/32768,1e-12)),'rms_dbfs':20*math.log10(max(rms/32768,1e-12)),'frames':len(pcm),'sample_rate':RATE,'channels':1,'encoding':'PCM16','family':family,'phase':phase,'variant':variant,'source_layer_contributions':used_sources,'design_metrics':design_metrics,'design_role':'physical material-led transient/scrape/rumble' if MATERIAL[family][0] in PHYSICAL_MATERIALS else 'tonal/elemental identity plus source texture'}
   variants.append(rec); qa.append({'cue_id':cue,'variant':variant,**rec})
  entry={'variants':[v['path'] for v in variants],'gain_db':PHASE_GAIN[phase],'cooldown_sec':PHASE_COOLDOWN[phase],'max_instances':PHASE_INSTANCES[phase],'priority':PHASE_PRIORITY[phase],'spatial':{'max_distance':1200.0,'panning_strength':0.55},'duck':{}}
  outentries[cue]=entry
 old={'feedback.pickup':['pickup_01.wav','pickup_02.wav'],'feedback.level':['level_01.wav','level_02.wav'],'feedback.elite':['elite_01.wav','elite_02.wav']}
 for cue,names in old.items():
  if not selected or cue in ('feedback.pickup','feedback.level','feedback.elite'):
   outentries[cue]={'variants':[f'res://assets/sfx/chronicle-feedback/{name}' for name in names],'gain_db':0.0,'cooldown_sec':0.08,'max_instances':2,'priority':2,'spatial':{'max_distance':1200.0,'panning_strength':0.55},'duck':{},'retained_utility':True}
 catalog={'schema_version':1,'cues':outentries}
 (ASSETS/'catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
 source_locks=[]
 for lock_path in sorted((BASE/'sources').glob('source-lock*.json')):
  source_locks.append({'path':str(lock_path.relative_to(ROOT)),'sha256':sha(lock_path),'source_name':json.loads(lock_path.read_text())['source_name']})
 tool_hashes={name:sha(BASE/name) for name in ('build_skill_sfx.py','verify_skill_sfx.py','make_previews.py','sources/fetch-oga-samples.sh') if (BASE/name).is_file()}
 report={'status':'PASS' if all(-4.15<=x['sample_peak_dbfs']<=-3.85 for x in qa) else 'FAIL','sample_rate':RATE,'channels':1,'format':'PCM16 WAV','cues':len([c for c in outentries if c not in old]),'new_variants':len(qa),'retained_utility_cues':list(old),'retained_utility_variant_references':sum(len(v['variants']) for k,v in outentries.items() if k in old),'catalog_variant_reference_count':sum(len(v['variants']) for v in outentries.values()),'source_manifests':source_locks,'tools_sha256':tool_hashes,'files':qa,'source_layer_policy':'Each new variant combines source-specific CC0 audio textures with deterministic family- and phase-specific synthesis and material processing. Physical families foreground source material and foley layers; purposeful tonal signatures are reserved for elemental/magical families. Missing or negligible source layers fail generation.'}
 (BASE/'qa'/('sfx-'+('-'.join(sorted(selected)) if selected else 'all')+'.json')).parent.mkdir(parents=True,exist_ok=True)
 (BASE/'qa'/('sfx-'+('-'.join(sorted(selected)) if selected else 'all')+'.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps({'status':report['status'],'cues':len(outentries),'variants':len(qa),'asset_dir':str(ASSETS)},ensure_ascii=False))

if __name__=='__main__': main()

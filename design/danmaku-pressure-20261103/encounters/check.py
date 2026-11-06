#!/usr/bin/env python3
"""Check authored identity, duel boundaries and pressure metrics without Godot."""
import importlib.util,json,math,sys
sys.dont_write_bytecode = True
from pathlib import Path
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('generator',HERE/'generate.py')
g=importlib.util.module_from_spec(spec); spec.loader.exec_module(g)
before=json.loads((HERE/'before.json').read_text())
after=json.loads((HERE/'after.json').read_text())
checks=0

def check(condition,message):
 global checks
 checks+=1
 assert condition,message

def actions(data):
 out={}
 for id,e in data['enemies'].items():
  for i,a in enumerate(e['attacks']):out[(id,0,i)]=a
 for id,fs in data['forms'].items():
  for fi,f in enumerate(fs):
   for i,a in enumerate(f['attacks']):out[(id,fi,i)]=a
 return out

ba,aa=actions(before),actions(after)
check(set(before['enemies'])==set(after['enemies']),'definition identity')
check(len(after['enemies'])==43,'43 definitions')
check(len(after['stages'])==18,'18 encounters')
check(ba.keys()==aa.keys(),'move inventory unchanged')
for key,a in aa.items():
 b=ba[key]
 check((a['id'],a['action'],a['shape'])==(b['id'],b['action'],b['shape']),f'move identity {key}')
 check(a!=b,f'unchanged move {key}')
 check(a['windup']>0 and a['recovery']>0,f'timing {key}')
 check(a['damage_scale']==b['damage_scale'],f'no blanket damage increase {key}')
 check(a.get('warning_policy') in ('none','aim','area'),f'warning policy {key}')
 if a['action']=='marker':
  check(a['windup']*215>=a['radius']+12,f'marker exit at 215 units/sec {key}')
 if a['action']=='charge':
  check(a['windup']*215>=a['half_width']+12,f'charge sidestep {key}')
 for pattern in ([a] if a['action'] in ('shot','fan') else []) + ([a['secondary_pattern']] if 'secondary_pattern' in a else []):
  check(1<=pattern.get('burst_count',1)<=8,f'bounded bursts {key}')
  check(pattern.get('burst_interval',.3)>=.12,f'burst spacing {key}')
  check(0<pattern.get('hit_radius',4)<=7,f'bullet collision {key}')
  if pattern.get('kind')=='ring':
   check(pattern.get('gap_width',0)>=1.0,f'explicit ring exit {key}')
  check(not pattern.get('aim_each_burst',False) or a['action']=='shot',f'only aimed arrows track between bursts {key}')
 if 'marker_count' in a:
  check(1<=a['marker_count']<=5 and a['marker_delay']>=.12,f'bounded locked marker trail {key}')
 for field in ('count','range','radius','life','speed'):
  if field in a:check(a[field]>0,f'positive {field} {key}')
for id,e in after['enemies'].items():
 b=before['enemies'][id]
 for field in ('id','name','behavior_id','rank','visual_id','elite_rule_id','damage','body_height','radius'):
  check(e[field]==b[field],f'identity/base damage {id}:{field}')
for id,s in after['stages'].items():
 b=before['stages'][id]
 for field in ('boss_time','bonus_time','boss_hp','enemy_hp','enemy_damage','boss_definition','field_elites','derivative_cap','boss_derivative_cap'):
  check(s[field]==b[field],f'campaign contract {id}:{field}')
 if id=='B18':
  check({k:v for k,v in s.items() if k!='boss_min_time'}==b and s['boss_min_time']==0,'B18 duel contract untouched')
  check(all(a['action']!='summon' for f in after['forms'][id] for a in f['attacks']),'B18 no summon')
 else:
  check(28<=s['boss_min_time']<=40 and s['boss_min_time']<s['boss_time'],'minimum fodder duration')
  check(58<=s['enemy_cap']<=94,'population bound')
  check(s['boss_kills']>b['boss_kills'],'kill gate scales with population')
  for w in s['waves']:
   check(w['cycle'].count('E01')/len(w['cycle'])>=2/3,f'fodder share {id}')
   check(all(x in g.STATS for x in w['cycle']),f'wave identity {id}')
for id,fs in after['forms'].items():check(len(fs)==2,f'two forms {id}')
# Ensure the checked JSON is the exact checked-in dictionary content.
for name,path,field in [('DEFINITIONS','enemy_catalog.gd','enemies'),('STAGES','stage_catalog.gd','stages'),('FORM_DEFINITIONS','boss_forms.gd','forms')]:
 source=(g.ROOT/'scripts/content'/path).read_text(); prefix='const '+name+' := '
 data,_=json.JSONDecoder().raw_decode(source[source.index(prefix)+len(prefix):])
 check(data==after[field],f'generated content drift {field}')
report={'checks':checks,'definitions':43,'encounters':18,'authored_action_contexts':len(aa),
 'move_identity_preserved':True,'base_damage_preserved':True,'duel_preserved':True,
 'stage_metrics':{id:{'cap_before':before['stages'][id]['enemy_cap'],'cap_after':s['enemy_cap'],
 'kill_gate_before':before['stages'][id]['boss_kills'],'kill_gate_after':s['boss_kills'],
 'waves':[{'at':w['at'],'attempted_bodies_per_second':round(w['count']/w['interval'],3),
 'fodder_fraction':round(w['cycle'].count('E01')/len(w['cycle']),3)} for w in s['waves']]}
 for id,s in after['stages'].items()},
 'action_changes':[{'context':list(k),'before':ba[k],'after':a} for k,a in aa.items()]}
(HERE/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(f'ENCOUNTER_PRESSURE_OK checks={checks} definitions=43 encounters=18 action_contexts={len(aa)}')

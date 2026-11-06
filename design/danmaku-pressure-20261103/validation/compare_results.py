#!/usr/bin/env python3
"""Create compact before/after evidence from completed probe JSONs."""
from pathlib import Path
import json,statistics
P=Path(__file__).resolve().parent
report={'scope':{'simulation':True,'human_playtest':False,'survival_fixtures':'normal HP/MP, current unmodified kits, fixed level1 B01 / level4 B05 / level8 B12 / level12 Boss. Not campaign reachability evidence. Boss phase fixtures instantiate individual phase.','exposure_fixtures':'HP reset each tick and player offense disabled; density/action/logic timing only, not survival evidence.','driver':'200ms delayed visible warnings/projectile state; decisions every150ms; actual total input reaction200–350ms. Projectile velocities inferred exactly by harness. No future move data.','timing':'Headless logic tick only; excludes rendering, UI, audio, driver. Host shared with other jobs, not stable 60FPS certification.','boss_seeds':'Boss fixtures with same start/phase are deterministic; different seed repeats are not independent difficulty samples.','zero_safe_sampled_directions':'Local 0.75s straight-velocity candidates; failure does not establish zero real exits.','initial_reachability':'Initial helper conservatively uses earliest deadline for all markers. Its 54 zero-candidate records are rechecked in marker_timing_review.json with each marker own deadline: all have a route. Replay excludes simultaneous hazards/projectiles; normal damage-on sessions are separate evidence.'},'suites':{}}
for suite in ['mobs','boss','exposure','growth']:
    files=[P/(v+'-'+suite+'.json') for v in ['before','after']]
    if not all(p.is_file() for p in files):continue
    before,after=[json.loads(p.read_text())['reports'] for p in files]
    key=lambda r:(r['stage'],r['phase_fixture'],r.get('start','center'),r['strategy'],r['seed'])
    bm={key(r):r for r in before};am={key(r):r for r in after}
    rows=[]
    metrics=['seconds','mean_alive','peak_alive','mean_within_240','peak_within_240','kills','kills_per_second','xp_collected','hurt_events','hurt_total','peak_hostile_projectiles','mean_hostile_projectiles','moving_fraction','boundary_fraction','zero_safe_sampled_directions','peak_delayed']
    for k in sorted(set(bm)&set(am)):
        b,a=bm[k],am[k]
        rows.append({'stage':k[0],'phase':k[1],'start':k[2],'strategy':k[3],'seed':k[4],'before_outcome':b['outcome'],'after_outcome':a['outcome'],'metrics':{m:{'before':b[m],'after':a[m],'ratio':a[m]/b[m] if b[m] else None} for m in metrics},'logic_step_ms':{'before':b['logic_step_ms'],'after':a['logic_step_ms']},'after_actions':a['actions_started'],'xp_budget':{'before_picked':b['xp_collected'],'after_picked':a['xp_collected'],'before_actual_gain':b.get('actual_xp_gained_by_member'),'after_actual_gain':a.get('actual_xp_gained_by_member'),'before_ground':b.get('xp_on_ground_at_stop'),'after_ground':a.get('xp_on_ground_at_stop'),'before_picked_or_ground':b.get('xp_picked_or_ground'),'after_picked_or_ground':a.get('xp_picked_or_ground'),'before_exit_levels':{i:v['level'] for i,v in b['exit'].items()},'after_exit_levels':{i:v['level'] for i,v in a['exit'].items()},'before_stop':b.get('stop_reason'),'after_stop':a.get('stop_reason')},'after_initial_warning_no_sampled_escape':[w for w in a.get('warning_initial_reachability',[]) if not w['safe_sampled_routes']]})
    report['suites'][suite]={'before_samples':len(before),'after_samples':len(after),'paired_samples':len(rows),'pairs':rows,'after_configuration_errors':[r for r in after if r['configuration_error']]}
for suite in ['duel','cadence']:
    path=P/('after-'+suite+'.json')
    if path.is_file(): report[suite]=json.loads(path.read_text())
if (P/'final-delta-validation.json').is_file(): report['final_delta']=json.loads((P/'final-delta-validation.json').read_text())
(P/'comparison.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
print(json.dumps({'suites':{s:{k:v[k] for k in ['before_samples','after_samples','paired_samples']} for s,v in report['suites'].items()}},indent=2))

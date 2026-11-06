#!/usr/bin/env python3
from pathlib import Path
import json,statistics as st
P=Path(__file__).resolve().parent
load=lambda name:json.loads((P/name).read_text())
summary={'human_playtest':False,'source_review':'source_review.json','comparison':'comparison.json','geometry_checks':load('geometry_probe.json'),'marker_deadline_review':{'reviewed':load('marker_timing_review.json')['reviewed'],'still_zero':load('marker_timing_review.json')['still_zero'],'scope':load('marker_timing_review.json')['scope']},'growth_to_boss':[],'continuous_duels':[],'cadence':[],'logic_timing':[],'mob_pressure':[]}
for stage in ['B01','B05','B12']:
    row={'stage':stage}
    for version in ['before','after']:
        rs=[r for r in load(version+'-growth.json')['reports'] if r['stage']==stage]
        row[version]={'samples':len(rs),'seconds_mean':st.mean(r['seconds'] for r in rs),'kills_mean':st.mean(r['kills'] for r in rs),'xp_picked_mean':st.mean(r['xp_collected'] for r in rs),'xp_ground_mean':st.mean(r['xp_on_ground_at_stop'] for r in rs),'xp_generated_mean':st.mean(r['xp_picked_or_ground'] for r in rs),'actual_jia_xp_mean':st.mean(r['actual_xp_gained_by_member']['JIA'] for r in rs),'jia_exit_levels':[r['exit']['JIA']['level'] for r in rs],'stop_reasons':[r['stop_reason'] for r in rs]}
    summary['growth_to_boss'].append(row)
    for policy in ['stationary','orbit','reactive']:
        row={'stage':stage,'strategy':policy}
        for version in ['before','after']:
            rs=[r for r in load(version+'-mobs.json')['reports'] if r['stage']==stage and r['strategy']==policy]
            row[version]={m:st.mean(r[m] for r in rs) for m in ['seconds','mean_alive','mean_within_240','kills_per_second','hurt_total','xp_collected']}
            row[version]['failed_samples']=sum(r['outcome']=='failed' for r in rs)
        summary['mob_pressure'].append(row)
for r in load('after-duel.json')['reports']:
    summary['continuous_duels'].append({k:r[k] for k in ['stage','start','seconds','outcome','hurt_total','entry','exit','phase_resource_records','actual_xp_gained_by_member']})
for r in load('after-cadence.json')['reports']:
    t=r['tell_timeline'];summary['cadence'].append({'stage':r['stage'],'start':r['start'],'strategy':r['strategy'],'first_tell':t[0],'largest_subsequent_gap':max(t[1:],key=lambda x:x['since_previous_tell'])})
for suite in ['mobs','boss','exposure']:
    rs=load('after-'+suite+'.json')['reports'];summary['logic_timing'].append({'suite':suite,'samples':sum(r['logic_step_ms']['samples'] for r in rs),'largest_sample_p95_ms':max(r['logic_step_ms']['p95'] for r in rs),'largest_step_ms':max(r['logic_step_ms']['max'] for r in rs),'peak_alive':max(r['peak_alive'] for r in rs),'peak_hostile_projectiles':max(r['peak_hostile_projectiles'] for r in rs),'configuration_errors':sum(bool(r['configuration_error']) for r in rs)})
summary['exposure_every_move_released']={r['stage']+':'+str(r['phase_fixture'])+':'+r['start']+':'+r['strategy']:r['release_events'] for r in load('after-exposure.json')['reports']}
summary['limitations']=['Fixed artificial fixtures do not establish reachable campaign builds or human difficulty acceptance.','Boss isolated-phase samples do not imply continuous-duel success; continuous-duel B18 center fails.','Boss different-seed repeats at the same fixture are deterministic, not independent difficulty samples.','Exposure resets HP and disables offense; its damage/outcome is not survival evidence.','Initial warning zero-direction counts were conservative; marker timing replay uses each own deadline and excludes simultaneous projectiles/hazards.','CPU Intel Core i5-14600K / Godot4.6.2 headless logic only, excludes rendering/audio/controller. Sampling window coordinated with core; OS not isolated. Largest observed mob tick25.971ms; p95 does not guarantee60FPS.','Total alive is not on-screen count; local pressure metric radius240 and renderer camera measurements should be read separately.','Growth compares actual Boss-appearance checkpoints, not full chapter XP economy.']
if (P/'final-delta-validation.json').is_file():
    summary['final_delta']=load('final-delta-validation.json')
    previous=load('acceptance_summary.json') if (P/'acceptance_summary.json').is_file() else {}
    summary['source_epochs']=previous.get('source_epochs',{})
    final_duels=load('final-after-duel.json')['reports']
    summary['continuous_duels_final_effective']=[r for r in summary['continuous_duels'] if r['stage']!='B17']+[{k:r[k] for k in ['stage','start','seconds','outcome','hurt_total','entry','exit','phase_resource_records','actual_xp_gained_by_member']} for r in final_duels]
    final_cadence=load('final-after-cadence.json')['reports']
    summary['cadence_final_effective']=[{'stage':r['stage'],'start':r['start'],'strategy':r['strategy'],'first_tell':r['tell_timeline'][0],'largest_subsequent_gap':max(r['tell_timeline'][1:],key=lambda x:x['since_previous_tell'])} for r in final_cadence]
    summary['limitations'].append('Original performance/full-suite reports use initial candidate hashes; final B17 regression comprises6 targeted logic samples without renewed whole-suite/FPS claim.')
(P/'acceptance_summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2))
print('summary written')

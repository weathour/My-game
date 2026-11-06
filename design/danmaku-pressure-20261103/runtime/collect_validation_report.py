#!/usr/bin/env python3
"""Collect final checker/package facts; refuses incomplete full validation."""
from pathlib import Path
import datetime, hashlib, json, re, subprocess
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def rel(path):
    return str(path.relative_to(ROOT))

full=HERE/'final-logs/full-project-check.log'
assert full.read_text().rstrip().endswith('PROJECT_CHECK_OK'), 'full check is incomplete'
smokes=[]
pack_names={'chronicle_enemy_pack_smoke','chronicle_music_pack_smoke','chronicle_story_pack_smoke','chronicle_combat_feedback_pack_smoke'}
for script in sorted((ROOT/'scripts/tests').glob('*_smoke.gd')):
    log=HERE/'full-check-logs'/(script.stem+'.log')
    result=subprocess.run(['python3',str(ROOT/'scripts/tests/check_smoke_log.py'),str(script),str(log)],capture_output=True,text=True)
    assert result.returncode==0, (script.name,result.stdout,result.stderr)
    text=log.read_text(); matches=re.findall(r'\bPASS\b[^\n]*\bchecks=(\d+)',text)
    smokes.append({'script':rel(script),'log':rel(log),'type':'pck' if script.stem in pack_names else 'source','checks':int(matches[-1]) if matches else None,'script_sha256':digest(script),'log_sha256':digest(log)})
assert len(smokes)==52, len(smokes)
freeze_path=HERE/'core-freeze.json';freeze=json.loads(freeze_path.read_text())
assert all(digest(ROOT/path)==sha for path,sha in freeze['sha256'].items())
package=ROOT/'builds/linux-danmaku-pressure-20261103'
manifest=json.loads((package/'build-manifest.json').read_text())
assert digest(package/'game.pck')==manifest['pck_sha256']
assert digest(package/'godot-4.6.2')==manifest['runtime_sha256']
assert manifest['battle_core_sha256']==freeze['sha256']
assert all(digest(package/item['path'])==item['sha256'] for item in manifest['notices_and_licenses'])
package_checks=[]
for name in ['package-danmaku','package-skill-audio','package-boss-impact']:
    path=HERE/'final-logs'/(name+'.log'); text=path.read_text()
    assert re.search(r'\bPASS\b[^\n]*failures=0',text), name
    assert not re.search(r'SCRIPT ERROR|Parser Error|Parse Error|Invalid call|^ERROR:',text,re.M), name
    matches=re.findall(r'\bPASS\b[^\n]*\bchecks=(\d+)',text)
    package_checks.append({'name':name,'checks':int(matches[-1]),'log':rel(path),'sha256':digest(path)})
for name in ['package-launch-headless','package-launch-graphical-graceful']:
    path=HERE/'final-logs'/(name+'.log'); text=path.read_text()
    assert 'Godot Engine v4.6.2' in text
    assert not re.search(r'SCRIPT ERROR|Parser Error|Parse Error|Invalid call|^ERROR:',text,re.M), name
session_log=HERE/'full-check-logs/chronicle_enemy_sessions_smoke.log'
session_reports=[json.loads(line.split(' ',1)[1]) for line in session_log.read_text().splitlines() if line.startswith('ENEMY_REAL_SESSION ')]
assert len(session_reports)==18
campaign_log=HERE/'full-check-logs/chronicle_enemy_campaign_smoke.log'
campaign_summaries=[json.loads(line.split(' ',1)[1]) for line in campaign_log.read_text().splitlines() if line.startswith('CONTINUOUS_CAMPAIGN_SUMMARY ')]
assert len(campaign_summaries)==2 and all(row['finished'] for row in campaign_summaries)
report={
 'status':'PASS_WITH_KNOWN_FORCED_EXIT_DIAGNOSTIC', 'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
 'godot_version':manifest['godot_version'],
 'startup':{'headless':True,'full_import_parse_entry':True,'log_directory':rel(HERE/'full-check-logs')},
 'full_project_check':{'result':'PROJECT_CHECK_OK','actual_uninterrupted_final_run':True,'log':rel(full),'log_sha256':digest(full),'total_smokes':len(smokes),'source_smokes':sum(x['type']=='source' for x in smokes),'pck_smokes':sum(x['type']=='pck' for x in smokes),'numeric_checks_sum':sum(x['checks'] or 0 for x in smokes),'smokes_without_numeric_counter':[x['script'] for x in smokes if x['checks'] is None],'smokes':smokes},
 'frozen_core':{'manifest':rel(freeze_path),'all_13_source_hashes_match':True,'sha256':freeze['sha256'],'delta_since_original_independent_probe':[path for path,sha in freeze['sha256'].items() if sha!=freeze['previous_sha256'][path]]},
 'independent_validation':{'summary':'design/danmaku-pressure-20261103/validation/acceptance_summary.json','final_b17_cadence':'design/danmaku-pressure-20261103/validation/final-after-cadence.json','final_b17_continuous_duel':'design/danmaku-pressure-20261103/validation/final-after-duel.json','source_epochs_preserved':True,'human_playtest':False},
 'presentation':{'actual_render':'artifacts/danmaku-pressure-20261103/presentation-real/real-pressure-render.json','root_review':'design/danmaku-pressure-20261103/runtime/presentation-review.json','projectile_impact_regression':'artifacts/danmaku-pressure-20261103/boss-impact-regression/report.json','actual_render_checks':218,'projectile_impact_headless_checks':11,'projectile_impact_graphical_checks':13},
 'final_fixed_input_sessions':{'eighteen_isolated_sessions':session_reports,'continuous_campaigns':campaign_summaries,'isolated_fixture_levels_are_not_a_campaign_reachability_claim':True},
 'compatibility_audit':'design/danmaku-pressure-20261103/compatibility/profile-compatibility.json',
 'regression_repair_evidence':{'enemy_runtime':'final-logs/repaired-enemy-runtime.log','combo':'final-logs/repaired-combo.log','forms':'final-logs/repaired-forms.log','chapter':'final-logs/repaired-chapter.log','combat':'final-logs/repaired-combat.log','ui':'final-logs/repaired-playable-ui.log','driver_contract':'final-logs/driver-contract.log','earlier_continuous_failure_and_explore_success':'final-logs/repaired-continuous-campaign.log','short_r4_input_success':'final-logs/repaired-continuous-short-v4.log','initial_checks':['final-logs/full-project-check-initial.log','final-logs/full-project-check-second.log','final-logs/full-project-check-third.log','final-logs/full-project-check-fourth.log']},
 'package':{'directory':rel(package),'launcher':rel(package/'run.sh'),'manifest':rel(package/'build-manifest.json'),'runtime_sha256':manifest['runtime_sha256'],'pck_sha256':manifest['pck_sha256'],'pck_bytes':manifest['pck_bytes'],'notices_and_sources':len(manifest['notices_and_licenses']),'notice_hashes_match':True,'launch_headless':True,'graphical_home_and_playing_bgm_checks':6,'graphical_ordered_unload_clean':True,'graphical_direct_forced_exit_clean':False,'forced_exit_diagnostic':{'resource':'midi_test_01.ogg / OggPacketSequence','direct_logs':['final-logs/package-launch-graphical-initial-fast-exit.log','final-logs/package-launch-graphical.log'],'prior_audio_package_reproduced':True,'control_log':'final-logs/old-audio-package-forced-quit-control-2.log','ordered_unload_log':'final-logs/package-launch-graphical-graceful.log','native_drain_seconds':.3},'functional_checks':package_checks,'test_data':'builds/linux-danmaku-pressure-20261103/test-user-data','empty_cwd':True},
 'final_integration_test_files':[{'path':path,'sha256':digest(ROOT/path)} for path in ['scripts/tests/baimen_enemy_runtime_smoke.gd','scripts/tests/boss_combo_timing_smoke.gd','scripts/tests/boss_forms_smoke.gd','scripts/tests/chronicle_chapter_two_smoke.gd','scripts/tests/chronicle_combat_smoke.gd','scripts/tests/chronicle_enemy_sessions_smoke.gd','scripts/tests/chronicle_enemy_campaign_smoke.gd','scripts/tests/chronicle_playable_ui_smoke.gd','scripts/tests/reference_walk_driver.gd','scripts/tests/chronicle_danmaku_smoke.gd','scripts/tests/chronicle_skill_audio_smoke.gd','scripts/check_project.sh']],
 'test_input_semantics':{'helper':'scripts/tests/reference_walk_driver.gd','projectile_only_is_not_instant_area':True,'actual_r4_relative_swept_paths':True,'reaction_padding_world_units':2,'continuous_campaign_resource_injection':False,'continuous_ingame_limit_seconds':450,'isolated_session_ingame_limit_seconds':360,'continuous_wall_timeout_seconds':480,'isolated_session_wall_timeout_seconds':300},
 'scope_limits':['Direct graphical quit-after exits retain an Ogg/Vorbis playback reference on some runs; reproduced in the prior audio PCK. The actual home/BGM startup and ordered scene unload with .3-second native drain pass without diagnostics.','Automated fixed-input runs and bounded PNG inspection do not establish human play balance or subjective audio quality.','Independent baseline scenarios retain their original frozen source epoch; only the B17 cadence/continuous-duel delta was independently rerun against the final core.','Logic-step timing from isolated headless probes is not a sustained rendering frame-rate claim.'],
 'protected_data_final_audit_owner':'root; see completion/audit record for player data and protected media hashes'
}
(HERE/'validation-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'status':report['status'],'smokes':len(smokes),'counted_checks':report['full_project_check']['numeric_checks_sum'],'package_checks':sum(x['checks'] for x in package_checks)}))

import concurrent.futures, json, os, re, subprocess, tempfile, time
from pathlib import Path
root=Path("/tmp/my-game-baseline-9c1472e")
logs=Path("/tmp/my-game-implementation/baseline-smokes"); logs.mkdir(parents=True, exist_ok=True)
scripts=[root/"scripts/tests"/(name+".gd") for name in ['blade_storm_build_smoke', 'boss_danmaku_stress_smoke', 'developer_catalog_smoke', 'endless_camp_smoke', 'enemy_rebirth_smoke', 'gunner_basic_level_talents_smoke', 'gunner_infinite_reload_manual_smoke', 'gunner_skill_level_effect_smoke', 'gunner_skill_talents_smoke', 'mage_arcane_charge_level_talents_smoke', 'mage_basic_level_talents_smoke', 'mage_skill_level_effect_smoke', 'mage_stage_two_three_talents_smoke', 'mage_talent_smoke', 'menu_ui_smoke', 'player_blindness_smoke', 'player_projectile_query_smoke', 'player_skill_level_system_smoke', 'reward_flow_talent_smoke', 'ruan_stone_ui_smoke', 'skill_info_ui_smoke', 'skill_level_milestone_runtime_smoke', 'skulltomb_rework_smoke', 'swordsman_advanced_talents_smoke', 'swordsman_basic_attack_event_smoke', 'swordsman_skill_talents_smoke', 'swordsman_trait_runtime_flow_smoke'] if name not in ["endless_camp_smoke", "menu_ui_smoke", "reward_flow_talent_smoke", "boss_danmaku_stress_smoke"]]

def run(p):
 env=os.environ.copy(); d=tempfile.mkdtemp(prefix="my-game-smoke-"); env.update(XDG_DATA_HOME=d+"/data",XDG_CONFIG_HOME=d+"/config")
 args=["/home/weathour/.local/bin/godot-4.6.2", "--path", str(root), "-s", str(p)]
 args+=(["--rendering-method","gl_compatibility","--display-driver","x11","--audio-driver","Dummy"] if "_render_smoke" in p.name else ["--headless"])
 t=time.monotonic()
 try:
  r=subprocess.run(args, env=env, capture_output=True,text=True,timeout=50); out=r.stdout+r.stderr; code=r.returncode
 except subprocess.TimeoutExpired as e:
  out=(e.stdout or b"").decode()+(e.stderr or b"").decode(); code=124
 (logs/(p.stem+".log")).write_text(out)
 ok=code==0 and not re.search(r"SCRIPT ERROR|Parser Error|Parse Error|Invalid call|^ERROR:",out,re.M) and re.search(r"(_OK|: (OK|PASS))$",out,re.M)!=None
 return {"name":p.stem,"ok":ok,"exit":code,"seconds":round(time.monotonic()-t,2)}
results=[]
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
 for result in pool.map(run,scripts):
  results.append(result)
  if not result["ok"]: print(result,flush=True)
(logs/"results.json").write_text(json.dumps(results,indent=2))
print({"total":len(results),"passed":sum(r["ok"] for r in results)},flush=True)

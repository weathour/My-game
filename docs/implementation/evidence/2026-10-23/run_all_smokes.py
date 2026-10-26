import concurrent.futures, json, os, re, subprocess, tempfile, time
from pathlib import Path
root=Path("/home/weathour/programs/desktop-projects/My-game")
logs=Path("/tmp/my-game-implementation/all-smokes"); logs.mkdir(parents=True, exist_ok=True)
scripts=sorted((root/"scripts/tests").glob("*_smoke.gd"))
scripts=[p for p in scripts if p.name != "dense_combat_benchmark_smoke.gd"]
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

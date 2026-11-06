#!/usr/bin/env python3
"""Reuse the existing licensed runtime packager for the isolated battle build."""
import argparse, hashlib, json, subprocess, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
p=argparse.ArgumentParser()
p.add_argument('--pck',type=Path,required=True)
p.add_argument('--output',type=Path,default=ROOT/'builds/linux-danmaku-pressure-20261103')
a=p.parse_args()
subprocess.run([sys.executable,str(ROOT/'design/skill-audio-20261103/runtime/create_local_test_build.py'),'--pck',str(a.pck),'--output',str(a.output)],check=True,stdout=subprocess.DEVNULL)
f=a.output/'build-manifest.json'; manifest=json.loads(f.read_text())
freeze=ROOT/'design/danmaku-pressure-20261103/runtime/core-freeze.json'
manifest['battle_core_sha256']=json.loads(freeze.read_text())['sha256']
manifest['battle_feedback_sha256']={str(x.relative_to(ROOT)):hashlib.sha256(x.read_bytes()).hexdigest() for x in [ROOT/'scripts/ui/chronicle/combat_feedback.gd',ROOT/'scripts/ui/chronicle/boss_feedback.gd',ROOT/'scripts/ui/chronicle/boss_camera.gd']}
manifest['battle_hurt_radius']=4
manifest['encounters']=18
manifest['b18_solo_two_form']=True
manifest['launcher_sha256']=hashlib.sha256((a.output/'run.sh').read_bytes()).hexdigest()
f.write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps({'package':str(a.output),'pck_sha256':manifest['pck_sha256'],'pck_bytes':manifest['pck_bytes'],'notices':len(manifest['notices_and_licenses'])}))

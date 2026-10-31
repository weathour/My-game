#!/usr/bin/env python3
"""Prepare isolated historical/current timing projects; execute only with --run."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    here = Path(__file__).resolve().parent
    metadata = json.loads((here.parent / "summary.json").read_text())
    inputs = json.loads((here.parent / "input-sha256.json").read_text())
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", type=Path, default=here.parents[4])
    parser.add_argument("--engine", type=Path, default=Path(metadata["engine"]))
    parser.add_argument("--run", action="store_true")
    args = parser.parse_args()
    root = args.repository.resolve()
    output = Path(tempfile.mkdtemp(prefix="my-game-melee-timing-reproduce-", dir="/tmp"))
    report = {"temporary_root": str(output), "baseline_commit": metadata["baseline_commit"], "runs": {}}
    success = True
    for mode, manifest_key, expected_key in (("baseline", "head_baseline", "head_first_damage_seconds"), ("current", "fixed", "fixed_first_damage_seconds")):
        project = output / mode
        (project / "scripts").mkdir(parents=True)
        (project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Hit timing"\n')
        for directory in ("battle", "content"):
            shutil.copytree(root / "scripts" / directory, project / "scripts" / directory)
        shutil.copy2(here / "timing.gd", project / "timing.gd")
        if mode == "baseline":
            for name in ("battle_session", "combat_mechanics", "combat_resolver"):
                relative = f"scripts/battle/{name}.gd"
                original = subprocess.check_output(["git", "-C", str(root), "show", f'{metadata["baseline_commit"]}:{relative}'])
                (project / relative).write_bytes(original)
        drift = []
        for relative, expected in inputs[manifest_key].items():
            candidate = project / relative
            actual = digest(candidate) if candidate.exists() else None
            if actual != expected:
                drift.append({"path": relative, "captured_sha256": expected, "actual_sha256": actual})
        command = [str(args.engine), "--headless", "--path", str(project), "--script", "timing.gd"]
        env = os.environ.copy()
        for variable, directory in (("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache")):
            env[variable] = str(output / f"{mode}-xdg" / directory)
        record = {"project": str(project), "command": command, "input_drift": drift}
        if args.run:
            result = subprocess.run(command, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            log = output / f"{mode}.log"
            log.write_text(result.stdout)
            natural = [json.loads(line[8:]) for line in result.stdout.splitlines() if line.startswith("NATURAL ")]
            comparison = []
            for expected in metadata["behavior_change"]["timing"]:
                actual = next((row for row in natural if row["mode"] == expected["mode"]), None)
                first_damage = actual["marks"]["first_damage"]["time"] if actual else None
                same = first_damage is not None and abs(first_damage - expected[expected_key]) < 1e-9
                comparison.append({"mode": expected["mode"], "expected_first_damage_seconds": expected[expected_key], "actual_first_damage_seconds": first_damage, "matches_capture": same})
            ok = result.returncode == 0 and "ERROR" not in result.stdout and all(row["matches_capture"] for row in comparison)
            record.update(exit_code=result.returncode, log=str(log), comparison=comparison, status="PASS" if ok else "FAIL")
            success = success and ok
        report["runs"][mode] = record
    report["engine_sha256"] = digest(args.engine)
    report["engine_matches_capture"] = report["engine_sha256"] == metadata["engine_sha256"]
    (output / "reproduction.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    return 0 if success else 1


if __name__ == "__main__":
    raise SystemExit(main())

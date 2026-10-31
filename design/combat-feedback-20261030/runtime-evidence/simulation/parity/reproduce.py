#!/usr/bin/env python3
"""Recreate the captured minimal projects under /tmp; run only with --run.

No historical runtime code is written into the repository. This helper checks
captured input hashes and reports drift; current work may legitimately differ.
The comparison.json file records the exact original version and commands.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    here = Path(__file__).resolve().parent
    metadata = json.loads((here / "comparison.json").read_text())
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", type=Path, default=here.parents[4])
    parser.add_argument("--engine", type=Path, default=Path(metadata["engine"]))
    parser.add_argument("--run", action="store_true", help="Run both generated projects after preparation")
    args = parser.parse_args()
    root = args.repository.resolve()
    output = Path(tempfile.mkdtemp(prefix="my-game-feedback-parity-reproduce-", dir="/tmp"))
    report = {"root": str(output), "baseline_commit": metadata["baseline_commit"], "modes": {}}
    for mode in ("baseline", "current"):
        project = output / mode
        (project / "scripts").mkdir(parents=True)
        (project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Feedback parity"\n')
        for directory in ("battle", "content"):
            shutil.copytree(root / "scripts" / directory, project / "scripts" / directory)
        shutil.copy2(here / "parity.gd", project / "parity.gd")
        if mode == "baseline":
            for name in ("battle_session", "combat_mechanics", "combat_resolver"):
                relative = f"scripts/battle/{name}.gd"
                original = subprocess.check_output(
                    ["git", "-C", str(root), "show", f'{metadata["baseline_commit"]}:{relative}']
                )
                (project / relative).write_bytes(original)
        captured = json.loads((here / f"{mode}-state-summary.json").read_text())
        drift = []
        for relative, expected in captured["inputs_sha256"].items():
            path = project / relative
            actual = sha256(path) if path.exists() else None
            if actual != expected:
                drift.append({"path": relative, "captured_sha256": expected, "actual_sha256": actual})
        env = os.environ.copy()
        for variable, directory in (("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache")):
            env[variable] = str(output / f"{mode}-xdg" / directory)
        command = [str(args.engine), "--headless", "--path", str(project), "--script", "parity.gd"]
        record = {"project": str(project), "command": command, "input_drift": drift}
        if args.run:
            completed = subprocess.run(command, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            log = output / f"{mode}.log"
            log.write_text(completed.stdout)
            record.update(exit_code=completed.returncode, log=str(log))
            print(completed.stdout, end="")
        report["modes"][mode] = record
    report["engine_sha256"] = sha256(args.engine)
    report["engine_matches_capture"] = report["engine_sha256"] == metadata["engine_sha256"]
    (output / "reproduction.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    if args.run:
        baseline_lines = [line for line in (output / "baseline.log").read_text().splitlines() if line.startswith("PARITY ")]
        current_lines = [line for line in (output / "current.log").read_text().splitlines() if line.startswith("PARITY ")]
        ok = baseline_lines == current_lines and len(current_lines) == 3 and all(value["exit_code"] == 0 for value in report["modes"].values())
        print("REPRODUCTION_PARITY", "PASS" if ok else "FAIL")
        return 0 if ok else 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

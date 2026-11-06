#!/usr/bin/env python3
"""Durable local validation runner; does not touch normal game/editor processes."""
from __future__ import annotations

import json
import argparse
import os
from pathlib import Path
import signal
import subprocess
import time

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
STATUS = HERE / "project-check-status.json"
LOG = HERE / "project-check.log"
state: dict = {"status": "starting", "runner_pid": os.getpid(), "started_at": time.time()}


def save() -> None:
    temporary = STATUS.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(state, indent=2) + "\n")
    temporary.replace(STATUS)


def interrupted(number: int, _frame: object) -> None:
    # The child has its own session. Preserve its PID for recovery, never kill
    # unrelated Godot processes or restart already-completed checks implicitly.
    state.update(status="runner_interrupted", runner_signal=number, interrupted_at=time.time())
    save()
    raise SystemExit(128 + number)


def main() -> None:
    global STATUS, LOG
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--name", default="project-check")
    parser.add_argument("--reuse-manifest", type=Path)
    args = parser.parse_args()
    assert args.name and all(character.isalnum() or character in "-_" for character in args.name)
    STATUS = HERE / (args.name + "-status.json")
    LOG = HERE / (args.name + ".log")
    assert (ROOT / "project.godot").is_file()
    for number in [signal.SIGTERM, signal.SIGINT]: signal.signal(number, interrupted)
    save()
    environment = os.environ.copy()
    environment["GODOT_BIN"] = "/home/weathour/.local/bin/godot-4.6.2"
    environment["PROJECT_CHECK_LOG_DIR"] = str(HERE / args.name)
    if args.reuse_manifest:
        environment["PROJECT_CHECK_REUSE_MANIFEST"] = str(args.reuse_manifest.resolve())
    state.update(name=args.name, log=str(LOG), log_directory=environment["PROJECT_CHECK_LOG_DIR"],
                 reuse_manifest=str(args.reuse_manifest.resolve()) if args.reuse_manifest else None)
    with LOG.open("w") as output:
        process = subprocess.Popen(["bash", "scripts/check_project.sh"], cwd=ROOT,
                                   env=environment, stdout=output, stderr=subprocess.STDOUT,
                                   stdin=subprocess.DEVNULL, start_new_session=True)
        state.update(status="running", child_pid=process.pid, child_pgid=process.pid)
        save()
        code = process.wait()
    state.update(status="passed" if code == 0 else "failed", returncode=code,
                 finished_at=time.time(), elapsed_seconds=time.time() - float(state["started_at"]))
    save()


if __name__ == "__main__":
    main()

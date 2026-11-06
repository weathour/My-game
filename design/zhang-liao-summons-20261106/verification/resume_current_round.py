#!/usr/bin/env python3
"""Dated B17 recovery: 34 current-round source receipts +4 same-pack +27 fresh.

The production harness remains unchanged. Its exact run_smoke function and
discovery loop execute with the same flags, limits, validator and isolated XDG.
Only this round's already completed PCK export/checks are retained separately.
"""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "scripts/tests"))
from check_project_reuse import guard, check_manifest, sha, reusable
from check_smoke_log import validate


def read(name):
    return json.loads((HERE / name).read_text())


def pack_guard():
    receipt = read("same-round-pack-receipt.json")
    pack = Path(receipt["pack"]["path"])
    assert sha(pack) == receipt["pack"]["sha256"]
    assert pack.stat().st_size == receipt["pack"]["bytes"]
    assert sha(Path(receipt["stdout"]["path"])) == receipt["stdout"]["sha256"]
    stdout = Path(receipt["stdout"]["path"]).read_text()
    for name, item in receipt["entries"].items():
        assert sha(ROOT / item["entry"]) == item["entry_sha256"]
        assert sha(Path(item["external_script"])) == item["entry_sha256"]
        assert sha(Path(item["log"])) == item["log_sha256"]
        body = Path(item["log"]).read_text()
        assert not validate(name, body)
        token = "== Godot " + name + " against isolated main pack from empty cwd ==\n" + body
        assert stdout.count(token) == 1
        assert stdout.split(token, 1)[1].startswith("== Godot ")
        # Original set -e/pipefail and the explicit failure branch establish
        # process and validator exit0 before the next heading can be emitted.
        assert item["returncode"] == 0
    return receipt


def main():
    state = {"status": "starting", "runner_pid": os.getpid(), "started_at": time.time()}
    status = HERE / "recovery-status.json"

    def save():
        temporary = status.with_suffix(".json.tmp")
        temporary.write_text(json.dumps(state, indent=2) + "\n")
        temporary.replace(status)

    save()
    try:
        baseline = read("recovery-frozen-inputs.json")
        original = read("frozen-inputs.json")
        binary = Path(baseline["godot"]["path"])
        guard(ROOT, baseline, binary)
        assert all(sha(ROOT / e) == v for e, v in baseline["entry_sha256"].items())
        assert all(sha(ROOT / f) == v for f, v in read("harness-inputs.json").items())
        changed = [e for e, v in original["entry_sha256"].items() if sha(ROOT / e) != v]
        assert changed == ["scripts/tests/chronicle_music_playback_smoke.gd"]
        manifest = read("partial-recovery-manifest.json")
        check_manifest(ROOT, manifest, binary)
        assert len(manifest["entries"]) == 34
        assert all(reusable(ROOT, manifest, entry)[0] for entry in manifest["entries"])
        receipt = pack_guard()
        source = (ROOT / "scripts/check_project.sh").read_text()
        function = source.split("  run_smoke() {\n", 1)[1].split("\n  run_pack_smokes() {", 1)[0]
        function = "  run_smoke() {\n" + function
        loop = "  for smoke in scripts/tests/*_smoke.gd; do\n" + source.split("  for smoke in scripts/tests/*_smoke.gd; do\n", 1)[1].split("\n  done", 1)[0] + "\n  done\n"
        scratch = Path(tempfile.mkdtemp(prefix="liao-current-round-recovery-"))
        logdir = HERE / "recovery-logs"
        logdir.mkdir(exist_ok=False)
        generated = scratch / "run-source-recovery.sh"
        # Paths are local task-owned constants, quoted with shlex rather than
        # interpolated through a shell-escaping surrogate.
        import shlex
        q = shlex.quote
        generated.write_text("#!/usr/bin/env bash\nset -euo pipefail\nROOT=" + q(str(ROOT)) +
            "\ncd \"$ROOT\"\nGODOT_BIN=" + q(str(binary)) + "\nCHECK_DATA_DIR=" + q(str(scratch)) +
            "\nCHECK_LOG_DIR=" + q(str(logdir)) + "\nexport XDG_DATA_HOME=\"$CHECK_DATA_DIR/data\"\n" +
            "export XDG_CONFIG_HOME=\"$CHECK_DATA_DIR/config\"\nexport PYTHONDONTWRITEBYTECODE=1\n" +
            "python3 scripts/tests/check_project_reuse.py check --manifest \"$PROJECT_CHECK_REUSE_MANIFEST\" --godot \"$GODOT_BIN\"\n" +
            "python3 scripts/tests/check_project_reuse.py self-test\n" + function + "\n" + loop +
            "echo '== Godot current round source recovery completed =='\n" +
            "python3 scripts/tests/check_project_reuse.py check --manifest \"$PROJECT_CHECK_REUSE_MANIFEST\" --godot \"$GODOT_BIN\"\n" +
            "echo CURRENT_ROUND_RECOVERY_OK\n")
        env = os.environ.copy()
        env["PROJECT_CHECK_REUSE_MANIFEST"] = str(HERE / "partial-recovery-manifest.json")
        state.update(status="running", source_cache_count=34, same_pack_count=4,
                     source_fresh_count=27, log_directory=str(logdir),
                     stdout=str(HERE / "recovery.log"), derived_script=str(generated),
                     derived_script_sha256=sha(generated),
                     exact_function_sha256=hashlib.sha256(function.encode()).hexdigest(),
                     exact_loop_sha256=hashlib.sha256(loop.encode()).hexdigest(),
                     manifest_sha256=sha(HERE / "partial-recovery-manifest.json"),
                     formal_pack=receipt["pack"], production_harness_unchanged=True)
        save()
        with (HERE / "recovery.log").open("w") as output:
            process = subprocess.Popen(["bash", str(generated)], cwd=ROOT, env=env,
                stdin=subprocess.DEVNULL, stdout=output, stderr=subprocess.STDOUT,
                start_new_session=True)
            state["child_pid"] = process.pid
            save()
            code = process.wait()
        guard(ROOT, baseline, binary)
        assert all(sha(ROOT / e) == v for e, v in baseline["entry_sha256"].items())
        assert all(sha(ROOT / f) == v for f, v in read("harness-inputs.json").items())
        check_manifest(ROOT, manifest, binary)
        pack_guard()
        state.update(status="passed" if code == 0 else "failed", returncode=code,
                     finished_at=time.time(), elapsed_seconds=time.time() - state["started_at"])
        save()
    except Exception as error:
        state.update(status="failed", exception=repr(error), finished_at=time.time())
        save()
        raise


if __name__ == "__main__":
    main()

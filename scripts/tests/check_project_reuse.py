#!/usr/bin/env python3
"""Optional, hash-guarded recovery of strictly validated source smoke results.

This never caches import/startup/Python/export/PCK checks. A historical stdout
must show that the shell advanced past an exact log body: a PASS line alone
cannot establish a successful process exit. The owner must freeze inputs before
building a cache and establish that they are the inputs of that historical run.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
import time

from check_smoke_log import validate

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ("scripts/check_project.sh", "scripts/tests/check_project_reuse.py")
PACKS = {f"chronicle_{name}_pack_smoke" for name in ("enemy", "music", "story", "combat_feedback")}


def sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def object_sha(value: object) -> str:
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def inputs(root: Path) -> dict:
    entries = sorted(p.relative_to(root).as_posix() for p in (root / "scripts/tests").glob("*_smoke.gd"))
    files = []
    for base in ("assets", "scenes", "effects", "scripts", "addons"):
        for path in (root / base).rglob("*"):
            if not path.is_file() or any(part in {".godot", "__pycache__"} for part in path.parts):
                continue
            if path.suffix in {".import", ".uid", ".pyc"}:
                continue
            relative = path.relative_to(root).as_posix()
            # Test entry content is guarded separately. Common test helpers,
            # validator, runtime scripts and resource bytes are global inputs.
            if relative not in TOOLS and relative not in entries:
                files.append(path)
    for path in root.iterdir():
        if path.is_file() and path.suffix in {".godot", ".cfg", ".svg", ".gd", ".tscn", ".tres", ".json", ".png", ".wav", ".ogg"}:
            files.append(path)
    return {"inputs": {p.relative_to(root).as_posix(): sha(p) for p in sorted(files)}, "smoke_entries": entries}


def freeze(root: Path, godot: Path) -> dict:
    snapshot = inputs(root)
    return {"schema": 1, "root": str(root), "captured_at": time.time(), **snapshot,
            "input_sha256": object_sha(snapshot),
            "entry_sha256": {entry: sha(root / entry) for entry in snapshot["smoke_entries"]},
            "godot": {"path": str(godot.resolve()), "sha256": sha(godot)}}


def guard(root: Path, baseline: dict, godot: Path) -> None:
    if baseline["schema"] != 1 or baseline["root"] != str(root):
        raise ValueError("schema/root mismatch")
    recorded = {key: baseline[key] for key in ("inputs", "smoke_entries")}
    if object_sha(recorded) != baseline["input_sha256"]:
        raise ValueError("manifest input digest is inconsistent")
    current = inputs(root)
    if current != recorded:
        changed = sorted(set(recorded["inputs"]) ^ set(current["inputs"]) | {
            name for name in recorded["inputs"].keys() & current["inputs"].keys()
            if recorded["inputs"][name] != current["inputs"][name]})
        raise ValueError("frozen inputs changed: " + ", ".join(changed[:12]) +
                         ("; smoke entry inventory changed" if current["smoke_entries"] != recorded["smoke_entries"] else ""))
    if {"path": str(godot.resolve()), "sha256": sha(godot)} != baseline["godot"]:
        raise ValueError("Godot binary changed")


def completed_in_stdout(name: str, body: str, stdout: str) -> bool:
    heading = "== Godot " + name.replace("_", " ") + " ==\n"
    # check_project.sh uses set -e/pipefail, validates each completed command,
    # then emits the next heading. Exact body matching ties the exit evidence
    # to this log, rather than another run's same-named test.
    token = heading + body
    if not token.endswith("\n"):
        token += "\n"
    start = stdout.find(token)
    if start < 0 or stdout.find(token, start + 1) >= 0:
        return False
    remainder = stdout[start + len(token):]
    return remainder.startswith("== Godot ") or remainder.startswith("== graphify ")


def build(root: Path, baseline: dict, godot: Path, log_dir: Path, stdout_path: Path) -> dict:
    guard(root, baseline, godot)
    stdout = stdout_path.read_text(errors="replace")
    entries, excluded = {}, {}
    for script in baseline["smoke_entries"]:
        name = Path(script).stem
        if name in PACKS:
            continue
        log = (log_dir / (name + ".log")).resolve()
        if sha(root / script) != baseline["entry_sha256"][script]:
            excluded[script] = "entry changed since freeze"
        elif not log.is_file():
            excluded[script] = "missing log"
        else:
            body = log.read_text(errors="replace")
            errors = validate(name, body)
            if errors:
                excluded[script] = "strict validator: " + "; ".join(errors)
            elif not completed_in_stdout(name, body, stdout):
                excluded[script] = "no exact successful command/validator completion evidence in stdout"
            else:
                entries[script] = {"script_sha256": sha(root / script), "log": str(log), "log_sha256": sha(log)}
    return {"schema": 1, "created_at": time.time(), "baseline": baseline,
            "recovery_tools": {tool: sha(root / tool) for tool in TOOLS},
            "stdout": {"path": str(stdout_path.resolve()), "sha256": sha(stdout_path)},
            "entries": entries, "excluded": excluded}


def check_manifest(root: Path, manifest: dict, godot: Path) -> None:
    if manifest["schema"] != 1:
        raise ValueError("unsupported manifest schema")
    guard(root, manifest["baseline"], godot)
    if manifest["recovery_tools"] != {tool: sha(root / tool) for tool in TOOLS}:
        raise ValueError("recovery harness changed; rebuild manifest after review")
    source = manifest["stdout"]
    if sha(Path(source["path"])) != source["sha256"]:
        raise ValueError("historical stdout changed; preserve original evidence")


def reusable(root: Path, manifest: dict, script: str) -> tuple[bool, str]:
    entry = manifest["entries"].get(script)
    if entry is None:
        return False, "no validated cache entry"
    if Path(script).stem in PACKS or script not in manifest["baseline"]["smoke_entries"]:
        return False, "not an eligible source smoke"
    if entry["script_sha256"] != manifest["baseline"]["entry_sha256"][script]:
        return False, "entry digest disagrees with frozen baseline"
    if sha(root / script) != entry["script_sha256"]:
        return False, "test entry changed"
    log = Path(entry["log"])
    if not log.is_file() or sha(log) != entry["log_sha256"]:
        return False, "original log missing/changed"
    body = log.read_text(errors="replace")
    if validate(Path(script).stem, body):
        return False, "strict validator rejected log"
    stdout = Path(manifest["stdout"]["path"]).read_text(errors="replace")
    if not completed_in_stdout(Path(script).stem, body, stdout):
        return False, "successful command completion evidence missing"
    return True, str(log)


def write_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")


def self_test() -> None:
    # Fixtures never touch real runtime inputs or historical logs.
    checks = []
    with tempfile.TemporaryDirectory(prefix="project-check-reuse-test-") as temporary:
        root = Path(temporary)
        for name in ("scripts/tests", "assets", "scenes", "effects", "addons", "logs"):
            (root / name).mkdir(parents=True)
        for tool in TOOLS:
            (root / tool).write_text("harness\n")
        script = "scripts/tests/fixture_smoke.gd"
        bad_script = "scripts/tests/failed_smoke.gd"
        (root / script).write_text("fixture\n")
        (root / bad_script).write_text("fixture failed\n")
        (root / "scripts/tests/common.gd").write_text("helper\n")
        (root / "project.godot").write_text("config_version=5\n")
        godot = root / "fake-engine"
        godot.write_text("engine fixture\n")
        body = "FIXTURE_SMOKE PASS checks=2 failures=0\n"
        log = root / "logs/fixture_smoke.log"
        log.write_text(body)
        (root / "logs/failed_smoke.log").write_text("FAILED_SMOKE PASS\nERROR: leaked resource\n")
        stdout = root / "stdout.log"
        stdout.write_text("== Godot fixture smoke ==\n" + body + "== Godot failed smoke ==\nFAILED_SMOKE PASS\nERROR: leaked resource\n")
        baseline = freeze(root, godot)
        manifest = build(root, baseline, godot, root / "logs", stdout)
        check_manifest(root, manifest, godot)
        assert reusable(root, manifest, script)[0]
        checks.append("matching_cache_accepted")
        assert bad_script not in manifest["entries"]
        checks.append("failed_log_excluded")
        forged_entry = copy.deepcopy(manifest)
        forged_entry["entries"][script]["script_sha256"] = "0" * 64
        assert not reusable(root, forged_entry, script)[0]
        checks.append("tampered_entry_digest_reruns")
        altered = copy.deepcopy(manifest)
        altered["baseline"]["inputs"]["project.godot"] = "0" * 64
        try:
            check_manifest(root, altered, godot)
        except ValueError:
            checks.append("tampered_manifest_digest_rejected")
        else:
            raise AssertionError("tampered manifest accepted")
        (root / script).write_text("changed entry\n")
        check_manifest(root, manifest, godot)
        assert not reusable(root, manifest, script)[0]
        (root / script).write_text("fixture\n")
        checks.append("changed_entry_reruns")
        log.write_text(body + "changed\n")
        assert not reusable(root, manifest, script)[0]
        log.write_text(body)
        checks.append("changed_log_reruns")
        (root / "scripts/tests/common.gd").write_text("changed helper\n")
        try:
            check_manifest(root, manifest, godot)
        except ValueError:
            checks.append("changed_global_helper_rejected")
        else:
            raise AssertionError("changed global helper accepted")
        assert not completed_in_stdout("fixture_smoke", body, "== Godot fixture smoke ==\n" + body + "FIXTURE_SMOKE_FAILED\n")
        checks.append("nonzero_exit_pass_not_accepted")
        assert not completed_in_stdout("fixture_smoke", body, "== Godot fixture smoke ==\n" + body)
        checks.append("unproven_exit_not_accepted")
    print(json.dumps({"status": "PASS", "checks": checks}, indent=2))
    print("PROJECT_CHECK_REUSE_SELF_TEST_OK")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("freeze", "build", "check", "reuse", "self-test"))
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--godot", type=Path, default=Path(os.environ.get("GODOT_BIN", shutil.which("godot") or "/home/weathour/.local/bin/godot-4.6.2")))
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--manifest", type=Path)
    parser.add_argument("--log-dir", type=Path)
    parser.add_argument("--stdout", type=Path)
    parser.add_argument("--script")
    parser.add_argument("--output-log", type=Path)
    args = parser.parse_args()
    root = args.root.resolve()
    try:
        if args.command == "self-test":
            self_test()
        elif args.command == "freeze":
            write_json(args.baseline, freeze(root, args.godot))
        elif args.command == "build":
            baseline = json.loads(args.baseline.read_text())
            manifest = build(root, baseline, args.godot, args.log_dir, args.stdout)
            write_json(args.manifest, manifest)
            print(f"PROJECT_CHECK_REUSE_CACHE_BUILT entries={len(manifest['entries'])} excluded={len(manifest['excluded'])}")
        else:
            manifest = json.loads(args.manifest.read_text())
            check_manifest(root, manifest, args.godot)
            if args.command == "check":
                print(f"PROJECT_CHECK_REUSE_GUARD_OK entries={len(manifest['entries'])}")
            else:
                accepted, detail = reusable(root, manifest, args.script)
                if not accepted:
                    print(f"PROJECT_CHECK_REUSE_MISS script={args.script} reason={detail}")
                    return 3
                source = Path(detail)
                if args.output_log.resolve() != source.resolve():
                    shutil.copyfile(source, args.output_log)
                print(f"REUSED_VALIDATED_SMOKE script={args.script} original_log={source} sha256={sha(source)}")
                print(source.read_text(errors="replace"), end="")
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"PROJECT_CHECK_REUSE_GUARD_FAILED: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

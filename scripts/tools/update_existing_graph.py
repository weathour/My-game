#!/usr/bin/env python3
"""Keep the last usable graph if the installed extractor drops Godot sources."""
from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
from pathlib import Path


def supports_godot(root: Path) -> bool:
    try:
        from graphify.detect import CODE_EXTENSIONS
        from graphify.extract import _get_extractor
        return ".gd" in CODE_EXTENSIONS and _get_extractor(root / "scripts/main.gd") is not None
    except (ImportError, AttributeError):
        return False


def update(root: Path) -> bool:
    directory = root / "graphify-out"
    if not (directory / "graph.json").is_file():
        return True  # This command never creates an index.
    required = {
        path.relative_to(root).as_posix()
        for path in (root / "scripts").rglob("*.gd")
        if path.relative_to(root / "scripts").parts[0] not in {"tests", "tools"}
    }
    accepted = False
    reason = "update interrupted"
    with tempfile.TemporaryDirectory(prefix="mygame-graph-backup-") as backup_path:
        backup = Path(backup_path)
        original = {path.name for path in directory.iterdir() if path.is_file()}
        for name in original:
            shutil.copy2(directory / name, backup / name)
        try:
            result = subprocess.run(["graphify", "update", "."], cwd=root, check=False)
            graph = json.loads((directory / "graph.json").read_text())
            covered = {
                str(node.get("source_file", "")).removeprefix(str(root) + "/").removeprefix("res://")
                for node in graph.get("nodes", [])
            }
            missing = sorted(required - covered)
            extractor_available = supports_godot(root)
            accepted = result.returncode == 0 and extractor_available and not missing
            reason = f"exit={result.returncode}; Godot extractor={extractor_available}; missing {len(missing)} runtime GDScript files"
            print(json.dumps({"graph_update_accepted": accepted, "reason": reason, "missing": missing}, ensure_ascii=False))
        except (OSError, ValueError) as error:
            reason = str(error)
        finally:
            if accepted:
                (directory / ".needs_update").unlink(missing_ok=True)
            else:
                for path in directory.iterdir():
                    if path.is_file() and path.name not in original:
                        path.unlink()
                for name in original:
                    shutil.copy2(backup / name, directory / name)
                warning = "STALE: Graphify update rejected (" + reason + "). Prior graph retained; current source and docs/08 are authoritative."
                (directory / ".needs_update").write_text(warning + "\n")
                report = directory / "GRAPH_REPORT.md"
                if report.exists():
                    text = report.read_text()
                    if text.startswith("> STALE: Graphify update rejected ("):
                        text = text.split("\n\n", 1)[-1]
                    report.write_text("> " + warning + "\n\n" + text)
                print("GRAPHIFY_UPDATE_REJECTED: " + reason)
    return accepted


if __name__ == "__main__":
    # Graph navigation is optional for the runtime gate; stale output is explicit.
    update(Path(__file__).resolve().parents[2])

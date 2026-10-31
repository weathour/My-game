#!/usr/bin/env python3
import json
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from update_existing_graph import update

with tempfile.TemporaryDirectory() as temp:
    root = Path(temp)
    (root / "scripts").mkdir()
    (root / "scripts/new.gd").write_text("extends Node\n")
    graph = root / "graphify-out"
    graph.mkdir()
    original = b'{"nodes": [{"source_file": "scripts/old.gd"}]}'
    (graph / "graph.json").write_bytes(original)
    (graph / "GRAPH_REPORT.md").write_text("# Prior graph\n")
    (graph / "manifest.json").write_text("prior manifest")

    def partial_update(*args, **kwargs):
        (graph / "graph.json").write_text('{"nodes": []}')
        (graph / "manifest.json").write_text("partial manifest")
        return type("Result", (), {"returncode": 0})()

    with patch("update_existing_graph.subprocess.run", side_effect=partial_update), patch("update_existing_graph.supports_godot", return_value=True):
        assert not update(root)
    assert (graph / "graph.json").read_bytes() == original
    assert (graph / "manifest.json").read_text() == "prior manifest"
    assert "STALE" in (graph / "GRAPH_REPORT.md").read_text()
    assert (graph / ".needs_update").exists()

    def covered_update(*args, **kwargs):
        (graph / "graph.json").write_text(json.dumps({"nodes": [{"source_file": "scripts/new.gd"}]}))
        return type("Result", (), {"returncode": 0})()

    # Retained old nodes alone must not count as current Godot extraction.
    with patch("update_existing_graph.subprocess.run", side_effect=covered_update), patch("update_existing_graph.supports_godot", return_value=False):
        assert not update(root)
    assert (graph / "graph.json").read_bytes() == original
    with patch("update_existing_graph.subprocess.run", side_effect=covered_update), patch("update_existing_graph.supports_godot", return_value=True):
        assert update(root)
    assert "scripts/new.gd" in (graph / "graph.json").read_text()
    assert not (graph / ".needs_update").exists()

print("GRAPH_UPDATE_SELF_TEST_OK")

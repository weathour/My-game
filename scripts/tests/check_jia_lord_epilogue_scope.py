#!/usr/bin/env python3
"""Read-only comparison with the previous formally validated campaign PCK data."""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "design/jia-lord-epilogue-20261106/verification/baseline-data"
DATA = ROOT / "assets/data/chronicle"
TEXT_EDITS = {"s14_02", "s14_n02", "s14_n13"}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path: Path) -> object:
    return json.loads(path.read_text())


def inspect() -> dict:
    provenance = read(BASE / "provenance.json")
    for name, digest in provenance["files_match_prior_frozen_source_sha256"].items():
        assert sha(BASE / name) == digest, (name, "independent baseline changed")
    old = read(BASE / "story_events.json")
    current = read(DATA / "story_events.json")
    assert set(old) == set(current) and len(current) == 22
    assert all(old[key] == current[key] for key in old if key != "S14"), "unrelated main story changed"
    prefix, lines = old["S14"]["lines"], current["S14"]["lines"]
    assert len(prefix) == 20 and len(lines) == 58
    assert [line["id"] for line in lines[:20]] == [line["id"] for line in prefix]
    assert [line["id"] for line in lines[20:]] == [f"s14_lord_{index:02}" for index in range(1, 39)]
    actual_text_edits = set()
    for before, after in zip(prefix, lines):
        normalized = copy.deepcopy(after)
        for actor in normalized.get("actors", []):
            if actor["id"] == "JIA":
                assert actor.pop("appearance", None) == "campaign", after["id"]
        if before["text"] != normalized["text"]:
            assert before["id"] in TEXT_EDITS, (before["id"], "unapproved old-line text edit")
            actual_text_edits.add(before["id"])
            normalized["text"] = before["text"]
        assert before == normalized, (before["id"], "old-line fields changed outside approval")
    assert actual_text_edits == TEXT_EDITS
    assert {key: value for key, value in old["S14"].items() if key != "lines"} == {key: value for key, value in current["S14"].items() if key != "lines"}
    route, route_new = read(BASE / "route.json"), read(DATA / "route.json")
    assert len(route_new) == 36 and sum(node["kind"] in ("battle", "elite", "boss") for node in route_new) == 18
    normalized = copy.deepcopy(route_new)
    for before, after in zip(route, normalized):
        if before["id"] == "S14":
            for key in ("summary", "map_summary"):
                assert isinstance(after[key], str) and after[key].strip()
                after[key] = before[key]
    assert normalized == route, "route topology or unrelated route data changed"
    optional, optional_new = read(BASE / "character_events.json"), read(DATA / "character_events.json")
    assert len(optional_new) == 32 and set(optional_new) == set(optional)
    normalized = copy.deepcopy(optional_new)
    assert normalized["CE22"].pop("jia_appearance") == "lord_formal"
    assert normalized["CE23"].pop("jia_appearance") == "lord_casual"
    changes = 0
    for before, after in zip(optional["CE23"]["lines"], normalized["CE23"]["lines"]):
        for actor_before, actor_after in zip(before.get("actors", []), after.get("actors", [])):
            if actor_after["id"] == "JIA":
                assert actor_after["expression"] == "laugh"
                actor_after["expression"] = actor_before["expression"]
                changes += 1
    assert changes == 5 and normalized == optional, "optional-story speech or unrelated fields changed"
    assert all(actor["id"] != "JIA" for key in ("CE21", "CE24") for line in optional_new[key]["lines"] for actor in line.get("actors", []))
    reactions, reactions_new = read(BASE / "story_reactions.json"), read(DATA / "story_reactions.json")
    assert len(reactions) == 48 and len(reactions_new) == 49
    assert set(reactions_new) - set(reactions) == {"RX_S14_LORD_01"}
    assert all(reactions[key] == reactions_new[key] for key in reactions)
    reaction = reactions_new["RX_S14_LORD_01"]
    assert reaction["event_id"] == "S14" and reaction["after_line"] == "s14_lord_33"
    assert reaction["conditions"] == {"owned_all": ["F11"], "alive_all": ["F11"]}
    copies = read(ROOT / "design/jia-lord-combat-20261105/qa/lord-forms-20261106/source-copies.json")
    assert len(copies) == 4
    textures = []
    for item in copies:
        source, runtime = ROOT / item["source"], ROOT / item["runtime"]
        assert sha(source) == sha(runtime) == item["sha256"]
        with Image.open(runtime) as image:
            assert image.mode == "RGBA" and image.size == (1024, 1536)
        textures.append({"path": item["runtime"], "sha256": item["sha256"]})
    for name in ("lord-hall", "lord-chamber"):
        path = ROOT / f"assets/story/chronicle/{name}.png"
        with Image.open(path) as image:
            assert image.size == (1536, 864) and image.mode in ("RGB", "RGBA")
            if image.mode == "RGBA": assert image.getchannel("A").getextrema() == (255, 255)
        textures.append({"path": path.relative_to(ROOT).as_posix(), "sha256": sha(path)})
    return {"status": "passed", "baseline_pack_sha256": provenance["pack_sha256"], "old_s14_ids": [line["id"] for line in prefix], "old_line_text_edits": sorted(actual_text_edits), "appended_lines": 38, "route_nodes": 36, "battle_nodes": 18, "optional_events": 32, "unchanged_prior_reactions": 48, "reactions": 49, "runtime_images": textures}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    result = inspect()
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(result, indent=2) + "\n")
    print("JIA_LORD_EPILOGUE_SCOPE_OK old_lines=20 new_lines=38 optional=32 reactions=49 images=6")


if __name__ == "__main__":
    main()

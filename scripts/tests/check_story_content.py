#!/usr/bin/env python3
"""Fast structural guard for the shipped Chronicle campaign story data."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "assets/data/chronicle"

def read(name: str):
    return json.loads((DATA / name).read_text(encoding="utf-8"))

def main() -> int:
    route = read("route.json")
    events = read("story_events.json")
    optional = read("character_events.json")
    reactions = read("story_reactions.json")
    lore = read("story_lore.json")
    characters = read("characters.json")
    ids = {str(node["id"]) for node in route}
    failures = []
    if len(route) != 36 or len(ids) != 36: failures.append("route must contain 36 unique Chronicle nodes")
    if len(events) != 22: failures.append("main story catalog must cover the 22 authored story nodes")
    if len(optional) != 32: failures.append("character-story catalog must contain 32 authored events")
    if len(reactions) != 49: failures.append("conditional reaction catalog must contain 49 entries")
    if not lore: failures.append("read-only lore catalog must not be empty")
    known = {str(person["id"]) for person in characters}
    for group_name, group in (("main", events), ("optional", optional)):
        for key, event in group.items():
            if event.get("id") != key or not event.get("lines"):
                failures.append(f"{group_name} story identity/lines invalid: {key}")
            for line in event.get("lines", []):
                speaker = line.get("speaker", "")
                if speaker and speaker not in known:
                    failures.append(f"unknown speaker {speaker} in {key}/{line.get('id', '')}")
    if failures:
        print("CHRONICLE_STORY_CONTENT_CHECK_FAILED")
        print("\n".join(failures))
        return 1
    print("CHRONICLE_STORY_CONTENT_CHECK_OK")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

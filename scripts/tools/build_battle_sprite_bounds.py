#!/usr/bin/env python3
"""Record exact alpha bounds before import, avoiding runtime GPU readbacks."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "assets/data/chronicle/battle_sprite_bounds.json"


def build() -> dict:
    sheets: dict[Path, tuple[int, int, int]] = {}
    manifests = sorted((ROOT / "assets/enemies/baimen").glob("*/manifest.json"))
    manifests += sorted((ROOT / "assets/players/chronicle-cast").glob("*/manifest.json"))
    campaign_manifest = ROOT / "assets/players/jia-campaign/manifest.json"
    if campaign_manifest.exists():
        manifests.append(campaign_manifest)
    for manifest in manifests:
        data = json.loads(manifest.read_text())
        for name, clip in data.get("clips", {}).items():
            width, height = clip["frame_size"]
            sheets[manifest.parent / clip.get("file", name + ".png")] = (
                width, height, clip["frames"]
            )
    for weapon in ("dao", "spear"):
        for clip, count in (("idle", 4), ("run", 8), ("attack", 4)):
            sheets[ROOT / f"assets/players/jia/{weapon}-{clip}.png"] = (192, 192, count)
    for identity in range(2, 11):
        for clip, count in (("idle", 4), ("run", 8), ("attack", 4), ("cast", 4)):
            sheets[ROOT / f"assets/players/baimen-women/F{identity:02}/{clip}.png"] = (192, 192, count)

    entries = {}
    for path, (width, height, count) in sorted(sheets.items()):
        with Image.open(path) as image:
            assert image.size == (width * count, height), f"Unexpected sheet size: {path}"
            alpha = image.convert("RGBA").getchannel("A")
            regions = {}
            for index in range(count):
                region = (index * width, 0, width, height)
                bounds = alpha.crop((region[0], 0, region[0] + width, height)).getbbox()
                regions[",".join(map(str, region))] = (
                    [bounds[0], bounds[1], bounds[2] - bounds[0], bounds[3] - bounds[1]]
                    if bounds else [0, 0, 0, 0]
                )
            bounds = alpha.getbbox()
            regions[f"0,0,{image.width},{image.height}"] = (
                [bounds[0], bounds[1], bounds[2] - bounds[0], bounds[3] - bounds[1]]
                if bounds else [0, 0, 0, 0]
            )
            entries["res://" + path.relative_to(ROOT).as_posix()] = {
                "size": list(image.size),
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                "regions": regions,
            }
    return {"version": 1, "alpha_threshold": 0, "textures": entries}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Fail if the checked-in table is stale")
    args = parser.parse_args()
    expected = build()
    if args.check:
        if not OUTPUT.exists() or json.loads(OUTPUT.read_text()) != expected:
            raise SystemExit("BATTLE_SPRITE_BOUNDS_STALE: run scripts/tools/build_battle_sprite_bounds.py")
    else:
        OUTPUT.write_text(json.dumps(expected, ensure_ascii=False, separators=(",", ":")) + "\n")
    print(f"BATTLE_SPRITE_BOUNDS_OK textures={len(expected['textures'])} "
          f"regions={sum(len(item['regions']) for item in expected['textures'].values())}")


if __name__ == "__main__":
    main()

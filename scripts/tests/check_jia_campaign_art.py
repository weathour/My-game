#!/usr/bin/env python3
"""Read-only checks of the approved campaign Jia runtime exports and alpha table."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "assets/players/jia-campaign"
CLIPS = {"idle": 4, "run": 8, "attack": 4, "sweep": 4, "break": 4}


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def inspect() -> dict:
    manifest = json.loads((ART / "manifest.json").read_text())
    assert manifest.get("body_height_px") == 80 and manifest.get("anchor_px") == [128, 236] and manifest.get("foot_anchor") == [128, 236], "manifest body/anchor contract differs from approved measurements"
    table = json.loads((ROOT / "assets/data/chronicle/battle_sprite_bounds.json").read_text())["textures"]
    colors: set[tuple[int, int, int]] = set()
    frames: list[dict] = []
    sheets: list[dict] = []
    seen: dict[str, str] = {}
    for weapon in ("dao", "spear"):
        for clip, count in CLIPS.items():
            path = ART / f"{weapon}-{clip}.png"
            raw = path.read_bytes()
            key = "res://" + path.relative_to(ROOT).as_posix()
            with Image.open(path) as image:
                assert image.mode == "RGBA", (path, image.mode)
                assert image.size == (256 * count, 256), (path, image.size)
                alpha = image.getchannel("A")
                assert set(alpha.getdata()) == {0, 255}, (path, "runtime alpha must be binary")
                colors.update(pixel[:3] for pixel in image.getdata() if pixel[3])
                assert key in table, (path, "missing precomputed alpha metadata")
                entry = table[key]
                assert entry["sha256"] == digest(raw), (path, "stale alpha metadata SHA")
                assert entry["size"] == list(image.size), (path, "stale alpha metadata size")
                for index in range(count):
                    frame = image.crop((256 * index, 0, 256 * (index + 1), 256))
                    bounds = frame.getchannel("A").getbbox()
                    label = f"{weapon}-{clip}:{index}"
                    assert bounds is not None, (label, "empty pose")
                    assert 0 < bounds[0] < bounds[2] < 256 and 0 < bounds[1] < bounds[3] < 256, (label, "opaque pixels touch frame edge", bounds)
                    frame_hash = digest(frame.tobytes())
                    assert frame_hash not in seen, (label, "duplicate pose pixels", seen.get(frame_hash))
                    seen[frame_hash] = label
                    region = f"{256 * index},0,256,256"
                    expected = [bounds[0], bounds[1], bounds[2] - bounds[0], bounds[3] - bounds[1]]
                    assert entry["regions"].get(region) == expected, (label, "metadata differs from source alpha")
                    frames.append({"clip": f"{weapon}-{clip}", "frame": index, "alpha_bounds": list(bounds), "rgba_sha256": frame_hash})
                if clip in ("attack", "sweep", "break"):
                    assert manifest["clips"][f"{weapon}-{clip}"]["contact_frame"] == 1, (path, "contact order differs from approved frame 1")
                sheets.append({"path": path.relative_to(ROOT).as_posix(), "size": list(image.size), "sha256": digest(raw)})
    assert len(frames) == len(seen) == 48
    assert len(colors) <= 64, ("shared runtime actor palette exceeds approved limit", len(colors))
    # The independent portrait has its own palette; it is not counted as a
    # combat pose or manufactured by cropping a runtime animation sheet.
    portrait = ART / "campaign-head.png"
    with Image.open(portrait) as image:
        assert image.mode == "RGBA" and image.size == (128, 128), (portrait, image.mode, image.size)
        assert set(image.getchannel("A").getdata()) == {0, 255}, (portrait, "portrait alpha must be binary")
        portrait_bounds = image.getchannel("A").getbbox()
        assert portrait_bounds is not None
        portrait_colors = len({pixel[:3] for pixel in image.getdata() if pixel[3]})
        assert portrait_colors <= 64, (portrait, "independent portrait palette exceeds 64 colors", portrait_colors)
    editable = []
    for stem, count, dimensions in [(f"{weapon}-{clip}", count, (256, 256)) for weapon in ("dao", "spear") for clip, count in CLIPS.items()] + [("actor", 48, (256, 256)), ("campaign-head", 1, (128, 128))]:
        path = ART / (stem + ".aseprite")
        header = path.read_bytes()[:128]
        magic, actual_count, width, height, depth = struct.unpack_from("<5H", header, 4)
        # Indexed Aseprite is the natural editable representation of the
        # approved shared palette. Exported runtime PNGs above must be RGBA.
        assert magic == 0xA5E0 and actual_count == count and (width, height) == dimensions and depth in (8, 32), (path, "editable source header", magic, actual_count, width, height, depth)
        editable.append({"path": path.relative_to(ROOT).as_posix(), "frames": actual_count, "size": [width, height], "color_depth": depth, "sha256": digest(path.read_bytes())})
    standing = ROOT / "assets/ui/chronicle/characters/JIA-campaign-standing.png"
    with Image.open(standing) as image:
        assert image.mode == "RGBA" and image.size == (1024, 1536), (standing, image.mode, image.size)
        assert 0 in image.getchannel("A").getextrema(), (standing, "standing master has no transparency")
        standing_size = list(image.size)
    assert digest(standing.read_bytes()) == digest((ROOT / "design/jia-lord-combat-20261105/jia-lord-campaign-v2.png").read_bytes()), "UI standing must retain the approved master bytes"
    return {"status": "passed", "expected_body_height_px": 80, "expected_foot_anchor": [128, 236], "expected_world_body_height": 72,
            "combat_poses": len(frames), "actor_palette_colors": len(colors), "sheets": sheets,
            "portrait": {"path": portrait.relative_to(ROOT).as_posix(), "sha256": digest(portrait.read_bytes()), "alpha_bounds": list(portrait_bounds), "palette_colors": portrait_colors},
            "standing": {"path": standing.relative_to(ROOT).as_posix(), "sha256": digest(standing.read_bytes()), "size": standing_size}, "editable_sources": editable, "frames": frames}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    result = inspect()
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(result, indent=2) + "\n")
    print(f"JIA_CAMPAIGN_ART_CHECK_OK poses={result['combat_poses']} colors={result['actor_palette_colors']} sheets={len(result['sheets'])}")


if __name__ == "__main__":
    main()

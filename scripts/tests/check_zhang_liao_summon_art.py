#!/usr/bin/env python3
"""Read-only audit of the authored B17 command/apparition strips and bounds."""
from __future__ import annotations

import argparse
import hashlib
import json
import struct
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
FOLDER = ROOT / "assets/enemies/baimen/zhang_liao_summons"
EXPECTED = {
    **{(identity, role): (6, 3, 3) for identity in ("B17_human", "B17")
       for role in ("order_gaoshun", "order_chengong")},
    **{(identity, "gaoshun"): (8, 4, 4) for identity in ("M03_human", "M03_WAR")},
    **{(identity, "chengong"): (10, 5, 7) for identity in ("M04_human", "M04_WAR")},
}
EFFECTS = {("FX", "gaoshun_entry"): (8, [256, 480], [260, 260], 4, 4),
           ("FX", "chengong_seal"): (8, [256, 256], [260, 260], 4, 5)}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def opaque_colors(image: Image.Image) -> set[int]:
    colors = image.convert("RGBA").getcolors(maxcolors=65536)
    assert colors is not None, "RGBA color enumeration exceeded65536 entries"
    return {(r << 16) | (g << 8) | b for _count, (r, g, b, a) in colors if a > 0}


def audit() -> dict:
    manifest = json.loads((FOLDER / "manifest.json").read_text())
    table = json.loads((ROOT / "assets/data/chronicle/battle_sprite_bounds.json").read_text())
    by_role = {(spec["visual_id"], spec["role"]): spec for spec in manifest["clips"].values()}
    assert set(by_role) == set(EXPECTED) | set(EFFECTS), "two command forms, both collaborators and the two independent FX"
    assert len(by_role) == len(manifest["clips"]), "duplicate visual/role keys would overwrite a cached strip"
    assert len({spec["file"] for spec in by_role.values()}) == 10, "eight actor strips and two effects must remain independently authored files"
    files: dict[Path, dict] = {}
    identities: dict[str, set[int]] = {}
    for key in list(EXPECTED) + list(EFFECTS):
        spec = by_role[key]
        effect = key in EFFECTS
        count = EFFECTS[key][0] if effect else EXPECTED[key][0]
        if effect:
            assert spec.get("kind", spec.get("type")) == "effect", (key, "effect must be explicitly separated from actor calibration")
            assert spec["frames"] == count and spec["anchor_px"] == EFFECTS[key][1] and spec["world_size"] == EFFECTS[key][2], (key, "effect frame/anchor/world footprint")
            assert (spec["release_frame"], spec["contact_frame"]) == EFFECTS[key][3:], (key, "effect must contact at its actual release/hazard event")
            assert spec["body_height_px"] == 0, (key, "effects have no actor body height")
        else:
            assert (spec["frames"], spec["release_frame"], spec["contact_frame"]) == EXPECTED[key], (key, "pose/contact order")
            assert spec["anchor_px"] == [384, 608] and spec["body_height_px"] == 224, (key, "foot/body calibration")
            assert spec.get("faces_left", False) is False, (key, "native orientation")
        assert spec["frame_size"] == ([512, 512] if effect else [768, 640]), (key, "independent effect/actor canvas")
        width, height = spec["frame_size"]
        path = FOLDER / spec["file"]
        assert path.parent == FOLDER and path.suffix == ".png", (key, "flat PNG clip path")
        if path not in files:
            with Image.open(path) as source:
                assert source.mode == "RGBA" and source.size == (width * count, height), (path, "RGBA strip dimensions")
                histogram = source.getchannel("A").histogram()
                assert not sum(histogram[1:255]), (path, "binary alpha")
                colors = opaque_colors(source)
                assert 0 < len(colors) and len(colors) + int(histogram[0] > 0) <= 64, (path, "independent palette exceeds64 total colors", len(colors))
                bounds_entry = table["textures"]["res://" + path.relative_to(ROOT).as_posix()]
                assert bounds_entry["sha256"] == sha(path) and bounds_entry["size"] == list(source.size), (path, "stale runtime alpha metadata")
                frame_rows = []
                frame_hashes = set()
                tight_silhouettes = set()
                for index in range(count):
                    frame = source.crop((index * width, 0, (index + 1) * width, height))
                    alpha = frame.getchannel("A")
                    box = alpha.getbbox()
                    if not effect: assert box and 0 < box[0] < box[2] < width and 0 < box[1] < box[3] < height, (path, index, "empty or clipped actor art", box)
                    digest = hashlib.sha256(frame.tobytes()).hexdigest()
                    assert digest not in frame_hashes, (path, index, "duplicated authored pose")
                    frame_hashes.add(digest)
                    if box:
                        silhouette = alpha.crop(box).resize((128, 128), Image.Resampling.NEAREST)
                        tight_silhouettes.add(hashlib.sha256(silhouette.tobytes()).hexdigest())
                    actual = [box[0], box[1], box[2] - box[0], box[3] - box[1]] if box else [0, 0, 0, 0]
                    assert bounds_entry["regions"][f"{index * width},0,{width},{height}"] == actual, (path, index, "incorrect source-alpha region")
                    frame_rows.append({"index": index, "rgba_sha256": digest, "alpha_bounds": actual})
                if not effect: assert len(tight_silhouettes) >= 4, (path, "fewer than four distinct cropped/scale-normalized silhouettes")
                full = source.getchannel("A").getbbox()
                assert bounds_entry["regions"][f"0,0,{source.width},{source.height}"] == [full[0], full[1], full[2]-full[0], full[3]-full[1]], (path, "incorrect full-strip alpha union")
            editable = path.with_suffix(".aseprite")
            assert editable.is_file() and editable.stat().st_size > 0, (path, "missing editable clip")
            with editable.open("rb") as file: size, magic, frames, edit_width, edit_height = struct.unpack("<IHHHH", file.read(12))
            assert size == editable.stat().st_size and magic == 0xA5E0 and (frames, edit_width, edit_height) == (count, width, height), (editable, "editable clip header/frame contract")
            files[path] = {"path": path.relative_to(ROOT).as_posix(), "kind": "effect" if effect else "actor", "sha256": sha(path), "opaque_colors": len(colors), "distinct_normalized_silhouettes": len(tight_silhouettes), "frames": frame_rows, "editable_sha256": sha(editable), "_colors": colors}
        if not effect: identities.setdefault(key[0], set()).update(files[path]["_colors"])
    for identity, colors in identities.items():
        assert len(colors) + 1 <= 64, (identity, "palette differs across command roles", len(colors))
        old_folder = ROOT / "assets/enemies/baimen" / identity
        old_manifest = json.loads((old_folder / "manifest.json").read_text())
        original_colors = set()
        for name in {clip["file"] for clip in old_manifest["clips"].values()}:
            with Image.open(old_folder / name) as old_image: original_colors.update(opaque_colors(old_image))
        assert colors <= original_colors, (identity, "actor colors must retain the existing identity palette")
    return {"status": "passed", "visual_roles": len(EXPECTED), "effect_roles": len(EFFECTS), "physical_strips": len(files), "independent_physical_frames": sum(len(row["frames"]) for row in files.values()), "manifest_sha256": sha(FOLDER / "manifest.json"), "body_calibration": {"canvas": [768, 640], "foot_anchor": [384, 608], "body_height": 224}, "pixel_metadata_matches": True, "files": [{k: v for k, v in row.items() if k != "_colors"} for row in files.values()]}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    try:
        result = audit()
    except (AssertionError, OSError, KeyError, ValueError, struct.error) as error:
        print("ZHANG_LIAO_SUMMON_ART_AUDIT FAIL", error)
        return 1
    if args.report:
        args.report.write_text(json.dumps(result, indent=2) + "\n")
    print(f"ZHANG_LIAO_SUMMON_ART_AUDIT PASS roles={result['visual_roles']} effects={result['effect_roles']} strips={result['physical_strips']} frames={result['independent_physical_frames']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

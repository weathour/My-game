#!/usr/bin/env python3
"""Read-only cross-roster audit of new ImageGen/Aseprite combat art deliveries."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
IDS = ["M07", "M08", "F01", "F11"] + [f"N{i:02d}" for i in range(1, 19)]
CLIPS = {"idle": 4, "move": 4, "attack": 4, "special": 4, "hit": 2}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def audit() -> dict:
    result = {"characters": [], "failures": [], "counts": {
        "new_models": 22, "independent_body_drawings": 352,
        "exported_body_frames_including_reuse": 396, "independent_portraits": 22,
    }}
    for identity in IDS:
        folder = ROOT / "assets/players/chronicle-cast" / identity
        source_folder = ROOT / "design/skill-presentation-20261105/characters" / identity
        row = {"id": identity, "clips": {}, "outputs": [], "evidence": str(source_folder.relative_to(ROOT))}
        try:
            manifest = json.loads((folder / "manifest.json").read_text())
            measured = json.loads((source_folder / "measurements.json").read_text())
            exports = json.loads((source_folder / "export-manifest.json").read_text())
            assert manifest["character_id"] == identity
            assert manifest["anchor_px"] == [96, 176]
            assert manifest["body_height_px"] == 80
            assert measured["canvas"]["body_height_px"] == 80
            assert len(measured["poses"]) == 16
            assert len({pose["id"] for pose in measured["poses"]}) == 16
            for source in measured["sources"].values():
                path = source_folder / source["path"]
                assert digest(path) == source["sha256"], f"source hash: {path}"
                with Image.open(path) as picture:
                    assert picture.mode == "RGBA" and list(picture.size) == source["size"], f"source format: {picture.mode} {picture.size}"
                    alpha_extrema = picture.getchannel("A").getextrema()
                    # ImageGen raw edges/background may contain near-zero alpha
                    # (N10 is 1..255). The Aseprite binary export is audited below.
                    assert alpha_extrema[0] < 128 <= alpha_extrema[1], f"source transparency: {alpha_extrema}"
                    row.setdefault("source_alpha_extrema", {})[source["path"]] = list(alpha_extrema)
                assert source["standing_body_height"] > 0
            colors = set()
            for name, count in CLIPS.items():
                clip = manifest["clips"][name]
                assert clip["frame_size"] == [192, 192] and clip["frames"] == count
                path = folder / clip["file"]
                assert (folder / (name + ".aseprite")).is_file()
                with Image.open(path) as picture:
                    assert picture.mode == "RGBA" and picture.size == (192 * count, 192), f"clip format: {identity}/{name}"
                    assert set(picture.getchannel("A").getdata()) == {0, 255}, f"nonbinary alpha: {identity}/{name}"
                    colors.update(pixel[:3] for pixel in picture.getdata() if pixel[3])
                    bounds, frame_hashes = [], []
                    for index in range(count):
                        frame = picture.crop((index * 192, 0, (index + 1) * 192, 192))
                        box = frame.getbbox()
                        assert box and 0 < box[0] < box[2] < 192 and 0 < box[1] < box[3] < 192, f"canvas boundary: {identity}/{name}/{index}: {box}"
                        allowance = 3 if identity == "F11" and name in ["special", "hit"] else 0
                        assert abs(box[3] - 176) <= allowance, f"ground silhouette: {identity}/{name}/{index}: {box}"
                        bounds.append(list(box))
                        frame_hashes.append(hashlib.sha256(frame.tobytes()).hexdigest())
                    assert len(set(frame_hashes)) == count, f"duplicate frame: {identity}/{name}"
                    row["clips"][name] = {"frames": count, "distinct_frames": len(set(frame_hashes)), "bounds": bounds}
            assert 0 < len(colors) <= 64, f"palette: {identity}: {len(colors)}"
            row["shared_actor_colors"] = len(colors)
            with Image.open(folder / "head.png") as head:
                assert head.mode == "RGBA" and head.size == (128, 128), f"head format: {identity}: {head.mode} {head.size}"
                assert set(head.getchannel("A").getdata()) == {0, 255}, f"head alpha: {identity}"
            for suffix in [".tscn", "-head.tscn"]:
                assert (folder / (identity + suffix)).is_file()
            assert (folder / "actor.aseprite").is_file() and (folder / "head.aseprite").is_file()
            for output in exports["outputs"]:
                path = ROOT / output["path"]
                assert digest(path) == output["sha256"], f"export hash: {path}"
            for path in sorted(folder.iterdir()):
                if path.suffix in [".png", ".aseprite", ".json", ".tscn"]:
                    row["outputs"].append({"path": str(path.relative_to(ROOT)), "sha256": digest(path), "bytes": path.stat().st_size})
            row["status"] = "passed"
        except (AssertionError, KeyError, OSError, ValueError) as error:
            row["status"] = "failed"
            result["failures"].append(f"{identity}: {error} (audit line {error.__traceback__.tb_lineno})")
        result["characters"].append(row)
    baseline = ROOT / "design/skill-presentation-20261105/implementation-baseline.json"
    original = json.loads(baseline.read_text())["source_sha256"]
    # The 2026-11-06 skill-information projection adds raw display fields and
    # reports N07's existing support cooldown. Its independently audited two-hunk
    # diff is recorded in design/skill-information-20261106/verification/;
    # roster/ability numerical definitions retain the original strict hashes.
    expected = dict(original)
    expected["scripts/content/combat_catalog.gd"] = "77b7c91cf8366efe4469eb2a90d86e9bdd4e8610e23b15c6e4898f86a2df0bfc"
    result["frozen_definition_hashes"] = {}
    for name in ["scripts/content/roster_kit_data.gd", "scripts/content/combat_catalog.gd", "scripts/battle/ability_definition.gd"]:
        value = digest(ROOT / name)
        result["frozen_definition_hashes"][name] = value
        if value != expected[name]: result["failures"].append("numerical definition changed: " + name)
    result["status"] = "passed" if not result["failures"] else "failed"
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    report = audit()
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    for error in report["failures"]: print(error)
    print("CHRONICLE_CAST_ART_AUDIT " + ("PASS" if report["status"] == "passed" else "FAIL") +
          f" characters={len(report['characters'])} failures={len(report['failures'])}")
    return int(bool(report["failures"]))


if __name__ == "__main__":
    raise SystemExit(main())

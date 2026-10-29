"""Read-only image QA; write only the export provenance/measurement report.

Run from repository root. --source PATH emits connected-component measurements.
No images are drawn or transformed by this utility.
"""
from __future__ import annotations

import argparse
from hashlib import sha256
import json
from pathlib import Path
import struct

from PIL import Image

ROOT = Path("design/baimen-women-20261028")


def digest(path: Path) -> str:
    return sha256(path.read_bytes()).hexdigest()


def components(path: Path) -> None:
    import numpy as np
    from scipy.ndimage import label, find_objects

    image = Image.open(path).convert("RGBA")
    labels, _ = label(np.array(image.getchannel("A")) >= 128)
    sizes = np.bincount(labels.ravel())
    found = []
    for i, region in enumerate(find_objects(labels), 1):
        if region is not None and sizes[i] >= 100:
            y, x = region
            found.append({"opaque_pixels": int(sizes[i]), "bbox": [x.start, y.start, x.stop, y.stop]})
    print(json.dumps({"path": str(path), "sha256": digest(path), "size": image.size,
                      "components_alpha_ge_128": sorted(found, key=lambda item: (item["bbox"][1], item["bbox"][0]))}, indent=2))


def audit() -> None:
    measurements = json.loads((ROOT / "export-measurements.json").read_text())
    records = []
    for character in measurements["characters"]:
        if character["review_status"] != "accepted_for_export":
            continue
        folder = Path("assets/players/baimen-women") / character["id"]
        colors = set()
        outputs = []
        for name, frame_count, size in (("idle", 4, (768, 192)), ("run", 8, (1536, 192)),
                                        ("attack", 4, (768, 192)), ("cast", 4, (768,192)), ("head", 1, (128, 128))):
            path = folder / f"{name}.png"
            with Image.open(path) as image:
                assert image.mode == "RGBA", (path, image.mode)
                assert image.size == size, (path, image.size)
                assert set(image.getchannel("A").getdata()) == {0, 255}, path
                opaque = {pixel[:3] for pixel in image.getdata() if pixel[3]}
                if name != "head":
                    colors.update(opaque)
                else:
                    assert len(opaque) <= 64, (path, len(opaque))
                    # Nearest-neighbour 2x means each 2x2 block is identical.
                    px = image.load()
                    assert all(px[x,y] == px[x+1,y] == px[x,y+1] == px[x+1,y+1]
                               for y in range(0,128,2) for x in range(0,128,2)), path
                bounds = []
                frame_hashes = []
                frame_width = size[0] // frame_count
                for frame in range(frame_count):
                    region = image.crop((frame*frame_width, 0, (frame+1)*frame_width, size[1]))
                    bounds.append(region.getchannel("A").getbbox())
                    assert bounds[-1] is not None, (path, frame)
                    frame_hashes.append(sha256(region.tobytes()).hexdigest())
                assert len(set(frame_hashes)) == frame_count, (path, "duplicate runtime frames")
                outputs.append({"path": str(path), "size": list(image.size), "frames": frame_count,
                                "sha256": digest(path), "alpha": [0,255], "opaque_colors": len(opaque),
                                "frame_alpha_bounds": bounds, "frame_pixel_sha256": frame_hashes})
            editable = folder / f"{name}.aseprite"
            data = editable.read_bytes()
            magic, frames, width, height = struct.unpack_from("<4H", data, 4)
            assert magic == 0xA5E0 and frames == frame_count, editable
            assert (width, height) == ((64,64) if name == "head" else (192,192)), editable
            outputs.append({"path": str(editable), "size": [width,height], "frames": frames,
                            "sha256": digest(editable)})
        assert len(colors) <= 64, (character["id"], len(colors))
        sources = []
        source_records = {kind: character[kind] for kind in ("combat", "portrait")}
        source_records.update(character.get("extra_sources", {}))
        for kind, source in source_records.items():
            path = ROOT / source["path"]
            actual = digest(path)
            assert actual == source["sha256"], (path, "source changed after measurement")
            sources.append({"kind": kind, "path": str(path), "sha256": actual, "size": source["size"]})
            if "standing_body_height" in source:
                sources[-1]["standing_body_height_source"] = source["standing_body_height"]
                sources[-1]["scale"] = 80 / source["standing_body_height"]
        records.append({"id": character["id"], "slug": character["slug"], "sources": sources,
                        "attack_contact_frame": character["attack_contact_frame"],
                        "scale": 80 / character["standing_body_height"],
                        "standing_body_height_source": character["standing_body_height"],
                        "actor_shared_opaque_colors": len(colors), "actor_frames": 20,
                        "outputs": outputs})
    report = {"schema": 1, "generator": "ImageGen source / Aseprite extraction, registration and quantization",
              "frame_size": [192,192], "anchor": [96,176], "portrait_native_size": [64,64],
              "portrait_png_size": [128,128], "alpha_threshold": 128,
              "export_script": "scripts/tools/import_baimen_women_art.lua",
              "export_script_sha256": digest(Path("scripts/tools/import_baimen_women_art.lua")),
              "audit_script_sha256": digest(Path(__file__)),
              "measurements": str(ROOT / "export-measurements.json"),
              "measurements_sha256": digest(ROOT / "export-measurements.json"),
              "characters": records}
    (ROOT / "export-manifest.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    print(f"BAIMEN_ART_AUDIT_OK {len(records)} characters / {len(records)*20} actor frames")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path)
    args = parser.parse_args()
    components(args.source) if args.source else audit()

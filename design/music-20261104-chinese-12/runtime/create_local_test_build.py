#!/usr/bin/env python3
"""Extend the existing battle pack with the D2 music provenance and notices."""
import argparse
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
BASE = Path(__file__).resolve().parent.parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--pck", type=Path, required=True)
    parser.add_argument("--output", type=Path,
                        default=ROOT / "builds/linux-chinese-d2-20261104")
    args = parser.parse_args()
    subprocess.run([
        sys.executable,
        str(ROOT / "design/danmaku-pressure-20261103/runtime/create_local_test_build.py"),
        "--pck", str(args.pck), "--output", str(args.output),
    ], check=True, stdout=subprocess.DEVNULL)
    path = args.output / "build-manifest.json"
    manifest = json.loads(path.read_text())
    sources = [BASE / "README.md", BASE / "THIRD_PARTY_NOTICES.md",
               BASE / "trial-manifest.json", BASE / "sources/lock.json",
               BASE / "sources/dsk-regions.json", BASE / "runtime/d2-game-render.json",
               ROOT / "docs/implementation/2026-11-04_中国器乐D2游戏接入.md",
               ROOT / "design/music-20261104-chinese-trial/THIRD_PARTY_NOTICES.md"]
    sources += sorted((BASE / "reports").glob("audio-*.json"))
    sources += sorted((BASE / "reports").glob("midi-*.json"))
    # Preserve published terms and records, without redistributing the SF2 bank
    # or any extracted instrument samples from the local rendering cache.
    for directory in (BASE / "sources", ROOT / "design/music-20261104-chinese-trial/sources"):
        sources += [p for p in directory.rglob("*") if p.is_file()
                    and p.suffix in (".md", ".txt", ".html", ".json")]
    by_path = {r["path"]: r for r in manifest["notices_and_licenses"]}
    for source in sorted(set(sources)):
        relative = source.relative_to(ROOT)
        dest = args.output / "notices" / relative
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, dest)
        by_path[str(dest.relative_to(args.output))] = {
            "path": str(dest.relative_to(args.output)), "source": str(relative),
            "sha256": sha(dest),
        }
    render = json.loads((BASE / "runtime/d2-game-render.json").read_text())
    manifest.update({
        "music_arrangement_variant": "D2", "music_cues_replaced": 12,
        "music_render_report_sha256": sha(BASE / "runtime/d2-game-render.json"),
        "music_render_sha256": {r["cue_id"]: r["output"]["sha256"] for r in render["cues"]},
        "notices_and_licenses": sorted(by_path.values(), key=lambda row: row["path"]),
    })
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"package": str(args.output), "variant": "D2",
                      "pck_sha256": manifest["pck_sha256"],
                      "pck_bytes": manifest["pck_bytes"],
                      "notices": len(manifest["notices_and_licenses"])}))


if __name__ == "__main__":
    main()

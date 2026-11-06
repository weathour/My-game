#!/usr/bin/env python3
"""Publish the approved D2 renders at the existing game's music mix level."""
from __future__ import annotations

import concurrent.futures
import datetime
import hashlib
import json
import math
import os
import re
import subprocess
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[3]
BASE = Path(__file__).resolve().parent.parent
RUNTIME = Path(__file__).resolve().parent
POLICY = {
    "integrated_lufs_max": -21.0,
    "preencode_true_peak_target_dbtp": -3.5,
    "encoded_true_peak_ceiling_dbtp": -3.0,
    "processing": "fixed_gain_only",
}


def sha(path: Path) -> str:
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def run(args: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(args, check=True, capture_output=True)


def loudness(path: Path) -> dict:
    result = run([
        "ffmpeg", "-nostdin", "-hide_banner", "-nostats", "-threads", "1",
        "-filter_threads", "1", "-i", str(path), "-af",
        "loudnorm=I=-21:LRA=11:TP=-3:print_format=json", "-f", "null", "-",
    ])
    blocks = re.findall(r'\{[^{}]*"input_i"[^{}]*\}', result.stderr.decode(), re.S)
    assert blocks, result.stderr.decode()[-2000:]
    data = json.loads(blocks[-1])
    assert all(math.isfinite(float(data[key])) for key in ("input_i", "input_tp"))
    return data


def file_ref(path: Path) -> dict:
    return {"path": str(path), "sha256": sha(path)}


def encode(item: dict) -> dict:
    cue = item["cue_id"]
    report = json.loads((BASE / f"reports/audio-{cue}.json").read_text())
    source_info = report["outputs"]["D2"]["files"]["flac"]
    source = Path(source_info["path"])
    assert sha(source) == source_info["sha256"], f"D2 audio changed: {cue}"
    midi = BASE / "arrangements" / cue / "D2.mid"
    plan = BASE / "arrangements" / cue / "plan-D2.json"
    frozen = Path(item["frozen_midi"])
    assert sha(frozen) == item["source_sha256"], f"Frozen MIDI changed: {cue}"
    assert sha(plan) == report["variants"]["D2"]["plan_sha256"], cue
    midi_report = json.loads((BASE / f"reports/midi-{cue}.json").read_text())
    assert midi_report["status"] == "PASS" and all(midi_report["checks"].values()), cue
    measured = loudness(source)
    gain = min(
        POLICY["integrated_lufs_max"] - float(measured["input_i"]),
        POLICY["preencode_true_peak_target_dbtp"] - float(measured["input_tp"]),
    )
    asset = ROOT / "assets/music/midi_test" / f"{cue}.ogg"
    temporary = asset.with_name(f".{cue}.d2-tmp.ogg")
    # Vorbis can overshoot the PCM master slightly. Adjust only a constant gain,
    # then measure the actual decoded result before atomically publishing it.
    for attempt in range(3):
        run([
            "ffmpeg", "-nostdin", "-v", "error", "-y", "-threads", "1",
            "-filter_threads", "1", "-i", str(source), "-map_metadata", "-1",
            "-af", f"volume={gain:.8f}dB", "-ar", "48000", "-ac", "2",
            "-c:a", "libvorbis", "-q:a", "7", str(temporary),
        ])
        levels = loudness(temporary)
        excess = max(
            float(levels["input_i"]) - POLICY["integrated_lufs_max"],
            float(levels["input_tp"]) - POLICY["preencode_true_peak_target_dbtp"],
        )
        if excess <= 0.05:
            break
        gain -= excess + 0.05
    else:
        raise RuntimeError(f"Cannot meet mix headroom: {cue} {levels}")
    probe = json.loads(run([
        "ffprobe", "-v", "error", "-show_entries",
        "format=duration:stream=codec_name,sample_rate,channels", "-of", "json",
        str(temporary),
    ]).stdout)
    stream = probe["streams"][0]
    duration = float(probe["format"]["duration"])
    assert stream["codec_name"] == "vorbis" and stream["sample_rate"] == "48000"
    assert stream["channels"] == 2 and abs(duration - report["duration_seconds"]) < 0.002
    pcm = np.frombuffer(run([
        "ffmpeg", "-nostdin", "-v", "error", "-i", str(temporary),
        "-f", "f32le", "-acodec", "pcm_f32le", "-",
    ]).stdout, dtype="<f4")
    assert pcm.size > 0 and np.isfinite(pcm).all(), cue
    peak = float(np.max(np.abs(pcm)))
    assert 0.001 < peak < 1.0, cue
    assert float(levels["input_tp"]) <= POLICY["encoded_true_peak_ceiling_dbtp"], cue
    output = {
        "path": str(asset.relative_to(ROOT)), "sha256": sha(temporary),
        "duration_seconds": duration, "sample_rate": 48000, "channels": 2,
        "integrated_lufs": float(levels["input_i"]),
        "true_peak_dbtp": float(levels["input_tp"]),
        "sample_peak_linear": peak, "sample_peak_dbfs": 20 * math.log10(peak),
        "decoded_finite": True, "decoded_frames": int(pcm.size // 2),
    }
    os.replace(temporary, asset)
    print(f"{cue} D2 PASS {output['integrated_lufs']:.2f} LUFS "
          f"{output['true_peak_dbtp']:.2f} dBTP", flush=True)
    return {
        "index": item["index"], "cue_id": cue, "title": item["title"],
        "source_audio": file_ref(source), "source_midi": file_ref(frozen),
        "arrangement_midi": file_ref(midi), "arrangement_plan": file_ref(plan),
        "source_loudness": measured, "fixed_gain_db": gain, "output": output,
    }


def main() -> None:
    manifest = json.loads((BASE / "trial-manifest.json").read_text())
    assert len(manifest["selected"]) == 12
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        cues = list(pool.map(encode, manifest["selected"]))
    catalog_path = ROOT / "assets/data/audio/music_catalog.json"
    catalog = json.loads(catalog_path.read_text())
    catalog["version"] = 3
    by_id = {row["cue_id"]: row for row in cues}
    for entry in catalog["cues"]:
        if entry["id"] not in by_id:
            continue
        row = by_id[entry["id"]]
        entry.update({
            "scene": "第一章中国器乐与调式配乐", "kind": "中国器乐·有限调式",
            "arrangement_variant": "D2", "source_audio_variant": "D2",
            "arrangement_midi_sha256": row["arrangement_midi"]["sha256"],
            "arrangement_plan_sha256": row["arrangement_plan"]["sha256"],
            "source_audio_sha256": row["source_audio"]["sha256"],
            "render_sha256": row["output"]["sha256"],
        })
        for key in ("duration_seconds", "integrated_lufs", "true_peak_dbtp",
                    "sample_peak_dbfs", "sample_peak_linear"):
            entry[key] = row["output"][key]
    catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n")
    result = {
        "schema_version": 1, "status": "PASS", "arrangement_variant": "D2",
        "utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "mix_policy": POLICY, "catalog_sha256": sha(catalog_path), "cues": cues,
        "producer_sha256": sha(Path(__file__)),
        "ffmpeg_version": run(["ffmpeg", "-version"]).stdout.decode().splitlines()[0],
    }
    (RUNTIME / "d2-game-render.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print("D2_GAME_RENDER_OK cues=12 catalog_version=3", flush=True)


if __name__ == "__main__":
    main()

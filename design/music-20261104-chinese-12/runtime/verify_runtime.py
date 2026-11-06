#!/usr/bin/env python3
"""Verify that the published chapter music assets are the approved D2 renders."""
import hashlib
import json
import math
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
PRODUCTION = ROOT / "design/music-20261104-chinese-12"
CATALOG = ROOT / "assets/data/audio/music_catalog.json"
REPORT = PRODUCTION / "runtime/d2-game-render.json"
CATALOG_BEFORE = PRODUCTION / "runtime/music-catalog-before.json"
GAME_MUSIC_BEFORE = PRODUCTION / "runtime/game-music-before.json"
ALLOCATION = ROOT / "design/music-20261103-midi-test/chapter-music-map.json"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def probe(path: Path) -> dict:
    raw = subprocess.check_output([
        "ffprobe", "-v", "error", "-show_entries",
        "format=duration:stream=codec_name,sample_rate,channels",
        "-of", "json", str(path),
    ])
    return json.loads(raw)


def main() -> None:
    catalog = json.loads(CATALOG.read_text())
    report = json.loads(REPORT.read_text())
    old_catalog = json.loads(CATALOG_BEFORE.read_text())
    old_game_music = json.loads(GAME_MUSIC_BEFORE.read_text())
    allocation = json.loads(ALLOCATION.read_text())
    assert catalog["version"] == 3, "D2 catalog schema version must be 3"
    assert report["schema_version"] == 1 and report["status"] == "PASS"
    assert report["arrangement_variant"] == "D2"
    mix = report["mix_policy"]
    assert float(mix["integrated_lufs_max"]) == -21.0
    assert float(mix["preencode_true_peak_target_dbtp"]) == -3.5
    assert float(mix["encoded_true_peak_ceiling_dbtp"]) == -3.0
    assert mix["processing"] == "fixed_gain_only"
    rows = {row["id"]: row for row in catalog["cues"]}
    production_rows = {row["cue_id"]: row for row in report["cues"]}
    assert len(production_rows) == 12 and len(report["cues"]) == 12
    old_rows = {row["id"]: row for row in old_catalog["cues"]}
    prior_game_rows = {row["cue_id"]: row for row in old_game_music["cues"]}
    expected_ids = set(old_rows)
    assert set(rows) == expected_ids == set(prior_game_rows), "catalog cue roster changed"
    for cue in expected_ids:
        assert rows[cue]["path"] == old_rows[cue]["path"] == prior_game_rows[cue]["path"], f"stable cue path: {cue}"
    retained = {"camp_home", "rest_spring", "hero_daily", "story_warmth"}
    for cue in retained:
        assert rows[cue] == old_rows[cue], f"retained warm catalog entry changed: {cue}"

    expected_route_hash = allocation["route_source_sha256"]
    assert sha256(ROOT / "assets/data/chronicle/route.json") == expected_route_hash, "route source data changed"
    frozen_by_id = {row["cue_id"]: row for row in allocation["new_test_cues"]}

    checked = 0
    for index in range(1, 13):
        cue = f"midi_test_{index:02d}"
        row = rows[cue]
        item = production_rows[cue]
        midi_path = Path(item["arrangement_midi"]["path"])
        plan_path = Path(item["arrangement_plan"]["path"])
        source_midi_path = Path(item["source_midi"]["path"])
        source_audio = Path(item["source_audio"]["path"])
        ogg = ROOT / row["path"].removeprefix("res://")
        midi_report = json.loads((PRODUCTION / "reports" / f"midi-{cue}.json").read_text())
        audio_report = json.loads((PRODUCTION / "reports" / f"audio-{cue}.json").read_text())
        approved_d2_audio = audio_report["outputs"]["D2"]["files"]["flac"]
        assert row["arrangement_variant"] == "D2" and row["source_audio_variant"] == "D2", cue
        assert row["source_midi_sha256"] == frozen_by_id[cue]["midi_sha256"], f"frozen MIDI provenance: {cue}"
        assert source_midi_path.is_file() and sha256(source_midi_path) == item["source_midi"]["sha256"] == row["source_midi_sha256"], f"frozen MIDI provenance: {cue}"
        assert source_midi_path == ROOT / frozen_by_id[cue]["repo_midi_file"], f"frozen MIDI path: {cue}"
        assert midi_report["status"] == "PASS" and all(value is True for value in midi_report["checks"].values()), f"existing D2 MIDI verification: {cue}"
        assert midi_report["D2_midi"] == str(midi_path) and midi_report["source_sha256"] == row["source_midi_sha256"]
        assert midi_path.is_file() and sha256(midi_path) == item["arrangement_midi"]["sha256"] == row["arrangement_midi_sha256"], f"D2 MIDI provenance: {cue}"
        assert plan_path.is_file() and sha256(plan_path) == item["arrangement_plan"]["sha256"] == row["arrangement_plan_sha256"] == audio_report["variants"]["D2"]["plan_sha256"], f"D2 arrangement plan provenance: {cue}"
        assert audio_report["status"] == "PASS" and audio_report["source_sha256"] == row["source_midi_sha256"]
        assert source_audio == Path(approved_d2_audio["path"]) and source_audio.is_file()
        assert sha256(source_audio) == approved_d2_audio["sha256"]
        assert source_audio.is_file() and sha256(source_audio) == item["source_audio"]["sha256"] == row["source_audio_sha256"], f"approved D2 master: {cue}"
        assert item["output"]["path"] == str(ogg.relative_to(ROOT)), f"published output path: {cue}"
        assert ogg.is_file() and sha256(ogg) == item["output"]["sha256"] == row["render_sha256"], f"published game render hash: {cue}"
        assert sha256(ogg) != prior_game_rows[cue]["sha256"], f"game asset differs from old C render: {cue}"
        assert abs(float(row["duration_seconds"]) - float(item["output"]["duration_seconds"])) < 0.001
        assert abs(float(row["integrated_lufs"]) - float(item["output"]["integrated_lufs"])) <= 0.01
        assert abs(float(row["true_peak_dbtp"]) - float(item["output"]["true_peak_dbtp"])) <= 0.01
        assert abs(float(row["sample_peak_dbfs"]) - float(item["output"]["sample_peak_dbfs"])) <= 0.01
        assert abs(float(row["sample_peak_linear"]) - float(item["output"]["sample_peak_linear"])) <= 0.001
        assert math.isfinite(float(item["fixed_gain_db"]))
        assert item["output"]["decoded_finite"] is True
        assert int(item["output"]["sample_rate"]) == 48000 and int(item["output"]["channels"]) == 2
        assert float(item["output"]["integrated_lufs"]) <= float(mix["integrated_lufs_max"]) + 0.15
        assert float(item["output"]["true_peak_dbtp"]) <= float(mix["encoded_true_peak_ceiling_dbtp"])

        details = probe(ogg)
        streams = details["streams"]
        assert len(streams) == 1 and streams[0]["codec_name"] == "vorbis", f"Vorbis stream: {cue}"
        duration = float(details["format"]["duration"])
        assert abs(duration - float(row["duration_seconds"])) < 0.001, f"full render duration: {cue}"
        levels = subprocess.run([
            "ffmpeg", "-hide_banner", "-i", str(ogg), "-af",
            "ebur128=peak=true", "-f", "null", "-",
        ], capture_output=True, text=True, check=True).stderr
        import re
        integrated = re.findall(r"I:\s*(-?\d+(?:\.\d+)?) LUFS", levels)
        true_peak = re.findall(r"Peak:\s*(-?\d+(?:\.\d+)?) dBFS", levels)
        assert integrated and true_peak, f"decoded loudness measurements: {cue}"
        assert abs(float(integrated[-1]) - float(row["integrated_lufs"])) <= 0.15, f"integrated loudness: {cue}"
        assert abs(float(true_peak[-1]) - float(row["true_peak_dbtp"])) <= 0.15, f"true peak: {cue}"
        assert math.isfinite(float(row["sample_peak_dbfs"])) and float(row["sample_peak_dbfs"]) < 0.0, cue
        checked += 1

    warm = {"camp_home", "rest_spring", "hero_daily", "story_warmth"}
    assert set(rows) == {f"midi_test_{i:02d}" for i in range(1, 13)} | warm
    for cue in warm:
        path = ROOT / rows[cue]["path"].removeprefix("res://")
        assert sha256(path) == prior_game_rows[cue]["sha256"], f"retained warm audio unchanged: {cue}"
    print(f"CHINESE_MUSIC_D2_RUNTIME_OK cues={checked} retained_warm={len(warm)} route_sha256={expected_route_hash}")


if __name__ == "__main__":
    main()

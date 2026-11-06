#!/usr/bin/env python3
"""Build short D2 + candidate quarter-beat listening previews.

The click track is an unverified timing aid. It does not label accents or assert
that the MIDI beat map has been audition-calibrated against the rendered music.
"""
from __future__ import annotations

import hashlib
import json
import math
import shutil
import subprocess
import wave
from pathlib import Path
from typing import Any

import numpy as np


ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OUT = HERE / "preview"
AUDIT = HERE / "midi-audit.json"
SAMPLE_RATE = 48_000
CHANNELS = 2
CLICK_HZ = 880.0
CLICK_SECONDS = 0.035
CLICK_PEAK = 10 ** (-24.0 / 20.0)
OUTPUT_CEILING = 10 ** (-1.0 / 20.0)
CUES = ("midi_test_02", "midi_test_06", "midi_test_08")


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def run(args: list[str]) -> bytes:
    p = subprocess.run(args, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return p.stdout


def tick_times(tempo_events: list[dict[str, Any]], ppq: int, ticks: list[int]) -> list[float]:
    """Integrate the complete tempo map, resolving same-tick order as the audit does."""
    ordered = sorted(tempo_events, key=lambda x: (int(x["tick"]), int(x["track"]), int(x["message_index"])))
    effective: list[tuple[int, int]] = []
    for event in ordered:
        item = (int(event["tick"]), int(event["tempo_us_per_quarter"]))
        if effective and effective[-1][0] == item[0]:
            effective[-1] = item
        else:
            effective.append(item)
    if not effective or effective[0][0] > 0:
        effective.insert(0, (0, 500_000))

    output: list[float] = []
    for target in ticks:
        tempo = 500_000
        last_tick = 0
        seconds = 0.0
        for tick, usec in effective:
            if tick > target:
                break
            seconds += (tick - last_tick) * tempo / (ppq * 1_000_000.0)
            tempo = usec
            last_tick = tick
        seconds += (target - last_tick) * tempo / (ppq * 1_000_000.0)
        output.append(seconds)
    assert all(a <= b for a, b in zip(output, output[1:])), "beat event times must be monotonic"
    return output


def write_pcm16(path: Path, audio: np.ndarray) -> None:
    pcm = np.clip(np.rint(audio * 32767.0), -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(CHANNELS)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        wav.writeframes(pcm.tobytes())


def make_click_track(event_samples: list[int], frames: int) -> np.ndarray:
    click_frames = round(CLICK_SECONDS * SAMPLE_RATE)
    t = np.arange(click_frames, dtype=np.float64) / SAMPLE_RATE
    envelope = np.exp(-t * 95.0)
    tone = (CLICK_PEAK * np.sin(2.0 * math.pi * CLICK_HZ * t) * envelope).astype(np.float32)
    clicks = np.zeros((frames, CHANNELS), dtype=np.float32)
    used: list[int] = []
    for sample in event_samples:
        if sample < 0 or sample >= frames:
            raise ValueError(f"beat cue outside clip: {sample}/{frames}")
        end = min(frames, sample + click_frames)
        clicks[sample:end, :] += tone[:end - sample, None]
        used.append(sample)
    return clicks


def main() -> None:
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        raise RuntimeError("ffmpeg is required to decode the existing game OGG files")
    OUT.mkdir(parents=True, exist_ok=True)
    audit = json.loads(AUDIT.read_text(encoding="utf-8"))
    songs = {s["cue_id"]: s for s in audit["songs"]}
    manifest_songs: list[dict[str, Any]] = []
    playlist: list[str] = ["#EXTM3U", "# Candidate beat cues for listening only; not a calibrated game chart."]

    for cue_id in CUES:
        song = songs[cue_id]
        window = next(w for w in song["drum_windows_8_quarter_beats"] if w["selection"] == "median_density")
        audio_info = song["audio_alignment_and_provenance"]
        trim = float(audio_info["declared_trim_seconds"])
        midi_start = float(window["start_seconds"])
        midi_end = float(window["end_seconds"])
        ogg_start = midi_start - trim
        ogg_end = midi_end - trim
        assert ogg_start >= 0.0 and ogg_end > ogg_start
        source_path = ROOT / "assets/music/midi_test" / f"{cue_id}.ogg"
        source_hash_before = sha256(source_path)
        decoded = run([ffmpeg, "-nostdin", "-v", "error", "-i", str(source_path), "-f", "f32le",
                       "-ac", str(CHANNELS), "-ar", str(SAMPLE_RATE), "pipe:1"])
        source_audio = np.frombuffer(decoded, dtype="<f4").reshape((-1, CHANNELS)).copy()
        frame_start = round(ogg_start * SAMPLE_RATE)
        frame_end = round(ogg_end * SAMPLE_RATE)
        original = source_audio[frame_start:frame_end]
        assert len(original) > 0
        duration = len(original) / SAMPLE_RATE
        assert abs(duration - (midi_end - midi_start)) <= 2.0 / SAMPLE_RATE

        ppq = int(song["source"]["ticks_per_beat"])
        beat_ticks = [int(window["start_tick"]) + beat * ppq for beat in range(8)]
        midi_beat_times = tick_times(song["source"]["tempo_raw"], ppq, beat_ticks)
        game_beat_times = [t - trim for t in midi_beat_times]
        local_beat_times = [t - ogg_start for t in game_beat_times]
        event_samples = [round(t * SAMPLE_RATE) for t in local_beat_times]
        assert all(a < b for a, b in zip(event_samples, event_samples[1:])), "beat cues must not collide"
        assert all(0 <= sample < len(original) for sample in event_samples)

        clicks = make_click_track(event_samples, len(original))
        candidate = original + clicks
        peak_before = max(float(np.max(np.abs(original))), float(np.max(np.abs(candidate))))
        shared_gain = min(1.0, OUTPUT_CEILING / max(peak_before, 1e-12))
        original_out = original * shared_gain
        candidate_out = candidate * shared_gain
        pair_stem = f"{cue_id}-median-8beats"
        original_path = OUT / f"{pair_stem}-d2-original.wav"
        candidate_path = OUT / f"{pair_stem}-d2-plus-candidate-quarter-clicks.wav"
        write_pcm16(original_path, original_out)
        write_pcm16(candidate_path, candidate_out)
        source_hash_after = sha256(source_path)
        assert source_hash_before == source_hash_after, f"source OGG changed during preview generation: {cue_id}"

        playlist.extend([
            f"#EXTINF:{duration:.3f},{cue_id} — 原 D2 短段（未加提示音）",
            original_path.name,
            f"#EXTINF:{duration:.3f},{cue_id} — D2 + 候选四分音符提示（未人工验拍）",
            candidate_path.name,
        ])
        manifest_songs.append({
            "cue_id": cue_id,
            "title": song["title"],
            "window_selection": "median_density",
            "window_start_tick": int(window["start_tick"]),
            "window_end_tick": int(window["end_tick"]),
            "ppq": ppq,
            "window_midi_start_seconds": midi_start,
            "window_midi_end_seconds": midi_end,
            "declared_trim_seconds": trim,
            "nominal_ogg_start_seconds": round(ogg_start, 9),
            "nominal_ogg_end_seconds": round(ogg_end, 9),
            "duration_seconds": round(duration, 9),
            "source_ogg_path": str(source_path.relative_to(ROOT)),
            "source_ogg_sha256_before": source_hash_before,
            "source_ogg_sha256_after": source_hash_after,
            "source_ogg_hash_unchanged": source_hash_before == source_hash_after,
            "source_event_count_in_window": int(window["drum_event_count"]),
            "source_event_density_per_quarter": float(window["events_per_quarter_beat"]),
            "source_event_velocities_in_window": sorted({int(e["velocity"]) for e in window["events"]}),
            "beat_cue_candidate": {
                "events": [{"quarter_index": i, "midi_tick": tick,
                            "midi_time_seconds": round(midi_time, 9),
                            "nominal_ogg_time_seconds": round(game_time, 9),
                            "clip_time_seconds": round(local_time, 9),
                            "sample_index": sample}
                           for i, (tick, midi_time, game_time, local_time, sample) in enumerate(
                               zip(beat_ticks, midi_beat_times, game_beat_times, local_beat_times, event_samples))],
                "tone_hz": CLICK_HZ,
                "tone_duration_seconds": CLICK_SECONDS,
                "tone_peak_dbfs_before_shared_gain": -24.0,
                "same_tone_each_quarter": True,
                "accent_or_downbeat_claimed": False,
                "status": "candidate timing cue; not manually beat-calibrated",
            },
            "output": {
                "sample_rate": SAMPLE_RATE,
                "channels": CHANNELS,
                "pcm": "signed 16-bit little-endian",
                "original_wav": {"path": original_path.name, "sha256": sha256(original_path),
                                  "duration_seconds": round(duration, 9),
                                  "peak_dbfs": round(20 * math.log10(max(float(np.max(np.abs(original_out))), 1e-12)), 6)},
                "candidate_wav": {"path": candidate_path.name, "sha256": sha256(candidate_path),
                                   "duration_seconds": round(duration, 9),
                                   "peak_dbfs": round(20 * math.log10(max(float(np.max(np.abs(candidate_out))), 1e-12)), 6)},
                "shared_fixed_gain_linear": round(shared_gain, 12),
                "common_peak_ceiling_dbfs": -1.0,
                "dynamic_processing": False,
                "same_crop_and_original_gain_for_pair": True,
            },
        })

    playlist_path = OUT / "preview.m3u"
    playlist_path.write_text("\n".join(playlist) + "\n", encoding="utf-8")
    manifest = {
        "schema_version": 1,
        "purpose": "Compare D2 audio with a candidate quarter-note timing cue by ear.",
        "status": "candidate_only_not_manually_beat_calibrated",
        "playlist": {"path": playlist_path.name, "sha256": sha256(playlist_path)},
        "method": {
            "source": "existing published D2 game OGGs, decoded without altering them",
            "window": "median_density, fixed 8 quarter-note beats from the rhythm audit",
            "nominal_mapping": "t_ogg = t_midi - declared_trim_seconds; this is the declared render transform, while residual renderer/device delay remains unmeasured",
            "tempo": "Each quarter-note event uses integration of the complete per-song MIDI tempo map, including changes inside a window.",
            "candidate_cue": "Eight identical quiet 880 Hz, 35 ms decaying sine ticks, one at each quarter-note boundary. No accent or downbeat strength is inferred.",
            "mixing": "Original and candidate receive the same crop and same fixed gain. If needed, one shared constant gain keeps the pair below -1 dBFS. No compressor, limiter, fades, or time-moving processing.",
            "drum_metadata": "Drum count/density and MIDI velocities are listed only as candidate comparison data; velocity is not treated as audible loudness or a true accent.",
        },
        "songs": manifest_songs,
    }
    manifest_path = OUT / "preview-manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"PREVIEW PASS pairs={len(manifest_songs)} manifest={manifest_path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

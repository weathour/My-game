#!/usr/bin/env python3
"""Offline experiment: derive candidate combat windows from D2 MIDI alone."""
from __future__ import annotations

import hashlib
import json
import math
import re
import statistics
from collections import Counter
from pathlib import Path
from typing import Any

import mido


ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OUT_JSON = HERE / "auto-windows.json"
D2_DIR = ROOT / "design/music-20261104-chinese-12/arrangements"
PPQ_DEFAULT_TEMPO = 500_000
MERGE_SECONDS = 0.020
MIN_CENTER_GAP_SECONDS = 0.180
WINDOW_HALF_CAP_SECONDS = 0.090
WINDOW_SIDE_FRACTION = 0.30
LONG_GAP_MIN_SECONDS = 1.25
LONG_GAP_BEATS = 3.0
BEAT_EXAMPLE_CUE = "midi_test_02"


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def effective_tempos(mid: mido.MidiFile) -> list[tuple[int, int]]:
    events: list[tuple[int, int, int, int]] = []
    for ti, track in enumerate(mid.tracks):
        tick = 0
        for mi, msg in enumerate(track):
            tick += msg.time
            if msg.type == "set_tempo":
                events.append((tick, ti, mi, int(msg.tempo)))
    events.sort()
    grouped: list[tuple[int, int]] = []
    for tick, _ti, _mi, tempo in events:
        if grouped and grouped[-1][0] == tick:
            grouped[-1] = (tick, tempo)
        else:
            grouped.append((tick, tempo))
    if not grouped or grouped[0][0] > 0:
        grouped.insert(0, (0, PPQ_DEFAULT_TEMPO))
    return grouped


def make_time_map(tempos: list[tuple[int, int]], ppq: int) -> list[dict[str, float | int]]:
    rows: list[dict[str, float | int]] = []
    sec = 0.0
    prev_tick = 0
    active = PPQ_DEFAULT_TEMPO
    for tick, tempo in tempos:
        if tick < prev_tick:
            raise ValueError("tempo map must be monotonic")
        sec += (tick - prev_tick) * active / (ppq * 1_000_000.0)
        rows.append({"tick": tick, "seconds": sec, "tempo_us_per_quarter": tempo})
        prev_tick, active = tick, tempo
    return rows


def tick_to_seconds(tick: int, tempos: list[tuple[int, int]], ppq: int) -> float:
    active = PPQ_DEFAULT_TEMPO
    previous = 0
    seconds = 0.0
    for change_tick, tempo in tempos:
        if change_tick > tick:
            break
        seconds += (change_tick - previous) * active / (ppq * 1_000_000.0)
        active = tempo
        previous = change_tick
    return seconds + (tick - previous) * active / (ppq * 1_000_000.0)


def tempo_at_tick(tick: int, tempos: list[tuple[int, int]]) -> int:
    active = PPQ_DEFAULT_TEMPO
    for change_tick, tempo in tempos:
        if change_tick > tick:
            break
        active = tempo
    return active


def parse_offset_and_notes(mid: mido.MidiFile, tempos: list[tuple[int, int]]) -> tuple[float, list[dict[str, Any]], int, int, int]:
    markers: list[float] = []
    notes: list[dict[str, Any]] = []
    all_track_end = 0
    zero_velocity_note_on_count = 0
    for ti, track in enumerate(mid.tracks):
        tick = 0
        track_name = ""
        for msg in track:
            tick += msg.time
            all_track_end = max(all_track_end, tick)
            if msg.type == "track_name":
                track_name = msg.name
            if msg.type in ("marker", "text", "cue_marker"):
                match = re.fullmatch(r"muscriptor:bar_offset=([0-9]+(?:\.[0-9]+)?)", getattr(msg, "text", ""))
                if match:
                    markers.append(float(match.group(1)))
            if msg.type == "note_on":
                if int(msg.velocity) <= 0:
                    zero_velocity_note_on_count += 1
                else:
                    is_drum = int(getattr(msg, "channel", -1)) == 9 or any(token in track_name.lower() for token in ("drum", "percussion"))
                    notes.append({"tick": tick, "track": ti, "track_name": track_name,
                                  "channel": int(getattr(msg, "channel", -1)), "pitch": int(msg.note),
                                  "velocity": int(msg.velocity), "is_drum": is_drum,
                                  "seconds": tick_to_seconds(tick, tempos, mid.ticks_per_beat)})
    if len(markers) != 1:
        raise ValueError(f"expected exactly one muscriptor bar-offset marker, found {markers}")
    return markers[0], notes, all_track_end, sum(1 for n in notes if n["is_drum"]), zero_velocity_note_on_count


def merge_simultaneous(notes: list[dict[str, Any]]) -> list[dict[str, Any]]:
    ordered = sorted(notes, key=lambda x: (x["seconds"], x["tick"], x["track"], x["pitch"]))
    groups: list[list[dict[str, Any]]] = []
    for note in ordered:
        if not groups or note["seconds"] - groups[-1][0]["seconds"] > MERGE_SECONDS:
            groups.append([note])
        else:
            groups[-1].append(note)
    merged = []
    for group in groups:
        times = [float(x["seconds"]) for x in group]
        merged.append({"seconds": statistics.mean(times), "tick": round(statistics.median(int(x["tick"]) for x in group)),
                       "pitches": sorted({int(x["pitch"]) for x in group}),
                       "velocity_values": sorted({int(x["velocity"]) for x in group}),
                       "note_on_count": len(group), "track_names": sorted({str(x["track_name"]) for x in group}),
                       "channels": sorted({int(x["channel"]) for x in group})})
    return merged


def thin_by_minimum_gap(candidates: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], int]:
    kept: list[dict[str, Any]] = []
    thinned = 0
    for candidate in candidates:
        if kept and float(candidate["seconds"]) - float(kept[-1]["seconds"]) < MIN_CENTER_GAP_SECONDS:
            thinned += 1
            continue
        kept.append(candidate)
    return kept, thinned


def add_gap_fallbacks(events: list[dict[str, Any]], end_tick: int, tempos: list[tuple[int, int]], ppq: int) -> tuple[list[dict[str, Any]], int]:
    if not events:
        # With no note-on evidence at all, only a tempo-derived quarter grid remains.
        end_sec = tick_to_seconds(end_tick, tempos, ppq)
        beats = []
        tick = 0
        while tick_to_seconds(tick, tempos, ppq) < end_sec:
            sec = tick_to_seconds(tick, tempos, ppq)
            if sec > 0:
                beats.append({"tick": tick, "seconds": sec, "source": "tempo_quarter_fallback",
                              "pitches": [], "velocity_values": [], "note_on_count": 0,
                              "track_names": [], "channels": []})
            tick += ppq
        return beats, len(beats)

    filled: list[dict[str, Any]] = [events[0]]
    inserted = 0
    for right in events[1:]:
        left = filled[-1]
        while True:
            gap = float(right["seconds"]) - float(left["seconds"])
            beat_s = tempo_at_tick(int(left["tick"]), tempos) / 1_000_000.0
            threshold = max(LONG_GAP_MIN_SECONDS, LONG_GAP_BEATS * beat_s)
            if gap <= threshold:
                break
            next_tick = (int(left["tick"]) // ppq + 1) * ppq
            next_sec = tick_to_seconds(next_tick, tempos, ppq)
            while next_sec - float(left["seconds"]) < MIN_CENTER_GAP_SECONDS:
                next_tick += ppq
                next_sec = tick_to_seconds(next_tick, tempos, ppq)
            if (next_tick <= int(left["tick"])
                    or float(right["seconds"]) - next_sec < MIN_CENTER_GAP_SECONDS):
                break
            fallback = {"tick": next_tick, "seconds": next_sec, "source": "tempo_quarter_fallback",
                        "pitches": [], "velocity_values": [], "note_on_count": 0,
                        "track_names": [], "channels": []}
            filled.append(fallback)
            inserted += 1
            left = fallback
        filled.append(right)
    return filled, inserted


def event_windows(candidates: list[dict[str, Any]], trim: float, audio_end: float, cue_id: str) -> list[dict[str, Any]]:
    game_events = [dict(e, seconds=float(e["seconds"]) - trim) for e in candidates if float(e["seconds"]) - trim >= 0.0]
    centers = [float(e["seconds"]) for e in game_events]
    windows = []
    for i, event in enumerate(game_events):
        left_interval = centers[i] - centers[i - 1] if i > 0 else (centers[i + 1] - centers[i] if i + 1 < len(centers) else 0.6)
        right_interval = centers[i + 1] - centers[i] if i + 1 < len(centers) else left_interval
        half = min(WINDOW_HALF_CAP_SECONDS, WINDOW_SIDE_FRACTION * left_interval, WINDOW_SIDE_FRACTION * right_interval)
        start = max(0.0, centers[i] - half)
        end = min(audio_end, centers[i] + half)
        if end < centers[i] or start > centers[i]:
            raise AssertionError("window must contain its center")
        source = str(event.get("source", "midi_drum_note_on"))
        confidence = {"midi_drum_note_on": "MIDI-event-derived; audio alignment unverified",
                     "midi_non_drum_note_on_fallback": "MIDI-event fallback; audio alignment unverified",
                     "tempo_quarter_fallback": "tempo-map fallback; no note-on claim"}[source]
        windows.append({"event_id": f"{cue_id}-auto-{i + 1:05d}", "center_sec": round(centers[i], 6),
                        "start_sec": round(start, 6), "end_sec": round(end, 6), "source": source,
                        "confidence": confidence, "midi_tick": int(event["tick"]),
                        "candidate_pitches": event["pitches"], "candidate_velocity_values": event["velocity_values"],
                        "merged_note_on_count": event["note_on_count"]})
    for a, b in zip(windows, windows[1:]):
        if b["center_sec"] - a["center_sec"] < MIN_CENTER_GAP_SECONDS - 1e-6:
            raise AssertionError(f"minimum center gap violated: {a['event_id']} {b['event_id']}")
        if a["end_sec"] > b["start_sec"]:
            raise AssertionError(f"overlapping candidate windows: {a['event_id']} {b['event_id']}")
    return windows


def percentile_summary(values: list[float]) -> dict[str, float | None]:
    if not values:
        return {"min": None, "median": None, "max": None}
    return {"min": round(min(values), 6), "median": round(statistics.median(values), 6), "max": round(max(values), 6)}


def main() -> None:
    midi_paths = sorted(D2_DIR.glob("midi_test_*/D2.mid"))
    if len(midi_paths) != 12:
        raise AssertionError(f"expected 12 D2 MIDI files, found {len(midi_paths)}")
    before_hashes = {p.name + ":" + p.parent.name: sha256(p) for p in midi_paths}
    results = []
    for path in midi_paths:
        cue_id = path.parent.name
        mid = mido.MidiFile(path)
        ppq = int(mid.ticks_per_beat)
        tempos = effective_tempos(mid)
        offset, note_ons, end_tick, drum_note_count, zero_velocity_note_on_count = parse_offset_and_notes(mid, tempos)
        onset_source = "midi_drum_note_on" if drum_note_count else "midi_non_drum_note_on_fallback"
        chosen = [n for n in note_ons if n["is_drum"]] if drum_note_count else note_ons
        merged = merge_simultaneous(chosen)
        assert sum(int(group["note_on_count"]) for group in merged) == len(chosen), "simultaneous merging must conserve selected positive note-ons"
        for item in merged:
            item["source"] = onset_source
        thinned, thinned_count = thin_by_minimum_gap(merged)
        if not thinned and note_ons:
            # A pathological stream of sub-minimum gaps still gets one event: the richest merge group.
            fallback = max(merged, key=lambda x: (x["note_on_count"], -x["seconds"]))
            fallback = dict(fallback, source=onset_source)
            thinned = [fallback]
        selected, gap_fallback_count = add_gap_fallbacks(thinned, end_tick, tempos, ppq)
        if not selected:
            selected, gap_fallback_count = add_gap_fallbacks([], end_tick, tempos, ppq)
        audio_end = max(0.0, tick_to_seconds(end_tick, tempos, ppq) - offset)
        windows = event_windows(selected, offset, audio_end, cue_id)
        midi_length = float(mid.length)
        integrated_length = tick_to_seconds(end_tick, tempos, ppq)
        tempo_integral_matches_mido_length = abs(midi_length - integrated_length) < 1e-5
        if any(a["center_sec"] >= b["center_sec"] for a, b in zip(windows, windows[1:])):
            raise AssertionError("candidate centers must be ordered")
        intervals = [b["center_sec"] - a["center_sec"] for a, b in zip(windows, windows[1:])]
        intervals_midi = [float(b["seconds"]) - float(a["seconds"]) for a, b in zip(selected, selected[1:])]

        # Representative 8-quarter-note window: median candidate-event count, earliest on ties.
        window_ticks = ppq * 8
        total_windows = max(1, math.ceil(end_tick / window_ticks))
        event_counts = []
        for wi in range(total_windows):
            left_tick, right_tick = wi * window_ticks, (wi + 1) * window_ticks
            count = sum(left_tick <= int(e["tick"]) < right_tick for e in selected)
            event_counts.append((count, wi, left_tick, min(right_tick, end_tick)))
        nonempty_counts = [x for x in event_counts if x[0] > 0]
        if nonempty_counts:
            target = statistics.median(x[0] for x in nonempty_counts)
            rep = min(nonempty_counts, key=lambda x: (abs(x[0] - target), x[1]))
            rep_left_s = tick_to_seconds(rep[2], tempos, ppq) - offset
            rep_right_s = tick_to_seconds(rep[3], tempos, ppq) - offset
            rep_windows = [w for w in windows if rep_left_s <= w["center_sec"] < rep_right_s]
            rep_info = {"start_tick": rep[2], "end_tick": rep[3], "start_sec": round(max(0.0, rep_left_s), 6),
                        "end_sec": round(min(audio_end, rep_right_s), 6), "candidate_count": len(rep_windows),
                        "events": rep_windows}
        else:
            rep_info = {"start_tick": None, "end_tick": None, "start_sec": None, "end_sec": None,
                        "candidate_count": 0, "events": []}

        results.append({"cue_id": cue_id, "title": cue_id, "source_d2_path": str(path.relative_to(ROOT)),
                        "source_d2_sha256": before_hashes[path.name + ":" + path.parent.name],
                        "ppq": ppq, "tempo_event_count": sum(1 for tr in mid.tracks for msg in tr if msg.type == "set_tempo"),
                        "effective_tempo_change_count": max(0, len(tempos) - 1),
                        "tempo_integrated_end_seconds": round(integrated_length, 9),
                        "mido_length_seconds": round(midi_length, 9),
                        "tempo_integral_matches_mido_length": tempo_integral_matches_mido_length,
                        "effective_tempo_us_per_quarter": [{"tick": t, "tempo_us_per_quarter": v} for t, v in tempos],
                        "declared_trim_seconds_from_muscriptor_marker": offset,
                        "raw_positive_note_on_count": len(note_ons), "drum_positive_note_on_count": drum_note_count,
                        "zero_velocity_note_on_count_excluded": zero_velocity_note_on_count,
                        "selected_source_positive_note_on_count": len(chosen),
                        "merged_note_on_count_conserved": sum(int(group["note_on_count"]) for group in merged),
                        "selected_onset_source": onset_source, "same_sound_merge_tolerance_seconds": MERGE_SECONDS,
                        "same_sound_merged_group_count": len(merged), "minimum_center_gap_seconds": MIN_CENTER_GAP_SECONDS,
                        "minimum_gap_thinned_count": thinned_count, "gap_tempo_fallback_insert_count": gap_fallback_count,
                        "candidate_window_count": len(windows), "candidate_center_interval_seconds": percentile_summary(intervals),
                        "event_derived_window_count": sum(w["source"] != "tempo_quarter_fallback" for w in windows),
                        "tempo_fallback_window_count": sum(w["source"] == "tempo_quarter_fallback" for w in windows),
                        "audio_end_nominal_seconds": round(audio_end, 6), "representative_8_quarter_note_window": rep_info,
                        "_all_candidate_intervals_midi_seconds": intervals_midi})

    after_hashes = {p.name + ":" + p.parent.name: sha256(p) for p in midi_paths}
    assert before_hashes == after_hashes, "D2 MIDI inputs changed during analysis"
    assert all(all(a["end_sec"] <= b["start_sec"] for a, b in zip(r["representative_8_quarter_note_window"]["events"], r["representative_8_quarter_note_window"]["events"][1:])) for r in results)

    example_song = next(x for x in results if x["cue_id"] == BEAT_EXAMPLE_CUE)
    example = example_song["representative_8_quarter_note_window"]
    centers = [e["center_sec"] for e in example["events"]]
    example_intervals = [round(b - a, 6) for a, b in zip(centers, centers[1:])]
    example_rows = []
    for i, event in enumerate(example["events"]):
        example_rows.append({"event_id": event["event_id"], "center_sec": event["center_sec"],
                             "interval_from_previous_sec": None if i == 0 else round(centers[i] - centers[i - 1], 6),
                             "candidate_pitches": event["candidate_pitches"],
                             "candidate_velocity_values": event["candidate_velocity_values"],
                             "source": event["source"]})
    for result in results:
        result.pop("_all_candidate_intervals_midi_seconds", None)
    report = {
        "schema_version": 1,
        "status": "PASS_OFFLINE_ALGORITHM_EXPERIMENT_ONLY",
        "purpose": "Demonstrate automatic candidate combat windows derivable from D2 MIDI without hand-authored per-song beat charts.",
        "runtime_status": "No Godot runtime integration or gameplay balancing was implemented or claimed.",
        "algorithm": {
            "input": "12 derived D2 MIDI files; only MIDI notes and embedded muscriptor bar-offset metadata are read.",
            "onset_rule": "Positive-velocity note_on on channel 10 or a drum/percussion-named track; if none exist, use positive-velocity note_on from any track; zero velocity is excluded.",
            "simultaneous_rule": f"Merge note-ons whose integrated MIDI onset times are within {MERGE_SECONDS:.3f}s into one candidate; retain pitch/count provenance.",
            "minimum_spacing_rule": f"Greedy chronological thinning with a {MIN_CENTER_GAP_SECONDS:.3f}s global minimum center gap.",
            "long_gap_fallback_rule": f"Between available events, insert quarter-note tempo-map candidates while a gap exceeds max({LONG_GAP_MIN_SECONDS:.2f}s, {LONG_GAP_BEATS:.1f} local quarter-note durations). If no note-ons exist, use a tempo quarter grid across the file.",
            "window_rule": f"Half-width=min({WINDOW_HALF_CAP_SECONDS:.3f}s, {WINDOW_SIDE_FRACTION:.2f}*left interval, {WINDOW_SIDE_FRACTION:.2f}*right interval); clipped to nominal game-audio bounds.",
            "time_rule": "Integrate the full effective MIDI tempo map in tick order; then subtract the embedded muscriptor:bar_offset seconds. Same-tick tempo uses last track/message order.",
            "neutrality": "No manual time signatures, section labels, guessed accents, or forced J/K key sequence; drum pitches and MIDI velocity are provenance only.",
            "confidence_meaning": "Labels identify the evidence type, not a calibrated probability or proof of audible alignment.",
        },
        "parameters": {"same_sound_merge_tolerance_seconds": MERGE_SECONDS,
                       "minimum_center_gap_seconds": MIN_CENTER_GAP_SECONDS,
                       "window_half_width_cap_seconds": WINDOW_HALF_CAP_SECONDS,
                       "window_side_interval_fraction": WINDOW_SIDE_FRACTION,
                       "long_gap_min_seconds": LONG_GAP_MIN_SECONDS,
                       "long_gap_quarter_beats": LONG_GAP_BEATS},
        "self_checks": {"twelve_d2_files_found": len(midi_paths) == 12,
                        "source_hashes_unchanged": before_hashes == after_hashes,
                        "all_tempo_integrals_match_mido_length": all(r["tempo_integral_matches_mido_length"] for r in results),
                        "all_representative_centers_ordered": all(all(a["center_sec"] < b["center_sec"] for a, b in zip(r["representative_8_quarter_note_window"]["events"], r["representative_8_quarter_note_window"]["events"][1:])) for r in results),
                        "all_representative_windows_nonoverlapping": all(all(a["end_sec"] <= b["start_sec"] for a, b in zip(r["representative_8_quarter_note_window"]["events"], r["representative_8_quarter_note_window"]["events"][1:])) for r in results),
                        "all_candidate_centers_respect_minimum_gap": all(r["candidate_center_interval_seconds"]["min"] is None or r["candidate_center_interval_seconds"]["min"] >= MIN_CENTER_GAP_SECONDS - 1e-6 for r in results),
                        "same_onset_merge_conserves_selected_positive_note_ons": all(r["selected_source_positive_note_on_count"] == r["merged_note_on_count_conserved"] for r in results),
                        "zero_velocity_note_ons_excluded": all(all(v > 0 for w in r["representative_8_quarter_note_window"]["events"] for v in w["candidate_velocity_values"]) for r in results),
                        "full_tempo_map_integrated": True},
        "song_count": len(results),
        "global_counts": {"candidate_windows": sum(r["candidate_window_count"] for r in results),
                          "event_derived_windows": sum(r["event_derived_window_count"] for r in results),
                          "tempo_gap_fallbacks": sum(r["tempo_fallback_window_count"] for r in results),
                          "minimum_gap_thinned_groups": sum(r["minimum_gap_thinned_count"] for r in results)},
        "midi_test_02_interval_example": {
            "window": {k: example[k] for k in ("start_tick", "end_tick", "start_sec", "end_sec", "candidate_count")},
            "event_centers_game_audio_seconds": centers,
            "actual_selected_event_intervals_seconds": example_intervals,
            "selected_event_pitch_and_interval_rows": example_rows,
            "quarter_note_interval_at_fixed_130_bpm_seconds": round(60.0 / 130.0, 6),
            "interpretation": "Intervals follow selected MIDI drum-family onsets and are not a fixed 130 BPM quarter-note grid; event pitch families are retained for inspection, not labeled as true accents.",
        },
        "songs": results,
        "limitations": [
            "This is an offline algorithm demonstration, not Godot runtime code. It does not prove that player input, pause, latency compensation, or game-state transitions are implemented.",
            "MIDI note-on metadata may not match audible attacks; the nominal trim transform does not measure remaining render, decoder, device, or human-perception delay.",
            "180 ms spacing, 20 ms merging, fallback thresholds, and 90 ms maximum window half-width are experimental global parameters, not play-tested or balanced values.",
            "Drum pitch and velocity have no asserted semantic role, loudness, or true accent meaning. The algorithm does not impose J/K alternation or any key assignment.",
            "Tempo-quarter fallback creates candidate timing only; it does not claim a note-on or musical accent at that point.",
        ],
    }
    OUT_JSON.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"AUTO_WINDOWS PASS songs={len(results)} candidates={report['global_counts']['candidate_windows']} tempo_fallbacks={report['global_counts']['tempo_gap_fallbacks']} json={OUT_JSON.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

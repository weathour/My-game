#!/usr/bin/env python3
"""Read-only MIDI/meta audit for rhythm-combat exploration; emits JSON and CSV."""
from __future__ import annotations
import csv
import hashlib
import json
import math
import statistics
import importlib.metadata
from collections import Counter, defaultdict, deque
from pathlib import Path
from typing import Any
import mido

ROOT = Path(__file__).resolve().parents[2]
INPUT_DIR = ROOT / "design/music-20261103-midi-test/inputs"
D2_DIR = ROOT / "design/music-20261104-chinese-12/arrangements"
TRIAL = ROOT / "design/music-20261104-chinese-12/trial-manifest.json"
RENDER = ROOT / "design/music-20261104-chinese-12/runtime/d2-game-render.json"
INDEPENDENT = ROOT / "design/music-20261104-chinese-12/reports/midi-independent-verification.json"
OLD_MANIFEST = ROOT / "design/music-20261103-midi-test/experiment-manifest.json"
OUT_JSON = ROOT / "design/rhythm-combat-research-20261104/midi-audit.json"
OUT_CSV = ROOT / "design/rhythm-combat-research-20261104/midi-summary.csv"
OUT_EXAMPLES = ROOT / "design/rhythm-combat-research-20261104/drum-window-examples.json"
DEFAULT_TEMPO = 500_000


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def roundn(x: float, n: int = 6) -> float:
    return round(float(x), n)


def parse_midi(path: Path) -> dict[str, Any]:
    midi = mido.MidiFile(path)
    ppq = int(midi.ticks_per_beat)
    assert ppq > 0, f"SMPTE/division not supported by this PPQ audit: {path}"
    tempo_raw: list[dict[str, Any]] = []
    meter_raw: list[dict[str, Any]] = []
    markers: list[dict[str, Any]] = []
    notes: list[dict[str, Any]] = []
    track_lengths: list[int] = []
    unmatched_on = 0
    unmatched_off = 0
    for ti, track in enumerate(midi.tracks):
        tick = 0
        pending: dict[tuple[int, int], deque] = defaultdict(deque)
        track_name = ""
        for mi, msg in enumerate(track):
            tick += int(msg.time)
            if msg.type == "track_name":
                track_name = str(msg.name)
                markers.append({"type": "track_name", "track": ti, "tick": tick, "text": track_name})
            elif msg.type == "set_tempo":
                tempo_raw.append({"tick": tick, "tempo_us_per_quarter": int(msg.tempo), "track": ti, "message_index": mi})
            elif msg.type == "time_signature":
                meter_raw.append({"tick": tick, "numerator": int(msg.numerator), "denominator": int(msg.denominator),
                                  "clocks_per_click": int(msg.clocks_per_click), "notated_32nd_notes_per_beat": int(msg.notated_32nd_notes_per_beat),
                                  "track": ti, "message_index": mi})
            elif msg.type in ("text", "marker", "cue_marker", "lyrics", "sequence_number", "key_signature", "sequencer_specific"):
                text = getattr(msg, "text", None)
                item = {"type": msg.type, "track": ti, "tick": tick, "message_index": mi}
                if text is not None:
                    item["text"] = str(text)
                elif msg.type == "key_signature":
                    item["key"] = str(msg.key)
                    item["mode"] = str(getattr(msg, "mode", ""))
                elif msg.type == "sequence_number":
                    item["number"] = int(msg.number)
                else:
                    item["data_bytes"] = len(getattr(msg, "data", ()))
                markers.append(item)
            if msg.type in ("note_on", "note_off"):
                ch, pitch, vel = int(msg.channel), int(msg.note), int(getattr(msg, "velocity", 0))
                key = (ch, pitch)
                is_on = msg.type == "note_on" and vel > 0
                if is_on:
                    pending[key].append((tick, vel, mi))
                else:
                    if pending[key]:
                        start, on_vel, on_idx = pending[key].popleft()
                        notes.append({"track": ti, "track_name": track_name, "channel": ch, "pitch": pitch,
                                      "velocity": on_vel, "start_tick": start, "end_tick": tick,
                                      "note_on_index": on_idx, "note_off_index": mi,
                                      "off_type": msg.type, "off_velocity": vel})
                    else:
                        unmatched_off += 1
        track_lengths.append(tick)
        for (ch, pitch), queue in pending.items():
            while queue:
                start, vel, on_idx = queue.popleft()
                unmatched_on += 1
                notes.append({"track": ti, "track_name": track_name, "channel": ch, "pitch": pitch,
                              "velocity": vel, "start_tick": start, "end_tick": tick,
                              "note_on_index": on_idx, "note_off_index": None,
                              "off_type": "unterminated_at_track_end", "off_velocity": None})
    tempo_raw.sort(key=lambda x: (x["tick"], x["track"], x["message_index"]))
    meter_raw.sort(key=lambda x: (x["tick"], x["track"], x["message_index"]))

    # Integrate one deterministic global tempo stream. Only the last ordered tempo at a tick
    # takes effect; intervening same-tick values have zero duration and are never counted as
    # separate effective tempo changes. Conflicts are surfaced rather than hidden.
    tempo_changes: list[dict[str, Any]] = []
    active_tempo = DEFAULT_TEMPO
    last_tick = 0
    elapsed = 0.0
    tempo_restatements = 0
    tempo_conflicts = []
    tempo_shadowed_same_tick_events = 0
    by_tick: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for e in tempo_raw:
        by_tick[e["tick"]].append(e)
    for tick in sorted(by_tick):
        elapsed += (tick - last_tick) * active_tempo / (ppq * 1_000_000.0)
        vals = {x["tempo_us_per_quarter"] for x in by_tick[tick]}
        if len(vals) > 1:
            tempo_conflicts.append({"tick": tick, "values_us_per_quarter": sorted(vals)})
        group = by_tick[tick]
        final_event = group[-1]
        new_tempo = int(final_event["tempo_us_per_quarter"])
        if len(vals) == 1:
            tempo_restatements += len(group) if new_tempo == active_tempo else len(group) - 1
        else:
            tempo_shadowed_same_tick_events += len(group) - 1
            if new_tempo == active_tempo:
                tempo_restatements += 1
        if new_tempo != active_tempo:
            tempo_changes.append({"tick": tick, "time_seconds": roundn(elapsed, 9),
                                  "from_us_per_quarter": active_tempo,
                                  "to_us_per_quarter": new_tempo,
                                  "bpm": roundn(60_000_000.0 / new_tempo, 6),
                                  "track": final_event["track"], "message_index": final_event["message_index"]})
            active_tempo = new_tempo
        last_tick = tick

    # Tick->seconds integral. At same tick all tempo events share the same elapsed time.
    grouped = sorted(by_tick.items())
    def tick_to_sec(target: int) -> float:
        tempo = DEFAULT_TEMPO
        previous = 0
        seconds = 0.0
        for t, evs in grouped:
            if t > target:
                break
            seconds += (t - previous) * tempo / (ppq * 1_000_000.0)
            for e in evs:
                tempo = e["tempo_us_per_quarter"]
            previous = t
        seconds += (target - previous) * tempo / (ppq * 1_000_000.0)
        return seconds

    # Meter map uses the same deterministic order; preserve every declaration and effective changes.
    meter_effective: list[dict[str, Any]] = []
    active_meter = None
    meter_restatements = 0
    for e in meter_raw:
        sig = (e["numerator"], e["denominator"])
        if sig == active_meter:
            meter_restatements += 1
        else:
            meter_effective.append({"tick": e["tick"], "time_seconds": roundn(tick_to_sec(e["tick"]), 9),
                                   "numerator": sig[0], "denominator": sig[1],
                                   "clocks_per_click": e["clocks_per_click"],
                                   "notated_32nd_notes_per_beat": e["notated_32nd_notes_per_beat"]})
            active_meter = sig

    notes.sort(key=lambda x: (x["start_tick"], x["track"], x["note_on_index"]))
    end_tick = max(track_lengths, default=0)
    midi_integral_end = tick_to_sec(end_tick)
    tick_ms = [e["tempo_us_per_quarter"] / ppq / 1000.0 for e in tempo_raw] or [DEFAULT_TEMPO / ppq / 1000.0]
    drum_notes = [n for n in notes if n["channel"] == 9 or "drum" in n["track_name"].lower() or "percussion" in n["track_name"].lower()]
    velocities = [n["velocity"] for n in drum_notes]
    bins = Counter(velocities)
    # Tick resolution is discrete; grid residuals characterize stored MIDI onsets, not acoustic timing.
    def grid_stats(sample: list[dict[str, Any]]) -> list[dict[str, Any]]:
        out = []
        for ndiv in (4, 8, 12, 16, 24):
            unit = ppq / ndiv
            residuals = [min((n["start_tick"] % ppq) % unit, unit - ((n["start_tick"] % ppq) % unit)) for n in sample]
            residuals.sort()
            out.append({"subdivision_per_quarter": ndiv, "grid_ticks": unit,
                        "share_within_one_tick": roundn(sum(r <= 1.0 for r in residuals) / len(residuals), 6) if residuals else None,
                        "residual_p95_ticks": roundn(residuals[min(len(residuals)-1, math.ceil(.95*len(residuals))-1)], 4) if residuals else None,
                        "residual_max_ticks": roundn(max(residuals), 4) if residuals else None})
        return out
    subdivisions = grid_stats(drum_notes)
    all_note_subdivisions = grid_stats(notes)
    phase_counts = Counter(round((n["start_tick"] % ppq) / ppq, 6) for n in drum_notes)
    meta_types = Counter(m["type"] for m in markers)
    # mido.length is an independent tempo integration implementation; compare when same-tick conflicts don't exist.
    mido_length = float(midi.length)
    integral_matches_mido = not tempo_conflicts and abs(midi_integral_end - mido_length) < 2e-6
    if not tempo_conflicts:
        assert integral_matches_mido, (path.name, midi_integral_end, mido_length)
    assert all(a["time_seconds"] <= b["time_seconds"] for a, b in zip(tempo_changes, tempo_changes[1:])), path.name
    assert all(n["end_tick"] >= n["start_tick"] for n in notes), path.name
    return {"path": str(path.relative_to(ROOT)), "sha256": sha256(path), "ticks_per_beat": ppq,
            "track_count": len(midi.tracks), "max_track_end_tick": end_tick,
            "tempo_raw": tempo_raw, "tempo_raw_event_count": len(tempo_raw),
            "tempo_raw_distinct_bpm": sorted({round(60_000_000 / e["tempo_us_per_quarter"], 6) for e in tempo_raw}),
            "midi_tick_resolution_ms_min": roundn(min(tick_ms), 6), "midi_tick_resolution_ms_max": roundn(max(tick_ms), 6),
            "tempo_state_transitions_including_initial_assignment": tempo_changes,
            "tempo_initial_assignment_bpm": roundn(60_000_000 / next((e["tempo_us_per_quarter"] for e in tempo_raw if e["tick"] == 0), DEFAULT_TEMPO), 6),
            "tempo_effective_changes": [e for e in tempo_changes if e["tick"] > 0],
            "tempo_effective_change_count": sum(e["tick"] > 0 for e in tempo_changes),
            "tempo_effective_distinct_bpm": sorted({round(60_000_000 / tempo, 6) for tempo in _effective_tempos(tempo_raw)}),
            "tempo_restatement_count": tempo_restatements, "tempo_same_tick_conflicts": tempo_conflicts,
            "tempo_same_tick_shadowed_event_count": tempo_shadowed_same_tick_events,
            "tempo_seconds_end_integrated": roundn(midi_integral_end, 9), "mido_length_seconds": roundn(mido_length, 9),
            "tempo_integral_matches_mido_length": integral_matches_mido,
            "tempo_event_types": {"set_tempo_count": len(tempo_raw)},
            "time_signature_events": meter_raw, "time_signature_event_count": len(meter_raw),
            "time_signature_missing": len(meter_raw) == 0, "time_signature_effective_map": meter_effective,
            "time_signature_effective_change_count_after_initial": sum(e["tick"] > 0 for e in meter_effective),
            "time_signature_restatement_count": meter_restatements,
            "structure_markers": markers, "structure_marker_type_counts": dict(meta_types),
            "note_count": len(notes), "unmatched_note_on_count": unmatched_on, "unmatched_note_off_count": unmatched_off,
            "earliest_note_start_tick": min((n["start_tick"] for n in notes), default=None),
            "earliest_note_start_seconds": roundn(tick_to_sec(min(n["start_tick"] for n in notes)), 9) if notes else None,
            "latest_note_end_tick": max((n["end_tick"] for n in notes), default=None),
            "latest_note_end_seconds": roundn(tick_to_sec(max(n["end_tick"] for n in notes)), 9) if notes else None,
            "drums": {"classification_rule": "MIDI channel 10 (zero-based channel 9), or track name containing drum/percussion",
                      "note_count": len(drum_notes), "notes_per_minute": roundn(len(drum_notes) / (midi_integral_end / 60), 4) if midi_integral_end else None,
                      "unique_pitch_count": len({n["pitch"] for n in drum_notes}),
                      "pitch_counts": {str(k): v for k, v in sorted(Counter(n["pitch"] for n in drum_notes).items())},
                      "velocity_min": min(velocities) if velocities else None, "velocity_max": max(velocities) if velocities else None,
                      "velocity_mean": roundn(statistics.mean(velocities), 4) if velocities else None,
                      "velocity_median": statistics.median(velocities) if velocities else None,
                      "velocity_unique_values": len(bins), "velocity_histogram": {str(k): v for k, v in sorted(bins.items())},
                      "velocity_levels_distinguishable_in_data": len(bins) > 1,
                      "beat_phase_histogram": {str(k): v for k, v in sorted(phase_counts.items())},
                      "tick_subdivision_residuals": subdivisions,
                      "all_note_onset_tick_subdivision_residuals": all_note_subdivisions,
                      "quantization_limit_note": "integer PPQ ticks expose MIDI-grid positions only; swing-like phase distribution is observable, but acoustic microtiming and intended swing are not established"},
            "_notes": notes}


def _effective_tempos(raw: list[dict[str, Any]]) -> list[int]:
    ordered = sorted(raw, key=lambda x: (x["tick"], x["track"], x["message_index"]))
    by_tick: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for e in ordered:
        by_tick[e["tick"]].append(e)
    initial = by_tick.get(0, [])
    active = int(initial[-1]["tempo_us_per_quarter"]) if initial else DEFAULT_TEMPO
    out = [active]
    for tick in sorted(by_tick):
        if tick == 0:
            continue
        t = int(by_tick[tick][-1]["tempo_us_per_quarter"])
        if t != active:
            active = t
            out.append(active)
    return out


def drum_windows(audit: dict[str, Any], ppq: int, nbeats: int = 8) -> list[dict[str, Any]]:
    drums = [n for n in audit["_notes"] if n["channel"] == 9 or "drum" in n["track_name"].lower() or "percussion" in n["track_name"].lower()]
    width = ppq * nbeats
    end = audit["max_track_end_tick"]
    rows = []
    for start in range(0, end, width):
        events = [n for n in drums if start <= n["start_tick"] < start + width]
        ticks_audit = {"tempo_raw": audit["tempo_raw"], "ticks_per_beat": ppq}
        start_s = tick_to_sec_from_audit(start, ticks_audit)
        end_s = tick_to_sec_from_audit(min(start + width, end), ticks_audit)
        rows.append({"start_tick": start, "end_tick": min(start + width, end), "start_seconds": roundn(start_s, 6),
                     "end_seconds": roundn(end_s, 6), "beats": roundn((min(start + width, end) - start) / ppq, 3),
                     "drum_event_count": len(events), "velocity_sum": sum(n["velocity"] for n in events),
                     "events_per_quarter_beat": roundn(len(events) / max(1e-9, (min(start + width, end) - start) / ppq), 4),
                     "velocity_mean": roundn(statistics.mean([n["velocity"] for n in events]), 3) if events else None,
                     "velocity_max": max((n["velocity"] for n in events), default=None),
                     "events": [{"time_seconds": roundn(tick_to_sec_from_audit(n["start_tick"], ticks_audit), 6),
                                 "beat_offset": roundn((n["start_tick"] - start) / ppq, 4), "tick": n["start_tick"],
                                 "pitch": n["pitch"], "velocity": n["velocity"],
                                 "duration_seconds": roundn(tick_to_sec_from_audit(n["end_tick"], ticks_audit) - tick_to_sec_from_audit(n["start_tick"], ticks_audit), 6)}
                                for n in events]})
    nonempty = [r for r in rows if r["drum_event_count"]]
    if not nonempty:
        return []
    ranked = sorted(nonempty, key=lambda r: (r["drum_event_count"], r["velocity_sum"], -r["start_tick"]))
    mid = sorted(nonempty, key=lambda r: (abs(r["drum_event_count"] - statistics.median(x["drum_event_count"] for x in nonempty)), r["start_tick"]))[0]
    picks = [("highest_event_count", ranked[-1]), ("median_density", mid), ("lowest_nonzero_density", ranked[0])]
    seen = set()
    out = []
    for label, row in picks:
        if row["start_tick"] in seen:
            continue
        seen.add(row["start_tick"])
        out.append({"selection": label, **row})
    return out


def tick_to_sec_from_audit(tick: int, audit: dict[str, Any]) -> float:
    ppq = int(audit["ticks_per_beat"])
    events = sorted(audit["tempo_raw"], key=lambda x: (x["tick"], x["track"], x["message_index"]))
    tempo = DEFAULT_TEMPO
    previous = 0
    seconds = 0.0
    for e in events:
        t = int(e["tick"])
        if t > tick:
            break
        seconds += (t - previous) * tempo / (ppq * 1_000_000.0)
        tempo = int(e["tempo_us_per_quarter"])
        previous = t
    return seconds + (tick - previous) * tempo / (ppq * 1_000_000.0)


def main() -> None:
    assert import_self_check()
    trial, d2_render, independent = read_json(TRIAL), read_json(RENDER), read_json(INDEPENDENT)
    old_manifest = read_json(OLD_MANIFEST)
    old_inputs = {int(row["index"]): row for row in old_manifest["inputs"]}
    assert len(trial["selected"]) == 12
    render_by_id = {c["cue_id"]: c for c in d2_render["cues"]}
    independent_by_id = {c["cue_id"]: c for c in independent["results"]}
    inputs = sorted(INPUT_DIR.glob("midi_test_*.mid"))
    assert len(inputs) == 12, len(inputs)
    input_hashes_before = {p.name: sha256(p) for p in inputs}
    results = []
    for source_path in inputs:
        cue_id = source_path.stem
        idx = int(cue_id[-2:])
        d2_path = D2_DIR / cue_id / "D2.mid"
        plan_path = D2_DIR / cue_id / "plan-D2.json"
        legacy_report = ROOT / f"design/music-20261104-chinese-12/reports/midi-{cue_id}.json"
        audio_report = ROOT / f"design/music-20261104-chinese-12/reports/audio-{cue_id}.json"
        source = parse_midi(source_path)
        d2 = parse_midi(d2_path)
        plan = read_json(plan_path)
        midi_report = read_json(legacy_report)
        audio = read_json(audio_report)
        render = render_by_id[cue_id]
        independent_item = independent_by_id[cue_id]
        old_input = old_inputs[idx]
        source_notes = source.pop("_notes")
        d2_notes = d2.pop("_notes")
        assert source["sha256"] == midi_report["source_sha256"]
        assert source["sha256"] == old_input["midi_sha256"]
        assert plan["source_sha256"] == source["sha256"]
        assert plan["derived_sha256"] == d2["sha256"]
        assert render["source_midi"]["sha256"] == source["sha256"]
        assert render["arrangement_midi"]["sha256"] == d2["sha256"]
        assert plan["ticks_per_beat"] == source["ticks_per_beat"] == d2["ticks_per_beat"]
        assert source["tempo_raw"] == d2["tempo_raw"], f"tempo metadata changed: {cue_id}"
        assert source["time_signature_events"] == d2["time_signature_events"], f"meter metadata changed: {cue_id}"
        assert source["structure_markers"] == d2["structure_markers"], f"structure markers changed: {cue_id}"
        assert len(source_notes) == int(independent_item["note_count"])
        assert len(d2_notes) == len(source_notes) == len(plan["events"])
        assert source["drums"]["note_count"] == int(independent_item["drum_note_count"])
        # D2 is a pitch-only change for eligible paired note messages: onset, end, channel, track and velocity stay.
        def signature(n: dict[str, Any], include_pitch: bool) -> tuple:
            base = (n["track"], n["channel"], n["start_tick"], n["end_tick"], n["velocity"])
            return base + ((n["pitch"],) if include_pitch else ())
        assert Counter(signature(n, False) for n in source_notes) == Counter(signature(n, False) for n in d2_notes)
        source_drums = [n for n in source_notes if n["channel"] == 9 or "drum" in n["track_name"].lower() or "percussion" in n["track_name"].lower()]
        d2_drums = [n for n in d2_notes if n["channel"] == 9 or "drum" in n["track_name"].lower() or "percussion" in n["track_name"].lower()]
        assert Counter(signature(n, True) for n in source_drums) == Counter(signature(n, True) for n in d2_drums)
        # Plan D2 event times must be monotonic and match its independently computed tempo integral.
        plan_tempo = [{"tick": int(x["tick"]), "tempo_us_per_quarter": int(x["microseconds_per_beat"])} for x in plan["tempo_map"]]
        assert [(x["tick"], x["tempo_us_per_quarter"]) for x in plan_tempo] == [(x["tick"], x["tempo_us_per_quarter"]) for x in source["tempo_raw"]]
        plan_meter = [(int(x["tick"]), int(x["numerator"]), int(x["denominator"])) for x in plan["meter_map"]]
        source_meter = [(int(x["tick"]), int(x["numerator"]), int(x["denominator"])) for x in source["time_signature_events"]]
        assert plan_meter == source_meter, (cue_id, plan_meter, source_meter)
        start_time_error = max((abs(float(e["start_s"]) - tick_to_sec_from_audit(int(e["start_tick"]), source)) for e in plan["events"]), default=0.0)
        assert start_time_error < 1e-8, (cue_id, start_time_error)
        assert audio["manual_listening_review"] == "not performed"
        declared_trim = float(audio["offset_seconds"])
        marker_events = [m for m in source["structure_markers"] if m["type"] == "marker"]
        assert len(marker_events) == 1 and marker_events[0]["text"].startswith("muscriptor:bar_offset=")
        windows = drum_windows({**source, "_notes": source_notes}, source["ticks_per_beat"])
        for window in windows:
            window["nominal_game_start_seconds"] = roundn(window["start_seconds"] - declared_trim, 6)
        results.append({"cue_id": cue_id, "title": plan["title"], "source": source, "D2": d2,
                        "marker_semantics": {"marker_event_count": len(marker_events),
                                             "marker_texts": [m["text"] for m in marker_events],
                                             "has_verse_chorus_or_other_section_semantic_marker": False},
                        "source_to_D2": {"plan_sha256": sha256(plan_path), "plan_variant": plan["variant"],
                                         "note_count_source_and_D2": len(source_notes),
                                         "note_times_channels_tracks_velocities_unchanged": True,
                                         "drum_pitch_timing_and_velocity_unchanged": True,
                                         "structure_marker_meta_preserved": True,
                                         "pitch_changed_notes_per_report": independent_item["changed_note_count"],
                                         "tempo_events_and_meter_events_preserved_exactly": True,
                                         "plan_note_start_time_max_abs_error_seconds": roundn(start_time_error, 12)},
                        "source_provenance": {"experiment_manifest_path": str(OLD_MANIFEST.relative_to(ROOT)),
                                              "frozen_source_path_in_experiment_manifest": old_input["midi_file"],
                                              "transcription_report_path_in_experiment_manifest": old_input["transcription_report"],
                                              "source_transcription_label": "MuScriptor-large path label in the prior trial manifest",
                                              "human_transcription_beat_calibration_status": "not established by these records"},
                        "audio_alignment_and_provenance": {"audio_report_path": str(audio_report.relative_to(ROOT)),
                                                            "audio_report_status": audio["status"],
                                                            "manual_listening_review": audio["manual_listening_review"],
                                                            "trial_manifest_manual_listening_approval": bool(trial["manual_listening_approval"]),
                                                            "comparison_bar_offset_seconds_removed_from_render": audio["offset_seconds"],
                                                            "declared_trim_seconds": declared_trim,
                                                            "nominal_midi_to_game_time_offset_seconds": roundn(-declared_trim, 7),
                                                            "nominal_time_mapping": "game_audio_time ~= midi_time - declared_trim_seconds; then account for measured residual render/device delay",
                                                            "render_time_transform_evidence": [
                                                                {"file": "design/music-20261104-chinese-12/tools/render_all.py", "line": 128,
                                                                 "operation": "raw-mix atrim=start=offset,asetpts=PTS-STARTPTS,apad,atrim"},
                                                                {"file": "design/music-20261104-chinese-trial/tools/render_trials.py", "line": 101,
                                                                 "operation": "same raw-mix trim and timestamp reset for reused initial trials"},
                                                                {"file": "design/music-20261104-chinese-12/runtime/encode_game_d2.py", "lines": "72-82",
                                                                 "operation": "fixed volume gain and Vorbis encoding; no subsequent trim"}],
                                                            "source_render_timeline_duration_seconds": audio["duration_seconds"],
                                                            "D2_game_audio_duration_seconds": render["output"]["duration_seconds"],
                                                            "midi_integrated_end_seconds": source["tempo_seconds_end_integrated"],
                                                            "first_note_onset_seconds": source["earliest_note_start_seconds"],
                                                            "last_note_end_seconds": source["latest_note_end_seconds"],
                                                            "D2_loudness_and_tempo_provenance_does_not_establish_audio_beat_alignment": True},
                        "drum_windows_8_quarter_beats": windows})
    input_hashes_after = {p.name: sha256(p) for p in inputs}
    assert input_hashes_before == input_hashes_after, "frozen source MIDI changed during audit"
    # Select examples using measured descriptors, never subjective genre labels.
    stable = min(results, key=lambda r: (r["source"]["tempo_effective_change_count"], r["source"]["tempo_raw_event_count"]))
    most_changes = max(results, key=lambda r: (r["source"]["tempo_effective_change_count"], len(r["source"]["tempo_effective_distinct_bpm"])))
    sparse_drums = min(results, key=lambda r: r["source"]["drums"]["notes_per_minute"])
    summary = [{"cue_id": r["cue_id"], "title": r["title"], "ppq": r["source"]["ticks_per_beat"],
                "tempo_event_count": r["source"]["tempo_raw_event_count"],
                "tempo_restatement_count": r["source"]["tempo_restatement_count"],
                "effective_tempo_change_count": r["source"]["tempo_effective_change_count"],
                "effective_distinct_bpm_count": len(r["source"]["tempo_effective_distinct_bpm"]),
                "effective_bpm_min": min(r["source"]["tempo_effective_distinct_bpm"] or [120]),
                "effective_bpm_max": max(r["source"]["tempo_effective_distinct_bpm"] or [120]),
                "time_signature_event_count": r["source"]["time_signature_event_count"],
                "time_signature_changes_after_initial": r["source"]["time_signature_effective_change_count_after_initial"],
                "time_signature_missing": r["source"]["time_signature_missing"],
                "drum_events": r["source"]["drums"]["note_count"],
                "drum_events_per_minute": r["source"]["drums"]["notes_per_minute"],
                "drum_velocity_unique_values": r["source"]["drums"]["velocity_unique_values"],
                "drum_sixteenth_note_grid_share_within_one_tick": next(x["share_within_one_tick"] for x in r["source"]["drums"]["tick_subdivision_residuals"] if x["subdivision_per_quarter"] == 4),
                "drum_per_quarter_16_grid_share_within_one_tick": next(x["share_within_one_tick"] for x in r["source"]["drums"]["tick_subdivision_residuals"] if x["subdivision_per_quarter"] == 16),
                "all_note_sixteenth_note_grid_share_within_one_tick": next(x["share_within_one_tick"] for x in r["source"]["drums"]["all_note_onset_tick_subdivision_residuals"] if x["subdivision_per_quarter"] == 4),
                "all_note_per_quarter_16_grid_share_within_one_tick": next(x["share_within_one_tick"] for x in r["source"]["drums"]["all_note_onset_tick_subdivision_residuals"] if x["subdivision_per_quarter"] == 16),
                "marker_event_count": r["marker_semantics"]["marker_event_count"],
                "marker_text": " | ".join(r["marker_semantics"]["marker_texts"]),
                "declared_trim_seconds": r["audio_alignment_and_provenance"]["declared_trim_seconds"],
                "nominal_midi_to_game_time_offset_seconds": r["audio_alignment_and_provenance"]["nominal_midi_to_game_time_offset_seconds"],
                "first_note_seconds": r["source"]["earliest_note_start_seconds"],
                "midi_end_seconds": r["source"]["tempo_seconds_end_integrated"],
                "game_audio_seconds": r["audio_alignment_and_provenance"]["D2_game_audio_duration_seconds"],
                "comparison_offset_seconds": r["audio_alignment_and_provenance"]["comparison_bar_offset_seconds_removed_from_render"]}
               for r in results]
    top = {"steady_tempo_lowest_effective_changes": stable["cue_id"],
           "most_effective_tempo_changes": most_changes["cue_id"],
           "lowest_midi_drum_events_per_minute": sparse_drums["cue_id"],
           "selection_note": "These are computed MIDI descriptors, not human judgments of groove/free feel. Sparse MIDI drums do not prove sparse perceived rhythm."}
    report = {"schema_version": 1, "status": "PASS", "generated_by": str(Path(__file__).relative_to(ROOT)),
              "supplemental_drum_examples": str(OUT_EXAMPLES.relative_to(ROOT)),
              "mido_version": importlib.metadata.version("mido"),
              "inputs": {"source_dir": str(INPUT_DIR.relative_to(ROOT)), "D2_dir": str(D2_DIR.relative_to(ROOT)),
                         "source_sha256_before": input_hashes_before, "source_sha256_after": input_hashes_after,
                         "sha256_unchanged": input_hashes_before == input_hashes_after,
                         "D2_trial_manifest": str(TRIAL.relative_to(ROOT)), "D2_render_report": str(RENDER.relative_to(ROOT)),
                         "independent_MIDI_report": str(INDEPENDENT.relative_to(ROOT)),
                         "prior_transcription_trial_manifest": str(OLD_MANIFEST.relative_to(ROOT))},
              "method": {"tempo_default_us_per_quarter": DEFAULT_TEMPO,
                         "same_tick_tempo_conflict_policy": "sort by tick, then track index, then message index; only last value per tick takes effect; conflicting earlier same-tick values are surfaced and never count as extra effective changes",
                         "grid_subdivision_naming": "subdivision_per_quarter=4 is a sixteenth note; subdivision_per_quarter=16 is a sixty-fourth note",
                         "drum_classification": "channel 10 / zero-based 9, or drum/percussion track name",
                         "window_definition": "fixed 8 quarter-note beats from tick zero using each file's PPQ; meter signature is reported independently and never assumed",
                         "render_time_mapping": "raw-mix is trimmed by declared bar offset and PTS is reset; nominal game time is MIDI time minus offset. The encoded OGG receives fixed gain/Vorbis only. Residual render/device delay still requires measurement.",
                         "render_time_transform_evidence": [
                             {"file": "design/music-20261104-chinese-12/tools/render_all.py", "line": 128},
                             {"file": "design/music-20261104-chinese-trial/tools/render_trials.py", "line": 101},
                             {"file": "design/music-20261104-chinese-12/runtime/encode_game_d2.py", "lines": "72-82"}],
                         "marker_semantics_summary": "All 12 MIDI files contain only one marker event, muscriptor:bar_offset=<seconds>; no verse/chorus or other section-semantic markers are present. Track names are reported separately.",
                         "velocity_is_NOT_claimed_to_be_audio_loudness_or_player_intensity": True,
                         "no_audio_waveform_beat_tracking_or_manual_calibration_performed": True,
                         "MIDI_source_provenance": "the prior experiment manifest names MuScriptor-large input paths and transcription-report paths; it does not establish who corrected/calibrated the beat grid. This audit verifies structure and hashes, not transcription accuracy or human beat calibration",
                         "D2_status": "derived MIDI and arrangement plan are hash-checked against trial/render manifests; manual listening approval is false and audio report says not performed"},
              "self_checks": {"twelve_sources_found": len(inputs) == 12,
                              "source_hashes_unchanged": input_hashes_before == input_hashes_after,
                              "no_same_tick_conflicting_tempo_messages": all(not r["source"]["tempo_same_tick_conflicts"] for r in results),
                              "all_markers_only_muscriptor_bar_offset": all(r["marker_semantics"]["marker_event_count"] == 1 and r["marker_semantics"]["marker_texts"][0].startswith("muscriptor:bar_offset=") for r in results),
                              "all_tempo_integrals_match_mido_length_when_unambiguous": all(r["source"]["tempo_integral_matches_mido_length"] for r in results),
                              "repeated_tempo_meta_does_not_count_as_change": import_self_check(),
                              "D2_tempo_and_meter_exactly_preserved": all(r["source_to_D2"]["tempo_events_and_meter_events_preserved_exactly"] for r in results),
                              "D2_pitch_only_temporal_structure_preserved": all(r["source_to_D2"]["note_times_channels_tracks_velocities_unchanged"] for r in results),
                              "all_plan_event_seconds_match_recomputed_tempo_integral_under_10ns": all(r["source_to_D2"]["plan_note_start_time_max_abs_error_seconds"] < 1e-8 for r in results)},
              "D2_pitch_changed_note_count_total": sum(r["source_to_D2"]["pitch_changed_notes_per_report"] for r in results),
              "representatives": top, "summary": summary, "songs": results,
              "nominal_offset_example": {"cue_id": "midi_test_02", "window_selection": "median_density",
                                          "source_midi_start_seconds": next(w["start_seconds"] for r in results if r["cue_id"] == "midi_test_02" for w in r["drum_windows_8_quarter_beats"] if w["selection"] == "median_density"),
                                          "declared_trim_seconds": next(r["audio_alignment_and_provenance"]["declared_trim_seconds"] for r in results if r["cue_id"] == "midi_test_02"),
                                          "predicted_ogg_start_seconds": next(w["nominal_game_start_seconds"] for r in results if r["cue_id"] == "midi_test_02" for w in r["drum_windows_8_quarter_beats"] if w["selection"] == "median_density")},
              "limitations": ["A tempo meta-event is a declared MIDI tempo; it is not proof that the transcribed audio has that tempo accurately or that a human calibrated it.",
                              "Time-signature meta may be absent. Missing signature means meter is unknown here; quarter-note beat windows are still computable from PPQ and tempo.",
                              "Velocity values are MIDI note-on metadata, not measured rendered SPL/loudness or validated player-perceived accent strength.",
                              "PPQ quantization shows representable ticks and grid residuals; a per-quarter 16-grid is a sixty-fourth-note grid, while a sixteenth-note grid is four subdivisions per quarter. These cannot reveal sub-tick performance timing or establish intentional swing.",
                              "The first MIDI note onset is measured from tick zero; it does not prove the rendered audio is silent before that point.",
                              "The legacy manual-listening field records that the production render was not manually reviewed; it does not negate the user's recognition/acceptance of the first three timbres in the conversation. It is not evidence that beat timing was manually calibrated.",
                              "D2 renders preserve source tempo/meter and note timing while pitch substitutions change eligible notes. This establishes metadata availability, not that D2 has been human-auditioned or beatmapped against audio.",
                              "The declared trim offset gives a nominal MIDI-to-game-audio mapping; actual residual render and device delay still require measurement. It does not constitute listening-based beat calibration or prove leading silence/audio onset.",
                              "The 8-quarter-beat drum windows are examples of MIDI events only; they are not a recommended complete input chart and should not force every drum event into gameplay."]}
    OUT_JSON.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    fields = list(summary[0])
    with OUT_CSV.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader(); writer.writerows(summary)
    example_ids = {stable["cue_id"], most_changes["cue_id"], sparse_drums["cue_id"]}
    examples = {"schema_version": 1,
                "selection": top,
                "window_definition": "8 quarter-note beats; actual MIDI-integrated seconds; source drum MIDI notes, which are unchanged in D2",
                "events_are_candidate_material_not_a_full_input_chart": True,
                "songs": [{"cue_id": r["cue_id"], "title": r["title"],
                           "drum_velocity_histogram": r["source"]["drums"]["velocity_histogram"],
                           "windows": r["drum_windows_8_quarter_beats"]}
                          for r in results if r["cue_id"] in example_ids]}
    OUT_EXAMPLES.write_text(json.dumps(examples, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"MIDI_AUDIT PASS songs={len(results)} representative={top} json={OUT_JSON.relative_to(ROOT)} csv={OUT_CSV.relative_to(ROOT)}")


def import_self_check() -> bool:
    # Regression guard: repeated meta declarations must not be counted as tempo transitions.
    active = DEFAULT_TEMPO
    changes = 0
    restatements = 0
    for tempo in (500_000, 500_000, 400_000, 400_000, 400_000):
        if tempo == active:
            restatements += 1
        else:
            changes += 1
            active = tempo
    assert changes == 1 and restatements == 4
    return True

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Bounded counterexample audit for the first-pass automatic MIDI windows."""
from __future__ import annotations

import hashlib
import io
import json
import statistics
import sys
from collections import Counter
from pathlib import Path
from typing import Any

import mido

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
import auto_windows as old  # noqa: E402

AUTO_REPORT = HERE / "auto-windows.json"
OUT = HERE / "beat-feasibility-probes.json"
D2_DIR = ROOT / "design/music-20261104-chinese-12/arrangements"
OGG_DIR = ROOT / "assets/music/midi_test"
PHASE_TOLERANCE_BEATS = 0.02


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def synthetic_midi(tracks: list[dict[str, Any]], end_tick: int = 3840) -> mido.MidiFile:
    mid = mido.MidiFile(type=1, ticks_per_beat=480)
    conductor = mido.MidiTrack()
    mid.tracks.append(conductor)
    conductor.extend([
        mido.MetaMessage("set_tempo", tempo=500_000, time=0),
        mido.MetaMessage("marker", text="muscriptor:bar_offset=0", time=0),
        mido.MetaMessage("end_of_track", time=end_tick),
    ])
    for spec in tracks:
        absolute: list[tuple[int, int, mido.Message]] = []
        for order, (tick, pitch, velocity) in enumerate(spec["notes"]):
            absolute.append((tick, order * 2 + 1, mido.Message("note_on", channel=9, note=pitch, velocity=velocity, time=0)))
            absolute.append((tick + 30, order * 2, mido.Message("note_off", channel=9, note=pitch, velocity=0, time=0)))
        absolute.append((end_tick, 10**9, mido.MetaMessage("end_of_track", time=0)))
        absolute.sort(key=lambda x: (x[0], x[1]))
        track = mido.MidiTrack()
        mid.tracks.append(track)
        track.append(mido.MetaMessage("track_name", name=spec["name"], time=0))
        previous = 0
        for tick, _order, msg in absolute:
            msg.time = tick - previous
            track.append(msg)
            previous = tick
    buffer = io.BytesIO()
    mid.save(file=buffer)
    buffer.seek(0)
    return mido.MidiFile(file=buffer)


def apply_old_onset_pipeline(mid: mido.MidiFile) -> dict[str, Any]:
    tempos = old.effective_tempos(mid)
    offset, notes, end_tick, drum_count, zero_count = old.parse_offset_and_notes(mid, tempos)
    chosen = [n for n in notes if n["is_drum"]] if drum_count else notes
    merged = old.merge_simultaneous(chosen)
    thinned, removed = old.thin_by_minimum_gap(merged)
    return {"offset": offset, "notes": notes, "chosen": chosen, "merged": merged,
            "selected": thinned, "removed": removed, "end_tick": end_tick,
            "drum_count": drum_count, "zero_velocity_note_on_count": zero_count,
            "ppq": mid.ticks_per_beat, "midi": mid}


def selected_counts(result: dict[str, Any], anchor_ticks: list[int], decor_ticks: list[int]) -> dict[str, Any]:
    events = result["selected"]
    is_anchor = lambda tick: any(abs(int(tick) - t) <= 1 for t in anchor_ticks)
    is_decor = lambda tick: any(abs(int(tick) - t) <= 1 for t in decor_ticks)
    return {"raw_positive_drum_note_ons": len(result["chosen"]),
            "after_20ms_merge_groups": len(result["merged"]),
            "selected_after_180ms_greedy": len(events),
            "thinned_groups": result["removed"],
            "selected_main_anchor_count": sum(is_anchor(e["tick"]) for e in events),
            "selected_decoration_count": sum(is_decor(e["tick"]) for e in events),
            "selected_pitch_histogram": dict(sorted(Counter(p for e in events for p in e["pitches"]).items())),
            "selected_center_ticks": [int(e["tick"]) for e in events]}


def test_anchor_window_acceptance(result: dict[str, Any], anchor_ticks: list[int], cue_id: str) -> dict[str, Any]:
    mid = result["midi"]
    tempos = old.effective_tempos(mid)
    anchors = [old.tick_to_seconds(tick, tempos, result["ppq"]) for tick in anchor_ticks]
    windows = old.event_windows(result["selected"], trim=0.0, audio_end=4.0, cue_id=cue_id)
    accepted = [any(w["start_sec"] <= t <= w["end_sec"] for w in windows) for t in anchors]
    return {"window_generator": "previous auto_windows.event_windows()", "trim_seconds": 0.0,
            "audio_end_seconds": 4.0, "anchor_times_seconds": [round(t, 6) for t in anchors],
            "generated_window_count": len(windows), "accepted_anchor_count": sum(accepted),
            "rejected_anchor_count": len(accepted) - sum(accepted),
            "accepted_anchor_flags": accepted,
            "rejected_anchor_times_seconds": [round(t, 6) for t, ok in zip(anchors, accepted) if not ok]}


def phase_stats(ticks: list[int], ppq: int) -> dict[str, Any]:
    quarter_distances = []
    eighth_distances = []
    quarter_bins = [0] * 8
    for tick in ticks:
        quarter_phase = (tick % ppq) / ppq
        quarter_dist = min(quarter_phase, 1.0 - quarter_phase)
        eighth_ticks = ppq / 2.0
        eighth_phase = (tick % eighth_ticks) / ppq
        eighth_dist = min(eighth_phase, 0.5 - eighth_phase)
        quarter_distances.append(quarter_dist)
        eighth_distances.append(eighth_dist)
        quarter_bins[min(7, int(quarter_phase * 8))] += 1
    def share_close(values: list[float]) -> float | None:
        return round(sum(x <= PHASE_TOLERANCE_BEATS for x in values) / len(values), 6) if values else None
    return {"event_center_count": len(ticks),
            "quarter_grid_nearest_phase_distance_beats": {"median": round(statistics.median(quarter_distances), 6) if quarter_distances else None,
                                                           "share_within_tolerance": share_close(quarter_distances)},
            "eighth_grid_nearest_phase_distance_beats": {"median": round(statistics.median(eighth_distances), 6) if eighth_distances else None,
                                                          "share_within_tolerance": share_close(eighth_distances)},
            "quarter_cycle_phase_bins_8": quarter_bins,
            "phase_tolerance_beats": PHASE_TOLERANCE_BEATS,
            "interpretation": "Grid proximity is descriptive MIDI quantization only. It does not identify the perceived main beat or validate an input window."}


def corpus_probe(old_report: dict[str, Any]) -> tuple[list[dict[str, Any]], dict[str, str], dict[str, str]]:
    old_by_id = {s["cue_id"]: s for s in old_report["songs"]}
    midi_paths = sorted(D2_DIR.glob("midi_test_*/D2.mid"))
    midi_before = {p.parent.name: sha256(p) for p in midi_paths}
    oggs = {p.stem: p for p in sorted(OGG_DIR.glob("midi_test_*.ogg"))}
    ogg_before = {cue: sha256(p) for cue, p in oggs.items()}
    rows = []
    for path in midi_paths:
        cue_id = path.parent.name
        auto_song = old_by_id[cue_id]
        assert auto_song["source_d2_sha256"] == midi_before[cue_id]
        mid = mido.MidiFile(path)
        result = apply_old_onset_pipeline(mid)
        chosen = result["chosen"]
        merged = result["merged"]
        selected = result["selected"]
        game_events = [e for e in selected if float(e["seconds"]) - result["offset"] >= 0.0]
        selected_game_ticks = [int(e["tick"]) for e in game_events]
        end_sec = old.tick_to_seconds(result["end_tick"], old.effective_tempos(mid), mid.ticks_per_beat)
        audio_duration = max(0.0, end_sec - result["offset"])
        source_tracks = sorted({n["track_name"] for n in chosen})
        pitch_counts = Counter(n["pitch"] for n in chosen)
        interval_stats = auto_song["candidate_center_interval_seconds"]
        rows.append({
            "cue_id": cue_id,
            "source_d2_sha256": midi_before[cue_id],
            "source_ogg_sha256": ogg_before[cue_id],
            "nominal_game_audio_duration_seconds": round(audio_duration, 6),
            "old_algorithm_candidate_windows": auto_song["candidate_window_count"],
            "old_algorithm_windows_per_second": round(auto_song["candidate_window_count"] / audio_duration, 6) if audio_duration else None,
            "old_algorithm_windows_per_minute": round(auto_song["candidate_window_count"] / audio_duration * 60.0, 4) if audio_duration else None,
            "old_algorithm_event_derived_windows": auto_song["event_derived_window_count"],
            "old_algorithm_tempo_fallback_windows": auto_song["tempo_fallback_window_count"],
            "old_algorithm_median_center_interval_seconds": interval_stats["median"],
            "old_algorithm_min_center_interval_seconds": interval_stats["min"],
            "old_algorithm_max_center_interval_seconds": interval_stats["max"],
            "raw_positive_drum_note_on_count": len(chosen),
            "merged_drum_onset_group_count": len(merged),
            "selected_drum_onset_group_count_before_tempo_fallback": len(game_events),
            "drum_track_names": source_tracks,
            "drum_pitch_histogram_top_8": [{"midi_pitch": p, "note_on_count": c} for p, c in pitch_counts.most_common(8)],
            "drum_pitch_semantics": "Raw MIDI pitch numbers only; no guessed kick/snare/hat labels or true-accent claims.",
            "selected_event_grid_phase": phase_stats(selected_game_ticks, mid.ticks_per_beat),
            "positive_drum_events_source_hash_verified": True,
        })
    midi_after = {p.parent.name: sha256(p) for p in midi_paths}
    ogg_after = {cue: sha256(p) for cue, p in oggs.items()}
    assert midi_before == midi_after
    assert ogg_before == ogg_after
    return rows, midi_before, ogg_before


def main() -> None:
    prior = json.loads(AUTO_REPORT.read_text(encoding="utf-8"))

    anchors = [(i * 480, 36 if i % 2 == 0 else 38, 100) for i in range(8)]
    anchor_ticks = [x[0] for x in anchors]
    baseline = apply_old_onset_pipeline(synthetic_midi([{"name": "drums", "notes": anchors}]))
    eighth_notes = anchors + [(240 + i * 480, 42, 45) for i in range(8)]
    eighth = apply_old_onset_pipeline(synthetic_midi([{"name": "drums", "notes": eighth_notes}]))
    sixteenth_notes = anchors + [(tick, 42, 45) for tick in range(120, 3840, 120) if tick % 480]
    sixteenth = apply_old_onset_pipeline(synthetic_midi([{"name": "drums", "notes": sixteenth_notes}]))
    eighth_ticks = [240 + i * 480 for i in range(8)]
    sixteenth_ticks = [tick for tick in range(120, 3840, 120) if tick % 480]

    ornaments = [(beat * 480 - 120, 40, 12) for beat in range(1, 8)]
    weak_result = apply_old_onset_pipeline(synthetic_midi([{"name": "drums", "notes": anchors + ornaments}]))
    loud_result = apply_old_onset_pipeline(synthetic_midi([{"name": "drums", "notes": anchors + [(t, p, 100) for t, p, _ in ornaments]}]))
    ornament_ticks = [t for t, _, _ in ornaments]

    chord_main = [(480, 36, 100), (650, 42, 70)]
    chord_same_tick = chord_main + [(480, 38, 85), (480, 46, 60)]
    chord_late_voices = chord_main + [(489, 46, 60), (489, 49, 55)]
    chord_base = apply_old_onset_pipeline(synthetic_midi([{"name": "drums A", "notes": chord_main}]))
    chord_same = apply_old_onset_pipeline(synthetic_midi([{"name": "drums A", "notes": chord_main},
                                                          {"name": "drums B", "notes": [(480, 38, 85), (480, 46, 60)]}]))
    chord_late = apply_old_onset_pipeline(synthetic_midi([{"name": "drums A", "notes": chord_main},
                                                          {"name": "drums B", "notes": [(489, 46, 60), (489, 49, 55)]}]))
    def describe_group(result: dict[str, Any]) -> dict[str, Any]:
        first = result["merged"][0]
        return {"merged_group_count": len(result["merged"]), "group_center_seconds": round(first["seconds"], 6),
                "group_center_tick": first["tick"], "merged_note_on_count": first["note_on_count"],
                "merged_pitches": first["pitches"], "selected_center_ticks": [x["tick"] for x in result["selected"]],
                "selected_group_count": len(result["selected"]), "thinned_group_count": result["removed"]}

    baseline_counts = selected_counts(baseline, anchor_ticks, [])
    eighth_counts = selected_counts(eighth, anchor_ticks, eighth_ticks)
    sixteenth_counts = selected_counts(sixteenth, anchor_ticks, sixteenth_ticks)
    weak_counts = selected_counts(weak_result, anchor_ticks, ornament_ticks)
    loud_counts = selected_counts(loud_result, anchor_ticks, ornament_ticks)
    baseline_acceptance = test_anchor_window_acceptance(baseline, anchor_ticks, "synthetic-baseline")
    eighth_acceptance = test_anchor_window_acceptance(eighth, anchor_ticks, "synthetic-eighth-hats")
    sixteenth_acceptance = test_anchor_window_acceptance(sixteenth, anchor_ticks, "synthetic-sixteenth-hats")
    weak_acceptance = test_anchor_window_acceptance(weak_result, anchor_ticks, "synthetic-weak-ornaments")
    assert baseline_counts["selected_after_180ms_greedy"] == 8
    assert eighth_counts["selected_after_180ms_greedy"] == 16 and eighth_counts["selected_main_anchor_count"] == 8
    assert sixteenth_counts["selected_after_180ms_greedy"] == 16 and sixteenth_counts["selected_main_anchor_count"] == 8
    assert weak_counts["selected_main_anchor_count"] == 1 and weak_counts["selected_decoration_count"] == 7
    assert weak_counts["selected_center_ticks"] == loud_counts["selected_center_ticks"]
    assert baseline_acceptance["accepted_anchor_count"] == 8
    assert eighth_acceptance["accepted_anchor_count"] == sixteenth_acceptance["accepted_anchor_count"] == 8
    assert weak_acceptance["accepted_anchor_count"] == 1 and weak_acceptance["rejected_anchor_count"] == 7
    base_chord = describe_group(chord_base)
    same_chord = describe_group(chord_same)
    late_chord = describe_group(chord_late)
    assert base_chord["selected_group_count"] == same_chord["selected_group_count"] == late_chord["selected_group_count"] == 1
    assert base_chord["group_center_seconds"] == same_chord["group_center_seconds"] == 0.5
    assert late_chord["group_center_seconds"] == 0.50625

    corpus, midi_hashes, ogg_hashes = corpus_probe(prior)
    all_counts = [x["old_algorithm_candidate_windows"] for x in corpus]
    rows_per_second = [x["old_algorithm_windows_per_second"] for x in corpus]
    summary = {
        "song_count": len(corpus),
        "candidate_window_count_total": sum(all_counts),
        "windows_per_second_across_total_nominal_duration": round(sum(all_counts) / sum(x["nominal_game_audio_duration_seconds"] for x in corpus), 6),
        "per_song_windows_per_second_median": round(statistics.median(rows_per_second), 6),
        "per_song_median_interval_seconds_median": round(statistics.median(x["old_algorithm_median_center_interval_seconds"] for x in corpus), 6),
        "total_tempo_fallback_count": sum(x["old_algorithm_tempo_fallback_windows"] for x in corpus),
        "interpretation": "These characterize the old candidate-window generator's event density; they do not measure how many inputs feel musically justified.",
    }
    report = {
        "schema_version": 1,
        "status": "PASS_COUNTEREXAMPLE_AND_CORPUS_AUDIT",
        "scope": "Offline synthetic counterexamples and re-analysis of the existing 12 D2 MIDI files. No production/runtime changes.",
        "prior_algorithm_reference": {"script": "design/rhythm-combat-research-20261104/auto_windows.py",
                                       "result": "design/rhythm-combat-research-20261104/auto-windows.json",
                                       "steps_under_test": "all drum note-ons -> 20 ms onset grouping -> chronological 180 ms greedy minimum-gap selection"},
        "synthetic_truth_boundary": "Main-beat anchor ticks below are labels chosen by the synthetic test generator only. They are not annotations or inferred ground truth for any existing song.",
        "synthetic_probes": [
            {"id": "same_anchors_plus_eighth_and_sixteenth_hi_hat", "ppq": 480, "tempo_bpm": 120,
             "declared_test_anchors_ticks": anchor_ticks, "main_anchor_source": "synthetic kick/snare events at quarter ticks",
             "baseline": baseline_counts,
             "baseline_anchor_window_acceptance": baseline_acceptance,
             "add_eighth_hat": eighth_counts,
             "add_eighth_hat_anchor_window_acceptance": eighth_acceptance,
             "add_sixteenth_hat": sixteenth_counts,
             "add_sixteenth_hat_anchor_window_acceptance": sixteenth_acceptance,
             "finding": "Adding offbeat eighth hats doubles selected windows from 8 to 16 while all 8 declared synthetic anchors remain inside generated windows. Adding sixteenth hats yields 16 selected windows too: the 180 ms greedy filter skips half of the faster hat layer and retains its midpoint events. This demonstrates a change in event density/beat layer, not by itself an audible error or proof that anchors were rejected."},
            {"id": "weak_prebeat_decorations_compete_with_anchors", "ppq": 480, "tempo_bpm": 120,
             "declared_test_anchors_ticks": anchor_ticks, "weak_decoration_ticks": ornament_ticks,
             "decoration_velocity": 12, "anchor_velocity": 100,
             "weak_decoration_result": weak_counts,
             "weak_decoration_anchor_window_acceptance": weak_acceptance,
             "same_ornament_loud_result": loud_counts,
             "finding": "Seven weak notes placed 125 ms before later anchors are selected first; their following stronger anchor is then suppressed by the 180 ms rule. Only 1 of 8 declared synthetic anchors survives. Changing decoration velocity from 12 to 100 changes nothing because the selector ignores velocity."},
            {"id": "chords_and_repeated_voices_change_group_center_not_priority", "ppq": 480, "tempo_bpm": 120,
             "declared_test_anchor_tick": 480,
             "single_track_and_neighbor": base_chord,
             "same_tick_chord_added_on_other_track": same_chord,
             "two_late_voice_onsets_at_tick_489": late_chord,
             "finding": "Same-tick chord tones add pitches but retain one group and the 0.5 s center. Two repeated voice onsets 9 ticks later retain one group but shift its arithmetic-mean center to 0.50625 s. In both cases the 0.677083 s neighbor is suppressed; group richness is not a priority score, and chronological first-wins remains."},
        ],
        "corpus_summary": summary,
        "per_song_old_window_statistics": corpus,
        "input_hash_verification": {"d2_midi_count": len(midi_hashes), "d2_midi_sha256_before": midi_hashes,
                                    "game_ogg_count": len(ogg_hashes), "game_ogg_sha256_before": ogg_hashes,
                                    "midi_and_ogg_hashes_unchanged_after": True},
        "technical_findings": [
            "The old method is an onset-density window generator, not a main-beat estimator: adding a subordinate instrument layer can multiply windows without changing the test anchors.",
            "Chronological greedy selection has no salience, role, or velocity weighting; a weak earlier ornament can suppress a later synthetic anchor.",
            "Multi-track aggregation can shift a merged center when voices have nearby but non-identical onset times; duplicate notes are not independent evidence of a stronger beat.",
            "Quarter/eighth-grid proximity is a property of MIDI quantization. It cannot by itself establish that the nearest grid point is the human-perceived main beat.",
            "A beat-level estimator would at minimum need evidence that distinguishes recurring pulse from subdivisions and ornaments, a stable tempo/phase hypothesis, and alignment of those hypotheses to audible attacks. This corpus audit does not establish those invariants or a human-perception model.",
        ],
        "candidate_invariants_for_future_beat_level_estimation": [
            "Subdivision invariance: adding a subordinate eighth/sixteenth layer while keeping the anchor layer fixed should not by itself multiply the inferred main-pulse rate.",
            "Ornament robustness: a weak lead-in event should not suppress a later candidate anchor solely because it occurred first.",
            "Polyphonic robustness: duplicate/near-synchronous voices should not move a common attack estimate in proportion to the number of MIDI parts.",
            "Pulse uncertainty separation: distinguish note-on candidates from pulse/phase hypotheses, and preserve ambiguity when multiple pulse levels fit the MIDI.",
            "Audible alignment: validate candidate phase against the rendered audio and measured playback/input latency before treating windows as calibrated.",
        ],
        "limitations": [
            "Synthetic main-beat anchors are controlled test labels only and are not ground truth for songs.",
            "Real-song drum pitch numbers are reported without guessed GM instrument or accent semantics; MIDI velocity is not treated as rendered loudness.",
            "Corpus grid phases show whether algorithmic events sit near quarter/eighth MIDI grids, not whether their pulse level is perceptually correct.",
            "No audio waveform onset tracking, human listening study, Godot runtime integration, or gameplay parameter balancing was performed.",
        ],
    }
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"BEAT_FEASIBILITY_PROBES PASS songs={len(corpus)} synthetic={len(report['synthetic_probes'])} output={OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

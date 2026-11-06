#!/usr/bin/env python3
"""Reproduce bounded timing and baseline-budget arithmetic from the MIDI audit."""
from __future__ import annotations

import json
from math import isclose
from pathlib import Path


FOLDER = Path(__file__).resolve().parent


def main() -> None:
    audit = json.loads((FOLDER / "midi-audit.json").read_text(encoding="utf-8"))
    assert audit["status"] == "PASS"
    rows = []
    for song in audit["songs"]:
        source = song["source"]
        ppq = source["ticks_per_beat"]
        events = source["tempo_raw"]
        initial = 500_000
        for event in events:
            if event["tick"] == 0:
                initial = event["tempo_us_per_quarter"]

        def seconds(tick: int) -> float:
            previous, elapsed, tempo = 0, 0.0, 500_000
            for event in events:
                if event["tick"] > tick:
                    break
                elapsed += (event["tick"] - previous) * tempo / ppq / 1_000_000
                previous, tempo = event["tick"], event["tempo_us_per_quarter"]
            return elapsed + (tick - previous) * tempo / ppq / 1_000_000

        trim = song["audio_alignment_and_provenance"]["declared_trim_seconds"]
        points = [(seconds(t), t * initial / ppq / 1_000_000)
                  for t in range(0, source["max_track_end_tick"] + 1, ppq)]
        full = max((abs(actual - fixed) for actual, fixed in points), default=0.0)
        first = max((abs(actual - fixed) for actual, fixed in points
                     if 0 <= actual - trim <= 100), default=0.0)
        if source["tempo_effective_change_count"] == 0:
            assert full < 1e-7
        rows.append({
            "cue_id": song["cue_id"],
            "effective_tempo_changes": source["tempo_effective_change_count"],
            "fixed_initial_tempo_max_error_seconds_full_midi": round(full, 6),
            "fixed_initial_tempo_max_error_seconds_game_first_100_seconds": round(first, 6),
        })

    target_rate = 27 * 1.45
    cases = []
    for bpm in (60, 90, 120, 130, 180):
        interval = 60 / bpm
        damage = target_rate * interval
        assert isclose(damage * bpm / 60, target_rate, rel_tol=1e-12)
        cases.append({
            "bpm": bpm, "pulse_seconds": round(interval, 6),
            "one_action_each_quarter_pulse": True,
            "fixed_damage_27_DPS": round(27 / interval, 6),
            "normalized_damage_per_action": round(damage, 6),
            "normalized_nominal_DPS": target_rate,
        })
    result = {
        "status": "PASS",
        "scope": "offline_budget_and_tempo_arithmetic_only_not_runtime_or_balance_test",
        "tempo_error_method": (
            "Compare the cumulative piecewise tempo integral with holding the tick-zero tempo forever. "
            "Sample every MIDI quarter note. Both subtract the identical declared audio trim; "
            "no manual beat offset is inferred. First100 means nominal game-audio interval [0,100] seconds. "
            "Reported maxima are over these samples, not continuous extrema."
        ),
        "tempo_error": rows,
        "damage_budget_example": {
            "inputs": {
                "reference_base_attack": 27, "reference_base_speed": 1.45,
                "source_character": "JIA", "source_file": "scripts/content/roster_kit_data.gd",
                "reference_damage_rate": target_rate,
                "ignored": ["armor", "AoE", "hit rate", "Space", "traits", "equipment", "support", "levels", "music-accent modifiers"],
            },
            "proposal_formula": "accepted_action_damage = reference_damage_rate * local_music_pulse_seconds",
            "cases": cases,
            "conditions": [
                "one successful baseline action per pulse",
                "use current local pulse duration; never bank idle seconds",
                "utility and hit-trigger budgets require independent limits",
                "not a claim of existing game DPS or proof of full-system balance",
            ],
        },
        "checks": [
            "fixed-tempo songs give negligible comparison error",
            "piecewise tempo rows come from audited maps",
            "normalization identities hold for five illustrative BPMs",
        ],
    }
    (FOLDER / "balance-examples.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print("BALANCE_ARITHMETIC_PASS: 12 tempo maps, 5 baseline-budget examples")


if __name__ == "__main__":
    main()

from __future__ import annotations

import csv
import json
from pathlib import Path
import tempfile
import unittest

import numpy as np

from tools.rhythm_tester.session import SessionLog, TapJudge


class TapJudgeTests(unittest.TestCase):
    def test_boundaries_and_nonoverlap_at_dense_tempo_change(self):
        judge = TapJudge([2, 1, 1.1, 1], window_ms=180)
        np.testing.assert_allclose(judge.times, [1, 1.1, 2])
        self.assertTrue(np.all(judge.ends[:-1] < judge.starts[1:]))
        self.assertEqual(judge.tap(.955, "J")["judgement"], "hit")
        self.assertEqual(judge.tap(1.146, "K")["judgement"], "late")
        self.assertEqual(judge.tap(1.055, "J")["judgement"], "hit")

    def test_compensation_advances_tap_without_moving_references(self):
        judge = TapJudge([1, 2], 50)
        event = judge.tap(1.1, "J", compensation_ms=100)
        self.assertEqual(event["judgement"], "hit")
        self.assertEqual(event["raw_audio_sec"], 1.1)
        self.assertAlmostEqual(event["corrected_audio_sec"], 1)
        self.assertAlmostEqual(event["error_ms"], 0)
        np.testing.assert_array_equal(judge.times, [1, 2])
        self.assertEqual(judge.tap(1.9, "K", compensation_ms=-100)["judgement"], "hit")

    def test_same_key_on_later_beats_is_legal_duplicate_is_shared_across_keys(self):
        judge = TapJudge([1, 2, 3])
        self.assertEqual(judge.tap(1, "J")["judgement"], "hit")
        self.assertEqual(judge.tap(1.02, "K")["judgement"], "duplicate")
        self.assertEqual(judge.tap(1.03, "SPACE")["judgement"], "duplicate")
        self.assertEqual(judge.tap(2, "J")["judgement"], "hit")
        self.assertEqual(judge.tap(3, "J")["judgement"], "hit")
        self.assertEqual(judge.stats()["duplicate_count"], 2)
        self.assertEqual(judge.stats()["match_rate"], 60)

    def test_presentation_offset_and_input_correction_are_distinct_and_raw_is_preserved(self):
        judge = TapJudge([1], 30)
        event = judge.tap(1.18, "J", compensation_ms=30, presentation_offset_ms=150)
        self.assertEqual(event["judgement"], "hit")
        self.assertEqual(event["raw_audio_sec"], 1.18)
        self.assertAlmostEqual(event["presentation_audio_sec"], 1.03)
        self.assertAlmostEqual(event["corrected_audio_sec"], 1)
        self.assertEqual(event["presentation_offset_ms"], 150)
        self.assertEqual(event["compensation_ms"], 30)
        self.assertEqual(TapJudge([1], 30).tap(1.18, "J")["judgement"], "late")

    def test_early_late_and_statistics_include_failed_attempts_exclude_duplicates(self):
        judge = TapJudge([1, 2], 90)
        self.assertEqual(judge.tap(.8, "J")["judgement"], "early")
        self.assertEqual(judge.tap(1.2, "J")["judgement"], "late")
        self.assertEqual(judge.tap(2.01, "K")["judgement"], "hit")
        judge.tap(2.08, "SPACE")
        stats = judge.stats()
        self.assertEqual(stats["hit_count"], 1)
        self.assertEqual(stats["match_rate"], 25)
        self.assertAlmostEqual(stats["mean_error"], 10/3)
        self.assertAlmostEqual(stats["median_abs_error"], 200)

    def test_blind_records_only_and_has_no_score_or_reference(self):
        judge = TapJudge([1, 2])
        event = judge.tap(1, "J", blind=True, source="mouse")
        self.assertEqual(event["judgement"], "recorded")
        self.assertIsNone(event["target_sec"])
        self.assertIsNone(event["error_ms"])
        self.assertIsNone(judge.stats()["match_rate"])
        self.assertEqual(event["source"], "mouse")
        self.assertEqual(judge.tap(1, "J")["judgement"], "hit")
        self.assertEqual(judge.stats()["match_rate"], 100)

    def test_empty_reset_validation_and_negative_corrected_time(self):
        judge = TapJudge([])
        self.assertEqual(judge.tap(0, "J")["judgement"], "outside")
        judge.reset()
        self.assertEqual(judge.stats()["tap_count"], 0)
        for values in ([float("nan")], [float("inf")], [-1]):
            with self.assertRaises(ValueError):
                TapJudge(values)
        with self.assertRaises(ValueError):
            TapJudge([], 0)
        with self.assertRaises(ValueError):
            judge.tap(float("nan"), "J")
        event = TapJudge([0]).tap(.01, "J", compensation_ms=100)
        self.assertEqual(event["judgement"], "early")
        self.assertAlmostEqual(event["corrected_audio_sec"], -.09)


class SessionLogTests(unittest.TestCase):
    def test_export_retains_trials_hashes_raw_times_and_blind_taps(self):
        with tempfile.TemporaryDirectory() as directory:
            log = SessionLog(directory)
            metadata = dict(reason="load", mode="pulse", midi_sha256="a"*64,
                            audio_sha256="b"*64, start_audio_sec=0,
                            reference_times_sec=np.array([1, 2]),
                            algorithm_metadata={"selected_rate": 1})
            log.start_trial(metadata)
            metadata["reason"] = "changed outside logger"
            event = TapJudge([1]).tap(1.1, "J", compensation_ms=100)
            log.append(event)
            event["raw_audio_sec"] = 55
            paths = log.export()
            log.start_trial(dict(reason="seek", start_audio_sec=40, mode="blind"))
            log.append(TapJudge([]).tap(40.2, "K", blind=True))
            self.assertEqual(log.export(), paths)
            payload = json.loads(paths[0].read_text())
            self.assertEqual(payload["trial_count"], 2)
            self.assertEqual(payload["total_taps"], 2)
            first = payload["trials"][0]
            self.assertEqual(first["metadata"]["reason"], "load")
            self.assertEqual(first["metadata"]["midi_sha256"], "a"*64)
            self.assertEqual(first["metadata"]["reference_times_sec"], [1, 2])
            self.assertEqual(first["events"][0]["raw_audio_sec"], 1.1)
            self.assertEqual(first["events"][0]["corrected_audio_sec"], 1)
            self.assertEqual(payload["trials"][1]["metadata"]["start_audio_sec"], 40)
            with paths[1].open(encoding="utf-8", newline="") as stream:
                rows = list(csv.DictReader(stream))
            self.assertEqual(len(rows), 2)
            self.assertEqual(rows[0]["compensation_ms"], "100.0")
            self.assertEqual(rows[1]["mode"], "blind")
            self.assertEqual(rows[1]["error_ms"], "")
            self.assertEqual(len(list(Path(directory).glob("*.json"))), 1)

    def test_empty_export_is_explicit_and_invalid_events_not_recorded(self):
        with tempfile.TemporaryDirectory() as directory:
            log = SessionLog(directory)
            with self.assertRaises(RuntimeError):
                log.append({})
            with self.assertRaises(ValueError):
                log.export()
            log.start_trial({"mode": "blind"})
            with self.assertRaises(ValueError):
                log.append({"raw_audio_sec": float("nan")})
            self.assertEqual(log.total_taps, 0)
            self.assertTrue(log.export()[0].exists())

    def test_export_records_both_compensations_and_new_timeline(self):
        with tempfile.TemporaryDirectory() as directory:
            log = SessionLog(directory)
            log.start_trial({"presentation_offset_ms": 150, "compensation_ms": 30})
            log.append(TapJudge([1]).tap(1.18,"J",compensation_ms=30,presentation_offset_ms=150))
            paths = log.export()
            d = json.loads(paths[0].read_text())
            self.assertEqual(d["schema_version"], 2)
            self.assertEqual(d["trials"][0]["events"][0]["presentation_offset_ms"], 150)
            with paths[1].open(encoding="utf-8",newline="") as stream:
                row = list(csv.DictReader(stream))[0]
            self.assertEqual(row["presentation_offset_ms"], "150.0")
            self.assertEqual(row["compensation_ms"], "30.0")
            self.assertAlmostEqual(float(row["presentation_audio_sec"]), 1.03)


if __name__ == "__main__":
    unittest.main()

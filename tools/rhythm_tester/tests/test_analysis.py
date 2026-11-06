"""Event/timeline regression tests; these do not measure perceptual beat accuracy."""
from __future__ import annotations

import json
from pathlib import Path
import tempfile
import unittest

import mido
import numpy as np

from tools.rhythm_tester.analysis import (ALGORITHM_VERSION, PHASE_RESOLUTION_QUARTERS,
    build_plan, parse_midi, _events, _score)

ROOT = Path(__file__).resolve().parents[3]


class AnalysisTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.serial = 0

    def midi(self, *, beats=16, tempo=500000, tempo_changes=(), trim=None,
             extras=(), chords=0, hats=0, weak_early=False, file_type=1, silent_beats=(), shift=0):
        self.serial += 1
        path = Path(self.directory.name)/f"{self.serial}.mid"
        mf = mido.MidiFile(type=file_type, ticks_per_beat=480)
        tr = mido.MidiTrack(); mf.tracks.append(tr)
        rows = [(0, mido.MetaMessage("set_tempo", tempo=tempo)),
                (0, mido.Message("program_change", channel=0, program=32))]
        if trim is not None: rows.append((0,mido.MetaMessage("marker",text=f"muscriptor:bar_offset={trim}")))
        rows.extend((int(q*480),mido.MetaMessage("set_tempo",tempo=t)) for q,t in tempo_changes)
        def note(q, pitch, velocity=100, channel=9, duration=.15):
            q += shift
            rows.append((round(q*480),mido.Message("note_on",channel=channel,note=pitch,velocity=velocity)))
            rows.append((round((q+duration)*480),mido.Message("note_off",channel=channel,note=pitch,velocity=0)))
        for q in range(beats):
            if q in silent_beats: continue
            note(q,36); note(q,40,channel=0)
            for j in range(chords): note(q,48+j,channel=1)
            if weak_early and q>0: note(q-.06,36,velocity=8,duration=.02)
            for j in range(hats): note(q+j/hats,42,velocity=70,duration=.02)
        for row in extras: note(*row)
        rows.append((round((beats+shift)*480),mido.MetaMessage("end_of_track")))
        last=0
        for tick,msg in sorted(rows,key=lambda x:x[0]):
            tr.append(msg.copy(time=tick-last));last=tick
        mf.save(path)
        return path

    def assert_valid(self, plan, duration):
        self.assertEqual(plan.times.shape,plan.strengths.shape)
        self.assertTrue(np.isfinite(plan.times).all())
        self.assertTrue(np.isfinite(plan.strengths).all())
        self.assertTrue((plan.times>=0).all())
        self.assertTrue((plan.times<=duration+1e-8).all())
        self.assertTrue((np.diff(plan.times)>0).all())

    def test_tempo_integral_trim_and_unknown_meter(self):
        d=parse_midi(self.midi(beats=4,tempo_changes=((2,1000000),),trim=.25))
        self.assertAlmostEqual(d.metadata["raw_duration_sec"],3.0)
        self.assertAlmostEqual(d.duration_sec,2.75)
        self.assertFalse(d.metadata["meter_known"])
        self.assertEqual(d.metadata["time_signatures"],[])
        p=build_plan(d,"quarter")
        np.testing.assert_allclose(p.times,[.25,.75,1.75,2.75],atol=1e-9)
        self.assert_valid(p,d.duration_sec)

    def test_override_and_missing_marker_are_explicit(self):
        path=self.midi(beats=4)
        d=parse_midi(path)
        self.assertEqual(d.trim_sec,0)
        self.assertIn("absent",d.metadata["trim_source"])
        overridden=parse_midi(path,trim_override=.4)
        self.assertAlmostEqual(overridden.duration_sec,1.6)
        self.assertEqual(overridden.metadata["trim_source"],"explicit_override")
        with self.assertRaises(ValueError): parse_midi(path,trim_override=float("nan"))
        with self.assertRaises(ValueError): parse_midi(path,trim_override=-1)

    def test_quarter_layer_and_half_phase(self):
        d=parse_midi(self.midi(beats=4))
        np.testing.assert_allclose(build_plan(d,"quarter",.5).times,[0,1,2])
        np.testing.assert_allclose(build_plan(d,"quarter",2).times,np.arange(0,2.01,.25))
        np.testing.assert_allclose(build_plan(d,"quarter",1,.5).times,[.25,.75,1.25,1.75])
        np.testing.assert_allclose(build_plan(d,"quarter",2,.5).times,np.arange(.125,2,.25))

    def test_pulse_follows_tempo_map_and_layer_modifiers(self):
        d=parse_midi(self.midi(beats=16,tempo_changes=((8,600000),)))
        p=build_plan(d)
        self.assertEqual(p.metadata["selected_rate"],1)
        self.assertEqual(p.metadata["selected_phase"],0)
        np.testing.assert_allclose(p.times[:9],np.arange(9)*.5)
        np.testing.assert_allclose(np.diff(p.times[8:]),.6)
        slower=build_plan(d,"pulse",.5)
        np.testing.assert_allclose(slower.times,p.times[::2])
        shifted=build_plan(d,"pulse",1,.5)
        self.assertAlmostEqual(shifted.times[0],.25)
        self.assert_valid(shifted,d.duration_sec)
        self.assertIn("uncalibrated",p.metadata["disclaimer"])
        self.assertGreaterEqual(p.metadata["score_gap"],0)

    def test_chords_and_weak_ornaments_do_not_steal_synthetic_pulse(self):
        base=build_plan(parse_midi(self.midi()))
        elaborate=build_plan(parse_midi(self.midi(chords=18,weak_early=True)))
        self.assertEqual(base.metadata["selected_rate"],1)
        self.assertEqual(elaborate.metadata["selected_rate"],1)
        self.assertEqual(elaborate.metadata["selected_phase"],0)
        np.testing.assert_allclose(base.times,elaborate.times)

    def test_hat_density_does_not_vote_itself_into_a_new_pulse(self):
        plans=[build_plan(parse_midi(self.midi(hats=h))) for h in (0,2,4,8)]
        for p in plans:
            self.assertEqual(p.metadata["selected_rate"],1)
            self.assertEqual(p.metadata["selected_phase"],0)
            np.testing.assert_allclose(p.times,plans[0].times)

    def test_pulse_can_infer_a_missing_onset_and_find_half_phase(self):
        d=parse_midi(self.midi(silent_beats=(7,)))
        p=build_plan(d)
        self.assertEqual(p.metadata["selected_rate"],1)
        self.assertTrue(np.any(np.isclose(p.times,3.5)))
        self.assertFalse(any(abs(n.time_sec-3.5)<1e-8 for n in d.notes))
        shifted=build_plan(parse_midi(self.midi(shift=.5)))
        self.assertEqual(shifted.metadata["selected_rate"],1)
        self.assertEqual(shifted.metadata["selected_phase"],.5)
        self.assertAlmostEqual(shifted.times[0],.25)

    def test_comfort_prior_can_select_a_slower_layer(self):
        plan=build_plan(parse_midi(self.midi(tempo=250000)))
        self.assertEqual(plan.metadata["selected_rate"],.5)
        np.testing.assert_allclose(np.diff(plan.times),.5)

    def test_chord_note_count_is_not_an_extra_vote(self):
        small=build_plan(parse_midi(self.midi(chords=1)))
        large=build_plan(parse_midi(self.midi(chords=18)))
        np.testing.assert_allclose(small.strengths,large.strengths)
        self.assertEqual(small.metadata["candidate_rankings"],large.metadata["candidate_rankings"])

    def test_equal_absolute_phase_resolution_fixes_shifted_quarter_search(self):
        data=parse_midi(self.midi(shift=.125))
        events=_events(data)
        old=[]
        for rate in (.5,1.,2.):
            for fraction in (0.,.25,.5,.75):
                old.append({"rate":rate,"offset_quarters":fraction/rate,
                            **_score(data,rate,fraction/rate,events)})
        self.assertFalse(any(r["rate"]==1 and r["offset_quarters"]==.125 for r in old))
        self.assertTrue(any(r["rate"]==2 and r["offset_quarters"]==.125 for r in old))
        plan=build_plan(data)
        self.assertEqual(plan.metadata["selected_rate"],1)
        self.assertEqual(plan.metadata["selected_phase"],.125)
        self.assertGreater(plan.metadata["candidate_rankings"][0]["score"],max(r["score"] for r in old))
        self.assertEqual(plan.metadata["algorithm_version"],ALGORITHM_VERSION)
        self.assertEqual(plan.metadata["phase_resolution_quarters"],1/32)
        for rate,count in ((.5,64),(1.,32),(2.,16)):
            offsets=sorted(r["offset_quarters"] for r in plan.metadata["candidate_rankings"] if r["rate"]==rate)
            self.assertEqual(len(offsets),count)
            np.testing.assert_allclose(np.diff(offsets),1/32)
            self.assertIn(.125,offsets)

    def test_nonbin_phase_error_is_bounded_without_moving_known_bin_truth(self):
        data=parse_midi(self.midi(shift=.14))
        plan=build_plan(data)
        self.assertEqual(plan.metadata["selected_rate"],1)
        self.assertLessEqual(abs(plan.metadata["offset_quarters"]-data.notes[0].quarter),PHASE_RESOLUTION_QUARTERS/2+1e-9)

    def test_score_support_is_shared_and_excludes_end_padding(self):
        data=parse_midi(self.midi())
        plan=build_plan(data)
        self.assertEqual(plan.metadata["selected_phase"],0)
        self.assertTrue(plan.metadata["changed_score_support"])
        self.assertEqual(plan.metadata["score_support"]["quarters"],[1,14])
        top=plan.metadata["candidate_rankings"][0]
        self.assertAlmostEqual(top["stability"],1)
        # End-of-track extends to16q, but has no onset at16q. It is not scored.
        self.assertEqual(data.end_quarter,16)
        self.assertEqual(plan.times[-1],8)

    def test_cached_candidates_are_detached_and_intrinsic_inputs_unchanged(self):
        data=parse_midi(self.midi())
        snapshot=(data.notes,data.sha256,data.duration_sec,data.trim_sec,data.tempo_us.copy(),json.loads(json.dumps(data.metadata)))
        first=build_plan(data)
        ranking=json.loads(json.dumps(first.metadata["candidate_rankings"]))
        first.metadata["candidate_rankings"][0]["score"]=999
        cached=data._pulse_cache
        later=build_plan(data,"pulse",2,.5)
        self.assertIs(data._pulse_cache,cached)
        self.assertEqual(later.metadata["candidate_rankings"],ranking)
        self.assertEqual(data.notes,snapshot[0]);self.assertEqual(data.sha256,snapshot[1])
        self.assertEqual((data.duration_sec,data.trim_sec),snapshot[2:4])
        np.testing.assert_array_equal(data.tempo_us,snapshot[4]);self.assertEqual(data.metadata,snapshot[5])
        data.notes=data.notes[:-1]
        build_plan(data)
        self.assertIsNot(data._pulse_cache,cached)

    def test_onset_merge_keeps_strong_later_event(self):
        d=parse_midi(self.midi(weak_early=True))
        p=build_plan(d,"onsets")
        np.testing.assert_allclose(p.times,np.arange(16)*.5)
        self.assertFalse(p.metadata["layer_phase_applied"])
        self.assertIn("not inferred beat",p.metadata["method"])

    def test_empty_valid_file_and_type0(self):
        p=Path(self.directory.name)/"empty.mid"
        m=mido.MidiFile(type=0);m.tracks.append(mido.MidiTrack());m.save(p)
        d=parse_midi(p)
        self.assertEqual(d.duration_sec,0)
        self.assertEqual(d.notes,())
        for mode in ("pulse","quarter","onsets"):
            plan=build_plan(d,mode)
            self.assertEqual(len(plan.times),0)
            self.assert_valid(plan,0)
        d0=parse_midi(self.midi(file_type=0))
        self.assertGreater(len(build_plan(d0).times),0)

    def test_bad_file_type2_and_invalid_options(self):
        p=Path(self.directory.name)/"bad.mid";p.write_bytes(b"not a MIDI")
        with self.assertRaises(ValueError):parse_midi(p)
        with self.assertRaises(ValueError):parse_midi(self.midi(file_type=2))
        d=parse_midi(self.midi())
        for mode,layer,phase in (("bad",1,0),("pulse",0,0),("quarter",1,.25),("pulse",float("inf"),0)):
            with self.assertRaises(ValueError):build_plan(d,mode,layer,phase)

    def test_all_twelve_D2_timelines_match_existing_audit(self):
        arrangements=ROOT/"design/music-20261104-chinese-12/arrangements"
        paths=sorted(arrangements.glob("*/D2.mid"))
        self.assertEqual(len(paths),12)
        for path in paths:
            cue=path.parent.name
            with self.subTest(cue=cue):
                d=parse_midi(path)
                old=json.loads((ROOT/f"design/music-20261103-midi-test/reports/{cue}.json").read_text())
                audio=json.loads((ROOT/f"design/music-20261104-chinese-12/reports/audio-{cue}.json").read_text())
                self.assertAlmostEqual(d.metadata["raw_duration_sec"],old["source_midi_duration_seconds"],places=7)
                self.assertAlmostEqual(d.trim_sec,audio["offset_seconds"],places=8)
                self.assertAlmostEqual(d.duration_sec,old["source_midi_duration_seconds"]-audio["offset_seconds"],places=7)
                self.assertEqual(len(d.notes),old["source_note_count_expected"])
                self.assertEqual(d.metadata["unclosed_notes_closed_at_end"],0)
                for mode in ("pulse","quarter","onsets"):
                    plan=build_plan(d,mode)
                    self.assertGreater(len(plan.times),0)
                    self.assert_valid(plan,d.duration_sec)
                    again=build_plan(d,mode)
                    np.testing.assert_array_equal(plan.times,again.times)
                    np.testing.assert_array_equal(plan.strengths,again.strengths)
                    self.assertEqual(plan.metadata,again.metadata)


if __name__=="__main__":unittest.main()

#!/usr/bin/env python3
"""Signal-level engine tests with synthetic known-frequency sample fixtures.

These verify pitch/time/controller/export behaviour, not musical listening quality.
Run: python3 -m unittest discover -s design/music-20261030 -p test_audio_engine.py
"""
import copy
import json
from pathlib import Path
import tempfile
import unittest

import numpy as np
from scipy.io import wavfile

from audio_engine import RATE, Sampler, prepare_source_channels, render_cue, render_track, validate_cue, write_midi
from fetch_instruments import apply_mapping_overrides, git_blob_hash


class EngineTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        t = np.arange(RATE * 2) / RATE
        data = np.repeat((.3 * np.sin(2 * np.pi * 440 * t)).astype(np.float32)[:, None], 2, axis=1)
        sample = self.root / 'test.wav'
        wavfile.write(sample, RATE, data)
        raw = sample.read_bytes()
        self.manifest = {'sources': {}, 'files': {'test.wav': {'size': len(raw), 'git_blob_sha1': git_blob_hash(raw)}},
                         'patches': {'test': {'regions': [{'file': 'test.wav', 'pitch_keycenter': 69,
                                                          'lokey': 60, 'hikey': 84, 'ampeg_release': .2}]}},
                         'instruments': {'test': {'status': 'sampled', 'actual_name': 'known sine fixture',
                                                   'patches': {'sustain': 'test'}, 'trim_db': 0}}}
        self.cue = {'id': 'test_cue', 'title': 'test', 'bpm': 120, 'beats': 8, 'meter': [7, 8], 'loop': False,
                    'tracks': [{'name': 'test', 'instrument': 'test', 'db': 0, 'pan': 0,
                                'notes': [[0, 1, 69, 127]]}]}

    def tearDown(self):
        self.temp.cleanup()

    def render(self, part=None):
        return render_track(self.cue, part or self.cue['tracks'][0], Sampler(self.manifest, self.root), .5, [])

    def test_pitch_and_octave(self):
        for pitch, expected in [(69, 440), (81, 880), (60, 261.6256)]:
            part = copy.deepcopy(self.cue['tracks'][0])
            part['notes'][0][2] = pitch
            data = self.render(part)[round(.05 * RATE):round(.4 * RATE), 0]
            n = 2 ** 18
            spec = abs(np.fft.rfft(data * np.hanning(len(data)), n=n))
            peak = np.argmax(spec) * RATE / n
            self.assertLess(abs(peak - expected), .5)

    def test_velocity_volume_and_stereo_balance(self):
        part = copy.deepcopy(self.cue['tracks'][0])
        high = self.render(part)
        part['notes'][0][3] = 64
        low = self.render(part)
        ratio = np.max(low) / np.max(high)
        self.assertAlmostEqual(float(ratio), (64 / 127) ** 2, places=5)
        part['pan'] = 1
        right = self.render(part)
        self.assertEqual(float(np.max(abs(right[:, 0]))), 0)
        self.assertGreater(float(np.max(abs(right[:, 1]))), .01)

    def test_cc_expression_and_sustain_pedal(self):
        part = copy.deepcopy(self.cue['tracks'][0])
        part['cc'] = [[0, 64, 127], [3, 64, 0], [2, 11, 0]]
        data = self.render(part)
        self.assertGreater(float(np.max(abs(data[round(.7 * RATE):round(.8 * RATE)]))), .1)
        self.assertEqual(float(np.max(abs(data[round(1.1 * RATE):]))), 0)

    def test_unrecognized_instrument_cc_and_nan_rejected(self):
        for mutate in [lambda c: c['tracks'][0].update(instrument='erhu_not_installed'),
                       lambda c: c['tracks'][0].update(cc=[[0, 91, 30]]),
                       lambda c: c.update(bpm=float('nan'))]:
            cue = copy.deepcopy(self.cue)
            mutate(cue)
            with self.assertRaises(ValueError):
                validate_cue(cue, self.manifest)

    def test_round_robin_and_range_extension_are_auditable(self):
        regions = self.manifest['patches']['test']['regions']
        first = regions[0]
        first.update(seq_length=2, seq_position=1)
        second = copy.deepcopy(first)
        second['seq_position'] = 2
        regions.append(second)
        sampler = Sampler(self.manifest, self.root)
        self.assertEqual(sampler.select('test', 69, 80, 0, 'attack', [])[0]['seq_position'], 1)
        self.assertEqual(sampler.select('test', 69, 80, 1, 'attack', [])[0]['seq_position'], 2)
        audit = []
        sampler.select('test', 55, 80, 0, 'attack', audit)
        self.assertEqual(audit[0]['type'], 'range_extension')

    def test_deterministic_stems_sum_and_editable_export(self):
        cue = copy.deepcopy(self.cue)
        cue['loop'] = True
        cue['tracks'].append(copy.deepcopy(cue['tracks'][0]))
        reports = [render_cue(cue, self.root / directory, self.root, self.manifest, .5)
                   for directory in ['a', 'b']]
        self.assertEqual(reports[0]['mix']['sha256'], reports[1]['mix']['sha256'])
        self.assertEqual(reports[0]['mix']['frames'], RATE * 4)
        directory = self.root / 'a' / 'test_cue'
        rate, mix = wavfile.read(directory / 'mix.wav')
        stems = [wavfile.read(directory / track['file'])[1] for track in reports[0]['tracks']]
        self.assertTrue(np.array_equal(mix, (stems[0].astype(np.float64) + stems[1]).astype(np.float32)))
        rpp = (directory / 'test_cue.rpp').read_text()
        self.assertIn('TEMPO 120 7 8', rpp)
        self.assertEqual(rpp.count('<SOURCE MIDI'), 2)
        self.assertEqual(rpp.count('<SOURCE WAVE'), 2)
        midi = (directory / 'score.mid').read_bytes()
        self.assertTrue(midi.startswith(b'MThd'))
        self.assertIn(b'\xff\x58\x04\x07\x03\x18\x08', midi)
        self.assertFalse(reports[0]['listening_review'])

    def test_tampered_sample_is_rejected(self):
        with (self.root / 'test.wav').open('ab') as output:
            output.write(b'tampering')
        with self.assertRaises(RuntimeError):
            self.render()

    def test_fractional_sample_period_is_one_frozen_integer(self):
        cue = copy.deepcopy(self.cue)
        cue.update(bpm=137, beats=7, loop=True)
        report = render_cue(cue, self.root / 'fractional', self.root, self.manifest, .5)
        expected = round(7 * 60 / 137 * RATE)
        self.assertEqual(report['mix']['frames'], expected)
        self.assertEqual(report['tracks'][0]['metrics']['frames'], expected)

    def test_antiphase_source_retains_original_440hz_spectrum(self):
        t = np.arange(RATE) / RATE
        original = (.4 * np.sin(2 * np.pi * 440 * t)).astype(np.float32)
        # Right is stronger, so selecting and duplicating it must preserve its
        # sign, waveform and full fundamental instead of averaging two mics.
        stereo = np.column_stack([-.5 * original, original])
        prepared, info = prepare_source_channels(stereo)
        self.assertTrue(info['selected'])
        self.assertEqual(info['selected_channel'], 'right')
        self.assertTrue(np.array_equal(prepared[:, 0], original))
        self.assertTrue(np.array_equal(prepared[:, 1], original))
        spectrum = abs(np.fft.rfft(prepared.mean(axis=1)))
        self.assertEqual(int(np.argmax(spectrum)), 440)
        self.assertAlmostEqual(float(spectrum[440]), .4 * RATE / 2, places=2)
        wavfile.write(self.root / 'test.wav', RATE, stereo)
        raw = (self.root / 'test.wav').read_bytes()
        self.manifest['files']['test.wav'].update(size=len(raw), git_blob_sha1=git_blob_hash(raw))
        rendered = self.render()
        np.testing.assert_allclose(rendered[round(.02 * RATE):round(.4 * RATE), 0],
                                   original[round(.02 * RATE):round(.4 * RATE)], atol=1e-7)

    def test_positive_correlated_stereo_is_preserved_exactly(self):
        t = np.arange(RATE) / RATE
        signal = (.4 * np.sin(2 * np.pi * 440 * t)).astype(np.float32)
        stereo = np.column_stack([signal, signal * .7])
        prepared, info = prepare_source_channels(stereo)
        self.assertFalse(info['selected'])
        self.assertTrue(np.array_equal(prepared, stereo))

    def test_local_mapping_override_is_explicit_reproducible_and_idempotent(self):
        baseline = self.render()
        original = copy.deepcopy(self.manifest)
        original['patches']['test']['regions'][0]['volume'] = 0
        original['local_mapping_overrides'] = [dict(id='reviewed_gain', patch='test', sample_file='test.wav',
                                                  opcode='volume', upstream_value=0, local_value=-6)]
        effective = apply_mapping_overrides(original)
        self.assertEqual(original['patches']['test']['regions'][0]['volume'], 0)
        self.assertEqual(effective['patches']['test']['regions'][0]['volume'], -6)
        self.assertEqual(apply_mapping_overrides(effective), effective)
        self.manifest = original
        rendered = self.render()
        self.assertAlmostEqual(float(np.max(rendered) / np.max(baseline)), 10 ** (-6 / 20), places=6)
        original['local_mapping_overrides'][0]['upstream_value'] = 12
        with self.assertRaises(ValueError):
            apply_mapping_overrides(original)


if __name__ == '__main__':
    unittest.main()

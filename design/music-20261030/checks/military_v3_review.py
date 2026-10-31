"""Reproducible file/MIDI/phase/mono checks for the military v3 render.

This verifies engineering properties, not listening approval or mastering.
"""
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import struct

import numpy as np
from scipy.io import wavfile


BASE = Path(__file__).resolve().parents[1]
SNAPSHOT = BASE / 'checks/military-v3-input.json'
ROOT = BASE / 'renders-military-v3'


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def midi_note_counts(path):
    data = path.read_bytes()
    assert data[:4] == b'MThd'
    length, fmt, count, ppq = struct.unpack('>IHHH', data[4:14])
    assert fmt == 1 and ppq == 960 and length == 6
    pos, counts = 14, []
    for _ in range(count):
        assert data[pos:pos + 4] == b'MTrk'
        size = int.from_bytes(data[pos + 4:pos + 8], 'big')
        block = data[pos + 8:pos + 8 + size]
        pos += 8 + size
        cursor, notes = 0, 0

        def varlen():
            nonlocal cursor
            value = 0
            while True:
                n = block[cursor]
                cursor += 1
                value = (value << 7) | (n & 127)
                if n < 128:
                    return value

        while cursor < len(block):
            varlen()
            status = block[cursor]
            cursor += 1
            if status == 0xff:
                cursor += 1
                payload_length = varlen()
                cursor += payload_length
            elif status in (0xf0, 0xf7):
                payload_length = varlen()
                cursor += payload_length
            else:
                assert status >= 128, 'This exporter writes explicit statuses'
                if status & 0xf0 == 0x90 and block[cursor + 1] > 0:
                    notes += 1
                cursor += 1 if status & 0xf0 in (0xc0, 0xd0) else 2
        assert cursor == len(block)
        counts.append(notes)
    assert pos == len(data)
    return counts


def audio_info(path, frames):
    rate, a = wavfile.read(path, mmap=True)
    assert rate == 48000 and a.shape == (frames, 2) and a.dtype == np.float32
    energy, mono, peak, clipped = 0., 0., 0., 0
    for start in range(0, len(a), rate * 10):
        block = np.asarray(a[start:start + rate * 10], dtype=np.float64)
        assert np.isfinite(block).all()
        energy += float(np.sum(block ** 2)) / 2
        mono += float(np.sum(np.mean(block, axis=1) ** 2))
        peak = max(peak, float(np.max(np.abs(block))))
        clipped += int(np.count_nonzero(np.abs(block) > 1))
    assert energy > 0 and clipped == 0
    return dict(frames=frames, rate=rate, channels=2, float32=True, finite=True,
                over_0dbfs_samples=clipped, peak_dbfs=20 * math.log10(peak),
                mono_energy_loss_db=10 * math.log10(mono / energy))


def main():
    cues = json.loads(SNAPSHOT.read_text())
    assert len(cues) == 18
    results, groups = [], {}
    allowed_information = {'instrument_mapping', 'unpitched_key_mapping',
                           'percussion_key_mapping', 'cc1_expression_proxy'}
    for cue in cues:
        directory = ROOT / cue['id']
        report = json.loads((directory / 'render-report.json').read_text())
        assert report['engine'] == 'my-game-multisample-3'
        assert json.loads((directory / 'score.json').read_text()) == cue
        frames = round(cue['beats'] * 60 / cue['bpm'] * 48000)
        counts = midi_note_counts(directory / 'score.mid')
        expected = [len(p['notes']) for p in cue['tracks']]
        assert counts == [0] + expected, (cue['id'], counts, expected)
        assert digest(directory / 'score.mid') == report['midi_sha256']
        project = (directory / (cue['id'] + '.rpp')).read_text()
        assert project.count('  <TRACK\n') == 2 * len(expected)
        assert project.count('    MUTESOLO 1 0 0') == len(expected)
        assert f"  TEMPO {cue['bpm']} {cue['meter'][0]} {cue['meter'][1]}" in project
        tracks, information = [], Counter()
        for part in report['tracks']:
            assert part['note_count'] == expected[part['index']]
            assert digest(directory / part['file']) == part['sha256']
            assert f'FILE "{part["file"]}"' in project
            issues = [a for a in part['audit'] if a['type'] not in allowed_information]
            assert not issues, (cue['id'], part['name'], issues)
            information.update(a['type'] for a in part['audit'])
            info = audio_info(directory / part['file'], frames)
            sources = part.get('source_channel_selection', [])
            tracks.append(dict(name=part['name'], instrument=part['instrument'],
                               actual=part['actual'], notes=part['note_count'], **info,
                               sources=len(sources),
                               selected_original_channels=sum(x['selected'] for x in sources)))
        assert digest(directory / 'mix.wav') == report['mix']['sha256']
        mixed = audio_info(directory / 'mix.wav', frames)
        assert mixed['mono_energy_loss_db'] >= -3.1, (cue['id'], mixed)
        if cue.get('phase_family'):
            groups.setdefault(cue['phase_family'], []).append((cue['id'], frames))
        results.append(dict(id=cue['id'], seconds=frames / 48000,
                            mix=mixed, stems=tracks, notes=sum(expected),
                            editable_midi_tracks=len(expected),
                            information_events=dict(information),
                            adaptation_errors=[], rpp_static_structure_verified=True,
                            render_report_sha256=digest(directory / 'render-report.json')))
    assert all(len({n for _, n in members}) == 1 for members in groups.values())
    reaper_probes = {}
    for meter, folder in [('6/8', 'military-reaper-6_8-v3'),
                          ('2/4', 'military-reaper-2_4-v3-exact')]:
        path = BASE / 'checks' / folder / 'result.json'
        result = json.loads(path.read_text())
        assert result['success'] and result['max_absolute_reconstruction_error'] <= 1e-6
        reaper_probes[meter] = dict(path=str(path.relative_to(BASE)),
                                   sha256=digest(path), **result)
    report = dict(cue_count=18, engine='my-game-multisample-3',
                  input_sha256=digest(SNAPSHOT),
                  source_sha256=digest(BASE / 'compositions/military.py'),
                  manifest_file_sha256=digest(BASE / 'instrument-manifest.json'),
                  phase_frames=groups, cues=results, actual_reaper_probes=reaper_probes,
                  listening_review=False, mastered=False,
                  note='Numerical/source/structure verification; no perceptual approval.')
    output = BASE / 'checks/military-v3-review.json'
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(dict(cues=len(results), stems=sum(len(x['stems']) for x in results),
                         notes=sum(x['notes'] for x in results),
                         worst_mix_mono_loss_db=min(x['mix']['mono_energy_loss_db'] for x in results),
                         worst_stem_mono_loss_db=min(s['mono_energy_loss_db'] for x in results for s in x['stems']),
                         output=str(output), listening_review=False), ensure_ascii=False))


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Verify allocation and unchanged nonmusic data; optionally retire old mix assets."""
import argparse
import hashlib
import json
import math
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
RUNTIME = Path(__file__).resolve().parent
PLAN = json.loads((RUNTIME.parent / 'chapter-music-map.json').read_text())
EXPERIMENT = json.loads((RUNTIME.parent / 'experiment-manifest.json').read_text())


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def nonmusic(value):
    if isinstance(value, dict):
        return {k: nonmusic(v) for k, v in value.items() if k not in ('music', 'stinger')}
    if isinstance(value, list):
        return [nonmusic(v) for v in value]
    return value


def main():
    args = argparse.ArgumentParser()
    args.add_argument('--retire-old-assets', action='store_true')
    args.add_argument('--require-published-assets', action='store_true')
    args.add_argument('--record-published-metadata', action='store_true')
    options = args.parse_args()
    catalog = json.loads((ROOT / 'assets/data/audio/music_catalog.json').read_text())
    expected = {c['cue_id'] for c in PLAN['new_test_cues'] + PLAN['retained_warm_cues']}
    assert {c['id'] for c in catalog['cues']} == expected and len(catalog['cues']) == 16
    before = json.loads((RUNTIME / 'nonmusic-story-baseline.json').read_text())
    for name, rows in [('story_events', PLAN['story_events']), ('character_events', PLAN['character_events'])]:
        data = json.loads((ROOT / f'assets/data/chronicle/{name}.json').read_text())
        actual = hashlib.sha256(json.dumps(nonmusic(data), ensure_ascii=False, sort_keys=True).encode()).hexdigest()
        assert actual == before[name], f'nonmusic data changed: {name}'
        for row in rows:
            assert data[row['event_id']]['music'] == row['cue_id']
        for event in data.values():
            for line in event['lines']:
                assert 'stinger' not in line
                assert line.get('music', event['music']) in expected
    for override in PLAN['line_music_overrides']:
        data = json.loads((ROOT / 'assets/data/chronicle/story_events.json').read_text())
        line = next(x for x in data[override['event_id']]['lines'] if x['id'] == override['line_id'])
        assert line['music'] == override['cue_id']
    assert digest(ROOT / 'assets/data/chronicle/route.json') == PLAN['route_source_sha256']
    for row in PLAN['new_test_cues']:
        frozen_copy = RUNTIME.parent / 'inputs' / (row['cue_id'] + '.mid')
        assert digest(frozen_copy) == row['midi_sha256'], row['cue_id']
        original = Path(row['midi_file'])
        if original.exists():
            assert digest(original) == row['midi_sha256'], row['cue_id']
    retained = {}
    for row in EXPERIMENT['old_music']['initial_keep_whitelist']:
        path = ROOT / row['path'].removeprefix('res://')
        retained[row['id']] = digest(path)
    retained_baseline = RUNTIME / 'retained-assets-baseline.json'
    if retained_baseline.exists():
        assert retained == json.loads(retained_baseline.read_text()), 'retained warm asset changed'
    else:
        retained_baseline.write_text(json.dumps(retained, indent=2) + '\n')
    new_assets = []
    production_path = RUNTIME.parent / 'audio-production-release-report.json'
    if options.require_published_assets or options.retire_old_assets or options.record_published_metadata:
        production = json.loads(production_path.read_text())
        assert production['status'] == 'PASS' and len(production['items']) == 12
        published = {row['cue_id']: row['outputs']['ogg'] for row in production['items']}
    if options.require_published_assets or options.retire_old_assets or options.record_published_metadata:
        for row in PLAN['new_test_cues']:
            path = ROOT / row['proposed_game_asset'].removeprefix('res://')
            probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_entries', 'format=duration:stream=codec_name,sample_rate,channels', '-of', 'json', str(path)]))
            assert float(probe['format']['duration']) > 10.0 and probe['streams'][0]['codec_name'] == 'vorbis'
            assert digest(path) == published[row['cue_id']]['sha256']
            assert abs(float(probe['format']['duration']) - float(published[row['cue_id']]['duration_seconds'])) < 0.001
            levels = subprocess.run(['ffmpeg', '-hide_banner', '-i', str(path), '-af', 'astats=measure_overall=Peak_level:measure_perchannel=none', '-f', 'null', '-'], capture_output=True, text=True, check=True)
            peaks = re.findall(r'Peak level dB:\s+(-?\d+(?:\.\d+)?)', levels.stderr)
            assert len(peaks) == 1, levels.stderr[-2000:]
            peak_dbfs = float(peaks[0])
            assert math.isfinite(peak_dbfs) and peak_dbfs < 0.0
            new_assets.append({'id': row['cue_id'], 'path': str(path.relative_to(ROOT)), 'sha256': digest(path), 'duration_seconds': float(probe['format']['duration']), 'sample_peak_dbfs': peak_dbfs, 'sample_peak_linear': 10 ** (peak_dbfs / 20.0)})
    if options.record_published_metadata:
        published = {row['id']: row for row in new_assets}
        for row in catalog['cues']:
            if row['id'] in published:
                row['duration_seconds'] = published[row['id']]['duration_seconds']
                row['render_sha256'] = published[row['id']]['sha256']
                row['sample_peak_dbfs'] = published[row['id']]['sample_peak_dbfs']
                row['sample_peak_linear'] = published[row['id']]['sample_peak_linear']
        (ROOT / 'assets/data/audio/music_catalog.json').write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n')
    retired = EXPERIMENT['old_music']['retire_from_test_runtime_and_music_room']
    assert len(retired) == 66
    removed = []
    if options.retire_old_assets:
        for row in retired:
            path = ROOT / f'assets/music/chronicle/{row["id"]}.ogg'
            record = {'id': row['id'], 'path': str(path.relative_to(ROOT)), 'sha256': digest(path) if path.exists() else None}
            if path.exists(): path.unlink()
            import_path = Path(str(path) + '.import')
            if import_path.exists(): import_path.unlink()
            removed.append(record)
        assert {p.stem for p in (ROOT / 'assets/music/chronicle').glob('*.ogg')} == set(retained)
        (RUNTIME / 'retired-assets.json').write_text(json.dumps({'retired_assets': removed, 'retained_assets_sha256': retained, 'new_assets': new_assets}, indent=2) + '\n')
    if options.require_published_assets:
        assert not any((ROOT / f'assets/music/chronicle/{row["id"]}.ogg').exists() for row in retired)
    print(f'MIDI_RUNTIME_STATIC_OK cues={len(expected)} story_events=22 line_overrides=9 character_events=32 frozen_inputs=12 nonmusic_data=unchanged new_assets_checked={len(new_assets)} retired={len(removed)}')


if __name__ == '__main__':
    main()

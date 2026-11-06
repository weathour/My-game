#!/usr/bin/env python3
"""Build aligned, level-matched listening excerpts and local playlists."""
from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
import subprocess
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT / 'design/music-20261104-chinese-12'
OUTPUT = Path('/home/weathour/音乐/Marilyn-Manson-伴奏学习/中国器乐全12曲_20261104')
WORK = Path.home() / '.cache/my-game/chinese-12-render-20261104/comparisons'
FIRST_BASE = ROOT / 'design/music-20261104-chinese-trial'
FIRST_OUTPUT = Path('/home/weathour/音乐/Marilyn-Manson-伴奏学习/中国器乐首轮_20261104')
spec = importlib.util.spec_from_file_location('existing_mix_qa', ROOT / 'design/music-20261103-midi-test/tools/mix_align_encode_c.py')
qa = importlib.util.module_from_spec(spec)
spec.loader.exec_module(qa)


def run(args):
    result = subprocess.run([str(x) for x in args], capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stderr.decode('utf-8', errors='replace')[-2400:])
    return result


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def inspect(path, duration):
    probe = qa.audio_probe(path)
    lm = qa.loudness(path)
    raw = run(['ffmpeg', '-v', 'error', '-i', path, '-f', 'f32le', '-acodec', 'pcm_f32le', '-']).stdout
    samples = np.frombuffer(raw, dtype='<f4')
    assert len(samples) and np.isfinite(samples).all(), path
    assert float(np.max(np.abs(samples))) < 1, path
    assert float(np.sqrt(np.mean(samples.astype(np.float64) ** 2))) > 1e-6, path
    assert abs(float(probe['format']['duration']) - duration) < .06, (path, probe)
    assert float(lm['input_tp']) <= -3, (path, lm)
    return {'path': str(path), 'sha256': digest(path), 'probe': probe, 'loudness': lm, 'finite': True}


def select_window(events, offset, song_length, length):
    changed = [e for e in events if e['pitch'] != e['source_pitch']]
    chinese = [e for e in events if e['role'] in ['plucked', 'bowed_lead']]
    last = max(0, int(song_length - length))
    scored = []
    for start in range(last + 1):
        changes = [e for e in changed if start <= e['start_s'] - offset < start + length]
        bins = {int((e['start_s'] - offset - start) * 2) for e in changes}
        colored = sum(start <= e['start_s'] - offset < start + length for e in chinese)
        # Prefer distinct changed onsets, with source-color presence as a tie-break.
        scored.append((len(bins) * 3 + len(changes) + colored * .01, -start, len(changes), colored))
    best = max(scored)
    return -best[1], {'changed_note_onsets': best[2], 'chinese_note_onsets': best[3],
                     'method': 'max distinct changed onset half-second bins, then note count and Chinese-layer presence; no amplitude selection'}


def build_one(index):
    cue = f'midi_test_{index:02d}'
    report_path = BASE / 'reports' / f'audio-{cue}.json'
    report = json.loads(report_path.read_text())
    assert report['status'] == 'PASS', report_path
    if index in (1, 4, 8):
        original = FIRST_BASE / 'reports/comparisons.json'
        previous = json.loads(original.read_text())
        row = copy.deepcopy(next(x for x in previous['clips'] if x['index'] == index))
        def relocate(value):
            if isinstance(value, str):
                return value.replace(str(FIRST_OUTPUT), str(OUTPUT))
            if isinstance(value, list):
                return [relocate(x) for x in value]
            if isinstance(value, dict):
                return {k: relocate(x) for k, x in value.items()}
            return value
        row = relocate(row)
        for file in [row['joined'], *row['individual_clips'].values()]:
            assert digest(file['path']) == file['sha256'], file['path']
        row['reuse_provenance'] = {'original_comparisons_report': str(original),
                                  'original_comparisons_report_sha256': digest(original),
                                  'copied_without_reencoding': True}
        row['current_audio_report_sha256'] = digest(report_path)
        return row
    plan = json.loads((BASE / 'arrangements' / cue / 'plan-D2.json').read_text())
    duration = min(45.0, float(report['duration_seconds']))
    start, selection = select_window(plan['events'], float(report['offset_seconds']), float(report['duration_seconds']), duration)
    folder = Path(report['outputs']['C']['files']['flac']['path']).parent
    work = WORK / cue
    work.mkdir(parents=True, exist_ok=True)
    excerpts = {}
    measurements = {}
    for variant in ['C', 'D1', 'D2']:
        source = Path(report['outputs'][variant]['files']['flac']['path'])
        target = work / f'{variant}-raw.wav'
        run(['ffmpeg', '-v', 'error', '-y', '-i', source, '-af',
             f'atrim=start={start}:duration={duration},asetpts=PTS-STARTPTS,afade=t=in:d=0.008,afade=t=out:st={duration-.008}:d=0.008',
             '-ar', 48000, '-ac', 2, '-c:a', 'pcm_f32le', target])
        excerpts[variant] = target
        measurements[variant] = qa.loudness(target)
    common = min([-18.] + [float(x['input_i']) - float(x['input_tp']) - 4. for x in measurements.values()])
    files = {}
    matched = []
    for variant in ['C', 'D1', 'D2']:
        gain = common - float(measurements[variant]['input_i'])
        pcm = work / f'{variant}-matched.wav'
        run(['ffmpeg', '-v', 'error', '-y', '-i', excerpts[variant], '-af', f'volume={gain:.7f}dB', '-c:a', 'pcm_f32le', pcm])
        path = folder / f'试听片段 - {variant}.mp3'
        run(['ffmpeg', '-v', 'error', '-y', '-i', pcm, '-c:a', 'libmp3lame', '-b:a', '320k', path])
        files[variant] = inspect(path, duration)
        assert abs(float(files[variant]['loudness']['input_i']) - common) <= .3
        files[variant]['fixed_gain_db'] = gain
        matched.append(pcm)
    silence = work / 'gap.wav'
    run(['ffmpeg', '-v', 'error', '-y', '-f', 'lavfi', '-i', 'anullsrc=r=48000:cl=stereo', '-t', .8, '-c:a', 'pcm_f32le', silence])
    concat = work / 'concat.txt'
    concat.write_text('\n'.join("file '" + str(x).replace("'", "'\\''") + "'" for x in [matched[0], silence, matched[1], silence, matched[2]]) + '\n')
    joined = folder / '快速对照 - C-D1-D2.mp3'
    run(['ffmpeg', '-v', 'error', '-y', '-f', 'concat', '-safe', 0, '-i', concat, '-c:a', 'libmp3lame', '-b:a', '320k', joined])
    row = {'index': index, 'cue_id': cue, 'title': report['title'], 'start_seconds_in_aligned_full_audio': start,
           'duration_per_variant_seconds': duration, 'selection': selection, 'common_excerpt_target_lufs': common,
           'individual_clips': files, 'joined_order': ['C', 'D1', 'D2'], 'gap_seconds': .8,
           'joined': inspect(joined, duration * 3 + 1.6), 'source_audio_report_sha256': digest(report_path)}
    return row


def playlist(path, entries):
    lines = ['#EXTM3U']
    for p, title, duration in entries:
        lines += [f'#EXTINF:{duration:.3f},{title}', str(Path(p).relative_to(OUTPUT))]
    path.write_text('\n'.join(lines) + '\n', encoding='utf-8')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--indices', default='1,2,3,4,5,6,7,8,9,10,11,12')
    args = parser.parse_args()
    indices = [int(x) for x in args.indices.split(',')]
    rows = [build_one(index) for index in indices]
    full, variants, short = [], [], []
    for row in rows:
        report = json.loads((BASE / 'reports' / f'audio-{row["cue_id"]}.json').read_text())
        for variant in ['C', 'D1', 'D2']:
            entry = (report['outputs'][variant]['files']['mp3']['path'], f'{row["title"]} — {variant}', report['duration_seconds'])
            full.append(entry)
            if variant != 'C':
                variants.append(entry)
        short.append((row['joined']['path'], f'{row["title"]} — C / D1 / D2', row['duration_per_variant_seconds'] * 3 + 1.6))
    paths = [OUTPUT / '先听12首短对照.m3u8', OUTPUT / '全部12首全曲_C-D1-D2.m3u8',
             OUTPUT / '仅中国器乐全曲_D1-D2.m3u8', OUTPUT / '仅D1_中国器乐原音高.m3u8',
             OUTPUT / '仅D2_中国器乐有限调式.m3u8']
    d1 = [entry for entry in full if entry[1].endswith(' — D1')]
    d2 = [entry for entry in full if entry[1].endswith(' — D2')]
    for path, entries in zip(paths, [short, full, variants, d1, d2]):
        playlist(path, entries)
    receipt = {'status': 'PASS', 'clips': rows, 'playlists': [{'path': str(x), 'sha256': digest(x)} for x in paths],
               'musical_source_edits': False, 'clip_level_matching': 'per-song common achievable target, fixed gain only; full songs remain unchanged',
               'manual_listening_review': 'not performed'}
    destination = BASE / 'reports' / 'comparisons.json'
    destination.write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'status': 'PASS', 'songs': len(rows), 'playlists': [str(x) for x in paths]}, ensure_ascii=False))


if __name__ == '__main__':
    main()

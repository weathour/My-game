#!/usr/bin/env python3
"""Make loop-safe, level-matched 48 kHz masters and game Vorbis from REAPER renders."""
import hashlib
import fcntl
import json
import math
from pathlib import Path
import subprocess
import sys
import tempfile

import numpy as np
from scipy.io import wavfile

HERE = Path(__file__).resolve().parent
RAW = Path('/tmp/mygame-music-render')
GAME = HERE.parents[1] / 'assets' / 'music'


def ffmpeg(*args):
    return subprocess.run(['ffmpeg', '-hide_banner', '-nostdin', '-y', *map(str, args)], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def loudness(path):
    result = ffmpeg('-i', path, '-af', 'loudnorm=I=-21:TP=-3:LRA=14:print_format=json', '-f', 'null', '-')
    report = result.stderr.decode()
    return json.loads(report[report.rindex('{'):report.rindex('}') + 1])


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    cues = json.loads((HERE / 'cue-sheet.json').read_text())
    selected = set(sys.argv[1:]) or {c['id'] for c in cues}
    assert selected <= {c['id'] for c in cues}
    qa_path = HERE / 'audio-qa.json'
    reports = json.loads(qa_path.read_text()) if qa_path.exists() else {}
    completed = (RAW / 'render.log').read_text()
    for cue in cues:
        cue_id = cue['id']
        if cue_id not in selected:
            continue
        assert 'DONE ' + cue_id + '\n' in completed, 'REAPER still rendering ' + cue_id
        source = RAW / (cue_id + '.wav')
        with tempfile.TemporaryDirectory(prefix='mygame-master-') as temp_dir:
            temp = Path(temp_dir)
            filtered = temp / 'filtered.wav'
            # Remove subsonic energy and unnecessary top-end; retain musical dynamics.
            ffmpeg('-i', source, '-af', 'highpass=f=32,lowpass=f=15500', '-c:a', 'pcm_f32le', filtered)
            rate, samples = wavfile.read(filtered)
            assert rate == 48000 and samples.ndim == 2 and samples.shape[1] == 2
            cycle_frames = round(cue['beats'] * 60 / cue['bpm'] * rate)
            samples = samples[cycle_frames:cycle_frames * 2].copy() if cue['loop'] else samples.copy()
            assert np.isfinite(samples).all() and np.max(np.abs(samples)) < .99, (cue_id, 'source clipping')
            assert np.sqrt(np.mean(samples**2)) > .0005, (cue_id, 'near silence')
            # The sampled keyboard/GM ensemble was too wide in the mono check.
            # Keep the centre intact while reducing the side signal, before gain.
            mid = samples.mean(axis=1)
            side = (samples[:, 0] - samples[:, 1]) * .275
            samples = np.column_stack((mid + side, mid - side))
            seam_correction = 0.0
            if cue['loop']:
                # Preserve the exact musical period and reverb, correcting only the
                # last 2.7 ms to match the next cycle's waveform slope (no silent gap).
                change = samples[0] - (samples[1] - samples[0]) - samples[-1]
                seam_correction = float(np.max(np.abs(change)))
                ramp = (.5 - .5 * np.cos(np.linspace(0, math.pi, 128)))[:, None]
                samples[-128:] += ramp * change
            else:
                audible = np.flatnonzero(np.max(np.abs(samples), axis=1) > .00003)
                assert len(audible), cue_id
                samples = samples[:min(len(samples), int(audible[-1]) + 4801)]
                samples[-2400:] *= np.linspace(1, 0, 2400)[:, None]
            loop_file = temp / 'loop.wav'
            wavfile.write(loop_file, rate, samples)
            pre = loudness(loop_file)
            # Linear gain keeps phrasing intact. Reserve room for both crossfading
            # streams; encoded true peak is checked again below.
            gain = min(cue['target_lufs'] - float(pre['input_i']), -3.5 - float(pre['input_tp']))
            master = HERE / 'masters' / (cue_id + '.flac')
            ffmpeg('-i', loop_file, '-af', f'volume={gain:.6f}dB', '-c:a', 'flac', '-sample_fmt', 's32', '-bits_per_raw_sample', '24', '-compression_level', '8', '-metadata', 'title=' + cue['title'], '-metadata', 'artist=My-game original score', master)
            ogg = GAME / (cue_id + '.ogg')
            ffmpeg('-i', master, '-c:a', 'libvorbis', '-q:a', '6', '-metadata', 'LOOPSTART=0', '-metadata', f'LOOPEND={len(samples)}', ogg)
            final = loudness(ogg)
            assert float(final['input_tp']) <= -2.5, (cue_id, 'encoded peak', final)
            assert float(final['input_i']) <= cue['target_lufs'] + .4, (cue_id, 'unexpected level')
            mono_loss = 20 * math.log10(max(float(np.sqrt(np.mean(samples.mean(axis=1)**2))), 1e-12) / float(np.sqrt(np.mean(samples**2))))
            assert mono_loss > -3, (cue_id, 'mono cancellation', mono_loss)
            seam = float(np.max(np.abs(samples[0] - samples[-1]))) if cue['loop'] else 0
            decoded = temp / 'decoded.wav'
            ffmpeg('-i', ogg, '-c:a', 'pcm_f32le', decoded)
            decoded_rate, decoded_samples = wavfile.read(decoded)
            assert decoded_rate == rate and abs(len(decoded_samples) - len(samples)) <= 1
            if cue['loop']:
                encoded_seam = float(np.max(np.abs(decoded_samples[0] - decoded_samples[-1])))
                typical_step = float(np.quantile(np.abs(np.diff(decoded_samples, axis=0)), .999))
                assert encoded_seam <= max(.004, typical_step * 1.5), (cue_id, 'loop click', encoded_seam, typical_step)
            else:
                encoded_seam = 0
                assert float(np.max(np.abs(decoded_samples[-480:]))) < .001, (cue_id, 'tail not quiet')
            reports[cue_id] = dict(duration_seconds=len(samples) / rate, sample_rate=rate, channels=2, integrated_lufs=float(final['input_i']), true_peak_dbtp=float(final['input_tp']), mono_loss_db=round(mono_loss, 3), linear_gain_db=round(gain, 4), seam_correction_peak=round(seam_correction, 8), pcm_boundary_step=round(seam, 8), vorbis_boundary_step=round(encoded_seam, 8), frames=len(samples), loop=cue['loop'], reaper_source_sha256=sha(source), flac_sha256=sha(master), ogg_sha256=sha(ogg))
            qa_path.write_text(json.dumps(reports, ensure_ascii=False, indent=2) + '\n')
            print(cue_id, reports[cue_id]['duration_seconds'], final['input_i'], final['input_tp'], flush=True)
    print('Verified', len(reports), 'of', len(cues), 'cues', flush=True)


if __name__ == '__main__':
    # Batch jobs share the QA ledger; never let two writers lose each other's rows.
    with (RAW / 'master.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        main()

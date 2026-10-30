#!/usr/bin/env python3
"""Render selected score cues in an isolated REAPER/X11 job; never publish assets."""
import argparse
import configparser
import hashlib
import json
import os
from pathlib import Path
import select
import shutil
import signal
import subprocess
import tempfile
import time

import numpy as np
from scipy.io import wavfile

from compose import lua

HERE = Path(__file__).resolve().parent
DEFAULT_REAPER = Path.home() / '.local/opt/reaper-7.83/reaper_linux_x86_64/REAPER/reaper'
LOCAL_XVFB = Path.home() / '.local/opt/my-game-xvfb/usr/bin/Xvfb'


def stop(process):
    if process is not None and process.poll() is None:
        os.killpg(process.pid, signal.SIGTERM)
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()


def diagnostics(job, env):
    """Only inspect the virtual display owned by this job."""
    try:
        result = subprocess.run(['xwininfo', '-root', '-tree'], env=env,
                                capture_output=True, text=True, timeout=5)
        (job / 'windows.txt').write_text(result.stdout + result.stderr)
        from PIL import ImageGrab
        ImageGrab.grab(xdisplay=env['DISPLAY']).save(job / 'desktop.png')
    except Exception as error:
        (job / 'diagnostics-error.txt').write_text(str(error))


def verify(job, cues):
    log = (job / 'render.log').read_text()
    if 'ERROR ' in log or not log.endswith('COMPLETE\n'):
        raise RuntimeError('REAPER did not complete the batch; see render.log')
    results = []
    for cue in cues:
        cue_id = cue['id']
        path = job / (cue_id + '.wav')
        project = job / 'projects' / (cue_id + '.rpp')
        if not project.is_file() or project.stat().st_size < 100:
            raise RuntimeError(f'{cue_id}: project was not saved')
        rate, data = wavfile.read(path)
        duration = cue['beats'] * 60 / cue['bpm'] * (2 if cue['loop'] else 1) + 3
        if rate != 48000 or data.ndim != 2 or data.shape[1] != 2:
            raise RuntimeError(f'{cue_id}: incorrect sample rate/channel count')
        if abs(len(data) / rate - duration) > .01:
            raise RuntimeError(f'{cue_id}: incomplete render duration')
        samples = data.astype(np.float64)
        if data.dtype.kind == 'i':
            samples /= float(2 ** (data.dtype.itemsize * 8 - 1))
        if not np.isfinite(samples).all() or np.sqrt(np.mean(samples ** 2)) < 1e-6:
            raise RuntimeError(f'{cue_id}: non-finite or silent render')
        results.append({'cue': cue_id, 'frames': len(data), 'sample_rate': rate,
                        'channels': 2, 'duration_seconds': len(data) / rate,
                        'wav_sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                        'project_sha256': hashlib.sha256(project.read_bytes()).hexdigest()})
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('cues', nargs='*', help='Cue IDs; default: every cue in score.json')
    parser.add_argument('--score', type=Path, default=HERE / 'score.json')
    parser.add_argument('--output', type=Path, help='New or empty job directory')
    parser.add_argument('--reaper', type=Path, default=DEFAULT_REAPER)
    parser.add_argument('--xvfb', type=Path, default=Path(shutil.which('Xvfb') or LOCAL_XVFB))
    parser.add_argument('--profile', type=Path, default=Path('/tmp/mygame-reaper-session'),
                        help='Existing authoring profile to copy; never modified')
    parser.add_argument('--timeout', type=float, default=600, help='Maximum batch seconds')
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error('--timeout must be positive')
    for binary in (args.reaper, args.xvfb):
        if not binary.is_file() or not os.access(binary, os.X_OK):
            parser.error(f'Executable missing: {binary}')
    all_cues = json.loads(args.score.read_text())
    ids = [cue['id'] for cue in all_cues]
    if len(set(ids)) != len(ids) or any(not name or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789_' for c in name) for name in ids):
        parser.error('Score cue IDs must be unique lowercase names with digits/underscores')
    unknown = set(args.cues) - set(ids)
    if unknown:
        parser.error('Unknown cue IDs: ' + ', '.join(sorted(unknown)))
    cues = [cue for cue in all_cues if not args.cues or cue['id'] in args.cues]
    if not cues:
        parser.error('No cues selected')
    if args.output:
        job = args.output.resolve()
        if job.exists() and any(job.iterdir()):
            parser.error('Output directory is not empty; choose a fresh job directory')
        job.mkdir(parents=True, exist_ok=True)
    else:
        cache = Path.home() / '.cache/my-game/music-render'
        cache.mkdir(parents=True, exist_ok=True)
        job = Path(tempfile.mkdtemp(prefix=time.strftime('%Y%m%d-%H%M%S-'), dir=cache))
    print('Render job: ' + str(job), flush=True)
    (job / 'projects').mkdir()
    profile = job / 'reaper-profile'
    profile.mkdir()
    # Retain existing evaluation/license state without editing it. No user's
    # project, recent list or personal REAPER instance is opened by this job.
    config = configparser.RawConfigParser(strict=False)
    config.optionxform = str
    config.read(args.profile / 'reaper.ini')
    for section in ('Recent', 'REAPER', 'reaper'):
        if config.has_section(section):
            config.remove_section(section)
    config['reaper'] = {'renderclosewhendone': '4'}
    with (profile / 'reaper.ini').open('w') as output:
        config.write(output)
    for name in ('reaper-license.rk',):
        source = args.profile / name
        if source.is_file():
            shutil.copy2(source, profile / name)
    # Use the exact bundled instruments; do not copy an arbitrary user's plugins.
    shutil.copytree(args.reaper.resolve().parent / 'InstallData/Effects', profile / 'Effects')
    empty = job / 'empty.rpp'
    empty.write_text('<REAPER_PROJECT 0.1 "7.83"\n>\n')
    (job / 'score.lua').write_text('return ' + lua(cues) + '\n')
    (job / 'score.json').write_text(json.dumps(cues, ensure_ascii=False) + '\n')
    settings = {'output': str(job), 'score': str(job / 'score.lua'),
                'projects': str(job / 'projects'), 'empty_project': str(empty)}
    launcher = job / 'run.lua'
    launcher.write_text('MYGAME_RENDER_CONFIG = ' + lua(settings) + '\n'
                        + 'dofile(' + lua(str(HERE / 'render.lua')) + ')\n')
    env = os.environ.copy()
    local_lib = args.xvfb.resolve().parents[1] / 'lib/x86_64-linux-gnu'
    if local_lib.is_dir():
        env['LD_LIBRARY_PATH'] = str(local_lib) + (':' + env['LD_LIBRARY_PATH'] if env.get('LD_LIBRARY_PATH') else '')
    env['GDK_BACKEND'] = 'x11'
    env.pop('WAYLAND_DISPLAY', None)
    xvfb = reaper = None
    result = {'success': False, 'job': str(job), 'cues': [cue['id'] for cue in cues]}
    started = time.monotonic()
    try:
        with (job / 'xvfb.log').open('w') as xlog, (job / 'reaper.log').open('w') as rlog:
            read_fd, write_fd = os.pipe()
            try:
                xvfb = subprocess.Popen([str(args.xvfb), '-displayfd', str(write_fd),
                                         '-screen', '0', '1280x800x24', '-nolisten', 'tcp'],
                                        env=env, pass_fds=(write_fd,), stdout=xlog,
                                        stderr=subprocess.STDOUT, start_new_session=True)
                os.close(write_fd)
                write_fd = None
                if not select.select([read_fd], [], [], 10)[0]:
                    raise RuntimeError('Virtual display did not start; see xvfb.log')
                number = os.read(read_fd, 64).decode().strip()
                if not number.isdigit():
                    raise RuntimeError('Virtual display failed; see xvfb.log')
            finally:
                os.close(read_fd)
                if write_fd is not None:
                    os.close(write_fd)
            env['DISPLAY'] = ':' + number
            reaper = subprocess.Popen([str(args.reaper), '-newinst', '-nosplash', '-new',
                                       '-cfgfile', str(profile / 'reaper.ini'), str(launcher)],
                                      env=env, stdout=rlog, stderr=subprocess.STDOUT,
                                      start_new_session=True)
            try:
                code = reaper.wait(timeout=args.timeout)
            except subprocess.TimeoutExpired:
                diagnostics(job, env)
                raise RuntimeError('Render timed out; inspect windows.txt/desktop.png') from None
            if code != 0:
                raise RuntimeError(f'REAPER exited with {code}; see reaper.log')
            result['files'] = verify(job, cues)
            result['success'] = True
    except Exception as error:
        result['error'] = str(error)
    finally:
        stop(reaper)
        stop(xvfb)
        result['elapsed_seconds'] = round(time.monotonic() - started, 2)
        (job / 'result.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(result, ensure_ascii=False, indent=2), flush=True)
    return 0 if result['success'] else 1


if __name__ == '__main__':
    raise SystemExit(main())

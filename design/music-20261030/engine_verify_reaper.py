#!/usr/bin/env python3
"""Open a rendered cue in isolated REAPER/Xvfb, check MIDI/stems, rerender mix.

No personal profile or running REAPER instance is modified. The output must be
a new directory. This is an engineering check, not a listening review.
"""
import argparse
import json
import os
from pathlib import Path
import select
import signal
import subprocess

import numpy as np
from scipy.io import wavfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cue-dir', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--timeout', type=float, default=60)
    parser.add_argument('--reaper', type=Path, default=Path.home() / '.local/opt/reaper-7.83/reaper_linux_x86_64/REAPER/reaper')
    parser.add_argument('--xvfb', type=Path, default=Path.home() / '.local/opt/my-game-xvfb/usr/bin/Xvfb')
    args = parser.parse_args()
    cue_dir = args.cue_dir.resolve()
    cue = json.loads((cue_dir / 'score.json').read_text())
    job = args.output.resolve()
    if job.exists() and any(job.iterdir()):
        parser.error('Use a new or empty verification directory')
    job.mkdir(parents=True, exist_ok=True)
    profile = job / 'profile'
    profile.mkdir()
    (profile / 'reaper.ini').write_text('[reaper]\nrenderclosewhendone=4\n')
    empty = job / 'empty.rpp'
    empty.write_text('<REAPER_PROJECT 0.1 "7.83"\n>\n')
    rate, original = wavfile.read(cue_dir / 'mix.wav')
    meter = cue.get('meter', [4, 4])
    # JSON quoted paths are also valid Lua strings on this Linux filesystem.
    config = ('local project=' + json.dumps(str(cue_dir / (cue['id'] + '.rpp'))) + '\n'
              + 'local out=' + json.dumps(str(job)) + '\n'
              + 'local empty=' + json.dumps(str(empty)) + '\n'
              + f'local expected_bpm={cue["bpm"]}\nlocal expected_num={meter[0]}\nlocal expected_denom={meter[1]}\n'
              + f'local stem_count={len(cue["tracks"])}\nlocal expected_frames={len(original)}\nlocal seconds=expected_frames/48000\n'
              + 'local expected_notes={' + ','.join(str(len(t.get('notes', []))) for t in cue['tracks']) + '}\n')
    script = job / 'verify.lua'
    script.write_text(config + '''
local log=assert(io.open(out..'/verify.log','w'))
local function run()
  reaper.Main_openProject('noprompt:'..project)
  assert(reaper.CountTracks(0)==stem_count*2,'track count mismatch')
  local num,denom,bpm=reaper.TimeMap_GetTimeSigAtTime(0,0)
  log:write('tempo='..bpm..' meter='..num..'/'..denom..'\\n')
  assert(math.abs(bpm-expected_bpm)<0.0001,'tempo mismatch')
  assert(num==expected_num and denom==expected_denom,'meter mismatch')
  for i=0,reaper.CountTracks(0)-1 do
    local tr=reaper.GetTrack(0,i)
    local item=reaper.GetTrackMediaItem(tr,0)
    local take=reaper.GetActiveTake(item)
    if i<stem_count then
      local source=reaper.GetMediaItemTake_Source(take)
      assert(reaper.GetMediaSourceSampleRate(source)==48000,'source sample rate')
      assert(reaper.GetMediaSourceNumChannels(source)==2,'source channel count')
    else
      local _,notes,cc=reaper.MIDI_CountEvts(take)
      assert(notes==expected_notes[i-stem_count+1],'MIDI note count mismatch')
      assert(reaper.GetMediaTrackInfo_Value(tr,'B_MUTE')==1,'MIDI safety mute missing')
      log:write('midi_track='..(i-stem_count+1)..' notes='..notes..' cc='..cc..'\\n')
    end
  end
  log:flush()
  -- Custom render bounds go through REAPER's render dialog time fields and
  -- lose sub-millisecond precision in 7.83. The API's time selection retains
  -- the exact integer-sample endpoint; do not pad/trim or relax length checks.
  reaper.GetSet_LoopTimeRange2(0,true,false,0,seconds,false)
  local selection_start,selection_end=reaper.GetSet_LoopTimeRange2(0,false,false,0,0,false)
  assert(math.abs(selection_start)<0.25/48000,'time selection start changed')
  assert(math.abs(selection_end-seconds)<0.25/48000,'time selection end changed')
  log:write('exact_time_selection_frames='..expected_frames..' end_seconds='..string.format('%.15f',selection_end)..'\\n')
  log:flush()
  reaper.GetSetProjectInfo(0,'RENDER_BOUNDSFLAG',2,true)
  reaper.GetSetProjectInfo(0,'RENDER_SRATE',48000,true)
  reaper.GetSetProjectInfo(0,'RENDER_CHANNELS',2,true)
  reaper.GetSetProjectInfo(0,'RENDER_SETTINGS',0,true)
  reaper.GetSetProjectInfo(0,'RENDER_TAILFLAG',0,true)
  reaper.GetSetProjectInfo_String(0,'RENDER_FORMAT','evaw',true)
  reaper.GetSetProjectInfo_String(0,'RENDER_FILE',out,true)
  reaper.GetSetProjectInfo_String(0,'RENDER_PATTERN','reaper_mix',true)
  reaper.Main_OnCommand(42230,0)
  log:write('COMPLETE\\n')
end
local ok,err=xpcall(run,debug.traceback)
if not ok then log:write('ERROR '..tostring(err)..'\\n') end
log:close()
reaper.defer(function() reaper.Main_openProject('noprompt:'..empty);reaper.Main_OnCommand(40004,0) end)
''')
    env = os.environ.copy()
    lib = args.xvfb.resolve().parents[1] / 'lib/x86_64-linux-gnu'
    if lib.is_dir():
        env['LD_LIBRARY_PATH'] = str(lib) + (':' + env['LD_LIBRARY_PATH'] if env.get('LD_LIBRARY_PATH') else '')
    env['GDK_BACKEND'] = 'x11'
    env.pop('WAYLAND_DISPLAY', None)
    x = r = None
    result = {'success': False, 'listening_review': False}
    try:
        with (job / 'xvfb.log').open('w') as xlog, (job / 'reaper.log').open('w') as rlog:
            read_fd, write_fd = os.pipe()
            try:
                x = subprocess.Popen([str(args.xvfb), '-displayfd', str(write_fd), '-screen', '0',
                                      '1280x800x24', '-nolisten', 'tcp'], env=env, pass_fds=(write_fd,),
                                     stdout=xlog, stderr=xlog, start_new_session=True)
                os.close(write_fd)
                write_fd = None
                if not select.select([read_fd], [], [], 10)[0]:
                    raise RuntimeError('Xvfb startup timed out')
                number = os.read(read_fd, 64).decode().strip()
                if not number.isdigit():
                    raise RuntimeError('Xvfb did not return a display number')
                env['DISPLAY'] = ':' + number
            finally:
                os.close(read_fd)
                if write_fd is not None:
                    os.close(write_fd)
            r = subprocess.Popen([str(args.reaper), '-newinst', '-nosplash', '-new', '-cfgfile',
                                  str(profile / 'reaper.ini'), str(script)], env=env,
                                 stdout=rlog, stderr=rlog, start_new_session=True)
            code = r.wait(timeout=args.timeout)
        log = (job / 'verify.log').read_text()
        if code != 0 or 'ERROR ' in log or not log.endswith('COMPLETE\n'):
            raise RuntimeError('REAPER structural verification failed; see verify.log')
        sample_rate, rendered = wavfile.read(job / 'reaper_mix.wav')
        if rendered.dtype.kind == 'i':
            rendered = rendered.astype(np.float64) / 2 ** (rendered.dtype.itemsize * 8 - 1)
        if sample_rate != rate or original.shape != rendered.shape:
            raise RuntimeError('REAPER render format/duration mismatch')
        delta = float(np.max(np.abs(original.astype(np.float64) - rendered)))
        if delta > 1e-6:
            raise RuntimeError(f'Frozen stem reconstruction differs by {delta}')
        result.update(success=True, frames=len(rendered), sample_rate=rate, channels=2,
                      expected_frames=len(original), render_bounds='exact integer-sample time selection',
                      frozen_stems=len(cue['tracks']), editable_midi_tracks=len(cue['tracks']),
                      max_absolute_reconstruction_error=delta,
                      last_64_frames_max_absolute_error=float(np.max(np.abs(original[-64:].astype(np.float64) - rendered[-64:]))),
                      note_count=sum(len(t.get('notes', [])) for t in cue['tracks']), log=log)
    except Exception as error:
        result['error'] = str(error)
    finally:
        for process in (r, x):
            if process and process.poll() is None:
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
        (job / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
    return 0 if result['success'] else 1


if __name__ == '__main__':
    raise SystemExit(main())

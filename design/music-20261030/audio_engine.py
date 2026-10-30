#!/usr/bin/env python3
"""Deterministic 48 kHz stereo multisample renderer and editable REAPER export.

No user's REAPER configuration is opened. Each cue contains aligned frozen
stems, a mix, a type-1 MIDI score, a REAPER project, and an auditable report.
Samples use the upstream SFZ numeric root notes, velocity regions, tuning,
gain, sample offsets, and deterministic round robin/random region selection.
There is deliberately no invented infinite sustain loop or GM fallback.
"""
from __future__ import annotations

import argparse
from fractions import Fraction
from functools import lru_cache
import hashlib
import json
import math
from pathlib import Path
import re
import struct
import subprocess
import sys
import warnings

import numpy as np
from scipy.io import wavfile
from scipy.signal import resample_poly

from fetch_instruments import DEFAULT_CACHE, DEFAULT_MANIFEST, apply_mapping_overrides, checked_file, fetch, file_path, load_manifest

RATE = 48000
SUPPORTED_CC = {1, 7, 10, 11, 64}
VERSION = 'my-game-multisample-3.1'
CHANNEL_SELECTION_THRESHOLD_DB = -4.0


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def finite(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def validate_cue(cue, manifest):
    if not isinstance(cue, dict) or not re.fullmatch(r'[a-z][a-z0-9_]*', str(cue.get('id', ''))):
        raise ValueError('Cue id must be a lowercase safe filename')
    for key in ('bpm', 'beats'):
        if not finite(cue.get(key)) or cue[key] <= 0:
            raise ValueError(f'{cue["id"]}: positive finite {key} required')
    if not isinstance(cue.get('loop'), bool):
        raise ValueError(f'{cue["id"]}: loop must be boolean')
    meter = cue.get('meter', [4, 4])
    if len(meter) != 2 or any(not isinstance(n, int) or isinstance(n, bool) for n in meter) or not 1 <= meter[0] <= 64 or meter[1] not in (1, 2, 4, 8, 16, 32):
        raise ValueError(f'{cue["id"]}: invalid MIDI meter')
    if not isinstance(cue.get('tracks'), list) or not cue['tracks']:
        raise ValueError(f'{cue["id"]}: tracks required')
    for index, part in enumerate(cue['tracks']):
        instrument = part.get('instrument')
        inst = manifest['instruments'].get(instrument)
        if not inst or inst['status'] == 'unsupported':
            raise ValueError(f'{cue["id"]} track {index}: unsupported {instrument!r}: {inst.get("reason") if inst else "unregistered"}')
        for key, lo, hi, default in [('db', -100, 24, 0), ('pan', -1, 1, 0)]:
            value = part.get(key, default)
            if not finite(value) or not lo <= value <= hi:
                raise ValueError(f'{cue["id"]}: invalid {key} {value!r}')
        if part.get('articulation', 'auto') not in ('auto', 'sustain', 'short'):
            raise ValueError(f'{cue["id"]}: articulation must be auto, sustain or short')
        for note in part.get('notes', []):
            if len(note) != 4 or not all(finite(n) for n in note):
                raise ValueError(f'{cue["id"]}: malformed note {note!r}')
            start, duration, pitch, velocity = note
            if start < 0 or duration <= 0 or start + duration > cue['beats'] + 1e-5 or int(pitch) != pitch or not 0 <= pitch <= 127 or int(velocity) != velocity or not 1 <= velocity <= 127:
                raise ValueError(f'{cue["id"]}: note outside score/MIDI range: {note}')
        for event in part.get('cc', []):
            if len(event) != 3 or not all(finite(n) for n in event):
                raise ValueError(f'{cue["id"]}: malformed CC {event}')
            beat, number, value = event
            if not 0 <= beat <= cue['beats'] or int(number) != number or int(value) != value or not 0 <= value <= 127 or number not in SUPPORTED_CC:
                raise ValueError(f'{cue["id"]}: unsupported/invalid CC {event}; supported: {sorted(SUPPORTED_CC)}')
    if not any(part.get('notes') for part in cue['tracks']):
        raise ValueError(f'{cue["id"]}: all tracks empty')
    return cue


def cc_value(events, beat, number, default):
    result = default
    for t, n, value in sorted(events):
        if t > beat:
            break
        if n == number:
            result = value
    return result


def pedal_end(events, end, cue_beats):
    if cc_value(events, end, 64, 0) < 64:
        return end
    return next((t for t, n, value in sorted(events) if t > end and n == 64 and value < 64), cue_beats)


def prepare_source_channels(data, threshold_db=CHANNEL_SELECTION_THRESHOLD_DB):
    """Keep native stereo unless its original mono energy loss is excessive.

    A selected original microphone is duplicated, never an average or polarity
    flip. This protects the recorded spectrum from inter-microphone comb loss.
    No gain adjustment is made; track panning and the later shared room remain
    separate. This does not modify the verified original file in the cache.
    """
    measured = data.astype(np.float64)
    energies = np.mean(measured ** 2, axis=0)
    stereo_energy = float(np.mean(energies))
    mono_energy = float(np.mean(np.mean(measured, axis=1) ** 2))
    loss_db = 10 * math.log10(max(mono_energy, 1e-30) / max(stereo_energy, 1e-30)) if stereo_energy else 0.0
    selected = loss_db < threshold_db
    channel = int(np.argmax(energies)) if selected else None
    info = {'policy': 'stronger_original_channel_if_mono_loss_below_threshold',
            'threshold_db': threshold_db, 'original_mono_energy_loss_db': loss_db,
            'original_channel_rms': [float(math.sqrt(e)) for e in energies],
            'selected': selected, 'selected_channel': ('left' if channel == 0 else 'right') if selected else None,
            'operation': 'copy one original channel to both outputs' if selected else 'preserve native stereo',
            'classification': 'source preprocessing information, not a musical adaptation error'}
    if selected:
        data = np.repeat(data[:, channel:channel + 1], 2, axis=1)
    return data, info


class Sampler:
    def __init__(self, manifest, cache):
        self.manifest, self.cache = apply_mapping_overrides(manifest), Path(cache)
        self.verified = set()
        self.source_channel_audit = {}

    @lru_cache(maxsize=192)
    def sample(self, key, pitch, root, cents=0, offset=0):
        record = self.manifest['files'][key]
        path = file_path(self.cache, key)
        if key not in self.verified:
            if not checked_file(path, record):
                raise RuntimeError(f'Missing/corrupt sample {path}; run fetch_instruments.py')
            self.verified.add(key)
        with warnings.catch_warnings():
            warnings.simplefilter('ignore', wavfile.WavFileWarning)
            rate, data = wavfile.read(path)
        if data.dtype.kind == 'i':
            data = data.astype(np.float32) / float(2 ** (8 * data.dtype.itemsize - 1))
        elif data.dtype.kind == 'u':
            data = (data.astype(np.float32) - 128) / 128
        else:
            data = data.astype(np.float32)
        if data.ndim == 1:
            data = np.repeat(data[:, None], 2, axis=1)
        if data.ndim != 2 or data.shape[1] != 2 or not np.isfinite(data).all():
            raise RuntimeError(f'Invalid audio sample: {path}')
        data, channel_info = prepare_source_channels(data)
        self.source_channel_audit[key] = {'file': key, **channel_info}
        data = data[int(offset):]
        ratio = 2 ** ((pitch - root + cents / 100) / 12)
        factor = Fraction(RATE / rate / ratio).limit_denominator(4096)
        if factor.numerator != factor.denominator:
            data = resample_poly(data, factor.numerator, factor.denominator, axis=0).astype(np.float32)
        return data

    def select(self, patch_id, pitch, velocity, event_index, trigger, audit):
        regions = [r for r in self.manifest['patches'][patch_id]['regions']
                   if r.get('trigger', 'attack') == trigger]
        if not regions:
            return []
        actual_pitch = pitch
        pitched = [r for r in regions if r.get('lokey', 0) <= pitch <= r.get('hikey', 127)]
        if not pitched:
            # Deliberate, measured range extension; never silently drop a note.
            nearest = min(regions, key=lambda r: min(abs(pitch - r.get('lokey', 0)), abs(pitch - r.get('hikey', 127))))
            actual_pitch = min(max(pitch, nearest.get('lokey', 0)), nearest.get('hikey', 127))
            pitched = [r for r in regions if r.get('lokey', 0) <= actual_pitch <= r.get('hikey', 127)]
            if trigger == 'attack':
                audit.append({'type': 'range_extension', 'pitch': pitch, 'nearest_mapped_key': actual_pitch, 'patch': patch_id})
        candidates = [r for r in pitched if r.get('lovel', 0) <= velocity <= r.get('hivel', 127)]
        if not candidates:
            distance = lambda r: min(abs(velocity - r.get('lovel', 0)), abs(velocity - r.get('hivel', 127)))
            best = min(map(distance, pitched))
            candidates = [r for r in pitched if distance(r) == best]
            audit.append({'type': 'velocity_region_repair', 'velocity': velocity, 'patch': patch_id})
        rnd = ((event_index * 0.6180339887498949) + 0.25) % 1
        chosen = [r for r in candidates if (event_index % r.get('seq_length', 1)) + 1 == r.get('seq_position', 1)
                  and r.get('lorand', 0) <= rnd < r.get('hirand', 1)]
        if not chosen:
            chosen = [candidates[event_index % len(candidates)]]
            audit.append({'type': 'round_robin_region_repair', 'patch': patch_id})
        return chosen

    def voice(self, region, pitch, velocity, hold, instrument, audit):
        source = self.sample(region['file'], pitch, region.get('pitch_keycenter', 60),
                             region.get('tune', 0), region.get('offset', 0))
        release = max(.005, float(region.get('ampeg_release', .3)))
        hold_frames = max(1, round(hold * RATE))
        length = min(len(source), hold_frames + round(release * RATE))
        data = source[:length].copy()
        if instrument.get('sustained', False) and len(source) < hold_frames and len(source) / RATE > .1:
            audit.append({'type': 'recorded_sustain_exhausted', 'file': region['file'],
                          'pitch': pitch, 'requested_seconds': round(hold, 4),
                          'recorded_seconds': round(len(source) / RATE, 4)})
        attack = min(length, round(max(.001, region.get('ampeg_attack', .004)) * RATE))
        if attack:
            data[:attack] *= np.linspace(0, 1, attack, dtype=np.float32)[:, None]
        if length > hold_frames:
            envelope = np.exp(-7 * np.arange(length - hold_frames, dtype=np.float32) / (release * RATE))
            data[hold_frames:] *= envelope[:, None]
        # Finite source playback; end fade prevents a cut at its recorded boundary.
        fade = min(length, round(.008 * RATE))
        if fade:
            data[-fade:] *= np.linspace(1, 0, fade, dtype=np.float32)[:, None]
        veltrack = region.get('amp_veltrack', 100) / 100
        gain = 10 ** ((region.get('volume', 0) + instrument.get('trim_db', -15)) / 20)
        curve = sorted((int(key.removeprefix('amp_velcurve_')), value)
                       for key, value in region.items() if key.startswith('amp_velcurve_'))
        if curve:
            points = dict([(0, 0), (127, 1)] + curve)
            keys = sorted(points)
            gain *= float(np.interp(velocity, keys, [points[key] for key in keys])) ** veltrack
        else:
            gain *= (velocity / 127) ** (2 * veltrack)
        return data * gain


def synth_voice(instrument, pitch, velocity, hold):
    release = .9 if instrument['algorithm'] == 'pad' else .35
    t = np.arange(round((hold + release) * RATE), dtype=np.float64) / RATE
    hz = 440 * 2 ** ((pitch - 69) / 12)
    # Fixed phases and no random source: repeated renders are byte-identical.
    y = sum(np.sin(2 * np.pi * hz * n * t) / n ** 2.5 for n in (1, 2, 3, 4))
    if instrument['algorithm'] == 'pad':
        env = np.minimum(t / .12, 1) * np.exp(-np.maximum(t - hold, 0) * 7 / release)
    else:
        env = np.minimum(t / .003, 1) * np.exp(-t * 2.5) * np.exp(-np.maximum(t - hold, 0) * 7 / release)
    y *= env * (velocity / 127) ** 2 * 10 ** (instrument.get('trim_db', -15) / 20)
    return np.repeat(y.astype(np.float32)[:, None], 2, axis=1)


def automation(part, frames, beats, seconds_per_beat, repeats):
    gain = np.ones(frames, dtype=np.float32)
    pan = np.full(frames, part.get('pan', 0), dtype=np.float32)
    events = part.get('cc', [])
    # MIDI controls are sample-accurate steps. A 5 ms ramp removes zipper clicks.
    smooth = round(.005 * RATE)
    period_frames = round(beats * seconds_per_beat * RATE)
    for number, initial in [(7, 127), (11, 127), (1, 127), (10, 64)]:
        controller = np.full(frames, initial, dtype=np.float32)
        selected = sorted((b, v) for b, n, v in events if n == number)
        if not selected:
            continue
        for repeat in range(repeats):
            for beat, value in selected:
                start = repeat * period_frames + round(beat * seconds_per_beat * RATE)
                if start >= frames:
                    continue
                old = controller[start - 1] if start else initial
                end = min(frames, start + smooth)
                controller[start:end] = np.linspace(old, value, end - start)
                controller[end:] = value
        if number == 10:
            pan = np.clip(pan + (controller - 64) / 63, -1, 1)
        else:
            # CC1 is explicitly an expression proxy, not recorded dynamic crossfade.
            gain *= (controller / 127) ** 2
    gain *= 10 ** (part.get('db', 0) / 20)
    # Stereo balance retains the sample's image and leaves centre at unity.
    return gain, np.minimum(1, 1 - pan), np.minimum(1, 1 + pan)


def render_track(cue, part, sampler, tail, audit, source_info=None, mapping_info=None):
    instrument = sampler.manifest['instruments'][part['instrument']]
    spb = 60 / cue['bpm']
    duration = cue['beats'] * spb
    period_frames = round(duration * RATE)
    repeats = 3 if cue['loop'] else 1
    frames = repeats * period_frames + round(tail * RATE)
    data = np.zeros((frames, 2), dtype=np.float32)
    events = sorted(part.get('notes', []), key=lambda n: (n[0], n[2], n[1], n[3]))
    used_sources = set()
    used_mapping_overrides = {}
    if instrument['status'] == 'mapped':
        audit.append({'type': 'instrument_mapping', 'requested': part['instrument'], 'actual': instrument['actual_name'], 'notice': instrument['mapping_notice']})
    if any(n == 1 for _, n, _ in part.get('cc', [])):
        audit.append({'type': 'cc1_expression_proxy', 'notice': 'CC1 controls amplitude; no recorded dynamic crossfade claimed'})
    for index, (start, note_beats, pitch, velocity) in enumerate(events):
        hold = (pedal_end(part.get('cc', []), start + note_beats, cue['beats']) - start) * spb
        patch_mode = part.get('articulation', 'auto')
        patch_mode = ('short' if note_beats * spb < .24 else 'sustain') if patch_mode == 'auto' else patch_mode
        if patch_mode not in instrument.get('patches', {}) and instrument['status'] != 'synthesized':
            patch_mode = 'sustain'
        rendered_pitch = instrument.get('fixed_key', pitch)
        if 'unpitched_key' in instrument and pitch not in instrument.get('unpitched_keys', [60, 61, 62]):
            rendered_pitch = instrument['unpitched_key']
            audit.append({'type': 'unpitched_key_mapping', 'input_pitch': pitch, 'source_key': rendered_pitch,
                          'notice': 'An unpitched gong hit; input MIDI pitch does not transpose it'})
        if str(pitch) in instrument.get('note_map', {}):
            rendered_pitch = instrument['note_map'][str(pitch)]
            audit.append({'type': 'percussion_key_mapping', 'input_pitch': pitch, 'source_key': rendered_pitch})
        voices = []
        if instrument['status'] == 'synthesized':
            voices.append((0, synth_voice(instrument, pitch, velocity, hold)))
        else:
            patch_id = instrument['patches'][patch_mode]
            if isinstance(patch_id, list):
                # Explicit register split, without multiplying unrelated sections.
                split_keys = instrument.get('split_keys', [56, 67])
                patch_id = patch_id[min(len(patch_id) - 1, sum(pitch >= key for key in split_keys))]
            for trigger in ('attack', 'release'):
                for region in sampler.select(patch_id, rendered_pitch, velocity, index, trigger, audit):
                    used_sources.add(region['file'])
                    if region.get('local_mapping_override'):
                        change = region['local_mapping_override']
                        used_mapping_overrides[change['id']] = change
                    note_audit = audit if not voices else []
                    voice_hold = hold if trigger == 'attack' else 15
                    voices.append((0 if trigger == 'attack' else hold,
                                   sampler.voice(region, rendered_pitch, velocity, voice_hold, instrument, note_audit)))
        for repeat in range(repeats):
            for offset, voice in voices:
                pos = repeat * period_frames + round((start * spb + offset) * RATE)
                n = min(len(voice), frames - pos)
                if n > 0:
                    data[pos:pos + n] += voice[:n]
    gain, left, right = automation(part, frames, cue['beats'], spb, repeats)
    data[:, 0] *= gain * left
    data[:, 1] *= gain * right
    if cue['loop']:
        data = data[period_frames:2 * period_frames]
    if source_info is not None:
        source_info.extend(sampler.source_channel_audit[key] for key in sorted(used_sources)
                           if sampler.source_channel_audit[key]['selected'])
    if mapping_info is not None:
        mapping_info.extend(used_mapping_overrides[key] for key in sorted(used_mapping_overrides))
    return data


def required_score_files(cues, manifest):
    """Exact deterministic note regions, not whole libraries, for --fetch."""
    sampler = Sampler(manifest, DEFAULT_CACHE)
    keys = set()
    for cue in cues:
        for part in cue['tracks']:
            inst = manifest['instruments'][part['instrument']]
            if inst['status'] == 'synthesized':
                continue
            events = sorted(part.get('notes', []), key=lambda n: (n[0], n[2], n[1], n[3]))
            for index, (_, duration, pitch, velocity) in enumerate(events):
                mode = part.get('articulation', 'auto')
                if mode == 'auto':
                    mode = 'short' if duration * 60 / cue['bpm'] < .24 else 'sustain'
                if mode not in inst['patches']:
                    mode = 'sustain'
                patch = inst['patches'][mode]
                if isinstance(patch, list):
                    patch = patch[min(len(patch) - 1, sum(pitch >= key for key in inst.get('split_keys', [56, 67])))]
                rendered_pitch = inst.get('fixed_key', pitch)
                if 'unpitched_key' in inst and pitch not in inst.get('unpitched_keys', [60, 61, 62]):
                    rendered_pitch = inst['unpitched_key']
                rendered_pitch = inst.get('note_map', {}).get(str(pitch), rendered_pitch)
                keys.add(manifest['patches'][patch]['mapping_file'])
                for trigger in ('attack', 'release'):
                    keys.update(r['file'] for r in sampler.select(patch, rendered_pitch, velocity, index, trigger, []))
    for source in {manifest['files'][key]['source'] for key in keys}:
        keys.update(manifest['sources'][source]['documentation_files'])
    return sorted(keys)


def metrics(data):
    peak = float(np.max(np.abs(data)))
    rms = float(np.sqrt(np.mean(data.astype(np.float64) ** 2)))
    return {'frames': len(data), 'sample_rate': RATE, 'channels': 2,
            'seconds': len(data) / RATE, 'peak_dbfs': 20 * math.log10(max(peak, 1e-12)),
            'rms_dbfs': 20 * math.log10(max(rms, 1e-12)), 'over_0dbfs_samples': int(np.sum(np.abs(data) > 1)),
            'loop_boundary_max_delta': float(np.max(np.abs(data[0] - data[-1]))) if len(data) else 0}


def vlq(value):
    result = [value & 127]
    while value >> 7:
        value >>= 7
        result.insert(0, (value & 127) | 128)
    return bytes(result)


def midi_track(events):
    result = bytearray()
    previous = 0
    for tick, priority, event in sorted(events, key=lambda e: (e[0], e[1], e[2])):
        result += vlq(tick - previous) + event
        previous = tick
    result += b'\0\xff\x2f\0'
    return b'MTrk' + struct.pack('>I', len(result)) + result


def write_midi(cue, path):
    ppq = 960
    tempo = round(60_000_000 / cue['bpm'])
    meter = cue.get('meter', [4, 4])
    conductor = [(0, 0, b'\xff\x51\x03' + tempo.to_bytes(3, 'big')),
                 (0, 0, b'\xff\x58\x04' + bytes([meter[0], int(math.log2(meter[1])), 24, 8]))]
    tracks = [midi_track(conductor)]
    channels = [n for n in range(16) if n != 9]
    for index, part in enumerate(cue['tracks']):
        ch = 9 if part['instrument'] in ('drums', 'taiko', 'rock_drums') else channels[index % len(channels)]
        label = part.get('name', part['instrument']).encode('utf-8')
        events = [(0, 0, b'\xff\x03' + vlq(len(label)) + label)]
        events.append((0, 1, bytes([0xc0 | ch, int(part.get('program', 0)) & 127])))
        for beat, number, value in part.get('cc', []):
            events.append((round(beat * ppq), 2, bytes([0xb0 | ch, int(number), int(value)])))
        for start, duration, pitch, velocity in part.get('notes', []):
            events.append((round(start * ppq), 4, bytes([0x90 | ch, int(pitch), int(velocity)])))
            events.append((round((start + duration) * ppq), 3, bytes([0x80 | ch, int(pitch), 0])))
        tracks.append(midi_track(events))
    path.write_bytes(b'MThd' + struct.pack('>IHHH', 6, 1, len(tracks), ppq) + b''.join(tracks))


def rpp_quote(value):
    return '"' + str(value).replace('"', "'").replace('\n', ' ') + '"'


def write_rpp(cue, stems, path, audio_seconds):
    meter = cue.get('meter', [4, 4])
    lines = ['<REAPER_PROJECT 0.1 7.83 1', f'  TEMPO {cue["bpm"]} {meter[0]} {meter[1]}',
             '  SAMPLERATE 48000']
    for name, relative in stems:
        lines += ['  <TRACK', f'    NAME {rpp_quote(name)}', '    VOLPAN 1 0 1 -1',
                  '    <ITEM', '      POSITION 0', f'      LENGTH {audio_seconds:.12f}',
                  '      VOLPAN 1 0 1 -1', f'      NAME {rpp_quote(name)}',
                  '      <SOURCE WAVE', f'        FILE {rpp_quote(relative)}', '      >', '    >', '  >']
    for index, part in enumerate(cue['tracks']):
        # A muted editable companion keeps the composition inside the project,
        # while the frozen tracks play without a third-party sampler plugin.
        events = []
        for start, duration, pitch, velocity in part.get('notes', []):
            events.append((round(start * 960), 2, [0x90, int(pitch), int(velocity)]))
            events.append((round((start + duration) * 960), 1, [0x80, int(pitch), 0]))
        for beat, number, value in part.get('cc', []):
            events.append((round(beat * 960), 0, [0xb0, int(number), int(value)]))
        lines += ['  <TRACK', f'    NAME {rpp_quote("MIDI / " + part.get("name", part["instrument"]))}',
                  '    MUTESOLO 1 0 0', '    <ITEM', '      POSITION 0',
                  f'      LENGTH {cue["beats"] * 60 / cue["bpm"]:.12f}',
                  f'      NAME {rpp_quote(part.get("name", part["instrument"]))}',
                  '      <SOURCE MIDI', '        HASDATA 1 960 QN']
        previous = 0
        for tick, _, event in sorted(events, key=lambda e: (e[0], e[1], e[2])):
            lines.append('        E ' + str(tick - previous) + ' ' + ' '.join(f'{byte:02x}' for byte in event))
            previous = tick
        lines += ['        E ' + str(max(0, round(cue['beats'] * 960) - previous)) + ' b0 7b 00',
                  '      >', '    >', '  >']
    lines += ['>']
    path.write_text('\n'.join(lines) + '\n')


def render_cue(cue, output, cache=DEFAULT_CACHE, manifest=None, tail=3.0, sampler=None):
    manifest = apply_mapping_overrides(manifest) if manifest is not None else load_manifest()
    validate_cue(cue, manifest)
    sampler = sampler or Sampler(manifest, cache)
    output = Path(output) / cue['id']
    if output.exists() and any(output.iterdir()):
        raise ValueError(f'Output cue directory is not empty: {output}')
    (output / 'stems').mkdir(parents=True, exist_ok=True)
    duration = cue['beats'] * 60 / cue['bpm']
    period_frames = round(duration * RATE)
    frames = period_frames if cue['loop'] else period_frames + round(tail * RATE)
    mix = np.zeros((frames, 2), dtype=np.float64)
    report = {'engine': VERSION, 'cue': cue['id'], 'bpm': cue['bpm'], 'meter': cue.get('meter', [4, 4]),
              'loop': cue['loop'], 'target_lufs_metadata_only': cue.get('target_lufs'),
              'mastering': 'No normalization, limiter or reverb. Float32 stems include source region gain, track gain and pan.',
              'listening_review': False, 'tracks': []}
    stems = []
    for index, part in enumerate(cue['tracks']):
        audit = []
        source_info = []
        mapping_info = []
        data = render_track(cue, part, sampler, tail, audit, source_info, mapping_info)
        if len(data) != frames or not np.isfinite(data).all():
            raise RuntimeError(f'{cue["id"]}: invalid render shape/data')
        name = re.sub(r'[^a-zA-Z0-9_-]+', '_', part.get('name', part['instrument'])).strip('_') or part['instrument']
        relative = f'stems/{index + 1:02d}_{name}.wav'
        path = output / relative
        wavfile.write(path, RATE, data)
        mix += data
        stems.append((part.get('name', part['instrument']), relative))
        report['tracks'].append({'index': index, 'name': part.get('name', part['instrument']),
                                 'instrument': part['instrument'], 'actual': manifest['instruments'][part['instrument']].get('actual_name'),
                                 'note_count': len(part.get('notes', [])), 'audit': audit,
                                 'source_channel_selection': source_info,
                                 'local_mapping_overrides': mapping_info,
                                 'metrics': metrics(data), 'file': relative, 'sha256': sha256(path)})
    mixed = mix.astype(np.float32)
    wavfile.write(output / 'mix.wav', RATE, mixed)
    write_midi(cue, output / 'score.mid')
    write_rpp(cue, stems, output / (cue['id'] + '.rpp'), frames / RATE)
    (output / 'score.json').write_text(json.dumps(cue, ensure_ascii=False, indent=2) + '\n')
    report['mix'] = metrics(mixed) | {'file': 'mix.wav', 'sha256': sha256(output / 'mix.wav')}
    report['manifest_sha256'] = hashlib.sha256(json.dumps(manifest, sort_keys=True).encode()).hexdigest()
    report['source_commits'] = {key: value.get('commit', value.get('archive_sha256')) for key, value in manifest['sources'].items()}
    report['midi_sha256'] = sha256(output / 'score.mid')
    report['source_channel_policy'] = {'threshold_db': CHANNEL_SELECTION_THRESHOLD_DB,
                                      'operation': 'RMS stronger original channel duplicated only below threshold; otherwise native stereo'}
    (output / 'render-report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('cues', nargs='*')
    parser.add_argument('--score', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--cache', type=Path, default=DEFAULT_CACHE)
    parser.add_argument('--manifest', type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument('--tail', type=float, default=3)
    parser.add_argument('--fetch', action='store_true')
    args = parser.parse_args()
    if not finite(args.tail) or args.tail < .05 or args.tail > 30:
        parser.error('--tail must be .05..30 seconds')
    manifest = load_manifest(args.manifest)
    cues = json.loads(args.score.read_text())
    cues = cues if isinstance(cues, list) else [cues]
    ids = [cue['id'] for cue in cues]
    if len(ids) != len(set(ids)) or set(args.cues) - set(ids):
        parser.error('Duplicate/unknown cue ids')
    cues = [cue for cue in cues if not args.cues or cue['id'] in args.cues]
    for cue in cues:
        validate_cue(cue, manifest)
    if args.fetch:
        names = sorted({part['instrument'] for cue in cues for part in cue['tracks']})
        fetch(manifest, args.cache, names, file_keys=required_score_files(cues, manifest))
    sampler = Sampler(manifest, args.cache)
    for cue in cues:
        report = render_cue(cue, args.output, args.cache, manifest, args.tail, sampler)
        print(json.dumps({'cue': cue['id'], 'output': str(args.output / cue['id']), 'mix': report['mix'],
                          'audit_events': sum(len(track['audit']) for track in report['tracks'])}, ensure_ascii=False), flush=True)
    return 0


if __name__ == '__main__':
    sys.exit(main())

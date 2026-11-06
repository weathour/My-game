#!/usr/bin/env python3
"""Build source-auditable D1/D2 orchestration plans; never edit frozen inputs."""
from __future__ import annotations

import bisect
import argparse
import collections
import copy
import hashlib
import json
from pathlib import Path
import shutil

import mido

ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT / 'design/music-20261104-chinese-12'
ACCEPTED = ROOT / 'design/music-20261104-chinese-trial'
OLD = ROOT / 'design/music-20261103-midi-test'
PITCH_NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
PENT = (0, 2, 4, 7, 9)
MODES = {'gong': 0, 'shang': 2, 'zhi': 7, 'yu': 9}
REGISTERS = {'pipa': (53, 95), 'ruan': (46, 83), 'zheng': (54, 81), 'erhu': (62, 88)}
NEW_INDICES = (2, 3, 5, 6, 7, 9, 10, 11, 12)
REUSED_INDICES = (1, 4, 8)
POLICIES = {
    2: {'short_max_s': .65, 'bow_min_s': .6, 'guitar_transfer_cap': .42, 'color': 'low_ruan_pulse_with_pipa_upper_accents_and_sparse_erhu'},
    3: {'short_max_s': .5, 'bow_min_s': .42, 'guitar_transfer_cap': .42, 'color': 'articulated_upper_pipa_ruan_preserving_clean_guitar_body'},
    5: {'short_max_s': .65, 'bow_min_s': .55, 'guitar_transfer_cap': .42, 'color': 'existing_aux_to_zheng_erhu_plus_selected_upper_guitar_plucks'},
    6: {'short_max_s': .55, 'bow_min_s': .65, 'guitar_transfer_cap': .42, 'color': 'pipa_ruan_attacks_and_sparse_long_erhu_above_retained_riff'},
    7: {'short_max_s': .55, 'bow_min_s': .7, 'guitar_transfer_cap': .38, 'color': 'ruan_upper_pulse_preserving_low_chromatic_guitar_riff'},
    9: {'short_max_s': .55, 'bow_min_s': .6, 'guitar_transfer_cap': .42, 'color': 'high_pipa_and_nonoverlapping_erhu_with_full_bass_and_guitar_foundation'},
    10: {'short_max_s': .6, 'bow_min_s': .65, 'guitar_transfer_cap': .42, 'color': 'clean_and_distorted_upper_guitar_colors_register_checked_without_octave_folding'},
    11: {'short_max_s': .65, 'bow_min_s': .65, 'guitar_transfer_cap': .42, 'color': 'long_erhu_upper_line_and_spaced_pipa_over_original_bass'},
    12: {'short_max_s': .55, 'bow_min_s': .65, 'guitar_transfer_cap': .42, 'color': 'pipa_ruan_attack_pattern_and_rare_long_erhu_accents'},
}
REGION_DATA = json.loads((ACCEPTED / 'sources/dsk-regions.json').read_text())
SAMPLE_DATA = {s['id']: s for s in REGION_DATA['samples']}
PATCH_IDS = {'pipa': 'pipa', 'ruan': 'luan', 'zheng': 'guzhen', 'erhu': 'erhu'}
PATCH_DATA = {family: next(p for p in REGION_DATA['patches'] if p['id'] == pid) for family, pid in PATCH_IDS.items()}


def sample_zone(family, pitch, velocity):
    rows = []
    for r in PATCH_DATA[family]['regions']:
        if r['key_low'] <= pitch <= r['key_high'] and r['velocity_low'] <= velocity <= r['velocity_high']:
            root = r.get('root_override')
            if root is None:
                root = SAMPLE_DATA[r['sample_id']]['root']
            rows.append({'sample_id': r['sample_id'], 'root': root, 'semitone_shift': pitch - root})
    return rows


def playable(family, pitch, velocity=100):
    lo, hi = REGISTERS[family]
    zones = sample_zone(family, pitch, velocity)
    return lo <= pitch <= hi and bool(zones) and all(abs(z['semitone_shift']) <= 4 for z in zones)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def dump(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')


def decode(path):
    mf = mido.MidiFile(path)
    ticks = 0
    prev = 0
    seconds = 0.0
    tempo = 500000
    tempo_rows = [(0, 0.0, tempo)]
    tempo_map, meter_map = [], []
    for msg in mido.merge_tracks(mf.tracks):
        ticks += msg.time
        seconds += (ticks - prev) * tempo / 1e6 / mf.ticks_per_beat
        prev = ticks
        if msg.type == 'set_tempo':
            tempo = msg.tempo
            if tempo_rows[-1][0] == ticks:
                tempo_rows[-1] = (ticks, seconds, tempo)
            else:
                tempo_rows.append((ticks, seconds, tempo))
            tempo_map.append({'tick': ticks, 'microseconds_per_beat': tempo})
        elif msg.type == 'time_signature':
            meter_map.append({'tick': ticks, **{k: v for k, v in msg.dict().items() if k not in ('type', 'time')}})
    row_ticks = [r[0] for r in tempo_rows]

    def to_s(t):
        tick, sec, tmp = tempo_rows[bisect.bisect_right(row_ticks, t) - 1]
        return sec + (t - tick) * tmp / 1e6 / mf.ticks_per_beat

    events = []
    issues = []
    for ti, track in enumerate(mf.tracks):
        active = collections.defaultdict(collections.deque)
        ticks = 0
        for mi, msg in enumerate(track):
            ticks += msg.time
            if msg.type == 'note_on' and msg.velocity > 0:
                active[(msg.channel, msg.note)].append((ticks, mi, msg.velocity))
            elif msg.type == 'note_off' or (msg.type == 'note_on' and msg.velocity == 0):
                queue = active[(msg.channel, msg.note)]
                if not queue:
                    issues.append({'unmatched_off': [ti, mi]})
                    continue
                start, on_index, velocity = queue.popleft()
                sid = f't{ti:02d}-c{msg.channel:02d}-on{on_index:06d}-s{start}-e{ticks}-p{msg.note}'
                events.append({'source_id': sid, 'source_track': ti, 'source_channel': msg.channel,
                               'channel': msg.channel, 'source_note_on_index': on_index,
                               'source_note_off_index': mi, 'start_tick': start, 'end_tick': ticks,
                               'start_s': to_s(start), 'end_s': to_s(ticks),
                               'duration_s': to_s(ticks) - to_s(start), 'velocity': velocity,
                               'source_pitch': msg.note, 'pitch': msg.note,
                               'source_note_off_type': msg.type, 'source_note_off_velocity': msg.velocity})
        if any(active.values()):
            issues.append({'unclosed_on': [ti, sum(map(len, active.values()))]})
    assert not issues, issues
    events.sort(key=lambda n: (n['source_track'], n['source_note_on_index']))
    return mf, events, seconds, tempo_map, meter_map


def overlap(a, b):
    return a['start_tick'] < b['end_tick'] and b['start_tick'] < a['end_tick']


def pluck_family(pitch, piano=False):
    if piano and 54 <= pitch <= 81:
        return 'zheng'
    return 'ruan' if pitch < 57 else 'pipa'


def orchestrate(index, events, source_report):
    assert index in NEW_INDICES, 'Accepted first-round arrangements must never be rebuilt.'
    policy = POLICIES[index]
    by_track = {t['track_index']: t for t in source_report['pitched_tracks']}
    for n in events:
        sr = 'drums' if n['channel'] == 9 else by_track[n['source_track']]['role']
        n['source_track_name'] = 'drums' if sr == 'drums' else by_track[n['source_track']]['source_track_name']
        n['source_role'] = sr
        n['role'] = sr
        n['instrument_family'] = {'guitar': 'electric_guitar', 'aux': 'pad'}.get(sr, sr)
        n['preferred_families'] = [n['instrument_family']]
        n['orchestration_reason'] = 'source_role_retained'
    guitar = [n for n in events if n['source_role'] == 'guitar']
    groups = collections.defaultdict(list)
    for n in guitar:
        groups[(n['source_track'], n['start_tick'])].append(n)
    tops = [max(g, key=lambda n: (n['pitch'], n['duration_s'])) for g in groups.values()]
    # A single global erhu line takes source events, never adds or extends a note.
    # Existing long auxiliary notes take priority in 05; the guitar melody otherwise
    # provides the same long upper-note source used to choose the plucked register.
    aux = [n for n in events if n['source_role'] == 'aux']
    bowed_candidates = [n for n in tops if n['duration_s'] >= policy['bow_min_s'] and playable('erhu', n['pitch'], n['velocity'])]
    if index == 5:
        bowed_candidates += [n for n in aux if n['duration_s'] >= .45 and playable('erhu', n['pitch'], n['velocity'])]
    bowed_candidates.sort(key=lambda n: (n['start_tick'], 0 if n['source_role'] == 'aux' else 1, -n['pitch'], -n['duration_s'], n['source_track']))
    erhu_end = -1
    selected_guitar = []
    for n in bowed_candidates:
        if n['start_tick'] < erhu_end:
            continue
        n['role'] = 'bowed_lead'
        n['instrument_family'] = 'erhu'
        n['preferred_families'] = ['erhu']
        n['orchestration_reason'] = 'nonoverlapping_long_upper_' + n['source_role'] + '_source_note'
        erhu_end = n['end_tick']
        if n['source_role'] == 'guitar':
            selected_guitar.append(n)
    if index == 5:
        for n in aux:
            if n['role'] == 'bowed_lead':
                continue
            if playable('zheng', n['pitch'], n['velocity']):
                family = 'zheng'
            elif playable('pipa', n['pitch'], n['velocity']):
                family = 'pipa'
            else:
                continue
            n['role'] = 'plucked'
            n['instrument_family'] = family
            n['preferred_families'] = [family]
            n['orchestration_reason'] = 'existing_auxiliary_note_to_recorded_chinese_pluck'
    isolated_serial = collections.Counter()
    for n in sorted(tops, key=lambda n: (n['start_tick'], n['source_track'])):
        if n['role'] != 'guitar' or n['duration_s'] > policy['short_max_s']:
            continue
        family = pluck_family(n['pitch'])
        if not playable(family, n['pitch'], n['velocity']):
            continue
        group = groups[(n['source_track'], n['start_tick'])]
        if len(group) == 1:
            isolated_serial[n['source_track']] += 1
            if isolated_serial[n['source_track']] % 2 == 0:
                continue
        n['role'] = 'plucked'
        n['instrument_family'] = family
        n['preferred_families'] = [family]
        n['orchestration_reason'] = 'short_upper_guitar_chord_note' if len(group) > 1 else 'alternating_isolated_upper_guitar_note'
        selected_guitar.append(n)
    # Preserve the heavy guitar foundation. If a sparse source has many isolated
    # upper notes, remove transfers evenly across the timeline rather than ending
    # the Chinese color halfway through the piece.
    cap = int(len(guitar) * policy['guitar_transfer_cap'])
    if len(selected_guitar) > cap:
        bowed_guitar = [n for n in selected_guitar if n['role'] == 'bowed_lead']
        plucked_guitar = sorted((n for n in selected_guitar if n['role'] == 'plucked'), key=lambda n: (n['start_tick'], n['source_track']))
        slots = max(0, cap - len(bowed_guitar))
        keep = {int(j * len(plucked_guitar) / slots) for j in range(slots)} if slots else set()
        for j, n in enumerate(plucked_guitar):
            if j not in keep:
                n['role'] = 'guitar'
                n['instrument_family'] = 'electric_guitar'
                n['preferred_families'] = ['electric_guitar']
                n['orchestration_reason'] = 'guitar_weight_transfer_cap_retained'
    for n in events:
        if n['instrument_family'] in REGISTERS:
            assert playable(n['instrument_family'], n['pitch'], n['velocity']), n
            n['D1_sf2_sample_zones'] = sample_zone(n['instrument_family'], n['pitch'], n['velocity'])
    assert sum(n['role'] == 'guitar' for n in guitar) >= len(guitar) * .55


def profile(notes):
    counts, durations = [0] * 12, [0.] * 12
    for n in notes:
        counts[n['pitch'] % 12] += 1
        durations[n['pitch'] % 12] += n['duration_s']
    return counts, durations


def norm(hist, pc):
    return hist[pc] / sum(hist) if sum(hist) else 0.0


def candidates_for_segment(notes, tpq, previous=None):
    pitched = [n for n in notes if n['channel'] != 9]
    count, duration = profile(pitched)
    _, bass = profile([n for n in pitched if n['source_role'] == 'bass'])
    _, long = profile([n for n in pitched if n['duration_s'] >= .4])
    # Quarter-note proximity is an explicit timing proxy, not reconstructed metric accent.
    _, accent = profile([n for n in pitched if min(n['start_tick'] % tpq, tpq - n['start_tick'] % tpq) <= tpq / 12])
    by_track = collections.defaultdict(list)
    for n in pitched:
        by_track[n['source_track']].append(n)
    endings = []
    for stream in by_track.values():
        stream.sort(key=lambda n: n['start_tick'])
        for j, n in enumerate(stream):
            if j == len(stream) - 1 or stream[j + 1]['start_s'] - n['end_s'] >= .35:
                endings.append(n)
    _, ending = profile(endings)
    rows = []
    for anchor in range(12):
        pcs = sorted((anchor + x) % 12 for x in PENT)
        nc = sum(count[p] for p in pcs) / sum(count) if sum(count) else 0
        dc = sum(duration[p] for p in pcs) / sum(duration) if sum(duration) else 0
        for mode, offset in MODES.items():
            center = (anchor + offset) % 12
            components = {'duration_coverage': dc, 'count_coverage': nc,
                          'bass_center_support': norm(bass, center), 'long_center_support': norm(long, center),
                          'quarter_onset_center_support': norm(accent, center), 'gap_ending_center_support': norm(ending, center)}
            score = .55 * dc + .15 * nc + .12 * components['bass_center_support'] + .08 * components['long_center_support'] + .04 * components['quarter_onset_center_support'] + .06 * components['gap_ending_center_support']
            continuity = 0.0
            if previous:
                continuity += .045 if anchor != previous['set_anchor_pc'] else 0
                continuity += .025 if center != previous['target_center_pc'] else 0
            rows.append({'set_anchor_pc': anchor, 'pitch_class_numbers': pcs,
                         'pitch_classes': [PITCH_NAMES[p] for p in pcs], 'target_mode': mode,
                         'target_center_pc': center, 'target_center': PITCH_NAMES[center],
                         'components': components, 'raw_score': score,
                         'continuity_penalty': continuity, 'score': score - continuity})
    return sorted(rows, key=lambda r: (-r['score'], r['set_anchor_pc'], r['target_mode']))


def build_sections(index, events, duration, tpq):
    if index in (1, 4):
        return [{'section_id': 's00', 'start_s': 0., 'end_s': duration,
                 'pitch_class_numbers': [0, 2, 5, 7, 9], 'pitch_classes': ['C', 'D', 'F', 'G', 'A'],
                 'set_anchor_pc': 5, 'target_center': None, 'target_center_pc': None, 'target_mode': None,
                 'selection_rule': 'fixed_low_change_collection_for_04' if index == 4 else 'upper_color_only_collection_original_chromatic_riff_exempt',
                 'modal_claim': 'arrangement_target_collection_only; original tonic/mode not inferred'}]
    # Bounded analysis windows merge when their selected target is identical. These are
    # machine arrangement blocks, never asserted to be the original song's formal sections.
    windows = []
    previous = None
    start = 0.
    while start < duration:
        end = min(duration, start + 30.)
        ns = [n for n in events if start <= n['start_s'] < end]
        ranked = candidates_for_segment(ns, tpq, previous)
        chosen = ranked[0]
        windows.append({'start_s': start, 'end_s': end, 'chosen': chosen, 'candidate_scores': ranked})
        previous = chosen
        start = end
    sections = []
    for w in windows:
        z = w['chosen']
        if sections and sections[-1]['set_anchor_pc'] == z['set_anchor_pc'] and sections[-1]['target_center_pc'] == z['target_center_pc']:
            sections[-1]['end_s'] = w['end_s']
            sections[-1]['diagnostic_windows'].append(w)
        else:
            sections.append({'section_id': f's{len(sections):02d}', 'start_s': w['start_s'], 'end_s': w['end_s'],
                             **{k: z[k] for k in ('set_anchor_pc', 'pitch_class_numbers', 'pitch_classes', 'target_center_pc', 'target_center', 'target_mode')},
                             'selection_rule': '30s_blocks_scored_by_collection_bass_long_quarter_onset_gap_ending_with_continuity_penalty',
                             'modal_claim': 'chosen_arrangement_target; automatic_transcription_does_not_establish_original_mode',
                             'diagnostic_windows': [w]})
    return sections


def map_d2(index, d1, sections, tpq):
    events = copy.deepcopy(d1)
    by_id = {n['source_id']: n for n in events}
    by_start = collections.defaultdict(list)
    by_track = collections.defaultdict(list)
    for n in events:
        by_start[n['start_tick']].append(n)
        by_track[(n['source_track'], n['channel'])].append(n)
    ordered = sorted(events, key=lambda n: (n['start_tick'], n['source_track'], n['source_note_on_index']))
    previous_by_family = {}
    failures = collections.Counter()
    for n in ordered:
        sec = next(s for s in sections if s['start_s'] <= n['start_s'] < s['end_s'] or (n['start_s'] == s['end_s'] == sections[-1]['end_s']))
        n['section_id'] = sec['section_id']
        n['mapping_reason'] = 'source_pitch_retained'
        n['mapping_semitones'] = 0
        if n['role'] not in ('plucked', 'bowed_lead'):
            n['mapping_reason'] = 'protected_original_riff_bass_harmony_or_drums'
            continue
        accompaniment = [x for x in events if x['role'] in ('guitar', 'piano', 'bass') and overlap(n, x)]
        original_semitone_ids = [x['source_id'] for x in accompaniment if (n['source_pitch'] - x['source_pitch']) % 12 in (1, 11)]
        n['retained_accompaniment_semitone_conflicts_before'] = original_semitone_ids
        n['retained_accompaniment_semitone_conflicts_after'] = original_semitone_ids
        pcs = sec['pitch_class_numbers']
        if n['pitch'] % 12 in pcs:
            n['mapping_reason'] = 'already_in_target_collection'
            previous_by_family[(n['instrument_family'], -1 if n['instrument_family'] == 'erhu' else n['source_track'])] = n
            continue
        # Short passing notes are retained except in the near-pentatonic 04 control.
        on_quarter = min(n['start_tick'] % tpq, tpq - n['start_tick'] % tpq) <= tpq / 12
        if n['duration_s'] < .18 and not on_quarter:
            n['mapping_reason'] = 'short_unaccented_passing_tone_exempt'
            continue
        # All changes remain within the exact original octave neighbourhood (+/- 1).
        possible = [n['source_pitch'] + d for d in (-1, 1) if (n['source_pitch'] + d) % 12 in pcs]
        lo, hi = REGISTERS[n['instrument_family']]
        possible = [p for p in possible if playable(n['instrument_family'], p, n['velocity'])]
        segment_notes = [x for x in d1 if sec['start_s'] <= x['start_s'] < sec['end_s'] and x['channel'] != 9]
        _, dh = profile(segment_notes)
        center = sec['target_center_pc']
        possible.sort(key=lambda p: (0 if center is not None and p % 12 == center else 1, -dh[p % 12], abs(p - n['source_pitch']), p))
        selected = None
        reason = 'nearest_target_backbone_pitch'
        for target in possible:
            new_semitones = [x for x in accompaniment if (target - x['source_pitch']) % 12 in (1, 11) and (n['source_pitch'] - x['source_pitch']) % 12 not in (1, 11)]
            if new_semitones:
                failures['new_semitone_against_retained_accompaniment_prevented'] += 1
                continue
            peers = by_track[(n['source_track'], n['channel'])]
            if any(x is not n and overlap(n, x) and x['pitch'] == target for x in peers):
                failures['target_same_pitch_overlap_prevented'] += 1
                continue
            strong_skeleton = [x for x in accompaniment if abs(x['start_tick'] - n['start_tick']) <= tpq / 12 and x['duration_s'] >= .25 and (n['source_pitch'] - x['source_pitch']) % 12 in (0, 5, 7)]
            if any((target - x['source_pitch']) % 12 != (n['source_pitch'] - x['source_pitch']) % 12 for x in strong_skeleton):
                failures['retained_octave_or_fifth_skeleton'] += 1
                continue
            stream_key = (n['instrument_family'], -1 if n['instrument_family'] == 'erhu' else n['source_track'])
            prev = previous_by_family.get(stream_key)
            if prev and prev['section_id'] == n['section_id']:
                source_delta = n['source_pitch'] - prev['source_pitch']
                output_delta = target - prev['pitch']
                if source_delta * output_delta < 0:
                    failures['melodic_direction_reversal_prevented'] += 1
                    continue
            selected = target
            break
        if selected is not None:
            n['pitch'] = selected
            n['mapping_semitones'] = selected - n['source_pitch']
            n['mapping_reason'] = reason
            n['retained_accompaniment_semitone_conflicts_after'] = [x['source_id'] for x in accompaniment if (selected - x['source_pitch']) % 12 in (1, 11)]
        else:
            n['mapping_reason'] = 'target_collision_register_contour_or_fifth_skeleton_exempt'
        previous_by_family[(n['instrument_family'], -1 if n['instrument_family'] == 'erhu' else n['source_track'])] = n
    return events, dict(failures)


def event_pairs(events):
    return collections.Counter((n['source_track'], n['channel'], n['start_tick'], n['end_tick'], n['pitch'], n['velocity']) for n in events)


def message_signature(mf, omit_pitch=False):
    rows = []
    for ti, track in enumerate(mf.tracks):
        tick = 0
        for mi, msg in enumerate(track):
            tick += msg.time
            d = msg.dict()
            if omit_pitch and msg.type in ('note_on', 'note_off'):
                d.pop('note', None)
            rows.append((ti, mi, tick, json.dumps(d, sort_keys=True)))
    return rows


def mapped_midi(source_mf, events):
    out = copy.deepcopy(source_mf)
    for n in events:
        for mi in (n['source_note_on_index'], n['source_note_off_index']):
            out.tracks[n['source_track']][mi].note = n['pitch']
    return out


def audit_plan(d1, d2):
    erhu = sorted((n for n in d1 if n['instrument_family'] == 'erhu'), key=lambda n: n['start_tick'])
    assert all(a['end_tick'] <= b['start_tick'] for a, b in zip(erhu, erhu[1:]))
    assert all(n['channel'] == 9 and n['pitch'] == n['source_pitch'] for n in d2 if n['source_role'] == 'drums')
    assert [n['source_id'] for n in d1] == [n['source_id'] for n in d2]
    assignment = ('role', 'instrument_family', 'preferred_families', 'orchestration_reason')
    assert all(all(a[k] == b[k] for k in assignment) for a, b in zip(d1, d2))
    changes = [n for n in d2 if n['pitch'] != n['source_pitch']]
    assert changes
    assert all(set(n.get('retained_accompaniment_semitone_conflicts_after', [])) <= set(n.get('retained_accompaniment_semitone_conflicts_before', [])) for n in d2)
    per_family = {}
    for family in sorted({n['instrument_family'] for n in d2}):
        ns = [n for n in d2 if n['instrument_family'] == family]
        changed = [n for n in ns if n['pitch'] != n['source_pitch']]
        per_family[family] = {'note_count': len(ns), 'changed_note_count': len(changed),
                              'source_pitch_range': [min(n['source_pitch'] for n in ns), max(n['source_pitch'] for n in ns)],
                              'output_pitch_range': [min(n['pitch'] for n in ns), max(n['pitch'] for n in ns)],
                              'source_pitch_classes': sorted({n['source_pitch'] % 12 for n in ns}),
                              'output_pitch_classes': sorted({n['pitch'] % 12 for n in ns}),
                              'changed_duration_seconds': sum(n['duration_s'] for n in changed)}
    direction_reversals, collapsed_steps = [], []
    repeated = collections.defaultdict(set)
    for family in REGISTERS:
        stream = sorted((n for n in d2 if n['instrument_family'] == family), key=lambda n: (n['start_tick'], n['source_track'], n['source_note_on_index']))
        for a, b in zip(stream, stream[1:]):
            if a['start_tick'] == b['start_tick'] or a['section_id'] != b['section_id']:
                continue
            sd, od = b['source_pitch'] - a['source_pitch'], b['pitch'] - a['pitch']
            if sd * od < 0:
                direction_reversals.append([a['source_id'], b['source_id'], sd, od])
            if sd and not od:
                collapsed_steps.append([a['source_id'], b['source_id'], sd])
        for n in stream:
            repeated[(family, n['section_id'], n['source_pitch'])].add(n['pitch'])
    return {'event_count': len(d1), 'changed_note_count': len(changes),
            'changed_note_fraction_all_events': len(changes) / len(d1),
            'changed_note_fraction_pitched_events': len(changes) / sum(n['channel'] != 9 for n in d1),
            'mapping_delta_counts': dict(collections.Counter(str(n['mapping_semitones']) for n in d2)),
            'mapping_reason_counts': dict(collections.Counter(n['mapping_reason'] for n in d2)),
            'per_instrument_family': per_family, 'erhu_note_count': len(erhu), 'erhu_no_overlap': True,
            'd1_d2_assignment_identical': True, 'drum_pitch_and_channel_unchanged': True,
            'no_new_semitone_conflicts_against_retained_accompaniment': True,
            'changed_notes_with_preexisting_semitone_conflicts': sum(bool(n.get('retained_accompaniment_semitone_conflicts_before')) for n in changes),
            'changed_source_ids': [n['source_id'] for n in changes],
            'adjacent_stream_direction_reversals': direction_reversals,
            'adjacent_stream_collapsed_steps': collapsed_steps,
            'source_repeated_pitch_with_multiple_outputs': [{'family': k[0], 'section_id': k[1], 'source_pitch': k[2], 'outputs': sorted(v)} for k, v in repeated.items() if len(v) > 1],
            'stream_warning': 'Adjacency in a polyphonic plucked event stream is diagnostic, not verified melodic voice leading.'}


def run(index):
    assert index in NEW_INDICES, 'Refusing to rebuild accepted 01/04/08.'
    cue = f'midi_test_{index:02d}'
    source = OLD / 'inputs' / f'{cue}.mid'
    frozen_hash = sha(source)
    report = json.loads((OLD / 'reports' / f'{cue}.json').read_text())
    assert frozen_hash == report['source_sha256_copy']
    mf, events, duration, tempos, meters = decode(source)
    assert len(events) == report['source_note_count_expected']
    orchestrate(index, events, report)
    sections = build_sections(index, events, duration, mf.ticks_per_beat)
    d2, mapping_preventions = map_d2(index, events, sections, mf.ticks_per_beat)
    for n in events:
        n['section_id'] = next(s['section_id'] for s in sections if s['start_s'] <= n['start_s'] < s['end_s'])
        n['mapping_reason'] = 'D1_exact_source_pitch'
        n['mapping_semitones'] = 0
    stats = audit_plan(events, d2)
    assert all(playable(n['instrument_family'], n['pitch'], n['velocity']) for n in d2 if n['instrument_family'] in REGISTERS)
    dest = BASE / 'arrangements' / cue
    dest.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, dest / 'D1.mid')
    mapped_midi(mf, d2).save(dest / 'D2.mid')
    for variant, ns in (('D1', events), ('D2', d2)):
        plan = {'schema_version': 1, 'cue_id': cue, 'title': report['title'], 'variant': variant,
                'source_midi': str(source), 'source_sha256': frozen_hash, 'derived_midi': str(dest / f'{variant}.mid'),
                'derived_sha256': sha(dest / f'{variant}.mid'), 'ticks_per_beat': mf.ticks_per_beat,
                'duration_seconds': duration, 'tempo_map': tempos, 'meter_map': meters,
                'sections': sections, 'instrument_registers_midi': REGISTERS,
                'orchestration_policy': POLICIES[index],
                'sample_region_source': str(ACCEPTED / 'sources/dsk-regions.json'),
                'sample_region_source_sha256': sha(ACCEPTED / 'sources/dsk-regions.json'),
                'max_allowed_actual_sample_transposition_semitones': 4,
                'rules': {'source_event_identity': 'source track/channel, source note-on message index, start/end tick, source pitch',
                          'D1': 'exact source pitch/time/velocity/events; original MIDI byte copy; timbre assignment is in plan only',
                          'D2': 'local melodic-backbone modalization only: same orchestration as D1; selected Chinese-timbre backbone notes may move +/-1 semitone; no octave displacement; not whole-song pentatonic conversion',
                          'protected': 'all drums and bass, retained guitar/piano/aux; source note identities and timing; near-simultaneous retained octave/fifth skeleton within 1/12 quarter note; no newly introduced semitone class against any overlapping retained guitar/piano/bass note',
                          'mode_caveat': 'Target collection/mode labels are arrangement decisions, not established original tonality or a claim of Chinese musical authenticity',
                          'aux_source_caveat': 'Automatic transcription and existing role classifications remain uncorrected',
                          'render': 'Use events and instrument_family; source MIDI channels do not encode the split timbres'},
                'events': ns}
        dump(dest / f'plan-{variant}.json', plan)
    d1mf, d1notes, d1duration, d1tempo, d1meter = decode(dest / 'D1.mid')
    d2mf, d2notes, d2duration, d2tempo, d2meter = decode(dest / 'D2.mid')
    checks = {'frozen_source_sha_unchanged': sha(source) == frozen_hash,
              'source_sha_matches_existing_report': frozen_hash == report['source_sha256_copy'],
              'source_note_count_matches_existing_report': len(events) == report['source_note_count_expected'],
              'D1_byte_identical_to_source': sha(dest / 'D1.mid') == frozen_hash,
              'D1_all_messages_exact': message_signature(mf) == message_signature(d1mf),
              'D1_note_pairs_exact': event_pairs(events) == event_pairs(d1notes),
              'D2_all_nonpitch_message_fields_exact': message_signature(mf, True) == message_signature(d2mf, True),
              'D2_note_pairs_match_plan': event_pairs(d2) == event_pairs(d2notes),
              'all_note_counts_exact': len(events) == len(d1notes) == len(d2notes),
              'tempo_and_meter_exact': tempos == d1tempo == d2tempo and meters == d1meter == d2meter,
              'duration_exact': duration == d1duration == d2duration,
              'drum_event_pairs_exact': event_pairs([n for n in events if n['channel'] == 9]) == event_pairs([n for n in d2notes if n['channel'] == 9]),
              'D2_has_bounded_pitch_changes': bool(stats['changed_note_count']) and all(abs(n['pitch'] - n['source_pitch']) <= 1 for n in d2),
              'D1_D2_same_timbre_assignments': stats['d1_d2_assignment_identical'],
              'erhu_has_no_overlapping_keydowns': stats['erhu_no_overlap'],
              'actual_SF2_zone_transposition_at_most_four_semitones': all(playable(n['instrument_family'], n['pitch'], n['velocity']) for n in events + d2 if n['instrument_family'] in REGISTERS),
              'retained_guitar_notes_at_least_55_percent': sum(n['role'] == 'guitar' for n in events) >= .55 * sum(n['source_role'] == 'guitar' for n in events),
              'bass_note_pairs_and_pitch_exact': all(n['source_pitch'] == n['pitch'] and n['role'] == 'bass' for n in d2 if n['source_role'] == 'bass'),
              'no_new_semitone_against_retained_accompaniment': stats['no_new_semitone_conflicts_against_retained_accompaniment']}
    assert all(checks.values()), checks
    result = {'schema_version': 1, 'cue_id': cue, 'title': report['title'], 'status': 'PASS',
              'source_midi': str(source), 'source_sha256': frozen_hash,
              'D1_midi': str(dest / 'D1.mid'), 'D2_midi': str(dest / 'D2.mid'),
              'checks': checks, 'mapping_preventions': mapping_preventions, 'statistics': stats,
              'orchestration_policy': POLICIES[index],
              'sections': sections,
              'acceptance_limit': 'Structural/event audit only. These candidates require audio rendering and listening; target collection scores are not music-quality scores.'}
    dump(BASE / 'reports' / f'midi-{cue}.json', result)
    print(cue, report['title'], 'PASS', 'notes', len(events), 'changed', stats['changed_note_count'], 'family counts', {k: v['note_count'] for k, v in stats['per_instrument_family'].items()})


def verify_all():
    """Independent source decoder and direct message/interval audit of all 12."""
    import importlib.util
    spec = importlib.util.spec_from_file_location('original_production_parser', OLD / 'tools/render_non_drum_stems.py')
    production = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(production)
    results = []
    total_notes = total_pitched = total_drums = 0
    for index in range(1, 13):
        cue = f'midi_test_{index:02d}'
        dest = BASE / 'arrangements' / cue
        source = OLD / 'inputs' / f'{cue}.mid'
        source_report = json.loads((OLD / 'reports' / f'{cue}.json').read_text())
        plans = {v: json.loads((dest / f'plan-{v}.json').read_text()) for v in ('D1', 'D2')}
        d1, d2 = plans['D1']['events'], plans['D2']['events']
        smf, source_tracks, source_duration, end_tick = production.parse_midi(source)
        source_notes = [(t['index'], n) for t in source_tracks for n in t['notes']]
        old_keys = collections.Counter((ti, n['channel'], n['start_tick'], n['end_tick'], n['pitch'], n['velocity']) for ti, n in source_notes)
        declared_source = collections.Counter((n['source_track'], n['channel'], n['start_tick'], n['end_tick'], n['source_pitch'], n['velocity']) for n in d2)
        source_seconds = {(ti, n['channel'], n['start_tick'], n['end_tick'], n['pitch']): (n['start_s'], n['end_s']) for ti, n in source_notes}
        max_seconds_error = max(max(abs(n['start_s'] - source_seconds[(n['source_track'], n['channel'], n['start_tick'], n['end_tick'], n['source_pitch'])][0]), abs(n['end_s'] - source_seconds[(n['source_track'], n['channel'], n['start_tick'], n['end_tick'], n['source_pitch'])][1])) for n in d2)
        d1mf = mido.MidiFile(dest / 'D1.mid')
        d2mf, d2tracks, derived_duration, derived_end_tick = production.parse_midi(dest / 'D2.mid')
        derived_pairs = collections.Counter((t['index'], n['channel'], n['start_tick'], n['end_tick'], n['pitch'], n['velocity']) for t in d2tracks for n in t['notes'])
        planned_pairs = collections.Counter((n['source_track'], n['channel'], n['start_tick'], n['end_tick'], n['pitch'], n['velocity']) for n in d2)
        changed = [n for n in d2 if n['source_pitch'] != n['pitch']]
        changed_messages = []
        message_fields_exact = len(smf.tracks) == len(d2mf.tracks)
        for ti, (st, dt) in enumerate(zip(smf.tracks, d2mf.tracks)):
            message_fields_exact &= len(st) == len(dt)
            for mi, (s, d) in enumerate(zip(st, dt)):
                sd, dd = s.dict(), d.dict()
                if sd == dd:
                    continue
                if s.type not in ('note_on', 'note_off') or d.type != s.type:
                    message_fields_exact = False
                    continue
                sp, dp = sd.pop('note'), dd.pop('note')
                message_fields_exact &= sd == dd and abs(sp - dp) == 1
                changed_messages.append((ti, mi))
        declared_changes = sorted((n['source_track'], mi) for n in changed for mi in (n['source_note_on_index'], n['source_note_off_index']))
        ids_exact = True
        absolute_ticks = []
        all_on_indices = set()
        for ti, tr in enumerate(smf.tracks):
            tick = 0
            row = []
            for mi, msg in enumerate(tr):
                tick += msg.time
                row.append(tick)
                if msg.type == 'note_on' and msg.velocity > 0:
                    all_on_indices.add((ti, mi))
            absolute_ticks.append(row)
        for n in d2:
            ti, on, off = n['source_track'], n['source_note_on_index'], n['source_note_off_index']
            a, b = smf.tracks[ti][on], smf.tracks[ti][off]
            ids_exact &= a.type == 'note_on' and a.velocity == n['velocity'] and a.note == n['source_pitch'] and a.channel == n['source_channel'] == n['channel']
            ids_exact &= b.type in ('note_off', 'note_on') and (b.type == 'note_off' or b.velocity == 0) and b.note == n['source_pitch'] and b.channel == n['channel']
            ids_exact &= absolute_ticks[ti][on] == n['start_tick'] and absolute_ticks[ti][off] == n['end_tick']
            ids_exact &= n['source_id'] == f't{ti:02d}-c{n["channel"]:02d}-on{on:06d}-s{n["start_tick"]}-e{n["end_tick"]}-p{n["source_pitch"]}'
        ids_exact &= {(n['source_track'], n['source_note_on_index']) for n in d2} == all_on_indices
        ids_exact &= len({n['source_id'] for n in d2}) == len(d2)
        assignments_exact = [n['source_id'] for n in d1] == [n['source_id'] for n in d2] and all(all(a[k] == b[k] for k in ('role', 'instrument_family', 'preferred_families', 'orchestration_reason')) for a, b in zip(d1, d2))
        retained = [n for n in d2 if n['role'] in ('guitar', 'piano', 'bass')]
        new_semitones, broken_skeleton = [], []
        for n in changed:
            for accompaniment in retained:
                if not (n['start_tick'] < accompaniment['end_tick'] and accompaniment['start_tick'] < n['end_tick']):
                    continue
                before = (n['source_pitch'] - accompaniment['source_pitch']) % 12
                after = (n['pitch'] - accompaniment['pitch']) % 12
                if after in (1, 11) and before not in (1, 11):
                    new_semitones.append([n['source_id'], accompaniment['source_id']])
                # Accepted 01/04 keep their original, narrower protection contract.
                tolerance = smf.ticks_per_beat / 12 if index in NEW_INDICES else 0
                if (index in NEW_INDICES or index == 8) and abs(n['start_tick'] - accompaniment['start_tick']) <= tolerance and accompaniment['duration_s'] >= .25 and before in (0, 5, 7) and after != before:
                    broken_skeleton.append([n['source_id'], accompaniment['source_id']])
        erhu = sorted((n for n in d2 if n['instrument_family'] == 'erhu'), key=lambda n: n['start_tick'])
        sample_details = {}
        all_sample_zones_safe = True
        # Read raw SF2-region authority afresh rather than call generator playable().
        raw_regions = json.loads((ACCEPTED / 'sources/dsk-regions.json').read_text())
        samples = {s['id']: s for s in raw_regions['samples']}
        for variant, ev in (('D1', d1), ('D2', d2)):
            for family, pid in PATCH_IDS.items():
                patch = next(p for p in raw_regions['patches'] if p['id'] == pid)
                shifts, missing = [], []
                for n in ev:
                    if n['instrument_family'] != family:
                        continue
                    matches = [r for r in patch['regions'] if r['key_low'] <= n['pitch'] <= r['key_high'] and r['velocity_low'] <= n['velocity'] <= r['velocity_high']]
                    if not matches:
                        missing.append(n['source_id'])
                    for r in matches:
                        root = r.get('root_override')
                        if root is None:
                            root = samples[r['sample_id']]['root']
                        shifts.append(n['pitch'] - root)
                all_sample_zones_safe &= not missing and all(abs(s) <= 4 for s in shifts)
                if shifts or missing:
                    sample_details[f'{variant}:{family}'] = {'matched_zone_count': len(shifts), 'max_absolute_transposition_semitones': max(map(abs, shifts), default=0), 'missing_zone_source_ids': missing}
        source_hash = sha(source)
        reuse = {}
        if index in REUSED_INDICES:
            for name in ('D1.mid', 'D2.mid', 'plan-D1.json', 'plan-D2.json'):
                accepted_path = ACCEPTED / 'arrangements' / cue / name
                reuse[name] = {'accepted_path': str(accepted_path), 'accepted_sha256': sha(accepted_path), 'current_sha256': sha(dest / name), 'byte_identical': sha(accepted_path) == sha(dest / name)}
        checks = {
            'source_sha_matches_frozen_report_and_both_plans': source_hash == source_report['source_sha256_copy'] == plans['D1']['source_sha256'] == plans['D2']['source_sha256'],
            'original_note_pairs_and_count_exact': old_keys == declared_source and len(d2) == source_report['source_note_count_expected'],
            'stable_source_ids_and_raw_message_indices_exact_and_unique': bool(ids_exact),
            'D1_byte_identical_source': sha(dest / 'D1.mid') == source_hash,
            'D1_plan_pitch_exact_source': all(n['pitch'] == n['source_pitch'] for n in d1),
            'D1_D2_same_event_ids_and_orchestration': assignments_exact,
            'independent_global_seconds_match_within_1ns': max_seconds_error < 1e-9,
            'D2_only_declared_paired_note_pitch_messages_changed': bool(message_fields_exact) and sorted(changed_messages) == declared_changes,
            'D2_note_pairs_match_plan_with_independent_FIFO_parser': derived_pairs == planned_pairs,
            'end_tick_and_duration_unchanged': end_tick == derived_end_tick and abs(source_duration - derived_duration) < 1e-9,
            'D2_has_real_changes_bounded_by_one_semitone': bool(changed) and all(abs(n['pitch'] - n['source_pitch']) <= 1 for n in d2),
            'protected_bass_drums_and_retained_accompaniment_pitch_exact': all(n['pitch'] == n['source_pitch'] for n in d2 if n['source_role'] in ('bass', 'drums') or n['role'] not in ('plucked', 'bowed_lead')),
            'drums_keep_channel_9_and_source_pitch': all(n['channel'] == 9 and n['pitch'] == n['source_pitch'] for n in d2 if n['source_role'] == 'drums'),
            'erhu_single_keydown_line': all(a['end_tick'] <= b['start_tick'] for a, b in zip(erhu, erhu[1:])),
            'no_new_semitone_against_any_sustained_retained_accompaniment': not new_semitones,
            'original_protected_octave_and_fifth_skeleton_exact': not broken_skeleton,
            'actual_SF2_zone_transposition_at_most_four_semitones': bool(all_sample_zones_safe),
            'accepted_three_reused_byte_exact': all(r['byte_identical'] for r in reuse.values()),
        }
        assert all(checks.values()), (cue, checks, new_semitones, broken_skeleton)
        count = len(d2)
        drums = sum(n['channel'] == 9 for n in d2)
        total_notes += count
        total_drums += drums
        total_pitched += count - drums
        result = {'cue_id': cue, 'title': source_report['title'], 'status': 'PASS', 'reused_accepted_trial': index in REUSED_INDICES,
                  'source_sha256': source_hash, 'note_count': count, 'pitched_note_count': count - drums, 'drum_note_count': drums,
                  'changed_note_count': len(changed), 'changed_raw_message_count': len(changed_messages),
                  'maximum_seconds_difference_from_original_production_parser': max_seconds_error,
                  'checks': checks, 'new_semitone_conflicts': new_semitones, 'broken_protected_skeleton': broken_skeleton,
                  'sample_zone_checks': sample_details, 'accepted_reuse_sha256': reuse,
                  'artifacts': {name: {'path': str(dest / name), 'sha256': sha(dest / name)} for name in ('D1.mid', 'D2.mid', 'plan-D1.json', 'plan-D2.json')}}
        results.append(result)
        print(cue, 'INDEPENDENT PASS', count, 'notes', len(changed), 'changes', 'accepted reuse' if reuse else 'new')
    aggregate_checks = {'twelve_songs_present': len(results) == 12, 'source_pair_total_42063': total_notes == 42063,
                        'pitched_total_26957': total_pitched == 26957, 'drum_total_15106': total_drums == 15106,
                        'all_songs_pass': all(r['status'] == 'PASS' for r in results)}
    assert all(aggregate_checks.values()), aggregate_checks
    dump(BASE / 'reports/midi-independent-verification.json', {
        'schema_version': 2, 'status': 'PASS', 'scope': '12 complete frozen MIDI files; three accepted arrangements byte-reused, nine new arrangements',
        'method': 'Independent original production parse_midi decoder; raw source/derived message comparison; direct interval-overlap harmony scan; fresh raw SF2 region scan; accepted artifact SHA comparison',
        'generator_path': str(Path(__file__).resolve()), 'generator_sha256': sha(Path(__file__).resolve()),
        'source_parser': str(OLD / 'tools/render_non_drum_stems.py'), 'source_parser_sha256': sha(OLD / 'tools/render_non_drum_stems.py'),
        'accepted_indices': list(REUSED_INDICES), 'new_indices': list(NEW_INDICES),
        'totals': {'note_pairs': total_notes, 'pitched_notes': total_pitched, 'drum_notes': total_drums,
                   'D2_changed_notes': sum(r['changed_note_count'] for r in results)},
        'aggregate_checks': aggregate_checks, 'results': results,
        'acceptance_limit': 'Event and declared-rule verification only. Original automatic-transcription errors, preserved chromatic conflicts, and repeated-pitch safety exemptions remain. Musical effect is evaluated by rendered listening.'})


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--indices', type=int, nargs='+', default=list(NEW_INDICES))
    parser.add_argument('--verify-all', action='store_true', help='Verify all 12 existing arrangements without rewriting any plan or MIDI.')
    args = parser.parse_args()
    if args.verify_all:
        verify_all()
    else:
        assert all(idx in NEW_INDICES for idx in args.indices), 'Only the nine new indices may be generated.'
        for idx in args.indices:
            run(idx)

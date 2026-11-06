#!/usr/bin/env python3
"""Build source-auditable D1/D2 orchestration plans; never edit frozen inputs."""
from __future__ import annotations

import bisect
import collections
import copy
import hashlib
import json
from pathlib import Path
import shutil

import mido

ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT / 'design/music-20261104-chinese-trial'
OLD = ROOT / 'design/music-20261103-midi-test'
PITCH_NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
PENT = (0, 2, 4, 7, 9)
MODES = {'gong': 0, 'shang': 2, 'zhi': 7, 'yu': 9}
REGISTERS = {'pipa': (53, 95), 'ruan': (46, 83), 'zheng': (54, 81), 'erhu': (62, 88)}


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
    by_track = {t['track_index']: t for t in source_report['pitched_tracks']}
    for n in events:
        sr = 'drums' if n['channel'] == 9 else by_track[n['source_track']]['role']
        n['source_track_name'] = 'drums' if sr == 'drums' else by_track[n['source_track']]['source_track_name']
        n['source_role'] = sr
        n['role'] = sr
        n['instrument_family'] = {'guitar': 'electric_guitar', 'aux': 'pad'}.get(sr, sr)
        n['preferred_families'] = [n['instrument_family']]
        n['orchestration_reason'] = 'source_role_retained'
    if index in (1, 4):
        groups = collections.defaultdict(list)
        for n in events:
            if n['source_role'] == 'guitar':
                groups[(n['source_track'], n['start_tick'])].append(n)
        serial = 0
        for key, group in sorted(groups.items()):
            candidates = [n for n in group if 46 <= n['pitch'] <= 88 and n['duration_s'] <= .65]
            if not candidates:
                continue
            n = max(candidates, key=lambda x: x['pitch'])
            # Transfer the upper chord note; alternate isolated notes so a guitar lead remains.
            if len(group) == 1 and serial % 2:
                serial += 1
                continue
            serial += 1
            n['role'] = 'plucked'
            n['instrument_family'] = pluck_family(n['pitch'])
            n['preferred_families'] = [n['instrument_family']]
            n['orchestration_reason'] = 'short_upper_guitar_chord_note' if len(group) > 1 else 'alternating_isolated_upper_guitar_note'
    else:
        piano_groups = collections.defaultdict(list)
        for n in events:
            if n['source_role'] == 'piano':
                piano_groups[n['start_tick']].append(n)
        erhu_end = -1
        for tick, group in sorted(piano_groups.items()):
            ordered = sorted(group, key=lambda x: (-x['pitch'], -x['duration_s']))
            top = ordered[0]
            if 62 <= top['pitch'] <= 88 and top['duration_s'] >= .4 and tick >= erhu_end:
                top['role'] = 'bowed_lead'
                top['instrument_family'] = 'erhu'
                top['preferred_families'] = ['erhu']
                top['orchestration_reason'] = 'nonoverlapping_long_top_piano_note'
                erhu_end = top['end_tick']
            # Upper two chord positions only; bass and remaining harmony stay at original timbre.
            for n in ordered[:2]:
                if n['role'] == 'piano' and 54 <= n['pitch'] <= 88:
                    n['role'] = 'plucked'
                    n['instrument_family'] = pluck_family(n['pitch'], piano=True)
                    n['preferred_families'] = [n['instrument_family']]
                    n['orchestration_reason'] = 'upper_piano_chord_position'
    for n in events:
        if n['instrument_family'] in REGISTERS:
            lo, hi = REGISTERS[n['instrument_family']]
            assert lo <= n['pitch'] <= hi, n


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
            previous_by_family[n['instrument_family']] = n
            continue
        # Short passing notes are retained except in the near-pentatonic 04 control.
        on_quarter = min(n['start_tick'] % tpq, tpq - n['start_tick'] % tpq) <= tpq / 12
        if index == 8 and n['duration_s'] < .22 and not on_quarter:
            n['mapping_reason'] = 'short_unaccented_passing_tone_exempt'
            continue
        # All changes remain within the exact original octave neighbourhood (+/- 1).
        possible = [n['source_pitch'] + d for d in (-1, 1) if (n['source_pitch'] + d) % 12 in pcs]
        lo, hi = REGISTERS[n['instrument_family']]
        possible = [p for p in possible if lo <= p <= hi]
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
            if index == 8:
                strong_skeleton = [x for x in by_start[n['start_tick']] if x is not n and x['role'] in ('bass', 'guitar', 'piano') and x['duration_s'] >= .25 and (n['source_pitch'] - x['source_pitch']) % 12 in (0, 5, 7)]
                if any((target - x['source_pitch']) % 12 != (n['source_pitch'] - x['source_pitch']) % 12 for x in strong_skeleton):
                    failures['retained_octave_or_fifth_skeleton'] += 1
                    continue
            prev = previous_by_family.get(n['instrument_family'])
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
        previous_by_family[n['instrument_family']] = n
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
                'rules': {'source_event_identity': 'source track/channel, source note-on message index, start/end tick, source pitch',
                          'D1': 'exact source pitch/time/velocity/events; original MIDI byte copy; timbre assignment is in plan only',
                          'D2': 'local melodic-backbone modalization only: same orchestration as D1; selected Chinese-timbre backbone notes may move +/-1 semitone; no octave displacement; not whole-song pentatonic conversion',
                          'protected': 'all drums, bass, retained guitar/piano/aux; source note identities and timing; 08 retained simultaneous octave/fifth skeleton; no newly introduced semitone class against any overlapping retained guitar/piano/bass note',
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
              'erhu_has_no_overlapping_keydowns': stats['erhu_no_overlap']}
    assert all(checks.values()), checks
    result = {'schema_version': 1, 'cue_id': cue, 'title': report['title'], 'status': 'PASS',
              'source_midi': str(source), 'source_sha256': frozen_hash,
              'D1_midi': str(dest / 'D1.mid'), 'D2_midi': str(dest / 'D2.mid'),
              'checks': checks, 'mapping_preventions': mapping_preventions, 'statistics': stats,
              'sections': sections,
              'acceptance_limit': 'Structural/event audit only. These candidates require audio rendering and listening; target collection scores are not music-quality scores.'}
    dump(BASE / 'reports' / f'midi-{cue}.json', result)
    print(cue, report['title'], 'PASS', 'notes', len(events), 'changed', stats['changed_note_count'], 'family counts', {k: v['note_count'] for k, v in stats['per_instrument_family'].items()})


if __name__ == '__main__':
    for idx in (1, 4, 8):
        run(idx)

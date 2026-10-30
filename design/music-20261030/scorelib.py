"""Small score-writing primitives; orchestration and form belong to each piece.

Time is in quarter-note beats. Phrases explicitly include rests and durations.
This module neither invents melodies nor imposes a fixed ensemble or song form.
"""
import copy
import math
import re


PROGRAMS = {
    'piano': 0, 'harpsichord': 6, 'bell': 8, 'vibraphone': 11,
    'marimba': 12, 'organ': 19, 'acoustic_guitar': 24,
    'electric_guitar': 29, 'bass': 33, 'contrabass': 43,
    'violin': 40, 'viola': 41, 'cello': 42, 'pizzicato': 45,
    'harp': 46, 'strings': 48, 'trumpet': 56, 'trombone': 57,
    'horn': 60, 'oboe': 68, 'bassoon': 70, 'clarinet': 71,
    'flute': 73, 'pad': 89, 'pluck': 107, 'taiko': 116,
    'gong': 118, 'drums': 0, 'contrabass_pizz': 45,
    'dan_tranh': 107, 'psaltery': 15, 'synth_pluck': 107,
}


def pitch(value):
    if isinstance(value, (int, float)):
        return int(value)
    if value in ('r', '-', 'rest', None):
        return None
    found = re.fullmatch(r'([A-G])([b#]?)(-?\d)', value)
    if not found:
        raise ValueError(f'Invalid pitch {value!r}')
    letter, accidental, octave = found.groups()
    return (int(octave) + 1) * 12 + {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}[letter] + {'': 0, 'b': -1, '#': 1}[accidental]


def cue(cue_id, title, bpm, bars, meter=(4, 4), category='bed', loop=True,
        target_lufs=-21, **metadata):
    result = dict(id=cue_id, title=title, bpm=bpm, meter=list(meter),
                  beats=bars * meter[0] * 4 / meter[1], loop=loop,
                  category=category, target_lufs=target_lufs, tracks=[])
    result.update(metadata)
    return result


def track(instrument, name=None, db=-10, pan=0, **metadata):
    if instrument not in PROGRAMS:
        raise ValueError(f'Unregistered instrument {instrument}')
    result = dict(name=name or instrument, instrument=instrument,
                  program=PROGRAMS[instrument], db=db, pan=pan, notes=[])
    result.update(metadata)
    return result


def add_track(score, instrument, name=None, db=-10, pan=0, **metadata):
    result = track(instrument, name, db, pan, **metadata)
    score['tracks'].append(result)
    return result


def note(part, start, duration, number, velocity=72):
    value = pitch(number)
    if value is None:
        return
    if start < 0 or duration <= 0 or not 0 <= value <= 127 or not 1 <= velocity <= 127:
        raise ValueError((start, duration, number, velocity))
    part['notes'].append([round(start, 6), round(duration, 6), value, int(velocity)])


def phrase(text, bar_beats=4):
    """Return (relative beat, nominal duration, pitch) for explicit bars.

Tokens without a duration divide the remaining bar time equally. Examples:
    D5:1 A5:.5 F5:.5 E5:1 r:1 | F5 D5 C5 Bb4
    D5:3 | F5:1 E5:1 r:1             # 3/4
"""
    result, cursor = [], 0.0
    for bar in text.split('|'):
        tokens = [token.split(':') for token in bar.split()]
        if not tokens:
            raise ValueError('Empty bar')
        fixed = sum(float(token[1]) for token in tokens if len(token) == 2)
        implicit = sum(len(token) == 1 for token in tokens)
        default = (bar_beats - fixed) / implicit if implicit else 0
        total = sum(float(token[1]) if len(token) == 2 else default for token in tokens)
        if abs(total - bar_beats) > 1e-6 or (implicit and default <= 0):
            raise ValueError(f'Bar duration {total}, expected {bar_beats}: {bar}')
        for token in tokens:
            duration = float(token[1]) if len(token) == 2 else default
            if duration <= 0:
                raise ValueError(f'Nonpositive duration: {token}')
            result.append((cursor, duration, pitch(token[0])))
            cursor += duration
    return result, cursor


def melody(part, text, start=0, bar_beats=4, velocity=76, gate=.88,
           transpose=0, accents=None):
    events, length = phrase(text, bar_beats)
    for index, (beat, duration, number) in enumerate(events):
        if number is not None:
            change = accents[index % len(accents)] if accents else 0
            note(part, start + beat, duration * gate, number + transpose,
                 max(1, min(127, velocity + change)))
    return start + length


def chord(symbol):
    root, kind = symbol.split(':')
    intervals = {
        'M': (0, 4, 7), 'm': (0, 3, 7), '5': (0, 7),
        '7': (0, 4, 7, 10), 'M7': (0, 4, 7, 11),
        'm7': (0, 3, 7, 10), 'm6': (0, 3, 7, 9),
        '6': (0, 4, 7, 9), 'sus2': (0, 2, 7), 'sus4': (0, 5, 7),
        'dim': (0, 3, 6), 'dim7': (0, 3, 6, 9),
        'add9': (0, 4, 7, 14), 'madd9': (0, 3, 7, 14),
    }[kind]
    return [pitch(root) + interval for interval in intervals]


def voicing(part, pitches, start, duration, velocity=62, spread=.0):
    for index, value in enumerate(pitches):
        note(part, start + index * spread, duration, value, velocity)


def cc(part, beat, number, value):
    if beat < 0 or not 0 <= number <= 127 or not 0 <= value <= 127:
        raise ValueError((beat, number, value))
    part.setdefault('cc', []).append([beat, number, value])


def copy_cue(score, cue_id, title, **metadata):
    result = copy.deepcopy(score)
    result.update(id=cue_id, title=title, **metadata)
    return result


def validate(score):
    required = ('id', 'title', 'bpm', 'beats', 'loop', 'tracks')
    if not all(key in score for key in required):
        raise ValueError(f'Missing cue fields: {score.keys()}')
    if not re.fullmatch(r'[a-z][a-z0-9_]*', score['id']):
        raise ValueError(score['id'])
    if score['bpm'] <= 0 or score['beats'] <= 0 or not score['tracks']:
        raise ValueError(f'Empty or invalid score: {score["id"]}')
    for part in score['tracks']:
        if part['instrument'] not in PROGRAMS or not -1 <= part['pan'] <= 1:
            raise ValueError((score['id'], part))
        for event in part['notes']:
            start, duration, number, velocity = event
            if not all(math.isfinite(value) for value in event):
                raise ValueError(event)
            if start < 0 or duration <= 0 or start + duration > score['beats'] + 1e-5:
                raise ValueError((score['id'], part['name'], 'outside score', event))
            if not 0 <= number <= 127 or not 1 <= velocity <= 127:
                raise ValueError(event)
        part['notes'].sort(key=lambda event: (event[0], event[2]))
    if not any(part['notes'] for part in score['tracks']):
        raise ValueError(f'Silent score: {score["id"]}')
    return score

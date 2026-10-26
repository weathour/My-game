#!/usr/bin/env python3
"""Original, explicitly scored My-game soundtrack. Write MIDI + a REAPER session script.

No model/API calls, borrowed songs/MIDI, or random melody generation. Themes below
are the score; the small arranger supplies orchestration and deterministic articulation.
"""
import json
import math
from pathlib import Path
import re
import struct

HERE = Path(__file__).resolve().parent
RENDER = Path('/tmp/mygame-music-render')
PPQ = 960


def pitch(name):
    m = re.fullmatch(r'([A-G])([b#]?)(-?\d)', name)
    assert m, name
    letter, accidental, octave = m.groups()
    return (int(octave) + 1) * 12 + {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}[letter] + {'': 0, 'b': -1, '#': 1}[accidental]


def phrase(text, beats=4):
    result = []
    for line in text.split('|'):
        tokens = line.strip().split()
        assert tokens
        bar = []
        for token in tokens:
            parts = token.split(':')
            duration = float(parts[1]) if len(parts) == 2 else beats / len(tokens)
            bar.append((None if parts[0] == 'r' else pitch(parts[0]), duration))
        assert abs(sum(d for _, d in bar) - beats) < 1e-7, (line, bar)
        result.append(bar)
    assert len(result) == 8, len(result)
    return result


def chord(name):
    root, kind = name.split(':')
    intervals = {'m': [0, 3, 7], 'M': [0, 4, 7], '7': [0, 4, 7, 10], 'm7': [0, 3, 7, 10], 'dim': [0, 3, 6], 'sus': [0, 5, 7]}[kind]
    return [pitch(root) + n for n in intervals]


# Each subject and contrasting answer is written separately. D–A–F–E is the camp's
# four-note signal, recollected in the frontpost and final battle, not every melody.
SCORES = [
 dict(id='camp_signal', title='等一声回答', bpm=76, key='D minor / F major', bars=32, lead='piano', counter='flute', bass='cello', quiet=True,
 A='D5:1 A5:.5 F5:.5 E5:1 r:1 | F5:1 D5:.5 C5:.5 Bb4:2 | A4:1 C5:1 F5:1 G5:1 | E5:1 D5:.5 E5:.5 G5:1 r:1 | G5:1 D5:1 Bb4:1 A4:1 | F5:1 E5:.5 D5:.5 A4:2 | E5:1 G5:1 Bb5:.5 A5:.5 G5:1 | E5:1 C#5:1 D5:1 r:1',
 B='F5:1 C6:.5 A5:.5 G5:1 E5:1 | D5:1 F5:.5 A5:.5 Bb5:1 A5:1 | G5:1 E5:.5 C5:.5 G4:2 | A4:1 C5:.5 E5:.5 F5:2 | Bb5:1 A5:.5 G5:.5 F5:1 D5:1 | G5:1 F5:1 E5:1 C5:1 | A4:1 D5:1 C#5:1 E5:1 | A5:1 G5:1 E5:1 r:1',
 H='D3:m Bb2:M F3:M C3:M G2:m D3:m E3:dim A2:7', J='F3:M Bb2:M C3:M F3:M G2:m C3:7 D3:m A2:7',
 C='F4 A4 | Bb3 F4 | C4 A3 | G3 E4 | D4 G4 | A3 F4 | G4 E4 | C#4 E4'),
 dict(id='stage_frontpost', title='前哨的两条来路', bpm=136, key='D minor', bars=64, lead='piano', counter='harpsichord', bass='bass',
 A='D5 A5 F5 E5 D5 F5 A5 C6 | Bb5 A5 G5 F5 E5 D5 C5 Bb4 | A4 C5 F5 A5 G5 F5 E5 D5 | E5:1 G5:.5 C6:.5 B5:.5 A5:.5 G5:1 | G5 D5 Bb5 A5 G5 F5 E5 D5 | F5:1 A5:.5 C6:.5 A5:1 F5:1 | E5 G5 Bb5 D6 C6 Bb5 A5 G5 | E5:1 C#5:.5 E5:.5 A5:1 r:1',
 B='A5:1 C6:.5 A5:.5 F5:.5 E5:.5 F5:1 | D6 C6 Bb5 A5 G5 F5 E5 D5 | G5:1 C6:1 B5:.5 A5:.5 G5:1 | A5 C6 F6 E6 D6 C6 A5 G5 | Bb5:1 A5:.5 G5:.5 F5:1 D5:1 | E5 G5 C6 Bb5 A5 G5 E5 C5 | D5 F5 A5 D6 C6 A5 F5 D5 | E5:1 C#5:1 A4:.5 C#5:.5 E5:1',
 H='D3:m Bb2:M F3:M C3:M G2:m D3:m E3:dim A2:7', J='F3:M Bb2:M C3:7 F3:M G2:m C3:7 D3:m A2:7',
 C='F4 E4 D4 A3 | D4 F4 Bb4 A4 | C4 A3 F4 E4 | G4 E4 C4 E4 | Bb3 D4 G4 F4 | A3 D4 F4 E4 | Bb3 E4 G4 F4 | C#4 B3 A3 E4'),
 dict(id='stage_rift', title='裂隙另一侧的回声', bpm=148, key='G minor', bars=64, lead='trumpet', counter='piano', bass='bass',
 A='G5:.5 D6:.5 Bb5:1 A5:.5 G5:.5 F#5:1 | G5 Bb5 D6 C6 Bb5 A5 G5 F5 | Eb5:1 Bb5:.5 C6:.5 D6:1 C6:.5 Bb5:.5 | A5:1 F#5:1 D5:.5 E5:.5 F#5:1 | G5 A5 Bb5 D6 C6 Bb5 A5 G5 | F5:1 A5:.5 C6:.5 Eb6:1 D6:1 | C6 Bb5 A5 G5 F5 Eb5 D5 C5 | F#5:1 A5:1 D6:1 r:1',
 B='Bb5:1 F6:.5 D6:.5 C6:1 Bb5:1 | Ab5 G5 F5 Eb5 D5 C5 Bb4 C5 | D5:1 F5:.5 Bb5:.5 A5:1 G5:1 | C6:1 A5:.5 F5:.5 E5:1 G5:1 | Eb5 G5 Bb5 D6 C6 Bb5 G5 Eb5 | C6:1 G5:1 A5:.5 Bb5:.5 C6:1 | Bb5 A5 G5 F#5 G5 Bb5 D6 C6 | A5:1 F#5:1 D5:1 r:1',
 H='G2:m G2:m Eb3:M D3:7 G2:m F3:7 C3:m D3:7', J='Bb2:M Ab2:M Bb2:M C3:7 Eb3:M C3:m G2:m D3:7',
 C='Bb4 A4 G4 D4 | D4 G4 Bb4 A4 | G4 F4 Eb4 Bb3 | F#4 A4 C5 A4 | D4 G4 F#4 G4 | A4 G4 F4 C4 | Eb4 G4 C5 Bb4 | A4 F#4 D4 C4'),
 dict(id='stage_core', title='群星失去方向', bpm=156, key='E minor', bars=64, lead='horn', counter='harpsichord', bass='synthbass',
 A='E5:1 B5:.5 G5:.5 F#5:1 D#5:1 | E5 G5 B5 D6 C6 B5 A5 G5 | A5:1 E6:1 C6:.5 B5:.5 A5:1 | F#5 A5 C6 B5 A5 F#5 D#5 B4 | G5 B5 E6 D6 C6 B5 G5 E5 | F#5:1 A5:.5 C6:.5 B5:1 A5:1 | C6 B5 A5 G5 F#5 E5 D#5 F#5 | B5:1 A5:1 F#5:1 r:1',
 B='G5:1 D6:1 B5:.5 A5:.5 G5:1 | C6:1 E6:.5 D6:.5 C6:1 B5:1 | A5 C6 E6 G6 F#6 E6 D6 C6 | B5:1 G5:1 D5:1 r:1 | A5:1 C6:.5 B5:.5 A5:1 F#5:1 | B5 A5 G5 F#5 E5 D#5 E5 G5 | F#5:1 A5:.5 C6:.5 E6:1 D#6:1 | B5:1 F#5:1 D#5:1 r:1',
 H='E3:m E3:m A2:m B2:7 E3:m F#3:dim A2:m B2:7', J='G2:M C3:M A2:m G2:M F#3:dim E3:m F#3:dim B2:7',
 C='G4 F#4 E4 B3 | B3 E4 G4 F#4 | C4 E4 A4 G4 | D#4 F#4 B4 A4 | B3 E4 G4 F#4 | C4 A3 F#4 E4 | E4 C4 A3 C4 | D#4 F#4 A4 F#4'),
 dict(id='elite_ram', title='踏破红线', bpm=168, key='C minor', bars=32, lead='brass', counter='piano', bass='synthbass',
 A='C5:.5 C5:.5 G5:1 Eb5:.5 D5:.5 C5:1 | Ab4:.5 Ab4:.5 Eb5:.5 F5:.5 G5:1 Eb5:1 | Bb4 D5 F5 D5 Bb4 F5 Ab5 F5 | G5:1 D5:.5 B4:.5 G4:1 r:1 | C5 Eb5 G5 C6 Bb5 G5 Eb5 C5 | Ab5:1 G5:.5 F5:.5 Eb5:1 C5:1 | F5:.5 F5:.5 C6:1 Ab5:.5 G5:.5 F5:1 | D5 B4 D5 G5 F5 D5 B4 G4',
 B='Eb5:1 Bb5:.5 G5:.5 F5:1 Eb5:1 | Ab5 G5 F5 Eb5 D5 C5 Bb4 Ab4 | F5:1 C6:1 Ab5:.5 G5:.5 F5:1 | G5 B5 D6 C6 B5 G5 F5 D5 | C6:1 G5:1 Eb5:.5 D5:.5 C5:1 | Ab5:1 Eb5:1 C5:1 r:1 | D5 F5 Ab5 C6 B5 Ab5 F5 D5 | B4:1 D5:1 G5:1 r:1',
 H='C3:m Ab2:M Bb2:M G2:7 C3:m Ab2:M F2:m G2:7', J='Eb3:M Ab2:M F2:m G2:7 C3:m Ab2:M D3:dim G2:7',
 C='Eb4 D4 C4 G3 | C4 Eb4 Ab4 G4 | D4 F4 Bb4 Ab4 | B3 D4 G4 F4 | G3 C4 Eb4 D4 | C4 Eb4 G4 Ab4 | Ab3 C4 F4 Eb4 | D4 B3 G3 B3'),
 dict(id='elite_splitshot', title='四向展开', bpm=174, key='F minor', bars=32, lead='trumpet', counter='harpsichord', bass='bass',
 A='F5 C6 Ab5 Eb6 C6 Ab5 G5 F5 | Db5 Ab5 F5 C6 Ab5 F5 Eb5 Db5 | Eb5 Bb5 G5 Db6 Bb5 G5 F5 Eb5 | E5 G5 C6 Bb5 G5 E5 D5 C5 | Ab5 F5 C6 Ab5 Eb6 C6 Ab5 G5 | Bb5 F5 Db6 Bb5 F6 Db6 Bb5 Ab5 | G5 Bb5 Db6 F6 E6 Db6 Bb5 G5 | C6:1 G5:.5 E5:.5 C5:1 r:1',
 B='Ab5:1 Eb6:.5 C6:.5 Bb5:.5 Ab5:.5 G5:1 | F5 Ab5 Db6 F6 Eb6 Db6 C6 Bb5 | G5:1 Bb5:.5 Eb6:.5 Db6:1 C6:1 | C6 Eb6 Ab6 G6 F6 Eb6 C6 Bb5 | Db6 C6 Bb5 Ab5 G5 F5 Eb5 Db5 | Bb5:1 F5:1 Db5:.5 Eb5:.5 F5:1 | G5 Db6 Bb5 F6 E6 C6 Bb5 G5 | E5:1 G5:1 C6:1 r:1',
 H='F3:m Db3:M Eb3:M C3:7 F3:m Bb2:m G3:dim C3:7', J='Ab2:M Db3:M Eb3:7 Ab2:M Db3:M Bb2:m G3:dim C3:7',
 C='Ab4 G4 F4 C4 | F4 Ab4 Db5 C5 | G4 Bb4 Eb5 Db5 | G4 E4 C4 E4 | C4 F4 Ab4 G4 | Db4 F4 Bb4 Ab4 | Bb4 G4 Db4 F4 | E4 G4 Bb4 G4'),
 dict(id='boss_tree', title='根须记住了雨', bpm=138, key='D minor with Dorian colour', bars=64, lead='reed', counter='harpsichord', bass='cello',
 A='D5 F5 A5 G5 F5 E5 D5 C5 | Bb4 D5 F5 A5 G5 F5 E5 D5 | E5 G5 Bb5 A5 G5 F5 E5 D5 | C#5 E5 G5 Bb5 A5 G5 E5 C#5 | D5:1 A5:1 G5:.5 F5:.5 E5:1 | B4 D5 G5 B5 A5 G5 F5 E5 | C5 E5 A5 G5 F5 E5 D5 C5 | E5:1 C#5:1 A4:1 r:1',
 B='F5:1 A5:.5 C6:.5 D6:1 C6:.5 A5:.5 | Bb5 A5 G5 F5 E5 D5 C5 Bb4 | G5:1 Bb5:1 A5:.5 G5:.5 F5:1 | E5 G5 C6 Bb5 A5 G5 E5 C5 | D5 F5 A5 C6 B5 A5 G5 F5 | E5:1 G5:.5 B5:.5 C6:1 B5:1 | Bb5 A5 G5 F5 E5 D5 C#5 E5 | A5:1 E5:1 C#5:1 r:1',
 H='D3:m Bb2:M E3:dim A2:7 D3:m G2:M A2:m A2:7', J='F3:M Bb2:M G2:m C3:7 D3:m E3:m G2:m A2:7',
 C='A3 D4 F4 E4 | F4 D4 Bb3 D4 | Bb3 E4 G4 F4 | E4 C#4 A3 G3 | F4 E4 D4 A3 | G3 B3 D4 F4 | E4 C4 A3 C4 | C#4 E4 G4 E4'),
 dict(id='boss_rebirth', title='第二次渡河', bpm=150, key='A minor', bars=64, lead='organ', counter='piano', bass='cello',
 A='A4:1 E5:1 C5:.5 B4:.5 A4:1 | F5:1 C5:1 A4:.5 G4:.5 F4:1 | D5 F5 A5 C6 B5 A5 G5 F5 | E5:1 B4:.5 G#4:.5 E4:1 r:1 | A5:1 G5:.5 E5:.5 C5:1 B4:1 | F5 A5 C6 B5 A5 G5 F5 E5 | D5:1 F5:.5 A5:.5 G#5:1 F5:1 | E5:1 B4:1 G#4:1 r:1',
 B='C6 B5 A5 G5 E5 G5 C6 E6 | F6:1 E6:.5 D6:.5 C6:1 A5:1 | D6:1 A5:1 F5:.5 E5:.5 D5:1 | G5 B5 D6 F6 E6 D6 B5 G5 | A5:1 E6:.5 C6:.5 B5:1 A5:1 | F5:1 A5:.5 C6:.5 B5:1 G5:1 | B5 A5 G#5 F5 E5 D5 C5 B4 | G#4:1 B4:1 E5:1 r:1',
 H='A2:m F3:M D3:m E3:7 A2:m F3:M B2:dim E3:7', J='C3:M F3:M D3:m G2:7 A2:m F3:M B2:dim E3:7',
 C='C4 B3 A3 E3 | A3 C4 F4 E4 | F4 E4 D4 A3 | G#3 B3 E4 D4 | E4 C4 A3 C4 | C4 F4 A4 G4 | F4 D4 B3 D4 | G#3 B3 D4 B3'),
 dict(id='boss_rose', title='八瓣回旋庭', bpm=168, key='G minor / Bb major', bars=64, lead='trumpet', counter='harpsichord', bass='bass',
 A='G5 Bb5 D6 G6 F6 D6 Bb5 A5 | Eb6:1 D6:.5 C6:.5 Bb5:1 G5:1 | A5 C6 F6 Eb6 D6 C6 A5 F5 | F#5:1 A5:.5 D6:.5 C6:1 A5:1 | Bb5 D6 G6 F6 Eb6 D6 C6 Bb5 | C6 Eb6 G6 F6 Eb6 D6 C6 Bb5 | A5 C6 Eb6 G6 F#6 Eb6 C6 A5 | F#5:1 D6:1 A5:1 r:1',
 B='D6:1 F6:.5 D6:.5 Bb5:1 A5:1 | Eb6 D6 C6 Bb5 A5 G5 F5 Eb5 | C6:1 G6:1 Eb6:.5 D6:.5 C6:1 | A5 C6 F6 Eb6 D6 C6 A5 F5 | G5:1 Bb5:.5 D6:.5 G6:1 F6:1 | Eb6:1 Bb5:1 G5:.5 A5:.5 Bb5:1 | A5 Eb6 C6 G6 F#6 D6 C6 A5 | D6:1 C6:1 A5:1 r:1',
 H='G2:m Eb3:M F3:7 D3:7 G2:m C3:m A2:dim D3:7', J='Bb2:M Eb3:M C3:m F3:7 G2:m Eb3:M A2:dim D3:7',
 C='Bb4 A4 G4 D4 | G4 Bb4 Eb5 D5 | C5 A4 F4 A4 | F#4 A4 C5 A4 | D4 G4 Bb4 A4 | Eb4 G4 C5 Bb4 | C5 A4 Eb4 G4 | F#4 A4 C5 A4'),
 dict(id='boss_spellcore', title='把回答带回黎明', bpm=180, key='D minor / F major', bars=64, lead='trumpet', counter='piano', bass='synthbass',
 A='D5 A5 F5 E5 D5 F5 A5 D6 | C6 Bb5 A5 G5 F5 E5 D5 C5 | Bb4 D5 G5 Bb5 A5 G5 F5 E5 | C#5 E5 A5 C6 Bb5 A5 G5 E5 | F5:1 A5:.5 D6:.5 C6:1 A5:1 | Bb5 D6 G6 F6 E6 D6 C6 Bb5 | E5 G5 Bb5 D6 C#6 Bb5 A5 G5 | E5:1 C#5:1 A4:1 r:1',
 B='F5:1 C6:.5 A5:.5 G5:1 F5:1 | D6 C6 Bb5 A5 G5 F5 E5 D5 | G5:1 C6:1 E6:.5 D6:.5 C6:1 | A5 C6 F6 E6 D6 C6 A5 G5 | Bb5:1 D6:1 C6:.5 Bb5:.5 A5:1 | G5 Bb5 Eb6 D6 C6 Bb5 G5 Eb5 | F5 A5 D6 C6 Bb5 A5 G5 F5 | E5:1 C#5:1 A5:1 r:1',
 H='D3:m Bb2:M G2:m A2:7 D3:m G2:m E3:dim A2:7', J='F3:M Bb2:M C3:7 F3:M G2:m Eb3:M D3:m A2:7',
 C='F4 E4 D4 A3 | D4 F4 Bb4 A4 | Bb3 D4 G4 F4 | C#4 E4 G4 E4 | A3 D4 F4 E4 | D4 G4 Bb4 A4 | G4 E4 Bb3 D4 | C#4 E4 G4 E4'),
]

INSTRUMENTS = {
    'piano': (0, -2.5, -0.10), 'harpsichord': (6, -10.0, 0.24),
    'flute': (73, -11.0, 0.18), 'cello': (42, -10.0, -0.14),
    'bass': (33, -7.0, 0), 'synthbass': (38, -10.0, 0),
    'trumpet': (56, -10.5, -0.08), 'brass': (61, -11.0, -0.06),
    'horn': (60, -10.0, -0.08), 'reed': (69, -7.5, -0.10),
    'organ': (19, -14.0, -0.08), 'strings': (48, -17.0, 0.12),
    'bell': (8, -17.0, 0.25), 'drums': (0, -10.5, 0),
}


def track(name, instrument, channel):
    program, db, pan = INSTRUMENTS[instrument]
    return dict(name=name, instrument=instrument, program=program, db=db, pan=pan, channel=channel, notes=[])


def note(t, start, duration, number, velocity):
    if number is None:
        return
    assert start >= 0 and duration > 0 and 0 <= number <= 127
    assert 1 <= velocity <= 127
    t['notes'].append([round(start, 6), round(duration, 6), int(number), int(velocity)])


def line(t, start, bar, velocity, octave=0, gate=.88):
    at = start
    for number, duration in bar:
        note(t, at, duration * gate, None if number is None else number + octave, velocity + (3 if abs(at - round(at)) < .01 else -4))
        at += duration


def compose(score, phase=0):
    a, b, c = phrase(score['A']), phrase(score['B']), phrase(score['C'])
    harmony = [[chord(x) for x in score[k].split()] for k in ('H', 'J')]
    assert all(len(h) == 8 for h in harmony)
    quiet = score.get('quiet', False)
    tracks = [track('01 Subject — ' + score['title'], score['lead'], 0),
              track('02 Answer / counterline', score['counter'], 1),
              track('03 Moving continuo', score['bass'], 2),
              track('04 Inner broken chords', 'harpsichord' if not quiet else 'piano', 3),
              track('05 Harmonic horizon', 'strings', 4),
              track('06 Light / high answer', 'bell', 5),
              track('07 Pulse', 'drums', 9)]
    if quiet:
        tracks[0]['db'] -= 3
        tracks[3]['db'] -= 9
        tracks[4]['db'] -= 6
    if score['id'] == 'boss_spellcore':
        tracks[0]['db'] += [-1, 0, .5][phase - 1]
        tracks[1]['db'] -= 1
    total = score['bars'] * 4
    for barno in range(score['bars']):
        section, local = divmod(barno, 8)
        contrast = section in (2, 3, 5, 7)
        melody = b[local] if contrast else a[local]
        harmony_index = 1 if contrast else 0
        h = harmony[harmony_index][local]
        # Eight-bar periods: exposed subject, answering voice, broad second subject,
        # development, reduced return, higher-intensity reprise, final dominant turn.
        energy = ([.66, .76, .85, .91, .59, .78, .95, 1.0][section] if score['bars'] == 64 else [.65, .83, .73, .94][section])
        if quiet:
            energy *= .75
        start = barno * 4
        lead_velocity = round(61 + 20 * energy + (2 if local in (2, 6) else 0))
        if quiet:
            lead_velocity -= 18
        # The bridge leaves the foreground to the answering instrument for two bars.
        exchange = score['bars'] == 64 and section == 4 and local in (2, 3)
        line(tracks[1] if exchange else tracks[0], start, melody, lead_velocity, gate=.90 if quiet else .84)
        if not quiet and (section > 0 or barno >= 4):
            counter_bar = c[local]
            # Contrasting harmony has a different bass; use a consonant independent
            # two-beat line there, instead of transposing the first subject blindly.
            if contrast:
                counter_bar = [(h[1] + 12, 1), (h[2] + 12, .5), (h[1] + 12, .5), (h[0] + 12, 1), (h[2], 1)]
            if not exchange:
                line(tracks[1], start, counter_bar, round(56 + energy * 11), gate=.79)
        elif quiet and section > 0 and local in (1, 3, 5, 7):
            note(tracks[1], start + 1, 1.6, h[1] + 24, 48)
            note(tracks[1], start + 3, .85, h[2] + 24, 43)
        # Bass has its own direction and breath. No machine-gun chord stacks.
        if quiet:
            note(tracks[2], start, 3.7, h[0], 52)
        else:
            for beat, number in enumerate((h[0] - 12, h[2] - 12, h[0], h[1])):
                note(tracks[2], start + beat, .72 if beat != 3 else .62, number, round(68 + energy * 13) - (beat % 2) * 8)
        arpeggio = [h[0] + 12, h[2] + 12, h[1] + 12, h[2] + 12, h[0] + 24, h[2] + 12, h[1] + 12, h[2] + 12]
        if quiet:
            arpeggio = arpeggio[::2]
        for i, number in enumerate(arpeggio):
            # Exposed first phrase and bridge create spectral space for the subject.
            if not quiet and section in (0, 4) and i % 2 == 1:
                continue
            note(tracks[3], start + i * 4 / len(arpeggio), .45 if not quiet else .85, number, (43 if quiet else 47) + (4 if i % 4 == 0 else 0))
        if section != 0 or local >= 4:
            for number in h[:3]:
                note(tracks[4], start + .03, 3.86, number + 12, round(42 + energy * 10))
        if local in (0, 4) and (quiet or section in (2, 3, 6, 7)):
            note(tracks[5], start, 1.4, h[2] + 36, 42 if quiet else 49)
        if not quiet:
            pulse = tracks[6]
            reduced = section == 4 or (phase == 1 and section in (0, 1, 4))
            kick_beats = [0, 2] if reduced else [0, 1.5, 2, 3.5]
            if score['id'] == 'elite_ram':
                kick_beats = [0, .75, 2, 2.75]
            if phase >= 2:
                kick_beats = [0, 1, 2, 3]
            for beat in kick_beats:
                note(pulse, start + beat, .12, 36, round(66 + energy * 14))
            for beat in (1, 3):
                note(pulse, start + beat, .12, 38 if not reduced else 37, round(59 + energy * 14))
            for i in range(8):
                if reduced and i % 2:
                    continue
                note(pulse, start + i * .5, .08, 42 if i != 7 or local != 7 else 46, (46 if i % 2 == 0 else 34) + round(energy * 5))
            if local == 7 and section != 4:
                for beat, num in ((3, 45), (3.25, 47), (3.5, 48), (3.75, 50)):
                    note(pulse, start + beat, .12, num, 53 + round(beat * 3))
            if local == 0 and section in (2, 6):
                note(pulse, start, .3, 49, 54)
        if phase >= 2:
            # Phase 2 adds a separate high invention, not a louder duplicate master.
            high = tracks[5]
            high['instrument'], high['program'], high['db'] = 'harpsichord', 6, -15
            if barno % 2:
                for i, number in enumerate(arpeggio):
                    note(high, start + i * .5, .34, number + 12, 56)
        if phase == 3:
            # Last phase opens the upper octave on phrase heads; the central melody
            # remains readable and the three mixes retain one musical timeline.
            if local in (0, 2, 4, 6):
                line(tracks[4], start, melody, 49, octave=12, gate=.72)
    cue_id = score['id'] + (f'_{phase}' if phase else '')
    return dict(id=cue_id, title=score['title'] + (f' · 第{phase}相' if phase else ''), bpm=score['bpm'], bars=score['bars'], beats=total,
                key=score['key'], loop=True, target_lufs=-23 if quiet else (-20 if phase else -21), tracks=tracks)


def ending(cue_id, win):
    # A six-bar cadence resolves the camp signal, a four-bar falling response leaves
    # room for retry UI. Both have natural decay and must never loop in the game.
    t = [track('Piano / signal resolution', 'piano', 0), track('Soft strings', 'strings', 1), track('Celesta', 'bell', 2)]
    melody = [('D5', 0, 1), ('A5', 1, .5), ('F5', 1.5, .5), ('E5', 2, 1), ('F5', 4, 1), ('A5', 5, 1), ('D6', 6, 2), ('F6', 8, 3)] if win else [('A5', 0, 1), ('F5', 1, 1), ('E5', 2, 1.5), ('D5', 4, 3)]
    for name, at, dur in melody:
        note(t[0], at, dur * .9, pitch(name), 66 if win else 53)
    for at, h in ((0, 'D3:m'), (4, 'Bb2:M' if win else 'G2:m'), (8, 'F3:M' if win else 'D3:m')):
        for number in chord(h):
            note(t[1], at, 3.7, number + 12, 46)
            note(t[0], at + .02, 2.8, number, 48)
    note(t[2], 8 if win else 4, 2, pitch('F6' if win else 'D6'), 46)
    return dict(id=cue_id, title='灯亮了' if win else '信号仍在', bpm=94 if win else 72, bars=4, beats=16, key='F major' if win else 'D minor', loop=False, target_lufs=-22 if win else -24, tracks=t)


def vlq(n):
    assert n >= 0
    data = [n & 127]
    while n > 127:
        n >>= 7
        data.insert(0, (n & 127) | 128)
    return bytes(data)


def midi(cue):
    chunks = []
    tempo = round(60_000_000 / cue['bpm'])
    conductor = b'\x00\xff\x51\x03' + tempo.to_bytes(3, 'big') + b'\x00\xff\x58\x04\x04\x02\x18\x08\x00\xff\x2f\x00'
    chunks.append(conductor)
    for t in cue['tracks']:
        ch = t['channel']
        events = [(0, bytes([0xC0 + ch, t['program']]))]
        name = t['name'].encode('utf-8')
        events.append((0, b'\xff\x03' + vlq(len(name)) + name))
        for start, duration, number, velocity in t['notes']:
            events += [(round(start * PPQ), bytes([0x90 + ch, number, velocity])), (round((start + duration) * PPQ), bytes([0x80 + ch, number, 0]))]
        # Program selection must precede a note at tick zero; note-offs precede
        # same-tick retriggers so imported MIDI retains the intended articulation.
        events.sort(key=lambda e: (e[0], 0 if e[1][0] == 0xFF else 1 if e[1][0] & 0xF0 in (0xB0, 0xC0) else 2 if e[1][0] & 0xF0 == 0x80 else 3))
        data, previous = bytearray(), 0
        for at, event in events:
            data.extend(vlq(at - previous) + event)
            previous = at
        data.extend(vlq(max(0, round(cue['beats'] * PPQ) - previous)) + b'\xff\x2f\x00')
        chunks.append(bytes(data))
    result = b'MThd' + struct.pack('>IHHH', 6, 1, len(chunks), PPQ)
    return result + b''.join(b'MTrk' + struct.pack('>I', len(c)) + c for c in chunks)


def lua(value):
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, list):
        return '{' + ','.join(lua(v) for v in value) + '}'
    if isinstance(value, dict):
        return '{' + ','.join('[' + lua(k) + ']=' + lua(v) for k, v in value.items()) + '}'
    return str(value)


def main():
    RENDER.mkdir(parents=True, exist_ok=True)
    for folder in ('projects', 'midi', 'masters'):
        (HERE / folder).mkdir(exist_ok=True)
    cues = []
    for score in SCORES:
        cues.extend([compose(score, p) for p in (1, 2, 3)] if score['id'] == 'boss_spellcore' else [compose(score)])
    cues += [ending('victory', True), ending('defeat', False)]
    assert len(cues) == 14 and len({c['id'] for c in cues}) == 14
    assert len({s['A'] for s in SCORES}) == 10
    for cue in cues:
        assert all(start + duration <= cue['beats'] for t in cue['tracks'] for start, duration, _, _ in t['notes'])
        assert all(23 <= n <= 108 for t in cue['tracks'] for _, _, n, _ in t['notes']), cue['id']
        # Same-note overlap can silently choke voices on MIDI instruments.
        for t in cue['tracks']:
            last = {}
            for start, duration, number, _ in sorted(t['notes']):
                assert start >= last.get(number, -1) - 1e-6, (cue['id'], t['name'], number, start)
                last[number] = start + duration
        (HERE / 'midi' / (cue['id'] + '.mid')).write_bytes(midi(cue))
    (HERE / 'score.json').write_text(json.dumps(cues, ensure_ascii=False, separators=(',', ':')) + '\n')
    (RENDER / 'score.lua').write_text('return ' + lua(cues) + '\n')
    manifest = [{k: v for k, v in c.items() if k != 'tracks'} | {'duration_seconds': c['beats'] * 60 / c['bpm'], 'track_count': len(c['tracks']), 'note_count': sum(len(t['notes']) for t in c['tracks'])} for c in cues]
    (HERE / 'cue-sheet.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'cues': len(cues), 'minutes': round(sum(c['beats'] * 60 / c['bpm'] for c in cues) / 60, 2), 'notes': sum(sum(len(t['notes']) for t in c['tracks']) for c in cues)}, ensure_ascii=False))


if __name__ == '__main__':
    main()

"""Hand-written character and dialogue scores (quarter-note beat units).

No borrowed melody or performance recording. Instrument names describe the
registered sounds, not unrecorded claims about Chinese historical instruments.
The helpers place authored material; they do not generate a melody.
"""
import copy

from scorelib import add_track, chord, cue, melody, note, pitch, validate, voicing


def _line(part, text, bar=0, meter=4, vel=74, gate=.84, shift=0):
    return melody(part, text, bar * meter, meter, vel, gate, shift)


def _harmony(part, symbols, bar=0, meter=4, mode='held', vel=52):
    """Place explicitly selected harmonies with an explicitly selected gesture."""
    for i, symbol in enumerate(symbols.split()):
        if symbol == '-':
            continue
        tones = chord(symbol)
        floor = part.get('voicing_floor')
        if floor is not None:
            # Authored inversion choice for the actual recorded section range.
            tones = [p + 12 * max(0, (floor - p + 11) // 12) for p in tones]
        at = (bar + i) * meter
        if mode == 'held':
            voicing(part, tones, at, meter * .84, vel)
        elif mode == 'offbeat':
            for offset in (.75, 2.5):
                if offset < meter:
                    voicing(part, tones, at + offset, .34, vel)
        elif mode == 'waltz':
            voicing(part, tones[1:], at + 1, .56, vel)
            voicing(part, tones[:2], at + 2, .55, vel - 5)
        elif mode == 'six':
            for offset, index in ((0, 0), (.5, 1), (1, 2), (1.5, 1), (2, 2), (2.5, 1)):
                note(part, at + offset, .38, tones[index], vel + (2 if offset == 0 else -4))
        elif mode == 'broken':
            for offset, index in ((0, 0), (1, 2), (2, 1), (3, 2)):
                if offset < meter:
                    note(part, at + offset, .72, tones[index], vel)
        else:
            raise ValueError(mode)


def _bass(part, roots, bar=0, meter=4, mode='long', vel=56):
    for i, root in enumerate(roots.split()):
        if root == '-':
            continue
        at, p = (bar + i) * meter, pitch(root)
        if mode == 'long':
            note(part, at, meter * .82, p, vel)
        elif mode == 'two':
            note(part, at, .78, p, vel)
            note(part, at + meter / 2, .66, p + 7, vel - 8)
        elif mode == 'short':
            note(part, at, .48, p, vel)
            if i % 2 == 0:
                note(part, at + meter - .5, .28, p + 7, vel - 10)


def _section(score, name, bar, bars, meter=4):
    score.setdefault('sections', []).append(dict(name=name, start=bar * meter, beats=bars * meter))


def _comedy():
    s = cue('story_comedy', '歪一步再走（工作题）', 118, 40,
            category='story', theme_family='comedy', target_lufs=-23,
            intent='Pitched question, a conspicuous pause, then an unhurried bass reply.')
    reed = add_track(s, 'bassoon', 'dry question', -9, -.16)
    pluck = add_track(s, 'pizzicato', 'short answers', -12, .22)
    keys = add_track(s, 'piano', 'lean syncopated chords', -15, -.12)
    low = add_track(s, 'contrabass', 'comic feet', -12, 0)
    drums = add_track(s, 'drums', 'quiet recorded snare taps', -24, .08)
    a = 'G4:.5 r:.5 B4:.5 D5:.5 r:2 | C5:.5 B4:.5 A4:1 r:2 | G4:.5 D4:.5 G4:1 A4:.5 r:1.5 | B4:1 r:1 D5:.5 C5:.5 r:1'
    answer = 'r:2 D4:.5 E4:.5 G4:1 | r:1 F4:.5 E4:.5 D4:1 r:1 | r:2 E4:.5 G4:.5 A4:1 | G4:.5 r:.5 D4:1 r:2'
    b = 'D5:.5 E5:.5 G5:1 r:1 F5:.5 E5:.5 | D5:1 B4:.5 C5:.5 D5:1 r:1 | E5:.5 r:.5 D5:.5 C5:.5 B4:1 A4:1 | G4:1 r:1 D5:.5 B4:.5 r:1'
    c = 'E4:1 G4:.5 A4:.5 r:2 | C5:1 B4:1 r:2 | A4:.5 B4:.5 C5:1 r:1 D5:.5 r:.5 | B4:1 A4:1 G4:1 r:1'
    for start in (0, 8, 28):
        _line(reed, a, start, vel=76 if start != 8 else 70, gate=.64, shift=-12)
        _line(pluck, answer, start + 4, vel=65, gate=.67)
    _line(reed, b, 16, vel=79, gate=.70, shift=-12)
    _line(pluck, b, 20, vel=64, gate=.63, shift=-12)
    _line(reed, c, 24, vel=68, gate=.71, shift=-12)
    _line(reed, 'D5:.5 r:.5 B4:.5 G4:.5 r:2 | C5:.5 B4:.5 A4:1 r:2 | G4:1 D4:.5 G4:.5 A4:.5 B4:.5 r:1 | D5:1 C5:.5 B4:.5 A4:.5 r:1.5', 36, vel=70, gate=.65, shift=-12)
    symbols = 'G3:6 C3:6 G3:M D3:7 G3:6 C3:6 A3:m7 D3:7'
    for start in (0, 8, 16, 28):
        _harmony(keys, symbols, start, mode='offbeat', vel=47 if start != 16 else 54)
        _bass(low, 'G2 C3 G2 D3 G2 C3 A2 D3', start, mode='short', vel=56)
    _harmony(keys, 'E3:m7 C3:6 A3:m7 D3:7', 24, mode='held', vel=44)
    _bass(low, 'E2 C3 A2 D3', 24, mode='long', vel=50)
    _harmony(keys, 'G3:6 C3:6 A3:m7 D3:7', 36, mode='offbeat', vel=46)
    _bass(low, 'G2 C3 A2 D3', 36, mode='short', vel=53)
    # Intentionally no kick grid: a reply lands after the melodic silence.
    for bar in (1, 5, 9, 13, 17, 19, 21, 23, 29, 33, 37):
        note(drums, bar * 4 + 2.5, .14, 37, 38)
    for name, start, bars in [('question/answer', 0, 8), ('second attempt', 8, 8), ('overstatement', 16, 8), ('straight face', 24, 4), ('return', 28, 8), ('pickup', 36, 4)]:
        _section(s, name, start, bars)
    return validate(s)


def _warmth():
    s = cue('story_warmth', '火边一席（工作题）', 76, 32, (3, 4),
            category='story', theme_family='warmth', target_lufs=-24,
            intent='Companionship with room for speech; not an automatic romance cue.')
    lead = add_track(s, 'flute', 'western flute / quiet breath', -12, -.16)
    guitar = add_track(s, 'acoustic_guitar', 'three-beat shared seat', -13, .20)
    cello = add_track(s, 'cello', 'warm low replies', -15, -.06)
    a = 'E5:1 G5:.5 E5:.5 D5:.5 r:.5 | C5:1 D5:.5 E5:.5 G4:1 | A4:1 C5:.5 D5:.5 E5:.5 r:.5 | D5:1 C5:1 r:1'
    a2 = 'E5:1 G5:.5 A5:.5 G5:.5 r:.5 | E5:1 D5:.5 C5:.5 B4:1 | C5:.5 E5:.5 D5:1 B4:.5 r:.5 | C5:2 r:1'
    b = 'A5:1 G5:.5 E5:.5 F5:1 | E5:1 D5:.5 C5:.5 D5:1 | G5:.5 E5:.5 C5:1 A4:1 | D5:2 r:1'
    _line(lead, a, 0, 3, 67, .84)
    _line(lead, a2, 4, 3, 70, .85)
    _line(cello, 'C3:2 G3:1 | E3:2 r:1 | F3:1 A3:1 C4:1 | G3:2 r:1', 8, 3, 54, .87)
    _line(lead, b, 12, 3, 71, .86)
    _line(lead, a, 16, 3, 65, .83)
    _line(lead, a2, 20, 3, 68, .85)
    _line(cello, 'A3:1 C4:.5 A3:.5 G3:1 | F3:1 E3:1 r:1 | D3:1 G3:1 B3:1 | G3:2 r:1', 24, 3, 53, .88)
    _line(lead, 'E5:1 G5:.5 E5:.5 D5:.5 r:.5 | C5:1 D5:.5 E5:.5 G4:1 | A4:1 B4:.5 C5:.5 D5:1 | B4:1 G4:.5 D5:.5 r:1', 28, 3, 64, .82)
    harmonies = ['C3:6 E3:m7 F3:M G3:7 C3:6 A3:m7 D3:m7 G3:7',
                 'C3:M E3:m F3:M G3:7 F3:M C3:M D3:m7 G3:7',
                 'C3:6 E3:m7 F3:M G3:7 C3:6 A3:m7 D3:m7 G3:7',
                 'A3:m7 F3:M D3:m7 G3:7 C3:6 E3:m7 F3:M G3:7']
    for i, symbols in enumerate(harmonies):
        _harmony(guitar, symbols, i * 8, 3, 'six', 46 if i != 1 else 43)
    _bass(cello, 'C3 E3 F3 G2 C3 A2 D3 G2', 0, 3, vel=45)
    _bass(cello, 'C3 E3 F3 G2 C3 A2 D3 G2', 16, 3, vel=44)
    for name, start, bars in [('nearby voices', 0, 8), ('low reply', 8, 4), ('open window', 12, 4), ('familiar return', 16, 8), ('shared silence', 24, 4), ('turn back to the fire', 28, 4)]:
        _section(s, name, start, bars, 3)
    return validate(s)


EMMA_A = 'D5:1 A4:.5 C5:.5 E5:.5 r:.5 | F5:1 E5:.5 D5:.5 A4:1 | C5:.5 D5:.5 E5:1 G5:.5 r:.5 | F5:1 E5:.5 D5:.5 r:1'
EMMA_B = 'A5:1 G5:.5 F5:.5 E5:1 | G5:1 E5:.5 D5:.5 C5:1 | D5:.5 F5:.5 A5:1 G5:.5 E5:.5 | D5:2 r:1'
EMMA_WARY = 'D5:.5 r:.5 A4:.5 C5:.5 E5:.5 r:.5 | F5:.5 r:.5 E5:.5 D5:.5 A4:.5 r:.5 | C5:.5 D5:.5 r:.5 E5:.5 G5:.5 r:.5 | F5:.5 E5:.5 D5:1 r:1'


def _emma(wary=False):
    ident = 'character_emma_wary' if wary else 'character_emma'
    s = cue(ident, '门外的星图·戒备（工作题）' if wary else '门外的星图（工作题）',
            76 if wary else 72, 40, (3, 4), category='character',
            theme_family='emma', variant_of='character_emma' if wary else None,
            target_lufs=-24 if wary else -22,
            intent='Independent curiosity and refusal; wary version fragments the same D-A-C-E head.')
    lead = add_track(s, 'clarinet', 'Emma / D-A-C-E identity', -10, -.12)
    harp = add_track(s, 'harp', 'unfamiliar constellations', -15, .23)
    viola = add_track(s, 'viola', 'unsettled inner line', -16, -.26)
    low = add_track(s, 'cello', 'own direction', -15, -.04)
    a, b = (EMMA_WARY, EMMA_B) if wary else (EMMA_A, EMMA_B)
    _line(lead, a, 0, 3, 67 if wary else 74, .64 if wary else .88)
    _line(lead, 'E5:1 G5:.5 E5:.5 C5:1 | D5:1 A4:.5 B4:.5 C5:1 | F5:.5 E5:.5 D5:1 C5:.5 A4:.5 | C5:1 E5:1 r:1', 4, 3, 68 if wary else 72, .70 if wary else .86)
    _line(viola, 'D4:1 A3:.5 C4:.5 E4:.5 r:.5 | F4:1 E4:.5 D4:.5 A3:1 | C4:1 D4:.5 E4:.5 G4:1 | F4:1 E4:1 r:1', 8, 3, 53, .83)
    _line(lead, b, 12, 3, 73 if wary else 79, .72 if wary else .88)
    _line(lead, 'B4:1 D5:.5 E5:.5 G5:1 | F5:.5 E5:.5 D5:1 B4:1 | A4:.5 C5:.5 E5:1 D5:.5 C5:.5 | A4:2 r:1', 16, 3, 69, .76 if wary else .88)
    _line(harp, 'D5:.5 A4:.5 C5:.5 E5:.5 r:1 | F5:1 E5:.5 D5:.5 r:1 | G5:1 E5:1 C5:1 | E5:2 r:1', 20, 3, 53, .79)
    _line(lead, a, 24, 3, 72 if wary else 76, .67 if wary else .88)
    _line(lead, b, 28, 3, 74 if wary else 80, .73 if wary else .88)
    _line(viola, 'D4:1 A3:.5 C4:.5 E4:.5 r:.5 | F4:1 E4:.5 D4:.5 A3:1 | C4:1 D4:.5 E4:.5 G4:1 | F4:1 E4:1 r:1', 32, 3, 50, .79)
    _line(lead, 'D5:1 A4:.5 C5:.5 E5:.5 r:.5 | F5:1 E5:.5 D5:.5 A4:1 | G4:1 B4:.5 D5:.5 E5:1 | C5:1 A4:1 r:1', 36, 3, 66 if wary else 69, .69 if wary else .84)
    progressions = [
        'D3:m D3:m C3:M D3:m C3:M G3:6 G3:m A3:m7',
        'D3:m F3:M C3:M A3:m7 F3:M C3:M G3:m D3:m',
        'G3:6 D3:m A3:m7 A3:7 D3:m D3:m C3:M A3:7',
        'D3:m D3:m C3:M D3:m F3:M C3:M G3:m D3:m',
        'D3:m F3:M C3:M A3:m7 D3:m D3:m G3:6 A3:m7']
    roots = ['D3 D3 C3 D3 C3 G2 G2 A2', 'D3 F3 C3 A2 F3 C3 G2 D3',
             'G2 D3 A2 A2 D3 D3 C3 A2', 'D3 D3 C3 D3 F3 C3 G2 D3',
             'D3 F3 C3 A2 D3 D3 G2 A2']
    for i, symbols in enumerate(progressions):
        if wary:
            # Dyads and empty middle beats leave refusal and vigilance audible in the score.
            for j, symbol in enumerate(symbols.split()):
                tones = chord(symbol)
                voicing(harp, (tones[0], tones[2]), (i * 8 + j) * 3 + .5, .43, 45)
            _bass(low, roots[i], i * 8, 3, 'short', 49)
        else:
            _harmony(harp, symbols, i * 8, 3, 'six', 45)
            _bass(low, roots[i], i * 8, 3, 'long', 47)
    if wary:
        _line(viola, 'A3:2 r:1 | Bb3:1 A3:1 r:1 | G3:2 r:1 | E3:1 A3:1 r:1', 16, 3, 48, .75)
    else:
        _line(viola, 'F4:2 E4:1 | G4:1 E4:1 C4:1 | Bb3:2 G3:1 | E4:2 r:1', 12, 3, 51, .90)
    for name, start, bars in [('identity', 0, 8), ('inside voice', 8, 4), ('action', 12, 8), ('alone with the map', 20, 4), ('identity returns', 24, 8), ('keep own counsel', 32, 8)]:
        _section(s, name, start, bars, 3)
    return validate(s)


def _travel():
    s = cue('story_travel', '路边接话（工作题）', 82, 36, (6, 8),
            category='story', theme_family='travel', target_lufs=-23,
            intent='Two travellers take turns; a six-eighth gait with an unhurried horizon.')
    lead = add_track(s, 'clarinet', 'walking conversation', -11, -.20)
    guitar = add_track(s, 'acoustic_guitar', 'six-eighth footpath', -14, .18)
    reed = add_track(s, 'bassoon', 'companion speaks lower', -15, .12)
    bass = add_track(s, 'contrabass', 'footfalls', -17, -.03)
    a = 'G4:1 B4:.5 D5:.5 E5:.5 r:.5 | D5:1 B4:.5 A4:.5 G4:1 | B4:.5 D5:.5 G5:1 F#5:.5 E5:.5 | D5:2 r:1'
    b = 'E5:1 G5:.5 F#5:.5 E5:1 | D5:.5 B4:.5 A4:1 B4:.5 D5:.5 | C5:1 E5:.5 D5:.5 B4:1 | A4:2 r:1'
    low_answer = 'G3:1 B3:.5 D4:.5 E4:.5 r:.5 | D4:1 B3:.5 A3:.5 G3:1 | E4:.5 D4:.5 B3:1 C4:1 | A3:2 r:1'
    _line(guitar, a, 0, 3, 52, .80)
    _line(lead, a, 4, 3, 71, .85)
    _line(lead, b, 8, 3, 72, .84)
    _line(reed, low_answer, 12, 3, 60, .83)
    _line(lead, 'r:1 B4:.5 D5:.5 E5:1 | r:1 D5:.5 B4:.5 A4:1 | G5:.5 F#5:.5 E5:1 D5:1 | B4:2 r:1', 16, 3, 64, .85)
    _line(reed, 'E4:1 G4:.5 E4:.5 D4:1 | C4:1 B3:.5 A3:.5 G3:1 | A3:.5 C4:.5 E4:1 F#4:.5 E4:.5 | D4:2 r:1', 20, 3, 59, .83)
    _line(lead, a, 24, 3, 73, .85)
    _line(lead, 'E5:1 G5:.5 A5:.5 G5:.5 r:.5 | F#5:1 E5:.5 D5:.5 B4:1 | C5:.5 E5:.5 D5:1 A4:1 | G4:2 r:1', 28, 3, 70, .86)
    _line(reed, 'G3:1 B3:.5 D4:.5 E4:1 | D4:1 B3:1 r:1 | A3:1 C4:.5 E4:.5 G4:1 | F#4:1 D4:1 r:1', 32, 3, 55, .83)
    harmonies = ['G3:6 E3:m C3:M D3:7',
                 'G3:6 E3:m C3:M D3:7 E3:m G3:M A3:m7 D3:7',
                 'G3:M E3:m C3:M D3:7 E3:m C3:M A3:m7 D3:7',
                 'C3:M G3:M A3:m7 D3:7',
                 'G3:6 E3:m C3:M D3:7 E3:m G3:M A3:m7 G3:M',
                 'G3:6 E3:m A3:m7 D3:7']
    starts = (0, 4, 12, 20, 24, 32)
    for symbols, start in zip(harmonies, starts):
        _harmony(guitar, symbols, start, 3, 'six', 42 if start in (12, 20) else 46)
    for start, roots in [(0, 'G2 E2 C3 D3'), (4, 'G2 E2 C3 D3 E2 G2 A2 D3'),
                         (12, 'G2 E2 C3 D3 E2 C3 A2 D3'), (20, 'C3 G2 A2 D3'),
                         (24, 'G2 E2 C3 D3 E2 G2 A2 G2'), (32, 'G2 E2 A2 D3')]:
        _bass(bass, roots, start, 3, 'two', 47)
    for name, start, bars in [('guitar walks first', 0, 4), ('wide road', 4, 8), ('another voice', 12, 8), ('bend in the path', 20, 4), ('road returns', 24, 8), ('next conversation', 32, 4)]:
        _section(s, name, start, bars, 3)
    return validate(s)


def _tension():
    s = cue('story_tension', '门闩未落（工作题）', 88, 28,
            category='story', theme_family='tension', target_lufs=-24,
            intent='A three-note question gets closer; rests carry the threat, not a wall of sound.')
    lead = add_track(s, 'oboe', 'three-note warning', -13, -.12)
    keys = add_track(s, 'piano', 'separated low-mid attacks', -16, .18)
    cello = add_track(s, 'cello', 'D / C pedal', -18, -.08)
    shade = add_track(s, 'viola', 'held doubt', -21, -.28)
    a = 'A4:.5 Bb4:.5 E5:1 r:2 | D5:1 C#5:.5 D5:.5 r:2 | r:1 A4:.5 Bb4:.5 E5:1 F5:.5 r:.5 | E5:1 C#5:1 r:2'
    _line(lead, a, 0, vel=65, gate=.77)
    _line(lead, a, 8, vel=69, gate=.73)
    _line(lead, 'E5:.5 F5:.5 Bb5:1 A5:.5 G5:.5 E5:1 | F5:1 E5:.5 D5:.5 C#5:1 r:1 | D5:.5 E5:.5 F5:1 Bb4:1 A4:1 | C#5:1 E5:1 r:2', 12, vel=76, gate=.76)
    _line(lead, 'A4:1 Bb4:1 E5:1 r:1 | D5:1 C#5:1 r:2 | E5:.5 F5:.5 E5:1 Bb4:1 A4:1 | C#5:2 r:2', 20, vel=66, gate=.79)
    _line(lead, 'A4:.5 Bb4:.5 E5:1 r:2 | F5:1 E5:1 D5:.5 r:1.5 | Bb4:1 A4:1 C#5:1 r:1 | E5:1 r:3', 24, vel=61, gate=.73)
    _line(shade, 'F3:3 r:1 | E3:2 r:2 | F3:3 r:1 | E3:2 r:2', 4, vel=43, gate=.94)
    _line(shade, 'G3:3 r:1 | F3:3 r:1 | E3:2 Bb3:1 r:1 | A3:2 r:2', 16, vel=46, gate=.91)
    symbols = 'D3:m Bb2:M D3:m A2:7 D3:m C3:M Bb2:M A2:7 D3:m Bb2:M D3:m A2:7 G3:m D3:m Bb2:M A2:7 G3:m F3:M B2:dim A2:7 D3:m Bb2:M G3:m A2:7 D3:m Bb2:M G3:m A2:7'
    for i, symbol in enumerate(symbols.split()):
        tones = chord(symbol)
        note(keys, i * 4 + .5, .62, tones[0], 43 + (6 if 12 <= i < 16 else 0))
        voicing(keys, tones[1:], i * 4 + 2.75, .48, 42)
    _bass(cello, 'D2 D2 C3 A2 D2 D2 C3 A2 D2 D2 C3 A2 G2 D3 Bb2 A2 G2 F2 B2 A2 D2 Bb2 G2 A2 D2 Bb2 G2 A2', meter=4, vel=42)
    for name, start, bars in [('outside', 0, 4), ('no answer', 4, 4), ('closer', 8, 4), ('movement', 12, 4), ('hold breath', 16, 4), ('listen again', 20, 8)]:
        _section(s, name, start, bars)
    return validate(s)


def _aftermath():
    s = cue('story_aftermath', '尚未说完（工作题）', 68, 24,
            category='story', theme_family='aftermath', target_lufs=-25,
            intent='Consequences remain present; the closing dominant opens a question rather than forgiveness.')
    lead = add_track(s, 'oboe', 'remaining words', -14, -.18)
    piano = add_track(s, 'piano', 'spaced aftermath', -17, .18)
    cello = add_track(s, 'cello', 'weight without melodrama', -19, -.03)
    a = 'E5:2 D5:1 r:1 | C5:1 B4:.5 A4:.5 G4:1 r:1 | A4:2 C5:1 B4:1 | E4:2 r:2'
    _line(lead, a, 0, vel=62, gate=.88)
    _line(piano, 'E4:2 D4:1 r:1 | C4:1 B3:.5 A3:.5 G3:1 r:1 | A3:2 C4:1 B3:1 | E3:2 r:2', 4, vel=48, gate=.86)
    _line(lead, 'G5:2 E5:1 D5:1 | C5:2 A4:1 r:1 | F5:1 E5:1 D5:1 C5:1 | B4:3 r:1', 8, vel=66, gate=.91)
    _line(cello, 'A3:2 C4:1 B3:1 | G3:2 E3:1 r:1 | F3:1 A3:1 C4:1 B3:1 | E3:3 r:1', 12, vel=49, gate=.90)
    _line(lead, a, 16, vel=60, gate=.89)
    _line(lead, 'C5:2 B4:1 A4:1 | G4:2 E4:1 r:1 | F4:1 A4:1 B4:1 C5:1 | B4:2 r:2', 20, vel=57, gate=.86)
    for at, tones, dur in [(0, ['A3','C4','E4'], 3), (8, ['F3','A3','C4'], 3), (12, ['E3','G#3','D4'], 2),
                           (32, ['C3','E3','G3'], 3), (40, ['D3','F3','A3'], 3), (44, ['E3','G#3','D4'], 2),
                           (64, ['A3','C4','E4'], 3), (72, ['F3','A3','C4'], 3), (80, ['F3','A3','C4'], 3),
                           (88, ['D3','F3','A3'], 2.5), (92, ['E3','G#3','B3'], 2.2)]:
        voicing(piano, tones, at + .3, dur, 42, .04)
    _bass(cello, 'A2 - F2 E2', 0, vel=41)
    _bass(cello, 'C3 - D3 E2', 8, vel=41)
    _bass(cello, 'A2 - F2 E2 F2 C3 D3 E2', 16, vel=39)
    for name, start, bars in [('unanswered', 0, 4), ('empty chair', 4, 4), ('words rise', 8, 4), ('weight below', 12, 4), ('what remains', 16, 8)]:
        _section(s, name, start, bars)
    return validate(s)


def _confrontation():
    s = cue('story_confrontation', '立在门前（工作题）', 84, 32,
            category='story', theme_family='confrontation', target_lufs=-23,
            intent='Ceremonial distance: long brass statements answered by a low reed, no combat drum grid.')
    horn = add_track(s, 'horn', 'formal statement', -12, -.16)
    reed = add_track(s, 'bassoon', 'opposing reply', -13, .17)
    viola = add_track(s, 'viola', 'closed chamber', -18, -.27, voicing_floor=48)
    cello = add_track(s, 'cello', 'ground', -16, -.04)
    a = 'D4:1.5 A4:.5 F4:1 r:1 | E4:1 D4:1 C4:1 A3:1 | Bb3:1 D4:.5 F4:.5 G4:1 A4:1 | E4:2 r:2'
    b = 'F4:1.5 C5:.5 A4:1 G4:1 | F4:1 E4:1 D4:1 r:1 | Bb4:1 A4:.5 G4:.5 F4:1 E4:1 | D4:2 A3:1 r:1'
    _line(horn, a, 0, vel=72, gate=.89)
    _line(reed, a, 4, vel=63, gate=.84, shift=-12)
    _line(horn, b, 8, vel=77, gate=.90)
    _line(reed, 'G3:1.5 D4:.5 Bb3:1 A3:1 | F3:1 A3:1 C4:1 D4:1 | E4:1 F4:.5 E4:.5 D4:1 C#4:1 | A3:3 r:1', 12, vel=65, gate=.88)
    _line(cello, 'D3:2 A2:1 F3:1 | E3:1 D3:1 C3:1 A2:1 | Bb2:1 D3:1 G3:1 F3:1 | E3:2 r:2', 16, vel=53, gate=.91)
    _line(horn, a, 20, vel=71, gate=.89)
    _line(horn, b, 24, vel=78, gate=.90)
    _line(reed, 'D3:1.5 A3:.5 F3:1 r:1 | C4:1 Bb3:1 A3:1 G3:1 | E3:1 G3:1 Bb3:1 C#4:1 | A3:2 r:2', 28, vel=60, gate=.84)
    harmonies = ['D3:m C3:M Bb2:M A2:7', 'D3:m C3:M G2:m A2:7', 'F3:M D3:m G3:m A2:7',
                 'G2:m F3:M B2:dim A2:7', 'D3:m C3:M Bb2:M A2:7', 'D3:m C3:M Bb2:M A2:7',
                 'F3:M D3:m G3:m A2:7', 'D3:m C3:M B2:dim A2:7']
    for i, symbols in enumerate(harmonies):
        _harmony(viola, symbols, i * 4, mode='held', vel=43 if i == 4 else 48)
    _bass(cello, 'D2 C3 Bb2 A2 D2 C3 G2 A2 F2 D3 G2 A2 G2 F2 B2 A2', vel=47)
    _bass(cello, 'D2 C3 Bb2 A2 F2 D3 G2 A2 D2 C3 B2 A2', 20, vel=47)
    for name, start, bars in [('first claim', 0, 4), ('reply', 4, 4), ('larger claim', 8, 4), ('counterclaim', 12, 4), ('unoccupied centre', 16, 4), ('return to terms', 20, 8), ('still opposed', 28, 4)]:
        _section(s, name, start, bars)
    return validate(s)


def _intrigue():
    s = cue('story_intrigue', '隔屏的棋子（工作题）', 88, 36, (3, 4),
            category='story', theme_family='intrigue', target_lufs=-24,
            intent='A concealed answer crosses the bar line; harpsichord figures remain incomplete.')
    keys = add_track(s, 'harpsichord', 'unfinished mechanism', -16, .23)
    lead = add_track(s, 'clarinet', 'partial information', -13, -.20)
    pizz = add_track(s, 'pizzicato', 'off-centre shadow', -17, .06)
    reed = add_track(s, 'bassoon', 'lower inference', -16, -.12)
    a = 'r:.5 E5:.5 F5:.5 E5:.5 C5:.5 r:.5 | B4:1 D5:.5 C5:.5 B4:1 | r:1 A4:.5 C5:.5 E5:.5 G#5:.5 | E5:1 B4:1 r:1'
    _line(lead, a, 4, 3, 66, .72)
    _line(reed, 'r:.5 E4:.5 F4:.5 E4:.5 C4:.5 r:.5 | B3:1 D4:.5 C4:.5 B3:1 | A3:1 C4:1 E4:.5 G#4:.5 | E4:1 B3:1 r:1', 8, 3, 56, .75)
    _line(lead, 'G5:1 E5:.5 D5:.5 C5:1 | B4:.5 C5:.5 D5:1 F5:1 | E5:.5 F5:.5 G#5:1 A5:.5 G#5:.5 | E5:2 r:1', 12, 3, 72, .76)
    _line(lead, 'r:1 A4:.5 C5:.5 E5:.5 r:.5 | F5:.5 E5:.5 D5:.5 C5:.5 B4:1 | r:1 D5:.5 C5:.5 B4:.5 G#4:.5 | A4:1 r:2', 20, 3, 63, .74)
    _line(reed, 'C4:1 E4:.5 F4:.5 E4:.5 r:.5 | D4:1 C4:.5 B3:.5 G#3:1 | B3:.5 D4:.5 F4:1 E4:1 | G#3:2 r:1', 24, 3, 55, .77)
    _line(lead, a, 28, 3, 65, .72)
    _line(lead, 'F5:1 E5:.5 C5:.5 B4:1 | D5:.5 C5:.5 B4:1 A4:.5 r:.5 | F5:.5 E5:.5 D5:1 B4:1 | G#4:1 E5:1 r:1', 32, 3, 62, .72)
    symbols = 'A3:m E3:7 A3:m E3:7 A3:m G3:7 A3:m E3:7 A3:m G3:7 A3:m E3:7 C4:M G3:7 E3:7 E3:7 A3:m E3:7 F3:M E3:7 A3:m D3:m6 B3:dim E3:7 C4:M E3:7 B3:dim E3:7 A3:m G3:7 A3:m E3:7 F3:M D3:m6 B3:dim E3:7'
    for i, symbol in enumerate(symbols.split()):
        tones = chord(symbol)
        # A rest at the expected last eighth is part of the motif, not random dropout.
        for offset, idx in ((.5, 0), (1, 2), (1.5, 1), (2, 2)):
            note(keys, i * 3 + offset, .26, tones[idx], 42 + (4 if i < 4 else 0))
        if i not in (16, 17, 18, 19):
            # This sound is a violin section, so the bassoon owns the low answer.
            first, fifth = tones[0], tones[2]
            first += 12 * max(0, (55 - first + 11) // 12)
            fifth += 12 * max(0, (55 - fifth + 11) // 12)
            note(pizz, i * 3, .3, first, 44)
            note(pizz, i * 3 + 2.5, .25, fifth, 39)
    _line(reed, 'A3:2 r:1 | G#3:2 r:1 | F3:1 A3:1 C4:1 | B3:1 G#3:1 r:1', 16, 3, 50, .85)
    for name, start, bars in [('closed screen', 0, 4), ('one clue', 4, 4), ('another reading', 8, 4), ('possible plan', 12, 4), ('missing piece', 16, 4), ('second clue', 20, 8), ('conceal again', 28, 8)]:
        _section(s, name, start, bars, 3)
    return validate(s)


def _discovery():
    s = cue('story_discovery', '窗后还有天（工作题）', 96, 28,
            category='story', theme_family='discovery', target_lufs=-23,
            intent='A motif migrates from pitched percussion to breath; discovery is expansion, not a victory fanfare.')
    mallet = add_track(s, 'vibraphone', 'first glint', -13, .16)
    flute = add_track(s, 'flute', 'western flute / horizon', -12, -.18)
    harp = add_track(s, 'harp', 'frame', -17, .26)
    bass = add_track(s, 'contrabass', 'ground opens slowly', -18, -.04)
    a = 'D5:.5 A5:.5 F#5:1 E5:.5 D5:.5 r:1 | B4:1 D5:.5 E5:.5 F#5:1 r:1 | A5:1 F#5:.5 E5:.5 D5:1 B4:1 | E5:2 r:2'
    _line(mallet, a, 0, vel=67, gate=.72)
    _line(flute, a, 4, vel=70, gate=.87)
    _line(flute, 'F#5:1 A5:.5 B5:.5 A5:1 G5:1 | F#5:1 E5:.5 D5:.5 C#5:1 r:1 | D5:.5 E5:.5 F#5:1 A5:1 F#5:1 | E5:2 r:2', 8, vel=74, gate=.88)
    _line(mallet, 'D6:1 A5:1 F#5:1 r:1 | E5:1 B5:1 G5:1 r:1 | D5:.5 A5:.5 F#5:.5 E5:.5 D5:1 B4:1 | C#5:1 E5:1 A5:1 r:1', 12, vel=58, gate=.70)
    _line(flute, 'B5:1 A5:1 F#5:.5 E5:.5 D5:1 | G5:1 F#5:.5 E5:.5 D5:1 B4:1 | E5:.5 F#5:.5 G5:1 B5:1 A5:1 | F#5:2 E5:1 r:1', 16, vel=75, gate=.88)
    _line(mallet, a, 20, vel=63, gate=.73)
    _line(flute, 'D5:.5 A5:.5 F#5:1 E5:.5 D5:.5 r:1 | B4:1 D5:.5 E5:.5 F#5:1 r:1 | G5:1 F#5:.5 E5:.5 D5:1 B4:1 | C#5:1 E5:1 A4:1 r:1', 24, vel=67, gate=.86)
    symbols = 'D3:add9 G3:M D3:M A3:sus4 D3:M B3:m G3:M A3:7 B3:m G3:M D3:M A3:7 D3:M E3:m G3:M A3:7 B3:m G3:M E3:m A3:7 D3:add9 G3:M D3:M A3:7 D3:M B3:m G3:M A3:7'
    for i, symbol in enumerate(symbols.split()):
        if 12 <= i < 16:
            continue
        _harmony(harp, symbol, i, mode='broken', vel=43)
    _bass(bass, 'D3 - G2 A2 D3 B2 G2 A2 B2 G2 D3 A2', vel=44)
    _bass(bass, 'B2 G2 E3 A2 D3 G2 D3 A2 D3 B2 G2 A2', 16, vel=45)
    for name, start, bars in [('glint', 0, 4), ('recognise', 4, 4), ('open space', 8, 4), ('look alone', 12, 4), ('wider than expected', 16, 4), ('glint returns', 20, 4), ('keep looking', 24, 4)]:
        _section(s, name, start, bars)
    return validate(s)


def _resolve():
    s = cue('story_resolve', '迈出这一程（工作题）', 100, 32,
            category='story', theme_family='resolve', target_lufs=-22,
            intent='A measured decision becomes action; an ascending fourth is answered by a stepwise return.')
    brass = add_track(s, 'trumpet', 'decision', -13, -.10)
    viola = add_track(s, 'viola', 'following through', -15, -.24)
    guitar = add_track(s, 'acoustic_guitar', 'forward quarters', -17, .21)
    cello = add_track(s, 'cello', 'steady ground', -17, -.04)
    drum = add_track(s, 'drums', 'quiet commitment', -25, .10)
    a = 'C5:1 F5:1 A5:.5 G5:.5 F5:1 | E5:1 D5:.5 C5:.5 D5:1 r:1 | F5:1 A5:.5 C6:.5 Bb5:1 A5:1 | G5:2 r:2'
    _line(viola, a, 0, vel=57, gate=.87, shift=-12)
    _line(brass, a, 4, vel=72, gate=.82)
    _line(brass, 'A5:1 G5:.5 F5:.5 E5:1 D5:1 | F5:.5 G5:.5 A5:1 C6:1 Bb5:1 | A5:1 F5:.5 E5:.5 D5:1 G5:1 | E5:2 C5:1 r:1', 8, vel=76, gate=.84)
    _line(viola, 'D4:1 A4:1 F4:.5 E4:.5 D4:1 | G4:1 F4:.5 E4:.5 D4:1 C4:1 | Bb3:1 D4:.5 F4:.5 A4:1 G4:1 | E4:2 r:2', 12, vel=61, gate=.87)
    _line(brass, 'C5:2 F5:1 A5:1 | G5:1 E5:1 D5:1 C5:1 | D5:1 F5:1 A5:1 Bb5:1 | G5:2 r:2', 16, vel=68, gate=.86)
    _line(brass, a, 20, vel=78, gate=.83)
    _line(brass, 'A5:1 C6:.5 Bb5:.5 A5:1 G5:1 | F5:.5 G5:.5 A5:1 C6:1 Bb5:1 | A5:1 G5:.5 F5:.5 D5:1 E5:1 | F5:3 r:1', 24, vel=80, gate=.85)
    _line(viola, 'C4:1 F4:1 A4:.5 G4:.5 F4:1 | E4:1 D4:1 C4:1 r:1 | Bb3:1 D4:1 F4:1 A4:1 | E4:1 G4:1 C4:1 r:1', 28, vel=58, gate=.85)
    symbols = 'F3:M C3:M Bb2:M C3:7 F3:M D3:m Bb2:M C3:7 D3:m F3:M Bb2:M C3:7 D3:m G3:m Bb2:M C3:7 F3:M C3:M D3:m C3:7 F3:M D3:m Bb2:M C3:7 D3:m F3:M G3:m F3:M F3:M C3:M Bb2:M C3:7'
    _harmony(guitar, symbols, mode='broken', vel=44)
    roots = 'F2 C3 Bb2 C3 F2 D3 Bb2 C3 D3 F2 Bb2 C3 D3 G2 Bb2 C3 F2 C3 D3 C3 F2 D3 Bb2 C3 D3 F2 G2 F2 F2 C3 Bb2 C3'
    _bass(cello, roots, mode='two', vel=48)
    for bar in list(range(4, 12)) + list(range(20, 28)):
        for offset in (1, 3):
            note(drum, bar * 4 + offset, .12, 37, 38)
        note(drum, bar * 4, .18, 36, 37)
    for name, start, bars in [('say it quietly', 0, 4), ('state decision', 4, 8), ('reckon with cost', 12, 4), ('choose again', 16, 4), ('act', 20, 8), ('continue onward', 28, 4)]:
        _section(s, name, start, bars)
    return validate(s)


def _solitude():
    s = cue('story_solitude', '各自的远方（工作题）', 64, 24,
            category='story', theme_family='solitude', target_lufs=-25,
            intent='Solo guitar and long gaps; solitude retains agency rather than asking for rescue.')
    guitar = add_track(s, 'acoustic_guitar', 'a line carried alone', -12, -.12)
    oboe = add_track(s, 'oboe', 'distant reply', -17, .19)
    bass = add_track(s, 'contrabass', 'occasional horizon', -22, -.02)
    a = 'E4:1 A4:1 B4:.5 C5:.5 E5:1 | D5:2 C5:1 r:1 | B4:1 G4:1 A4:1 C5:1 | E4:2 r:2'
    _line(guitar, a, 0, vel=58, gate=.83)
    _line(guitar, 'E4:1 A4:1 C5:1 E5:1 | G5:1 E5:.5 D5:.5 C5:1 r:1 | D5:1 B4:.5 A4:.5 G4:1 E4:1 | G#4:2 r:2', 4, vel=61, gate=.84)
    _line(oboe, 'A4:2 E5:1 D5:1 | C5:2 A4:1 r:1 | G4:1 B4:1 D5:1 C5:1 | B4:2 r:2', 8, vel=57, gate=.90)
    _line(guitar, 'F4:1 A4:.5 C5:.5 E5:1 D5:1 | C5:1 A4:1 G4:1 E4:1 | D4:1 F4:1 B4:1 A4:1 | G#4:2 r:2', 12, vel=54, gate=.82)
    _line(guitar, a, 16, vel=57, gate=.84)
    _line(oboe, 'E5:2 C5:1 A4:1 | G4:2 E4:1 r:1 | F4:1 A4:1 B4:1 C5:1 | G#4:2 r:2', 20, vel=53, gate=.89)
    for bar, tones in [(0,['A2','E3']), (2,['G2','D3']), (4,['A2','E3']), (6,['G2','D3']),
                       (8,['A2','E3']), (10,['G2','D3']), (12,['F2','C3']), (14,['D3','A3']),
                       (16,['A2','E3']), (18,['G2','D3']), (20,['F2','C3']), (22,['D3','A3'])]:
        voicing(guitar, tones, bar * 4 + .12, 2.8, 39, .08)
    for bar, root in [(0,'A2'), (3,'E2'), (8,'A2'), (11,'E2'), (16,'A2'), (19,'E2'), (23,'E2')]:
        note(bass, bar * 4, 2.7, root, 35)
    for name, start, bars in [('own road', 0, 8), ('a far reply', 8, 4), ('keep walking', 12, 4), ('recognise own steps', 16, 4), ('distance remains', 20, 4)]:
        _section(s, name, start, bars)
    return validate(s)


def _banter():
    s = cue('story_banter', '你一句我半句（工作题）', 105, 36, (3, 4),
            category='story', theme_family='banter', target_lufs=-23,
            intent='Two equal speakers interrupt and then listen; no ridicule by random pitches.')
    clarinet = add_track(s, 'clarinet', 'first speaker', -12, -.28)
    flute = add_track(s, 'flute', 'western flute / second speaker', -12, .28)
    pizz = add_track(s, 'pizzicato', 'dry violin three-beat pulse', -17, .02, voicing_floor=55)
    bass = add_track(s, 'contrabass', 'shared ground', -18, -.02)
    a = 'F5:.5 Bb5:.5 A5:.5 F5:.5 r:1 | G5:.5 F5:.5 D5:1 r:1 | F5:.5 Bb5:.5 C6:1 A5:.5 r:.5 | G5:1 F5:.5 D5:.5 r:1'
    answer = 'r:1 D5:.5 F5:.5 G5:1 | r:.5 F5:.5 Eb5:.5 D5:.5 C5:1 | r:1 Eb5:.5 G5:.5 A5:1 | F5:.5 D5:.5 C5:1 r:1'
    for start, vel in [(0,70), (8,72), (24,69)]:
        _line(clarinet, a, start, 3, vel, .69)
        _line(flute, answer, start + 4, 3, vel - 2, .72)
    _line(flute, 'D5:.5 F5:.5 Bb5:1 A5:.5 G5:.5 | F5:1 D5:.5 Eb5:.5 F5:1 | Eb5:.5 G5:.5 C6:1 Bb5:.5 A5:.5 | G5:1 F5:1 r:1', 16, 3, 74, .78)
    _line(clarinet, 'D5:1 F5:.5 G5:.5 Bb5:1 | A5:.5 G5:.5 F5:1 D5:1 | Eb5:1 G5:.5 A5:.5 C6:1 | A5:1 F5:1 r:1', 20, 3, 73, .76)
    _line(clarinet, 'F5:.5 Bb5:.5 A5:.5 F5:.5 r:1 | r:1 D5:.5 F5:.5 G5:1 | Eb5:1 D5:.5 C5:.5 Bb4:1 | A4:1 C5:1 r:1', 32, 3, 65, .71)
    _line(flute, 'r:1 D5:.5 F5:.5 G5:1 | F5:.5 D5:.5 C5:1 r:1 | r:1 Eb5:.5 G5:.5 F5:1 | C5:1 A4:1 r:1', 32, 3, 63, .72)
    symbols = 'Bb3:6 G3:m Eb3:M F3:7 Bb3:6 G3:m C3:m7 F3:7 Bb3:6 G3:m Eb3:M F3:7 Bb3:6 G3:m C3:m7 F3:7 Bb3:M G3:m C3:m7 F3:7 G3:m D3:m Eb3:M F3:7 Bb3:6 G3:m Eb3:M F3:7 Bb3:6 G3:m C3:m7 F3:7 Bb3:6 G3:m Eb3:M F3:7'
    _harmony(pizz, symbols, meter=3, mode='waltz', vel=42)
    _bass(bass, 'Bb2 G2 Eb3 F2 Bb2 G2 C3 F2 Bb2 G2 Eb3 F2 Bb2 G2 C3 F2 Bb2 G2 C3 F2 G2 D3 Eb3 F2 Bb2 G2 Eb3 F2 Bb2 G2 C3 F2 Bb2 G2 Eb3 F2', meter=3, mode='short', vel=45)
    for name, start, bars in [('first / second', 0, 8), ('second round', 8, 8), ('the other takes lead', 16, 4), ('listen then reply', 20, 4), ('familiar disagreement', 24, 8), ('speak together briefly', 32, 4)]:
        _section(s, name, start, bars, 3)
    return validate(s)


def _remembrance():
    s = cue('story_remembrance', '旧事未冷（工作题）', 66, 28,
            category='story', theme_family='remembrance', target_lufs=-25,
            intent='A piano recollection returns through viola with changed weight, not a generic sadness pad.')
    keys = add_track(s, 'piano', 'recalled contour', -13, .10)
    viola = add_track(s, 'viola', 'memory becomes a voice', -15, -.24)
    cello = add_track(s, 'cello', 'past beneath present', -20, -.02)
    a = 'G4:1 D5:1 Bb4:.5 A4:.5 G4:1 | F4:2 D4:1 r:1 | Eb4:1 G4:.5 A4:.5 Bb4:1 D5:1 | A4:2 r:2'
    _line(keys, a, 0, vel=58, gate=.83)
    _line(keys, 'D5:1 G5:1 F5:.5 D5:.5 Bb4:1 | A4:1 G4:1 F4:1 D4:1 | Eb4:.5 G4:.5 Bb4:1 A4:1 G4:1 | F#4:2 r:2', 4, vel=61, gate=.84)
    _line(viola, a, 8, vel=59, gate=.91, shift=-12)
    _line(viola, 'Bb3:2 D4:1 G4:1 | F4:2 Eb4:1 D4:1 | C4:1 Eb4:1 G4:1 F4:1 | D4:3 r:1', 12, vel=64, gate=.92)
    _line(keys, 'G4:2 D5:1 Bb4:1 | A4:2 G4:1 r:1 | Eb4:2 Bb4:1 A4:1 | F#4:2 r:2', 16, vel=52, gate=.85)
    _line(viola, a, 20, vel=57, gate=.90, shift=-12)
    _line(keys, 'G4:1 D5:1 Bb4:.5 A4:.5 G4:1 | F4:1 D4:1 Bb3:1 r:1 | Eb4:1 G4:1 A4:1 Bb4:1 | F#4:1 D4:1 r:2', 24, vel=53, gate=.82)
    for bar, symbol in enumerate('G2:m F2:M Eb3:M D3:7 G2:m Bb2:M C3:m D3:7 G2:m F2:M Eb3:M D3:7 Bb2:M Eb3:M C3:m D3:7 G2:m F2:M Eb3:M D3:7 G2:m F2:M Eb3:M D3:7 G2:m Bb2:M C3:m D3:7'.split()):
        tones = chord(symbol)
        voicing(keys, tones, bar * 4 + .10, 2.8 if bar % 2 == 0 else 1.9, 35, .03)
        if bar % 2 == 0 or bar >= 24:
            note(cello, bar * 4, 3.25, tones[0] - (12 if tones[0] > 48 else 0), 39)
    for name, start, bars in [('recalled detail', 0, 8), ('another perspective', 8, 4), ('whole scene', 12, 4), ('time between', 16, 4), ('same detail changed', 20, 4), ('present returns', 24, 4)]:
        _section(s, name, start, bars)
    return validate(s)


LINGQI_A = 'D5:1 G5:1 F5:.5 D5:.5 Bb4:1 | C5:.5 D5:.5 G4:1 Bb4:1 r:1 | D5:1 F5:.5 G5:.5 A5:1 Bb5:1 | A5:1 F5:1 D5:1 r:1'
LINGQI_B = 'G5:1 Bb5:.5 A5:.5 G5:1 F5:1 | Eb5:1 D5:.5 C5:.5 Bb4:1 r:1 | C5:1 Eb5:.5 G5:.5 F5:1 D5:1 | A4:2 D5:1 r:1'


def _lingqi(aftermath=False):
    if aftermath:
        s = cue('character_lingqi_aftermath', '独立的旗·余后（工作题）', 64, 32,
                category='character', theme_family='lingqi', variant_of='character_lingqi',
                target_lufs=-25, intent='Same proud D-G-F-D-Bb contour in augmentation; no forgiveness or romantic cadence.')
        lead = add_track(s, 'oboe', 'agency survives / augmented theme', -14, -.16)
        keys = add_track(s, 'piano', 'unfilled space', -18, .18)
        low = add_track(s, 'cello', 'weight', -20, -.03)
        # Exactly the opening pitch sequence of LINGQI_A, stretched over eight bars.
        augmented = 'D5:2 G5:2 | F5:1 D5:1 Bb4:2 | C5:1 D5:1 G4:2 | Bb4:2 r:2 | D5:2 F5:1 G5:1 | A5:2 Bb5:2 | A5:2 F5:2 | D5:2 r:2'
        _line(lead, augmented, 0, vel=60, gate=.90)
        _line(low, 'D3:2 G3:2 | F3:1 D3:1 Bb2:2 | C3:1 D3:1 G2:2 | Bb2:2 r:2', 8, vel=48, gate=.90)
        _line(lead, 'G5:2 Bb5:1 A5:1 | G5:2 F5:2 | Eb5:2 D5:1 C5:1 | Bb4:2 r:2', 12, vel=64, gate=.91)
        _line(lead, augmented, 16, vel=61, gate=.91)
        _line(lead, 'C5:2 Eb5:1 G5:1 | F5:2 D5:2 | A4:2 D5:2 | r:4', 24, vel=59, gate=.88)
        _line(low, 'D3:2 G3:2 | F3:1 D3:1 Bb2:2 | C3:1 D3:1 G2:2 | A2:2 r:2', 28, vel=45, gate=.86)
        harmonies = 'G2:m G2:m C3:m Eb3:M G2:m Eb3:M D3:m D3:7 G2:m F2:M C3:m Eb3:M Eb3:M Bb2:M C3:m D3:7 G2:m G2:m C3:m Eb3:M G2:m Eb3:M D3:m D3:7 C3:m G2:m D3:7 - G2:m F2:M C3:m D3:7'
        for bar, symbol in enumerate(harmonies.split()):
            if symbol == '-':
                continue
            tones = chord(symbol)
            if bar % 2 == 0 or bar in (7,15,23,31):
                voicing(keys, tones, bar * 4 + .35, 2.35, 36, .04)
            if bar < 8 or 12 <= bar < 28:
                note(low, bar * 4, 3.1, tones[0] - (12 if tones[0] > 48 else 0), 37)
        for name, start, bars in [('theme bears weight', 0, 8), ('low recollection', 8, 4), ('pride remains', 12, 4), ('theme returns', 16, 8), ('not settled', 24, 4), ('own course', 28, 4)]:
            _section(s, name, start, bars)
        return validate(s)
    s = cue('character_lingqi', '独立的旗（工作题）', 88, 40,
            category='character', theme_family='lingqi', target_lufs=-22,
            intent='Pride and an independent course: a fourth up, a falling third, a refusal to drift into a love theme.')
    oboe = add_track(s, 'oboe', 'personal direction', -11, -.17)
    horn = add_track(s, 'horn', 'public resolve', -14, .17)
    pluck = add_track(s, 'pizzicato', 'violin movement under control', -17, -.24, voicing_floor=55)
    cello = add_track(s, 'cello', 'own ground', -17, -.02)
    drum = add_track(s, 'drums', 'orchestral bass drum / sparse punctuation', -25, .06)
    _line(oboe, LINGQI_A, 0, vel=76, gate=.87)
    _line(oboe, LINGQI_B, 4, vel=77, gate=.88)
    _line(horn, LINGQI_A, 8, vel=64, gate=.86, shift=-12)
    _line(oboe, 'Bb5:1 A5:.5 G5:.5 F5:1 D5:1 | Eb5:.5 F5:.5 G5:1 Bb5:1 A5:1 | G5:1 F5:1 Eb5:.5 D5:.5 C5:1 | D5:2 r:2', 12, vel=80, gate=.88)
    _line(cello, 'D3:1 G3:1 F3:.5 D3:.5 Bb2:1 | C3:.5 D3:.5 G2:1 Bb2:1 r:1 | D3:1 F3:.5 G3:.5 A3:1 Bb3:1 | A3:1 F3:1 D3:1 r:1', 16, vel=55, gate=.88)
    _line(oboe, 'D5:2 G5:1 F5:1 | Eb5:1 D5:1 Bb4:1 r:1 | C5:1 Eb5:.5 G5:.5 F5:1 D5:1 | A4:2 D5:1 r:1', 20, vel=68, gate=.90)
    _line(oboe, LINGQI_A, 24, vel=79, gate=.88)
    _line(horn, LINGQI_B, 28, vel=67, gate=.87, shift=-12)
    _line(oboe, 'D5:1 G5:1 Bb5:.5 A5:.5 G5:1 | F5:1 D5:.5 C5:.5 Bb4:1 r:1 | C5:.5 D5:.5 Eb5:1 G5:1 F5:1 | D5:2 G5:1 r:1', 32, vel=78, gate=.87)
    _line(horn, 'D4:1 G4:1 F4:.5 D4:.5 Bb3:1 | C4:.5 D4:.5 G3:1 Bb3:1 r:1 | Eb4:1 C4:1 A3:1 D4:1 | F#4:1 D4:1 r:2', 36, vel=60, gate=.84)
    symbols = ['G3:m C3:m Eb3:M D3:m G3:m Eb3:M C3:m D3:7',
               'G3:m C3:m Eb3:M D3:m Eb3:M C3:m D3:m7 G3:m',
               'G3:m C3:m Eb3:M D3:m G3:m Eb3:M C3:m D3:7',
               'G3:m C3:m Eb3:M D3:7 G3:m Eb3:M C3:m D3:7',
               'G3:m Eb3:M C3:m G3:m G3:m C3:m A3:dim D3:7']
    roots = ['G2 C3 Eb3 D3 G2 Eb3 C3 D3', 'G2 C3 Eb3 D3 Eb3 C3 D3 G2',
             'G2 C3 Eb3 D3 G2 Eb3 C3 D3', 'G2 C3 Eb3 D3 G2 Eb3 C3 D3',
             'G2 Eb3 C3 G2 G2 C3 A2 D3']
    for i, progression in enumerate(symbols):
        _harmony(pluck, progression, i * 8, mode='broken', vel=45 if i != 2 else 39)
        if i != 2:
            _bass(cello, roots[i], i * 8, mode='two', vel=49)
    _bass(cello, 'G2 Eb3 C3 D3', 20, mode='long', vel=43)
    # Actual VSCO orchestral bass drum on key 36, not a taiko or Chinese war drum.
    for bar in (0, 4, 8, 12, 14, 24, 28, 30, 32, 34):
        note(drum, bar * 4, .35, 36, 44)
        if bar in (12, 14, 30, 34):
            note(drum, bar * 4 + 3, .25, 36, 36)
    for name, start, bars in [('personal flag', 0, 8), ('public stance', 8, 8), ('private cost', 16, 4), ('decide alone', 20, 4), ('theme in motion', 24, 8), ('hold direction', 32, 4), ('continue', 36, 4)]:
        _section(s, name, start, bars)
    return validate(s)


def build_probes():
    """Deterministic first 16 bars, 32.5–40 seconds, for the P0 renderer."""
    result = []
    for source in (_comedy(), _warmth(), _emma(), _emma(True)):
        score = copy.deepcopy(source)
        beats = 16 * source['meter'][0] * 4 / source['meter'][1]
        score.update(beats=beats, probe_of=source['id'], loop=False)
        score['sections'] = [dict(section, beats=min(section['beats'], beats - section['start']))
                             for section in score['sections'] if section['start'] < beats]
        for part in score['tracks']:
            part['notes'] = [[st, min(dur, beats - st), p, vel]
                             for st, dur, p, vel in part['notes'] if st < beats]
        result.append(validate(score))
    return result


def build_cues():
    return [_travel(), _comedy(), _warmth(), _tension(), _aftermath(),
            _confrontation(), _intrigue(), _discovery(), _resolve(),
            _solitude(), _banter(), _remembrance(), _emma(), _lingqi(),
            _emma(True), _lingqi(True)]


def self_check():
    result = []
    scores = build_cues()
    expected = {
        'story_travel', 'story_comedy', 'story_warmth', 'story_tension',
        'story_aftermath', 'story_confrontation', 'story_intrigue',
        'story_discovery', 'story_resolve', 'story_solitude', 'story_banter',
        'story_remembrance', 'character_emma', 'character_lingqi',
        'character_emma_wary', 'character_lingqi_aftermath',
    }
    assert {s['id'] for s in scores} == expected
    for score in scores:
        validate(score)
        overlaps = []
        for part in score['tracks']:
            by_pitch = {}
            for st, dur, p, vel in sorted(part['notes']):
                if st < by_pitch.get(p, -1) - 1e-5:
                    overlaps.append([part['name'], st, p])
                by_pitch[p] = st + dur
        assert not overlaps, (score['id'], overlaps)
        duration = score['beats'] * 60 / score['bpm']
        assert (60 <= duration <= 110) if score['category'] == 'story' else (90 <= duration <= 150)
        sections = score['sections']
        assert sections[0]['start'] == 0
        assert all(abs(a['start'] + a['beats'] - b['start']) < 1e-6
                   for a, b in zip(sections, sections[1:]))
        assert abs(sections[-1]['start'] + sections[-1]['beats'] - score['beats']) < 1e-6
        latest = max(st + dur for p in score['tracks'] for st, dur, _, _ in p['notes'])
        assert latest < score['beats'], (score['id'], 'no release space')
        result.append(dict(id=score['id'], seconds=round(duration, 2),
                           beats=score['beats'], meter=score['meter'], tracks=len(score['tracks']),
                           notes=sum(len(t['notes']) for t in score['tracks']),
                           form=[x['name'] for x in score['sections']], same_pitch_overlaps=overlaps,
                           release_space_seconds=round((score['beats'] - latest) * 60 / score['bpm'], 3),
                           registers={p['name']: [min(n[2] for n in p['notes']), max(n[2] for n in p['notes'])]
                                      for p in score['tracks'] if p['notes']}))
    assert len({item['id'] for item in result}) == len(result)
    by_id = {s['id']: s for s in scores}
    emma = by_id['character_emma']['tracks'][0]['notes'][:15]
    wary = by_id['character_emma_wary']['tracks'][0]['notes'][:15]
    assert [n[2] for n in emma] == [n[2] for n in wary]
    assert wary[0][1] < emma[0][1]
    flag = by_id['character_lingqi']['tracks'][0]['notes'][:17]
    weight = by_id['character_lingqi_aftermath']['tracks'][0]['notes'][:17]
    assert [n[2] for n in flag] == [n[2] for n in weight]
    assert all(abs(a[0] * 2 - b[0]) < 1e-5 for a, b in zip(flag, weight))
    fingerprints = [tuple(n[2] for n in s['tracks'][0]['notes'][:15])
                    for s in scores if s['category'] == 'story']
    assert len(set(fingerprints)) == 12
    return dict(cues=result, count=len(result), listening_status='not auditioned',
                theme_checks=dict(emma_same_first_15_pitches=True, emma_wary_shortened_attack=True,
                                  lingqi_same_first_17_pitches=True, lingqi_aftermath_onsets_doubled=True,
                                  story_opening_fingerprints_distinct=12),
                note='Finite events, bounds, durations, sections, registers, theme relations and same-pitch overlap checked; not a listening approval.')


if __name__ == '__main__':
    import json
    print(json.dumps(self_check(), ensure_ascii=False, indent=2))

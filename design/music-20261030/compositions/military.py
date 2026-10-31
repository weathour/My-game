"""Original military/adventure score package, 2026-10-30.

Editable notation, in quarter-note beats; no borrowed Rance/march melodies.
Run with --json PATH to export the score, or without arguments for an audit.
Instrument labels are rendering contracts, not claims of authentic instruments.
"""
from pathlib import Path
import argparse
import json
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from scorelib import cue, add_track, note, melody, chord, voicing, validate


def _new(cid, bpm, meter, ensemble, identity, sync=None):
    s = cue(cid, cid, bpm, 1, meter=meter, category='battle' if cid.startswith('battle_') else 'character',
            target_lufs=-21, composer='original military package',
            identity=identity, sections=[], sync_group=sync or cid,
            transition='bar_aligned_crossfade' if sync else 'phrase_end_fade',
            review_status='notation_validated_listening_pending')
    s['tracks'] = []
    for name, inst, db, pan in ensemble:
        add_track(s, inst, name, db, pan)
    return s


def _parts(s):
    return {p['name']: p for p in s['tracks']}


def _section(s, name, tune, harmonies, style='march', lead='lead', energy=0,
             counter=None, answer=None):
    """Place an authored phrase; accompaniment only realizes explicit harmony.

    Each harmony is one notated bar. Melody remains explicitly authored below.
    Empty sections are not padded or filled with generated melody.
    """
    p = _parts(s)
    b = s['meter'][0] * 4 / s['meter'][1]
    start = s['sections'][-1]['end'] if s['sections'] else 0
    end = melody(p[lead], tune, start, b, 73 + energy, .84 if style != 'lyric' else .94)
    if abs(end - start - len(harmonies) * b) > 1e-6:
        raise ValueError((s['id'], name, 'melody/harmony length mismatch'))
    if counter:
        melody(p['counter'], counter, start, b, 57 + energy, .88)
    if answer:
        melody(p['answer'], answer, start, b, 60 + energy, .82)
    for i, sym in enumerate(harmonies):
        t = start + i * b
        pitches = chord(sym)
        root = pitches[0]
        while root > 46:
            root -= 12
        while root < 32:
            root += 12
        # Mid-register harmonic bed stays below the lead, with explicit rests.
        upper = [x + 12 if x < 48 else x for x in pitches]
        while max(upper) > 67:
            upper = [x - 12 for x in upper]
        if 'bed' in p:
            if style in ('lyric', 'hush', 'ritual'):
                voicing(p['bed'], upper, t + .12, b - .3, 42 + energy)
            elif style == 'shots':
                if i % 4 in (0, 3):
                    voicing(p['bed'], upper, t, .32, 57 + energy)
            elif style == 'gallop':
                for off in (0, b / 2):
                    voicing(p['bed'], upper, t + off, .32, 51 + energy)
            else:
                for off in ([1, 3] if b == 4 else [b / 2]):
                    voicing(p['bed'], upper, t + off, .42, 49 + energy)
        if 'bass' in p:
            if style == 'shots':
                if i % 4 != 1:
                    note(p['bass'], t, .4, root, 71 + energy)
                if i % 4 == 3:
                    note(p['bass'], t + b - .5, .32, root + 7, 63 + energy)
            elif style in ('hush', 'ritual'):
                note(p['bass'], t, b - .2, root, 51 + energy)
            elif style == 'lyric':
                note(p['bass'], t, b / 2 - .12, root, 52 + energy)
                note(p['bass'], t + b / 2, b / 2 - .12, root + 7, 48 + energy)
            elif style == 'gallop':
                for k in range(int(b * 2)):
                    note(p['bass'], t + k * .5, .36, root if k % 3 != 2 else root + 7,
                         62 + energy + (7 if k % 3 == 0 else -3))
            elif style == 'drive':
                for k in range(int(b * 2)):
                    note(p['bass'], t + .5 * k, .33, root, 62 + energy + (5 if k % 2 == 0 else -4))
            else:
                for k in range(int(b)):
                    note(p['bass'], t + k, .62, root if k % 2 == 0 else root + 7, 61 + energy)
        if 'pulse' in p and style not in ('hush', 'lyric'):
            offs = (0, b / 2) if style in ('march', 'ritual') else (0, .5, b / 2)
            for k, off in enumerate(offs):
                if style != 'shots' or i % 4 in (0, 3):
                    note(p['pulse'], t + off, .18, root + 24, 48 + energy - k * 3)
        if 'drums' in p:
            d = p['drums']
            if style == 'hush':
                if i % 4 == 0:
                    note(d, t, .12, 36, 38 + energy)
            elif style == 'shots':
                if i % 4 in (0, 3):
                    note(d, t, .1, 36, 68 + energy)
                    note(d, t + .5, .1, 38, 48 + energy)
            elif style == 'ritual':
                # Three strengths of the recorded bass drum. VSCO 41 is a
                # snare roll and 45 has no source; neither is a low tom.
                for off, key, vel in [(0, 36, 62), (1.5, 36, 48), (2.5, 36, 39)]:
                    if off < b:
                        note(d, t + off, .13, key, vel + energy)
            elif style != 'lyric':
                note(d, t, .1, 36, 66 + energy)
                note(d, t + b / 2, .1, 38, 56 + energy)
                if style in ('drive', 'gallop'):
                    for k in range(int(b * 2)):
                        # Sparse alternating-snare ghosts, not a false hi-hat:
                        # VSCO key 42 is a gong scrape, key 40 a real snare hit.
                        if k % 2 == 1 and abs(k * .5 - b / 2) > .01:
                            note(d, t + k * .5, .075, 40, 29 + energy)
                elif i % 4 == 3:
                    note(d, t + b - .5, .1, 38, 43 + energy)
        if 'color' in p and i % 4 == 0 and style not in ('shots', 'hush'):
            note(p['color'], t, min(1.3, b - .1), upper[-1] + 12, 39 + energy)
    s['sections'].append(dict(name=name, start=start, end=end, harmony=harmonies, texture=style))
    s['beats'] = end
    return s


def _finish(s):
    # Whole cue has a composed opening; final dominant/pickup leads back to it.
    s['loop_start'] = 0
    s['loop_end'] = s['beats']
    return validate(s)


HERO_A = 'D4:1 F4:.5 A4:.5 G4:1 r:1 | F4:1 E4:.5 D4:.5 A3:1 r:1 | C4:1 D4:1 F4:1 A4:1 | G4:2 E4:1 r:1 | F4:1 A4:1 C5:1 Bb4:1 | A4:1 G4:.5 F4:.5 E4:1 r:1 | D4:1 F4:1 E4:.5 D4:.5 C4:1 | A3:2 r:1 A3:1'
HERO_B = 'Bb4:2 A4:1 F4:1 | G4:1 D5:1 C5:1 r:1 | A4:1 C5:.5 D5:.5 C5:1 A4:1 | G4:2 r:2 | F4:1 G4:1 A4:2 | E4:1 F4:.5 G4:.5 E4:1 C#4:1 | D4:2 F4:1 E4:1 | C#4:2 r:1 A3:1'
HERO_C = 'F4:2 A4:1 r:1 | C5:2 A4:1 G4:1 | Bb4:1 A4:1 F4:1 D4:1 | G4:3 r:1 | A4:1 G4:1 F4:2 | E4:1 C4:1 D4:1 E4:1 | F4:2 E4:1 D4:1 | C#4:2 r:2'
HA = ['D3:m','D3:m','Bb2:M','A2:sus4','F3:M','C3:M','G2:m','A2:7']
HB = ['Bb2:M','G2:m','F3:M','C3:M','D3:m','A2:7','D3:m','A2:7']
HC = ['F3:M','F3:M','Bb2:M','G2:m','D3:m','C3:M','Bb2:M','A2:7']


def _hero(daily=False):
    ensemble = [('lead','clarinet' if daily else 'horn',-9,-.12),
                ('counter','cello' if daily else 'bassoon',-15,.2),
                ('bed','acoustic_guitar' if daily else 'strings',-19,-.25),
                ('bass','cello' if daily else 'contrabass',-13,.08)]
    if not daily:
        ensemble += [('answer','trumpet',-16,.3),('drums','drums',-21,0)]
    s = _new('hero_daily' if daily else 'hero_main',88 if daily else 112,(4,4),ensemble,
             'D-F-A upward assertion, descending answer, breath before renewal')
    intro = 'r:2 A3:1 C4:1 | D4:2 r:2 | F4:2 E4:1 D4:1 | A3:3 r:1'
    _section(s,'invitation' if daily else 'unfurl',intro,['D3:m','D3:m','G2:m','A2:7'],'lyric' if daily else 'hush',energy=-5)
    _section(s,'assertion',HERO_A,HA,'lyric' if daily else 'march',energy=-3 if daily else 1)
    _section(s,'open_country',HERO_B,HB,'lyric' if daily else 'march',energy=-2 if daily else 3)
    _section(s,'trio_rest',HERO_C,HC,'lyric',energy=-6,
             counter='A3:3 r:1 | C4:2 F3:2 | D4:2 Bb3:2 | D4:2 Bb3:1 r:1 | F3:2 A3:2 | G3:2 C4:2 | Bb3:2 F3:2 | E3:3 r:1')
    _section(s,'familiar_return',HERO_A,HA,'lyric' if daily else 'march',energy=-1 if daily else 6)
    if not daily:
        _section(s,'horizon',HERO_B,HB,'drive',energy=7,
                 answer='r:4 | D4:2 r:2 | F4:2 r:2 | E4:2 r:2 | F4:2 r:2 | E4:2 r:2 | A4:2 F4:1 E4:1 | C#4:2 r:2')
    _section(s,'return_bridge','D4:2 A3:1 r:1 | F4:1 E4:1 D4:2 | Bb3:2 D4:1 E4:1 | C#4:2 r:1 A3:1',
             ['D3:m','D3:m','G2:m','A2:7'],'lyric' if daily else 'hush')
    return _finish(s)


CAO_A = 'D4:1 r:.5 D4:.5 A4:1 F4:1 | E4:1 D4:1 r:2 | F4:1 E4:.5 D4:.5 C4:1 D4:1 | E4:2 r:1 A3:1 | D4:1 F4:1 A4:2 | Bb4:1 A4:1 G4:1 r:1 | F4:1 E4:1 D4:1 C#4:1 | A3:2 r:2'
CAO_B = 'A4:1 G4:1 F4:1 D4:1 | Bb3:2 D4:1 F4:1 | G4:1 F4:1 E4:1 C4:1 | E4:3 r:1 | F4:1 A4:1 C5:1 A4:1 | Bb4:2 G4:1 F4:1 | E4:1 F4:1 D4:1 E4:1 | C#4:2 r:1 A3:1'
CAO_C = 'F4:3 r:1 | A4:2 G4:1 F4:1 | D4:2 F4:2 | E4:3 r:1 | G4:2 Bb4:1 A4:1 | F4:2 D4:1 r:1 | E4:1 D4:1 C#4:1 E4:1 | A3:2 r:2'
CA = ['D3:m','D3:m','Bb2:M','A2:7','D3:m','G2:m','D3:m','A2:7']
CB = ['D3:m','Bb2:M','C3:M','A2:7','F3:M','G2:m','D3:m','A2:7']
CC = ['F3:M','F3:M','Bb2:M','A2:7','G2:m','D3:m','A2:7','A2:7']


def _cao():
    # A horn carries the written high command line without extending tenor
    # trombone samples above F4. Trombone supplies the lower answering calls.
    s = _new('army_cao',104,(4,4),[('lead','horn',-10,-.12),('answer','trombone',-16,.24),
         ('bed','organ',-23,-.3),('bass','contrabass',-12,.1),('drums','drums',-20,0)],
         'D-rest-D-A-F command call; regulated answering descent')
    _section(s,'distant_order','D3:1 r:3 | A3:1 r:3 | D4:1 F4:1 E4:1 r:1 | C#4:2 r:2',CA[:4],'hush')
    _section(s,'formation',CAO_A,CA,'march',energy=2)
    _section(s,'deployment',CAO_B,CB,'march',energy=4)
    _section(s,'trio_council',CAO_C,CC,'lyric',energy=-6,
             answer='A3:2 r:2 | C4:2 r:2 | D4:2 Bb3:2 | C#4:2 r:2 | D4:2 r:2 | A3:2 r:2 | G3:2 E3:2 | C#4:2 r:2')
    _section(s,'formation_returns',CAO_A,CA,'march',energy=7)
    _section(s,'advance',CAO_B,CB,'drive',energy=6)
    _section(s,'command_again',CAO_A,CA,'march',energy=3)
    return _finish(s)


LU_A = 'D4:1 r:1 Ab4:.5 G4:.5 D4:1 | Eb4:1 D4:1 r:2 | A3:1 D4:1 F4:1 Eb4:1 | D4:2 r:2 | Ab4:1 G4:1 F4:1 D4:1 | Eb4:2 C4:1 r:1 | D4:1 Eb4:.5 D4:.5 A3:1 C#4:1 | D4:1 r:3'
LU_B = 'F4:1 Ab4:1 G4:2 | Eb4:1 G4:1 Bb4:1 r:1 | A4:1 F4:1 E4:1 D4:1 | C#4:2 r:2 | D5:1 C5:1 Ab4:1 G4:1 | F4:2 Eb4:1 D4:1 | Eb4:1 D4:1 C#4:1 A3:1 | D4:1 r:3'
LU_C = 'D4:3 r:1 | Eb4:2 D4:1 r:1 | C4:1 Eb4:1 G4:2 | F4:2 r:2 | Ab4:1 G4:1 Eb4:2 | D4:2 F4:1 Eb4:1 | D4:1 C#4:1 A3:1 r:1 | C#4:2 r:2'
LA = ['D3:5','D3:m','D3:m','D3:5','Ab2:M','C3:m','A2:7','D3:5']
LB = ['F3:m','Eb3:M','D3:m','A2:7','Ab2:M','D3:m','A2:7','D3:5']
LC = ['D3:5','Eb3:M','C3:m','F3:m','Ab2:M','D3:m','D3:5','A2:7']


def _lubu(war=False):
    ens = [('lead','horn' if war else 'cello',-9,-.08),('counter','violin',-16,.2),
           ('bed','strings',-21,-.3),('bass','contrabass',-11,0),('drums','drums',-19,.08)]
    if war:
        ens += [('answer','trombone',-13,.22),('pulse','electric_guitar',-23,-.22),('color','gong',-28,.1)]
    s = _new('boss_lubu_warform' if war else 'boss_lubu',108,(4,4),ens,
             'D — Ab-G-D, Eb-D answer; warform compresses the same chromatic signature', 'lubu_axis_108_224')
    intro = 'D3:1 r:3 | Ab3:.5 G3:.5 D3:1 r:2 | Eb3:1 r:1 D3:1 r:1 | A3:1 r:3'
    _section(s,'measure_the_enemy',intro,LA[:4],'shots' if war else 'hush',energy=5 if war else -8)
    _section(s,'signature',LU_A,LA,'drive' if war else 'shots',energy=8 if war else -2,
             answer='D3:2 r:2 | Eb3:1 D3:1 r:2 | A3:2 F3:2 | D3:2 r:2 | Ab3:2 G3:2 | Eb3:2 C3:2 | A3:2 C#4:2 | D4:1 r:3' if war else None)
    _section(s,'reach',LU_B,LB,'drive' if war else 'march',energy=9 if war else 0)
    _section(s,'restrained_center',LU_C,LC,'march' if war else 'hush',energy=1 if war else -8,
             counter='A4:2 r:2 | G4:2 r:2 | Eb4:2 r:2 | C5:2 r:2 | Eb5:2 r:2 | A4:2 r:2 | F4:2 r:2 | E4:2 r:2')
    _section(s,'signature_tightened',
             ('D4:.5 Ab4:.5 G4:.5 D4:.5 F4:1 r:1 | Eb4:.5 D4:.5 A3:1 D4:1 r:1 | A3:.5 D4:.5 F4:.5 Eb4:.5 D4:1 A4:1 | D4:1 r:1 A3:.5 C#4:.5 E4:1 | Ab4:.5 G4:.5 F4:.5 D4:.5 Ab4:1 G4:1 | Eb4:.5 C4:.5 Eb4:1 G4:1 r:1 | D4:.5 Eb4:.5 D4:.5 A3:.5 C#4:1 E4:1 | D4:1 r:3') if war else LU_A,
             LA,'drive' if war else 'shots',energy=10 if war else 0)
    _section(s,'full_reach',LU_B,LB,'drive' if war else 'march',energy=11 if war else 2,
             counter='r:2 F5:1 Eb5:1 | G5:2 r:2 | F5:2 E5:1 D5:1 | C#5:2 r:2 | Ab5:2 G5:1 Eb5:1 | F5:2 r:2 | E5:1 D5:1 C#5:2 | r:4' if war else None)
    _section(s,'last_look',LU_C,LC,'march' if war else 'hush',energy=2 if war else -8)
    _section(s,'hinge','D4:1 r:1 Ab4:.5 G4:.5 D4:1 | Eb4:1 D4:1 r:2 | A3:1 C#4:1 E4:1 r:1 | C#4:2 r:2',
             ['D3:5','Eb3:M','A2:7','A2:7'],'shots' if war else 'hush')
    return _finish(s)


ROAD_A = 'G4:.5 D5:.5 Bb4:1 A4:.5 G4:.5 | F4:1 D4:.5 F4:.5 G4:1 | Bb4:1 A4:.5 G4:.5 F4:1 | A4:1.5 r:1.5 | G4:.5 A4:.5 Bb4:1 D5:1 | C5:1 A4:.5 G4:.5 F4:1 | Eb4:1 G4:.5 F4:.5 D4:1 | D4:2 r:1'
ROAD_B = 'Bb4:1 D5:1 F5:1 | Eb5:1 D5:.5 C5:.5 Bb4:1 | A4:.5 C5:.5 Eb5:1 D5:1 | C5:1.5 r:1.5 | Bb4:1 A4:.5 G4:.5 F4:1 | Eb4:1 G4:1 Bb4:1 | A4:1 G4:.5 F#4:.5 A4:1 | G4:2 r:1'
ROAD_C = 'D5:2 r:1 | Bb4:1 D5:.5 C5:.5 Bb4:1 | G4:2 Bb4:1 | A4:2 r:1 | G4:1 Bb4:1 D5:1 | Eb5:1 D5:1 C5:1 | A4:1 F#4:1 D4:1 | F#4:1.5 r:1.5'
RH = ['G2:m','G2:m','Bb2:M','D3:7','G2:m','F3:M','Eb3:M','D3:7']
RB = ['Bb2:M','Eb3:M','C3:m','F3:M','G2:m','Eb3:M','D3:7','G2:m']
RC = ['G2:m','Bb2:M','Eb3:M','D3:7','G2:m','C3:m','D3:7','D3:7']


def _road():
    s = _new('battle_road',126,(6,8),[('lead','clarinet',-10,-.15),('counter','viola',-17,.24),
        ('bed','acoustic_guitar',-20,-.3),('bass','cello',-13,.08),('drums','drums',-23,0)],
        'G-D-Bb / A-G answer, two dotted beats carrying a traveling stride')
    _section(s,'footsteps','r:1 G4:.5 A4:.5 Bb4:1 | D5:1 r:2 | C5:1 Bb4:.5 A4:.5 G4:1 | F#4:1 r:2',RH[:4],'march',energy=-5)
    _section(s,'road_call',ROAD_A,RH,'gallop')
    _section(s,'ridge',ROAD_B,RB,'gallop',energy=2)
    _section(s,'road_answer',ROAD_A,RH,'march',energy=-2,
             counter='D4:1 r:2 | Bb3:2 r:1 | D4:1 F4:1 D4:1 | F#4:1 r:2 | D4:2 r:1 | C4:1 r:2 | Bb3:1 Eb4:1 G3:1 | A3:2 r:1')
    _section(s,'valley_trio',ROAD_C,RC,'lyric',energy=-7)
    _section(s,'ridge_returns',ROAD_B,RB,'gallop',energy=4)
    _section(s,'last_mile',ROAD_A,RH,'gallop',energy=5)
    _section(s,'open_horizon',ROAD_C,RC,'march',energy=-2)
    _section(s,'turnback','G4:1 D4:1 Bb3:1 | Eb4:1 G4:1 r:1 | A4:1 F#4:1 D4:1 | F#4:1 r:2',
             ['G2:m','Eb3:M','D3:7','D3:7'],'hush')
    return _finish(s)


SIEGE_A = 'D4:.5 D4:.5 A4:1 | F4:.5 E4:.5 D4:1 | Bb3:1 D4:1 | C#4:1 r:1 | D4:.5 F4:.5 A4:.5 F4:.5 | G4:1 E4:.5 C4:.5 | D4:1 E4:.5 F4:.5 | E4:1 r:1 | A4:.5 A4:.5 D5:1 | C5:.5 Bb4:.5 A4:1 | G4:.5 Bb4:.5 D5:1 | C#5:1 r:1 | A4:.5 F4:.5 D4:1 | Bb3:.5 D4:.5 F4:1 | E4:.5 D4:.5 C#4:.5 E4:.5 | A3:1 r:1'
SIEGE_B = 'F4:1 A4:1 | C5:1 A4:1 | Bb4:.5 A4:.5 G4:1 | F4:1 r:1 | D4:.5 F4:.5 G4:1 | Bb4:1 A4:1 | G4:.5 F4:.5 E4:1 | C#4:1 r:1 | F4:.5 A4:.5 C5:1 | D5:.5 C5:.5 A4:1 | G4:.5 Bb4:.5 A4:.5 G4:.5 | F4:1 r:1 | Bb3:1 D4:1 | G4:1 F4:1 | E4:.5 C#4:.5 D4:.5 E4:.5 | C#4:1 r:1'
SH = ['D3:m','D3:m','Bb2:M','A2:7','D3:m','C3:M','G2:m','A2:7',
      'D3:m','D3:m','G2:m','A2:7','D3:m','Bb2:M','A2:7','A2:7']
SB = ['F3:M','F3:M','Bb2:M','F3:M','G2:m','G2:m','C3:M','A2:7',
      'F3:M','D3:m','G2:m','F3:M','Bb2:M','G2:m','A2:7','A2:7']


def _siege():
    s = _new('battle_siege',116,(2,4),[('lead','horn',-9,-.1),('answer','trumpet',-15,.3),
         ('bed','trombone',-20,-.28),('bass','contrabass',-12,0),('pulse','pizzicato',-23,.15),
         ('drums','drums',-19,0)],'D-D-A siege signal, short answers against heavy two-beat steps')
    intro = 'D3:1 r:1 | D3:.5 A3:.5 D4:1 | r:2 | A3:1 r:1 | F4:1 D4:1 | Bb3:1 r:1 | E4:.5 C#4:.5 A3:1 | r:2'
    _section(s,'before_the_gate',intro,SH[:8],'shots')
    _section(s,'ram',SIEGE_A,SH,'march',energy=4)
    _section(s,'on_the_wall',SIEGE_B,SB,'drive',energy=5)
    _section(s,'trio_distant_banner',SIEGE_B,SB,'lyric',energy=-8,
             answer='r:2 | C4:1 r:1 | D4:1 r:1 | C4:1 r:1 | D4:1 r:1 | F4:1 r:1 | E4:1 r:1 | C#4:1 r:1 | A3:1 r:1 | F4:1 r:1 | D4:1 r:1 | C4:1 r:1 | D4:1 r:1 | Bb3:1 r:1 | A3:1 r:1 | r:2')
    _section(s,'ram_returns',SIEGE_A,SH,'drive',energy=8)
    _section(s,'battlement',SIEGE_B,SB,'march',energy=6)
    _section(s,'gate_reforms',intro,SH[:8],'shots',energy=-3)
    return _finish(s)


RITUAL_A = 'E4:1 Bb4:.5 A4:.5 F4:1 | E4:1 r:2 | G4:1 F4:.5 E4:.5 D4:1 | F4:1.5 r:1.5 | E4:.5 F4:.5 Bb4:1 A4:1 | G4:1 E4:1 D4:1 | F4:1 E4:.5 D4:.5 Bb3:1 | B3:1 r:2'
RITUAL_B = 'G4:2 Bb4:1 | A4:1 F4:1 E4:1 | C5:1 Bb4:.5 A4:.5 G4:1 | F4:2 r:1 | E4:1 G4:1 Bb4:1 | A4:1 F4:1 D4:1 | E4:1 D4:1 C4:1 | B3:1.5 r:1.5'
RIH = ['E3:dim','E3:5','C3:M','D3:m','Bb2:M','C3:M','D3:m','B2:7']
RIB = ['C3:M','F3:M','C3:M','D3:m','E3:dim','D3:m','C3:M','B2:7']


def _ritual():
    s = _new('battle_ritual',92,(6,8),[('lead','oboe',-10,-.18),('answer','bassoon',-14,.22),
         ('bed','organ',-24,-.3),('bass','contrabass',-15,0),('drums','drums',-23,.1),('color','bell',-28,.25)],
         'E-Bb-A-F uneven invocation; silence answers the tritone')
    _section(s,'threshold','E4:1 r:2 | Bb3:1 r:2 | F4:1 E4:1 r:1 | B3:1 r:2',RIH[:4],'hush',energy=-5)
    _section(s,'invocation',RITUAL_A,RIH,'ritual')
    _section(s,'apparition',RITUAL_B,RIB,'ritual',energy=2)
    _section(s,'lower_echo',RITUAL_A,RIH,'hush',energy=-5,
             answer='E3:2 r:1 | B3:1 r:2 | C4:1 E4:1 r:1 | A3:2 r:1 | F3:1 Bb3:1 r:1 | E3:2 r:1 | A3:1 F3:1 r:1 | F#3:1 r:2')
    _section(s,'circle_tightens',RITUAL_A,RIH,'gallop',energy=4)
    _section(s,'apparition_recedes',RITUAL_B,RIB,'ritual',energy=-2)
    _section(s,'threshold_returns','E4:1 r:2 | D4:1 C4:1 r:1 | F#4:1 D#4:1 B3:1 | B3:1 r:2',
             ['E3:dim','C3:M','B2:7','B2:7'],'hush',energy=-7)
    return _finish(s)


SKIRMISH_A = 'G4:.5 B4:.5 D5:1 | B4:.5 A4:.5 G4:.5 r:.5 | E4:.5 G4:.5 A4:1 | B4:.5 A4:.5 r:1 | D5:.5 B4:.5 G4:1 | A4:.5 G4:.5 E4:1 | F#4:.5 A4:.5 D5:.5 C5:.5 | B4:1 r:1 | G4:.5 B4:.5 D5:.5 E5:.5 | D5:.5 B4:.5 G4:1 | C5:.5 B4:.5 A4:.5 G4:.5 | E4:1 r:1 | A4:.5 B4:.5 C5:1 | B4:.5 A4:.5 G4:1 | F#4:.5 A4:.5 E4:.5 F#4:.5 | D4:1 r:1'
SKIRMISH_B = 'E5:1 D5:.5 B4:.5 | C5:1 A4:1 | B4:.5 G4:.5 A4:.5 B4:.5 | D5:1 r:1 | G4:.5 A4:.5 B4:1 | A4:.5 F#4:.5 D4:1 | E4:.5 G4:.5 C5:.5 B4:.5 | A4:1 r:1 | E5:.5 D5:.5 B4:1 | C5:.5 B4:.5 A4:1 | G4:.5 B4:.5 D5:1 | B4:1 r:1 | A4:.5 C5:.5 B4:.5 A4:.5 | G4:.5 E4:.5 C4:1 | D4:.5 F#4:.5 A4:.5 C5:.5 | D5:1 r:1'
KH = ['G2:M','G2:M','C3:M','D3:7','G2:M','C3:M','D3:7','G2:M',
      'G2:M','G2:M','C3:M','C3:M','A2:m','G2:M','D3:7','D3:7']
KB = ['E3:m','A2:m','G2:M','D3:7','G2:M','D3:7','C3:M','D3:7',
      'E3:m','A2:m','G2:M','G2:M','A2:m','C3:M','D3:7','D3:7']


def _skirmish():
    s = _new('battle_skirmish',140,(2,4),[('lead','clarinet',-10,-.2),('answer','bassoon',-16,.25),
         ('bed','pizzicato',-19,-.3),('bass','cello',-13,.08),('drums','drums',-26,0)],
         'G-B-D bounce with an eighth-note wink and full-beat breathing spaces')
    intro='G4:.5 r:.5 B4:1 | D5:1 r:1 | A4:.5 r:.5 C5:1 | D5:1 r:1 | B4:.5 A4:.5 G4:1 | E4:1 r:1 | F#4:.5 A4:.5 C5:1 | r:2'
    _section(s,'stumble_in',intro,KH[:8],'march',energy=-5)
    _section(s,'quick_feet',SKIRMISH_A,KH,'march',energy=1)
    _section(s,'wrong_turn',SKIRMISH_B,KB,'march',energy=3)
    _section(s,'pizzicato_detour',SKIRMISH_B,KB,'lyric',energy=-6,
             answer='G3:1 r:1 | E3:1 r:1 | D4:1 r:1 | A3:1 r:1 | B3:1 r:1 | A3:1 r:1 | E3:1 r:1 | F#3:1 r:1 | G3:1 r:1 | E3:1 r:1 | D4:1 r:1 | B3:1 r:1 | C4:1 r:1 | E3:1 r:1 | A3:1 r:1 | r:2')
    _section(s,'quick_feet_return',SKIRMISH_A,KH,'drive',energy=3)
    _section(s,'laugh_and_run',SKIRMISH_B,KB,'march',energy=2)
    _section(s,'another_corner',intro,KH[:8],'march',energy=-4)
    return _finish(s)


PURSUIT_A = 'A4:.5 E5:.5 C5:.5 B4:.5 A4:1 | G4:.5 A4:.5 B4:1 E4:1 | A4:1 C5:1 E5:1 | B4:1.5 r:1.5 | C5:.5 B4:.5 A4:1 E4:1 | G4:.5 F4:.5 E4:1 D4:1 | F4:1 A4:.5 G4:.5 F4:1 | G#4:1.5 r:1.5 | E5:.5 D5:.5 C5:1 A4:1 | F5:.5 E5:.5 D5:1 C5:1 | B4:.5 A4:.5 G#4:1 E4:1 | G#4:1 r:2'
PURSUIT_B = 'C5:1 E5:2 | D5:.5 C5:.5 A4:1 F4:1 | G4:.5 B4:.5 D5:1 F5:1 | E5:2 r:1 | A4:.5 C5:.5 E5:1 D5:1 | C5:1 A4:1 F4:1 | D5:.5 C5:.5 B4:1 A4:1 | G#4:2 r:1 | A4:1 E5:1 C5:1 | F5:1 D5:1 C5:1 | B4:1 G#4:.5 A4:.5 B4:1 | E5:1 r:2'
PH = ['A2:m','E3:m','A2:m','E3:7','A2:m','C3:M','D3:m','E3:7','A2:m','F3:M','E3:7','E3:7']
PB = ['C3:M','F3:M','G2:7','C3:M','A2:m','F3:M','D3:m','E3:7','A2:m','D3:m','E3:7','E3:7']


def _pursuit():
    s = _new('battle_pursuit',150,(6,8),[('lead','violin',-10,-.2),('counter','horn',-18,.2),
         ('bed','electric_guitar',-24,-.3),('bass','bass',-15,0),('pulse','pizzicato',-22,.3),('drums','drums',-22,0)],
         'A-E-C-B-A burst, a measured rest every fourth bar; galloping low motor')
    _section(s,'noticed','A3:.5 E4:.5 A4:1 r:1 | G4:1 E4:1 r:1 | F4:1 D4:1 r:1 | G#4:1 r:2',PH[:4],'gallop',energy=-3)
    _section(s,'pursuers',PURSUIT_A,PH,'gallop',energy=4)
    _section(s,'switchback',PURSUIT_B,PB,'gallop',energy=5)
    _section(s,'pursuers_nearer',PURSUIT_A,PH,'drive',energy=7)
    _section(s,'under_cover',PURSUIT_B,PB,'hush',energy=-4,
             counter='E4:2 r:1 | C4:2 r:1 | B3:2 r:1 | G3:2 r:1 | E4:2 r:1 | A3:2 r:1 | F4:2 r:1 | E4:2 r:1 | C4:2 r:1 | A3:2 r:1 | B3:2 r:1 | G#3:2 r:1')
    _section(s,'break_out',PURSUIT_A,PH,'gallop',energy=8)
    _section(s,'looping_track','A4:1 E4:1 C4:1 | F4:2 r:1 | D4:1 F4:1 A4:1 | G#4:2 r:1 | C5:1 B4:1 A4:1 | G4:1 F4:1 E4:1 | B4:1 G#4:1 E4:1 | r:3',
             ['A2:m','F3:M','D3:m','E3:7','A2:m','C3:M','E3:7','E3:7'],'gallop')
    return _finish(s)


DEFENSE_A = 'G3:1 Bb3:1 D4:2 | Eb4:1 D4:1 Bb3:1 r:1 | C4:1 D4:1 F4:1 Eb4:1 | D4:2 r:2 | G4:1 F4:1 D4:2 | Eb4:2 C4:1 Bb3:1 | A3:1 Bb3:1 A3:1 F#3:1 | D4:2 r:2'
DEFENSE_B = 'Bb3:2 D4:1 F4:1 | G4:2 F4:1 Eb4:1 | D4:1 C4:1 Bb3:1 A3:1 | C4:2 r:2 | Eb4:2 G4:1 F4:1 | D4:2 Bb3:2 | C4:1 Bb3:1 A3:1 C4:1 | F#3:2 r:2'
DEFENSE_C = 'D4:3 r:1 | G4:2 D4:2 | Eb4:3 D4:1 | C4:2 r:2 | Bb3:2 D4:2 | C4:2 Eb4:1 D4:1 | A3:1 C4:1 Eb4:1 D4:1 | F#3:2 r:2'
DH = ['G2:m','Eb3:M','C3:m','D3:7','G2:m','C3:m','D3:7','D3:7']
DB = ['Bb2:M','Eb3:M','G2:m','F3:M','C3:m','G2:m','A2:dim','D3:7']
DC = ['G2:m','G2:m','Eb3:M','C3:m','Bb2:M','C3:m','D3:7','D3:7']


def _defense():
    s = _new('battle_defense',104,(4,4),[('lead','cello',-9,-.12),('counter','horn',-16,.25),
         ('bed','strings',-22,-.3),('bass','contrabass',-12,0),('drums','drums',-23,.08)],
         'low G-Bb-D rising line, long notes held against pressure')
    _section(s,'hold_position','G3:2 r:2 | D4:2 r:2 | Eb4:1 D4:1 Bb3:1 r:1 | F#3:2 r:2',DH[:4],'hush')
    _section(s,'shield',DEFENSE_A,DH,'march',energy=1)
    _section(s,'the_cost',DEFENSE_B,DB,'march',energy=3)
    _section(s,'inside_the_circle',DEFENSE_C,DC,'lyric',energy=-6,
             counter='Bb3:2 r:2 | D4:2 r:2 | Bb3:2 r:2 | Eb4:2 r:2 | F4:2 r:2 | G4:2 r:2 | F#4:2 r:2 | A3:2 r:2')
    _section(s,'shield_returns',DEFENSE_A,DH,'drive',energy=5)
    _section(s,'unbroken',DEFENSE_B,DB,'march',energy=5)
    _section(s,'watch_again','G3:2 D4:1 Bb3:1 | Eb4:2 C4:1 r:1 | A3:1 C4:1 Eb4:1 F#4:1 | D4:2 r:2',DH[:4],'hush')
    return _finish(s)


DUEL_A = 'E4:.5 B4:.5 G4:1 F#4:.5 E4:.5 r:1 | D4:1 E4:1 G4:1 r:1 | A4:.5 G4:.5 F#4:1 E4:1 D4:1 | F#4:2 r:2 | E4:1 G4:.5 A4:.5 B4:1 r:1 | C5:1 B4:.5 A4:.5 G4:1 E4:1 | F#4:1 E4:1 D#4:.5 F#4:.5 B3:1 | E4:1 r:3'
DUEL_B = 'G4:2 B4:1 D5:1 | C5:1 A4:1 G4:1 r:1 | B4:1 G4:1 F#4:1 E4:1 | D#4:2 r:2 | E5:1 D5:.5 B4:.5 A4:1 G4:1 | F#4:2 D4:1 E4:1 | G4:.5 F#4:.5 E4:1 D#4:1 B3:1 | F#4:2 r:2'
UH = ['E3:m','E3:m','D3:M','B2:7','E3:m','C3:M','B2:7','E3:m']
UB = ['G2:M','A2:m','E3:m','B2:7','C3:M','D3:M','B2:7','B2:7']


def _duel():
    s = _new('battle_duel',132,(4,4),[('lead','violin',-10,-.16),('answer','cello',-14,.22),
         ('bed','harpsichord',-22,-.32),('bass','bass',-14,0),('drums','drums',-24,.08)],
         'E-B-G cut with withheld fourth beat; measured thrust and withdrawal')
    intro='E4:1 r:3 | B3:1 E4:1 r:2 | G4:1 F#4:1 E4:1 r:1 | D#4:1 r:3'
    _section(s,'distance',intro,UH[:4],'shots',energy=-3)
    _section(s,'measure_and_cut',DUEL_A,UH,'drive',energy=2)
    _section(s,'withdraw',intro,UH[:4],'shots',energy=-2)
    _section(s,'high_line',DUEL_B,UB,'march',energy=3)
    _section(s,'second_exchange',DUEL_A,UH,'drive',energy=5,
             answer='E3:2 r:2 | G3:2 r:2 | A3:2 r:2 | F#3:2 r:2 | B3:2 G3:2 | E3:2 r:2 | F#3:2 B3:2 | E3:1 r:3')
    _section(s,'high_line_returns',DUEL_B,UB,'drive',energy=6)
    _section(s,'circle_unclosed',DUEL_B,UB,'shots',energy=-4)
    return _finish(s)


DESPERATE_A = 'D4:.5 A4:.5 F4:.5 E4:.5 D4:1 r:1 | Bb3:1 D4:1 F4:.5 E4:.5 D4:1 | G4:.5 A4:.5 Bb4:1 A4:.5 G4:.5 F4:1 | E4:2 r:2 | A4:.5 C5:.5 D5:1 C5:.5 A4:.5 G4:1 | Bb4:1 G4:1 F4:.5 E4:.5 D4:1 | E4:.5 F4:.5 E4:1 C#4:1 A3:1 | D4:1 r:3'
DESPERATE_B = 'F4:1 A4:1 C5:2 | D5:1 C5:1 A4:1 r:1 | Bb4:1 D5:.5 C5:.5 Bb4:1 G4:1 | A4:2 r:2 | F4:1 G4:.5 A4:.5 C5:1 D5:1 | Eb5:2 D5:1 C5:1 | Bb4:1 A4:1 G4:1 E4:1 | C#4:2 r:2'
DESPERATE_C = 'D4:3 A3:1 | Bb3:2 F4:1 E4:1 | G4:2 F4:1 D4:1 | E4:3 r:1 | F4:2 A4:2 | Bb4:2 G4:2 | E4:1 F4:1 D4:1 E4:1 | C#4:2 r:2'
XH = ['D3:m','Bb2:M','G2:m','A2:7','D3:m','G2:m','A2:7','D3:m']
XB = ['F3:M','D3:m','G2:m','A2:7','F3:M','Eb3:M','G2:m','A2:7']
XC = ['D3:m','Bb2:M','G2:m','A2:7','F3:M','G2:m','A2:7','A2:7']


def _desperate():
    s = _new('battle_desperate',144,(4,4),[('lead','trumpet',-11,-.12),('counter','violin',-17,.28),
         ('answer','horn',-16,-.28),('bed','electric_guitar',-24,-.35),('bass','bass',-14,.08),
         ('pulse','pizzicato',-24,.32),('drums','drums',-22,0),('color','gong',-30,.1)],
         'D-A-F-E-D falling burst turns upward in the counterattack')
    _section(s,'under_pressure',DESPERATE_C,XC,'shots',energy=-2)
    _section(s,'break_the_ring',DESPERATE_A,XH,'drive',energy=6)
    _section(s,'answer_the_charge',DESPERATE_B,XB,'drive',energy=7)
    _section(s,'breath_in_the_smoke',DESPERATE_C,XC,'hush',energy=-7,
             answer='A3:2 r:2 | D4:2 r:2 | Bb3:2 r:2 | C#4:2 r:2 | C4:2 r:2 | D4:2 r:2 | E4:2 r:2 | A3:2 r:2')
    _section(s,'counterattack',DESPERATE_A,XH,'drive',energy=9,
             counter='F5:2 E5:1 D5:1 | Bb4:2 D5:2 | D5:2 Bb4:1 A4:1 | C#5:2 r:2 | F5:2 A5:1 G5:1 | D5:2 Bb4:1 A4:1 | E5:1 D5:1 C#5:2 | A4:2 r:2')
    _section(s,'rising_banner',DESPERATE_B,XB,'march',energy=8)
    _section(s,'not_yet_won',DESPERATE_A,XH,'drive',energy=6)
    _section(s,'ring_closes_again',DESPERATE_C,XC,'march',energy=-2)
    return _finish(s)


XIU_A = 'D4:.5 r:.5 D4:.5 A4:.5 F4:1 r:1 | r:4 | E4:.5 D4:.5 r:3 | A3:.5 C#4:.5 r:3 | D4:.5 F4:.5 A4:1 r:2 | Bb4:.5 A4:.5 r:3 | F4:.5 E4:.5 D4:1 r:2 | C#4:.5 A3:.5 r:3'
XIU_B = 'A4:.5 F4:.5 D4:1 r:2 | Bb3:.5 D4:.5 r:3 | G4:.5 E4:.5 C4:1 r:2 | C#4:1 r:3 | F4:.5 A4:.5 C5:1 r:2 | Bb4:.5 G4:.5 r:3 | E4:.5 F4:.5 D4:1 r:2 | C#4:.5 E4:.5 A3:1 r:2'
XIU_C = 'F4:2 r:2 | A4:1 G4:.5 F4:.5 r:2 | D4:1 r:3 | E4:1 r:3 | G4:.5 Bb4:.5 A4:1 r:2 | F4:1 D4:1 r:2 | E4:.5 D4:.5 C#4:1 r:2 | A3:1 r:3'


def _caoxiu():
    s = _new('army_caoxiu_warform',116,(4,4),[('lead','trumpet',-11,-.16),('answer','clarinet',-18,.25),
         ('bed','horn',-21,-.28),('bass','contrabass',-13,.08),('drums','drums',-21,0)],
         'Cao D-rest-D-A-F deliberately separated into short volleys and long waits')
    intro='D4:.5 r:3.5 | r:4 | A3:.5 D4:.5 r:3 | C#4:.5 r:3.5'
    _section(s,'sight_line',intro,CA[:4],'shots',energy=-3)
    _section(s,'first_volley',XIU_A,CA,'shots',energy=3)
    _section(s,'change_position',XIU_B,CB,'shots',energy=5)
    _section(s,'waiting_trio',XIU_C,CC,'hush',energy=-7,
             answer='A3:.5 r:3.5 | r:4 | Bb3:.5 D4:.5 r:3 | r:4 | D4:.5 r:3.5 | r:4 | G3:.5 E3:.5 r:3 | r:4')
    _section(s,'second_volley',XIU_A,CA,'shots',energy=8)
    _section(s,'crossfire',XIU_B,CB,'shots',energy=8)
    _section(s,'unspent_order',XIU_C,CC,'shots',energy=1)
    _section(s,'hold_fire',intro,CA[:4],'shots',energy=-5)
    return _finish(s)


CHUN_A = 'D4:.5 D4:.5 A4:.5 F4:.5 D4:1 | E4:.5 F4:.5 A4:1 r:1 | D5:1 C5:.5 A4:.5 F4:1 | E4:1 r:2 | D4:.5 A4:.5 F4:1 A4:1 | Bb4:1 A4:.5 G4:.5 F4:1 | E4:.5 D4:.5 E4:1 G4:1 | C#4:1 r:2 | A4:.5 F4:.5 D4:1 A3:1 | Bb3:1 D4:1 F4:1 | E4:.5 D4:.5 C#4:1 E4:1 | A3:1 r:2'
CHUN_B = 'F4:1 A4:.5 C5:.5 A4:1 | Bb4:1 G4:1 F4:1 | G4:.5 A4:.5 Bb4:1 D5:1 | C#5:1 r:2 | A4:.5 C5:.5 D5:1 A4:1 | F4:.5 G4:.5 A4:1 D5:1 | C5:1 Bb4:.5 A4:.5 G4:1 | E4:1 r:2 | F4:1 A4:1 C5:1 | Bb4:1 G4:1 D4:1 | E4:.5 F4:.5 E4:1 C#4:1 | A3:1 r:2'
CHUN_C = 'D4:2 F4:1 | A4:2 r:1 | G4:1 Bb4:1 A4:1 | E4:2 r:1 | F4:2 A4:1 | Bb4:2 G4:1 | E4:1 D4:1 E4:1 | C#4:2 r:1 | A4:1 G4:1 F4:1 | D4:2 Bb3:1 | E4:1 C#4:1 A3:1 | r:3'
CHUN_WA = 'D4:.5 D4:.5 A4:.5 F4:.5 A4:.5 D5:.5 | E5:.5 F5:.5 A4:1 r:1 | D5:.5 C5:.5 A4:.5 F4:.5 A4:1 | E4:.5 C#4:.5 E4:1 r:1 | D4:.5 A4:.5 F4:.5 A4:.5 D5:1 | Bb4:.5 A4:.5 G4:.5 F4:.5 D4:1 | E4:.5 D4:.5 E4:.5 G4:.5 E5:1 | C#5:1 r:2 | A4:.5 F4:.5 D4:.5 A3:.5 D4:1 | Bb3:.5 D4:.5 F4:.5 Bb4:.5 D5:1 | E5:.5 D5:.5 C#5:1 E5:1 | A4:1 r:2'
CH = ['D3:m','D3:m','D3:m','A2:7','D3:m','G2:m','G2:m','A2:7','D3:m','Bb2:M','A2:7','A2:7']
CHB = ['F3:M','G2:m','G2:m','A2:7','D3:m','D3:m','C3:M','A2:7','F3:M','G2:m','A2:7','A2:7']
CHC = ['D3:m','D3:m','G2:m','A2:7','F3:M','G2:m','D3:m','A2:7','D3:m','Bb2:M','A2:7','A2:7']


def _caochun(war=False):
    ens=[('lead','horn' if not war else 'trumpet',-11,-.12),('counter','cello',-18,.18),
         ('bed','strings' if not war else 'electric_guitar',-23,-.3),('bass','bass',-15,0),
         ('drums','drums',-23,.05)]
    if war:
        ens += [('answer','trombone',-16,.25),('pulse','pizzicato',-25,-.2)]
    s = _new('army_caochun_warform' if war else 'army_caochun_human',144,(6,8),ens,
             'D-D-A-F charge from Cao command; continuous low gallop while upper calls breathe',
             'caochun_axis_144_288')
    # The human horn's low D3 becomes D4 for the warform trumpet entrance;
    # subsequent pitch/rhythm identity and the complete sync axis remain.
    intro=('D4' if war else 'D3') + ':1 A3:1 r:1 | D4:.5 D4:.5 A4:1 r:1 | F4:1 E4:1 D4:1 | C#4:1 r:2 | A3:1 C#4:1 E4:1 | A4:1 r:2'
    _section(s,'bridle',intro,['D3:m','D3:m','D3:m','A2:7','A2:7','A2:7'],'gallop',energy=-2)
    _section(s,'charge',CHUN_WA if war else CHUN_A,CH,'gallop',energy=7 if war else 2,
             answer='D3:2 r:1 | A3:2 r:1 | F3:2 r:1 | E3:2 r:1 | D3:2 r:1 | Bb3:2 r:1 | G3:2 r:1 | C#4:2 r:1 | A3:2 r:1 | F3:2 r:1 | E3:2 r:1 | A3:1 r:2' if war else None)
    _section(s,'wheel',CHUN_B,CHB,'gallop',energy=8 if war else 4)
    _section(s,'charge_through',CHUN_WA if war else CHUN_A,CH,'gallop',energy=9 if war else 3)
    _section(s,'eyes_forward',CHUN_C,CHC,'gallop',energy=0 if war else -7,
             counter='A3:2 r:1 | F3:2 r:1 | D4:2 r:1 | C#4:2 r:1 | C4:2 r:1 | D4:2 r:1 | A3:2 r:1 | E3:2 r:1 | F3:2 r:1 | D3:2 r:1 | E3:2 r:1 | r:3')
    _section(s,'wheel_returns',CHUN_B,CHB,'gallop',energy=10 if war else 5)
    _section(s,'last_charge',CHUN_WA if war else CHUN_A,CH,'gallop',energy=10 if war else 4)
    _section(s,'horizon',CHUN_C,CHC,'gallop',energy=3 if war else -2)
    _section(s,'rein_back','D4:1 A3:1 F3:1 | Bb3:1 D4:1 r:1 | G4:1 F4:1 E4:1 | C#4:1 A3:1 r:1 | E4:.5 F4:.5 E4:1 C#4:1 | A3:1 r:2',
             ['D3:m','Bb2:M','G2:m','A2:7','A2:7','A2:7'],'gallop',energy=-3)
    return _finish(s)


LIAO_A = 'D5:.5 A4:.5 F4:.5 E4:.5 | D4:1 r:1 | F4:.5 A4:.5 C5:1 | Bb4:.5 A4:.5 r:1 | G4:.5 A4:.5 Bb4:.5 G4:.5 | F4:.5 E4:.5 D4:1 | E4:.5 F4:.5 E4:.5 C#4:.5 | A3:1 r:1 | D4:.5 F4:.5 A4:.5 D5:.5 | C5:.5 A4:.5 F4:1 | Bb4:.5 A4:.5 G4:.5 F4:.5 | E4:1 r:1 | G4:.5 Bb4:.5 A4:.5 G4:.5 | F4:.5 D4:.5 Bb3:1 | E4:.5 D4:.5 C#4:.5 E4:.5 | A3:1 r:1'
LIAO_B = 'F4:1 A4:.5 C5:.5 | D5:1 C5:.5 A4:.5 | Bb4:1 G4:1 | A4:1 r:1 | G4:.5 A4:.5 Bb4:1 | D5:.5 C5:.5 Bb4:1 | A4:.5 G4:.5 F4:.5 E4:.5 | C#4:1 r:1 | A4:.5 C5:.5 D5:1 | F5:.5 E5:.5 D5:1 | C5:.5 Bb4:.5 A4:.5 G4:.5 | F4:1 r:1 | G4:.5 Bb4:.5 D5:1 | C5:.5 A4:.5 G4:.5 F4:.5 | E4:.5 F4:.5 E4:.5 C#4:.5 | A3:1 r:1'
LIAO_C = 'D4:1 F4:1 | A4:1 r:1 | Bb4:1 A4:1 | G4:1 r:1 | F4:1 A4:1 | G4:1 F4:1 | E4:1 D4:1 | C#4:1 r:1 | D4:1 A3:1 | Bb3:1 D4:1 | G4:1 F4:1 | E4:1 r:1 | F4:1 D4:1 | Bb3:1 G3:1 | E4:.5 D4:.5 C#4:1 | A3:1 r:1'
LIAO_WA = 'D5:.5 A4:.5 F4:.5 E4:.5 | D4:.5 A4:.5 r:1 | F4:.5 A4:.5 C5:.5 F5:.5 | Bb4:.5 A4:.5 r:1 | G4:.5 A4:.5 Bb4:.5 G4:.5 | F4:.5 E4:.5 D4:.5 A4:.5 | E5:.5 F5:.5 E5:.5 C#5:.5 | A4:1 r:1 | D4:.5 F4:.5 A4:.5 D5:.5 | C5:.5 A4:.5 F4:.5 A4:.5 | Bb4:.5 A4:.5 G4:.5 F4:.5 | E4:.5 C#4:.5 r:1 | G4:.5 Bb4:.5 A4:.5 G4:.5 | F4:.5 D4:.5 Bb3:.5 D4:.5 | E4:.5 D4:.5 C#4:.5 E4:.5 | A4:1 r:1'
LH = ['D3:m','D3:m','F3:M','G2:m','G2:m','D3:m','A2:7','A2:7',
      'D3:m','F3:M','G2:m','A2:7','G2:m','Bb2:M','A2:7','A2:7']
LBH = ['F3:M','D3:m','G2:m','A2:7','G2:m','Bb2:M','C3:M','A2:7',
       'D3:m','D3:m','C3:M','F3:M','G2:m','F3:M','A2:7','A2:7']
LCH = ['D3:m','D3:m','G2:m','G2:m','F3:M','C3:M','D3:m','A2:7',
       'D3:m','Bb2:M','G2:m','A2:7','D3:m','G2:m','A2:7','A2:7']


def _liao(war=False):
    ens=[('lead','violin' if war else 'clarinet',-10,-.16),('counter','viola',-18,.25),
         ('bed','pizzicato' if not war else 'electric_guitar',-23,-.3),('bass','cello' if not war else 'bass',-14,0),
         ('drums','drums',-24,.08)]
    if war:
        ens += [('answer','trumpet',-17,.25),('pulse','pizzicato',-25,-.18)]
    s = _new('character_liao_warform' if war else 'character_liao',152,(2,4),ens,
             'D-A-F-E precise cut and one-beat withdrawal; warform widens register without losing the rest',
             'liao_axis_152_288')
    intro='D4:1 r:1 | A4:.5 F4:.5 E4:1 | D4:1 r:1 | A3:1 r:1 | Bb3:1 D4:1 | G4:1 r:1 | C#4:.5 E4:.5 A4:1 | r:2'
    _section(s,'order_before_motion',intro,LH[:8],'march',energy=-4)
    _section(s,'first_cut',LIAO_WA if war else LIAO_A,LH,'drive' if war else 'march',energy=6 if war else 1,
             answer='D4:1 r:1 | A3:1 r:1 | C4:1 r:1 | D4:1 r:1 | Bb3:1 r:1 | A3:1 r:1 | E4:1 r:1 | C#4:1 r:1 | D4:1 r:1 | C4:1 r:1 | Bb3:1 r:1 | C#4:1 r:1 | D4:1 r:1 | F3:1 r:1 | E4:1 r:1 | r:2' if war else None)
    _section(s,'formation_sweeps',LIAO_B,LBH,'drive',energy=7 if war else 3)
    _section(s,'measured_breath',LIAO_C,LCH,'march',energy=-1 if war else -6,
             counter='A3:1 r:1 | F3:1 r:1 | D4:1 r:1 | Bb3:1 r:1 | C4:1 r:1 | E4:1 r:1 | A3:1 r:1 | E3:1 r:1 | F3:1 r:1 | F3:1 r:1 | Bb3:1 r:1 | C#4:1 r:1 | A3:1 r:1 | D4:1 r:1 | E3:1 r:1 | r:2')
    _section(s,'second_cut',LIAO_WA if war else LIAO_A,LH,'drive',energy=8 if war else 4)
    _section(s,'formation_returns',LIAO_B,LBH,'drive',energy=9 if war else 5)
    _section(s,'discipline',LIAO_C,LCH,'march',energy=0 if war else -4)
    _section(s,'final_exchange',LIAO_WA if war else LIAO_A,LH,'drive',energy=9 if war else 5)
    _section(s,'controlled_withdrawal',LIAO_C,LCH,'march',energy=-1 if war else -5)
    _section(s,'order_repeated',intro,LH[:8],'march',energy=-4)
    return _finish(s)


def build_cues():
    return [_hero(), _hero(True), _cao(), _lubu(), _lubu(True),
            _road(), _siege(), _ritual(), _skirmish(), _pursuit(), _defense(), _duel(), _desperate(),
            _caoxiu(), _caochun(), _caochun(True), _liao(), _liao(True)]


def audit(scores):
    expected = {'hero_main','hero_daily','army_cao','boss_lubu','boss_lubu_warform',
                'battle_road','battle_siege','battle_ritual','battle_skirmish','battle_pursuit',
                'battle_defense','battle_duel','battle_desperate','army_caoxiu_warform',
                'army_caochun_human','army_caochun_warform','character_liao','character_liao_warform'}
    ids = set()
    for s in scores:
        validate(s)
        assert s['id'] not in ids
        ids.add(s['id'])
        assert all(p['notes'] for p in s['tracks']), (s['id'], 'empty part')
        duration = s['beats'] * 60 / s['bpm']
        low, high = (75, 140) if s['id'].startswith('battle_') else (100, 180)
        assert low <= duration <= high, (s['id'], 'duration', duration)
        lead = s['tracks'][0]['notes']
        active = sum(n[1] for n in lead) / s['beats']
        assert .12 < active < .85, (s['id'], 'lead breathing', active)
        assert 43 <= min(n[2] for n in lead) <= max(n[2] for n in lead) <= 88
        for previous, current in zip(lead, lead[1:]):
            assert previous[0] + previous[1] <= current[0] + 1e-5, (s['id'], 'lead overlap')
        assert s['sections'][0]['start'] == 0 and s['sections'][-1]['end'] == s['beats']
        print(f"{s['id']:28s} {s['bpm']:3d} bpm {s['meter']} {s['beats']:5.0f} qbeats "
              f"{s['beats']*60/s['bpm']:6.1f}s {len(s['tracks'])} parts "
              f"{sum(len(p['notes']) for p in s['tracks'])} notes")
    assert ids == expected, ('cue inventory', ids ^ expected)
    groups = {}
    for s in scores:
        groups.setdefault(s['sync_group'], []).append(s)
    for group, members in groups.items():
        if len(members) > 1:
            assert len({(s['bpm'],s['beats'],tuple(s['meter']),s['loop_start'],s['loop_end']) for s in members}) == 1, group
            assert len({tuple((x['start'],x['end']) for x in s['sections']) for s in members}) == 1, group
            assert len({tuple(tuple(x['harmony']) for x in s['sections']) for s in members}) == 1, (group, 'harmony axis')
    return scores


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--json', type=Path)
    args = parser.parse_args()
    scores = audit(build_cues())
    if args.json:
        args.json.write_text(json.dumps(scores, ensure_ascii=False, indent=2) + '\n')

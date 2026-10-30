"""World/location score: individually written themes, forms and ensemble plans."""
import argparse
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from scorelib import add_track, chord, copy_cue, cue, melody, note, validate, voicing


def harmony(part, symbols, start=0, bar=4, style='long', velocity=52):
    for index, symbol in enumerate(symbols.split()):
        tones = chord(symbol)
        at = start + index * bar
        if style == 'long':
            voicing(part, tones, at + .07, bar * .84, velocity, .012)
        elif style == 'open':
            voicing(part, [tones[0], tones[2]], at, bar * .9, velocity)
        elif style == 'waltz':
            note(part, at, .75, tones[0], velocity)
            for beat in range(1, int(bar)):
                voicing(part, [tones[1] + 12, tones[2] + 12], at + beat, .46, velocity - 7, .02)
        elif style == 'harp':
            # An unhurried arpeggio with a gap before the next harmonic change.
            pattern = [tones[0], tones[2], tones[1] + 12, tones[2] + 12]
            for beat, value in zip([0, bar * .25, bar * .5, bar * .625], pattern):
                note(part, at + beat, min(.9, bar * .23), value, velocity + (3 if beat == 0 else -3))
        elif style == 'market':
            for beat, duration in [(0, .48), (1.5, .38), (2.5, .42)]:
                voicing(part, [tones[1] + 12, tones[2] + 12], at + beat, duration, velocity, .025)
        else:
            raise ValueError(style)


def bass(part, symbols, start=0, bar=4, style='whole', velocity=57):
    for index, symbol in enumerate(symbols.split()):
        tones = chord(symbol)
        root = tones[0]
        while root > 52:
            root -= 12
        at = start + index * bar
        if style == 'whole':
            note(part, at, bar * .83, root, velocity)
        elif style == 'steps':
            for beat, value in [(0, root), (bar / 2, root + 7)]:
                note(part, at + beat, bar * .37, value, velocity - (4 if beat else 0))
        elif style == 'market':
            for beat, value, duration in [(0, root, .7), (1.5, root + 7, .42), (3, root, .5)]:
                note(part, at + beat, duration, value, velocity - int(beat) * 2)


TITLE_A = 'D5:1.5 A4:.5 F5:1 E5:1 | D5:2 r:1 A4:1 | Bb4:1 C5:1 D5:1 F5:1 | E5:2 r:1 C5:1 | D5:1 F5:1 G5:1 A5:1 | G5:1.5 F5:.5 E5:1 D5:1 | C5:1 D5:1 E5:1 G5:1 | E5:2 D5:1 r:1'
TITLE_B = 'F5:2 A5:1 C6:1 | Bb5:1.5 A5:.5 G5:1 F5:1 | E5:1 F5:1 G5:2 | A5:3 r:1 | D6:1 C6:1 A5:1 G5:1 | F5:2 D5:1 F5:1 | E5:1 G5:1 A5:1 C#6:1 | D6:2 A5:1 r:1'
TITLE_C = 'A4:2 r:1 D5:1 | C5:1 A4:1 F4:2 | G4:1 Bb4:1 D5:1 C5:1 | A4:3 r:1 | F5:1 E5:1 D5:2 | Bb4:2 G4:1 A4:1 | C#5:1 E5:1 A4:2 | r:1 A4:1 C#5:1 E5:1'
TITLE_HA = 'D3:m G2:m Bb2:M C3:M D3:m G2:M C3:M A2:sus4'
TITLE_HB = 'F3:M Bb2:M C3:M F3:M Bb2:M D3:m A2:7 D3:m'
TITLE_HC = 'D3:m F3:M G2:m A2:m Bb2:M G2:m A2:7 A2:7'


def title_overture():
    s = cue('title_overture', '山河未歇', 92, 48, target_lufs=-20,
            motifs=['world_ruins', 'journey'], form='A · B · C · A-answer · B-reprise · turn')
    lead = add_track(s, 'horn', 'Far horizon', -12, -.08)
    piano = add_track(s, 'piano', 'Human reply', -10, .08)
    fl = add_track(s, 'flute', 'Wind on the ruins', -15, -.19)
    strings = add_track(s, 'strings', 'Open harmony', -20, .19)
    low = add_track(s, 'cello', 'Ground', -16, -.08)
    hp = add_track(s, 'harp', 'Light between stones', -21, .22)
    percussion = add_track(s, 'drums', 'Distant procession', -22, 0)
    sections = [(TITLE_A,TITLE_HA,lead,64), (TITLE_B,TITLE_HB,lead,77),
                (TITLE_C,TITLE_HC,piano,56), (TITLE_A,TITLE_HA,fl,65),
                (TITLE_B,TITLE_HB,lead,82), (TITLE_C,TITLE_HC,piano,59)]
    for sec, (theme, chords, voice, velocity) in enumerate(sections):
        at = sec * 32
        melody(voice, theme, at, velocity=velocity, gate=.87, transpose=-12 if voice is lead else 0)
        harmony(strings, chords, at, style='open' if sec in (0,2,5) else 'long', velocity=42 if sec == 2 else 53)
        bass(low, chords, at, velocity=50 if sec in (2,5) else 62)
        if sec in (1,3,4):
            harmony(hp, chords, at, style='harp', velocity=50)
        if sec in (1,4):
            for bar in range(8):
                note(percussion, at + bar * 4, .36, 36, 52 + (bar % 2) * 7)
                if bar in (3,7):
                    note(percussion, at + bar * 4 + 2.5, .3, 38, 44)
        if sec == 4:
            melody(piano, 'r:2 C5:1 A4:1 | r:2 F5:1 D5:1 | r:2 E5:1 C5:1 | r:4 | r:2 F5:1 D5:1 | r:4 | r:2 E5:1 C#5:1 | r:4', at, velocity=53, gate=.7)
    return validate(s)


MAP_A = 'G4:1 A4:1 D5:1 | Bb4:1.5 A4:.5 G4:1 | F4:1 G4:1 A4:1 | D5:2 r:1 | Eb5:1 D5:1 Bb4:1 | A4:1 C5:1 D5:1 | G5:1 F5:1 D5:1 | Bb4:2 r:1'
MAP_B = 'D5:1 F5:1 G5:1 | A5:1.5 G5:.5 F5:1 | Eb5:1 D5:1 C5:1 | D5:2 r:1 | G5:1 A5:1 Bb5:1 | A5:1 F5:1 D5:1 | C5:1 A4:1 C5:1 | D5:2 r:1'
MAP_C = 'Bb4:2 r:1 | F5:1 D5:1 Bb4:1 | C5:1 Eb5:1 G5:1 | F5:2 r:1 | Eb5:1 D5:1 Bb4:1 | C5:1 A4:1 G4:1 | F#4:1 A4:1 C5:1 | A4:2 r:1'
MAP_HA = 'G2:m Eb3:M F3:M G2:m C3:m D3:sus4 Eb3:M Bb2:M'
MAP_HB = 'G2:m F3:M Eb3:M D3:7 G2:m Bb2:M C3:m D3:sus4'
MAP_HC = 'Bb2:M Bb2:M C3:m F3:M Eb3:M C3:m D3:7 D3:7'


def world_map():
    s = cue('world_map', '万里故山', 82, 48, meter=(3,4), target_lufs=-23,
            motifs=['world_distance'], form='A · A-response · B · C · B-open · A-return')
    flute = add_track(s, 'flute', 'Distance', -12, -.14)
    oboe = add_track(s, 'oboe', 'Wayfarer response', -14, .12)
    harp = add_track(s, 'harp', 'Slow water', -18, .22)
    strings = add_track(s, 'strings', 'Sky', -24, -.12)
    cello = add_track(s, 'cello', 'Riverbed', -17, 0)
    for sec, (theme, progression) in enumerate([(MAP_A,MAP_HA),(MAP_A,MAP_HA),(MAP_B,MAP_HB),(MAP_C,MAP_HC),(MAP_B,MAP_HB),(MAP_A,MAP_HA)]):
        at=sec*24
        voice=oboe if sec in (1,3) else flute
        melody(voice,theme,at,bar_beats=3,velocity=62+(sec==4)*8,gate=.83)
        harmony(harp,progression,at,bar=3,style='harp',velocity=44)
        bass(cello,progression,at,bar=3,velocity=49)
        if sec in (2,4):
            harmony(strings,progression,at,bar=3,style='open',velocity=42)
        if sec == 5:
            # Keep the final return small enough for indefinite map browsing.
            melody(oboe,'r:3 | r:1 D4:1 F4:1 | r:3 | Bb4:2 r:1 | r:3 | G4:1 F#4:1 A4:1 | r:3 | F#4:1 A4:1 r:1',at,bar_beats=3,velocity=43)
    return validate(s)


MARKET_A = 'E5:.5 G5:.5 B5:1 r:.5 A5:.5 G5:1 | F#5:.5 E5:.5 D5:1 B4:1 r:1 | C5:1 E5:.5 G5:.5 B5:1 A5:1 | F#5:1 D#5:.5 F#5:.5 B4:1 r:1 | E5:1 r:.5 B5:.5 A5:.5 G5:.5 E5:1 | F#5:1 A5:.5 C6:.5 B5:1 r:1 | G5:.5 E5:.5 D5:1 C5:.5 D5:.5 E5:1 | F#5:1 D#5:1 B4:1 r:1'
MARKET_B = 'G5:1 B5:1 D6:.5 B5:.5 A5:1 | C6:1 B5:.5 G5:.5 E5:1 r:1 | A5:.5 G5:.5 F#5:1 D5:1 A4:1 | B4:1 D5:.5 F#5:.5 G5:1 r:1 | E5:1 G5:1 C6:1 B5:1 | A5:1 F#5:.5 D5:.5 C5:1 r:1 | B4:.5 D#5:.5 F#5:1 A5:.5 F#5:.5 D#5:1 | E5:2 r:2'
MARKET_HA='E3:m7 D3:M C3:M7 B2:7 E3:m A2:m7 C3:M B2:7'
MARKET_HB='G2:M7 C3:M7 D3:7 G2:M A2:m D3:7 B2:7 E3:m'


def ghost_market():
    s=cue('region_ghost_market','灯下买卖',112,40,target_lufs=-22,
          motifs=['ghost_market'],form='A · B · instrumental conversation · A · B-thinned')
    cl=add_track(s,'clarinet','Seller',-13,-.16)
    ma=add_track(s,'marimba','Buyer',-13,.14)
    low=add_track(s,'contrabass_pizz','Shuffling feet',-13,-.04)
    pi=add_track(s,'pizzicato','Old counters',-19,.23)
    drums=add_track(s,'drums','Small wood responses',-24,-.1)
    bell=add_track(s,'bell','A lantern',-25,.18)
    for sec in range(5):
        at=sec*32
        progression=MARKET_HB if sec in (1,4) else MARKET_HA
        theme=MARKET_B if sec in (1,4) else MARKET_A
        melody(ma if sec==2 else cl,theme,at,velocity=65 if sec==4 else 74,gate=.72)
        bass(low,progression,at,style='market',velocity=60)
        harmony(pi,progression,at,style='market',velocity=48)
        if sec in (0,1,3):
            # Responses occupy rests rather than continuously doubling the tune.
            melody(ma,'r:3 E5:.5 B4:.5 | r:3 D5:.5 A4:.5 | r:4 | r:3 F#5:.5 D#5:.5 | r:4 | r:3 E5:.5 C5:.5 | r:4 | r:3 F#5:.5 B4:.5',at,velocity=48,gate=.55)
        if sec!=4:
            for bar in range(8):
                for beat, key, vel in [(0,37,39),(2.5,37,35)]:
                    note(drums,at+bar*4+beat,.15,key,vel)
        for b in [0,6]:
            note(bell,at+b*4+.5,.65,'B4' if b==0 else 'E5',35)
    return validate(s)


CITY_A='C4:2 G4:1 Eb4:1 | D4:1 C4:1 r:2 | Ab3:2 C4:1 Eb4:1 | F4:2 G4:1 r:1 | Bb4:1 Ab4:1 G4:1 Eb4:1 | F4:1 D4:1 C4:2 | D4:1 Eb4:1 G4:1 F4:1 | D4:2 r:2'
CITY_B='Eb5:1 Bb4:1 G4:2 | Ab4:2 C5:1 Eb5:1 | D5:1 C5:1 Bb4:1 G4:1 | F4:3 r:1 | Ab4:1 G4:1 Eb4:2 | F4:1 Ab4:1 C5:1 Bb4:1 | G4:1 F4:1 D4:1 B3:1 | C4:2 r:2'
CITY_HA='C3:m C3:m Ab2:M F3:m Eb3:M F3:m G2:sus4 G2:7'
CITY_HB='Eb3:M Ab2:M Bb2:M F3:m Ab2:M F3:m G2:7 C3:m'


def old_city():
    s=cue('region_old_city','旧城残照',78,40,target_lufs=-24,
          motifs=['baimen_stone'],form='low A · upper response · B · hollow return · distant B')
    ce=add_track(s,'cello','Stone memory',-12,-.1)
    ob=add_track(s,'oboe','Across the wall',-16,.15)
    hp=add_track(s,'harp','Dust',-23,.2)
    st=add_track(s,'strings','Old horizon',-25,-.15)
    low=add_track(s,'contrabass','Foundation',-23,0)
    for sec in range(5):
        at=sec*32
        theme=CITY_B if sec in (2,4) else CITY_A
        progression=CITY_HB if sec in (2,4) else CITY_HA
        melody(ce if sec in (0,3) else ob,theme,at,velocity=55 if sec==3 else 65,gate=.91,transpose=12 if sec==1 else 0)
        harmony(st,progression,at,style='open',velocity=39 if sec==3 else 46)
        bass(low,progression,at,velocity=43)
        if sec in (1,2,4):
            harmony(hp,progression,at,style='harp',velocity=39)
    return validate(s)


def camp_home():
    s=cue('camp_home','有灯可归',76,32,target_lufs=-24,
          motifs=['camp_hearth'],form='hearth · answer · open door · hearth return')
    guitar=add_track(s,'acoustic_guitar','Hearth strings',-12,-.13)
    cl=add_track(s,'clarinet','A familiar voice',-15,.14)
    ce=add_track(s,'cello','Warm foundation',-20,0)
    a='F4:1 A4:1 C5:1 A4:1 | G4:2 F4:1 r:1 | D4:1 F4:1 Bb4:2 | A4:1 G4:1 F4:1 r:1 | C5:1 D5:1 F5:1 E5:1 | D5:1 C5:1 A4:2 | G4:1 A4:1 Bb4:1 G4:1 | F4:2 r:2'
    b='A4:1 C5:1 F5:2 | E5:1 D5:1 C5:1 r:1 | Bb4:1 D5:1 G5:1 F5:1 | E5:2 C5:1 r:1 | D5:1 F5:1 A5:1 G5:1 | F5:2 D5:1 C5:1 | Bb4:1 A4:1 G4:1 E4:1 | C5:2 r:2'
    ha='F3:M C3:M Bb2:M F3:M D3:m F3:M G2:m C3:7'
    hb='F3:M C3:M G2:m C3:7 D3:m Bb2:M G2:m C3:7'
    for sec in range(4):
        at=sec*32
        progression=hb if sec==2 else ha
        melody(guitar if sec in (0,3) else cl,b if sec==2 else a,at,velocity=58 if sec==3 else 65,gate=.87)
        # Guitar melody and accompanying voicing use different registers.
        if sec in (1,2): harmony(guitar,progression,at,style='harp',velocity=43)
        bass(ce,progression,at,velocity=45)
        if sec==3:
            melody(cl,'r:4 | r:2 C4:1 E4:1 | r:4 | r:4 | r:2 A4:1 G4:1 | r:4 | r:2 D4:1 E4:1 | r:4',at,velocity=42)
    return validate(s)


def preparation():
    s=cue('preparation','拂去甲上尘',96,40,meter=(3,4),target_lufs=-24,
          motifs=['preparation'],form='thread · response · calculation · space · return')
    keys=add_track(s,'harpsichord','Measured hands',-17,-.13)
    pizz=add_track(s,'pizzicato','Inventory',-18,.18)
    ce=add_track(s,'cello','Steady resolve',-23,0)
    a='E4:1 B4:.5 G4:.5 F#4:1 | E4:1 r:1 B3:1 | C4:1 E4:1 G4:1 | F#4:2 r:1 | G4:1 B4:1 E5:1 | D5:1 B4:1 A4:1 | C5:1 A4:1 F#4:1 | B4:1 F#4:1 r:1'
    b='G4:1 D5:1 B4:1 | C5:1 B4:1 G4:1 | A4:1 C5:1 E5:1 | D5:2 r:1 | B4:1 A4:1 G4:1 | F#4:1 E4:1 D#4:1 | F#4:1 A4:1 B4:1 | E4:2 r:1'
    ha='E3:m E3:m C3:M B2:sus4 E3:m D3:M A2:m B2:7'
    hb='G2:M C3:M A2:m D3:M E3:m B2:7 B2:7 E3:m'
    for sec in range(5):
        at=sec*24
        progression=hb if sec in (2,3) else ha
        melody(pizz if sec==3 else keys,b if sec in (2,3) else a,at,bar_beats=3,velocity=54 if sec==3 else 62,gate=.65)
        bass(ce,progression,at,bar=3,velocity=42)
        if sec in (1,2,4):
            for index,symbol in enumerate(progression.split()):
                tones=chord(symbol)
                note(pizz,at+index*3+1,.4,tones[2]+12,40)
                note(pizz,at+index*3+2.5,.22,tones[1]+12,35)
    return validate(s)


def results_flow():
    s=cue('results_flow','旗落之后',108,32,meter=(6,8),target_lufs=-24,
          motifs=['small_victory'],form='A · reply · quiet B · return')
    pi=add_track(s,'piano','Count the survivors',-13,-.08)
    fl=add_track(s,'flute','Relief',-18,.13)
    ba=add_track(s,'contrabass_pizz','Resting pulse',-22,0)
    a='G4:1 B4:.5 D5:.5 B4:1 | A4:1 G4:1 r:1 | C5:1 B4:.5 A4:.5 G4:1 | D5:2 r:1 | E5:1 D5:1 B4:1 | C5:1 A4:1 F#4:1 | G4:1 B4:1 A4:1 | G4:2 r:1'
    b='B4:1 D5:1 G5:1 | F#5:1 E5:1 D5:1 | E5:1 C5:1 A4:1 | D5:2 r:1 | G5:1 E5:1 D5:1 | C5:1 B4:1 A4:1 | F#4:1 A4:1 D5:1 | G4:2 r:1'
    ha='G2:M D3:M C3:M G2:M E3:m A2:m D3:7 G2:M'
    hb='G2:M D3:M A2:m D3:7 C3:M G2:M D3:7 G2:M'
    for sec in range(4):
        at=sec*24
        progression=hb if sec==2 else ha
        melody(fl if sec==1 else pi,b if sec==2 else a,at,bar_beats=3,velocity=57,gate=.8)
        bass(ba,progression,at,bar=3,velocity=42)
        if sec==1: harmony(pi,progression,at,bar=3,style='waltz',velocity=42)
    return validate(s)


def archive_memories():
    s=cue('archive_memories','卷中旧事',66,24,target_lufs=-25,
          motifs=['memory'],form='a small recollection · contrasting recollection · incomplete return')
    pi=add_track(s,'piano','Ink',-14,-.1)
    va=add_track(s,'viola','Old voices',-18,.12)
    vi=add_track(s,'vibraphone','Margin light',-25,.23)
    a='Bb4:2 F5:1 D5:1 | C5:1 Bb4:1 r:2 | G4:1 Bb4:1 Eb5:2 | D5:3 r:1 | F5:1 G5:1 Bb5:2 | A5:1 F5:1 D5:2 | Eb5:1 D5:1 C5:1 A4:1 | Bb4:2 r:2'
    b='D5:1 F5:1 A5:2 | G5:2 D5:1 Bb4:1 | Eb5:1 F5:1 G5:1 Bb5:1 | A5:2 r:2 | C5:1 Eb5:1 G5:2 | F5:1 D5:1 Bb4:2 | A4:1 C5:1 F5:1 Eb5:1 | D5:2 r:2'
    ha='Bb2:M F3:M Eb3:M Bb2:M G2:m D3:m Eb3:M F3:7'
    hb='D3:m G2:m Eb3:M F3:M C3:m Bb2:M F3:7 Bb2:M'
    for sec in range(3):
        at=sec*32
        progression=hb if sec==1 else ha
        melody(va if sec==1 else pi,b if sec==1 else a,at,velocity=53 if sec==2 else 61,gate=.88,transpose=-12 if sec==1 else 0)
        if sec==1: harmony(pi,progression,at,style='long',velocity=38)
        for bar,symbol in enumerate(progression.split()):
            tones=chord(symbol)
            if sec!=1: note(va,at+bar*4+.2,3.2,tones[0]+12,37)
            if bar in (1,5): note(vi,at+bar*4+1,1.2,tones[2]+24,31)
    return validate(s)


def rest_spring():
    s=cue('rest_spring','石隙清泉',84,20,meter=(12,8),target_lufs=-25,
          motifs=['restoration'],form='five long breaths; sparse and unhurried')
    fl=add_track(s,'flute','Breath',-16,-.12)
    hp=add_track(s,'harp','Water',-20,.15)
    ce=add_track(s,'cello','Moss',-25,0)
    a='D5:2 F#5:1 A5:2 r:1 | B5:1 A5:1 F#5:2 E5:1 r:1 | G5:2 F#5:1 E5:1 D5:1 r:1 | E5:2 A4:2 r:2'
    b='F#5:1 A5:1 D6:2 C#6:1 r:1 | B5:2 F#5:1 E5:1 D5:1 r:1 | G5:2 B5:1 A5:1 F#5:1 r:1 | E5:2 C#5:2 r:2'
    for sec in range(5):
        at=sec*24
        progression='D3:add9 B2:m G2:M A2:sus4' if sec!=2 else 'D3:M B2:m7 G2:M A2:7'
        melody(fl,b if sec in (2,3) else a,at,bar_beats=6,velocity=51 if sec==4 else 59,gate=.84)
        harmony(hp,progression,at,bar=6,style='harp',velocity=40)
        bass(ce,progression,at,bar=6,velocity=36)
    return validate(s)


def journey_departure():
    s=cue('journey_departure','行囊与远路',112,64,meter=(2,4),target_lufs=-22,
          motifs=['journey'],form='departure · answer · wider horizon · return')
    ob=add_track(s,'oboe','A road ahead',-13,-.1)
    guitar=add_track(s,'acoustic_guitar','Steps',-16,.16)
    ba=add_track(s,'contrabass_pizz','Pace',-18,0)
    horn=add_track(s,'horn','Distant hills',-20,-.17)
    a='C5:.5 E5:.5 G5:1 | E5:1 r:.5 D5:.5 | C5:.5 D5:.5 E5:1 | G5:1 r:1 | A5:.5 G5:.5 E5:1 | F5:1 D5:1 | E5:.5 G5:.5 C6:1 | Bb5:1 r:1'
    b='G5:1 C6:.5 D6:.5 | E6:1 D6:1 | C6:.5 A5:.5 G5:1 | E5:1 r:1 | F5:.5 G5:.5 A5:1 | G5:1 E5:1 | D5:.5 E5:.5 F5:1 | G5:1 r:1'
    ha='C3:M C3:M F3:M C3:M A2:m D3:m C3:M Bb2:M'
    hb='C3:M G2:M A2:m C3:M F3:M C3:M D3:m G2:M'
    for sec in range(8):
        at=sec*16
        progression=hb if sec in (2,3,6) else ha
        melody(horn if sec in (3,5) else ob,b if sec in (2,3,6) else a,at,bar_beats=2,velocity=62 if sec==4 else 71,gate=.76,transpose=-12 if sec in (3,5) else 0)
        harmony(guitar,progression,at,bar=2,style='harp',velocity=44 if sec==4 else 51)
        bass(ba,progression,at,bar=2,style='steps',velocity=50)
    return validate(s)


def baimen_road():
    s=cue('region_baimen_road','远处白门',102,48,meter=(6,8),target_lufs=-23,
          motifs=['baimen_arrival'],form='road · questioning reply · city glimpsed · detour · return')
    fl=add_track(s,'flute','Roadside wind',-13,-.16)
    hp=add_track(s,'harp','Footpath',-19,.18)
    ce=add_track(s,'cello','Old ground',-18,0)
    ob=add_track(s,'oboe','Glimpse of the city',-16,.1)
    a='D5:1 A4:.5 C5:.5 D5:1 | F5:1 G5:.5 F5:.5 E5:1 | D5:1 C5:1 A4:1 | G4:2 r:1 | A4:1 C5:.5 D5:.5 F5:1 | E5:1 D5:.5 C5:.5 A4:1 | G4:1 A4:1 C5:1 | D5:2 r:1'
    b='A5:1 G5:1 F5:1 | E5:1 F5:1 D5:1 | C5:1 A4:1 G4:1 | A4:2 r:1 | D5:1 F5:1 A5:1 | C6:1 A5:.5 G5:.5 F5:1 | E5:1 D5:1 C5:1 | A4:2 r:1'
    ha='D3:m F3:M C3:M G2:M D3:m C3:M G2:M D3:m'
    hb='D3:m G2:M C3:M A2:m D3:m F3:M C3:M A2:sus4'
    for sec in range(6):
        at=sec*24
        progression=hb if sec in (2,4) else ha
        melody(ob if sec in (2,3) else fl,b if sec in (2,4) else a,at,bar_beats=3,velocity=60 if sec==3 else 68,gate=.82)
        harmony(hp,progression,at,bar=3,style='harp',velocity=42)
        bass(ce,progression,at,bar=3,style='whole',velocity=46)
    return validate(s)


def baimen_epilogue():
    s=cue('baimen_epilogue','白门余声',74,40,target_lufs=-23,
          motifs=['world_ruins','baimen_stone'],form='memory · consequence · open horizon · return · unresolved road')
    pi=add_track(s,'piano','What remains',-13,-.11)
    ce=add_track(s,'cello','Human memory',-16,.12)
    ho=add_track(s,'horn','Beyond the city',-18,-.2)
    st=add_track(s,'strings','Horizon',-25,.2)
    # The title theme returns, but a new middle avoids deciding anyone's future.
    middle='F5:2 C5:1 A4:1 | Bb4:1 D5:1 F5:2 | G5:1 F5:1 E5:1 D5:1 | C5:2 r:2 | A4:1 D5:1 F5:2 | E5:1 D5:1 Bb4:1 G4:1 | A4:2 C#5:1 E5:1 | D5:2 r:2'
    mh='F3:M Bb2:M G2:m C3:M D3:m G2:m A2:7 D3:m'
    for sec,(theme,progression) in enumerate([(TITLE_A,TITLE_HA),(middle,mh),(TITLE_B,TITLE_HB),(middle,mh),(TITLE_C,TITLE_HC)]):
        at=sec*32
        voice=pi if sec in (0,4) else ho if sec==2 else ce
        melody(voice,theme,at,velocity=66 if sec==2 else 57,gate=.9,transpose=-12 if voice in (ce,ho) else 0)
        harmony(st,progression,at,style='open',velocity=35 if sec==4 else 42)
        if voice is not pi: harmony(pi,progression,at,style='harp',velocity=39)
    return validate(s)


def build_cues():
    return [title_overture(),world_map(),camp_home(),preparation(),results_flow(),
            archive_memories(),rest_spring(),journey_departure(),baimen_road(),
            ghost_market(),old_city(),baimen_epilogue()]


def build_probes():
    result=[]
    for source in build_cues():
        s=copy_cue(source,source['id'],source['title'])
        s['beats']=min(s['beats'],64 if s['meter'][0]==4 else 48)
        s['loop']=False
        for part in s['tracks']:
            part['notes']=[n for n in part['notes'] if n[0]<s['beats']]
            for n in part['notes']:
                n[1]=min(n[1],s['beats']-n[0])
        result.append(validate(s))
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--json',type=Path)
    parser.add_argument('--probes',action='store_true')
    args=parser.parse_args()
    cues=build_probes() if args.probes else build_cues()
    if args.json:
        args.json.parent.mkdir(parents=True,exist_ok=True)
        args.json.write_text(json.dumps(cues,ensure_ascii=False,indent=2)+'\n')
    for item in cues:
        print(item['id'],len(item['tracks']),round(item['beats']*60/item['bpm'],2))

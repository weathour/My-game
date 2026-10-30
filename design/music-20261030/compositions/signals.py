"""Short authored musical punctuation, kept separate from background loops."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from scorelib import add_track, chord, cue, melody, note, validate, voicing


# Each phrase is notated in two-quarter bars. Most end before three seconds;
# natural release belongs to the renderer, not to an extra repeated score bar.
SCORES = [
 ('victory','小胜',112,'F5:.5 A5:.5 C6:.5 A5:.5 | F6:1.5 r:.5','F3:M F3:M','horn',False),
 ('important_victory','破阵',116,'D5:.5 F5:.5 A5:1 | Bb5:.5 A5:.5 G5:1 | A5:.5 C6:.5 F6:1','D3:m Bb2:M F3:M','trumpet',True),
 ('defeat','暂歇',76,'A4:.5 F4:.5 E4:1 | D4:1.5 r:.5','A2:sus4 D3:m','piano',False),
 ('recruit','新的同行者',108,'C5:.5 D5:.5 F5:1 | A5:.5 G5:.5 F5:1','F3:M F3:6','clarinet',False),
 ('elite','异客近前',128,'D4:.5 r:.5 Ab4:.5 A4:.5 | D5:1 r:1','D3:5 D3:5','trombone',True),
 ('boss','名将至',104,'D4:.5 D4:.5 A4:1 | F4:.5 E4:.5 D4:1','D3:5 Bb2:M','horn',True),
 ('transform','战相显',132,'r:2 | r:2','D3:5 D3:5','gong',True),
 ('discovery','灯火之外',120,'G5:.5 D6:.5 E6:1 | A6:1 r:1','G3:sus2 D3:sus2','harp',False),
 ('restore','泉声一滴',100,'D5:.5 E5:.5 A5:1 | F#5:.5 E5:.5 D5:1','D3:add9 D3:M','vibraphone',False),
 ('chapter_close','一程暂定',96,'D5:1 A4:1 | F5:.5 E5:.5 D5:1 | C5:1 D5:1','D3:m Bb2:M D3:sus2','piano',False),
 ('departure','启行',124,'C5:.5 E5:.5 G5:1 | A5:.5 G5:.5 C6:1','C3:M F3:M','oboe',True),
 ('arrival','望见城门',100,'G4:1 D5:.5 G5:.5 | A5:1 D5:1','G3:sus2 D3:sus4','horn',False),
 ('danger','危声',144,'C5:.5 Db5:.5 r:1 | C5:.5 Db5:.5 C5:.5 r:.5','C3:5 C3:5','strings',True),
 ('alliance','暂且同路',108,'D5:.5 F5:.5 A5:1 | G5:.5 E5:.5 F5:1','D3:m F3:6','clarinet',False),
 ('betrayal','裂隙',84,'A4:1 Eb5:.5 D5:.5 | C#5:1 r:1','A2:5 Eb3:5','piano',False),
 ('resolve','定意',100,'D5:1 A4:.5 D5:.5 | F5:.5 G5:.5 A5:1','D3:m D3:5','horn',False),
 ('mourning','无言',72,'F4:1 E4:.5 D4:.5 | A3:1 r:1','D3:m A2:5','cello',False),
 ('warmth','灯下',90,'F4:.5 A4:.5 C5:1 | A4:1 G4:.5 F4:.5','F3:M F3:6','acoustic_guitar',False),
 ('comic','话锋一转',132,'C4:.5 G4:.5 r:.5 E4:.5 | F4:.5 C4:.5 r:1','C3:M F3:M','bassoon',False),
 ('reward_rare','匣中微光',128,'D4:.25 F#4:.25 A4:.5 D5:1 | A4:1 r:1','D3:M D3:add9','bell',False),
 ('gate_open','门开',112,'G4:.5 D5:.5 G5:1 | F5:.5 D5:.5 C5:1','G3:5 C3:sus2','horn',True),
 ('retreat','收旗',112,'D5:.5 A4:.5 F4:1 | E4:1 A4:1','D3:m A2:sus4','oboe',False),
 ('memory','旧影',82,'Bb4:.5 F5:.5 D5:1 | C5:1 Bb4:1','Bb2:M F3:sus4','vibraphone',False),
 ('mystery','问影',88,'E5:.5 B5:.5 A5:1 | F5:1 r:1','E3:5 A2:m','harp',False),
]


def build_cues():
    result=[]
    for name,title,bpm,phrase,chords,instrument,percussion in SCORES:
        symbols=chords.split()
        s=cue('stinger_'+name,title,bpm,len(symbols),meter=(2,4),
              category='stinger',loop=False,target_lufs=-24,
              form='one-shot musical punctuation',purpose=name)
        lead=add_track(s,instrument,'Signal',-12 if instrument=='piano' else -15,0)
        if name=='transform':
            note(lead,0,1.5,60,62)
        else:
            melody(lead,phrase,bar_beats=2,velocity=72 if percussion else 61,gate=.85,
                   transpose=-12 if name in ('victory','important_victory','elite','arrival','resolve','gate_open') else 0)
        support=add_track(s,'piano' if name not in ('warmth','comic') else 'pizzicato','Harmonic landing',-22,.1)
        for index,symbol in enumerate(symbols):
            voicing(support,chord(symbol),index*2,1.6,46,.012)
        if percussion:
            drum=add_track(s,'drums','Small punctuation',-22,0)
            if name=='transform':
                for index in range(8):
                    note(drum,index*.25,.12,38,37+index*5)
                note(drum,2,.35,36,70)
                note(drum,2,.5,49,44)
            else:
                note(drum,0,.25,36,52)
                note(drum,1.5,.16,38,42)
                note(drum,2,.25,36,59)
        result.append(validate(s))
    if len({item['id'] for item in result})!=24:
        raise ValueError('Short cue roster drift')
    return result


if __name__=='__main__':
    import json
    cues=build_cues()
    print(json.dumps([{'id':c['id'],'seconds':round(c['beats']*60/c['bpm'],2)} for c in cues],indent=2))

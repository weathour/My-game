#!/usr/bin/env python3
"""Regenerate authored pressure configuration from the frozen pre-change input."""
import copy
import json
import math
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
BASE = json.loads((HERE / 'before.json').read_text())
DATA = copy.deepcopy(BASE)

def rounded(value):
    return round(value, 3)

def rewrite_literal(path, name, value):
    source = path.read_text()
    prefix = 'const ' + name + ' := '
    start = source.index(prefix) + len(prefix)
    _, length = json.JSONDecoder().raw_decode(source[start:])
    path.write_text(source[:start] + json.dumps(value, ensure_ascii=False, indent='\t') + source[start + length:])

# Bodies keep their economic/visual identity; most added bodies are disposable melee.
STATS = {
    'E01': (22, 84, 1), 'E02': (24, 52, 2), 'E03': (38, 128, 2),
    'E04': (62, 56, 3), 'E05': (32, 48, 2), 'E06': (38, 48, 3),
    'E07': (48, 46, 3), 'E08': (46, 18, 3), 'E09': (144, 40, 8),
    'E10': (116, 54, 7), 'E11': (132, 36, 8), 'E12': (164, 32, 9),
    'D01': (26, 92, 0),
}
for id, (hp, speed, xp) in STATS.items():
    DATA['enemies'][id].update(hp=hp, speed=speed, xp=xp)

# Early, middle and late encounters differ in active tactical capacity and influx.
for id, stage in DATA['stages'].items():
    n = int(id[1:])
    if n == 18:
        stage['boss_min_time'] = 0.0
        continue
    tier = 0 if n <= 6 else 1 if n <= 12 else 2
    stage.update(boss_min_time=28.0 + min(12, (n - 1)), enemy_cap=58 + (n - 1) * 2, spawn_interval=rounded(.78 - .012 * (n-1)),
                 boss_kills=int(round(stage['boss_kills'] * 3.2)),
                 action_budget={'major':3 + tier, 'melee':6 + tier * 2},
                 role_caps={'support':1 + int(tier == 2), 'heavy':2 + tier, 'ranged':5 + tier * 2})
    # Preserve level scaling and damage; the lower base HP is the fodder change.
    for wi, wave in enumerate(stage['waves']):
        original = wave['cycle']
        wave['cycle'] = []
        for kind in original:
            wave['cycle'].extend(['E01', 'E01', kind])
        wave.update(interval=rounded(stage['spawn_interval'] - wi * .06), count=4 + tier + wi)
    # A third, authored flank-pressure cycle preserves each node's tactical identity.
    last = copy.deepcopy(stage['waves'][-1])
    last.update(at=58., interval=rounded(stage['spawn_interval'] - .12), count=5 + tier)
    stage['waves'].append(last)


def warning(action):
    kind = action['action']
    action['warning_policy'] = 'none' if kind in ('shot', 'fan') else 'area'
    if kind in ('shot', 'fan'):
        action['bullet_style'] = 'needle' if kind == 'shot' else 'orb'

for id, enemy in DATA['enemies'].items():
    boss = enemy['rank'] == 'boss' or id == 'B10_R'
    heavy = enemy['rank'] in ('heavy', 'field_elite')
    n = int(id[1:]) if id.startswith('B') and id != 'B10_R' else 10
    for index, action in enumerate(enemy['attacks']):
        kind = action['action']
        warning(action)
        if boss:
            action['recovery'] = rounded(max(.75, action['recovery'] * .56))
            if kind in ('swipe', 'slam'):
                radius = (270 if n <= 2 else 330 if n <= 6 else 390) + index * 35
                action.update(range=radius, radius=radius, spread=2.35 + index * .2)
                action['windup'] = rounded(max(1.35, radius / 215 * .82))
            elif kind == 'charge':
                length = 780 if n <= 6 else 1060
                action.update(range=length, length=length, half_width=58 if n <= 6 else 76, windup=1.2)
            elif kind == 'fan':
                action.update(range=1100, radius=1100, count=15 if n <= 6 else 21,
                              spread=2.6 if n <= 6 else 3.4, speed=240, life=4.6, windup=1.05)
            elif kind == 'pot':
                action.update(range=1100, radius=135 if n <= 6 else 175, windup=1.25, duration=2.0)
            elif kind in ('anchor', 'pulse'):
                action.update(range=520, radius=520, inner_radius=100, gap_width=1.65, windup=1.7)
            elif kind == 'command':
                action.update(range=900, windup=1.0)
        else:
            action['recovery'] = rounded(max(.55, action['recovery'] * (.75 if heavy else .7)))
            if kind == 'shot':
                action.update(range=850, length=850, speed=245, life=3.5, windup=.7)
            elif kind == 'fan':
                action.update(range=820, count=9 if heavy else 7, spread=2.0, speed=190, life=4.4, windup=.85)
            elif kind == 'pot':
                action.update(range=750, radius=115 if heavy else 90, windup=1.0, duration=2.0)
            elif kind == 'charge':
                action.update(range=540, length=500, half_width=25, windup=.85)
            elif kind == 'hook':
                action.update(range=600, length=560, half_width=36, windup=.95, duration=1.6)
            elif kind in ('slam', 'pulse'):
                action.update(range=rounded(action['range'] * 1.3), radius=rounded(action['radius'] * 1.3))
            elif kind in ('swipe', 'strike'):
                action['windup'] = rounded(max(.38, action['windup'] * .9))
            elif kind in ('command', 'heal', 'summon'):
                action['windup'] = rounded(max(.8, action['windup'] * .85))

# Form-specific sequences retain all move IDs and their original action family.
for id, forms in DATA['forms'].items():
    for fi, form in enumerate(forms):
        for ai, action in enumerate(form['attacks']):
            warning(action)
            kind = action['action']
            action['recovery'] = rounded(max(.48, action['recovery'] * .58))
            if kind == 'charge':
                action.update(range=max(820, action['range'] * 1.25), length=max(820, action['length'] * 1.25),
                              half_width=action['half_width'] * 1.2, windup=1.15 if fi == 0 else 1.25)
            elif kind == 'slam':
                radius = min(550, action['radius'] * 1.22)
                action.update(range=radius, radius=radius, windup=rounded(max(1.25, radius / 215 * .76)))
            elif kind == 'fan':
                action.update(range=1200, radius=1200, count=19 if fi == 0 else 27,
                              spread=2.8 if fi == 0 else 3.8, speed=260 if fi == 0 else 240,
                              life=5.0, windup=1.0)
            elif kind == 'shot':
                action.update(range=1300, length=1300, speed=420, life=3.2, windup=.9, warning_policy='aim')
            elif kind == 'marker':
                radius = action['radius'] * 1.16
                action.update(radius=radius, windup=rounded((radius + 12) / 215 + .2))
            elif kind == 'pulse':
                action.update(range=min(650, action['radius'] * 1.2), radius=min(650, action['radius'] * 1.2),
                              gap_width=1.75, windup=1.8)
            elif kind == 'collaboration':
                action.update(range=1200, length=1100, half_width=80, radius=225,
                              windup=1.4, recovery=1.5)

# Frozen runtime protocol: burst/secondary projectiles and locked staggered markers.
def pattern(kind, count, speed, bursts=1, gap=1.0, spread=3.0, step=.1):
    value = dict(kind=kind, count=count, speed=speed, life=5.0, hit_radius=4.5,
                 burst_count=bursts, burst_interval=.34, angle_step=step,
                 angle_offset=0.0, aim_each_burst=False, bullet_style='orb')
    if kind == 'ring':
        value.update(gap_width=gap, gap_angle_offset=.65)
    else:
        value['spread'] = spread
    return value

for id, stage in DATA['stages'].items():
    for wi, wave in enumerate(stage['waves']):
        wave.update(formation=('surround', 'flank', 'intercept')[wi], spawn_radius=620,
                    formation_spread=1.25 if wi == 1 else 1.7, intercept_lead=1.0)

for id, enemy in DATA['enemies'].items():
    boss = enemy['rank'] == 'boss' or id == 'B10_R'
    heavy = enemy['rank'] in ('heavy', 'field_elite')
    n = int(id[1:]) if id.startswith('B') and id != 'B10_R' else 10
    for ai, action in enumerate(enemy['attacks']):
        kind = action['action']
        if kind in ('shot', 'fan'):
            action.update(hit_radius=4.0, burst_count=3 if boss else 2,
                          burst_interval=.3 if boss else .4, angle_step=.1,
                          aim_each_burst=False)
            if boss and n >= 10: action['burst_count'] = 4
        if boss:
            if kind in ('swipe', 'slam'):
                action['secondary_pattern'] = pattern('ring', 18 if n <= 2 else 28 if n <= 6 else 36,
                    155 if n <= 2 else 180, 1 if n <= 6 else 2, gap=1.2 if n <= 2 else 1.0)
            elif kind == 'charge':
                action['secondary_pattern'] = pattern('fan', 17 if n <= 6 else 23, 200, 2,
                    spread=3.6, step=.15)
            elif kind == 'command':
                action['secondary_pattern'] = pattern('fan', 25 if n < 10 else 31, 190, 3, spread=4.6, step=.16)
            elif kind == 'pot':
                action.update(marker_count=3, marker_spacing=action['radius'] * 1.7, marker_delay=.23)
                action['secondary_pattern'] = pattern('ring', 28, 165, 1, gap=1.15)
            elif kind in ('anchor', 'pulse'):
                action['secondary_pattern'] = pattern('ring', 40, 175, 3, gap=1.1, step=.08)
        elif kind == 'pot':
            action.update(marker_count=2 if heavy else 1, marker_spacing=175, marker_delay=.3)
        elif heavy and kind in ('slam', 'pulse'):
            action['secondary_pattern'] = pattern('ring', 22 if kind == 'pulse' else 16, 145, 1, gap=1.5)
        elif id == 'L05' and kind == 'hook':
            action['secondary_pattern'] = pattern('fan', 9, 180, 2, spread=2.4)

for id, forms in DATA['forms'].items():
    for fi, form in enumerate(forms):
        for action in form['attacks']:
            kind = action['action']
            if kind in ('shot', 'fan'):
                action.update(hit_radius=4.0, burst_count=3 if fi == 0 else 4,
                              burst_interval=.24 if kind == 'shot' else .32,
                              angle_step=.08, aim_each_burst=(kind == 'shot'))
            elif kind == 'charge':
                action['secondary_pattern'] = pattern('fan', 23 if fi == 0 else 31,
                    205, 2 if fi == 0 else 3, spread=4.0, step=.14)
            elif kind == 'slam':
                action['secondary_pattern'] = pattern('ring', 32 if fi == 0 else 44,
                    180 if fi == 0 else 195, 2, gap=1.0, step=.12)
            elif kind == 'marker':
                action.update(marker_count=3 if fi == 0 else 5,
                              marker_spacing=rounded(action['radius'] * 1.6), marker_delay=.18)
                action['secondary_pattern'] = pattern('ring', 34 if fi == 0 else 44, 175,
                    2, gap=1.1, step=.1)
            elif kind == 'pulse':
                action['secondary_pattern'] = pattern('ring', 44, 185, 3, gap=1.0, step=.1)
            elif kind == 'collaboration':
                action.update(marker_count=3, marker_spacing=320, marker_delay=.22)
                action['secondary_pattern'] = pattern('fan', 27 if fi == 0 else 35,
                    200, 3, spread=4.6, step=.12)



# Rejoin melee range after the long human lunge without increasing charge speed.
for action in DATA['forms']['B17'][0]['attacks']:
    if action['id'] == 'general_cut':
        action['approach_speed'] = 210


def write():
    rewrite_literal(ROOT/'scripts/content/enemy_catalog.gd', 'DEFINITIONS', DATA['enemies'])
    path = ROOT/'scripts/content/boss_forms.gd'
    source = path.read_text()
    if 'const FORM_DEFINITIONS := ' in source:
        rewrite_literal(path, 'FORM_DEFINITIONS', DATA['forms'])
    else:
        start = source.index('static func _authored(')
        source = source[:start] + 'static func _authored(id: String) -> Array:\n\treturn FORM_DEFINITIONS.get(id, []).duplicate(true)\n'
        point = source.index('static func forms(')
        source = source[:point] + 'const FORM_DEFINITIONS := ' + json.dumps(DATA['forms'],ensure_ascii=False,indent='\t') + '\n\n' + source[point:]
        path.write_text(source)
    rewrite_literal(ROOT/'scripts/content/stage_catalog.gd', 'STAGES', DATA['stages'])
    path = ROOT/'scripts/content/stage_catalog.gd'
    source = path.read_text().replace('value.enemy_cap < 28 or value.enemy_cap > 42','value.enemy_cap < 58 or value.enemy_cap > 94')
    source = source.replace('value.action_budget.major != (1 if id in ["B01", "B02"] else 2)', 'value.action_budget.major != (2 if duel else (3 if int(id.substr(1)) <= 6 else (4 if int(id.substr(1)) <= 12 else 5)))')
    path.write_text(source)
    (HERE/'after.json').write_text(json.dumps(DATA, ensure_ascii=False,indent=2)+'\n')

if __name__ == '__main__':
    write()

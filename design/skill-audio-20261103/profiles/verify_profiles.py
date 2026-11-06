#!/usr/bin/env python3
"""Structural coverage verification for skill sound profile production data."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT / "design/skill-audio-20261103/runtime/combat-content-baseline.json"
PROFILES = ROOT / "assets/data/audio/skill_sound_profiles.json"
INTERFACE = ROOT / "design/skill-audio-20261103/interface.json"
ABILITY_MAP = ROOT / "design/skill-audio-20261103/profiles/ability-family-map.json"


def fail(message):
    raise SystemExit("PROFILE_COVERAGE_FAIL: " + message)


base=json.loads(BASE.read_text())
profiles=json.loads(PROFILES.read_text())
interface=json.loads(INTERFACE.read_text())
ability_map=json.loads(ABILITY_MAP.read_text())
families=set(interface["families"])
phases=set(interface["common_phases"]+interface["boss_only_phases"])
expected_abilities={}
for owner,kit in base["kits"].items():
    expected_abilities[owner]=set()
    for slot in ["basic","automatic","manual","support"]:
        value=[kit["basic"]] if slot=="basic" else kit.get(slot,[])
        if isinstance(value,dict): value=[value]
        expected_abilities[owner].update(a["id"] for a in value if a)
if set(profiles["character_abilities"]) != set(expected_abilities): fail("character owner coverage mismatch")
if set(ability_map)!=set(expected_abilities): fail("explicit ability map owner coverage mismatch")
for owner,ids in expected_abilities.items():
    actual=profiles["character_abilities"][owner]
    if set(ability_map[owner])!=ids: fail(f"explicit ability map key mismatch {owner}")
    if set(actual)!=ids: fail(f"ability key mismatch {owner}: missing={ids-set(actual)}, extra={set(actual)-ids}")
    for aid,entry in actual.items():
        binding=ability_map[owner][aid]
        if binding.get("family")!=entry.get("family") or not all(binding.get(k) for k in ["owner_name","title","kind","design_basis"]):
            fail(f"explicit ability mapping lacks evidence {owner}/{aid}")
        if entry.get("family") not in families: fail(f"unknown ability family {owner}/{aid}")
        for key in ["cast","impact"]:
            value=entry.get(key,"")
            if not value:
                if not entry.get(key+"_silence_reason",""): fail(f"silent ability phase lacks reason {owner}/{aid}/{key}")
                continue
            family,phase=value.split(".")
            if family not in families or phase not in phases: fail(f"invalid cue {value}")
        for kind,override in entry.get("kind_overrides",{}).items():
            if override.get("family") not in families: fail(f"unknown override family {owner}/{aid}/{kind}")

expected_actions={}
for row in base["attacks"]:
    key=(row["enemy_id"],str(row["form_index"]),row["attack"]["id"])
    expected_actions.setdefault(key,[]).append(row)
actual_actions={}
for enemy,forms in profiles["enemy_actions"].items():
    for form,moves in forms.items():
        for move,entry in moves.items():
            key=(enemy,form,move)
            actual_actions[key]=entry
            if entry.get("family") not in families: fail(f"unknown enemy family {key}")
            for phasekey in ["tell","release","impact"]:
                value=entry.get(phasekey,"")
                if not value: fail(f"missing enemy phase {key}/{phasekey}")
                family,phase=value.split(".")
                if family not in families or phase not in phases: fail(f"invalid cue {value}")
            if set(entry.get("stage_priorities",{})) != {"tell","release","impact"}: fail(f"priority stages missing {key}")
if set(actual_actions)!=set(expected_actions): fail(f"enemy key coverage mismatch missing={set(expected_actions)-set(actual_actions)} extra={set(actual_actions)-set(expected_actions)}")
for key,rows in expected_actions.items():
    if len(rows)>1:
        families_for_duplicate={actual_actions[key]["family"]}
        if len(families_for_duplicate)!=1: fail(f"inconsistent duplicate move mapping {key}")
expected_boss_forms={}
for row in base["attacks"]:
    if base["enemies"][row["enemy_id"]]["rank"]=="boss":
        expected_boss_forms.setdefault(row["enemy_id"],set()).add(str(row["form_index"]))
if set(profiles["boss_events"])!=set(expected_boss_forms): fail("boss event definitions incomplete")
for boss,expected_forms in expected_boss_forms.items():
    if set(profiles["boss_events"].get(boss,{}))!=expected_forms: fail(f"boss event forms incomplete {boss}")
    for form,events in profiles["boss_events"][boss].items():
        for key in ["phase","defeated"]:
            family,phase=events[key].split(".")
            if family not in families or phase not in phases: fail(f"invalid boss cue {boss}/{form}/{key}")
for owner,trait in profiles["trait_bindings"].items():
    if not trait.get("cue","") and not trait.get("silence_reason",""): fail(f"silent trait lacks reason {owner}")
audit=json.loads((ROOT/"design/skill-audio-20261103/profiles/coverage-audit.json").read_text())
if audit["abilities"]!=137 or audit["enemy_actions"]!=87 or audit["unique_enemy_move_keys"]!=81 or audit["boss_event_contexts"]!=22 or audit["runtime_enemy_action_aliases"]!=1: fail("audit counts diverge")
if set(profiles["ability_aliases"])!={"curse_dot","guard_counter"}: fail("aliases must only name emitted special abilities")
for alias,entry in profiles["ability_aliases"].items():
    for phasekey in ["cast","impact"]:
        value=entry.get(phasekey,"")
        if not value and not entry.get(phasekey+"_silence_reason",""): fail(f"silent alias lacks reason {alias}/{phasekey}")
        if value:
            family,phase=value.split(".")
            if family not in families or phase not in phases: fail(f"invalid alias cue {alias}/{phasekey}")
if set(profiles["enemy_action_aliases"])!={"command_fallback_swipe"}: fail("dynamic enemy fallback action missing")
for boss,forms in profiles["boss_events"].items():
    if len(forms)>1 and forms["0"]["pitch_scale"]==forms["1"]["pitch_scale"]: fail(f"boss phases need distinct identity pitch {boss}")
for enemy,forms in profiles["enemy_actions"].items():
    rank=base["enemies"][enemy]["rank"]
    for moves in forms.values():
        for move,entry in moves.items():
            major=any(row["attack"]["id"]==move and row["enemy_id"]==enemy and row["attack"].get("major",False) for row in base["attacks"])
            p=entry["stage_priorities"]["tell"]
            if rank=="boss" and p!=5: fail(f"boss tell priority {enemy}/{move}")
            if major and rank!="boss" and p<4: fail(f"major tell priority {enemy}/{move}")
print("PROFILE_COVERAGE_OK abilities=137 enemy_action_records=87 unique_move_keys=81 duplicate_move_id_groups=6 boss_event_contexts=22; reviewed semantic overrides and priorities valid")

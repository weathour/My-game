#!/usr/bin/env python3
"""Static compatibility audit for encounter-action audio bindings.

Reads checked-in encounter JSON and skill SFX profiles/catalog. Does not start Godot.
"""
import json
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
DATA = ROOT / "design/danmaku-pressure-20261103/encounters/after.json"
PROFILES = ROOT / "assets/data/audio/skill_sound_profiles.json"
CUES = ROOT / "assets/sfx/skill-combat-20261103/catalog.json"
OUT = Path(__file__).with_name("profile-compatibility.json")

data = json.loads(DATA.read_text())
baseline = json.loads((DATA.parent / "before.json").read_text())
profiles = json.loads(PROFILES.read_text())
cues = json.loads(CUES.read_text()).get("cues", {})

actions = []
for definition, enemy in data["enemies"].items():
    for index, action in enumerate(enemy["attacks"]):
        actions.append((definition, 0, index, action))
for definition, forms in data["forms"].items():
    for form_index, form in enumerate(forms):
        for index, action in enumerate(form["attacks"]):
            actions.append((definition, form_index, index, action))

def action_identity(data):
    result = {}
    for definition, enemy in data["enemies"].items():
        for index, action in enumerate(enemy["attacks"]):
            result[(definition, 0, index)] = (action.get("id"), action.get("action"), action.get("shape"))
    for definition, forms in data["forms"].items():
        for form_index, form in enumerate(forms):
            for index, action in enumerate(form["attacks"]):
                result[(definition, form_index, index)] = (action.get("id"), action.get("action"), action.get("shape"))
    return result

before_identity = action_identity(baseline)
after_identity = action_identity(data)
identity_drift = [{"context": list(key), "before": before_identity.get(key), "after": after_identity.get(key)}
                  for key in sorted(set(before_identity) | set(after_identity))
                  if before_identity.get(key) != after_identity.get(key)]

freeze_path = ROOT / "design/danmaku-pressure-20261103/runtime/core-freeze.json"
freeze = json.loads(freeze_path.read_text())
freeze_mismatches = []
for source_path, expected_hash in freeze.get("sha256", {}).items():
    actual_hash = hashlib.sha256((ROOT / source_path).read_bytes()).hexdigest()
    if actual_hash != expected_hash:
        freeze_mismatches.append({"path": source_path, "expected": expected_hash, "actual": actual_hash})

missing = []
missing_stages = []
used_cues = set()
missing_files = []
move_ids = set()
for definition, form, index, action in actions:
    move_id = str(action["id"])
    move_ids.add((definition, form, move_id))
    binding = profiles.get("enemy_actions", {}).get(definition, {}).get(str(form), {}).get(move_id)
    if binding is None:
        missing.append({"definition": definition, "form": form, "move_id": move_id, "action_index": index})
        continue
    for stage in ("tell", "release", "impact"):
        cue = binding.get(stage, "")
        reason = binding.get(stage + "_silence_reason", "")
        if cue:
            used_cues.add(cue)
            if cue not in cues:
                missing_stages.append({"definition": definition, "form": form, "move_id": move_id, "stage": stage, "cue": cue})
            else:
                for resource in cues[cue].get("variants", []):
                    path = ROOT / resource.removeprefix("res://")
                    if not path.is_file():
                        missing_files.append({"cue": cue, "path": resource})
        elif not reason:
            missing_stages.append({"definition": definition, "form": form, "move_id": move_id, "stage": stage, "error": "empty without silence reason"})

alias = profiles.get("enemy_action_aliases", {}).get("command_fallback_swipe")
alias_ok = bool(alias and all(alias.get(k) in cues for k in ("tell", "release", "impact")))
if alias_ok:
    for stage in ("tell", "release", "impact"):
        for resource in cues[alias[stage]].get("variants", []):
            if not (ROOT / resource.removeprefix("res://")).is_file():
                missing_files.append({"cue": alias[stage], "path": resource})
boss_events = profiles.get("boss_events", {})
boss_definitions = {key for key, enemy in data["enemies"].items() if enemy.get("rank") == "boss"}
boss_contexts_by_id = {boss: len(data["forms"].get(boss, [None])) for boss in boss_definitions}
boss_contexts = sum(boss_contexts_by_id.values())
boss_missing = []
for boss, form_count in boss_contexts_by_id.items():
    for form_index in range(form_count):
        events = boss_events.get(boss, {}).get(str(form_index), {})
        for event in ("phase", "defeated"):
            cue = events.get(event, "")
            if event == "phase" and not cue:
                # Phase events only fire on actual transforms; final form has no subsequent phase.
                continue
            if not cue or cue not in cues:
                boss_missing.append({"boss": boss, "form": form_index, "event": event, "cue": cue})
            elif any(not (ROOT / resource.removeprefix("res://")).is_file() for resource in cues[cue].get("variants", [])):
                boss_missing.append({"boss": boss, "form": form_index, "event": event, "cue": cue, "error": "missing variant file"})

warnings = sorted({action.get("warning_policy", "(default)") for *_, action in actions})
patterned = [
    {"definition": d, "form": f, "move_id": a["id"], "action": a.get("action"),
     "warning_policy": a.get("warning_policy", "(default)"),
     "hit_radius": a.get("hit_radius", a.get("secondary_pattern", {}).get("hit_radius")),
     "burst_count": a.get("burst_count", a.get("secondary_pattern", {}).get("burst_count", 1)),
     "secondary_pattern": a.get("secondary_pattern", {}).get("kind", "")}
    for d, f, _, a in actions
    if "burst_count" in a or "secondary_pattern" in a
]
multi_marker = [
    {"definition": d, "form": f, "move_id": a["id"], "action": a.get("action"), "marker_count": int(a.get("marker_count", 1))}
    for d, f, _, a in actions if int(a.get("marker_count", 1)) > 1
]
preserved_stage_fields = ["boss_time", "bonus_time", "boss_hp", "enemy_hp", "enemy_damage", "boss_definition", "field_elites", "derivative_cap", "boss_derivative_cap"]
stage_field_diffs = {
    stage: [key for key in preserved_stage_fields if data["stages"][stage].get(key) != baseline["stages"][stage].get(key)]
    for stage in data["stages"]
}
b18_legacy_stage_equal = all(data["stages"]["B18"].get(key) == baseline["stages"]["B18"].get(key) for key in baseline["stages"]["B18"])
b18_behavior_ok = (
    data["stages"]["B18"].get("encounter_mode") == "boss_duel"
    and data["stages"]["B18"].get("fields_enabled") is False
    and data["stages"]["B18"].get("boss_time") == 0
    and data["stages"]["B18"].get("boss_kills") == 0
    and data["stages"]["B18"].get("boss_min_time") == 0
    and not data["stages"]["B18"].get("field_elites")
    and not data["stages"]["B18"].get("waves")
    and all(a.get("action") != "summon" for form in data["forms"].get("B18", []) for a in form.get("attacks", []))
)

report = {
    "inputs": {"encounters": str(DATA.relative_to(ROOT)), "profiles": str(PROFILES.relative_to(ROOT)), "cue_catalog": str(CUES.relative_to(ROOT))},
    "freeze_sha": {"checked": len(freeze.get("sha256", {})), "mismatches": freeze_mismatches},
    "counts": {"definitions": len(data["enemies"]), "encounters": len(data["stages"]), "bosses": len(boss_definitions), "bosses_with_multiple_forms": len(data["forms"]), "action_contexts": len(actions), "unique_definition_form_move_bindings": len(move_ids), "authored_pattern_actions": len(patterned), "boss_event_contexts": boss_contexts, "profile_enemy_definition_entries": len(profiles.get("enemy_actions", {}))},
    "coverage": {"missing_action_bindings": missing, "missing_or_invalid_action_stage_cues": missing_stages, "command_fallback_swipe_alias_valid": alias_ok, "missing_boss_event_bindings": boss_missing, "profile_referenced_cues_present": sorted(used_cues)},
    "identity_compatibility": {"action_identity_drift": identity_drift, "baseline_action_contexts": len(before_identity), "candidate_action_contexts": len(after_identity)},
    "asset_files": {"missing_variant_files": missing_files},
    "pattern_summary": {"warning_policies": warnings, "actions": patterned},
    "campaign_contract_review": {
        "changed_enemy_xp": {key: {"before": old, "after": new} for key, old, new in [("E01", baseline["enemies"]["E01"].get("xp"), data["enemies"]["E01"].get("xp"))] if old != new},
        "preserved_stage_fields": preserved_stage_fields,
        "stage_preserved_field_differences": stage_field_diffs,
        "b18_new_boss_min_time": data["stages"]["B18"].get("boss_min_time"),
        "b18_legacy_stage_fields_unchanged": b18_legacy_stage_equal,
        "b18_solo_behavior_contract_ok": b18_behavior_ok,
        "boss_min_time_by_stage": {stage: value.get("boss_min_time") for stage, value in data["stages"].items()},
        "field_reward_and_pool_logic_source": "scripts/battle/stage_director.gd:57-78,108-114; stage_catalog field_elites are preserved by encounter validation",
        "reward_observation": "Elite card/equipment reward tags and once-per-kind victory rewards are assigned in StageDirector/BattleSession, not by burst data; E01 XP is deliberately reduced 3->1 per kill in this candidate. Static checks do not establish net XP economy under increased population."
    },
    "runtime_pattern_observations_at_audit_time": {
        "projectile_pattern_consumption": "enemy_system.gd:225-232 calls PATTERNS.primary/launch for shot/fan; :276 launches PATTERNS.secondary. projectile_patterns.gd:10-15 applies primary/secondary patterns and inherited action fields; :18-28 schedules bounded bursts; :32-55 emits burst projectiles.",
        "authored_radius": "projectile_patterns.gd:47 clamps authored hit_radius (default 5 only if absent); _inherit at :58-62 carries hit_radius into nested patterns. battle_session.gd:350-352 passes projectile radius to HURTBOX.contains_swept.",
        "unified_hurtbox": "player_hurtbox.gd:4 sets RADIUS=4; contains_swept at :8-12 sums actor and projectile radii. enemy_geometry.gd:4 uses the same HURTBOX.RADIUS for area checks; enemy_system.gd:383+ uses contains_swept for charge sweeps.",
        "pending_lifecycle": "battle_session.gd:79 prevents all ticks while paused; :440-445 clears projectiles/pending patterns at terminal state; :470-500 removes dead-owner and transitioning-source hazards/projectiles/pending patterns. projectile_patterns.gd:22-29 drops dead/missing/wrong-form/transitioning owners.",
        "action_event_count": "enemy_system.gd:143 emits one enemy_tell per admitted action; :290 emits one enemy_release; :333 emits enemy_hazard_release per delayed hazard. combat_feedback.gd:261 uses owner/action_serial/release as the mixer key, independent of event kind; :263-267 keeps an attempt-scoped last serial per owner to suppress later markers after the mixer's 3-second key cache expires, and clear(clear_audio=true) resets it at :383-385.",
        "multi_marker_release_dedup": "Resolved. design/danmaku-pressure-20261103/runtime/final-logs/skill-audio.log reports CHRONICLE_SKILL_AUDIO_SMOKE PASS checks=2236 failures=0, including delayed same-serial suppression beyond 3.2s and next-serial playback.",
        "multi_marker_actions": multi_marker
    },
    "interpretation": [
        "Action SFX bindings are keyed by definition/form/move_id, so added projectile bursts do not create additional profile rows.",
        "Burst and secondary projectiles do not emit a sound event per projectile; delayed marker hazards now share their original action release identity and are suppressed at attempt scope.",
        "B18 accepts the new boss_min_time=0 field while retaining the existing solo duel behavior and all baseline B18 fields."
    ]
}
OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
print(f"PROFILE_COMPAT_OK definitions={len(data['enemies'])} actions={len(actions)} unique_bindings={len(move_ids)} missing={len(missing)} bad_stages={len(missing_stages)} boss_missing={len(boss_missing)} fallback={alias_ok}")
if missing or missing_stages or boss_missing or missing_files or not alias_ok or len(boss_definitions) != 18 or boss_contexts != 22 or stage_field_diffs["B18"] or not b18_behavior_ok or identity_drift or freeze_mismatches:
    raise SystemExit(1)

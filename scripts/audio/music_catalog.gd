extends RefCounted

const CUES := ["camp_signal", "stage_frontpost", "stage_rift", "stage_core", "elite_ram", "elite_splitshot", "boss_tree", "boss_rebirth", "boss_rose", "boss_spellcore_1", "boss_spellcore_2", "boss_spellcore_3", "victory", "defeat"]
const ENCOUNTERS := {
	"elite_ram_trail": "elite_ram", "elite_splitshot": "elite_splitshot",
	"smallboss_glutton": "boss_tree", "smallboss_rebirth": "boss_rebirth",
	"smallboss_turret": "boss_rose", "boss_spellcore": "boss_spellcore_1"
}
const STAGES := {"chapter1_stage1": "stage_frontpost", "chapter1_stage2": "stage_rift", "chapter1_stage3": "stage_core"}

static var arrival_cue: String = ""

static func path(cue: String) -> String:
	return "res://assets/music/%s.ogg" % cue if cue in CUES else ""

static func is_one_shot(cue: String) -> bool:
	return cue in ["victory", "defeat"]

static func same_phase_family(from: String, to: String) -> bool:
	return from.begins_with("boss_spellcore_") and to.begins_with("boss_spellcore_")

static func wave_cue(wave: int) -> String:
	if wave in [7, 12, 17]:
		return "stage_frontpost"
	return "stage_core" if wave >= 18 else "stage_rift" if wave >= 8 else "stage_frontpost"

static func battle_cue(view: Dictionary, encounters: Array) -> String:
	if str(view.get("outcome", "")) != "":
		return "victory" if view.outcome == "victory" else "defeat"
	if str(view.get("phase", "combat")) != "combat":
		return "camp_signal"
	var selected: String = ""
	var priority: int = 0
	for enemy in encounters:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.get("pooled_inactive") == true or enemy.get("runtime_configuration_complete") != true:
			continue
		# The rebirth tomb is still the same encounter, not a defeated Boss.
		if float(enemy.get("current_health")) <= 0.0 and float(enemy.get("rebirth_timer")) <= 0.0:
			continue
		var id := str(enemy.get("archetype_id"))
		if not ENCOUNTERS.has(id):
			continue
		var rank := 4 if id == "boss_spellcore" else 3 if id.begins_with("smallboss_") else 2 if id == "elite_ram_trail" else 1
		if rank > priority:
			priority = rank
			selected = "boss_spellcore_%d" % clampi(int(enemy.get("boss_phase")), 1, 3) if id == "boss_spellcore" else str(ENCOUNTERS[id])
	if selected != "":
		return selected
	if view.get("mode") == "story":
		return str(STAGES.get(str(view.get("stage_id", "")), "stage_frontpost"))
	return wave_cue(int(view.get("wave", 0)))

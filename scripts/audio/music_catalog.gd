extends RefCounted

const CUES := ["camp_signal", "stage_frontpost", "stage_rift", "stage_core", "elite_ram", "elite_splitshot", "boss_tree", "boss_rebirth", "boss_rose", "boss_spellcore_1", "boss_spellcore_2", "boss_spellcore_3", "victory", "defeat"]
const TRACK_INFO := {
	"camp_signal": {"title": "等一声回答", "scene": "主菜单、选档与营地", "kind": "场景配乐"},
	"stage_frontpost": {"title": "前哨的两条来路", "scene": "第一章·前哨清剿 / 无尽前段", "kind": "场景配乐"},
	"stage_rift": {"title": "裂隙另一侧的回声", "scene": "第一章·裂隙推进 / 无尽中段", "kind": "场景配乐"},
	"stage_core": {"title": "群星失去方向", "scene": "第一章·星核讨伐 / 无尽后段", "kind": "场景配乐"},
	"elite_ram": {"title": "踏破红线", "scene": "精英遭遇·冲锋骷髅", "kind": "场景配乐"},
	"elite_splitshot": {"title": "四向展开", "scene": "精英遭遇·分裂骷髅", "kind": "场景配乐"},
	"boss_tree": {"title": "根须记住了雨", "scene": "幽影树人 / 无尽第6波", "kind": "场景配乐"},
	"boss_rebirth": {"title": "第二次渡河", "scene": "引渡人 / 无尽第11波", "kind": "场景配乐"},
	"boss_rose": {"title": "八瓣回旋庭", "scene": "地瑰灵 / 无尽第16波", "kind": "场景配乐"},
	"boss_spellcore_1": {"title": "把回答带回黎明·第一相", "scene": "星核Boss·第一相 / 无尽第20波", "kind": "场景配乐"},
	"boss_spellcore_2": {"title": "把回答带回黎明·第二相", "scene": "星核Boss·第二相 / 无尽第20波", "kind": "场景配乐"},
	"boss_spellcore_3": {"title": "把回答带回黎明·第三相", "scene": "星核Boss·第三相 / 无尽第20波", "kind": "场景配乐"},
	"victory": {"title": "灯亮了", "scene": "胜利结算", "kind": "结算短曲"},
	"defeat": {"title": "信号仍在", "scene": "失败结算", "kind": "结算短曲"}
}
const ENCOUNTERS := {
	"elite_ram_trail": "elite_ram", "elite_splitshot": "elite_splitshot",
	"smallboss_glutton": "boss_tree", "smallboss_rebirth": "boss_rebirth",
	"smallboss_turret": "boss_rose", "boss_spellcore": "boss_spellcore_1"
}
const STAGES := {"chapter1_stage1": "stage_frontpost", "chapter1_stage2": "stage_rift", "chapter1_stage3": "stage_core"}

const MANIFEST := "res://assets/data/audio/music_catalog.json"
static var _chapter: Dictionary = {}
static var _loaded := false
static var arrival_cue: String = ""

static func chapter_cues() -> Array[String]:
	_load_chapter()
	var result: Array[String] = []
	for id: String in _chapter: result.append(id)
	return result

static func info(cue: String) -> Dictionary:
	_load_chapter()
	return _chapter.get(cue, TRACK_INFO.get(cue, {})).duplicate(true)

static func has_cue(cue: String) -> bool:
	_load_chapter()
	return cue in CUES or _chapter.has(cue)

static func _load_chapter() -> void:
	if _loaded: return
	_loaded = true
	if not FileAccess.file_exists(MANIFEST): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not parsed is Dictionary: return
	for entry: Dictionary in parsed.get("cues", []):
		var id := str(entry.get("id", ""))
		if not id.is_empty(): _chapter[id] = entry.duplicate(true)


static func path(cue: String) -> String:
	_load_chapter()
	return str(_chapter[cue].get("path", "")) if _chapter.has(cue) else "res://assets/music/%s.ogg" % cue if cue in CUES else ""

static func is_one_shot(cue: String) -> bool:
	return cue in ["victory", "defeat"] or (has_cue(cue) and not bool(info(cue).get("loop", true)))

static func same_phase_family(from: String, to: String) -> bool:
	if from.begins_with("boss_spellcore_") and to.begins_with("boss_spellcore_"): return true
	var a := info(from)
	var b := info(to)
	var family := str(a.get("phase_family", ""))
	return not family.is_empty() and family == str(b.get("phase_family", "")) and a.get("bpm") == b.get("bpm") and a.get("beats") == b.get("beats") and bool(a.get("loop", false)) and bool(b.get("loop", false))

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

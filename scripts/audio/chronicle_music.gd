extends RefCounted
## Presentation-only routing. Node identities never depend on the hovered map node.
const NODE_CUES := {
	"S01":"hero_daily", "B01":"battle_road", "S02":"character_emma_wary", "B02":"battle_road", "S03":"region_ghost_market",
	"B04":"battle_road", "B05":"battle_ritual", "B03":"battle_siege", "S04":"hero_main", "F01":"rest_spring", "B06":"battle_ritual", "S05":"story_banter",
	"B07":"battle_siege", "B08":"battle_siege", "B09":"battle_siege", "B10":"battle_siege", "S06":"story_resolve", "F02":"rest_spring",
	"S07":"character_lingqi", "S08":"story_tension", "S09":"character_lingqi_aftermath", "B11":"battle_ritual", "B12":"battle_ritual", "S10":"army_cao",
	"S11":"story_confrontation", "B13":"battle_siege", "B14":"battle_road", "B15":"army_cao", "S12":"region_old_city", "F03":"rest_spring", "B16":"army_caochun_human", "S13":"story_aftermath",
	"F04":"rest_spring", "B17":"character_liao", "B18":"boss_lubu", "S14":"baimen_epilogue"
}
const WARFORMS := {"B15":"army_caoxiu_warform", "B16":"army_caochun_warform", "B17":"character_liao_warform", "B18":"boss_lubu_warform"}
const SERIOUS_RESULTS := ["B06", "B15", "B16", "B17"]

static func node_cue(id: String) -> String:
	return str(NODE_CUES.get(id, "region_baimen_road"))

static func page_cue(page: String, current_node: String, previous: String = "") -> String:
	match page:
		"home": return "title_overture"
		"world": return "world_map"
		"route":
			if current_node in ["S03", "S04", "S05", "B03", "B04", "B05", "B06", "F01"]: return "region_ghost_market"
			if current_node in ["S07", "S08", "S09", "S10", "S11", "S12", "S13", "S14", "B11", "B12", "B13", "B14", "B15", "B16", "B17", "B18", "F03", "F04"]: return "region_old_city"
			return "region_baimen_road"
		"preparation": return "preparation"
		"reward": return "results_flow"
		"failure": return "story_solitude"
		"journal": return "archive_memories"
		"roster", "equipment": return "preparation" if previous == "preparation" else "camp_home"
		"menu", "settings", "saves": return "" # Utility overlays keep the owning scene's bed.
	return "camp_home"

static func battle_cue(id: String, form_index: int) -> String:
	return str(WARFORMS[id]) if form_index > 0 and WARFORMS.has(id) else node_cue(id)

static func story_cue(event: Dictionary, line_id: String) -> String:
	var cue := str(event.get("music", node_cue(str(event.get("id", "")))))
	# Reconstruct authored changes up to a checkpoint without replaying old stingers.
	for line: Dictionary in event.get("lines", []):
		if line.has("music"): cue = str(line.music)
		if str(line.get("id", "")) == line_id: break
	return cue

static func line_stinger(event: Dictionary, line_id: String) -> String:
	for line: Dictionary in event.get("lines", []):
		if str(line.get("id", "")) == line_id: return str(line.get("stinger", ""))
	return ""

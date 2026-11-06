extends RefCounted
## Presentation-only routing. Node identities never depend on the hovered map node.
const NODE_CUES := {
	"S01": "hero_daily",
	"B01": "midi_test_03",
	"S02": "midi_test_05",
	"B02": "midi_test_09",
	"S03": "midi_test_10",
	"B04": "midi_test_04",
	"B05": "midi_test_10",
	"B03": "midi_test_02",
	"S04": "midi_test_11",
	"F01": "rest_spring",
	"B06": "midi_test_06",
	"S05": "story_warmth",
	"B07": "midi_test_09",
	"B08": "midi_test_03",
	"B09": "midi_test_02",
	"B10": "midi_test_05",
	"S06": "midi_test_05",
	"F02": "rest_spring",
	"S07": "midi_test_05",
	"S08": "midi_test_08",
	"S09": "midi_test_08",
	"B11": "midi_test_10",
	"B12": "midi_test_06",
	"S10": "midi_test_06",
	"S11": "midi_test_03",
	"B13": "midi_test_03",
	"B14": "midi_test_09",
	"B15": "midi_test_04",
	"S12": "midi_test_05",
	"F03": "rest_spring",
	"B16": "midi_test_07",
	"S13": "midi_test_08",
	"F04": "rest_spring",
	"B17": "midi_test_12",
	"B18": "midi_test_01",
	"S14": "midi_test_11"
}
const ROUTE_SEGMENT_CUES := ["midi_test_11", "midi_test_10", "midi_test_09", "midi_test_10", "midi_test_06", "midi_test_05"]
static var _node_segments := {}

static func node_cue(id: String) -> String:
	return str(NODE_CUES.get(id, "midi_test_11"))

static func route_cue(current_node: String) -> String:
	if _node_segments.is_empty():
		var nodes: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/route.json"))
		if nodes is Array:
			for node: Dictionary in nodes: _node_segments[str(node.id)] = int(node.segment)
	var segment := int(_node_segments.get(current_node, -1))
	return str(ROUTE_SEGMENT_CUES[segment]) if segment >= 0 and segment < ROUTE_SEGMENT_CUES.size() else "midi_test_11"

static func page_cue(page: String, current_node: String, previous: String = "") -> String:
	match page:
		"home": return "midi_test_01"
		"world", "journal": return "midi_test_11"
		"route": return route_cue(current_node)
		"preparation": return "midi_test_05"
		"reward": return node_cue(current_node) # Same battle bed continues; reload starts the same full song.
		"failure": return "midi_test_08"
		"camp": return "camp_home"
		"roster", "equipment": return "midi_test_05" if previous == "preparation" else "camp_home"
		"menu", "settings", "saves", "help", "about", "music": return ""
	return "midi_test_11"

static func battle_cue(id: String, _form_index: int) -> String:
	return node_cue(id)

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

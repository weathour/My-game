extends RefCounted
## Pure appearance projection. It never mutates campaign progress or creates a save flag.
const COMMON := "common"
const CAMPAIGN := "campaign"
const LORD_FORMAL := "lord_formal"
const LORD_CASUAL := "lord_casual"
const APPEARANCES := [COMMON, CAMPAIGN, LORD_FORMAL, LORD_CASUAL]
const EXPRESSIONS := ["neutral", "smirk", "laugh", "approach"]
# Complete current route descendants of the first anti-Cao battles B13/B14.
# S10 is only a report and S11 is still the pre-battle alliance scene.
const ROUTE_NODES := ["S01","B01","S02","B02","S03","B04","B05","B03","S04","F01","B06","S05","B07","B08","B09","B10","S06","F02","S07","S08","S09","B11","B12","S10","S11","B13","B14","B15","S12","F03","B16","S13","F04","B17","B18","S14"]
const CAMPAIGN_NODES := ["B13","B14","B15","S12","F03","B16","S13","F04","B17","B18","S14"]

static func for_node(node_id: String) -> String:
	return CAMPAIGN if node_id in CAMPAIGN_NODES else COMMON

static func for_battle(request: Dictionary) -> String:
	return for_node(str(request.get("node",{}).get("id","")))

static func lord_unlocked(data: Dictionary) -> bool:
	return "B18" in data.get("completed", [])

static func normalize_appearance(value: String) -> String:
	return value if value in APPEARANCES else COMMON

static func normalize_expression(value: String) -> String:
	return value if value in EXPRESSIONS else "neutral"

static func portrait_pose(appearance: String, expression: String = "neutral") -> String:
	if appearance == LORD_FORMAL: return "laugh" if expression == "laugh" else "smirk"
	if appearance == LORD_CASUAL: return "approach" if expression == "approach" else "laugh"
	return "neutral"

static func for_campaign(data: Dictionary, context: String = "formal") -> String:
	if lord_unlocked(data): return LORD_CASUAL if context == "rest" else LORD_FORMAL
	if for_node(str(data.get("current","")))==CAMPAIGN: return CAMPAIGN
	for id in data.get("completed",[]):
		if for_node(str(id))==CAMPAIGN: return CAMPAIGN
	# Future available nodes are choices, not evidence that their scene was entered.
	return COMMON

static func for_scene(data: Dictionary, scene: String) -> String:
	# The existing post-chapter world/route surface is the returned camp.
	# Roster, equipment and formal cards continue to use for_campaign directly.
	var context := "rest" if bool(data.get("finished", false)) and scene in ["world", "route"] else "formal"
	return for_campaign(data, context)

static func _historical_gate_rank(node_id: String) -> int:
	# Completing either of these guarantees the final victory already happened.
	if node_id in ["B18", "S14"]: return 2
	return 1 if for_node(node_id) == CAMPAIGN else 0

static func for_story(event: Dictionary) -> String:
	if event.has("jia_appearance"):
		return normalize_appearance(str(event.jia_appearance))
	if str(event.get("id","")) in ROUTE_NODES: return for_node(str(event.id))
	# Optional scenes use authored historical gates, never the caller's live save.
	# AND prerequisites establish their latest required phase; OR prerequisites
	# guarantee only the earliest phase among their possible alternatives.
	var rank := 0
	var conditions: Dictionary = event.get("conditions", {})
	for id in conditions.get("completed_all", []):
		rank = maxi(rank, _historical_gate_rank(str(id)))
	var alternatives: Array = conditions.get("completed_any", [])
	if not alternatives.is_empty():
		var alternative_rank := 2
		for id in alternatives: alternative_rank = mini(alternative_rank, _historical_gate_rank(str(id)))
		rank = maxi(rank, alternative_rank)
	return [COMMON, CAMPAIGN, LORD_FORMAL][rank]

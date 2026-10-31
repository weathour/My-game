extends RefCounted
## Formal campaign boundary. Only validated victories mutate progression.
## UI rehearsal and legacy saves have separate schemas and directories.
const STORY_STATE := preload("res://scripts/campaign/campaign_story_state.gd")
const STORIES := preload("res://scripts/content/story_catalog.gd")
const STORY_CONDITIONS := preload("res://scripts/content/story_conditions.gd")
const CONTENT := preload("res://scripts/content/combat_catalog.gd")
const STORE := preload("res://scripts/campaign/campaign_store.gd")
const REWARDS := preload("res://scripts/campaign/reward_rules.gd")
const SUMMARY := preload("res://scripts/campaign/party_summary.gd")
signal changed
signal problem(message: String)
signal battle_requested(request: Dictionary)

const DIRECTORY := "user://chronicle_campaign_v1"
const SCHEMA := 1
const INITIAL_POOL := CONTENT.INITIAL_POOL
const SEGMENTS := ["城外来客", "夺寨聚众", "官印易主", "吕家风波", "协力守城", "白门终战"]
const UNLOCKS := {
	"S02":["F11"], "S03":["F03", "N18", "F04"], "S04":["F07", "M07", "F08"],
	"B06":["N14", "F05"], "S05":["F09"], "S06":["M08", "F02", "F06", "F10", "N02", "N05", "N08"],
	"B15":["M06", "N09", "N11", "N15"], "B16":["M05", "N12"],
	"B17":["M02", "M03", "M04", "N03", "N06", "N10"], "S14":["M01", "F01"]
}
const POST_BATTLE_STORIES := ["B06", "B15", "B16", "B17"]
const EQUIPMENT := CONTENT.EQUIPMENT

var characters: Dictionary = {}
var nodes: Dictionary = {}
var data: Dictionary = {}
var entry_snapshot: Dictionary = {}
var in_battle := false
var directory := DIRECTORY
var active_attempt := ""
var reward_rng := RandomNumberGenerator.new()

func _init() -> void:
	for character in JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/characters.json")):
		characters[character.id] = character
	for node in JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/route.json")):
		nodes[node.id] = node
	_refresh_descriptions()
	reset(false)

func reset(persist: bool = true) -> bool:
	var previous := data.duplicate(true)
	data = {"schema":SCHEMA, "scope":"campaign", "current":"S01", "completed":[],
		"available":["S01"], "pool":INITIAL_POOL.duplicate(), "owned":{"JIA":new_character("JIA")},
		"party":["", ""], "equipped":{"weapon":"plain_blade", "armor":"cloth_armor", "accessory":"ember_seal"},
		"inventory":["plain_blade", "cloth_armor", "ember_seal"], "pending":{}, "deferred_reward":{}, "story_checkpoint":{},
		"optional_story_read":[], "optional_story_checkpoints":{}, "story_contexts":{}, "battle_story_contexts":{},
		"log":[], "finished":false, "started":false, "reward_seed":int(randi() & 0x7fffffff), "reward_index":0, "last_result":""}
	entry_snapshot.clear()
	in_battle = false
	active_attempt = ""
	return commit(previous) if persist else true

func new_character(id: String) -> Dictionary:
	return CONTENT.record(id, CONTENT.entry_level(id))

func commit(previous: Dictionary) -> bool:
	if not save_slot("auto"):
		data = previous
		problem.emit("未能保存行军进度，本次操作未提交。请检查存储空间或目录权限。")
		return false
	changed.emit()
	return true

func begin_campaign() -> bool:
	var previous := data.duplicate(true)
	data.started = true
	return commit(previous)

func roster() -> Array:
	var result: Array = ["JIA"]
	for id in data.party:
		if not str(id).is_empty(): result.append(id)
	return result

func assign(id: String, slot: int) -> bool:
	if in_battle or not data.pending.is_empty() or slot not in [0, 1]: return false
	if id == "JIA" or (id != "" and (not data.owned.has(id) or data.owned[id].dead)): return false
	var previous := data.duplicate(true)
	for index in 2:
		if data.party[index] == id: data.party[index] = ""
	data.party[slot] = id
	return commit(previous)

func can_reposition_party(id: String, target_slot: int, source_slot: int = -1) -> bool:
	if in_battle or not data.pending.is_empty() or target_slot not in [-1, 0, 1] or source_slot not in [-1, 0, 1]: return false
	if id == "JIA" or not data.owned.has(id) or bool(data.owned[id].dead): return false
	if source_slot >= 0 and data.party[source_slot] != id: return false
	return target_slot >= 0 or id in data.party

func reposition_party(id: String, target_slot: int, source_slot: int = -1) -> bool:
	if not can_reposition_party(id, target_slot, source_slot): return false
	var origin: int = data.party.find(id)
	if origin == target_slot: return true
	var previous := data.duplicate(true)
	if target_slot == -1:
		data.party[origin] = ""
	else:
		var displaced: String = data.party[target_slot]
		if origin >= 0: data.party[origin] = displaced
		data.party[target_slot] = id
	return commit(previous)

func equip(id: String) -> bool:
	if in_battle or not data.pending.is_empty() or id not in data.inventory: return false
	for item in EQUIPMENT:
		if item.id == id:
			var previous := data.duplicate(true)
			data.equipped[item.slot] = id
			return commit(previous)
	return false

func choose_node(id: String) -> bool:
	if in_battle or not data.pending.is_empty() or id not in data.available: return false
	if awaiting_battle_story() and id != data.current: return false
	var previous := data.duplicate(true)
	if data.current != id: data.story_checkpoint = {}
	data.current = id
	return commit(previous)

func start_battle() -> Dictionary:
	if in_battle or not data.pending.is_empty() or not data.deferred_reward.is_empty() or data.current not in data.available: return {}
	var stage := CONTENT.stage(data.current)
	if stage.is_empty():
		problem.emit("这一段关卡尚在制作，当前行军进度已保留。")
		return {}
	entry_snapshot = data.duplicate(true)
	active_attempt = "%s-%s-%s" % [data.current, Time.get_ticks_usec(), randi()]
	in_battle = true
	var request := {"attempt_id":active_attempt, "node":nodes[data.current].duplicate(true), "members":roster(),
		"characters":data.owned.duplicate(true), "equipment":data.equipped.duplicate(true), "stage":stage, "seed":stage.seed}
	battle_requested.emit(request)
	return request

func abandon_battle() -> void:
	if not in_battle: return
	data = entry_snapshot.duplicate(true)
	active_attempt = ""
	in_battle = false
	entry_snapshot.clear()
	changed.emit()

func complete_battle(result: Dictionary) -> bool:
	if not in_battle or result.get("attempt_id", "") != active_attempt or result.get("outcome") != "victory": return false
	if data.last_result == active_attempt or not result.get("characters") is Dictionary: return false
	var updated_roster: Dictionary = data.owned.duplicate(true)
	for member in roster():
		if not _valid_record_shape(member, result.characters.get(member)): return false
		updated_roster[member] = result.characters[member]
	var bonuses := CONTENT.owned_bonuses(updated_roster)
	for member in roster():
		if not _valid_record(member, result.characters[member], bonuses, data.equipped): return false
	if result.characters.JIA.dead or result.characters.JIA.hp <= 0: return false
	var previous := entry_snapshot.duplicate(true)
	var id: String = data.current
	STORY_STATE.defaults(data)
	# Actual entrants survive auxiliary death/removal and are committed with victory.
	var entrants: Array = ["JIA"]
	for member in entry_snapshot.party:
		if member != "": entrants.append(member)
	data.battle_story_contexts[id] = entrants
	for member in roster(): data.owned[member] = result.characters[member].duplicate(true)
	for index in 2:
		var member: String = data.party[index]
		if member != "" and data.owned[member].dead: data.party[index] = ""
	if result.get("equipment_elite", false):
		for item in ["long_spear", "iron_armor", "frost_jade"]:
			if item not in data.inventory: data.inventory.append(item); break
	var extra: bool = result.get("card_elite", false)
	data.last_result = active_attempt
	data.log.append("%s · 击破%d · %.1f秒%s" % [nodes[id].name, result.get("kills", 0), result.get("elapsed", 0), " · 速胜经验" if result.get("fast_clear", false) else ""])
	in_battle = false
	if id == "B18":
		data.deferred_reward = {"id":id, "extra":extra}
		advance(id)
	elif id in POST_BATTLE_STORIES:
		# A won battle waits for its authored scene before unlocking the pool and
		# generating a concrete reward. The victory cannot be replayed meanwhile.
		data.deferred_reward = {"id":id, "extra":extra}
		data.available = [id]
		data.story_checkpoint = {}
	else:
		unlock(id)
		if not make_reward(id, extra): data = previous; in_battle = true; return false
	if not commit(previous):
		in_battle = true
		return false
	active_attempt = ""
	entry_snapshot.clear()
	return true

func save_story_checkpoint(event_id: String, line_id: String) -> bool:
	if in_battle or not data.pending.is_empty() or line_id.is_empty(): return false
	if event_id != data.current or event_id not in data.available or event_id not in nodes: return false
	if not event_available(event_id): return false
	var previous := data.duplicate(true)
	STORY_STATE.defaults(data)
	if not data.story_contexts.has(event_id): data.story_contexts[event_id] = _initial_story_context(event_id)
	if not STORIES.has_line(story_event(event_id), line_id): data = previous; return false
	data.story_checkpoint = {"event":event_id, "line":line_id}
	return commit(previous)

func _initial_story_context(id: String) -> Dictionary:
	# A pre-feature in-progress save has already entered its base scene.
	# Never invent a historical reaction from its later/current inventory.
	if data.get("story_checkpoint", {}).get("event") == id: return {"reactions":[]}
	return STORIES.select_context(id, data)

func story_event(id: String, replay: bool = false) -> Dictionary:
	var event: Dictionary = STORIES.optional_events().get(id, {})
	if event.is_empty() and nodes.has(id): event = STORIES.for_node(nodes[id])
	var contexts: Dictionary = data.get("story_contexts", {})
	# Completed old scenes without historical context deliberately contain base lines only.
	var context: Dictionary = contexts.get(id, {}) if replay or contexts.has(id) else _initial_story_context(id)
	return STORIES.resolved(event, context)

func optional_story_available(id: String) -> bool:
	var catalog := STORIES.optional_events()
	if not catalog.has(id) or id in data.get("optional_story_read", []): return false
	if data.get("optional_story_checkpoints", {}).has(id): return true
	return STORY_CONDITIONS.matches(catalog[id].get("conditions", {}), data)

func can_read_optional_story() -> bool:
	return not in_battle and data.pending.is_empty() and data.deferred_reward.is_empty()

func available_optional_stories() -> Array[String]:
	var result: Array[String] = []
	for id in STORIES.optional_events():
		if optional_story_available(id): result.append(id)
	return result

func read_optional_stories() -> Array:
	return data.get("optional_story_read", []).duplicate()

func save_optional_story_checkpoint(event_id: String, line_id: String) -> bool:
	if not can_read_optional_story() or not optional_story_available(event_id): return false
	var previous := data.duplicate(true)
	STORY_STATE.defaults(data)
	if not data.story_contexts.has(event_id): data.story_contexts[event_id] = _initial_story_context(event_id)
	if not STORIES.has_line(story_event(event_id), line_id): data = previous; return false
	data.optional_story_checkpoints[event_id] = line_id
	return commit(previous)

func complete_optional_story(id: String) -> bool:
	if not can_read_optional_story() or not optional_story_available(id): return false
	var previous := data.duplicate(true)
	STORY_STATE.defaults(data)
	if not data.story_contexts.has(id): data.story_contexts[id] = _initial_story_context(id)
	data.optional_story_read.append(id)
	data.optional_story_checkpoints.erase(id)
	return commit(previous)

func available_story_lore() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in STORIES.lore().values():
		if STORY_CONDITIONS.matches(entry.get("conditions", {}), data): result.append(entry.duplicate(true))
	return result

func resolve_event() -> bool:
	if in_battle or not data.pending.is_empty(): return false
	var id: String = data.current
	if not event_available(id): return false
	var previous := data.duplicate(true)
	STORY_STATE.defaults(data)
	if not data.story_contexts.has(id): data.story_contexts[id] = _initial_story_context(id)
	unlock(id)
	if awaiting_battle_story():
		var won: Dictionary = data.deferred_reward.duplicate()
		data.deferred_reward.clear()
		data.story_checkpoint = {}
		if not make_reward(id, won.extra): data = previous; return false
		return commit(previous)
	if id == "S02" and not data.owned.has("F11"):
		data.owned["F11"] = new_character("F11")
		data.log.append("艾玛随行 · 剧情加入，不占本关选卡名额。")
	if nodes[id].kind == "spring" or id == "S14":
		for member in data.owned:
			data.owned[member].hp = resource_max(member, "hp")
			data.owned[member].mp = resource_max(member, "mp")
			data.owned[member].dead = false
	if data.get("story_checkpoint", {}).get("event", "") == id: data.story_checkpoint = {}
	advance(id)
	if not data.deferred_reward.is_empty():
		var deferred: Dictionary = data.deferred_reward.duplicate()
		data.deferred_reward.clear()
		if not make_reward(deferred.id, deferred.extra): data = previous; return false
	return commit(previous)

func awaiting_battle_story() -> bool:
	return _awaiting_battle_story(data)

func _awaiting_battle_story(snapshot: Dictionary) -> bool:
	var id: String = str(snapshot.get("deferred_reward", {}).get("id", ""))
	return id in POST_BATTLE_STORIES and id == snapshot.get("current") and id in snapshot.get("available", []) and id not in snapshot.get("completed", [])

func event_available(id: String) -> bool:
	if in_battle or not data.pending.is_empty() or id not in data.available or id not in nodes: return false
	return nodes[id].kind in ["event", "spring"] or (id == data.current and awaiting_battle_story())

func is_story_node(id: String) -> bool:
	return nodes.has(id) and (nodes[id].kind in ["event", "spring"] or id in POST_BATTLE_STORIES)

func unlock(id: String) -> void:
	for card in UNLOCKS.get(id, []):
		if card not in data.pool: data.pool.append(card)

func advance(id: String) -> void:
	if id not in data.completed:
		data.completed.append(id)
		data.log.append(nodes[id].name)
	data.available = nodes[id].next.duplicate()
	if data.available.is_empty():
		data.finished = true
	else:
		data.current = data.available[0]

func make_reward(id: String, extra: bool) -> bool:
	var draft := _draft_reward(data, id, extra)
	if draft.is_empty():
		problem.emit("已解锁卡池不足以生成本关奖励，进度保留。")
		return false
	data.pending = draft
	data.reward_index += 1
	return true

func _draft_reward(snapshot: Dictionary, id: String, extra: bool) -> Dictionary:
	reward_rng.seed = int(snapshot.reward_seed) + int(snapshot.reward_index) * 104729
	var pool: Array = snapshot.pool.duplicate()
	# The first draft precedes Emma's event, including when recovering a legacy save.
	if id == "B01" and "S02" not in snapshot.completed and not snapshot.owned.has("F11"):
		pool.erase("F11")
	return REWARDS.draft(id, pool, characters, extra, reward_rng)

func select_card(id: String) -> bool:
	if data.pending.is_empty() or id not in data.pending.candidates: return false
	var previous := data.duplicate(true)
	if id in data.pending.selected: data.pending.selected.erase(id)
	elif data.pending.selected.size() < int(data.pending.picks): data.pending.selected.append(id)
	else: return false
	return commit(previous)

func claim_reward() -> bool:
	if data.pending.is_empty() or data.pending.selected.size() != int(data.pending.picks): return false
	var previous := data.duplicate(true)
	for id in data.pending.selected:
		if data.owned.has(id):
			data.owned[id].level += 1
		else: data.owned[id] = new_character(id)
	# All selected cards contribute before filling newly joined/upgraded bodies.
	# Unchanged bodies keep their resources; dead duplicate cards stay dead.
	for id in data.pending.selected:
		if not data.owned[id].dead:
			data.owned[id].hp = resource_max(id, "hp")
			data.owned[id].mp = resource_max(id, "mp")
	var id: String = data.pending.node
	data.pending.clear()
	if id not in data.completed: advance(id)
	return commit(previous)

func save_slot(slot: String) -> bool:
	var snapshot := entry_snapshot if in_battle else data
	if not valid(snapshot): return false
	return STORE.write(directory, slot, snapshot, valid)

func read_slot(slot: String) -> Dictionary:
	var value := STORE.read(directory, slot, valid)
	if value.is_empty(): return value
	# JSON has one numeric representation; normalize domain integers at the boundary.
	for key in ["schema", "reward_seed", "reward_index"]: value[key] = int(value[key])
	for id in value.owned:
		value.owned[id].level = int(value.owned[id].level)
		value.owned[id].xp = roundf(float(value.owned[id].xp) * 6.0) / 6.0
	if not value.pending.is_empty(): value.pending.picks = int(value.pending.picks)
	if not value.has("story_checkpoint"): value.story_checkpoint = {}
	STORY_STATE.defaults(value)
	# Schema 1 previously deferred B01 until S02. Recover its reward before the
	# event, retaining concrete candidates/selections if already generated.
	if value.deferred_reward.get("id", "") == "B01" and value.current == "S02" and not value.owned.has("F11"):
		if value.pending.is_empty():
			var draft := _draft_reward(value, "B01", value.deferred_reward.extra)
			if draft.is_empty(): return {}
			value.pending = draft
			value.reward_index += 1
		value.deferred_reward.clear()
		value.story_checkpoint.clear()
	# Additive content: completed gates gain new pool entries without rerolling a draft.
	for node in value.completed:
		for id in UNLOCKS.get(node, []):
			if id not in value.pool: value.pool.append(id)
	return value

func load_slot(slot: String) -> bool:
	if in_battle: return false
	var snapshot := read_slot(slot)
	if snapshot.is_empty():
		problem.emit("该行军档为空或内容损坏，当前进度保留。")
		return false
	var previous := data.duplicate(true)
	data = snapshot
	in_battle = false
	entry_snapshot.clear()
	return commit(previous)

func valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("schema") != SCHEMA or value.get("scope") != "campaign": return false
	for key in ["owned", "equipped", "pending", "deferred_reward"]:
		if not value.get(key) is Dictionary: return false
	for key in ["available", "completed", "pool", "party", "inventory", "log"]:
		if not value.get(key) is Array: return false
	if value.get("current", "") not in nodes or value.party.size() != 2 or not value.owned.has("JIA"): return false
	for id in value.owned:
		if not _valid_record_shape(id, value.owned[id]): return false
	var bonuses := CONTENT.owned_bonuses(value.owned)
	for id in value.owned:
		if not _valid_record(id, value.owned[id], bonuses, value.equipped): return false
	if value.owned.JIA.dead: return false
	for key in ["reward_seed", "reward_index"]:
		if typeof(value.get(key)) not in [TYPE_INT, TYPE_FLOAT] or value[key] < 0: return false
	if not value.get("last_result") is String: return false
	for id in value.party:
		if id != "" and (id == "JIA" or id not in value.owned or value.owned[id].dead): return false
	if value.party[0] != "" and value.party[0] == value.party[1]: return false
	for id in value.pool:
		if id not in CONTENT.IDS or id == "JIA": return false
	for id in value.available + value.completed:
		if id not in nodes: return false
	if value.has("story_checkpoint"):
		if not value.story_checkpoint is Dictionary: return false
		var checkpoint: Dictionary = value.story_checkpoint
		if not checkpoint.is_empty():
			if checkpoint.size() != 2 or not checkpoint.get("event") is String or not checkpoint.get("line") is String: return false
			if checkpoint.line.is_empty() or checkpoint.event != value.current or checkpoint.event not in value.available: return false
			if not value.pending.is_empty(): return false
			if nodes[checkpoint.event].kind not in ["event", "spring"] and not _awaiting_battle_story(value): return false
	if not STORY_STATE.valid(value, characters, nodes): return false
	for slot in ["weapon", "armor", "accessory"]:
		var found := false
		for item in EQUIPMENT:
			if item.id == value.equipped.get(slot) and item.slot == slot and item.id in value.inventory: found = true
		if not found: return false
	if not value.pending.is_empty():
		var pending: Dictionary = value.pending
		if not pending.get("candidates") is Array or not pending.get("selected") is Array: return false
		if pending.get("node", "") not in nodes or typeof(pending.get("picks")) not in [TYPE_INT, TYPE_FLOAT]: return false
		if pending.candidates.size() != (7 if pending.node == "B18" else 5): return false
		if typeof(pending.get("extra")) != TYPE_BOOL: return false
		if pending.picks != (3 if pending.node == "B18" else 2) + (1 if pending.extra else 0): return false
		if pending.picks < 2 or pending.picks > 4 or pending.selected.size() > pending.picks: return false
		var unique := {}
		for id in pending.candidates:
			if id not in value.pool or unique.has(id): return false
			unique[id] = true
		unique.clear()
		for id in pending.selected:
			if id not in pending.candidates or unique.has(id): return false
			unique[id] = true
	if not value.deferred_reward.is_empty():
		if value.deferred_reward.get("id") not in ["B01", "B18"] + POST_BATTLE_STORIES or typeof(value.deferred_reward.get("extra")) != TYPE_BOOL: return false
		if value.deferred_reward.id in POST_BATTLE_STORIES and (not _awaiting_battle_story(value) or not value.pending.is_empty()): return false
	for key in ["started", "finished"]:
		if typeof(value.get(key)) != TYPE_BOOL: return false
	return true

func _valid_record_shape(id: String, value: Variant) -> bool:
	if id not in CONTENT.IDS or not value is Dictionary: return false
	for key in ["level", "xp", "hp", "mp"]:
		if typeof(value.get(key)) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value[key])): return false
	if value.level < 1 or value.level > 9999 or value.level != int(value.level) or value.xp < 0 or value.hp < 0 or value.mp < 0: return false
	if value.xp >= CONTENT.xp_required(int(value.level)): return false
	if typeof(value.get("dead")) != TYPE_BOOL or not value.get("cooldowns") is Dictionary: return false
	if value.dead != (value.hp <= 0): return false
	for key in value.cooldowns:
		if typeof(key) not in [TYPE_STRING, TYPE_STRING_NAME] or typeof(value.cooldowns[key]) not in [TYPE_INT, TYPE_FLOAT]: return false
		if not is_finite(float(value.cooldowns[key])) or value.cooldowns[key] < 0: return false
	return true

func _valid_record(id: String, value: Variant, bonuses: Dictionary = {}, equipment: Dictionary = {}) -> bool:
	if not _valid_record_shape(id, value): return false
	var limits := CONTENT.attributes(id, int(value.level), bonuses, equipment)
	return value.hp <= limits.hp + 0.001 and value.mp <= limits.mp + 0.001

func resource_max(id: String, stat: String) -> float:
	if id not in CONTENT.IDS: return 100.0
	var level: int = int(data.owned[id].level) if data.owned.has(id) else CONTENT.entry_level(id)
	return float(CONTENT.attributes(id, level, CONTENT.owned_bonuses(data.owned), data.equipped)[stat])

func display_stats(id: String) -> Array:
	if id not in CONTENT.IDS: return ["此人物能力尚未制作。"]
	var level: int = int(data.owned[id].level) if data.owned.has(id) else CONTENT.entry_level(id)
	var stats := CONTENT.attributes(id, level, CONTENT.owned_bonuses(data.owned), data.equipped)
	var result: Array = []
	var names := {"hp":"生命上限", "mp":"魔法上限", "attack":"攻击", "armor":"防御", "speed":"攻击速度", "move":"移动速度", "regen":"魔法回复"}
	for key in names: result.append("%s %.2f" % [names[key], stats[key]])
	if data.owned.has(id): result.append("经验 %.1f / %.0f" % [data.owned[id].xp, CONTENT.xp_required(level)])
	return result

func party_summary() -> Dictionary:
	return SUMMARY.build(data, characters)

func battle_available(id: String) -> bool:
	return not CONTENT.stage(id).is_empty()

func _refresh_descriptions() -> void:
	for id in characters:
		if id not in CONTENT.IDS:
			characters[id].front = "设计预览 · 尚未实装\n" + characters[id].front
			continue
		var def := CONTENT.definition(id)
		characters[id].level = CONTENT.entry_level(id)
		characters[id].skills = []
		for ability in def.manual: characters[id].skills.append("%s · Lv.%d · %d魔法" % [ability.title, ability.unlock_level, ability.mana_cost])
		characters[id].back = def.back_text
		characters[id].owned = def.owned_text
		characters[id].front = CONTENT.ability_description(CONTENT.basic(id, {}), characters[id].level)
		var trait_text := CONTENT.trait_description(id)
		if not trait_text.is_empty(): characters[id].front += "\n" + trait_text

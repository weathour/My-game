extends RefCounted
## Formal campaign boundary. Only validated victories mutate progression.
## UI rehearsal and legacy saves have separate schemas and directories.
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
const UNLOCKS := {"S02":["F11"], "S03":["F03", "N18"], "S04":["F07"], "B06":["N14"]}
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
		"inventory":["plain_blade", "cloth_armor", "ember_seal"], "pending":{}, "deferred_reward":{},
		"log":[], "finished":false, "started":false, "reward_seed":int(randi() & 0x7fffffff), "reward_index":0, "last_result":""}
	entry_snapshot.clear()
	in_battle = false
	active_attempt = ""
	return commit(previous) if persist else true

func new_character(id: String) -> Dictionary:
	return CONTENT.record(id, int(characters[id].level))

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
	var previous := data.duplicate(true)
	data.current = id
	return commit(previous)

func start_battle() -> Dictionary:
	if in_battle or not data.pending.is_empty() or data.current not in data.available: return {}
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
	for member in roster():
		if not _valid_record(member, result.characters.get(member)): return false
	if result.characters.JIA.dead or result.characters.JIA.hp <= 0: return false
	var previous := entry_snapshot.duplicate(true)
	var id: String = data.current
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
	if id in ["B01", "B18"]:
		data.deferred_reward = {"id":id, "extra":extra}
		advance(id)
	else:
		unlock(id)
		if not make_reward(id, extra): data = previous; in_battle = true; return false
	if not commit(previous):
		in_battle = true
		return false
	active_attempt = ""
	entry_snapshot.clear()
	return true

func resolve_event() -> bool:
	if in_battle or not data.pending.is_empty(): return false
	var id: String = data.current
	if id not in data.available or nodes[id].kind not in ["event", "spring"]: return false
	var previous := data.duplicate(true)
	unlock(id)
	if id == "S02" and not data.owned.has("F11"):
		data.owned["F11"] = new_character("F11")
		data.log.append("艾玛随行 · 剧情加入，不占本关选卡名额。")
	if nodes[id].kind == "spring" or id == "S14":
		for member in data.owned:
			data.owned[member].hp = resource_max(member, "hp")
			data.owned[member].mp = resource_max(member, "mp")
			data.owned[member].dead = false
	advance(id)
	if not data.deferred_reward.is_empty():
		var deferred: Dictionary = data.deferred_reward.duplicate()
		data.deferred_reward.clear()
		if not make_reward(deferred.id, deferred.extra): data = previous; return false
	return commit(previous)

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
	reward_rng.seed = int(data.reward_seed) + int(data.reward_index) * 104729
	var draft := REWARDS.draft(id, data.pool, characters, extra, reward_rng)
	if draft.is_empty():
		problem.emit("已解锁卡池不足以生成本关奖励，进度保留。")
		return false
	data.pending = draft
	data.reward_index += 1
	return true

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
			if not data.owned[id].dead:
				data.owned[id].hp = resource_max(id, "hp")
				data.owned[id].mp = resource_max(id, "mp")
		else: data.owned[id] = new_character(id)
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
		if not _valid_record(id, value.owned[id]): return false
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
		if value.deferred_reward.get("id") not in ["B01", "B18"] or typeof(value.deferred_reward.get("extra")) != TYPE_BOOL: return false
	for key in ["started", "finished"]:
		if typeof(value.get(key)) != TYPE_BOOL: return false
	return true

func _valid_record(id: String, value: Variant) -> bool:
	if id not in CONTENT.IDS or not value is Dictionary: return false
	for key in ["level", "xp", "hp", "mp"]:
		if typeof(value.get(key)) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value[key])): return false
	if value.level < 1 or value.level > 9999 or value.level != int(value.level) or value.xp < 0 or value.hp < 0 or value.mp < 0: return false
	if value.xp >= CONTENT.xp_required(int(value.level)): return false
	if typeof(value.get("dead")) != TYPE_BOOL or not value.get("cooldowns") is Dictionary: return false
	if value.dead != (value.hp <= 0): return false
	var limits := CONTENT.attributes(id, int(value.level))
	if value.hp > limits.hp or value.mp > limits.mp: return false
	for key in value.cooldowns:
		if typeof(key) not in [TYPE_STRING, TYPE_STRING_NAME] or typeof(value.cooldowns[key]) not in [TYPE_INT, TYPE_FLOAT]: return false
		if not is_finite(float(value.cooldowns[key])) or value.cooldowns[key] < 0: return false
	return true

func resource_max(id: String, stat: String) -> float:
	if id not in CONTENT.IDS: return 100.0
	var level: int = int(data.owned[id].level) if data.owned.has(id) else int(characters[id].level)
	return float(CONTENT.attributes(id, level, CONTENT.owned_bonuses(data.owned), data.equipped)[stat])

func display_stats(id: String) -> Array:
	if id not in CONTENT.IDS: return ["此人物能力尚未制作。"]
	var level: int = int(data.owned[id].level) if data.owned.has(id) else int(characters[id].level)
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
		characters[id].skills = []
		for ability in def.manual: characters[id].skills.append("%s · Lv.%d · %d魔法" % [ability.title, ability.unlock_level, ability.mana_cost])
		characters[id].back = def.back_text
		characters[id].owned = def.owned_text
		if id == "F11": characters[id].front = "自动远程术法；Lv.2解锁不耗魔的自动冰星。霜环减速近身敌人，Lv.3解锁高伤星火。"

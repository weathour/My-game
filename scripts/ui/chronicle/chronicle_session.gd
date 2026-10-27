extends RefCounted
## UI rehearsal state, deliberately separate from legacy campaign/game saves.
## A future combat adapter consumes battle_requested and supplies resolved results.
signal changed
signal problem(message: String)
signal battle_requested(request: Dictionary)

const DIRECTORY := "user://chronicle_ui_v1"
const SCHEMA := 1
const INITIAL_POOL := ["N01", "N04", "N07", "N13", "N16", "N17"]
const SEGMENTS := ["城外来客", "夺寨聚众", "官印易主", "吕家风波", "协力守城", "白门终战"]
const UNLOCKS := {
	"S02": ["F11"], "S03": ["F03", "F04", "F09", "N18"],
	"S04": ["M07", "F07", "F08"], "B06": ["F05", "N14"],
	"S06": ["M08", "F06", "F10", "N02", "N05", "N08"],
	"B15": ["M06", "N09", "N11"], "B16": ["M05", "N12", "N15"],
	"B17": ["M02", "M03", "M04", "N03", "N06", "N10"], "S14": ["M01", "F01"]
}
const EQUIPMENT := [
	{"id":"plain_blade", "name":"旧铁刀", "slot":"weapon", "effect":"主角普攻：近身横斩", "detail":"主角攻击形态 · 辅助保留自身攻击。", "mark":"刀"},
	{"id":"long_spear", "name":"破阵长枪", "slot":"weapon", "effect":"主角普攻：长线突刺", "detail":"较窄的攻击范围，更长的攻击距离。", "mark":"枪"},
	{"id":"cloth_armor", "name":"行旅布甲", "slot":"armor", "effect":"受击后短暂提高移动速度", "detail":"由实际承伤者触发，展示效果尚未接入战斗。", "mark":"甲"},
	{"id":"iron_armor", "name":"旧军铁甲", "slot":"armor", "effect":"受击时产生短暂护身效果", "detail":"实际承伤者生效；具体数值留待战斗设计。", "mark":"铠"},
	{"id":"ember_seal", "name":"余烬符", "slot":"accessory", "effect":"当前人物的直接攻击附带火焰", "detail":"默认覆盖普攻与技能；后台支援、召唤物不自动继承。", "mark":"火"},
	{"id":"frost_jade", "name":"寒泉玉", "slot":"accessory", "effect":"当前人物的直接攻击附带寒霜", "detail":"基础属性加成面向本关队伍；附魔面向当前攻击者。", "mark":"霜"}
]

var characters: Dictionary = {}
var nodes: Dictionary = {}
var data: Dictionary = {}
var entry_snapshot: Dictionary = {}
var in_battle := false
var directory := DIRECTORY

func _init() -> void:
	for character in JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/characters.json")):
		characters[character.id] = character
	for node in JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/route.json")):
		nodes[node.id] = node
	reset(false)

func reset(persist: bool = true) -> bool:
	var previous := data.duplicate(true)
	data = {"schema":SCHEMA, "scope":"ui_rehearsal", "current":"S01", "completed":[],
		"available":["S01"], "pool":INITIAL_POOL.duplicate(), "owned":{"JIA":new_character("JIA")},
		"party":["", ""], "equipped":{"weapon":"plain_blade", "armor":"cloth_armor", "accessory":"ember_seal"},
		"inventory":["plain_blade", "cloth_armor", "ember_seal"], "pending":{}, "deferred_reward":{},
		"log":[], "finished":false, "started":false}
	entry_snapshot.clear()
	in_battle = false
	return commit(previous) if persist else true

func new_character(id: String) -> Dictionary:
	return {"level":int(characters[id].level), "xp":0, "hp":100, "mp":100, "dead":false, "cooldowns":[0.0, 0.0]}

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
	if nodes[data.current].kind not in ["battle", "elite", "boss"]: return {}
	entry_snapshot = data.duplicate(true)
	in_battle = true
	var request := {"node":nodes[data.current].duplicate(true), "members":roster(),
		"characters":data.owned.duplicate(true), "equipment":data.equipped.duplicate(true)}
	battle_requested.emit(request)
	return request

func abandon_battle() -> void:
	if not in_battle: return
	data = entry_snapshot.duplicate(true)
	in_battle = false
	entry_snapshot.clear()
	changed.emit()

func complete_battle(result: Dictionary) -> bool:
	if not in_battle: return false
	var previous := entry_snapshot.duplicate(true)
	var id: String = data.current
	for member in roster():
		if result.get("characters", {}).has(member):
			var status: Dictionary = result.characters[member]
			data.owned[member].hp = clampi(int(status.get("hp", 100)), 0, 100)
			data.owned[member].mp = clampi(int(status.get("mp", 100)), 0, 100)
			data.owned[member].dead = bool(status.get("dead", false))
			data.owned[member].cooldowns = status.get("cooldowns", [0.0, 0.0]).duplicate()
	if data.owned.JIA.dead:
		abandon_battle()
		return false
	for index in 2:
		var member: String = data.party[index]
		if member != "" and data.owned[member].dead: data.party[index] = ""
	if result.get("equipment_elite", false):
		for item in ["long_spear", "iron_armor", "frost_jade"]:
			if item not in data.inventory:
				data.inventory.append(item)
				break
	var extra: bool = result.get("card_elite", false)
	in_battle = false
	if id in ["B01", "B18"]:
		data.deferred_reward = {"id":id, "extra":extra}
		advance(id)
	else:
		unlock(id)
		make_reward(id, extra)
	if not commit(previous):
		in_battle = true
		return false
	entry_snapshot.clear()
	return true

func resolve_event() -> bool:
	if in_battle or not data.pending.is_empty(): return false
	var id: String = data.current
	if id not in data.available or nodes[id].kind not in ["event", "spring"]: return false
	var previous := data.duplicate(true)
	unlock(id)
	if id == "S02" and not data.owned.has("F11"):
		data.owned.F11 = new_character("F11")
		data.log.append("艾玛随行 · 剧情加入，不占本关选卡名额。")
	if nodes[id].kind == "spring" or id == "S14":
		for member in data.owned:
			data.owned[member].hp = 100
			data.owned[member].mp = 100
			data.owned[member].dead = false
	advance(id)
	if not data.deferred_reward.is_empty():
		var deferred: Dictionary = data.deferred_reward.duplicate()
		data.deferred_reward.clear()
		make_reward(deferred.id, deferred.extra)
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

func make_reward(id: String, extra: bool) -> void:
	var final := id == "B18"
	var count := 7 if final else 5
	var pool: Array = data.pool.duplicate()
	pool.shuffle()
	var candidates: Array = []
	if final:
		for card in pool:
			if characters[card].kind == "重要人物" and candidates.size() < 2: candidates.append(card)
	for card in pool:
		if candidates.size() >= count: break
		if card not in candidates: candidates.append(card)
	data.pending = {"node":id, "candidates":candidates, "selected":[], "picks":(3 if final else 2) + (1 if extra else 0), "extra":extra}

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
				data.owned[id].hp = 100
				data.owned[id].mp = 100
		else: data.owned[id] = new_character(id)
	var id: String = data.pending.node
	data.pending.clear()
	if id not in data.completed: advance(id)
	return commit(previous)

func save_slot(slot: String) -> bool:
	if slot not in ["auto", "1", "2", "3"]: return false
	if DirAccess.make_dir_recursive_absolute(directory) != OK: return false
	var path := directory.path_join(slot + ".json")
	var snapshot := entry_snapshot if in_battle else data
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(snapshot))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return false
	return DirAccess.rename_absolute(path + ".tmp", path) == OK

func read_slot(slot: String) -> Dictionary:
	if slot not in ["auto", "1", "2", "3"]: return {}
	var path := directory.path_join(slot + ".json")
	if not FileAccess.file_exists(path): return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not valid(value): return {}
	return value

func load_slot(slot: String) -> bool:
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
	if not value is Dictionary or value.get("schema") != SCHEMA or value.get("scope") != "ui_rehearsal": return false
	for key in ["owned", "equipped", "pending", "deferred_reward"]:
		if not value.get(key) is Dictionary: return false
	for key in ["available", "completed", "pool", "party", "inventory", "log"]:
		if not value.get(key) is Array: return false
	if value.get("current", "") not in nodes or value.party.size() != 2 or not value.owned.has("JIA"): return false
	for id in value.owned:
		if id not in characters or not value.owned[id] is Dictionary: return false
		for key in ["level", "xp", "hp", "mp"]:
			if typeof(value.owned[id].get(key)) not in [TYPE_INT, TYPE_FLOAT]: return false
		if value.owned[id].level < 1 or typeof(value.owned[id].get("dead")) != TYPE_BOOL: return false
		if value.owned[id].xp < 0 or value.owned[id].hp < 0 or value.owned[id].hp > 100 or value.owned[id].mp < 0 or value.owned[id].mp > 100: return false
		if not value.owned[id].get("cooldowns") is Array or value.owned[id].cooldowns.size() != 2: return false
		for cooldown in value.owned[id].cooldowns:
			if typeof(cooldown) not in [TYPE_FLOAT, TYPE_INT] or cooldown < 0: return false
	for id in value.party:
		if id != "" and (id == "JIA" or id not in value.owned or value.owned[id].dead): return false
	if value.party[0] != "" and value.party[0] == value.party[1]: return false
	for id in value.pool:
		if id not in characters or id == "JIA": return false
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

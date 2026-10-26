extends RefCounted

const PATH := "res://assets/story/chapter1.json"
const STAGES := preload("res://scripts/story_data.gd")
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_data = parsed
	return _data.duplicate(true)

static func entries(kind: String) -> Array:
	return data().get(kind, [])

static func find(kind: String, id: String) -> Dictionary:
	for entry: Dictionary in entries(kind):
		if str(entry.get("id", "")) == id:
			return entry
	return {}

static func quest_for_stage(stage_id: String) -> Dictionary:
	for quest: Dictionary in entries("quests"):
		if quest.stage_id == stage_id:
			return quest
	return {}

static func stage(stage_id: String) -> Dictionary:
	for value: Dictionary in STAGES.STORY_STAGES:
		if value.id == stage_id:
			return value.duplicate(true)
	return {}

static func node(dialogue_id: String, node_id: String) -> Dictionary:
	for value: Dictionary in find("dialogues", dialogue_id).get("nodes", []):
		if value.id == node_id:
			return value
	return {}

static func validate() -> Array[String]:
	var errors: Array[String] = []
	if data().is_empty():
		return ["故事内容无法读取"]
	for kind in ["stages", "quests", "items", "speakers", "dialogues", "journal_entries"]:
		var ids := {}
		for entry in entries(kind):
			if not entry is Dictionary or str(entry.get("id", "")) == "" or ids.has(entry.id):
				errors.append("重复或无效的内容ID：" + kind)
				continue
			ids[entry.id] = true
	var completed := []
	for _step in entries("quests").size():
		for quest: Dictionary in entries("quests"):
			if completed.has(quest.id):
				continue
			var unlocked := true
			for dependency in quest.requires_completed_quests:
				unlocked = unlocked and completed.has(dependency)
			if unlocked:
				completed.append(quest.id)
			if stage(quest.stage_id).is_empty():
				errors.append("未知关卡：" + str(quest.stage_id))
	if completed.size() != entries("quests").size():
		errors.append("任务前置存在循环或未知ID")
	for dialogue: Dictionary in entries("dialogues"):
		var exits := []
		for value: Dictionary in dialogue.nodes:
			if find("speakers", value.speaker).is_empty():
				errors.append("未知说话者：" + str(value.speaker))
			if bool(value.get("end", false)):
				exits.append(value.id)
			var targets: Array = [value.next] if value.has("next") else []
			for choice: Dictionary in value.get("choices", []):
				targets.append(choice.next)
				if choice.has("command") and find("quests", choice.command.get("quest_id", "")).is_empty():
					errors.append("选项引用未知任务")
			for target in targets:
				if node(dialogue.id, target).is_empty():
					errors.append("未知对话节点：" + str(target))
		if node(dialogue.id, dialogue.entry).is_empty() or exits.is_empty():
			errors.append("对话缺少入口或出口：" + str(dialogue.id))
	return errors

extends RefCounted

const SAVE := preload("res://scripts/save_manager.gd")
const STORE := preload("res://scripts/save/save_file_store.gd")
const CONTENT := preload("res://scripts/story/story_content.gd")
const STATE := preload("res://scripts/story/story_state.gd")

static func result(ok: bool, reason: String = "", profile: Dictionary = {}) -> Dictionary:
	return {"ok": ok, "reason": reason, "profile": profile.duplicate(true)}

static func message(reason: String) -> String:
	return {
		"save_failed": "保存未完成，请检查存储空间后重试。现有文件已保留。",
		"invalid_state": "当前进度已变化，请刷新后重试。",
		"item_missing": "交付物品不足，未消耗任何物品。",
		"stale_attempt": "战局与当前档案不一致，原文件已保留。",
		"content_mismatch": "内容或存档版本不兼容，原文件已保留。",
		"corrupt": "没有可读取的有效存档。原文件已保留，请从备份恢复。",
		"run_corrupt": "战局无法恢复。可保留文件退出，或放弃本关构筑后重新出击。",
		"run_exists": "已有战局，请先继续或放弃当前战局。",
		"wrong_slot": "请回到对应的故事存档后再操作。",
		"wrong_npc": "这件物品需要交给任务中指定的人。"
	}.get(reason, "操作未完成，请刷新后重试。")

static func _profile(slot: int) -> Dictionary:
	if SAVE.get_active_mode() != SAVE.MODE_STORY or SAVE.get_active_slot_id() != slot:
		return {}
	return SAVE.load_story_profile(slot)

static func _commit(slot: int, profile: Dictionary) -> Dictionary:
	STATE.refresh(profile)
	var error := STATE.error(profile)
	if error != "":
		return result(false, error)
	if SAVE.save_story_profile(profile, slot) <= 0:
		return result(false, "save_failed")
	return result(true, "", profile)

static func open_slot(slot: int) -> Dictionary:
	if not CONTENT.validate().is_empty():
		return result(false, "content_mismatch")
	var original := SAVE.profile_status(slot, SAVE.MODE_STORY)
	if original.status in ["corrupt", "incompatible", "invalid"]:
		return result(false, "content_mismatch" if original.status == "incompatible" else "corrupt")
	var profile := SAVE.create_or_load_story_profile(slot)
	if profile.is_empty():
		return result(false, "save_failed")
	var run := SAVE.load_run(slot, SAVE.MODE_STORY)
	var state: Dictionary = profile.story
	var migrated: bool = not original.data.is_empty() and int(original.data.get("schema_version", 0)) < STATE.SCHEMA_VERSION
	if migrated and not run.is_empty() and not run.has("story_attempt"):
		var quests := CONTENT.entries("quests")
		var index := int(profile.current_stage_index)
		if index >= quests.size():
			return result(false, "stale_attempt")
		var quest: Dictionary = quests[index]
		state.quest_states[quest.id] = "active"
		state.active_attempt = _make_attempt(slot, quest.stage_id, "advance", profile.team_order)
		state.active_attempt["legacy_import"] = true
	var changed: bool = migrated or original.status == "recoverable"
	for quest: Dictionary in CONTENT.entries("quests"):
		if state.quest_states[quest.id] != "ready_to_turn_in" or not state.claimed_reward_ids.has(quest.first_clear_reward.receipt_id):
			continue
		for grant: Dictionary in quest.first_clear_reward.items:
			if CONTENT.find("items", grant.item_id).storage == "story.quest_items" and int(state.quest_items.get(grant.item_id, 0)) == 0:
				state.quest_items[grant.item_id] = int(grant.quantity)
				changed = true
	if changed:
		var saved := _commit(slot, profile)
		if not saved.ok:
			return saved
	var attempt: Dictionary = state.active_attempt
	if not attempt.is_empty():
		if bool(attempt.get("legacy_import", false)) and not run.is_empty() and not run.has("story_attempt"):
			run.story_attempt = attempt.duplicate(true)
			if SAVE.save_run(run, slot, SAVE.MODE_STORY) <= 0:
				return result(false, "save_failed")
		if attempt.phase == "starting":
			return _start_pending(slot, profile)
		if run.is_empty():
			return result(false, "run_corrupt", profile)
		if not _matches(run.get("story_attempt", {}), attempt):
			return result(false, "stale_attempt", profile)
		if run.has("pending_settlement"):
			return settle_stage(slot, attempt.attempt_id)
	elif not run.is_empty():
		if _matches(run.get("story_attempt", {}), state.last_settlement):
			if not SAVE.clear_save(slot, SAVE.MODE_STORY):
				return result(false, "save_failed", profile)
		else:
			return result(false, "stale_attempt", profile)
	elif SAVE.run_status(slot, SAVE.MODE_STORY).status == "corrupt":
		return result(false, "run_corrupt", profile)
	return result(true, "", SAVE.load_story_profile(slot))

static func current_quest(profile: Dictionary) -> Dictionary:
	for quest: Dictionary in CONTENT.entries("quests"):
		if profile.get("story", {}).get("quest_states", {}).get(quest.id) in ["available", "active", "ready_to_turn_in"]:
			return quest
	return {}

static func item_quantity(profile: Dictionary, item_id: String) -> int:
	var item := CONTENT.find("items", item_id)
	if item.is_empty():
		return 0
	return int(profile.get("boss_core_fragments", 0)) if item.storage == "boss_core_fragments" else int(profile.story.quest_items.get(item_id, 0))

static func _add_item(profile: Dictionary, item_id: String, quantity: int) -> void:
	if CONTENT.find("items", item_id).storage == "boss_core_fragments":
		profile.boss_core_fragments = int(profile.boss_core_fragments) + quantity
	else:
		profile.story.quest_items[item_id] = item_quantity(profile, item_id) + quantity

static func accept_quest(slot: int, quest_id: String, npc: String) -> Dictionary:
	var profile := _profile(slot)
	if profile.is_empty():
		return result(false, "wrong_slot")
	var error := _quest_command(profile, quest_id, npc, "accept_quest")
	return _commit(slot, profile) if error == "" else result(false, error)

static func turn_in_quest(slot: int, quest_id: String, npc: String) -> Dictionary:
	var profile := _profile(slot)
	if profile.is_empty():
		return result(false, "wrong_slot")
	var error := _quest_command(profile, quest_id, npc, "turn_in_quest")
	return _commit(slot, profile) if error == "" else result(false, error)

static func _quest_command(profile: Dictionary, quest_id: String, npc: String, command: String) -> String:
	var quest := CONTENT.find("quests", quest_id)
	if quest.is_empty():
		return "content_mismatch"
	var state: Dictionary = profile.story
	var status := str(state.quest_states[quest_id])
	if command == "accept_quest":
		if npc != quest.accept_npc:
			return "wrong_npc"
		if status == "active":
			return ""
		if status != "available":
			return "invalid_state"
		state.quest_states[quest_id] = "active"
		return ""
	if command != "turn_in_quest":
		return "invalid_state"
	if npc != quest.turn_in_npc:
		return "wrong_npc"
	if state.claimed_reward_ids.has(quest.turn_in.receipt_id):
		return ""
	if status != "ready_to_turn_in":
		return "invalid_state"
	for cost: Dictionary in quest.turn_in.costs:
		if item_quantity(profile, cost.item_id) < int(cost.quantity):
			return "item_missing"
	for cost: Dictionary in quest.turn_in.costs:
		_add_item(profile, cost.item_id, -int(cost.quantity))
	state.quest_states[quest_id] = "completed"
	for entry in quest.turn_in.journal_entries:
		if not state.journal_entries.has(entry):
			state.journal_entries.append(entry)
	for flag in quest.turn_in.flags:
		state.flags[flag] = true
	var source: Dictionary = state.claimed_reward_ids.get(quest.first_clear_reward.receipt_id, {})
	state.claimed_reward_ids[quest.turn_in.receipt_id] = {"attempt_id": source.get("attempt_id", "")}
	if not state.pending_presentation.has(quest.turn_in.receipt_id):
		state.pending_presentation.append(quest.turn_in.receipt_id)
	STATE.refresh(profile)
	return ""

static func _make_attempt(slot: int, stage_id: String, purpose: String, team: Array) -> Dictionary:
	return {"mode": "story", "slot_id": slot, "attempt_id": "story_%d_%d_%d" % [slot, int(Time.get_unix_time_from_system()), Time.get_ticks_usec()], "stage_id": stage_id, "purpose": purpose, "phase": "starting", "team_order": team.duplicate()}

static func _matches(left: Dictionary, right: Dictionary) -> bool:
	return STATE.same_attempt(left, right)

static func _clear_settled_run(slot: int, profile: Dictionary) -> bool:
	var status := SAVE.run_status(slot, SAVE.MODE_STORY)
	if status.status == "missing":
		return true
	return _matches(status.data.get("story_attempt", {}), profile.story.last_settlement) and SAVE.clear_save(slot, SAVE.MODE_STORY)

static func begin_stage(slot: int, stage_id: String, purpose: String) -> Dictionary:
	var profile := _profile(slot)
	if profile.is_empty():
		return result(false, "wrong_slot")
	var quest := CONTENT.quest_for_stage(stage_id)
	if quest.is_empty() or not purpose in ["advance", "replay"]:
		return result(false, "content_mismatch")
	var state: Dictionary = profile.story
	if not state.active_attempt.is_empty():
		if state.active_attempt.phase == "starting" and state.active_attempt.stage_id == stage_id and state.active_attempt.purpose == purpose:
			return _start_pending(slot, profile)
		return result(false, "run_exists")
	if SAVE.run_status(slot, SAVE.MODE_STORY).status != "missing":
		if not _clear_settled_run(slot, profile):
			return result(false, "run_exists")
	if (purpose == "advance" and state.quest_states[quest.id] != "active") or (purpose == "replay" and not state.completed_stage_ids.has(stage_id)):
		return result(false, "invalid_state")
	state.active_attempt = _make_attempt(slot, stage_id, purpose, profile.team_order)
	var saved := _commit(slot, profile)
	return _start_pending(slot, saved.profile) if saved.ok else saved

static func _start_pending(slot: int, profile: Dictionary) -> Dictionary:
	var attempt: Dictionary = profile.story.active_attempt
	var run := SAVE.load_run(slot, SAVE.MODE_STORY)
	if not run.is_empty() and not _matches(run.get("story_attempt", {}), attempt):
		return result(false, "stale_attempt")
	if run.is_empty():
		if SAVE.run_status(slot, SAVE.MODE_STORY).status != "missing":
			return result(false, "run_corrupt")
		run = {"story_attempt": attempt.duplicate(true), "story_initial": true, "player": {}}
		if SAVE.save_run(run, slot, SAVE.MODE_STORY) <= 0:
			return result(false, "save_failed")
	attempt.phase = "running"
	return _commit(slot, profile)

static func continue_attempt(slot: int) -> Dictionary:
	var opened := open_slot(slot)
	if not opened.ok:
		return opened
	if opened.profile.story.active_attempt.is_empty():
		return result(false, "invalid_state", opened.profile)
	SAVE.request_continue()
	return opened

static func settle_stage(slot: int, attempt_id: String) -> Dictionary:
	var profile := _profile(slot)
	if profile.is_empty():
		return result(false, "wrong_slot")
	var state: Dictionary = profile.story
	if state.last_settlement.get("attempt_id") == attempt_id and state.last_settlement.get("outcome") == "victory":
		return result(true, "already_applied", profile) if _clear_settled_run(slot, profile) else result(false, "save_failed", profile)
	var attempt: Dictionary = state.active_attempt
	var run := SAVE.load_run(slot, SAVE.MODE_STORY)
	var pending: Dictionary = run.get("pending_settlement", {})
	if attempt.get("attempt_id") != attempt_id or not _matches(run.get("story_attempt", {}), attempt) or not _matches(pending, attempt) or pending.get("outcome") != "victory":
		return result(false, "stale_attempt")
	var quest := CONTENT.quest_for_stage(attempt.stage_id)
	if attempt.purpose == "advance":
		if state.quest_states[quest.id] != "active":
			return result(false, "invalid_state")
		var receipt: String = quest.first_clear_reward.receipt_id
		if not state.claimed_reward_ids.has(receipt):
			for grant: Dictionary in quest.first_clear_reward.items:
				_add_item(profile, grant.item_id, int(grant.quantity))
			state.claimed_reward_ids[receipt] = {"attempt_id": attempt_id}
			state.pending_presentation.append(receipt)
		if not state.completed_stage_ids.has(attempt.stage_id):
			state.completed_stage_ids.append(attempt.stage_id)
		state.quest_states[quest.id] = "ready_to_turn_in"
	state.last_settlement = attempt.duplicate(true)
	state.last_settlement.merge({"outcome": "victory", "summary": pending.get("summary", {})}, true)
	state.active_attempt = {}
	var saved := _commit(slot, profile)
	if saved.ok and not _clear_settled_run(slot, profile):
		return result(false, "save_failed", profile)
	return saved

static func end_attempt(slot: int, attempt_id: String, outcome: String, summary: Dictionary = {}) -> Dictionary:
	var profile := _profile(slot)
	if profile.is_empty():
		return result(false, "wrong_slot")
	if not outcome in ["failed", "abandoned"]:
		return result(false, "invalid_state")
	var attempt: Dictionary = profile.story.active_attempt
	if attempt.is_empty() and profile.story.last_settlement.get("attempt_id") == attempt_id and profile.story.last_settlement.get("outcome") == outcome:
		return result(true, "", profile) if _clear_settled_run(slot, profile) else result(false, "save_failed", profile)
	if attempt.get("attempt_id") != attempt_id:
		return result(false, "stale_attempt")
	var run_state := SAVE.run_status(slot, SAVE.MODE_STORY)
	if run_state.status == "corrupt":
		for path in [STORE.story_run_path(slot), STORE.story_run_backup_path(slot)]:
			if not STORE.preserve_file(path):
				return result(false, "save_failed")
	if run_state.data.has("pending_settlement"):
		return result(false, "invalid_state")
	profile.story.last_settlement = attempt.duplicate(true)
	profile.story.last_settlement.outcome = outcome
	profile.story.last_settlement.summary = summary.duplicate(true)
	profile.story.active_attempt = {}
	var saved := _commit(slot, profile)
	if saved.ok and not SAVE.clear_save(slot, SAVE.MODE_STORY):
		return result(false, "save_failed", profile)
	return saved

static func abandon_unreadable_run(slot: int) -> Dictionary:
	var profile := _profile(slot)
	if profile.is_empty():
		return result(false, "wrong_slot")
	var attempt: Dictionary = profile.story.active_attempt
	if not attempt.is_empty():
		return end_attempt(slot, attempt.attempt_id, "abandoned")
	for path in [STORE.story_run_path(slot), STORE.story_run_backup_path(slot)]:
		if not STORE.preserve_file(path):
			return result(false, "save_failed")
	return result(SAVE.clear_save(slot, SAVE.MODE_STORY), "", profile)

static func conditions_met(profile: Dictionary, conditions: Array) -> bool:
	for condition: Dictionary in conditions:
		match condition.get("type"):
			"quest_state":
				if profile.story.quest_states.get(condition.quest_id) != condition.value:
					return false
			"flag":
				if profile.story.flags.get(condition.flag_id, false) != condition.value:
					return false
			_:
				return false
	return true

static func dialogues_for_npc(profile: Dictionary, npc: String) -> Array:
	var choices := []
	for dialogue: Dictionary in CONTENT.entries("dialogues"):
		if dialogue.npc_id == npc and conditions_met(profile, dialogue.conditions):
			choices.append(dialogue)
	var priorities := {"turn_in": 0, "accept": 1, "reminder": 2, "optional": 3}
	choices.sort_custom(func(a, b): return priorities.get(a.kind, 4) < priorities.get(b.kind, 4))
	return choices

static func _checkpoint(profile: Dictionary, conversation: String, node_id: String) -> void:
	profile.story.dialogue_checkpoint = {"conversation_id": conversation, "node_id": node_id}
	var seen: Dictionary = profile.story.dialogue_seen_nodes
	if not seen.has(conversation):
		seen[conversation] = []
	if not seen[conversation].has(node_id):
		seen[conversation].append(node_id)

static func open_dialogue(slot: int, conversation: String) -> Dictionary:
	var profile := _profile(slot)
	if profile.is_empty():
		return result(false, "wrong_slot")
	var dialogue := CONTENT.find("dialogues", conversation)
	if dialogue.is_empty():
		return result(false, "content_mismatch")
	if profile.story.dialogue_checkpoint.get("conversation_id") == conversation:
		return result(true, "", profile)
	if not conditions_met(profile, dialogue.conditions):
		return result(false, "invalid_state")
	_checkpoint(profile, conversation, dialogue.entry)
	return _commit(slot, profile)

static func advance_dialogue(slot: int, conversation: String, node_id: String, choice_id: String = "", skip: bool = false) -> Dictionary:
	var profile := _profile(slot)
	if profile.is_empty():
		return result(false, "wrong_slot")
	if profile.story.dialogue_checkpoint != {"conversation_id": conversation, "node_id": node_id}:
		return result(false, "invalid_state")
	var dialogue := CONTENT.find("dialogues", conversation)
	var current := CONTENT.node(conversation, node_id)
	if current.is_empty():
		return result(false, "content_mismatch")
	var next := str(current.get("next", ""))
	if current.has("choices"):
		var selected := {}
		for choice: Dictionary in current.choices:
			if choice.id == choice_id:
				selected = choice
		if selected.is_empty():
			return result(false, "invalid_state")
		if selected.has("command"):
			var error := _quest_command(profile, selected.command.quest_id, dialogue.npc_id, selected.command.type)
			if error != "":
				return result(false, error)
		next = str(selected.next)
	if next == "":
		profile.story.dialogue_checkpoint = {}
	else:
		_checkpoint(profile, conversation, next)
		if skip:
			var visited := {}
			while CONTENT.node(conversation, next).has("next"):
				if visited.has(next):
					return result(false, "content_mismatch")
				visited[next] = true
				next = CONTENT.node(conversation, next).next
				_checkpoint(profile, conversation, next)
	return _commit(slot, profile)

static func ack_presentation(slot: int, ids: Array) -> Dictionary:
	var profile := _profile(slot)
	if profile.is_empty():
		return result(false, "wrong_slot")
	for id in ids:
		profile.story.pending_presentation.erase(id)
	return _commit(slot, profile)

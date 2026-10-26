extends RefCounted

const CONTENT := preload("res://scripts/story/story_content.gd")
const SCHEMA_VERSION := 2
const STATES := ["locked", "available", "active", "ready_to_turn_in", "completed"]
const ROLES := ["swordsman", "gunner", "mage", "mechanic"]

static func whole_number(value: Variant, minimum: int = 0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) == floor(float(value))

static func same_attempt(left: Variant, right: Variant) -> bool:
	if not left is Dictionary or not right is Dictionary or str(left.get("attempt_id", "")) == "":
		return false
	for key in ["mode", "slot_id", "attempt_id", "stage_id", "purpose"]:
		if not left.has(key) or left[key] != right.get(key):
			return false
	return true

static func migrate(profile: Dictionary) -> Dictionary:
	var result := profile.duplicate(true)
	if int(result.get("schema_version", 0)) == SCHEMA_VERSION:
		return result
	var state := {
		"content_version": int(CONTENT.data().get("content_version", 1)),
		"quest_states": {}, "completed_stage_ids": [], "quest_items": {},
		"flags": {}, "journal_entries": [], "dialogue_checkpoint": {},
		"dialogue_seen_nodes": {}, "active_attempt": {}, "claimed_reward_ids": {},
		"last_settlement": {}, "pending_presentation": []
	}
	var old_index := int(result.get("current_stage_index", 0))
	var quests := CONTENT.entries("quests")
	for i in quests.size():
		var quest: Dictionary = quests[i]
		state.quest_states[quest.id] = "completed" if i < old_index else ("available" if i == old_index else "locked")
		if i < old_index:
			state.completed_stage_ids.append(quest.stage_id)
			for entry in quest.turn_in.journal_entries:
				state.journal_entries.append(entry)
			for flag in quest.turn_in.flags:
				state.flags[flag] = true
			for receipt in [quest.first_clear_reward.receipt_id, quest.turn_in.receipt_id]:
				state.claimed_reward_ids[receipt] = {"migrated": true, "attempt_id": "legacy"}
	result.schema_version = SCHEMA_VERSION
	result.story = state
	return result

static func error(profile: Dictionary) -> String:
	var version: Variant = profile.get("schema_version", 0)
	if not whole_number(version) or int(version) > SCHEMA_VERSION:
		return "content_mismatch"
	if int(version) < SCHEMA_VERSION:
		if not whole_number(profile.get("current_stage_index")) or int(profile.current_stage_index) > CONTENT.entries("quests").size() or not whole_number(profile.get("chapter_index", 1), 1) or int(profile.get("chapter_index", 1)) != 1:
			return "invalid_state"
		return ""
	var state: Variant = profile.get("story")
	if not state is Dictionary:
		return "invalid_state"
	if not whole_number(state.get("content_version"), 1) or int(state.content_version) != int(CONTENT.data().get("content_version", 1)):
		return "content_mismatch"
	for key in ["quest_states", "quest_items", "flags", "dialogue_checkpoint", "dialogue_seen_nodes", "active_attempt", "claimed_reward_ids", "last_settlement"]:
		if not state.get(key) is Dictionary:
			return "invalid_state"
	for key in ["completed_stage_ids", "journal_entries", "pending_presentation"]:
		if not state.get(key) is Array:
			return "invalid_state"
	var active_count := 0
	var receipt_ids := []
	for quest: Dictionary in CONTENT.entries("quests"):
		var status: Variant = state.quest_states.get(quest.id)
		if not status in STATES:
			return "invalid_state"
		if status in ["active", "ready_to_turn_in"]:
			active_count += 1
		for prerequisite in quest.requires_completed_quests:
			if status != "locked" and state.quest_states.get(prerequisite) != "completed":
				return "invalid_state"
		if status in ["ready_to_turn_in", "completed"] and not state.completed_stage_ids.has(quest.stage_id):
			return "invalid_state"
		if status in ["ready_to_turn_in", "completed"] and not state.claimed_reward_ids.has(quest.first_clear_reward.receipt_id):
			return "invalid_state"
		if status == "completed" and not state.claimed_reward_ids.has(quest.turn_in.receipt_id):
			return "invalid_state"
		receipt_ids.append(quest.first_clear_reward.receipt_id)
		receipt_ids.append(quest.turn_in.receipt_id)
	if active_count > 1 or state.quest_states.size() != CONTENT.entries("quests").size():
		return "invalid_state"
	for stage_id in state.completed_stage_ids:
		if CONTENT.stage(str(stage_id)).is_empty():
			return "content_mismatch"
	for item_id in state.quest_items:
		var item := CONTENT.find("items", str(item_id))
		if item.is_empty() or item.get("storage") != "story.quest_items":
			return "content_mismatch"
		if not whole_number(state.quest_items[item_id]) or int(state.quest_items[item_id]) > int(item.max_stack):
			return "invalid_state"
	for entry in state.journal_entries:
		if CONTENT.find("journal_entries", str(entry)).is_empty():
			return "content_mismatch"
	for flag in state.flags:
		if flag != CONTENT.data().completion_flag or not state.flags[flag] is bool:
			return "content_mismatch"
	for receipt in state.claimed_reward_ids:
		if not receipt_ids.has(receipt) or not state.claimed_reward_ids[receipt] is Dictionary:
			return "content_mismatch"
	for receipt in state.pending_presentation:
		if not state.claimed_reward_ids.has(receipt):
			return "invalid_state"
	var checkpoint: Dictionary = state.dialogue_checkpoint
	if not checkpoint.is_empty() and CONTENT.node(str(checkpoint.get("conversation_id", "")), str(checkpoint.get("node_id", ""))).is_empty():
		return "content_mismatch"
	for conversation in state.dialogue_seen_nodes:
		if not state.dialogue_seen_nodes[conversation] is Array:
			return "invalid_state"
		for node_id in state.dialogue_seen_nodes[conversation]:
			if CONTENT.node(str(conversation), str(node_id)).is_empty():
				return "content_mismatch"
	var attempt: Dictionary = state.active_attempt
	if not attempt.is_empty():
		if not attempt.get("attempt_id") is String or attempt.attempt_id == "" or CONTENT.stage(str(attempt.get("stage_id", ""))).is_empty():
			return "invalid_state"
		if attempt.get("mode") != "story" or not whole_number(attempt.get("slot_id"), 1) or int(attempt.slot_id) != int(profile.get("slot_id", -2)) or not attempt.get("phase") in ["starting", "running"] or not attempt.get("purpose") in ["advance", "replay"]:
			return "invalid_state"
		if not attempt.get("team_order") is Array or attempt.team_order.size() != 3:
			return "invalid_state"
		var unique := {}
		for role in attempt.team_order:
			if not role in ROLES or unique.has(role):
				return "invalid_state"
			unique[role] = true
		var quest := CONTENT.quest_for_stage(attempt.stage_id)
		if (attempt.purpose == "advance" and state.quest_states[quest.id] != "active") or (attempt.purpose == "replay" and not state.completed_stage_ids.has(attempt.stage_id)):
			return "invalid_state"
	var last: Dictionary = state.last_settlement
	if not last.is_empty():
		if not last.get("attempt_id") is String or last.attempt_id == "" or last.get("mode") != "story" or last.get("slot_id") != profile.slot_id or CONTENT.stage(str(last.get("stage_id", ""))).is_empty():
			return "invalid_state"
		if not last.get("outcome") in ["victory", "failed", "abandoned"] or not last.get("purpose") in ["advance", "replay"] or not last.get("summary") is Dictionary:
			return "invalid_state"
	return ""

static func refresh(profile: Dictionary) -> void:
	var state: Dictionary = profile.story
	var completed := 0
	for quest: Dictionary in CONTENT.entries("quests"):
		if state.quest_states[quest.id] == "completed":
			completed += 1
		if state.quest_states[quest.id] != "locked":
			continue
		var available := true
		for prerequisite in quest.requires_completed_quests:
			available = available and state.quest_states[prerequisite] == "completed"
		if available:
			state.quest_states[quest.id] = "available"
	profile.current_stage_index = completed

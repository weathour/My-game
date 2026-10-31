extends RefCounted
## Additive schema-1 story fields. Validation is shared by atomic primary/backup IO.
const STORIES := preload("res://scripts/content/story_catalog.gd")
const CONDITIONS := preload("res://scripts/content/story_conditions.gd")

static func defaults(value: Dictionary) -> void:
	for key in ["optional_story_checkpoints", "story_contexts", "battle_story_contexts"]:
		if not value.has(key): value[key] = {}
	if not value.has("optional_story_read"): value.optional_story_read = []
	# Recover the short-lived single optional-reader format without losing its position.
	var legacy: Dictionary = value.get("optional_story_checkpoint", {})
	if not legacy.is_empty() and not value.optional_story_checkpoints.has(legacy.event):
		value.optional_story_checkpoints[legacy.event] = legacy.line
	value.erase("optional_story_checkpoint")

static func valid(value: Dictionary, characters: Dictionary, nodes: Dictionary) -> bool:
	var optional := STORIES.optional_events()
	var all_events := STORIES.events()
	all_events.merge(optional)
	var read: Variant = value.get("optional_story_read", [])
	if not read is Array: return false
	var seen := {}
	for id in read:
		if not id is String or not optional.has(id) or seen.has(id): return false
		seen[id] = true
	var contexts: Variant = value.get("story_contexts", {})
	if not contexts is Dictionary: return false
	var catalog := STORIES.reactions()
	for id in contexts:
		if not id is String or not all_events.has(id) or not contexts[id] is Dictionary: return false
		var context: Dictionary = contexts[id]
		if context.size() != 1 or not context.get("reactions") is Array: return false
		var anchors := {}
		for reaction in context.reactions:
			if not reaction is String or not catalog.has(reaction) or catalog[reaction].event_id != id: return false
			var anchor: String = catalog[reaction].after_line
			if anchors.has(anchor): return false
			anchors[anchor] = true
	var battles: Variant = value.get("battle_story_contexts", {})
	if not battles is Dictionary: return false
	for id in battles:
		if not id is String or not nodes.has(id) or nodes[id].kind not in ["battle", "elite", "boss"] or not battles[id] is Array: return false
		seen = {}
		for member in battles[id]:
			if not member is String or not characters.has(member) or seen.has(member): return false
			seen[member] = true
		if not seen.has("JIA"): return false
	var checkpoints: Variant = value.get("optional_story_checkpoints", {})
	if not checkpoints is Dictionary: return false
	for id in checkpoints:
		if not _valid_checkpoint(id, checkpoints[id], optional, read, contexts): return false
	# Intermediate singular field is accepted only as a valid recoverable checkpoint.
	var legacy: Variant = value.get("optional_story_checkpoint", {})
	if not legacy is Dictionary: return false
	if not legacy.is_empty():
		if legacy.size() != 2 or not _valid_checkpoint(legacy.get("event"), legacy.get("line"), optional, read, contexts): return false
		if checkpoints.has(legacy.event) and checkpoints[legacy.event] != legacy.line: return false
	return true

static func _valid_checkpoint(id: Variant, line: Variant, optional: Dictionary, read: Array, contexts: Dictionary) -> bool:
	if not id is String or not line is String or not optional.has(id) or id in read or not contexts.has(id): return false
	return STORIES.has_line(STORIES.resolved(optional[id], contexts[id]), line)

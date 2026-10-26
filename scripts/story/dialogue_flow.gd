extends RefCounted

const PROGRESS := preload("res://scripts/story/story_progress.gd")
const CONTENT := preload("res://scripts/story/story_content.gd")
var slot: int
var profile: Dictionary = {}

func open(slot_id: int, conversation: String) -> Dictionary:
	slot = slot_id
	return _apply(PROGRESS.open_dialogue(slot, conversation))

func current_node() -> Dictionary:
	var checkpoint: Dictionary = profile.get("story", {}).get("dialogue_checkpoint", {})
	return CONTENT.node(checkpoint.get("conversation_id", ""), checkpoint.get("node_id", ""))

func advance(choice_id: String = "", skip: bool = false) -> Dictionary:
	var checkpoint: Dictionary = profile.get("story", {}).get("dialogue_checkpoint", {})
	return _apply(PROGRESS.advance_dialogue(slot, checkpoint.get("conversation_id", ""), checkpoint.get("node_id", ""), choice_id, skip))

func _apply(response: Dictionary) -> Dictionary:
	if response.ok:
		profile = response.profile
	return response

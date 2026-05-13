extends Node

var sequences: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func schedule(interval: float, repeat_count: int, callback: Callable, initial_delay: float = 0.0) -> void:
	if repeat_count <= 0 or not callback.is_valid():
		return
	sequences.append({
		"interval": max(0.0, interval),
		"remaining": repeat_count,
		"callback": callback,
		"next_delay": max(0.0, initial_delay),
		"index": 0
	})
	set_process(true)


func _process(delta: float) -> void:
	if sequences.is_empty():
		set_process(false)
		return
	for sequence_index in range(sequences.size() - 1, -1, -1):
		var sequence: Dictionary = sequences[sequence_index]
		var next_delay: float = float(sequence.get("next_delay", 0.0)) - delta
		if next_delay > 0.0:
			sequence["next_delay"] = next_delay
			sequences[sequence_index] = sequence
			continue
		var callback: Callable = sequence.get("callback", Callable())
		if callback.is_valid():
			callback.call(int(sequence.get("index", 0)))
		var remaining: int = int(sequence.get("remaining", 0)) - 1
		if remaining <= 0:
			sequences.remove_at(sequence_index)
			continue
		sequence["remaining"] = remaining
		sequence["index"] = int(sequence.get("index", 0)) + 1
		sequence["next_delay"] = max(0.0, float(sequence.get("interval", 0.0))) + min(0.0, next_delay)
		sequences[sequence_index] = sequence

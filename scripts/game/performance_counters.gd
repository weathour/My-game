extends RefCounted

static var frame_index: int = -1
static var counters: Dictionary = {}
static var last_frame_snapshot: Dictionary = {}
static var peak_snapshot: Dictionary = {}


static func add(counter_name: String, amount: int = 1) -> void:
	if counter_name == "" or amount == 0:
		return
	_ensure_frame()
	counters[counter_name] = int(counters.get(counter_name, 0)) + amount


static func get_snapshot() -> Dictionary:
	_ensure_frame()
	var result := last_frame_snapshot.duplicate(true)
	result["current_frame"] = counters.duplicate(true)
	result["peak"] = peak_snapshot.duplicate(true)
	return result


static func _ensure_frame() -> void:
	var current_frame := Engine.get_process_frames()
	if frame_index == current_frame:
		return
	if frame_index >= 0:
		last_frame_snapshot = counters.duplicate(true)
		_update_peak_snapshot(last_frame_snapshot)
	counters = {}
	frame_index = current_frame


static func _update_peak_snapshot(snapshot: Dictionary) -> void:
	for key in snapshot.keys():
		var current_value := int(snapshot.get(key, 0))
		if current_value > int(peak_snapshot.get(key, 0)):
			peak_snapshot[key] = current_value

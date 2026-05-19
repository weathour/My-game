extends RefCounted

const MAX_FRAME_SAMPLES := 7200

static var frame_samples_ms: Array[float] = []
static var session_samples_ms: Array[float] = []
static var current_scopes: Dictionary = {}
static var scope_totals_us: Dictionary = {}
static var scope_peaks_us: Dictionary = {}
static var session_active: bool = false
static var session_label: String = ""


static func reset() -> void:
	frame_samples_ms.clear()
	session_samples_ms.clear()
	current_scopes.clear()
	scope_totals_us.clear()
	scope_peaks_us.clear()
	session_active = false
	session_label = ""


static func start_session(label: String = "") -> void:
	session_active = true
	session_label = label
	session_samples_ms.clear()
	scope_totals_us.clear()
	scope_peaks_us.clear()


static func stop_session() -> Dictionary:
	var snapshot := get_session_snapshot()
	session_active = false
	session_label = ""
	return snapshot


static func record_frame(delta: float) -> void:
	if delta <= 0.0:
		return
	var frame_ms := delta * 1000.0
	frame_samples_ms.append(frame_ms)
	if frame_samples_ms.size() > MAX_FRAME_SAMPLES:
		frame_samples_ms.pop_front()
	if session_active:
		session_samples_ms.append(frame_ms)


static func begin_scope(scope_name: String) -> void:
	if scope_name == "":
		return
	current_scopes[scope_name] = Time.get_ticks_usec()


static func end_scope(scope_name: String) -> void:
	if scope_name == "" or not current_scopes.has(scope_name):
		return
	var elapsed := Time.get_ticks_usec() - int(current_scopes.get(scope_name, Time.get_ticks_usec()))
	current_scopes.erase(scope_name)
	scope_totals_us[scope_name] = int(scope_totals_us.get(scope_name, 0)) + elapsed
	scope_peaks_us[scope_name] = max(int(scope_peaks_us.get(scope_name, 0)), elapsed)


static func get_rolling_snapshot() -> Dictionary:
	var snapshot := _build_snapshot(frame_samples_ms)
	snapshot["scope_totals_ms"] = _convert_scope_map_to_ms(scope_totals_us)
	snapshot["scope_peaks_ms"] = _convert_scope_map_to_ms(scope_peaks_us)
	return snapshot


static func get_session_snapshot() -> Dictionary:
	var snapshot := _build_snapshot(session_samples_ms)
	snapshot["label"] = session_label
	snapshot["scope_totals_ms"] = _convert_scope_map_to_ms(scope_totals_us)
	snapshot["scope_peaks_ms"] = _convert_scope_map_to_ms(scope_peaks_us)
	return snapshot


static func _build_snapshot(samples: Array[float]) -> Dictionary:
	if samples.is_empty():
		return {
			"count": 0,
			"p50_ms": 0.0,
			"p95_ms": 0.0,
			"p99_ms": 0.0,
			"max_ms": 0.0,
			"avg_ms": 0.0
		}
	var sorted_samples := samples.duplicate()
	sorted_samples.sort()
	var total := 0.0
	for value in sorted_samples:
		total += float(value)
	return {
		"count": sorted_samples.size(),
		"p50_ms": _percentile(sorted_samples, 0.50),
		"p95_ms": _percentile(sorted_samples, 0.95),
		"p99_ms": _percentile(sorted_samples, 0.99),
		"max_ms": float(sorted_samples[sorted_samples.size() - 1]),
		"avg_ms": total / float(sorted_samples.size())
	}


static func _percentile(sorted_samples: Array, percentile: float) -> float:
	if sorted_samples.is_empty():
		return 0.0
	var index := int(ceil(percentile * float(sorted_samples.size()))) - 1
	index = clamp(index, 0, sorted_samples.size() - 1)
	return float(sorted_samples[index])


static func _convert_scope_map_to_ms(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in source.keys():
		result[str(key)] = float(source[key]) / 1000.0
	return result

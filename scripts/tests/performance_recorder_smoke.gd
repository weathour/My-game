extends SceneTree

const PERFORMANCE_RECORDER := preload("res://scripts/game/performance_recorder.gd")
const PERFORMANCE_FEATURE_FLAGS := preload("res://scripts/game/performance_feature_flags.gd")

var failures: Array[String] = []


func _init() -> void:
	PERFORMANCE_RECORDER.reset()
	PERFORMANCE_RECORDER.record_frame(0.010)
	PERFORMANCE_RECORDER.record_frame(0.020)
	PERFORMANCE_RECORDER.record_frame(0.030)
	var snapshot := PERFORMANCE_RECORDER.get_rolling_snapshot()
	_expect_close(float(snapshot.get("p50_ms", 0.0)), 20.0, "p50")
	_expect_close(float(snapshot.get("p95_ms", 0.0)), 30.0, "p95")
	_expect_close(float(snapshot.get("p99_ms", 0.0)), 30.0, "p99")
	var node := Node.new()
	root.add_child(node)
	PERFORMANCE_FEATURE_FLAGS.set_flag(node, PERFORMANCE_FEATURE_FLAGS.FLAG_ENEMY_BATCH, true)
	if not PERFORMANCE_FEATURE_FLAGS.is_enabled(node, PERFORMANCE_FEATURE_FLAGS.FLAG_ENEMY_BATCH):
		failures.append("feature flag should be enabled from node meta")
	node.queue_free()
	if failures.is_empty():
		print("PERFORMANCE_RECORDER_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect_close(actual: float, expected: float, label: String) -> void:
	if abs(actual - expected) > 0.01:
		failures.append("%s expected %.2f got %.2f" % [label, expected, actual])

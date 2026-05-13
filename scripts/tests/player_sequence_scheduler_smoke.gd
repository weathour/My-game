extends SceneTree

const PlayerSequenceScheduler := preload("res://scripts/player/player_sequence_scheduler.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scheduler := PlayerSequenceScheduler.new()
	root.add_child(scheduler)
	var received: Array[int] = []
	scheduler.schedule(0.01, 3, func(index: int) -> void:
		received.append(index)
	)
	for _frame in range(8):
		await process_frame
	if received != [0, 1, 2]:
		failures.append("scheduler should emit ordered sequence indexes; got %s" % [str(received)])
	scheduler.queue_free()
	await process_frame
	if failures.is_empty():
		print("PLAYER_SEQUENCE_SCHEDULER_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

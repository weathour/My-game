extends RefCounted

const PERFORMANCE_COUNTERS := preload("res://scripts/game/performance_counters.gd")

const STEP_DELAY := 0.02


static func run_jobs(owner, jobs: Array[Callable]) -> void:
	if owner == null or jobs.is_empty():
		return
	var tree: SceneTree = owner.get_tree()
	if tree == null:
		return
	var tween: Tween = owner.create_tween()
	for index in range(jobs.size()):
		if index > 0:
			tween.tween_interval(STEP_DELAY)
		var queued_job: Callable = jobs[index]
		tween.tween_callback(func() -> void:
			if owner == null or not is_instance_valid(owner):
				return
			PERFORMANCE_COUNTERS.add("switch_jobs", 1)
			if queued_job.is_valid():
				queued_job.call()
		)

extends RefCounted

const PERFORMANCE_COUNTERS := preload("res://scripts/game/performance_counters.gd")

const STEP_DELAY := 0.02


static func run_jobs(owner, jobs: Array[Callable]) -> void:
	if owner == null or jobs.is_empty():
		return
	var tree: SceneTree = owner.get_tree()
	if tree == null:
		return
	for index in range(jobs.size()):
		var queued_job: Callable = jobs[index]
		var delay: float = STEP_DELAY * float(index)
		if owner.has_method("_schedule_repeating_sequence"):
			owner._schedule_repeating_sequence(0.0, 1, func(_sequence_index: int) -> void:
				if owner == null or not is_instance_valid(owner):
					return
				PERFORMANCE_COUNTERS.add("switch_jobs", 1)
				if queued_job.is_valid():
					queued_job.call()
			, delay)
		else:
			PERFORMANCE_COUNTERS.add("switch_jobs", 1)
			if queued_job.is_valid():
				queued_job.call()

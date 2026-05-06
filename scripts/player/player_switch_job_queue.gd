extends RefCounted

const PERFORMANCE_COUNTERS := preload("res://scripts/game/performance_counters.gd")

const STEP_DELAY := 0.02


static func run_jobs(owner, jobs: Array[Callable]) -> void:
	if owner == null or jobs.is_empty():
		return
	var tree: SceneTree = owner.get_tree()
	if tree == null:
		return
	var current_scene: Node = tree.current_scene
	if current_scene == null:
		return
	var controller := Node.new()
	controller.name = "SwitchJobQueue"
	current_scene.add_child(controller)
	_run_next(owner, controller, jobs, 0)


static func _run_next(owner, controller: Node, jobs: Array[Callable], index: int) -> void:
	if controller == null or not is_instance_valid(controller):
		return
	if owner == null or not is_instance_valid(owner):
		controller.queue_free()
		return
	if index >= jobs.size():
		controller.queue_free()
		return
	PERFORMANCE_COUNTERS.add("switch_jobs", 1)
	var job: Callable = jobs[index]
	if job.is_valid():
		job.call()
	var tree: SceneTree = owner.get_tree()
	if tree == null:
		controller.queue_free()
		return
	var timer: SceneTreeTimer = tree.create_timer(STEP_DELAY, false)
	timer.timeout.connect(func() -> void:
		_run_next(owner, controller, jobs, index + 1)
	)

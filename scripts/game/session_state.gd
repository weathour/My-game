extends RefCounted

const WAVE_PLAN := preload("res://scripts/game/combat_wave_plan.gd")

# Scene-local reasons prevent one panel from releasing another owner's pause.
static func set_pause_reason(main: Node, reason: String, active: bool) -> void:
	var reasons: Dictionary = main.get_meta("pause_reasons", {}).duplicate()
	if active:
		reasons[reason] = true
	else:
		reasons.erase(reason)
	main.set_meta("pause_reasons", reasons)
	main.get_tree().paused = not reasons.is_empty()

static func has_pause_reason(main: Node, reason: String) -> bool:
	return main.get_meta("pause_reasons", {}).has(reason)

static func clear_pause_reasons(main: Node) -> void:
	if main.has_meta("pause_reasons"):
		main.remove_meta("pause_reasons")
	main.get_tree().paused = false

static func set_outcome(main: Node, outcome: String) -> void:
	assert(outcome in ["victory", "failed", "abandoned"])
	main.set_meta("session_outcome", outcome)

static func presentation(main: Node) -> Dictionary:
	var mode := "story" if main.get("story_mode_active") == true else "endless" if main.get("endless_mode_active") == true else "survival"
	if main.has_method("_is_developer_mode") and main._is_developer_mode():
		mode = "developer"
	var waves = main.get("wave_flow")
	var phase := str(waves.phase) if is_instance_valid(waves) else "combat"
	var outcome := str(main.get_meta("session_outcome", ""))
	if outcome == "" and main.has_meta("pending_run_end"):
		outcome = str(main.get_meta("pending_run_end").get("outcome", "failed"))
	if outcome == "" and main.has_meta("pending_story_settlement"):
		outcome = "victory"
	# Existing snapshots derive terminal state here, not in each observer.
	if outcome == "" and (main.get("stage_cleared") == true or str(main.get("reward_context")) in ["endless_tier_clear", "final_core", "story_settlement"] or (is_instance_valid(waves) and phase != "combat" and bool(waves.ending_final))):
		outcome = "victory"
	if outcome == "" and main.get("game_over") == true:
		outcome = "failed"
	if outcome != "":
		phase = "result"
	if main.has_meta("run_restore_failed"):
		phase = "restore_failed"
	var stage: Variant = main.get("story_stage")
	var raw_elapsed: Variant = main.get("survival_time")
	var elapsed := float(raw_elapsed) if raw_elapsed is float or raw_elapsed is int else 0.0
	var remaining := 0.0
	var target_kind := "survive"
	if mode == "story" and stage is Dictionary:
		target_kind = "defeat_boss" if stage.get("type") == "boss" else "survive"
		remaining = maxf(0.0, float(stage.get("target_time", 0.0)) - elapsed)
	elif is_instance_valid(waves):
		if outcome == "":
			elapsed = float(waves.elapsed)
		if phase == "preparation":
			remaining = maxf(0.0, float(waves.remaining))
		else:
			var duration := WAVE_PLAN.duration(int(waves.wave))
			target_kind = "defeat_boss" if duration <= 0 else "survive_wave"
			remaining = maxf(0.0, duration - elapsed)
	var view := {
		"mode": mode, "phase": phase, "outcome": outcome,
		"stage_id": str(stage.get("id", "")) if stage is Dictionary else "",
		"wave": int(waves.wave) if is_instance_valid(waves) else 0,
		"paused": main.get_tree().paused,
		"target_kind": target_kind, "elapsed_seconds": elapsed, "remaining_seconds": remaining
	}
	view.make_read_only()
	return view

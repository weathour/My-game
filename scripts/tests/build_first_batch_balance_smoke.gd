extends SceneTree

const BalanceAnalyzer := preload("res://scripts/build/build_first_batch_balance_analyzer.gd")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var analysis := BalanceAnalyzer.analyze_first_batch()
	_check_analysis_shape(analysis)
	_check_no_obvious_best(analysis)
	_check_bad_policy_is_weak(analysis)
	_check_stage_curves(analysis)
	if failures.is_empty():
		print(BalanceAnalyzer.make_text_report(analysis))
		print("BUILD_FIRST_BATCH_BALANCE_SMOKE_OK")
		quit(0)
	else:
		print(BalanceAnalyzer.make_text_report(analysis))
		for failure in failures:
			push_error(failure)
		quit(1)

func _check_analysis_shape(analysis: Dictionary) -> void:
	var runs: Array = analysis.get("runs", [])
	if runs.size() < 8:
		failures.append("balance analyzer should simulate multiple reasonable policies, got %d" % runs.size())
	for run_variant in runs:
		var run: Dictionary = run_variant
		var timeline: Array = run.get("timeline", [])
		if timeline.size() != 4:
			failures.append("%s should have 4 milestone snapshots, got %d" % [str(run.get("policy_id", "")), timeline.size()])
		for snapshot_variant in timeline:
			var snapshot: Dictionary = snapshot_variant
			if float(snapshot.get("score", 0.0)) <= 0.0:
				failures.append("%s L%d should have positive model strength" % [str(run.get("policy_id", "")), int(snapshot.get("level", 0))])

func _check_no_obvious_best(analysis: Dictionary) -> void:
	var dominance: Dictionary = analysis.get("dominance", {})
	if bool(dominance.get("has_obvious_optimum", false)):
		failures.append("model should not report an obvious single optimum: %s" % str(dominance))
	if float(dominance.get("aggregate_gap", 99.0)) > BalanceAnalyzer.DOMINANCE_AGGREGATE_GAP_LIMIT:
		failures.append("top aggregate gap too high: %s" % str(dominance))
	if int(dominance.get("close_policy_count", 0)) < BalanceAnalyzer.DOMINANCE_MIN_CLOSE_POLICIES:
		failures.append("too few policies close to top: %s" % str(dominance))

func _check_bad_policy_is_weak(analysis: Dictionary) -> void:
	var dominance: Dictionary = analysis.get("dominance", {})
	if not bool(dominance.get("bad_policy_is_weaker", false)):
		failures.append("bad scattered policy should be meaningfully weaker than reasonable median: %s" % str(dominance))

func _check_stage_curves(analysis: Dictionary) -> void:
	var by_id := {}
	for run_variant in analysis.get("runs", []):
		var run: Dictionary = run_variant
		by_id[str(run.get("policy_id", ""))] = run
	for required_id in ["swordsman_main", "gunner_main", "mage_main", "summon_support", "ultimate_cycle", "balanced_trio", "resonance_hunter"]:
		if not by_id.has(required_id):
			failures.append("missing policy %s" % required_id)
	var swordsman := by_id.get("swordsman_main", {}) as Dictionary
	var gunner := by_id.get("gunner_main", {}) as Dictionary
	var mage := by_id.get("mage_main", {}) as Dictionary
	var summon := by_id.get("summon_support", {}) as Dictionary
	var ultimate := by_id.get("ultimate_cycle", {}) as Dictionary
	if _score_at(swordsman, 6) < _score_at(mage, 6) * 0.92:
		failures.append("swordsman should be at least competitive early, sword L6 %.2f mage L6 %.2f" % [_score_at(swordsman, 6), _score_at(mage, 6)])
	if _score_at(summon, 18) <= _score_at(summon, 6) * 1.8:
		failures.append("summon support should scale into mid/late game: L6 %.2f L18 %.2f" % [_score_at(summon, 6), _score_at(summon, 18)])
	if _score_at(ultimate, 25) <= _score_at(ultimate, 12) * 1.7:
		failures.append("ultimate cycle should be later-scaling: L12 %.2f L25 %.2f" % [_score_at(ultimate, 12), _score_at(ultimate, 25)])
	var final_scores := [_score_at(swordsman, 25), _score_at(gunner, 25), _score_at(mage, 25)]
	final_scores.sort()
	if final_scores[2] / max(0.001, final_scores[0]) > 1.55:
		failures.append("three hero main axes final scores should stay in same broad band: %s" % str(final_scores))

func _score_at(run: Dictionary, level: int) -> float:
	for snapshot_variant in run.get("timeline", []):
		var snapshot: Dictionary = snapshot_variant
		if int(snapshot.get("level", 0)) == level:
			return float(snapshot.get("score", 0.0))
	return 0.0

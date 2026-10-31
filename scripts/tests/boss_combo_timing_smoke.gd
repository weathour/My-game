extends SceneTree
## Runs the real action scheduler for two complete war-form cycles.
const E = preload("res://scripts/battle/enemy_runtime.gd")
const C = preload("res://scripts/content/enemy_catalog.gd")
const S = preload("res://scripts/battle/enemy_system.gd")
var checks := 0
var failures := 0
func _init() -> void: call_deferred("run")
func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func run() -> void:
	var boss := E.new(1,"boss",Vector2(1600,900))
	boss.configure(C.definition("B18")); boss._apply_form(1); boss.cooldown = 0
	var expected: Array = ["demon_fourfold","demon_skybreaker","demon_quake","demon_heavenfall","demon_final_cleave"]
	var resets: Array = [0.65,0.8,1.0,0.9,3.7]
	var tells: Array = []
	var releases: Array = []
	var elapsed := 0.0
	for frame in 5000:
		elapsed += 0.01
		var output: Dictionary = S.step([boss],boss.position+Vector2(40,0),0.01,{"actor_speed":215.0})
		for event in output.events:
			if event.kind == "enemy_tell": tells.append({"move":boss.current_action.id,"time":elapsed})
			if event.kind == "enemy_release":
				releases.append({"move":event.geometry.move_id,"time":elapsed})
				expect(not boss.telegraph.is_empty() if event.geometry.action_id == "charge" else boss.telegraph.is_empty(), "only committed charge remains active after release")
		if tells.size() >= 11: break
	expect(tells.size() == 11 and releases.size() == 10,"two complete cycles reach next opening")
	for index in releases.size():
		var beat := index % 5
		expect(releases[index].move == expected[beat] and tells[index].move == expected[beat],"authored order preserved")
		var warning: float = float(releases[index].time) - float(tells[index].time)
		var authored: float = boss.actions[beat].windup
		expect(warning >= authored - 0.001 and warning <= authored + 0.02,"every combo beat keeps its full locked warning")
		var gap: float = float(tells[index+1].time) - float(releases[index].time)
		var active := 0.65 if beat == 1 else 0.0
		expect(gap >= float(resets[beat]) + active - 0.001 and gap <= float(resets[beat]) + active + 0.04,"actual reset matches authored recovery plus moving charge")
		print("BOSS_COMBO_BEAT ",JSON.stringify({"cycle":index/5,"move":expected[beat],"tell":snappedf(tells[index].time,.01),"release":snappedf(releases[index].time,.01),"next_tell":snappedf(tells[index+1].time,.01),"warning":snappedf(warning,.01),"release_to_next_tell":snappedf(gap,.01)}))
	print("BOSS_COMBO_TIMING_SMOKE ","PASS" if failures == 0 else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)

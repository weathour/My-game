extends SceneTree
const H := preload("res://scripts/battle/player_hurtbox.gd")
const G := preload("res://scripts/battle/enemy_geometry.gd")
const B := preload("res://scripts/battle/battle_session.gd")
var checks: Array = []
func expect(label: String, value: bool) -> void:
	checks.append({"label":label,"passed":value})
	if not value: push_error(label)
func _init() -> void:
	expect("actual shared world radius four",H.RADIUS==4 and B.hurt_radius()==4)
	expect("swept fast projectile crosses tiny actor",H.contains_swept(Vector2(-100,0),Vector2(100,0),4,Vector2.ZERO,Vector2.ZERO))
	expect("relative crossing actor and projectile paths hit",H.contains_swept(Vector2(-100,0),Vector2(100,0),4,Vector2(0,-100),Vector2(0,100)))
	expect("parallel moving actor with20gap does not hit",not H.contains_swept(Vector2.ZERO,Vector2(100,0),4,Vector2(0,20),Vector2(100,20)))
	expect("paths crossing at different times do not hit",not H.contains_swept(Vector2(-100,0),Vector2(100,0),4,Vector2.ZERO,Vector2(0,100)))
	expect("projectile radius4 plus hurt4 boundary hits",H.contains_swept(Vector2(-100,8),Vector2(100,8),4,Vector2.ZERO,Vector2.ZERO))
	expect("projectile radius4 plus hurt4 outside misses",not H.contains_swept(Vector2(-100,8.01),Vector2(100,8.01),4,Vector2.ZERO,Vector2.ZERO))
	var disc := {"shape":"disc","origin":Vector2.ZERO,"radius":100.0}
	expect("disc reaches104 actual padding",G.contains(disc,Vector2(104,0)))
	expect("disc misses104.01",not G.contains(disc,Vector2(104.01,0)))
	var line := {"shape":"line","origin":Vector2.ZERO,"direction":Vector2.RIGHT,"length":100.0,"half_width":10.0}
	expect("line reaches14 actual padding",G.contains(line,Vector2(50,14)))
	expect("line misses14.01",not G.contains(line,Vector2(50,14.01)))
	expect("capsule endpoint includes radial padding",G.contains(line,Vector2(114,0)))
	expect("capsule endpoint outside misses",not G.contains(line,Vector2(114.01,0)))
	var sector := {"shape":"sector","origin":Vector2.ZERO,"direction":Vector2.RIGHT,"radius":100.0,"spread":1.0}
	expect("sector front hits",G.contains(sector,Vector2(50,0)))
	expect("sector rear outside hurt4 misses",not G.contains(sector,Vector2(-10,0)))
	expect("sector origin4 intersects actor",G.contains(sector,Vector2(-4,0)))
	var ring := {"shape":"ring_gap","origin":Vector2.ZERO,"direction":Vector2.RIGHT,"radius":100.0,"inner_radius":40.0,"gap_angle":0.0,"gap_width":1.2}
	expect("ring gap permits actor in gap",not G.contains(ring,Vector2(60,0)))
	expect("ring opposite side hurts",G.contains(ring,Vector2(-60,0)))
	expect("ring hole remains safe outside padding",not G.contains(ring,Vector2(-35.99,0)))
	expect("ring inner edge plus4 hits",G.contains(ring,Vector2(-36,0)))
	var failures := 0
	for item in checks: failures+=int(not item.passed)
	var path := "/tmp/danmaku-geometry.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): path=arg.trim_prefix("--output=")
	var f := FileAccess.open(path,FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"Production shared hurtbox and area geometry primitives; session wiring verified separately by source inspection and normal sessions."},"  "))
	print("GEOMETRY_PROBE checks=",checks.size()," failures=",failures);quit(0 if failures==0 else 1)

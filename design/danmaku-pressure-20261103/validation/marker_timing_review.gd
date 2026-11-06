extends SceneTree
const G := preload("res://scripts/battle/enemy_geometry.gd")
var regex := RegEx.new()
func decode(value: Variant) -> Variant:
	if value is String and value.begins_with("(") and value.ends_with(")"):
		var parts: PackedStringArray = value.trim_prefix("(").trim_suffix(")").split(",")
		if parts.size()==2 and parts[0].strip_edges().is_valid_float() and parts[1].strip_edges().is_valid_float(): return Vector2(float(parts[0]),float(parts[1]))
	if value is Dictionary:
		var result := {}
		for key in value: result[key]=decode(value[key])
		return result
	if value is Array:
		var result: Array=[]
		for item in value: result.append(decode(item))
		return result
	return value
func _init() -> void:
	var source := "";var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source="): source=arg.trim_prefix("--source=")
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source))
	var reviews: Array=[];var still_zero:=0
	for record in data.reports:
		for raw in record.warning_initial_reachability:
			if int(raw.safe_sampled_routes)>0: continue
			var w: Dictionary=decode(raw)
			var warning: Dictionary=w.warning
			var markers: Array=[warning]+warning.get("extra_markers",[])
			var max_deadline:=0.0
			for marker in markers: max_deadline=maxf(max_deadline,float(marker.remaining)-.2)
			var safe:=0;var chosen: Vector2=w.position
			for ring in [.0,.25,.5,.75,1.0]:
				for index in 64:
					var endpoint: Vector2=(w.position+Vector2.RIGHT.rotated(index*TAU/64)*float(w.speed)*max_deadline*float(ring)).clamp(Vector2(55,65),Vector2(3145,1735))
					var distance: float=w.position.distance_to(endpoint)
					var blocked:=false
					for marker in markers:
						var remaining:=maxf(0,float(marker.remaining)-.2)
						var at_release: Vector2=w.position.lerp(endpoint,minf(1,float(w.speed)*remaining/maxf(.001,distance)))
						if G.contains(marker,at_release): blocked=true;break
					if not blocked: safe+=1;chosen=endpoint
			still_zero+=int(safe==0)
			reviews.append({"stage":record.stage,"phase":record.phase_fixture,"start":record.start,"strategy":record.strategy,"seed":record.seed,"time":w.time,"move_id":w.move_id,"initial_earliest_deadline_safe_routes":0,"per_marker_release_safe_routes":safe,"example_endpoint":chosen,"speed":w.speed,"reaction":.2,"marker_deadlines":markers.map(func(m): return float(m.remaining))})
	var f:=FileAccess.open(output,FileAccess.WRITE)
	f.store_string(JSON.stringify({"scope":"Rechecks conservative initial-tell zeros using each marker's own release deadline and production hurt4 geometry. Tests marker series only; active hazards/projectiles are not replayed. Full damage-on reactive sessions separately establish actual successful phase completions.","reviewed":reviews.size(),"still_zero":still_zero,"reviews":reviews},"  "))
	print("MARKER_TIMING_REVIEW reviewed=",reviews.size()," still_zero=",still_zero);quit()

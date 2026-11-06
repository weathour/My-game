extends SceneTree
## Lossless render-cache contracts. Pixel readbacks occur only in this verification.
const P=preload("res://scripts/ui/chronicle/skill_presentation_profiles.gd")
const A=preload("res://scripts/ui/chronicle/authored_battle_effects.gd")
const V=preload("res://scripts/ui/chronicle/skill_presentation.gd")
var checks:=0
var failures:=0
func _init() -> void:call_deferred("run")
func expect(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func run() -> void:
	for ability in P.all_profiles():
		var raw: Dictionary=P.all_profiles()[ability]
		var compiled:=P.render_profile(raw.source,ability)
		expect(compiled.is_read_only(),ability+" compiled profile immutable")
		expect(is_same(compiled,P.render_profile(raw.source,ability)),ability+" stable render lookup shares one dictionary")
		for key in raw:expect(compiled[key]==raw[key],ability+" retains raw "+str(key))
		expect(compiled._palette_color==Color(str(raw.palette)) and compiled._accent_color==Color(str(raw.accent)),ability+" exact parsed colors")
		var edited:=P.profile(raw.source,ability);edited.palette="ff0000"
		expect(P.profile(raw.source,ability).palette==raw.palette and P.render_profile(raw.source,ability)._palette_color==Color(str(raw.palette)),ability+" public copies cannot contaminate render cache")
		var count:=3+int(raw.signature)%5
		for i in count+1:expect(compiled._glyph_outline[i]==Vector2.from_angle(TAU*i/count),ability+" exact static glyph vertex")
		for i in 5:expect(compiled._contact_primary[i]==Vector2.from_angle(i*TAU/5+float(raw.signature)*.21),ability+" exact contact direction")
	var blade:=P.render_profile("JIA","JIA_basic",0)
	var spear:=P.render_profile("JIA","JIA_basic",1)
	expect(blade.weapon=="dao" and spear.weapon=="spear" and spear.motion=="thrust","JIA equipment variant has its own compiled entry")
	expect(P.render_profile("F05","curse_dot").source=="F05" and P.render_profile("F05","curse_dot").material=="curse","curse alias retains actual source identity")
	expect(P.render_profile("F02","guard_counter").motion=="guard","guard alias retains counter identity")
	var first:=A.new();var second:=A.new()
	expect(is_same(first.clips,second.clips) and first.clips.is_read_only(),"all attempts share immutable clip atlas data")
	for key in A.SCENES:
		var scene: SceneState=A.SCENES[key].get_state()
		for node in scene.get_node_count():
			for property in scene.get_node_property_count(node):
				if scene.get_node_property_name(node,property)!=&"sprite_frames":continue
				var frames: SpriteFrames=scene.get_node_property_value(node,property)
				var animation:=frames.get_animation_names()[0]
				var union:=Rect2i()
				var total:=0.0
				for i in frames.get_frame_count(animation):
					var texture:=frames.get_frame_texture(animation,i)
					var used:=texture.get_image().get_used_rect()
					union=used if i==0 else union.merge(used)
					total+=frames.get_frame_duration(animation,i)/frames.get_animation_speed(animation)
					expect(first.clips[key].textures[i].region==Rect2(A.CLIP_BOUNDS[key]),key+" atlas region unchanged")
				expect(union==first.clips[key].bounds and total==first.clips[key].duration,key+" exact source alpha union and timing")
	var wave:=Rect2i()
	for i in range(11,17):
		var texture: Texture2D=load("res://effects/wizard/wave/%d.png" % i)
		var used:=texture.get_image().get_used_rect();wave=used if i==11 else wave.merge(used)
	expect(wave==first.clips.wave.bounds,"wave exact source alpha union")
	var visible:=Rect2(0,0,100,100)
	expect(not V.effect_visible({"origin":Vector2(-1000,50),"radius":20.0},visible),"entirely offscreen small effect is not drawn")
	expect(V.effect_visible({"origin":Vector2(-200,50),"radius":240.0},visible),"offscreen center with overlapping large ring remains visible")
	expect(V.effect_visible({"origin":Vector2(-600,50),"radius":700.0,"kind":"slash"},visible),"long attack tip crossing viewport remains visible")
	expect(V.effect_visible({"origin":Vector2(-1000,50),"radius":0.0,"position_after":Vector2(50,50)},visible),"actual dash end inside viewport retains its trail")
	expect(V.effect_visible({"origin":Vector2(-10000,0),"phase":"benefit"},visible),"screen-space actual receiver text is never world-culled")
	var viewport:=SubViewport.new();viewport.size=Vector2i(200,100);root.add_child(viewport)
	var parent:=Node2D.new();parent.position=Vector2(30,50);parent.scale=Vector2(2,2);viewport.add_child(parent)
	var painter:=Node2D.new();painter.position=Vector2(10,5);parent.add_child(painter);await process_frame
	var projected:=V.world_view(painter,Vector2(-100,-50),2.0)
	expect(projected.is_equal_approx(Rect2(-10.5,-38,146,121)),"viewport projection accounts for parent scale/translation and world scale")
	viewport.free();first=null;second=null
	print("CHRONICLE_SKILL_CACHE_SMOKE ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures)
	quit(1 if failures else 0)

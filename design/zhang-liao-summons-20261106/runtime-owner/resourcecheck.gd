extends SceneTree
## Actual imported clip bindings/bounds only; native visual acceptance is separate.
const P=preload("res://scripts/ui/chronicle/zhang_liao_summon_presentation.gd")
const ACTOR=preload("res://scripts/ui/chronicle/enemy_actor.gd")
const BOUNDS=preload("res://scripts/ui/chronicle/battle_sprite_bounds.gd")
var checks:=0
var failures:=0
func _init():call_deferred("run")
func expect(value:bool,label:String):
	checks+=1
	if not value:failures+=1;push_error(label)
func run():
	var p:=P.new();p.warmup()
	expect(p.clips.size()==10,"ten real imported strips")
	expect(not p.trace_draws,"ordinary draw tracing disabled")
	var identities:Dictionary={}
	var frames:=0
	var actors:=0
	var effects:=0
	for key in p.clips:
		var clip:Dictionary=p.clips[key]
		var image:Texture2D=clip.texture
		identities[key]=image.get_instance_id()
		var dimensions:Vector2i=Vector2i(clip.frame_size[0],clip.frame_size[1])
		expect(image.resource_path.begins_with(P.ROOT),"real new asset path "+str(key))
		expect(image.get_size()==Vector2(dimensions.x*int(clip.frames),dimensions.y),"real imported dimensions "+str(key))
		for index in int(clip.frames):
			frames+=1
			var used:Rect2i=BOUNDS.used_rect(image,Rect2i(index*dimensions.x,0,dimensions.x,dimensions.y))
			expect(used.has_area(),"actual nonempty bounds "+str(key)+str(index))
		if clip.kind=="effect":
			effects+=1
			expect(clip.world_size.size()==2 and float(clip.world_size[0])==260.0 and float(clip.world_size[1])==260.0 and dimensions==Vector2i(512,512),"square actual effect calibration "+str(key))
			continue
		actors+=1
		var visual:=ACTOR.new();visual.setup(str(clip.visual_id));root.add_child(visual)
		var original:float=visual.body_profile().x
		var world_height:=200.0 if clip.visual_id=="M03_WAR" else 190.0 if clip.visual_id=="M04_WAR" else 128.0 if clip.visual_id=="M03_human" else 120.0 if clip.visual_id=="M04_human" else 240.0
		visual.scale=Vector2.ONE*world_height/original
		for index in int(clip.frames):
			expect(visual.present_summon_frame(clip,index,Vector2.LEFT,1.0,Vector2.ZERO,2.0),"actual body API "+str(key)+str(index))
			expect(visual.sprite.texture==image and visual.sprite.frame==index and visual.sprite.hframes==int(clip.frames),"actual frame binding "+str(key)+str(index))
			var ground:Vector2=visual.sprite.position+(Vector2(384,608)-Vector2(768,640)*.5)*visual.sprite.scale
			expect(ground.is_equal_approx(Vector2.ZERO),"fixed new art ground anchor "+str(key)+str(index))
			expect(is_equal_approx(224.0*visual.scale.y*visual.sprite.scale.y,world_height),"unchanged visible world body "+str(key)+str(index))
		visual.preview("idle",2.1)
		expect(visual.sprite.scale==Vector2.ONE and not visual.sprite.texture.resource_path.begins_with(P.ROOT),"ordinary clip restores old profile "+str(key))
		visual.free()
	for repeat in 100:p.warmup()
	for key in identities:expect(p.clips[key].texture.get_instance_id()==identities[key],"compiled resource reused "+str(key))
	expect(frames==76 and actors==8 and effects==2,"actual eight actor/sixty poses and two FX/sixteen frames")
	expect(BOUNDS.readbacks==0,"no new alpha readback in all seventy-six real imported frames")
	print("LIAO_SUMMON_RESOURCECHECK ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures," frames=",frames," alpha_readbacks=",BOUNDS.readbacks)
	quit(0 if failures==0 else 1)

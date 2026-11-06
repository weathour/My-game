extends SceneTree
## Political identity, historical reading and rendering through production services.
const CAMPAIGN := preload("res://scripts/campaign/campaign_service.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const STORY := preload("res://scripts/content/story_catalog.gd")
const READER := preload("res://scripts/ui/chronicle/chronicle_story_view.gd")
const SHELL := preload("res://scenes/chronicle/chronicle_shell.tscn")
const LOOK := preload("res://scripts/ui/chronicle/jia_appearance.gd")
const PORTRAITS := preload("res://scripts/ui/chronicle/chronicle_portraits.gd")
const SETTINGS := preload("res://scripts/shared/settings.gd")
const OLD_IDS := ["s14_01","s14_02","s14_03","s14_04","s14_05","s14_06","s14_n01","s14_n02","s14_n03","s14_n04","s14_n05","s14_n06","s14_n07","s14_08","s14_07","s14_n15","s14_n13","s14_n14","s14_anchor_01","s14_09"]
const REACTION := "RX_S14_LORD_01"
const RX_LINE := "rx_s14_lord_01_01"
const HALL := "res://assets/story/chronicle/lord-hall.png"
const CHAMBER := "res://assets/story/chronicle/lord-chamber.png"
const FORMS := [
	["lord_formal","smirk","JIA-lord-formal-smirk.png"],
	["lord_formal","laugh","JIA-lord-formal-laugh.png"],
	["lord_casual","laugh","JIA-lord-casual-laugh.png"],
	["lord_casual","approach","JIA-lord-casual-approach.png"],
]

class GuardedCampaign extends "res://scripts/campaign/campaign_service.gd":
	var guarded := false
	var mutations: Array[String] = []
	func block(method: String) -> bool:
		if guarded: mutations.append(method)
		return guarded
	func commit(previous: Dictionary) -> bool: return false if block("commit") else super.commit(previous)
	func save_slot(slot: String) -> bool: return false if block("save_slot") else super.save_slot(slot)
	func load_slot(slot: String) -> bool: return false if block("load_slot") else super.load_slot(slot)
	func resolve_event() -> bool: return false if block("resolve_event") else super.resolve_event()
	func choose_node(id: String) -> bool: return false if block("choose_node") else super.choose_node(id)
	func save_story_checkpoint(id: String,line: String) -> bool: return false if block("checkpoint") else super.save_story_checkpoint(id,line)
	func save_optional_story_checkpoint(id: String,line: String) -> bool: return false if block("optional_checkpoint") else super.save_optional_story_checkpoint(id,line)
	func complete_optional_story(id: String) -> bool: return false if block("optional_complete") else super.complete_optional_story(id)
	func start_battle() -> Dictionary: return {} if block("start_battle") else super.start_battle()
	func complete_battle(result: Dictionary) -> bool: return false if block("complete_battle") else super.complete_battle(result)

var checks := 0
var failures := 0
var changed := 0
var viewport: SubViewport
var container: SubViewportContainer
var reader: Control
var shell: Control
var state: GuardedCampaign
var event: Dictionary
var capture_dir := ""

func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="): capture_dir = argument.trim_prefix("--capture=")
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	call_deferred("run")

func expect(value: bool,label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)

func frames(count: int = 3) -> void:
	for index in count: await process_frame

func texture_path(texture: Texture2D) -> String:
	while texture is AtlasTexture: texture = texture.atlas
	return texture.resource_path if texture != null else ""

func line_ids(value: Dictionary) -> Array:
	var ids: Array = []
	for line in value.lines: ids.append(line.id)
	return ids

func snapshot_files() -> Dictionary:
	var result := {}
	for name in DirAccess.get_files_at(state.directory):
		var path: String = state.directory.path_join(name)
		result[name] = {"bytes":FileAccess.get_file_as_bytes(path),"mtime":FileAccess.get_modified_time(path)}
	return result

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"),"isolated data/config")
	if failures: quit(1); return
	var old_motion := SETTINGS.comfort_enabled("reduced_motion")
	SETTINGS.save_comfort("reduced_motion",true)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		container = SubViewportContainer.new()
		container.size = Vector2(1280,720)
		root.add_child(container)
		container.add_child(viewport)
	else: root.add_child(viewport)
	event = STORY.events().S14
	check_catalog_and_projection()
	check_portrait_cache()
	state = GuardedCampaign.new()
	state.directory = "user://lord_epilogue_"+str(Time.get_ticks_usec())
	state.changed.connect(func(): changed += 1)
	await check_transactions()
	await check_old_checkpoints()
	check_f11_contexts()
	await check_reader_precedence()
	await check_line_restore_and_names()
	await check_replay_and_menu()
	if not capture_dir.is_empty() and DisplayServer.get_name() != "headless": await native_review()
	if is_instance_valid(reader): reader.queue_free()
	if is_instance_valid(shell): shell.queue_free()
	await frames()
	viewport.queue_free()
	if container != null: container.queue_free()
	await frames()
	await create_timer(.3).timeout
	SETTINGS.save_comfort("reduced_motion",old_motion)
	print("JIA_LORD_EPILOGUE_SMOKE ","PASS" if failures == 0 else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)

func check_catalog_and_projection() -> void:
	expect(STORY.validate().is_empty(),"whole authored catalog validates")
	expect(STORY.events().size()==22 and STORY.optional_events().size()==32 and STORY.reactions().size()==49,"exact catalog sizes")
	var ids := line_ids(event)
	expect(ids.slice(0,20)==OLD_IDS and ids.size()==58,"all previous twenty IDs retained in order")
	for index in 38: expect(ids[index+20]=="s14_lord_%02d"%(index+1),"append-only epilogue ID "+str(index))
	for data in [
		{"current":"B18","completed":[],"available":["S14"]},
		{"current":"S14","completed":["B17"],"available":["S14"],"finished":true,"owned":{"M01":{"level":9999}},"pending":{"candidates":["M01"]}},
	]:
		expect(not LOOK.lord_unlocked(data) and LOOK.for_campaign(data)=="campaign","future nodes/ownership/level/rewards never grant lord")
	for data in [{"current":"S14","completed":["B18"]},{"current":"S14","completed":["B18","S14"],"finished":true}]:
		var unchanged: Dictionary = data.duplicate(true)
		expect(LOOK.lord_unlocked(data) and LOOK.for_campaign(data)=="lord_formal" and LOOK.for_campaign(data,"rest")=="lord_casual","valid completed B18 projects formal/private contexts")
		expect(data==unchanged,"projection writes no identity flag/schema")
	expect(LOOK.for_battle({"node":{"id":"B18"}})=="campaign" and LOOK.for_story(event)=="campaign","war armor and historical S14 opening remain distinct")
	for fixture in [
		[["B01","B18"],"common"],[["B13","B18"],"campaign"],[["B18","S14"],"lord_formal"],
	]: expect(LOOK.for_story({"id":"optional-fixture","conditions":{"completed_any":fixture[0]}})==fixture[1],"OR gate guarantees earliest possible historical phase")
	expect(LOOK.for_story({"id":"S01","jia_appearance":"lord_casual"})=="lord_casual","explicit event context precedes historical fallback")
	var characters := {}
	for person in JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/characters.json")): characters[person.id]=true
	for patch in [{"appearance":"../../outside"},{"appearance":77},{"expression":"unknown"},{"expression":[]}]:
		var actor := {"id":"JIA","slot":"left"};actor.merge(patch,true)
		expect(not STORY._validate_lines([{"id":"invalid","speaker":"JIA","text":"test","actors":[actor]}],"S14",characters).is_empty(),"catalog rejects malformed actor enum "+str(patch))
	expect(not STORY._validate_lines([{"id":"invalid","text":"test","location":"","actors":[]}],"S14",characters).is_empty(),"catalog rejects blank cumulative location")
	expect(not STORY._validate_lines([{"id":"invalid","text":"test","actors":[{"id":"F11","slot":"right","appearance":"lord_formal"}]}],"S14",characters).is_empty(),"catalog rejects non-Jia costume field")
	var original: Dictionary = STORY._events.duplicate(true)
	for invalid in ["unknown","res://fake.png",12]:
		STORY._events.S14.jia_appearance=invalid
		expect(STORY.validate().any(func(error: String)->bool:return error.contains("Invalid story appearance")),"catalog rejects illegal event context")
	STORY._events=original
	expect(LOOK.normalize_appearance("../x")=="common" and LOOK.normalize_expression("../x")=="neutral","renderer enum fallback cannot become a resource path")

func check_portrait_cache() -> void:
	var unique := {}
	for form in FORMS:
		var texture: Texture2D = PORTRAITS.standing("JIA",form[0],form[1])
		expect(texture != null and texture.resource_path=="res://assets/ui/chronicle/characters/"+str(form[2]) and texture.get_size()==Vector2(1024,1536),"four distinct fixed full-resolution source assets")
		unique[texture.get_instance_id()]=true
		PORTRAITS.texture("JIA",form[0],form[1]);PORTRAITS.dialogue("JIA",form[0],form[1])
	expect(unique.size()==4,"four expressions really resolve four images")
	expect(PORTRAITS.standing("JIA","lord_formal","neutral")==PORTRAITS.standing("JIA","lord_formal","smirk"),"formal default pose is smirk")
	expect(PORTRAITS.standing("JIA","lord_casual","smirk")==PORTRAITS.standing("JIA","lord_casual","laugh"),"unsupported legal casual expression uses casual default")
	var sizes := [PORTRAITS.cache.size(),PORTRAITS.standing_cache.size(),PORTRAITS.dialogue_cache.size()]
	for repeat in 100:
		for form in FORMS:
			expect(PORTRAITS.standing("JIA",form[0],form[1]).get_instance_id() in unique,"cached source instance reused")
			PORTRAITS.texture("JIA",form[0],form[1]);PORTRAITS.dialogue("JIA",form[0],form[1])
	expect(sizes==[PORTRAITS.cache.size(),PORTRAITS.standing_cache.size(),PORTRAITS.dialogue_cache.size()],"repeated projection grows no image/atlas caches")
	for id in ["F11","F01","M01","N01"]:
		for form in FORMS: expect(PORTRAITS.dialogue(id,form[0],form[1])==PORTRAITS.dialogue(id),"non-Jia portrait never inherits costume "+id)

func b18_fixture() -> Dictionary:
	var value: Dictionary = state.data.duplicate(true)
	value.current="B18";value.completed=["B17"];value.available=["B18"];value.finished=false
	value.pending={};value.deferred_reward={};value.story_checkpoint={};value.story_contexts={}
	value.reward_seed=71106;value.reward_index=0
	value.owned={"JIA":C.record("JIA"),"F11":C.record("F11")}
	value.owned.JIA.hp=17.0;value.owned.JIA.mp=3.0;value.owned.F11.hp=9.0;value.owned.F11.mp=2.0
	value.party=["",""]
	return value

func check_transactions() -> void:
	state.data=b18_fixture()
	var before: Dictionary = state.data.duplicate(true)
	var request: Dictionary = state.start_battle()
	expect(not request.is_empty() and not LOOK.lord_unlocked(state.data),"B18 entry does not grant political identity")
	expect(state.save_slot("1"),"in-progress battle can save entry snapshot")
	var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(state.directory.path_join("1.json")))
	expect(not LOOK.lord_unlocked(disk) and disk.schema==1 and disk.keys().size()==before.keys().size(),"battle save has no new flag/schema or premature identity")
	expect(not state.complete_battle({"attempt_id":request.attempt_id,"outcome":"failed","characters":request.characters}),"failed B18 cannot commit victory")
	state.abandon_battle()
	expect(state.data==before and not LOOK.lord_unlocked(state.data),"cancel/failure restores exact entry state")
	request=state.start_battle()
	expect(not state.complete_battle({"attempt_id":"wrong","outcome":"victory","characters":request.characters}),"foreign victory cannot unlock lord")
	expect(state.complete_battle({"attempt_id":request.attempt_id,"outcome":"victory","characters":request.characters}),"real service accepts valid B18 victory transaction")
	expect(LOOK.lord_unlocked(state.data) and state.data.current=="S14" and "B18" in state.data.completed,"identity follows committed B18 and route advances to S14")
	expect(state.data.pending.is_empty() and state.data.deferred_reward.id=="B18" and state.data.reward_index==0,"seven-pick-three remains deferred until S14 completion")
	expect(state.data.owned==before.owned and state.data.inventory==before.inventory and state.data.pool==before.pool,"victory adds no people/pool gifts/restoration/equipment without their old rules")
	expect(not state.claim_reward() and not state.complete_battle({"attempt_id":request.attempt_id,"outcome":"victory","characters":request.characters}),"neither premature claim nor duplicate victory works")
	var after_win: Dictionary = state.data.duplicate(true)
	for id in [OLD_IDS[0],"s14_lord_19","s14_lord_31","s14_lord_38"]:
		expect(state.save_story_checkpoint("S14",id),"valid S14 checkpoint "+id)
		expect(state.data.pending.is_empty() and state.data.reward_index==0 and state.data.owned==after_win.owned,"reading checkpoint never gives reward/restores resources")
	expect(state.resolve_event(),"S14 completion commits its existing ending transaction")
	expect(state.data.finished and "S14" in state.data.completed and state.data.deferred_reward.is_empty() and state.data.pending.node=="B18" and state.data.pending.picks==3 and state.data.pending.candidates.size()==7 and state.data.reward_index==1,"only story completion creates exact seven-pick-three")
	expect(state.data.owned.keys()==before.owned.keys() and "M01" in state.data.pool and "F01" in state.data.pool,"ending opens old pool but never grants those characters directly")
	for id in state.data.owned:
		expect(state.data.owned[id].hp==state.resource_max(id,"hp") and state.data.owned[id].mp==state.resource_max(id,"mp"),"existing ending restoration happens once")
	var once: Dictionary = state.data.duplicate(true)
	expect(not state.resolve_event() and state.data==once,"ending cannot issue a second reward")
	for id in state.data.pending.candidates.slice(0,3): expect(state.select_card(id),"select existing ending reward "+id)
	expect(state.claim_reward(),"normal three-card claim remains available")
	var claimed: Dictionary = state.data.duplicate(true)
	expect(not state.claim_reward() and not state.resolve_event() and state.data==claimed,"claim/completion cannot duplicate after clear")

func mount_reader(value: Dictionary,line: String) -> void:
	if is_instance_valid(reader): reader.queue_free();await frames()
	reader=READER.new();reader.setup(value,line);viewport.add_child(reader);await frames()

func check_old_checkpoints() -> void:
	var late: Dictionary = state.data.duplicate(true)
	for id in OLD_IDS:
		state.data=late.duplicate(true);state.data.finished=false;state.data.current="S14";state.data.available=["S14"];state.data.completed=["B18"];state.data.pending={};state.data.deferred_reward={"id":"B18","extra":false};state.data.story_contexts={};state.data.story_checkpoint={"event":"S14","line":id}
		expect(state.save_slot("2") and state.load_slot("2"),"schema-1 old interrupted line loads "+id)
		var restored: Dictionary = state.story_event("S14")
		expect(STORY.line_id(restored,state.data.story_checkpoint)==id and restored.lines.size()==58,"old checkpoint keeps exact line and never invents late reaction")
		await mount_reader(restored,id)
		expect(reader.current_line_id==id and reader._background_path==event.background and reader._resolved_location()==event.location,"old line resumes original scene/location "+id)
		if reader._actors.has("JIA"): expect(reader._actors.JIA.get_meta("appearance")=="campaign","old opening keeps battlefield armor "+id)
	state.data=late

func check_f11_contexts() -> void:
	var late: Dictionary = state.data.duplicate(true)
	for variant in ["absent","dead","alive"]:
		state.data=late.duplicate(true);state.data.finished=false;state.data.current="S14";state.data.completed=["B18"];state.data.available=["S14"];state.data.pending={};state.data.deferred_reward={"id":"B18","extra":false};state.data.story_checkpoint={};state.data.story_contexts={}
		state.data.owned.erase("F11")
		if variant!="absent":
			state.data.owned.F11=C.record("F11")
			if variant=="dead":state.data.owned.F11.hp=0.0;state.data.owned.F11.dead=true
		expect(state.save_story_checkpoint("S14",OLD_IDS[0]),"freeze real first-read conditional context "+variant)
		var resolved: Dictionary = state.story_event("S14")
		var ids := line_ids(resolved)
		expect((RX_LINE in ids)==(variant=="alive") and ids.size()==(59 if variant=="alive" else 58),"F11 owned plus alive is exact condition "+variant)
		if variant=="alive":expect(ids.find(RX_LINE)==ids.find("s14_lord_33")+1,"new reaction follows exact authored anchor")
		var frozen: Dictionary = state.data.story_contexts.S14.duplicate(true)
		state.data.owned.F11=C.record("F11")
		expect(state.story_event("S14",true).lines==resolved.lines and state.data.story_contexts.S14==frozen,"later obtain/revival cannot fabricate historical reaction "+variant)
	state.data=late.duplicate(true);state.data.story_contexts.erase("S14");state.data.owned.F11=C.record("F11")
	expect(state.story_event("S14",true).lines.size()==58,"old cleared save without context gets complete base tail without invented reaction")
	state.data=late

func check_reader_precedence() -> void:
	var custom := {"id":"S14","title":"衣装接口验证","location":"外署","background":HALL,"jia_appearance":"lord_formal","lines":[]}
	for index in 5:
		var form: Array = [ ["campaign","neutral"], ["lord_formal","smirk"], ["lord_formal","laugh"], ["lord_casual","laugh"], ["lord_casual","approach"] ][index]
		custom.lines.append({"id":"swap"+str(index),"speaker":"JIA","text":"衣装与姿态切换验证。","actors":[{"id":"JIA","slot":"left","appearance":form[0],"expression":form[1]}]})
	custom.lines.append({"id":"event-default","speaker":"JIA","text":"显式场景正装。","actors":[{"id":"JIA","slot":"left"}]})
	custom.lines.append({"id":"explicit-texture","speaker":"JIA","text":"旧贴图接口优先。","actors":[{"id":"JIA","slot":"left","texture":"res://assets/ui/chronicle/emma.png","appearance":"lord_formal","expression":"laugh"}]})
	custom.lines.append({"id":"other","speaker":"F11","text":"配角保持原图。","actors":[{"id":"F11","slot":"right","appearance":"lord_formal","expression":"approach"}]})
	for reduced in [true,false]:
		SETTINGS.save_comfort("reduced_motion",reduced)
		await mount_reader(custom,"swap0");await create_timer(.25).timeout
		var actor: TextureRect = reader._actors.JIA
		var identity := actor.get_instance_id();var position := actor.position;var dimensions := actor.size
		for index in 5:
			reader.show_line("swap"+str(index))
			expect(reader._actors.JIA.get_instance_id()==identity and actor.position==position and actor.size==dimensions and actor.get_meta("slot")=="left","same actor costume/pose never slides or remounts, reduced="+str(reduced))
			expect(reader.find_children("StoryActorLeaving_JIA*","TextureRect",true,false).is_empty(),"no retired-image ghost for same actor")
			expect(actor.get_meta("appearance")==custom.lines[index].actors[0].appearance and texture_path(actor.texture)==texture_path(PORTRAITS.dialogue("JIA",custom.lines[index].actors[0].appearance,custom.lines[index].actors[0].expression)),"actor override and actual expression image agree")
			await create_timer(.25).timeout
		reader.show_line("event-default");expect(actor.get_meta("appearance")=="lord_formal","event override precedes S14 campaign default")
		reader.show_line("explicit-texture");expect(texture_path(actor.texture)=="res://assets/ui/chronicle/emma.png","explicit texture remains highest-priority old API")
		reader.show_line("other");expect(reader._actors.F11.get_meta("appearance")=="common" and reader._actors.F11.texture==PORTRAITS.dialogue("F11"),"renderer ignores invalid non-Jia costume without changing companion")
	SETTINGS.save_comfort("reduced_motion",true)

func check_line_restore_and_names() -> void:
	await mount_reader(event,"s14_lord_31")
	for pair in [["s14_lord_31",CHAMBER,"外署内室","lord_casual"],["s14_lord_02",HALL,"外署正堂","lord_formal"],["s14_03",event.background,event.location,"campaign"],["s14_lord_19",HALL,"外署正堂","lord_formal"],["s14_lord_30",CHAMBER,"外署内室","lord_casual"]]:
		reader.show_line(pair[0]);await frames()
		expect(reader._background_path==pair[1] and reader._resolved_location()==pair[2] and reader._actors.JIA.get_meta("appearance")==pair[3],"direct seek/backward/fast-forward restores complete historical scene "+pair[0])
	var anonymous := 0
	for line in event.lines:
		if line.has("speaker_name"):
			anonymous+=1;reader.show_line(line.id)
			expect(line.get("speaker","")=="" and line.speaker_name in ["老兵","乡人","义勇","众人"] and reader._speaker_name.text==line.speaker_name and reader._name_panel.visible,"anonymous named voice is actually rendered "+line.id)
			expect(reader.history_entries().back().speaker_name==line.speaker_name,"history preserves anonymous voice label "+line.id)
	expect(anonymous==11,"all eleven new anonymous attributions exercised")
	reader.show_line("s14_lord_31");reader.reveal_current();reader._open_history()
	var reading: Dictionary = reader.reading_state()
	reader._close_history(false);reader.restore_reading_state(reading);await frames()
	expect(reader.is_history_open() and reader.current_line_id=="s14_lord_31" and reader._background_path==CHAMBER and reader._resolved_location()=="外署内室","history restoration retains location/background/pose at the same line")
	reader._close_history(false)

func check_replay_and_menu() -> void:
	if is_instance_valid(reader): reader.queue_free();await frames()
	state.data.owned.JIA.hp=7.0;state.data.owned.JIA.mp=1.0
	state.data.story_contexts.erase("S14")
	for id in ["S01","S10","S11","B13","S12"]:
		if id not in state.data.completed:state.data.completed.append(id)
	state.data.optional_story_read=["CE22","CE23","CE25"]
	expect(state.save_slot("1"),"late low-resource save baseline")
	shell=SHELL.instantiate();shell.session=state;viewport.add_child(shell);await frames()
	for page in ["world","route","roster"]:
		shell.open_page(page);await frames()
		var expected := "lord_casual" if page in ["world","route"] else "lord_formal"
		if page=="roster":
			var card: Button = shell.find_child("character_JIA",true,false)
			expect(card!=null and card.appearance==expected and texture_path(card.portrait).contains("JIA-lord-formal"),"formal roster actually selects formal source")
		else:
			var found := false
			for image in shell.find_children("*","TextureRect",true,false):
				if image.get_meta("character_id","")=="JIA":
					found=true;expect(image.get_meta("appearance")==expected and texture_path(image.texture).contains("JIA-lord-casual"),"finished camp presenter actually selects casual source "+page)
			expect(found,"existing camp command presenter exposes Jia "+page)
		shell.inspect_character("JIA");await frames()
		expect(shell.character_sheet.appearance_context==expected and texture_path(shell.character_sheet.portrait.texture).contains("JIA-lord-"+("casual" if expected=="lord_casual" else "formal")),"detail inherits actual opener context "+page)
		shell.close_character_sheet(false);await frames()
	shell.open_page("journal");await frames()
	var before: Dictionary = state.data.duplicate(true);var files := snapshot_files();var rng: int = state.reward_rng.state;var signals := changed
	state.guarded=true;state.mutations.clear()
	for pair in [["S14","s14_03","campaign"],["S14","s14_lord_02","lord_formal"],["S14","s14_lord_31","lord_casual"],["S01","s01_03","common"],["CE22","","lord_formal"],["CE23","","lord_casual"],["CE25","","campaign"]]:
		expect(shell.open_story_replay(pair[0],"journal"),"late old clear opens historical replay "+pair[0]);await frames()
		var target: String = pair[1]
		if target.is_empty():
			for line in state.story_event(pair[0],true).lines:
				for actor in line.get("actors",[]):
					if actor.id=="JIA":target=line.id;break
				if not target.is_empty():break
		shell.story_view.show_line(target);await frames()
		expect(shell.story_view._actors.has("JIA") and shell.story_view._actors.JIA.get_meta("appearance")==pair[2],"replay ignores current lord state in favor of historical context "+str(pair))
		if pair[0]=="CE23":expect(shell.story_view._actors.JIA.get_meta("pose")=="laugh","casual archery scene really uses laugh image")
		shell.close_story_replay();await frames()
	expect(state.data==before and state.reward_rng.state==rng and changed==signals and snapshot_files()==files and state.mutations.is_empty(),"repeated replays change no resources/rewards/pool/context/files/mtime/RNG and call no transaction")
	state.guarded=false
	shell.queue_free();await frames();shell=null

func native_review() -> void:
	SETTINGS.save_comfort("reduced_motion",false)
	var resolved := STORY.resolved(event,{"reactions":[REACTION]})
	for dimensions in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
		viewport.size=dimensions;container.size=Vector2(dimensions);DisplayServer.window_set_size(dimensions)
		await mount_reader(resolved,"s14_03")
		var selections: Array = ["s14_03","s14_lord_02","s14_lord_19","s14_lord_30","s14_lord_31",RX_LINE,"s14_lord_24","s14_lord_37"]
		for line in event.lines:
			if line.has("speaker_name"):selections.append(line.id)
		for id in selections:
			reader.show_line(id);reader.reveal_current();await create_timer(.28).timeout;await frames()
			expect(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(reader._dialogue.get_global_rect()),"native dialogue stays inside viewport "+str(dimensions)+id)
			for actor in reader._actors.values():expect(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(actor.get_global_rect()),"native crown/sleeve portrait canvas stays inside viewport")
			await save_native("%d-%s"%[dimensions.x,id])
		reader.show_line("s14_lord_31");reader.reveal_current();await create_timer(.28).timeout
		reader._open_history();await frames();await save_native("%d-history-casual"%dimensions.x)
		reader._close_history(false)
		expect(reader.current_line_id=="s14_lord_31" and reader._background_path==CHAMBER and reader._actors.JIA.get_meta("appearance")=="lord_casual","native history closes onto same private scene")
		var old_slot: Dictionary = state.read_slot("2")
		expect(old_slot.story_checkpoint.line=="s14_09","native legacy recovery uses actual saved old checkpoint")
		await mount_reader(STORY.resolved(event,{}),old_slot.story_checkpoint.line)
		reader.reveal_current();await frames();await save_native("%d-old-slot-s14_09"%dimensions.x)
		reader.queue_free();await frames()
		shell=SHELL.instantiate();shell.session=state;viewport.add_child(shell);await frames()
		for page in ["world","roster"]:
			shell.open_page(page);await frames();await save_native("%d-menu-%s"%[dimensions.x,page])
			shell.inspect_character("JIA");await create_timer(.25).timeout;await frames()
			await save_native("%d-detail-%s"%[dimensions.x,page])
			shell.close_character_sheet(false);await frames()
		shell.queue_free();await frames();shell=null

func save_native(label: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	viewport.get_texture().get_image().save_png(capture_dir.path_join(label+".png"))

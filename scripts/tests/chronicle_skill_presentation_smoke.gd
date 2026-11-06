extends SceneTree
## Full-roster skill-presentation contract. No combat numbers are duplicated here.
const PLAN_PATH := "res://design/skill-presentation-20261105/batch-plan.json"
const VIEW := preload("res://scripts/ui/chronicle/battle_view.gd")
const BATTLE := preload("res://scripts/battle/battle_session.gd")
const SPACE := preload("res://scripts/battle/battle_space.gd")
const HURTBOX := preload("res://scripts/battle/player_hurtbox.gd")
const GEOMETRY := preload("res://scripts/battle/enemy_geometry.gd")
const ENEMY := preload("res://scripts/battle/enemy_runtime.gd")
const ENEMIES := preload("res://scripts/content/enemy_catalog.gd")
const COMBAT := preload("res://scripts/content/combat_catalog.gd")
const PROFILE := preload("res://scripts/ui/chronicle/skill_presentation_profiles.gd")
const ART := preload("res://scripts/ui/chronicle/battle_art.gd")
const SETTINGS := preload("res://scripts/shared/settings.gd")
const AUTHORED := preload("res://scripts/ui/chronicle/authored_battle_effects.gd")
const FEEDBACK := preload("res://scripts/ui/chronicle/combat_feedback.gd")
const DETAILS := preload("res://scripts/ui/chronicle/character_detail_projection.gd")
const ABILITY := preload("res://scripts/battle/ability_definition.gd")
const CORE_FROM_FEET := Vector2(0, -36)
const RADIUS := 4.0
const REQUIRED_PROFILE_FIELDS := ["source", "ability", "weapon", "material", "motion", "palette", "accent", "signature", "strength", "release_duration", "contact_duration"]
var checks := 0
var failures := 0
var capture_dir := ""
var report_path := ""
var ability_rows_checked := 0
var actors_checked := 0
var captures: Array[Dictionary] = []
var performance_samples: Array[Dictionary] = []
var hud_snapshot: Dictionary = {}
var failures_by_test: Array[String] = []
var viewport: SubViewport
var view: Control
var leak_trace_path := ""
var leak_trace: Array[Dictionary] = []
var lifecycle_refs: Dictionary = {}
var audio_refs: Dictionary = {}
var audio_teardown: Dictionary = {}

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_dir = arg.trim_prefix("--capture=")
		if arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
		if arg.begins_with("--leak-trace="): leak_trace_path=arg.trim_prefix("--leak-trace=")
	call_deferred("run")

func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		failures_by_test.append(label)
		push_error(label)

func frames(count: int = 2) -> void:
	for _i in count: await process_frame

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "test uses an isolated temporary user directory")
	if failures: call_deferred("_finish"); return
	verify_plan_and_profiles()
	verify_owned_passive_oracle()
	await verify_actor_load_and_dispatch()
	await verify_jia_weapon_variants()
	await verify_failure_and_delivery_truth()
	verify_benefit_and_state_truth()
	await verify_pause_switch_and_cleanup()
	verify_hurtbox_contract()
	if not capture_dir.is_empty(): await render_acceptance_scenes()
	# Leave all nested await resumptions before report/exit own any local resources.
	call_deferred("_finish")

func verify_plan_and_profiles() -> void:
	var raw := FileAccess.get_file_as_string(PLAN_PATH)
	var plan: Variant = JSON.parse_string(raw)
	expect(plan is Dictionary, "batch plan parses as the frozen coverage oracle")
	if not plan is Dictionary: return
	var rows: Array = plan.get("abilities", [])
	var keys := {}
	var ids := {}
	for row in rows:
		var key := str(row.get("key", ""))
		var id := str(row.get("ability_id", ""))
		expect(not key.is_empty() and not keys.has(key), "coverage key is unique: " + key)
		expect(not id.is_empty() and not ids.has(id), "roster ability id is unique: " + id)
		keys[key] = true
		ids[id] = true
		expect(COMBAT.IDS.has(str(row.get("character_id", ""))), "coverage owner exists in CombatCatalog: " + key)
	expect(rows.size() == 137, "coverage oracle includes all 137 planned ability rows")
	var profiles: Dictionary = PROFILE.all_profiles()
	expect(profiles.size() == ids.size(), "presentation profile count matches the 137 ability oracle")
	for row in rows:
		var character_id := str(row.character_id)
		var ability_id := str(row.ability_id)
		var profile: Dictionary = PROFILE.profile(character_id, ability_id)
		for field in REQUIRED_PROFILE_FIELDS:
			expect(profile.has(field), "%s profile has %s" % [row.key, field])
		expect(str(profile.get("source", "")) == character_id, "%s profile retains owner" % row.key)
		expect(str(profile.get("ability", "")) == ability_id, "%s profile retains ability identity" % row.key)
		expect(str(profile.get("kind", "")) == str(row.get("kind", "")), "%s profile retains its real ability kind" % row.key)
		expect(str(profile.get("mechanic", "")) == str(row.get("mechanic", "")), "%s profile retains its real mechanic" % row.key)
		ability_rows_checked += 1
	# Verify plan rows are not merely present in the display table: every ability
	# resolves to an actual catalog Resource in the declared slot.
	for id in COMBAT.IDS:
		var definition: Dictionary = COMBAT.definition(id)
		var actual: Dictionary = _ability_resources(definition)
		for slot_key in actual:
			var resource: Resource = actual[slot_key]
			var key := "%s:%s:%s" % [id, str(slot_key).split(":")[0], resource.id]
			expect(keys.has(key), "catalog ability is represented in the full coverage oracle: " + key)
			expect(PROFILE.profile(id, str(resource.id), int(resource.kind)).size() >= REQUIRED_PROFILE_FIELDS.size(), "catalog ability resolves its runtime style: " + key)
			var kind_names := ["SWEEP", "THRUST", "PROJECTILE", "NOVA", "HEAL", "MANA", "WARD"]
			var planned: Dictionary = {}
			for row in rows:
				if str(row.get("character_id", "")) == id and str(row.get("ability_id", "")) == str(resource.id): planned = row; break
			expect(not planned.is_empty(), "runtime catalog row resolves to a full plan entry: " + key)
			if not planned.is_empty():
				expect(str(planned.get("kind", "")) == kind_names[int(resource.kind)], "ability screen kind is grounded in actual catalog data: " + key)
				expect(str(planned.get("mechanic", "")) == str(resource.mechanic), "ability screen mechanic is grounded in actual catalog data: " + key)

func verify_owned_passive_oracle() -> void:
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PLAN_PATH))
	var rows: Array = plan.get("owned_passives", [])
	var owners := {}
	expect(rows.size() == 37, "all 37 owned-passive character rows are covered")
	for row in rows:
		var id := str(row.get("character_id", ""))
		expect(not owners.has(id), "owned-passive owner is unique: " + id)
		owners[id] = true
		var actual: Dictionary = COMBAT.definition(id).get("owned", {})
		var expected_bonuses: Dictionary = row.get("bonuses_per_level", {})
		expect(actual.size() == expected_bonuses.size(), "owned-passive stat count matches authoritative catalog: " + id)
		for stat in expected_bonuses:
			expect(actual.has(stat) and is_equal_approx(float(actual.get(stat, -1)), float(expected_bonuses[stat])), "owned-passive oracle matches authoritative per-level catalog values: %s/%s" % [id, stat])
		var record := {"level":1, "dead":false}
		var low_rows: Array[Dictionary] = DETAILS.owned_rows({"owned":{id:record}}, id)
		expect(low_rows.size() == actual.size(), "low-pool owned rows expose each actual passive stat: " + id)
		for low in low_rows:
			var step := float(low.per_level)
			var raw := float(low.card_raw)
			var expected_actual := minf(raw, float(low.cap))
			expect(is_equal_approx(float(low.actual), expected_actual), "owned low-pool actual respects cap: %s/%s" % [id, low.key])
			expect(is_zero_approx(float(low.acquisition_delta)), "already-owned character has no acquisition-only increment: %s/%s" % [id, low.key])
			var expected_next := minf(raw + step, float(low.cap)) - expected_actual
			expect(is_equal_approx(float(low.next_delta), expected_next), "owned next-level increment is the true cap-limited amount: %s/%s" % [id, low.key])
			var dead_bench_rows: Array[Dictionary] = DETAILS.owned_rows({"owned":{id:{"level":1,"dead":true}}, "party":[]}, id)
			expect(dead_bench_rows.size() == low_rows.size() and bool(dead_bench_rows[0].owned), "dead/bench ownership still grants passive ledger rows: " + id)
			var unowned_rows: Array[Dictionary] = DETAILS.owned_rows({"owned":{}}, id)
			var matching: Dictionary = {}
			for unowned in unowned_rows:
				if str(unowned.key) == str(low.key): matching = unowned; break
			var entry_level := COMBAT.entry_level(id)
			var expected_acquisition := minf(step * entry_level, float(low.cap))
			expect(not bool(matching.get("owned", true)), "unowned character contributes no live passive: " + id)
			expect(is_equal_approx(float(matching.get("acquisition_delta", -1)), expected_acquisition), "unowned acquisition preview is only the actual first unlock delta: %s/%s" % [id, low.key])
			var expected_upgrade := minf(expected_acquisition + step, float(low.cap)) - expected_acquisition
			expect(is_equal_approx(float(matching.get("next_delta", -1)), expected_upgrade), "unowned next-level preview assumes acquisition followed by one upgrade: %s/%s" % [id, low.key])
	var representative: Dictionary = {}
	for owner in rows:
		if not owner.get("bonuses_per_level", {}).is_empty(): representative = owner; break
	if not representative.is_empty():
		var id := str(representative.character_id)
		var key: String = representative.bonuses_per_level.keys()[0]
		var step := float(representative.bonuses_per_level[key])
		var cap := float(COMBAT.OWNED_CAPS[key])
		var near_level := maxi(1, int(floor((cap - step * .5) / step)))
		var near_data := {"owned":{id:{"level":near_level,"dead":false}}}
		var before := near_data.duplicate(true)
		var near_rows: Array[Dictionary] = DETAILS.owned_rows(near_data, id)
		var near: Dictionary = {}
		for value in near_rows:
			if str(value.key) == key: near = value; break
		expect(float(near.get("actual", INF)) <= cap and float(near.get("actual", -INF)) >= cap - step, "near-cap passive preview is bounded by the actual remaining capacity")
		expect(float(near.get("next_delta", INF)) >= 0 and float(near.get("next_delta", INF)) <= step, "near-cap next increment cannot exceed its per-level value")
		var over_level := int(ceil(cap / step)) + 2
		var over_rows: Array[Dictionary] = DETAILS.owned_rows({"owned":{id:{"level":over_level,"dead":false}}}, id)
		var over: Dictionary = {}
		for value in over_rows:
			if str(value.key) == key: over = value; break
		expect(is_equal_approx(float(over.get("actual", -1)), cap) and bool(over.get("capped", false)), "over-cap passive is clamped to its global stat cap")
		expect(is_zero_approx(float(over.get("next_delta", -1))), "over-cap upgrade yields zero actual increment")
		expect(near_data == before, "owned passive previews never mutate campaign input data")

func _ability_resources(definition: Dictionary) -> Dictionary:
	var result := {}
	var basic: Resource = definition.get("basic")
	if basic != null: result["basic:0"] = basic
	for slot in ["manual", "automatic"]:
		var list: Array = definition.get(slot, [])
		for index in list.size(): result["%s:%d" % [slot, index]] = list[index]
	var support: Resource = definition.get("support")
	if support != null: result["support:0"] = support
	return result

func verify_actor_load_and_dispatch() -> void:
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PLAN_PATH))
	var rows_by_owner := {}
	for row in plan.get("abilities", []):
		var id := str(row.character_id)
		if not rows_by_owner.has(id): rows_by_owner[id] = []
		rows_by_owner[id].append(row)
	expect(COMBAT.IDS.size() == 38 and rows_by_owner.size() == 38, "the roster oracle and actor catalog both cover 38 characters")
	for id in COMBAT.IDS:
		var packed: PackedScene = ART.actor(id)
		expect(packed != null, "ART resolves an actor scene: " + id)
		if packed == null: continue
		var visual := packed.instantiate() as Node2D
		expect(visual != null, "actor scene instantiates: " + id)
		if visual == null: continue
		root.add_child(visual)
		if not leak_trace_path.is_empty(): lifecycle_refs["actor:"+id]=weakref(visual)
		await process_frame
		expect(visual.has_method("set_moving"), "actor exposes shared locomotion adapter: " + id)
		expect(visual.has_method("present_cast"), "actor exposes shared successful-cast adapter: " + id)
		expect(visual.has_method("presentation_snapshot"), "actor exposes a read-only action snapshot: " + id)
		if visual.has_method("set_moving"): visual.call("set_moving", false, Vector2.RIGHT)
		_expect_manifest_foot_anchor(visual, id, "right")
		if visual.has_method("set_moving"): visual.call("set_moving", false, Vector2.LEFT)
		_expect_manifest_foot_anchor(visual, id, "left")
		var owned_rows: Array = rows_by_owner.get(id, [])
		if not owned_rows.is_empty() and visual.has_method("present_cast"):
			var row: Dictionary = owned_rows[0]
			var profile: Dictionary = PROFILE.profile(id, str(row.ability_id))
			var effect := _test_descriptor(id, str(row.ability_id), profile, 100000 + COMBAT.IDS.find(id))
			visual.call("present_cast", effect)
			var snapshot: Dictionary = visual.call("presentation_snapshot")
			expect(int(snapshot.get("successful_presentations", 0)) >= 1, "successful action is consumed once by actor controller: " + id)
			expect(str(snapshot.get("last_presentation_id", "")) == str(effect.presentation_id), "actor action snapshot identifies its presentation event: " + id)
			if id == "JIA":
				expect(str(snapshot.get("last_clip", "")).contains("dao"), "JIA standard blade selects its authored action clip")
		visual.queue_free()
		await process_frame
		actors_checked += 1

func _expect_manifest_foot_anchor(visual: Node2D, id: String, direction_name: String) -> void:
	var has_manifest := false
	for property: Dictionary in visual.get_property_list():
		if str(property.get("name", "")) == "manifest": has_manifest = true; break
	if not has_manifest: return
	var manifest: Dictionary = visual.get("manifest")
	if manifest.is_empty(): return
	var sprite: AnimatedSprite2D = visual.get("sprite") as AnimatedSprite2D
	if sprite == null: return
	var clip: Dictionary = manifest.get("clips", {}).get(str(sprite.animation), manifest.get("clips", {}).get("idle", {}))
	var frame_size: Array = clip.get("frame_size", [192,192])
	var anchor: Array = manifest.get("anchor_px", [96,176])
	var expected_x := float(frame_size[0]) * .5 - float(anchor[0])
	if sprite.flip_h: expected_x = -expected_x
	expect(absf(sprite.position.x - expected_x) < .01, "%s %s-facing sprite maps its manifested foot back to actor x=0" % [id, direction_name])

func _test_descriptor(source: String, ability: String, profile: Dictionary, presentation_id: int) -> Dictionary:
	return {"kind":"cast", "source":source, "ability":ability, "cast":presentation_id,
		"cast_id":presentation_id, "delivery":presentation_id, "presentation_id":presentation_id,
		"direct":true, "manual":true, "color":"manual", "origin":Vector2(100,100),
		"position":Vector2(100,100), "direction":Vector2.RIGHT, "profile":profile}

func verify_jia_weapon_variants() -> void:
	var visual: Node2D = ART.actor("JIA").instantiate()
	root.add_child(visual)
	await process_frame
	if not visual.has_method("presentation_snapshot") or not visual.has_method("present_cast") or not visual.has_method("set_weapon"):
		expect(false, "JIA exposes weapon, action, and read-only snapshot APIs")
		visual.queue_free(); return
	var initial: Dictionary = visual.call("presentation_snapshot")
	var base := _test_descriptor("JIA", "JIA_basic", PROFILE.profile("JIA", "JIA_basic"), 110001)
	visual.call("set_weapon", "plain_blade")
	visual.call("present_cast", base)
	var dao: Dictionary = visual.call("presentation_snapshot")
	var spear := _test_descriptor("JIA", "JIA_basic", PROFILE.profile("JIA", "JIA_basic", 1), 110002)
	visual.call("set_weapon", "long_spear")
	visual.call("present_cast", spear)
	var lance: Dictionary = visual.call("presentation_snapshot")
	expect(str(dao.get("last_clip", "")).contains("dao"), "JIA blade presentation uses dao clip")
	expect(str(lance.get("last_clip", "")).contains("spear"), "JIA spear presentation uses spear clip")
	expect(int(lance.get("successful_presentations", 0)) > int(initial.get("successful_presentations", 0)), "JIA weapon swap does not disable cast presentation")
	visual.queue_free()

func verify_failure_and_delivery_truth() -> void:
	var battle := _battle_fixture(["JIA", "F11"])
	var mage: RefCounted = battle.characters.F11
	var projectile: Resource = COMBAT.basic("F11", battle.equipment)
	mage.mp = mage.stats.mp
	var initial_mp: float = mage.mp
	var initial_cd: float = float(mage.cooldowns.get(projectile.id, 0.0))
	var fail_no_target: bool = battle._cast(projectile, mage, true)
	expect(not fail_no_target and is_equal_approx(mage.mp, initial_mp), "no-target projectile request fails without MP debit")
	expect(is_equal_approx(float(mage.cooldowns.get(projectile.id, 0.0)), initial_cd), "no-target projectile request starts no cooldown")
	expect(_count_event(battle.events, "ability_release") == 0, "no-target request emits no successful presentation release")
	battle.events.clear()
	var manual: Resource = COMBAT.definition("F11").manual[0]
	mage.mp = 0
	var fail_mp: bool = battle._cast(manual, mage, true, true)
	expect(not fail_mp and mage.mp == 0, "insufficient-MP manual request does not debit MP")
	expect(_count_event(battle.events, "ability_release") == 0, "insufficient-MP request emits no successful presentation release")
	battle.events.clear()
	mage.mp = mage.stats.mp
	mage.cooldowns[str(manual.id)] = 10
	var fail_cooldown: bool = battle._cast(manual, mage, true, true)
	expect(not fail_cooldown and _count_event(battle.events, "ability_release") == 0, "cooldown-blocked request emits no success presentation")
	var before: int = battle.delivery_serial
	var delivery_a: Dictionary = battle.delivery_context({"source":"F11", "ability":str(manual.id), "cast":700, "direct":true, "secondary":false})
	var delivery_b: Dictionary = battle.delivery_context({"source":"F11", "ability":str(manual.id), "cast":700, "direct":true, "secondary":true})
	expect(int(delivery_a.delivery) == before + 1 and int(delivery_b.delivery) == before + 2, "same-cast repeated deliveries keep distinct simulation delivery identities")
	expect(int(delivery_a.cast) == int(delivery_b.cast), "delivery identity does not replace original cast identity")
	if battle.has_method("add_presentation_effect"):
		battle.call("add_presentation_effect", {"kind":"delivery", "source":"F11", "ability":str(manual.id), "cast":700, "delivery":delivery_a.delivery, "origin":Vector2.ZERO, "position":Vector2.ZERO, "radius":12.0, "life":.4})
		battle.call("add_presentation_effect", {"kind":"delivery", "source":"F11", "ability":str(manual.id), "cast":700, "delivery":delivery_b.delivery, "origin":Vector2(10,0), "position":Vector2(10,0), "radius":12.0, "life":.4})
		var presentation_ids := {}
		for effect in battle.effects:
			if int(effect.get("cast", 0)) == 700: presentation_ids[int(effect.get("presentation_id", 0))] = true
		expect(presentation_ids.size() == 2 and not presentation_ids.has(0), "same-cast deliveries receive distinct presentation identities")
		var authored := AUTHORED.new()
		authored.sync(battle)
		expect(authored.skill.transients.size() == 2, "fact renderer retains both distinct deliveries from one cast")
	else:
		expect(false, "runtime exposes independent presentation effect insertion")
	var feedback := FEEDBACK.new()
	root.add_child(feedback)
	if not leak_trace_path.is_empty(): lifecycle_refs["feedback"]=weakref(feedback)
	await process_frame
	var old_muted: bool = SETTINGS.load_audio_muted()
	var old_skill_gain: float = SETTINGS.load_audio_volume("player_skill")
	var old_flash: bool = SETTINGS.comfort_enabled("reduced_flash")
	var old_motion: bool = SETTINGS.comfort_enabled("reduced_motion")
	SETTINGS.save_comfort("reduced_flash", true)
	SETTINGS.save_comfort("reduced_motion", true)
	feedback.refresh_settings()
	expect(feedback.reduced_flash and feedback.reduced_motion, "reduced-flash and reduced-motion settings reach the live feedback controller")
	var sounds_before: int = feedback.audio.counters.started
	SETTINGS.save_audio_volume("player_skill", 0.0)
	feedback._sound("magic", 4, 1.0)
	expect(feedback.audio.counters.started == sounds_before, "zero player-skill volume suppresses its sound category")
	SETTINGS.save_audio_muted(true)
	SETTINGS.save_audio_volume("player_skill", 1.0)
	feedback._sound("magic", 4, 1.0)
	expect(feedback.audio.counters.started == sounds_before, "master mute suppresses a skill sound")
	SETTINGS.save_audio_muted(old_muted)
	SETTINGS.save_audio_volume("player_skill", old_skill_gain)
	SETTINGS.save_comfort("reduced_flash", old_flash)
	SETTINGS.save_comfort("reduced_motion", old_motion)
	_watch_audio_release(feedback)
	feedback.queue_free()
	await process_frame

func verify_benefit_and_state_truth() -> void:
	var battle := _battle_fixture(["JIA", "F03", "F11"])
	var enemy: RefCounted = battle.director.spawn("E01", battle.position + Vector2(90,0))
	enemy.hp = 100000.0; enemy.max_hp = enemy.hp; enemy.speed = 0.0; enemy.cooldown = 9999.0
	battle.enemies.append(enemy)
	var jia: RefCounted = battle.characters.JIA
	var expose: Resource = COMBAT.definition("JIA").manual[1]
	jia.cooldowns[str(expose.id)] = 0.0
	expect(battle._cast(expose, jia, true, true), "real JIA expose skill succeeds in its target fixture")
	battle._resolve_hits()
	var expose_cast := int(battle.effects.back().get("cast", 0)) if not battle.effects.is_empty() else 0
	var exposed := false
	for state in battle.presentation_states():
		if str(state.get("kind", "")) == "expose" and int(state.get("target_id", -1)) == enemy.id and str(state.get("source", "")) == "JIA":
			exposed = float(state.get("remaining", 0)) > 0 and str(state.get("key", "")) == "expose:%d:JIA:%d" % [enemy.id, expose_cast]
	expect(exposed, "enemy status projection names the actual source, target, cast, and remaining duration")
	var before_life := 0.0
	for state in battle.presentation_states():
		if str(state.get("kind", "")) == "expose" and int(state.get("target_id", -1)) == enemy.id: before_life = float(state.remaining)
	battle.paused = true
	battle.tick(.5, Vector2.ZERO)
	var paused_life := 0.0
	for state in battle.presentation_states():
		if str(state.get("kind", "")) == "expose" and int(state.get("target_id", -1)) == enemy.id: paused_life = float(state.remaining)
	expect(is_equal_approx(before_life, paused_life), "real exposed status lifetime freezes during pause")
	battle.paused = false
	battle.tick(4.5, Vector2.ZERO)
	var ended := true
	for state in battle.presentation_states():
		if str(state.get("kind", "")) == "expose" and int(state.get("target_id", -1)) == enemy.id: ended = false
	expect(ended, "exposure snapshot disappears after the real status expires")

	var healer: RefCounted = battle.characters.F03
	var heal: Resource = COMBAT.definition("F03").manual[0]
	healer.hp = healer.stats.hp - 30.0
	healer.mp = healer.stats.mp
	healer.cooldowns[str(heal.id)] = 0.0
	battle.events.clear()
	expect(battle._cast(heal, healer, false, true), "real party heal succeeds for a damaged party member")
	var positive_benefit := false
	for event in battle.events:
		if str(event.get("kind", "")) == "ability_effect" and str(event.get("recipient", "")) == "F03" and float(event.get("hp_delta", 0)) > 0: positive_benefit = true
	expect(positive_benefit, "healing presentation fact identifies the real recipient and applied HP delta")
	var heal_delivery := -1
	for event in battle.events:
		if str(event.get("kind", "")) == "ability_effect" and str(event.get("recipient", "")) == "F03": heal_delivery = int(event.get("delivery", -1))
	battle.events.clear()
	healer.hp = healer.stats.hp
	healer.cooldowns[str(heal.id)] = 0.0
	expect(battle._cast(heal, healer, false, true), "capped heal request remains a valid cast")
	var false_heal := false
	for event in battle.events:
		if str(event.get("kind", "")) == "ability_effect" and str(event.get("recipient", "")) == "F03" and float(event.get("hp_delta", 0)) > 0: false_heal = true
	expect(not false_heal, "capped heal emits no false visual-benefit fact")
	if battle.has_method("add_presentation_fact"):
		expect(heal_delivery >= 0, "real healing fact preserves a simulation delivery id")
	else:
		expect(false, "runtime exposes stable presentation-fact identity without spending a delivery")
	battle._finish("failed")
	expect(battle.presentation_states().is_empty(), "terminal outcome detaches all active state snapshots")

func verify_pause_switch_and_cleanup() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	view = VIEW.new()
	var fixture := _view_request(["JIA", "F11", "F03"])
	view.setup(fixture.request, fixture.definitions)
	viewport.add_child(view)
	if not leak_trace_path.is_empty(): lifecycle_refs["view"]=weakref(view);lifecycle_refs["viewport"]=weakref(viewport)
	view.set_physics_process(false)
	await frames(3)
	var battle: RefCounted = view.battle
	var target := ENEMY.new(901, ENEMIES.definition("E01"), battle.position + Vector2(20,0))
	target.hp = 100000; target.max_hp = target.hp; target.speed = 0; target.cooldown = 9999
	battle.enemies.append(target)
	view.canvas.refresh(false)
	var jia: RefCounted = battle.characters.JIA
	var ability: Resource = COMBAT.definition("JIA").manual[0]
	jia.cooldowns[str(ability.id)] = 0.0
	expect(battle._cast(ability, jia, true, true), "real JIA manual cast succeeds in actual view fixture")
	var releases: int = _count_event(battle.events, "ability_release")	
	expect(releases == 1, "successful cast emits one release fact")
	view.canvas.consume_events(battle.events)
	_watch_audio_release(view.canvas.combat_feedback)
	battle.events.clear()
	view.canvas.refresh(false)
	var cast_snapshot: Dictionary = view.canvas.actor_visual.call("presentation_snapshot")
	expect(int(cast_snapshot.get("successful_presentations", 0)) == 1 and not str(cast_snapshot.get("last_presentation_id", "")).is_empty(), "actual paid JIA cast reaches the live actor once with presentation identity")
	var elapsed_before: float = battle.director.elapsed
	var visuals_before: int = view.canvas.authored_effects.transients.size()
	var skill_visuals_before: int = view.canvas.authored_effects.skill.transients.size()
	battle.paused = true
	for _i in 4: battle.tick(.25, Vector2.RIGHT)
	view.canvas.refresh(false)
	view.canvas.advance_presentation(.25)
	expect(is_equal_approx(battle.director.elapsed, elapsed_before), "paused simulation clock does not advance")
	expect(view.canvas.authored_effects.transients.size() == visuals_before, "paused cast visual lifetime freezes with battle time")
	expect(view.canvas.authored_effects.skill.transients.size() == skill_visuals_before, "new skill release/contact visuals freeze on the same paused clock")
	battle.paused = false
	battle.request_switch(1)
	battle.enemies.clear()
	battle.tick(0.0, Vector2.ZERO)
	view.canvas.refresh(false)
	var cast_identity := str(cast_snapshot.get("last_presentation_id", ""))
	var replayed := false
	for event in battle.events:
		if str(event.get("kind", "")) == "ability_release" and str(event.get("presentation_id", "")) == cast_identity: replayed = true
	expect(not replayed, "switching characters does not replay a prior cast event")
	for _i in 2:
		battle.switch_cooldown = 0.0
		battle.request_switch(1); battle.tick(0.0, Vector2.ZERO)
	view.canvas.refresh(false)
	var returned_snapshot: Dictionary = view.canvas.actor_visual.call("presentation_snapshot")
	expect(int(returned_snapshot.get("successful_presentations", 0)) == 0, "switching away and back does not replay a consumed cast on a fresh actor instance")
	expect(view.canvas.controlled_hurtbox().center == battle.position + CORE_FROM_FEET, "switch preserves the independent 72-unit core oracle")
	battle._finish("failed")
	view.canvas.refresh(false)
	view.canvas.advance_presentation(0.1)
	expect(view.canvas.authored_effects.transients.is_empty() and view.canvas.authored_effects.skill.transients.is_empty(), "terminal failure clears legacy and new skill presentation transients")
	expect(view.canvas.authored_effects.skill.states.is_empty(), "terminal failure clears projected status presentation states")
	view.canvas.combat_feedback.clear()
	view.canvas.authored_effects.clear()
	view.canvas.boss_feedback.clear()
	view.queue_free(); await frames(2); viewport.queue_free(); view = null; viewport = null; await frames(2)

func verify_hurtbox_contract() -> void:
	var foot := Vector2(137, 211)
	expect(is_equal_approx(SPACE.ACTOR_BODY_HEIGHT, 72.0), "standing actor reference body stays 72 world units")
	expect(HURTBOX.center(foot) == foot + CORE_FROM_FEET, "hurtbox center stays 36 world units above ground anchor")
	expect(is_equal_approx(HURTBOX.RADIUS, RADIUS), "hurtbox collision radius stays four world units")
	var bounds := {"shape":"disc", "origin":foot + CORE_FROM_FEET, "radius":0.0}
	expect(GEOMETRY.contains_actor(bounds, foot), "area point adapter accepts the fixed torso core")
	expect(not GEOMETRY.contains(bounds, foot), "raw geometry point remains feet-based and distinct from actor-core adapter")

func render_acceptance_scenes() -> void:
	# Three short, deterministic captures reuse real B01/B12/B18 catalog content.
	# The caller supplies --capture only after runtime assets and UI are frozen.
	await measure_b12_performance()
	for dimensions in [Vector2i(960,540), Vector2i(1280,720), Vector2i(1920,1080)]:
		# Current live battle, where available, is rendered at all requested view sizes.
		if view == null:
			await _mount_render_battle("B01", ["JIA", "F11", "F03"])
			_prepare_render_action("B01")
		await _resize_render_view(dimensions)
		await _capture("B01-JIA-%d" % dimensions.x, dimensions)
		await _dispose_render_battle()
		await _mount_render_battle("B12", ["JIA", "F06", "N07"])
		_prepare_render_action("B12")
		await _resize_render_view(dimensions)
		await _capture("B12-dense-%d" % dimensions.x, dimensions)
		await _dispose_render_battle()
		await _mount_render_battle("B18", ["JIA", "M01", "F03"])
		_prepare_render_action("B18")
		await _resize_render_view(dimensions)
		await _capture("B18-boss-%d" % dimensions.x, dimensions)
		await _dispose_render_battle()
	await create_timer(.35).timeout

func _prepare_render_action(stage: String) -> void:
	var battle: RefCounted = view.battle
	var actor_id := "JIA"
	var actor_index := 0
	var ability: Resource
	if stage == "B01":
		ability = COMBAT.definition("JIA").manual[0]
		for i in 1: spawn_target(battle, battle.position + Vector2(90 + i * 18, (i % 2) * 14))
	elif stage == "B12":
		actor_id = "F06"; actor_index = 1
		ability = COMBAT.definition(actor_id).manual[0]
		_add_b12_targets(battle)
	else:
		actor_id = "M01"; actor_index = 1
		ability = COMBAT.definition(actor_id).manual[0]
		var boss: RefCounted
		var boss_count := 0
		for enemy: RefCounted in battle.enemies:
			if enemy.rank == "boss": boss = enemy; boss_count += 1
		expect(boss_count == 1, "B18 boss-duel fixture uses its single stage-authored Boss")
		if boss != null:
			boss.position = battle.position + Vector2(220,-70)
			boss.hp = boss.max_hp * .7
	battle.active = actor_index
	view.refresh()
	view._layout_hud()
	view.canvas.refresh(false)
	var actor: RefCounted = battle.characters[actor_id]
	actor.mp = actor.stats.mp
	actor.cooldowns[str(ability.id)] = 0.0
	var succeeded: bool = battle._cast(ability, actor, true, true)
	expect(succeeded, "%s representative QA skill succeeds in %s fixture" % [str(ability.id), stage])
	battle._resolve_hits()
	view.canvas.consume_events(battle.events)
	_watch_audio_release(view.canvas.combat_feedback)
	battle.events.clear()
	view.refresh()
	view._layout_hud()
	view.canvas.refresh(false)
	_assert_hud_matches_current(stage)

func _assert_hud_matches_current(stage: String) -> void:
	var active_index: int = view.battle.active
	var active_id: String = view.battle.current().id
	var presentation: Control = view.hud.presentation
	var properties := _property_names(presentation)
	var entries: Array = presentation.get("members") if properties.has("members") else presentation.get("rows") if properties.has("rows") else []
	expect(active_index >= 0 and active_index < entries.size(), "%s HUD exposes the active party row" % stage)
	if active_index < 0 or active_index >= entries.size(): return
	var entry: Dictionary = entries[active_index]
	var portrait: Control = entry.get("portrait") as Control
	var displayed_id := str(portrait.get("role_id")) if portrait != null else ""
	expect(displayed_id == active_id, "%s HUD active portrait matches battle.current() (%s)" % [stage, active_id])
	var expected_name := str(view.definitions[active_id].get("name", active_id))
	var visible_name := ""
	var visible_skills: Array[String] = []
	if properties.has("actor_name"):
		var actor_name: Label = presentation.get("actor_name") as Label
		if actor_name != null: visible_name = actor_name.text
		expect(actor_name != null and actor_name.text.contains(expected_name), "%s HUD actor name matches battle.current() (%s)" % [stage, active_id])
		var skill_slots: Array = presentation.get("skills")
		var manuals: Array = COMBAT.definition(active_id).manual
		for index in mini(2, manuals.size()):
			var slot: Dictionary = skill_slots[index]
			var title: Label = slot.get("title") as Label
			if title != null: visible_skills.append(title.text)
			expect(title != null and title.text == str(manuals[index].title), "%s HUD manual skill %d matches active actor %s" % [stage, index, active_id])
	else:
		var slots: Array = entry.get("slots", [])
		var manuals: Array = COMBAT.definition(active_id).manual
		for index in mini(2, manuals.size()):
			var slot: Dictionary = slots[index + 2]
			var title: Label = slot.get("label") as Label
			if title != null: visible_skills.append(title.text)
			expect(title != null and title.text.begins_with(str(manuals[index].title)), "%s HUD manual skill %d matches active actor %s" % [stage, index, active_id])
	hud_snapshot = {"battle_current_id":active_id, "active_portrait_role_id":displayed_id,
		"actor_name_label":visible_name, "manual_skill_labels":visible_skills}

func _property_names(object: Object) -> Array[String]:
	var names: Array[String] = []
	for property: Dictionary in object.get_property_list(): names.append(str(property.get("name", "")))
	return names

func measure_b12_performance() -> void:
	# Same seed, stage, three actors and twelve stationary targets. The first sample
	# measures the normal scene; the second measures one real dense F06 release and
	# its confirmed delivery visuals. This is a local fixture measurement, not a
	# cross-machine or before/after build benchmark.
	await _mount_render_battle("B12", ["JIA", "F06", "N07"])
	_add_b12_targets(view.battle)
	view.canvas.refresh(false)
	await frames(30)
	performance_samples.append(await _sample_live_frames("B12-default", 120))
	await _dispose_render_battle()
	await _mount_render_battle("B12", ["JIA", "F06", "N07"])
	_prepare_render_action("B12")
	await frames(2)
	performance_samples.append(await _sample_live_frames("B12-one-real-dense-release", 120))
	await _dispose_render_battle()

func _dispose_render_battle() -> void:
	if view != null:
		_watch_audio_release(view.canvas.combat_feedback)
		view.canvas.combat_feedback.clear()
		view.canvas.authored_effects.clear()
		view.canvas.boss_feedback.clear()
		view.queue_free()
	await frames(2)
	if viewport != null: viewport.queue_free()
	view = null
	viewport = null
	await frames(4)
	await RenderingServer.frame_post_draw

func _add_b12_targets(battle: RefCounted) -> void:
	for i in 12:
		var angle := TAU * float(i) / 12.0
		spawn_target(battle, battle.position + Vector2.from_angle(angle) * (72.0 + float(i % 3) * 16.0))

func _sample_live_frames(label: String, sample_count: int) -> Dictionary:
	var wall_samples: Array[float] = []
	var update_cpu_samples: Array[float] = []
	var peak_transients := 0
	var peak_states := 0
	var previous_usec := Time.get_ticks_usec()
	for _i in sample_count:
		await process_frame
		var now_usec := Time.get_ticks_usec()
		wall_samples.append(float(now_usec - previous_usec) / 1000.0)
		previous_usec = now_usec
		var update_start_usec := Time.get_ticks_usec()
		if view != null:
			view.canvas.advance_presentation(1.0 / 60.0)
			view.canvas.refresh(false)
			peak_transients = maxi(peak_transients, view.canvas.authored_effects.skill.transients.size())
			peak_states = maxi(peak_states, view.canvas.authored_effects.skill.states.size())
		update_cpu_samples.append(float(Time.get_ticks_usec() - update_start_usec) / 1000.0)
	wall_samples.sort()
	update_cpu_samples.sort()
	return {"label":label, "frames":sample_count, "wall_frame_ms":{"median":_percentile(wall_samples,.5),"p95":_percentile(wall_samples,.95),"max":wall_samples.back() if not wall_samples.is_empty() else 0.0},
		"qa_view_update_cpu_ms":{"median":_percentile(update_cpu_samples,.5),"p95":_percentile(update_cpu_samples,.95),"max":update_cpu_samples.back() if not update_cpu_samples.is_empty() else 0.0},
		"peak_skill_transients":peak_transients, "peak_skill_states":peak_states}

func _percentile(sorted_values: Array[float], fraction: float) -> float:
	if sorted_values.is_empty(): return 0.0
	return sorted_values[mini(sorted_values.size() - 1, int(ceil(float(sorted_values.size() - 1) * fraction)))]

func spawn_target(battle: RefCounted, position: Vector2) -> RefCounted:
	var enemy: RefCounted = battle.director.spawn("E01", position)
	enemy.hp = 100000.0; enemy.max_hp = enemy.hp; enemy.speed = 0.0; enemy.cooldown = 9999.0
	battle.enemies.append(enemy)
	return enemy

func _mount_render_battle(stage: String, members: Array) -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	view = VIEW.new()
	var fixture := _view_request(members, stage)
	view.setup(fixture.request, fixture.definitions)
	viewport.add_child(view)
	view.set_physics_process(false)
	await frames(3)
	view.battle.director.spawn_remaining = 10000.0
	view.battle.director.config.boss_time = 100000.0
	view.battle.director.config.boss_kills = 100000
	view.canvas.refresh(false)

func _resize_render_view(dimensions: Vector2i) -> void:
	# Resizing the SubViewport first lets anchored HUD controls receive the new
	# parent bounds before the root Control and nested containers are captured.
	viewport.size = dimensions
	await frames(1)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await frames(3)
	var view_rect := view.get_rect()
	expect(view_rect.position == Vector2.ZERO and view_rect.size.distance_to(Vector2(dimensions)) < .1,
		"render fixture root Control exactly fills its %s SubViewport" % str(dimensions))
	view.canvas.refresh(false)

func _capture(name: String, dimensions: Vector2i) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	var marker: Dictionary = view.canvas.controlled_hurtbox()
	expect(marker.visible and marker.center == view.battle.position + CORE_FROM_FEET and is_equal_approx(float(marker.radius), RADIUS), "rendered %s retains fixed red danger core at %s" % [name, str(dimensions)])
	var actual_boss_count := 0
	for enemy: RefCounted in view.battle.enemies:
		if enemy.rank == "boss": actual_boss_count += 1
	var bottom_band: Control = view.hud.presentation.get("band") as Control if view.hud != null and view.hud.presentation != null else null
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(dimensions))
	var bottom_hud_visible := bottom_band != null and bottom_band.is_visible_in_tree() and viewport_rect.encloses(bottom_band.get_global_rect())
	expect(bottom_hud_visible, "rendered %s retains the full in-viewport bottom party HUD at %s" % [name, str(dimensions)])
	if name.begins_with("B18-"): expect(actual_boss_count == 1, "rendered %s contains exactly one stage-authored Boss" % name)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var filename := name + ".png"
	var image := viewport.get_texture().get_image()
	var saved := image.save_png(capture_dir.path_join(filename)) == OK
	image = null
	expect(saved, "real rendered QA capture saved: " + filename)
	captures.append({"name":name, "viewport":[dimensions.x, dimensions.y], "boss_count":actual_boss_count,
		"bottom_hud_visible":bottom_hud_visible, "hud":hud_snapshot.duplicate(true),
		"path":capture_dir.get_file().path_join(filename)})

func _view_request(members: Array, stage: String = "B01") -> Dictionary:
	var definitions := {}
	for person in JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/characters.json")):
		definitions[str(person.id)] = person
	var records := {}
	for id in members: records[id] = COMBAT.record(str(id), 10)
	if not records.has("JIA"): records["JIA"] = COMBAT.record("JIA", 10)
	var request := {"attempt_id":"skill-presentation-qa", "members":members.duplicate(), "characters":records,
		"equipment":{"weapon":"plain_blade", "armor":"cloth_armor", "accessory":""},
		"stage":COMBAT.stage(stage), "seed":20261105, "node":{"id":stage, "name":"技能表现验收"}}
	return {"request":request, "definitions":definitions}

func _battle_fixture(members: Array) -> RefCounted:
	var fixture := _view_request(members)
	var battle: RefCounted = BATTLE.new(fixture.request)
	battle.director.spawn_remaining = 10000.0
	battle.director.config.boss_time = 100000.0
	battle.director.config.boss_kills = 100000
	return battle

func _count_event(events: Array, kind: String) -> int:
	var count := 0
	for event in events:
		if str(event.get("kind", "")) == kind: count += 1
	return count

func _finish() -> void:
	_lifecycle_trace("finish-deferred")
	await _await_audio_release()
	var report := {"schema_version":1, "checks":checks, "failures":failures,
		"ability_rows_checked":ability_rows_checked, "actors_checked":actors_checked,
		"captures":captures, "performance_samples":performance_samples, "failure_details":failures_by_test, "audio_teardown":audio_teardown,
		"user_data_isolated":ProjectSettings.globalize_path("user://").begins_with("/tmp/")}
	var destination := report_path if not report_path.is_empty() else "design/skill-presentation-20261105/qa/skill-presentation-results.json"
	var absolute := ProjectSettings.globalize_path(destination) if destination.begins_with("user://") or destination.begins_with("res://") else ProjectSettings.globalize_path("res://" + destination.trim_prefix("./"))
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	file = null
	print("CHRONICLE_SKILL_PRESENTATION_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures, " abilities=", ability_rows_checked, " actors=", actors_checked, " captures=", captures.size())
	# This callback must return as well: neither the run coroutine nor its report
	# FileAccess should remain on the shutdown stack. No arbitrary drain timeout.
	call_deferred("_quit_after_report")

func _quit_after_report() -> void:
	_lifecycle_trace("quit-deferred")
	quit(1 if failures else 0)

# Optional diagnostics are weak observations and never keep fixture nodes alive.
func _lifecycle_trace(stage: String) -> void:
	if leak_trace_path.is_empty(): return
	var alive: Dictionary={}
	for key in lifecycle_refs:
		var object: Object=lifecycle_refs[key].get_ref()
		if object!=null: alive[key]={"id":object.get_instance_id(),"class":object.get_class()}
	leak_trace.append({"stage":stage,"stack":get_stack(),"script_refcount":get_script().get_reference_count(),"live_fixture_nodes":alive,"root_child_count":root.get_child_count(),"orphan_nodes":Node.get_orphan_node_ids(),"object_count":Performance.get_monitor(Performance.OBJECT_COUNT),"resource_count":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)})
	var file:=FileAccess.open(leak_trace_path,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(leak_trace,"  "));file.close()

# AudioStreamPlayer.stop() queues the real-time mixer removal; a queued-free Node
# disappearing does not prove the AudioServer has dropped its playback Resource.
# Keep only weak references, sampled while the actual test sound is playing.
func _watch_audio_release(feedback: Node) -> void:
	if feedback==null: return
	for voice: AudioStreamPlayer in feedback.voices:
		if voice.stream!=null:
			audio_refs[voice.stream.get_instance_id()]={"weak":weakref(voice.stream),"class":voice.stream.get_class(),"path":voice.stream.resource_path}
		if voice.has_stream_playback():
			var playback:=voice.get_stream_playback()
			audio_refs[playback.get_instance_id()]={"weak":weakref(playback),"class":playback.get_class(),"path":""}

func _live_audio_refs() -> Array[Dictionary]:
	var live: Array[Dictionary]=[]
	for id in audio_refs:
		var record: Dictionary=audio_refs[id]
		if record.weak.get_ref()!=null: live.append({"id":id,"class":record["class"],"path":record.path})
	return live

func _await_audio_release() -> void:
	var started:=Time.get_ticks_usec()
	var initial:=_live_audio_refs()
	var mix_before:=AudioServer.get_time_since_last_mix()
	while not _live_audio_refs().is_empty() and Time.get_ticks_usec()-started<1000000:
		# Wait for the next *actual audio mix*, then observe the same weak refs.
		# A timeout is a test error, not permission to ignore a shutdown warning.
		await create_timer(maxf(.001,AudioServer.get_time_to_next_mix()+.001),true,false,true).timeout
	var remaining:=_live_audio_refs()
	audio_teardown={"watched_objects":audio_refs.size(),"initial_live":initial,"remaining_live":remaining,"wait_usec":Time.get_ticks_usec()-started,"mix_age_before":mix_before,"mix_age_after":AudioServer.get_time_since_last_mix(),"condition":"all actual test WAV/playback weakrefs released; no extra sound or assertion suppressed"}
	if not remaining.is_empty():
		failures+=1
		var message:="AudioServer fixture playback resources did not release within one second: "+JSON.stringify(remaining)
		failures_by_test.append(message);push_error(message)

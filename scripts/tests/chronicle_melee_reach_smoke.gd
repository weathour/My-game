extends SceneTree
## Cast eligibility shares the existing melee impact shape; no timing or stat overrides in production.
const B := preload("res://scripts/battle/battle_session.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const A := preload("res://scripts/battle/ability_definition.gd")
const E := preload("res://scripts/battle/enemy_runtime.gd")
var checks := 0
var failures := 0

func _init() -> void: call_deferred("run")

func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func fixture(ids: Array = ["JIA"]) -> RefCounted:
	var records := {}
	for id in ids: records[id] = C.record(id, 20)
	var stage := C.stage("B01")
	stage.boss_time = 10000.0
	stage.boss_kills = 10000
	var b := B.new({"attempt_id":"reach", "members":ids, "characters":records, "equipment":{}, "stage":stage, "seed":1701})
	b.director.spawn_remaining = 10000.0
	return b

func enemy(b: RefCounted, point: Vector2, radius: float = 13) -> RefCounted:
	var value := E.new(b.enemies.size() + 1, "melee", b.position + point)
	value.radius = radius
	value.hp = 100000
	value.max_hp = value.hp
	value.speed = 0
	value.cooldown = 10000
	b.enemies.append(value)
	return value

func damage_rows(b: RefCounted) -> Array:
	return b.events.filter(func(event: Dictionary) -> bool: return event.kind == "damage_dealt")

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated XDG required")
	if failures: quit(1); return
	shape_boundaries()
	mixed_radii_and_stickiness()
	authored_melee_coverage()
	weapon_support_manual()
	other_kinds_unchanged()
	print("CHRONICLE_MELEE_REACH_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)

func shape_boundaries() -> void:
	for kind in [A.Kind.SWEEP, A.Kind.THRUST]:
		for offset in [-0.01, 0.0, 0.01]:
			var b := fixture()
			var e := enemy(b, Vector2(125 + offset, 0))
			var ability := A.make("reach_probe", "reach", kind, 1, 112, 5)
			var activated: bool = b._cast(ability, b.current(), true)
			expect(activated == (offset <= 0), "shape boundary eligibility kind=%s offset=%s" % [kind, offset])
			b._resolve_hits()
			expect((damage_rows(b).size() == 1) == activated, "eligible contact resolves in the same call without double radius")
			if activated: expect(e.hp < e.max_hp and b.current().cooldowns.reach_probe == 5, "actual contact retains original damage and cooldown")
			else: expect(not b.current().cooldowns.has("reach_probe"), "unreachable enemy cannot spend cooldown")
	# A large radius must not double into reach+2r.
	var outside := fixture()
	enemy(outside, Vector2(130, 0), 13)
	expect(not outside._cast(C.basic("JIA", {}), outside.current(), true), "near miss inside reach+2r stays unreachable")

func mixed_radii_and_stickiness() -> void:
	var b := fixture()
	var small := enemy(b, Vector2(-120, 0), 3)
	var large := enemy(b, Vector2(150, 0), 40)
	b.target_id = small.id
	expect(b._cast(C.basic("JIA", {}), b.current(), true), "large body can intersect reach while a closer small body remains outside")
	b._resolve_hits()
	var hits := damage_rows(b)
	expect(hits.size() == 1 and hits[0].enemy_id == large.id and small.hp == small.max_hp, "each candidate uses its own radius and unreachable old target cannot stick")
	for nearer_x in [-100.0, -70.0]:
		var sticky := fixture()
		var held := enemy(sticky, Vector2(115, 0), 13)
		var nearer := enemy(sticky, Vector2(nearer_x, 0), 13)
		sticky.target_id = held.id
		expect(sticky._cast(C.basic("JIA", {}), sticky.current(), true), "sticky-target fixture casts")
		var cast: Dictionary = sticky.events[0]
		expect(cast.direction.x == (1 if nearer_x == -100 else -1), "existing center-distance stickiness threshold is preserved")
		sticky._resolve_hits()
		var expected_id: int = held.id if nearer_x == -100 else nearer.id
		expect(damage_rows(sticky).size() == 1 and damage_rows(sticky)[0].enemy_id == expected_id, "aimed contact agrees with selected sticky target")
	var excluded := fixture()
	var dead := enemy(excluded, Vector2(110, 0))
	dead.dead = true
	var untargetable := enemy(excluded, Vector2(110, 10))
	untargetable.targetable = false
	expect(not excluded._cast(C.basic("JIA", {}), excluded.current(), true), "dead and untargetable bodies cannot trigger an attack")

func authored_melee_coverage() -> void:
	var count := 0
	var kinds := {"basic":0, "manual":0, "support":0, "automatic":0}
	for id in C.IDS:
		var definition: Dictionary = C.definition(id)
		var groups := {"basic":[definition.basic], "manual":definition.manual, "automatic":definition.automatic,
			"support":[] if definition.support == null else [definition.support]}
		for group in groups:
			for ability in groups[group]:
				if ability.kind not in [A.Kind.SWEEP, A.Kind.THRUST]: continue
				count += 1
				kinds[group] += 1
				for offset in [0.0, 0.01]:
					var ids: Array = ["JIA"] if id == "JIA" else ["JIA", id]
					var b := fixture(ids)
					if group != "support": b.active = ids.find(id)
					var source: RefCounted = b.characters[id]
					source.mp = 100000
					var reach: float = b.mechanics.query_reach(ability, source, group != "support")
					enemy(b, Vector2(reach + 13 + offset, 0))
					var cast: bool = b._cast(ability, source, group != "support", group == "manual")
					expect(cast == (offset == 0), "authored %s %s per-body boundary offset=%s" % [group, ability.id, offset])
	expect(count == 56 and kinds.basic == 24 and kinds.manual == 18 and kinds.support == 14 and kinds.automatic == 0, "all 56 authored melee-shaped casts are covered")

func weapon_support_manual() -> void:
	var spear := fixture()
	spear.equipment.weapon = "long_spear"
	var spear_enemy := enemy(spear, Vector2(193, 0))
	expect(spear._cast(C.basic("JIA", spear.equipment), spear.current(), true), "long-spear replacement uses its actual 180 reach plus radius")
	spear._resolve_hits()
	expect(damage_rows(spear).size() == 1 and damage_rows(spear)[0].enemy_id == spear_enemy.id, "long spear retains narrow real contact")
	var support := fixture(["JIA", "N01"])
	var skill: Resource = C.definition("N01").support
	var support_enemy := enemy(support, Vector2(skill.reach + 13, 0))
	expect(support._cast(skill, support.characters.N01, false), "background melee can reach a body edge")
	support._resolve_hits()
	var support_hits := damage_rows(support)
	expect(support_hits.size() == 1, "background body-edge contact deals damage")
	if support_hits.size() == 1:
		var row: Dictionary = support_hits[0]
		expect(row.source == "N01" and not row.direct and row.enemy_id == support_enemy.id, "background contact preserves source and direct attribution")
	var manual := fixture()
	var ability: Resource = C.definition("JIA").manual[1]
	enemy(manual, Vector2(ability.reach + 13, 0))
	var mana: float = manual.current().mp
	expect(manual._cast(ability, manual.current(), true, true), "manual thrust uses identical body-edge eligibility")
	manual._resolve_hits()
	expect(damage_rows(manual).size() == 1 and manual.current().mp == mana - ability.mana_cost and manual.current().cooldowns.jia_break == ability.cooldown, "manual hit preserves original payment, cooldown and damage resolution")
	var tempered := fixture()
	tempered.mechanics.states.JIA.windows.temper = {"reach_bonus":50.0, "owner":"JIA", "attack":0.0, "spark_scale":0.0}
	enemy(tempered, Vector2(175, 0))
	expect(tempered._cast(C.basic("JIA", {}), tempered.current(), true), "existing temper reach is queried once alongside receiver radius")
	tempered._resolve_hits()
	expect(damage_rows(tempered).size() == 1, "prepared temper impact agrees with extended eligibility")

func other_kinds_unchanged() -> void:
	var projectile := fixture(["JIA", "F11"])
	projectile.active = 1
	var ability: Resource = C.basic("F11", {})
	enemy(projectile, Vector2(ability.reach + 10, 0), 40)
	expect(not projectile._cast(ability, projectile.current(), true), "projectile keeps center-distance launch range")
	var nova := fixture()
	var mana: float = nova.current().mp
	var sweep: Resource = C.definition("JIA").manual[0]
	expect(nova._cast(sweep, nova.current(), true, true) and nova.current().mp == mana - sweep.mana_cost, "NOVA keeps existing no-target activation/payment")
	nova._resolve_hits()
	expect(damage_rows(nova).is_empty(), "empty NOVA does not invent contact")

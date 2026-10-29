extends RefCounted
var definition_id := ""
var behavior_id := ""
var elite_rule_id := ""
var visual_id := ""
var rank := "ordinary"
var reward_tag := ""
var parent_id := 0
var hp_owner_id := 0
var hp_owner: RefCounted
var targetable := true
var counts_for_threshold := true
var death_reason := ""
var body_height := 64.0
var state := "approach"
var active_remaining := 0.0
var active_total := 0.0
var active_hit := false
var guard_active := true
var action_serial := 0
var telegraph: Dictionary = {}
var definition: Dictionary = {}
var actions: Array = []
var current_action: Dictionary = {}
var params: Dictionary = {}
var spawned_total := 0
var initialized := false
var anchor_position := Vector2.ZERO
var healing_received := 0.0
var rule_cooldown := 0.0
var protection_remaining := 0.0
var command_remaining := 0.0
var form_index := 0
var form_count := 1
var form_name := ""
var forms: Array = []
var encounter_max_hp := 0.0
var transition_remaining := 0.0
var observation_remaining := 0.0
var phase_damage_bank := 0.0
var phase_change_pending := false
var phase := 0
var age := 0.0
var id := 0
var kind := "melee"
var position := Vector2.ZERO
var hp := 40.0
var max_hp := 40.0
var radius := 14.0
var speed := 65.0
var damage := 12.0
var xp := 3.0
var dead := false
var slow := 0.0
var slow_time := 0.0
var cooldown := 1.0
var windup := 0.0
var aim := Vector2.RIGHT
var attack := ""
var attack_index := 0
var flash := 0.0
var attack_cycle: Array = ["strike"]
var attack_range := 46.0
var attack_delay := 0.4
var recovery := 1.25
var blast_radius := 145.0

func _init(key: int, type: String, point: Vector2) -> void:
	id = key
	hp_owner_id = key
	anchor_position = point
	kind = type
	position = point
	if type == "ranged": hp = 32; speed = 46; damage = 13; xp = 4
	if type in ["card_elite", "equipment_elite"]: hp = 280; radius = 23; speed = 72; damage = 23; xp = 18
	if type == "boss": hp = 550; radius = 30; speed = 53; damage = 30; xp = 30
	if type == "charger": hp = 62; radius = 16; speed = 92; damage = 17; xp = 5
	if type == "guard": hp = 105; radius = 19; speed = 43; damage = 18; xp = 6
	attack_range = radius + 32
	if type in ["card_elite", "equipment_elite", "guard"]: recovery = 2.2
	if type == "ranged": attack_cycle = ["shot"]; attack_range = 310; attack_delay = .65; recovery = 2.2
	if type == "charger": attack_cycle = ["charge"]; attack_range = 270; attack_delay = .8; recovery = 2.4
	if type == "boss": attack_cycle = ["charge", "fan"]; attack_range = 310; attack_delay = .95; recovery = 2.2
	max_hp = hp

func configure(value: Dictionary) -> void:
	if value.is_empty(): return
	definition = value.duplicate(true)
	definition_id = str(value.get("id", ""))
	behavior_id = str(value.get("behavior_id", definition_id))
	visual_id = str(value.get("visual_id", definition_id))
	elite_rule_id = str(value.get("elite_rule_id", ""))
	rank = str(value.get("rank", "ordinary"))
	for key in ["hp", "damage", "speed", "radius", "xp", "body_height"]:
		if value.has(key): set(key, float(value[key]))
	max_hp = hp
	params = value.get("params", {}).duplicate(true)
	targetable = bool(params.get("targetable", true))
	counts_for_threshold = bool(params.get("counts_for_threshold", counts_for_threshold))
	actions = value.get("attacks", []).duplicate(true)
	if rank in ["object", "proxy"]: counts_for_threshold = false; xp = 0
	if rank == "boss": kind = "boss"; counts_for_threshold = false
	if rank == "field_elite": counts_for_threshold = false
	forms = value.get("forms", []).duplicate(true)
	form_count = maxi(1, forms.size())
	if not forms.is_empty(): configure_form_budget(max_hp)

func damage_owner() -> RefCounted:
	return hp_owner if hp_owner != null else self

func configure_form_budget(total_hp: float) -> void:
	encounter_max_hp = total_hp
	if forms.is_empty():
		hp = total_hp; max_hp = total_hp
		return
	_apply_form(form_index)

func _apply_form(index: int) -> void:
	form_index = index
	phase = index
	var value: Dictionary = forms[index]
	form_name = str(value.name)
	visual_id = definition_id + ("_human" if index == 0 else "")
	body_height = float(value.body_height)
	radius = float(value.radius)
	speed = float(value.speed)
	actions = value.attacks.duplicate(true)
	var fraction := float(params.get("phase_hp_fraction", 0.4))
	max_hp = encounter_max_hp * (fraction if index == 0 else 1.0 - fraction)
	hp = max_hp
	attack_index = 0

## All already-calculated damage, including curse pools, crosses the form boundary.
## The bounded observation window preserves a visible second form for burst teams.
func receive_damage(amount: float) -> void:
	if transition_remaining > 0 or observation_remaining > 0:
		phase_damage_bank += maxf(0, amount)
		return
	var remainder := maxf(0, amount - hp)
	hp = maxf(0, hp - amount)
	if hp > 0: return
	if form_index + 1 < form_count:
		_apply_form(form_index + 1)
		phase_damage_bank += remainder
		transition_remaining = float(params.get("transition_duration", 1.0))
		observation_remaining = float(params.get("phase_observation_duration", 0.65))
		phase_change_pending = true
		windup = 0; active_remaining = 0; active_total = 0
		telegraph.clear(); current_action.clear(); attack = ""
		state = "transition"; cooldown = 0
		# Old slows still expire naturally; they do not pause the transformation.
	else:
		dead = true

func advance_form(delta: float) -> bool:
	var safe_step := transition_remaining > 0
	if safe_step:
		var safe_time := minf(delta, transition_remaining)
		transition_remaining = maxf(0, transition_remaining - safe_time)
		delta = maxf(0, delta - safe_time)
		if transition_remaining < 0.000001: transition_remaining = 0
		state = "transition"
		if transition_remaining > 0: return true
	if observation_remaining > 0:
		observation_remaining = maxf(0, observation_remaining - delta)
		if observation_remaining < 0.000001: observation_remaining = 0
		if observation_remaining <= 0 and phase_damage_bank > 0:
			var bank := phase_damage_bank
			phase_damage_bank = 0
			receive_damage(bank)
	return dead or safe_step

func remaining_health_budget() -> float:
	var future := encounter_max_hp * (1.0 - float(params.get("phase_hp_fraction", 0.4))) if form_count > 1 and form_index == 0 else 0.0
	return maxf(0, hp + future - phase_damage_bank)

extends RefCounted


static func spawn_pulsing_field(owner, center: Vector2, radius: float, color: Color, pulse_count: int, interval: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	var safe_pulse_count: int = max(1, pulse_count)
	if owner.has_method("_schedule_repeating_sequence"):
		owner._schedule_repeating_sequence(max(0.0, interval), safe_pulse_count, func(_index: int) -> void:
			if is_instance_valid(owner):
				trigger_field_pulse(owner, center, radius, color, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration)
		)
		return
	for pulse_index in range(safe_pulse_count):
		trigger_field_pulse(owner, center, radius, color, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration)


static func trigger_field_pulse(owner, center: Vector2, radius: float, color: Color, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float) -> void:
	owner._spawn_ring_effect(center, radius, Color(color.r, color.g, color.b, min(0.9, color.a + 0.35)), 6.0, 0.18)
	owner._spawn_burst_effect(center, radius, color, 0.18)
	if slow_duration > 0.0:
		owner._spawn_frost_sigils_effect(center, max(18.0, radius * 0.58), Color(0.84, 0.98, 1.0, 0.72), 0.18)
	owner._damage_enemies_in_radius(center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration)

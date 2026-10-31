extends RefCounted
## Pure draft generation. The caller persists the concrete candidates before showing them.
static func draft(node: String, pool: Array, definitions: Dictionary, extra: bool, rng: RandomNumberGenerator) -> Dictionary:
	var final := node == "B18"
	var count := 7 if final else 5
	var shuffled: Array = []
	for id in pool:
		if id not in shuffled and definitions.has(id): shuffled.append(id)
	for i in range(shuffled.size() - 1, 0, -1):
		var other := rng.randi_range(0, i)
		var value: Variant = shuffled[i]
		shuffled[i] = shuffled[other]
		shuffled[other] = value
	if shuffled.size() < count: return {}
	var candidates: Array = []
	if final:
		for id in shuffled:
			if definitions[id].kind == "重要人物" and candidates.size() < 2: candidates.append(id)
		if candidates.size() < 2: return {}
	for id in shuffled:
		if candidates.size() == count: break
		if id not in candidates: candidates.append(id)
	return {"node":node, "candidates":candidates, "selected":[], "picks":(3 if final else 2) + int(extra), "extra":extra}

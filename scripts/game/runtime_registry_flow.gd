extends RefCounted


static func is_runtime_node_valid(node: Variant) -> bool:
	if node == null:
		return false
	if not is_instance_valid(node):
		return false
	var typed_node := node as Node
	if typed_node == null:
		return false
	return not typed_node.is_queued_for_deletion()


static func rebuild_runtime_registry_cache(registry: Dictionary) -> Array:
	var cache: Array = []
	var stale_ids: Array = []
	for instance_id in registry.keys():
		var node = registry[instance_id]
		if is_runtime_node_valid(node):
			cache.append(node)
		else:
			stale_ids.append(instance_id)
	for instance_id in stale_ids:
		registry.erase(instance_id)
	return cache

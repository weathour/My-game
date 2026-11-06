extends "./b17_dense_bench.gd"
## QA server retirement only, outside every timed/scored scenario. The original
## two measured fixture files remain byte-identical for all compared PCKs.
func _reset_view() -> void:
	await super._reset_view()
	await create_timer(.3).timeout
	await _frames(2)

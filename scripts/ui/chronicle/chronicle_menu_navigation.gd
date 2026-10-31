extends RefCounted
## Directional focus follows rows/columns; Tab follows the visible reading order.
static func wire(rows: Array) -> void:
	var ordered: Array[Button] = []
	for row in rows:
		for button in row:
			if _enabled(button): ordered.append(button)
	if ordered.is_empty(): return
	for index in ordered.size():
		var button := ordered[index]
		button.focus_next = button.get_path_to(ordered[(index + 1) % ordered.size()])
		button.focus_previous = button.get_path_to(ordered[posmod(index - 1, ordered.size())])
	for y in rows.size():
		var row: Array = rows[y]
		for x in row.size():
			var button: Variant = row[x]
			if not _enabled(button): continue
			button.focus_neighbor_left = button.get_path_to(_horizontal(row, x, -1))
			button.focus_neighbor_right = button.get_path_to(_horizontal(row, x, 1))
			button.focus_neighbor_top = button.get_path_to(_vertical(rows, x, y, -1))
			button.focus_neighbor_bottom = button.get_path_to(_vertical(rows, x, y, 1))

static func _enabled(button: Variant) -> bool:
	return button is Button and not button.disabled and button.focus_mode != Control.FOCUS_NONE

static func _horizontal(row: Array, index: int, step: int) -> Button:
	var cursor := index + step
	while cursor >= 0 and cursor < row.size():
		if _enabled(row[cursor]): return row[cursor]
		cursor += step
	return row[index]

static func _vertical(rows: Array, x: int, y: int, step: int) -> Button:
	var ratio: float = (x + .5) / rows[y].size()
	var cursor := y + step
	while cursor >= 0 and cursor < rows.size():
		var nearest: Button
		var distance := INF
		var row: Array = rows[cursor]
		for index in row.size():
			if not _enabled(row[index]): continue
			var candidate_distance: float = absf((index + .5) / row.size() - ratio)
			if candidate_distance < distance:
				nearest = row[index]
				distance = candidate_distance
		if nearest != null: return nearest
		cursor += step
	return rows[y][x]

extends VBoxContainer
## Returning a fielded card anywhere in the library removes it atomically.
const DRAG := preload("res://scripts/ui/chronicle/chronicle_party_drag_card.gd")
var host: Control
var hovering_drop := false

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_exited.connect(func(): hovering_drop = false; queue_redraw())

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	hovering_drop = DRAG.valid_drop(host, data, -1)
	queue_redraw()
	return hovering_drop

func _drop_data(_position: Vector2, data: Variant) -> void:
	DRAG.apply_drop(host, data, -1)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_SPACE] and not DRAG.carried(host).is_empty():
		DRAG.apply_drop(host, DRAG.carried(host), -1)
		accept_event()

func _draw() -> void:
	if hovering_drop:
		draw_rect(Rect2(Vector2.ZERO, size).grow(-2), Color("dfc187"), false, 3)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		hovering_drop = false
		queue_redraw()

extends RefCounted
## Fonts and campaign frame decoration used by the current chronicle UI.
const CAMPAIGN_FRAME := preload("res://scripts/ui/shared/campaign_frame.gd")
static var reading_font: SystemFont
static var heading_font: SystemFont

static func get_heading_font() -> SystemFont:
	if heading_font == null:
		heading_font = SystemFont.new()
		heading_font.font_names = PackedStringArray(["Noto Serif CJK SC", "Source Han Serif SC", "SimSun", "serif"])
		heading_font.font_weight = 700
	return heading_font

static func apply_campaign_frame(control: Control, variant: String = "panel") -> void:
	if control == null:
		return
	for child in control.get_children():
		if child is CAMPAIGN_FRAME and not child.is_queued_for_deletion():
			child.variant = variant
			child.queue_redraw()
			return
	var frame := CAMPAIGN_FRAME.new()
	frame.name = "CampaignFrame"
	frame.variant = variant
	control.add_child(frame)
	# A Node2D decoration contributes neither input nor container minimum size.
	if variant == "screen":
		frame.z_index = 8
	else:
		control.move_child(frame, 0)

static func get_reading_font() -> SystemFont:
	if reading_font == null:
		reading_font = SystemFont.new()
		reading_font.font_names = PackedStringArray(["Noto Sans CJK SC", "Microsoft YaHei", "PingFang SC", "sans-serif"])
	return reading_font

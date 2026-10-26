extends SceneTree

const CORE := preload("res://addons/godot_mcp/native_mcp/mcp_server_core.gd")
const DEBUG_TOOLS := preload("res://addons/godot_mcp/tools/debug_tools_native.gd")

func _init() -> void:
	var core = CORE.new()
	core.set_log_level(0)
	var module = DEBUG_TOOLS.new()
	module.register_tools(core)
	assert(core.get_tools_count() > 0)
	var server_ref: WeakRef = weakref(core)
	var module_ref: WeakRef = weakref(module)
	core.cleanup()
	assert(core.get_tools_count() == 0)
	core.cleanup() # Repeated shutdown is safe even when the transport never started.
	module = null
	core = null
	assert(module_ref.get_ref() == null and server_ref.get_ref() == null)
	print("MCP_CLEANUP_SMOKE_OK")
	quit()

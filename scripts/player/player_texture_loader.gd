extends RefCounted

static func get_desktop_sketch_path(relative_path: String) -> String:
	return OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP).replace("\\", "/") + "/草图/" + relative_path

static func get_project_sketch_path(relative_path: String) -> String:
	return "res://assets/sketch/" + relative_path

static func get_cached_runtime_texture(relative_path: String, runtime_texture_cache: Dictionary) -> Texture2D:
	if runtime_texture_cache.has(relative_path):
		return runtime_texture_cache[relative_path]
	var project_path := get_project_sketch_path(relative_path)
	if ResourceLoader.exists(project_path):
		var project_texture := load(project_path) as Texture2D
		if project_texture != null:
			runtime_texture_cache[relative_path] = project_texture
			return project_texture
	var image := Image.new()
	var load_error := image.load(get_desktop_sketch_path(relative_path))
	if load_error != OK:
		return null
	var texture := ImageTexture.create_from_image(image)
	runtime_texture_cache[relative_path] = texture
	return texture

static func create_white_key_material(
		shader: Shader,
		value_threshold: float = 0.94,
		saturation_threshold: float = 0.08,
		edge_softness: float = 0.03
) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("value_threshold", value_threshold)
	material.set_shader_parameter("saturation_threshold", saturation_threshold)
	material.set_shader_parameter("edge_softness", edge_softness)
	return material

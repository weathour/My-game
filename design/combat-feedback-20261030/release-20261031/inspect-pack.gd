extends SceneTree
var paths: Array[String] = []
var rows: Array[Dictionary] = []
func _init() -> void: call_deferred("run")
func walk(path: String) -> void:
    var dir := DirAccess.open(path)
    if dir == null: return
    dir.include_hidden = true
    for child in dir.get_directories():
        if child not in [".",".."]: walk(path.path_join(child))
    for child in dir.get_files(): paths.append(path.path_join(child))
func run() -> void:
    walk("res://")
    var origins := {}
    for path in paths:
        if not path.ends_with(".import"): continue
        var cfg := ConfigFile.new()
        if cfg.load(path) != OK: continue
        for key in cfg.get_section_keys("remap"):
            if str(key).begins_with("path"):
                origins[str(cfg.get_value("remap",key))] = path.trim_suffix(".import")
    var total := 0
    for path in paths:
        var file := FileAccess.open(path,FileAccess.READ)
        if file == null: continue
        var amount := file.get_length()
        total += amount
        rows.append({"path":path,"source":str(origins.get(path,path)),"bytes":amount})
    rows.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.bytes) > int(b.bytes))
    var groups := {}
    for row in rows:
        var source: String = row.source.trim_prefix("res://")
        var parts := source.split("/")
        var key := parts[0] + ("/" + parts[1] if parts.size() > 1 else "")
        groups[key] = int(groups.get(key,0)) + int(row.bytes)
    var report := {"scope":"Fresh PCK inventory; entries measured with FileAccess, imported textures mapped through packed .import metadata.","entries":rows.size(),"entry_bytes":total,"groups":groups,"largest":rows.slice(0,30)}
    var target := OS.get_environment("MYGAME_INVENTORY_OUTPUT")
    FileAccess.open(target,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("PACK_INVENTORY_OK entries=",rows.size()," bytes=",total)
    quit()

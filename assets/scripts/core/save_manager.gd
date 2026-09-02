class_name SaveManager

const SAVE_PATH: String = "user://save_data.cfg"


static func save_last_level(scene_path: String) -> void:
	if scene_path == "" or scene_path.contains("menu"):
		return
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("game", "last_scene", scene_path)
	config.save(SAVE_PATH)


static func get_last_level(default_path: String = "res://assets/scenes/levels/map_1.tscn") -> String:
	var config := ConfigFile.new()
	var err := config.load(SAVE_PATH)
	if err == OK:
		return config.get_value("game", "last_scene", default_path)
	return default_path


static func has_save() -> bool:
	var config := ConfigFile.new()
	return config.load(SAVE_PATH) == OK and config.has_section_key("game", "last_scene")

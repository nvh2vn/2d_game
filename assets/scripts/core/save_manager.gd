class_name SaveManager

const SAVE_PATH: String = "user://save_data.cfg"

static var return_scene_path: String = "res://assets/scenes/menu/main_menu.tscn"
static var last_geo_collected: int = 0
static var last_bench_pos: Vector2 = Vector2.ZERO
static var last_bench_scene: String = ""


static func save_bench_checkpoint(bench_pos: Vector2, scene_path: String) -> void:
	last_bench_pos = bench_pos
	last_bench_scene = scene_path
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("checkpoint", "bench_x", bench_pos.x)
	config.set_value("checkpoint", "bench_y", bench_pos.y)
	config.set_value("checkpoint", "scene", scene_path)
	config.save(SAVE_PATH)


static func get_bench_checkpoint() -> Dictionary:
	var config := ConfigFile.new()
	var err := config.load(SAVE_PATH)
	if err == OK and config.has_section("checkpoint"):
		var bx = config.get_value("checkpoint", "bench_x", 0.0)
		var by = config.get_value("checkpoint", "bench_y", 0.0)
		var sc = config.get_value("checkpoint", "scene", "")
		return {"pos": Vector2(bx, by), "scene": sc}
	if last_bench_pos != Vector2.ZERO:
		return {"pos": last_bench_pos, "scene": last_bench_scene}
	return {"pos": Vector2.ZERO, "scene": ""}


static func save_last_level(scene_path: String) -> void:
	if scene_path == "" or scene_path.contains("menu") or scene_path.contains("ui"):
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


static func save_geo(amount: int) -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("player", "geo", amount)
	config.save(SAVE_PATH)


static func get_geo() -> int:
	var config := ConfigFile.new()
	var err := config.load(SAVE_PATH)
	if err == OK:
		return config.get_value("player", "geo", 0)
	return 0


static func save_shade(pos: Vector2, scene_path: String, geo: int) -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("shade", "active", true)
	config.set_value("shade", "x", pos.x)
	config.set_value("shade", "y", pos.y)
	config.set_value("shade", "scene", scene_path)
	config.set_value("shade", "geo", geo)
	config.save(SAVE_PATH)


static func get_shade() -> Dictionary:
	var config := ConfigFile.new()
	var err := config.load(SAVE_PATH)
	if err == OK and config.has_section("shade") and config.get_value("shade", "active", false):
		return {
			"active": true,
			"pos": Vector2(config.get_value("shade", "x", 0.0), config.get_value("shade", "y", 0.0)),
			"scene": config.get_value("shade", "scene", ""),
			"geo": config.get_value("shade", "geo", 0)
		}
	return {"active": false, "pos": Vector2.ZERO, "scene": "", "geo": 0}


static func clear_shade() -> void:
	var config := ConfigFile.new()
	var err := config.load(SAVE_PATH)
	if err == OK:
		config.set_value("shade", "active", false)
		config.set_value("shade", "geo", 0)
		config.save(SAVE_PATH)


static func save_cocoon(pos: Vector2, scene_path: String, geo: int) -> void:
	save_shade(pos, scene_path, geo)


static func get_cocoon() -> Dictionary:
	return get_shade()


static func clear_cocoon() -> void:
	clear_shade()



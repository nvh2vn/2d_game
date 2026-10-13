extends Node

signal waypoint_unlocked(wp_id: String, wp_name: String)

var unlocked_waypoints: Dictionary = {}
var target_waypoint_marker: String = ""

const SAVE_PATH: String = "user://save_data.cfg"

func _ready() -> void:
	load_waypoints()

func unlock_waypoint(wp_id: String, wp_name: String, scene_path: String, marker_id: String) -> void:
	if wp_id == "" or wp_name == "":
		return
		
	if not unlocked_waypoints.has(wp_id):
		unlocked_waypoints[wp_id] = {
			"name": wp_name,
			"scene_path": scene_path,
			"marker_id": marker_id
		}
		waypoint_unlocked.emit(wp_id, wp_name)
		save_waypoints()

func is_unlocked(wp_id: String) -> bool:
	return unlocked_waypoints.has(wp_id)

func get_unlocked_list() -> Array:
	var list: Array = []
	for wp_id in unlocked_waypoints.keys():
		var item = unlocked_waypoints[wp_id].duplicate()
		item["id"] = wp_id
		list.append(item)
	return list

func save_waypoints() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("teleport", "unlocked", unlocked_waypoints)
	config.save(SAVE_PATH)

func load_waypoints() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		unlocked_waypoints = config.get_value("teleport", "unlocked", {})

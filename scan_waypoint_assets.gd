@tool
extends SceneTree

func _init() -> void:
	print("==========================================")
	print("--- SCANNING ASSETS FOR WAYPOINT/PILLAR ---")
	print("==========================================")
	scan_dir("res://assets")
	print("==========================================")
	quit()

func scan_dir(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if not file_name.begins_with("."):
					scan_dir(path + "/" + file_name)
			else:
				var lower = file_name.to_lower()
				if lower.ends_with(".png") or lower.ends_with(".jpg") or lower.ends_with(".webp") or lower.ends_with(".tscn"):
					if any_keyword(lower):
						print("MATCH: ", path + "/" + file_name)
			file_name = dir.get_next()

func any_keyword(txt: String) -> bool:
	var kw = ["pillar", "waypoint", "monolith", "obelisk", "statue", "altar", "teleport", "shrine", "totem", "plinth", "pole", "door", "gate", "fury", "ouiji", "bench"]
	for k in kw:
		if k in txt:
			return true
	return false

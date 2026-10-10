@tool
extends SceneTree

func _init() -> void:
	print("==========================================")
	print("--- VERIFYING TELEPORT WAYPOINT SYSTEM ---")
	print("==========================================")
	
	# 1. Test TeleportManager unlock & list statically
	TeleportManager.unlock_waypoint("area_1_pillar", "Khu Vực 1 - King's Pass", "res://assets/scenes/levels/map_1.tscn", "wp_1")
	TeleportManager.unlock_waypoint("area_2_pillar", "Khu Vực 2 - Dirtmouth", "res://assets/scenes/levels/level_2.tscn", "wp_2")
	
	assert(TeleportManager.is_unlocked("area_1_pillar") == true, "Waypoint 1 unlock fail")
	assert(TeleportManager.is_unlocked("area_2_pillar") == true, "Waypoint 2 unlock fail")
	
	var list = TeleportManager.get_unlocked_list()
	assert(list.size() >= 2, "Unlocked list size fail")
	print("✅ 1. TeleportManager unlock & persistence: PASSED")
	
	# 2. Test WaypointPillar script loading
	var pillar_script = load("res://assets/scripts/environment/waypoint_pillar.gd")
	assert(pillar_script != null, "WaypointPillar script load fail")
	var pillar_inst = pillar_script.new()
	assert(pillar_inst.waypoint_id == "area_1_pillar", "Pillar default id fail")
	print("✅ 2. WaypointPillar script & instance: PASSED")
	
	# 3. Test TeleportMenu script loading
	var menu_script = load("res://assets/scripts/ui/teleport_menu.gd")
	assert(menu_script != null, "TeleportMenu script load fail")
	print("✅ 3. TeleportMenu script load: PASSED")
	
	print("==========================================")
	print("--- ALL TELEPORT SYSTEM TESTS PASSED! ---")
	print("==========================================")
	quit()

@tool
extends SceneTree

func _init():
	print("--- BEGIN TEST CONTEXTUAL INTERACT BUTTON ---")
	
	# 1. Verify InputMap
	assert(InputMap.has_action("interact"), "InputMap must have 'interact' action")
	var events = InputMap.action_get_events("interact")
	print("Interact action event count: ", events.size())
	assert(events.size() > 0, "Interact action must have assigned events")
	
	# 2. Instantiate TouchControls
	var tc_scene = load("res://scenes/ui/touch_controls.tscn")
	assert(tc_scene != null, "touch_controls.tscn must load")
	var tc = tc_scene.instantiate()
	root.add_child(tc)
	
	var interact_btn = tc.get_node_or_null("%InteractButton")
	assert(interact_btn != null, "InteractButton must exist in touch_controls")
	print("InteractButton found: ", interact_btn.name, " Action: ", interact_btn.action)
	assert(interact_btn.action == &"interact", "InteractButton action must be 'interact'")
	assert(not interact_btn.visible or interact_btn.modulate.a == 0.0, "InteractButton must be initially hidden")
	
	# 3. Test show_interact_button
	tc.show_interact_button("test_npc")
	assert(interact_btn.visible, "InteractButton must be visible after show_interact_button")
	print("InteractButton shown, visible: ", interact_btn.visible, " modulate.a: ", interact_btn.modulate.a)
	
	# 4. Test hide_interact_button
	tc.hide_interact_button()
	print("hide_interact_button called successfully")
	
	# 5. Test Tuk NPC script
	var tuk_script = load("res://scripts/npc/tuk_npc.gd")
	assert(tuk_script != null, "tuk_npc.gd must load")
	print("tuk_npc.gd loaded successfully")
	
	# 6. Test Bench script
	var bench_script = load("res://scripts/environment/bench.gd")
	assert(bench_script != null, "bench.gd must load")
	print("bench.gd loaded successfully")
	
	# 7. Test Waypoint script
	var wp_script = load("res://scripts/environment/waypoint_pillar.gd")
	assert(wp_script != null, "waypoint_pillar.gd must load")
	print("waypoint_pillar.gd loaded successfully")
	
	# 8. Test Elevator scene
	var elev_scene = load("res://scenes/environment/elevator_fast_travel.tscn")
	assert(elev_scene != null, "elevator_fast_travel.tscn must load")
	var elev = elev_scene.instantiate()
	assert(elev is ElevatorFastTravel, "ElevatorFastTravel instance must have script")
	print("ElevatorFastTravel instantiated with script successfully")
	elev.queue_free()
	
	tc.queue_free()
	print("--- ALL TESTS PASSED SUCCESSFULLY! ---")
	quit()

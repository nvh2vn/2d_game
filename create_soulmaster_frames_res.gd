@tool
extends SceneTree

func _init():
	print("Assembling Soul Master SpriteFrames...")
	var base = "res://assets/art/2d/silksong_full/Animations/Enemy/SoulMaster/"
	var sf = SpriteFrames.new()
	if sf.has_animation("default"): sf.remove_animation("default")
	
	# Helper
	var add_anim = func(anim_name: String, path_list: Array, fps: float, loop: bool):
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, fps)
		sf.set_animation_loop(anim_name, loop)
		for p in path_list:
			var tex = load(p)
			if tex:
				sf.add_frame(anim_name, tex)
			else:
				printerr("Could not load: ", p)
				
	# 1. idle
	var idle_paths = []
	for i in range(6): idle_paths.append(base + "Idle/" + str(i) + ".png")
	add_anim.call("idle", idle_paths, 8.0, true)
	
	# 2. teleport_out
	var tp_out_paths = []
	for i in range(7): tp_out_paths.append(base + "Teleport/" + str(i) + ".png")
	add_anim.call("teleport_out", tp_out_paths, 16.0, false)
	
	# 3. teleport_in
	var tp_in_paths = []
	for i in [6, 5, 4, 3, 2, 1, 0]: tp_in_paths.append(base + "Teleport/" + str(i) + ".png")
	add_anim.call("teleport_in", tp_in_paths, 16.0, false)
	
	# 4. cast_orb
	var cast_paths = []
	for i in range(3): cast_paths.append(base + "StartSummon/" + str(i) + ".png")
	for i in range(4): cast_paths.append(base + "Summon/" + str(i) + ".png")
	add_anim.call("cast_orb", cast_paths, 10.0, false)
	
	# 5. orb_shield
	add_anim.call("orb_shield", idle_paths, 8.0, true)
	
	# 6. slam_anticipation
	var sq_paths = []
	for i in range(8): sq_paths.append(base + "StartQuake/" + str(i) + ".png")
	add_anim.call("slam_anticipation", sq_paths, 12.0, true)
	
	# 7. slam_dive
	add_anim.call("slam_dive", [base + "Quake.png"], 1.0, true)
	
	# 8. dash
	var dash_paths = []
	for i in range(6): dash_paths.append(base + "StartDash/" + str(i) + ".png")
	for i in range(3): dash_paths.append(base + "Dash/" + str(i) + ".png")
	add_anim.call("dash", dash_paths, 14.0, false)
	
	# 9. stagger_start
	var start_stun_paths = []
	for i in range(10): start_stun_paths.append(base + "StartStun/" + str(i) + ".png")
	add_anim.call("stagger_start", start_stun_paths, 12.0, false)
	
	# 10. stagger
	var stun_paths = []
	for i in range(6): stun_paths.append(base + "Stun/" + str(i) + ".png")
	add_anim.call("stagger", stun_paths, 8.0, true)
	
	# 11. death
	var die_paths = []
	for i in range(7): die_paths.append(base + "Die/" + str(i) + ".png")
	add_anim.call("death", die_paths, 8.0, false)
	
	var save_path = "res://assets/art/2d/silksong_full/Animations/Enemy/SoulMaster/soul_master_frames.tres"
	var err = ResourceSaver.save(sf, save_path)
	if err == OK:
		print("Saved soul_master_frames.tres")
	else:
		printerr("Failed to save soul_master_frames.tres: ", err)
		quit(1)
		return
		
	# Shockwave frames
	var sw_sf = SpriteFrames.new()
	if sw_sf.has_animation("default"): sw_sf.remove_animation("default")
	var sw_paths = []
	for i in range(5): sw_paths.append(base + "QuakeEffect/" + str(i) + ".png")
	sw_sf.add_animation("wave")
	sw_sf.set_animation_speed("wave", 12.0)
	sw_sf.set_animation_loop("wave", false)
	for p in sw_paths:
		var tex = load(p)
		if tex: sw_sf.add_frame("wave", tex)
	ResourceSaver.save(sw_sf, "res://assets/art/2d/silksong_full/Animations/Enemy/SoulMaster/soul_shockwave_frames.tres")
	print("Saved soul_shockwave_frames.tres")
	
	quit(0)

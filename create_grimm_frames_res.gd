@tool
extends SceneTree

func _init():
	print("Creating SpriteFrames resource for Troupe Master Grimm...")
	var frames = SpriteFrames.new()
	var dir_path = "res://assets/art/2d/Enemies/grimm_extracted/"
	
	var anim_configs = {
		"idle": {"count": 12, "fps": 10.0, "loop": true},
		"bow": {"count": 7, "fps": 7.0, "loop": false},
		"screech": {"count": 4, "fps": 10.0, "loop": true},
		"teleport_out": {"count": 5, "fps": 16.0, "loop": false},
		"teleport_in": {"count": 2, "fps": 12.0, "loop": false},
		"dash_slash": {"count": 7, "fps": 14.0, "loop": false},
		"uppercut": {"count": 3, "fps": 10.0, "loop": false},
		"dive": {"count": 3, "fps": 12.0, "loop": false},
		"slide": {"count": 3, "fps": 12.0, "loop": false},
		"cast_firebats": {"count": 8, "fps": 10.0, "loop": false},
		"spikes_cast": {"count": 10, "fps": 12.0, "loop": false},
		"pufferfish": {"count": 5, "fps": 10.0, "loop": true},
		"death": {"count": 5, "fps": 8.0, "loop": false},
		"stagger": {"count": 3, "fps": 8.0, "loop": false, "prefix": "death"}
	}
	
	# Clear default animation
	if frames.has_animation("default"):
		frames.remove_animation("default")
		
	for anim_name in anim_configs:
		var cfg = anim_configs[anim_name]
		var count = cfg["count"]
		var fps = cfg["fps"]
		var loop = cfg["loop"]
		var prefix = cfg.get("prefix", anim_name)
		
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, fps)
		frames.set_animation_loop(anim_name, loop)
		
		for i in range(count):
			var tex_path = dir_path + prefix + "_" + str(i) + ".png"
			var tex = load(tex_path)
			if tex:
				frames.add_frame(anim_name, tex)
			else:
				printerr("Missing texture: ", tex_path)
				
	var save_path = "res://assets/art/2d/Enemies/master_grimm_frames.tres"
	var err = ResourceSaver.save(frames, save_path)
	if err == OK:
		print("Successfully saved SpriteFrames to ", save_path)
	else:
		printerr("Failed to save SpriteFrames: ", err)
		quit(1)
		return
		
	# Also let's create SpriteFrames for firebat projectile
	var bat_frames = SpriteFrames.new()
	if bat_frames.has_animation("default"): bat_frames.remove_animation("default")
	bat_frames.add_animation("fly")
	bat_frames.set_animation_speed("fly", 12.0)
	bat_frames.set_animation_loop("fly", true)
	for i in range(5):
		var tex = load(dir_path + "firebat_" + str(i) + ".png")
		if tex: bat_frames.add_frame("fly", tex)
	ResourceSaver.save(bat_frames, "res://assets/art/2d/Enemies/grimm_firebat_frames.tres")
	print("Saved grimm_firebat_frames.tres")
	
	# And small bat for stagger
	var small_bat_frames = SpriteFrames.new()
	if small_bat_frames.has_animation("default"): small_bat_frames.remove_animation("default")
	small_bat_frames.add_animation("fly")
	small_bat_frames.set_animation_speed("fly", 12.0)
	small_bat_frames.set_animation_loop("fly", true)
	for i in range(5):
		var tex = load(dir_path + "stagger_bat_" + str(i) + ".png")
		if tex: small_bat_frames.add_frame("fly", tex)
	ResourceSaver.save(small_bat_frames, "res://assets/art/2d/Enemies/grimm_stagger_bat_frames.tres")
	print("Saved grimm_stagger_bat_frames.tres")
	
	quit(0)

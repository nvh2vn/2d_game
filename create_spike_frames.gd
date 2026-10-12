@tool
extends SceneTree

func _init():
	var dir_path = "res://assets/art/2d/Enemies/grimm_extracted/"
	var spike_frames = SpriteFrames.new()
	if spike_frames.has_animation("default"): spike_frames.remove_animation("default")
	
	# warn animation
	spike_frames.add_animation("warn")
	spike_frames.set_animation_speed("warn", 8.0)
	spike_frames.set_animation_loop("warn", true)
	spike_frames.add_frame("warn", load(dir_path + "spike_0.png"))
	spike_frames.add_frame("warn", load(dir_path + "spike_1.png"))
	
	# erupt animation
	spike_frames.add_animation("erupt")
	spike_frames.set_animation_speed("erupt", 14.0)
	spike_frames.set_animation_loop("erupt", false)
	spike_frames.add_frame("erupt", load(dir_path + "spike_2.png"))
	spike_frames.add_frame("erupt", load(dir_path + "spike_3.png"))
	spike_frames.add_frame("erupt", load(dir_path + "spike_4.png"))
	spike_frames.add_frame("erupt", load(dir_path + "spike_5.png"))
	
	# retract animation
	spike_frames.add_animation("retract")
	spike_frames.set_animation_speed("retract", 12.0)
	spike_frames.set_animation_loop("retract", false)
	spike_frames.add_frame("retract", load(dir_path + "spike_2.png"))
	spike_frames.add_frame("retract", load(dir_path + "spike_1.png"))
	spike_frames.add_frame("retract", load(dir_path + "spike_0.png"))
	
	ResourceSaver.save(spike_frames, "res://assets/art/2d/Enemies/grimm_spike_frames.tres")
	print("Saved grimm_spike_frames.tres")
	quit(0)

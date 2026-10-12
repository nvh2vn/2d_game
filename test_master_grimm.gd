@tool
extends SceneTree

const MasterGrimmScript = preload("res://assets/scripts/enemies/master_grimm.gd")

func _init():
	print("--- Running Master Grimm Automated Tests ---")
	
	# 1. Test Scene Loading
	var grimm_packed = load("res://assets/scenes/enemies/master_grimm.tscn")
	if not grimm_packed:
		printerr("TEST FAILED: Cannot load master_grimm.tscn")
		quit(1)
		return
	print("[PASS] master_grimm.tscn loaded successfully")
	
	# 2. Test Instantiation
	var grimm = grimm_packed.instantiate()
	if not grimm:
		printerr("TEST FAILED: Cannot instantiate MasterGrimm")
		quit(1)
		return
	print("[PASS] MasterGrimm instantiated")
	
	# Add to root for testing ready hooks
	root.add_child(grimm)
	
	# 3. Test SpriteFrames and Animations
	var anim_sprite: AnimatedSprite2D = grimm.get_node("%AnimatedSprite")
	if not anim_sprite or not anim_sprite.sprite_frames:
		printerr("TEST FAILED: Missing AnimatedSprite2D or SpriteFrames")
		quit(1)
		return
		
	var required_anims = [
		"idle", "bow", "screech", "teleport_out", "teleport_in",
		"dash_slash", "uppercut", "dive", "slide",
		"cast_firebats", "spikes_cast", "pufferfish", "stagger", "death"
	]
	for a in required_anims:
		if not anim_sprite.sprite_frames.has_animation(a):
			printerr("TEST FAILED: Missing animation: ", a)
			quit(1)
			return
		var frame_count = anim_sprite.sprite_frames.get_frame_count(a)
		if frame_count == 0:
			printerr("TEST FAILED: Animation ", a, " has 0 frames!")
			quit(1)
			return
		print("  - Anim '", a, "': ", frame_count, " frames, fps=", anim_sprite.sprite_frames.get_animation_speed(a))
	print("[PASS] All required animations exist and have frames")
	
	# 4. Test Prefabs Loading
	var prefabs = {
		"Firebat": grimm.firebat_scene,
		"Spike": grimm.spike_scene,
		"Fireball": grimm.fireball_scene,
		"StaggerBat": grimm.stagger_bat_scene,
		"HealthBar": grimm.health_bar_scene
	}
	for p_name in prefabs:
		var scene = prefabs[p_name]
		if not scene:
			printerr("TEST FAILED: Prefab ", p_name, " is null!")
			quit(1)
			return
		var inst = scene.instantiate()
		if not inst:
			printerr("TEST FAILED: Cannot instantiate prefab ", p_name)
			quit(1)
			return
		print("  - Prefab '", p_name, "' instantiated: ", inst.name)
		inst.free()
	print("[PASS] All combat and UI prefabs instantiated successfully")
	
	# 5. Test Bow Punish Logic
	grimm.state = MasterGrimmScript.BossState.INTRO_BOW
	print("Initial state: INTRO_BOW. Simulating player attack during bow...")
	grimm.take_damage(1)
	print("Post-attack state: ", MasterGrimmScript.BossState.keys()[grimm.state])
	if grimm.state != MasterGrimmScript.BossState.TELEPORTING and grimm.state != MasterGrimmScript.BossState.ATTACK_PUFFERFISH:
		printerr("TEST FAILED: Did not enter bow punish state!")
		quit(1)
		return
	print("[PASS] Bow attack properly triggers retaliation mechanic")
	
	# Cleanup
	grimm.queue_free()
	print("--- ALL TESTS PASSED SUCCESSFULLY! ---")
	quit(0)

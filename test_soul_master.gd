@tool
extends SceneTree

const SoulMasterScript = preload("res://assets/scripts/enemies/soul_master.gd")

func _init():
	print("--- Running Soul Master Automated Verification ---")
	
	# 1. Test Scene Loading
	var sm_packed = load("res://assets/scenes/enemies/soul_master.tscn")
	if not sm_packed:
		printerr("TEST FAILED: Cannot load soul_master.tscn")
		quit(1)
		return
	print("[PASS] soul_master.tscn loaded successfully")
	
	# 2. Test Instantiation
	var sm = sm_packed.instantiate()
	if not sm:
		printerr("TEST FAILED: Cannot instantiate SoulMaster")
		quit(1)
		return
	print("[PASS] SoulMaster instantiated")
	
	root.add_child(sm)
	
	# 3. Test SpriteFrames and Animations
	var anim_sprite: AnimatedSprite2D = sm.get_node("%AnimatedSprite")
	if not anim_sprite or not anim_sprite.sprite_frames:
		printerr("TEST FAILED: Missing AnimatedSprite2D or SpriteFrames")
		quit(1)
		return
		
	var required_anims = [
		"idle", "teleport_out", "teleport_in",
		"cast_orb", "orb_shield", "slam_anticipation", "slam_dive",
		"dash", "stagger_start", "stagger", "death"
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
	print("[PASS] All required Soul Master animations exist and have frames")
	
	# 4. Test Prefabs Loading
	var prefabs = {
		"SoulOrb": sm.orb_scene,
		"Shockwave": sm.shockwave_scene,
		"HealthBar": sm.health_bar_scene
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
	print("[PASS] All combat prefabs instantiated successfully")
	
	# 5. Test State & Stagger Logic
	sm.state = SoulMasterScript.BossState.IDLE_HOVER
	print("Simulating damage hits up to stagger threshold...")
	for i in range(14):
		sm.take_damage(1)
		sm.damage_cooldown = 0.0 # reset for test loop
		
	print("Post-hits state: ", SoulMasterScript.BossState.keys()[sm.state])
	if sm.state != SoulMasterScript.BossState.STAGGER:
		printerr("TEST FAILED: Did not enter STAGGER state after 14 hits!")
		quit(1)
		return
	print("[PASS] Stagger mechanic triggered successfully")
	
	# Cleanup
	sm.queue_free()
	print("--- ALL SOUL MASTER TESTS PASSED! ---")
	quit(0)

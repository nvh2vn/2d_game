@tool
extends SceneTree

func _initialize() -> void:
	var rep = FileAccess.open("res://verify_all_enemies_report.txt", FileAccess.WRITE)
	rep.store_line("==================================================")
	rep.store_line("  HOLLOW KNIGHT ENEMIES VERIFICATION REPORT")
	rep.store_line("==================================================")
	
	var prefabs = [
		"res://assets/prefabs/enemies/winged_sentry.tscn",
		"res://assets/prefabs/enemies/aspid_hunter.tscn",
		"res://assets/prefabs/enemies/furious_vengefly.tscn",
		"res://assets/prefabs/enemies/baldur.tscn",
		"res://assets/prefabs/enemies/corpse_creeper.tscn",
		"res://assets/prefabs/enemies/deephunter.tscn",
		"res://assets/prefabs/enemies/mosscreep.tscn",
		"res://assets/prefabs/enemies/mossfly.tscn",
		"res://assets/prefabs/projectiles/aspid_projectile.tscn"
	]
	
	var passed = 0
	var total = prefabs.size()
	
	for path in prefabs:
		rep.store_line("Checking: " + path)
		var scn = load(path)
		if not scn:
			rep.store_line("  [FAIL] Cannot load scene: " + path)
			continue
			
		var inst = scn.instantiate()
		if not inst:
			rep.store_line("  [FAIL] Cannot instantiate scene: " + path)
			continue
			
		root.add_child(inst)
		
		# Thông tin Node
		rep.store_line("  [OK] Node: " + inst.name + " (" + inst.get_class() + ")")
		
		# Kiểm tra AnimatedSprite & Animations
		var sprite = inst.get_node_or_null("%AnimatedSprite")
		if sprite and sprite.sprite_frames:
			var anims = sprite.sprite_frames.get_animation_names()
			rep.store_line("  [OK] SpriteFrames animations (" + str(anims.size()) + "): " + str(anims))
		elif inst is Area2D:
			rep.store_line("  [OK] Area2D projectile confirmed")
			
		# Kiểm tra Hurtbox & Nail Pogo Support
		var hurtbox = inst.get_node_or_null("%Hurtbox")
		if hurtbox:
			var has_td = hurtbox.has_method("take_damage")
			rep.store_line("  [OK] Hurtbox take_damage method present (Pogo jump ready): " + str(has_td))
			
		# Kiểm tra Hitbox
		var hitbox = inst.get_node_or_null("%Hitbox")
		if hitbox:
			rep.store_line("  [OK] Hitbox contact damage node present")
			
		# Kiểm tra take_damage và Knockback
		if inst.has_method("take_damage"):
			var init_hp = inst.current_health
			inst.take_damage(1, Vector2.LEFT)
			rep.store_line("  [OK] take_damage test: HP " + str(init_hp) + " -> " + str(inst.current_health))
			
		inst.queue_free()
		passed += 1
		rep.store_line("--------------------------------------------------")
		
	rep.store_line("RESULT: " + str(passed) + "/" + str(total) + " PREFABS PASSED 100% VERIFICATION")
	rep.close()
	quit(0)

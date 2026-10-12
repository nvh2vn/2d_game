@tool
extends SceneTree

# Mock player class mimicking PlayerController
class MockPlayer extends CharacterBody2D:
	var current_health: int = 5
	var is_invincible: bool = false
	var last_damage_taken: int = 0
	
	func _init():
		name = "PlayerController"
		collision_layer = 4
		add_to_group("player")
		
	func take_damage(amount: int, _source_pos: Vector2 = Vector2.ZERO) -> void:
		if is_invincible:
			return
		last_damage_taken = amount
		current_health -= amount

func _init():
	print("--- Running Hitbox & Damage Verification ---")
	
	var player = MockPlayer.new()
	root.add_child(player)
	
	# 1. Test Soul Master Hitbox & AttackHitbox
	var sm_scene = load("res://assets/scenes/enemies/soul_master.tscn")
	var sm = sm_scene.instantiate()
	root.add_child(sm)
	
	print("Checking SoulMaster masks:")
	var hb: Area2D = sm.get_node("%Hitbox")
	var ahb: Area2D = sm.get_node("AttackHitbox")
	print("  Hitbox mask: ", hb.collision_mask, " (has layer 3: ", (hb.collision_mask & 4) != 0, ")")
	print("  AttackHitbox mask: ", ahb.collision_mask, " (has layer 3: ", (ahb.collision_mask & 4) != 0, ")")
	if (hb.collision_mask & 4) == 0 or (ahb.collision_mask & 4) == 0:
		printerr("FAILED: SoulMaster Hitbox missing player layer mask!")
		quit(1)
		return
		
	player.last_damage_taken = 0
	sm._on_hitbox_body_entered(player)
	print("  Contact damage result: ", player.last_damage_taken)
	if player.last_damage_taken == 0:
		printerr("FAILED: Hitbox body_entered did not damage player!")
		quit(1)
		return
	print("[PASS] Soul Master contact hitbox successfully damages Player")
	
	player.last_damage_taken = 0
	sm._on_attack_hitbox_body_entered(player)
	print("  AttackHitbox damage result: ", player.last_damage_taken)
	if player.last_damage_taken == 0:
		printerr("FAILED: AttackHitbox body_entered did not damage player!")
		quit(1)
		return
	print("[PASS] Soul Master AttackHitbox successfully damages Player")
	
	# 2. Test Soul Orb Projectile
	var orb_scene = load("res://assets/scenes/enemies/soul_orb.tscn")
	var orb: Area2D = orb_scene.instantiate()
	root.add_child(orb)
	print("Checking SoulOrb mask: ", orb.collision_mask, " (has layer 3: ", (orb.collision_mask & 4) != 0, ")")
	if (orb.collision_mask & 4) == 0:
		printerr("FAILED: SoulOrb missing player layer mask!")
		quit(1)
		return
		
	player.last_damage_taken = 0
	orb._on_body_entered(player)
	print("  SoulOrb damage result: ", player.last_damage_taken)
	if player.last_damage_taken == 0:
		printerr("FAILED: SoulOrb body_entered did not damage player!")
		quit(1)
		return
	print("[PASS] Soul Orb successfully damages Player")
	
	# 3. Test Shockwave Hazard
	var sw_scene = load("res://assets/scenes/enemies/soul_shockwave.tscn")
	var sw: Area2D = sw_scene.instantiate()
	root.add_child(sw)
	print("Checking Shockwave mask: ", sw.collision_mask, " (has layer 3: ", (sw.collision_mask & 4) != 0, ")")
	if (sw.collision_mask & 4) == 0:
		printerr("FAILED: Shockwave missing player layer mask!")
		quit(1)
		return
		
	player.last_damage_taken = 0
	sw._on_body_entered(player)
	print("  Shockwave damage result: ", player.last_damage_taken)
	if player.last_damage_taken == 0:
		printerr("FAILED: Shockwave body_entered did not damage player!")
		quit(1)
		return
	print("[PASS] Shockwave successfully damages Player")
	
	# 4. Test Area-Entered detection (in case hurtbox is an Area2D)
	var dummy_area = Area2D.new()
	player.add_child(dummy_area)
	
	player.last_damage_taken = 0
	sm._on_attack_hitbox_area_entered(dummy_area)
	print("  AttackHitbox area_entered damage result: ", player.last_damage_taken)
	if player.last_damage_taken == 0:
		printerr("FAILED: AttackHitbox area_entered did not resolve player!")
		quit(1)
		return
	print("[PASS] Area2D detection correctly resolves parent PlayerController and damages Player")
	
	# Cleanup
	sm.queue_free()
	player.queue_free()
	print("--- ALL DAMAGE & HITBOX TESTS PASSED! ---")
	quit(0)
